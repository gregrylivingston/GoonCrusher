class_name HudMirror extends Control

#The rear-view mirror at the top of the screen (docs/HUD.md, "The mirror"): its glass holds the mode and the run
#clock on the left (TopCenter: ModeLabel and Timer) and the mode's goal on the right (Objective), which it lays
#out and restyles but does not own. Its frame is the car's dashboard's (HudSkin.mirror): a plain mirror, the
#cab's with its license card, a camera screen... The semi has no mirror, so it gets a low console flush with the
#top edge. Dice (the luck stat, as pips: 18 is three sixes) and a clover (the clover stat, as its number) hang
#from the top of it, each die and the clover on its own string that runs down behind the frame. They are heavy:
#they swing slowly as the car turns, lift while it brakes or pulls away, and hop and jiggle on their strings when
#it hits something; their pickups fly to them. The frame is drawn once. What moves is on two child CanvasItems that redraw
#on change: `charms` behind the frame (a charm that swings high goes behind the mirror) and `front` over it.

const SIZE := Vector2(540, 92)
const STALK := 14.0          #the mirror hangs this far under the top edge
const CONSOLE := 62.0        #the semi's console is this tall, with no stalk
const CLOCK_WIDTH := 170.0   #the left of the glass, for the clock; the goal takes the rest
const GOAL_WIDTH := 340.0
const DICE_SHOWN := 3        #dice at most: 18 pips; more luck than that is a number under them
const DIE := 24.0
const CLOVER_SCALE := 1.4    #the clover's size, against the 15 px number it was drawn around
#the charms, each on its own string from the top of the frame: [the angle it rests at (radians off plumb, left is
#negative), how much of its string shows under the frame, its swing's period in seconds, its bounce's period].
#Three dice, then the clover. No two share a period, so they drift apart as they swing and land out of step, and
#they rest fanned out so each can be seen.
const CHARMS := [[-0.06, 30.0, 1.15, 0.3], [-0.27, 50.0, 1.6, 0.38], [-0.5, 38.0, 1.35, 0.33], [0.27, 42.0, 1.8, 0.42]]
const CLOVER := 3            #its place in CHARMS
const LEAN := 0.26           #radians a hard turn swings them
const DAMPING := 1.1         #how fast a swing dies down
const KICK := 2.6            #radians a second a charm jumps when its stat rises
#the bounce: a charm rides up its string (`drops`, px, up is negative) and falls back until the string snaps taut
const LIFT := 14.0           #px a charm rides up under a full dip or squat...
const LIFT_ACCEL := 1100.0   #...which is this many px/s² along the car (CarJuice.PITCH_ACCEL)
const LIFT_MAX := 34.0       #px: the highest a hop goes
const ACCEL_EASE := 10.0     #per second the acceleration reading follows the car
const BOUNCE_DAMP := 3.2     #how fast a bounce dies down in the air
const REBOUND := 0.5         #share of its speed a charm keeps when its string snaps taut
const REBOUND_MIN := 25.0    #px/s: slower than this, it stays down
const JOLT_MIN := 60.0       #px/s the car's velocity changes in one frame before it counts as a jolt
const JOLT_MAX := 700.0
const JOLT_HOP := 0.75       #px/s up the string per px/s of jolt
const JOLT_SWING := 0.004    #radians a second sideways per px/s of jolt
const TILT := 0.6            #share of its swing a charm turns with its string
const TILT_SPEED := 0.05     #radians it turns per radian a second it swings
const GLASS := Color(0.07, 0.09, 0.1, 0.93)
const LEAF := Color(0.25, 0.68, 0.35)
const PIPS := [[], [Vector2.ZERO], [Vector2(-1, -1), Vector2(1, 1)], [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)], [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
	[Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]]

var skin: HudSkin = HudSkin.named(&"house")
var charms := Control.new() #behind the frame
var front := Control.new()  #over it
var markers := {}
var set := false
var angles: Array[float] = [] #each charm's angle off plumb
var speeds: Array[float] = []
var drops: Array[float] = []  #each charm's place along its string: 0 hanging, negative riding up
var dropSpeeds: Array[float] = []
var prevVel := Vector2.INF    #the car's velocity last frame
var accel := 0.0              #px/s² along the car, smoothed
var lastLuck := -1
var lastClover := -1
var shownKey := []
var shownFront := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	charms.mouse_filter = MOUSE_FILTER_IGNORE
	charms.show_behind_parent = true
	add_child(charms)
	charms.draw.connect(drawCharms)
	front.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(front)
	front.draw.connect(drawFront)
	for group in ["luckui", "cloverui"]: markers[group] = HudTheme.marker(self, group, Vector2.ZERO)
	Settings.changed.connect(onSettingChanged)
	apply.call_deferred() #once the clock and the goal are in the tree beside it

