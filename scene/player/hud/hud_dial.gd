class_name HudDial extends Control

#One of the two instrument clusters sunk into the bottom corners: the tachometer (left) with the fuel and the
#engine and tank lamps, or the speedometer (right) with the hull and the steering, lights and tires lamps.
#Only the top two thirds of a dial is on screen, so its scale is a half turn tilted toward the middle of the
#screen, and the gear and the speed sit in the hub. Fuel and hull are arcs round the dial's inner side (a bar
#beside a square housing). The face (ticks, numbers, arcs) is drawn once, and again only when its scale, its
#skin or night changes. The needle, readouts, fuel or hull and lamps are drawn on a child CanvasItem that
#redraws only when what it shows has visibly moved.
#How it looks is the car's dashboard (HudSkin, docs/HUD.md "Dashboards"): round needle dials with one of four
#bezels, the pickup's sliding ribbons, or the Track bar tach and digits; the ambulance's hull is a heart
#monitor. What it reads, and where pickups fly to, is the same on every dash.

enum Kind { TACH, SPEEDO }

@export var kind := Kind.SPEEDO
@export var flyerGroups: PackedStringArray = [] #reward flyers for these groups land on the fuel (tach) or the hull (speedo)

const TILT := 12.0           #the scale's half turn leans this many degrees toward the middle of the screen
#The tach's scale is the car's own (CarInfo.redline, thousands of rpm: a semi's 2.4, a sedan's 6, a supercar's 8.5)
const RPM_IDLE := 0.8        #idle, or RPM_IDLE_SHARE of a low redline
const RPM_IDLE_SHARE := 0.2
const RPM_AFTER_SHIFT := 0.35 #share of the redline the needle lands at after a shift up; it reaches the redline as the gear runs out
const RPM_OVER := 0.5        #past the redline on the limiter
const RPM_HEADROOM := 0.75   #the dial runs to the next whole thousand past redline + this
const CRUSH_SPEED := 100.0   #px/s; goons die when hit faster than this (overhead_car_body_2d)
const LOW := 25.0            #fuel and hull blink under this
const BOOT_SECONDS := 1.1    #the ignition sweep at the start of a run: needles to the top of the scale and back
const WORN := 40.0           #under this hull the speedometer's glass is cracked; under this engine condition the tach needle trembles
const HUB := 30.0            #the hub disc that holds the gear or the speed, in face units
const WING_FROM := 100.0     #fuel and hull arcs: from this many degrees round the inner side (empty)...
const WING_TO := 40.0        #...up to this (full)
const RIBBON_BOX := 92.0     #a ribbon's readout box, at its right end
const RIBBON_ROW := 62.0     #a ribbon's height; the fuel or hull bar and the lamps are a row under it
const MONITOR := Vector2(210, 94) #the heart monitor, beside the speedometer
const CRACK := [Vector2(-66, -61), Vector2(-49, -34), Vector2(-58, -20), Vector2(-35, -8)] #face units from the centre
const SCREEN := Color(0.016, 0.078, 0.047, 0.95) #the heart monitor

const FUEL_ICON := preload("res://texture/icon/fuel.svg")
const HULL_ICON := preload("res://texture/icon/health.svg")
const HORN_ICON := preload("res://texture/icon/horn.svg")
const HORN_LIT := 20         #ticks the horn lamp stays bright after a honk
const TAPE := Color(0.64, 0.66, 0.67)

var needle := Control.new()
var skin: HudSkin = HudSkin.named(&"house")
var baseOffsets := []        #where the scene put it; a skin may move it (HudSkin.rects)
var wingMarkers: Array[Control] = []
var lampMarkers := {}        #system id -> the point its stat pickup flies to
var center: Vector2
var radius: float
var unit: float              #face design units: a dial is 118 across its radius
var rpmMax := 8.0            #the tach's scale and red zone, set from the car (setRevScale)
var redline := 6.5
var speedMax := 160          #speedometer scale in the player's units, set from the car's top speed
var scaled := false
var night := false           #the backlight is on
var boot := -1.0             #seconds into the ignition sweep; -1 when it is over
var beat := 0.0              #the heart monitor's trace, in beats
var shownValue := 0.0        #the needle eases toward its target, frame-rate independent
var wingShown := 0.0         #fuel or hull, eased the same way
var shownKey := []
var readout := 0             #speedometer digits, refreshed 10 times a second like the old HUD
var readoutTimer := 0.0
var lastStats := {}
var landsAt := {}            #system id -> msec when its pickup flyer arrives

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	baseOffsets = [offset_left, offset_top, offset_right, offset_bottom]
	needle.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(needle)
	needle.draw.connect(drawNeedle)
	for group in flyerGroups: wingMarkers.push_back(HudTheme.marker(self, group, size * 0.5))
	for id in systems(): lampMarkers[id] = HudTheme.marker(self, HudLamps.SYSTEMS[id].stat + "ui", size * 0.5)
	resized.connect(layOut)
	Settings.changed.connect(onSettingChanged)
	applySkin()

