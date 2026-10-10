class_name DriverCard extends Panel

#One driver in the garage carousel (main2.gd). The card is drawn at 380 x 560 and the carousel
#scales the side cards down. Side cards show their back: the background art and the portrait, nothing
#else. Selecting a card flips it over (`flip`; a fade with Reduce Motion) to its front, top to bottom:
#  art      the driver's background and portrait, with the stats in a black rail against the card's left
#           edge (`StatRail`): eight rows (icon and value, over a thin bar against 100: cream = the car's
#           base stat, gold = upgrades bought), for show only: Upgrades is where they are bought. The rail
#           runs down into the name band and ends there in a cut corner, edged in orange.
#           A manual car (CarInfo.gears) carries a "6-SPEED MANUAL" chip in the art's top right corner.
#  band     the name (right of the rail), with the car type and weight class
#  traits   the car's two signature features (CarTraits): icon, name, kind and its one-line `short`;
#           hovering one shows its full text
#Under the focused card, outside its frame, a pill says what this car has won (SaveManager.carProgress):
#medals by tier and levels won. A card has no buttons of its own: Drive (or Unlock), Upgrades and Pickups
#are on the launch bar (LaunchBar).
#Locked drivers show as a silhouette with their unlock price over the foot of the art, and no stats.
#Portraits sit against the right edge, clear of the rail: the art's drivers stand at the right of their
#pictures, and some (sedan, van, racer) are cut off there.

signal selectRequested

