class_name SettingsDialog extends Control

#Small modal used by the settings overlay and the main menu: a message, up to three buttons,
#and an optional countdown that picks the last button when it runs out.

signal chosen(index: int)


var message: String
var buttons: PackedStringArray
var countdown: float = 0.0
var countdownText: String = ""
var label: Label
var buttonNodes: Array[Button] = []

static func make(text: String, options: PackedStringArray, seconds: float = 0.0, secondsText: String = "") -> SettingsDialog:
	var dialog = SettingsDialog.new()
	dialog.message = text
	dialog.buttons = options
	dialog.countdown = seconds
	dialog.countdownText = secondsText
	return dialog

static func safeModePrompt() -> SettingsDialog:
	var dialog = make("The game didn't start properly last time.\nStart in safe mode? (Potato preset, windowed, Compatibility renderer)", ["Use safe mode", "No thanks"])
	dialog.chosen.connect(func(i): Settings.accept_safe_mode(i == 0))
	return dialog

static func detectToast() -> SettingsDialog:
	var text = "Graphics set to %s for %s." % [Settings.get_tier_name(), Settings.get_value("meta/adapter_name")]
	if Settings.calibrated_down: text += " It was lowered one step after measuring this graphics card."
	var dialog = make(text, ["OK", "Open Graphics"])
	dialog.chosen.connect(func(i):
		Settings.detect_toast_pending = false
		Settings.set_value("meta/detect_toast_shown", true)
		if i == 1 && is_instance_valid(Root.mainMenu):
			var menu = load("res://scene/player/menu/settings/settings.tscn").instantiate()
			Root.mainMenu.add_child(menu)
	)
	return dialog

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = MenuTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.055, 0.047, 0.043, 0.95), HudTheme.RIM, 14, 3, Vector4(28, 28, 28, 28)))
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_constant_override("outline_size", 8)
	label.custom_minimum_size = Vector2(640, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)
	for i in buttons.size():
		var button = SettingsMenu.makeButton(buttons[i])
		button.pressed.connect(choose.bind(i))
		row.add_child(button)
		buttonNodes.push_back(button)
	updateText()
	buttonNodes[0].grab_focus.call_deferred()
	Settings.push_menu()

func _process(delta):
	if countdown <= 0.0: return
	countdown -= delta
	updateText()
	if countdown <= 0.0: choose(buttons.size() - 1)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") || event.is_action_pressed("ui_menu"):
		get_viewport().set_input_as_handled()
		choose(buttons.size() - 1)

func updateText() -> void:
	label.text = message
	if countdown > 0.0: label.text += "\n" + countdownText % ceili(countdown)

func choose(index: int) -> void:
	if is_queued_for_deletion(): return
	chosen.emit(index)
	Settings.pop_menu()
	queue_free()
