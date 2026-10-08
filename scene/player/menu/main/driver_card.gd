class_name DriverCard extends Panel

#One driver in the garage carousel (main2.gd). The card is drawn at 380 x 640 and the carousel
#scales the side cards down. Only the focused card shows stats and buttons:
#  stats    browsing: a compact 2 x 4 grid (icon, value, an underline against 100: cream = the car's
#           base stat, gold = upgrades bought). Clicking a stat opens the upgrade sheet on it.
#  sheet    upgrade mode: the art folds up and the stats become one row each with the stat's name and
#           the next upgrade's price. Hovering a row focuses it, and the focused row's price becomes a
#           BUY button. Accept or a click buys, on the press; holding Accept keeps buying.
#  buttons  Drive (or Unlock with its price) and Upgrade (Done in upgrade mode)
#Locked drivers show as a silhouette with their unlock price.

signal drivePressed
signal unlockPressed
signal upgradePressed(stat: Root.upgrade)
signal sheetRequested(stat: Root.upgrade)
signal selectRequested

const SIZE := Vector2(380, 640)
const ART_HEIGHT := 380.0
const SHEET_ART_HEIGHT := 150.0  #the art's height with the upgrade sheet open
const BAND_HEIGHT := 64.0
const SHEET_SECONDS := 0.28
const PRICE_WIDTH := 84.0 #a sheet row's price slot; the focused row's BUY button widens it
const HOLD_DELAY := 0.4    #holding Accept on a sheet row buys again after this...
const HOLD_REPEAT := 0.12  #...and then this often, until the stat maxes or the coins run out
const STATS := [
	["engine", Root.upgrade.ENGINE, preload("res://texture/icon/engine.svg")],
	["steering", Root.upgrade.STEERING, preload("res://texture/icon/steering.svg")],
	["traction", Root.upgrade.TRACTION, preload("res://texture/icon/traction.svg")],
	["armor", Root.upgrade.ARMOR, preload("res://texture/icon/armor.svg")],
	["oil", Root.upgrade.OIL, preload("res://texture/icon/oil.svg")],
	["headlights", Root.upgrade.HEADLIGHTS, preload("res://texture/icon/headlights.svg")],
	["clover", Root.upgrade.CLOVER, preload("res://texture/icon/clover.svg")],
	["luck", Root.upgrade.LUCK, preload("res://texture/icon/luck.svg")],
]
#the sheet's name and tooltip for each stat
const STAT_TEXT := {
	"engine": ["Engine", "Acceleration and top speed"],
	"steering": ["Steering", "How fast the car turns"],
	"traction": ["Traction", "Grip on loose and slick ground"],
	"armor": ["Armor", "Less damage from goons and walls"],
	"oil": ["Oil", "Burns less fuel"],
	"headlights": ["Lights", "Headlight reach at night"],
	"clover": ["Clover", "Chance a crushed goon drops a pickup"],
	"luck": ["Dice", "Better prizes from pickups and slots"],
}

var car: Dictionary          #the save's entry: name, scene, cost, upgrades, records
var info: CarInfo
var index := 0
var focused := false
var demoLocked := false
var upgrading := false
var sheetAmount := 0.0       #0 browsing, 1 upgrade sheet open; tweened by setUpgradeMode

var art := TextureRect.new()
var portrait := TextureRect.new()
var band := ColorRect.new()
var nameLabel := Label.new()
var infoLabel := Label.new()
var priceLine := Control.new() #a locked driver's price, as numbers and symbols, under the car type
var stats := Control.new()       #holds both stat layouts
var compact := GridContainer.new()
var sheet := VBoxContainer.new()
var actions := HBoxContainer.new()
var frame := Panel.new()
var catcher := Button.new() #a click anywhere on a side card selects it
var mainButton: Button
var upgradeButton: Button
var statButtons: Array[Button] = []    #the sheet's rows, which buy
var compactButtons: Array[Button] = [] #the grid's rows, which open the sheet
var sheetTween: Tween
var holdTime := 0.0

