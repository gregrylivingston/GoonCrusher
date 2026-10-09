extends Node

#Automated playtesting with the AI driver (docs/AI_DRIVER.md). Inert unless the user args include
#--playtest. Runs are real: no god mode, the real clock, the real endings. Every level x mode x car
#x AI profile combination is played --runs times, with map seeds --seed, --seed+1, ...; each run
#adds a row to user://playtest/results<tag>.csv and prints PLAYTEST_RESULT, and the end prints
#PLAYTEST_SUMMARY per combination and PLAYTEST_RANKING per mode (profiles by average score, see
#runScore). Fastest: headless, with frames decoupled from real time. scripts/ai/tournament.py runs
#several profiles in parallel processes and ranks them.
#  Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=sprint --runs=5
#Options: --level=prairie[,...] (a Levels id, its 0-based index or an old scene name)  --mode=countdown|sprint|goonpocalypse|marathon|defense[,...]
#  --car=sedan[,...]  --profiles=cautious[,default,...] (AIProfiles specs; cautious, the best all-round in the tournaments, by default)  --runs=N  --seed=N  --upgrades=N|save (every stat at level N; default 0, the
#  stock car; "save" keeps the save's)  --sight=human|full  --max-seconds=N (level time before a run
#  is cut short, default 900)  --ai-debug (draw the AI's plan; not headless)  --trace (state once a
#  second)  --tag=name
#Progress goes to a scratch save, as with the benchmark, so the real save is never touched.
#--career instead plays a whole career through the real menus as one of the Personas (CareerPilot,
#scripts/debug/career.gd); its runs are recorded here the same way.

const SCRATCH_SAVE = "user://playtest/playtest_save%s.tres" #per --tag, so parallel processes don't share one
const MODE_ALIASES = {"countdown":"GOONCRUSHER"}
#one CSV row per run, in this order (damage is health lost; see _physics_process for the split)
const COLUMNS = ["run", "level", "mode", "car", "profile", "seed", "upgrades", "sight", "score", "reason", "won", "level_time",
	"clock", "time_left", "station_px", "station_left_px", "route_reached", "legs", "crushed", "coin", "star", "payout", "gem",
	"slot_machines", "fuel_pickups", "health_pickups", "purses", "coins_picked", "gems_picked", "stat_pickups",
	"damage_rocks", "damage_goon_contact", "damage_goon_attacks", "crush_misses", "min_fuel", "min_health",
	"end_fuel", "end_health", "distance_px", "avg_speed", "top_speed", "eco_seconds", "stuck", "escapes", "ai_ms", "goals",
	"pk_supply", "pk_tune", "pk_boost", "pk_gadget", "pk_loot", "pk_casino", "pk_skill", "pk_mode", "pk_move", "persona", "session",
	"tier", "win_bonus", "first_clear", "first_clear_gem", "damage_water"]

var options := {}
var jobs: Array = []
var jobIndex := -1
var results: Array = []
var car: OverheadCarBody2D
var driver: AIDriver
var row := {}
var recorded := false
var levelTime := 0.0
var maxSeconds := 900.0
var prevHealth := 100.0
var prevWallLost := 0.0
var prevWaterLost := 0.0
var lastPosition := Vector2.ZERO
var clockSeen := false
var slotPressTimer := 0.0
var lastStuck := 0
var speedBefore := 0.0 #the car's speed going into its last tick
var career: CareerPilot #--career: the persona playing through the menus starts the runs