func onSettingChanged(key: String, _value) -> void:
	if key == "access/classic_dash": apply()

func isConsole() -> bool:
	return skin.mirror == &"console"

## The mirror's frame, in its own coordinates
func body() -> Rect2:
	return Rect2(0, 0, SIZE.x, CONSOLE) if isConsole() else Rect2(Vector2(0, STALK), SIZE)

func glass() -> Rect2:
	return body().grow(-6.0)

func corner() -> int:
	return skin.corner()

func frameColor() -> Color:
	return skin.frameColor()

func glassColor() -> Color:
	if skin.light: return HudDial.SCREEN
	if skin.style == HudSkin.Style.BAR || isConsole(): return Color(skin.face, 0.96)
	return GLASS

#where the charms' strings are tied: the top of the frame
func hook() -> Vector2:
	return Vector2(size.x * 0.5, body().position.y + 2.0)

#where charm `i`'s string ends: swinging, or (`resting`) hanging still
func charmPoint(i: int, resting := false) -> Vector2:
	var still := resting || angles.is_empty()
	var angle: float = CHARMS[i][0] if still else angles[i]
	return hook() + Vector2(sin(angle), cos(angle)) * (body().size.y + CHARMS[i][1] + (0.0 if still else drops[i]))

#how far charm `i` is turned on its string: it follows its swing, and lags when it is thrown
func charmTilt(i: int) -> float:
	if angles.is_empty(): return 0.0
	return -(angles[i] - CHARMS[i][0]) * TILT - speeds[i] * TILT_SPEED

## Dice shown for a luck stat: a die for every six, DICE_SHOWN at most
static func diceFor(luck: int) -> int:
	return clampi(ceili(luck / 6.0), 1, DICE_SHOWN)

#the dashboard's mirror: its frame, and the clock and the goal laid out on its glass and dressed to match
func apply() -> void:
	skin = HudSkin.current()
	var middle := body().get_center().y
	var top: Control = get_parent().get_node_or_null("TopCenter")
	if top:
		var compact := isConsole() #no room for the mode's name over the clock
		top.offset_left = -SIZE.x * 0.5 + 8.0
		top.offset_right = top.offset_left + CLOCK_WIDTH
		top.offset_top = middle - (48.0 if compact else 41.0)
		top.offset_bottom = top.offset_top + 80.0
		var timer: Label = top.get_node_or_null("Timer")
		var mode: Label = top.get_node_or_null("ModeLabel")
		for label in [timer, mode]:
			if label == null: continue
			label.offset_left = 0.0
			label.offset_right = CLOCK_WIDTH
		if mode:
			mode.visible = not compact
			mode.add_theme_color_override("font_color", skin.muted if not skin.light else Color(0.6, 0.85, 0.7))
		if timer:
			var screen := skin.style == HudSkin.Style.BAR
			timer.add_theme_font_override("font", HudSkin.LED if skin.light else skin.bold)
			timer.add_theme_font_size_override("font_size", 27 if screen else 44 if skin.light else 42)
			timer.add_theme_color_override("font_color", HudTheme.OK if skin.light else skin.text if screen else skin.accent)
			timer.add_theme_color_override("font_outline_color", HudTheme.DEEP if skin.id == &"house" || skin.id == &"beater" else HudTheme.OUTLINE)
			timer.add_theme_constant_override("outline_size", 0 if skin.light else 12 if skin.accent == HudTheme.GOLD else 8)
			timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var goal: Control = get_parent().get_node_or_null("Objective")
	if goal:
		goal.offset_left = SIZE.x * 0.5 - 14.0 - GOAL_WIDTH
		goal.offset_right = goal.offset_left + GOAL_WIDTH
		goal.offset_top = middle - 21.0
		goal.offset_bottom = middle + 21.0
		goal.set("framed", false) #the glass is its panel
		goal.queue_redraw()
	markers.luckui.position = charmPoint(0, true)
	markers.cloverui.position = charmPoint(CLOVER, true)
	queue_redraw()
	charms.queue_redraw()
	front.queue_redraw()

