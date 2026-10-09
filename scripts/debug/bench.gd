extends Node

#Benchmark harness (docs/PERFORMANCE.md, "Benchmarking").
#Inert unless the user args include --bench=<id>, e.g.
#  Godot_console.exe --path . --windowed --resolution 1600x900 -- --bench=S2 --seconds=90
#Options: --seconds=N, --preset=potato|low|medium|high, --set=gfx/lighting:0;gfx/smoke:1 (any
#setting, not saved), --shot=5;30 (screenshots at those level seconds), --open-settings (S1 only),
#--notext, --car=taxi (another car than the scenario's), --damage=engine:30;tank:10 (system conditions,
#held for the whole run; e.g. to look at the damaged car art or time the damage effects).
#Game mode: --mode=gooncrusher|sprint|marathon|defense|goonpocalypse (default gooncrusher) sets the
#scratch save's gameMode before the level loads. --level-seconds=N replaces the level's authored
#seconds (Sprint derives its clock from them). Without --level-seconds the bench keeps a
#counting-down clock from running out, so long benchmarks are not cut short by the Countdown win;
#with it the run can end, and BENCH_RUN_ENDED is printed (the bench then stops driving).
#--level=<id|index|path> plays another level than the scenario's: a level id or scene basename
#(prairie, level_grass_1; resolved under scene/level/levels/ as <arg>.tscn or level_<arg>.tscn), an
#index into the save's level list, or a res:// path.
#Writes a per-frame CSV and a summary row to user://bench/. Saves are redirected to a scratch
#copy, so a benchmark never changes player progress. Columns include chunk_ms (main-thread chunk
#build/apply time that frame, read from TileManager.chunkMs when the world code provides it; 0
#otherwise) and occluders (visible LightOccluder2Ds, sampled every 0.5 s like lights).
#--pattern=none|sine|circle|route replaces the scenario's driving. --at=water|wall|station|x,y moves the car, once
#the world is ready, next to the nearest deep water or wall (a coarse barrier cell beside open ground), onto the
#station's approach (a mode with a station: --mode=sprint|marathon|defense) or to a world point, to look at the
#world's edges (with --shot). --zoom=0.4 holds the camera's zoom. --seed=N plays another map than 1337 (a playtest's seed, say).

const LEVELS = "res://scene/level/levels/"
const SCENARIOS = {
	"S1": {"level":"", "seconds":60},
	"S2": {"level":"prairie", "car":"sedan", "pattern":"sine", "seconds":90},
	"S3": {"level":"quarry", "car":"police", "night":true, "pattern":"circle", "spawnTimer":2.0, "escalation":0.0, "seconds":90},
	"S4": {"level":"quarry", "car":"police", "night":true, "pattern":"circle", "spawnTimer":1.0, "progress":200, "giantOdds":50, "seconds":150},
	"S5": {"level":"prairie", "car":"sedan", "pattern":"none", "slots":5, "seconds":90},
	"S6": {"level":"prairie", "car":"sedan", "pattern":"route", "seconds":600},
	"S7": {"level":"prairie", "car":"sedan", "night":true, "pattern":"none", "purses":10, "seconds":30},
	#lighting parity: parked at night with no goons; use --headlights=N and --shot
	"SL": {"level":"prairie", "car":"sedan", "night":true, "pattern":"none", "spawnTimer":9999.0, "escalation":0.0, "seconds":10},
}
const WARMUP = 5.0
const SCRATCH_SAVE = "user://bench/bench_save.tres"

