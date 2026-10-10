class_name AIProfiles extends RefCounted

#The AI driver's tuning (docs/AI_DRIVER.md, "Who is driving"). Every number the driver weighs is a key of
#DEFAULTS; a driver's own set is built in layers, each listing only what it changes (build()):
#  DEFAULTS -> the house style (HOUSE) -> the car's driver (its tuning()) -> a personality of that car
#  -> the mode's brief (ModeBrief.tuning) -> a skill (SKILLS) -> overrides from the spec
#A spec string names the personality, the skill and any overrides:
#  "auto"                      the car's first personality, driven by an ace (BEST)
#  "alt"                       its second personality
#  "showoff@rookie"            a personality by name (the racer's), at a skill
#  "@regular"                  the first personality at a skill
#  "crusher"                   a house style by name instead of HOUSE, with no personality on top
#  "auto+horizonTicks=120"     any of them with a value changed ("+key=value", through str_to_var)
#A personality another car owns falls back to the car's first, so one spec can drive a whole field.
#Specs are compared with the playtest harness (--profiles=a,b) or scripts/ai/tournament.py.

const DEFAULTS = {
	#planning
	"scanTicks": 8,            #plans are re-chosen every this many ticks (7.5 times a second)
	"horizonTicks": 45,        #each plan is simulated tick by tick this far ahead (60 ticks = 1 s)...
	"maxHorizonTicks": 45,     #...or, when this is larger, far enough to cover lookaheadPx at the current speed (costly)
	"lookaheadPx": 1600.0,     #past the plan, a car-wide straight sweep along its end heading reaches this far from
	"probeSeconds": 1.5,       #the start, or this many seconds of travel at the end speed if further (a stock
	                           #sedan at 744 px/s needs about 800 px to brake or swerve round a rock)
	"probeCost": 4.0,          #cost of that sweep finding a wall, scaled by how close it is
	"hitCost": 6.0,            #cost of hitting a rock or wall at 400 px/s within the plan (grows with speed)
	"smashCost": 0.25,         #cost of driving through a breakable prop (fence, hedge...) fast enough to smash it
	"smashMargin": 1.15,       #a breakable counts as passable only at this multiple of its smash speed or more
	"turnCost": 0.6,           #seconds per radian the car still has to turn at the end of a plan
	"samePlanBonus": 0.08,     #keeps the choice from flickering between near-equal plans
	#forward over backward
	"reverseCost": 0.5,        #seconds of cost per second a plan spends rolling backwards: forward preferred, not required
	"reverseIfBlocked": 1.0,   #when slow, reverse plans are also weighed if every forward plan hits within this many seconds
	"reverseWhenStopped": true, #a nearly stopped car always weighs backing up too (three-point turns)
	"recoverForward": true,    #a stuck car first tries to turn out forwards, and reverses only if that has no room
	#goons
	"crushReward": 1.5,        #seconds taken off a plan for each goon it would meet with the bumper at speed
	"goonValue": 14.0,         #value of a goon as a goal (a fuel can at half a tank is about 44)
	"goonPackBonus": 4.0,      #added per other goon within 350 px of it (up to 6)
	"goonTargetPx": 3000.0,    #goons further than this are left to come to the car
	"slowGoonCost": 1.5,       #per second below crush speed, per goon within 350 px
	"flankCost": 1.0,          #per second a goon spends beside the car, in lunge range but off the bumper
	"reserveBase": 10.0,       #below this much health (plus reservePerSecond x Countdown seconds left)...
	"reservePerSecond": 0.04,  #...the car stops hunting goons and steers around them
	#goals
	"commitBonus": 1.3,        #the current goal's utility is multiplied by this
	"pickupScale": 1.0,        #multiplies every pickup's value
	"amongRocksSeconds": 4.0,  #extra time charged for a pickup with rocks around it
	"amongRocksMinValue": 20.0, #pickups among rocks worth less than this are left alone
	"roamMinPx": 6000.0,       #roam points nearer than this are disliked (long straight runs)
	#speed
	"ecoMinSpeed": 250.0,      #fuel saving never slows the car below this
	"fuelHope": 1.15,          #fuel saving assumes this much more fuel turns up on the way
	"carefulSpeed": 260.0,     #speed when going in for a pickup among rocks
	"stationSpeed": 450.0,     #speed within 2500 px of the station's driveway
	#deep water (WorldHooks): the car takes about 30 health a second with its centre over it (never planned through),
	#and the wading band and shallows before it are slow and slippery
	"waterLookSeconds": 0.9,   #deep water this many seconds ahead along a plan's path costs...
	"waterNearCost": 8.0,      #...this much per second of the plan, more the closer and faster
	"waterSpeed": 340.0,       #the throttle lifts above this speed while deep water is ahead within 1.5x waterLookSeconds
	"waterTargetPx": 400.0,    #pickups and roam points this close to deep water are skipped (unless on a bridge)
	"waterGoonPx": 350.0,      #goons this close to deep water aren't hunted (they drown on their own)
	#races (Sprint, Marathon): the clock is the opponent (career playtests found the driver hunting goons
	#2-9 times as often as it headed for the station, and losing by 1,400-2,700 px)
	"raceGoonScale": 0.4,      #goons are worth this share of their value as a race goal
	"raceDetourShare": 0.3,    #all detours on one leg together may use this share of the leg's starting spare time
	#Defense: the base is the objective
	"defenseRingPx": 2500.0,   #goons further than this from the base are left alone
	"defenseThreat": 3.0,      #a goon at the base's walls is worth this many times more than one at defenseRingPx
	#the handbrake (Space): a powerslide for a turn too tight to steer, and what Drift Trial scores
	"handbrakeFrom": 320.0,    #handbrake plans are weighed above this speed...
	"handbrakeTurn": 1.1,      #...when the aim is at least this many radians off the nose (0: never pulls it)
	"driftReward": 0.0,        #seconds taken off a plan per second it holds a slide (the boost on release; Drift Trial)
	#the gearbox (the racer, the supercar, the semi)
	"shiftByHand": true,       #works the lever itself on a geared car: a shift near the redline earns the kick
	"shiftAt": 0.9,            #shifts up at this share of the gear's band (the kick wants 0.8 or more)
	"shiftSlop": 0.0,          #each shift's point is off by up to this much: early ones cut the push, late ones sit on the limiter
	#the buttons
	"hornGoons": 2,            #honks at this many goons ahead that it is too slow to crush (0: never)
	"nitroStraightPx": 1400.0, #with no goons about, Nitro is lit with this much straight, clear road to the aim
	#the car's own quirks (each car's driver, scene/car/<car>/<car>_driver.gd)
	"trailerCost": 3.0,        #cost of a plan that drags the trailer through a rock or wall
	"tipCost": 5.0,            #the van: cost of a plan that keeps it up on two wheels until it rolls
	#human imperfection (SKILLS); 0 drives as well as the driver can
	"reactionTicks": 0,        #the keys reach the car this many ticks after the driver chooses them
	"planSlop": 0.0,           #up to this many seconds of noise on each plan's cost: close calls go either way, some wrong
}

