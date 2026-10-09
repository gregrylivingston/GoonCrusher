extends GameTest

#World (scripts/world/world.gd): the terrain table, its predicates, the runtime queries' delegation,
#and the car's use of them: surface handling in integrate(), the off-road rule, wall-hit angles and
#the two-tick water death.

const DT := 1.0 / 60.0

#a stand-in for the phase-2 WorldMap: one terrain everywhere, or `left` west of x = 0
class FakeMap extends RefCounted:
	var terrain := 0
	var left := -1
	func terrainAt(pos: Vector2) -> int: return left if left >= 0 && pos.x < 0.0 else terrain
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))

class Breakable extends StaticBody2D:
	var smashSpeed := 180.0
	func smash(_car) -> void: pass

#counts destroy() instead of exploding (no level in the tests)
class LethalCar extends OverheadCarBody2D:
	var destroyed := 0
	func destroy():
		destroyed += 1
		isWrecked = true

var savedMap
var savedSettings: Dictionary
var cars: Array = []

func before_each():
	savedMap = Root.worldMap
	savedSettings = Settings.values.duplicate(true)

func after_each():
	Root.worldMap = savedMap
	World.resetCache()
	for car in cars: car.free()
	cars.clear()
	for key in savedSettings: Settings.values[key] = savedSettings[key]
	Settings.apply_all()

func makeCar(script = OverheadCarBody2D) -> OverheadCarBody2D:
	var car = script.new()
	car.engine = 25
	car.steering = 12
	car.traction = 4
	car.armor = 1
	cars.push_back(car)
	return car

func useMap(terrain: int) -> FakeMap:
	var map = FakeMap.new()
	map.terrain = terrain
	Root.worldMap = map
	return map

func input(steer := 0.0, accel := 0.0, braking := false) -> OverheadCarBody2D.CarInput:
	var i = OverheadCarBody2D.CarInput.new()
	i.steering = steer
	i.acceleration = accel
	i.braking = braking
	return i

#speed after `ticks` ticks of integrate from `speed` along +x
func coast(car, ticks: int, speed: float, how: OverheadCarBody2D.CarInput) -> Vector2:
	var vel = Vector2(speed, 0)
	var forward = Vector2.RIGHT
	for t in ticks:
		var next = car.integrate(Vector2(100, 100), forward, vel, how, DT)
		forward = next[0]
		vel = next[1]
	return vel

#--- the table -----------------------------------------------------------------------------------

func test_table_matches_the_terrain_enums():
	assert_eq(World.TERRAIN.size(), Root.terrain.size(), "one row per Root.terrain value")
	assert_eq(World.count(), Root.terrain.size())
	for key in Root.terrain:
		var id: int = Root.terrain[key]
		assert_eq(World.TERRAIN[id].name, key, "row %d is %s" % [id, key])
		assert_eq(Goons.T[key], id, "Goons.T.%s mirrors Root.terrain" % key)
	assert_eq(Goons.T.size(), Root.terrain.size(), "Goons.T has every terrain")
	var expected := ["GRASS", "SAND", "MUD", "WATER", "HILLS", "MOSS", "DIRT", "SNOW", "ASPHALT", "ICE", "OIL",
		"SHALLOWS", "WASH", "CONVEYOR", "MUDPIT", "DEEPSNOW", "LOT", "BUILDING", "BRIDGE"]
	for i in expected.size(): assert_eq(Root.terrain.find_key(i), expected[i], "append-only order at %d" % i)

func test_table_rows_are_consistent():
	var letters := {}
	for i in World.TERRAIN.size():
		var d: Dictionary = World.TERRAIN[i]
		for field in ["name", "letter", "friction", "grip", "brake", "push", "passable", "lethal", "wall", "routeWeight", "spawnable"]:
			assert_true(d.has(field), "%s has %s" % [d.get("name", i), field])
		assert_false(letters.has(d.letter), "letter %s is unique" % d.letter)
		letters[d.letter] = true
		assert_false(d.letter in ["S", "X"], "S and X are the playtest map's start and station")
		if d.lethal || d.wall: assert_false(d.passable, "%s: lethal and wall terrain is impassable" % d.name)
		if d.spawnable: assert_true(d.passable, "%s: spawnable terrain is passable" % d.name)
		if d.passable: assert_true(d.routeWeight >= 1.0, "%s: route weight at least 1" % d.name)
		else: assert_eq(d.routeWeight, 0.0, "%s: blocked terrain has no route weight" % d.name)
	assert_eq(World.letter(Root.terrain.WATER), "~")
	assert_eq(World.letter(Root.terrain.HILLS), "^")

