class_name CoopPanel extends PanelContainer

#Level Options' second-player plate (docs/UI.md), between the records and the launch bar. Empty, it says how
#to join; with a guest in (Coop), it shows their car, their side, their gadget and boost, and which of the
#guest's own buttons change each. The guest is always on a controller, so its buttons are drawn as a pad's.
#The first player can remove the guest with LEAVE_ACTION or a click on its hint. main2 passes the guest's
#presses to Coop.menuInput and calls refresh.

const SIZE := Vector2(348, 128)
const PIC := Vector2(124, 46)
const ITEM := 30.0
const SIDE_COLORS := {true: HudTheme.OK, false: HudTheme.BAD} #friend, rival
const LEAVE_ACTION := "ui_coop_leave" #InputGlyphs.ensureMenuActions

var body := VBoxContainer.new()

func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(1, 1, 1, 0.22), 16, 2, Vector4(16, 8, 16, 8)))
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(body)

#a pad button as the key hints draw one (the guest is always on a pad, whatever the first player holds)
static func chip(index: int) -> Control:
	return MenuTheme.chip(InputGlyphs.PAD_NAMES.get(index, "?"), 12)

static func label(text: String, variation: String, fontSize: int) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", fontSize)
	l.clip_text = true
	return l

#a row of the guest's buttons and what each does: [[buttons], word] pairs
static func hints(list: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for hint in list:
		for index in hint[0]: row.add_child(chip(index))
		var word := label(hint[1], "MutedLabel", 12)
		word.clip_text = false
		row.add_child(word)
		var gap := Control.new()
		gap.custom_minimum_size.x = 4
		row.add_child(gap)
	return row

## Redraws the plate from Coop; `info` is the guest's car's CarInfo (null while it loads) and `mode` the
## selected mode, which picks the guest's side
func refresh(info: CarInfo, mode: int) -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if not Coop.active:
		body.add_child(label("PLAYER 2", "MutedLabel", 15))
		body.add_child(hints([[[JOY_BUTTON_START], "on a second controller to join"]]))
		body.add_child(label("Split screen. The run, its rewards and its records stay player one's.", "MutedLabel", 12))
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = PIC
	pic.texture = info.sidePic if info else null
	top.add_child(pic)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", -4)
	var rival := Coop.isRival(mode)
	var side := label("PLAYER 2  -  %s" % ("RIVAL" if rival else "FRIEND"), "MutedLabel", 13)
	side.add_theme_color_override("font_color", SIDE_COLORS[not rival])
	side.tooltip_text = "The mode picks player two's side: against you in the Goon Cup, with you everywhere else."
	who.add_child(side)
	who.add_child(label(info.charName.to_upper() if info else "", "GoldLabel", 18))
	top.add_child(who)
	for id in [Coop.gadget, Coop.boost]: #what they start with; an empty ring for nothing
		var slot := TextureRect.new()
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.custom_minimum_size = Vector2(ITEM, ITEM)
		slot.size_flags_vertical = SIZE_SHRINK_CENTER
		slot.texture = Pickups.texture(id) if id != "" else null
		var ring := Panel.new()
		ring.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, -3)
		ring.show_behind_parent = true
		ring.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.3), int(ITEM), 2, Vector4.ZERO))
		slot.add_child(ring)
		top.add_child(slot)
	body.add_child(top)
	body.add_child(hints([[[JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER], "Car"], [[JOY_BUTTON_X], "Gadget"], [[JOY_BUTTON_Y], "Boost"], [[JOY_BUTTON_B], "Leave"]]))
	for child in body.get_children(): LaunchBar.ignoreMouse(child)
	var remove := KeyHint.make(PackedStringArray([LEAVE_ACTION]), "Remove player 2", 12, true) #the first player's own way: its key, or a click
	remove.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_child(remove)
