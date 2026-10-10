extends ModeBrief

#Demolition Derby: the last car running inside a painted line. A hit hurts by closing speed and by where it
#lands: a car struck on its nose takes 30%, on its flank or tail all of it (OverheadCarBody2D.bumpShare).
#So the driver goes for the car whose side or back it can reach soonest, aims a little ahead of it, and
#never leaves the line (12 health a second out there).

const SIDE_BONUS := 0.45 #a target tail-on to us counts as this much nearer (side-on: half of it)

func ramsCars() -> bool:
	return true

func objective() -> Dictionary:
	var arena = Root.levelRoot.get("derby")
	if arena == null: return super()
	var car := d.car
	var prey: Node2D = null
	var best := INF
	for other in car.get_tree().get_nodes_in_group(&"cars"):
		if other == car || other.isDestroyed || not arena.inside(other.global_position): continue
		var to: Vector2 = other.global_position - car.global_position
		#1 when it faces us (its nose: the worst place to hit it), 0 side-on, -1 tail-on
		var facing: float = -Vector2.from_angle(other.rotation).dot(to.normalized())
		var score: float = to.length() * (1.0 - SIDE_BONUS * (1.0 - facing) * 0.5)
		if score < best:
			best = score
			prey = other
	if prey == null: return {"kind":"gate", "pos":arena.center, "value":200.0, "key":"ram"}
	var at: Vector2 = d.leadPoint(prey)
	if not arena.inside(at): at = prey.global_position
	return {"kind":"gate", "pos":at, "value":200.0, "key":"ram"}

func healthReserve() -> float:
	return 0.0
