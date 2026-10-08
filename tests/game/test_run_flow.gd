extends GameTest

#Run flow (GAMEPLAY_SUGGESTIONS T0-2..T0-5): objectives are placed on land inside the map, the
#Sprint clock comes from the station distance, a run ends once, and the clock ends the run.

var timerScript = load("res://scene/player/Timer.gd")
const NO_CHUNK = WorldGen.NO_CHUNK

#a coarse flag map: all open and reachable (START) unless `blocked` says otherwise
func openFlags() -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(WorldGen.W * WorldGen.H)
	flags.fill(WorldGen.START)
	return flags

func test_objectives_land_on_reachable_ground_inside_the_map():
	for levelId in [&"prairie", &"bayou", &"canyon", &"city"]:
		var map := WorldMap.build(42, Levels.get_def(levelId))
		for desired in [Vector2i(9, 0), Vector2i(19, -4), Vector2i(875, 250), Vector2i(-500, -500), Vector2i(0, 0), Vector2i(30, 30), Vector2i(-40, 20)]:
			var chunk := map.findStationChunk(desired, Vector2i.ZERO)
			assert_true(WorldGen.stationCoreOk(map.flags, chunk, true), "%s %s: the station's cells are open and reachable (%s)" % [levelId, desired, chunk])
			assert_true(absi(chunk.x) <= WorldGen.CHUNK_LIMIT && absi(chunk.y) <= WorldGen.CHUNK_LIMIT, "%s %s: inside the map (%s)" % [levelId, desired, chunk])
			assert_true(chunk != Vector2i.ZERO, "%s %s: never the forbidden chunk" % [levelId, desired])

func test_objective_placement_is_deterministic():
	var a := WorldMap.build(1337, Levels.get_def(&"canyon"))
	var b := WorldMap.build(1337, Levels.get_def(&"canyon"))
	for desired in [Vector2i(9, 2), Vector2i(875, -250), Vector2i(-40, 33)]:
		assert_eq(a.findStationChunk(desired, NO_CHUNK), b.findStationChunk(desired, NO_CHUNK), "same map, same chunk for %s" % desired)

func test_station_search_prefers_a_clear_lot():
	var flags := openFlags()
	assert_eq(WorldGen.findStationChunk(flags, Vector2i(3, 2), NO_CHUNK).chunk, Vector2i(3, 2), "open ground: the desired chunk")
	assert_true(WorldGen.findStationChunk(flags, Vector2i(3, 2), NO_CHUNK).clear)
	assert_eq(WorldGen.findStationChunk(flags, Vector2i(3, 2), Vector2i(3, 2)).chunk.distance_to(Vector2i(3, 2)), 1.0, "the forbidden chunk is skipped for a neighbour")
	assert_eq(WorldGen.findStationChunk(flags, Vector2i(900, 0), NO_CHUNK).chunk, Vector2i(WorldGen.CHUNK_LIMIT, 0), "far-off chunks are clamped into the map first")
	#a barrier through the lot's approach: the desired chunk's centre is open but its lot is not
	var c := WorldGen.chunkCell(Vector2i(3, 2))
	flags[(c.y + 1) * WorldGen.W + c.x + 4] = WorldGen.BLOCKED
	var found := WorldGen.findStationChunk(flags, Vector2i(3, 2), NO_CHUNK)
	assert_true(found.clear, "a chunk with a clear lot is found nearby")
	assert_true(found.chunk != Vector2i(3, 2), "and preferred over the blocked lot")
	#unreachable ground (no START) is never used
	var island := openFlags()
	for i in island.size(): island[i] = 0
	var picked := WorldGen.findStationChunk(island, Vector2i(3, 2), NO_CHUNK)
	assert_false(picked.clear, "nothing reachable: no clear lot")

#a chunk where no station can stand: its four centre cells (WorldGen.stationCoreOk) blocked
func blockCore(flags: PackedByteArray, chunk: Vector2i) -> void:
	var c := WorldGen.chunkCell(chunk) + Vector2i(1, 0)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cell: Vector2i = c + d
		if WorldGen.inMap(cell): flags[cell.y * WorldGen.W + cell.x] = WorldGen.BLOCKED

func test_a_station_is_never_placed_much_nearer_than_asked():
	var flags := openFlags()
	for x in range(6, 13): #a band of chunks where nothing can stand, from 6 to 12 chunks out
		for y in range(-WorldGen.CHUNK_LIMIT, WorldGen.CHUNK_LIMIT + 1): blockCore(flags, Vector2i(x, y))
	var desired := Vector2i(8, 0)
	var near: Vector2i = WorldGen.findStationChunk(flags, desired, NO_CHUNK).chunk
	assert_eq(near, Vector2i(5, 0), "without an origin the nearest good chunk wins, even back toward the start")
	var far: Vector2i = WorldGen.findStationChunk(flags, desired, NO_CHUNK, true, Vector2i.ZERO).chunk
	assert_true(Vector2(far).length() >= 8.0 * WorldGen.STATION_MIN_SHARE, "from the start it stays at least 85%% as far (%s)" % far)
	assert_true(WorldGen.stationCoreOk(flags, far, true), "on good ground")
	var only: Vector2i = WorldGen.findStationChunk(openOnly(Vector2i(2, 0)), desired, NO_CHUNK, true, Vector2i.ZERO).chunk
	assert_eq(only, Vector2i(2, 0), "when nothing far enough is good, the nearest good chunk still gets the station")

#every cell blocked but one chunk's station core
func openOnly(chunk: Vector2i) -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(WorldGen.W * WorldGen.H)
	flags.fill(WorldGen.BLOCKED)
	var c := WorldGen.chunkCell(chunk) + Vector2i(1, 0)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cell: Vector2i = c + d
		flags[cell.y * WorldGen.W + cell.x] = WorldGen.START
	return flags

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
	for levelSeconds in [250, 300, 330, 340, 370, 380, 420, 460, 470, 500, 540]:
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