## The system lamps this cluster carries, left to right
func systems() -> Array[String]:
	return HudLamps.LEFT if kind == Kind.TACH else HudLamps.RIGHT

#+1 on the tachometer, -1 on the speedometer: the way toward the middle of the screen
func inward() -> float:
	return 1.0 if kind == Kind.TACH else -1.0

func isRibbon() -> bool:
	return skin.style == HudSkin.Style.RIBBON

func isBar() -> bool:
	return skin.style == HudSkin.Style.BAR

func isMonitor() -> bool:
	return kind == Kind.SPEEDO && skin.hullMonitor

#fuel or hull is a bar beside the dial where its housing is square, an arc round it otherwise
func wingIsBar() -> bool:
	return skin.bezel == HudSkin.Bezel.SQUARE || skin.bezel == HudSkin.Bezel.CHROME

#the car's dashboard: its look, and the place the skin gives this dial
func applySkin() -> void:
	skin = HudSkin.current()
	var to: Array = skin.rects.get(int(kind), baseOffsets)
	offset_left = to[0]
	offset_top = to[1]
	offset_right = to[2]
	offset_bottom = to[3]
	layOut()

func layOut() -> void:
	center = Vector2(size.x * 0.5, size.x * 0.5) #a round dial's box is square, with its lower part under the screen's edge
	radius = size.x * 0.5
	unit = radius / 118.0
	needle.size = size
	for marker in wingMarkers: marker.position = wingAnchor()
	var ids := systems()
	for i in ids.size(): lampMarkers[ids[i]].position = lampAt(i)
	queue_redraw()
	needle.queue_redraw()

func onSettingChanged(key: String, _value) -> void:
	if key == "gameplay/speed_units" && kind == Kind.SPEEDO: setSpeedScale()
	if key == "access/classic_dash": applySkin()

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
	return gearedRpm(car) if kind == Kind.TACH else car.velocity.length() * unitsPerPx()

#fuel on the tachometer, hull on the speedometer
func wingTarget(car) -> float:
	return clampf(car.fuel if kind == Kind.TACH else car.health, 0.0, 100.0)

func fullScale() -> float:
	return rpmMax if kind == Kind.TACH else float(speedMax)