func _ready():
	options = parseArgs()
	if options.has("play-start") && not options.has("career") && not options.has("playtest"):
		startHumanSave()
		queue_free() #a person plays: no harness, transitions on
		return
	if not options.has("playtest") && not options.has("career"):
		queue_free()
		return
	if options.has("world-preview"): #print generated worlds and quit (scripts/debug/world_preview.gd)
		WorldPreview.run(options)
		get_tree().quit()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.on_menu_ready() #runs leave the menu before main2 reports it, which would count as a crashed boot
	Settings.set_value("display/pause_unfocused", false, false)
	DirAccess.make_dir_recursive_absolute("user://playtest")
	maxSeconds = float(options.get("max-seconds", 900.0))
	#--unlocks=all|save: every pickup open (the default, so tuning runs compare with older ones) or what the
	#save has opened (the default for careers and --play-start, which play the progression)
	var progression: bool = options.has("career") || options.has("play-start")
	Unlocks.allOpen = str(options.get("unlocks", "save" if progression else "all")) == "all"
	if options.has("career"):
		career = CareerPilot.new()
		career.playtest = self
		var problem := career.setup(options) #writes the starting save before the menu loads it
		if problem != "": return fail(problem)
		add_child(career)
		get_tree().node_added.connect(onNodeAdded)
		return
	SaveManager.save_path = SCRATCH_SAVE % str(options.get("tag", ""))
	var firstSeed = int(options.get("seed", 1))
	for levelArg in listArg("level", "prairie"):
		var level := String(Levels.resolve(levelArg)) #an id, an index in Levels.ORDER or an old scene name
		if level == "": return fail("Unknown level " + levelArg)
		for modeName in listArg("mode", "countdown"):
			var key = MODE_ALIASES.get(modeName.to_lower(), modeName.to_upper())
			if not Root.gameModes.has(key): return fail("Unknown mode " + modeName)
			for carName in listArg("car", "sedan"):
				if carIndex(carName) < 0: return fail("Unknown car " + carName)
				for profile in listArg("profiles", AIProfiles.BEST):
					if not AIProfiles.PROFILES.has(profile.split("+")[0]): return fail("Unknown AI profile " + profile)
					for tierName in listArg("tier", "easy"): #ModeTiers: easy, medium, hard
						var tier := ModeTiers.NAMES.map(func(n): return n.to_lower()).find(tierName.to_lower())
						if tier < ModeTiers.EASY: return fail("Unknown tier " + tierName)
						for i in int(options.get("runs", 1)):
							jobs.push_back({"level":level, "mode":key, "tier":tier, "car":carName, "profile":profile, "seed":firstSeed + i})
	get_tree().node_added.connect(onNodeAdded)
	await get_tree().create_timer(1.0).timeout
	startNext()

#--play-start=<tier> (CareerStart.TIERS): a person plays from that point in progress on a scratch save,
#user://playtest/human_<tier>_save.tres, so late levels can be checked by hand without touching the real
#save. Later launches with the same tier carry on with it; --fresh rebuilds it. --coins= --gems= --cars=
#--upgrades= --levels= override the tier as for careers. Runs still log to runlog.csv as driver "player".
func startHumanSave() -> void:
	var overrides := {}
	for key in ["coins", "gems", "cars", "upgrades", "levels"]:
		if options.has(key): overrides[key] = int(options[key])
	var result := CareerStart.useScratchSave(str(options["play-start"]), options.has("fresh"), overrides) #the console's `start` does the same
	if result.begins_with("Error"): push_error("PLAYTEST " + result)
	else: print("PLAYTEST_HUMAN " + result)

static func parseArgs() -> Dictionary:
	var result = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") && arg.contains("="):
			var parts = arg.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
		elif arg.begins_with("--"):
			result[arg.substr(2)] = true
	return result

func listArg(key: String, fallback: String) -> PackedStringArray:
	return str(options.get(key, fallback)).split(",", false)

func fail(message: String) -> void:
	push_error("PLAYTEST " + message)
	get_tree().quit(1)

func carIndex(carName: String) -> int:
	var cars = SaveManager.playerData.cars
	for i in cars.size():
		if cars[i].name == carName: return i
	return -1

