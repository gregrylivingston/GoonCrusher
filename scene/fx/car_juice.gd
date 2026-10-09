class_name CarJuice extends Node2D
## Driving juice (package 13, docs/CAR_ART.md "Driving feel"): how the car itself feels, apart from crushes
## (CrushFeel). The player's car owns one. It is show only: it reads the car each physics tick after the car
## has moved and never writes its velocity, input or stats, so handling and the AI's predictions are unchanged.
##   - D-1 lean: the body leans out of a turn (it slides out and narrows, the shadow goes the other way) and
##     tips onto two wheels in a hard one, with squealing smoke off the outer tyres and a bounce when it lands.
##   - D-2 weight: the nose dips under braking and the tail squats on launch and boost (both read from the
##     car's measured acceleration), bumps on Hop and Jump Jets landings, wall hits and ground changes, and a
##     camera jolt on wall hits scaled by speed (through CrushFeel's kick and trauma).
##   - D-3 ground: dust, spray and clods per surface
##     (World.surfaceAt), tyre smoke in slides, wall-scrape sparks, and a flame and glow when a drift boost fires;
##     in water a bow wave off the nose, and over deep water the car settles in, tinted, with bubbles (water()).
##   - D-4 sound: engine pitch through the gears (the controller's gear rule), tyre squeal from slip and a
##     backfire pop on lift-off.
## Reduce Motion drops the jolts and bounces and calms the lean; Car Shake Off drops the bounces;
## Driving Effects (gfx/driving_fx) sizes the particles. Particles are pooled, drawn by two nodes.

#--- body (D-1, D-2) ---
const ACCEL_FILTER := 0.3        #share of each tick's acceleration reading kept (a low-pass)
const LEAN_CURVE := 1.8         #lean = (sideways acceleration / the car's grip limit) ^ this: ordinary turns
                                 #only settle the suspension (half the limit leans 0.29), hard ones lean right over
const PITCH_ACCEL := 1100.0      #px/s² along the car for a full dip or squat
const ROLL_PX := 4.5             #body offset (car px) at a full lean
const ROLL_SQUASH := 0.06        #width the body loses at a full lean (the roof turns away)
const PITCH_PX := 4.0            #body offset at a full dip or squat
const SHADOW_PX := 3.0           #the shadow moves the other way
const LEAN_SPRING := 220.0       #per s²: the body's spring...
const LEAN_DAMP := 13.0          #...and damper, under-damped so a lean that lets go overshoots once
const TWO_WHEEL_ON := 0.9        #share of the car's grip limit that tips it onto two wheels...
const TWO_WHEEL_OFF := 0.65      #...and the share that drops it back
const TWO_WHEEL_TICKS := 24      #held this long first (0.4 s): only a long, flat-out turn tips it
const TWO_WHEEL_SPEED := 0.6     #share of the car's top speed it must be doing
const TWO_WHEEL_LEAN := 1.6      #lean while up
const HEIGHT_SPRING := 300.0     #the bounce: height in units, about -2 (squashed) to 2 (lifted)
const HEIGHT_DAMP := 9.0
const HEIGHT_SCALE := 0.035      #body scale per unit of height
const HEIGHT_SHADOW := Vector2(4, 6) #world px the shadow falls away per unit of height (light from the top left)
const BUMP_LAND := -1.6          #height kicks: two wheels coming down, a Hop, Jump Jets...
const BUMP_HOP := -2.2
const BUMP_JETS := -3.0
const BUMP_GROUND := 0.9         #...a change between road and rough ground, at 600 px/s

#--- camera (D-2) ---
const WALL_KICK_PER_SPEED := 1.0 / 35.0 #world px of kick per px/s of square-on impact speed
const WALL_KICK_MAX := 24.0
const WALL_TRAUMA_PER_SPEED := 1.0 / 2600.0
const WALL_TRAUMA_MAX := 0.4
const WALL_MIN_FORCE := 120.0    #px/s into the wall before a hit jolts anything
const BOOST_ZOOM := 0.02         #a drift boost pulls the zoom out this much per tier; updateCameraZoom eases it back

