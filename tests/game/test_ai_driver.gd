extends GameTest

#The AI driver (scripts/ai/, docs/AI_DRIVER.md): its route planner, its prediction of the car, and
#the rules it scores goals and plans with. Nothing here starts a run.

const CELL = Vector2(1280, 1280) #the world's coarse cells

#a 16x16 grass map with a north-south wall of water at map column 10, open only at row 3
func walledMap() -> PackedByteArray:
	var map = PackedByteArray()
	map.resize(16 * 16)
	map.fill(Root.terrain.GRASS)
	for y in 16:
		if y != 3: map[y * 16 + 10] = Root.terrain.WATER
	return map

#world position of the middle of map cell (x, y); world (0, 0) is the corner of map cell (8, 8)
func cellMiddle(x: int, y: int) -> Vector2:
	return (Vector2(x - 8, y - 8) + Vector2(0.5, 0.5)) * CELL

func test_route_goes_round_water():
	var route = AIRoute.new(walledMap(), Vector2i(16, 16), CELL)
	var result = route.plan(cellMiddle(4, 8), cellMiddle(13, 8))
	assert_true(result.reached, "the far side is reachable through the gap")
	var throughGap = false
	for point in result.points:
		assert_false(AIRoute.isBlocked(route.terrainAt(point)), "every waypoint is on land: %s" % str(point))
		if route.terrainAt(point) == Root.terrain.GRASS && absf(point.y - cellMiddle(10, 3).y) < CELL.y: throughGap = true
	assert_true(throughGap, "the route uses the gap in row 3")
	assert_false(route.lineIsClear(cellMiddle(4, 8), cellMiddle(13, 8)), "the straight line crosses water")
	assert_true(route.lineIsClear(cellMiddle(4, 8), cellMiddle(8, 8)), "a line on grass is clear")

func test_route_to_an_island_is_partial():
	var map = walledMap()
	map[3 * 16 + 10] = Root.terrain.HILLS #close the gap: hills are walls too
	var route = AIRoute.new(map, Vector2i(16, 16), CELL)
	var result = route.plan(cellMiddle(4, 8), cellMiddle(13, 8))
	assert_false(result.reached, "nothing reaches the far side")
	assert_eq(route.terrainAt(cellMiddle(40, 8)), Root.terrain.WATER, "outside the map is water")

func test_pickup_values_follow_need():
	var fullTank = AIDriver.pickupValue("fuel", 20, 95.0, 100.0, 0.0)
	var halfTank = AIDriver.pickupValue("fuel", 20, 50.0, 100.0, 0.0)
	var runningDry = AIDriver.pickupValue("fuel", 20, 15.0, 100.0, 1.0)
	assert_gt(halfTank, fullTank, "fuel is worth more the less of it would be wasted")
	assert_gt(runningDry, halfTank, "and much more when the car is running dry")
	assert_gt(AIDriver.pickupValue("health", 20, 50.0, 30.0, 0.0), AIDriver.pickupValue("health", 20, 50.0, 95.0, 0.0), "health likewise")
	assert_gt(AIDriver.pickupValue("coin", AIDriver.PURSE_QUANTITY, 50.0, 100.0, 0.0), AIDriver.pickupValue("coin", 1, 50.0, 100.0, 0.0), "a purse beats a coin")
	assert_gt(AIDriver.goonValue(3), AIDriver.goonValue(0), "a pack is worth more than one goon")

func test_plan_keys():
	var tapLeft = {"steer":-1, "steerTicks":6, "throttle":AIDriver.Throttle.ON}
	assert_eq(AIDriver.keysFor(tapLeft, 0, 0.0, INF), AIDriver.LEFT | AIDriver.ACCEL, "a tap steers and accelerates")
	assert_eq(AIDriver.keysFor(tapLeft, 6, 0.0, INF), AIDriver.ACCEL, "then lets go of the wheel")
	assert_eq(AIDriver.keysFor(tapLeft, 0, 400.0, 300.0), AIDriver.LEFT, "no throttle above the speed cap")
	var brake = {"steer":0, "steerTicks":0, "throttle":AIDriver.Throttle.BRAKE}
	assert_eq(AIDriver.keysFor(brake, 0, 300.0, INF), AIDriver.BRAKE, "brakes while moving")
	assert_eq(AIDriver.keysFor(brake, 0, 30.0, INF), 0, "but never so long that it starts reversing")