func startNext() -> void:
	jobIndex += 1
	if jobIndex >= jobs.size():
		finish()
		return
	var job = jobs[jobIndex]
	var data = SaveManager.playerData
	data.selectedCar = carIndex(job.car)
	data.gameMode = Root.gameModes[job.mode]
	data.gameTier = job.get("tier", ModeTiers.EASY)
	data.selectedLevel = Levels.indexOf(job.level) #Region reads the level's faction band and roster from it; gameSummary names and records it
	var upgrades = str(options.get("upgrades", "0"))
	if upgrades != "save":
		var levels = {}
		if int(upgrades) > 0:
			for stat in [Root.upgrade.ENGINE, Root.upgrade.STEERING, Root.upgrade.TRACTION, Root.upgrade.ARMOR,
					Root.upgrade.HEADLIGHTS, Root.upgrade.OIL, Root.upgrade.CLOVER, Root.upgrade.LUCK]:
				levels[stat] = int(upgrades)
		data.cars[data.selectedCar].upgrades = levels
	Root.selectedCar = data.cars[data.selectedCar]
	seed(job.seed)
	beginRow(job, upgrades)
	print("PLAYTEST_RUN %d/%d %s %s %s %s seed=%d" % [jobIndex + 1, jobs.size(), job.level, job.mode.to_lower(), job.car, job.profile, job.seed])
	Region.resetRegions()
	Root.isRunActive = false
	get_tree().paused = false
	get_tree().change_scene_to_node(RunView.wrap(load(Levels.scenePath(job.level)).instantiate()))

#the run's state and its row, before the level loads
func beginRow(job: Dictionary, upgrades: String) -> void:
	car = null
	driver = null
	recorded = false
	clockSeen = false
	waterDeath = {}
	lastStuck = 0
	levelTime = 0.0
	row = {"run":jobIndex + 1, "level":job.level, "mode":job.mode.to_lower(), "car":job.car, "profile":job.profile, "seed":job.seed,
		"upgrades":upgrades, "sight":str(options.get("sight", "human")),
		"fuel_pickups":0, "health_pickups":0, "purses":0, "coins_picked":0, "gems_picked":0, "stat_pickups":0,
		"crush_misses":0, "damage_rocks":0.0, "damage_goon_contact":0.0, "damage_goon_attacks":0.0, "damage_water":0.0, "min_fuel":100.0, "min_health":100.0, "distance_px":0.0, "timeout":false}

#--career: the menu started a run (the save holds what the persona chose); record it like a job
func beginCareerRun() -> void:
	var data = SaveManager.playerData
	var job = {"level":String(Levels.ORDER[data.selectedLevel]), "mode":str(Root.gameModes.find_key(data.gameMode)),
		"car":data.cars[data.selectedCar].name, "profile":career.persona.profile, "seed":int(options.get("seed", 1)) + jobs.size()}
	jobs.push_back(job)
	jobIndex = jobs.size() - 1
	beginRow(job, "save")

func onNodeAdded(node: Node) -> void:
	if career && node is Level: beginCareerRun()
	if jobIndex < 0 || jobIndex >= jobs.size(): return
	if node is Level: seed(jobs[jobIndex].seed) #again, as late as possible: the menu frames between use the RNG too
	elif node is TileManager: node.worldSeed = jobs[jobIndex].seed
	elif node is OverheadCarBody2D && node.isPlayer: node.ready.connect(onCarReady.bind(node), CONNECT_ONE_SHOT)

func onCarReady(newCar: OverheadCarBody2D) -> void:
	car = newCar
	driver = AIDriver.attach(car, {"sight":row.sight, "debug":options.has("ai-debug"), "profile":row.profile})
	car.rewarded.connect(onRewarded)
	prevHealth = car.health
	prevWallLost = 0.0
	prevWaterLost = 0.0
	lastPosition = car.global_position

func onRewarded(powerup: String, quantity) -> void:
	match powerup:
		"fuel": row.fuel_pickups += 1
		"health": row.health_pickups += 1
		"gem": row.gems_picked += 1
		"coin":
			if quantity >= AIDriver.PURSE_QUANTITY: row.purses += 1
			else: row.coins_picked += 1
		"currentGoonsCrushed": pass
		_: row.stat_pickups += 1

