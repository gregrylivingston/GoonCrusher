extends "res://scripts/ai/briefs/race_brief.gd"

#Flat Out: due east to the station with Nitro at every checkpoint, and two seconds on the clock for crossing
#the line too fast to stop (ModeTiers.FLATOUT_STOP_SPEED). So: no slow zone round the lot, Nitro on the
#straights, and brakes from the point where the car can still get under the stop speed.

const LINE_SPEED := ModeTiers.FLATOUT_STOP_SPEED - 40.0 #what it brakes to, with a margin under the stop speed
const LINE_MARGIN_PX := 400.0                           #it starts braking this much before it has to

var brakeFrom := -1.0 #px from the driveway where braking starts; worked out again as the speed changes
var brakeTick := -9999

func tuning() -> Dictionary:
	return {"stationSpeed": 5000.0} #flat out to the braking point: brakeAbove slows it, not the lot

func brakeAbove() -> float:
	var course = Root.levelRoot.get("course")
	if not is_instance_valid(Root.station) || (course != null && course.next < course.total() - 1): return INF #checkpoints still to come (the last one is inside the braking distance)
	if d.tick - brakeTick >= AIDriver.GOAL_TICKS:
		brakeTick = d.tick
		brakeFrom = d.brakeDistance(LINE_SPEED) + LINE_MARGIN_PX
	var line: Vector2 = Root.station.get_node("driveway/CollisionShape2D").global_position
	return LINE_SPEED if d.car.global_position.distance_to(line) < brakeFrom + AIDriver.GOAL_RADIUS.station else INF

func wantsBoost() -> bool:
	return brakeAbove() == INF && d.openRoadAhead()
