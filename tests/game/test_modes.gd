extends GameTest

#The shared prerequisites (goon physics layer, the save's meta, explosion pooling) and the modes they
#serve: Goonpocalypse records and score, Marathon's relay, Defense's barrier, and the developer run log.
#Nothing here writes the save: SaveManager.playerData is swapped for a test copy and restored.

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

#--- goon physics layer -------------------------------------------------------------------------

func test_goons_have_their_own_layer_and_never_collide_with_each_other():
	var goon = load("res://scene/enemy/walker/walker.tscn").instantiate()
	assert_eq(goon.collision_layer & goon.collision_mask, 0, "a goon's mask doesn't include its own layer")
	assert_true(goon.collision_mask & 1 != 0, "goons still hit rocks, walls and the car")
	assert_eq(Vector2i(goon.collision_layer, goon.collision_mask), goon.savedLayers, "setSolid restores the scene's layers")
	var car = load("res://scene/car/car.tscn").instantiate()
	assert_true(car.collision_mask & goon.collision_layer != 0, "the car still meets goons, so it can crush them")
	var pickup = Root.getSpecificPowerup(Root.upgrade.COIN)
	assert_eq(pickup.get_node("Area2D").collision_mask & goon.collision_layer, 0, "pickups no longer test goons")
	for node in [goon, car, pickup]: node.free()

#--- meta ---------------------------------------------------------------------------------------

func test_migrate_adds_meta_sections_and_keeps_their_contents():
	var data = PlayerData.new()
	data.saveVersion = 3
	data.meta = {"hints": {"firstSlot": true}}
	data.cars[0].records.erase("score")
	SaveManager.playerData = data
	assert_true(SaveManager.migrate())
	for section in PlayerData.new().meta:
		assert_true(data.meta.get(section) is Dictionary, "meta.%s added" % section)
	assert_true(data.meta.hints.firstSlot, "existing meta is kept")
	assert_eq(data.cars[0].records.score, 0, "the score record is added")

#--- Goonpocalypse ------------------------------------------------------------------------------

func test_goonpocalypse_records_keep_the_best_time_and_score_separately():
	var first = SaveManager.recordGoonpocalypse(1, "van", 100, 50)
	assert_true(first.time && first.score, "the first run sets both")
	var second = SaveManager.recordGoonpocalypse(1, "van", 80, 70)
	assert_false(second.time, "a shorter run is not a time best")
	assert_true(second.score, "but its score is")
	assert_eq(SaveManager.bestGoonpocalypse(1, "van"), {"time": 100, "score": 70})
	assert_eq(SaveManager.bestGoonpocalypse(1, "sedan"), {"time": 0, "score": 0}, "per car")
	assert_eq(SaveManager.bestGoonpocalypse(2, "van"), {"time": 0, "score": 0}, "per level")
	assert_eq(SaveManager.getCarByName("van").records.time, 100, "the car's own records follow")
	assert_eq(SaveManager.getCarByName("van").records.score, 70)
	assert_true(SaveManager.playerData.meta.records.goonpocalypse.has(String(Levels.ORDER[1])), "keyed by the level's id")

func test_goonpocalypse_score_and_waves():
	assert_eq(Level.pocalypseScore(10, 2, 61.0), 10 + 10 + 30)
	Region.resetWaves()
	Region.runTime = Region.waveLength * 9.5
	Region.wave = 10 #what _process reaches by then: waves keep coming with no cap
	assert_eq(Region.waveSecondsLeft(), int(Region.waveLength * 0.5), "the run clock keeps going: no wave cap")
	assert_almost_eq(Region.waveIntensity(), 10.25, 0.001)
	Region.resetWaves()

#--- Defense ------------------------------------------------------------------------------------