func _physics_process(delta):
	if not is_instance_valid(car) || not is_instance_valid(Root.levelRoot): return
	if Root.levelRoot.hasEnded:
		if Input.is_action_pressed("Accelerate"): Input.action_release("Accelerate")
		if not recorded: recordRun()
		return
	if get_tree().paused:
		if not career: tapSlotMachine(delta) #a persona answers pausing screens itself
		return
	pausedEmptySince = -1 #a softlock is one unbroken pause: an earlier countdown's doesn't count towards it
	if Root.levelRoot.clockReady && not clockSeen:
		clockSeen = true
		row.clock = snappedf(Root.levelRoot.seconds, 0.1)
		row.station_px = int(Root.levelRoot.startPosition.distance_to(Root.station.global_position)) if is_instance_valid(Root.station) else 0
		if options.has("trace"): printMap()
	if not clockSeen: return #the world is still being built: the run hasn't started
	levelTime += delta
	if car.isWrecked && waterDeath.is_empty() && World.lethalAt(car.global_position): waterDeath = waterSnapshot()
	#this runs before the car's tick, so health and collisions are both from the tick before
	var drop = prevHealth - car.health
	#walls: exactly what the car's wall hits and scrapes took (a car pinned to a wall by goons used to have their
	#attacks counted as wall damage); the rest is goons
	var wallDrop = car.wallHealthLost - prevWallLost
	prevWallLost = car.wallHealthLost
	if wallDrop > 0.0:
		row.damage_rocks += wallDrop
		drop -= wallDrop
	#water: what wading and deep water took (OverheadCarBody2D.soak)
	var waterDrop = car.waterHealthLost - prevWaterLost
	prevWaterLost = car.waterHealthLost
	if waterDrop > 0.0:
		row.damage_water += waterDrop
		drop -= waterDrop
		if options.has("trace") && wallDrop > 1.0: print("PLAYTEST_HIT t=%.1f v=%d drop=%.1f plan=%s predicted_hit=%s goal=%s with=%s" % [levelTime, car.velocity.length(), wallDrop, str(driver.plan), str(driver.planHit), driver.goal.get("kind", "-"), wallName()])
	if drop > 0.001:
		if touchingGoon(): row.damage_goon_contact += drop #the car ran into it (crushes cost health too)
		else: row.damage_goon_attacks += drop #a goon lunged into the car's body (or a blast, fire, spikes)
	prevHealth = car.health
	countMissedCrushes()
	row.min_fuel = minf(row.min_fuel, car.fuel)
	row.min_health = minf(row.min_health, car.health)
	row.distance_px += car.global_position.distance_to(lastPosition)
	lastPosition = car.global_position
	if options.has("trace") && Engine.get_physics_frames() % Engine.physics_ticks_per_second == 0: trace()
	if row.mode == "defense" && Engine.get_physics_frames() % (Engine.physics_ticks_per_second * 10) == 0: traceDefense()
	if options.has("trace") && driver.stats.stuck != lastStuck:
		lastStuck = driver.stats.stuck
		var station = Root.station.global_position.distance_to(car.global_position) if is_instance_valid(Root.station) else -1.0
		print("PLAYTEST_STUCK t=%.1f pos=(%d,%d) station=%d goal=%s goons_near=%d touching=%s" % [levelTime, car.global_position.x, car.global_position.y,
			station, driver.goal.get("kind", "-"), driver.nearGoons.size(), wallName() if touchingWall() else ("goon" if touchingGoon() else "-")]
			+ " near=%s water=%s keys=%d accel=%.1f slides=%d ground=%s fwd=%.0f buffs=%s" % [nearStatics(car.global_position, 320.0), str(WorldHooks.nearLethal(car.global_position, 400.0)),
			driver.keys, car._car_input.acceleration, car.get_slide_collision_count(), World.letter(World.terrainAt(car.global_position)), driver.forwardSpeed(), str(car.buffs.keys())]
			+ " overlap=%s" % overlapping())
	if levelTime > maxSeconds:
		row.timeout = true
		Root.levelRoot.endLevel(false, Root.endCondition.ABANDONED)

#--trace: once a second, what the driver is doing
func trace() -> void:
	var goal = driver.goal
	var goalText = "%s%s@%d" % [goal.get("kind", "-"), "(" + goal.type + ")" if goal.has("type") else "", int(car.global_position.distance_to(driver.goalPosition()))] if not goal.is_empty() else "-"
	var aimText = "-"
	if driver.aim != Vector2.INF:
		aimText = "%d@%+.0fdeg" % [car.global_position.distance_to(driver.aim), rad_to_deg(car.global_transform.x.angle_to(driver.aim - car.global_position))]
	print("PLAYTEST_TRACE t=%.0f pos=(%d,%d) v=%d hp=%.0f fuel=%.0f goal=%s aim=%s plan=%d/%d/%d cap=%.0f goons=%d seen=%d stuck=%d" % [levelTime,
		car.global_position.x, car.global_position.y, car.velocity.length(), car.health, car.fuel, goalText, aimText,
		driver.plan.steer, mini(driver.plan.steerTicks, 99), driver.plan.throttle, minf(driver.speedCap, 9999.0), GameStats.goons(), goonsSeen(), driver.stats.stuck])
	print("PLAYTEST_COSTS hop=%d " % driver.approachHop + " ".join(driver.lastCosts))

