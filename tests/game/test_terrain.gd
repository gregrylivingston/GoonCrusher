extends GameTest

#The world map (scripts/world/world_map.gd, docs/WORLD.md): 96 x 96 chunks, chunk (0,0) at map cell
#(48,48), a coarse grid of 1280 px cells (384 x 192) with a district per passable cell, and fine rasters of
#128 px cells per chunk. test_world_gen.gd checks the generator's guarantees over every level and seed.

var map: WorldMap

func before_each():
	if map == null: map = WorldMap.build(1337, Levels.get_def(&"prairie"))

func test_sizes_and_coordinates():
	assert_eq(map.terrain.size(), 384 * 192, "384 x 192 coarse cells")
	assert_eq(map.flags.size(), map.terrain.size())
	assert_eq(map.district.size(), map.terrain.size())
	assert_eq(WorldGen.chunkCell(Vector2i(0, 0)), Vector2i(192, 96), "chunk (0,0) is map chunk (48,48), coarse cell (192,96)")
	assert_eq(map.coarseCell(Vector2(0, 0)), Vector2i(192, 96))
	assert_eq(map.coarseCell(Vector2(-1, -1)), Vector2i(191, 95))
	assert_eq(WorldGen.chunkOf(Vector2(5119, 2559)), Vector2i(0, 0))
	assert_eq(WorldGen.chunkOf(Vector2(-1, 0)), Vector2i(-1, 0), "chunks use floor")
	assert_true(WorldMap.chunkInMap(Vector2i(-48, 47)), "chunks -48..47 are on the map")
	assert_false(WorldMap.chunkInMap(Vector2i(48, 0)))
	assert_false(WorldMap.chunkInMap(Vector2i(0, -49)))

func test_outside_the_map_is_water():
	assert_eq(map.terrainAt(Vector2(400000, 0)), Root.terrain.WATER)
	assert_true(map.lethalAt(Vector2(0, -200000)))
	assert_eq(map.chunkTile(Vector2i(60, 0)).terrain, Root.terrain.WATER)
	assert_eq(map.chunkTile(Vector2i(60, 0)).region, -2)
	assert_eq(map.districtAt(Vector2(400000, 0)), -1)

func test_every_passable_cell_has_a_district():
	for i in map.terrain.size():
		var passable := map.flags[i] & WorldGen.BLOCKED == 0
		if passable != (map.district[i] >= 0):
			fail("cell %d: blocked=%s but district %d" % [i, not passable, map.district[i]])
			return
		if passable != World.isPassable(map.terrain[i]):
			fail("cell %d: flags and terrain %d disagree about passability" % [i, map.terrain[i]])
			return
	assert_true(map.districts.size() >= 40, "about 72 districts of ~40,000 px on a 96 x 96 chunk map (%d)" % map.districts.size())

func test_start_is_the_main_ground_and_open():
	var start := Levels.get_def(&"prairie").startPosition
	assert_eq(map.coarseTerrainAt(start), Root.terrain.GRASS, "the prairie starts on grass")
	assert_true(map.district[map.coarseIndex(start)] >= 0)
	assert_true(map.flags[map.coarseIndex(start)] & WorldGen.START != 0, "the start is in its own component")

func test_fine_rasters_take_over_from_the_coarse_map():
	var start := Levels.get_def(&"prairie").startPosition
	var chunk := WorldGen.chunkOf(start)
	map.buildNow(chunk)
	assert_true(map.fine.has(chunk), "the start chunk's raster is cached")
	var raster: Dictionary = map.rasters[chunk]
	assert_eq(raster.terrain.size(), 40 * 20, "40 x 20 cells of 128 px")
	assert_eq(raster.water.size(), 42 * 22, "fields carry a one-cell apron")
	assert_eq(map.terrainAt(start), raster.terrain[(floori(start.y / 128.0) - chunk.y * 20) * 40 + floori(start.x / 128.0) - chunk.x * 40])
	assert_eq(map.surfaceAt(start), Root.terrain.GRASS)
	assert_false(map.lethalAt(start))
	assert_true(map.spawnableAt(start))

func test_lru_keeps_the_cars_chunks():
	var lru := WorldMap.build(5, Levels.get_def(&"prairie"))
	lru.setKeep([Vector2i(0, 0)])
	lru.buildNow(Vector2i(0, 0))
	for k in WorldMap.LRU + 5: lru.buildNow(Vector2i(k - 10, 3))
	assert_eq(lru.fine.size(), WorldMap.LRU, "at most LRU rasters")
	assert_true(lru.fine.has(Vector2i(0, 0)), "a kept chunk is never evicted")
	assert_false(lru.fine.has(Vector2i(-10, 3)), "the oldest went first")

func test_rasters_build_on_the_worker_pool():
	var pooled := WorldMap.build(9, Levels.get_def(&"bayou"))
	pooled.request(Vector2i(1, 1))
	pooled.request(Vector2i(2, 1))
	assert_true(pooled.pending.has(Vector2i(1, 1)), "queued")
	pooled.ensure(Vector2i(1, 1)) #waits for its task
	assert_true(pooled.fine.has(Vector2i(1, 1)))
	pooled.shutdown()
	assert_true(pooled.pending.is_empty(), "shutdown waits for every task")
	var direct := WorldMap.build(9, Levels.get_def(&"bayou"))
	direct.buildNow(Vector2i(1, 1))
	assert_eq(pooled.fine[Vector2i(1, 1)], direct.fine[Vector2i(1, 1)], "a worker raster matches one built in place")

func test_chunk_tiles_map_new_surfaces_to_old_scenes():
	var city := WorldMap.build(3, Levels.get_def(&"city"))
	for x in range(-6, 7):
		for y in range(-6, 7):
			var t: int = city.chunkTile(Vector2i(x, y)).terrain
			assert_true(t >= 0 && t <= 7, "chunk scenes are the 8 old landscape maps (%d)" % t)
