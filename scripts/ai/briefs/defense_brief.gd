extends ModeBrief

#Defense: hold the station until the clock runs out. Goons march on the pumps and blow up there, so a goon
#is worth more the nearer it is to the base (defenseThreat times more at the lot than at defenseRingPx),
#double once it is about to blow at a pump and nothing beyond the ring. With nothing to hunt the car
#patrols close to the base. It doesn't guard lanes or park to refuel yet.

const BLAST_PX := 500.0

var point := Vector2.INF
var until := 0

func objective() -> Dictionary:
	if not is_instance_valid(Root.station): return {}
	var car := d.car
	if point == Vector2.INF || d.tick > until || car.global_position.distance_to(point) < AIDriver.GOAL_RADIUS.patrol:
		for attempt in 8: #a patrol point on dry land, clear of the water's edge
			point = Root.station.global_position + Vector2.from_angle(randf() * TAU) * randf_range(500.0, 1100.0)
			if not d.nearWater(point): break
		until = d.tick + 15 * Engine.physics_ticks_per_second
	return {"kind":"patrol", "pos":point, "value":4.0, "key":"patrol"}

func goonWorth(goon: Node, value: float) -> float:
	if not is_instance_valid(Root.station): return value
	var away: float = goon.global_position.distance_to(Root.station.global_position)
	if away > d.p.defenseRingPx: return 0.0
	var worth: float = value * lerpf(d.p.defenseThreat, 1.0, away / d.p.defenseRingPx)
	var toPump: float = goon.global_position.distance_to(Root.station.nearestPump(goon.global_position))
	return worth * 2.0 if toPump < BLAST_PX else worth
