extends Node

#Automated playtesting with the AI driver (docs/AI_DRIVER.md). Inert unless the user args include
#--playtest. Runs are real: no god mode, the real clock, the real endings. Every level x mode x car
#x AI profile combination is played --runs times, with map seeds --seed, --seed+1, ...; each run
#adds a row to user://playtest/results<tag>.csv and prints PLAYTEST_RESULT, and the end prints
#PLAYTEST_SUMMARY per combination and PLAYTEST_RANKING per mode (profiles by average score, see
#runScore). Fastest: headless, with frames decoupled from real time. scripts/ai/tournament.py runs
#several profiles in parallel processes and ranks them.
#  Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=sprint --runs=5
#Options: --level=level_grass_1[,...]  --mode=countdown|sprint|goonpocalypse|marathon|defense[,...]
#  --car=sedan[,...]  --profiles=default[,crusher,...] (AIProfiles specs)  --runs=N  --seed=N  --upgrades=N|save (every stat at level N; default 0, the
#  stock car; "save" keeps the save's)  --sight=human|full  --max-seconds=N (level time before a run
#  is cut short, default 900)  --ai-debug (draw the AI's plan; not headless)  --trace (state once a
#  second)  --tag=name
#Progress goes to a scratch save, as with the benchmark, so the real save is never touched.

const LEVELS = "res://scene/level/levels/"
const SCRATCH_SAVE = "user://playtest/playtest_save%s.tres" #per --tag, so parallel processes don't share one
const MODE_ALIASES = {"countdown":"GOONCRUSHER"}
#one CSV row per run, in this order (damage is health lost; see _physics_process for the split)
const COLUMNS = ["run", "level", "mode", "car", "profile", "seed", "upgrades", "sight", "score", "reason", "won", "level_time",
	"clock", "time_left", "station_px", "station_left_px", "route_reached", "crushed", "coin", "star", "payout", "gem",
	"slot_machines", "fuel_pickups", "health_pickups", "purses", "coins_picked", "gems_picked", "stat_pickups",
	"damage_rocks", "damage_goon_contact", "damage_goon_attacks", "crush_misses", "min_fuel", "min_health",
	"end_fuel", "end_health", "distance_px", "avg_speed", "top_speed", "eco_seconds", "stuck", "escapes", "goals"]

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
var lastPosition := Vector2.ZERO
var clockSeen := false
var slotPressTimer := 0.0
var lastStuck := 0
var speedBefore := 0.0 #the car's speed going into its last tick

func _ready():
	options = parseArgs()
	if not options.has("playtest"):
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.on_menu_ready() #runs leave the menu before main2 reports it, which would count as a crashed boot
	Settings.set_value("display/pause_unfocused", false, false)
	DirAccess.make_dir_recursive_absolute("user://playtest")
	SaveManager.save_path = SCRATCH_SAVE % str(options.get("tag", ""))
	maxSeconds = float(options.get("max-seconds", 900.0))
	var firstSeed = int(options.get("seed", 1))
	for level in listArg("level", "level_grass_1"):
		if not ResourceLoader.exists(LEVELS + level + ".tscn"): return fail("Unknown level " + level)
		for modeName in listArg("mode", "countdown"):
			var key = MODE_ALIASES.get(modeName.to_lower(), modeName.to_upper())
			if not Root.gameModes.has(key): return fail("Unknown mode " + modeName)
			for carName in listArg("car", "sedan"):
				if carIndex(carName) < 0: return fail("Unknown car " + carName)
				for profile in listArg("profiles", "default"):
					if not AIProfiles.PROFILES.has(profile.split("+")[0]): return fail("Unknown AI profile " + profile)
					for i in int(options.get("runs", 1)):
						jobs.push_back({"level":level, "mode":key, "car":carName, "profile":profile, "seed":firstSeed + i})
	get_tree().node_added.connect(onNodeAdded)
	await get_tree().create_timer(1.0).timeout
	startNext()

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
	car = null
	driver = null
	recorded = false
	clockSeen = false
	lastStuck = 0
	levelTime = 0.0
	row = {"run":jobIndex + 1, "level":job.level, "mode":job.mode.to_lower(), "car":job.car, "profile":job.profile, "seed":job.seed,
		"upgrades":upgrades, "sight":str(options.get("sight", "human")),
		"fuel_pickups":0, "health_pickups":0, "purses":0, "coins_picked":0, "gems_picked":0, "stat_pickups":0,
		"crush_misses":0, "damage_rocks":0.0, "damage_goon_contact":0.0, "damage_goon_attacks":0.0, "min_fuel":100.0, "min_health":100.0, "distance_px":0.0, "timeout":false}
	print("PLAYTEST_RUN %d/%d %s %s %s %s seed=%d" % [jobIndex + 1, jobs.size(), job.level, job.mode.to_lower(), job.car, job.profile, job.seed])
	Region.resetRegions()
	Root.isRunActive = false
	get_tree().paused = false
	get_tree().change_scene_to_node(RunView.wrap(load(LEVELS + job.level + ".tscn").instantiate()))

