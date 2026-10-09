class_name CarHandling extends RefCounted

#How a car's stats become its handling (docs/CAR_ART.md, "Handling"). One shared instance, `tune`, holds
#the numbers, so the dev console's `handling` command can change them live for every car at once, and
#the AI driver's predictions follow (integrate() and the controller read the same instance).
#
#Stats go through dim() first: diminishing returns, so upgrades and pickups sharpen a car without
#erasing its character. Weight (CarInfo.weight, 0-100, never upgraded) is the car's character: heavy
#cars turn in slower, slide wider, brake longer, bounce less off walls and take longer to get going.
#
#Everything here is read only and allocation-free: integrate() calls it every tick, and the AI driver
#calls integrate() thousands of times a tick.

static var tune := CarHandling.new()

const STAT_KNEE := 60.0 #dim(): a stat of 60 gets half of what an endless one would

#--- turning ---
var yawLow := 1.7            #rad/s the car turns at most with steering 0...
var yawHigh := 3.2           #...and with an endless steering stat
var yawLight := 1.15          #the yaw ceiling's weight multiplier at weight 0...
var yawHeavy := 0.8          #...and at weight 100
var yawTaperFrom := 650.0    #px/s: above this the ceiling eases down...
var yawTaperTo := 1700.0     #...to yawTaper of itself at this speed, so top speed isn't twitchy
var yawTaper := 0.8
var wheelLow := 34.0         #degrees of full lock at steering 0 (sets the turn at walking pace)...
var wheelHigh := 44.0        #...and with an endless steering stat

#--- the wheel (playerCarController.steerToward) ---
var steerTimeSlow := 0.20    #seconds from centre to full lock at steering 0...
var steerTimeFast := 0.06    #...and with an endless steering stat
var steerLight := 0.85       #the time's weight multiplier at weight 0...
var steerHeavy := 1.3        #...and at weight 100
var steerReturn := 2.5       #letting go or counter-steering moves the wheel this many times faster

#--- grip: the share of the gap between travel and nose closed per tick ---
var gripSlowLow := 0.6       #below gripBlendFrom px/s, at traction 0...
var gripSlowHigh := 0.9      #...and endless traction
var gripFastLow := 0.10      #above gripBlendTo px/s, at traction 0...
var gripFastHigh := 0.30     #...and endless traction
var gripBlendFrom := 60.0
var gripBlendTo := 260.0
var gripLight := 1.15        #grip's weight multiplier at weight 0...
var gripHeavy := 0.8         #...and at weight 100: heavy cars carry their momentum wider
var turnScrub := 0.08        #speed lost per radian the travel is swung round (tyres scrubbing)
var thrustSteerCut := 0.12   #share of the engine's push lost at full lock

#--- longitudinal ---
var brakeLow := 650.0        #px/s² of braking at traction 0...
var brakeHigh := 1600.0      #...and endless traction
var brakeLight := 1.1        #the brake's weight multiplier at weight 0...
var brakeHeavy := 0.8        #...and at weight 100
var inertiaLight := 1.1      #how quickly speed changes (engine, drag, friction) at weight 0...
var inertiaHeavy := 0.85     #...and at weight 100 (the top speed is the same; getting there isn't)
var pickupLow := 0.8         #how quickly speed changes at a standstill (all cars)...
var pickupHigh := 0.3        #...falling to this at pickupTo px/s and above, so the last stretch to top speed takes a while.
var pickupTo := 1100.0       #It scales the net change (engine against drag and friction), so the top speed stays put
var reverseBase := 250.0     #px/s top speed in reverse, plus...
var reversePerEngine := 6.0  #...this per dim(engine)

#--- walls (OverheadCarBody2D.collideWithFixedObject) ---
var bounceLight := 0.35      #share of the speed into a wall given back at weight 0...
var bounceHeavy := 0.12      #...and at weight 100
var bounceMinSpeed := 150.0  #px/s into the wall before it bounces at all
var deflect := 0.25          #share of the angle to the wall's line the nose turns each contact tick...
var deflectMaxAngle := 55.0  #...when it meets the wall within this many degrees of glancing
var scrapeKeep := 0.995      #share of speed kept per tick sliding along a wall