var id: String
var cfg: Dictionary
var seconds: float
var elapsed: float = 0.0
var levelTime: float = 0.0
var rows: PackedStringArray = []
var frameMs: PackedFloat32Array = []
var lightCount: int = 0
var occluderCount: int = 0
var levelPath: String = "" #the level scene this run plays ("" for the menu, S1)
var lightTimer: float = 0.0
var started: bool = false
var nightSet: bool = false
var slotPressTimer: float = 0.0
var slotsClaimed: int = 0
var pursesSpawned: int = 0
var stripText: bool = false
var shots: Array = []
var headlights: int = -1
var damage := {} #--damage: system -> condition
var loadStart: int = 0
var loadReported := false
var longestLoadFrame: float = 0.0
var label: String = "" #--tag=name, added to output file names
var stuckTime: float = 0.0
var recoverTime: float = 0.0
var gameMode: int = Root.gameModes.GOONCRUSHER #--mode
var levelSeconds: float = -1.0 #--level-seconds; -1 keeps the level's own
var runEndReported := false
var worldReported := false
var at := "" #--at
var zoom := 0.0 #--zoom

func _ready():
	var args = parseArgs()
	if not args.has("bench"):
		queue_free()
		return
	id = args.bench
	Settings.on_menu_ready() #runs leave the menu before main2 reports it, which would count as a crashed boot and start the next run in safe mode
	print("BENCH_STARTUP_MS %d" % Time.get_ticks_msec()) #process start to the main menu being ready
	if not SCENARIOS.has(id):
		push_error("Unknown bench scenario " + id)
		get_tree().quit(1)
		return
	cfg = SCENARIOS[id].duplicate()
	if args.has("car"): cfg.car = str(args.car)
	if args.has("pattern"): cfg.pattern = str(args.pattern)
	at = str(args.get("at", ""))
	zoom = float(args.get("zoom", 0.0))
	if cfg.level != "": levelPath = resolveLevel(cfg.level)
	if args.has("level"):
		levelPath = resolveLevel(str(args.level))
		if levelPath == "":
			push_error("Unknown bench level " + str(args.level))
			get_tree().quit(1)
			return
		cfg.level = levelPath.get_file().get_basename()
	seconds = float(args.get("seconds", cfg.seconds))
	if args.has("mode"):
		var modeName = str(args.mode).to_upper()
		if not Root.gameModes.has(modeName):
			push_error("Unknown bench mode " + str(args.mode))
			get_tree().quit(1)
			return
		gameMode = Root.gameModes[modeName]
	levelSeconds = float(args.get("level-seconds", -1.0))
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://bench")
	SaveManager.save_path = SCRATCH_SAVE
	Unlocks.allOpen = str(args.get("unlocks", "all")) == "all" #every pickup can drop, as before the unlocks
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	stripText = args.has("notext") #measure with every 3D-text material removed
	get_tree().node_added.connect(onNodeAdded)
	if stripText:
		for node in get_tree().root.find_children("*", "CanvasItem", true, false): onNodeAdded(node)
	if args.has("preset") && has_node("/root/Settings") && get_node("/root/Settings").has_method("apply_preset_by_name"):
		get_node("/root/Settings").apply_preset_by_name(args.preset, false)
	if has_node("/root/Settings") && get_node("/root/Settings").has_method("set_value"):
		Settings.set_value("display/pause_unfocused", false, false) #clicking another window must not pause a run
	if args.has("set"):
		for pair in str(args.set).split(";"):
			var kv = pair.split(":")
			if kv.size() == 2: Settings.set_value(kv[0], str_to_var(kv[1]), false)
	label = str(args.get("tag", ""))
	headlights = int(args.get("headlights", -1))
	if args.has("damage"):
		for pair in str(args.damage).split(";"):
			var kv = pair.split(":")
			if kv.size() == 2: damage[kv[0]] = float(kv[1])
	if args.has("shot"):
		for t in str(args.shot).split(";"): shots.push_back(float(t))
	if args.has("open-settings"):
		await get_tree().create_timer(1.5).timeout
		var menu = load("res://scene/player/menu/settings/settings.tscn").instantiate()
		Root.mainMenu.add_child(menu)
		if args["open-settings"] is String: menu.showTab(int(args["open-settings"])) #--open-settings=2 opens the third tab
	await get_tree().create_timer(1.0).timeout
	if cfg.level != "": startLevel()
	started = true

