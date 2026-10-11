class_name Derby extends Node2D
## Demolition Derby's arena (Modes, Root.gameModes.DERBY): a stadium RADIUS across on the level's own ground
## round the start: a hard wall (buildWalls) with stands of cheering goons behind it (Crowd), and inside it
## everything the level put there: trees and rocks to hide behind and be pinned against,
## fences and crates to smash through, mud, ice and water. The cars start on a ring facing the middle. Cars hit
## far harder here (ModeTiers.DERBY_BUMP) and every driver steers into the nearest other car (AIDriver.ramCars).
## The wall keeps everyone in (a car that still gets outside loses OUT_DAMAGE health a second). The last car
## running wins: Level.rivalWrecked ends it when no rival is left.
##
## What keeps a heavy car from simply winning (OverheadCarBody2D.bumpCar): a hit hurts by how fast the cars
## close and where it lands, not by armor; a car struck on its nose takes NOSE_SHARE of it, so the one that
## turns quicker and arrives faster does the damage. Repair Kits and Nitro lie at fixed spots (PADS) and come
## back RESPAWN seconds after they are taken; the obstacles are there for the quick cars to use.
## Every number is a first guess.

const RADIUS := 3400.0     #the wall's inner face, px from the start
const WALL_SEGMENTS := 64  #straight pieces of wall round the ring
const WALL_THICK := 140.0
const STANDS := 620.0      #depth of the stands behind the wall
const WALL_COLOR := Color(0.78, 0.76, 0.72)
const STANDS_COLOR := Color(0.24, 0.25, 0.29)
const STEP_COLOR := Color(0.33, 0.34, 0.39)
const RING := 1250.0       #the cars start this far from the middle
const OUT_DAMAGE := 12.0   #health a second outside the line
const LINE := Color(1.0, 0.78, 0.2, 0.8)
const PADS := [[900.0, "nitro"], [1900.0, "health"], [2700.0, "nitro"], [1500.0, "health"], [2300.0, "nitro"], [2900.0, "health"], [1100.0, "nitro"], [2100.0, "health"]] #[px from the middle, pickup id], spread round the circle
const RESPAWN := 18.0      #seconds before a taken pickup comes back

var center := Vector2.ZERO
var pads: Array = []       #[spot, pickup id, the pickup node or null, seconds until it comes back]

## Dry ground a car can stand on, as near `spot` as a few steps toward the middle find
static func settle(spot: Vector2, middle: Vector2) -> Vector2:
	for step in 6:
		var at := spot.lerp(middle, step * 0.12)
		if World.spawnableAt(at): return at
	return spot

## Puts the player and the rivals on the starting ring, lays the pickups and returns the arena
static func build(level: Node, at: Vector2) -> Derby:
	var derby := Derby.new()
	derby.center = at
	derby.z_index = 1
	level.add_child(derby)
	derby.buildWalls()
	var crowd := Crowd.new()
	crowd.center = at
	crowd.z_index = 1
	crowd.setup(LevelRoster.lineupFor(level.def))
	derby.add_child(crowd)
	var cars: Array = [Root.playerCar] + level.rivals.cars
	var tier := ModeTiers.clampTier(level.tier)
	for i in cars.size():
		var car: OverheadCarBody2D = cars[i]
		var angle := PI + i * TAU / cars.size() #the player on the west side
		car.global_position = settle(at + Vector2.from_angle(angle) * RING, at)
		car.rotation = angle + PI #facing the middle
		car.velocity = Vector2.ZERO
		if car != Root.playerCar: car.health = ModeTiers.DERBY_HEALTH[tier]
	level.startPosition = Root.playerCar.global_position
	if Root.playerCar.has_node("Camera2D"): Root.playerCar.get_node("Camera2D").reset_smoothing()
	for i in PADS.size():
		var spot: Vector2 = at + Vector2.from_angle(0.4 + i * TAU / PADS.size()) * PADS[i][0]
		if World.spawnableAt(spot): derby.pads.push_back([spot, PADS[i][1], null, 0.0])
	return derby

## The stadium wall: WALL_SEGMENTS straight pieces on the world layer, so cars and the AI's sweeps stop at it
func buildWalls() -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var piece := RectangleShape2D.new()
	piece.size = Vector2(2.0 * (RADIUS + WALL_THICK) * tan(PI / WALL_SEGMENTS) + 8.0, WALL_THICK)
	for i in WALL_SEGMENTS:
		var angle := i * TAU / WALL_SEGMENTS
		var shape := CollisionShape2D.new()
		shape.shape = piece
		shape.position = Vector2.from_angle(angle) * (RADIUS + WALL_THICK * 0.5)
		shape.rotation = angle + PI * 0.5
		wall.add_child(shape)
	add_child(wall)

## The goons in the stands: two rows of the level's own, facing the middle and hopping. Show only.
class Crowd extends Node2D:
	const ROWS := [190.0, 430.0] #px behind the wall's back face
	const SPACING := 135.0
	const SIZE := 0.55
	const HOP := 16.0
	const SEEN := 2600.0       #only the goons this near the camera are drawn
	var center := Vector2.ZERO
	var art: Array = []
	var seats := PackedVector2Array()
	var clock := 0.0

	func setup(lineup: Array) -> void:
		for id in lineup:
			var path := "res://scene/enemy/goons/%s/art/%s_idle0.png" % [id, id]
			if art.size() < 4 && ResourceLoader.exists(path): art.push_back(load(path))
		for row in ROWS.size():
			var r: float = Derby.RADIUS + Derby.WALL_THICK + ROWS[row]
			var count := int(TAU * r / SPACING)
			for i in count: seats.push_back(Vector2.from_angle((i + row * 0.5) * TAU / count) * r)

	func _process(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		var car = Root.playerCar
		if art.is_empty() || not is_instance_valid(car): return
		var eye: Vector2 = car.global_position - center
		for i in seats.size():
			var seat := seats[i]
			if seat.distance_squared_to(eye) > SEEN * SEEN: continue
			var texture: Texture2D = art[i % art.size()]
			var hop := absf(sin(clock * (5.0 + (i % 5) * 0.6) + i * 1.7)) * HOP
			draw_set_transform(center + seat - seat.normalized() * hop, seat.angle() + PI, Vector2.ONE * SIZE)
			draw_texture(texture, -texture.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO)

func inside(point: Vector2) -> bool:
	return point.distance_squared_to(center) < RADIUS * RADIUS

func _physics_process(delta: float) -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.hasEnded || not level.clockReady: return
	for car in get_tree().get_nodes_in_group(&"cars"):
		if not car.isDestroyed && not inside(car.global_position): car.damage(OUT_DAMAGE * delta)
	for pad in pads: #a taken pickup comes back after a while
		if is_instance_valid(pad[2]) && pad[2].is_inside_tree() && pad[2].visible: continue
		pad[3] -= delta
		if pad[3] > 0.0: continue
		var pickup := Pickups.make(pad[1])
		pickup.position = pad[0]
		level.add_child(pickup)
		pad[2] = pickup
		pad[3] = RESPAWN

func _draw() -> void:
	var back := RADIUS + WALL_THICK
	draw_arc(center, back + STANDS * 0.5, 0.0, TAU, 160, STANDS_COLOR, STANDS)
	for step in 3: draw_arc(center, back + STANDS * (step + 1) / 4.0, 0.0, TAU, 160, STEP_COLOR, 10.0)
	draw_arc(center, RADIUS + WALL_THICK * 0.5, 0.0, TAU, 160, WALL_COLOR, WALL_THICK)
	draw_arc(center, RADIUS + 10.0, 0.0, TAU, 160, LINE, 20.0)
