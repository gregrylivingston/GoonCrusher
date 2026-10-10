class_name HudInstrument extends Control

#The car's signature instrument (docs/HUD.md, "Dashboards"): the one gauge no other car has, on the bottom
#edge just inside the tachometer's fuel arc. Which one is the skin's (HudSkin.instrument); most show a trait
#(CarTraits) the way that car's dash would: the taxi's meter, the van's tilt gauge, the racer's shift lights.
#Hidden on the house dash. Redraws only when what it shows changes.

const SIZE := Vector2(200, 96)
const KINDS: Array[StringName] = [&"beater", &"meter", &"radar", &"defib", &"load", &"bed", &"tilt", &"shift"]
const OFFSETS := [300.0, -104.0, 500.0, -8.0] #from the bottom left corner; a skin may give its own (HudSkin.instrumentAt)
const ODO_START := 187402    #the beater's odometer, in tenths of a mile
const LIGHTBAR := [Color(1.0, 0.18, 0.18), Color.WHITE, Color(0.184, 0.482, 1.0)]
const CRATE := Color(0.66, 0.46, 0.23)
const CRATE_EDGE := Color(0.37, 0.25, 0.11)

var skin: HudSkin = HudSkin.named(&"house")
var kind: StringName = &""
var set := false
var shownKey := []
var odo := 0.0               #px driven this run (the beater)
var fastest := 0.0           #px/s, the run's best (the radar)
var lean := 0.0              #degrees the tilt gauge shows
var rough := false           #on ground that lights the 4x4 lamp

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	Settings.changed.connect(onSettingChanged)

func onSettingChanged(key: String, _value) -> void:
	if key == "access/classic_dash": set = false

