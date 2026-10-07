class_name SettingsMenu extends Control

#Settings overlay. Rows are built from buildSchema(); changes apply live and are saved by
#the Settings autoload. "Revert changes" restores the values from when the overlay opened,
#"Reset tab" restores defaults. Controller: LB/RB tabs, B back, Y reset tab, Start close.

const PREVIEW_SOUND = preload("res://sound/ui/click_2.wav")
const GAMEPLAY_TAG = "Affects gameplay"

var tabs: Array = []
var currentTab := 0
var tabButtons: Array[Button] = []
var rowBox: VBoxContainer
var scroll: ScrollContainer
var infoTitle: Label
var infoText: RichTextLabel
var footer: Array[Button] = []
var rows: Array[OptionRow] = []
var snapshot := {}
var previousFocus: Control
var previewPlayer: AudioStreamPlayer
var resetArmed := false
var capturingRow: OptionRow
var captureDialog: SettingsDialog

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = MenuTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	previousFocus = get_viewport().gui_get_focus_owner()
	snapshot = Settings.values.duplicate(true)
	Settings.push_menu()
	Settings.changed.connect(onSettingChanged)
	previewPlayer = AudioStreamPlayer.new()
	previewPlayer.stream = PREVIEW_SOUND
	add_child(previewPlayer)
	tabs = buildSchema().filter(func(t): return not t.rows.is_empty())
	buildShell()
	showTab(0)
	Juice.dropIn(self, 30.0)

func _exit_tree():
	Settings.save_now()

#--- schema ---------------------------------------------------------------------------------

static func onOff() -> Array: return [[true, "On"], [false, "Off"]]
static func percent(v) -> String: return str(roundi(v * 100.0)) + "%"