func _process(delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	if not set:
		set = true
		apply()
	swingCharms(car, delta)
	var key := [car.luck, car.clover]
	for angle in angles: key.push_back(snappedf(angle, 0.004)) #the strings are long: a small angle is a pixel
	for drop in drops: key.push_back(snappedf(drop, 0.5))
	if key != shownKey:
		shownKey = key
		charms.queue_redraw()
	var frontKey := [snappedf(hurry(), 0.1), HudDial.glassStage(car)]
	if skin.mirror == &"lights": frontKey.push_back(HudInstrument.lightbarPhase(car))
	if skin.mirror == &"screen": frontKey.push_back(HudTheme.blinkOn())
	if frontKey != shownFront:
		shownFront = frontKey
		front.queue_redraw()

#each charm is its own pendulum: pulled toward its rest (plus the car's turn), on its own period, dying down slowly.
#A stat that rises kicks its charm, and the car's own acceleration lifts and jolts them. With Reduce Motion they
#hang still.
func swingCharms(car, delta: float) -> void:
	if angles.is_empty(): restCharms()
	var kickDice: bool = lastLuck >= 0 && car.luck > lastLuck
	var kickClover: bool = lastClover >= 0 && car.clover > lastClover
	lastLuck = car.luck
	lastClover = car.clover
	var change: Vector2 = Vector2.ZERO if prevVel == Vector2.INF else (car.velocity - prevVel).rotated(-car.rotation) #in car space: x forward
	prevVel = car.velocity
	if Settings.reduce_motion() || delta <= 0.0:
		restCharms()
		return
	accel = lerpf(accel, change.x / delta, 1.0 - exp(-ACCEL_EASE * delta))
	jolt(change)
	for i in CHARMS.size():
		if (kickClover if i == CLOVER else kickDice): speeds[i] += KICK * (1.0 if i % 2 == 0 else -1.0)
	stepCharms(clampf(-car.spinRate * 0.25, -LEAN, LEAN), accel, delta)

func restCharms() -> void:
	angles.resize(CHARMS.size())
	speeds.resize(CHARMS.size())
	drops.resize(CHARMS.size())
	dropSpeeds.resize(CHARMS.size())
	accel = 0.0
	for i in CHARMS.size():
		angles[i] = CHARMS[i][0]
		speeds[i] = 0.0
		drops[i] = 0.0
		dropSpeeds[i] = 0.0

## A sudden change in the car's velocity (`change`, px/s in car space: a crash, a wall, a hard stop) throws the
## charms up their strings and knocks them sideways, each a little differently so they jiggle out of step.
func jolt(change: Vector2) -> void:
	if angles.is_empty(): restCharms()
	var hit := minf(change.length(), JOLT_MAX) - JOLT_MIN
	if hit <= 0.0: return
	var side := clampf(change.y, -JOLT_MAX, JOLT_MAX)
	for i in CHARMS.size():
		var own := 0.7 + 0.15 * i
		dropSpeeds[i] -= hit * JOLT_HOP * own
		speeds[i] += (-side * own + hit * 0.6 * (1.0 if i % 2 == 0 else -1.0)) * JOLT_SWING

## One frame of the charms: `lean` is the angle the car's turn holds them at, `along` its acceleration (px/s²)
func stepCharms(lean: float, along: float, delta: float) -> void:
	if angles.is_empty(): restCharms()
	var lift := -minf(absf(along) / LIFT_ACCEL, 1.0) * LIFT
	var steps := maxi(1, ceili(delta * 120.0)) #small steps keep a long frame from flinging them
	var dt := delta / steps
	for i in CHARMS.size():
		var pull: float = pow(TAU / CHARMS[i][2], 2.0)
		var spring: float = pow(TAU / CHARMS[i][3], 2.0)
		for step in steps:
			speeds[i] += (-pull * (angles[i] - CHARMS[i][0] - lean) - DAMPING * speeds[i]) * dt
			angles[i] = clampf(angles[i] + speeds[i] * dt, -1.45, 1.45)
			dropSpeeds[i] += (-spring * (drops[i] - lift) - BOUNCE_DAMP * dropSpeeds[i]) * dt
			drops[i] += dropSpeeds[i] * dt
			if drops[i] > 0.0: #the string snaps taut: it bounces
				drops[i] = 0.0
				dropSpeeds[i] = -dropSpeeds[i] * REBOUND if dropSpeeds[i] > REBOUND_MIN else 0.0
			elif drops[i] < -LIFT_MAX:
				drops[i] = -LIFT_MAX
				dropSpeeds[i] = maxf(dropSpeeds[i], 0.0)

## 0 to 1: the frame's red pulse in the last seconds of a clock that loses the run when it runs out (the station
## pointer's rule, HudChance.HURRY_SECONDS)
static func hurry() -> float:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.seconds <= 0.0 || level.seconds > HudChance.HURRY_SECONDS: return 0.0
	var mode := Modes.running()
	if mode == Root.gameModes.GOONPOCALYPSE || Level.timeUpCondition(mode) != Root.endCondition.NOTIME: return 0.0
	return 1.0 if Settings.get_value("access/reduce_flashing") else 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)

