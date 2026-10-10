extends Node

#One capture job (docs/PROMO.md): started by the Capture autoload (scripts/debug/capture.gd) from a job
#file that promo/tools/capture.py wrote. A job is one shot at one size. Its fields (all optional):
#  kind      "shot" (a run, filmed), "hand" (a person drives; the drive is taped), "stage" (an interface
#            piece, a title or a line-up on a plain backdrop: promo/stages/)
#  out       where the files go, without an extension (an absolute path outside the repo)
#  size      [w, h] pixels                     fps      60
#  record    "frames" (every filmed frame is saved as a PNG, with transparency, in <out>_frames/) or "none".
#            Sound: when the process was started with --write-movie <out>_sound.avi, Godot mixes the game's
#            audio offline into that file, in step with the frames (its own picture is fixed at 1600x900,
#            so only its sound is used); capture.py cuts it to the filmed frames.
#  level, car, mode, tier, seed, upgrades      what is played (as the playtest's options)
#  time      "day", "night" or "cycle" (the level's own)
#  driver    "ai", "ai:<profile>", "pattern:sine|circle|straight", "tape" (replays job.tape), "none" (parked)
#  tape      a taped drive (promo/tapes/*.tape); a hand session writes one
#  lead      seconds of driving (after GO) before filming    seconds   how long is filmed
#  hud       "full", "minimal" or "off" (CleanFeed)          god       true: the car can't be hurt or run dry
#  camera    a DirectorCamera rig                            at        "water", "wall", "station" or "x,y"
#  crowd     {"spawnTimer", "escalation", "progress", "giantOdds", "floor"} for the SpawnManager
#  events    [{"t": seconds from the start of filming, "do": ..., ...}] (see `fire`)
#  stills    [seconds from the start of filming, ...] saved as PNGs beside the clip
#  set       {"gfx/smoke": 2, ...} settings for this run only        audio  {"music": false, ...} buses heard
#While it runs it prints CAPTURE_* lines; at the end it writes <out>.json (the sidecar: the job, the
#frames filmed, where the car was on screen in each and what happened when) and quits.

const SCRATCH_SAVE := "user://capture/capture_save.tres"
const SHORT_SIDE := 900.0 #the logical canvas's short side, whatever the frame's shape (16:9 gives the game's 1600x900)
const DRIVE_ACTIONS := ["Accelerate", "Brake", "TurnLeft", "TurnRight"]
const PATTERNS := ["sine", "circle", "straight"]
const TAP_SECONDS := 0.4 #how often a driver that isn't a person taps a pausing screen's action key
const CHECK_TICKS := 60 #a taped drive notes where the car is this often, so a replay can say how far it drifts
const BOOKMARK_KEY := KEY_F9
const FINISH_KEY := KEY_F10

var args := {}
var job := {}
var kind := "shot"
var record := "none"
var fps := 60
var frameSize := Vector2i(1920, 1080)
var lead := 3.0
var seconds := 10.0
var driverKind := "ai"
var driverArg := ""
var car: OverheadCarBody2D
var aiDriver: AIDriver
var camera: DirectorCamera
var started := false
var worldSeen := false
var runTick := -1 #physics ticks since GO: the shot's clock and the tape's
var filming := false
var done := false
var firstFrame := -1 #Engine.get_frames_drawn() at the first filmed frame (the movie's frame number)
var framesFilmed := 0
var track: PackedFloat32Array = [] #x, y per filmed frame: the car on screen, 0 to 1
var happenings: Array = [] #{"frame", "t", "kind", "label"}
var pendingEvents: Array = []
var pendingStills: Array = []
var tapTimer := 0.0
var nightWanted := -1 #-1: the level's own cycle
var tape: Tape
var label: Label
var going := false #the start lamps have let the car go
var saves: Array = [] #WorkerThreadPool tasks still writing frames
var drift := 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var problem := readJob()
	if problem != "": return fail(problem)
	kind = str(job.get("kind", "shot"))
	record = str(job.get("record", "none"))
	fps = int(job.get("fps", 60))
	var size = job.get("size", [1920, 1080])
	frameSize = Vector2i(int(size[0]), int(size[1]))
	lead = float(job.get("lead", 3.0))
	seconds = float(job.get("seconds", 10.0))
	var driver := str(job.get("driver", "hand" if kind == "hand" else "ai"))
	driverKind = driver.get_slice(":", 0)
	driverArg = driver.get_slice(":", 1) if driver.contains(":") else ""
	pendingEvents = (job.get("events", []) as Array).duplicate()
	pendingEvents.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	pendingStills = (job.get("stills", []) as Array).duplicate()
	pendingStills.sort()
	nightWanted = {"day": 0, "night": 1}.get(str(job.get("time", "cycle")), -1)
	if job.has("out"): DirAccess.make_dir_recursive_absolute(str(job.out) + "_frames" if record == "frames" else str(job.out).get_base_dir())

	DirAccess.make_dir_recursive_absolute("user://capture")
	SaveManager.save_path = SCRATCH_SAVE
	Unlocks.allOpen = true
	Settings.on_menu_ready() #runs leave the menu before main2 reports it, which would count as a crashed boot
	Settings.set_value("display/pause_unfocused", false, false)
	Settings.set_value("display/render_res", "native", false) #never the 1600x900 cap or a RunView: full pixels
	if job.has("preset"): Settings.apply_preset_by_name(str(job.preset), false)
	for key in job.get("set", {}): Settings.set_value(key, job.set[key], false)
	TileManager.steady = bool(job.get("steady", true)) #the same run on any machine (a replay must match its tape)
	CleanFeed.quiet()
	applyAudio()
	#a hand drive must run at the tape's pace: one physics tick a frame, 60 frames a second
	if kind == "hand":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = fps
	setFrame(frameSize)
	get_tree().node_added.connect(onNodeAdded)
	RenderingServer.frame_post_draw.connect(onFrameDrawn)
	await get_tree().create_timer(0.5).timeout
	if kind == "stage": startStage()
	else: startLevel()
	started = true

