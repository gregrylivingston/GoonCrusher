class_name Level extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var explosionScene = preload("res://scene/fx/explosion.tscn") #loaded with the level, not with every car
const BEACON_MATERIAL := preload("res://shader/world_beacon.tres") #shared by every landmark's beacon: dim by day
var explosions: ExplosionPool
var fx: Fx #everything round a blast, and the ground's burn marks (scene/fx/fx.gd)
var playerCar: OverheadCarBody2D
## The level's LevelDef (Levels, res://world/levels/<id>.tres). Its clock, spawn tuning and start position
## are copied in when the level enters the tree (applyDef). Old scenes without one keep their own values.
@export var def: LevelDef
var defApplied := false
@export var seconds = 600 #the run clock. Every mode counts it down except Goonpocalypse, which counts up from 0
var levelSeconds: float #the level's authored seconds, kept after the mode replaces `seconds`
var tier: int = ModeTiers.EASY #the run's tier (ModeTiers, picked in run setup): its goal and how tough the world is
#the region's elite strength step (Territories.step), applied to each goon as it spawns (Walker)
var strength: Dictionary = Territories.NO_STEP
#the run's mode and level index, kept: a won run moves the save's selection on (SaveManager.currentLevelPassed)
var runMode: int = Root.gameModes.GOONCRUSHER
var runLevel := 0
var elapsed := 0.0 #run-clock seconds that have passed, whichever way the clock counts (Timer.gd)

var isDaytime: bool = true
var nightsSeen := 0 #nights that fell this run, for the unlock counters (Unlocks.countRun)
var hasEnded := false #endLevel runs once per run, whichever ending gets there first
## A Free Play run: a mode this level doesn't play (Root.freePlayOpen). It pays its coins and nothing else: the
## results ticket credits no medal, clear, record or unlock counter.
var freePlay := false
var endReason: int = -1 #Root.endCondition once the run has ended
var startPosition: Vector2 #where the car starts; objectives are placed relative to it
var clockReady := false #true once the clock holds its final starting value (Sprint sets it from the station distance)

#Sprint: the station is placed by distance (by region: Territories.sprintDistance, x the tier's:
#ModeTiers.SPRINT_DISTANCE) and the clock is derived
#from the real distance.
const SPRINT_DRIVE_FRACTION = 0.25 #ModeTiers' pay estimate: share of the level's seconds spent driving at REFERENCE_SPEED
#px/s; a fixed baseline, not the selected car, so fast cars feel fast. The stock sedan tops out at about
#744 on grass, 615 on snow and 499 on sand and mud, so 450 leaves room for rocks, goons and turns.
const REFERENCE_SPEED = 450.0
#the last region's distance (px): about 0.8 of the stock sedan's tank (87 s at full throttle) at its sand and
#mud top speed. A station is never further than this x ModeTiers.SPRINT_DISTANCE (a Sprint's tier, or a
#Marathon leg), so every race needs fuel pickups or oil upgrades on the way.
const SPRINT_MAX_DISTANCE = 34000.0
const SPRINT_Y_SPREAD = 0.25 #the station's y offset is up to this share of the distance, either way
#The clock is set from the A* route on the coarse map (1280 px cells), which is shorter than the drive: the
#fine walls, pools, props and fords inside passable cells, the corners, and the station house on the lot
#(the lot itself is open on every side). So the route gets a share on top per
#grammar (more where walls are dense) plus a fixed approach allowance (driveLengthFor).
const ROUTE_FACTOR = {&"meadow": 1.08, &"bayou": 1.12, &"canyon": 1.15, &"quarry": 1.12, &"mountain": 1.15,
	&"highway": 1.05, &"city": 1.12, &"yard": 1.15}
const ROUTE_FACTOR_DEFAULT = 1.1
const STATION_APPROACH_PX = 1500.0

#Marathon: a relay of short legs (ModeTiers.MARATHON_LEG) (ModeTiers.LEGS by tier). Each station but the last adds that leg's
#clock, refuels, patches the car up and opens the pit shop; the last one wins.
const MARATHON_TURN = PI / 3 #each leg heads off within this of the last leg's heading
#a leg that would leave the map (WorldGen.CHUNK_LIMIT, less this margin of the leg's length for its y spread)
#heads back toward the map's center instead
const MARATHON_EDGE_MARGIN = 0.3
const MARATHON_HEAL = 35.0   #health restored at each station
var leg := 1
var legHeading := 0.0

#Goonpocalypse: endless. Surviving ModeTiers.pocalypseSeconds beats the mode on the
#run's tier; after that it is a chase for score and time (SaveManager.recordGoonpocalypse).
var targetReached := false

#Defense: hold the station until the clock runs out (ModeTiers.DEFENSE_HOLD seconds). Goons spawn at the mouths of the straight lanes the
#world generator cleared out from it (WorldGen.placeDefense) and march on its pumps, blowing up when they reach one (Walker.siege); the
#station's barrier health is in station.gd. Without lanes (no world map) they ring it instead.
const DEFENSE_RING = 4000.0
const DEFENSE_SPAWNERS = 4
const DEFENSE_START = Vector2(1250, 290) #east of the lot, by the driveway, from the station's origin

#Before any child is ready, so SpawnManager._ready (Goonpocalypse escalation) builds on the def's numbers,
#and before the bench's node_added overrides, which come after this.
func _enter_tree():
	readRun()
	applyDef()

#the run's mode, level and tier from the save, once (a level can re-enter the tree: RunView)
var runRead := false
func readRun() -> void:
	if runRead: return
	runRead = true
	tier = SaveManager.getGameTier()
	runMode = SaveManager.playerData.gameMode
	runLevel = SaveManager.playerData.selectedLevel
	Coop.readArgs()
	if Coop.padGone(): Coop.leave()
	freePlay = Root.isFreePlay(runLevel, runMode)

