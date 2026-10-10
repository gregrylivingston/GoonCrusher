class_name DriverBench extends Control

#The garage's driver focus (main2.gd; docs/UI.md, "Driver focus"): the bench that opens beside the focused
#driver's card while the other drivers are off screen. Two panels, so the launch bar keeps its place:
#  stats      UPGRADES, the car's strong and weak stats against the other cars, its best run and the levels
#             bought, over the eight stats (DriverCard.STATS): icon, name and what it does, a bar against 100
#             (cream = the car's base stat, gold = upgrades bought), the value, the level and a button that
#             buys the next one (the price in symbols, gold when the bank covers it, MAX at the cap). The
#             row in focus is lit, shows what the next level makes the value and the Buy key.
#  signature  in the bottom row, beside the launch bar: the car's two features (CarTraits) with their full text
#A locked car shows the same sheet with no buttons (STATS); the launch bar's primary button unlocks it.
#Up and Down move between the buy buttons and Buy (E / A, `ui_buy`; main2 routes it) or a click buys, one
#level a press; a click anywhere on a row takes the focus there. Accept stays on Drive.
#`bought` follows each purchase.

signal bought(stat: int)

const SIZE := Vector2(1008, 672)
const STATS_SIZE := Vector2(1008, 532)
const SIGNATURE := Rect2(0, 544, 640, 128) #level with the launch bar, and as tall (main2.LAUNCH_POS, LaunchBar.SIZE)
const BUY_WIDTH := 190.0
const NEXT_TEXT := Color(0.6, 0.9, 0.45)
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")
const UPGRADE_ICON := preload("res://texture/icon/upgrade.svg")

var index := -1
var info: CarInfo
var lastStat: int = Root.upgrade.ENGINE #the row the focus was on last: it stays there from driver to driver
var rows: Array[Dictionary] = []     #per DriverCard.STATS: panel, bar, value, next, preview, level, button, key
var title := Label.new()
var summary := Label.new()
var boughtLabel := Label.new()
var bestRow := HBoxContainer.new()
var signature := HBoxContainer.new()

func _ready() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	var stats = PanelContainer.new()
	stats.size = STATS_SIZE
	stats.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.93), HudTheme.RIM, 14, 3, Vector4(18, 12, 18, 12)))
	add_child(stats)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	stats.add_child(column)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	title.theme_type_variation = "GoldLabel"
	title.add_theme_font_size_override("font_size", 26)
	head.add_child(title)
	summary.theme_type_variation = "MutedLabel"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.clip_text = true
	head.add_child(summary)
	bestRow.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(bestRow)
	boughtLabel.theme_type_variation = "MutedLabel"
	boughtLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(boughtLabel)
	var list = VBoxContainer.new() #the rows share the panel's height
	list.add_theme_constant_override("separation", 3)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list)
	for s in DriverCard.STATS: list.add_child(makeRow(s))
	var panel = PanelContainer.new()
	panel.position = SIGNATURE.position
	panel.size = SIGNATURE.size
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(1, 1, 1, 0.22), 16, 2, Vector4(16, 8, 16, 8)))
	add_child(panel)
	signature.add_theme_constant_override("separation", 20)
	panel.add_child(signature)

#a stat's row; `refresh` fills in its numbers and its button, `lightRows` lights the one in focus
func makeRow(s: Array) -> PanelContainer:
	var stat: int = s[1]
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", rowBox(false))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := MenuTheme.iconRect(s[2], 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var names = VBoxContainer.new()
	names.custom_minimum_size.x = 300
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -3)
	row.add_child(names)
	var statName = Label.new()
	statName.text = DriverCard.STAT_TEXT[s[0]][0]
	statName.add_theme_font_size_override("font_size", 18)
	statName.add_theme_constant_override("outline_size", 0)
	names.add_child(statName)
	var what = Label.new()
	what.text = DriverCard.STAT_TEXT[s[0]][1]
	what.theme_type_variation = "MutedLabel"
	what.add_theme_font_size_override("font_size", 13)
	what.clip_text = true
	names.add_child(what)
	var bar = DriverCard.StatBar.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var value = Label.new()
	value.add_theme_font_size_override("font_size", 20)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 44
	row.add_child(value)
	var next = Label.new() #what the next level makes it, on the row in focus
	next.add_theme_font_size_override("font_size", 17)
	next.add_theme_color_override("font_color", NEXT_TEXT)
	next.custom_minimum_size.x = 56
	row.add_child(next)
	var level = Label.new()
	level.theme_type_variation = "MutedLabel"
	level.add_theme_font_size_override("font_size", 14)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.custom_minimum_size.x = 60
	row.add_child(level)
	var buy = MenuTheme.button("")
	buy.custom_minimum_size = Vector2(BUY_WIDTH, 36)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.set_meta("stat", stat)
	buy.pressed.connect(buyUpgrade.bind(stat))
	buy.focus_entered.connect(onRowFocus.bind(stat))
	buy.focus_exited.connect(lightRows)
	var key = KeyHint.make(PackedStringArray(["ui_buy"]), "", 13)
	key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	key.grow_vertical = Control.GROW_DIRECTION_BOTH
	key.offset_left = 10
	key.visible = false
	buy.add_child(key)
	row.add_child(buy)
	panel.gui_input.connect(onRowInput.bind(buy))
	rows.push_back({"stat": stat, "panel": panel, "bar": bar, "value": value, "next": next, "preview": "", "level": level, "button": buy, "key": key})
	return panel