func _process(delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var calm: bool = Settings.reduce_motion()
	if not scaled:
		scaled = true
		applySkin()
		if kind == Kind.SPEEDO: setSpeedScale()
		if kind == Kind.TACH: setRevScale(car)
		if not calm: boot = 0.0
	var dark: bool = is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight
	if dark != night:
		night = dark
		queue_redraw()
	var target = targetValue(car)
	if boot >= 0.0: #the ignition sweep
		boot += delta
		if boot >= BOOT_SECONDS: boot = -1.0
		else: target = fullScale() * sin(PI * boot / BOOT_SECONDS)
	elif kind == Kind.TACH && car.condition.engine < WORN && not calm: target += (randf() - 0.5) * redline * 0.06 #a worn engine: the needle trembles
	var step := 1.0 - exp(-delta * 14.0)
	shownValue = lerpf(shownValue, target, step)
	wingShown = lerpf(wingShown, wingTarget(car), step)
	#a damaged lights system: the backlight flickers at night
	var dim: bool = night && car.condition.lights < WORN && not Settings.get_value("access/reduce_flashing") && randf() < 0.06
	var alpha := 0.6 if dim else 1.0
	if modulate.a != alpha: modulate.a = alpha
	var key := [snappedf(wingShown, 0.25), wingShown < LOW && HudTheme.blinkOn(), car.myLights.visible]
	if kind == Kind.TACH:
		key.append_array([snappedf(shownValue, 0.02), gearText(car), gearColor(car), hornState(car), car.condition.tank < 50.0])
		if taped(): key.push_back(taping(car) && HudTheme.blinkOn())
	else:
		readoutTimer -= delta
		if readoutTimer <= 0.0:
			readoutTimer = 0.1
			readout = int(target) if boot < 0.0 else int(shownValue)
		key.append_array([snappedf(shownValue, 0.2), readout, cracked(car)])
		if isMonitor() && not calm: #the trace runs faster as the hull drops
			beat += delta * lerpf(2.4, 0.9, wingShown / 100.0)
			key.push_back(int(beat * 24.0))
	#the lamps: a stat that rose has a pickup on its way, and its lamp pulses as it lands
	var now := Time.get_ticks_msec()
	var animating := false
	for id in systems():
		var stat = car.get(HudLamps.SYSTEMS[id].stat)
		if lastStats.has(id) && stat > lastStats[id]: landsAt[id] = now + int(RewardFlyers.FLIGHT_SECONDS * 1000.0)
		lastStats[id] = stat
		var condition: float = car.condition[id]
		key.append_array([stat, roundi(condition)])
		if condition < 25.0 || (landsAt.has(id) && now < landsAt[id] + HudLamps.PULSE_MS): animating = true
	if animating: key.push_back(now)
	if key != shownKey:
		shownKey = key
		needle.queue_redraw()

#the revs: through the gear the car is in (an automatic's shown gear too), bouncing off the limiter at the top of any gear but the
#last; in N the throttle revs it freely
static func gearedRpm(car) -> float:
	var red: float = car.redline
	var idle := idleRpm(red)
	if car.gear == 0: return lerpf(idle, red, 0.85) if car._car_input.acceleration > 0.0 else idle
	if car.velocity.length() < 5.0 && car._car_input.acceleration == 0.0: return idle
	var share: float = car.revShare()
	#a shift up lands at RPM_AFTER_SHIFT of the redline and the revs climb to the redline at the gear's limit; first
	#gear climbs from idle. Too high a gear sags toward idle; on the limiter the needle sits in the red and stutters.
	var low := red * RPM_AFTER_SHIFT if car.gear > 1 else idle * 1.3
	var rpm := maxf(lerpf(low, red, minf(share, 1.0)), idle)
	if share >= 1.0:
		rpm = minf(red + (share - 1.0) * red, red + RPM_OVER)
		if car.gear < car.gears && car._car_input.acceleration > 0.0: rpm -= red * 0.04 * absf(sin(Time.get_ticks_msec() * 0.03))
	return rpm

static func idleRpm(red: float) -> float:
	return minf(RPM_IDLE, red * RPM_IDLE_SHARE)

## The tach's top number for a redline: the next whole thousand past redline + RPM_HEADROOM
static func rpmMaxFor(red: float) -> float:
	return ceilf(red + RPM_HEADROOM)

func setRevScale(car) -> void:
	redline = car.redline
	rpmMax = rpmMaxFor(redline)
	queue_redraw()
	needle.queue_redraw()

#the gear's colour: gold, green near the redline of a gear you shift by hand (time to shift up), white
#while a well-timed shift's push lasts
static func gearColor(car) -> Color:
	if car.gears <= 0 || car.gear < 1: return HudTheme.GOLD
	if car.shiftKick > 0: return Color.WHITE
	if car.isManual() && car.gear < car.gears && car.revShare() >= OverheadCarBody2D.SHIFT_KICK_FROM: return HudTheme.OK
	return HudTheme.GOLD

static func gearText(car) -> String:
	if car.gear < 0: return "R"
	if car.gear == 0: return "N"
	return str(car.gear)

#the fuel tank leaks once the damage model wears it below half (see docs/HUD.md)
func leaking(car) -> bool:
	return kind == Kind.TACH && car.condition.tank < 50.0

#the horn lamp on the tach: 2 just after a honk, 0 while the horn can't sound again yet, 1 ready
static func hornState(car) -> int:
	if car.hornCooldown > OverheadCarBody2D.HORN_COOLDOWN - HORN_LIT: return 2
	return 0 if car.hornCooldown > 0 else 1

#the beater's fuel arc has tape across its end, which lights up while Duct Tape is patching the car
func taped() -> bool:
	return kind == Kind.TACH && skin.id == &"beater"

static func taping(car) -> bool:
	return is_instance_valid(car.traitRig) && car.traitRig.taping()

#the gear has its own window on the semi's instrument (HudInstrument, "load")
func showsGear() -> bool:
	return skin.instrument != &"load"

#the gear or the speed sits in a disc at the hub, and the needle starts at its edge
func hasHubDisc() -> bool:
	return not isBar() && (kind == Kind.SPEEDO || showsGear())

#a cracked glass: the beater's always is, and any car's under WORN hull
func cracked(car) -> bool:
	return skin.id == &"beater" || car.health < WORN

#the scale: a half turn (the skin's sweep either side), leaning toward the middle of the screen
func sweepFrom() -> float:
	return -skin.sweep + TILT * inward()

func sweepTo() -> float:
	return skin.sweep + TILT * inward()

func angleFor(fraction: float) -> float:
	return lerpf(sweepFrom(), sweepTo(), clampf(fraction, 0.0, 1.0))

## The tach's numbered ticks: one a thousand rpm, or one every 500 on a tach that reads in hundreds
func tachMajors() -> int:
	return int(rpmMax) * (2 if skin.tachUnits == 10 else 1)

func tachLabel(i: int) -> String:
	return str(i * 5) if skin.tachUnits == 10 else str(i)

func tachCaption() -> String:
	return "RPM x100" if skin.tachUnits == 10 else "RPM x1000"

func speedUnit() -> String:
	return "KM/H" if unitsPerPx() > 0.1 else "MPH"

#numerals and ticks: the skin's, tinted by the backlight at night
func ink() -> Color:
	return skin.text.lerp(skin.glow, 0.4) if night && not skin.light else skin.text

#the gear number's colour on this dash: the skin's accent where the HUD's gold would be, a darker green on a light face
func gearInk(car) -> Color:
	var color := gearColor(car)
	if color == HudTheme.GOLD: return skin.accent
	if color == HudTheme.OK: return skin.ok
	return skin.needle if skin.light else color

#---------- where things sit ----------

## Lamp `i` of this cluster's: on a round face they sit between the hub and the numerals, either side of the top
## (and at the top, the speedometer's third); on a ribbon, in the row under it
func lampAt(i: int) -> Vector2:
	var count := systems().size()
	if isRibbon(): return Vector2(size.x - 26.0 - (count - 1 - i) * 34.0, RIBBON_ROW + 19.0)
	var spread := 50.0 if isBar() else 62.0
	return HudTheme.polar(center, lampReach(), lerpf(-spread, spread, float(i) / (count - 1)))

func lampReach() -> float:
	return (52.0 if isBar() else 47.0) * unit

func lampUnit() -> float:
	return 1.15 if isRibbon() else unit

#the horn lamp, on the tachometer: at the top of the face, between its two system lamps
func hornAt() -> Vector2:
	if isRibbon(): return ribbonBox().position + Vector2(12, 11)
	return HudTheme.polar(center, lampReach(), 0.0)

#fuel or hull as a bar beside a square housing
func wingBar() -> Rect2:
	return Rect2(size.x + 10.0 if inward() > 0.0 else -22.0, 62, 12, 88)

#the row under a ribbon: the fuel or hull bar
func stripBar() -> Rect2:
	return Rect2(44, RIBBON_ROW + 13.0, 140, 12)

func monitorRect() -> Rect2:
	return Rect2(Vector2(size.x + 16.0 if inward() > 0.0 else -16.0 - MONITOR.x, 60), MONITOR)

## The fuel or hull icon, where its pickups land
func wingAnchor() -> Vector2:
	if isRibbon(): return Vector2(24, RIBBON_ROW + 19.0)
	if isMonitor(): return monitorRect().position + Vector2(MONITOR.x - 38.0, 22)
	if wingIsBar(): return Vector2(wingBar().get_center().x, wingBar().position.y - 16.0)
	return HudTheme.polar(center, radius + 32.0 * unit, 84.0 * inward())

#the arc from empty up to `fraction` full
func wingArc(item: CanvasItem, fraction: float, color: Color) -> void:
	var to := lerpf(WING_FROM, WING_TO, clampf(fraction, 0.0, 1.0))
	if inward() > 0.0: HudTheme.arc(item, center, radius + 10 * unit, to, WING_FROM, color, 9 * unit)
	else: HudTheme.arc(item, center, radius + 10 * unit, -WING_FROM, -to, color, 9 * unit)

#---------- face ----------

func _draw() -> void:
	if isRibbon():
		drawRibbonFace(kind == Kind.TACH)
		return
	drawBezel()
	if kind == Kind.TACH:
		if isBar(): drawBarTachFace()
		else: drawBigFace(true)
	elif isBar(): drawDigitFace()
	else: drawBigFace(false)
	var icon := FUEL_ICON if kind == Kind.TACH else HULL_ICON
	if isMonitor(): drawMonitorFace()
	elif wingIsBar():
		draw_rect(wingBar().grow(2), Color(0.03, 0.03, 0.03, 0.85))
		draw_rect(wingBar(), skin.track)
		HudTheme.icon(self, icon, wingAnchor(), 22 * unit)
	else:
		wingArc(self, 1.0, Color(skin.track, 0.92))
		HudTheme.icon(self, icon, wingAnchor(), 22 * unit)

#the housing, the face and its rim
func drawBezel() -> void:
	var s := skin
	var r := radius
	var whole := Rect2(Vector2.ZERO, size)
	match s.bezel:
		HudSkin.Bezel.SQUARE:
			HudTheme.panel(self, whole, s.rim, int(18 * unit), s.house)
			r -= 8.0 * unit
			draw_circle(center, r, s.face)
			draw_arc(center, r - unit, 0.0, TAU, 64, s.rim, 2.0 * unit, true)
		HudSkin.Bezel.CHROME: #a wood plate, then a chrome ring shaded round its turn
			HudTheme.panel(self, whole, Color(0.16, 0.1, 0.06), int(16 * unit), Color(0.227, 0.145, 0.086, 0.96))
			for i in 5:
				var y = size.y * (0.12 + 0.19 * i)
				draw_line(Vector2(14 * unit, y), Vector2(size.x - 14 * unit, y + 3 * unit), Color(0.3, 0.196, 0.125), 1.5, true)
			draw_circle(center, r, s.face)
			for i in 48:
				var from = TAU * i / 48.0
				var shade = Color(0.36, 0.38, 0.4).lerp(Color(0.96, 0.96, 0.96), 0.5 + 0.5 * sin(from * 2.0 + 0.8))
				draw_arc(center, r - 3.5 * unit, from, from + TAU / 48.0 + 0.02, 3, shade, 7.0 * unit, true)
		HudSkin.Bezel.CHECKER:
			draw_circle(center, r, s.face)
			for i in 72:
				draw_arc(center, r - 5.0 * unit, TAU * i / 72.0, TAU * (i + 1) / 72.0, 3, s.rim if i % 2 == 0 else Color(0.03, 0.03, 0.03), 8.0 * unit)
			draw_arc(center, r - 10.0 * unit, 0.0, TAU, 64, s.rim, unit, true)
		_:
			draw_circle(center, r, s.face)
			draw_arc(center, r - 1.5 * unit, 0.0, TAU, 64, s.rim, s.rimWidth * unit, true)
			if not s.light: draw_arc(center, r - 8.0 * unit, 0.0, TAU, 64, Color(1, 1, 1, 0.06), 2.0 * unit, true)
	if s.weave: #carbon: hatching across the face
		var reach := r - 12.0 * unit
		var gap := 9.0 * unit
		var d := -reach + gap
		while d < reach:
			var half := sqrt(reach * reach - d * d)
			var along := Vector2(0.7071, 0.7071)
			var across := Vector2(-0.7071, 0.7071) * d
			draw_line(center + across - along * half, center + across + along * half, Color(1, 1, 1, 0.045), 3.0 * unit, true)
			d += gap
	if night: draw_arc(center, r - 1.5 * unit, 0.0, TAU, 64, Color(s.glow, 0.4), 5.0 * unit, true)

func drawBigFace(isTach: bool) -> void:
	var s := skin
	var color := ink()
	var maxValue := rpmMax if isTach else float(speedMax)
	var majors := tachMajors() if isTach else 8
	var minor := (5 if s.tachUnits == 10 else 2) if isTach else s.minor
	HudTheme.arc(self, center, 100 * unit, sweepFrom(), sweepTo(), s.track, 6 * unit)
	if isTach:
		if s.econ != Vector2.ZERO: HudTheme.arc(self, center, 100 * unit, angleFor(s.econ.x / rpmMax), angleFor(s.econ.y / rpmMax), s.ok, 6 * unit)
		HudTheme.arc(self, center, 100 * unit, angleFor(redline / rpmMax), sweepTo(), s.bad, 6 * unit)
		if s.tachUnits == 10: s.write(self, center + Vector2(0, -20) * unit, tachCaption(), int(10 * unit), s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
	else: #the green arc is where hitting a goon crushes it
		var from := angleFor(CRUSH_SPEED * unitsPerPx() / maxValue)
		if s.bezel == HudSkin.Bezel.RING: HudTheme.arc(self, center, 111 * unit, from, sweepTo(), Color(s.ok, 0.85), 4 * unit)
		else: HudTheme.arc(self, center, 100 * unit, from, sweepTo(), s.ok, 6 * unit) #a wide bezel: on the track
	var total := majors * minor
	var numerals := (19.0 if isTach else 16.0) * s.numScale * (0.85 if majors > 8 else 1.0)
	for i in total + 1:
		var d = angleFor(float(i) / total)
		var major = i % minor == 0
		var mid = minor >= 10 && i % (minor / 2) == 0
		draw_line(HudTheme.polar(center, (86 if major else 91 if mid else 95) * unit, d), HudTheme.polar(center, 106 * unit, d), color, (3.0 if major else 1.5) * unit, true)
		#a half turn has room for every number on the tach, and every other one on the speedometer
		if major && (isTach || (i / minor) % 2 == 0):
			var label = tachLabel(i / minor) if isTach else str(int(round(maxValue / 8.0 * (i / minor))))
			s.write(self, HudTheme.polar(center, 70 * unit, d) + Vector2(0, 7) * unit, label, int(numerals * unit), color)

#--- Track: a segmented bar tach round the gear, and the speed in digits ---

func barSegments() -> int:
	return int(rpmMax) * 4

#segment `i` of the bar, lit or not
func drawSegment(item: CanvasItem, i: int, color: Color) -> void:
	var span := 2.0 * skin.sweep / barSegments()
	HudTheme.arc(item, center, 96 * unit, sweepFrom() + i * span + 0.6, sweepFrom() + (i + 1) * span - 0.6, color, 13 * unit)

func drawBarTachFace() -> void:
	for i in barSegments(): drawSegment(self, i, skin.track)
	HudTheme.arc(self, center, 109 * unit, angleFor(redline / rpmMax), sweepTo(), skin.bad, 3 * unit)
	for i in int(rpmMax) + 1:
		skin.write(self, HudTheme.polar(center, 76 * unit, angleFor(i / rpmMax)) + Vector2(0, 5) * unit, str(i), int(13 * skin.numScale * unit), skin.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)

func drawDigitFace() -> void:
	HudTheme.arc(self, center, 100 * unit, sweepFrom(), sweepTo(), skin.track, 6 * unit)
	HudTheme.arc(self, center, 110 * unit, angleFor(CRUSH_SPEED * unitsPerPx() / speedMax), sweepTo(), skin.ok, 2.5 * unit)

#--- the pickup: a pointer sliding along a ribbon, with fuel or hull as a bar and the lamps in a row under it ---

func ribbonWindow() -> Rect2:
	return Rect2(8, 8, size.x - 24 - RIBBON_BOX, RIBBON_ROW - 12.0)

func ribbonBox() -> Rect2:
	return Rect2(size.x - 8 - RIBBON_BOX, 8, RIBBON_BOX, RIBBON_ROW - 12.0)

func ribbonX(fraction: float) -> float:
	var window := ribbonWindow()
	return window.position.x + 18.0 + (window.size.x - 36.0) * clampf(fraction, 0.0, 1.0)

func drawRibbonFace(isTach: bool) -> void:
	var s := skin
	var window := ribbonWindow()
	var color := ink()
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), s.rim, 12, s.house)
	HudTheme.panel(self, window, Color(s.rim, 0.5), 6, s.face)
	HudTheme.panel(self, ribbonBox(), Color(s.rim, 0.5), 6, s.face)
	var maxValue := rpmMax if isTach else float(speedMax)
	var majors := tachMajors() if isTach else 8
	var base := window.end.y - 9.0
	for i in majors * 2 + 1:
		var x := ribbonX(i / (majors * 2.0))
		var major := i % 2 == 0
		draw_line(Vector2(x, base - (13.0 if major else 7.0)), Vector2(x, base), color, 2.5 if major else 1.3, true)
		if major && (isTach || speedMax <= 120 || i % 4 == 0): #a long speed scale numbers every other tick
			var label = tachLabel(i / 2) if isTach else str(int(round(maxValue / 8.0 * (i / 2))))
			s.write(self, Vector2(x, base - 17.0), label, int(15 * s.numScale), color)
	if isTach: draw_rect(Rect2(ribbonX(redline / rpmMax), base + 1.0, ribbonX(1.0) - ribbonX(redline / rpmMax), 4.0), s.bad)
	else: #green from the speed that crushes a goon
		var from := ribbonX(CRUSH_SPEED * unitsPerPx() / maxValue)
		draw_rect(Rect2(from, base + 1.0, ribbonX(1.0) - from, 4.0), s.ok)
	HudTheme.icon(self, FUEL_ICON if isTach else HULL_ICON, wingAnchor(), 24)