func applyDef() -> void:
	if defApplied || def == null: return
	defApplied = true
	def.resolve() #the world fields it leaves to its landscape
	readRun()
	seconds = def.seconds
	strength = Territories.step(def.region)
	var spawnManager = get_node_or_null("SpawnManager")
	if spawnManager:
		spawnManager.spawnTimer = def.spawnTimer * ModeTiers.SPAWN_TIMER[tier]
		spawnManager.giantOdds = def.giantOdds + ModeTiers.GIANT_ODDS[tier]
		spawnManager.escalationSpeed = def.escalationSpeed * ModeTiers.ESCALATION[tier]
		if runMode == Root.gameModes.DEFENSE: spawnManager.spawnScale = ModeTiers.DEFENSE_SPAWN_SCALE
		if Modes.lightGoons(runMode): spawnManager.spawnScale = ModeTiers.LIGHT_SPAWN_SCALE

#Sprint and Marathon slack: the def's (else the old curve over the level's seconds), x the tier's
func slack() -> float:
	var byTier: Array = ModeTiers.SLACK
	if runMode == Root.gameModes.RALLY: byTier = ModeTiers.RALLY_SLACK
	elif runMode == Root.gameModes.MARATHON: byTier = ModeTiers.MARATHON_SLACK
	elif runMode == Root.gameModes.HOTLAP: byTier = ModeTiers.HOTLAP_SLACK
	elif runMode == Root.gameModes.FLATOUT: byTier = ModeTiers.FLATOUT_SLACK
	return (def.sprintSlack if def else sprintSlack(levelSeconds)) * byTier[tier]

#Marathon: stations to reach on this tier
func legs() -> int:
	return ModeTiers.LEGS[tier]

func _ready():
	levelSeconds = seconds
	BEACON_MATERIAL.set_shader_parameter("night", 0.0) #runs start by day
	explosions = ExplosionPool.new(explosionScene)
	add_child(explosions)
	fx = Fx.new()
	add_child(fx)

	#add my car
	var newPosition = def.startPosition if def else $Car.position
	startPosition = newPosition
	$Car.queue_free()
	if is_instance_valid(Root.playerCar): Root.playerCar.queue_free()
	if Root.selectedCar.is_empty(): #level launched directly (editor F6 or benchmark) - fall back to the saved car
		Root.selectedCar = SaveManager.playerData.cars[SaveManager.playerData.selectedCar]
	Root.playerCar = load(Root.selectedCar.scene).instantiate()
	Root.playerCar.position = newPosition
	add_child(Root.playerCar)

	Root.levelRoot = self
	Pickups.resetRun()
	add_child(PickupWorld.new()) #supply drops, events and chunk props (scene/pickups/pickup_world.gd)
	var warmup = ShaderWarmup.new() #compiles gameplay shaders behind the countdown
	warmup.position = newPosition + Vector2(0, 150)
	add_child(warmup)
	Root.isRunActive = true
	Settings.on_run_started()
	
	Root.playerRoot = get_tree().get_nodes_in_group("playerGameUi")[0]
	Root.playerRoot.updateStats()
	
	OverheadCarBody2D.carBumpScale = {Root.gameModes.PURSUIT: ModeTiers.PURSUIT_BUMP, Root.gameModes.DERBY: ModeTiers.DERBY_BUMP}.get(runMode, 1.0)
	Root.playerCar.fuelFree = Modes.isTrial(runMode) || not Modes.hasGoons(runMode) #no pumps on the road where there are no goons #a Trial is about the driving: the tank doesn't run down
	if not Modes.hasGoons(runMode): $SpawnManager.floorOn = false #no spawners below, and no goons topped up round the car
	else:
		match Modes.running(): #the run rules: a variant plays its base mode's (Modes.plays)
			Root.gameModes.GOONCRUSHER:createCountdownSpawners()
			Root.gameModes.GOONPOCALYPSE:createCountdownSpawners()
			Root.gameModes.BOUNTY:createCountdownSpawners()
			Root.gameModes.MARATHON:createSprintSpawners()
			Root.gameModes.SPRINT:createSprintSpawners()
			#DEFENSE: its spawners ring the station, which exists only once the world is ready

	match Modes.running(): #the tier's clock; Sprint and Marathon set theirs from the route
		Root.gameModes.GOONPOCALYPSE: seconds = 0
		Root.gameModes.GOONCRUSHER: seconds = ModeTiers.countdownSeconds(levelSeconds, tier)
		Root.gameModes.DEFENSE: seconds = ModeTiers.DEFENSE_HOLD[tier]
		Root.gameModes.BOUNTY: seconds = ModeTiers.bountySeconds(tier)
		Root.gameModes.SMASH, Root.gameModes.DRIFT, Root.gameModes.KEEPCUP, Root.gameModes.DERBY: seconds = ModeTiers.goalSeconds(runMode, tier, levelSeconds, 1.0)
		Root.gameModes.CONES: seconds = ModeTiers.CONES_SECONDS[tier]

	#the TileManager waits at least one frame before placing stations, so this is never too late
	var tileManager = $TileManager
	holdUnderShutter()
	if tileManager.isWorldReady: onWorldReady()
	else: tileManager.world_ready.connect(onWorldReady)

var bounty: BountyHunt #Bounty Hunt's marks; null in every other mode
var course: Course #a fixed-map mode's checkpoints or gates; null in every other mode
var rivals: Rivals #the Goon Cup's other drivers; null in every other mode
var coop: CoopRun #a two-player run's guest and split screen (Coop); null with one player
var finishPlace := 0 #the player's place at the finish of a race against rivals (0: didn't finish)