#--- sound (D-4) ---
const GEAR_SPEED := 300.0        #px/s per gear, the controller's rule for car.gear
const PITCH_IDLE := 0.85
const PITCH_RANGE := 0.85        #added from the bottom of a gear to its top
const PITCH_PER_GEAR := 0.12     #each higher gear starts a little higher (up to 4)
const PITCH_LOAD := 0.08         #throttle on
const PITCH_EASE := 7.0          #per second toward the target, so an upshift glides down
const ENGINE_COAST_DB := -5.0    #off the throttle
const SQUEAL_MIN_DB := -22.0
const SQUEAL_MAX_DB := -2.0
const BACKFIRE_SPEED := 250.0
const BACKFIRE_CHANCE := 0.55
const BACKFIRE_GAP := 0.8        #seconds between pops

#--- ground and sparks (D-3) ---
enum Kind { PUFF, BITS, SPRAY }
## Per surface name (World.TERRAIN): [colour, amount, kind]. Missing surfaces leave no trail.
const TRAILS := {
	"SAND": [Color(0.86, 0.76, 0.55, 0.5), 1.0, Kind.PUFF],
	"DIRT": [Color(0.6, 0.47, 0.32, 0.45), 0.8, Kind.PUFF],
	"WASH": [Color(0.8, 0.7, 0.55, 0.4), 0.7, Kind.PUFF],
	"SNOW": [Color(0.95, 0.97, 1.0, 0.7), 1.0, Kind.PUFF],
	"DEEPSNOW": [Color(0.95, 0.97, 1.0, 0.8), 1.4, Kind.PUFF],
	"MUD": [Color(0.33, 0.24, 0.14, 0.9), 0.8, Kind.BITS],
	"MUDPIT": [Color(0.3, 0.21, 0.12, 0.9), 1.2, Kind.BITS],
	"OIL": [Color(0.07, 0.07, 0.09, 0.85), 0.6, Kind.BITS],
	"GRASS": [Color(0.38, 0.58, 0.24, 0.8), 0.25, Kind.BITS],
	"MOSS": [Color(0.32, 0.5, 0.26, 0.8), 0.25, Kind.BITS],
	"ICE": [Color(0.85, 0.95, 1.0, 0.6), 0.3, Kind.BITS],
	"SHALLOWS": [Color(0.78, 0.9, 1.0, 0.75), 1.5, Kind.SPRAY],
	"WADE": [Color(0.8, 0.92, 1.0, 0.8), 2.4, Kind.SPRAY],
	"WATER": [Color(0.78, 0.9, 1.0, 0.85), 2.0, Kind.SPRAY],
}
#--- water (docs/CAR_ART.md, "Driving feel": Water) ---
const BOW_SPEED := 220.0         #px/s before wading depth or deep water throws a bow wave off the nose
const BOW_RATE := 0.9            #bow particles per front corner per tick at 700 px/s (times the trail rate)
const SINK_EASE := 2.5           #per second toward fully sunk (over deep water) or afloat
const SINK_SCALE := 0.1          #body scale lost fully sunk: it settles into the water
const SINK_PX := 5.0             #body offset fully sunk (down the screen, like the lean's shadow drop)
const SINK_TINT := Color(0.5, 0.64, 0.74) #body tint fully sunk: the water over it
const SINK_SHADOW := 0.85        #share of the shadow gone fully sunk
const BUBBLE_RATE := 0.6         #bubbles per tick fully sunk (times the trail rate)
const LAVA_SPRAY := Color(1.0, 0.55, 0.15, 0.9) #a lava landscape's deep "water" throws embers instead
const LAVA_TINT := Color(1.0, 0.55, 0.4)
const SMOKE := Color(0.82, 0.82, 0.84, 0.45) #tyre smoke in a slide or up on two wheels
const SPARK := Color(1.0, 0.75, 0.35)
const SLIDE_SMOKE_SLIP := 0.35   #rad of slip before the tyres smoke
const ROUGH_FRICTION := 0.25     #surfaces at least this draggy count as rough ground for bumps
const TRAIL_MIN_SPEED := 120.0
## Per Driving Effects level (Minimal, Reduced, Full): [dust pool, spark pool, trail rate]
const LEVELS := [[0, 12, 0.0], [48, 24, 0.5], [128, 48, 1.0]]
const FLAME_SECS := 0.45
const BACKFIRE_SECS := 0.12

var car
var body: Sprite2D
var shadow: Sprite2D
var bodyBase := Vector2.ZERO
var bodyScale := Vector2.ONE
var shadowBase := Vector2.ZERO
var rng := RandomNumberGenerator.new() #its own, so show-only rolls never move the game's random numbers

