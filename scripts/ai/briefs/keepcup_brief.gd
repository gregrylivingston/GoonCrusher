extends ModeBrief

#Keep the Cup: one trophy and six cars after it; whoever holds it banks time, and any car that stays close
#to the holder for two seconds takes it (KeepCup). Without the cup: go and get it. Holding it: keep away
#from the nearest chaser, on ground that leads somewhere.

const FLEE_PX := 2600.0 #how far ahead the holder picks its next point
const FLEE_TRIES := 7

var fleeTo := Vector2.INF
var fleeUntil := 0

func objective() -> Dictionary:
	var trophy = Root.levelRoot.get("cup")
	if trophy == null: return super()
	var car := d.car
	if trophy.holder != car: return {"kind":"gate", "pos":trophy.cupPosition(), "value":200.0, "key":"cup"}
	if fleeTo == Vector2.INF || d.tick > fleeUntil || car.global_position.distance_to(fleeTo) < AIDriver.GOAL_RADIUS.roam:
		fleeTo = fleePoint()
		fleeUntil = d.tick + 4 * Engine.physics_ticks_per_second
	return {"kind":"roam", "pos":fleeTo, "value":200.0, "key":"flee"} if fleeTo != Vector2.INF else {}

#away from the nearest chaser, bent toward the way the car is already going (a U-turn hands the cup over)
func fleePoint() -> Vector2:
	var car := d.car
	var chaser: Node2D = null
	for other in car.get_tree().get_nodes_in_group(&"cars"):
		if other != car && not other.isDestroyed && (chaser == null || other.global_position.distance_squared_to(car.global_position) < chaser.global_position.distance_squared_to(car.global_position)): chaser = other
	var forward := Vector2.from_angle(car.rotation)
	var away: Vector2 = (car.global_position - chaser.global_position).normalized() if chaser else forward
	var heading := (away + forward * 0.8).normalized()
	for i in FLEE_TRIES: #fan out to either side until a point is dry and reachable
		var spot: Vector2 = car.global_position + heading.rotated(((i + 1) / 2) * 0.45 * (1.0 if i % 2 == 0 else -1.0)) * FLEE_PX
		if not AIRoute.isBlocked(d.route.terrainAt(spot)) && not d.nearWater(spot) && d.route.lineIsClear(car.global_position, spot, 250.0): return spot
	return Vector2.INF

func healthReserve() -> float:
	return d.p.reserveBase