#a level id (Levels.ORDER), its 0-based index or an old scene name (Levels.resolve), another scene
#basename under scene/level/levels/, or a res:// path; "" when unknown
static func resolveLevel(arg: String) -> String:
	if arg.begins_with("res://"): return arg if ResourceLoader.exists(arg) else ""
	var id := Levels.resolve(arg)
	if id != &"": return Levels.scenePath(id)
	if arg.is_valid_int():
		var levels: Array = SaveManager.playerData.levels
		var i := int(arg)
		return str(levels[i].scene) if i >= 0 && i < levels.size() else ""
	for path in [LEVELS + arg + ".tscn", LEVELS + "level_" + arg + ".tscn"]:
		if ResourceLoader.exists(path): return path
	return ""

static func parseArgs() -> Dictionary:
	var result = {}
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--") && arg.contains("="):
			var parts = arg.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
		elif arg.begins_with("--"):
			result[arg.substr(2)] = true
	return result

func startLevel() -> void:
	var data = SaveManager.playerData
	for i in data.cars.size():
		if data.cars[i].name == cfg.get("car", "sedan"): data.selectedCar = i
	data.gameMode = gameMode
	var levelIndex := Levels.indexOf(Levels.resolve(levelPath))
	if levelIndex >= 0: data.selectedLevel = levelIndex #Region reads the level's faction band and roster from it
	Root.selectedCar = data.cars[data.selectedCar]
	seed(1337)
	loadStart = Time.get_ticks_msec()
	if parseArgs().has("via-menu") && is_instance_valid(Root.mainMenu):
		Root.mainMenu.startLevel(levelPath) #the real menu path: threaded load
		return
	Region.resetRegions()
	get_tree().change_scene_to_node(RunView.wrap(load(levelPath).instantiate()))

func onNodeAdded(node: Node) -> void:
	if stripText && node is CanvasItem && node.material is ShaderMaterial && node.material.shader && node.material.shader.code.contains("VERTEX_ID>>1"):
		node.material = null
	if node is TileManager:
		node.worldSeed = int(parseArgs().get("seed", 1337)) #--seed=N: another map
	elif node is Level:
		if levelSeconds >= 0.0: node.seconds = levelSeconds #before _ready, so every mode sees it
	elif node is SpawnManager:
		if cfg.has("spawnTimer"): node.spawnTimer = cfg.spawnTimer
		if cfg.has("escalation"): node.escalationSpeed = cfg.escalation
		if cfg.has("progress"): node.gameTimeProgress = cfg.progress
		if cfg.has("giantOdds"): node.giantOdds = cfg.giantOdds

func _physics_process(_delta):
	if not started || cfg.level == "" || not is_instance_valid(Root.levelRoot) || not is_instance_valid(Root.playerCar): return
	if Root.levelRoot.hasEnded:
		#the summary continues on any key, so stop pressing them
		for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight"]:
			if Input.is_action_pressed(action): Input.action_release(action)
		return
	var car = Root.playerCar
	car.health = 100.0 #god mode
	car.lethalTicks = 0 #...over deep water too: the car drowns after LETHAL_TICKS ticks in a row, and a drowned car ends the benchmark
	car.fuel = 100.0
	drive(car)


#S6 measures streaming, so the car must keep going: a car that covers under 400 px in 3 s (grinding
#round a ring of rocks never trips the speed check above) backs up; if that fails twice it is lifted
#900 px along the route
var progressFrom := Vector2.INF
var progressTimer: float = 0.0
var failedRecoveries: int = 0
func checkRouteProgress(car) -> void:
	progressTimer += get_physics_process_delta_time()
	if progressTimer < 3.0: return
	progressTimer = 0.0
	if progressFrom != Vector2.INF && car.global_position.distance_to(progressFrom) < 400.0:
		failedRecoveries += 1
		if failedRecoveries >= 2:
			var heading = 0.0 if levelTime < seconds / 2.0 else -PI / 2.0
			car.global_position += Vector2.from_angle(heading) * 900.0
			car.rotation = heading
			car.velocity = Vector2.ZERO
			failedRecoveries = 0
		else:
			recoverTime = 2.4
	else:
		failedRecoveries = 0
	progressFrom = car.global_position

