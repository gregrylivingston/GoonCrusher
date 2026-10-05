class_name HudSystems extends Control

#The bottom-center strip: one lamp per car system, each with a short underline for its rating.
#  Lamp: dimmed while the system is healthy; the headlight lamp is bright while the lights are on.
#        Under 70% condition it glows amber, under 40% red, and under 25% it blinks.
#  Underline: the stat against 100. Cream is what the run started with (base + upgrades), gold is
#        what pickups added this run, red is what damage takes off (car.conditionFactor).
#Stat pickups fly here (the "<stat>ui" groups RewardFlyers aims at) and the lamp pulses as they land.
#Nothing lowers condition yet, so lamps stay quiet and there is no red; see docs/HUD.md.

const SYSTEMS := [
	{"id":"lights", "stat":"headlights", "icon":preload("res://texture/icon/headlights.svg")},
	{"id":"engine", "stat":"engine", "icon":preload("res://texture/icon/engine.svg")},
	{"id":"steering", "stat":"steering", "icon":preload("res://texture/icon/steering.svg")},
	{"id":"tires", "stat":"traction", "icon":preload("res://texture/icon/traction.svg")},
	{"id":"tank", "stat":"oil", "icon":preload("res://texture/icon/oil.svg")},
]
const SPACING := 80.0
const LAMP_Y := 19.0
const ICON := 28.0
const LINE_WIDTH := 40.0
const LINE_Y := 36.0
const PULSE_MS := 600
const QUIET := Color(0.62, 0.62, 0.62, 0.9)

var lastStats := {}
var landsAt := {}          #system id -> msec when its pickup flyer arrives
var shownKey := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in SYSTEMS.size(): HudTheme.marker(self, SYSTEMS[i].stat + "ui", lampCenter(i))

func lampCenter(i: int) -> Vector2:
	return Vector2(size.x * 0.5 + (i - 2) * SPACING, LAMP_Y)

func _process(_delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var now = Time.get_ticks_msec()
	var key := [car.myLights.visible]
	var animating := false
	for s in SYSTEMS:
		var stat = car.get(s.stat)
		if lastStats.has(s.id) && stat > lastStats[s.id]: landsAt[s.id] = now + int(RewardFlyers.FLIGHT_SECONDS * 1000.0)
		lastStats[s.id] = stat
		var condition = car.condition[s.id]
		key.append_array([stat, roundi(condition)])
		if condition < 25.0 || (landsAt.has(s.id) && now < landsAt[s.id] + PULSE_MS): animating = true
	if animating: key.append(now)
	if key != shownKey:
		shownKey = key
		queue_redraw()

#0..1 while a landed pickup's pulse plays, else -1
func pulse(id: String, now: int) -> float:
	if not landsAt.has(id) || now < landsAt[id] || now > landsAt[id] + PULSE_MS: return -1.0
	return float(now - landsAt[id]) / PULSE_MS

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var w = size.x
	var h = size.y
	var shape = PackedVector2Array([Vector2(0, h), Vector2(16, 0), Vector2(w - 16, 0), Vector2(w, h)])
	draw_colored_polygon(shape, Color(0.047, 0.039, 0.035, 0.88))
	draw_polyline(shape, Color(HudTheme.RIM, 0.75), 2.5, true)
	var now = Time.get_ticks_msec()
	for i in SYSTEMS.size():
		var s = SYSTEMS[i]
		var c = lampCenter(i)
		var condition: float = car.condition[s.id]
		var tint = QUIET
		if s.id == "lights" && car.myLights.visible: tint = Color.WHITE
		if condition < 70.0 && (condition >= 25.0 || HudTheme.blinkOn()):
			draw_circle(c, ICON * 0.62, Color(HudTheme.conditionColor(condition), 0.45))
			tint = Color.WHITE
		var p = pulse(s.id, now)
		var iconSize = ICON
		if p >= 0.0:
			draw_circle(c, ICON * (0.5 + 0.4 * p), Color(HudTheme.GAIN, 0.5 * (1.0 - p)))
			iconSize = ICON * (1.0 + 0.35 * (1.0 - p))
			tint = Color.WHITE
			HudTheme.text(self, c + Vector2(0, -16 - 18 * p), "+1", 16, Color(HudTheme.GAIN, 1.0 - p), HORIZONTAL_ALIGNMENT_CENTER, 6)
		HudTheme.icon(self, s.icon, c, iconSize, tint)
		drawUnderline(car, s, Vector2(c.x - LINE_WIDTH * 0.5, LINE_Y))
		var gain = car.get(s.stat) - car.runStartStats.get(s.stat, car.get(s.stat))
		if gain > 0: HudTheme.text(self, c + Vector2(15, -5), "+" + str(gain), 10, HudTheme.GAIN, HORIZONTAL_ALIGNMENT_LEFT, 5)

#the stat against 100: cream up to the starting rating, gold for pickups, red for what damage takes
func drawUnderline(car, s: Dictionary, at: Vector2) -> void:
	var rating: float = car.get(s.stat)
	var start: float = minf(car.runStartStats.get(s.stat, rating), rating)
	var effective: float = rating * car.conditionFactor(s.id)
	var x = func(v: float) -> float: return at.x + LINE_WIDTH * clampf(v / 100.0, 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(LINE_WIDTH, 4)), HudTheme.TRACK)
	var spans = [[0.0, minf(start, effective), HudTheme.START], [start, effective, HudTheme.GAIN], [effective, rating, HudTheme.BAD]]
	for span in spans:
		var from = x.call(span[0])
		var to = x.call(span[1])
		if to - from > 0.01: draw_rect(Rect2(from, at.y, maxf(1.0, to - from), 4), span[2])
	if rating > 100.0: HudTheme.text(self, at + Vector2(LINE_WIDTH + 2, 6), "+", 11, HudTheme.GAIN, HORIZONTAL_ALIGNMENT_LEFT, 4)