static func rowBox(lit: bool) -> StyleBoxFlat:
	return MenuTheme.box(Color(HudTheme.RIM, 0.13) if lit else Color(1, 1, 1, 0.035), Color(HudTheme.RIM, 0.9 if lit else 0.0), 8, 2, Vector4(12, 3, 10, 3))

func onRowFocus(stat: int) -> void:
	lastStat = stat
	lightRows()

#the row in focus: lit, with its preview and the Buy key
func lightRows() -> void:
	for r in rows:
		var lit: bool = r.button.has_focus()
		r.panel.add_theme_stylebox_override("panel", rowBox(lit))
		r.next.text = r.preview if lit else ""
		r.key.visible = lit && not r.button.disabled && InputGlyphs.label("ui_buy") != ""

#a click anywhere on a row takes the focus to its button (a click on the button itself buys)
func onRowInput(event: InputEvent, button: Button) -> void:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed && button.visible: button.grab_focus()

func rowFor(stat: int) -> Dictionary:
	for r in rows:
		if r.stat == stat: return r
	return {}

## Shows a car. `infos` are the CarInfos loaded so far, for the strong and weak line.
func setup(carIndex: int, carInfo: CarInfo, infos: Array) -> void:
	index = carIndex
	info = carInfo
	summary.text = strongWeak(info, infos)
	for child in signature.get_children():
		signature.remove_child(child)
		child.queue_free()
	for id in info.traits:
		if CarTraits.has(id): signature.add_child(signatureBlock(id))
	refresh()

func isLocked() -> bool:
	return SaveManager.playerData.cars[index].cost != 0 || (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT)

## Everything a purchase changes: the numbers, the prices and which the bank covers
func refresh() -> void:
	if info == null || index < 0: return
	var car: Dictionary = SaveManager.playerData.cars[index]
	var locked := isLocked()
	title.text = "STATS" if locked else "UPGRADES"
	var total := 0
	for i in rows.size():
		var s: Array = DriverCard.STATS[i]
		var r := rows[i]
		var base: int = info.get(s[0])
		var level: int = int(car.upgrades.get(s[1], 0))
		total += level
		r.bar.base = base
		r.bar.bought = level
		r.bar.queue_redraw()
		r.value.text = str(base + level)
		r.level.text = "%d / %d" % [level, SaveManager.MAX_UPGRADE_LEVEL]
		r.level.visible = not locked
		var b: Button = r.button
		b.visible = not locked
		r.preview = ""
		if locked: continue
		var maxed := SaveManager.isUpgradeMaxed(s[1], index)
		var cost := SaveManager.requestStatCost(s[1], index)
		var affordable := not maxed && cost <= SaveManager.playerData.coin
		r.preview = "" if maxed else "> %d" % (base + level + 1)
		b.disabled = maxed
		#the price in gold when the bank covers it; only the launch bar's button is solid orange
		var old = b.get_node_or_null("parts")
		if old:
			b.remove_child(old)
			old.queue_free()
		var parts := MenuTheme.symbolRow(["MAX"] if maxed else [UPGRADE_ICON, {"coin": cost}], 17, HudTheme.GOLD if affordable else HudTheme.MUTED)
		parts.name = "parts"
		parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parts.offset_left = 26 #clear of the Buy key
		parts.modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.55)
		b.add_child(parts)
		b.tooltip_text = "" if maxed else "Next %s upgrade (%d / %d)" % [DriverCard.STAT_TEXT[s[0]][0], level + 1, SaveManager.MAX_UPGRADE_LEVEL]
	lightRows()
	boughtLabel.text = "" if locked else "%d / %d bought" % [total, rows.size() * SaveManager.MAX_UPGRADE_LEVEL]
	for child in bestRow.get_children():
		bestRow.remove_child(child)
		child.queue_free()
	var records: Dictionary = car.get("records", {})
	if int(records.get("goonsCrushed", 0)) > 0:
		bestRow.add_child(MenuTheme.symbolRow(["Best run   %d crushed   " % records.goonsCrushed, {"coin": int(records.get("coin", 0))}], 15, HudTheme.MUTED, 0))

