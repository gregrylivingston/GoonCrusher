class_name HudDial extends Control

#A gauge in the bottom corners: tachometer, speedometer, fuel or hull. The face (ticks, numbers,
#arcs) is drawn once, and again only when its scale changes. The needle and readouts are drawn on a
#child CanvasItem that redraws only when what it shows has visibly moved.

enum Kind { TACH, SPEEDO, FUEL, HULL }

@export var kind := Kind.SPEEDO
@export var flyerGroups: PackedStringArray = [] #reward flyers for these groups land on the dial's center

const SWEEP := 135.0         #tach and speedometer run from -135 to +135 degrees
const SMALL_SWEEP := 70.0    #fuel and hull run from -70 to +70
const RPM_MAX := 8.0
const REDLINE := 6.5
const CRUSH_SPEED := 100.0   #px/s; goons die when hit faster than this (overhead_car_body_2d)
const LOW := 25.0            #fuel and hull blink under this
const FACE := Color(0.047, 0.039, 0.035, 0.86)
const HUB := Color(0.106, 0.09, 0.078)

const FUEL_ICON := preload("res://texture/icon/fuel.svg")
const HULL_ICON := preload("res://texture/icon/health.svg")

var needle := Control.new()
var center: Vector2
var radius: float
var unit: float              #face design units: a big dial is 118 across its radius, a small one 64
var speedMax := 160          #speedometer scale in the player's units, set from the car's top speed
var scaled := false
var shownValue := 0.0        #the needle eases toward its target, frame-rate independent
var shownKey := []
var readout := 0             #speedometer digits, refreshed 10 times a second like the old HUD
var readoutTimer := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	center = size * 0.5
	radius = minf(size.x, size.y) * 0.5
	unit = radius / (64.0 if isSmall() else 118.0)
	needle.mouse_filter = MOUSE_FILTER_IGNORE
	needle.size = size
	add_child(needle)
	needle.draw.connect(drawNeedle)
	for group in flyerGroups: HudTheme.marker(self, group, center)
	Settings.changed.connect(onSettingChanged)

func isSmall() -> bool:
	return kind == Kind.FUEL || kind == Kind.HULL

func onSettingChanged(key: String, _value) -> void:
	if key == "gameplay/speed_units" && kind == Kind.SPEEDO: setSpeedScale()

static func unitsPerPx() -> float:
	return 0.1609 if Settings.get_value("gameplay/speed_units") == "kmh" else 0.1

#the car's flat-out speed in px/s, where engine force meets drag and friction (overhead_car_body_2d)
static func topSpeed(car) -> float:
	var force = (car.engine + 14) * 10 * 2.2
	return (-car.friction + sqrt(car.friction * car.friction + 4.0 * car.drag * force)) / (2.0 * car.drag)

#the scale is a multiple of 40, so its 8 numbered ticks land on round numbers
static func speedScaleFor(car) -> int:
	return clampi(ceili(topSpeed(car) * 1.1 * unitsPerPx() / 40.0) * 40, 80, 320)

func setSpeedScale() -> void:
	if not is_instance_valid(Root.playerCar): return
	speedMax = speedScaleFor(Root.playerCar)
	queue_redraw()
	needle.queue_redraw()

func targetValue(car) -> float:
	match kind:
		Kind.TACH:
			return gearedRpm(car)
		Kind.SPEEDO: return car.velocity.length() * unitsPerPx()
		Kind.FUEL: return clampf(car.fuel, 0.0, 100.0)
		_: return clampf(car.health, 0.0, 100.0)