const SIZE := Vector2(380, 560)
const ART_HEIGHT := 404.0
const BAND_HEIGHT := 52.0
const RAIL_WIDTH := 78.0
const RAIL_FOOT := ART_HEIGHT + 26.0 #the rail runs halfway down the band...
const BEVEL := Vector2(26, 40)        #...and its foot's inner corner is cut off this much
const NAME_X := RAIL_WIDTH + 14.0     #the name starts clear of the rail
const RAIL_PAD := Vector4(12, 16, 14, 14) #the rows' margins inside the rail: left, top, right (clear of the orange edge), bottom (clear of the cut)
const TRAIT_ROW := 44.0
const TRAITS_Y := ART_HEIGHT + BAND_HEIGHT + 8
const GAP := 10.0 #between the card and the progress pill under it
const FLIP_SECONDS := 0.42
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
#each stat's name and tooltip
const STAT_TEXT := {
	"engine": ["Engine", "Acceleration and top speed"],
	"steering": ["Steering", "How fast the car turns"],
	"traction": ["Traction", "Grip in corners and on slick ground, and brakes"],
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
var showingFront := false

var flipper := Control.new() #the card's faces and frame, turned by `flip` about the card's center
var flipTween: Tween

var art := TextureRect.new()
var portrait := TextureRect.new()
var band := ColorRect.new()
var nameLabel := Label.new()
var typeLabel := Label.new()  #"PICKUP · HEAVY" at the band's right end
var gearChip := PanelContainer.new() #"6-SPEED MANUAL" on a manual car's art
var gearLabel := Label.new()
var traitList := VBoxContainer.new()
var statLine := StatRail.new()
var statList := VBoxContainer.new()
var body := Panel.new()  #the card itself, clipped to its rounded corners; the progress pill hangs below it
var progress := PanelContainer.new()
var medalCounts: Array[Label] = [] #Easy, Medium, Hard
var levelsLabel := Label.new()
var lockLine := PanelContainer.new() #a locked driver's price (or "Not in the demo"), over the foot of the art
var lockList := VBoxContainer.new()
var infoLabel := Label.new()
var priceLine := Control.new()
var frame := Panel.new()
var catcher := Button.new() #a click anywhere on a side card selects it
var statRows: Array[Control] = [] #the rail's rows: icon, value and bar

func _ready() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	flipper.size = SIZE
	flipper.pivot_offset = SIZE / 2.0
	flipper.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flipper)
	body.size = SIZE
	body.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	body.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.082, 0.067, 0.059, 0.97), Color(0, 0, 0, 0), 18, 0))
	flipper.add_child(body)
	for picture in [art, portrait]:
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.mouse_filter = MOUSE_FILTER_IGNORE
		body.add_child(picture)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.stretch_mode = TextureRect.STRETCH_SCALE #sized to the texture's aspect by layoutFace

	band.color = HudTheme.RIM
	band.mouse_filter = MOUSE_FILTER_IGNORE
	band.position = Vector2(0, ART_HEIGHT)
	band.size = Vector2(SIZE.x, BAND_HEIGHT)
	body.add_child(band)
	nameLabel.theme_type_variation = "DarkLabel"
	nameLabel.add_theme_font_size_override("font_size", 30)
	nameLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameLabel.clip_text = true
	body.add_child(nameLabel)
	typeLabel.theme_type_variation = "DarkLabel"
	typeLabel.add_theme_font_size_override("font_size", 12)
	typeLabel.modulate = Color(1, 1, 1, 0.8)
	typeLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	typeLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	typeLabel.position = Vector2(16, ART_HEIGHT + 3)
	typeLabel.size = Vector2(SIZE.x - 32, BAND_HEIGHT)
	body.add_child(typeLabel)

	gearChip.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.85), HudTheme.RIM, 7, 2, Vector4(8, 1, 8, 1)))
	gearChip.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(gearChip)
	gearLabel.add_theme_font_size_override("font_size", 12)
	gearLabel.add_theme_color_override("font_color", HudTheme.GOLD)
	gearLabel.add_theme_constant_override("outline_size", 0)
	gearLabel.mouse_filter = MOUSE_FILTER_IGNORE
	gearChip.add_child(gearLabel)

	traitList.add_theme_constant_override("separation", 0)
	traitList.position = Vector2(14, TRAITS_Y)
	traitList.size = Vector2(SIZE.x - 28, 2 * TRAIT_ROW)
	traitList.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(traitList)

	statLine.size = Vector2(RAIL_WIDTH, RAIL_FOOT)
	statLine.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(statLine) #after the band, which it overlaps
	statList.add_theme_constant_override("separation", 0)
	statList.position = Vector2(RAIL_PAD.x, RAIL_PAD.y)
	statList.size = Vector2(RAIL_WIDTH - RAIL_PAD.x - RAIL_PAD.z, RAIL_FOOT - BEVEL.y - RAIL_PAD.y - RAIL_PAD.w)
	statList.mouse_filter = MOUSE_FILTER_IGNORE
	statLine.add_child(statList)
	var smoked := MenuTheme.box(Color(HudTheme.PANEL, 0.72), Color(1, 1, 1, 0.12), 12, 1, Vector4(4, 6, 4, 6))
	for s in STATS: statRows.push_back(makeStatRow(s))

	progress.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.9), Color(1, 1, 1, 0.14), 12, 2, Vector4(14, 3, 14, 3)))
	progress.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(progress)
	var won = HBoxContainer.new()
	won.add_theme_constant_override("separation", 12)
	won.mouse_filter = MOUSE_FILTER_IGNORE
	progress.add_child(won)
	for tier in ModeTiers.TIERS:
		var medal = HBoxContainer.new()
		medal.add_theme_constant_override("separation", 4)
		medal.mouse_filter = MOUSE_FILTER_PASS
		medal.tooltip_text = "Modes won on %s or harder" % ModeTiers.NAMES[tier]
		var star := MenuTheme.iconRect(HudTheme.STAR_ICON, 16)
		star.modulate = ModeTiers.MEDAL_COLORS[tier]
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.mouse_filter = MOUSE_FILTER_IGNORE
		medal.add_child(star)
		var count = Label.new()
		count.add_theme_font_size_override("font_size", 15)
		count.add_theme_constant_override("outline_size", 0)
		count.mouse_filter = MOUSE_FILTER_IGNORE
		medal.add_child(count)
		medalCounts.push_back(count)
		won.add_child(medal)
	levelsLabel.theme_type_variation = "MutedLabel"
	levelsLabel.add_theme_font_size_override("font_size", 14)
	levelsLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	won.add_child(levelsLabel)

	lockLine.add_theme_stylebox_override("panel", smoked)
	lockLine.position = Vector2(12, ART_HEIGHT - 12 - 46)
	lockLine.size = Vector2(SIZE.x - 24, 46)
	lockLine.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(lockLine)
	lockList.alignment = BoxContainer.ALIGNMENT_CENTER
	lockList.mouse_filter = MOUSE_FILTER_IGNORE
	lockLine.add_child(lockList)
	infoLabel.theme_type_variation = "BodyLabel"
	infoLabel.add_theme_font_size_override("font_size", 20)
	infoLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lockList.add_child(infoLabel)
	priceLine.custom_minimum_size = Vector2(0, 34)
	priceLine.mouse_filter = MOUSE_FILTER_IGNORE
	lockList.add_child(priceLine)

	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.size = SIZE
	flipper.add_child(frame)
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.size = SIZE
	catcher.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(func(): selectRequested.emit())
	add_child(catcher)
	layoutFace()
	setFocused(false)

