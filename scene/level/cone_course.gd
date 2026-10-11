class_name ConeCourse extends RefCounted
## Cone Course's layout (Modes, Root.gameModes.CONES): a car-park course of cone gates on a cleared lot. The world
## is built with a lot at the start and no station on it (TileManager.buildWorld gives the mode the "defense"
## objective). The course is a curve through CONTROL (path): a slalom along the top of the lot, a hairpin,
## a sweeping run back through the middle, a second hairpin and a slalom to the finish along the bottom.
## A gate stands every GATE_GAP along it, square to the curve; on the straights the gates step SLALOM to
## either side in turn, in the bends they sit on the curve.
## Each gate is two cones (the baked cone prop, which knocks over at speed: PropReactions) either side of a
## point the car must pass, in order (Course, with a small radius); the last gate is the finish. A knocked
## cone takes CONE_PENALTY seconds off the clock (Level.coneKnocked). Course draws the line to the next gates.
## Every number is a first guess.

const CONE_SCENE := "res://world/art/props/cone.tscn"
#the curve's points from the lot's center, all inside WorldGen.LOT_RECT with room for the cones
const CONTROL := [Vector2(-2000, -1000), Vector2(-200, -1000), Vector2(1500, -1000), Vector2(2250, -480), Vector2(1850, 120),
	Vector2(700, -150), Vector2(-500, -360), Vector2(-1700, -60), Vector2(-2250, 500), Vector2(-1800, 1040),
	Vector2(-400, 1000), Vector2(1000, 1050), Vector2(2200, 950)]
const STEPS := 24         #samples of the curve between two of its points
const GATE_GAP := 400.0   #px of curve between gates
const SLALOM := 150.0     #on a straight, each gate is this far to one side of the curve, in turn
const STRAIGHT := 0.1     #radians the curve may turn between two gates and still count as straight
const GATE_HALF := 115.0  #a cone's distance from its gate's center
const PASS_RADIUS := 95.0
const CONE_PENALTY := 1.0 #seconds off the clock for a knocked cone
const START := Vector2(-2450.0, -1000.0) #the car, from the lot's center: west of the first gate, facing it

## The curve through CONTROL, as closely spaced points (Catmull-Rom)
static func path() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in CONTROL.size() - 1:
		var before: Vector2 = CONTROL[maxi(i - 1, 0)]
		var after: Vector2 = CONTROL[mini(i + 2, CONTROL.size() - 1)]
		for step in STEPS: out.push_back(CONTROL[i].cubic_interpolate(CONTROL[i + 1], before, after, float(step) / STEPS))
	out.push_back(CONTROL[-1])
	return out

## The gates round the lot's `center`, in order: [their centers, the unit vector across each (cone to cone)]
static func gates(center: Vector2) -> Array:
	var line := path()
	var spots := PackedVector2Array()
	var headings := PackedVector2Array()
	var due := 0.0
	var along := 0.0
	for i in range(1, line.size()):
		var step := line[i - 1].distance_to(line[i])
		while step > 0.0 && along + step >= due:
			spots.push_back(line[i - 1].lerp(line[i], (due - along) / step))
			headings.push_back((line[i] - line[i - 1]).normalized())
			due += GATE_GAP
		along += step
	var centers := PackedVector2Array()
	var across := PackedVector2Array()
	var side := 1.0
	for i in spots.size():
		var normal := headings[i].orthogonal()
		var straight: bool = i > 0 && i < spots.size() - 1 && absf(headings[i - 1].angle_to(headings[i])) < STRAIGHT && absf(headings[i].angle_to(headings[i + 1])) < STRAIGHT
		centers.push_back(center + spots[i] + (normal * SLALOM * side if straight else Vector2.ZERO))
		across.push_back(normal)
		if straight: side = -side
	return [centers, across]

## Gate centers round the lot's `center`, in order
static func layout(center: Vector2) -> PackedVector2Array:
	return gates(center)[0]

## Builds the level's course: the cones in the world and the Course that counts the gates
static func build(level: Node, center: Vector2) -> Course:
	var made := gates(center)
	var centers: PackedVector2Array = made[0]
	var scene: PackedScene = load(CONE_SCENE)
	for i in centers.size():
		for side in [-1.0, 1.0]:
			var cone: Node2D = scene.instantiate()
			cone.position = centers[i] + made[1][i] * GATE_HALF * side
			cone.set_meta(&"courseCone", true)
			level.add_child(cone)
	var course := Course.new()
	course.radius = PASS_RADIUS
	course.look = &"dot"
	course.finishes = true
	course.gateWord = "GATE"
	level.add_child(course)
	course.setPoints(centers)
	return course