func _process(delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	if not set:
		set = true
		skin = HudSkin.current()
		kind = skin.instrument
		visible = kind != &""
		var to: Array = OFFSETS if skin.instrumentAt.is_empty() else skin.instrumentAt
		offset_left = to[0]
		offset_top = to[1]
		offset_right = to[2]
		offset_bottom = to[3]
		shownKey = []
	if not visible: return
	var rig: CarTraitRig = car.traitRig
	var speed: float = car.velocity.length()
	var calm: bool = Settings.reduce_motion()
	var key := []
	match kind:
		&"beater":
			odo += speed * delta
			key = [int(odo / 1000.0), car.secondWindUsed, car.condition.engine < HudDial.SCUFFED, car.condition.engine < HudDial.WORN && HudTheme.blinkOn()]
		&"meter":
			if rig: key = [rig.meterFare, rig.meterMult, rig.meterTicks > 0]
		&"radar":
			fastest = maxf(fastest, speed)
			key = [int(speed * HudDial.unitsPerPx()), int(fastest * HudDial.unitsPerPx()), lightbarPhase(car)]
		&"defib": key = [car.defibUsed, car.health < HudDial.LOW && HudTheme.blinkOn()]
		&"load":
			if rig: key = [int(rig.abilityReady() * 60.0), HudDial.gearText(car), HudDial.gearColor(car)]
		&"bed":
			if Engine.get_process_frames() % 6 == 0: rough = OverheadCarBody2D.isRough(World.surfaceAt(car.global_position))
			if rig: key = [rig.bedCrates, rough]
		&"tilt":
			lean = lerpf(lean, tiltOf(car, rig, speed), 1.0 - exp(-delta * (60.0 if calm else 8.0)))
			key = [snappedf(lean, 0.5), car.twoWheels, car.heldItem, car.heldCharges, car.spareItem, car.spareCharges]
		&"shift": key = [shiftLit(car), shiftNow(car) && flashOn(), int(traitFill(car, speed) * 80.0), car.gear]
	if key != shownKey:
		shownKey = key
		queue_redraw()

#---------- what they read ----------

#-1 by day or with no lightbar (the repeater sits dim), 0 steady, 1 red's turn, 2 blue's: in step with the car's own (CarTraitRig.tickLightbar)
static func lightbarPhase(car) -> int:
	if not car.tLightbar || not is_instance_valid(Root.spawnManager) || not Root.spawnManager.isNight: return -1
	if Settings.get_value("access/reduce_flashing"): return 0
	return 1 + (Engine.get_physics_frames() / 8) % 2

## Degrees the van leans: with how hard it corners for its speed, further once it is up on two wheels (CarTraitRig.tickTip)
static func tiltOf(car, rig: CarTraitRig, speed: float) -> float:
	var limit: float = car.yawLimit(speed)
	var share: float = clampf(absf(car.spinRate) / limit, 0.0, 1.0) if limit > 0.01 else 0.0
	var side := signf(car.spinRate)
	if car.twoWheels && rig: return side * lerpf(20.0, 30.0, float(rig.upTicks) / CarTraitRig.ROLL_TICKS)
	return side * 18.0 * share * clampf(speed / CarTraitRig.TIP_SPEED, 0.0, 1.0)

## Shift lights lit, of 10: all of them at the revs where a shift up earns its kick
static func shiftLit(car) -> int:
	if car.gear < 1 || car.velocity.length() < 5.0: return 0
	return clampi(int(car.revShare() / OverheadCarBody2D.SHIFT_KICK_FROM * 10.0), 0, 10)

static func shiftNow(car) -> bool:
	return car.gear >= 1 && car.gear < car.gears && car.revShare() >= OverheadCarBody2D.SHIFT_KICK_FROM

#the shift lights' flash; steady with Reduce Flashing
static func flashOn() -> bool:
	return Settings.get_value("access/reduce_flashing") || Time.get_ticks_msec() % 160 < 90

## The racer's drift charge in tiers (0-3: a tier each, the third a Drift King's), or the supercar's downforce (0-1)
static func traitFill(car, speed: float) -> float:
	if car.tDriftKing:
		var marks := [0.0, float(OverheadCarBody2D.DRIFT_TIERS[0][0]), float(OverheadCarBody2D.DRIFT_TIERS[1][0]), float(OverheadCarBody2D.DRIFT_KING_TIER[0])]
		var filled := 0.0
		for i in 3: filled += clampf((car.driftCharge - marks[i]) / (marks[i + 1] - marks[i]), 0.0, 1.0)
		return filled
	if car.tDownforce: return smoothstep(OverheadCarBody2D.DOWNFORCE_FROM, OverheadCarBody2D.DOWNFORCE_FULL, speed)
	return 0.0

#---------- drawing ----------

func box(rect: Rect2, edge := 0.8) -> void:
	HudTheme.panel(self, rect, Color(skin.rim, edge), mini(skin.radius, 10), Color(skin.face, 0.94))

func led(pos: Vector2, value: String, fontSize: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	HudTheme.text(self, pos, value, fontSize, color, align, 0, HudTheme.OUTLINE, HudSkin.LED)

#a lamp with a word on it: lit in `color`, or a dim outline
func lamp(rect: Rect2, word: String, color: Color, lit: bool, filled := false) -> void:
	var shown := color if lit else Color(skin.muted, 0.3)
	if filled && lit: HudTheme.panel(self, rect, shown, 4, shown)
	else: HudTheme.panel(self, rect, shown, 4, Color(0, 0, 0, 0.35))
	var ink := Color(0.05, 0.05, 0.05) if filled && lit else shown
	HudTheme.text(self, rect.get_center() + Vector2(0, 4), word, 11, ink, HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, skin.body)

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var rig: CarTraitRig = car.traitRig
	match kind:
		&"beater": drawBeater(car)
		&"meter": if rig: drawMeter(rig)
		&"radar": drawRadar(car)
		&"defib": drawDefib(car)
		&"load": if rig: drawLoad(car, rig)
		&"bed": if rig: drawBed(rig)
		&"tilt": drawTilt(car)
		&"shift": drawShift(car)

#the sedan: an odometer that keeps counting, a check-engine lamp that comes on as the engine wears and Second Wind's lamp
func drawBeater(car) -> void:
	var s := skin
	s.write(self, Vector2(10, 14), "ODOMETER", 10, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0)
	var digits := str(ODO_START + int(odo / 1000.0)).pad_zeros(6).right(6)
	for i in 6:
		var cell := Rect2(8 + i * 24.0, 20, 22, 30)
		var tenths := i == 5
		draw_rect(cell, Color(0.91, 0.87, 0.78) if tenths else Color(0.1, 0.09, 0.08))
		draw_rect(cell, Color(0.23, 0.2, 0.18), false, 1.5)
		HudTheme.text(self, cell.get_center() + Vector2(0, 7), digits[i], 20, Color(0.1, 0.09, 0.08) if tenths else s.text, HORIZONTAL_ALIGNMENT_CENTER, 0)
	var worn: bool = car.condition.engine < HudDial.WORN
	lamp(Rect2(8, 62, 92, 26), "CHECK ENGINE", s.bad if worn else s.warn, car.condition.engine < HudDial.SCUFFED && (not worn || HudTheme.blinkOn()))
	if car.tSecondWind: lamp(Rect2(106, 62, 86, 26), "2ND WIND", s.ok, not car.secondWindUsed)

#the taxi: The Meter's fare so far, its rate, and the HIRED lamp while it runs
func drawMeter(rig: CarTraitRig) -> void:
	var s := skin
	var on := rig.meterTicks > 0
	box(Rect2(Vector2.ZERO, size))
	s.write(self, Vector2(12, 19), "FARE", 12, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0, s.body)
	lamp(Rect2(118, 6, 74, 17), "FOR HIRE", s.rim, not on, true)
	draw_rect(Rect2(8, 27, 184, 38), Color(0.11, 0.02, 0.012))
	led(Vector2(100, 59), "8888", 38, Color(0.23, 0.047, 0.03))
	led(Vector2(100, 59), str(mini(rig.meterFare, 9999)).pad_zeros(4), 38, Color(1.0, 0.23, 0.19))
	s.write(self, Vector2(12, 86), "RATE", 12, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0, s.body)
	led(Vector2(64, 87), "x%d" % rig.meterMult, 20, s.rim if on else Color(s.rim, 0.3))
	lamp(Rect2(118, 70, 74, 20), "HIRED", Color(1.0, 0.23, 0.19), on, true)

#the police car: a lightbar repeater, and a radar unit with the speed now and the run's fastest
func drawRadar(car) -> void:
	var s := skin
	var phase := lightbarPhase(car)
	box(Rect2(0, 0, size.x, 22))
	for i in 8:
		var group := 0 if i < 3 else 1 if i < 5 else 2
		var lit := phase == 0 || (phase > 0 && (Time.get_ticks_msec() % 160 < 80 if group == 1 else phase == group / 2 + 1))
		draw_rect(Rect2(6 + i * 23.7, 5, 21, 12), Color(LIGHTBAR[group], 1.0 if lit else 0.22 if phase < 0 else 0.12))
	box(Rect2(0, 28, size.x, 68))
	var speeds := [int(car.velocity.length() * HudDial.unitsPerPx()), int(fastest * HudDial.unitsPerPx())]
	for i in 2:
		var x := 52.0 + i * 96.0
		s.write(self, Vector2(x, 44), ["PATROL", "FASTEST"][i], 11, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0, s.body)
		draw_rect(Rect2(x - 44, 50, 88, 38), Color(0.08, 0.05, 0.0))
		led(Vector2(x + 26, 81), str(speeds[i]), 32, Color(1.0, 0.69, 0.0), HORIZONTAL_ALIGNMENT_RIGHT)

#the ambulance: the Defibrillator's one shock, ready or spent
func drawDefib(car) -> void:
	var s := skin
	var ready: bool = car.tDefib && not car.defibUsed
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(s.rim, 0.9), 10, Color(0.04, 0.05, 0.05, 0.94))
	draw_circle(Vector2(44, 48), 30, Color(0.933, 0.945, 0.918))
	draw_rect(Rect2(36, 26, 16, 44), s.bad)
	draw_rect(Rect2(22, 40, 44, 16), s.bad)
	HudTheme.text(self, Vector2(136, 28), "DEFIBRILLATOR", 12, Color(0.8, 0.82, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, s.body)
	HudTheme.text(self, Vector2(136, 62), "READY" if ready else "USED", 30, HudTheme.OK if ready else Color(0.4, 0.42, 0.41), HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, s.bold)
	HudTheme.bar(self, Rect2(88, 74, 96, 8), 1.0 if ready else 0.0, HudTheme.OK)

#the semi: how far the trailer is through restocking, and the gear in its own window with the gearbox's range
func drawLoad(car, rig: CarTraitRig) -> void:
	var s := skin
	var ready := rig.abilityReady()
	var full := ready >= 1.0
	var pivot := Vector2(62, 64)
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), s.rim, 10, Color(0.227, 0.145, 0.086, 0.96))
	HudTheme.panel(self, Rect2(8, 8, 108, 80), Color(s.rim, 0.5), 8, s.face)
	HudTheme.arc(self, pivot, 46, -70, 70, s.track, 9)
	HudTheme.arc(self, pivot, 46, -70, -70 + 140 * ready, s.accent if full else s.warn, 9)
	draw_line(pivot, HudTheme.polar(pivot, 40, -70 + 140 * ready), s.needle, 4, true)
	draw_circle(pivot, 6, s.rim)
	s.write(self, pivot + Vector2(-42, 12), "E", 12, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
	s.write(self, pivot + Vector2(42, 12), "F", 12, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
	s.write(self, Vector2(62, 84), "LOAD READY" if full else "LOAD %d%%" % int(ready * 100.0), 13, s.accent if full else s.warn, HORIZONTAL_ALIGNMENT_CENTER, 0)
	HudTheme.panel(self, Rect2(124, 8, 68, 50), Color(s.rim, 0.5), 8, s.face)
	var gearColor := HudDial.gearColor(car)
	s.write(self, Vector2(158, 48), HudDial.gearText(car), 38, s.accent if gearColor == HudTheme.GOLD else gearColor, HORIZONTAL_ALIGNMENT_CENTER, 6)
	var high: bool = car.gear > car.gears / 2
	lamp(Rect2(124, 64, 32, 24), "LO", s.warn, not high && car.gear >= 1)
	lamp(Rect2(160, 64, 32, 24), "HI", s.warn, high)

#the pickup: the bed from above with its crates and what they add to the payout, and a 4x4 lamp on rough ground
func drawBed(rig: CarTraitRig) -> void:
	var s := skin
	box(Rect2(Vector2.ZERO, size))
	s.write(self, Vector2(10, 21), "BED", 14, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0)
	s.write(self, Vector2(126, 22), "+%d%% PAY" % roundi(rig.bedCrates * CarTraitRig.BED_BONUS * 100.0), 16, s.accent if rig.bedCrates > 0 else Color(s.muted, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	HudTheme.panel(self, Rect2(6, 30, 122, 58), s.rim, 6, Color(0.05, 0.05, 0.03))
	for i in CarTraitRig.BED_MAX:
		var crate := Rect2(12 + i * 22.6, 38, 19, 42)
		if i < rig.bedCrates:
			draw_rect(crate, CRATE)
			draw_rect(crate, CRATE_EDGE, false, 2.0)
			draw_line(crate.position + Vector2(2, 2), crate.end - Vector2(2, 2), CRATE_EDGE, 2.0, true)
			draw_line(crate.position + Vector2(17, 2), crate.position + Vector2(2, 40), CRATE_EDGE, 2.0, true)
		else: draw_rect(crate, Color(s.rim, 0.45), false, 1.0)
	lamp(Rect2(138, 42, 54, 34), "4x4", s.warn, rough)

#the van: how far it leans, red once it is close to going over, and Cargo Bay's two gadgets
func drawTilt(car) -> void:
	var s := skin
	var pivot := Vector2(66, 86)
	var hot: bool = absf(lean) > 20.0 || car.twoWheels
	var color := s.bad if hot else s.text
	box(Rect2(0, 0, 132, size.y))
	drawBay(Rect2(140, 1, 58, 45), "1", car.heldItem, car.heldCharges)
	drawBay(Rect2(140, 50, 58, 45), "2", car.spareItem, car.spareCharges)
	HudTheme.arc(self, pivot, 68, -30, 30, s.track, 5)
	HudTheme.arc(self, pivot, 68, -30, -20, s.bad, 5)
	HudTheme.arc(self, pivot, 68, 20, 30, s.bad, 5)
	for d in range(-30, 31, 10): draw_line(HudTheme.polar(pivot, 60, d), HudTheme.polar(pivot, 72, d), s.text, 2.5 if d == 0 else 1.3, true)
	draw_line(Vector2(16, pivot.y), Vector2(116, pivot.y), s.rim, 1.5)
	s.write(self, Vector2(8, 16), "TILT", 11, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0, s.body)
	led(Vector2(126, 17), "%d°" % roundi(absf(lean)), 14, color, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_set_transform(pivot, deg_to_rad(lean))
	draw_rect(Rect2(-15, -44, 30, 36), color, false, 2.5)
	draw_rect(Rect2(-10, -39, 20, 11), Color(color, 0.35))
	draw_rect(Rect2(-17, -9, 8, 9), color)
	draw_rect(Rect2(9, -9, 8, 9), color)
	draw_set_transform(Vector2.ZERO)

#one of the van's two gadget bays: the gadget in it and its charges, or empty
func drawBay(rect: Rect2, number: String, id: String, charges: int) -> void:
	var s := skin
	var held := id != ""
	HudTheme.panel(self, rect, Pickups.rarityColor(Pickups.rarity(id)) if held else Color(s.rim, 0.6), 4, Color(s.face, 0.94))
	s.write(self, rect.position + Vector2(6, 14), number, 11, s.muted, HORIZONTAL_ALIGNMENT_LEFT, 0, s.body)
	if not held:
		s.write(self, rect.get_center() + Vector2(4, 5), "EMPTY", 11, Color(s.muted, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 0, s.body)
		return
	HudTheme.icon(self, Pickups.texture(id), rect.get_center() + Vector2(4, 0), 36.0)
	if charges > 1: s.write(self, rect.end - Vector2(6, 5), str(charges), 14, s.text, HORIZONTAL_ALIGNMENT_RIGHT, 4)

#the racer and the supercar: shift lights that fill through each gear and flash at the shift point, then the car's own trait
func drawShift(car) -> void:
	var s := skin
	var lit := shiftLit(car)
	var flash := shiftNow(car)
	HudTheme.panel(self, Rect2(0, 0, size.x, 26), Color(s.muted, 0.6), 13, Color(0.03, 0.03, 0.03, 0.94))
	for i in 10:
		var color: Color = HudTheme.OK if i < 4 else HudTheme.WARN if i < 7 else HudTheme.BAD
		if flash: color = Color.WHITE if flashOn() else Color(0.13, 0.13, 0.13)
		elif i >= lit: color = Color(0.13, 0.13, 0.13)
		draw_circle(Vector2(19 + i * 18.0, 13), 6.0, color)
	if not car.tDriftKing && not car.tDownforce: return
	box(Rect2(0, 34, size.x, 62), 0.5)
	var filled := traitFill(car, car.velocity.length())
	if car.tDriftKing:
		s.write(self, Vector2(100, 53), "DRIFT CHARGE", 9, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
		var tiers := [OverheadCarBody2D.DRIFT_TIERS[0][2], OverheadCarBody2D.DRIFT_TIERS[1][2], OverheadCarBody2D.DRIFT_KING_TIER[2]]
		for i in 3: HudTheme.bar(self, Rect2(10 + i * 61.0, 64, 57, 16), clampf(filled - i, 0.0, 1.0), tiers[i], s.track)
	else:
		s.write(self, Vector2(100, 53), "DOWNFORCE", 9, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
		HudTheme.bar(self, Rect2(10, 62, 180, 14), filled, s.accent, s.track)
		s.write(self, Vector2(100, 90), "GRIP +%d%%" % roundi(filled * (OverheadCarBody2D.DOWNFORCE_HIGH / OverheadCarBody2D.DOWNFORCE_LOW - 1.0) * 100.0), 8, s.muted, HORIZONTAL_ALIGNMENT_CENTER, 0)