## The player reached the finish (station.gd): a win, or in a race against rivals the place that the tier asks for
func playerFinished() -> void:
	if runMode == Root.gameModes.PURSUIT: return #the station is the runner's goal, not the player's
	if runMode == Root.gameModes.FLATOUT && is_instance_valid(Root.playerCar) && Root.playerCar.velocity.length() > ModeTiers.FLATOUT_STOP_SPEED:
		overshot = true #too fast to stop in the box: it costs time, and the run if there was none to spare
		elapsed += ModeTiers.FLATOUT_PENALTY
		seconds -= ModeTiers.FLATOUT_PENALTY
		if seconds <= 0.0:
			endLevel(false, Root.endCondition.NOTIME)
			return
	if rivals == null:
		endLevel(true, Root.endCondition.SUCCESS)
		return
	finishPlace = rivals.nextPlace()
	rivals.finishOrder.push_back("")
	var placed: bool = finishPlace <= ModeTiers.CUP_PLACE[tier]
	endLevel(placed, Root.endCondition.SUCCESS if placed else Root.endCondition.OUTRUN)

## A rival reached the finish: once the paying places are gone the race is lost
func rivalFinished(car: Node) -> void:
	if rivals == null || hasEnded: return
	if runMode == Root.gameModes.PURSUIT: #the runner made it
		endLevel.call_deferred(false, Root.endCondition.OUTRUN)
		return
	rivals.rivalFinished(car)
	if rivals.nextPlace() > ModeTiers.CUP_PLACE[tier]: endLevel.call_deferred(false, Root.endCondition.OUTRUN)

var cup: KeepCup #Keep the Cup's trophy; null in every other mode
var derby: Derby #Demolition Derby's arena; null in every other mode
var overshot := false #Flat Out: crossed the line too fast to stop
var lapTarget := 0.0 #Hot Lap: the lap time the tier asks for
var lapFinishers := {} #Knockout: laps done -> the cars that have finished that lap

#Hot Lap, Circuit Race, Knockout: a loop out of the start and back along the world's routes (Course.loopRoute),
#and the clock for its laps. Hot Lap asks for a lap under lapTarget; the races have a Sprint's slack a lap.
func setupLoop() -> void:
	var loop := Course.loopRoute($TileManager.worldMap, startPosition, Course.CIRCUIT_RADIUS if runMode == Root.gameModes.CIRCUIT else Course.LOOP_RADIUS)
	if loop.is_empty(): #no way round from here: a square of open-map checkpoints, so the mode still runs
		var s := startPosition
		loop = {"route": PackedVector2Array([s, s + Vector2(4000, 0), s + Vector2(4000, 3200), s + Vector2(0, 3200), s]), "length": 14400.0}
	var count: int = ModeTiers.HOTLAP_LAPS
	if runMode == Root.gameModes.CIRCUIT: count = ModeTiers.CIRCUIT_LAPS
	elif runMode == Root.gameModes.KNOCKOUT: count = maxi(rivals.cars.size(), 1) if rivals else 1 #one car out a lap
	course = Course.new()
	add_child(course)
	course.setupLoop(loop, startPosition, count)
	var lapSeconds := sprintSeconds(driveLength(loop.length), levelSeconds, slack())
	lapTarget = lapSeconds
	seconds = lapSeconds * count * (2.5 if runMode == Root.gameModes.HOTLAP else 1.0) #room for three laps that miss the target

## A car finished a lap of the loop (Course)
func lapDone(car: Node, lapsDone: int) -> void:
	if hasEnded: return
	if car == Root.playerCar && lapsDone < course.laps: TapeBanner.post("LAP %d  %s" % [lapsDone, Course.clock(course.lapTimes[-1])], 1.2)
	if runMode != Root.gameModes.KNOCKOUT || rivals == null: return
	var done: Array = lapFinishers.get_or_add(lapsDone, [])
	done.push_back(car)
	var running: Array = [Root.playerCar] + rivals.cars.filter(func(c): return is_instance_valid(c) && not c.isDestroyed)
	if done.size() < running.size() - 1: return
	for other in running: #everyone else is through: the one still on the lap is out
		if other in done: continue
		if other == Root.playerCar: endLevel.call_deferred(false, Root.endCondition.OUTRUN)
		else:
			rivals.eliminate(other)
			if rivals.cars.is_empty(): endLevel.call_deferred(true, Root.endCondition.SUCCESS)
		return

## A car finished the course (Course): the gates, or every lap of a loop
func courseDone(car: Node) -> void:
	if hasEnded: return
	var mine: bool = car == Root.playerCar
	match runMode:
		Root.gameModes.CONES: endLevel(true, Root.endCondition.SUCCESS)
		Root.gameModes.HOTLAP:
			var quick: bool = course.bestLap() <= lapTarget
			endLevel(quick, Root.endCondition.SUCCESS if quick else Root.endCondition.NOTIME)
		Root.gameModes.CIRCUIT:
			if mine: playerFinished()
			else: rivalFinished(car)
		Root.gameModes.KNOCKOUT: endLevel(mine, Root.endCondition.SUCCESS if mine else Root.endCondition.OUTRUN)
var wrecks := 0 #rivals wrecked this run

## A rival was wrecked (Rivals.onRivalGone): in a Pursuit that is the win
func rivalWrecked(who: String) -> void:
	if hasEnded: return
	wrecks += 1
	TapeBanner.post("%s WRECKED" % (who if who != "" else "RIVAL"), 1.2)
	if runMode == Root.gameModes.PURSUIT: endLevel(true, Root.endCondition.SUCCESS)
	elif runMode in [Root.gameModes.DERBY, Root.gameModes.KNOCKOUT] && rivals && rivals.cars.is_empty(): endLevel(true, Root.endCondition.SUCCESS) #the last car running

