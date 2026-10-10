extends AIDriver

#Kim's driver (the racer: Drift King, Featherweight, six gears). The car is built round the handbrake: a
#looser rear, a wider catch and a third boost tier, so this driver pulls it for smaller turns than the rest.
#It is light and fragile at speed, so it keeps more health in hand.

func tuning() -> Dictionary:
	return {"handbrakeTurn": 0.8, "reserveBase": 30.0}

func personalities() -> Dictionary:
	return {
		#slides everything for the boost
		"showoff": {"driftReward": 0.6, "handbrakeTurn": 0.6},
		#grips and brakes: the handbrake only for a hairpin
		"lineholder": {"handbrakeTurn": 1.4},
	}
