class_name Derby extends Node2D
## Demolition Derby's arena (Modes, Root.gameModes.DERBY): the cleared lot the world builds at the start, with
## no station on it (TileManager.buildWorld gives the mode the "defense" objective). The cars start on a ring
## facing the middle; cars hit far harder here (ModeTiers.DERBY_BUMP) and every driver steers into the nearest
## other car (AIDriver.ramCars). A car outside the painted line loses OUT_DAMAGE health a second, so nobody
## wins by driving away. The last car running wins: Level.rivalWrecked ends it when no rival is left.
## Every number is a first guess.

const ARENA := Rect2(-2300.0, -1250.0, 4600.0, 2500.0) #from the lot's centre, inside WorldGen.LOT_RECT
const RING := 950.0        #the cars start this far from the middle
const OUT_DAMAGE := 12.0   #health a second outside the line
const LINE := Color(1.0, 0.78, 0.2, 0.8)

var centre := Vector2.ZERO

## Puts the player and the rivals on the starting ring and returns the arena
static func build(level: Node, at: Vector2) -> Derby:
	var derby := Derby.new()
	derby.centre = at
	derby.z_index = 1
	level.add_child(derby)
	var cars: Array = [Root.playerCar] + level.rivals.cars
	var tier := ModeTiers.clampTier(level.tier)
	for i in cars.size():
		var car: OverheadCarBody2D = cars[i]
		var angle := PI + i * TAU / cars.size() #the player on the west side
		car.global_position = at + Vector2.from_angle(angle) * RING
		car.rotation = angle + PI #facing the middle
		car.velocity = Vector2.ZERO
		if car != Root.playerCar: car.health = ModeTiers.DERBY_HEALTH[tier]
	level.startPosition = Root.playerCar.global_position
	if Root.playerCar.has_node("Camera2D"): Root.playerCar.get_node("Camera2D").reset_smoothing()
	return derby

func inside(point: Vector2) -> bool:
	return Rect2(centre + ARENA.position, ARENA.size).has_point(point)

func _physics_process(delta: float) -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.hasEnded || not level.clockReady: return
	for car in get_tree().get_nodes_in_group(&"cars"):
		if not car.isDestroyed && not inside(car.global_position): car.damage(OUT_DAMAGE * delta)

func _draw() -> void:
	draw_rect(Rect2(centre + ARENA.position, ARENA.size), LINE, false, 18.0)
