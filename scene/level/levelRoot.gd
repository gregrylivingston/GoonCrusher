class_name Level extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var explosionScene = preload("res://scene/fx/explosion.tscn") #loaded with the level, not with every car
var explosions: ExplosionPool
var playerCar: OverheadCarBody2D
var playerController
## The level's LevelDef (Levels, res://world/levels/<id>.tres). Its clock, spawn tuning and start position
## are copied in when the level enters the tree (applyDef). Old scenes without one keep their own values.
@export var def: LevelDef
var defApplied := false
@export var seconds = 600 #the run clock. Every mode counts it down except Goonpocalypse, which counts up from 0
var levelSeconds: float #the level's authored seconds, kept after the mode replaces `seconds`
var elapsed := 0.0 #run-clock seconds that have passed, whichever way the clock counts (Timer.gd)

var isDaytime: bool = true
var hasEnded := false #endLevel runs once per run, whichever ending gets there first
var endReason: int = -1 #Root.endCondition once the run has ended
var startPosition: Vector2 #where the car starts; objectives are placed relative to it
var clockReady := false #true once the clock holds its final starting value (Sprint sets it from the station distance)

#Sprint: the station is placed by distance and the clock is derived from the real distance.
const SPRINT_DRIVE_FRACTION = 0.25 #share of the level's authored seconds spent driving at REFERENCE_SPEED
#px/s; a fixed baseline, not the selected car, so fast cars feel fast. The stock sedan tops out at about
#744 on grass, 615 on snow and 499 on sand and mud, so 450 leaves room for rocks, goons and turns.
const REFERENCE_SPEED = 450.0
#the station is never further than this (px): about 0.75 of the stock sedan's tank (87 s at full throttle)
#at its sand and mud top speed, so a run is possible without fuel pickups
const SPRINT_MAX_DISTANCE = 32000.0
const SPRINT_Y_SPREAD = 0.25 #the station's y offset is up to this share of the distance, either way

#Marathon: a relay of Sprint-length legs. Each station but the last adds that leg's clock, refuels,
#patches the car up and opens a free slot machine; the last one wins.
const MARATHON_LEGS = 5
const MARATHON_TURN = PI / 3 #each leg heads off within this of the last leg's heading
const MARATHON_HEAL = 35.0   #health restored at each station
var leg := 1
var legHeading := 0.0

#Goonpocalypse: endless. Surviving POCALYPSE_TARGET x the level's seconds beats the mode (its star);
#after that it is a chase for score and time (SaveManager.recordGoonpocalypse).
const POCALYPSE_TARGET = 2.0
var targetReached := false

#Defense: hold the station until the clock runs out. Goons spawn at the mouths of the straight lanes the
#world generator cleared out from it (WorldGen.placeDefense) and march on its walls (Walker.siege); the
#station's barrier health is in station.gd. Without lanes (no world map) they ring it instead.
const DEFENSE_RING = 4000.0
const DEFENSE_SPAWNERS = 4
const DEFENSE_START = Vector2(1250, 290) #outside the lot's gap (its east side), from the station's origin

#Before any child is ready, so SpawnManager._ready (Goonpocalypse escalation) builds on the def's numbers,
#and before the bench's node_added overrides, which come after this.
func _enter_tree():
	applyDef()

func applyDef() -> void:
	if defApplied || def == null: return
	defApplied = true
	seconds = def.seconds
	var spawnManager = get_node_or_null("SpawnManager")
	if spawnManager:
		spawnManager.spawnTimer = def.spawnTimer
		spawnManager.giantOdds = def.giantOdds
		spawnManager.escalationSpeed = def.escalationSpeed
	var tileManager = get_node_or_null("TileManager")
	if tileManager && not def.objectTiles.is_empty(): #interim: the old object pools, read in TileManager._ready
		tileManager.requestedObjectTiles = def.objectTiles.duplicate()

#Sprint and Marathon slack: the def's, else the old curve over the level's seconds
func slack() -> float:
	return def.sprintSlack if def else sprintSlack(levelSeconds)

func _ready():
	levelSeconds = seconds
	explosions = ExplosionPool.new(explosionScene)
	add_child(explosions)

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
	
	match SaveManager.playerData.gameMode:
		Root.gameModes.GOONCRUSHER:createCountdownSpawners()
		Root.gameModes.GOONPOCALYPSE:createCountdownSpawners()
		Root.gameModes.MARATHON:createSprintSpawners()
		Root.gameModes.SPRINT:createSprintSpawners()
		#DEFENSE: its spawners ring the station, which exists only once the world is ready

	if SaveManager.playerData.gameMode == Root.gameModes.GOONPOCALYPSE: seconds = 0

	#the TileManager waits at least one frame before placing stations, so this is never too late
	var tileManager = $TileManager
	if tileManager.isWorldReady: onWorldReady()
	else: tileManager.world_ready.connect(onWorldReady)

#the map is built and every station is placed and in the tree
func onWorldReady() -> void:
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			if is_instance_valid(Root.station):
				seconds = sprintSeconds(routeLengthTo(Root.station.global_position), levelSeconds, slack())
				legHeading = (Root.station.global_position - startPosition).angle()
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station): setupDefense()
	clockReady = true
	get_tree().call_group("runTimer", "onClockReady")