#the spec the game and the harnesses use when none is named: the car's own driver, first personality, an ace
const BEST := "auto"
#the style every car's driver and personality is built on (the tournament winner of the single-driver days)
const HOUSE := "cautious"

#How well the keys are worked, apart from what the driver wants: the Goon Cup's rivals get one by tier
#(Rivals.SKILL), the career personas by who they are (Personas).
const SKILLS = {
	"ace": {},
	"regular": {"reactionTicks": 5, "planSlop": 0.3, "shiftSlop": 0.12},
	"rookie": {"reactionTicks": 12, "planSlop": 0.8, "lookaheadPx": 1000.0, "probeSeconds": 1.0, "shiftAt": 0.75, "shiftSlop": 0.35},
}

#every car that has a driver of its own, scene/car/<id>/<id>_driver.gd
const CARS = ["sedan", "van", "taxi", "pickup", "police", "ambulance", "racer", "supercar", "semi"]

#house styles: whole-driver tunings by name, from before each car had a driver
const PROFILES = {
	"default": {},
	#the driver as first tuned (2026-10-05), before notes on going forward, looking further and crushing
	"v1": {"scanTicks": 6, "horizonTicks": 60, "lookaheadPx": 0.0, "maxHorizonTicks": 60, "probeSeconds": 0.0, "probeCost": 0.6,
		"reverseCost": 0.0, "reverseIfBlocked": 0.4, "reverseWhenStopped": false, "recoverForward": false,
		"crushReward": 0.0, "goonValue": 12.0, "goonTargetPx": 2500.0},
	#plays for crushes: goons are worth more, meeting them pays, flanks matter less
	"crusher": {"crushReward": 3.0, "goonValue": 24.0, "goonPackBonus": 6.0, "goonTargetPx": 3500.0, "flankCost": 0.5,
		"reserveBase": 5.0, "reservePerSecond": 0.02},
	#looks two seconds ahead and further past the plan
	"farsight": {"horizonTicks": 120, "lookaheadPx": 2400.0, "maxHorizonTicks": 180, "probeSeconds": 2.0},
	#keeps health: walls and flanks cost more, and it stops hunting sooner
	"cautious": {"hitCost": 10.0, "flankCost": 3.0, "slowGoonCost": 3.0, "crushReward": 0.5, "reserveBase": 25.0,
		"reservePerSecond": 0.08},
	#pickups first: fuel, health and prizes are worth twice as much
	"collector": {"pickupScale": 2.0, "goonValue": 10.0, "crushReward": 0.5},
	#a new player: reacts 0.2 s late, misjudges close calls, looks less far ahead and chases goons
	"rookie": {"reactionTicks": 12, "planSlop": 0.8, "lookaheadPx": 1000.0, "probeSeconds": 1.0, "goonValue": 18.0,
		"reserveBase": 5.0, "reservePerSecond": 0.02},
}