var trial: TrialScore #Smash Run's and Drift Trial's score; null in every other mode

#Cone Course: the cones on the lot the world cleared at the start, and the car at the first lane
func setupCones() -> void:
	var map = $TileManager.worldMap
	var center: Vector2 = map.station if map.station != Vector2.INF else startPosition
	course = ConeCourse.build(self, center)
	var car = Root.playerCar
	car.global_position = center + ConeCourse.START
	car.rotation = 0.0
	car.velocity = Vector2.ZERO
	startPosition = car.global_position
	if car.has_node("Camera2D"): car.get_node("Camera2D").reset_smoothing()

## The car smashed a breakable (BreakableProp.smashNode): Smash Run counts it
func propSmashed(_prop: Node) -> void:
	if trial && runMode == Root.gameModes.SMASH: trial.add(1)

## The car knocked over one of the course's cones (PropReactions.knock): a second off the clock
func coneKnocked(cone: Node2D) -> void:
	if course == null || hasEnded: return
	course.conesHit += 1
	seconds = maxf(seconds - ConeCourse.CONE_PENALTY, 0.0)
	var fx = Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null
	if fx: fx.label(cone.global_position, "-1 SECOND", 22, HudTheme.BAD)

#the map is built and every station is placed and in the tree
func onWorldReady() -> void:
	match Modes.running():
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			if is_instance_valid(Root.station):
				seconds = sprintSeconds(driveLength(routeLengthTo(Root.station.global_position)), levelSeconds, slack())
				legHeading = (Root.station.global_position - startPosition).angle()
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station): setupDefense()
		Root.gameModes.BOUNTY:
			bounty = BountyHunt.new()
			add_child(bounty)
			bounty.begin()
	if Modes.hasRivals(runMode):
		rivals = Rivals.new()
		add_child(rivals)
		if runMode == Root.gameModes.PURSUIT: rivals.spawnRunner()
		else: rivals.spawn()
	if Coop.active: #before the mode sets up: a rival guest is one of its field
		coop = CoopRun.new()
		add_child(coop)
	if runMode == Root.gameModes.KEEPCUP:
		cup = KeepCup.new()
		add_child(cup)
	match runMode:
		Root.gameModes.SMASH, Root.gameModes.DRIFT:
			trial = TrialScore.new()
			add_child(trial)
		Root.gameModes.CONES: setupCones()
		Root.gameModes.HOTLAP, Root.gameModes.CIRCUIT, Root.gameModes.KNOCKOUT: setupLoop()
		Root.gameModes.DERBY: derby = Derby.build(self, startPosition) #on the level's own ground, props and all
	if Modes.isFixedMap(runMode) && is_instance_valid(Root.station):
		course = Course.new()
		add_child(course)
		course.setup($TileManager.worldMap.route)
		if runMode == Root.gameModes.FLATOUT: #nitro at every checkpoint: placed, the same every run
			for point in course.points:
				var nitro := Pickups.make("nitro")
				nitro.position = point
				add_child(nitro)
	clockReady = true
	get_tree().call_group("runTimer", "onClockReady")
	revealRun()

#---------- the start: behind the loading shutter (Transition, docs/UI.md) ----------
#The menu's loading door is still down when the level enters. The run waits paused behind it while
#the world builds (the build waits on process frames, which run while paused, and the TileManager
#keeps streaming), then the door rolls up on the car mid-burnout and the usual 3-2-1 starts the run.

const REVEAL_SETTLE_FRAMES := 12 #at least this many frames of streaming behind the door
const REVEAL_MAX_SECONDS := 3.0   #and at most this long waiting for the nearby chunks

var heldUnderShutter := false

func holdUnderShutter() -> void:
	if not Transition.holdsRunStart(): return
	heldUnderShutter = true
	get_tree().paused = true
	$TileManager.process_mode = Node.PROCESS_MODE_ALWAYS
	Transition.active.progress = maxf(Transition.active.progress, 0.6)
	Transition.active.tree_exiting.connect(releaseShutterHold) #however the door goes, the run must start

func revealRun() -> void:
	if not Transition.busy(): return
	var door = Transition.active
	if not heldUnderShutter: #instant (harnesses): just clear the door
		door.open()
		return
	door.progress = 0.85
	#the chunks around the car stream in behind the door before it opens (at most REVEAL_MAX_SECONDS)
	var tileManager = $TileManager
	var waitStart := Time.get_ticks_msec()
	var frames := 0
	while frames < REVEAL_SETTLE_FRAMES || (Time.get_ticks_msec() - waitStart < REVEAL_MAX_SECONDS * 1000.0 && not (tileManager.loadQueue.is_empty() && tileManager.applyQueue.is_empty())):
		frames += 1
		door.progress = lerpf(0.85, 0.98, clampf((Time.get_ticks_msec() - waitStart) / (REVEAL_MAX_SECONDS * 1000.0), 0.0, 1.0))
		await get_tree().process_frame
		if not is_instance_valid(door): break
	if not is_inside_tree(): return
	if not is_instance_valid(door):
		releaseShutterHold()
		return
	door.progress = 1.0
	await get_tree().create_timer(0.15, true, false, true).timeout
	if not is_instance_valid(door):
		releaseShutterHold()
		return
	burnout(door.fx)
	door.open(true)
	await door.opened
	releaseShutterHold()