func test_table_numbers_follow_the_spec():
	assert_almost_eq(World.friction(Root.terrain.GRASS), 0.13, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.SAND), 0.5, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.MUD), 0.6, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.DIRT), 0.03, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.MOSS), 0.08, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.SNOW), 0.3, 0.0001)
	assert_almost_eq(World.grip(Root.terrain.ICE), 0.35, 0.0001)
	assert_almost_eq(World.brake(Root.terrain.ICE), 0.5, 0.0001)
	assert_almost_eq(World.grip(Root.terrain.OIL), 0.25, 0.0001)
	assert_almost_eq(World.brake(Root.terrain.OIL), 0.4, 0.0001)
	assert_almost_eq(World.friction(Root.terrain.MUDPIT), 1.0, 0.0001)
	assert_almost_eq(World.push(Root.terrain.CONVEYOR), 250.0, 0.0001)
	assert_almost_eq(World.push(Root.terrain.GRASS), 0.0, 0.0001)

func test_predicates():
	var t = Root.terrain
	assert_true(World.isLethal(t.WATER))
	assert_false(World.isPassable(t.WATER))
	assert_false(World.isSpawnable(t.WATER))
	assert_false(World.isWallTerrain(t.WATER), "water kills, it doesn't stop the car")
	for wall in [t.HILLS, t.BUILDING]:
		assert_true(World.isWallTerrain(wall))
		assert_false(World.isPassable(wall))
		assert_true(World.isBlocked(wall))
	assert_true(World.isPassable(t.BRIDGE), "a bridge deck is passable")
	assert_false(World.isLethal(t.BRIDGE))
	assert_true(World.isPassable(t.SHALLOWS), "shallows can be driven")
	assert_false(World.isSpawnable(t.SHALLOWS), "but nothing spawns there")
	assert_false(World.isLethal(t.SHALLOWS))
	for land in [t.GRASS, t.SAND, t.MUD, t.MOSS, t.DIRT, t.SNOW]:
		assert_true(World.isPassable(land) && World.isSpawnable(land) && not World.isBlocked(land), "%s is plain land" % land)
	#an unknown id (no map loaded) is none of these
	for check in [World.isPassable, World.isLethal, World.isWallTerrain, World.isSpawnable, World.isBlocked]:
		assert_false(check.call(World.UNKNOWN), "UNKNOWN is never %s" % check.get_method())
		assert_false(check.call(999), "an id past the table is never %s" % check.get_method())
	assert_eq(World.def(-1).name, "GRASS", "def() of an unknown id is grass's row")

func test_old_water_and_hills_checks_are_unchanged():
	#AIRoute and the chunk map keep treating exactly water and hills as solid among the old terrains
	for id in 8:
		var old = id == Root.terrain.WATER || id == Root.terrain.HILLS
		assert_eq(AIRoute.isBlocked(id), old, "AIRoute.isBlocked(%d)" % id)
		assert_eq(not World.isPassable(id), old, "World.isPassable(%d)" % id)
		assert_eq(not World.isSpawnable(id), old, "World.isSpawnable(%d)" % id)

func test_is_wall():
	var body = StaticBody2D.new()
	var tiles = TileMap.new()
	var goon = CharacterBody2D.new()
	var area = Area2D.new()
	assert_true(World.isWall(body), "static bodies (rocks, walls) are walls")
	assert_true(World.isWall(tiles), "terrain TileMaps are walls")
	assert_false(World.isWall(goon), "a CharacterBody2D is a goon")
	assert_false(World.isWall(area))
	assert_false(World.isWall(null))
	for node in [body, tiles, goon, area]: node.free()

#--- runtime queries -----------------------------------------------------------------------------

func test_queries_without_a_map_are_unknown_and_harmless():
	Root.worldMap = null
	World.resetCache()
	if is_instance_valid(Root.levelRoot): return #a level is loaded: the fallback map answers instead
	assert_eq(World.terrainAt(Vector2(5, 5)), World.UNKNOWN)
	assert_eq(World.surfaceAt(Vector2(5, 5)), World.UNKNOWN)
	assert_false(World.lethalAt(Vector2(5, 5)), "nothing is lethal before a map exists")
	assert_false(World.blockedAt(Vector2(5, 5)))
	assert_false(World.spawnableAt(Vector2(5, 5)))

