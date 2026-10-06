extends GameTest

#The terrain map is built on a worker thread into packed arrays. The same seed must give the same
#map, every land cell must get a region, and the start area must be region 0 grass.

func makeGenerator(mapSeed: int) -> landscapeGenerator:
	var generator = landscapeGenerator.new()
	generator.inputSizeX = 256
	generator.inputSizeY = 256
	generator.inputNoiseType = 4
	generator.inputSeed = mapSeed
	return add_child_autofree(generator)

func test_map_is_deterministic_and_fully_labelled():
	seed(7)
	var a = makeGenerator(1337)
	await a.createNewTerrain()
	seed(7)
	var b = makeGenerator(1337)
	await b.createNewTerrain()
	assert_eq(a.terrainMap, b.terrainMap, "same seed, same terrain")
	assert_eq(a.regionMap, b.regionMap, "same seed, same regions")
	assert_eq(a.terrainMap.size(), 256 * 256)
	assert_eq(a.regionMap.find(-1), -1, "every land cell has a region")
	var centre = a.cellAt(128, 128)
	assert_eq(centre.terrain, Root.terrain.GRASS, "the start cell is grass")
	assert_eq(centre.region, 0, "the start cell is region 0")
	for i in a.terrainMap.size():
		var noRegion = not World.isPassable(a.terrainMap[i])
		if noRegion != (a.regionMap[i] == -2):
			fail("cell %d: terrain %d has region %d" % [i, a.terrainMap[i], a.regionMap[i]])
			break
	assert_eq(a.cellAt(-1, 5).terrain, Root.terrain.WATER, "outside the map is water")
	assert_eq(a.cellAt(256, 5).region, -2)

func test_neighbouring_cells_of_one_terrain_share_a_region():
	var generator = makeGenerator(42)
	await generator.createNewTerrain()
	var width = generator.inputSizeX
	for i in generator.terrainMap.size():
		if generator.regionMap[i] < 0: continue
		for next in [i + 1, i + width]:
			if next >= generator.terrainMap.size() || (next == i + 1 && next % width == 0): continue
			if generator.terrainMap[next] == generator.terrainMap[i] && generator.regionMap[next] != generator.regionMap[i]:
				fail("cells %d and %d are both terrain %d but in regions %d and %d" % [i, next, generator.terrainMap[i], generator.regionMap[i], generator.regionMap[next]])
				return
