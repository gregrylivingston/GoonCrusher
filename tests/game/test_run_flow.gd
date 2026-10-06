extends GameTest

#Run flow (GAMEPLAY_SUGGESTIONS T0-2..T0-5): objectives are placed on land inside the map, the
#Sprint clock comes from the station distance, a run ends once, and the clock ends the run.

var tileManagerScript = load("res://scene/level/tileManager.gd")
var timerScript = load("res://scene/player/Timer.gd")
const NO_CHUNK = Vector2i(-99999, -99999)

func makeMap(mapSeed: int) -> landscapeGenerator:
	var generator = landscapeGenerator.new()
	generator.inputSizeX = 256
	generator.inputSizeY = 256
	generator.inputNoiseType = 4
	generator.inputSeed = mapSeed
	add_child_autofree(generator)
	seed(mapSeed)
	await generator.createNewTerrain()
	return generator

func find(generator: landscapeGenerator, desired: Vector2i, forbidden := NO_CHUNK) -> Vector2i:
	return tileManagerScript.findObjectiveChunk(generator.terrainMap, Vector2i(256, 256), desired, forbidden, 100)

func terrainOf(generator: landscapeGenerator, chunk: Vector2i) -> int:
	return generator.cellAt(chunk.x + 128, chunk.y + 128).terrain

func test_objectives_land_on_land_inside_the_map():
	var desiredChunks = [Vector2i(9, 0), Vector2i(19, -4), Vector2i(875, 250), Vector2i(-500, -500),
		Vector2i(100, 100), Vector2i(-128, 127), Vector2i(0, 0), Vector2i(60, -90)]
	for x in range(-120, 121, 15):
		for y in range(-120, 121, 20): desiredChunks.push_back(Vector2i(x, y))
	for mapSeed in [1337, 42, 7]:
		var generator = await makeMap(mapSeed)
		for desired in desiredChunks:
			var chunk = find(generator, desired, Vector2i.ZERO)
			var terrain = terrainOf(generator, chunk)
			if terrain == Root.terrain.WATER || terrain == Root.terrain.HILLS:
				fail("seed %d: %s placed on terrain %d at %s" % [mapSeed, desired, terrain, chunk])
			if absi(chunk.x) > 100 || absi(chunk.y) > 100: fail("seed %d: %s placed outside the map at %s" % [mapSeed, desired, chunk])
			if chunk == Vector2i.ZERO: fail("seed %d: %s placed on the forbidden start chunk" % [mapSeed, desired])

func test_objective_placement_is_deterministic_and_keeps_good_chunks():
	var a = await makeMap(1337)
	var b = await makeMap(1337)
	assert_eq(a.terrainMap, b.terrainMap, "same seed, same map")
	for desired in [Vector2i(9, 2), Vector2i(875, -250), Vector2i(-40, 33)]:
		assert_eq(find(a, desired), find(b, desired), "same map, same chunk for %s" % desired)
		assert_eq(find(a, desired), find(a, desired), "repeatable for %s" % desired)
	#the start chunk is grass with grass all round, so it is kept when it is not forbidden (Defense)
	assert_eq(find(a, Vector2i.ZERO), Vector2i.ZERO, "Defense keeps the start chunk")
	assert_true(find(a, Vector2i.ZERO, Vector2i.ZERO) != Vector2i.ZERO, "Sprint never gets the start chunk")

func test_objective_search_prefers_land_neighbours():
	#an 8x8 map of water with a lone sand cell next to the desired chunk and a 3x3 grass block further out
	var size = Vector2i(8, 8)
	var terrain := PackedByteArray()
	terrain.resize(size.x * size.y)
	terrain.fill(Root.terrain.WATER)
	var setCell = func(chunk: Vector2i, type: int): terrain[(chunk.y + 4) * size.x + chunk.x + 4] = type
	setCell.call(Vector2i(-2, 0), Root.terrain.SAND)
	for y in range(-1, 2):
		for x in range(1, 4): setCell.call(Vector2i(x, y), Root.terrain.GRASS)
	setCell.call(Vector2i(-3, -3), Root.terrain.HILLS)
	assert_eq(tileManagerScript.findObjectiveChunk(terrain, size, Vector2i(-1, 0), NO_CHUNK, 100), Vector2i(2, 0),
		"the grass block's centre (land all round) beats the closer lone sand cell")
	assert_eq(tileManagerScript.findObjectiveChunk(terrain, size, Vector2i(50, 0), NO_CHUNK, 100), Vector2i(2, 0),
		"far-off chunks are clamped into the map first")
	assert_eq(tileManagerScript.findObjectiveChunk(terrain, size, Vector2i(2, 0), Vector2i(2, 0), 100), Vector2i(2, -1),
		"the forbidden chunk is skipped")
	for y in range(-1, 2):
		for x in range(1, 4): setCell.call(Vector2i(x, y), Root.terrain.WATER)
	assert_eq(tileManagerScript.findObjectiveChunk(terrain, size, Vector2i(-3, -3), NO_CHUNK, 100), Vector2i(-2, 0),
		"hills are never chosen; with no well-surrounded chunk the closest land wins")