var prevVel := Vector2.ZERO
var accel := Vector2.ZERO        #smoothed, in car space (x forward, y to the right)
var lean := 0.0                  #+ = the body toward the car's right
var leanVel := 0.0
var pitch := 0.0                 #+ = the nose down (forward)
var pitchVel := 0.0
var height := 0.0
var heightVel := 0.0
var twoWheels := false
var twoWheelHeld := 0
var lastSurface := -1
var tick := 0
var top := 1200.0                #the car's top speed and grip limit (maxLateral), refreshed twice a second
var limit := 3000.0

var enginePitchNow := 1.0
var engineBaseDb := 0.0
var squealBaseDb := 0.0
var lastThrottle := 0.0
var lastGear := 1
var backfireCooldown := 0.0

var level: Array = LEVELS[2]
var motion := 1.0                #lean scale: Reduce Motion calms it
var bumps := true                #bounces and jolts: off with Reduce Motion or Car Shake Off
var flameLeft := 0.0
var flameColor := Color.WHITE
var flameTier := 0
var backfireLeft := 0.0

var dust: Particles
var sparks: Particles

var sink := 0.0                  #0 afloat to 1 sunk: deep water under the car (show only)
var wasDeep := false
var lava := false                #the level's deep water is lava (Landscape.waterLook)
var shadowAlpha := 1.0

static var trailBySurface := {}  #World surface index -> TRAILS entry, built once

func _ready() -> void:
	car = get_parent()
	body = car.get_node("sprite/body")
	shadow = car.get_node("sprite/shadow")
	bodyBase = body.position
	bodyScale = body.scale
	shadowBase = shadow.position
	shadowAlpha = shadow.self_modulate.a
	engineBaseDb = car.engineAudio.volume_db
	squealBaseDb = car.tiresAudio.volume_db
	prevVel = car.velocity
	if trailBySurface.is_empty():
		for i in World.count():
			var n: String = World.def(i).name
			if TRAILS.has(n): trailBySurface[i] = TRAILS[n]
	var glow := CanvasItemMaterial.new() #flames and sparks glow through the night
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = glow
	dust = Particles.new(false, 0)
	sparks = Particles.new(true, 2)
	sparks.material = glow
	for n in [dust, sparks]: add_child(n)
	var def := Levels.current()
	var land: Landscape = Landscapes.get_def(def.landscape) if def else null
	lava = land != null && land.waterLook == &"lava"
	readSettings()
	Settings.changed.connect(onSettingChanged)

func onSettingChanged(key: String, _value) -> void:
	if key in ["gfx/driving_fx", "access/reduce_motion", "access/car_shake"]: readSettings()

func readSettings() -> void:
	level = LEVELS[clampi(Settings.get_value("gfx/driving_fx"), 0, LEVELS.size() - 1)]
	var calm: bool = Settings.reduce_motion()
	motion = 0.4 if calm else 1.0
	bumps = not calm && Settings.get_value("access/car_shake")
	dust.resize(level[0])
	sparks.resize(level[1])

#--- each tick --------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if delta <= 0.0: return
	tick += 1
	var vel: Vector2 = car.velocity
	var speed := vel.length()
	var raw: Vector2 = ((vel - prevVel) / delta).rotated(-car.rotation)
	prevVel = vel
	accel = accel.lerp(raw, ACCEL_FILTER)
	var dead: bool = car.isDestroyed
	var airborne: bool = car.airborneTicks > 0
	var slip := slipAngle(vel, car.rotation)

	#D-1, D-2: lean and pitch spring toward the acceleration; two wheels in a hard turn
	if tick % 30 == 1:
		top = topSpeed()
		limit = maxLateral(top)
	var leanTo := 0.0 if dead || airborne else leanTarget(accel.y, limit)
	var pitchTo := 0.0 if dead || airborne else pitchTarget(accel.x)
	var step := [car.twoWheels, 0] if car.tTopHeavy else twoWheelStep(twoWheels, twoWheelHeld, absf(accel.y) / limit, speed / top)
	if twoWheels && not step[0]: landTwoWheels()
	twoWheels = step[0]
	twoWheelHeld = step[1]
	if twoWheels: leanTo = signf(leanTo) * TWO_WHEEL_LEAN
	var sprung := spring(lean, leanVel, leanTo * motion, LEAN_SPRING, LEAN_DAMP, delta)
	lean = sprung.x
	leanVel = sprung.y
	sprung = spring(pitch, pitchVel, pitchTo * motion, LEAN_SPRING, LEAN_DAMP, delta)
	pitch = sprung.x
	pitchVel = sprung.y
	sprung = spring(height, heightVel, 0.0, HEIGHT_SPRING, HEIGHT_DAMP, delta)
	height = sprung.x
	heightVel = sprung.y
	placeBody()

	#ground: a bump between road and rough ground, and the trail off the tyres
	var surface := World.surfaceAt(car.global_position)
	if surface != lastSurface && lastSurface != -1 && surface != World.UNKNOWN && lastSurface != World.UNKNOWN:
		if isRough(surface) != isRough(lastSurface) && speed > 200.0: bump(BUMP_GROUND * minf(speed / 600.0, 1.5))
		if trailKind(surface) == Kind.SPRAY && speed > 200.0: groundBurst(surface, 10)
	lastSurface = surface
	if not airborne && not dead: emitTrail(surface, speed, slip)
	water(surface, speed, airborne, delta)

	#D-4
	engineSound(speed, car._car_input.acceleration, vel.dot(Vector2.from_angle(car.rotation)) < 0.0 && speed > 5.0, delta)
	squealSound(dead || airborne || speed < 1.0, squeal(slip, speed, car._car_input.braking || car._car_input.handbrake, twoWheels), car.driftCharge)

	flameLeft = maxf(0.0, flameLeft - delta)
	backfireLeft = maxf(0.0, backfireLeft - delta)
	if flameLeft > 0.0 || backfireLeft > 0.0: queue_redraw()
	elif tick % 30 == 0: queue_redraw() #clears the last flame frame