#ends the wait behind the door: streaming back to normal, and the 3-2-1, which unpauses the run on GO.
#Also runs if the door leaves early for any reason, so a run can never stay frozen behind it.
func releaseShutterHold() -> void:
	if not heldUnderShutter || not is_inside_tree(): return
	heldUnderShutter = false
	$TileManager.process_mode = Node.PROCESS_MODE_INHERIT
	if not hasEnded && is_instance_valid(Root.playerRoot): Root.playerRoot.addCountdown()

#the car revving on the spot as the door rises: a rev and a squeal. (It used to throw a cloud of smoke off
#its tail too, which hid the car, and the semi's trailer, as the run was revealed.)
func burnout(_fx: TransitionFx) -> void:
	if not is_instance_valid(Root.playerCar): return
	Transition.sound("rev", -2.0)
	Transition.sound("screech", -8.0)

#Sprint station offset from the car start, in px: `distance` straight ahead (+x), with a y offset of up
#to SPRINT_Y_SPREAD of the distance, never further than SPRINT_MAX_DISTANCE (x the tier's distance for a
#Sprint; without a tier, a Marathon leg). yRoll is -1..1.
static func sprintOffsetPx(distance: float, yRoll: float, sprintTier: int = ModeTiers.NONE) -> Vector2:
	var cap: float = SPRINT_MAX_DISTANCE * ModeTiers.SPRINT_DISTANCE[clampi(sprintTier, ModeTiers.NONE, ModeTiers.HARD)]
	return Vector2(distance, distance * SPRINT_Y_SPREAD * clampf(yRoll, -1.0, 1.0)).limit_length(cap)

#how far a level's Sprint station is: by its region (Territories.sprintDistance), x the tier's
#(ModeTiers.SPRINT_DISTANCE). Without a tier, a Marathon leg.
static func sprintDistance(levelDef: LevelDef, sprintTier: int = ModeTiers.NONE) -> float:
	return Territories.sprintDistance(levelDef.region if levelDef else &"") * ModeTiers.SPRINT_DISTANCE[clampi(sprintTier, ModeTiers.NONE, ModeTiers.HARD)]

#how far apart a Marathon's stations are: shorter than the one-station races' drive, since it has several
static func legDistance(levelDef: LevelDef) -> float:
	return sprintDistance(levelDef) * ModeTiers.MARATHON_LEG

#time allowed per second of reference driving: 1.5 on Easy (250 s) down to 1.1 on Northern Wastes (540 s)
static func sprintSlack(levelSeconds: float) -> float:
	return clampf(1.5 - (levelSeconds - 250.0) / 290.0 * 0.4, 1.1, 1.5)

#The length (px) of the drive to the station just placed: the A* route on the world's coarse map
#(TileManager.lastRouteLength), never less than the straight line
func routeLengthTo(target: Vector2) -> float:
	var straight := startPosition.distance_to(target)
	var tileManager = get_node_or_null("TileManager")
	if tileManager == null || tileManager.lastRouteLength <= 0.0: return straight
	return maxf(tileManager.lastRouteLength, straight)

#the drive the clock allows for, from the coarse route's length (px): ROUTE_FACTOR and STATION_APPROACH_PX
static func driveLengthFor(routePx: float, grammar: StringName) -> float:
	return routePx * ROUTE_FACTOR.get(grammar, ROUTE_FACTOR_DEFAULT) + STATION_APPROACH_PX

## A level's own route factor (features "routeFactor": Orchard Lanes' hedgerow lattice makes the drive a
## staircase the coarse route doesn't see) replaces its grammar's
func driveLength(routePx: float) -> float:
	var own := float(def.features.get("routeFactor", 0.0)) if def else 0.0
	if own > 0.0: return routePx * own + STATION_APPROACH_PX
	return driveLengthFor(routePx, def.grammar if def else &"")

#the Sprint clock: the drive's length (the route on the coarse map) at REFERENCE_SPEED, plus the level's
#slack (LevelDef.sprintSlack when given, else the curve over the level's seconds)
static func sprintSeconds(distancePx: float, levelSeconds: float, slackOverride: float = -1.0) -> float:
	return distancePx / REFERENCE_SPEED * (slackOverride if slackOverride > 0.0 else sprintSlack(levelSeconds))

#how a run ends when a counting-down clock reaches 0 (Root.endCondition): Countdown and Defense are won,
#the races are lost. A wrecked car (exploding, its NOHEALTH ending still pending) has not survived. A car
#that only ran out of fuel has, matching the rolling finish in station.gd.
static func timeUpCondition(gameMode: int, wrecked: bool = false) -> int:
	gameMode = Modes.plays(gameMode)
	if gameMode != Root.gameModes.GOONCRUSHER && gameMode != Root.gameModes.DEFENSE: return Root.endCondition.NOTIME
	return Root.endCondition.NOHEALTH if wrecked else Root.endCondition.SUCCESS

func timeRanOut() -> void:
	var car = Root.playerCar
	var wrecked = is_instance_valid(car) && (car.isWrecked || car.health <= 0)
	var condition = timeUpCondition(SaveManager.playerData.gameMode, wrecked)
	endLevel(condition == Root.endCondition.SUCCESS, condition)

#--- pay ----------------------------------------------------------------------------------------

## Won: reached its goal (a Goonpocalypse that survived its target is won however it ended)
func isWon() -> bool:
	return hasEnded && (endReason == Root.endCondition.SUCCESS || targetReached)

var firstClear := {"coin": 0, "gem": 0} #paid by the results ticket on a tier's first win (ModeTiers.firstClear)

## The win bonus this run pays if it is won: by mode, level and tier (ModeTiers.winBonus)
func winBonus() -> int:
	return ModeTiers.winBonus(runMode, tier, runLevel)