func readJob() -> String:
	if not args.has("job"): return "needs --job=<file> (promo/tools/capture.py writes one)"
	var path := str(args.job)
	if not FileAccess.file_exists(path): return "no job file at " + path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return "the job file is not a JSON object: " + path
	job = parsed
	if str(job.get("driver", "")) == "tape" || job.get("kind", "") == "hand":
		if not job.has("tape"): return "a taped drive needs \"tape\": the file to read or write"
	return ""

func fail(message: String) -> void:
	push_error("CAPTURE " + message)
	print("CAPTURE_FAILED " + message)
	get_tree().quit(1)

#the window is the picture: borderless, the frame's pixels, on a logical canvas SHORT_SIDE on its short side
func setFrame(pixels: Vector2i) -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.borderless = true
	window.position = Vector2i.ZERO
	window.size = pixels
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = logicalFor(frameSize)

static func logicalFor(pixels: Vector2i) -> Vector2i:
	if pixels.x >= pixels.y: return Vector2i(roundi(SHORT_SIDE * pixels.x / pixels.y), int(SHORT_SIDE))
	return Vector2i(int(SHORT_SIDE), roundi(SHORT_SIDE * pixels.y / pixels.x))

#{"music": false} mutes the radio; any bus name works (docs/RADIO.md: music is its own bus)
func applyAudio() -> void:
	var heard: Dictionary = job.get("audio", {})
	for busName in heard:
		var found := false
		for bus in AudioServer.bus_count:
			if AudioServer.get_bus_name(bus).to_lower() == str(busName).to_lower():
				AudioServer.set_bus_mute(bus, not bool(heard[busName]))
				found = true
		if not found: print("CAPTURE_NOTE no audio bus called " + str(busName))

