class_name ModeBrief extends RefCounted

#What a mode asks of an AI driver (docs/AI_DRIVER.md, "Mode briefs"): its objective, what it punishes and
#which of the driver's habits fit. AIDriver holds one for the mode being played (Level.runMode, so a variant
#has its own: Flat Out is not Sprint here) and asks it instead of matching on the mode. This base is a mode
#with no rules of its own: roam, crush, collect. The briefs in scripts/ai/briefs/ extend it, and
#ModeBriefs.forMode picks one. A brief reads the driver (`d`) and the level; it holds no keys.

var mode: int = 0  #Root.gameModes: the mode played
var d: AIDriver

#what this mode changes in the driver's tuning (AIProfiles.build lays it over the car's and the personality's)
func tuning() -> Dictionary:
	return {}

#The mode's own goal as {"kind", "pos", "value", "key"}, or {} to roam. A course with no station (a loop,
#Cone Course) sends any car to its next gate.
func objective() -> Dictionary:
	return d.gateObjective()

#the clock is the opponent and the station the goal: detours are budgeted and goons are worth less
func isRace() -> bool:
	return false

#how the tank is rationed: &"clock" (it must last the countdown), &"race" (it must cover the route) or
#&"open" (saved only once it runs low)
func fuelPlan() -> StringName:
	return &"open"

#below this much health the car stops hunting goons and steers around them
func healthReserve() -> float:
	return d.p.reserveBase + 15.0

#what a goon is worth as a goal here, from its usual `value`; 0 leaves it alone
func goonWorth(_goon: Node, value: float) -> float:
	return value

#seconds a knocked cone costs a plan (Cone Course takes a second off the clock for each)
func knockCost() -> float:
	return d.p.smashCost

#plans brake above this speed (Flat Out's stop box); INF for no limit
func brakeAbove() -> float:
	return INF

#the sweeps leave other cars out, so the driver steers into them (Demolition Derby; Pursuit's hunter)
func ramsCars() -> bool:
	return false

#the mode is scored by sliding: handbrake plans are always weighed (Drift Trial)
func drifts() -> bool:
	return false

#a reason of the mode's own to light the Boost slot this tick
func wantsBoost() -> bool:
	return false