func test_queries_delegate_to_the_world_map():
	var map = useMap(Root.terrain.GRASS)
	map.left = Root.terrain.WATER
	assert_eq(World.terrainAt(Vector2(10, 0)), Root.terrain.GRASS)
	assert_eq(World.terrainAt(Vector2(-10, 0)), Root.terrain.WATER)
	assert_true(World.lethalAt(Vector2(-10, 0)))
	assert_false(World.lethalAt(Vector2(10, 0)))
	assert_true(World.blockedAt(Vector2(-10, 0)))
	assert_true(World.spawnableAt(Vector2(10, 0)))
	map.terrain = Root.terrain.CONVEYOR
	assert_eq(World.pushAt(Vector2(10, 0), Root.terrain.CONVEYOR), Vector2(250, 0), "belts run along +x until WorldMap stores a direction")
	assert_eq(World.pushAt(Vector2(10, 0), Root.terrain.GRASS), Vector2.ZERO)

#--- car surface handling ------------------------------------------------------------------------

func test_off_road_rule():
	assert_almost_eq(World.effectiveFriction(0.13, 100.0), 0.13, 0.0001, "grass is the baseline")
	assert_almost_eq(World.effectiveFriction(0.03, 100.0), 0.03, 0.0001, "hard ground below grass is never changed")
	assert_almost_eq(World.effectiveFriction(0.5, 0.0), 0.5, 0.0001, "no armor: the full friction")
	assert_almost_eq(World.effectiveFriction(0.5, 40.0), 0.13 + 0.37 * 0.8, 0.0001, "armor 40 ignores 20% of the extra")
	assert_almost_eq(World.effectiveFriction(0.5, 70.0), 0.13 + 0.37 * 0.65, 0.0001, "capped at 35%")
	assert_almost_eq(World.effectiveFriction(0.5, 500.0), 0.13 + 0.37 * 0.65, 0.0001, "still 35%")
	assert_almost_eq(World.effectiveFriction(0.5, -10.0), 0.5, 0.0001, "negative armor doesn't add friction")

func test_soft_ground_slows_the_car_and_armor_ploughs_through():
	var car = makeCar()
	useMap(Root.terrain.GRASS)
	var onGrass = coast(car, 60, 400.0, input()).length()
	useMap(Root.terrain.SAND)
	var onSand = coast(car, 60, 400.0, input()).length()
	assert_gt(onGrass, onSand + 20.0, "sand drags more than grass")
	car.armor = 70
	var armoredOnSand = coast(car, 60, 400.0, input()).length()
	assert_gt(armoredOnSand, onSand, "an armored car loses less speed on sand")
	useMap(Root.terrain.DIRT)
	assert_gt(coast(car, 60, 400.0, input()).length(), onGrass, "hardpan is faster than grass")

func test_no_map_keeps_the_cars_own_friction():
	Root.worldMap = null
	World.resetCache()
	if is_instance_valid(Root.levelRoot): return
	var slick = makeCar()
	slick.friction = 0.02
	var sticky = makeCar()
	sticky.friction = 0.6
	assert_gt(coast(slick, 60, 400.0, input()).length(), coast(sticky, 60, 400.0, input()).length() + 20.0,
		"without a map integrate() uses the car's friction")

func test_ice_and_oil_cut_grip_after_the_clamp():
	var car = makeCar()
	car.traction = 150 #maxed: gripFor clamps it, the surface still multiplies after
	var turn = input(1.0, 1.0)
	useMap(Root.terrain.GRASS)
	var grass = coast(car, 30, 400.0, turn)
	useMap(Root.terrain.ICE)
	var ice = coast(car, 30, 400.0, turn)
	#the heading turns as fast on both; on ice the velocity lags behind it
	assert_gt(absf(grass.angle()), absf(ice.angle()) + 0.03, "velocity follows the wheels less on ice")
	useMap(Root.terrain.ASPHALT)
	var asphalt = coast(car, 30, 400.0, turn)
	assert_true(absf(asphalt.angle()) >= absf(grass.angle()) - 0.001, "asphalt grips at least as well as grass")