#--- the ambulance: the hull as a heart monitor ---

func monitorTrace() -> Rect2:
	var whole := monitorRect()
	return Rect2(whole.position + Vector2(8, 8), whole.size - Vector2(86, 16))

func drawMonitorFace() -> void:
	var trace := monitorTrace()
	var whole := monitorRect()
	HudTheme.panel(self, whole, Color(0.75, 0.78, 0.76), 10, SCREEN)
	var x := trace.position.x + 12.0
	while x < trace.end.x:
		draw_line(Vector2(x, trace.position.y), Vector2(x, trace.end.y), Color(0.05, 0.165, 0.1), 1.0)
		x += 24.0
	var y := trace.position.y + 16.0
	while y < trace.end.y:
		draw_line(Vector2(trace.position.x, y), Vector2(trace.end.x, y), Color(0.05, 0.165, 0.1), 1.0)
		y += 24.0
	draw_line(Vector2(trace.end.x + 4.0, whole.position.y + 10), Vector2(trace.end.x + 4.0, whole.end.y - 10), Color(0.11, 0.23, 0.165), 1.5)
	HudTheme.icon(self, HULL_ICON, wingAnchor(), 24)

#one heartbeat, 0..1 through it: the height of the trace above its baseline
static func heartbeat(p: float) -> float:
	if p < 0.10: return 0.0
	if p < 0.18: return 5.0 * sin((p - 0.10) / 0.08 * PI)
	if p < 0.24: return 0.0
	if p < 0.27: return -6.0 * (p - 0.24) / 0.03
	if p < 0.31: return -6.0 + 44.0 * (p - 0.27) / 0.04
	if p < 0.35: return 38.0 - 50.0 * (p - 0.31) / 0.04
	if p < 0.38: return -12.0 + 12.0 * (p - 0.35) / 0.03
	if p < 0.5: return 0.0
	if p < 0.64: return 8.0 * sin((p - 0.5) / 0.14 * PI)
	return 0.0

