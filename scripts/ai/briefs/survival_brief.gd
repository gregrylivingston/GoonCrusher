extends ModeBrief

#Countdown and Blackout: still driving when the clock ends. The tank has to last the countdown, and health
#is a budget for the time left (every crush costs some), so the reserve shrinks as the clock runs down.
#Blackout is the same run with no daylight: the driver sees what the beams show (AIDriver.canSee).

func fuelPlan() -> StringName:
	return &"clock"

func healthReserve() -> float:
	return d.p.reserveBase + maxf(Root.levelRoot.seconds, 0.0) * d.p.reservePerSecond