func test_brakes_are_weaker_on_ice_and_oil():
	var car = makeCar()
	var stop = input(0.0, 0.0, true)
	useMap(Root.terrain.LOT) #the same friction as oil, so only the brake differs
	var lot = coast(car, 20, 500.0, stop).length()
	useMap(Root.terrain.OIL)
	var oil = coast(car, 20, 500.0, stop).length()
	assert_gt(oil, lot + 20.0, "braking on oil sheds less speed")

func test_conveyor_pushes_along_the_belt():
	var car = makeCar()
	useMap(Root.terrain.CONVEYOR)
	var vel = coast(car, 120, 0.0, input())
	assert_gt(vel.x, 150.0, "a parked car is carried along +x")
	assert_true(vel.x <= 250.0 + 1.0, "never past the belt speed")
	assert_eq(OverheadCarBody2D.conveyorPull(Vector2(300, 0), Vector2(250, 0)), Vector2.ZERO, "a car already faster that way is left alone")
	assert_eq(OverheadCarBody2D.conveyorPull(Vector2(100, 0), Vector2.ZERO), Vector2.ZERO)
	useMap(Root.terrain.GRASS)
	assert_almost_eq(coast(car, 120, 0.0, input()).length(), 0.0, 0.001, "no push off the belt")

func test_integrate_stays_pure_with_a_map():
	var car = makeCar()
	useMap(Root.terrain.SAND)
	car.velocity = Vector2(300, 0)
	car.friction = 0.1
	car.integrate(Vector2.ZERO, Vector2.RIGHT, car.velocity, input(1.0, 1.0, true), DT)
	assert_eq(car.velocity, Vector2(300, 0), "integrate never changes the car's velocity")
	assert_almost_eq(car.friction, 0.1, 0.0001, "or its friction")

#--- wall hits -----------------------------------------------------------------------------------

func test_wall_impact_scales_with_the_angle():
	var head_on = OverheadCarBody2D.wallImpact(Vector2(-1, 0), Vector2(400, 0))
	assert_almost_eq(head_on, 1.0, 0.0001, "head-on")
	assert_almost_eq(OverheadCarBody2D.wallImpact(Vector2(-1, 0), Vector2(0, 400)), OverheadCarBody2D.WALL_IMPACT_MIN, 0.0001, "along the wall: the minimum")
	assert_almost_eq(OverheadCarBody2D.wallImpact(Vector2(-1, 0), Vector2(300, 300)), sqrt(0.5), 0.0001, "45 degrees")
	assert_almost_eq(OverheadCarBody2D.wallImpact(Vector2(-1, 0), Vector2.ZERO), OverheadCarBody2D.WALL_IMPACT_MIN, 0.0001, "no speed")
	assert_almost_eq(OverheadCarBody2D.wallImpact(Vector2(0, 1), Vector2(10, -1000)), 0.99995, 0.001, "sign doesn't matter")
	assert_almost_eq(OverheadCarBody2D.wallSpeedKeep(1.0), 0.85, 0.0001, "a head-on hit keeps 85% (as before)")
	assert_almost_eq(OverheadCarBody2D.wallSpeedKeep(0.15), 1.0 - 0.15 * 0.15, 0.0001, "a scrape keeps 97.75%")
	assert_gt(OverheadCarBody2D.wallSpeedKeep(0.5), OverheadCarBody2D.wallSpeedKeep(0.9), "squarer hits lose more")

func test_wall_contact_kinds():
	var C = OverheadCarBody2D.WallContact
	assert_eq(OverheadCarBody2D.wallContact(20.0, false, false), C.HIT, "meeting a wall is a hit, however slow")
	assert_eq(OverheadCarBody2D.wallContact(50.0, true, true), C.SCRAPE, "staying against it is a scrape")
	assert_eq(OverheadCarBody2D.wallContact(50.0, true, false), C.NONE, "a scrape still cooling down costs nothing")
	assert_eq(OverheadCarBody2D.wallContact(OverheadCarBody2D.WALL_REHIT_SPEED, true, false), C.HIT, "driving into it hard again is a new hit")
	var hit = OverheadCarBody2D.wallDamage(C.HIT, 600.0, 1.0)
	assert_almost_eq(hit, OverheadCarBody2D.WALL_DAMAGE_PER_SPEED * 600.0, 0.001, "a head-on hit: full speed")
	assert_almost_eq(OverheadCarBody2D.wallDamage(C.HIT, 600.0, 0.5), hit * 0.5, 0.001, "scaled by the impact")
	assert_almost_eq(OverheadCarBody2D.wallDamage(C.SCRAPE, 2000.0, 0.15), OverheadCarBody2D.WALL_SCRAPE_MAX, 0.001, "a scrape is capped")
	assert_eq(OverheadCarBody2D.wallDamage(C.NONE, 600.0, 1.0), 0.0)

