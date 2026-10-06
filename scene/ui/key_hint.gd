class_name KeyHint extends HBoxContainer

#A key or button prompt: one chip per action, then a label ("[Enter] Drive" or "[A] Drive").
#It shows the binding for the device in use and switches as soon as the player changes device.
#An action with no binding on that device is left out; with none at all the hint hides.

@export var actions: PackedStringArray = []
@export var text := ""
@export var chipSize := 15

var shownPad := -1

static func make(actionList: PackedStringArray, label := "", size := 15) -> KeyHint:
	var hint = KeyHint.new()
	hint.actions = actionList
	hint.text = label
	hint.chipSize = size
	return hint

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	rebuild()

func _input(event: InputEvent) -> void:
	InputGlyphs.note(event)
	if int(InputGlyphs.usingPad) != shownPad: rebuild()

func setText(value: String) -> void:
	text = value
	shownPad = -1
	rebuild()

func rebuild() -> void:
	shownPad = int(InputGlyphs.usingPad)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var any := false
	for action in actions:
		var glyph = InputGlyphs.label(action)
		if glyph == "": continue
		any = true
		add_child(MenuTheme.chip(glyph, chipSize))
	if text != "":
		var label = Label.new()
		label.text = text
		label.theme_type_variation = "HintLabel"
		add_child(label)
	visible = any