## The body, its scale and the shadow from the lean, pitch and height (car space turned into the sprite's)
func placeBody() -> void:
	var sprite: Node2D = body.get_parent()
	var off := Vector2(pitch * PITCH_PX, lean * ROLL_PX)
	var down := (Vector2(0.0, SINK_PX * sink)).rotated(-car.rotation) #settling into deep water: down the screen
	body.position = bodyBase + off.rotated(-sprite.rotation) + down.rotated(-sprite.rotation)
	body.scale = bodyScale * Vector2(1.0 - ROLL_SQUASH * minf(absf(lean), 2.0), 1.0) * (1.0 + HEIGHT_SCALE * height) * (1.0 - SINK_SCALE * sink)
	var drop := (HEIGHT_SHADOW * maxf(height, 0.0)).rotated(-car.rotation) #the light doesn't turn with the car
	shadow.position = shadowBase + (-off * SHADOW_PX / ROLL_PX + drop).rotated(-sprite.rotation)

## Water, each tick (show only): a bow wave off the nose in wading depth and deep water at speed; over deep
## water the car settles in (sink: smaller, lower, tinted by the water over it, its shadow gone), bubbles and
## a waterline of foam round it, and a big splash going in (with a hiss and a thud)
func water(surface: int, speed: float, airborne: bool, delta: float) -> void:
	var deep := not airborne && surface != World.UNKNOWN && World.isLethal(surface)
	var was := sink
	sink = move_toward(sink, 1.0 if deep else 0.0, SINK_EASE * delta)
	if sink != was:
		body.modulate = Color.WHITE.lerp(LAVA_TINT if lava else SINK_TINT, sink)
		shadow.self_modulate.a = shadowAlpha * (1.0 - SINK_SHADOW * sink)
	if deep && not wasDeep:
		groundBurst(surface, int(clampf(speed / 30.0, 8.0, 30.0)))
		Audio.play(Transition.SOUNDS["hiss"], -8.0, 0.7)
		if speed > 300.0: Audio.play(Transition.SOUNDS["thud"], -6.0, 0.7)
		bump(-clampf(speed / 500.0, 0.4, 1.6))
	wasDeep = deep
	if level[0] == 0 || airborne: return
	var rate: float = level[2]
	var wet := deep || surface == Root.terrain.WADE
	if wet && speed > BOW_SPEED: bowWave(surface, speed, rate)
	if sink > 0.3 && rng.randf() < BUBBLE_RATE * rate * sink: bubble()

func bowWave(surface: int, speed: float, rate: float) -> void:
	var t := trailFor(surface)
	var fwd := Vector2.from_angle(car.rotation)
	var front: float = car.bodyRect.end.x
	for s in [-1.0, 1.0]:
		if rng.randf() >= BOW_RATE * rate * clampf(speed / 700.0, 0.3, 1.3): continue
		var corner: Vector2 = car.to_global(Vector2(front, s * car.bodyRect.size.y * 0.45))
		var side: Vector2 = fwd.orthogonal() * s
		dust.spawn(corner, (side * rng.randf_range(0.45, 0.8) + fwd * rng.randf_range(0.1, 0.35)) * speed * 0.6, rng.randf_range(0.3, 0.55), rng.randf_range(5.0, 8.0), t[0], Kind.SPRAY)

