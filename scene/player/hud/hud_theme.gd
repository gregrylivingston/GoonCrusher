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
const STATION := SKY                             #the station: its pointer, tag and distance (nothing else is blue)
const START := Color(0.902, 0.863, 0.796)        #rating underline: what the run started with
const GAIN := Color(1.0, 0.761, 0.227)           #rating underline: added by pickups this run

const BOLD := preload("res://style/font/Tektur/Tektur-ExtraBold.ttf")
const BODY := preload("res://style/font/Tektur/Tektur-Medium.ttf")

const COIN_ICON := preload("res://texture/icon/coin.svg")
const GEM_ICON := preload("res://texture/icon/gem.svg")
const STAR_ICON := preload("res://texture/icon/star.svg")
const LOCK_ICON := preload("res://texture/icon/lock.svg")
#one per game mode (scripts/art/pickup_icons.js): run setup's medallions and the Goonopedia's mode tiles
const MODE_ICONS := {
	Root.gameModes.GOONCRUSHER: preload("res://texture/icon/mode_countdown.svg"),
	Root.gameModes.SPRINT: preload("res://texture/icon/mode_sprint.svg"),
	Root.gameModes.MARATHON: preload("res://texture/icon/mode_marathon.svg"),
	Root.gameModes.DEFENSE: preload("res://texture/icon/mode_defense.svg"),
	Root.gameModes.GOONPOCALYPSE: preload("res://texture/icon/mode_pocalypse.svg"),
	Root.gameModes.BLACKOUT: preload("res://texture/icon/mode_blackout.svg"),
	Root.gameModes.BOUNTY: preload("res://texture/icon/mode_bounty.svg"),
	Root.gameModes.RALLY: preload("res://texture/icon/mode_rally.svg"),
	Root.gameModes.FLATOUT: preload("res://texture/icon/mode_flatout.svg"),
	Root.gameModes.HOTLAP: preload("res://texture/icon/mode_hotlap.svg"),
	Root.gameModes.DRIFT: preload("res://texture/icon/mode_drift.svg"),
	Root.gameModes.CONES: preload("res://texture/icon/mode_cones.svg"),
	Root.gameModes.SMASH: preload("res://texture/icon/mode_smash.svg"),
	Root.gameModes.CANNONBALL: preload("res://texture/icon/mode_cannonball.svg"),
	Root.gameModes.CIRCUIT: preload("res://texture/icon/mode_circuit.svg"),
	Root.gameModes.DERBY: preload("res://texture/icon/mode_derby.svg"),
	Root.gameModes.KNOCKOUT: preload("res://texture/icon/mode_knockout.svg"),
	Root.gameModes.KEEPCUP: preload("res://texture/icon/mode_keepcup.svg"),
	Root.gameModes.PURSUIT: preload("res://texture/icon/mode_pursuit.svg"),
}

static var boxes := {}

const STATION_HIT_SECONDS := 1.2

## The car's distance to the station, "2.3 km" or "1.4 mi" (Settings' units, one decimal under 10),
## or "" with no station
static func stationDistance(car = Root.playerCar) -> String:
	if not is_instance_valid(Root.station): return ""
	return distanceFrom(car, Root.station.drivewayPoint())

## The car's distance to a point in the world, the same way; "" with no car or for Vector2.INF
static func distanceTo(point: Vector2) -> String:
	return distanceFrom(Root.playerCar, point)

## ...from `car` (a HUD's own: GameUI.carOf)
static func distanceFrom(car, point: Vector2) -> String:
	if point == Vector2.INF || not is_instance_valid(car): return ""
	var miles: float = car.global_position.distance_to(point) / 10000.0
	if Settings.distance_unit() == "km": miles *= 1.609
	var shown := "%.1f" % maxf(miles, 0.1) if miles < 10.0 else str(int(miles))
	return "%s %s" % [shown, Settings.distance_unit()]

## Defense: 1 the moment a goon blows up at a pump, fading to 0 over STATION_HIT_SECONDS
static func stationHit() -> float:
	if not is_instance_valid(Root.station) || not Root.station.hasBarrier: return 0.0
	return clampf(1.0 - (Time.get_ticks_msec() - Root.station.lastHitMsec) / (STATION_HIT_SECONDS * 1000.0), 0.0, 1.0)

#green, amber or red for a 0-100 amount (hull, system condition)
static func conditionColor(value: float) -> Color:
	if value >= 70.0: return OK
	if value >= 40.0: return WARN
	return BAD

#on/off phase shared by everything that blinks, so blinking lamps stay in step. With Reduce Flashing
#nothing blinks: every warning holds steady (on), which still reads as a warning in its color.
static func blinkOn() -> bool:
	if Settings.get_value("access/reduce_flashing"): return true
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
#with no rim or radius given it takes the dashboard's (HudSkin): the car's rim color and corner shape
static func panel(item: CanvasItem, rect: Rect2, rim := Color(0, 0, 0, 0), radius := -1, fill := PANEL) -> void:
	if rim.a == 0.0: rim = Color(HudSkin.of(item).rim, 0.55)
	if radius < 0: radius = HudSkin.of(item).radius
	var key = rim.to_html() + str(radius) + fill.to_html()
	if not boxes.has(key):
		var box = StyleBoxFlat.new()
		box.bg_color = fill
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
	var ui := GameUI.of(parent)
	if ui == null || not ui.guest: point.add_to_group(group) #pickups fly to the player's HUD, never the second player's
	parent.add_child(point)
	return point
