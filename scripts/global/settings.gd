extends Node

#Player settings (docs/PERFORMANCE_SETTINGS_PLAN.md section 4).
#  user://settings.cfg  personal preferences, synced by Steam Cloud: [audio] [gameplay] [controls] [access]
#  user://graphics.cfg  per machine, not synced: [meta] [display] [gfx] [audio_perf]
#  user://override.cfg  only the renderer choice; read by the engine before anything else runs
#Read values with Settings.get_value("section/key"); change them with set_value, which applies
#the change, emits `changed` and saves 0.5 s later.

signal changed(key: String, value)

const VERSION := 1
const SETTINGS_PATH := "user://settings.cfg"
const GRAPHICS_PATH := "user://graphics.cfg"
const OVERRIDE_PATH := "user://override.cfg"
const GRAPHICS_SECTIONS := ["meta", "display", "gfx", "audio_perf"]

enum Tier { POTATO, LOW, MEDIUM, HIGH, CUSTOM }
const TIER_NAMES := ["Potato", "Low", "Medium", "High", "Custom"]

#preset-driven keys; index = Tier. Every other key has one default.
const PRESET := {
	"display/render_res":  ["cap900", "auto", "auto", "native"],
	"display/max_fps":     [60, 60, 0, 0],      #0 = match display, -1 = unlimited
	"display/menu_fps":    [30, 30, 0, 0],      #0 = same as game
	"gfx/text_fx":         [0, 1, 2, 3],        #flat, still, animated (8 slices), animated HD (16)
	"gfx/lighting":        [0, 1, 1, 2],
	"gfx/simple_cone":     [true, true, false, false],
	"gfx/smoke":           [0, 1, 2, 2],
	"gfx/tire_marks":      [0, 1, 2, 2],
	"gfx/pickup_fx":       [0, 0, 1, 1],
	"gfx/celebration":     [0, 1, 2, 2],
	"gfx/reward_fx":       [0, 1, 2, 2],
	"audio_perf/max_sfx":  [8, 12, 24, 24],
}

const DEFAULTS := {
	"meta/version": VERSION,
	"meta/tier": -1,                  #-1 = not detected yet
	"meta/recommended_tier": -1,
	"meta/adapter_id": "",
	"meta/adapter_name": "",
	"meta/boot_pending_count": 0,
	"meta/safe_mode_handled": false,
	"meta/detect_toast_shown": false,
	"meta/advisor_shown": false,

	"display/window_mode": 3,         #Window.MODE_WINDOWED 0, MODE_FULLSCREEN 3 (borderless), MODE_EXCLUSIVE_FULLSCREEN 4
	"display/window_size": Vector2i(1600, 900),
	"display/monitor": -1,            #-1 = whichever screen the game opens on
	"display/render_res": "auto",
	"display/vsync": 1,               #DisplayServer.VSYNC_DISABLED 0, ENABLED 1, ADAPTIVE 2
	"display/max_fps": 0,
	"display/menu_fps": 0,
	"display/pause_unfocused": true,
	"display/renderer": "standard",   #mirrors override.cfg so the menu can show it
	"display/perf_overlay": 0,

	"gfx/text_fx": 2,
	"gfx/lighting": 1,
	"gfx/simple_cone": false,
	"gfx/smoke": 2,
	"gfx/tire_marks": 2,
	"gfx/pickup_fx": 1,
	"gfx/celebration": 2,
	"gfx/reward_fx": 2,
	"audio_perf/max_sfx": 24,

	"audio/master": 0.8,
	"audio/music": 0.7,
	"audio/voice": 0.9,
	"audio/fx": 0.8,
	"audio/ui": 0.7,
	"audio/master_mute": false,
	"audio/music_mute": false,
	"audio/voice_mute": false,
	"audio/fx_mute": false,
	"audio/ui_mute": false,
	"audio/mute_unfocused": false,

	"gameplay/speed_units": "mph",
	"gameplay/show_timer": true,
	"gameplay/confirm_quit": true,

	"controls/deadzone": 0.5,
	"controls/vibration": 2,
	"controls/bindings": {},

	"access/reduce_motion": false,
	"access/reduce_flashing": false,
	"access/giant_style": 0,
	"access/giant_color": 0,
	"access/plain_text": false,
	"access/car_shake": true,
	"access/hud_scale": 1.0,
}