## A bubble or a fleck of foam on the waterline round the sunk car
func bubble() -> void:
	var r: Rect2 = car.bodyRect
	var local := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
	if rng.randf() < 0.5: local.y = r.position.y if local.y < r.get_center().y else r.end.y #on the flank: the waterline
	var at: Vector2 = car.to_global(local)
	var c := LAVA_SPRAY if lava else Color(0.88, 0.96, 1.0, 0.7)
	dust.spawn(at, car.velocity * 0.1 + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)), rng.randf_range(0.5, 0.9), rng.randf_range(3.0, 6.0), c, Kind.PUFF)

## A jolt of `amount` height units (negative squashes first, positive lifts first)
func bump(amount: float) -> void:
	if bumps: heightVel += amount * 12.0

func landTwoWheels() -> void:
	bump(BUMP_LAND)
	for tire in innerTires(): groundBurst(lastSurface, 3, tire.global_position)
	Audio.play(Transition.SOUNDS["thud"], -12.0, 1.3)

#--- static rules (tests) -------------------------------------------------------------------------

## The lean the body wants from sideways acceleration (car space, + to the right): away from the turn
## The lean the body wants from sideways acceleration (car space, + to the right), against the car's grip
## limit `limit` (maxLateral): away from the turn, slight until the turn gets near the limit
static func leanTarget(lateral: float, limit: float) -> float:
	return -signf(lateral) * pow(minf(absf(lateral) / maxf(limit, 1.0), 1.2), LEAN_CURVE)

## The pitch from acceleration along the car: braking dips the nose (+), launching squats the tail (-)
static func pitchTarget(forward: float) -> float:
	return clampf(-forward / PITCH_ACCEL, -1.3, 1.3)

## [up on two wheels, ticks the tip has been held] after one tick: `share` is the sideways acceleration as a
## share of the grip limit, `speedShare` the speed as a share of top speed
static func twoWheelStep(up: bool, held: int, share: float, speedShare: float) -> Array:
	if up: return [share > TWO_WHEEL_OFF && speedShare > TWO_WHEEL_SPEED * 0.7, 0]
	if share >= TWO_WHEEL_ON && speedShare >= TWO_WHEEL_SPEED:
		held += 1
		return [held >= TWO_WHEEL_TICKS, held]
	return [false, 0]

## One tick of a damped spring: Vector2(position, velocity)
static func spring(x: float, v: float, target: float, k: float, damp: float, delta: float) -> Vector2:
	v += ((target - x) * k - v * damp) * delta
	return Vector2(x + v * delta, v)

## The angle between the nose and the travel, folded so reversing straight back is 0
static func slipAngle(vel: Vector2, rotation: float) -> float:
	if vel.length_squared() < 1.0: return 0.0
	var a := absf(angle_difference(vel.angle(), rotation))
	return PI - a if a > PI / 2.0 else a

## The engine's pitch: it climbs through each gear and drops at the shift
static func enginePitch(speed: float, throttle: float, reverse: bool) -> float:
	var load := PITCH_LOAD * absf(throttle)
	if reverse: return PITCH_IDLE + PITCH_RANGE * clampf(speed / GEAR_SPEED, 0.0, 1.0) + load
	var gears := speed / GEAR_SPEED
	var g := floorf(gears)
	return PITCH_IDLE + PITCH_RANGE * (gears - g) + PITCH_PER_GEAR * minf(g, 4.0) + load

static func gearOf(speed: float) -> int:
	return int(speed / GEAR_SPEED) + 1

## How hard the tyres squeal, 0 to 1: slip at speed, a locked brake, or two wheels
static func squeal(slip: float, speed: float, braking: bool, onTwoWheels: bool) -> float:
	var s := clampf((slip - 0.12) / 0.5, 0.0, 1.0) * clampf((speed - 120.0) / 250.0, 0.0, 1.0)
	if braking && speed > 200.0: s = maxf(s, 0.2 + 0.4 * clampf((speed - 200.0) / 300.0, 0.0, 1.0))
	if onTwoWheels: s = maxf(s, 0.55)
	return s

static func isRough(surface: int) -> bool:
	return World.friction(surface) >= ROUGH_FRICTION