func _ready() -> void:
	set_process(false) #runs in upgrade mode only, for the held Accept
	size = SIZE
	custom_minimum_size = SIZE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", MenuTheme.box(Color(0.082, 0.067, 0.059, 0.97), Color(0, 0, 0, 0), 18, 0))
	for picture in [art, portrait]:
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(picture)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	band.color = HudTheme.RIM
	band.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(band)
	nameLabel.theme_type_variation = "DarkLabel"
	nameLabel.add_theme_font_size_override("font_size", 38)
	nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(nameLabel)

	infoLabel.theme_type_variation = "BodyLabel"
	infoLabel.add_theme_font_size_override("font_size", 26)
	infoLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infoLabel.position = Vector2(0, ART_HEIGHT + BAND_HEIGHT + 24)
	infoLabel.size = Vector2(SIZE.x, 40)
	add_child(infoLabel)
	priceLine.position = Vector2(0, ART_HEIGHT + BAND_HEIGHT + 68)
	priceLine.size = Vector2(SIZE.x, 36)
	priceLine.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(priceLine)

	stats.mouse_filter = MOUSE_FILTER_IGNORE
	stats.size = SIZE
	add_child(stats)
	compact.columns = 2
	compact.add_theme_constant_override("h_separation", 6)
	compact.add_theme_constant_override("v_separation", 2)
	compact.position = Vector2(12, ART_HEIGHT + BAND_HEIGHT + 8)
	compact.size = Vector2(SIZE.x - 24, 124)
	compact.mouse_filter = MOUSE_FILTER_IGNORE
	stats.add_child(compact)
	sheet.add_theme_constant_override("separation", 2)
	sheet.position = Vector2(12, SHEET_ART_HEIGHT + BAND_HEIGHT + 8)
	sheet.size = Vector2(SIZE.x - 24, SIZE.y - 74 - (SHEET_ART_HEIGHT + BAND_HEIGHT + 8))
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	stats.add_child(sheet)
	for s in STATS:
		compactButtons.push_back(makeCompactRow(s))
		statButtons.push_back(makeSheetRow(s))

	actions.add_theme_constant_override("separation", 10)
	actions.position = Vector2(14, SIZE.y - 66)
	actions.size = Vector2(SIZE.x - 28, 54)
	add_child(actions)
	mainButton = MenuTheme.button("DRIVE", PackedStringArray(["ui_accept"]), true)
	mainButton.custom_minimum_size = Vector2(0, 52)
	mainButton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mainButton.add_theme_font_size_override("font_size", 24)
	mainButton.pressed.connect(onMainPressed)
	actions.add_child(mainButton)
	upgradeButton = MenuTheme.button("Upgrade", PackedStringArray(["ui_upgrade"]), false, preload("res://texture/icon/upgrade.svg"))
	upgradeButton.custom_minimum_size = Vector2(168, 52)
	upgradeButton.add_theme_font_size_override("font_size", 18)
	upgradeButton.pressed.connect(func(): upgradePressed.emit(-1))
	actions.add_child(upgradeButton)

	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.size = SIZE
	add_child(frame)
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.size = SIZE
	catcher.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(func(): selectRequested.emit())
	add_child(catcher)
	applySheet(0.0)
	setFocused(false)

#a stat row: a Button whose highlight is the row itself, holding a line laid out inside its margins.
#Everything in the line ignores the mouse so a click anywhere on the row reaches the button.
func statRow(stat: Array, height: float, inset: float) -> Array:
	var row = Button.new()
	row.theme_type_variation = "StatRow"
	row.custom_minimum_size = Vector2(0, height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	row.tooltip_text = "%s: %s" % STAT_TEXT[stat[0]]
	var line = HBoxContainer.new()
	line.name = "line"
	line.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 7)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = inset
	line.offset_right = -inset
	row.add_child(line)
	return [row, line]

func makeCompactRow(stat: Array) -> Button:
	var parts = statRow(stat, 29, 8)
	var row: Button = parts[0]
	var line: HBoxContainer = parts[1]
	line.add_child(MenuTheme.iconRect(stat[2], 20))
	line.add_child(valueLabel(18, 28))
	line.add_child(statBar(6))
	row.pressed.connect(func(): sheetRequested.emit(stat[1]))
	MenuTheme.addSounds(row)
	compact.add_child(row)
	return row