#---------- the frame ----------

func _draw() -> void:
	var s := skin
	var b := body()
	var g := glass()
	var turn := corner()
	if not isConsole(): draw_rect(Rect2(size.x * 0.5 - 8.0, 0, 16, STALK + 4.0), frameColor())
	HudTheme.panel(self, b, Color(s.rim, 0.9), turn, frameColor())
	HudTheme.panel(self, g, Color(s.rim, 0.55), maxi(2, turn - 5), glassColor())
	if isConsole(): #wood grain, and a chrome lip under the top edge
		for i in 3: draw_line(Vector2(b.position.x + 10, b.position.y + 2.0 + i * 1.6), Vector2(b.end.x - 10, b.position.y + 2.0 + i * 1.6), Color(0.3, 0.196, 0.125), 1.0)
	elif s.style != HudSkin.Style.BAR: #a glint across the glass
		for band in [[0.12, 0.1], [0.27, 0.035]]:
			var from: float = g.position.x + g.size.x * band[0]
			var wide: float = g.size.x * band[1]
			draw_colored_polygon(PackedVector2Array([Vector2(from + 34, g.position.y + 2), Vector2(from + 34 + wide, g.position.y + 2), Vector2(from + wide, g.end.y - 2), Vector2(from, g.end.y - 2)]), Color(1, 1, 1, 0.05))
	draw_line(Vector2(8.0 + CLOCK_WIDTH + 4.0, g.position.y + 12), Vector2(8.0 + CLOCK_WIDTH + 4.0, g.end.y - 12), Color(s.rim, 0.4), 1.0)
	match s.mirror:
		&"checker": #a checker band along the bottom of the glass, and the driver's license hanging off the end
			var x := g.position.x + 10.0
			while x < g.end.x - 14.0:
				draw_rect(Rect2(x, g.end.y - 7, 8, 4), s.rim)
				x += 16.0
			var card := Rect2(b.end.x - 60, b.end.y + 8, 44, 30)
			draw_line(Vector2(card.get_center().x, b.end.y - 2), Vector2(card.get_center().x, card.position.y), s.muted, 1.2, true)
			draw_rect(card, Color(0.945, 0.9, 0.78))
			draw_rect(card, Color(0.07, 0.07, 0.07), false, 1.5)
			draw_rect(Rect2(card.position + Vector2(4, 5), Vector2(13, 16)), Color(0.54, 0.48, 0.35))
			for i in 3: draw_line(card.position + Vector2(21, 8 + i * 6), card.position + Vector2(39 - i * 4, 8 + i * 6), Color(0.33, 0.33, 0.33), 2.0)
		&"clinic": #a red cross on the corner
			var at := Vector2(b.end.x - 4, b.position.y + 5)
			draw_circle(at, 13, Color(0.933, 0.945, 0.918))
			draw_arc(at, 13, 0.0, TAU, 24, s.bad, 1.5, true)
			draw_rect(Rect2(at - Vector2(3, 9), Vector2(6, 18)), s.bad)
			draw_rect(Rect2(at - Vector2(9, 3), Vector2(18, 6)), s.bad)
		&"keys":
			var at := Vector2(b.position.x + 46, b.end.y - 2)
			draw_line(at, at + Vector2(0, 12), s.muted, 1.2, true)
			draw_arc(at + Vector2(0, 19), 7, 0.0, TAU, 20, Color(0.79, 0.8, 0.815), 2.0, true)
			draw_rect(Rect2(at + Vector2(-9, 25), Vector2(5, 17)), Color(0.79, 0.8, 0.815))
			draw_rect(Rect2(at + Vector2(3, 25), Vector2(5, 13)), Color(0.66, 0.66, 0.66))
		&"convex": #a round blind-spot mirror stuck on the corner
			var at := Vector2(b.end.x - 4, b.end.y - 4)
			draw_circle(at, 15, Color(0.22, 0.27, 0.29))
			draw_arc(at, 15, 0.0, TAU, 24, s.muted, 2.0, true)
			draw_circle(at + Vector2(-5, -5), 4.5, Color(1, 1, 1, 0.18))

#---------- what moves over the frame: the hurry pulse, the lights ----------

