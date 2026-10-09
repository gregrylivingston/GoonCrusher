extends GameTest

#Package 13, driving juice (docs/CAR_ART.md, "Driving feel"): the lean, pitch and two-wheel rules, the
#engine and squeal sound rules, surface trails, and that the car's own juice never touches its handling.

var savedCar
var savedSettings := {}
const KEYS := ["gfx/driving_fx", "access/reduce_motion", "access/car_shake"]

func before_each():
	savedCar = Root.playerCar
	for k in KEYS: savedSettings[k] = Settings.get_value(k)

func after_each():
	for k in KEYS: Settings.set_value(k, savedSettings[k], false)
	Root.playerCar = savedCar

func makeCar():
	var car = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	Root.playerCar = car
	return car

func surface(name: String) -> int:
	for i in World.count():
		if World.def(i).name == name: return i
	return -1

func test_the_body_leans_out_of_a_turn():
	#turning right, the velocity swings toward the car's right (+y): the body leans left
	assert_gt(0.0, CarJuice.leanTarget(800.0, 3000.0), "a right turn leans the body left")
	assert_gt(CarJuice.leanTarget(-800.0, 3000.0), 0.0, "a left turn leans it right")
	assert_almost_eq(CarJuice.leanTarget(-1e6, 3000.0), pow(1.2, CarJuice.LEAN_CURVE), 0.001, "capped")

func test_ordinary_turns_only_settle_the_suspension():
	assert_gt(0.35, absf(CarJuice.leanTarget(1500.0, 3000.0)), "half the grip limit: a slight lean")
	assert_gt(absf(CarJuice.leanTarget(2700.0, 3000.0)), 0.75, "near the limit: well over")

func test_braking_dips_the_nose_and_launching_squats():
	assert_gt(CarJuice.pitchTarget(-900.0), 0.0, "braking: the body moves forward")
	assert_gt(0.0, CarJuice.pitchTarget(900.0), "launching: it sits back")

func test_two_wheels_need_a_long_turn_at_the_limit_and_speed():
	var s := [false, 0]
	for i in CarJuice.TWO_WHEEL_TICKS - 1: s = CarJuice.twoWheelStep(s[0], s[1], 1.0, 0.9)
	assert_false(s[0], "a short hard turn doesn't tip it")
	s = CarJuice.twoWheelStep(s[0], s[1], 1.0, 0.9)
	assert_true(s[0], "held long enough at the limit, it is up")
	assert_true(CarJuice.twoWheelStep(true, 0, 0.75, 0.9)[0], "stays up through a slightly easier turn")
	assert_false(CarJuice.twoWheelStep(true, 0, 0.4, 0.9)[0], "comes down once the turn eases")
	assert_false(CarJuice.twoWheelStep(false, 100, 1.2, 0.3)[0], "never well below top speed")
	s = [false, 0]
	for i in 120: s = CarJuice.twoWheelStep(s[0], s[1], 0.8, 1.0)
	assert_false(s[0], "a hard turn short of the limit never tips it")

func test_the_spring_settles_and_overshoots_once():
	var x := Vector2(1.0, 0.0)
	var crossed := false
	for i in 120:
		x = CarJuice.spring(x.x, x.y, 0.0, CarJuice.LEAN_SPRING, CarJuice.LEAN_DAMP, 1.0 / 60.0)
		if x.x < 0.0: crossed = true
	assert_true(crossed, "under-damped: a lean that lets go swings past centre")
	assert_gt(0.02, absf(x.x), "and settles within two seconds")

func test_engine_pitch_climbs_through_a_gear_and_drops_at_the_shift():
	var low := CarJuice.enginePitch(20.0, 1.0, false)
	var high := CarJuice.enginePitch(CarJuice.GEAR_SPEED - 1.0, 1.0, false)
	var shifted := CarJuice.enginePitch(CarJuice.GEAR_SPEED + 1.0, 1.0, false)
	assert_gt(high, low, "revs climb in a gear")
	assert_gt(high - 0.4, shifted, "and fall at the shift")
	assert_gt(shifted, low, "each gear starts higher than the last")
	assert_gt(CarJuice.enginePitch(400.0, 1.0, false), CarJuice.enginePitch(400.0, 0.0, false), "throttle adds load")
	assert_eq(CarJuice.gearOf(650.0), 3, "the controller's gear rule")