func drive(car) -> void:
	var wanted = []
	if get_tree().get_nodes_in_group("slotMachine").size() > 0:
		#tap the prize games' action key through whatever is open
		slotPressTimer -= get_physics_process_delta_time()
		if slotPressTimer <= 0.0:
			slotPressTimer = 0.4
			wanted = [PickupMenu.ACT]
	elif recoverTime > 0.0:
		#stuck on a rock: back up while turning, then drive off at an angle
		recoverTime -= get_physics_process_delta_time()
		wanted = ["Brake", "TurnLeft"] if recoverTime > 1.2 else ["Accelerate", "TurnRight"]
	else:
		match cfg.pattern:
			"circle": wanted = ["Accelerate", "TurnRight"]
			"sine": wanted = ["Accelerate", "TurnRight" if int(levelTime / 2.0) % 2 == 0 else "TurnLeft"]
			"route": #+x for the first half, then -y
				wanted = ["Accelerate"]
				var target = 0.0 if levelTime < seconds / 2.0 else -PI / 2.0
				var error = wrapf(target - car.rotation, -PI, PI)
				if error > 0.05: wanted.push_back("TurnRight")
				elif error < -0.05: wanted.push_back("TurnLeft")
	if "Accelerate" in wanted && recoverTime <= 0.0 && cfg.pattern != "none" && car.velocity.length() < 60.0:
		stuckTime += get_physics_process_delta_time()
		if stuckTime > 1.0 && levelTime > 6.0:
			stuckTime = 0.0
			recoverTime = 2.4
	else:
		stuckTime = 0.0
	if cfg.pattern == "route" && levelTime > 6.0: checkRouteProgress(car)
	for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight", PickupMenu.ACT]:
		if action in wanted && not Input.is_action_pressed(action): Input.action_press(action)
		elif not action in wanted && Input.is_action_pressed(action): Input.action_release(action)

func _process(delta):
	if loadStart > 0 && not loadReported:
		longestLoadFrame = maxf(longestLoadFrame, delta * 1000.0)
		if is_instance_valid(Root.levelRoot) && levelTime > 1.0:
			loadReported = true
			print("BENCH_LOAD level ready after %d ms, longest frame %.0f ms" % [Time.get_ticks_msec() - loadStart - int(levelTime * 1000), longestLoadFrame])
	if not started: return
	elapsed += delta
	if cfg.level != "" && is_instance_valid(Root.levelRoot) && is_instance_valid(Root.playerCar):
		levelTime += delta
		levelEvents()
	elif cfg.level != "":
		return #still loading
	lightTimer -= delta
	if lightTimer <= 0.0:
		lightTimer = 0.5
		lightCount = GameStats.lights(get_tree())
		occluderCount = 0
		for occluder in get_tree().get_nodes_in_group("gc_occluder"):
			if occluder.is_visible_in_tree(): occluderCount += 1
	var t = levelTime if cfg.level != "" else elapsed
	if not shots.is_empty() && t >= shots[0]: screenshot(shots.pop_front())
	if t >= WARMUP: record(t, delta)
	if t >= seconds + WARMUP: finish()