#live goons inside the view and its LOD margin (SpawnManager.physicsView): what the player can see or about to
func goonsSeen() -> int:
	var n := 0
	for g in Root.spawnManager.goons:
		if is_instance_valid(g) && not g.dead && Root.spawnManager.physicsView.has_point(g.global_position): n += 1
	return n

#Defense, every 10 s: the barrier, the goons marching on the station and wedged on the way, and how many have
#blown up at the pumps so far
func traceDefense() -> void:
	var station = Root.station
	if not is_instance_valid(station) || not is_instance_valid(Root.spawnManager): return
	var marching := 0
	var wedged := 0
	var near := 0
	for g in Root.spawnManager.goons:
		if not is_instance_valid(g) || g.dead: continue
		if g.global_position.distance_to(station.global_position) < 1500.0: near += 1
		if g.sieging(car): marching += 1
		if g.isStuck(): wedged += 1
	print("PLAYTEST_DEFENSE t=%.0f barrier=%.0f goons=%d marching=%d blown=%d within_1500=%d wedged=%d car_to_station=%d" % [levelTime,
		station.barrier, Root.spawnManager.goons.size(), marching, station.blasts, near, wedged, car.global_position.distance_to(station.global_position)])

#--trace: what the car's own collision polygons (the front bumper and the rear; the middle of the car has
#none) overlap right now, "F"/"R" plus "*" for the one enabled: a car wedged inside a shape can't move
func overlapping() -> String:
	var parts := PackedStringArray()
	for nodeName in ["CollisionShape2D", "CollisionShape2D_rear"]:
		var node = car.get_node_or_null(nodeName)
		if not node is CollisionPolygon2D: continue
		var shape := ConvexPolygonShape2D.new()
		shape.points = node.polygon
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = node.global_transform
		q.collision_mask = 1
		q.exclude = [car.get_rid()]
		var names := PackedStringArray()
		for hit in car.get_world_2d().direct_space_state.intersect_shape(q, 8):
			var c = hit.collider
			names.push_back(String(c.get_meta(&"propId", c.name)) if c is Node else "?")
		parts.push_back("%s%s:%s" % ["F" if nodeName == "CollisionShape2D" else "R", "" if node.disabled else "*", "+".join(names) if not names.is_empty() else "-"])
	return " ".join(parts)

#--trace: what solid things are within `radius` of a point: prop ids (BreakableProp metadata) or "wall"
func nearStatics(pos: Vector2, radius: float) -> String:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = circle
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = 1
	q.exclude = [car.get_rid()]
	var names := {}
	for hit in car.get_world_2d().direct_space_state.intersect_shape(q, 16):
		var id := String(hit.collider.get_meta(&"propId", "wall")) if hit.collider is Node else "?"
		names[id] = names.get(id, 0) + 1
	return ",".join(names.keys().map(func(k): return "%s%s" % [k, "x%d" % names[k] if names[k] > 1 else ""])) if not names.is_empty() else "-"

func wallName() -> String:
	for i in car.get_slide_collision_count():
		var collider = car.get_slide_collision(i).get_collider()
		if World.isWall(collider): return "%s(%s) layer=%d at %s" % [collider.name, collider.get_parent().name, collider.collision_layer if collider is StaticBody2D else -1, str(car.get_slide_collision(i).get_position())]
	return "-"