#---------- needle, readouts, fuel or hull, lamps ----------

#the needle: from the hub disc's edge where the hub holds a readout, through the centre otherwise
func drawPointer(degrees: float, length: float, color: Color, width: float) -> void:
	var disc := hasHubDisc()
	var hub := HUB * unit if disc else 10 * unit
	if skin.taper:
		var points: PackedVector2Array
		if disc: points = PackedVector2Array([HudTheme.polar(center, hub, degrees - 14.0), HudTheme.polar(center, length, degrees), HudTheme.polar(center, hub, degrees + 14.0)])
		else: points = PackedVector2Array([HudTheme.polar(center, 8 * unit, degrees - 90.0), HudTheme.polar(center, length, degrees),
			HudTheme.polar(center, 8 * unit, degrees + 90.0), HudTheme.polar(center, 20 * unit, degrees + 180.0)])
		needle.draw_colored_polygon(points, color)
	else:
		var from := HudTheme.polar(center, hub, degrees) if disc else HudTheme.polar(center, 14 * unit, degrees + 180.0)
		needle.draw_line(from, HudTheme.polar(center, length, degrees), color, width, true)
		if skin.tip.a > 0.0: needle.draw_line(HudTheme.polar(center, length * 0.8, degrees), HudTheme.polar(center, length, degrees), skin.tip, width, true)
	needle.draw_circle(center, hub, skin.hub)
	needle.draw_arc(center, hub, 0.0, TAU, 32, skin.text if skin.taper else color, (1.5 if skin.taper else 3.0) * unit, true)