func makeSheetRow(stat: Array) -> Button:
	var parts = statRow(stat, 40, 12)
	var row: Button = parts[0]
	var line: HBoxContainer = parts[1]
	line.add_child(MenuTheme.iconRect(stat[2], 26))
	var title = Label.new()
	title.text = STAT_TEXT[stat[0]][0].to_upper()
	title.theme_type_variation = "BodyLabel"
	title.add_theme_font_size_override("font_size", 17)
	title.custom_minimum_size.x = 92
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(title)
	line.add_child(valueLabel(22, 34))
	line.add_child(statBar(8))
	var price = Control.new()
	price.name = "price"
	price.custom_minimum_size = Vector2(PRICE_WIDTH, 26)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_child(price)
	row.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS #buys on the press, so a held Accept repeats from there
	row.pressed.connect(onSheetRowPressed.bind(row, stat[1]))
	row.mouse_entered.connect(func():
		if row.focus_mode != Control.FOCUS_NONE: row.grab_focus())
	row.focus_entered.connect(showBuy.bind(row, true))
	row.focus_exited.connect(showBuy.bind(row, false))
	MenuTheme.addSounds(row)
	sheet.add_child(row)
	return row

static func valueLabel(fontSize: int, width: float) -> Label:
	var value = Label.new()
	value.name = "value"
	value.custom_minimum_size.x = width
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_theme_font_size_override("font_size", fontSize)
	value.mouse_filter = MOUSE_FILTER_IGNORE
	return value

static func statBar(height: float) -> StatBar:
	var bar = StatBar.new()
	bar.name = "bar"
	bar.custom_minimum_size = Vector2(30, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	return bar

func setup(entry: Dictionary, carInfo: CarInfo, carIndex: int) -> void:
	car = entry
	info = carInfo
	index = carIndex
	demoLocked = Root.IS_DEMO && carIndex >= Root.DEMO_CAR_COUNT
	art.texture = info.backgroundPic
	portrait.texture = info.profilePic
	refresh()

func isLocked() -> bool:
	return car.cost != 0 || demoLocked

#everything that can change while the menu is open: lock state, prices, stats, coins
func refresh() -> void:
	if info == null: #still loading: a plain card with the car's name
		nameLabel.text = str(car.get("name", "")).to_upper()
		infoLabel.text = ""
		stats.visible = false
		actions.visible = false
		return
	var locked = isLocked()
	portrait.modulate = Color(0, 0, 0, 0.88) if locked else Color.WHITE
	nameLabel.text = info.charName.to_upper()
	var type = info.carId.capitalize()
	infoLabel.text = "Not in the demo" if demoLocked else type
	stats.visible = focused && not locked
	infoLabel.visible = not stats.visible
	for child in priceLine.get_children():
		priceLine.remove_child(child)
		child.queue_free()
	var cost := Unlocks.price("car:" + str(car.name))
	if car.cost != 0 && not demoLocked: #"10,000 (coin)  5 (gem)", gold when the bank covers it
		var row := MenuTheme.symbolRow([HudTheme.LOCK_ICON, "  ", cost], 26, HudTheme.GOLD if Unlocks.canAfford("car:" + str(car.name)) else MenuTheme.BODY_TEXT)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		priceLine.add_child(row)
	priceLine.visible = infoLabel.visible
	actions.visible = focused
	upgradeButton.visible = not locked
	upgradeButton.text = "Done" if upgrading else "Upgrade"
	var oldParts = mainButton.get_node_or_null("parts")
	if oldParts:
		mainButton.remove_child(oldParts)
		oldParts.queue_free()
	if demoLocked:
		mainButton.text = "NOT IN DEMO"
		mainButton.disabled = true
	elif car.cost != 0: #entry cars cost coins; advanced ones coins and gems (Unlocks.price); the price is shown above
		var short := {}
		if car.cost > SaveManager.playerData.coin: short.coin = car.cost - SaveManager.playerData.coin
		if int(car.get("gems", 0)) > SaveManager.playerData.gem: short.gem = int(car.gems) - SaveManager.playerData.gem
		mainButton.disabled = not short.is_empty()
		if short.is_empty(): mainButton.text = "UNLOCK"
		else: MenuTheme.setButtonParts(mainButton, ["NEED", short, "MORE"], 20)
	else:
		mainButton.text = "DRIVE"
		mainButton.disabled = false
	if stats.visible: refreshStats()

func refreshStats() -> void:
	for i in STATS.size():
		var s = STATS[i]
		var base: int = info.get(s[0])
		var level = SaveManager.getUpgradeLevel(s[1])
		for row in [compactButtons[i], statButtons[i]]:
			row.get_node("line/value").text = str(base + level)
			var bar: StatBar = row.get_node("line/bar")
			bar.base = base
			bar.bought = level
			bar.queue_redraw()
		var row = statButtons[i]
		var holder: Control = row.get_node("line/price")
		for child in holder.get_children():
			holder.remove_child(child) #now, so the new chips keep their names
			child.queue_free()
		var maxed = SaveManager.isUpgradeMaxed(s[1])
		var affordable = canBuy(s[1])
		var price = "MAX" if maxed else formatCoins(SaveManager.requestStatCost(s[1]))
		var chipPanel = MenuTheme.priceChip(price, HudTheme.COIN_ICON, affordable)
		chipPanel.name = "plain"
		holder.add_child(chipPanel)
		if not maxed:
			var buy = buyChip(price)
			buy.name = "buy"
			holder.add_child(buy)
		for chip in holder.get_children(): chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
		#unaffordable rows stay pressable so a click can say no (shakeRow); they are only dimmed
		row.get_node("line").modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.55)
		showBuy(row, row.has_focus())

