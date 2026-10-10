extends GameTest

#Fixed courses and the featured modes built on them (Course, BountyHunt, Modes; GAMEPLAY_SUGGESTIONS package 18):
#the seed and checkpoint rules, the record book and what a Trial switches off. Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

const M = Root.gameModes

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func test_a_course_has_one_seed_per_level_and_mode():
	var seed := Course.seedFor(&"prairie", M.RALLY)
	assert_eq(seed, Course.seedFor(&"prairie", M.RALLY), "the same every time")
	assert_true(seed >= 0, "a seed the generator takes")
	assert_true(seed != Course.seedFor(&"mudlick", M.RALLY), "another level, another course")
	assert_true(seed != Course.seedFor(&"prairie", M.HOTLAP), "another mode, another course")

func test_checkpoints_follow_the_route():
	var route := PackedVector2Array([Vector2.ZERO, Vector2(12000, 0), Vector2(12000, 9000)])
	var points := Course.checkpointsOn(route, 5000.0)
	assert_eq(points.size(), 3, "one every 5,000 px, none within half a gap of the finish")
	assert_eq(points[0], Vector2(5000, 0))
	assert_eq(points[1], Vector2(10000, 0))
	assert_eq(points[2], Vector2(12000, 3000), "round the corner")
	assert_eq(Course.checkpointsOn(PackedVector2Array([Vector2.ZERO, Vector2(3000, 0)]), 5000.0).size(), 0, "a short route has none")
	assert_eq(Course.checkpointsOn(PackedVector2Array(), 5000.0).size(), 0)

func test_the_stage_clock_reads_tenths():
	assert_eq(Course.clock(83.44), "1:23.4")
	assert_eq(Course.clock(0.0), "0:00.0")
	assert_eq(Course.clock(59.96), "1:00.0")

func test_the_record_book_keeps_each_cars_best():
	assert_true(SaveManager.bestCourse(0, M.RALLY, "sedan").is_empty(), "no record to start with")
	assert_true(SaveManager.recordCourse(0, M.RALLY, "sedan", 90.0, [30.0, 60.0]).time, "a first run is a best")
	assert_false(SaveManager.recordCourse(0, M.RALLY, "sedan", 95.0, [31.0, 62.0]).time, "a slower one isn't")
	assert_eq(SaveManager.bestCourse(0, M.RALLY, "sedan").time, 90.0)
	assert_true(SaveManager.recordCourse(0, M.RALLY, "sedan", 85.5, [29.0, 58.0]).time)
	var best := SaveManager.bestCourse(0, M.RALLY, "sedan")
	assert_eq(best.splits, [29.0, 58.0], "with its splits")
	assert_eq(best.version, Course.VERSION)
	assert_true(SaveManager.bestCourse(0, M.RALLY, "van").is_empty(), "per car")
	assert_true(SaveManager.bestCourse(1, M.RALLY, "sedan").is_empty(), "per level")
	best.version = Course.VERSION - 1 #the course changed since
	assert_true(SaveManager.recordCourse(0, M.RALLY, "sedan", 120.0, []).time, "a record from an older course is replaced")

func test_a_trial_has_no_goons_drops_or_night():
	for mode in Modes.inCategory(Modes.Category.TRIAL):
		assert_false(Modes.hasGoons(mode), "%s has no goons" % M.find_key(mode))
		assert_true(Modes.isFixedMap(mode), "%s drives a fixed course" % M.find_key(mode))
		assert_true(Modes.drops(mode) != Modes.Drops.ALL, "%s rolls no drops" % M.find_key(mode))
		assert_false(Modes.fillsBoxes(mode))
	for mode in [M.GOONCRUSHER, M.SPRINT, M.BOUNTY, M.BLACKOUT]:
		assert_true(Modes.hasGoons(mode) && Modes.drops(mode) == Modes.Drops.ALL && not Modes.isTrial(mode), "%s is a Crusher mode" % M.find_key(mode))
	assert_eq(Modes.plays(M.RALLY), M.SPRINT, "a Rally Stage runs on Sprint's rules: the station is its finish")
	assert_eq(Level.timeUpCondition(M.RALLY), Root.endCondition.NOTIME, "and its clock loses it")
	assert_eq(Level.timeUpCondition(M.BOUNTY), Root.endCondition.NOTIME, "so does a Bounty Hunt's")
	assert_eq(Level.timeUpCondition(M.BLACKOUT), Root.endCondition.SUCCESS, "a Blackout is won at dawn")

