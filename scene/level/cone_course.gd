class_name ConeCourse extends RefCounted
## Cone Course's layout (Modes, Root.gameModes.CONES): a car-park course of cone gates on a cleared lot. The world
## is built with a lot at the start and no station on it (TileManager.buildWorld gives the mode the "defense"
## objective); three lanes of slalom gates run east, back west and east again, joined by two tight turns.
## Each gate is two cones (the baked cone prop, which knocks over at speed: PropReactions) either side of a
## point the car must pass, in order (Course, with a small radius); the last gate is the finish. A knocked
## cone takes CONE_PENALTY seconds off the clock (Level.coneKnocked). Every number is a first guess.

const CONE_SCENE := "res://world/art/props/cone.tscn"
const LANES := [-800.0, 0.0, 800.0] #lane y from the lot's center: all inside WorldGen.LOT_RECT
const LANE_HALF := 2000.0 #a lane runs this far either side of the center
const PER_LANE := 10
const SLALOM := 130.0     #each gate is this far up or down from its lane, in turn
const GATE_HALF := 125.0  #a cone's distance from its gate's center
const PASS_RADIUS := 105.0
const CONE_PENALTY := 1.0 #seconds off the clock for a knocked cone
const START := Vector2(-2450.0, -800.0) #the car, from the lot's center: west of the first lane, facing down it

## Gate centers round the lot's `center`, in order
static func layout(center: Vector2) -> PackedVector2Array:
	var gates := PackedVector2Array()
	for lane in LANES.size():
		for g in PER_LANE:
			var along := lerpf(-LANE_HALF, LANE_HALF, float(g) / (PER_LANE - 1)) * (1.0 if lane % 2 == 0 else -1.0)
			gates.push_back(center + Vector2(along, LANES[lane] + SLALOM * (1.0 if g % 2 == 0 else -1.0)))
	return gates

## Builds the level's course: the cones in the world and the Course that counts the gates
static func build(level: Node, center: Vector2) -> Course:
	var gates := layout(center)
	var scene: PackedScene = load(CONE_SCENE)
	for gate in gates:
		for side in [-1.0, 1.0]:
			var cone: Node2D = scene.instantiate()
			cone.position = gate + Vector2(0.0, GATE_HALF * side)
			cone.set_meta(&"courseCone", true)
			level.add_child(cone)
	var course := Course.new()
	course.radius = PASS_RADIUS
	course.finishes = true
	course.gateWord = "GATE"
	level.add_child(course)
	course.setPoints(gates)
	return course