#--trace: the world's coarse map (1280 px cells) around the start and the station, one letter per cell
#from World.TERRAIN: g grass, s sand, m mud, ~ water, ^ hills, o moss, d dirt, * snow, = asphalt, i ice,
#% oil, - shallows, w wash, > conveyor, @ mud pit, # deep snow, l lot, B building, b bridge, v wading depth
#(fine maps only); + a pass;
#S start, X station. Cropped to MAP_CROP cells.
const MAP_CROP := Vector2i(120, 48)
func printMap() -> void:
	var map: WorldMap = Root.worldMap
	if map == null: return
	var start := map.coarseCell(Root.levelRoot.startPosition)
	var station := map.coarseCell(Root.station.global_position) if is_instance_valid(Root.station) else start
	var low := Vector2i(mini(start.x, station.x), mini(start.y, station.y)) - Vector2i(8, 6)
	var high := Vector2i(maxi(start.x, station.x), maxi(start.y, station.y)) + Vector2i(8, 6)
	var size := (high - low + Vector2i.ONE).min(MAP_CROP)
	var marks := {start: "S", station: "X"} if station != start else {start: "S"}
	var lines := WorldGen.ascii({"terrain": map.terrain, "flags": map.flags}, (low + high) / 2, size.x, size.y, marks)
	for i in lines.size(): print("PLAYTEST_MAP %4d %s" % [(low + high).y / 2 - size.y / 2 + i, lines[i]])

#A drowning, as it was on the tick the car was wrecked (it coasts on until the run ends): where, how fast,
#what the driver was doing, and the fine map round the car (9 x 9 cells of 128 px, World.TERRAIN letters,
#C the car's cell)
var waterDeath := {}
func waterSnapshot() -> Dictionary:
	var at := car.global_position
	var lines := PackedStringArray()
	for dy in range(-4, 5):
		var line := ""
		for dx in range(-4, 5):
			line += "C" if dx == 0 && dy == 0 else World.letter(World.terrainAt(at + Vector2(dx, dy) * 128.0))
		lines.push_back(line)
	return {"text": "PLAYTEST_WATER t=%.1f pos=(%d,%d) v=(%d,%d) heading=%.0fdeg goal=%s plan=%s goons_near=%d airborne=%d buffs=%s" % [levelTime, at.x, at.y,
		car.velocity.x, car.velocity.y, rad_to_deg(car.rotation), driver.goal.get("kind", "-"), str(driver.plan),
		Root.spawnManager.goonsNear(at, 400.0).size() if is_instance_valid(Root.spawnManager) else 0, car.airborneTicks, str(car.buffs.keys())], "map": lines}

func printWaterDeath() -> void:
	if waterDeath.is_empty(): waterDeath = waterSnapshot()
	print(waterDeath.text)
	for line in waterDeath.map: print("PLAYTEST_WATER_MAP " + line)

#Goons the car hit at crushing speed (over 200 px/s going in) that survived the hit. Should stay 0
#while every hit at speed crushes; a goon that can resist a crush shows up here.
func countMissedCrushes() -> void:
	var counted = {}
	for i in car.get_slide_collision_count():
		var collider = car.get_slide_collision(i).get_collider()
		if collider is Walker && is_instance_valid(collider) && not collider.isDying() && speedBefore > 200.0 && not counted.has(collider):
			counted[collider] = true
			row.crush_misses += 1
	speedBefore = car.velocity.length()

func touchingGoon() -> bool:
	for i in car.get_slide_collision_count():
		if car.get_slide_collision(i).get_collider() is CharacterBody2D: return true
	return false

func touchingWall() -> bool:
	for i in car.get_slide_collision_count():
		var collider = car.get_slide_collision(i).get_collider()
		if World.isWall(collider): return true
	return false

#a prize game pauses the run: tap its action key (PickupMenu.ACT) until it closes
#paused this long (real ms) with no menu to answer once the run has started, the run would hang (a crush goal
#that paused for a menu that never opened)
const SOFTLOCK_MS := 10000
var pausedEmptySince := -1
func tapSlotMachine(delta: float) -> void:
	if get_tree().get_nodes_in_group("slotMachine").is_empty():
		if Input.is_action_pressed(PickupMenu.ACT): Input.action_release(PickupMenu.ACT)
		if pausedEmptySince < 0: pausedEmptySince = Time.get_ticks_msec()
		elif clockSeen && Time.get_ticks_msec() - pausedEmptySince > SOFTLOCK_MS && get_tree().get_nodes_in_group("pauseMenu").is_empty():
			print("PLAYTEST_SOFTLOCK t=%.1f: the tree was paused with no menu open; unpausing" % levelTime)
			pausedEmptySince = -1
			get_tree().paused = false
		return
	pausedEmptySince = -1
	slotPressTimer -= delta
	if Input.is_action_pressed(PickupMenu.ACT): Input.action_release(PickupMenu.ACT)
	elif slotPressTimer <= 0.0:
		slotPressTimer = 0.4
		Input.action_press(PickupMenu.ACT) #the prize games' action key