## What the run pays: its coins plus the win bonus when won, times the star multiplier (Root.computePayout).
## The results ticket, the run log and the harnesses all use this.
func runPayout(won: bool) -> int:
	var car = Root.playerCar
	if not is_instance_valid(car): return 0
	var pay := Root.computePayout(car.coin + (winBonus() if won else 0), car.star)
	return roundi(pay * car.traitRig.payoutBonus()) if car.traitRig else pay #Loaded Bed's crates

#--- the run's rank (RunRank) ---------------------------------------------------------------------

## How much of the mode's own goal the run has reached: 1 is the goal. The score or the marks out of the target,
## the cup's seconds, the gates and laps of a course, the stations of a Marathon, the way to the station, else
## the share of the clock survived. Goonpocalypse goes on past 1.
func goalProgress() -> float:
	if Modes.running() == Root.gameModes.GOONPOCALYPSE: return elapsed / maxf(pocalypseTarget(), 1.0)
	if isWon(): return 1.0
	if trial: return clampf(float(trial.score) / maxf(trial.target, 1.0), 0.0, 1.0)
	if bounty: return clampf(float(bounty.caught) / maxf(bounty.total, 1.0), 0.0, 1.0)
	if cup: return clampf(cup.playerSeconds() / maxf(cup.need, 1.0), 0.0, 1.0)
	if course && course.total() > 0:
		return clampf(float(course.lap * course.total() + course.next) / (course.total() * maxi(course.laps, 1)), 0.0, 1.0)
	if runMode == Root.gameModes.DERBY && rivals: return clampf(float(wrecks) / maxf(rivals.field() - 1, 1.0), 0.0, 1.0)
	if runMode == Root.gameModes.PURSUIT: return 0.0 #the runner got away
	if Modes.running() == Root.gameModes.MARATHON: return clampf(float(leg - 1) / maxf(legs(), 1.0), 0.0, 1.0)
	if timeUpCondition(runMode) == Root.endCondition.SUCCESS: return clampf(elapsed / maxf(elapsed + seconds, 1.0), 0.0, 1.0)
	if is_instance_valid(Root.station) && is_instance_valid(Root.playerCar):
		var whole := startPosition.distance_to(Root.station.global_position)
		return clampf(1.0 - Root.playerCar.global_position.distance_to(Root.station.global_position) / maxf(whole, 1.0), 0.0, 1.0)
	return 0.0

## What RunRank grades: the run as it stands (the results ticket and the playtest harness read it once it has ended)
func rankStats() -> Dictionary:
	var car = Root.playerCar
	if not is_instance_valid(car): return {}
	var survival: bool = Modes.running() == Root.gameModes.GOONPOCALYPSE || runMode == Root.gameModes.KEEPCUP || timeUpCondition(runMode) == Root.endCondition.SUCCESS
	return {"won": isWon(), "progress": goalProgress(), "timed": not survival, "time": elapsed,
		"crushed": car.currentGoonsCrushed, "giants": car.giantsCrushed, "combo": car.bestCombo,
		"speed": float(car._highest_measured_speed), "paid": runPayout(isWon()), "fuel": car.fuel}

## The par key of this run (RunRank.parKey): its level, mode and tier
func parKey() -> String:
	return RunRank.parKey(str(def.id) if def else "", Modes.idOf(runMode), tier)

## The run's score and rank (RunRank.grade) against the par for its level, mode and tier
func runRank() -> Dictionary:
	return RunRank.grade(rankStats(), RunRank.parFor(str(def.id) if def else "", Modes.idOf(runMode), tier), tier)

#--- Goonpocalypse ------------------------------------------------------------------------------

func pocalypseTarget() -> float:
	return ModeTiers.pocalypseSeconds(levelSeconds, tier)

#crushes, plus 5 per giant, plus a point for every 2 s survived
static func pocalypseScore(crushes: int, giants: int, survived: float) -> int:
	return crushes + 5 * giants + int(survived / 2.0)

func runScore() -> int:
	var car = Root.playerCar
	return pocalypseScore(car.currentGoonsCrushed, car.giantsCrushed, elapsed) if is_instance_valid(car) else 0

#Timer.gd calls this every frame the clock runs
func onClockTick() -> void:
	if targetReached || Modes.running() != Root.gameModes.GOONPOCALYPSE || hasEnded: return
	if seconds >= pocalypseTarget():
		targetReached = true #the mode is beaten however the run ends (endLevel)
		if is_instance_valid(Root.spawnManager): Root.spawnManager.overtime() #from here it only gets worse
		var host = TapeBanner.layer()
		if host: Stamp.slam(host, "TARGET SMASHED", Vector2(get_viewport().get_visible_rect().size.x * 0.5, 320.0), HudTheme.GOLD, 72, 1.6)

#--- the briefing -------------------------------------------------------------------------------

#At GO (countdown.gd, run start only) a tape banner says the mode's goal; for a mode's first BRIEF_RUNS runs a
#second one says how (meta.hints.briefings counts them per mode)
const BRIEF_RUNS := 3