func buildSchema() -> Array:
	return [
		{"name":"Graphics", "rows":graphicsRows()},
		{"name":"Display", "rows":[
			{"type":"choice", "key":"display/window_mode", "label":"Window Mode", "confirm":true,
				"options":[[3, "Borderless"], [4, "Exclusive Fullscreen"], [0, "Windowed"]],
				"info":"Borderless fills the screen and switches apps instantly. Exclusive can have slightly lower input lag on some PCs.", "perf":"None"},
			{"type":"choice", "key":"display/window_size", "label":"Window Size", "confirm":true, "options":windowSizes(),
				"visible_if":func(): return Settings.get_value("display/window_mode") == Window.MODE_WINDOWED, "watch":["display/window_mode"],
				"info":"Size of the game window. The game always shows the same amount of the world.", "perf":"Smaller windows draw fewer pixels."},
			{"type":"choice", "key":"display/monitor", "label":"Monitor", "confirm":true, "options":monitors(),
				"visible_if":func(): return DisplayServer.get_screen_count() > 1,
				"info":"Which screen the game opens on.", "perf":"None"},
			{"type":"choice", "key":"display/render_res", "label":"Render Resolution", "confirm":true,
				"options":[["native", "Native"], ["auto", "Auto"], ["cap900", "Cap 900p"], ["720", "720p"], ["540", "540p"]],
				"info":"Native draws at your screen's full resolution. Cap 900p draws at 1600x900 and scales up, so text is slightly softer. Auto caps only above 1080p. 720p and 540p draw runs (the world, HUD and in-run menus) at that height and scale them up: blurrier, but much faster at night on integrated graphics. Menus stay as Auto. The view of the world is the same at every setting.",
				"perf":"Large. A 4K screen draws up to 5.8x the pixels of 900p; 720p draws less than half the pixels of 1080p."},
			{"type":"choice", "key":"display/vsync", "label":"V-Sync", "options":[[1, "On"], [2, "Adaptive"], [0, "Off"]],
				"info":"On stops tearing. Adaptive turns it off briefly when the game can't keep up. Off has the least input lag.", "perf":"Off can raise frame rate and heat."},
			{"type":"choice", "key":"display/max_fps", "label":"Frame Rate Limit",
				"options":[[0, "Match display"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [-1, "Unlimited"]],
				"info":"Caps how many frames are drawn each second. Match display lets V-Sync pace frames.", "perf":"Lower caps run cooler and save battery."},
			{"type":"choice", "key":"display/menu_fps", "label":"Menu Frame Rate", "options":[[30, "30"], [0, "Same as game"]],
				"info":"Frame cap used only in the main menu and the pause menu.", "perf":"30 keeps laptops cooler in menus."},
			{"type":"choice", "key":"display/pause_unfocused", "label":"Pause When Unfocused", "options":onOff(),
				"info":"Opens the pause menu when you switch to another window during a run.", "perf":"None"},
			{"type":"choice", "key":"display/perf_overlay", "label":"Performance Overlay", "options":[[0, "Off"], [1, "FPS"], [2, "Detailed"]],
				"info":"Shows frame rate and timings. F3 cycles it at any time.", "perf":"Detailed costs a little."},
			{"type":"header", "label":"Troubleshooting"},
			{"type":"choice", "key":"display/renderer", "label":"Renderer", "restart":true,
				"options":[["standard", "Standard"], ["compat", "Compatibility"]], "setter":setRenderer,
				"info":"Only change this if the game crashes or shows a black screen. Standard is faster on most PCs.", "perf":"Compatibility is usually slower."},
		]},
		{"name":"Audio", "rows":[
			audioRow("master", "Master"), audioRow("music", "Music"), audioRow("voice", "Voice"),
			audioRow("fx", "Effects"), audioRow("ui", "Menu Sounds"),
			{"type":"choice", "key":"audio/mute_unfocused", "label":"Mute When Unfocused", "options":onOff(),
				"info":"Silences the game while another window has focus.", "perf":"None"},
		]},
		{"name":"Controls", "rows":controlRows()},
		{"name":"Accessibility", "rows":accessibilityRows()},
		{"name":"Gameplay", "rows":[
			{"type":"choice", "key":"gameplay/speed_units", "label":"Speed Units", "options":[["mph", "MPH"], ["kmh", "km/h"]],
				"info":"Units for the speedometer, the summary and the station distance.", "perf":"None"},
			{"type":"choice", "key":"gameplay/show_timer", "label":"Show Run Timer", "options":onOff(), "tag":GAMEPLAY_TAG,
				"info":"Shows the run clock on the HUD.", "gameplay":"In Sprint and Marathon the timer is information you lose when it is hidden.", "perf":"None"},
			{"type":"choice", "key":"gameplay/confirm_quit", "label":"Confirm Abandon / Quit", "options":onOff(),
				"info":"Abandon and Quit in the pause menu need a second press.", "perf":"None"},
			{"type":"choice", "key":"gameplay/car_paint", "label":"Car Paint", "options":[["weathered", "Weathered"], ["showroom", "Showroom"]],
				"info":"Weathered: rust, dust and faded paint, as in each driver's painting. Showroom: the same cars, clean and glossy. Only the look changes; dents and damage show on both.", "perf":"None"},
			{"type":"button", "label":"Reset Progress", "button":"Reset...", "action":resetProgress,
				"info":"Deletes all coins, cars, upgrades and level unlocks. Your settings are kept. Press twice to confirm.", "perf":"None"},
		]},
	]

func graphicsRows() -> Array:
	return [
		{"type":"choice", "key":"meta/tier", "label":"Quality Preset", "getter":func(): return Settings.get_value("meta/tier"),
			"setter":setPreset,
			"options":[[0, "Potato"], [1, "Low"], [2, "Medium"], [3, "High"], [4, "Custom"]], "watch":Settings.PRESET.keys(),
			"info":recommendedText(),
			"perf":"Potato is for PCs without a graphics card that struggle on Low. Changing any option below shows Custom."},
		{"type":"button", "label":"Detect Again", "button":"Detect", "action":detectAgain,
			"info":"Checks your graphics hardware and applies the recommended preset.", "perf":"None"},
		{"type":"choice", "key":"gfx/text_fx", "label":"Text Effects",
			"options":[[0, "Flat"], [1, "Still 3D"], [2, "Animated"], [3, "Animated HD"]],
			"info":"How titles, buttons and HUD numbers are drawn. Flat keeps every outline but drops the 3D depth. Still 3D keeps the depth without the wobble. All text stays readable.",
			"perf":"Large in menus. Flat is about 9 texture reads per pixel; Animated HD up to 48."},
		{"type":"choice", "key":"gfx/lighting", "label":"Lighting", "options":[[0, "Low"], [1, "Medium"], [2, "High"]],
			"tag":"Low affects gameplay", "watch":["gfx/simple_cone"],
			"info":"Night lighting. High is as designed. Medium uses a smaller shadow map and turns off the glow on collected pickups; night play is unchanged. Low turns off shadows and the small lights, and lights the station yard with one big lamp. Your headlights always reach as far as your Headlights upgrade allows.",
			"gameplay":"On Low, shadows no longer hide goons behind rocks and other goons, so you see more at night.",
			"perf":"The biggest cost at night. Shadows are drawn again for every goon, rock and wall each frame."},
		{"type":"choice", "key":"gfx/simple_cone", "label":"Simple Headlight Cone", "options":onOff(),
			"visible_if":func(): return Settings.SIMPLE_CONE_READY,
			"info":"Draws your headlights as one cone instead of five overlapping lamps. Same reach and brightness.",
			"perf":"Large at night: one shadow pass instead of five."},
		{"type":"choice", "key":"gfx/smoke", "label":"Exhaust Smoke", "options":[[0, "Off"], [1, "Low"], [2, "Full"]],
			"info":"Smoke puffs from the exhaust. Low makes fewer, smaller, shorter puffs.",
			"perf":"Medium. Full keeps about 35 large see-through puffs per car on screen."},
		{"type":"choice", "key":"gfx/tire_marks", "label":"Tire Marks", "options":[[0, "Off"], [1, "Short"], [2, "Full"]],
			"info":"Skid marks on the ground. Short: rear tyres only, gone after 6 seconds. Full: all tyres, 20 seconds.",
			"perf":"Small."},
		{"type":"choice", "key":"gfx/damage_fx", "label":"Damage Effects", "options":[[1, "Low"], [2, "Full"]],
			"info":"Effects from a damaged car. Low: engine smoke only. Full: also flames, a fuel drip trail and sparks from a wrecked wheel. Dents and flickering headlights always show, because they tell you what is broken.",
			"perf":"Small. Only a damaged car makes any, from small capped pools."},
		{"type":"choice", "key":"gfx/pickup_fx", "label":"Pickup Glow", "options":[[0, "Simple"], [1, "Full"]],
			"info":"Simple keeps the full-width outline around pickups but drops the moving shine.",
			"perf":"Small to medium, depending on how many pickups are on screen."},
		{"type":"choice", "key":"gfx/ground", "label":"Ground Detail", "options":[[0, "Simple"], [1, "Full"]],
			"info":"Full blends the ground's surfaces into each other with natural borders and moves water and conveyor belts. Simple draws each patch of ground with one surface.",
			"perf":"Small to medium: the ground covers the whole screen."},
		{"type":"choice", "key":"gfx/celebration", "label":"Slot Celebration", "options":[[0, "Minimal"], [1, "Reduced"], [2, "Full"]],
			"info":"The icon wall and icon burst around the slot machine. Reels, results and claiming are the same at every level.",
			"perf":"Large spikes on Full: up to 1,200 icons in the wall and 600 in the burst."},
		{"type":"choice", "key":"gfx/reward_fx", "label":"Reward Pop-ups", "options":[[0, "Minimal"], [1, "Reduced"], [2, "Full"]],
			"info":"How many collected rewards fly to the HUD at once (3, 10 or 20). Every reward is counted the moment you collect it, whatever this is set to.",
			"perf":"Small to medium during purses and crowds."},
		{"type":"choice", "key":"audio_perf/max_sfx", "label":"Max Sound Effects", "options":[[8, "8"], [12, "12"], [24, "24"]],
			"info":"How many goon, pickup and crush sounds can play at once. Engine, crash and voice sounds are separate and always play.",
			"perf":"Small CPU saving on older processors."},
	]

func setPreset(tier: int) -> void:
	if tier < Settings.Tier.CUSTOM: Settings.apply_preset(tier)

func recommendedText() -> String:
	var tier = Settings.get_value("meta/recommended_tier")
	if tier < 0: return "Sets every graphics option below at once."
	return "Sets every graphics option below at once.

Recommended: %s (%s)" % [Settings.TIER_NAMES[tier], Settings.get_value("meta/adapter_name")]

func detectAgain(_row: OptionRow) -> void:
	var tier = Settings.detect_tier()
	Settings.set_value("meta/recommended_tier", tier)
	Settings.apply_preset(tier)
	for row in rows: row.refresh()
	showInfo(rows[0])

func controlRows() -> Array:
	var rows = []
	for action in Settings.REBINDABLE:
		rows.push_back({"type":"binding", "key":"controls/bindings", "action":action, "label":Settings.REBINDABLE[action],
			"info":"Two keyboard keys, then one controller button or stick. Left and right pick a slot; press Accept, then the new key or button. Esc cancels.",
			"perf":"None"})
	return rows + [
		{"type":"choice", "key":"controls/vibration", "label":"Controller Vibration", "options":[[0, "Off"], [1, "Low"], [2, "High"]],
			"info":"Rumble when you crush goons, hit walls and explode.", "perf":"None"},
		{"type":"slider", "key":"controls/deadzone", "label":"Stick Deadzone", "min":0.2, "max":0.8, "step":0.05, "format":percent,
			"info":"How far a stick must move before it counts as a press. Steering stays digital.", "perf":"None"},
		{"type":"header", "label":"Start pauses   LB / RB switch tabs   Y resets a tab"},
	]

func accessibilityRows() -> Array:
	return [
		{"type":"choice", "key":"access/reduce_motion", "label":"Reduce Motion", "options":onOff(),
			"info":"Stops the 3D text wobble, freezes rainbow fills, makes the giant marker steady, turns off car shake, fades screen transitions instead of slamming the shutter (no smoke or shake) and limits slot celebrations to Reduced. Camera zoom at speed is unchanged.", "perf":"Slightly faster"},
		{"type":"choice", "key":"access/reduce_flashing", "label":"Reduce Flashing", "options":onOff(),
			"info":"Minimal slot celebrations, a slower giant pulse and no over-bright giant glow.", "perf":"Slightly faster"},
		{"type":"choice", "key":"access/giant_style", "label":"Giant Marker Style", "options":[[0, "Pulse"], [1, "Steady"], [2, "Tint + ground ring"]],
			"info":"How giants are marked. Giants are always bigger than other goons. New giants use the new style.", "perf":"None"},
		{"type":"choice", "key":"access/giant_color", "label":"Giant Marker Colour", "options":[[0, "Red"], [1, "Yellow"], [2, "Cyan"], [3, "Magenta"], [4, "White"]],
			"info":"Colour of the giant marker. Yellow or Cyan are easier to tell apart with red-green colour blindness.", "perf":"None"},
		{"type":"choice", "key":"access/plain_text", "label":"Plain Text", "options":onOff(),
			"info":"Draws all 3D text flat, whatever Text Effects is set to.", "perf":"Faster in menus"},
		{"type":"choice", "key":"access/car_shake", "label":"Car Shake", "options":onOff(),
			"info":"The car body's shake at speed.", "perf":"None"},
		{"type":"slider", "key":"access/hud_scale", "label":"HUD Scale", "min":0.8, "max":1.3, "step":0.05, "format":percent,
			"info":"Size of the in-run HUD: counters, region panel, crush goal and the car's bars. The view of the world is unchanged.", "perf":"None"},
	]

func audioRow(bus: String, label: String) -> Dictionary:
	return {"type":"slider", "key":"audio/" + bus, "mute":"audio/" + bus + "_mute", "label":label, "min":0.0, "max":1.0, "step":0.05,
		"format":percent, "bus":bus, "info":"Volume of the %s channel. 0%% mutes it." % label, "perf":"None"}

func windowSizes() -> Array:
	var usable = DisplayServer.screen_get_usable_rect(get_window().current_screen).size
	var sizes = []
	for size in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		if size.x <= usable.x && size.y <= usable.y: sizes.push_back([size, "%dx%d" % [size.x, size.y]])
	var saved = Settings.get_value("display/window_size")
	if not sizes.any(func(o): return o[0] == saved): sizes.push_back([saved, "%dx%d" % [saved.x, saved.y]])
	return sizes

func monitors() -> Array:
	var options = [[-1, "Current"]]
	for i in DisplayServer.get_screen_count(): options.push_back([i, "Monitor %d" % (i + 1)])
	return options

#--- shell ----------------------------------------------------------------------------------

static func makeButton(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 24)
	button.custom_minimum_size = Vector2(160, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuTheme.addSounds(button)
	return button

func buildShell() -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.055, 0.047, 0.043, 0.95), HudTheme.RIM, 16, 3, Vector4(24, 24, 24, 24)))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 90
	panel.offset_right = -90
	panel.offset_top = 50
	panel.offset_bottom = -50
	add_child(panel)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var tabRow = HBoxContainer.new()
	tabRow.alignment = BoxContainer.ALIGNMENT_CENTER
	tabRow.add_theme_constant_override("separation", 10)
	layout.add_child(tabRow)
	tabRow.add_child(KeyHint.make(PackedStringArray(["ui_tab_prev"]), "", 15, true))
	for i in tabs.size():
		var button = makeButton(tabs[i].name)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.theme_type_variation = "TabButton"
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(showTab.bind(i))
		tabRow.add_child(button)
		tabButtons.push_back(button)
	tabRow.add_child(KeyHint.make(PackedStringArray(["ui_tab_next"]), "", 15, true))

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	layout.add_child(body)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.7
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	rowBox = VBoxContainer.new()
	rowBox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rowBox.add_theme_constant_override("separation", 4)
	scroll.add_child(rowBox)

	var info = PanelContainer.new()
	info.theme_type_variation = "InfoPanel"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var infoBox = VBoxContainer.new()
	infoBox.add_theme_constant_override("separation", 12)
	info.add_child(infoBox)
	infoTitle = Label.new()
	infoTitle.add_theme_font_size_override("font_size", 28)
	infoTitle.add_theme_constant_override("outline_size", 8)
	infoTitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	infoBox.add_child(infoTitle)
	infoText = RichTextLabel.new()
	infoText.bbcode_enabled = true
	infoText.fit_content = true
	infoText.size_flags_vertical = Control.SIZE_EXPAND_FILL
	infoText.add_theme_font_size_override("normal_font_size", 20)
	infoText.add_theme_font_size_override("bold_font_size", 20)
	infoText.add_theme_constant_override("outline_size", 0)
	infoText.add_theme_color_override("default_color", Color(0.95, 0.9, 0.85))
	infoBox.add_child(infoText)

	var footerRow = HBoxContainer.new()
	footerRow.alignment = BoxContainer.ALIGNMENT_CENTER
	footerRow.add_theme_constant_override("separation", 30)
	layout.add_child(footerRow)
	for entry in [["Revert changes", revertChanges, []], ["Reset tab", resetTab, ["ui_reset_tab"]], ["Close", close, ["ui_cancel"]]]:
		var button = MenuTheme.button(entry[0], PackedStringArray(entry[2]))
		button.custom_minimum_size = Vector2(230, 52)
		button.pressed.connect(entry[1])
		footerRow.add_child(button)
		footer.push_back(button)