func drawFront() -> void:
	var car = Root.playerCar
	var b := body()
	var pulse := hurry()
	if pulse > 0.0: HudTheme.panel(front, b, Color(HudTheme.BAD, pulse), corner(), Color(HudTheme.BAD, 0.08 * pulse))
	if not is_instance_valid(car): return
	var stage := HudDial.glassStage(car)
	if stage >= 2: #the glass cracks once the hull is badly hurt (the dials' crack first), and further when it is nearly gone
		var at := Vector2(glass().end.x - 64, glass().position.y + 2)
		front.draw_polyline(PackedVector2Array([at, at + Vector2(14, 16), at + Vector2(7, 26), at + Vector2(27, 40)]), Color(1, 1, 1, 0.42), 1.3, true)
		front.draw_line(at + Vector2(7, 26), at + Vector2(-8, 33), Color(1, 1, 1, 0.3), 1.0, true)
		if stage >= 3:
			front.draw_polyline(PackedVector2Array([at + Vector2(14, 16), at + Vector2(34, 12), at + Vector2(46, 24)]), Color(1, 1, 1, 0.3), 1.3, true)
			front.draw_line(at, at + Vector2(-16, 14), Color(1, 1, 1, 0.3), 1.0, true)
	if skin.mirror == &"lights": #a light strip under the frame, in step with the car's lightbar at night
		var phase := HudInstrument.lightbarPhase(car)
		for i in 8:
			var group := 0 if i < 3 else 1 if i < 5 else 2
			var lit := phase == 0 || (phase > 0 && (Time.get_ticks_msec() % 160 < 80 if group == 1 else phase == group / 2 + 1))
			var x := b.position.x + 40.0 + i * 58.0 + (26.0 if i > 3 else 0.0)
			front.draw_rect(Rect2(x, b.end.y - 3, 44, 5), Color(HudInstrument.LIGHTBAR[group], 1.0 if lit else 0.3 if phase < 0 else 0.14))
	if skin.mirror == &"screen": #a rear camera: recording
		var at := Vector2(glass().end.x - 44.0, glass().position.y + 11.0)
		if HudTheme.blinkOn(): front.draw_circle(at, 3.5, HudTheme.BAD)
		HudTheme.text(front, at + Vector2(8, 4), "REC", 9, HudTheme.BAD, HORIZONTAL_ALIGNMENT_LEFT, 0, HudTheme.OUTLINE, skin.body)

#---------- what moves behind it: the dice and the clover ----------

func drawCharms() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	#the dice: the luck stat in pips, a die for every six, each on its own string
	var origin := hook()
	var luck: int = maxi(car.luck, 1)
	var count := diceFor(luck)
	var lowest := origin
	var ink := Color(0.1, 0.09, 0.08)
	for i in range(count - 1, -1, -1): #the nearest die last, on top
		var face := clampi(luck - i * 6, 1, 6)
		var at := charmPoint(i)
		var die := Rect2(-DIE * 0.5, 0, DIE, DIE)
		charms.draw_line(origin, at, skin.muted, 1.6, true)
		charms.draw_set_transform(at, charmTilt(i))
		HudTheme.panel(charms, die, ink, 5, Color(0.98, 0.95, 0.88))
		for pip in PIPS[face]: charms.draw_circle(die.get_center() + pip * DIE * 0.27, DIE * 0.1, ink)
		charms.draw_set_transform(Vector2.ZERO)
		if at.y > lowest.y: lowest = at
	if luck > DICE_SHOWN * 6: HudTheme.text(charms, lowest + Vector2(0, DIE + 16.0), str(luck), 15, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 5)
	#the clover: the clover stat, as the number on it
	var clover := charmPoint(CLOVER)
	var k := CLOVER_SCALE
	var heart := Vector2(0, 12) * k
	charms.draw_line(origin, clover, skin.muted, 1.6, true)
	charms.draw_set_transform(clover, charmTilt(CLOVER))
	charms.draw_line(heart, heart + Vector2(5, 17) * k, LEAF.darkened(0.45), 2.5 * k, true)
	for leaf in [Vector2(-6.5, -6.5), Vector2(6.5, -6.5), Vector2(-6.5, 6.5), Vector2(6.5, 6.5)]:
		charms.draw_circle(heart + leaf * k, 8.0 * k, LEAF.darkened(0.45))
		charms.draw_circle(heart + leaf * k, 6.8 * k, LEAF)
	HudTheme.text(charms, heart + Vector2(0, 5.5 * k), str(car.clover), int(15 * k), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5)
	charms.draw_set_transform(Vector2.ZERO)