## [goal, how] for the run's mode, banner-ready (upper case)
func briefing() -> Array[String]:
	match SaveManager.playerData.gameMode:
		Root.gameModes.FLATOUT: return ["FLAT OUT TO THE STATION", "GRAB THE NITRO. BE SLOW ENOUGH TO STOP AT THE LINE"]
		Root.gameModes.HOTLAP: return ["%d LAPS. YOUR BEST ONE COUNTS" % ModeTiers.HOTLAP_LAPS, "BEAT %s" % Course.clock(lapTarget)]
		Root.gameModes.CIRCUIT: return ["%d LAPS" % ModeTiers.CIRCUIT_LAPS, "FIRST" if tier >= ModeTiers.HARD else "FINISH IN THE TOP %d" % ModeTiers.CUP_PLACE[tier]]
		Root.gameModes.KNOCKOUT: return ["LAST PLACE IS OUT EVERY LAP", "BE THE ONE LEFT"]
		Root.gameModes.DERBY: return ["WRECK THEM ALL", "HIT THEIR SIDES AND TAILS, NOT THE NOSE"]
		Root.gameModes.PURSUIT: return ["WRECK THE RUNNER", "RAM THEM BEFORE THEY REACH THE STATION"]
		Root.gameModes.KEEPCUP: return ["HOLD THE CUP FOR %d SECONDS" % ModeTiers.CUP_HOLD[tier], "GET CLOSE TO WHOEVER HAS IT TO TAKE IT"]
		Root.gameModes.CANNONBALL: return ["FIRST TO THE STATION" if tier >= ModeTiers.HARD else "TOP %d TO THE STATION" % ModeTiers.CUP_PLACE[tier], "ANY ROUTE. RAM WHO YOU LIKE"]
		Root.gameModes.SMASH: return ["SMASH %d THINGS" % ModeTiers.SMASH_QUOTA[tier], "FENCES, CRATES AND BALES BREAK AT SPEED. ROCKS DON'T"]
		Root.gameModes.DRIFT: return ["SCORE %d DRIFTING" % ModeTiers.DRIFT_TARGET[tier], "HOLD THE HANDBRAKE THROUGH A TURN. LONGER AND FASTER SCORES MORE"]
		Root.gameModes.CONES: return ["THROUGH EVERY GATE", "A KNOCKED CONE COSTS A SECOND"]
		Root.gameModes.RALLY: return ["BEAT THE CLOCK TO THE FINISH", "PASS EVERY CHECKPOINT ON THE WAY"]
		Root.gameModes.BOUNTY: return ["CRUSH %d MARKS" % ModeTiers.BOUNTY_MARKS[tier], "FOLLOW THE RED ARROW TO EACH ONE"]
		Root.gameModes.BLACKOUT: return ["SURVIVE THE NIGHT", "ONLY YOUR HEADLIGHTS SHOW THE GOONS"]
		Root.gameModes.SPRINT: return ["REACH THE STATION", "FOLLOW THE BLUE ARROW BEFORE TIME RUNS OUT"]
		Root.gameModes.MARATHON: return ["REACH %d STATIONS" % legs(), "EACH STATION REFUELS YOU AND ADDS TIME"]
		Root.gameModes.DEFENSE: return ["HOLD THE BASE", "CRUSH GOONS BEFORE THEY REACH THE PUMPS"]
		Root.gameModes.GOONPOCALYPSE:
			var target := int(pocalypseTarget())
			return ["SURVIVE %d:%02d FOR THE STAR" % [target / 60, target % 60], "THEN CHASE YOUR BEST SCORE"]
	return ["SURVIVE THE CLOCK", "CRUSH GOONS FOR COINS AND STARS"]

func postBriefing() -> void:
	var lines := briefing()
	TapeBanner.post(lines[0], 1.4)
	var counts: Dictionary = SaveManager.playerData.meta.get_or_add("hints", {}).get_or_add("briefings", {})
	var key := str(SaveManager.playerData.gameMode)
	if counts.get(key, 0) >= BRIEF_RUNS: return
	counts[key] = counts.get(key, 0) + 1
	SaveManager.save_character_data()
	TapeBanner.post(lines[1], 1.8)

#--- Marathon -----------------------------------------------------------------------------------

#the active station's driveway calls this in Marathon
func stationReached(station: Node2D) -> void:
	if leg >= legs():
		endLevel(true, Root.endCondition.SUCCESS)
		return
	leg += 1
	TapeBanner.post("STATION  -  LEG %d OF %d" % [leg, legs()], 1.0)
	var car = Root.playerCar
	car.fuel = 100.0 #a car coasting in on an empty tank is saved: outOfFuel checks the tank again
	car.health = minf(100.0, car.health + MARATHON_HEAL)
	car.repairAll()
	car.updateDamageLook()
	car.resetGasWarning()
	car.resetHealthWarning()
	var from = station.global_position
	var tileManager = $TileManager
	var turn := (WorldGen.hashf(tileManager.worldSeed, WorldGen.TAG_LEG, leg, 0) * 2.0 - 1.0) * MARATHON_TURN
	var next = tileManager.placeNextStation(from, legHeadingFrom(from, legHeading, turn, legDistance(def)), legDistance(def))
	legHeading = (next.global_position - from).angle()
	seconds += sprintSeconds(driveLength(maxf(tileManager.lastRouteLength, from.distance_to(next.global_position))), levelSeconds, slack())
	call_deferred("openPitShop")

#the heading of a leg `distance` px long from `from`: the last heading plus `turn`, unless that leaves the
#map; then toward the map's center (plus the turn if that fits), which always does
static func legHeadingFrom(from: Vector2, lastHeading: float, turn: float, distance: float) -> float:
	if legFits(from, lastHeading + turn, distance): return lastHeading + turn
	var home := (-from).angle()
	return home + turn if legFits(from, home + turn, distance) else home

static func legFits(from: Vector2, heading: float, distance: float) -> bool:
	var reach: Vector2 = Vector2(WorldGen.CHUNK_LIMIT * WorldGen.CHUNK_PX) - Vector2.ONE * distance * MARATHON_EDGE_MARGIN
	var to := from + Vector2.from_angle(heading) * distance
	return absf(to.x) <= reach.x && absf(to.y) <= reach.y

