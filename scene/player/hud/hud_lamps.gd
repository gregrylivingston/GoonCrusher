class_name HudLamps

#The car's five system lamps, drawn on the dials (HudDial; docs/HUD.md, "System lamps"): engine and tank on the
#tachometer, steering, lights and tires on the speedometer, on every dash. Each is its system's icon with its rating.
#  Lamp: dimmed while the system is healthy; the headlight lamp is bright while the lights are on.
#        Under 70% condition it glows amber, under 40% red, and under 25% it blinks.
#  Rating: the stat against 100. Cream is what the run started with (base + upgrades), gold is
#        what pickups added this run, red is what damage takes off (car.conditionFactor).
#Stat pickups fly to their lamp (the "<stat>ui" groups RewardFlyers aims at) and it pulses as they land.
#How a lamp is drawn is the dashboard's (HudSkin.lamp): a ring, a tile, a little gauge...

const SYSTEMS := {
	"lights": {"stat":"headlights", "icon":preload("res://texture/icon/headlights.svg")},
	"engine": {"stat":"engine", "icon":preload("res://texture/icon/engine.svg")},
	"steering": {"stat":"steering", "icon":preload("res://texture/icon/steering.svg")},
	"tires": {"stat":"traction", "icon":preload("res://texture/icon/traction.svg")},
	"tank": {"stat":"oil", "icon":preload("res://texture/icon/oil.svg")},
}
const LEFT: Array[String] = ["engine", "tank"]                 #on the tachometer: what makes it go
const RIGHT: Array[String] = ["steering", "lights", "tires"]   #on the speedometer: how it handles and what you see
const PULSE_MS := 600
const QUIET := Color(0.8, 0.8, 0.8, 0.95)
const LINE_TRACK := Color(0.33, 0.3, 0.27)  #the room left up to 100, so a weak stat still reads

#0..1 while a landed pickup's pulse plays, else -1
static func pulse(landsAt: Dictionary, id: String, now: int) -> float:
	if not landsAt.has(id) || now < landsAt[id] || now > landsAt[id] + PULSE_MS: return -1.0
	return float(now - landsAt[id]) / PULSE_MS

## The rating's three parts as [from, to, colour], each 0-1 of 100: what the run started with, what pickups added,
## what damage takes off
static func spans(car, id: String) -> Array:
	var stat: String = SYSTEMS[id].stat
	var rating: float = car.get(stat)
	var start: float = minf(car.runStartStats.get(stat, rating), rating)
	var effective: float = rating * car.conditionFactor(id)
	var part = func(v: float) -> float: return clampf(v / 100.0, 0.0, 1.0)
	return [[0.0, part.call(minf(start, effective)), HudTheme.START], [part.call(start), part.call(effective), HudTheme.GAIN],
		[part.call(effective), part.call(rating), HudTheme.BAD]]

#the rating as a line: `length` long from `at`, across or (bottom up) down the screen
static func line(item: CanvasItem, car, id: String, at: Vector2, length: float, thick: float, upright := false) -> void:
	item.draw_rect(Rect2(at, Vector2(thick, -length) if upright else Vector2(length, thick)).abs(), LINE_TRACK)
	for span in spans(car, id):
		var from: float = span[0] * length
		var to: float = span[1] * length
		if to - from < 0.01: continue
		if upright: item.draw_rect(Rect2(at.x, at.y - to, thick, maxf(1.0, to - from)), span[2])
		else: item.draw_rect(Rect2(at.x + from, at.y, maxf(1.0, to - from), thick), span[2])