func test_squeal_follows_slip():
	assert_eq(CarJuice.squeal(0.05, 600.0, false, false), 0.0, "gripping: silent")
	assert_gt(CarJuice.squeal(0.7, 600.0, false, false), 0.9, "sliding: loud")
	assert_eq(CarJuice.squeal(0.7, 50.0, false, false), 0.0, "not at a crawl")
	assert_gt(CarJuice.squeal(0.0, 500.0, true, false), 0.2, "a hard stop squeals")
	assert_gt(CarJuice.squeal(0.0, 600.0, false, true), 0.5, "so do two wheels")

func test_slip_folds_reversing_straight_back_to_zero():
	assert_almost_eq(CarJuice.slipAngle(Vector2(-300, 0), 0.0), 0.0, 0.001, "reversing")
	assert_almost_eq(CarJuice.slipAngle(Vector2(0, 300), 0.0), PI / 2.0, 0.001, "sideways")

func test_surfaces_have_the_right_trails():
	makeCar() #builds the table
	assert_eq(CarJuice.trailKind(surface("SAND")), CarJuice.Kind.PUFF, "sand: dust")
	assert_eq(CarJuice.trailKind(surface("SNOW")), CarJuice.Kind.PUFF, "snow: powder")
	assert_eq(CarJuice.trailKind(surface("MUD")), CarJuice.Kind.BITS, "mud: clods")
	assert_eq(CarJuice.trailKind(surface("SHALLOWS")), CarJuice.Kind.SPRAY, "shallows: spray")
	assert_eq(CarJuice.trailKind(surface("WADE")), CarJuice.Kind.SPRAY, "wading depth: spray")
	assert_eq(CarJuice.trailKind(surface("WATER")), CarJuice.Kind.SPRAY, "deep water: spray")
	assert_eq(CarJuice.trailKind(surface("ASPHALT")), -1, "asphalt: only tyre smoke in a slide")
	assert_true(CarJuice.isRough(surface("MUD")) && not CarJuice.isRough(surface("ASPHALT")), "a road to mud bumps")

func test_the_player_car_has_juice_and_its_pools_follow_the_setting():
	var car = makeCar()
	assert_true(is_instance_valid(car.juice), "the player's car owns one")
	Settings.set_value("gfx/driving_fx", 0, false)
	assert_eq(car.juice.dust.pos.size(), 0, "Minimal: no ground trails")
	Settings.set_value("gfx/driving_fx", 2, false)
	assert_eq(car.juice.dust.pos.size(), CarJuice.LEVELS[2][0], "Full")
	Settings.set_value("access/reduce_motion", true, false)
	assert_false(car.juice.bumps, "Reduce Motion: no bounces or jolts")
	Settings.set_value("access/reduce_motion", false, false)
	Settings.set_value("access/car_shake", false, false)
	assert_false(car.juice.bumps, "Car Shake Off: no bounces")

func test_juice_never_touches_handling():
	var car = makeCar()
	car.velocity = Vector2(700, 0)
	car.juice.prevVel = Vector2(700, -500) #a big sideways change: a hard lean
	var before: Vector2 = car.velocity
	for i in 10: car.juice._physics_process(1.0 / 60.0)
	assert_eq(car.velocity, before, "the velocity is the car's alone")
	assert_true(car.juice.lean != 0.0, "but the body leaned")
	car.juice.onWall(car.global_position + Vector2(100, 0), Vector2.LEFT, Vector2(600, 0), true)
	car.juice.driftBoost(1, Color.ORANGE)
	car.juice.land(true)
	assert_eq(car.velocity, before, "hits, boosts and landings only show")