#allowed values for enumerated keys; numeric keys not listed here are clamped by RANGES
const OPTIONS := {
	"display/window_mode": [3, 4, 0],
	"display/render_res": ["native", "auto", "cap900", "720", "540"],
	"display/vsync": [1, 2, 0],
	"display/max_fps": [0, 30, 60, 120, 144, -1],
	"display/menu_fps": [30, 0],
	"display/renderer": ["standard", "compat"],
	"display/perf_overlay": [0, 1, 2],
	"gfx/text_fx": [0, 1, 2, 3],
	"gfx/lighting": [0, 1, 2],
	"gfx/smoke": [0, 1, 2],
	"gfx/tire_marks": [0, 1, 2],
	"gfx/pickup_fx": [0, 1],
	"gfx/celebration": [0, 1, 2],
	"gfx/reward_fx": [0, 1, 2],
	"audio_perf/max_sfx": [8, 12, 24],
	"gameplay/speed_units": ["mph", "kmh"],
	"controls/vibration": [0, 1, 2],
	"access/giant_style": [0, 1, 2],
	"access/giant_color": [0, 1, 2, 3, 4],
}
const RANGES := {
	"audio/master": [0.0, 1.0], "audio/music": [0.0, 1.0], "audio/voice": [0.0, 1.0],
	"audio/fx": [0.0, 1.0], "audio/ui": [0.0, 1.0],
	"controls/deadzone": [0.2, 0.8],
	"access/hud_scale": [0.8, 1.3],
	"meta/tier": [-1, 4], "meta/recommended_tier": [-1, 3],
	"meta/boot_pending_count": [0, 100],
}
const AUDIO_BUSES := {"master":"Master", "music":"Music", "voice":"Voice", "fx":"FX", "ui":"UI"}
#giant marker tints. Red is the authored HDR tint: white-hot by day, a red glow under headlights.
const GIANT_COLORS := [Color(128.498, 1, 1), Color(128.498, 128.498, 1), Color(1, 128.498, 128.498), Color(128.498, 1, 128.498), Color(128.498, 128.498, 128.498)]
#actions whose deadzone follows controls/deadzone
const STICK_ACTIONS := ["ui_left", "ui_right", "ui_up", "ui_down", "TurnLeft", "TurnRight", "Accelerate", "Brake"]

var values := {}
var settingsFile := ConfigFile.new()
var graphicsFile := ConfigFile.new()
var dirtySettings := false
var dirtyGraphics := false
var saveTimer: Timer
var perfOverlay: PerfOverlay

#the settings overlay and dialogs push/pop this; main2, the HUD and the pause menu ignore input while it is open
var menuDepth := 0
var menu_open: bool:
	get: return menuDepth > 0
var needs_volume_import := false
var safe_mode_prompt := false     #ask about safe mode once the menu is up
var detect_toast_pending := false
var inMenu := false               #main menu or pause menu showing; drives display/menu_fps
var cliWindow := false            #window flags given on the command line win over saved settings
var cliVsync := false
var cliFps := false
var applyingPreset := false
var sessionOnly := {}             #key -> value on disk, for session values (safe mode, persist = false) that must not reach the file
var focusMuted := false


func _enter_tree():
	process_mode = Node.PROCESS_MODE_ALWAYS
	#autoload _ready runs after the main scene is in the tree, so hook node_added here
	get_tree().node_added.connect(onNodeAdded)
	#Godot consumes its own flags (--windowed, --resolution, --disable-vsync, --max-fps) before
	#scripts can see them, so command-line overrides are user args after `--`:
	#  -- --window=1600x900   windowed at that size, saved window settings ignored
	#  -- --uncapped          V-Sync off and no frame cap, for benchmarks
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	cliWindow = cliWindowSize() != Vector2i.ZERO
	cliVsync = args.has("--uncapped")
	cliFps = args.has("--uncapped")
	if cliVsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	if args.has("--reset-graphics"):
		DirAccess.remove_absolute(GRAPHICS_PATH)
		DirAccess.remove_absolute(OVERRIDE_PATH)
	load_all()
	bootSafety(args)
	detectIfNeeded()
	ensureDefaultActions()
	for action in REBINDABLE: defaultBindings[action] = InputMap.action_get_events(action)
	apply_all()
	saveTimer = Timer.new()
	saveTimer.one_shot = true
	saveTimer.wait_time = 0.5
	saveTimer.timeout.connect(save_now)
	add_child(saveTimer)

func _ready():
	for node in get_tree().root.find_children("*", "Node2D", true, false): onNodeAdded(node)
	GameStats.registerMonitors(get_tree())
	perfOverlay = PerfOverlay.new()
	add_child(perfOverlay)
	perfOverlay.setMode(get_value("display/perf_overlay"))
	get_window().size_changed.connect(applyRenderResolution)
	if cliWindow:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = cliWindowSize()
	applyRenderResolution()
	set_process(false)

func _exit_tree():
	save_now()

func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST: save_now()
		NOTIFICATION_APPLICATION_FOCUS_OUT: onFocusChanged(false)
		NOTIFICATION_APPLICATION_FOCUS_IN: onFocusChanged(true)

func _unhandled_input(event):
	if event is InputEventKey && event.pressed && not event.echo && event.keycode == KEY_F3:
		set_value("display/perf_overlay", (get_value("display/perf_overlay") + 1) % 3)


#--- values -------------------------------------------------------------------------------

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func get_default(key: String) -> Variant:
	if PRESET.has(key):
		var tier = get_value("meta/recommended_tier")
		if tier < 0: tier = Tier.MEDIUM
		return PRESET[key][tier]
	return DEFAULTS[key]