func startLevel() -> void:
	var id := Levels.resolve(str(job.get("level", "prairie")))
	if id == &"": return fail("unknown level " + str(job.get("level")))
	var modeName := str(job.get("mode", "countdown")).to_upper()
	if modeName == "COUNTDOWN": modeName = "GOONCRUSHER"
	if not Root.gameModes.has(modeName): return fail("unknown mode " + str(job.get("mode")))
	var data = SaveManager.playerData
	var carName := str(job.get("car", "sedan"))
	var carIndex := -1
	for i in data.cars.size():
		if data.cars[i].name == carName: carIndex = i
	if carIndex < 0: return fail("unknown car " + carName)
	var tier := ModeTiers.NAMES.map(func(n): return n.to_lower()).find(str(job.get("tier", "easy")).to_lower())
	if tier < 0: return fail("unknown tier " + str(job.get("tier")))
	data.selectedCar = carIndex
	data.gameMode = Root.gameModes[modeName]
	data.gameTier = tier
	data.selectedLevel = Levels.indexOf(id)
	var upgrades := int(job.get("upgrades", 0))
	var levels := {}
	if upgrades > 0:
		for stat in [Root.upgrade.ENGINE, Root.upgrade.STEERING, Root.upgrade.TRACTION, Root.upgrade.ARMOR,
				Root.upgrade.HEADLIGHTS, Root.upgrade.OIL, Root.upgrade.CLOVER, Root.upgrade.LUCK]:
			levels[stat] = upgrades
	data.cars[carIndex].upgrades = levels
	Root.selectedCar = data.cars[carIndex]
	if driverKind == "tape":
		tape = Tape.read(str(job.tape))
		if tape == null: return fail("can't read the tape " + str(job.tape))
	elif kind == "hand":
		tape = Tape.new()
		addLabel()
	seed(int(job.get("seed", 1)))
	Region.resetRegions()
	Root.isRunActive = false
	print("CAPTURE_RUN %s %s %s %s seed=%d driver=%s" % [id, modeName.to_lower(), carName, ModeTiers.NAMES[tier].to_lower(), int(job.get("seed", 1)), driverKind])
	get_tree().change_scene_to_node(RunView.wrap(load(Levels.scenePath(id)).instantiate()))

const STAGE := "res://promo/stages/stage.gd"

#job.stage: "menu" (the real main menu, on a save at job.start's point in the game), a res:// scene (a
#prize lab scene: tests/prize_lab/<game>.tscn), or one of the stage script's own (title, lineup ...)
func startStage() -> void:
	var what := str(job.get("stage", ""))
	var stage: Node
	if job.get("doors", false): Transition.forceShown = true #screen changes go behind the shutter, as the player sees them
	if what == "menu":
		var result := CareerStart.useScratchSave(str(job.get("start", "mid")), false, {})
		if result.begins_with("Error"): return fail(result)
		SaveManager.save_path = "user://capture/menu_save.tres" #what a tour buys never reaches the --play-start save it began from
		Settings.set_menu_context(true)
		get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	elif what.begins_with("res://"):
		if not ResourceLoader.exists(what): return fail("no scene at " + what)
		stage = load(what).instantiate()
		stage.ready.connect(dressLab.bind(stage), CONNECT_ONE_SHOT) #after its _ready has added them
		get_tree().change_scene_to_node(stage)
	else:
		stage = load(STAGE).new()
		stage.job = job
		get_tree().change_scene_to_node(stage)
	worldSeen = true
	going = true
	runTick = 0
	print("CAPTURE_STAGE " + what)

#a prize lab scene has its own dark fill and a corner panel of notes: the fill takes the job's backdrop, the panel goes
func dressLab(lab: Node) -> void:
	var backdrop := str(job.get("backdrop", "clear"))
	for child in lab.get_children():
		if child is CanvasLayer && child.layer == -10: child.visible = false
		elif child is CanvasLayer && child.layer == 30: child.visible = false
	load(STAGE).backdrop(lab, backdrop)

func onNodeAdded(node: Node) -> void:
	if node is TileManager: node.worldSeed = int(job.get("seed", 1))
	elif node is Level:
		seed(int(job.get("seed", 1))) #again, as late as possible: the frames in between use the RNG too
		if nightWanted >= 0 && node.def && node.def.rules.has("nightShare"): node.def.rules.erase("nightShare") #the shot sets the time of day
		if job.has("level-seconds"): node.seconds = float(job["level-seconds"])
	elif node is SpawnManager:
		var crowd: Dictionary = job.get("crowd", {})
		if crowd.has("floor"): node.floorOn = bool(crowd.floor)
		if crowd.has("spawnTimer"): node.spawnTimer = float(crowd.spawnTimer)
		if crowd.has("escalation"): node.escalationSpeed = float(crowd.escalation)
		if crowd.has("progress"): node.gameTimeProgress = float(crowd.progress)
		if crowd.has("giantOdds"): node.giantOdds = float(crowd.giantOdds)
	elif node is OverheadCarBody2D && node.isPlayer: node.ready.connect(onCarReady.bind(node), CONNECT_ONE_SHOT)
	elif node is GameUI: node.ready.connect(onHudReady.bind(node), CONNECT_ONE_SHOT)

func onCarReady(newCar: OverheadCarBody2D) -> void:
	car = newCar
	car.rewarded.connect(onRewarded)
	if driverKind == "ai":
		aiDriver = AIDriver.attach(car, {"sight": "human", "profile": driverArg if driverArg != "" else AIProfiles.BEST})