#a wall hit costs its damage once; scraping along the wall afterwards costs a small capped amount per second
func test_scraping_along_a_wall_costs_little():
	var car = makeCar()
	var normal = Vector2(0, -1) #a wall below the car
	var first = car.wallTick(normal, Vector2(400, 300), 1000) #in at an angle: impact 0.6
	assert_almost_eq(first, OverheadCarBody2D.WALL_DAMAGE_PER_SPEED * 500.0 * 0.6, 0.01, "the hit: speed x impact")
	var scrape := 0.0
	var hits := 0
	for t in range(1001, 1061): #a second along it at 500 px/s, nearly parallel
		var d = car.wallTick(normal, Vector2(500, 5), t)
		scrape += d
		if d > OverheadCarBody2D.WALL_SCRAPE_MAX: hits += 1
	assert_eq(hits, 0, "no second hit while scraping")
	var perSecond = 60.0 / OverheadCarBody2D.WALL_SCRAPE_TICKS * OverheadCarBody2D.WALL_SCRAPE_MAX
	assert_between(scrape, 0.1, perSecond + 0.01, "a second of scraping costs at most %.1f before armor" % perSecond)
	var oldModel = OverheadCarBody2D.WALL_DAMAGE_PER_SPEED * 500.0 * OverheadCarBody2D.WALL_IMPACT_MIN * 60.0
	assert_gt(oldModel / 4.0, scrape, "far less than a tick-by-tick scrape (%.0f)" % oldModel)
	assert_almost_eq(car.wallTick(normal, Vector2(500, 5), 1061), 0.0, 0.0001, "the scrape is still cooling down")
	assert_gt(car.wallTick(normal, Vector2(300, 400), 1062), OverheadCarBody2D.WALL_DAMAGE_PER_SPEED * 300.0, "turning hard into the wall is a new hit")
	assert_gt(car.wallTick(normal, Vector2(500, 5), 1200), 0.0, "after a gap, touching again is a new contact")
	assert_almost_eq(car.wallTick(normal, Vector2(500, 5), 1200), 0.0, 0.0001, "and only one per tick")

func test_breakables_need_their_smash_speed():
	var plain = StaticBody2D.new()
	assert_almost_eq(OverheadCarBody2D.smashSpeedOf(plain), 0.0, 0.0001, "no smashSpeed: 0")
	var fence = Breakable.new()
	assert_almost_eq(OverheadCarBody2D.smashSpeedOf(fence), 180.0, 0.0001, "reads smashSpeed")
	assert_true(fence.has_method("smash"), "the car smashes what has smash()")
	plain.free()
	fence.free()

#--- water death ---------------------------------------------------------------------------------

func test_water_wrecks_the_car_after_two_ticks():
	var map = useMap(Root.terrain.GRASS)
	map.left = Root.terrain.WATER
	var car = makeCar(LethalCar)
	car.checkGround(Vector2(-500, 0))
	assert_eq(car.destroyed, 0, "one tick over water is forgiven")
	car.checkGround(Vector2(-500, 0))
	assert_eq(car.destroyed, 1, "the second wrecks the car")
	car.checkGround(Vector2(-500, 0))
	car.checkGround(Vector2(-500, 0))
	assert_eq(car.destroyed, 1, "only once")

func test_water_count_resets_on_land():
	var map = useMap(Root.terrain.GRASS)
	map.left = Root.terrain.WATER
	var car = makeCar(LethalCar)
	car.checkGround(Vector2(-500, 0))
	car.checkGround(Vector2(500, 0))
	car.checkGround(Vector2(-500, 0))
	assert_eq(car.destroyed, 0, "two ticks, but not in a row")
	assert_almost_eq(car.friction, World.friction(Root.terrain.WATER), 0.0001, "friction follows the ground under the car")
	car.checkGround(Vector2(500, 0))
	assert_almost_eq(car.friction, 0.13, 0.0001, "grass")

