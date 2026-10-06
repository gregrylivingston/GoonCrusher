class_name HudTheme

#The in-run HUD's shared look: colors, fonts and the draw helpers its widgets use (see docs/HUD.md).
#Gauge angles are degrees clockwise from 12 o'clock, like a dial face.

const PANEL := Color(0.055, 0.047, 0.043, 0.82)
const RIM := Color(0.941, 0.627, 0.188)          #the HUD's orange edge
const TEXT := Color(1.0, 0.953, 0.863)
const MUTED := Color(0.804, 0.749, 0.663)
const OUTLINE := Color(0.07, 0.05, 0.04)
const GOLD := Color(1.0, 0.827, 0.42)
const DEEP := Color(0.306, 0.067, 0.043)         #outline of the big gold numbers
const NEEDLE := Color(1.0, 0.478, 0.165)
const TRACK := Color(0.173, 0.153, 0.141)
const OK := Color(0.384, 0.824, 0.435)
const WARN := Color(0.949, 0.694, 0.204)
const BAD := Color(1.0, 0.29, 0.239)
const SKY := Color(0.498, 0.816, 1.0)
const START := Color(0.902, 0.863, 0.796)        #rating underline: what the run started with
const GAIN := Color(1.0, 0.761, 0.227)           #rating underline: added by pickups this run

const BOLD := preload("res://style/font/Tektur/Tektur-ExtraBold.ttf")
const BODY := preload("res://style/font/Tektur/Tektur-Medium.ttf")

const COIN_ICON := preload("res://texture/icon/coin.svg")
const GEM_ICON := preload("res://texture/icon/gem.svg")
const STAR_ICON := preload("res://texture/icon/star.svg")
const LOCK_ICON := preload("res://texture/icon/lock.svg")

static var boxes := {}

#green, amber or red for a 0-100 amount (hull, system condition)
static func conditionColor(value: float) -> Color:
	if value >= 70.0: return OK
	if value >= 40.0: return WARN
	return BAD

#on/off phase shared by everything that blinks, so blinking lamps stay in step
static func blinkOn() -> bool:
	return Time.get_ticks_msec() % 700 < 430

static func polar(center: Vector2, radius: float, degrees: float) -> Vector2:
	return center + Vector2.from_angle(deg_to_rad(degrees - 90.0)) * radius

static func arc(item: CanvasItem, center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> void:
	if to - from < 0.2: return
	item.draw_arc(center, radius, deg_to_rad(from - 90.0), deg_to_rad(to - 90.0), maxi(6, int((to - from) / 4.0)), color, width, true)

#text at a baseline, aligned on `pos.x`, with the dark outline every HUD label uses
static func text(item: CanvasItem, pos: Vector2, value: String, fontSize: int, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT,
		outline := 6, outlineColor := OUTLINE, font: Font = BOLD) -> void:
	var x = pos.x
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x
		x -= w if align == HORIZONTAL_ALIGNMENT_RIGHT else w * 0.5
	if outline > 0: item.draw_string_outline(font, Vector2(x, pos.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, outline, outlineColor)
	item.draw_string(font, Vector2(x, pos.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)

static func textWidth(value: String, fontSize: int, font: Font = BOLD) -> float:
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x

#the smoked, rimmed backing every HUD panel shares
static func panel(item: CanvasItem, rect: Rect2, rim := Color(RIM, 0.55), radius := 12) -> void:
	var key = rim.to_html() + str(radius)
	if not boxes.has(key):
		var box = StyleBoxFlat.new()
		box.bg_color = PANEL
		box.border_color = rim
		box.set_border_width_all(2)
		box.set_corner_radius_all(radius)
		box.corner_detail = 6
		boxes[key] = box
	item.draw_style_box(boxes[key], rect)

#a progress bar with round ends; `fraction` of it filled
static func bar(item: CanvasItem, rect: Rect2, fraction: float, color: Color, track := Color(0.227, 0.188, 0.165)) -> void:
	var r = rect.size.y * 0.5
	for part in [[1.0, track], [clampf(fraction, 0.0, 1.0), color]]:
		var w = rect.size.x * part[0]
		if w < 0.5: continue
		item.draw_circle(rect.position + Vector2(r, r), r, part[1])
		item.draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(maxf(0.0, w - 2.0 * r), rect.size.y)), part[1])
		item.draw_circle(rect.position + Vector2(maxf(r, w - r), r), r, part[1])

static func icon(item: CanvasItem, texture: Texture2D, center: Vector2, iconSize: float, tint := Color.WHITE) -> void:
	item.draw_texture_rect(texture, Rect2(center - Vector2(iconSize, iconSize) * 0.5, Vector2(iconSize, iconSize)), false, tint)

#a zero-size point in `group` that RewardFlyers aims at (it flies to the target's canvas origin)
static func marker(parent: Control, group: String, pos: Vector2) -> Control:
	var point = Control.new()
	point.name = group
	point.mouse_filter = Control.MOUSE_FILTER_IGNORE
	point.position = pos
	point.add_to_group(group)
	parent.add_child(point)
	return point
