class_name WorldPreview extends RefCounted
## Prints a level's generated world as text, with its build timings (docs/WORLD.md). Run through the
## playtest harness (an autoload, so the game's classes are all there), which quits afterwards:
##   Godot_console.exe --headless --path . -- --playtest --world-preview --level=prairie,city --seeds=1,2
## Options: --level=all|<ids> --seeds=<n,...> --w=80 --h=30 (the crop, in coarse cells of 1280 px)
##          --objective=sprint|defense (place a station and show its route) --fine=<chunks to time>
## Legend: World.TERRAIN letters (g grass, s sand, m mud, ~ deep water, ^ hills/rock, o moss, d dirt, * snow,
## = asphalt, i ice, % oil, - shallows, w wash, > conveyor, @ mud pit, # deep snow, l lot, B building,
## b bridge), '+' a pass cut through a wall, S start, X station, M a Defense lane mouth, '.' the route.

static func run(options: Dictionary) -> void:
	var ids: Array = Levels.ORDER.duplicate()
	var levels := str(options.get("level", "all"))
	if levels != "all":
		ids = []
		for id in levels.split(","): ids.push_back(Levels.resolve(id))
	var seeds: Array = []
	for s in str(options.get("seeds", options.get("seed", "1"))).split(","): seeds.push_back(int(s))
	var w := int(options.get("w", "80"))
	var h := int(options.get("h", "30"))
	var objective := str(options.get("objective", ""))
	var fineCount := int(options.get("fine", "0"))
	if options.has("probe"): #--probe=x,y: the coarse cells and the fine map round a world point
		var xy := str(options.probe).split(",")
		probe(Levels.get_def(ids[0]), int(seeds[0]), Vector2(float(xy[0]), float(xy[1])), objective)
		return
	for id in ids:
		var def := Levels.get_def(id)
		if def == null: continue
		for s in seeds:
			preview(def, s, w, h, objective, fineCount)

static func preview(def: LevelDef, worldSeed: int, w: int, h: int, objective: String, fineCount: int) -> void:
	var offset := Level.sprintOffsetPx(Level.sprintDistance(def), WorldGen.hashf(worldSeed, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0)
	var map := WorldMap.build(worldSeed, def, objective, offset)
	var blocked := 0
	var reachable := 0
	for f in map.flags:
		if f & WorldGen.BLOCKED != 0: blocked += 1
		elif f & WorldGen.START != 0: reachable += 1
	print("WORLD %s seed=%d grammar=%s coarse=%.0fms (sample %.0f, rules %.0f, districts %.0f, astar %.0f) blocked=%.1f%% reachable=%.1f%% districts=%d crossings=%d" % [
		def.id, worldSeed, def.grammar, map.buildMs.total, map.buildMs.sample, map.buildMs.rules, map.buildMs.districts, map.buildMs.astar,
		100.0 * blocked / map.flags.size(), 100.0 * reachable / map.flags.size(), map.districts.size(), map.crossings.size()])
	print("  steps " + str(map.buildMs.get("steps", {})))
	var marks := {}
	var startCell := WorldGen.cellOf(def.startPosition)
	if map.station != Vector2.INF:
		print("  station chunk %s, route %.0f px (straight %.0f), reached=%s" % [map.stationChunk, map.routeLength, def.startPosition.distance_to(map.station), map.route.size() > 1])
		for p in map.route: marks[WorldGen.cellOf(p)] = "."
		marks[WorldGen.cellOf(map.station)] = "X"
	for mouth in map.lanes: marks[WorldGen.cellOf(mouth)] = "M"
	marks[startCell] = "S"
	var here := map.districtAt(def.startPosition)
	if here >= 0:
		var d: Dictionary = map.districts[here]
		print("  start district %d '%s' zone=%d faction=%s goons=%s" % [here, d.name, d.zone, Goons.factionName(d.faction), d.goons])
	var centre := startCell
	if map.station != Vector2.INF && objective == "sprint": centre = (startCell + WorldGen.cellOf(map.station)) / 2
	for line in WorldGen.ascii({"terrain": map.terrain, "flags": map.flags}, centre, w, h, marks): print("  |" + line + "|")
	if fineCount > 0:
		var total := 0
		var worst := 0
		var start := WorldGen.chunkOf(def.startPosition)
		for k in fineCount:
			var chunk := start + Vector2i(k % 5 - 2, k / 5 - 2)
			var job := map.fineJob(chunk)
			WorldGen.fineRaster(job)
			total += job.result.usec
			worst = maxi(worst, job.result.usec)
		var f := WorldField.make(worldSeed, map.snapshot)
		var t0 := Time.get_ticks_usec()
		var sink := 0.0
		for j in WorldGen.FIELD_H:
			for i in WorldGen.FIELD_W: sink += f.sample(5000.0 + i * 128.0, 3000.0 + j * 128.0).x
		var sampleUsec := Time.get_ticks_usec() - t0
		print("  fine raster: %d chunks, mean %.2f ms, worst %.2f ms (fields alone %.2f ms)" % [fineCount, total / 1000.0 / fineCount, worst / 1000.0, sampleUsec / 1000.0])

static func probe(def: LevelDef, worldSeed: int, at: Vector2, objective: String) -> void:
	var offset := Level.sprintOffsetPx(Level.sprintDistance(def), WorldGen.hashf(worldSeed, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0)
	var map := WorldMap.build(worldSeed, def, objective, offset)
	var cell := map.coarseCell(at)
	print("PROBE %s seed=%d at %s: coarse cell %s chunk %s" % [def.id, worldSeed, at, cell, WorldGen.chunkOf(at)])
	for dy in range(-3, 4):
		var line := ""
		for dx in range(-3, 4):
			var i := map.cellIndex(cell + Vector2i(dx, dy))
			line += " %s%s%02X" % ["*" if dx == 0 && dy == 0 else " ", World.letter(map.terrain[i]), map.flags[i]]
		print("PROBE_COARSE" + line)
	for dy in range(-1, 2):
		for dx in range(-1, 2): map.buildNow(WorldGen.chunkOf(at) + Vector2i(dx, dy))
	for dy in range(-12, 13):
		var line := ""
		for dx in range(-20, 21):
			line += "C" if dx == 0 && dy == 0 else World.letter(map.terrainAt(at + Vector2(dx, dy) * 128.0))
		print("PROBE_FINE " + line)
