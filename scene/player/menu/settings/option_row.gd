class_name OptionRow extends PanelContainer

#One row of the settings overlay, built from a schema entry (see SettingsMenu.buildSchema).
#Types: "choice" (< value >), "slider" (with optional mute), "button", "header",
#"binding" (two keyboard slots and one controller slot; left/right pick a slot, accept rebinds it).
#Left/right change the value, accept presses buttons and toggles mute. No dropdowns, so every
#row works the same with a controller.

signal row_focused(row: OptionRow)
signal value_chosen(row: OptionRow, old, new)
signal activated(row: OptionRow)

const FONT_SIZE = 24
const NORMAL = Color(0, 0, 0, 0)
const FOCUSED = Color(0.93, 0.6, 0.16, 0.22)

var def: Dictionary
var valueLabel: Label
var slider: HSlider
var muteButton: Button
var style: StyleBoxFlat
var refreshing := false
var slot := 0
var slotButtons: Array[Button] = []

func _init(definition: Dictionary):
	def = definition

func _ready():
	style = StyleBoxFlat.new()
	style.bg_color = NORMAL
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(0, 46)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var nameLabel = Label.new()
	nameLabel.text = def.label
	nameLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameLabel.add_theme_font_size_override("font_size", FONT_SIZE + (4 if def.type == "header" else 0))
	nameLabel.add_theme_constant_override("outline_size", 6)
	row.add_child(nameLabel)
	if def.type == "header":
		focus_mode = Control.FOCUS_NONE
		nameLabel.modulate = Color(1, 1, 1, 0.7)
		return

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(onFocus.bind(true))
	focus_exited.connect(onFocus.bind(false))
	mouse_entered.connect(grab_focus)
	if def.has("tag"):
		var tag = Label.new()
		tag.text = def.tag
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 15)
		tag.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
		tag.add_theme_constant_override("outline_size", 4)
		row.add_child(tag)

	var control = HBoxContainer.new()
	control.custom_minimum_size = Vector2(380, 0)
	control.add_theme_constant_override("separation", 6)
	row.add_child(control)
	match def.type:
		"choice":
			control.add_child(arrowButton("<", -1))
			valueLabel = makeValueLabel()
			valueLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.add_child(valueLabel)
			control.add_child(arrowButton(">", 1))
		"slider":
			slider = HSlider.new()
			slider.min_value = def.min
			slider.max_value = def.max
			slider.step = def.step
			slider.focus_mode = Control.FOCUS_NONE
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.value_changed.connect(onSliderChanged)
			slider.drag_ended.connect(func(_c): activated.emit(self))
			control.add_child(slider)
			valueLabel = makeValueLabel()
			valueLabel.custom_minimum_size = Vector2(70, 0)
			control.add_child(valueLabel)
			if def.has("mute"):
				muteButton = Button.new()
				muteButton.toggle_mode = true
				muteButton.focus_mode = Control.FOCUS_NONE
				muteButton.custom_minimum_size = Vector2(80, 0)
				muteButton.add_theme_font_size_override("font_size", 18)
				muteButton.pressed.connect(toggleMute)
				control.add_child(muteButton)
		"binding":
			for i in 3:
				var slotButton = Button.new()
				slotButton.focus_mode = Control.FOCUS_NONE
				slotButton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slotButton.clip_text = true
				slotButton.add_theme_font_size_override("font_size", FONT_SIZE - 6)
				slotButton.pressed.connect(func(): grab_focus(); slot = i; refresh(); activated.emit(self))
				control.add_child(slotButton)
				slotButtons.push_back(slotButton)
		"button":
			var button = Button.new()
			button.text = def.get("button", "Open")
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", FONT_SIZE - 2)
			button.pressed.connect(func(): grab_focus(); activated.emit(self))
			control.add_child(button)
	refresh()

func onSliderChanged(value: float) -> void:
	if not refreshing: commit(value)

func arrowButton(text: String, direction: int) -> Button:
	var button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(40, 0)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(func(): grab_focus(); step(direction))
	return button

func makeValueLabel() -> Label:
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	label.add_theme_constant_override("outline_size", 6)
	label.clip_text = true
	return label

func onFocus(isFocused: bool) -> void:
	style.bg_color = FOCUSED if isFocused else NORMAL
	if def.type == "binding": refresh()
	if isFocused: row_focused.emit(self)

func _gui_input(event):
	if def.type == "header": return
	if event.is_action_pressed("ui_left", true): step(-1)
	elif event.is_action_pressed("ui_right", true): step(1)
	elif event.is_action_pressed("ui_accept"):
		if def.type == "button" || def.type == "binding": activated.emit(self)
		elif def.type == "slider" && muteButton: toggleMute()
		else: step(1)
	else: return
	accept_event()

func current() -> Variant:
	if def.has("getter"): return def.getter.call()
	return Settings.get_value(def.key)

func step(direction: int) -> void:
	match def.type:
		"binding":
			slot = clampi(slot + direction, 0, 2)
			refresh()
		"choice":
			var options = def.options
			var index = 0
			for i in options.size():
				if options[i][0] == current(): index = i
			index = clampi(index + direction, 0, options.size() - 1)
			if options[index][0] != current(): commit(options[index][0])
		"slider":
			commit(clampf(snappedf(current() + direction * def.step, def.step), def.min, def.max))
			activated.emit(self)

func commit(value) -> void:
	var old = current()
	if old == value: return
	if def.has("setter"): def.setter.call(value)
	else: Settings.set_value(def.key, value)
	value_chosen.emit(self, old, value)
	refresh()

func toggleMute() -> void:
	Settings.set_value(def.mute, not Settings.get_value(def.mute))
	refresh()
	activated.emit(self)

func refresh() -> void:
	if def.type == "header" || def.type == "button": return
	if def.type == "binding":
		var slots = Settings.binding_slots(def.action)
		for i in 3:
			slotButtons[i].text = Settings.event_name(slots[i])
			slotButtons[i].add_theme_color_override("font_color", Color.WHITE if i == slot && has_focus() else Color(0.93, 0.6, 0.16))
		return
	refreshing = true
	var value = current()
	match def.type:
		"choice":
			valueLabel.text = str(value)
			for option in def.options:
				if option[0] == value: valueLabel.text = option[1]
		"slider":
			slider.value = value
			valueLabel.text = def.format.call(value) if def.has("format") else str(value)
			if muteButton:
				var muted = Settings.get_value(def.mute)
				muteButton.button_pressed = muted
				muteButton.text = "Muted" if muted else "Mute"
	refreshing = false

func describes(key: String) -> bool:
	return def.get("key", "") == key || def.get("mute", "") == key || def.get("watch", []).has(key)