func test_bridges_and_shallows_are_safe():
	var car = makeCar(LethalCar)
	for safe in [Root.terrain.BRIDGE, Root.terrain.SHALLOWS]:
		useMap(safe)
		for i in 5: car.checkGround(Vector2(10, 10))
	assert_eq(car.destroyed, 0)

#--- lighting ------------------------------------------------------------------------------------

func test_lighting_low_keeps_world_occluders():
	var rockOccluder = LightOccluder2D.new()
	rockOccluder.set_meta("gc_vis", true)
	rockOccluder.set_meta("gc_world", true)
	var goonOccluder = LightOccluder2D.new()
	goonOccluder.set_meta("gc_vis", true)
	var hidden = LightOccluder2D.new()
	hidden.set_meta("gc_vis", false)
	hidden.set_meta("gc_world", true)
	assert_true(Settings.occluderVisible(rockOccluder, 0), "Low keeps world occluders")
	assert_false(Settings.occluderVisible(goonOccluder, 0), "Low drops goon occluders")
	for level in [1, 2]:
		assert_true(Settings.occluderVisible(rockOccluder, level))
		assert_true(Settings.occluderVisible(goonOccluder, level))
	for level in 3: assert_false(Settings.occluderVisible(hidden, level), "an occluder authored hidden stays hidden")
	for node in [rockOccluder, goonOccluder, hidden]: node.free()

func test_rocks_walls_and_the_station_mark_their_occluders():
	Settings.set_value("gfx/lighting", 0, false)
	var rock = load("res://world/art/props/rock.tscn").instantiate()
	add_child_autofree(rock)
	assert_true(rock.get_node("LightOccluder2D").get_meta("gc_world", false), "rock occluders are world geometry")
	assert_true(rock.get_node("LightOccluder2D").visible, "and stay on at Lighting Low")
	var wall = load("res://world/art/props/fortwall.tscn").instantiate()
	assert_true(wall.get_node("LightOccluder2D").get_meta("gc_world", false), "fort walls too")
	wall.free()
	var station = load("res://scene/level/station.tscn").instantiate()
	assert_true(station.get_node("house/LightOccluder2D").get_meta("gc_world", false), "and the station house")
	for side in ["wallNorth", "wallSouth", "wallWest", "wallEast"]:
		assert_true(station.get_node(side + "/LightOccluder2D").get_meta("gc_world", false), "and the station's %s" % side)
	station.free()
	var goon = load("res://scene/enemy/walker/walker.tscn").instantiate()
	for occluder in goon.find_children("*", "LightOccluder2D", true, false):
		assert_false(occluder.get_meta("gc_world", false), "goon occluders aren't world geometry, so Low drops them")
	goon.free()

#--- AI route weights ----------------------------------------------------------------------------

func test_route_weights_come_from_the_table():
	var map = PackedByteArray()
	map.resize(16 * 16)
	map.fill(Root.terrain.GRASS)
	var t = Root.terrain
	var cells = {Vector2i(1, 1): t.SAND, Vector2i(2, 1): t.SNOW, Vector2i(3, 1): t.BUILDING, Vector2i(4, 1): t.BRIDGE, Vector2i(5, 1): t.SHALLOWS, Vector2i(6, 1): t.WATER}
	for c in cells: map[c.y * 16 + c.x] = cells[c]
	var route = AIRoute.new(map, Vector2i(16, 16), Vector2(1280, 1280))
	for c in cells:
		var cell = c
		var type = cells[c]
		assert_eq(route.grid.is_point_solid(cell), not World.isPassable(type), "terrain %d solid" % type)
		if World.isPassable(type): assert_almost_eq(route.grid.get_point_weight_scale(cell), World.routeWeight(type), 0.0001, "terrain %d weight" % type)
	assert_almost_eq(route.grid.get_point_weight_scale(Vector2i(1, 1)), 1.4, 0.0001, "sand keeps its old 1.4")
	assert_almost_eq(route.grid.get_point_weight_scale(Vector2i(2, 1)), 1.2, 0.0001, "snow keeps its old 1.2")