func set_value(key: String, value, persist := true) -> void:
	value = validate(key, value)
	if value == null: return
	var old = values.get(key)
	values[key] = value
	#persist = false (benchmarks, tests, previews) must never reach the file: remember the saved value
	if persist: sessionOnly.erase(key)
	elif not sessionOnly.has(key): sessionOnly[key] = old
	if PRESET.has(key) && not applyingPreset && get_value("meta/tier") != Tier.CUSTOM && value != old:
		if not persist && not sessionOnly.has("meta/tier"): sessionOnly["meta/tier"] = values["meta/tier"]
		values["meta/tier"] = Tier.CUSTOM
		if persist:
			sessionOnly.erase("meta/tier")
			markDirty("meta/tier")
		changed.emit("meta/tier", Tier.CUSTOM)
	applyKey(key)
	if old != value: changed.emit(key, value)
	if persist: markDirty(key)

func apply_preset(tier: int, persist := true) -> void:
	applyingPreset = true
	for key in PRESET: set_value(key, PRESET[key][tier], persist)
	applyingPreset = false
	if persist: sessionOnly.erase("meta/tier")
	elif not sessionOnly.has("meta/tier"): sessionOnly["meta/tier"] = values["meta/tier"]
	values["meta/tier"] = tier
	changed.emit("meta/tier", tier)
	if persist: markDirty("meta/tier")

func apply_preset_by_name(tierName: String, persist := true) -> void:
	for i in 4:
		if TIER_NAMES[i].to_lower() == tierName.to_lower(): apply_preset(i, persist)

func get_tier_name() -> String:
	var tier = get_value("meta/tier")
	return TIER_NAMES[tier] if tier >= 0 else "Unset"

#accessibility options override presets without relabelling them
func text_quality() -> int:
	if get_value("access/plain_text"): return 0
	return get_value("gfx/text_fx")

func celebration_level() -> int:
	var level = get_value("gfx/celebration")
	if get_value("access/reduce_flashing"): level = 0
	elif get_value("access/reduce_motion"): level = min(level, 1)
	return level

func reduce_motion() -> bool:
	return get_value("access/reduce_motion")

func validate(key: String, value) -> Variant:
	if not DEFAULTS.has(key): return null
	var def = DEFAULTS[key]
	if typeof(def) == TYPE_FLOAT && typeof(value) == TYPE_INT: value = float(value)
	elif typeof(def) == TYPE_INT && typeof(value) == TYPE_FLOAT: value = int(value)
	elif typeof(def) == TYPE_VECTOR2I && typeof(value) == TYPE_VECTOR2: value = Vector2i(value)
	if typeof(value) != typeof(def): return null
	if OPTIONS.has(key) && not OPTIONS[key].has(value): return null
	if RANGES.has(key): value = clamp(value, RANGES[key][0], RANGES[key][1])
	if key == "display/window_size": value = Vector2i(clampi(value.x, 640, 7680), clampi(value.y, 360, 4320))
	return value

func markDirty(key: String) -> void:
	if fileFor(key) == graphicsFile: dirtyGraphics = true
	else: dirtySettings = true
	if is_instance_valid(saveTimer) && saveTimer.is_inside_tree(): saveTimer.start()

func fileFor(key: String) -> ConfigFile:
	return graphicsFile if GRAPHICS_SECTIONS.has(key.get_slice("/", 0)) else settingsFile


#--- load and save ------------------------------------------------------------------------

func load_all() -> void:
	var hadSettings = settingsFile.load(SETTINGS_PATH) == OK
	graphicsFile.load(GRAPHICS_PATH)
	needs_volume_import = not hadSettings
	values = DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		var file = fileFor(key)
		var section = key.get_slice("/", 0)
		var field = key.get_slice("/", 1)
		if not file.has_section_key(section, field): continue
		var value = validate(key, file.get_value(section, field))
		if value != null: values[key] = value #a wrong type keeps the default
	#keys added by later versions take the stored tier's preset value
	var tier = values["meta/tier"]
	for key in PRESET:
		var section = key.get_slice("/", 0)
		if not graphicsFile.has_section_key(section, key.get_slice("/", 1)) && tier >= 0 && tier < Tier.CUSTOM:
			values[key] = PRESET[key][tier]
	migrate(int(graphicsFile.get_value("meta", "version", VERSION)))
	values["meta/version"] = VERSION

func migrate(_fromVersion: int) -> void:
	pass #add `if fromVersion < N:` blocks here when the format changes

#writes only keys this version knows; unknown keys already in the files are left untouched
func save_now() -> void:
	if not dirtySettings && not dirtyGraphics: return
	for key in values:
		var file = fileFor(key)
		if (file == settingsFile && not dirtySettings) || (file == graphicsFile && not dirtyGraphics): continue
		var value = sessionOnly.get(key, values[key])
		file.set_value(key.get_slice("/", 0), key.get_slice("/", 1), value)
	if dirtySettings: settingsFile.save(SETTINGS_PATH)
	if dirtyGraphics: graphicsFile.save(GRAPHICS_PATH)
	dirtySettings = false
	dirtyGraphics = false