#--- a trailer (CarTrailer: the semi) ---
var trailerGrip := 0.35      #share of the way the trailer's turn rate goes to the no-slide rate per tick (times the ground's grip)
var trailerJackknife := 80.0 #degrees the trailer can fold against the tractor...
var trailerFoldDrag := 0.03  #...where it drags this share of the tractor's speed off per tick

#--- camera ---
var lookAhead := 0.3         #seconds of travel the camera leads the car by...
var lookAheadMax := 450.0    #...up to this many px
var lookAheadRate := 3.0     #how quickly it catches up (1/s)

## a stat with diminishing returns: about the stat while small, never more than STAT_KNEE
static func dim(stat: float) -> float:
	var s := maxf(stat, 0.0)
	return s * STAT_KNEE / (s + STAT_KNEE)

## 0 to 1: the share of what an endless stat would give
static func share(stat: float) -> float:
	return dim(stat) / STAT_KNEE

static func weightShare(weight: float) -> float:
	return clampf(weight / 100.0, 0.0, 1.0)

## rad/s: the fastest this car turns at `speed`, before the wheel's lock limits it at walking pace
func yawAt(speed: float, steerStat: float, w: float) -> float:
	var ceiling := lerpf(yawLow, yawHigh, share(steerStat)) * lerpf(yawLight, yawHeavy, w)
	return ceiling * lerpf(1.0, yawTaper, smoothstep(yawTaperFrom, yawTaperTo, speed))

## radians: the full lock
func wheelMax(steerStat: float) -> float:
	return deg_to_rad(lerpf(wheelLow, wheelHigh, share(steerStat)))

## radians: the wheel angle at full input. The bicycle model turns at speed x sin(angle) / wheelBase, so
## this is the angle that turns at yawAt, or the full lock when that isn't enough (slow)
func wheelAngle(speed: float, steerStat: float, w: float, wheelBase: float) -> float:
	var lock := wheelMax(steerStat)
	if speed < 1.0: return lock
	var s := yawAt(speed, steerStat, w) * wheelBase / speed
	return minf(lock, asin(s)) if s < 1.0 else lock

## how far the wheel turns per physics tick toward full lock
func steerRate(steerStat: float, w: float) -> float:
	var seconds := lerpf(steerTimeSlow, steerTimeFast, sqrt(share(steerStat))) * lerpf(steerLight, steerHeavy, w)
	return 1.0 / (seconds * Engine.physics_ticks_per_second)

## the share of the slip closed this tick, at `speed`
func grip(speed: float, tractionStat: float, w: float) -> float:
	var t := share(tractionStat)
	var g := lerpf(lerpf(gripSlowLow, gripSlowHigh, t), lerpf(gripFastLow, gripFastHigh, t), smoothstep(gripBlendFrom, gripBlendTo, speed))
	return g * lerpf(gripLight, gripHeavy, w)

## px/s² of braking, before the ground's brake multiplier
func brakeDecel(tractionStat: float, w: float) -> float:
	return lerpf(brakeLow, brakeHigh, share(tractionStat)) * lerpf(brakeLight, brakeHeavy, w)

func inertia(w: float) -> float:
	return lerpf(inertiaLight, inertiaHeavy, w)

## The share of the net speed change a car gets at `speed` (pickupLow to pickupHigh, eased): the push fades
## as the car nears its top speed without moving it
func pickup(speed: float) -> float:
	var t := clampf(speed / pickupTo, 0.0, 1.0)
	return lerpf(pickupLow, pickupHigh, t * t)

func reverseTop(engineStat: float) -> float:
	return reverseBase + reversePerEngine * dim(engineStat)

func bounce(w: float) -> float:
	return lerpf(bounceLight, bounceHeavy, w)

#--- the dev console (`handling`) ---

## the tunable names, in order
func names() -> Array:
	var out := []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE && p.type == TYPE_FLOAT: out.push_back(p.name)
	return out

static func reset() -> void:
	tune = CarHandling.new()