func drawNeedle() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var s := skin
	var now := Time.get_ticks_msec()
	var ids := systems()
	if isRibbon(): drawRibbon(car)
	for i in ids.size(): HudLamps.draw(needle, s, car, ids[i], lampAt(i), lampUnit(), now, landsAt)
	if isRibbon(): return
	if isMonitor(): drawMonitor()
	else: drawWing(car)
	if kind == Kind.TACH:
		drawHorn(car, hornAt(), 18 * unit)
		if isBar():
			var hot := shownValue >= redline * 0.97
			var lit := shownValue / rpmMax * barSegments()
			for i in ceili(lit): drawSegment(needle, i, Color(s.bad if hot else s.accent, clampf(lit - i, 0.25, 1.0)))
			s.write(needle, center + Vector2(0, 22) * unit, gearText(car), int(58 * unit), Color.WHITE if hot else gearInk(car), HORIZONTAL_ALIGNMENT_CENTER, 8)
		else:
			drawPointer(angleFor(shownValue / rpmMax), 98 * unit, s.needle, 5 * unit)
			if showsGear(): s.write(needle, center + Vector2(0, 14) * unit, gearText(car), int(40 * unit), gearInk(car), HORIZONTAL_ALIGNMENT_CENTER, 8)
	else:
		if isBar():
			HudTheme.arc(needle, center, 100 * unit, sweepFrom(), angleFor(shownValue / speedMax), s.text, 6 * unit)
			s.write(needle, center + Vector2(0, 14) * unit, str(readout), int(38 * unit), s.text, HORIZONTAL_ALIGNMENT_CENTER, 8)
			s.write(needle, center + Vector2(0, 30) * unit, speedUnit(), int(9 * unit), s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
		else:
			drawPointer(angleFor(shownValue / speedMax), 98 * unit, s.needle, 5 * unit)
			s.write(needle, center + Vector2(0, 7) * unit, str(readout), int(27 * unit), s.text, HORIZONTAL_ALIGNMENT_CENTER, 6)
			s.write(needle, center + Vector2(0, 20) * unit, speedUnit(), int(8 * unit), s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
		if cracked(car):
			var crack := PackedVector2Array()
			for point in CRACK: crack.push_back(center + point * unit)
			needle.draw_polyline(crack, Color(1, 1, 1, 0.4), 1.3, true)
			needle.draw_line(crack[2], crack[2] + Vector2(-19, 12) * unit, Color(1, 1, 1, 0.3), 1.0, true)

#fuel is amber, the hull green to red; both blink red when low
func wingColor() -> Color:
	var color := skin.warn if kind == Kind.TACH else skin.condition(wingShown)
	if wingShown < LOW: color = skin.bad if HudTheme.blinkOn() else Color(0.48, 0.16, 0.13)
	return color

#fuel or hull: the arc (or the bar) filled from the bottom, with its number by its icon
func drawWing(car) -> void:
	var color := wingColor()
	var at := wingAnchor()
	var number := str(int(round(wingShown)))
	if wingIsBar():
		var bar := wingBar()
		var filled := bar.size.y * wingShown / 100.0
		var side := HORIZONTAL_ALIGNMENT_LEFT if inward() > 0.0 else HORIZONTAL_ALIGNMENT_RIGHT
		var beside := bar.get_center().x + 12.0 * inward()
		needle.draw_rect(Rect2(bar.position.x, bar.end.y - filled, bar.size.x, filled), color)
		skin.write(needle, Vector2(beside, bar.end.y), number, int(18 * unit), color, side, 6)
		if leaking(car): skin.write(needle, Vector2(beside, bar.end.y - 22.0), "LEAK", int(12 * unit), skin.bad, side, 6)
	else:
		wingArc(needle, wingShown / 100.0, color)
		skin.write(needle, at + Vector2(0, 30) * unit, number, int(18 * unit), color, HORIZONTAL_ALIGNMENT_CENTER, 6)
		if leaking(car): skin.write(needle, at + Vector2(0, 45) * unit, "LEAK", int(12 * unit), skin.bad, HORIZONTAL_ALIGNMENT_CENTER, 6)
	if taped(): drawTape(taping(car) && HudTheme.blinkOn())

#the horn lamp: a glow as it sounds, dim until it can sound again
func drawHorn(car, at: Vector2, lampSize: float) -> void:
	var state := hornState(car)
	if state == 2: needle.draw_circle(at, lampSize * 0.75, Color(skin.warn, 0.55))
	HudTheme.icon(needle, HORN_ICON, at, lampSize, Color(1, 1, 1, [0.2, 0.6, 1.0][state]))

#a strip of tape across the top end of the fuel arc, bright while it is patching
func drawTape(lit: bool) -> void:
	var color := Color(0.95, 0.96, 0.9) if lit else TAPE
	needle.draw_set_transform(HudTheme.polar(center, radius + 8 * unit, WING_TO + 4.0), -0.5)
	needle.draw_rect(Rect2(-30 * unit, -9 * unit, 60 * unit, 18 * unit), Color(color, 0.94))
	for y in [-3.0, 4.0]: needle.draw_line(Vector2(-30, y) * unit, Vector2(30, y) * unit, color.darkened(0.14), 1.0)
	needle.draw_set_transform(Vector2.ZERO)

func drawRibbon(car) -> void:
	var s := skin
	var window := ribbonWindow()
	var box := ribbonBox().get_center()
	var x := ribbonX(shownValue / fullScale())
	needle.draw_line(Vector2(x, window.position.y + 5.0), Vector2(x, window.end.y - 4.0), s.needle, 4.0, true)
	needle.draw_colored_polygon(PackedVector2Array([Vector2(x - 7, window.position.y + 2), Vector2(x + 7, window.position.y + 2), Vector2(x, window.position.y + 13)]), s.needle)
	if kind == Kind.TACH:
		s.write(needle, box + Vector2(0, 9), gearText(car), 34, gearInk(car), HORIZONTAL_ALIGNMENT_CENTER, 8)
		s.write(needle, box + Vector2(0, 21), tachCaption(), 8, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
		drawHorn(car, hornAt(), 16.0)
	else:
		s.write(needle, box + Vector2(0, 8), str(readout), 30, s.text, HORIZONTAL_ALIGNMENT_CENTER, 7)
		s.write(needle, box + Vector2(0, 21), speedUnit(), 9, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
	var color := wingColor()
	HudTheme.bar(needle, stripBar(), wingShown / 100.0, color, s.track)
	s.write(needle, Vector2(stripBar().end.x + 10.0, RIBBON_ROW + 27.0), str(int(round(wingShown))), 22, color, HORIZONTAL_ALIGNMENT_LEFT, 6)
	if leaking(car): s.write(needle, stripBar().get_center() + Vector2(0, 5), "LEAK", 13, s.bad, HORIZONTAL_ALIGNMENT_CENTER, 6)

func drawMonitor() -> void:
	var trace := monitorTrace()
	var whole := monitorRect()
	var color := HudTheme.conditionColor(wingShown)
	if wingShown < LOW && not HudTheme.blinkOn(): color = Color(0.48, 0.16, 0.13)
	var base := trace.position.y + trace.size.y * 0.6
	var gain := trace.size.y / 112.0 if wingShown > 0.5 else 0.0 #a wreck flatlines
	var points := PackedVector2Array()
	var x := trace.position.x + 2.0
	while x <= trace.end.x - 2.0:
		points.push_back(Vector2(x, base - heartbeat(fposmod((x - trace.position.x) / 92.0 - beat, 1.0)) * gain))
		x += 3.0
	needle.draw_polyline(points, color, 2.2, true)
	HudTheme.text(needle, Vector2(whole.end.x - 38.0, whole.end.y - 14.0), str(int(round(wingShown))), 40, color, HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, HudSkin.LED)