## The buy button for a stat, or null while the car is locked
func upgradeButton(stat: int) -> Button:
	var r := rowFor(stat)
	return r.button if not r.is_empty() && r.button.visible else null

## Where the focus goes when the bench opens or the driver changes: the row it was on last
func focusButton() -> Button:
	return upgradeButton(lastStat)

## True while one of the buy buttons has the focus
func rowFocused() -> bool:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return focused != null && rows.any(func(r): return r.button == focused)

## Up from the first row stays there; Down from the last goes to `below` (the launch bar's primary button) and back
func linkFocus(below: Control) -> void:
	if rows.is_empty(): return
	var first: Button = rows[0].button
	var last: Button = rows[-1].button
	first.focus_neighbor_top = first.get_path()
	last.focus_neighbor_bottom = below.get_path()
	below.focus_neighbor_top = last.get_path() if last.visible else NodePath()

## Buys the next level of a stat at the garage's price, and shows it: a gold wash over the row, the bar's
## new part glowing, the number popping. A shake when the bank is short or the stat is maxed.
func buyUpgrade(stat: int) -> void:
	var r := rowFor(stat)
	if r.is_empty(): return
	if not SaveManager.requestStatUpgrade(stat, index):
		Juice.shake(r.button)
		return
	Audio.play(BUY_SOUND)
	SaveManager.flush()
	refresh()
	Juice.flash(r.panel, HudTheme.GOLD, 0.45, 8)
	Juice.pop(r.value, 1.35)
	r.bar.glow = 1.0
	r.bar.create_tween().tween_property(r.bar, "glow", 0.0, 0.6)
	bought.emit(stat)

#a signature feature: its icon, name and kind (with the Ability key) over its full text
func signatureBlock(id: StringName) -> VBoxContainer:
	var block = VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 0)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	block.add_child(head)
	var icon := MenuTheme.iconRect(CarTraits.texture(id), 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var traitName = Label.new()
	traitName.text = CarTraits.displayName(id)
	traitName.theme_type_variation = "GoldLabel"
	traitName.add_theme_font_size_override("font_size", 17)
	head.add_child(traitName)
	var kind = Label.new()
	kind.text = CarTraits.KIND_NAMES[CarTraits.kind(id)]
	if CarTraits.kind(id) == CarTraits.Kind.ABILITY: kind.text += "  ·  " + InputGlyphs.label("Ability")
	kind.add_theme_font_size_override("font_size", 11)
	kind.add_theme_color_override("font_color", CarTraits.color(id))
	kind.add_theme_constant_override("outline_size", 0)
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kind)
	var text = Label.new()
	text.text = CarTraits.DATA[id].text
	text.theme_type_variation = "BodyLabel"
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_constant_override("line_spacing", -1)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 200
	block.add_child(text)
	return block

## "Strong engine and armor. Weak lights." against the average of `infos`
static func strongWeak(info: CarInfo, infos: Array) -> String:
	if infos.size() < 2: return ""
	var ratios = []
	for s in DriverCard.STATS:
		var total := 0.0
		for other in infos: total += other.get(s[0])
		ratios.push_back([str(DriverCard.STAT_TEXT[s[0]][0]).to_lower(), info.get(s[0]) / maxf(total / infos.size(), 1.0)])
	ratios.sort_custom(func(a, b): return a[1] > b[1])
	var strong = ratios.filter(func(r): return r[1] >= 1.2).slice(0, 2).map(func(r): return r[0])
	var weak = ratios.filter(func(r): return r[1] <= 0.8)
	var parts = []
	if not strong.is_empty(): parts.push_back("Strong " + " and ".join(strong) + ".")
	if not weak.is_empty(): parts.push_back("Weak " + weak.back()[0] + ".")
	return " ".join(parts) if not parts.is_empty() else "An all-rounder."
