extends GameTest

#The world generator's guarantees (scripts/world/world_gen.gd, docs/WORLD.md), for every level over SEEDS:
#the build completes and repeats exactly for a seed; the start bubble is clear and the start isn't lethal;
#the station is reachable and its route is never shorter than the straight line; no barrier runs more
#than MAX_RUN cells without a crossing; the fine rasters agree with the coarse map; every district has a
#faction in the level's band, three goons of it and (in the start's component) two exits; barriers keep
#under the level's share cap; Defense gets three clear lanes.

const SEEDS := [1, 2, 3, 4, 5]

static func sprintOffset(def: LevelDef, worldSeed: int) -> Vector2:
	return Level.sprintOffsetPx(def.seconds, WorldGen.hashf(worldSeed, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0)

func test_every_level_keeps_its_guarantees():
	var timings := PackedStringArray()
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var total := 0.0
		var worst := 0.0
		for worldSeed in SEEDS:
			var map := WorldMap.build(worldSeed, def, "sprint", sprintOffset(def, worldSeed))
			var label := "%s seed %d" % [id, worldSeed]
			total += map.buildMs.total
			worst = maxf(worst, map.buildMs.total)
			checkStart(map, def, label)
			checkStation(map, def, label)
			checkCrossings(map, label)
			checkFineAgrees(map, def, worldSeed, label)
			checkDistricts(map, def, label)
			checkShare(map, label)
		timings.push_back("%s %.0f/%.0f ms" % [id, total / SEEDS.size(), worst])
	print("  coarse build mean/worst: " + ", ".join(timings))

func checkStart(map: WorldMap, def: LevelDef, label: String) -> void:
	var start := def.startPosition
	var lo := WorldGen.cellOf(start - Vector2.ONE * WorldField.START_CLEAR)
	var hi := WorldGen.cellOf(start + Vector2.ONE * WorldField.START_CLEAR)
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell := Rect2(WorldGen.ORIGIN + Vector2(cx, cy) * WorldGen.CELL, Vector2.ONE * WorldGen.CELL)
			var nearest := start.clamp(cell.position, cell.end)
			if nearest.distance_to(start) < WorldField.START_CLEAR && map.flags[cy * WorldGen.W + cx] & WorldGen.BLOCKED != 0:
				fail("%s: a barrier cell %s within %d px of the start" % [label, Vector2i(cx, cy), WorldField.START_CLEAR])
				return
	var chunk := WorldGen.chunkOf(start)
	for dy in range(-1, 2):
		for dx in range(-1, 2): map.buildNow(chunk + Vector2i(dx, dy))
	for y in range(-20, 21):
		for x in range(-20, 21):
			var p := start + Vector2(x, y) * 128.0
			if p.distance_to(start) < WorldField.START_CLEAR - 64.0 && map.blockedAt(p):
				fail("%s: fine barrier (%d) %d px from the start" % [label, map.terrainAt(p), p.distance_to(start)])
				return
	assert_false(map.lethalAt(start), "%s: the start isn't lethal" % label)
	assert_true(map.flags[map.coarseIndex(start)] & WorldGen.START != 0, "%s: the start is in the start component" % label)

func checkStation(map: WorldMap, def: LevelDef, label: String) -> void:
	assert_true(map.station != Vector2.INF, "%s: a station was placed" % label)
	if map.station == Vector2.INF: return
	assert_true(WorldGen.stationCoreOk(map.flags, map.stationChunk, true), "%s: the station's cells are reachable" % label)
	assert_true(map.stationChunk != WorldGen.chunkOf(def.startPosition), "%s: never the start chunk" % label)
	var route := map.routeBetween(def.startPosition, map.station)
	assert_true(route.reached, "%s: A* reaches the station" % label)
	assert_almost_eq(route.length, map.routeLength, 0.5, "%s: the build's route length" % label)
	assert_true(map.routeLength >= def.startPosition.distance_to(map.station) - 0.01, "%s: the route is never shorter than the straight line" % label)

#No barrier runs (approximately: thin runs of barrier cells chained column to column, as WorldGen scans them;
#short barriers, which are driven round, excepted) more than MAX_RUN cells without a crossing, in either
#direction. Counted on the finished map, so a run may span cells WorldGen saw as two barriers.
func checkCrossings(map: WorldMap, label: String) -> void:
	var short := WorldGen.barrierExtents(map.flags)
	for alongX in [true, false]:
		var outer := WorldGen.W if alongX else WorldGen.H
		var inner := WorldGen.H if alongX else WorldGen.W
		var prev: Array = []
		for o in outer:
			var cur: Array = []
			var k := 0
			while k < inner:
				var i := k * WorldGen.W + o if alongX else o * WorldGen.W + k
				if map.flags[i] & (WorldGen.BLOCKED | WorldGen.RESERVED) != WorldGen.BLOCKED || short[i] != 0:
					k += 1
					continue
				var a0 := k
				while k < inner:
					var j := k * WorldGen.W + o if alongX else o * WorldGen.W + k
					if map.flags[j] & (WorldGen.BLOCKED | WorldGen.RESERVED) != WorldGen.BLOCKED || short[j] != 0: break
					k += 1
				var a1 := k - 1
				var before := (a0 - 1) * WorldGen.W + o if alongX else o * WorldGen.W + a0 - 1
				var after := (a1 + 1) * WorldGen.W + o if alongX else o * WorldGen.W + a1 + 1
				var thin := a1 - a0 + 1 <= WorldGen.MAX_CUT && a0 > 0 && a1 < inner - 1 \
					&& map.flags[before] & WorldGen.BLOCKED == 0 && map.flags[after] & WorldGen.BLOCKED == 0
				var count := 0
				if thin && not WorldGen.crossingNear(map.flags, o, a0, a1, alongX):
					for r in prev:
						if WorldGen.runsChain(r[0], r[1], a0, a1): count = maxi(count, r[2])
					count += 1
					if count > WorldGen.MAX_RUN + 1:
						fail("%s: a barrier runs %d thin cells without a crossing near %s" % [label, count, Vector2i(o, a0) if alongX else Vector2i(a0, o)])
						return
				cur.push_back([a0, a1, count])
			prev = cur

#Fine rasters never disagree with the coarse map: the fine cells round a passable coarse cell's centre are
#passable, round a blocked one's blocked; the walk between two adjacent passable centres is open
func checkFineAgrees(map: WorldMap, def: LevelDef, worldSeed: int, label: String) -> void:
	var chunks: Array[Vector2i] = [WorldGen.chunkOf(def.startPosition)]
	if map.station != Vector2.INF: chunks.push_back(map.stationChunk)
	for k in 6:
		chunks.push_back(Vector2i(WorldGen.ihash(worldSeed, 900, k, 0) % 30 - 15, WorldGen.ihash(worldSeed, 901, k, 0) % 30 - 15))
	for chunk in chunks:
		map.buildNow(chunk)
		var base := WorldGen.chunkCell(chunk)
		for k in 8:
			var cell := base + Vector2i(k % 4, k / 4)
			var i := cell.y * WorldGen.W + cell.x
			var centre := WorldGen.cellCentre(cell)
			var blocked := map.flags[i] & WorldGen.BLOCKED != 0
			for d in [Vector2(-64, -64), Vector2(64, -64), Vector2(-64, 64), Vector2(64, 64)]:
				var fineBlocked := map.blockedAt(centre + d)
				if fineBlocked != blocked:
					fail("%s: chunk %s cell %s is %s in the coarse map but fine terrain %d" % [label, chunk, cell, "blocked" if blocked else "open", map.terrainAt(centre + d)])
					return
			if blocked: continue
			for step in [Vector2i(1, 0), Vector2i(0, 1)]:
				var next: Vector2i = cell + step
				if next.x >= base.x + 4 || next.y >= base.y + 2: continue #stay inside the raster
				if map.flags[next.y * WorldGen.W + next.x] & WorldGen.BLOCKED != 0: continue
				for t in 11:
					var p := centre + Vector2(step) * WorldGen.CELL * t / 10.0
					if map.blockedAt(p):
						fail("%s: the way between passable cells %s and %s is blocked at %s" % [label, cell, next, p])
						return

func checkDistricts(map: WorldMap, def: LevelDef, label: String) -> void:
	var allowed := {}
	for score in [minf(def.factionBand.x, def.factionBand.y), LevelRoster.bandTop(def.factionBand)]:
		allowed[LevelRoster.factionForScore(score)] = true
	for f in range(LevelRoster.factionForScore(minf(def.factionBand.x, def.factionBand.y)), LevelRoster.factionForScore(LevelRoster.bandTop(def.factionBand)) + 1):
		allowed[LevelRoster.rosterFaction(def, f)] = true
	var problems := 0
	for d in map.districts:
		if not allowed.has(d.faction):
			fail("%s: district %d is %s, outside the band %s" % [label, d.id, Goons.factionName(d.faction), def.factionBand])
			problems += 1
		if d.goons.size() != 3:
			fail("%s: district %d has %d goons" % [label, d.id, d.goons.size()])
			problems += 1
		for g in d.goons:
			if not Goons.DATA.has(g) || Goons.DATA[g].faction != d.faction:
				fail("%s: district %d's goon %s isn't %s" % [label, d.id, g, Goons.factionName(d.faction)])
				problems += 1
		if d.inStart && d.neighbours.size() < 2:
			fail("%s: district %d (%d cells) has %d exits" % [label, d.id, d.cells, d.neighbours.size()])
			problems += 1
		if d.name == "": problems += 1
		if problems > 3: return

#Hard barriers (not set pieces, the map edge or filled pockets) under the level's cap in every 3x3-chunk
#window, by what they really cover (WorldGen.cover)
func checkShare(map: WorldMap, label: String) -> void:
	var cap := WorldField.make(map.worldSeed, map.snapshot).barrierCap
	var maxCells := int(floor(cap * WorldGen.WINDOW.x * WorldGen.WINDOW.y * 255.0))
	for wy in range(0, WorldGen.H - WorldGen.WINDOW.y + 1, 2):
		for wx in range(0, WorldGen.W - WorldGen.WINDOW.x + 1, 4):
			var count := 0
			for y in range(wy, wy + WorldGen.WINDOW.y):
				for x in range(wx, wx + WorldGen.WINDOW.x):
					var i := y * WorldGen.W + x
					if map.flags[i] & (WorldGen.BLOCKED | WorldGen.RESERVED | WorldGen.FILL) == WorldGen.BLOCKED: count += map.cover[i]
			if count > maxCells:
				fail("%s: %.1f%% barrier in the window at %s (cap %.0f%%)" % [label, 100.0 * count / (255.0 * WorldGen.WINDOW.x * WorldGen.WINDOW.y), Vector2i(wx, wy), cap * 100.0])
				return

func test_the_start_district_is_the_levels_first_faction():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var map := WorldMap.build(3, def)
		var start: Dictionary = map.districts[map.districtAt(def.startPosition)]
		var allowed := []
		for jitter in [-Goons.FACTION_JITTER, 0.0, Goons.FACTION_JITTER]:
			allowed.push_back(LevelRoster.rosterFaction(def, LevelRoster.factionAt(def, 0.0, jitter)))
		assert_true(start.faction in allowed, "%s starts in the band's first faction (%s), not %s" % [id, allowed, Goons.factionName(start.faction)])

func test_same_seed_same_world():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var a := WorldMap.build(77, def, "sprint", sprintOffset(def, 77))
		var b := WorldMap.build(77, def, "sprint", sprintOffset(def, 77))
		assert_eq(a.terrain, b.terrain, "%s: terrain" % id)
		assert_eq(a.flags, b.flags, "%s: flags" % id)
		assert_eq(a.district, b.district, "%s: districts" % id)
		assert_eq(a.stationChunk, b.stationChunk, "%s: station" % id)
		assert_eq(a.districts.map(func(d): return [d.name, d.faction, d.goons, d.tint]), b.districts.map(func(d): return [d.name, d.faction, d.goons, d.tint]), "%s: district table" % id)
		var chunk := WorldGen.chunkOf(def.startPosition) + Vector2i(1, 0)
		a.buildNow(chunk)
		b.buildNow(chunk)
		assert_eq(a.rasters[chunk].terrain, b.rasters[chunk].terrain, "%s: fine raster" % id)
		assert_eq(a.rasters[chunk].water, b.rasters[chunk].water, "%s: water field" % id)
		var other := WorldMap.build(78, def)
		assert_true(other.terrain != a.terrain, "%s: another seed, another world" % id)

func test_chunk_edges_agree():
	#a raster's apron samples the same fields as its neighbour's edge cells
	var map := WorldMap.build(4, Levels.get_def(&"bayou"))
	var a := Vector2i(2, 1)
	var b := Vector2i(3, 1)
	map.buildNow(a)
	map.buildNow(b)
	var ra: Dictionary = map.rasters[a]
	var rb: Dictionary = map.rasters[b]
	for j in range(1, WorldGen.FIELD_H - 1):
		#a's apron column (i = FIELD_W - 1) is b's first column (i = 1)
		assert_almost_eq(ra.water[j * WorldGen.FIELD_W + WorldGen.FIELD_W - 1], rb.water[j * WorldGen.FIELD_W + 1], 0.0001, "row %d" % j)
		assert_almost_eq(ra.wall[j * WorldGen.FIELD_W + WorldGen.FIELD_W - 2], rb.wall[j * WorldGen.FIELD_W], 0.0001, "row %d" % j)

func test_defense_gets_three_clear_lanes():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var map := WorldMap.build(1, def, "defense")
		assert_eq(map.stationChunk, WorldGen.chunkOf(def.startPosition), "%s: the station is the start's chunk" % id)
		assert_eq(map.lanes.size(), WorldGen.DEFENSE_LANES, "%s: three lanes" % id)
		for mouth in map.lanes:
			assert_almost_eq(mouth.distance_to(map.station), WorldGen.DEFENSE_LANE_PX, 1.0, "%s: 4000 px out" % id)
			var dir: Vector2 = (mouth - map.station).normalized()
			for t in range(900, int(WorldGen.DEFENSE_LANE_PX) + 1, 256):
				var p: Vector2 = map.station + dir * t
				if map.flags[map.coarseIndex(p)] & WorldGen.BLOCKED != 0:
					fail("%s: lane blocked %d px out" % [id, t])
					break
			assert_true(map.cellReachable(map.coarseCell(mouth)), "%s: the lane mouth is reachable" % id)

func test_raster_and_build_times():
	var def := Levels.get_def(&"city")
	var map := WorldMap.build(2, def)
	assert_true(map.buildMs.total < 5000.0, "coarse build %.0f ms (target ~1500 on the HD 620 box)" % map.buildMs.total)
	var total := 0
	for k in 10:
		var job := map.fineJob(Vector2i(k - 5, 2))
		WorldGen.fineRaster(job)
		total += job.result.usec
	print("  fine raster mean %.2f ms (city)" % (total / 10000.0))
	assert_true(total / 10000.0 < 40.0, "fine raster %.1f ms (target ~10)" % (total / 10000.0))