func test_station_barrier_and_wall_points():
	var station = add_child_autofree(load("res://scene/level/station.tscn").instantiate())
	station.global_position = Vector2(1000, 500)
	station.damage(50)
	assert_eq(station.barrier, station.BARRIER_MAX, "no barrier outside Defense")
	station.startBarrier()
	station.damage(50)
	assert_almost_eq(station.barrier, station.BARRIER_MAX - 50 * station.SIEGE_DAMAGE, 0.01, "walls take SIEGE_DAMAGE of a blow")
	assert_gt(1.0, station.get_node("walls").self_modulate.g, "the walls redden as the barrier wears down")
	var inside = station.global_position + Vector2(10, 10)
	assert_eq(station.nearestWallPoint(inside), inside, "a goon inside the lot is already at the walls")
	var far = station.global_position + Vector2(5000, 0)
	assert_almost_eq(station.nearestWallPoint(far).x, station.global_position.x + station.LOT.end.x, 0.01, "east of the lot: its east edge")
	station.retire()
	assert_false(station.active, "a retired Marathon station's driveway does nothing")
	for wall in station.WALL_BODIES: assert_false(station.get_node(wall + "/LightOccluder2D").visible, "%s: a passed station's lot opens up (its walls stop blocking)" % wall)

#the wall bodies trace the lot (LOT) with its one gap on the east side, where the driveway is
func test_station_walls_leave_the_east_gap():
	var station = load("res://scene/level/station.tscn").instantiate()
	var walls: Array[Rect2] = []
	for body in station.get_children():
		if body is StaticBody2D && body.name.begins_with("wall"):
			var shape: CollisionShape2D = body.get_node("CollisionShape2D")
			var size: Vector2 = shape.shape.size
			walls.push_back(Rect2(body.position + shape.position - size / 2, size))
	assert_eq(walls.size(), 4)
	var lot: Rect2 = station.LOT
	for wall in walls: assert_true(lot.grow(3).encloses(wall), "every wall lies on the lot's edge")
	var blocked = func(p: Vector2) -> bool: return walls.any(func(w: Rect2): return w.has_point(p))
	var drivewayY: float = station.get_node("driveway").position.y + station.get_node("driveway/CollisionShape2D").position.y
	assert_false(blocked.call(Vector2(lot.end.x - 26, drivewayY)), "the east side is open level with the driveway")
	assert_true(blocked.call(Vector2(lot.position.x + 26, drivewayY)), "the west side is walled")
	assert_true(blocked.call(Vector2(0, lot.position.y + 26)) && blocked.call(Vector2(0, lot.end.y - 26)), "north and south are walled")
	station.free()

#--- explosion pooling --------------------------------------------------------------------------

func test_explosions_are_reused():
	var pool = add_child_autofree(ExplosionPool.new(load("res://scene/fx/explosion.tscn")))
	var first = pool.explode(Vector2(10, 20))
	assert_eq(first.global_position, Vector2(10, 20))
	assert_true(first.visible && first.is_playing())
	pool.onFinished(first)
	assert_eq(pool.explode(Vector2.ZERO), first, "a finished explosion is fired again")
	for i in ExplosionPool.MAX_LIVE + 3: pool.explode(Vector2.ZERO)
	assert_eq(pool.get_child_count(), ExplosionPool.MAX_LIVE, "never more than MAX_LIVE nodes")

#--- run log ------------------------------------------------------------------------------------

func test_run_log_writes_one_header_and_moves_old_files_aside():
	var path = "user://test_runlog.csv"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	RunLog.write({"car": "sedan", "mode": "sprint", "reason": "a,b"}, path)
	RunLog.write({"car": "van"}, path)
	var lines = FileAccess.get_file_as_string(path).strip_edges().split("\n")
	assert_eq(lines.size(), 3)
	assert_eq(lines[0], ",".join(RunLog.COLUMNS))
	assert_eq(lines[1].split(",").size(), RunLog.COLUMNS.size(), "commas in a value don't add columns")
	DirAccess.remove_absolute(path)