func hint(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color(1, 1, 1, 0.6)
	return label

func showTab(index: int) -> void:
	currentTab = wrapi(index, 0, tabs.size())
	resetArmed = false
	for i in tabButtons.size():
		tabButtons[i].button_pressed = i == currentTab
	for row in rows: row.queue_free()
	rows.clear()
	for def in tabs[currentTab].rows:
		var row = OptionRow.new(def)
		row.row_focused.connect(showInfo)
		row.value_chosen.connect(onValueChosen)
		row.activated.connect(onActivated)
		rowBox.add_child(row)
		rows.push_back(row)
	updateVisibility()
	focusFirstRow.call_deferred()

func focusFirstRow() -> void:
	for row in rows:
		if row.visible && row.focus_mode != Control.FOCUS_NONE:
			row.grab_focus()
			return
	footer[footer.size() - 1].grab_focus()

#keeps keyboard and controller focus inside the overlay
func linkFocus() -> void:
	var focusable = rows.filter(func(r): return r.visible && r.focus_mode != Control.FOCUS_NONE)
	for i in focusable.size():
		var row = focusable[i]
		row.focus_neighbor_top = row.get_path_to(focusable[i - 1] if i > 0 else row)
		row.focus_neighbor_bottom = row.get_path_to(focusable[i + 1] if i < focusable.size() - 1 else footer[0])
		row.focus_neighbor_left = row.get_path()
		row.focus_neighbor_right = row.get_path()
	for i in footer.size():
		var button = footer[i]
		button.focus_neighbor_top = button.get_path_to(focusable[focusable.size() - 1] if not focusable.is_empty() else button)
		button.focus_neighbor_bottom = button.get_path()
		button.focus_neighbor_left = button.get_path_to(footer[maxi(i - 1, 0)])
		button.focus_neighbor_right = button.get_path_to(footer[mini(i + 1, footer.size() - 1)])

func updateVisibility() -> void:
	for row in rows:
		if row.def.has("visible_if"): row.visible = row.def.visible_if.call()
	linkFocus()

func showInfo(row: OptionRow) -> void:
	var def = row.def
	infoTitle.text = def.label
	var text = def.get("info", "")
	if def.has("perf"): text += "\n\n[b]Performance:[/b] " + def.perf
	if def.has("gameplay"): text += "\n\n[color=#ff6a5a][b]Affects gameplay:[/b] " + def.gameplay + "[/color]"
	if def.get("restart", false): text += "\n\n[color=#ffd36a]Needs a restart.[/color]"
	infoText.text = text

#--- input ----------------------------------------------------------------------------------

func _unhandled_input(event):
	if hasDialog(): return
	if event.is_action_pressed("ui_tab_prev"): showTab(currentTab - 1)
	elif event.is_action_pressed("ui_tab_next"): showTab(currentTab + 1)
	elif event.is_action_pressed("ui_reset_tab"): resetTab()
	elif event.is_action_pressed("ui_cancel") || event.is_action_pressed("ui_menu"): close()
	else: return
	get_viewport().set_input_as_handled()

func hasDialog() -> bool:
	return get_children().any(func(c): return c is SettingsDialog)

#--- changes --------------------------------------------------------------------------------

func onSettingChanged(key: String, _value) -> void:
	for row in rows:
		if row.describes(key): row.refresh()
	if rows.any(func(r): return r.def.has("visible_if")): updateVisibility()

func onValueChosen(row: OptionRow, old, new) -> void:
	if row.def.get("confirm", false): confirmOrRevert(row, old)
	elif row.def.get("restart", false) && new != Settings.current_renderer():
		var dialog = SettingsDialog.make("Restart now to switch the renderer?", ["Restart now", "Later"])
		dialog.chosen.connect(func(i):
			if i == 0: Settings.restart()
		)
		add_child(dialog)

func onActivated(row: OptionRow) -> void:
	if row.def.has("bus"):
		previewPlayer.bus = Settings.AUDIO_BUSES[row.def.bus]
		previewPlayer.play()
	if row.def.type == "binding": startCapture(row)
	elif row.def.has("action"): row.def.action.call(row)

#--- rebinding ------------------------------------------------------------------------------

func startCapture(row: OptionRow) -> void:
	capturingRow = row
	var what = "a controller button or stick" if row.slot == 2 else "a key"
	captureDialog = SettingsDialog.make("Press %s for %s" % [what, row.def.label], ["Cancel"], 5.0, "Cancelling in %d s")
	captureDialog.chosen.connect(func(_i): capturingRow = null)
	add_child(captureDialog)

func _input(event):
	if capturingRow == null || not is_instance_valid(captureDialog): return
	var wantPad = capturingRow.slot == 2
	var captured: InputEvent = null
	if event is InputEventKey && event.pressed && not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			captureDialog.choose(0)
			return
		if not wantPad: captured = Settings.keyEvent(event.physical_keycode)
	elif wantPad && event is InputEventJoypadButton && event.pressed:
		captured = Settings.joyButton(event.button_index)
	elif wantPad && event is InputEventJoypadMotion && absf(event.axis_value) > 0.6:
		captured = InputEventJoypadMotion.new()
		captured.device = -1
		captured.axis = event.axis
		captured.axis_value = signf(event.axis_value)
	if captured == null: return
	get_viewport().set_input_as_handled()
	var row = capturingRow
	var conflict = Settings.set_binding(row.def.action, row.slot, captured)
	captureDialog.choose(0)
	row.grab_focus()
	for r in rows: r.refresh()
	showInfo(row)
	if conflict != "":
		infoText.text += "

[color=#ffd36a]%s was also bound to %s, so it was removed there.[/color]" % [Settings.event_name(captured), conflict]

func confirmOrRevert(row: OptionRow, old) -> void:
	var dialog = SettingsDialog.make("Keep these display settings?", ["Keep", "Revert"], 15.0, "Reverting in %d s")
	dialog.chosen.connect(func(i):
		if i == 1: Settings.set_value(row.def.key, old)
		row.refresh()
		row.grab_focus()
	)
	add_child(dialog)

func setRenderer(value: String) -> void:
	Settings.setRenderer(value)
	Settings.changed.emit("display/renderer", value)

func resetProgress(row: OptionRow) -> void:
	if not resetArmed:
		resetArmed = true
		showInfo(row)
		infoText.text += "\n\n[color=#ff6a5a][b]Press again to delete all progress.[/b][/color]"
		return
	resetArmed = false
	SaveManager.reset_save()
	get_tree().paused = false
	Settings.pop_menu()
	Root.isRunActive = false
	get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")

func revertChanges() -> void:
	for key in snapshot:
		if key.begins_with("meta/") || Settings.values.get(key) == snapshot[key]: continue
		Settings.set_value(key, snapshot[key])
	Settings.values["meta/tier"] = snapshot["meta/tier"]
	Settings.markDirty("meta/tier")
	Settings.changed.emit("meta/tier", snapshot["meta/tier"])
	for row in rows: row.refresh()

func resetTab() -> void:
	if tabs[currentTab].name == "Graphics" && Settings.get_value("meta/recommended_tier") >= 0:
		Settings.apply_preset(Settings.get_value("meta/recommended_tier"))
	for row in rows:
		if row.def.has("key") && not row.def.has("setter") && not row.def.has("getter") && not Settings.PRESET.has(row.def.key):
			Settings.set_value(row.def.key, Settings.get_default(row.def.key))
		if row.def.has("mute"): Settings.set_value(row.def.mute, false)
		row.refresh()

func close() -> void:
	if is_queued_for_deletion(): return
	Settings.save_now()
	Settings.pop_menu()
	if is_instance_valid(previousFocus) && previousFocus.is_visible_in_tree(): previousFocus.grab_focus()
	queue_free()
