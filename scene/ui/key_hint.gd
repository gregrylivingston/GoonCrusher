class_name KeyHint extends HBoxContainer

#A key or button prompt: one chip per action, then a label ("[Enter] Drive" or "[A] Drive").
#It shows the binding for the device in use and switches as soon as the player changes device.
#An action with no binding on that device is left out; with none at all the hint hides.
#A clickable hint (hint bars, tab chips) fires its action when clicked, exactly as the key would:
#one action makes the whole hint a button, several make each chip its own button.

@export var actions: PackedStringArray = []
@export var text := ""
@export var chipSize := 15
@export var clickable := false

var shownPad := -1

static func make(actionList: PackedStringArray, label := "", size := 15, canClick := false) -> KeyHint:
	var hint = KeyHint.new()
	hint.actions = actionList
	hint.text = label
	hint.chipSize = size
	hint.clickable = canClick
	return hint

#a centered row of clickable hints from [[actions], label] pairs: the bottom bar of a menu
static func bar(list: Array, size := 16, separation := 26) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	for h in list: row.add_child(make(PackedStringArray(h[0]), h[1], size, true))
	return row

#presses and releases `action` as if its key were tapped: _input handlers, the GUI and
#Input.is_action_just_pressed polling all see it. The release is bound to Input, not to the hint,
#so it still arrives if the press rebuilds or frees the hint.
static func fire(action: String) -> void:
	if not InputMap.has_action(action): return
	var press = InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	var release = InputEventAction.new()
	release.action = action
	(Engine.get_main_loop() as SceneTree).process_frame.connect(Input.parse_input_event.bind(release), CONNECT_ONE_SHOT)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	rebuild()

func _input(event: InputEvent) -> void:
	InputGlyphs.note(event)
	if int(InputGlyphs.usingPad) != shownPad: rebuild()

func rebuild() -> void:
	shownPad = int(InputGlyphs.usingPad)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var bound := PackedStringArray()
	var chips: Array[Control] = []
	for action in actions:
		var glyph = InputGlyphs.label(action)
		if glyph == "": continue
		bound.push_back(action)
		var chip = MenuTheme.chip(glyph, chipSize)
		chips.push_back(chip)
		add_child(chip)
	var label: Label = null
	if text != "":
		label = Label.new()
		label.text = text
		label.theme_type_variation = "HintLabel"
		add_child(label)
	visible = not bound.is_empty()
	if not clickable || bound.is_empty(): return
	if bound.size() == 1:
		makeClickable(self, bound[0], chips[0], label)
	else:
		for i in bound.size(): makeClickable(chips[i], bound[i], chips[i], null)

#hover lights the chip orange and the label gold; a left click fires the action
func makeClickable(target: Control, action: String, chip: Control, label: Label) -> void:
	target.mouse_filter = MOUSE_FILTER_STOP
	target.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	var light = func(on: bool):
		if is_instance_valid(chip): chip.theme_type_variation = "KeyChipHot" if on else "KeyChip"
		if is_instance_valid(label):
			if on: label.add_theme_color_override("font_color", HudTheme.GOLD)
			else: label.remove_theme_color_override("font_color")
	target.mouse_entered.connect(light.bind(true))
	target.mouse_exited.connect(light.bind(false))
	target.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			target.accept_event()
			MenuTheme.click()
			KeyHint.fire(action))