func onHudReady(ui: GameUI) -> void:
	#after the HUD's own _ready has added its widgets
	await get_tree().process_frame
	CleanFeed.apply(ui, str(job.get("hud", "full")))
	#"layer": "hud" films the HUD alone, over nothing: the run goes on unseen under it
	if str(job.get("layer", "")) == "hud":
		Root.levelRoot.visible = false
		get_tree().root.transparent_bg = true

func onRewarded(powerup: String, quantity) -> void:
	if powerup == "currentGoonsCrushed": note("crush", str(quantity))
	else: note("pickup", powerup)

#something an editor would cut on: kept with the frame it happened in
func note(what: String, text := "") -> void:
	if not filming: return
	happenings.push_back({"frame": framesFilmed, "t": snappedf(float(framesFilmed) / fps, 0.001), "kind": what, "label": text})

func _physics_process(delta):
	if not started || done: return
	if kind == "stage":
		if job.get("tap", false): drive(delta) #a prize game plays itself
		return
	if not is_instance_valid(car) || not is_instance_valid(Root.levelRoot): return
	if not worldSeen:
		if not Root.levelRoot.clockReady: return
		worldSeen = true
		if job.has("at"): placeCar(str(job.at))
		print("CAPTURE_WORLD clock=%.1f start=%s" % [Root.levelRoot.seconds, str(car.global_position)])
	if not going:
		if get_tree().paused: return #the start lamps are still counting; how long they take in ticks depends on the machine
		going = true
		print("CAPTURE_GO")
	runTick += 1
	#before the tape listens: a tape holds what was held going into each tick, as it is for a person's keys
	if driverKind in ["ai", "pattern", "none"] && not Root.levelRoot.hasEnded: drive(delta)
	if tape:
		if kind == "hand": tape.listen(runTick, car)
		else:
			var off := tape.play(runTick, car)
			drift = maxf(drift, off)
			if job.get("trace", false) && tape.checks.has(runTick): print("CAPTURE_DRIFT tick=%d px=%.1f paused=%s pos=%s" % [runTick, off, get_tree().paused, str(car.global_position)])
	if Root.levelRoot.hasEnded:
		releaseKeys()
		if kind == "hand": finish()
		return
	if job.get("god", false):
		car.health = 100.0
		car.fuel = 100.0
	holdTimeOfDay()

#the keys of a driver that isn't a person or a tape
func drive(delta: float) -> void:
	var wanted := []
	if get_tree().get_nodes_in_group("slotMachine").size() > 0:
		tapTimer -= delta
		if tapTimer <= 0.0:
			tapTimer = TAP_SECONDS
			wanted = [PickupMenu.ACT]
	elif driverKind == "pattern":
		match driverArg:
			"circle": wanted = ["Accelerate", "TurnRight"]
			"straight": wanted = ["Accelerate"]
			_: wanted = ["Accelerate", "TurnRight" if int(runTick / (2.0 * Engine.physics_ticks_per_second)) % 2 == 0 else "TurnLeft"]
	var held: Array = DRIVE_ACTIONS + [PickupMenu.ACT] if driverKind != "ai" && kind != "stage" else [PickupMenu.ACT] #the AI holds its own driving keys
	for action in held:
		if action in wanted && not Input.is_action_pressed(action): Input.action_press(action)
		elif not action in wanted && Input.is_action_pressed(action): Input.action_release(action)

func releaseKeys() -> void:
	for action in DRIVE_ACTIONS + [PickupMenu.ACT]:
		if Input.is_action_pressed(action): Input.action_release(action)

func holdTimeOfDay() -> void:
	if nightWanted < 0: return
	var timer = get_tree().get_first_node_in_group("runTimer")
	if is_instance_valid(timer): timer.reset = true #no cycle of its own
	var night := nightWanted == 1
	if Root.levelRoot.isDaytime == night && runTick > 30:
		Root.levelRoot.isDaytime = not night
		Root.levelRoot.setNighttime(night)