#the focused row's price turns into a solid BUY button (none once the stat is maxed); the slot widens
#for it and the bar gives up the room
func showBuy(row: Button, isFocused: bool) -> void:
	var holder: Control = row.get_node("line/price")
	var buy: Control = holder.get_node_or_null("buy")
	var on = isFocused && buy != null
	holder.get_node("plain").visible = not on
	if buy:
		buy.visible = on
		buy.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	holder.custom_minimum_size.x = maxf(PRICE_WIDTH, buy.get_combined_minimum_size().x) if on else PRICE_WIDTH

#"BUY 504 (coin)" on the orange of the primary button
static func buyChip(price: String) -> PanelContainer:
	var chipPanel = PanelContainer.new()
	chipPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chipPanel.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.RIM, MenuTheme.DEEP_ORANGE, 7, 2, Vector4(8, 1, 8, 1)))
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in ["BUY", price, HudTheme.COIN_ICON]:
		if part is Texture2D:
			line.add_child(MenuTheme.iconRect(part, 18))
			continue
		var label = Label.new()
		label.text = part
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", MenuTheme.DARK_TEXT)
		label.add_theme_constant_override("outline_size", 0)
		line.add_child(label)
	chipPanel.add_child(line)
	return chipPanel

static func canBuy(stat: int) -> bool:
	return not SaveManager.isUpgradeMaxed(stat) && SaveManager.requestStatCost(stat) <= SaveManager.playerData.coin

func onSheetRowPressed(row: Button, stat: int) -> void:
	holdTime = 0.0
	if canBuy(stat): upgradePressed.emit(stat)
	else: Juice.shake(row)

#a held Accept on the focused row buys again every HOLD_REPEAT after HOLD_DELAY, and stops for good
#(until released) at the first upgrade it can't buy
func _process(delta: float) -> void:
	var at := statButtons.find(get_viewport().gui_get_focus_owner())
	if at < 0 || not Input.is_action_pressed("ui_accept") || Settings.menu_open:
		holdTime = 0.0
		return
	holdTime += delta
	if holdTime < HOLD_DELAY: return
	holdTime -= HOLD_REPEAT
	if canBuy(STATS[at][1]): upgradePressed.emit(STATS[at][1])
	else: holdTime = -INF

#a bought upgrade: the row flashes gold, the value pops and the bar's new segment glows
func celebrate(stat: int) -> void:
	for i in STATS.size():
		if STATS[i][1] != stat: continue
		var row = statButtons[i]
		Juice.flash(row, HudTheme.GOLD)
		Juice.pop(row.get_node("line/value"), 1.45)
		var bar: StatBar = row.get_node("line/bar")
		bar.glow = 1.0
		bar.create_tween().tween_property(bar, "glow", 0.0, 0.5)