func test_sprint_distance_and_clock():
	assert_almost_eq(Level.sprintSlack(250), 1.5, 0.0001, "Easy")
	assert_almost_eq(Level.sprintSlack(540), 1.1, 0.0001, "Northern Wastes")
	assert_almost_eq(Level.sprintSlack(395), 1.3, 0.0001, "half way")
	assert_almost_eq(Level.sprintSlack(100), 1.5, 0.0001, "clamped high")
	assert_almost_eq(Level.sprintSlack(900), 1.1, 0.0001, "clamped low")
	var offset: Vector2 = Level.sprintOffsetPx(250, 0.0)
	assert_almost_eq(offset.x, 250 * 0.25 * 450.0, 0.01, "62.5 s at 450 px/s")
	assert_almost_eq(offset.y, 0.0, 0.01)
	assert_almost_eq(Level.sprintOffsetPx(250, 1.0).y, 28125.0 * 0.25, 0.01, "y spread is 25% of the distance")
	assert_almost_eq(Level.sprintOffsetPx(250, -5.0).y, -28125.0 * 0.25, 0.01, "y roll is clamped")
	assert_almost_eq(Level.sprintOffsetPx(540, 0.0).length(), Level.SPRINT_MAX_DISTANCE, 0.01, "long levels are capped")
	assert_almost_eq(Level.sprintSeconds(28125.0, 250), 93.75, 0.001, "Easy: 62.5 s of driving x 1.5")
	assert_almost_eq(Level.sprintSeconds(32000.0, 540), 32000.0 / 450.0 * 1.1, 0.001, "Northern Wastes: capped distance x 1.1")
	#the stock sedan: top speed about 499 px/s on sand and mud, about 87 s of fuel at full throttle
	const SEDAN_SLOWEST_TOP_SPEED = 499.0
	const SEDAN_TANK_SECONDS = 87.0
	for levelSeconds in [250, 330, 370, 420, 470, 540]:
		for yRoll in [-1.0, 0.0, 1.0]:
			var distance = Level.sprintOffsetPx(levelSeconds, yRoll).length()
			var clock = Level.sprintSeconds(distance, levelSeconds)
			assert_true(distance <= Level.SPRINT_MAX_DISTANCE + 0.01, "level %d: capped" % levelSeconds)
			#a station exactly where it was aimed always leaves more time than the reference drive needs
			assert_gt(clock, distance / Level.REFERENCE_SPEED, "level %d" % levelSeconds)
			assert_gt(SEDAN_SLOWEST_TOP_SPEED, distance / clock, "level %d: the sedan is fast enough even on sand" % levelSeconds)
			assert_gt(SEDAN_TANK_SECONDS * 0.8, distance / SEDAN_SLOWEST_TOP_SPEED, "level %d: one tank is enough" % levelSeconds)

func test_clock_end_conditions_and_display():
	assert_eq(Level.timeUpCondition(Root.gameModes.GOONCRUSHER), Root.endCondition.SUCCESS, "Countdown is won at 0")
	assert_eq(Level.timeUpCondition(Root.gameModes.SPRINT), Root.endCondition.NOTIME)
	assert_eq(Level.timeUpCondition(Root.gameModes.MARATHON), Root.endCondition.NOTIME)
	assert_eq(Level.timeUpCondition(Root.gameModes.DEFENSE), Root.endCondition.SUCCESS, "Defense is won by holding out")
	assert_eq(Level.timeUpCondition(Root.gameModes.DEFENSE, true), Root.endCondition.NOHEALTH)
	assert_eq(Level.timeUpCondition(Root.gameModes.GOONCRUSHER, true), Root.endCondition.NOHEALTH, "a wrecked car has not survived Countdown")
	assert_eq(Level.timeUpCondition(Root.gameModes.SPRINT, true), Root.endCondition.NOTIME)
	assert_eq(timerScript.formatClock(0), "0 : 00")
	assert_eq(timerScript.formatClock(65), "1 : 05")
	assert_eq(timerScript.formatClock(250), "4 : 10")
	assert_eq(timerScript.formatClock(-5), "0 : 00", "never below 0:00")

func test_end_level_runs_once():
	var level = Level.new()
	level.hasEnded = true
	level.endReason = Root.endCondition.NOGAS
	level.endLevel(true, Root.endCondition.SUCCESS) #would need the level's children if it ran
	assert_eq(level.endReason, Root.endCondition.NOGAS, "the first ending stands")
	assert_eq(level.get_child_count(), 0, "no second summary")
	assert_false(get_tree().paused)
	level.free()