func onNodeAdded(node: Node) -> void:
	if jobIndex < 0 || jobIndex >= jobs.size(): return
	if node is Level: seed(jobs[jobIndex].seed) #again, as late as possible: the menu frames between use the RNG too
	elif node is landscapeGenerator: node.inputSeed = jobs[jobIndex].seed
	elif node is OverheadCarBody2D && node.isPlayer: node.ready.connect(onCarReady.bind(node), CONNECT_ONE_SHOT)

func onCarReady(newCar: OverheadCarBody2D) -> void:
	car = newCar
	driver = AIDriver.attach(car, {"sight":row.sight, "debug":options.has("ai-debug"), "profile":row.profile})
	car.rewarded.connect(onRewarded)
	prevHealth = car.health
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
		tapSlotMachine(delta)
		return
	if Root.levelRoot.clockReady && not clockSeen:
		clockSeen = true
		row.clock = snappedf(Root.levelRoot.seconds, 0.1)
		row.station_px = int(Root.levelRoot.startPosition.distance_to(Root.station.global_position)) if is_instance_valid(Root.station) else 0
		if options.has("trace"): printMap()
	levelTime += delta
	#this runs before the car's tick, so health and collisions are both from the tick before
	var drop = prevHealth - car.health
	if drop > 0.0:
		if touchingWall():
			row.damage_rocks += drop
			if options.has("trace") && drop > 1.0: print("PLAYTEST_HIT t=%.1f v=%d drop=%.1f plan=%s predicted_hit=%s goal=%s with=%s" % [levelTime, car.velocity.length(), drop, str(driver.plan), str(driver.planHit), driver.goal.get("kind", "-"), wallName()])
		elif touchingGoon(): row.damage_goon_contact += drop #the car ran into it (crushes cost health too)
		else: row.damage_goon_attacks += drop #a goon lunged into the car's body
	prevHealth = car.health
	countMissedCrushes()
	row.min_fuel = minf(row.min_fuel, car.fuel)
	row.min_health = minf(row.min_health, car.health)
	row.distance_px += car.global_position.distance_to(lastPosition)
	lastPosition = car.global_position
	if options.has("trace") && Engine.get_physics_frames() % Engine.physics_ticks_per_second == 0: trace()
	if options.has("trace") && driver.stats.stuck != lastStuck:
		lastStuck = driver.stats.stuck
		var station = Root.station.global_position.distance_to(car.global_position) if is_instance_valid(Root.station) else -1.0
		print("PLAYTEST_STUCK t=%.1f pos=(%d,%d) station=%d goal=%s goons_near=%d touching=%s" % [levelTime, car.global_position.x, car.global_position.y,
			station, driver.goal.get("kind", "-"), driver.nearGoons.size(), wallName() if touchingWall() else ("goon" if touchingGoon() else "-")])
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
	print("PLAYTEST_TRACE t=%.0f pos=(%d,%d) v=%d hp=%.0f fuel=%.0f goal=%s aim=%s plan=%d/%d/%d cap=%.0f goons=%d stuck=%d" % [levelTime,
		car.global_position.x, car.global_position.y, car.velocity.length(), car.health, car.fuel, goalText, aimText,
		driver.plan.steer, mini(driver.plan.steerTicks, 99), driver.plan.throttle, minf(driver.speedCap, 9999.0), GameStats.goons(), driver.stats.stuck])
	print("PLAYTEST_COSTS hop=%d " % driver.approachHop + " ".join(driver.lastCosts))

func wallName() -> String:
	for i in car.get_slide_collision_count():
		var collider = car.get_slide_collision(i).get_collider()
		if collider is StaticBody2D || collider is TileMap: return "%s(%s) layer=%d at %s" % [collider.name, collider.get_parent().name, collider.collision_layer if collider is StaticBody2D else -1, str(car.get_slide_collision(i).get_position())]
	return "-"

