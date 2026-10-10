extends ModeBrief

#Drift Trial: a score from held handbrake slides (TrialScore: speed a tick, doubled and tripled as the
#drift charge passes its tiers), against the clock. Sliding is the objective, so handbrake plans are always
#weighed and every second of slide takes driftReward off a plan; where it slides hardly matters, so it
#roams the open ground (or the course's gates if it has them).

func tuning() -> Dictionary:
	return {"driftReward": 3.0, "handbrakeFrom": 220.0, "roamMinPx": 2500.0}

func drifts() -> bool:
	return true

func healthReserve() -> float:
	return d.p.reserveBase