#called by SaveManager after it loads an existing demo-era save that still carries volumes
func import_legacy_volume(volume: Dictionary) -> void:
	if not needs_volume_import: return
	needs_volume_import = false
	var pairs = [["master", "master"], ["music", "music"], ["voice", "voice"], ["fx", "fx"], ["fx", "ui"]]
	for pair in pairs:
		var db = float(volume.get(pair[0], 0))
		set_value("audio/" + pair[1], legacy_volume(db))
		if db <= -39.0: set_value("audio/" + pair[1] + "_mute", true)
	save_now()

#old saves stored bus dB (-40..+10, -500 = muted); sliders are p with dB = linear_to_db(p*p), max 0 dB
static func legacy_volume(db: float) -> float:
	if db <= -39.0: return 0.0
	return snappedf(sqrt(clampf(db_to_linear(db), 0.0, 1.0)), 0.05)


#--- boot -----------------------------------------------------------------------------------

func bootSafety(args) -> void:
	if DisplayServer.get_name() == "headless": return #tests and imports never reach the menu; they are not crashed boots
	var pending = get_value("meta/boot_pending_count")
	var askedFor = args.has("--safe-mode")
	if not askedFor: values["meta/safe_mode_handled"] = false
	if askedFor && not get_value("meta/safe_mode_handled"):
		values["meta/safe_mode_handled"] = true
		enterSafeMode()
	values["meta/boot_pending_count"] = pending + 1
	dirtyGraphics = true
	save_now() #must hit the disk now, or a crash during load would not be counted
	if pending >= 2 && not askedFor:
		#two boots in a row never reached the menu: use safe values for this session only and ask
		safe_mode_prompt = true
		var safe = {"meta/tier": Tier.POTATO, "display/window_mode": Window.MODE_WINDOWED}
		for key in PRESET: safe[key] = PRESET[key][Tier.POTATO]
		for key in safe:
			sessionOnly[key] = values[key]
			values[key] = safe[key]

func enterSafeMode() -> void:
	apply_preset(Tier.POTATO, true)
	values["display/window_mode"] = Window.MODE_WINDOWED
	dirtyGraphics = true
	setRenderer("compat")
	save_now()
	if RenderingServer.get_current_rendering_method() != "gl_compatibility": restart()

#main2 calls this once the menu is on screen
func on_menu_ready() -> void:
	if get_value("meta/boot_pending_count") != 0:
		values["meta/boot_pending_count"] = 0
		dirtyGraphics = true
		save_now()

func accept_safe_mode(accept: bool) -> void:
	safe_mode_prompt = false
	sessionOnly.clear()
	if accept:
		enterSafeMode()
	else:
		load_all() #drop the session-only safe values
		apply_all()

func detect_tier() -> int:
	var type = RenderingServer.get_video_adapter_type()
	var adapter = RenderingServer.get_video_adapter_name().to_lower()
	var cores = OS.get_processor_count()
	var fellBack = RenderingServer.get_current_rendering_method() != ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if type == RenderingDevice.DEVICE_TYPE_CPU || fellBack || cores <= 2 \
			|| adapter.contains("llvmpipe") || adapter.contains("basic render") || adapter.contains("swiftshader"):
		return Tier.POTATO
	if type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		return Tier.HIGH if cores >= 6 else Tier.MEDIUM
	if RegEx.create_from_string("intel.*\\bu?hd graphics").search(adapter) || cores <= 4:
		return Tier.LOW #matches both "Intel(R) HD Graphics 620" and the ANGLE name
	return Tier.MEDIUM

#vendor plus model, normalised so Vulkan and ANGLE names of the same GPU match
static func adapterId(adapterName: String, vendor: String) -> String:
	var n = adapterName.to_lower()
	var angle = RegEx.create_from_string("^angle \\([^,]*,\\s*(.*?)(\\s*\\(0x[0-9a-f]+\\))?\\s*(direct3d|vulkan|opengl|metal).*$").search(n)
	if angle: n = angle.get_string(1)
	for junk in ["(r)", "(tm)", "®", "™"]: n = n.replace(junk, "")
	n = RegEx.create_from_string("\\s+").sub(n.strip_edges(), " ", true)
	#ANGLE reports the vendor as "Google Inc. (Intel)"; Vulkan reports "Intel"
	var v = vendor.to_lower().strip_edges()
	var inner = RegEx.create_from_string("\\(([^)]+)\\)\\s*$").search(v)
	if inner: v = inner.get_string(1).strip_edges()
	return v + ":" + n

func detectIfNeeded() -> void:
	if DisplayServer.get_name() == "headless": return #tests and imports: no GPU to detect, and the player's tier must stand
	var id = adapterId(RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor())
	if get_value("meta/tier") >= 0 && id == get_value("meta/adapter_id"): return
	var tier = detect_tier()
	values["meta/recommended_tier"] = tier
	values["meta/adapter_id"] = id
	values["meta/adapter_name"] = RenderingServer.get_video_adapter_name()
	if get_value("meta/tier") != Tier.CUSTOM:
		applyingPreset = true
		for key in PRESET: values[key] = PRESET[key][tier]
		applyingPreset = false
		values["meta/tier"] = tier
		detect_toast_pending = not get_value("meta/detect_toast_shown")
		calibrate_pending = tier > Tier.POTATO
	dirtyGraphics = true