func test_steering_ramps_and_recentres():
	var controller = load("res://scene/player/controller/playerCarController.gd")
	var wheel = 0.0
	for i in 5: wheel = controller.nextSteering(wheel, true, false, 0.1)
	assert_almost_eq(wheel, -0.5, 0.0001, "holding left turns the wheel `rate` a tick")
	wheel = controller.nextSteering(wheel, false, false, 0.1)
	assert_almost_eq(wheel, -0.5 + 0.1 * CarHandling.tune.steerReturn, 0.0001, "letting go recentres it, faster")
	wheel = controller.nextSteering(-0.1, false, true, 0.1)
	assert_almost_eq(wheel, 0.0, 0.0001, "counter-steering stops at the centre first")
	assert_almost_eq(controller.steerToward(0.0, 0.4, 1.0), 0.4, 0.0001, "a stick held part way turns the wheel part way")

func test_station_graph_shortest_first_hop():
	#0 is the goal; the car sees only 2, and 2 reaches 0 through 1
	var points = [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)]
	var edges = [
		PackedFloat32Array([INF, 100.0, INF]),
		PackedFloat32Array([100.0, INF, 100.0]),
		PackedFloat32Array([INF, 100.0, INF]),
	]
	assert_eq(AIDriver.firstHop(points, edges, PackedFloat32Array([INF, INF, 50.0])), 2, "first hop is the only visible point")
	assert_eq(AIDriver.firstHop(points, edges, PackedFloat32Array([500.0, INF, 50.0])), 2, "a long direct run loses to a shorter way round")
	assert_eq(AIDriver.firstHop(points, edges, PackedFloat32Array([150.0, INF, 50.0])), 0, "a short direct run wins")
	assert_eq(AIDriver.firstHop(points, edges, PackedFloat32Array([INF, INF, INF])), -1, "nothing visible, no hop")

#a sedan out of the tree's way: not the player, not processing
func makeCar() -> OverheadCarBody2D:
	var car = load("res://scene/car/sedan/sedan.tscn").instantiate()
	car.isPlayer = false
	car.process_mode = Node.PROCESS_MODE_DISABLED
	return add_child_autofree(car)

func test_prediction_uses_the_cars_physics_without_touching_it():
	var car = makeCar()
	car.velocity = Vector2(300, 0)
	var input = OverheadCarBody2D.CarInput.new()
	input.acceleration = 1.0
	var next = car.integrate(car.position, car.transform.x, car.velocity, input, 1.0 / 60.0)
	assert_eq(car.velocity, Vector2(300, 0), "integrate never changes the car")
	assert_gt(next[1].x, 300.0, "full throttle speeds it up")

	var driver = AIDriver.new()
	driver.car = car
	var straight = driver.simulate(AIDriver.PLANS[0], 60)
	var end: Vector2 = straight.path[straight.path.size() - 1]
	assert_gt(end.x - car.position.x, 100.0, "driving straight goes forward")
	assert_almost_eq(end.y, car.position.y, 1.0, "and stays on its line")
	var left = driver.simulate({"steer":-1, "steerTicks":AIDriver.HOLD, "throttle":AIDriver.Throttle.ON}, 60)
	var heading: Vector2 = left.headings[left.headings.size() - 1]
	assert_true(heading.angle() < -0.2, "holding left turns the nose left (negative angle): %s" % heading.angle())
	assert_between(driver.sustainableSpeed(0.3), 1.0, driver.topSpeed() - 1.0, "a part-time throttle holds less than top speed")
	var v = driver.sustainableSpeed(0.3)
	assert_almost_eq((car.drag * v * v + car.friction * v) / driver.engineForce(), 0.3, 0.001, "and that speed needs exactly that much throttle")
	driver.free()