func recordRun() -> void:
	recorded = true
	var reason = str(Root.endCondition.find_key(Root.levelRoot.endReason))
	if row.timeout: reason = "TIMEOUT"
	elif reason == "NOHEALTH" && car.drowned:
		reason = "WATER" #wrecked over deep water
		printWaterDeath()
	row.erase("timeout")
	row.reason = reason
	row.won = Root.levelRoot.isWon() #as the results ticket counts it: a Goonpocalypse past its target is won
	row.level_time = snappedf(levelTime, 0.1)
	row.crush_xp = int(car.crushXp)
	row.boxes = Root.playerRoot.boxLevel if is_instance_valid(Root.playerRoot) else 0
	row.time_left = snappedf(Root.levelRoot.seconds, 0.1) if row.mode != "goonpocalypse" else 0.0
	row.station_left_px = int(car.global_position.distance_to(Root.station.global_position)) if is_instance_valid(Root.station) else 0
	#stations reached (Sprint 0 or 1; Marathon counts each leg's station, TileManager.legsPlaced moves on at each)
	var tm = Root.levelRoot.get_node_or_null("TileManager")
	row.legs = (int(tm.legsPlaced) if tm != null else 0) + (1 if row.won && row.mode in ["sprint", "marathon"] else 0)
	row.crushed = car.currentGoonsCrushed
	row.coin = car.coin
	row.star = car.star
	row.payout = Root.levelRoot.runPayout(Root.levelRoot.isWon())
	row.tier = ModeTiers.NAMES[Root.levelRoot.tier].to_lower()
	row.win_bonus = Root.levelRoot.winBonus() if Root.levelRoot.isWon() else 0
	row.first_clear = Root.levelRoot.firstClear.coin
	row.first_clear_gem = Root.levelRoot.firstClear.gem
	row.gem = car.gem
	row.slot_machines = car.slotMachines
	row.end_fuel = snappedf(car.fuel, 0.1)
	row.end_health = snappedf(car.health, 0.1)
	row.top_speed = int(car._highest_measured_speed)
	row.avg_speed = int(row.distance_px / maxf(levelTime, 0.1))
	row.distance_px = int(row.distance_px)
	for key in ["damage_rocks", "damage_goon_contact", "damage_goon_attacks", "damage_water", "min_fuel", "min_health"]: row[key] = snappedf(row[key], 0.1)
	if is_instance_valid(driver):
		row.stuck = driver.stats.stuck
		row.escapes = driver.stats.escapes
		row.eco_seconds = snappedf(driver.stats.eco_seconds, 0.1)
		row.route_reached = driver.stats.route_reached
		row.goals = JSON.stringify(driver.stats.goals).replace(",", ";") #one CSV cell
		row.ai_ms = snappedf(driver.stats.think_usec / 1000.0 / maxf(levelTime, 0.1), 0.1) #driver CPU per game second
		if options.has("trace"):
			var parts = []
			for key in ["usec_goal", "usec_aim", "usec_plan", "usec_sim", "usec_score", "usec_recover"]: parts.push_back("%s=%.0f" % [key.trim_prefix("usec_"), driver.stats.get(key, 0) / 1000.0 / maxf(levelTime, 0.1)])
			print("PLAYTEST_AI_MS per game second: " + " ".join(parts))
	var kinds = Pickups.countByKind(car.pickedById)
	for kind in kinds: row["pk_" + kind] = kinds[kind]
	row.score = snappedf(runScore(row), 0.1)
	if career: career.onRunRecorded(row) #adds persona and session
	results.push_back(row.duplicate())
	print("PLAYTEST_RESULT " + JSON.stringify(row))
	appendCsv(row)
	if career: return #the persona reads the results ticket and goes back to the garage
	await get_tree().create_timer(0.5).timeout
	startNext()

