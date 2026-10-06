class_name AIProfiles extends RefCounted

#The AI driver's tuning, as named profiles (docs/AI_DRIVER.md, "Profiles and tournaments").
#A profile lists only what it changes from DEFAULTS. A spec string can add overrides on top:
#  "crusher"                         a named profile
#  "crusher+horizonTicks=120"        that profile with one value changed
#  "default+crushReward=3+flankCost=0.5"
#Values go through str_to_var, so numbers and true/false work as written. Profiles are compared
#with the playtest harness (--profiles=a,b) or scripts/ai/tournament.py.

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
}

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
}

#the full parameter set for a spec ("name" or "name+key=value+..."); unknown names and keys are errors
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