#--trace: the chunks around the start (and the station), one letter per chunk:
#g grass, s sand, m mud, ~ water, ^ hills, o moss, d dirt, * snow; S start, X station
func printMap() -> void:
	var tileManager = Root.levelRoot.get_node("TileManager")
	var start: Vector2i = tileManager.chunkOf(Root.levelRoot.startPosition)
	var station: Vector2i = tileManager.chunkOf(Root.station.global_position) if is_instance_valid(Root.station) else start
	var low = Vector2i(mini(start.x, station.x), mini(start.y, station.y)) - Vector2i(4, 6)
	var high = Vector2i(maxi(start.x, station.x), maxi(start.y, station.y)) + Vector2i(4, 6)
	var letters = "gsm~^od*"
	for y in range(low.y, high.y + 1):
		var line = ""
		for x in range(low.x, high.x + 1):
			var chunk = Vector2i(x, y)
			if chunk == start: line += "S"
			elif chunk == station: line += "X"
			else: line += letters[tileManager.tileAt(chunk).terrain]
		print("PLAYTEST_MAP %4d %s" % [y, line])

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
		if collider is StaticBody2D || collider is TileMap: return true
	return false

#a slot machine pauses the run: tap Accelerate to stop each reel, then claim (never reroll)
func tapSlotMachine(delta: float) -> void:
	if get_tree().get_nodes_in_group("slotMachine").is_empty():
		if Input.is_action_pressed("Accelerate"): Input.action_release("Accelerate")
		return
	slotPressTimer -= delta
	if Input.is_action_pressed("Accelerate"): Input.action_release("Accelerate")
	elif slotPressTimer <= 0.0:
		slotPressTimer = 0.4
		Input.action_press("Accelerate")

func recordRun() -> void:
	recorded = true
	var reason = str(Root.endCondition.find_key(Root.levelRoot.endReason))
	if row.timeout: reason = "TIMEOUT"
	elif reason == "NOHEALTH" && car.health > 0.0: reason = "WATER" #the water kills without damage
	row.erase("timeout")
	row.reason = reason
	row.won = Root.levelRoot.endReason == Root.endCondition.SUCCESS
	row.level_time = snappedf(levelTime, 0.1)
	row.time_left = snappedf(Root.levelRoot.seconds, 0.1) if row.mode != "goonpocalypse" else 0.0
	row.station_left_px = int(car.global_position.distance_to(Root.station.global_position)) if is_instance_valid(Root.station) else 0
	row.crushed = car.currentGoonsCrushed
	row.coin = car.coin
	row.star = car.star
	row.payout = Root.computePayout(car.coin, car.star)
	row.gem = car.gem
	row.slot_machines = car.slotMachines
	row.end_fuel = snappedf(car.fuel, 0.1)
	row.end_health = snappedf(car.health, 0.1)
	row.top_speed = int(car._highest_measured_speed)
	row.avg_speed = int(row.distance_px / maxf(levelTime, 0.1))
	row.distance_px = int(row.distance_px)
	for key in ["damage_rocks", "damage_goon_contact", "damage_goon_attacks", "min_fuel", "min_health"]: row[key] = snappedf(row[key], 0.1)
	if is_instance_valid(driver):
		row.stuck = driver.stats.stuck
		row.escapes = driver.stats.escapes
		row.eco_seconds = snappedf(driver.stats.eco_seconds, 0.1)
		row.route_reached = driver.stats.route_reached
		row.goals = JSON.stringify(driver.stats.goals).replace(",", ";") #one CSV cell
	row.score = snappedf(runScore(row), 0.1)
	results.push_back(row.duplicate())
	print("PLAYTEST_RESULT " + JSON.stringify(row))
	appendCsv(row)
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

#How well a run was played, 0 to about 150, so profiles can be ranked within a mode:
#  countdown/defense: % of the clock survived, +25 for surviving it, +0.1 per crush (up to 200)
#  sprint/marathon: a win is 100 + 50 x the share of the clock left; a loss is up to 50 for the
#    share of the way to the station covered
#  goonpocalypse: a point per 3 s survived, +0.1 per crush (up to 300)
static func runScore(result: Dictionary) -> float:
	var clock = maxf(float(result.get("clock", 1.0)), 1.0)
	match result.mode:
		"gooncrusher", "defense":
			return 100.0 * minf(result.level_time / clock, 1.0) + (25.0 if result.won else 0.0) + minf(result.crushed, 200) * 0.1
		"sprint", "marathon":
			if result.won: return 100.0 + 50.0 * result.time_left / clock
			return 50.0 * clampf(1.0 - float(result.station_left_px) / maxf(float(result.get("station_px", 1)), 1.0), 0.0, 1.0)
	return result.level_time / 3.0 + minf(result.crushed, 300) * 0.1

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
		for field in ["score", "level_time", "crushed", "payout", "star", "damage_rocks", "damage_goon_contact", "damage_goon_attacks", "min_fuel", "stuck", "avg_speed"]:
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