#"x,y", or beside the nearest water or wall, or on the station's approach (the bench's --at)
func placeCar(where: String) -> void:
	var map: WorldMap = Root.worldMap
	var target := Vector2.INF
	if where.contains(","):
		target = Vector2(float(where.get_slice(",", 0)), float(where.get_slice(",", 1)))
	elif where == "station":
		if not is_instance_valid(Root.station): return
		target = Root.station.global_position + Vector2(1500, 0)
		car.rotation = PI
	elif map != null:
		var start := map.coarseCell(car.global_position)
		for ring in range(2, 60):
			for dy in range(-ring, ring + 1):
				for dx in range(-ring, ring + 1):
					if maxi(absi(dx), absi(dy)) != ring || target != Vector2.INF: continue
					var cell := start + Vector2i(dx, dy)
					var i := map.cellIndex(cell)
					if i < 0 || map.flags[i] & WorldGen.BLOCKED == 0: continue
					if (map.terrain[i] == Root.terrain.WATER) != (where == "water"): continue
					for d in WorldGen.DIRS4:
						if target == Vector2.INF && map.cellReachable(cell + d * 2) && map.cellPassable(cell + d):
							target = WorldGen.cellCentre(cell + d)
							car.rotation = Vector2(-d).angle()
	if target == Vector2.INF: return
	car.global_position = target
	car.velocity = Vector2.ZERO

func _process(_delta):
	if not started || done || not worldSeen: return
	if kind == "stage": runTick += 1
	if runTick < 0: return
	var t := float(runTick) / Engine.physics_ticks_per_second #the clock is ticks, so a slow machine films the same run
	if kind == "hand":
		if Engine.max_fps != fps: Engine.max_fps = fps #Settings sets its own cap when a run starts; a taped drive must run at the tape's pace
		if is_instance_valid(label): label.text = "TAPING  %s   %d:%02d   F9 / R3 bookmark (%d)   F10 finish" % [str(job.tape).get_file(), int(t) / 60, int(t) % 60, tape.bookmarks.size()]
		if job.has("seconds") && t >= seconds: finish() #a tape of a set length (the kit's own tests: a pattern drives)
		return
	if not filming && t >= lead: startFilming()
	if not filming: return
	var shotTime := t - lead
	while not pendingEvents.is_empty() && float(pendingEvents[0].get("t", 0.0)) <= shotTime: fire(pendingEvents.pop_front())
	if shotTime >= seconds: finish()

func startFilming() -> void:
	filming = true
	if job.has("camera") && is_instance_valid(car): camera = DirectorCamera.attach(car, job.camera)
	if tape:
		for mark in tape.bookmarks: #a replay carries the driver's bookmarks into the sidecar
			var frame := int((float(mark.tick) / Engine.physics_ticks_per_second - lead) * fps)
			if frame >= 0 && frame < int(seconds * fps): happenings.push_back({"frame": frame, "t": snappedf(float(frame) / fps, 0.001), "kind": "bookmark", "label": str(mark.get("label", ""))})

#one frame is on screen: count it, note where the car is in it, keep it if this script is the recorder
func onFrameDrawn() -> void:
	if not filming || done: return
	if firstFrame < 0:
		firstFrame = Engine.get_frames_drawn()
		print("CAPTURE_FILMING first_frame=%d size=%dx%d" % [firstFrame, frameSize.x, frameSize.y])
	var spot := Vector2(0.5, 0.5)
	if is_instance_valid(car): spot = car.get_global_transform_with_canvas().origin / car.get_viewport().get_visible_rect().size
	track.push_back(snappedf(spot.x, 0.0001))
	track.push_back(snappedf(spot.y, 0.0001))
	var shotTime := float(framesFilmed) / fps
	var still: bool = not pendingStills.is_empty() && float(pendingStills[0]) <= shotTime
	if record == "frames" || still:
		var image := get_window().get_texture().get_image()
		if record == "frames": saveLater(image, "%s_frames/f%06d.png" % [str(job.out), framesFilmed])
		if still:
			var path := "%s_t%03d.png" % [str(job.out), int(float(pendingStills.pop_front()) * 10.0)]
			image.save_png(path)
			print("CAPTURE_STILL " + path)
	framesFilmed += 1

#PNG encoding is most of a frame's cost at 4K, so it runs on the worker threads, a few frames at a time
const SAVES_AT_ONCE := 12
func saveLater(image: Image, path: String) -> void:
	while saves.size() >= SAVES_AT_ONCE: WorkerThreadPool.wait_for_task_completion(saves.pop_front())
	saves.push_back(WorkerThreadPool.add_task(func(): image.save_png(path)))