func test_bounty_and_rally_tiers_ask_more():
	for tier in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.BOUNTY_MARKS[tier + 1], ModeTiers.BOUNTY_MARKS[tier], "more marks")
		assert_gt(ModeTiers.BOUNTY_MARK_SECONDS[tier], ModeTiers.BOUNTY_MARK_SECONDS[tier + 1], "less time for each")
		assert_gt(ModeTiers.RALLY_SLACK[tier], ModeTiers.RALLY_SLACK[tier + 1], "a tighter stage clock")
	assert_eq(ModeTiers.bountySeconds(ModeTiers.EASY), 240.0)
	assert_true(ModeTiers.goalText(M.RALLY, ModeTiers.HARD, 300.0).contains("gold"))

func test_the_cone_course_fits_its_lot():
	var gates := ConeCourse.layout(Vector2.ZERO)
	assert_eq(gates.size(), ConeCourse.LANES.size() * ConeCourse.PER_LANE)
	var lot := Rect2(WorldGen.LOT_RECT)
	for gate in gates:
		for side in [-1.0, 1.0]: assert_true(lot.has_point(gate + Vector2(0.0, ConeCourse.GATE_HALF * side)), "a cone at %s is on the lot" % gate)
	assert_true(lot.has_point(ConeCourse.START), "the car starts on it too")
	assert_gt(ConeCourse.GATE_HALF, ConeCourse.PASS_RADIUS, "the car has to go between the cones")
	assert_gt(gates[1].x, gates[0].x, "the first lane runs east")
	assert_gt(gates[ConeCourse.PER_LANE].x, gates[ConeCourse.PER_LANE + 1].x, "the second comes back")

func test_score_trials_have_a_target_and_a_clock():
	for tier in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.trialTarget(M.SMASH, tier + 1), ModeTiers.trialTarget(M.SMASH, tier), "more to smash")
		assert_gt(ModeTiers.trialTarget(M.DRIFT, tier + 1), ModeTiers.trialTarget(M.DRIFT, tier), "a higher drift score")
		assert_gt(ModeTiers.CONES_SECONDS[tier], ModeTiers.CONES_SECONDS[tier + 1], "less time for the gates")
	for mode in [M.SMASH, M.DRIFT, M.CONES]:
		assert_true(Root.isModeAvailable(mode), "%s is built" % M.find_key(mode))
		assert_eq(Level.timeUpCondition(mode), Root.endCondition.NOTIME, "%s is lost on the clock" % M.find_key(mode))

func test_the_rivals_are_the_garages_other_drivers():
	var ids: Array = SaveManager.playerData.cars.map(func(c): return str(c.name))
	var field := Rivals.lineup(ids[0], Rivals.COUNT)
	assert_eq(field.size(), Rivals.COUNT)
	assert_false(ids[0] in field, "never the player's own car")
	assert_eq(field[0], ids[1], "the next cars in the garage, in order")
	assert_eq(Rivals.lineup(ids[ids.size() - 1], 2), [ids[0], ids[1]], "wrapping round")
	assert_eq(Rivals.placeWord(1), "1ST")
	assert_eq(Rivals.placeWord(3), "3RD")
	for tier in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.CUP_PLACE[tier], ModeTiers.CUP_PLACE[tier + 1], "a better place on a harder tier")
		assert_gt(Rivals.PACE[tier + 1], Rivals.PACE[tier], "against a quicker field")
	assert_true(Modes.hasRivals(M.CANNONBALL) && Modes.lightGoons(M.CANNONBALL))
	assert_false(Modes.hasRivals(M.SPRINT))

func test_a_mode_only_hands_out_pickups_that_are_useful_there():
	assert_true(Modes.allowsKind(M.GOONCRUSHER, "casino"), "a Crusher mode rolls everything")
	assert_true(Modes.allowsKind(M.CANNONBALL, "boost") && Modes.allowsKind(M.CANNONBALL, "supply"), "a race keeps boosts, fuel and repairs")
	assert_false(Modes.allowsKind(M.CANNONBALL, "casino"), "but no prize games")
	assert_false(Modes.allowsKind(M.RALLY, "boost"), "a mode with no pickups has none")
	assert_false(Pickups.allowedIn("slotmachine", M.CANNONBALL))
	assert_true(Pickups.allowedIn("coin", M.CANNONBALL), "the plain coin is always there to fall back on")

func test_pursuit_and_the_cup_ask_more_on_harder_tiers():
	for tier in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.CUP_HOLD[tier + 1], ModeTiers.CUP_HOLD[tier], "a longer hold")
		assert_gt(ModeTiers.RUNNER_HEALTH[tier + 1], ModeTiers.RUNNER_HEALTH[tier], "a tougher runner")
		assert_gt(ModeTiers.RUNNER_START[tier + 1], ModeTiers.RUNNER_START[tier], "a longer lead")
		assert_gt(ModeTiers.RUNNER_PACE[tier + 1], ModeTiers.RUNNER_PACE[tier], "a quicker one")
	assert_true(ModeTiers.RUNNER_PACE[ModeTiers.HARD] < 1.0, "the runner is never quicker than the player's car")
	assert_true(KeepCup.HOLDER_PACE < 1.0, "the holder can always be caught")
	assert_gt(KeepCup.STEAL_PX, KeepCup.PICK_PX)
	for mode in [M.PURSUIT, M.KEEPCUP]: assert_true(Modes.hasRivals(mode) && Root.isModeAvailable(mode), "%s is built, with rivals" % M.find_key(mode))
	assert_eq(Modes.plays(M.PURSUIT), M.SPRINT, "the runner makes for the station")

