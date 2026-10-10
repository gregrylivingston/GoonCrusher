extends "res://scripts/ai/briefs/lap_brief.gd"

#Cone Course: gates, a slalom and a handbrake box on a lot of cones. A knocked cone takes a second off the
#clock (Level.coneKnocked), so to a plan it costs that and as much again (plans touch more cones than they predict), not the passing touch a cone is
#anywhere else. The gates are tight: the handbrake is weighed for smaller turns than usual.

const CONE_SECONDS := 2.0

func tuning() -> Dictionary:
	return {"handbrakeTurn": 0.8, "handbrakeFrom": 260.0}

func knockCost() -> float:
	return CONE_SECONDS