#An event: "do" is one of
#  console   "line": any dev console command (night, day, god, heal, pickup <id>, give ..., win ...)
#  crowd     "goon": id (default the level's first), "count" (12), "ahead" px (1100), "side" px (0)
#  explode   "ahead" px (500), "side" px (0)
#  camera    a DirectorCamera rig: a new rig, or a change to the one in use
#  hud       "mode": full, minimal or off
#  press     "action": an input action tapped (ui_right, ui_accept, UseItem ...); "hold" seconds
#  click     "at": [x, y]: a left click there
#  mark      "label": a marker for the editor, nothing happens in the game
func fire(event: Dictionary) -> void:
	var what := str(event.get("do", ""))
	var heading := Vector2.from_angle(car.global_rotation) if is_instance_valid(car) else Vector2.RIGHT
	var spot: Vector2 = (car.global_position if is_instance_valid(car) else Vector2.ZERO) + heading * float(event.get("ahead", 1100.0 if what == "crowd" else 500.0)) + heading.orthogonal() * float(event.get("side", 0.0))
	match what:
		"console":
			var console = get_node_or_null("/root/Console")
			if console: print("CAPTURE_CONSOLE %s -> %s" % [event.get("line", ""), console.execute(str(event.get("line", "")))])
		"crowd":
			var goon := StringName(str(event.get("goon", "")))
			if goon == &"" && not Root.spawnManager.basicGoons.is_empty(): goon = StringName(str(Root.spawnManager.pickGoonId()))
			Root.spawnManager.spawnGroup(goon, spot, int(event.get("count", 12)))
		"explode": Root.levelRoot.explode(spot)
		"camera":
			if is_instance_valid(camera): camera.setRig(event)
			elif is_instance_valid(car): camera = DirectorCamera.attach(car, event)
		"hud": CleanFeed.apply(Root.playerRoot, str(event.get("mode", "full")))
		"press": #"action": held for "hold" seconds (default a tap)
			var action := str(event.get("action", "ui_accept"))
			Input.action_press(action)
			var pressed := InputEventAction.new()
			pressed.action = action
			pressed.pressed = true
			Input.parse_input_event(pressed)
			get_tree().create_timer(float(event.get("hold", 0.08))).timeout.connect(func():
				Input.action_release(action)
				var released := InputEventAction.new()
				released.action = action
				Input.parse_input_event(released))
		"click": #"at": [x, y] on the logical canvas (900 px on the short side)
			var at = event.get("at", [0, 0])
			for down in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = down
				click.position = Vector2(float(at[0]), float(at[1]))
				click.global_position = click.position
				Input.parse_input_event(click)
		"mark": pass
		_: print("CAPTURE_NOTE unknown event " + what)
	note("event" if what != "mark" else "mark", str(event.get("label", what)))

func _unhandled_key_input(event: InputEvent) -> void:
	if kind != "hand" || not event.is_pressed() || event.is_echo() || not worldSeen: return
	if event.keycode == BOOKMARK_KEY: bookmark()
	elif event.keycode == FINISH_KEY: finish()

func _input(event: InputEvent) -> void:
	if kind == "hand" && worldSeen && event is InputEventJoypadButton && event.pressed && event.button_index == JOY_BUTTON_RIGHT_STICK: bookmark()

func bookmark() -> void:
	tape.bookmarks.push_back({"tick": runTick, "label": "mark %d" % (tape.bookmarks.size() + 1)})
	print("CAPTURE_BOOKMARK tick=%d" % runTick)

func addLabel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	label = Label.new()
	label.position = Vector2(24, 12)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	add_child(layer)

func finish() -> void:
	if done: return
	done = true
	releaseKeys()
	if kind == "hand":
		var header := job.duplicate()
		for key in ["out", "record", "size", "kind", "stills", "events", "camera", "hud", "lead", "seconds"]: header.erase(key)
		header["driver"] = "tape"
		tape.write(str(job.tape), header, runTick)
		print("CAPTURE_TAPE %s ticks=%d bookmarks=%d" % [str(job.tape), runTick, tape.bookmarks.size()])
	elif job.has("out"):
		for task in saves: WorkerThreadPool.wait_for_task_completion(task)
		var sidecar := {"job": job, "fps": fps, "size": [frameSize.x, frameSize.y], "first_frame": firstFrame, "frames": framesFilmed,
			"track": Array(track), "events": happenings, "drift_px": snappedf(drift, 0.1),
			"crushed": car.currentGoonsCrushed if is_instance_valid(car) && "currentGoonsCrushed" in car else 0}
		var file := FileAccess.open(str(job.out) + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(sidecar))
		file.close()
	print("CAPTURE_DONE frames=%d first_frame=%d drift_px=%.1f" % [framesFilmed, firstFrame, drift])
	get_tree().quit()