static func trailKind(surface: int) -> int:
	return trailBySurface[surface][2] if trailBySurface.has(surface) else -1

## The sideways acceleration the car can hold at top speed (its turn rate there): the most a turn can lean it
func maxLateral(topSpeed: float) -> float:
	return car.yawLimit(topSpeed) * topSpeed

## The car's top speed on grass (engine against drag), for the lean limit
func topSpeed() -> float:
	var force: float = (car.engine * car.conditionFactor("engine") + 14.0) * 10.0 * 2.2
	var d: float = car.drag
	if car.buffs.has("nitro"):
		force *= Pickups.DATA["nitro"]["thrust"]
		d *= Pickups.DATA["nitro"]["thrust"] / pow(Pickups.DATA["nitro"]["top"], 2.0)
	var f := World.GRASS_FRICTION
	return (-f + sqrt(f * f + 4.0 * d * force)) / (2.0 * d) if d > 0.0 else 2000.0

#--- sound ----------------------------------------------------------------------------------------

func engineSound(speed: float, throttle: float, reverse: bool, delta: float) -> void:
	var player: AudioStreamPlayer2D = car.engineAudio
	var target := enginePitch(speed, throttle, reverse)
	enginePitchNow = lerpf(enginePitchNow, target, 1.0 - exp(-PITCH_EASE * delta))
	player.pitch_scale = maxf(enginePitchNow, 0.1)
	player.volume_db = engineBaseDb + (0.0 if absf(throttle) > 0.1 else ENGINE_COAST_DB)
	var gear := gearOf(speed)
	if gear > lastGear && throttle > 0.5 && not reverse: pitchVel -= 0.35 * motion #the squat of a shift
	lastGear = gear
	backfireCooldown = maxf(0.0, backfireCooldown - delta)
	var lifted := lastThrottle > 0.5 && throttle <= 0.1
	lastThrottle = throttle
	if lifted && speed > BACKFIRE_SPEED && backfireCooldown == 0.0 && not car.isDestroyed && rng.randf() < BACKFIRE_CHANCE: backfire()

func backfire() -> void:
	backfireCooldown = BACKFIRE_GAP
	backfireLeft = BACKFIRE_SECS
	Audio.play(Transition.SOUNDS["pop"], -2.0, rng.randf_range(0.45, 0.6))
	var at: Vector2 = car.smoke.global_position
	var back := -Vector2.from_angle(car.rotation)
	for i in 3: sparks.spawn(at, back.rotated(rng.randf_range(-0.6, 0.6)) * rng.randf_range(250.0, 450.0) + car.velocity, 0.25, 2.0, SPARK)

func squealSound(silent: bool, amount: float, charge: int) -> void:
	var player: AudioStreamPlayer2D = car.tiresAudio
	if silent || amount < 0.05:
		if player.playing: player.stop()
		return
	player.volume_db = squealBaseDb + lerpf(SQUEAL_MIN_DB, SQUEAL_MAX_DB, amount)
	var tier: int = car.driftTier(charge) if charge > 0 else -1
	player.pitch_scale = 0.9 + 0.25 * amount + 0.1 * (tier + 1) #a charged slide sings higher
	if not player.playing: player.play()

#--- ground and sparks ----------------------------------------------------------------------------

func rearTires() -> Array:
	return car.tires.filter(func(t): return car.to_local(t.global_position).x < 0.0)

## The tyres on the inside of the lean: the ones that lift on two wheels
func innerTires() -> Array:
	return car.tires.filter(func(t): return car.to_local(t.global_position).y * lean < 0.0)

func emitTrail(surface: int, speed: float, slip: float) -> void:
	if level[0] == 0 || speed < TRAIL_MIN_SPEED: return
	var rate: float = level[2]
	var back := -Vector2.from_angle(car.rotation)
	if trailBySurface.has(surface):
		var t: Array = trailFor(surface)
		var chance: float = t[1] * rate * clampf(speed / 700.0, 0.2, 1.0) * (1.0 + 2.0 * slip)
		var tires: Array = car.tires if t[2] == Kind.SPRAY else rearTires()
		for tire in tires:
			if rng.randf() < chance * 0.5: groundParticle(t, tire.global_position, back, speed)
	elif (slip > SLIDE_SMOKE_SLIP && speed > 200.0) || twoWheels:
		var from: Array = car.tires.filter(func(t): return car.to_local(t.global_position).y * lean > 0.0) if twoWheels else rearTires()
		for tire in from:
			if rng.randf() < 0.35 * rate: dust.spawn(tire.global_position + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), car.velocity * 0.15 + back * 30.0, 0.9, 14.0, SMOKE, Kind.PUFF)