func _process(delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	if kind == Kind.SPEEDO && not scaled:
		scaled = true
		setSpeedScale()
	var target = targetValue(car)
	shownValue = lerpf(shownValue, target, 1.0 - exp(-delta * 14.0))
	var key: Array
	match kind:
		Kind.TACH: key = [snappedf(shownValue, 0.02), gearText(car), gearColor(car)]
		Kind.SPEEDO:
			readoutTimer -= delta
			if readoutTimer <= 0.0:
				readoutTimer = 0.1
				readout = int(target)
			key = [snappedf(shownValue, 0.2), readout]
		_: key = [snappedf(shownValue, 0.25), shownValue < LOW && HudTheme.blinkOn(), leaking(car)]
	if key != shownKey:
		shownKey = key
		needle.queue_redraw()

#the revs: through the gear the car is in (an automatic's shown gear too), bouncing off the limiter at the top of any gear but the
#last; in N the throttle revs it freely
static func gearedRpm(car) -> float:
	if car.gear == 0: return 0.8 + (5.6 if car._car_input.acceleration > 0.0 else 0.0)
	var r: float = car.rpmShare()
	if car.velocity.length() < 5.0 && car._car_input.acceleration == 0.0: return 0.8
	var rpm := 1.1 + 6.4 * minf(r, 1.0)
	if r >= 1.0 && car.gear < car.gears && car._car_input.acceleration > 0.0: rpm -= 0.35 * absf(sin(Time.get_ticks_msec() * 0.03))
	return rpm

#the gear's colour: gold, green near the redline of a gear you shift by hand (time to shift up), white
#while a well-timed shift's push lasts
static func gearColor(car) -> Color:
	if car.gears <= 0 || car.gear < 1: return HudTheme.GOLD
	if car.shiftKick > 0: return Color.WHITE
	if car.isManual() && car.gear < car.gears && car.rpmShare() >= OverheadCarBody2D.SHIFT_KICK_FROM: return HudTheme.OK
	return HudTheme.GOLD

static func gearText(car) -> String:
	if car.gear < 0: return "R"
	if car.gear == 0: return "N"
	return str(car.gear)

#the fuel tank leaks once the damage model wears it below half (see docs/HUD.md)
func leaking(car) -> bool:
	return kind == Kind.FUEL && car.condition.tank < 50.0

func angleFor(fraction: float) -> float:
	var sweep = SMALL_SWEEP if isSmall() else SWEEP
	return -sweep + 2.0 * sweep * clampf(fraction, 0.0, 1.0)

#---------- face ----------

func _draw() -> void:
	draw_circle(center, radius, FACE)
	draw_arc(center, radius - 1.5 * unit, 0.0, TAU, 64, HudTheme.RIM, 3.0 * unit, true)
	draw_arc(center, radius - 8.0 * unit, 0.0, TAU, 64, Color(1, 1, 1, 0.06), 2.0 * unit, true)
	match kind:
		Kind.TACH: drawBigFace(RPM_MAX, 1, true)
		Kind.SPEEDO: drawBigFace(speedMax, speedMax / 8, false)
		Kind.FUEL: drawSmallFace("E", "F", FUEL_ICON)
		Kind.HULL: drawSmallFace("0", "100", HULL_ICON)

func drawBigFace(maxValue: float, step: float, isTach: bool) -> void:
	HudTheme.arc(self, center, 100 * unit, -SWEEP, SWEEP, HudTheme.TRACK, 6 * unit)
	if isTach:
		HudTheme.arc(self, center, 100 * unit, angleFor(REDLINE / RPM_MAX), SWEEP, HudTheme.BAD, 6 * unit)
		HudTheme.text(self, center + Vector2(0, -30) * unit, "RPM x1000", int(10 * unit), HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 0)
	else: #the green arc is where hitting a goon crushes it
		HudTheme.arc(self, center, 111 * unit, angleFor(CRUSH_SPEED * unitsPerPx() / maxValue), SWEEP, Color(HudTheme.OK, 0.85), 4 * unit)
	for i in 17:
		var d = angleFor(i / 16.0)
		var major = i % 2 == 0
		draw_line(HudTheme.polar(center, (86 if major else 95) * unit, d), HudTheme.polar(center, 106 * unit, d), HudTheme.TEXT, (3.0 if major else 1.5) * unit, true)
		if major:
			var label = str(int(round(step * i / 2)))
			HudTheme.text(self, HudTheme.polar(center, 70 * unit, d) + Vector2(0, 7) * unit, label, int((19 if isTach else 16) * unit), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)

func drawSmallFace(low: String, high: String, icon: Texture2D) -> void:
	HudTheme.arc(self, center, 50 * unit, -SMALL_SWEEP, SMALL_SWEEP, HudTheme.TRACK, 9 * unit)
	HudTheme.text(self, HudTheme.polar(center, 50 * unit, -92) + Vector2(0, 6) * unit, low, int(13 * unit), HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(self, HudTheme.polar(center, 50 * unit, 92) + Vector2(0, 6) * unit, high, int(13 * unit), HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.icon(self, icon, center + Vector2(0, 22) * unit, 24 * unit)

#---------- needle and readouts ----------

func drawPointer(degrees: float, length: float, color: Color, width: float) -> void:
	needle.draw_line(HudTheme.polar(center, 14 * unit, degrees + 180.0), HudTheme.polar(center, length, degrees), color, width, true)
	needle.draw_circle(center, 10 * unit, HUB)
	needle.draw_arc(center, 10 * unit, 0.0, TAU, 24, color, 3 * unit, true)

func drawNeedle() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	match kind:
		Kind.TACH:
			drawPointer(angleFor(shownValue / RPM_MAX), 98 * unit, HudTheme.NEEDLE, 5 * unit)
			HudTheme.text(needle, center + Vector2(0, 74) * unit, gearText(car), int(40 * unit), gearColor(car), HORIZONTAL_ALIGNMENT_CENTER, 10, HudTheme.DEEP)
		Kind.SPEEDO:
			drawPointer(angleFor(shownValue / speedMax), 98 * unit, HudTheme.NEEDLE, 5 * unit)
			HudTheme.text(needle, center + Vector2(0, 66) * unit, str(readout), int(34 * unit), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 7)
			HudTheme.text(needle, center + Vector2(0, 84) * unit, "KM/H" if unitsPerPx() > 0.1 else "MPH", int(11 * unit), HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 0)
		_:
			var color = HudTheme.WARN if kind == Kind.FUEL else HudTheme.conditionColor(shownValue)
			if shownValue < LOW: color = HudTheme.BAD if HudTheme.blinkOn() else Color(0.48, 0.16, 0.13)
			HudTheme.arc(needle, center, 50 * unit, -SMALL_SWEEP, angleFor(shownValue / 100.0), color, 9 * unit)
			drawPointer(angleFor(shownValue / 100.0), 44 * unit, HudTheme.TEXT, 4 * unit)
			HudTheme.text(needle, center + Vector2(0, 56) * unit, str(int(round(shownValue))), int(17 * unit), color, HORIZONTAL_ALIGNMENT_CENTER, 6)
			if leaking(car): HudTheme.text(needle, center + Vector2(0, -72) * unit, "LEAK", int(13 * unit), HudTheme.BAD, HORIZONTAL_ALIGNMENT_CENTER, 6)