#a file written with other columns (an older harness) is moved aside, not appended to
func appendCsv(values: Dictionary) -> void:
	var path = "user://playtest/results%s.csv" % str(options.get("tag", ""))
	var header = ",".join(COLUMNS)
	if FileAccess.file_exists(path) && FileAccess.open(path, FileAccess.READ).get_line() != header:
		DirAccess.rename_absolute(path, path.get_basename() + "_old_%d.csv" % Time.get_unix_time_from_system())
	var isNew = not FileAccess.file_exists(path)
	var file = FileAccess.open(path, FileAccess.WRITE if isNew else FileAccess.READ_WRITE)
	file.seek_end()
	if isNew: file.store_line(header)
	file.store_line(",".join(COLUMNS.map(func(column): return str(values.get(column, "")))))
	file.close()

#How well a run was played, so profiles can be ranked within a mode: coins, since payout (coins x
#stars) is what buys cars and upgrades, plus the mode's own result. scripts/ai/tournament.py
#computes the same score from the CSV, so keep the two in step.
#  coins: 30 x log10(1 + payout): 60 for 100, 90 for 1000, 104 for 3000 (one huge run can't swamp the rest)
#  countdown: + 50 x the share of the clock survived
#  sprint/marathon: + 50 + 25 x the share of the clock left for a win; up to 25 for the share of the
#    way to the station covered for a loss
#  goonpocalypse/defense: + 50 x the share of 300 s survived
static func runScore(result: Dictionary) -> float:
	var clock = maxf(float(result.get("clock", 1.0)), 1.0)
	var coins = 30.0 * log(1.0 + maxf(float(result.payout), 0.0)) / log(10.0)
	match result.mode:
		"gooncrusher":
			return coins + 50.0 * minf(result.level_time / clock, 1.0)
		"sprint", "marathon":
			if result.won: return coins + 50.0 + 25.0 * result.time_left / clock
			return coins + 25.0 * clampf(1.0 - float(result.station_left_px) / maxf(float(result.get("station_px", 1)), 1.0), 0.0, 1.0)
	return coins + 50.0 * minf(result.level_time / 300.0, 1.0)

#one line per level x mode x car x profile (wins, endings and averages), then each mode's profiles
#ranked by average score
func finish() -> void:
	var groups = {}
	for result in results:
		var key = "%s %s %s %s" % [result.level, result.mode, result.car, result.profile]
		groups.get_or_add(key, []).push_back(result)
	for key in groups:
		var runs: Array = groups[key]
		var endings = {}
		for result in runs: endings[result.reason] = endings.get(result.reason, 0) + 1
		var summary = {"combo":key, "runs":runs.size(), "wins":runs.filter(func(r): return r.won).size(), "endings":endings}
		for field in ["score", "level_time", "legs", "crushed", "payout", "star", "damage_rocks", "damage_goon_contact", "damage_goon_attacks", "damage_water", "min_fuel", "stuck", "escapes", "avg_speed"]:
			var total = 0.0
			for result in runs: total += float(result.get(field, 0))
			summary["avg_" + field] = snappedf(total / runs.size(), 0.1)
		print("PLAYTEST_SUMMARY " + JSON.stringify(summary))
	var byMode = {}
	for result in results: byMode.get_or_add(result.mode, {}).get_or_add(result.profile, []).push_back(result)
	for mode in byMode:
		var ranking = []
		for profile in byMode[mode]:
			var runs: Array = byMode[mode][profile]
			var total = 0.0
			for result in runs: total += result.score
			ranking.push_back([total / runs.size(), profile, runs.size()])
		ranking.sort_custom(func(a, b): return a[0] > b[0])
		for i in ranking.size():
			print("PLAYTEST_RANKING %s #%d %s score=%.1f runs=%d" % [mode, i + 1, ranking[i][1], ranking[i][0], ranking[i][2]])
	print("PLAYTEST_DONE %d runs, results in %s" % [results.size(), ProjectSettings.globalize_path("user://playtest/")])
	get_tree().quit(0)