#First-run calibration. The detected tier is a guess from the adapter's name and type, so the
#first time the menu is up its GPU time is measured, and the tier steps down once if this GPU is
#clearly slower than the tier assumes. The menu costs the same GPU time at every preset (the
#reference Intel HD 620 takes a median 3.8 ms at 1080p on all four), so it measures GPU speed:
#  Low steps to Potato at twice the HD 620's time (a GPU half as fast);
#  Medium steps to Low unless the GPU beats the HD 620 by a quarter;
#  High steps to Medium unless the GPU is at least twice as fast as the HD 620.
#Times are scaled to 1080p by pixel count. Calibration runs only on the standard renderer.
const REFERENCE_MENU_GPU_MS = 3.8
const CALIBRATION_LIMIT = [0.0, 2.0, 0.8, 0.5] #per tier, times REFERENCE_MENU_GPU_MS
const CALIBRATION_SKIP = 30     #frames left out while shaders compile
const CALIBRATION_FRAMES = 120
var calibrate_pending := false
var calibrated_down := false    #the toast says the tier was lowered after measuring

#main2 awaits this before it shows the detection toast
func calibrate_if_needed() -> void:
	if not calibrate_pending || safe_mode_prompt: return
	calibrate_pending = false
	#the reference was measured on Vulkan; Compatibility (ANGLE) does report GPU time, but it is slower
	#by design, so measuring there would push every machine down a tier
	if RenderingServer.get_current_rendering_method() == "gl_compatibility": return
	var vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var samples := PackedFloat32Array()
	for i in CALIBRATION_SKIP + CALIBRATION_FRAMES:
		await get_tree().process_frame
		if not is_instance_valid(Root.mainMenu) || menu_open: return #left the menu or opened settings: keep the detected tier
		if i >= CALIBRATION_SKIP: samples.push_back(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	samples.sort()
	var pixels = Vector2(get_viewport().get_texture().get_size())
	var median = samples[samples.size() / 2] * (1920.0 * 1080.0) / maxf(pixels.x * pixels.y, 1.0)
	var tier = get_value("meta/tier")
	if median > 0.0 && tier > Tier.POTATO && tier < Tier.CUSTOM && median > CALIBRATION_LIMIT[tier] * REFERENCE_MENU_GPU_MS:
		values["meta/recommended_tier"] = tier - 1
		apply_preset(tier - 1)
		calibrated_down = true
	print("Settings: calibration median GPU %.2f ms at tier %d -> tier %d" % [median, tier, get_value("meta/tier")])

func ensureDefaultActions() -> void:
	#controller Start pauses; LB/RB (and Q/E) switch settings tabs
	addEventIfMissing("ui_menu", joyButton(JOY_BUTTON_START))
	if not InputMap.has_action("ui_tab_prev"): InputMap.add_action("ui_tab_prev")
	if not InputMap.has_action("ui_tab_next"): InputMap.add_action("ui_tab_next")
	addEventIfMissing("ui_tab_prev", joyButton(JOY_BUTTON_LEFT_SHOULDER))
	addEventIfMissing("ui_tab_next", joyButton(JOY_BUTTON_RIGHT_SHOULDER))
	addEventIfMissing("ui_tab_prev", keyEvent(KEY_Q))
	addEventIfMissing("ui_tab_next", keyEvent(KEY_E))
	if not InputMap.has_action("ui_reset_tab"): InputMap.add_action("ui_reset_tab")
	addEventIfMissing("ui_reset_tab", joyButton(JOY_BUTTON_Y))

static func joyButton(button: int) -> InputEventJoypadButton:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	return event

static func keyEvent(key: int) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = key
	return event

static func addEventIfMissing(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)


#--- applying values ------------------------------------------------------------------------

func apply_all() -> void:
	for key in values: applyKey(key)

func applyKey(key: String) -> void:
	match key.get_slice("/", 0):
		"audio": applyAudio()
		"display":
			match key:
				"display/window_mode", "display/window_size", "display/monitor": applyWindow()
				"display/render_res": applyRenderResolution()
				"display/vsync":
					if not cliVsync: DisplayServer.window_set_vsync_mode(get_value("display/vsync"))
					applyFrameCap()
				"display/max_fps", "display/menu_fps": applyFrameCap()
				"display/perf_overlay": if is_instance_valid(perfOverlay): perfOverlay.setMode(get_value(key))
		"gfx", "access":
			applyShaderGlobals()
			if key == "gfx/lighting" || key == "gfx/simple_cone": applyLighting()
		"controls":
			if key == "controls/bindings": applyBindings()
			if key == "controls/deadzone":
				for action in STICK_ACTIONS:
					if InputMap.has_action(action): InputMap.action_set_deadzone(action, get_value(key))

#global uniforms declared in project.godot [shader_globals]
func applyShaderGlobals() -> void:
	var text = text_quality()
	RenderingServer.global_shader_parameter_set("gc_text_quality", mini(text, 2))
	RenderingServer.global_shader_parameter_set("gc_text_max_slices", 16 if text == 3 else 8)
	RenderingServer.global_shader_parameter_set("gc_motion", 0.0 if reduce_motion() else 1.0)
	RenderingServer.global_shader_parameter_set("gc_pickup_fx", get_value("gfx/pickup_fx"))
	var style = get_value("access/giant_style")
	if style == 0 && reduce_motion(): style = 1 #Reduce Motion: the pulse becomes steady
	RenderingServer.global_shader_parameter_set("gc_giant_style", style)
	var tint: Color = GIANT_COLORS[get_value("access/giant_color")]
	if get_value("access/reduce_flashing"):
		#hue-preserving 0-1 colour: clamping the HDR tint instead would turn giants white
		var peak = maxf(tint.r, maxf(tint.g, tint.b))
		tint = Color(tint.r / peak, tint.g / peak, tint.b / peak)
	RenderingServer.global_shader_parameter_set("gc_giant_color", tint)
	RenderingServer.global_shader_parameter_set("gc_flash", 0.3 if get_value("access/reduce_flashing") else 1.0)

func applyAudio() -> void:
	for channel in AUDIO_BUSES:
		var bus = AudioServer.get_bus_index(AUDIO_BUSES[channel])
		if bus < 0: continue
		var p: float = get_value("audio/" + channel)
		AudioServer.set_bus_volume_db(bus, linear_to_db(p * p) if p > 0.0 else -80.0)
		var muted = p <= 0.0 || get_value("audio/" + channel + "_mute") || (channel == "master" && focusMuted)
		AudioServer.set_bus_mute(bus, muted)

func applyWindow() -> void:
	if cliWindow || not is_inside_tree(): return
	var window = get_window()
	var monitor = get_value("display/monitor")
	if monitor >= 0 && monitor < DisplayServer.get_screen_count() && window.current_screen != monitor:
		window.current_screen = monitor
	var mode = get_value("display/window_mode")
	if window.mode != mode: window.mode = mode
	if mode == Window.MODE_WINDOWED:
		var usable = DisplayServer.screen_get_usable_rect(window.current_screen)
		var size = get_value("display/window_size")
		size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
		window.size = size
		window.position = usable.position + (usable.size - size) / 2

func applyRenderResolution() -> void:
	if not is_inside_tree(): return
	var window = get_window()
	var base = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var cap = false
	match get_value("display/render_res"):
		"cap900": cap = window.size.x > base.x || window.size.y > base.y
		"auto", "720", "540": cap = window.size.x * window.size.y > 1920 * 1080 #720/540 apply to runs (RunView); menus behave as Auto
	#viewport mode draws at 1600x900 and scales up; the logical canvas stays 1600x900 either way
	var mode = Window.CONTENT_SCALE_MODE_VIEWPORT if cap else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if window.content_scale_mode != mode: window.content_scale_mode = mode

func applyFrameCap() -> void:
	if cliFps: return
	var cap = get_value("display/max_fps")
	if inMenu && get_value("display/menu_fps") > 0: cap = get_value("display/menu_fps")
	elif cap == 0: #match display
		var vsyncOn = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		var refresh = DisplayServer.screen_get_refresh_rate()
		cap = 0 if vsyncOn || refresh <= 0.0 else int(round(refresh))
	elif cap < 0: cap = 0
	Engine.max_fps = cap

func push_menu() -> void:
	menuDepth += 1

#released one frame late so the key that closed a menu is not also seen by the menu beneath it
func pop_menu() -> void:
	await get_tree().process_frame
	menuDepth = maxi(menuDepth - 1, 0)

#explicit signals only: main2 entered or left, pause menu opened or closed.
#never called for slot machine, countdown or summary pauses.
func set_menu_context(isMenu: bool) -> void:
	inMenu = isMenu
	applyFrameCap()

func onFocusChanged(focused: bool) -> void:
	if get_value("audio/mute_unfocused"):
		focusMuted = not focused
		applyAudio()
	if not focused && get_value("display/pause_unfocused") && Root.isRunActive && is_instance_valid(Root.playerRoot):
		Root.playerRoot.openPause()


#--- lighting -------------------------------------------------------------------------------
#Every Light2D and LightOccluder2D is registered as it enters the tree. Its authored shadow,
#enabled and visible state is kept in metadata and only ever ANDed with the setting, so a
#light that never cast shadows never starts to.
#  High (2):   as authored, shadow atlas 2048
#  Medium (1): as authored except pickup-flyer lights off; atlas 1024. Night stealth is unchanged:
#              every occluder stays, so goons behind rocks and goons stay hidden.
#  Low (0):    no shadows, no occluders, tail/pickup/explosion/lamp-post lights off and the central
#              station light enlarged to light the yard; atlas 256. Affects gameplay.
#At every level the headlight cone (or the baked Simple Cone) still scales with the Headlights stat.
const SHADOW_ATLAS = [256, 1024, 2048]
#the baked cone (texture/fx/headlight_cone.png, scripts/debug/bake_headlight_cone.gd) matched the five
#lamps within 1% brightness at Headlights 1 and 100. Set false to hide the option again.
const SIMPLE_CONE_READY = true
const STATION_LIGHT_LOW_SCALE = 2.5

func onNodeAdded(node: Node) -> void:
	if node is Light2D:
		if not node.has_meta("gc_role"):
			node.set_meta("gc_shadow", node.shadow_enabled)
			node.set_meta("gc_enabled", node.enabled)
			node.set_meta("gc_scale", node.texture_scale if node is PointLight2D else 1.0)
			node.set_meta("gc_role", lightRole(node))
		node.add_to_group("gc_light")
		applyLight(node)
	elif node is LightOccluder2D:
		if not node.has_meta("gc_vis"): node.set_meta("gc_vis", node.visible)
		node.add_to_group("gc_occluder")
		node.visible = node.get_meta("gc_vis") && get_value("gfx/lighting") >= 1

static func lightRole(light: Node) -> String:
	var parent = light.get_parent()
	if light.name == "simpleCone": return "cone"
	if parent.name == "headlights": return "headlamp"
	if parent.name == "taillamps": return "tail"
	if parent is Powerup: return "pickup"
	if parent.scene_file_path.contains("explosion"): return "explosion"
	if parent.name == "Lights": return "station"
	if parent.get_parent() && parent.get_parent().name == "Lights": return "post"
	return "other"

func applyLight(light: Light2D) -> void:
	var level = get_value("gfx/lighting")
	var role = light.get_meta("gc_role")
	var on = light.get_meta("gc_enabled")
	if level == 0 && role in ["tail", "pickup", "explosion", "post"]: on = false
	if level == 1 && role == "pickup": on = false
	#the Simple Headlight Cone replaces the five headlamps when it is turned on
	var cone = get_value("gfx/simple_cone") && SIMPLE_CONE_READY
	if role == "headlamp" && cone: on = false
	if role == "cone": on = cone
	light.enabled = on
	light.shadow_enabled = light.get_meta("gc_shadow") && level >= 1
	if role == "station" && light is PointLight2D:
		light.texture_scale = light.get_meta("gc_scale") * (STATION_LIGHT_LOW_SCALE if level == 0 else 1.0)

func applyLighting() -> void:
	if not is_inside_tree(): return
	RenderingServer.canvas_set_shadow_texture_size(SHADOW_ATLAS[get_value("gfx/lighting")])
	for light in get_tree().get_nodes_in_group("gc_light"): applyLight(light)
	for occluder in get_tree().get_nodes_in_group("gc_occluder"):
		occluder.visible = occluder.get_meta("gc_vis") && get_value("gfx/lighting") >= 1


#--- key and button bindings ----------------------------------------------------------------
#Each rebindable action has two keyboard slots and one controller slot. Only actions the player
#changed are stored in controls/bindings; the rest keep the project defaults.
const REBINDABLE := {"Accelerate":"Accelerate", "Brake":"Brake", "TurnLeft":"Steer Left", "TurnRight":"Steer Right", "ui_menu":"Pause"}
const JOY_BUTTON_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-Up", "D-Down", "D-Left", "D-Right"]
const JOY_AXIS_NAMES := ["LS", "LS", "RS", "RS", "LT", "RT"]
var defaultBindings := {}

#[key1, key2, pad] events for an action; null where a slot is empty
func binding_slots(action: String) -> Array:
	var keys = []
	var pad = null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: keys.push_back(event)
		elif pad == null && (event is InputEventJoypadButton || event is InputEventJoypadMotion): pad = event
	return [keys[0] if keys.size() > 0 else null, keys[1] if keys.size() > 1 else null, pad]

static func event_name(event: InputEvent) -> String:
	if event == null: return "-"
	if event is InputEventKey:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventJoypadButton:
		return JOY_BUTTON_NAMES[event.button_index] if event.button_index < JOY_BUTTON_NAMES.size() else "Button %d" % event.button_index
	if event is InputEventJoypadMotion:
		var axis = JOY_AXIS_NAMES[event.axis] if event.axis < JOY_AXIS_NAMES.size() else "Axis %d" % event.axis
		if event.axis >= 4: return axis
		var horizontal = event.axis == JOY_AXIS_LEFT_X || event.axis == JOY_AXIS_RIGHT_X
		var direction = ("Right" if event.axis_value > 0 else "Left") if horizontal else ("Down" if event.axis_value > 0 else "Up")
		return axis + " " + direction
	return event.as_text()

static func serialize(event: InputEvent) -> Dictionary:
	if event is InputEventKey: return {"key": event.physical_keycode if event.physical_keycode != 0 else event.keycode}
	if event is InputEventJoypadButton: return {"button": event.button_index}
	if event is InputEventJoypadMotion: return {"axis": event.axis, "value": signf(event.axis_value)}
	return {}

static func deserialize(data: Dictionary) -> InputEvent:
	if data.has("key"): return keyEvent(int(data.key))
	if data.has("button"): return joyButton(int(data.button))
	if data.has("axis"):
		var event = InputEventJoypadMotion.new()
		event.device = -1
		event.axis = int(data.axis)
		event.axis_value = float(data.value)
		return event
	return null

static func sameInput(a: InputEvent, b: InputEvent) -> bool:
	return a != null && b != null && serialize(a) == serialize(b)

func applyBindings() -> void:
	var saved = get_value("controls/bindings")
	for action in REBINDABLE:
		if not InputMap.has_action(action) || not defaultBindings.has(action): continue
		InputMap.action_erase_events(action)
		var events = defaultBindings[action]
		if saved.has(action):
			events = []
			for data in saved[action]:
				var event = deserialize(data)
				if event: events.push_back(event)
		for event in events: InputMap.action_add_event(action, event)

#binds `event` to slot 0/1 (keys) or 2 (controller) of `action`. Returns the name of the action
#that lost the input because it was bound there, or "" when there was no conflict.
func set_binding(action: String, slot: int, event: InputEvent) -> String:
	var conflict = ""
	var bindings = get_value("controls/bindings").duplicate(true)
	for other in REBINDABLE:
		if other == action: continue
		var otherEvents = InputMap.action_get_events(other)
		if otherEvents.any(func(e): return sameInput(e, event)):
			conflict = REBINDABLE[other]
			bindings[other] = otherEvents.filter(func(e): return not sameInput(e, event)).map(serialize)
	var slots = binding_slots(action)
	slots[slot] = event
	var events = []
	for e in slots:
		if e != null && not events.any(func(x): return sameInput(x, e)): events.push_back(e)
	#keep any extra controller events the defaults had beyond the one shown, unless the pad slot changed
	if slot != 2:
		for e in InputMap.action_get_events(action):
			if not e is InputEventKey && not events.any(func(x): return sameInput(x, e)): events.push_back(e)
	bindings[action] = events.map(serialize)
	set_value("controls/bindings", bindings)
	return conflict


#--- runtime advisor ------------------------------------------------------------------------
#Once per install: if the 1% low stays under 45 fps over the first 90 s of a run, the run
#summary suggests Potato. It never changes a setting by itself.
const ADVISOR_SECONDS = 90.0
const ADVISOR_MIN_FPS = 45.0
var advisorTime := -1.0
var advisorFrames: PackedFloat32Array = []
var advisor_pending := false

func on_run_started() -> void:
	advisorFrames.clear()
	advisorTime = 0.0 if not get_value("meta/advisor_shown") && get_value("meta/tier") != Tier.POTATO else -1.0
	set_process(advisorTime >= 0.0)

func _process(delta):
	if advisorTime < 0.0 || not Root.isRunActive:
		set_process(false)
		return
	if get_tree().paused: return
	advisorTime += delta
	advisorFrames.push_back(delta)
	if advisorTime < ADVISOR_SECONDS: return
	set_process(false)
	advisorTime = -1.0
	advisorFrames.sort()
	var worst = maxi(1, advisorFrames.size() / 100)
	var total = 0.0
	for i in worst: total += advisorFrames[advisorFrames.size() - 1 - i]
	advisor_pending = worst / total < ADVISOR_MIN_FPS

func take_advisor_message() -> String:
	if not advisor_pending: return ""
	advisor_pending = false
	set_value("meta/advisor_shown", true)
	return "Running slow? Try the Potato preset in Settings > Graphics."


#--- renderer and restart -------------------------------------------------------------------

func setRenderer(renderer: String) -> void:
	values["display/renderer"] = renderer
	dirtyGraphics = true
	var override = ConfigFile.new()
	override.load(OVERRIDE_PATH)
	if renderer == "compat":
		override.set_value("rendering", "renderer/rendering_method", "gl_compatibility")
	elif override.has_section_key("rendering", "renderer/rendering_method"):
		override.erase_section_key("rendering", "renderer/rendering_method")
	if override.get_sections().is_empty(): DirAccess.remove_absolute(OVERRIDE_PATH)
	else: override.save(OVERRIDE_PATH)

func current_renderer() -> String:
	return "compat" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "standard"

func restart() -> void:
	save_now()
	var args = Array(OS.get_cmdline_args()).filter(func(a): return a != "--safe-mode" && a != "--reset-graphics")
	OS.set_restart_on_exit(true, PackedStringArray(args))
	get_tree().quit()


#--- helpers --------------------------------------------------------------------------------

func args_has(flag: String) -> bool:
	return OS.get_cmdline_args().has(flag) || OS.get_cmdline_user_args().has(flag)

func cliWindowSize() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window="):
			var parts = arg.substr(9).split("x")
			if parts.size() == 2: return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO

#Controller Vibration: Off / Low / High
func vibrate(weak: float, strong: float, seconds: float) -> void:
	var level = get_value("controls/vibration")
	if level == 0: return
	var gain = 0.5 if level == 1 else 1.0
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak * gain, strong * gain, seconds)

func speed_text(pixelsPerSecond: float) -> String:
	if get_value("gameplay/speed_units") == "kmh": return str(int(pixelsPerSecond / 10.0 * 1.609)) + " KM/H"
	return str(int(pixelsPerSecond / 10.0)) + " MPH"

func distance_unit() -> String:
	return "km" if get_value("gameplay/speed_units") == "kmh" else "mi"