func test_profiles_resolve_overrides():
	var crusher = AIProfiles.resolve("crusher")
	assert_eq(crusher.crushReward, AIProfiles.PROFILES.crusher.crushReward, "a profile's own value wins")
	assert_eq(crusher.hitCost, AIProfiles.DEFAULTS.hitCost, "and the rest come from DEFAULTS")
	var tweaked = AIProfiles.resolve("crusher+horizonTicks=120+recoverForward=false")
	assert_eq(tweaked.horizonTicks, 120, "overrides after + are applied")
	assert_eq(tweaked.recoverForward, false, "booleans too")
	assert_eq(AIProfiles.resolve("").size(), AIProfiles.DEFAULTS.size(), "an empty spec is the defaults")
	for profile in AIProfiles.PROFILES:
		for key in AIProfiles.PROFILES[profile]:
			assert_true(AIProfiles.DEFAULTS.has(key), "%s sets a known key: %s" % [profile, key])

#breakable props are passable for the planner when the predicted speed smashes them, walls otherwise;
#explosives never count as a way through
func test_breakables_are_passable_only_at_smash_speed():
	var fence = StaticBody2D.new()
	fence.set_meta(&"smashSpeed", 180.0)
	assert_true(AIDriver.smashableAt(fence, 250.0, 1.15), "well above its smash speed: drive through")
	assert_false(AIDriver.smashableAt(fence, 200.0, 1.15), "within the margin: a wall")
	assert_false(AIDriver.smashableAt(fence, 0.0, 1.15), "standing still: a wall")
	var barrel = StaticBody2D.new()
	barrel.set_meta(&"smashSpeed", 120.0)
	barrel.set_meta(&"explosive", true)
	assert_false(AIDriver.smashableAt(barrel, 900.0, 1.15), "an explosive is never free")
	var rock = StaticBody2D.new()
	assert_false(AIDriver.smashableAt(rock, 900.0, 1.15), "a rock is a rock")
	assert_false(AIDriver.smashableAt(null, 900.0, 1.15))
	fence.set_meta(&"smashed", true)
	assert_false(AIDriver.smashableAt(fence, 900.0, 1.15), "already smashed: its collision is off anyway")
	assert_true(AIProfiles.DEFAULTS.has("smashCost") && AIProfiles.DEFAULTS.has("smashMargin"), "tunable per profile")
	for node in [fence, barrel, rock]: node.free()

#the last legs into the station (inner marker, driveway) are taken only heading in along the gap's line,
#or slowly: side-on at speed the car would overshoot the gap and loop round the lot
func test_station_last_legs_need_the_car_lined_up():
	var car = makeCar()
	var driver = AIDriver.new()
	driver.car = car
	driver.stationGap = Vector2.RIGHT #the gap faces east: the way in is west
	driver.stationPoints = [Vector2.ZERO, Vector2(1100, 0), Vector2(2000, 0)]
	car.velocity = Vector2(-450, 0)
	car.rotation = PI #heading west, into the lot
	assert_true(driver.linedUpFor(1), "heading in along the line: go for the inner marker")
	assert_true(driver.linedUpFor(0), "and the driveway")
	car.rotation = PI / 2.0 #heading south, across the line
	car.velocity = Vector2(0, 450)
	assert_false(driver.linedUpFor(1), "side-on at speed: not yet")
	assert_true(driver.linedUpFor(2), "the outer marker is always fine")
	car.velocity = Vector2(0, 200)
	assert_true(driver.linedUpFor(1), "slow enough to turn in")
	driver.free()

#Marathon moves the station on: the approach graph built for the old one is dropped, not reused
func test_a_new_station_drops_the_old_approach_graph():
	var driver = AIDriver.new()
	var saved = Root.station
	var first = Node2D.new()
	var second = Node2D.new()
	Root.station = first
	driver.graphStation = first
	driver.stationGap = Vector2.UP
	driver.stationPoints = [Vector2.ZERO, Vector2(0, -1100), Vector2(0, -2000)]
	driver.stationEdges = [PackedFloat32Array([0.0])]
	driver.approachHop = 1
	driver.forgetStaleStation()
	assert_eq(driver.stationPoints.size(), 3, "the same station keeps its graph")
	Root.station = second
	driver.forgetStaleStation()
	assert_true(driver.stationPoints.is_empty(), "a new station: the old points are gone")
	assert_true(driver.stationEdges.is_empty(), "and the old edges")
	assert_eq(driver.approachHop, -1, "and the old hop")
	assert_eq(driver.stationGap, Vector2.RIGHT, "and the old gap")
	Root.station = saved
	for node in [driver, first, second]: node.free()