static func formatCoins(amount: int) -> String:
	var text = str(amount)
	var out = ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out

func setFocused(value: bool) -> void:
	focused = value
	catcher.visible = not value
	frame.add_theme_stylebox_override("panel", frameBox(value))
	if not value && upgrading: setUpgradeMode(false, false)
	refresh()

static func frameBox(isFocused: bool) -> StyleBoxFlat:
	var style = MenuTheme.box(Color(0, 0, 0, 0), HudTheme.RIM if isFocused else Color(1, 1, 1, 0.22), 18, 5 if isFocused else 3)
	style.draw_center = false
	return style

#upgrade mode: the art folds up, the sheet's rows take focus so a controller or keyboard can buy,
#and the mouse focuses whichever row it is over. `stat` picks the row to start on.
func setUpgradeMode(on: bool, animate := true, stat := -1) -> void:
	upgrading = on
	holdTime = 0.0
	set_process(on)
	for row in statButtons: row.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if sheetTween: sheetTween.kill()
	if animate:
		sheetTween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		sheetTween.tween_method(applySheet, sheetAmount, 1.0 if on else 0.0, SHEET_SECONDS)
	else: applySheet(1.0 if on else 0.0)
	refresh()
	if not on:
		if focused: mainButton.grab_focus()
		return
	for i in STATS.size():
		if STATS[i][1] == stat:
			statButtons[i].grab_focus()
			return
	for i in STATS.size():
		if canBuy(STATS[i][1]):
			statButtons[i].grab_focus()
			return
	statButtons[0].grab_focus()

#lays the card out between browsing (0) and the upgrade sheet (1)
func applySheet(amount: float) -> void:
	sheetAmount = amount
	var artHeight = lerpf(ART_HEIGHT, SHEET_ART_HEIGHT, amount)
	art.size = Vector2(SIZE.x, artHeight)
	portrait.position = Vector2(10, lerpf(30, 8, amount))
	portrait.size = Vector2(SIZE.x - 20, artHeight - portrait.position.y)
	band.position = Vector2(0, artHeight)
	band.size = Vector2(SIZE.x, BAND_HEIGHT)
	nameLabel.position = band.position
	nameLabel.size = band.size
	compact.modulate.a = clampf(1.0 - amount * 2.5, 0.0, 1.0)
	compact.visible = compact.modulate.a > 0.0
	sheet.modulate.a = clampf(amount * 2.0 - 1.0, 0.0, 1.0)
	sheet.position.y = SHEET_ART_HEIGHT + BAND_HEIGHT + 8 + (1.0 - amount) * 40.0
	#shown (if still clear) for all of upgrade mode: hiding it early in the fade-in dropped the focus the
	#sheet's first row had just taken, leaving keys and pads with nothing to move
	sheet.visible = sheet.modulate.a > 0.0 || upgrading

func onMainPressed() -> void:
	if isLocked(): unlockPressed.emit()
	else: drivePressed.emit()

#a stat against 100: cream for the car's base value, gold for the upgrades bought on top,
#with faint ticks every 10. `glow` brightens the gold part for a moment after a purchase.
class StatBar extends Control:
	var base := 0
	var bought := 0
	var glow := 0.0:
		set(value):
			glow = value
			queue_redraw()
	func _draw() -> void:
		var w = size.x
		var h = size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.33, 0.3, 0.27))
		var b = w * clampf(base / 100.0, 0.0, 1.0)
		var g = w * clampf((base + bought) / 100.0, 0.0, 1.0)
		if b > 0.0: draw_rect(Rect2(0, 0, maxf(1.0, b), h), HudTheme.START)
		if g > b: draw_rect(Rect2(b, 0, maxf(1.0, g - b), h), HudTheme.GAIN.lerp(Color.WHITE, glow * 0.7))
		if h >= 8.0:
			for i in range(1, 10): draw_rect(Rect2(w * i / 10.0, 0, 1, h), Color(0, 0, 0, 0.35))
		if glow > 0.0: draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(HudTheme.GOLD, glow * 0.5), false, 2.0)
