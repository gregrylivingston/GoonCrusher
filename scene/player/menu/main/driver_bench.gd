class_name DriverBench extends PanelContainer

#The garage's driver focus (main2.gd; docs/UI.md, "Driver focus"): the bench that opens beside the focused
#driver's card while the other drivers are off screen. Top to bottom:
#  head       UPGRADES, the car's strong and weak stats against the other cars, and the levels bought
#  rows       the eight stats (DriverCard.STATS): icon, name and what it does, a bar against 100 (cream = the
#             car's base stat, gold = upgrades bought), the value, the level and a button that buys the next
#             one (the price in symbols, solid orange when the bank covers it, MAX at the cap)
#  signature  the car's two features (CarTraits) with their full text, and its best run
#A locked car shows the same sheet with no buttons (STATS); the dock's main button unlocks it.
#Up and Down move between the buy buttons and Buy (E / A, `ui_buy`; main2 routes it) or a click buys; Accept
#stays on Drive. `bought` follows each purchase.

signal bought(stat: int)

const SIZE := Vector2(1008, 600)
const BUY_WIDTH := 190.0
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")
const UPGRADE_ICON := preload("res://texture/icon/upgrade.svg")

var index := -1
var info: CarInfo
var lastStat: int = Root.upgrade.ENGINE #the row the focus was on last: it stays there from driver to driver
var rows: Array[Dictionary] = []     #per DriverCard.STATS: panel, bar, value, plus, level, button
var title := Label.new()
var summary := Label.new()
var boughtLabel := Label.new()
var bestRow := HBoxContainer.new()
var signature := HBoxContainer.new()

func _ready() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.93), HudTheme.RIM, 14, 3, Vector4(18, 12, 18, 12)))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
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
	boughtLabel.theme_type_variation = "MutedLabel"
	boughtLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(boughtLabel)
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	column.add_child(list)
	for s in DriverCard.STATS: list.add_child(makeRow(s))
	var rule = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.14)
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var signatureHead = HBoxContainer.new()
	column.add_child(signatureHead)
	var heading = Label.new()
	heading.text = "SIGNATURE"
	heading.theme_type_variation = "MutedLabel"
	heading.add_theme_font_size_override("font_size", 15)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signatureHead.add_child(heading)
	bestRow.mouse_filter = MOUSE_FILTER_IGNORE
	signatureHead.add_child(bestRow)
	signature.add_theme_constant_override("separation", 24)
	column.add_child(signature)

#a stat's row; `refresh` fills in its numbers and its button
func makeRow(s: Array) -> PanelContainer:
	var stat: int = s[1]
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 8, 2, Vector4(12, 3, 10, 3)))
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
	names.add_child(what)
	var bar = DriverCard.StatBar.new()
	bar.custom_minimum_size = Vector2(120, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value = Label.new()
	value.add_theme_font_size_override("font_size", 20)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 44
	row.add_child(value)
	var plus = Label.new()
	plus.add_theme_font_size_override("font_size", 15)
	plus.add_theme_color_override("font_color", HudTheme.GOLD)
	plus.custom_minimum_size.x = 40
	row.add_child(plus)
	var level = Label.new()
	level.theme_type_variation = "MutedLabel"
	level.add_theme_font_size_override("font_size", 14)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.custom_minimum_size.x = 60
	row.add_child(level)
	var buy = MenuTheme.button("")
	buy.custom_minimum_size = Vector2(BUY_WIDTH, 36)
	buy.set_meta("stat", stat)
	buy.pressed.connect(buyUpgrade.bind(stat))
	buy.focus_entered.connect(func(): lastStat = stat) #only the button shows the focus, not the row
	row.add_child(buy)
	rows.push_back({"stat": stat, "panel": panel, "bar": bar, "value": value, "plus": plus, "level": level, "button": buy})
	return panel

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
		r.plus.text = "+%d" % level if level > 0 else ""
		r.level.text = "%d / %d" % [level, SaveManager.MAX_UPGRADE_LEVEL]
		r.level.visible = not locked
		var b: Button = r.button
		b.visible = not locked
		if locked: continue
		var maxed := SaveManager.isUpgradeMaxed(s[1], index)
		var cost := SaveManager.requestStatCost(s[1], index)
		var affordable := not maxed && cost <= SaveManager.playerData.coin
		b.disabled = maxed
		b.theme_type_variation = "PrimaryButton" if affordable else ""
		MenuTheme.setButtonParts(b, ["MAX"] if maxed else [UPGRADE_ICON, {"coin": cost}], 17)
		b.get_node("parts").offset_right = 0 #no key hint to clear
		b.get_node("parts").modulate = Color.WHITE if affordable || maxed else Color(1, 1, 1, 0.55)
		b.custom_minimum_size.x = BUY_WIDTH #the columns stay in line
		b.tooltip_text = "" if maxed else "Next %s upgrade (%d / %d)" % [DriverCard.STAT_TEXT[s[0]][0], level + 1, SaveManager.MAX_UPGRADE_LEVEL]
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

## Up from the first row stays there; Down from the last goes to `below` (the dock's main button) and back
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

#a signature feature: its icon, name and kind (with the Ability key), and its full text
func signatureBlock(id: StringName) -> HBoxContainer:
	var block = HBoxContainer.new()
	block.add_theme_constant_override("separation", 12)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := MenuTheme.iconRect(CarTraits.texture(id), 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	block.add_child(icon)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	block.add_child(column)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var traitName = Label.new()
	traitName.text = CarTraits.displayName(id)
	traitName.theme_type_variation = "GoldLabel"
	traitName.add_theme_font_size_override("font_size", 20)
	head.add_child(traitName)
	var kind = Label.new()
	kind.text = CarTraits.KIND_NAMES[CarTraits.kind(id)]
	if CarTraits.kind(id) == CarTraits.Kind.ABILITY: kind.text += "  ·  " + InputGlyphs.label("Ability")
	kind.add_theme_font_size_override("font_size", 12)
	kind.add_theme_color_override("font_color", CarTraits.color(id))
	kind.add_theme_constant_override("outline_size", 0)
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kind)
	var text = Label.new()
	text.text = CarTraits.DATA[id].text
	text.theme_type_variation = "BodyLabel"
	text.add_theme_font_size_override("font_size", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 200
	column.add_child(text)
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