func test_the_body_returns_to_rest():
	var car = makeCar()
	car.velocity = Vector2.ZERO
	car.juice.prevVel = Vector2(0, -600)
	car.juice.bump(-2.0)
	for i in 240: car.juice._physics_process(1.0 / 60.0)
	var body: Sprite2D = car.get_node("sprite/body")
	assert_gt(0.1, body.position.distance_to(car.juice.bodyBase), "the body is back in place")
	assert_gt(0.001, absf(body.scale.x - car.juice.bodyScale.x), "and its size")

#Water (CarJuice.water): over deep water the body settles in, tinted, its shadow fading, and comes back out;
#a bow wave sprays in wading depth at speed; none of it touches the car's velocity
class WaterMap extends RefCounted:
	var terrain := 0
	func terrainAt(_pos: Vector2) -> int: return terrain
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))

func test_the_car_settles_into_deep_water_and_sprays_through_wading_depth():
	var savedMap = Root.worldMap
	var map := WaterMap.new()
	Root.worldMap = map
	var car = makeCar()
	Settings.set_value("gfx/driving_fx", 2, false)
	var body: Sprite2D = car.get_node("sprite/body")
	var shadow: Sprite2D = car.get_node("sprite/shadow")
	var alpha := shadow.self_modulate.a
	car.velocity = Vector2(600, 0)
	map.terrain = Root.terrain.WATER
	for i in 60: car.juice._physics_process(1.0 / 60.0)
	assert_almost_eq(car.juice.sink, 1.0, 0.001, "a second over deep water: sunk")
	assert_gt(1.0, body.modulate.g, "tinted by the water over it")
	assert_gt(car.juice.bodyScale.x, body.scale.x, "settled lower: smaller from overhead")
	assert_gt(alpha, shadow.self_modulate.a, "its shadow gone under")
	assert_eq(car.velocity, Vector2(600, 0), "show only")
	map.terrain = Root.terrain.GRASS
	for i in 60: car.juice._physics_process(1.0 / 60.0)
	assert_almost_eq(car.juice.sink, 0.0, 0.001, "out again")
	assert_eq(body.modulate, Color.WHITE)
	assert_almost_eq(shadow.self_modulate.a, alpha, 0.001)
	map.terrain = Root.terrain.WADE
	car.juice.dust.resize(CarJuice.LEVELS[2][0]) #an empty pool
	for i in 20: car.juice._physics_process(1.0 / 60.0)
	assert_gt(car.juice.dust.alive, 10, "wading at speed: spray and a bow wave")
	assert_almost_eq(car.juice.sink, 0.0, 0.001, "wading never sinks the car")
	Root.worldMap = savedMap

#Headlights (OverheadCarBody2D.setHeadlightStrength): the stat shows as a longer, wider, brighter beam and
#bigger, brighter tail lamps, bright when braking or reversing
func test_better_headlights_show_in_the_lamps():
	var car = makeCar()
	car.headlights = 1
	car.setHeadlightStrength()
	var lamp: PointLight2D = car.get_node("headlamps/headlights/headlamp1")
	var tail: PointLight2D = car.get_node("headlamps/taillamps/tailLamp3")
	var beam: Vector2 = car.get_node("headlamps/headlights").scale
	var glow := lamp.energy
	var tailSize := tail.scale
	car.headlights = 41
	car.setHeadlightStrength()
	var wider: Vector2 = car.get_node("headlamps/headlights").scale
	assert_gt(wider.x, beam.x, "reaches further")
	assert_gt(wider.y, beam.y + 0.3, "clearly wider")
	assert_gt(lamp.energy, glow * 1.4, "clearly brighter")
	assert_gt(tail.scale.x, tailSize.x, "bigger tail lamps")
	assert_eq(tail.position, Vector2(-107, -32), "still on the bumper")
	assert_gt(OverheadCarBody2D.tailLampEnergy(true, 0.0), OverheadCarBody2D.tailLampEnergy(false, 0.0) * 2.0, "braking is bright")
	assert_gt(OverheadCarBody2D.tailLampEnergy(false, 0.6), OverheadCarBody2D.tailLampEnergy(false, 0.0), "upgrades brighten them")
	car.headlights = 1
	car.setHeadlightStrength()
	assert_almost_eq(lamp.energy, glow, 0.0001, "and come back down without drifting")
