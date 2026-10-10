class_name LaunchBar extends Panel

#The launch bar (docs/UI.md): one plate at the bottom right of the garage, the road map and Level Options,
#the same on all three. On the left the driver's car (a click or Q/E takes the next driver) over four slots,
#each with its key hanging off its foot, in two pairs: round, what the run starts with (the gadget and the
#boost, bought with gems at Start; a plus when empty), and square, where the bank is spent (Upgrades and
#Pickups, with a count of what it covers). On the right the round primary button, the only thing here that
#takes the focus, so Accept always goes on: DRIVE, SELECT or START. Nothing is written under the slots:
#their tooltips say what they hold and cost, and START's badge has the gems the loadout takes.
#This builds and draws it; main2 says what each part does and fills it in (refreshLaunch, refreshLoadout).

signal goPressed
signal driverPressed
signal slotPressed(slot: String)

const SIZE := Vector2(376, 128)
const PAD := Vector2(10, 8)
const DRIVER_HEIGHT := 46.0
const SLOT_SIZE := 48.0
const SLOT_GAP := 10.0  #between the two slots of a pair
const PAIR_GAP := 28.0  #between the pairs, with a rule down the middle
const GO_SIZE := 104.0
const SLOTS := ["loadout", "boostLoadout", "upgrades", "pickups"] #left to right; the first two are the loadout's (main2.SLOTS)
const SLOT_ACTIONS := {"loadout": "ui_gadget", "boostLoadout": "ui_boost", "upgrades": "ui_upgrade", "pickups": "ui_pickups"}
const UPGRADE_ICON := preload("res://texture/icon/upgrade.svg")
const PICKUPS_ICON := preload("res://texture/icon/gift.svg")
const BADGE_HEIGHT := 22.0
const BADGE_REST := Vector2(6, 0) #low on the slot's shoulder: a hop stays clear of the driver's keys

var goButton: Button
var driverButton := Button.new()
var driverPic := TextureRect.new()
var driverKeys: KeyHint
var slotButtons := {} #slot -> its round button
var badges := {}      #"upgrades", "pickups" -> how many the bank could buy right now
var gemBadge := PanelContainer.new() #on the primary button: the gems the loadout takes at Start

func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(1, 1, 1, 0.22), 16, 2, Vector4.ZERO))
	buildDriver()
	for i in SLOTS.size(): buildSlot(SLOTS[i], PAD + Vector2(i * (SLOT_SIZE + SLOT_GAP) + (i / 2) * (PAIR_GAP - SLOT_GAP), DRIVER_HEIGHT + 6.0), i >= 2)
	var rule = ColorRect.new() #between what the run starts with and where the bank is spent
	rule.color = Color(1, 1, 1, 0.16)
	rule.position = PAD + Vector2(2.0 * SLOT_SIZE + SLOT_GAP + PAIR_GAP / 2.0 - 1.0, DRIVER_HEIGHT + 10.0)
	rule.size = Vector2(2, SLOT_SIZE - 8.0)
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(rule)
	setSlot("upgrades", UPGRADE_ICON)
	setSlot("pickups", PICKUPS_ICON)
	for i in 2:
		var slot: String = SLOTS[2 + i]
		badges[slot] = CountBadge.on(slotButtons[slot], 0.35 * i, BADGE_HEIGHT, BADGE_REST)
	buildGo()

#the driver, across the top of the left side: the car's side view and the keys that change it. It has no
#frame of its own, only a pale wash under the mouse.
func buildDriver() -> void:
	MenuTheme.addSounds(driverButton)
	driverButton.position = PAD
	driverButton.size = Vector2(4.0 * SLOT_SIZE + 2.0 * SLOT_GAP + PAIR_GAP, DRIVER_HEIGHT)
	driverButton.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	driverButton.focus_mode = FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		driverButton.add_theme_stylebox_override(state, MenuTheme.box(Color(1, 1, 1, 0.0 if state == "normal" else 0.1), Color(0, 0, 0, 0), 10, 0, Vector4.ZERO))
	driverButton.pressed.connect(func(): driverPressed.emit())
	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -6
	driverPic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	driverPic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	driverPic.custom_minimum_size = Vector2(124, DRIVER_HEIGHT - 2.0)
	driverPic.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(driverPic)
	var gap = Control.new()
	gap.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(gap)
	driverKeys = KeyHint.make(PackedStringArray(["ui_tab_prev", "ui_tab_next"]), "", 12)
	driverKeys.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(driverKeys)
	driverButton.add_child(row)
	ignoreMouse(row)
	add_child(driverButton)

