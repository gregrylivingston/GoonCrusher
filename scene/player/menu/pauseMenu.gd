extends CanvasLayer

#The pause card (docs/UI.md): Continue, Settings, Abandon run and Quit game, then this run's numbers
#and the car's stats with what pickups added. Opened by GameUI.openPause; built in code with MenuTheme.

const SETTINGS_ICON := preload("res://texture/icon/settings.svg")
const QUIT_ICON := preload("res://texture/icon/quit.svg")
const STATS := DriverCard.STATS

var continueButton: Button
var abandonButton: Button
var quitButton: Button
var confirmTimers = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Settings.set_menu_context(true)
	InputGlyphs.ensureMenuActions()
	build()
	continueButton.grab_focus()

func build() -> void:
	var root = Control.new()
	root.theme = MenuTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var card = PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.055, 0.047, 0.043, 0.94), HudTheme.RIM, 18, 5, Vector4(0, 0, 0, 0)))
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(540, 0)
	root.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)

	var band = PanelContainer.new()
	band.theme_type_variation = "BandPanel"
	band.add_theme_stylebox_override("panel", bandBox())
	var title = Label.new()
	title.text = "PAUSED"
	title.theme_type_variation = "DarkLabel"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(title)
	column.add_child(band)

	var margin = MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	column.add_child(margin)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	continueButton = MenuTheme.button("CONTINUE", PackedStringArray(["ui_menu"]), true)
	continueButton.custom_minimum_size = Vector2(0, 70)
	continueButton.add_theme_font_size_override("font_size", 30)
	continueButton.pressed.connect(_on_continue_pressed)
	body.add_child(continueButton)
	var settingsButton = MenuTheme.button("Settings", PackedStringArray(), false, SETTINGS_ICON)
	settingsButton.custom_minimum_size = Vector2(0, 58)
	settingsButton.pressed.connect(_on_settings_pressed)
	body.add_child(settingsButton)
	abandonButton = MenuTheme.button(abandonText(), PackedStringArray(), false)
	abandonButton.custom_minimum_size = Vector2(0, 58)
	abandonButton.pressed.connect(_on_abandon_pressed)
	body.add_child(abandonButton)
	quitButton = MenuTheme.button("Quit game", PackedStringArray(), false, QUIT_ICON)
	quitButton.custom_minimum_size = Vector2(0, 58)
	quitButton.pressed.connect(_on_quit_pressed)
	body.add_child(quitButton)

	var runLine = Label.new()
	runLine.theme_type_variation = "MutedLabel"
	runLine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	runLine.text = runSummary()
	body.add_child(runLine)
	if is_instance_valid(Root.playerCar): body.add_child(statRow(Root.playerCar))
	var hints = HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 22)
	hints.add_child(KeyHint.make(PackedStringArray(["ui_up", "ui_down"]), "Choose"))
	hints.add_child(KeyHint.make(PackedStringArray(["ui_accept"]), "Select"))
	hints.add_child(KeyHint.make(PackedStringArray(["ui_menu"]), "Continue"))
	body.add_child(hints)

static func bandBox() -> StyleBoxFlat:
	var style = MenuTheme.box(HudTheme.RIM, Color(0, 0, 0, 0), 0, 0, Vector4(12, 10, 12, 10))
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	return style

func abandonText() -> String:
	if not is_instance_valid(Root.playerCar): return "Abandon run"
	return "Abandon run  (keeps %s coins)" % DriverCard.formatCoins(Root.computePayout(Root.playerCar.coin, Root.playerCar.star))

#"Countdown  -  4 : 08 left  -  7 crushed"
func runSummary() -> String:
	var parts: Array[String] = [Root.gameModeDescription[SaveManager.playerData.gameMode].name.capitalize()]
	var timer = get_tree().get_first_node_in_group("runTimer")
	if is_instance_valid(timer): parts.push_back(timer.text)
	if is_instance_valid(Root.playerCar): parts.push_back("%d crushed" % Root.playerCar.currentGoonsCrushed)
	return "   -   ".join(parts)

#the car's stats, each with a gold +N for what pickups added this run
func statRow(car) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for s in STATS:
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var picture = MenuTheme.iconRect(s[2], 30)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(picture)
		var value = Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 18)
		value.text = str(car.get(s[0]))
		cell.add_child(value)
		var gain = car.get(s[0]) - car.runStartStats.get(s[0], car.get(s[0]))
		if gain > 0:
			var plus = Label.new()
			plus.text = "+%d" % gain
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.add_theme_font_size_override("font_size", 13)
			plus.add_theme_color_override("font_color", HudTheme.GAIN)
			cell.add_child(plus)
		row.add_child(cell)
	return row

func _process(_delta):
	if Input.is_action_just_pressed("ui_menu") && not Settings.menu_open:
		_on_continue_pressed()

func _on_continue_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Settings.set_menu_context(false)
	queue_free()
	get_tree().paused = false

func _on_quit_pressed():
	if confirmed(quitButton, "Quit game", "Press again to quit to the desktop"):
		get_tree().quit()

#abandoning ends the run like a death: the summary shows it and pays coins x stars (at least x1)
func _on_abandon_pressed():
	if is_queued_for_deletion(): return
	if confirmed(abandonButton, abandonText(), "Press again to end this run"):
		Settings.set_menu_context(false)
		if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("endLevel") && not Root.levelRoot.hasEnded:
			queue_free()
			Root.levelRoot.endLevel(false, Root.endCondition.ABANDONED)
		else: #no run to end (the level is gone, or it already ended and paid): just leave
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")

#with Confirm Abandon / Quit on, the first press only arms the button for 3 seconds
func confirmed(button: Button, label: String, armedLabel: String) -> bool:
	if not Settings.get_value("gameplay/confirm_quit") || confirmTimers.get(button, false): return true
	armConfirm(button, label, armedLabel)
	return false

func armConfirm(button: Button, label: String, armedLabel: String) -> void:
	confirmTimers[button] = true
	button.text = armedLabel
	button.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	await get_tree().create_timer(3.0, true).timeout
	if is_instance_valid(button):
		confirmTimers[button] = false
		button.text = label
		button.remove_theme_color_override("font_color")

func _on_settings_pressed():
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())
