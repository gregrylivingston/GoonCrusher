class_name Derby extends Node2D
## Demolition Derby's arena (Modes, Root.gameModes.DERBY): a painted circle RADIUS across the level's own ground
## round the start, with everything the level put there: trees and rocks to hide behind and be pinned against,
## fences and crates to smash through, mud, ice and water. The cars start on a ring facing the middle. Cars hit
## far harder here (ModeTiers.DERBY_BUMP) and every driver steers into the nearest other car (AIDriver.ramCars).
## A car outside the line loses OUT_DAMAGE health a second, so nobody wins by driving away. The last car running
## wins: Level.rivalWrecked ends it when no rival is left.
##
## What keeps a heavy car from simply winning (OverheadCarBody2D.bumpCar): a hit hurts by how fast the cars
## close and where it lands, not by armour; a car struck on its nose takes NOSE_SHARE of it, so the one that
## turns quicker and arrives faster does the damage. Repair Kits and Nitro lie at fixed spots (PADS) and come
## back RESPAWN seconds after they are taken; the obstacles are there for the quick cars to use.
## Every number is a first guess.

const RADIUS := 3400.0     #the painted line, px from the start
const RING := 1250.0       #the cars start this far from the middle
const OUT_DAMAGE := 12.0   #health a second outside the line
const LINE := Color(1.0, 0.78, 0.2, 0.8)
const PADS := [[900.0, "nitro"], [1900.0, "health"], [2700.0, "nitro"], [1500.0, "health"], [2300.0, "nitro"], [2900.0, "health"], [1100.0, "nitro"], [2100.0, "health"]] #[px from the middle, pickup id], spread round the circle
const RESPAWN := 18.0      #seconds before a taken pickup comes back

var centre := Vector2.ZERO
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
	derby.centre = at
	derby.z_index = 1
	level.add_child(derby)
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

func inside(point: Vector2) -> bool:
	return point.distance_squared_to(centre) < RADIUS * RADIUS

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
	draw_arc(centre, RADIUS, 0.0, TAU, 160, LINE, 20.0)