#a stand-in for the world's routes: every pair of points connects by a straight line
class FlatMap:
	func routeBetween(a: Vector2, b: Vector2) -> Dictionary:
		return {"points": PackedVector2Array([a, b]), "length": a.distance_to(b), "reached": true}

class NoRoutes:
	func routeBetween(a: Vector2, b: Vector2) -> Dictionary:
		return {"points": PackedVector2Array([a]), "length": a.distance_to(b), "reached": false}

func test_a_loop_comes_back_to_the_start():
	var loop := Course.loopRoute(FlatMap.new(), Vector2(100, 100), 5000.0)
	assert_false(loop.is_empty())
	assert_eq(loop.route[0], Vector2(100, 100), "out from the start")
	assert_eq(loop.route[loop.route.size() - 1], Vector2(100, 100), "and back to it")
	assert_true(absf(loop.length - 15000.0) < 1.0, "three legs of 5,000 px: an equilateral loop")
	assert_true(Course.loopRoute(NoRoutes.new(), Vector2.ZERO).is_empty(), "no loop where the legs don't connect")

func test_every_mode_of_the_menu_is_built():
	for mode in M.values(): assert_true(Root.isModeAvailable(mode), "%s can be played" % M.find_key(mode))
	for i in Levels.count(): assert_eq(Root.roadModes(i), Root.featuredModes(i), "%s: all three featured modes open the road" % Levels.ORDER[i])
	for mode in [M.CIRCUIT, M.KNOCKOUT, M.DERBY]: assert_true(Modes.hasRivals(mode) && not Modes.hasGoons(mode), "%s: rivals and no goons" % M.find_key(mode))
	for tier in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.HOTLAP_SLACK[tier], ModeTiers.HOTLAP_SLACK[tier + 1], "a quicker lap to beat")
		assert_gt(ModeTiers.FLATOUT_SLACK[tier], ModeTiers.FLATOUT_SLACK[tier + 1])
		assert_gt(ModeTiers.DERBY_HEALTH[tier + 1], ModeTiers.DERBY_HEALTH[tier], "tougher rivals")
	assert_gt(Derby.RADIUS, Derby.RING * 2.0, "the cars start well inside the line")
	for pad in Derby.PADS:
		assert_true(pad[0] < Derby.RADIUS, "a pickup lies inside the line")
		assert_true(Pickups.has(pad[1]), "%s is a pickup" % pad[1])

func test_a_car_hit_is_about_speed_and_where_it_lands_not_armor():
	var car := OverheadCarBody2D
	assert_eq(car.bumpShare(0.0, Vector2.RIGHT), car.CAR_NOSE_SHARE, "struck on the nose: most of it shrugged off")
	assert_eq(car.bumpShare(0.0, Vector2.UP), 1.0, "on the flank: all of it")
	assert_eq(car.bumpShare(0.0, Vector2.LEFT), 1.0, "on the tail too")
	assert_eq(car.bumpShare(PI / 2.0, Vector2.DOWN), car.CAR_NOSE_SHARE, "whichever way it faces")
	assert_true(car.CAR_WEIGHT_POWER < 0.5, "weight counts for little of the damage")
	var heavy := pow(2.8 / 1.4, car.CAR_WEIGHT_POWER) #a semi against a racer
	assert_true(heavy < 1.25, "a car twice the weight takes under a quarter less (x%.2f the other way)" % heavy)

func test_a_race_starts_abreast_not_nose_to_tail():
	var seen := [Vector2.ZERO]
	for n in range(1, Rivals.COUNT + 1):
		var spot := Rivals.gridSlot(n, 0, Vector2.ZERO, Vector2.RIGHT)
		assert_eq(spot.x, 0.0, "rival %d starts on the line, not behind it" % n)
		for other in seen: assert_true(spot.distance_to(other) >= Rivals.LINE_GAP - 0.01, "with room beside the next car")
		seen.push_back(spot)
	assert_true(Rivals.gridSlot(1, 0, Vector2.ZERO, Vector2.RIGHT).y * Rivals.gridSlot(2, 0, Vector2.ZERO, Vector2.RIGHT).y < 0.0, "either side of the player")
	assert_eq(Rivals.gridSlot(1, 1, Vector2.ZERO, Vector2.RIGHT).x, -Rivals.LINE_BACK, "a blocked slot moves a line back")
