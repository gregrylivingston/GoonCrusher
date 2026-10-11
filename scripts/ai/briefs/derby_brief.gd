extends ModeBrief

#Demolition Derby: the last car running inside the stadium wall. A hit hurts by closing speed and by where it
#lands: a car struck on its nose takes 30%, on its flank or tail all of it (OverheadCarBody2D.bumpShare).
#So the driver goes for the car whose side or back it can reach soonest, aims a little ahead of it, and
#never aims outside the wall.
#Two cars that meet nose to nose push each other to a stop and would sit there, so a car that has been slow
#beside another for STALL_TICKS backs off to one side (the driver's escape: reversing allowed) and comes
#again with a run-up. A hit with no run-up does nothing, so prey nearer than RUN_UP counts as further off.

const SIDE_BONUS := 0.45 #a target tail-on to us counts as this much nearer (side-on: half of it)
const STALL_SPEED := 110.0 #px/s: slower than this beside another car is a stall
const STALL_RANGE := 340.0 #px between the two cars' centers
const STALL_TICKS := 35
const BACK_OFF := 850.0    #px behind the car it backs off to, and SIDE_STEP to one side
const SIDE_STEP := 500.0
const BACK_OFF_TICKS := 140
const RUN_UP := 500.0      #prey nearer than this, while we are slow, counts as RUN_UP further off

var stalledAt := -1 #the tick the car was first seen stalled against another; -1 when it isn't

func ramsCars() -> bool:
	return true

func objective() -> Dictionary:
	var arena = Root.levelRoot.get("derby")
	if arena == null: return super()
	var car := d.car
	if stalled(car):
		#back and to one side (each car has its own, so two that met head on part ways), kept inside the wall
		var side := 1.0 if car.get_instance_id() % 2 == 0 else -1.0
		var out: Vector2 = car.global_position - car.global_transform.x * BACK_OFF + car.global_transform.y * SIDE_STEP * side
		if out.distance_to(arena.center) > Derby.RADIUS - 400.0: out = arena.center + (out - arena.center).normalized() * (Derby.RADIUS - 400.0)
		d.escapePoint = out
		d.escapeUntil = d.tick + BACK_OFF_TICKS
		return {"kind":"escape", "pos":out, "value":1000.0, "key":"escape"}
	var slow: bool = car.velocity.length() < STALL_SPEED * 2.0
	var prey: Node2D = null
	var best := INF
	for other in car.get_tree().get_nodes_in_group(&"cars"):
		if other == car || other.isDestroyed || not arena.inside(other.global_position): continue
		var to: Vector2 = other.global_position - car.global_position
		#1 when it faces us (its nose: the worst place to hit it), 0 side-on, -1 tail-on
		var facing: float = -Vector2.from_angle(other.rotation).dot(to.normalized())
		var score: float = to.length() * (1.0 - SIDE_BONUS * (1.0 - facing) * 0.5)
		if slow && to.length() < RUN_UP: score += RUN_UP
		if score < best:
			best = score
			prey = other
	if prey == null: return {"kind":"gate", "pos":arena.center, "value":200.0, "key":"ram"}
	var at: Vector2 = d.leadPoint(prey)
	if not arena.inside(at): at = prey.global_position
	return {"kind":"gate", "pos":at, "value":200.0, "key":"ram"}

#has the car sat slow beside another for STALL_TICKS? (it counts by the driver's clock, however often it is asked)
func stalled(car: Node2D) -> bool:
	var beside := false
	if car.velocity.length() < STALL_SPEED:
		for other in car.get_tree().get_nodes_in_group(&"cars"):
			if other != car && not other.isDestroyed && other.global_position.distance_to(car.global_position) < STALL_RANGE: beside = true
	if not beside:
		stalledAt = -1
		return false
	if stalledAt < 0: stalledAt = d.tick
	if d.tick - stalledAt < STALL_TICKS: return false
	stalledAt = -1
	return true

func healthReserve() -> float:
	return 0.0