## How many of a car's stats the bank could buy the next level of right now, each on its own
static func affordableUpgrades(carIndex: int) -> int:
	var count := 0
	for s in STATS:
		if not SaveManager.isUpgradeMaxed(s[1], carIndex) && SaveManager.requestStatCost(s[1], carIndex) <= SaveManager.playerData.coin: count += 1
	return count

#a stat's row on the rail: icon and value side by side over a thin bar. Display only, so nothing in it
#takes the mouse.
func makeStatRow(stat: Array) -> VBoxContainer:
	var row = VBoxContainer.new()
	row.name = stat[0]
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(top)
	var icon := MenuTheme.iconRect(stat[2], 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(icon)
	var value = Label.new()
	value.name = "value"
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_constant_override("outline_size", 0)
	value.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(value)
	var bar = StatBar.new()
	bar.name = "bar"
	bar.custom_minimum_size = Vector2(0, 3)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(bar)
	statList.add_child(row)
	return row

func setup(entry: Dictionary, carInfo: CarInfo, carIndex: int) -> void:
	car = entry
	info = carInfo
	index = carIndex
	demoLocked = Root.IS_DEMO && carIndex >= Root.DEMO_CAR_COUNT
	art.texture = info.backgroundPic
	portrait.texture = info.profilePic
	layoutFace()
	for child in traitList.get_children():
		traitList.remove_child(child)
		child.queue_free()
	for id in info.traits:
		if CarTraits.has(id): traitList.add_child(traitLine(id))
	refresh()

## A trait's row: its icon, then its name and kind over its one-line description (CarTraits `short`).
## Hovering it shows the full text.
static func traitLine(id: StringName) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = TRAIT_ROW
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = MOUSE_FILTER_PASS
	row.tooltip_text = CarTraits.DATA[id].text
	var icon := MenuTheme.iconRect(CarTraits.texture(id), 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(column)
	var title = HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(title)
	var heading = Label.new()
	heading.text = CarTraits.displayName(id)
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_constant_override("outline_size", 0)
	heading.mouse_filter = MOUSE_FILTER_IGNORE
	title.add_child(heading)
	var kind = Label.new()
	kind.text = CarTraits.KIND_NAMES[CarTraits.kind(id)]
	if CarTraits.kind(id) == CarTraits.Kind.ABILITY: kind.text += "  ·  " + InputGlyphs.label("Ability")
	kind.add_theme_font_size_override("font_size", 11)
	kind.add_theme_color_override("font_color", CarTraits.color(id))
	kind.add_theme_constant_override("outline_size", 0)
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.mouse_filter = MOUSE_FILTER_IGNORE
	title.add_child(kind)
	var short = Label.new()
	short.text = CarTraits.DATA[id].short
	short.theme_type_variation = "MutedLabel"
	short.add_theme_font_size_override("font_size", 13)
	short.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	short.clip_text = true
	short.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_child(short)
	return row

func isLocked() -> bool:
	return car.cost != 0 || demoLocked

#everything that can change while the menu is open: lock state, prices, stats, progress
func refresh() -> void:
	for node in [band, nameLabel, typeLabel, traitList]: node.visible = showingFront
	gearChip.visible = showingFront && info != null && info.gears > 0
	if gearChip.visible:
		gearLabel.text = "%d-SPEED MANUAL" % info.gears
		gearChip.reset_size()
		gearChip.position = Vector2(SIZE.x - gearChip.size.x - 10, 10)
	if info == null: #still loading: a plain card with the car's name
		nameLabel.text = str(car.get("name", "")).to_upper()
		typeLabel.text = ""
		statLine.visible = false
		progress.visible = false
		lockLine.visible = false
		return
	var locked = isLocked()
	portrait.modulate = Color(0, 0, 0, 0.88) if locked else Color.WHITE
	nameLabel.text = info.charName.to_upper()
	typeLabel.text = "%s  ·  %s" % [info.carId.capitalize().to_upper(), weightClass(info.weight).to_upper()]
	statLine.visible = showingFront && not locked
	nameLabel.position = Vector2(NAME_X if statLine.visible else 16.0, ART_HEIGHT)
	nameLabel.size = Vector2(SIZE.x - 16 - nameLabel.position.x, BAND_HEIGHT)
	progress.visible = focused && not locked
	lockLine.visible = showingFront && locked
	infoLabel.text = "Not in the demo"
	infoLabel.visible = demoLocked
	for child in priceLine.get_children():
		priceLine.remove_child(child)
		child.queue_free()
	if car.cost != 0 && not demoLocked: #entry cars cost coins, advanced ones coins and gems: "10,000 (coin)  5 (gem)", gold when the bank covers it
		var cost := Unlocks.price("car:" + str(car.name))
		var row := MenuTheme.symbolRow([HudTheme.LOCK_ICON, "  ", cost], 26, HudTheme.GOLD if Unlocks.canAfford("car:" + str(car.name)) else MenuTheme.BODY_TEXT)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		priceLine.add_child(row)
	priceLine.visible = car.cost != 0 && not demoLocked
	if not locked:
		refreshStats()
		refreshProgress()

#the car's weight (CarInfo.weight, CarHandling) in a word, on the band
static func weightClass(weight: int) -> String:
	if weight < 30: return "Light"
	if weight < 60: return "Medium"
	return "Heavy" if weight < 85 else "Very heavy"

func refreshStats() -> void:
	for i in STATS.size():
		var s = STATS[i]
		var base: int = info.get(s[0])
		var level = SaveManager.getUpgradeLevel(s[1], index)
		var row := statRows[i]
		row.find_child("value", true, false).text = str(base + level)
		var bar: StatBar = row.get_node("bar")
		bar.base = base
		bar.bought = level
		bar.queue_redraw()

#medals by tier (each level and mode once, on its tier or harder) and the levels won, out of every level;
#the demo counts all of them too, its locked ones included
func refreshProgress() -> void:
	var won := SaveManager.carProgress(info.carId)
	for i in ModeTiers.TIERS.size(): medalCounts[i].text = str(won.tiers[ModeTiers.TIERS[i]])
	levelsLabel.text = "%d / %d levels won" % [won.levels, SaveManager.playerData.levels.size()] if won.levels > 0 else "Not raced yet"
	placeProgress()

#the pill centered under the card, sized to what it says
func placeProgress() -> void:
	progress.reset_size()
	progress.position = Vector2((SIZE.x - progress.size.x) / 2.0, SIZE.y + GAP)

static func formatCoins(amount: int) -> String:
	var text = str(amount)
	var out = ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out

## `animate` flips the card over to its new face; otherwise it just shows it
func setFocused(value: bool, animate := false) -> void:
	focused = value
	catcher.visible = not value
	frame.add_theme_stylebox_override("panel", frameBox(value))
	if animate && value != showingFront && is_visible_in_tree(): flip(value)
	else: showFace(value)

func showFace(front: bool) -> void:
	showingFront = front
	layoutFace()
	refresh()

#the back is the background over the whole card with the portrait standing at its foot, full width; the
#front keeps the art above the band, the portrait against the right edge (the rail is on the left)
func layoutFace() -> void:
	art.size = Vector2(SIZE.x, ART_HEIGHT if showingFront else SIZE.y)
	var aspect := 1.0
	if portrait.texture: aspect = portrait.texture.get_width() / float(portrait.texture.get_height())
	if showingFront:
		var h := ART_HEIGHT - 24.0
		portrait.size = Vector2(h * aspect, h)
		portrait.position = Vector2(SIZE.x - portrait.size.x, 24.0)
	else:
		portrait.size = Vector2(SIZE.x, SIZE.x / aspect)
		portrait.position = Vector2(0, SIZE.y - portrait.size.y)

#turns the card over about its vertical axis: it squeezes to an edge with a little lift and tilt, swaps
#faces there, then opens out with a flash and an overshoot. Reduce Motion crossfades instead.
func flip(front: bool) -> void:
	if flipTween: flipTween.kill()
	flipper.scale = Vector2.ONE
	flipper.rotation = 0.0
	flipper.modulate = Color.WHITE
	flipTween = create_tween()
	if Settings.reduce_motion():
		flipTween.tween_property(flipper, "modulate:a", 0.0, 0.1)
		flipTween.tween_callback(showFace.bind(front))
		flipTween.tween_property(flipper, "modulate:a", 1.0, 0.14)
		return
	var half := FLIP_SECONDS * 0.4
	var tilt := -0.05 if front else 0.05
	flipTween.set_parallel()
	flipTween.tween_property(flipper, "scale", Vector2(0.0, 1.07), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flipTween.tween_property(flipper, "rotation", tilt, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flipTween.chain().tween_callback(func():
		showFace(front)
		flipper.modulate = Color(1.7, 1.6, 1.4)) #the new face catches the light as it turns toward you
	flipTween.chain().tween_property(flipper, "scale", Vector2.ONE, FLIP_SECONDS - half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flipTween.tween_property(flipper, "rotation", 0.0, FLIP_SECONDS - half).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flipTween.tween_property(flipper, "modulate", Color.WHITE, FLIP_SECONDS - half)

static func frameBox(isFocused: bool) -> StyleBoxFlat:
	var style = MenuTheme.box(Color(0, 0, 0, 0), HudTheme.RIM if isFocused else Color(1, 1, 1, 0.22), 18, 5 if isFocused else 3)
	style.draw_center = false
	return style

#the stat rail's ground: near-black, lighter toward its inner edge, from the card's top into the name band,
#its foot's inner corner cut off, with an orange line down the inner edge and along the cut
class StatRail extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - BEVEL.y), Vector2(w - BEVEL.x, h), Vector2(0, h)])
		var dark := Color(0.043, 0.035, 0.031)
		var light := Color(0.11, 0.086, 0.075)
		draw_polygon(shape, PackedColorArray([dark, light, light, dark.lerp(light, (w - BEVEL.x) / w), dark]))
		draw_polyline(PackedVector2Array([Vector2(w - 1.5, 0), Vector2(w - 1.5, h - BEVEL.y), Vector2(w - BEVEL.x - 1.5, h)]), HudTheme.RIM, 3.0, true)

#a stat against 100: cream for the car's base value, gold for the upgrades bought on top,
#with faint ticks every 10 when it is tall enough. `glow` brightens the gold part for a moment.
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