func levelEvents() -> void:
	var timer = get_tree().get_first_node_in_group("runTimer")
	if is_instance_valid(timer): timer.reset = true #hold the current time of day
	if levelSeconds < 0.0 && is_instance_valid(timer) && timer.timeIsCountingDown < 0 && Root.levelRoot.clockReady:
		Root.levelRoot.seconds = maxf(Root.levelRoot.seconds, 30.0) #a benchmark run never ends on time
	if Root.levelRoot.clockReady && not worldReported:
		worldReported = true
		if at != "": moveCar()
		print("BENCH_WORLD mode=%s clock=%.1f station=%s start=%s" % [Root.gameModes.find_key(gameMode), Root.levelRoot.seconds,
			str(Root.station.global_position) if is_instance_valid(Root.station) else "none", str(Root.levelRoot.startPosition)])
	if Root.levelRoot.hasEnded && not runEndReported:
		runEndReported = true
		print("BENCH_RUN_ENDED mode=%s reason=%s level_time=%.1f station=%s" % [Root.gameModes.find_key(gameMode),
			Root.endCondition.find_key(Root.levelRoot.endReason), levelTime, str(Root.station.global_position) if is_instance_valid(Root.station) else "none"])
	if zoom > 0.0 && Root.playerCar.has_node("Camera2D"): Root.playerCar.get_node("Camera2D").zoom = Vector2(zoom, zoom)
	for system in damage:
		if Root.playerCar.condition.get(system, -1.0) != damage[system]: Root.playerCar.setCondition(system, damage[system])
	if headlights >= 0 && Root.playerCar.headlights != headlights:
		Root.playerCar.headlights = headlights
		Root.playerCar.setHeadlightStrength()
	if cfg.get("night", false) && not nightSet && levelTime > 0.5:
		nightSet = true
		Root.levelRoot.isDaytime = false
		Root.levelRoot.setNighttime(true)
	if cfg.has("slots") && slotsClaimed < cfg.slots && levelTime > 4.0 && not get_tree().paused && get_tree().get_nodes_in_group("slotMachine").size() == 0:
		slotsClaimed += 1
		SlotMachine.open()
		get_tree().paused = true
	if cfg.has("purses") && pursesSpawned < cfg.purses && levelTime > 5.0 + pursesSpawned && not get_tree().paused:
		pursesSpawned += 1
		var purse = Root.getSpecificPowerup(Root.upgrade.PURSE)
		purse.global_position = Root.playerCar.global_position
		Root.levelRoot.add_child(purse)

#--at: the car beside the nearest barrier of a kind (water or wall), facing it from 900 px, east of the station, or at x,y
func moveCar() -> void:
	var map: WorldMap = Root.worldMap
	var car = Root.playerCar
	if map == null || not is_instance_valid(car): return
	var target := Vector2.INF
	if at.contains(","):
		target = Vector2(float(at.get_slice(",", 0)), float(at.get_slice(",", 1)))
	elif at == "station":
		if not is_instance_valid(Root.station): return
		target = Root.station.global_position + Vector2(1500, 0) #on the approach east of the lot, facing the house
		car.rotation = PI
	else:
		var start := map.coarseCell(car.global_position)
		for ring in range(2, 60):
			for dy in range(-ring, ring + 1):
				for dx in range(-ring, ring + 1):
					if maxi(absi(dx), absi(dy)) != ring || target != Vector2.INF: continue
					var cell := start + Vector2i(dx, dy)
					var i := map.cellIndex(cell)
					if i < 0 || map.flags[i] & WorldGen.BLOCKED == 0: continue
					var water := map.terrain[i] == Root.terrain.WATER
					if water != (at == "water"): continue
					for d in WorldGen.DIRS4:
						if target == Vector2.INF && map.cellReachable(cell + d * 2) && map.cellPassable(cell + d):
							target = WorldGen.cellCentre(cell + d)
							car.rotation = Vector2(-d).angle()
	if target == Vector2.INF: return
	car.global_position = target
	car.velocity = Vector2.ZERO
	print("BENCH_AT %s %s" % [at, target])

func screenshot(t: float) -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = "user://bench/%s%s_%s_t%d.png" % [id, label, Settings.get_tier_name(), int(t)]
	image.save_png(path)
	print("BENCH_SHOT " + ProjectSettings.globalize_path(path))

