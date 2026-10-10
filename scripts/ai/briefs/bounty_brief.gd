extends ModeBrief

#Bounty Hunt: marked goons, one at a time, each on its own clock. Out to the mark; close up, the mark is a
#goon worth MARK_VALUE times a plain one, so the usual goon rules (its crush speed, its armor) take over.

const MARK_VALUE := 6.0

func objective() -> Dictionary:
	var hunt = Root.levelRoot.get("bounty")
	var at: Vector2 = hunt.markPosition() if hunt else Vector2.INF
	if at != Vector2.INF && d.car.global_position.distance_to(at) > AIDriver.GOAL_RADIUS.patrol: return {"kind":"patrol", "pos":at, "value":60.0, "key":"mark"}
	return super()

func goonWorth(goon: Node, value: float) -> float:
	return value * MARK_VALUE if goon.has_meta(&"bounty") else value