#the driver script for a car: its own (AIDriver's child), or AIDriver for a car that has none
static func driverScript(carId: String) -> Script:
	var path := "res://scene/car/%s/%s_driver.gd" % [carId, carId]
	return load(path) if carId != "" && ResourceLoader.exists(path) else load("res://scripts/ai/ai_driver.gd")

#a car's personalities (name -> overlay; the first is its default), read from its driver script
static func personalitiesOf(carId: String) -> Dictionary:
	var driver = driverScript(carId).new()
	var out: Dictionary = driver.personalities()
	driver.free()
	return out

#"showoff@rookie+hitCost=4" -> {"name": "showoff", "skill": "rookie", "overrides": ["hitCost=4"]}
static func parse(spec: String) -> Dictionary:
	var parts := spec.strip_edges().split("+")
	var head := parts[0].strip_edges()
	if head.contains(":"): head = head.get_slice(":", 1) #"racer:showoff": the car is whichever it is attached to
	var overrides: Array = []
	for i in range(1, parts.size()): overrides.push_back(parts[i])
	return {"name": head.get_slice("@", 0), "skill": head.get_slice("@", 1) if head.contains("@") else "ace", "overrides": overrides}

#"" when a spec is sound, else what is wrong with it (the harnesses check before a run starts)
static func problemWith(spec: String) -> String:
	var parts := parse(spec)
	if not SKILLS.has(parts.skill): return "AI skill '%s' doesn't exist (have %s)" % [parts.skill, ", ".join(SKILLS.keys())]
	for pair in parts.overrides:
		var kv = pair.split("=", true, 1)
		if kv.size() != 2 || not DEFAULTS.has(kv[0]): return "AI override '%s' is not key=value with a known key" % pair
	if parts.name in ["", "auto", "alt"] || PROFILES.has(parts.name): return ""
	for carId in CARS:
		if personalitiesOf(carId).has(parts.name): return ""
	return "AI spec '%s' names no personality or style" % parts.name

#A driver's whole parameter set: the layers in the order of the header. `personalities` and `carTuning` are the
#car's driver's own, `briefTuning` the mode's.
static func build(spec: String, personalities: Dictionary = {}, carTuning: Dictionary = {}, briefTuning: Dictionary = {}) -> Dictionary:
	var parts := parse(spec)
	var params = DEFAULTS.duplicate()
	var style := HOUSE
	var personality := {}
	if PROFILES.has(parts.name): style = parts.name
	else: personality = personalities.get(personalityName(spec, personalities), {})
	params.merge(PROFILES[style], true)
	params.merge(carTuning, true)
	params.merge(personality, true)
	params.merge(briefTuning, true)
	params.merge(SKILLS.get(parts.skill, {}), true)
	for pair in parts.overrides:
		var kv = pair.split("=", true, 1)
		if kv.size() != 2 || not DEFAULTS.has(kv[0]):
			push_error("AI override '%s' is not key=value with a known key" % pair)
			continue
		params[kv[0]] = str_to_var(kv[1])
	return params

#the personality a spec picks from a car's set ("" for a house style or a car with none), for logs and name plates
static func personalityName(spec: String, personalities: Dictionary) -> String:
	var parts := parse(spec)
	var names: Array = personalities.keys()
	if PROFILES.has(parts.name) || names.is_empty(): return ""
	if personalities.has(parts.name): return parts.name
	return names[1] if parts.name == "alt" && names.size() > 1 else names[0]

#a house style alone ("name" or "name+key=value+..."), on DEFAULTS; unknown names and keys are errors
static func resolve(spec: String) -> Dictionary:
	var params = DEFAULTS.duplicate()
	if spec.strip_edges() == "": return params
	var parts = spec.split("+")
	var name = parts[0].strip_edges()
	if not PROFILES.has(name):
		push_error("AI profile '%s' doesn't exist (have %s)" % [name, ", ".join(PROFILES.keys())])
		return params
	params.merge(PROFILES[name], true)
	for i in range(1, parts.size()):
		var pair = parts[i].split("=", true, 1)
		if pair.size() != 2 || not DEFAULTS.has(pair[0]):
			push_error("AI profile override '%s' is not key=value with a known key" % parts[i])
			continue
		params[pair[0]] = str_to_var(pair[1])
	return params
