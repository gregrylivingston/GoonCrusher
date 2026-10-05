extends Node

#Benchmark harness (docs/PERFORMANCE_SETTINGS_PLAN.md section 9).
#Inert unless the user args include --bench=<id>, e.g.
#  Godot_console.exe --path . --windowed --resolution 1600x900 -- --bench=S2 --seconds=90
#Options: --seconds=N, --preset=potato|low|medium|high, --set=gfx/lighting:0;gfx/smoke:1 (any
#setting, not saved), --shot=5;30 (screenshots at those level seconds), --open-settings (S1 only),
#--notext.
#Writes a per-frame CSV and a summary row to user://bench/. Saves are redirected to a scratch
#copy, so a benchmark never changes player progress.

const LEVELS = "res://scene/level/levels/"
const SCENARIOS = {
	"S1": {"level":"", "seconds":60},
	"S2": {"level":"level_grass_1", "car":"sedan", "pattern":"sine", "seconds":90},
	"S3": {"level":"level_mud_3", "car":"police", "night":true, "pattern":"circle", "spawnTimer":2.0, "escalation":0.0, "seconds":90},
	"S4": {"level":"level_mud_3", "car":"police", "night":true, "pattern":"circle", "spawnTimer":1.0, "progress":200, "giantOdds":50, "seconds":150},
	"S5": {"level":"level_grass_1", "car":"sedan", "pattern":"none", "slots":5, "seconds":90},
	"S6": {"level":"level_grass_1", "car":"sedan", "pattern":"route", "seconds":600},
	"S7": {"level":"level_grass_1", "car":"sedan", "night":true, "pattern":"none", "purses":10, "seconds":30},
	#lighting parity: parked at night with no goons; use --headlights=N and --shot
	"SL": {"level":"level_grass_1", "car":"sedan", "night":true, "pattern":"none", "spawnTimer":9999.0, "escalation":0.0, "seconds":10},
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
var lightTimer: float = 0.0
var started: bool = false
var nightSet: bool = false
var slotPressTimer: float = 0.0
var slotsClaimed: int = 0
var pursesSpawned: int = 0
var stripText: bool = false
var shots: Array = []
var headlights: int = -1
var loadStart: int = 0
var loadReported := false
var longestLoadFrame: float = 0.0
var label: String = "" #--tag=name, added to output file names
var stuckTime: float = 0.0
var recoverTime: float = 0.0

func _ready():
	var args = parseArgs()
	if not args.has("bench"):
		queue_free()
		return
	id = args.bench
	print("BENCH_STARTUP_MS %d" % Time.get_ticks_msec()) #process start to the main menu being ready
	if not SCENARIOS.has(id):
		push_error("Unknown bench scenario " + id)
		get_tree().quit(1)
		return
	cfg = SCENARIOS[id]
	seconds = float(args.get("seconds", cfg.seconds))
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://bench")
	SaveManager.save_path = SCRATCH_SAVE
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
	data.gameMode = Root.gameModes.GOONCRUSHER
	Root.selectedCar = data.cars[data.selectedCar]
	seed(1337)
	loadStart = Time.get_ticks_msec()
	if parseArgs().has("via-menu") && is_instance_valid(Root.mainMenu):
		Root.mainMenu.startLevel(LEVELS + cfg.level + ".tscn") #the real menu path: threaded load
		return
	Region.resetRegions()
	get_tree().change_scene_to_file(LEVELS + cfg.level + ".tscn")

func onNodeAdded(node: Node) -> void:
	if stripText && node is CanvasItem && node.material is ShaderMaterial && node.material.shader && node.material.shader.code.contains("VERTEX_ID>>1"):
		node.material = null
	if node is landscapeGenerator:
		node.inputSeed = 1337
	elif node is SpawnManager:
		if cfg.has("spawnTimer"): node.spawnTimer = cfg.spawnTimer
		if cfg.has("escalation"): node.escalationSpeed = cfg.escalation
		if cfg.has("progress"): node.gameTimeProgress = cfg.progress
		if cfg.has("giantOdds"): node.giantOdds = cfg.giantOdds

func _physics_process(_delta):
	if not started || cfg.level == "" || not is_instance_valid(Root.levelRoot) || not is_instance_valid(Root.playerCar): return
	var car = Root.playerCar
	car.health = 100.0 #god mode
	car.fuel = 100.0
	drive(car)

func drive(car) -> void:
	var wanted = []
	if get_tree().get_nodes_in_group("slotMachine").size() > 0:
		#tap Accelerate to stop each reel and then claim
		slotPressTimer -= get_physics_process_delta_time()
		if slotPressTimer <= 0.0:
			slotPressTimer = 0.4
			wanted = ["Accelerate"]
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
	for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight"]:
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
	var t = levelTime if cfg.level != "" else elapsed
	if not shots.is_empty() && t >= shots[0]: screenshot(shots.pop_front())
	if t >= WARMUP: record(t, delta)
	if t >= seconds + WARMUP: finish()

func levelEvents() -> void:
	var timer = get_tree().get_first_node_in_group("runTimer")
	if is_instance_valid(timer): timer.reset = true #hold the current time of day
	if headlights >= 0 && Root.playerCar.headlights != headlights:
		Root.playerCar.headlights = headlights
		Root.playerCar.setHeadlightStrength()
	if cfg.get("night", false) && not nightSet && levelTime > 0.5:
		nightSet = true
		Root.levelRoot.isDaytime = false
		Root.levelRoot.setNighttime(true)
	if cfg.has("slots") && slotsClaimed < cfg.slots && levelTime > 4.0 && not get_tree().paused && get_tree().get_nodes_in_group("slotMachine").size() == 0:
		slotsClaimed += 1
		Root.levelRoot.add_child(load("res://scene/player/slots/slotMachine.tscn").instantiate())
		get_tree().paused = true
	if cfg.has("purses") && pursesSpawned < cfg.purses && levelTime > 5.0 + pursesSpawned && not get_tree().paused:
		pursesSpawned += 1
		var purse = Root.getSpecificPowerup(Root.upgrade.PURSE)
		purse.global_position = Root.playerCar.global_position
		Root.levelRoot.add_child(purse)

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
	rows.push_back("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d" % [
		t - WARMUP, ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		GameStats.goons(), GameStats.chunks(), lightCount,
	])

func finish() -> void:
	started = false
	var preset = "current"
	if has_node("/root/Settings") && get_node("/root/Settings").has_method("get_tier_name"):
		preset = get_node("/root/Settings").get_tier_name()
	var size = DisplayServer.window_get_size()
	var tag = "%s_%s_%s_%dx%d" % [id + ("-notext" if stripText else "") + label, preset, RenderingServer.get_current_rendering_method(), size.x, size.y]
	var file = FileAccess.open("user://bench/" + tag + ".csv", FileAccess.WRITE)
	file.store_line("t,frame_ms,process_ms,physics_ms,gpu_ms,render_cpu_ms,draw_calls,nodes,goons,chunks,lights")
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
	}
	print("BENCH_SUMMARY " + JSON.stringify(summary))
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