func record(t: float, delta: float) -> void:
	var vp = get_viewport().get_viewport_rid()
	var ms = delta * 1000.0
	frameMs.push_back(ms)
	rows.push_back("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%.3f,%d" % [
		t - WARMUP, ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		GameStats.goons(), GameStats.chunks(), lightCount, takeChunkMs(), occluderCount,
	])

#main-thread ms the world spent building or applying chunks since the last frame, if the TileManager
#keeps the count (chunkMs); reset after reading
func takeChunkMs() -> float:
	if not is_instance_valid(Root.levelRoot): return 0.0
	var tm = Root.levelRoot.get_node_or_null("TileManager")
	if tm == null || tm.get("chunkMs") == null: return 0.0
	var ms = float(tm.chunkMs)
	tm.chunkMs = 0.0
	return ms

func finish() -> void:
	started = false
	var preset = "current"
	if has_node("/root/Settings") && get_node("/root/Settings").has_method("get_tier_name"):
		preset = get_node("/root/Settings").get_tier_name()
	var size = DisplayServer.window_get_size()
	var tag = "%s_%s_%s_%dx%d" % [id + ("-notext" if stripText else "") + label, preset, RenderingServer.get_current_rendering_method(), size.x, size.y]
	var file = FileAccess.open("user://bench/" + tag + ".csv", FileAccess.WRITE)
	file.store_line("t,frame_ms,process_ms,physics_ms,gpu_ms,render_cpu_ms,draw_calls,nodes,goons,chunks,lights,chunk_ms,occluders")
	for row in rows: file.store_line(row)
	file.close()

	var sorted = frameMs.duplicate()
	sorted.sort()
	var n = sorted.size()
	var total = 0.0
	for ms in sorted: total += ms
	var worstCount = max(1, n / 100)
	var worstTotal = 0.0
	for i in worstCount: worstTotal += sorted[n - 1 - i]
	var over50 = 0
	var under175 = 0
	for ms in sorted:
		if ms > 50.0: over50 += 1
		if ms <= 17.5: under175 += 1
	var summary = {
		"tag": tag, "frames": n,
		"avg_fps": snappedf(1000.0 * n / total, 0.1),
		"low1_fps": snappedf(1000.0 * worstCount / worstTotal, 0.1),
		"p50_ms": snappedf(sorted[n / 2], 0.01),
		"p95_ms": snappedf(sorted[int(n * 0.95)], 0.01),
		"p99_ms": snappedf(sorted[int(n * 0.99)], 0.01),
		"max_ms": snappedf(sorted[n - 1], 0.01),
		"frames_over_50ms": over50,
		"pct_under_17_5ms": snappedf(100.0 * under175 / n, 0.1),
		"max_goons": maxColumn(8), "max_chunks": maxColumn(9), "end_nodes": int(rows[rows.size() - 1].split(",")[7]),
		"max_chunk_ms": snappedf(maxColumnF(11), 0.01), "max_occluders": maxColumn(12),
	}
	print("BENCH_SUMMARY " + JSON.stringify(summary))
	if is_instance_valid(Root.playerCar): print("BENCH_CAR health=%.0f condition=%s" % [Root.playerCar.health, str(Root.playerCar.condition)])
	var summaryPath = "user://bench/summary.csv"
	var isNew = not FileAccess.file_exists(summaryPath)
	var sfile = FileAccess.open(summaryPath, FileAccess.READ_WRITE if not isNew else FileAccess.WRITE)
	sfile.seek_end()
	if isNew: sfile.store_line(",".join(summary.keys()))
	sfile.store_line(",".join(summary.values().map(func(v): return str(v))))
	sfile.close()

	get_tree().quit()

func maxColumn(column: int) -> int:
	var best = 0
	for row in rows: best = max(best, int(row.split(",")[column]))
	return best

func maxColumnF(column: int) -> float:
	var best = 0.0
	for row in rows: best = maxf(best, float(row.split(",")[column]))
	return best