## One lamp, centred on `at`; `u` is the dial's unit (a lamp is about 26 across)
static func draw(item: CanvasItem, skin: HudSkin, car, id: String, at: Vector2, u: float, now: int, landsAt: Dictionary) -> void:
	var system: Dictionary = SYSTEMS[id]
	var condition: float = car.condition[id]
	var tint := QUIET
	var fill := Color(skin.hub, 0.92)
	var alert := false
	if id == "lights" && car.myLights.visible: tint = Color.WHITE
	if condition < 70.0 && (condition >= 25.0 || HudTheme.blinkOn()):
		fill = Color(HudTheme.conditionColor(condition), 0.55)
		tint = Color.WHITE
		alert = true
	var iconAt := at
	var iconSize := 16.0 * u
	match skin.lamp:
		HudSkin.Lamp.TILE: #a square tile with its rating under it
			var tile := Rect2(at - Vector2(11, 12) * u, Vector2(22, 20) * u)
			item.draw_rect(tile, fill)
			item.draw_rect(tile, skin.rim, false, 1.5)
			line(item, car, id, tile.position + Vector2(0, 21) * u, 22 * u, 3 * u)
			iconAt = tile.get_center()
		HudSkin.Lamp.BLOCK: #an annunciator block
			var block := Rect2(at - Vector2(13, 11) * u, Vector2(26, 18) * u)
			item.draw_rect(block, fill if alert else Color(skin.track, 0.95))
			item.draw_rect(block, skin.rim, false, 1.0)
			line(item, car, id, block.position + Vector2(0, 19.5) * u, 26 * u, 3 * u)
			iconAt = block.get_center()
			iconSize = 15.0 * u
		HudSkin.Lamp.PILL:
			var pill := Rect2(at - Vector2(13, 12) * u, Vector2(26, 19) * u)
			HudTheme.panel(item, pill, skin.rim, int(9 * u), fill if alert else Color(skin.face, 0.95))
			line(item, car, id, pill.position + Vector2(2, 20.5) * u, 22 * u, 3 * u)
			iconAt = pill.get_center()
			iconSize = 15.0 * u
		HudSkin.Lamp.VITAL: #a monitor's reading: the icon over what the system is worth now
			iconAt = at + Vector2(0, -5) * u
			iconSize = 14.0 * u
			var worth: float = car.get(system.stat) * car.conditionFactor(id)
			skin.write(item, at + Vector2(0, 13) * u, str(roundi(worth)), int(11 * u), skin.condition(condition), HORIZONTAL_ALIGNMENT_CENTER, 0)
		HudSkin.Lamp.GAUGE: #a little chrome gauge: its needle is what the system is worth now
			var worth: float = clampf(car.get(system.stat) * car.conditionFactor(id) / 100.0, 0.0, 1.0)
			item.draw_circle(at, 11.5 * u, fill if alert else Color(skin.face, 0.98))
			item.draw_arc(at, 11.5 * u, 0.0, TAU, 24, skin.rim, 2.5 * u, true)
			iconSize = 12.0 * u
			HudTheme.icon(item, system.icon, at, iconSize, Color(tint, 0.6))
			item.draw_line(at, HudTheme.polar(at, 10 * u, -110.0 + 220.0 * worth), skin.needle, 2.0 * u, true)
			iconSize = 0.0
		HudSkin.Lamp.LCD: #a block display: five blocks under the icon
			var cell := Rect2(at - Vector2(12, 13) * u, Vector2(24, 26) * u)
			item.draw_rect(cell, fill if alert else Color(skin.track, 0.95))
			iconAt = at + Vector2(0, -4) * u
			iconSize = 14.0 * u
			var worth: float = car.get(system.stat) * car.conditionFactor(id)
			for i in 5: item.draw_rect(Rect2(cell.position + Vector2(1.5 + i * 4.3, 20) * u, Vector2(3.4, 4) * u), skin.text if i < roundi(worth / 20.0) else Color(skin.text, 0.15))
		HudSkin.Lamp.LED: #the icon beside an LED column
			if alert: item.draw_circle(at + Vector2(-3, 0) * u, 10 * u, fill)
			iconAt = at + Vector2(-3, 0) * u
			line(item, car, id, at + Vector2(8, 11) * u, 22 * u, 4 * u, true)
		_: #a round tell-tale with its rating as a ring
			item.draw_circle(at, 10 * u, fill)
			item.draw_arc(at, 12.5 * u, 0.0, TAU, 32, LINE_TRACK, 2.5 * u, true)
			for span in spans(car, id): HudTheme.arc(item, at, 12.5 * u, span[0] * 360.0, span[1] * 360.0, span[2], 2.5 * u)
	var p := pulse(landsAt, id, now)
	if p >= 0.0: #its pickup has landed
		item.draw_circle(iconAt, 16.0 * u * (0.5 + 0.5 * p), Color(HudTheme.GAIN, 0.5 * (1.0 - p)))
		iconSize *= 1.0 + 0.35 * (1.0 - p)
		tint = Color.WHITE
		HudTheme.text(item, iconAt + Vector2(0, -14 - 14 * p) * u, "+1", int(14 * u), Color(HudTheme.GAIN, 1.0 - p), HORIZONTAL_ALIGNMENT_CENTER, 6)
	if iconSize > 0.0: HudTheme.icon(item, system.icon, iconAt, iconSize, tint)
	var gain: int = car.get(system.stat) - car.runStartStats.get(system.stat, car.get(system.stat))
	if gain > 0: HudTheme.text(item, at + Vector2(8, -9) * u, "+" + str(gain), int(9 * u), HudTheme.GAIN, HORIZONTAL_ALIGNMENT_LEFT, 4)
	if car.get(system.stat) > 100: HudTheme.text(item, at + Vector2(-14, -9) * u, "+", int(10 * u), HudTheme.GAIN, HORIZONTAL_ALIGNMENT_LEFT, 4)