#Marathon stations: the pit shop sells pickups for run coins
func openPitShop() -> void:
	if hasEnded || get_tree().paused: return
	PitShop.open()

#--- Defense ------------------------------------------------------------------------------------

#the car starts outside the lot, facing away from it; spawners ring the station
func setupDefense() -> void:
	var station = Root.station
	var car = Root.playerCar
	car.global_position = station.global_position + DEFENSE_START
	car.rotation = 0.0
	car.velocity = Vector2.ZERO
	startPosition = car.global_position
	if car.has_node("Camera2D"): car.get_node("Camera2D").reset_smoothing()
	var offsets: Array = []
	var map = Root.worldMap
	if map != null && not map.lanes.is_empty():
		for mouth in map.lanes: offsets.push_back(mouth - station.global_position)
	else:
		for i in DEFENSE_SPAWNERS: offsets.push_back(Vector2.from_angle(i * TAU / DEFENSE_SPAWNERS) * DEFENSE_RING)
	for offset in offsets:
		var spawner = newSpawner(offset, station)
		#SpawnManager lists the "spawner" group once, a frame after it starts; these may come later
		if is_instance_valid(Root.spawnManager) && Root.spawnManager.spawners is Array && not spawner in Root.spawnManager.spawners:
			Root.spawnManager.spawners.push_back(spawner)
	station.startBarrier()

#--- spawners and the day -----------------------------------------------------------------------

func createCountdownSpawners():
	newSpawner( Vector2i(4000,2000)) 
	newSpawner( Vector2i(4000,-2000)) 
	
	newSpawner( Vector2i(4000,250) )
	newSpawner( Vector2i(4000,-250))
	newSpawner( Vector2i(-3500,0)) 

func createSprintSpawners():
	newSpawner( Vector2i(4000,800)) 
	newSpawner( Vector2i(4000,-800)) 

	newSpawner( Vector2i(4000,250) )
	newSpawner( Vector2i(4000,-250)) 
	newSpawner( Vector2i(-3500,0)) 
		

func setNighttime(isNighttime: bool):

	if isNighttime:
		nightsSeen += 1
		TapeBanner.post("NIGHT FALLS", 1.0) #night is gameplay: only the headlights show the world
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(.0,.0,.0,1.0) , 5)
		fadeBeacons(1.0)
			#if canvasmodulate this is set to .05 powerups and giants glow at night.  If set to 0 they don't
		await get_tree().create_timer(2).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(1).timeout
		Transition.sound("clank", -8.0, 0.7) #the headlights clunk on
		Root.playerCar.turnOnHeadlights(true)
	else: 
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(1.0,1.0,1.0,1.0) , 5)
		fadeBeacons(0.0)
		await get_tree().create_timer(1).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		#$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(2).timeout
		Root.playerCar.turnOnHeadlights(false)
	
#landmark beacons glow at night and dim by day, with the CanvasModulate
func fadeBeacons(night: float) -> void:
	var from = BEACON_MATERIAL.get_shader_parameter("night")
	if not from is float: from = 1.0 - night #never set (null)
	get_tree().create_tween().tween_method(func(v): BEACON_MATERIAL.set_shader_parameter("night", v), from, night, 5.0)

#spawners are children of the car by default, so their offsets rotate with it
func newSpawner( spawnerPosition: Vector2, parent: Node = null ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	(parent if parent != null else Root.playerCar).add_child(newSpawner)
	return newSpawner

	


	
#Every ending (car NOHEALTH/NOGAS, station SUCCESS, clock SUCCESS/NOTIME, abandon) comes here.
#Only the first counts: later calls, such as a car's pending NOGAS timer firing after the summary
#paused the tree (SceneTreeTimers run while paused), return at once.
#`then` skips the ticket and goes straight on once the run is paid ("retry": the pause menu's Restart).
func endLevel(levelCompleted: bool, reason, then := ""):  #reason takes Root.endCondition
	if hasEnded: return
	if targetReached: levelCompleted = true #Goonpocalypse ends in a wreck, but surviving the target beat it
	hasEnded = true
	endReason = reason
	if course || trial || bounty: #the mode's own count, for the harnesses' logs
		print("RUN_GOAL mode=%s won=%s t=%.1f course=%s trial=%s bounty=%s" % [Modes.idOf(runMode), levelCompleted, elapsed,
			"%d/%d cones=%d" % [course.next, course.total(), course.conesHit] if course else "-",
			"%d/%d" % [trial.score, trial.target] if trial else "-", "%d/%d" % [bounty.caught, bounty.total] if bounty else "-"])
	if rivals: print("RUN_RACE mode=%s won=%s t=%.1f place=%d field=%d finished=%s rivals_left=%d wrecks=%d cup=%s" % [Modes.idOf(runMode), levelCompleted, elapsed, finishPlace, rivals.field(), rivals.finishOrder, rivals.cars.size(), wrecks,
		"%.0f/%.0f rival %.0f" % [cup.playerSeconds(), cup.need, cup.rivalBest()] if cup else "-"])
	if is_instance_valid(Root.playerCar): Root.playerCar.isDestroyed = true
	if coop: coop.close() #the results have the whole screen
	var gameSummary = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	gameSummary.reason = reason
	gameSummary.autoAction = then
	if levelCompleted: gameSummary.levelCompleted = true #no win jingle: the radio plays on
	add_child( gameSummary )
	get_tree().paused = true


#a pooled explosion at a world position, with its flash, debris, smoke, scorch mark, boom and shake (Fx.blast)
func explode(worldPosition: Vector2, size: int = Fx.Size.BLAST) -> void:
	explosions.explode(worldPosition, Fx.BLAST[size].core)
	fx.blast(worldPosition, size)
