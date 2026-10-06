class_name PickupMenu extends CanvasLayer

#Base for the pickup menus that pause a run (The Deal, the Claw Crane, the Pit Shop): a dimmed screen
#with one card in the menu theme (docs/UI.md), driven by the driving keys as well as the menu keys.
#Keys pressed in the first moments are ignored, so a held Accelerate can't pick something by accident.
#Closing resumes the run through the usual 3-2-1 countdown.

const ARM_SECONDS := 0.6

var root := Control.new()
var card := PanelContainer.new()
var body := VBoxContainer.new()
var armed := 0.0
var closed := false

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	add_to_group("slotMachine") #the playtest and bench harnesses tap Accelerate through anything in it
	add_to_group("pickupMenu")
	InputGlyphs.ensureMenuActions()
	root.theme = MenuTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	card.theme_type_variation = "CardPanel"
	centre.add_child(card)
	body.add_theme_constant_override("separation", 14)
	card.add_child(body)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	build()

func build() -> void: pass

func _process(delta: float) -> void:
	if closed: return
	armed += delta
	if armed < ARM_SECONDS: return
	for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight", "UseItem", "ui_accept", "ui_cancel"]:
		if InputMap.has_action(action) && Input.is_action_just_pressed(action): onAction(action)
	tick(delta)

func onAction(_action: String) -> void: pass
func tick(_delta: float) -> void: pass

func title(text: String, sub := "") -> void:
	var t = Label.new()
	t.text = text
	t.theme_type_variation = "TitleLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	if sub != "":
		var s = Label.new()
		s.text = sub
		s.theme_type_variation = "MutedLabel"
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(s)

func hints(list: Array) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	for h in list: row.add_child(KeyHint.make(PackedStringArray(h[0]), h[1], 16))
	body.add_child(row)
	return row

static func runCoins() -> int:
	return Root.playerCar.coin if is_instance_valid(Root.playerCar) else 0

## Leaves the menu. `countdown`: resume through 3-2-1 (false when another pausing screen follows).
func close(countdown := true) -> void:
	if closed: return
	closed = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if countdown && is_instance_valid(Root.playerCar): Root.playerCar.add_child(load("res://scene/player/countdown.tscn").instantiate())
	elif not countdown: get_tree().paused = false
	queue_free()