#Sprint station offset from the car start, in px: straight ahead (+x), with a y offset of up
#to SPRINT_Y_SPREAD of the distance. yRoll is -1..1.
static func sprintOffsetPx(levelSeconds: float, yRoll: float) -> Vector2:
	var distance = levelSeconds * SPRINT_DRIVE_FRACTION * REFERENCE_SPEED
	return Vector2(distance, distance * SPRINT_Y_SPREAD * clampf(yRoll, -1.0, 1.0)).limit_length(SPRINT_MAX_DISTANCE)

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

#the Sprint clock: the drive's length (the route on the coarse map) at REFERENCE_SPEED, plus the level's
#slack (LevelDef.sprintSlack when given, else the curve over the level's seconds)
static func sprintSeconds(distancePx: float, levelSeconds: float, slackOverride: float = -1.0) -> float:
	return distancePx / REFERENCE_SPEED * (slackOverride if slackOverride > 0.0 else sprintSlack(levelSeconds))

#how a run ends when a counting-down clock reaches 0 (Root.endCondition): Countdown and Defense are won,
#the races are lost. A wrecked car (exploding, its NOHEALTH ending still pending) has not survived. A car
#that only ran out of fuel has, matching the rolling finish in station.gd.
static func timeUpCondition(gameMode: int, wrecked: bool = false) -> int:
	if gameMode != Root.gameModes.GOONCRUSHER && gameMode != Root.gameModes.DEFENSE: return Root.endCondition.NOTIME
	return Root.endCondition.NOHEALTH if wrecked else Root.endCondition.SUCCESS

func timeRanOut() -> void:
	var car = Root.playerCar
	var wrecked = is_instance_valid(car) && (car.isWrecked || car.health <= 0)
	var condition = timeUpCondition(SaveManager.playerData.gameMode, wrecked)
	endLevel(condition == Root.endCondition.SUCCESS, condition)

#--- Goonpocalypse ------------------------------------------------------------------------------

func pocalypseTarget() -> float:
	return levelSeconds * POCALYPSE_TARGET

#crushes, plus 5 per giant, plus a point for every 2 s survived
static func pocalypseScore(crushes: int, giants: int, survived: float) -> int:
	return crushes + 5 * giants + int(survived / 2.0)

func runScore() -> int:
	var car = Root.playerCar
	return pocalypseScore(car.currentGoonsCrushed, car.giantsCrushed, elapsed) if is_instance_valid(car) else 0

#Timer.gd calls this every frame the clock runs
func onClockTick() -> void:
	if targetReached || SaveManager.playerData.gameMode != Root.gameModes.GOONPOCALYPSE || hasEnded: return
	if seconds >= pocalypseTarget():
		targetReached = true #the mode is beaten however the run ends (endLevel)
		$AudioStreamPlayer.stream = load("res://sound/fx/slotmachine/winner_3.mp3")
		$AudioStreamPlayer.play()

#--- Marathon -----------------------------------------------------------------------------------

#the active station's driveway calls this in Marathon
func stationReached(station: Node2D) -> void:
	if leg >= MARATHON_LEGS:
		endLevel(true, Root.endCondition.SUCCESS)
		return
	leg += 1
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
	var next = tileManager.placeNextStation(from, legHeading + turn, levelSeconds)
	legHeading = (next.global_position - from).angle()
	seconds += sprintSeconds(maxf(tileManager.lastRouteLength, from.distance_to(next.global_position)), levelSeconds, slack())
	call_deferred("openPitShop")

#Marathon stations: the pit shop sells pickups for run coins, then the free slot machine opens
func openPitShop() -> void:
	if hasEnded || get_tree().paused: return
	PitShop.open()

func openFreeSlotMachine() -> void:
	if hasEnded || get_tree().paused: return
	get_tree().paused = true
	add_child(preload("res://scene/player/slots/slotMachine.tscn").instantiate())

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
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(.0,.0,.0,1.0) , 5)
			#if canvasmodulate this is set to .05 powerups and giants glow at night.  If set to 0 they don't
		await get_tree().create_timer(2).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(1).timeout
		Root.playerCar.turnOnHeadlights(true)
	else: 
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(1.0,1.0,1.0,1.0) , 5)
		await get_tree().create_timer(1).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		#$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(2).timeout
		Root.playerCar.turnOnHeadlights(false)
	
#spawners are children of the car by default, so their offsets rotate with it
func newSpawner( spawnerPosition: Vector2, parent: Node = null ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	(parent if parent != null else Root.playerCar).add_child(newSpawner)
	return newSpawner

	


	
#Every ending (car NOHEALTH/NOGAS, station SUCCESS, clock SUCCESS/NOTIME, abandon) comes here.
#Only the first counts: later calls, such as a car's pending NOGAS timer firing after the summary
#paused the tree (SceneTreeTimers run while paused), return at once.
func endLevel(levelCompleted: bool, reason):  #reason takes Root.endCondition
	if hasEnded: return
	if targetReached: levelCompleted = true #Goonpocalypse ends in a wreck, but surviving the target beat it
	hasEnded = true
	endReason = reason
	if is_instance_valid(Root.playerCar): Root.playerCar.isDestroyed = true
	var gameSummary = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	gameSummary.reason = reason 
	if levelCompleted:
		$AudioStreamPlayer.stream = load("res://sound/fx/slotmachine/winner_3.mp3")
		$AudioStreamPlayer.play()
		gameSummary.levelCompleted = true
	add_child( gameSummary )
	get_tree().paused = true


#a pooled explosion at a world position
func explode(worldPosition: Vector2) -> void:
	explosions.explode(worldPosition)

func getTileByCoordinates(coord: Vector2i):
	return $TileManager.getTile(coord)
