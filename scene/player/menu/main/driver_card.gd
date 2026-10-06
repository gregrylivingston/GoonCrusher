class_name DriverCard extends Panel

#One driver in the garage carousel (main2.gd). The card is drawn at 380 x 640 and the carousel
#scales the side cards down. Only the focused card shows stats, prices and buttons:
#  stats    one row per stat: icon, value, an underline against 100 (cream = the car's base stat,
#           gold = upgrades bought) and the next upgrade's price, always shown, dimmed if unaffordable
#  buttons  Drive (or Unlock with its price) and Upgrade
#Locked drivers show as a silhouette with their unlock price.

signal drivePressed
signal unlockPressed
signal upgradePressed(stat: Root.upgrade)
signal selectRequested

const SIZE := Vector2(380, 640)
const ART_HEIGHT := 380.0
const BAND_HEIGHT := 64.0
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

var car: Dictionary          #the save's entry: name, scene, cost, upgrades, records
var info: CarInfo
var index := 0
var focused := false
var demoLocked := false

var art := TextureRect.new()
var portrait := TextureRect.new()
var nameLabel := Label.new()
var infoLabel := Label.new()
var stats := GridContainer.new()
var actions := HBoxContainer.new()
var frame := Panel.new()
var catcher := Button.new() #a click anywhere on a side card selects it
var mainButton: Button
var upgradeButton: Button
var statButtons: Array[Button] = []

func _ready() -> void:
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
	art.size = Vector2(SIZE.x, ART_HEIGHT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(10, 30)
	portrait.size = Vector2(SIZE.x - 20, ART_HEIGHT - 30)

	var band = ColorRect.new()
	band.color = HudTheme.RIM
	band.position = Vector2(0, ART_HEIGHT)
	band.size = Vector2(SIZE.x, BAND_HEIGHT)
	band.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(band)
	nameLabel.theme_type_variation = "DarkLabel"
	nameLabel.add_theme_font_size_override("font_size", 38)
	nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameLabel.position = band.position
	nameLabel.size = band.size
	add_child(nameLabel)

	infoLabel.theme_type_variation = "BodyLabel"
	infoLabel.add_theme_font_size_override("font_size", 26)
	infoLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	infoLabel.position = Vector2(0, ART_HEIGHT + BAND_HEIGHT + 24)
	infoLabel.size = Vector2(SIZE.x, 40)
	add_child(infoLabel)

	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 2)
	stats.position = Vector2(12, ART_HEIGHT + BAND_HEIGHT + 10)
	stats.size = Vector2(SIZE.x - 24, 130)
	add_child(stats)
	for s in STATS: statButtons.push_back(makeStatRow(s))

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
	upgradeButton = MenuTheme.button("Upgrade", PackedStringArray(["ui_upgrade"]))
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
	for state in ["normal", "hover", "pressed", "focus"]: catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(func(): selectRequested.emit())
	add_child(catcher)
	setFocused(false)

func makeStatRow(stat: Array) -> Button:
	var row = Button.new()
	row.custom_minimum_size = Vector2(172, 27)
	row.focus_mode = Control.FOCUS_NONE
	row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	row.pressed.connect(func(): upgradePressed.emit(stat[1]))
	MenuTheme.addSounds(row)
	var line = HBoxContainer.new()
	line.name = "line"
	line.mouse_filter = MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 4
	line.offset_right = -4
	line.add_child(MenuTheme.iconRect(stat[2], 22))
	var value = Label.new()
	value.name = "value"
	value.custom_minimum_size.x = 26
	value.add_theme_font_size_override("font_size", 18)
	line.add_child(value)
	var bar = StatBar.new()
	bar.name = "bar"
	bar.custom_minimum_size = Vector2(44, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(bar)
	var price = Control.new()
	price.name = "price"
	price.custom_minimum_size = Vector2(48, 24)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(price)
	row.add_child(line)
	stats.add_child(row)
	return row

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
	if demoLocked: infoLabel.text = "Not in the demo"
	elif car.cost != 0: infoLabel.text = "%s  -  %s coins" % [type, formatCoins(car.cost)]
	else: infoLabel.text = type
	stats.visible = focused && not locked
	infoLabel.visible = not stats.visible
	actions.visible = focused
	upgradeButton.visible = not locked
	if demoLocked:
		mainButton.text = "NOT IN DEMO"
		mainButton.disabled = true
	elif car.cost != 0:
		var short = car.cost - SaveManager.playerData.coin
		mainButton.text = "UNLOCK  %s" % formatCoins(car.cost) if short <= 0 else "NEED %s MORE" % formatCoins(short)
		mainButton.disabled = short > 0
	else:
		mainButton.text = "DRIVE"
		mainButton.disabled = false
	if stats.visible: refreshStats()

func refreshStats() -> void:
	for i in STATS.size():
		var s = STATS[i]
		var row = statButtons[i]
		var base: int = info.get(s[0])
		var level = SaveManager.getUpgradeLevel(s[1])
		row.get_node("line/value").text = str(base + level)
		var bar: StatBar = row.get_node("line/bar")
		bar.base = base
		bar.bought = level
		bar.queue_redraw()
		var holder: Control = row.get_node("line/price")
		for child in holder.get_children(): child.queue_free()
		var maxed = SaveManager.isUpgradeMaxed(s[1])
		var cost = SaveManager.requestStatCost(s[1])
		var chipPanel = MenuTheme.priceChip("MAX" if maxed else str(cost), HudTheme.COIN_ICON, not maxed && cost <= SaveManager.playerData.coin)
		chipPanel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
		holder.add_child(chipPanel)
		row.disabled = maxed || cost > SaveManager.playerData.coin

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
	refresh()

static func frameBox(isFocused: bool) -> StyleBoxFlat:
	var style = MenuTheme.box(Color(0, 0, 0, 0), HudTheme.RIM if isFocused else Color(1, 1, 1, 0.22), 18, 5 if isFocused else 3)
	style.draw_center = false
	return style

#upgrade mode: the stat rows take focus so a controller or keyboard can buy upgrades
func setUpgradeMode(on: bool) -> void:
	for row in statButtons: row.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if on:
		for row in statButtons:
			if not row.disabled:
				row.grab_focus()
				return
		statButtons[0].focus_mode = Control.FOCUS_ALL
		statButtons[0].grab_focus()
	else: mainButton.grab_focus()

func onMainPressed() -> void:
	if isLocked(): unlockPressed.emit()
	else: drivePressed.emit()

#a stat against 100: cream for the car's base value, gold for the upgrades bought on top
class StatBar extends Control:
	var base := 0
	var bought := 0
	func _draw() -> void:
		var w = size.x
		var h = size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.33, 0.3, 0.27))
		var b = w * clampf(base / 100.0, 0.0, 1.0)
		var g = w * clampf((base + bought) / 100.0, 0.0, 1.0)
		if b > 0.0: draw_rect(Rect2(0, 0, maxf(1.0, b), h), HudTheme.START)
		if g > b: draw_rect(Rect2(b, 0, maxf(1.0, g - b), h), HudTheme.GAIN)