func groundParticle(t: Array, at: Vector2, back: Vector2, speed: float) -> void:
	var jitter := Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	match t[2]:
		Kind.PUFF: dust.spawn(at + jitter, car.velocity * 0.2 + back * 40.0 + jitter * 3.0, rng.randf_range(0.6, 1.1), rng.randf_range(10.0, 16.0), t[0], Kind.PUFF)
		Kind.BITS: dust.spawn(at + jitter, back.rotated(rng.randf_range(-0.5, 0.5)) * speed * rng.randf_range(0.25, 0.5) + car.velocity * 0.4, rng.randf_range(0.3, 0.5), rng.randf_range(2.5, 4.0), t[0], Kind.BITS)
		Kind.SPRAY:
			var side := Vector2.from_angle(car.rotation).orthogonal() * (1.0 if car.to_local(at).y > 0.0 else -1.0)
			dust.spawn(at + jitter, (side * rng.randf_range(0.3, 0.6) + back * 0.3) * speed + car.velocity * 0.3, rng.randf_range(0.35, 0.6), rng.randf_range(4.0, 7.0), t[0], Kind.SPRAY)

## The surface's trail entry, with embers for a lava landscape's deep "water"
func trailFor(surface: int) -> Array:
	if lava && World.isLethal(surface): return [LAVA_SPRAY, 1.0, Kind.SPRAY]
	return trailBySurface.get(surface, [SMOKE, 1.0, Kind.PUFF])

## A burst of the surface's trail (or tyre smoke on hard ground) at `at`, or under the car
func groundBurst(surface: int, count: int, at := Vector2.INF) -> void:
	if level[0] == 0: return
	if at == Vector2.INF: at = car.global_position
	var t: Array = trailFor(surface)
	for i in count: groundParticle(t, at, Vector2.RIGHT.rotated(rng.randf() * TAU), 300.0)

func sparkBurst(at: Vector2, dir: Vector2, count: int, color := SPARK, spread := 0.9, speed := 400.0) -> void:
	for i in count:
		sparks.spawn(at, dir.rotated(rng.randf_range(-spread, spread)) * speed * rng.randf_range(0.5, 1.2), rng.randf_range(0.15, 0.35), rng.randf_range(1.5, 3.0), color)

#--- hooks from the car and gadgets ---------------------------------------------------------------

## A tick of wall contact (OverheadCarBody2D.collideWithFixedObject): `hit` a fresh hit, else a scrape
func onWall(point: Vector2, normal: Vector2, moving: Vector2, hit: bool) -> void:
	var speed := moving.length()
	var along := (moving - normal * moving.dot(normal)).normalized()
	if not hit:
		if speed > 120.0 && tick % 2 == 0: sparkBurst(point, (along + normal * 0.4).normalized(), 2, SPARK, 0.35, speed * 0.8)
		return
	var force := absf(moving.dot(normal))
	if force < WALL_MIN_FORCE: return
	sparkBurst(point, (normal + along * 0.6).normalized(), int(clampf(force / 60.0, 3.0, 14.0)))
	bump(-clampf(force / 500.0, 0.3, 1.8))
	var feel: CrushFeel = car.crushFeel
	if is_instance_valid(feel) && bumps:
		feel.kick += -normal * minf(force * WALL_KICK_PER_SPEED, WALL_KICK_MAX)
		feel.addTrauma(minf(force * WALL_TRAUMA_PER_SPEED, WALL_TRAUMA_MAX))

## A drift boost fired (OverheadCarBody2D.tickDriftCharge): flame, glow, sparks and a zoom pull
func driftBoost(tier: int, color: Color) -> void:
	flameLeft = FLAME_SECS
	flameColor = color
	flameTier = tier
	var rear: Vector2 = car.to_global(Vector2(car.bodyRect.position.x, 0.0))
	sparkBurst(rear, -Vector2.from_angle(car.rotation), 8 + 6 * tier, color, 0.7, 500.0)
	if bumps && is_instance_valid(car.camera) && not Transition.instant(): car.camera.zoom *= 1.0 - BOOST_ZOOM * (tier + 1)
	queue_redraw()