#a slot: a button showing what it holds (a plus when empty) over its key; the key or a click works it.
#`square` is the shape of Upgrades and Pickups, round the loadout's.
func buildSlot(slot: String, at: Vector2, square: bool) -> void:
	var b := Button.new()
	MenuTheme.addSounds(b)
	b.name = slot
	b.position = at
	b.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	b.focus_mode = FOCUS_NONE
	for state in ["normal", "hover", "pressed"]: #its rim lights under the mouse
		var style = MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(HudTheme.RIM, 0.9) if state == "hover" else Color(1, 1, 1, 0.3), 12 if square else int(SLOT_SIZE / 2.0), 2, Vector4.ZERO)
		style.corner_detail = 12
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(func(): slotPressed.emit(slot))
	var pic = TextureRect.new()
	pic.name = "pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2((SLOT_SIZE - 28.0) / 2.0, 5)
	pic.size = Vector2(28, 28)
	b.add_child(pic)
	var plus = Label.new()
	plus.name = "plus"
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 24)
	plus.add_theme_color_override("font_color", HudTheme.MUTED)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.position = pic.position
	plus.size = pic.size
	b.add_child(plus)
	var key = KeyHint.make(PackedStringArray([SLOT_ACTIONS[slot]]), "", 12)
	key.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	key.grow_horizontal = GROW_DIRECTION_BOTH #a wide chip (View) stays centered
	key.offset_top = -14
	key.offset_bottom = 8
	b.add_child(key)
	ignoreMouse(b)
	b.mouse_filter = MOUSE_FILTER_STOP
	add_child(b)
	slotButtons[slot] = b

#the round primary button: its word over its key, and the gem badge on its shoulder
func buildGo() -> void:
	goButton = MenuTheme.button("DRIVE", PackedStringArray(), true)
	goButton.position = Vector2(SIZE.x - PAD.x - GO_SIZE, (SIZE.y - GO_SIZE) / 2.0)
	goButton.size = Vector2(GO_SIZE, GO_SIZE)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = MenuTheme.theme().get_stylebox(state, "PrimaryButton").duplicate()
		if style is StyleBoxFlat:
			style.set_corner_radius_all(int(GO_SIZE / 2.0))
			style.corner_detail = 16
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 0
			style.content_margin_bottom = 24 #the word sits over its key
		goButton.add_theme_stylebox_override(state, style)
	var key = KeyHint.make(PackedStringArray(["ui_accept"]), "", 13)
	key.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	key.offset_top = -40
	key.offset_bottom = -15
	key.alignment = BoxContainer.ALIGNMENT_CENTER
	goButton.add_child(key)
	ignoreMouse(key)
	goButton.pressed.connect(func(): goPressed.emit())
	add_child(goButton)
	gemBadge.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.06, 0.07, 0.09), Color(0.3, 0.72, 1.0), 13, 2, Vector4(9, 0, 9, 0)))
	gemBadge.position = goButton.position + Vector2(GO_SIZE - 60.0, -8.0)
	gemBadge.mouse_filter = MOUSE_FILTER_IGNORE
	gemBadge.visible = false
	add_child(gemBadge)

## The primary button's word, and whether it can be pressed; a long or locked one is set smaller
func setGo(text: String, enabled: bool) -> void:
	goButton.text = text
	goButton.disabled = not enabled
	goButton.add_theme_font_size_override("font_size", 22 if enabled && text.length() <= 6 else 16)

func setDriver(side: Texture2D, charName: String) -> void:
	driverPic.texture = side
	driverButton.tooltip_text = "%s drives. Next driver" % charName

## The keys beside the driver: Q/E (LB/RB), or Left/Right while E buys on the bench
func setDriverKeys(actions: PackedStringArray) -> void:
	if driverKeys.actions == actions: return
	driverKeys.actions = actions
	if driverKeys.is_node_ready(): driverKeys.rebuild()

## What a slot holds: its picture, or a plus for nothing
func setSlot(slot: String, texture: Texture2D) -> void:
	var b: Button = slotButtons[slot]
	b.get_node("pic").texture = texture
	b.get_node("plus").visible = texture == null

## The gems Start will take for the loadout, on the primary button; hidden at 0
func setGems(cost: int) -> void:
	for child in gemBadge.get_children():
		gemBadge.remove_child(child)
		child.queue_free()
	gemBadge.visible = cost > 0
	if cost > 0: gemBadge.add_child(MenuTheme.symbolRow(["-", {"gem": cost}], 15))

#children of a button let the click through (docs/UI.md, "Mouse")
static func ignoreMouse(node: Node) -> void:
	if node is Control: node.mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignoreMouse(child)