## A Hop or Jump Jets came down (Gadgets.land)
func land(blast: bool) -> void:
	bump(BUMP_JETS if blast else BUMP_HOP)
	for tire in car.tires: groundBurst(lastSurface, 3, tire.global_position)
	Audio.play(Transition.SOUNDS["thud"], -4.0 if blast else -8.0, 0.8 if blast else 1.0)
	var feel: CrushFeel = car.crushFeel
	if is_instance_valid(feel) && bumps: feel.addTrauma(0.3 if blast else 0.12)

#--- drawing: the flame and backfire, in car space (additive) --------------------------------------

func _draw() -> void:
	var rearX: float = car.bodyRect.position.x
	if flameLeft > 0.0:
		var t := flameLeft / FLAME_SECS
		var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.05)
		var length := (70.0 + 40.0 * flameTier) * t * flick
		for y in [-18.0, 18.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(rearX, y - 11), Vector2(rearX - length, y), Vector2(rearX, y + 11)]), Color(flameColor, 0.9 * t))
			draw_colored_polygon(PackedVector2Array([Vector2(rearX, y - 5), Vector2(rearX - length * 0.55, y), Vector2(rearX, y + 5)]), Color(1, 1, 1, 0.8 * t))
		var r := 70.0 + 30.0 * flameTier
		draw_texture_rect(Particles.SOFT, Rect2(Vector2(rearX - r * 0.6, -r), Vector2(r, r) * 2.0), false, Color(flameColor, 0.55 * t))
	if backfireLeft > 0.0:
		var t := backfireLeft / BACKFIRE_SECS
		var at: Vector2 = to_local(car.smoke.global_position) + Vector2(-10, 0)
		draw_texture_rect(Particles.SOFT, Rect2(at - Vector2(28, 28), Vector2(56, 56)), false, Color(1.0, 0.6, 0.2, 0.9 * t))
		draw_circle(at, 8.0 * t, Color(1.0, 0.95, 0.7, t))

#--- pooled particles -----------------------------------------------------------------------------

## A ring of particles in world space, drawn by one node. Puffs grow and slow, bits and spray fly and
## fade, sparks (`streaks`) draw as short lines.
class Particles extends Node2D:
	static var SOFT := softDot() #white, fading to clear at the rim

	static func softDot() -> GradientTexture2D:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.6))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		return t
	var streaks := false
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var size := PackedFloat32Array()
	var col := PackedColorArray()
	var kind := PackedByteArray()
	var next := 0
	var alive := 0

	func _init(isStreaks: bool, z: int) -> void:
		streaks = isStreaks
		top_level = true
		z_as_relative = false
		z_index = z
		set_process(false)

	func resize(n: int) -> void:
		pos.resize(n)
		vel.resize(n)
		age.resize(n)
		life.resize(n)
		size.resize(n)
		col.resize(n)
		kind.resize(n)
		life.fill(0.0)
		age.fill(0.0)
		next = 0
		alive = 0
		queue_redraw()

	func spawn(at: Vector2, v: Vector2, seconds: float, s: float, c: Color, k := 0) -> void:
		var n := pos.size()
		if n == 0: return
		if life[next] <= 0.0: alive += 1
		pos[next] = at
		vel[next] = v
		age[next] = 0.0
		life[next] = seconds
		size[next] = s
		col[next] = c
		kind[next] = k
		next = (next + 1) % n
		set_process(true)

	func _process(delta: float) -> void:
		for i in pos.size():
			if life[i] <= 0.0: continue
			age[i] += delta
			if age[i] >= life[i]:
				life[i] = 0.0
				alive -= 1
				continue
			pos[i] += vel[i] * delta
			vel[i] *= 1.0 - minf((3.0 if kind[i] == CarJuice.Kind.PUFF else 1.5) * delta, 1.0)
		queue_redraw()
		if alive <= 0:
			alive = 0
			set_process(false)

	func _draw() -> void:
		for i in pos.size():
			if life[i] <= 0.0: continue
			var t := age[i] / life[i]
			var c := col[i]
			if streaks:
				c.a = 1.0 - t
				draw_line(pos[i], pos[i] - vel[i] * 0.03, c, size[i])
			elif kind[i] == CarJuice.Kind.PUFF:
				c.a *= (1.0 - t) * minf(t * 6.0, 1.0)
				var r := size[i] * (1.0 + 2.0 * t)
				draw_texture_rect(SOFT, Rect2(pos[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
			else:
				c.a *= 1.0 - t * t
				draw_circle(pos[i], size[i] * (1.0 - 0.4 * t), c)
