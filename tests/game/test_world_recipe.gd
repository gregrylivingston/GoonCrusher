extends GameTest

#Chunk recipes and their apply (scripts/world/chunk_recipe.gd, chunk_view.gd, docs/WORLD.md): for every level
#over SEEDS and a sample of chunks (the start's, the station's and some round them) a recipe builds within the
#chunk budgets; its wall pieces are convex, inside the chunk and agree with the wall field; occluders and
#lines are short; props and pickups stand on open spawnable ground away from the start's core and the
#station lot; the same input gives the same recipe; an applied chunk stays within the node budget, and a
#collected pickup stays gone when the chunk is applied again.

const SEEDS := [1, 2, 3]
const AROUND := [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(2, -1), Vector2i(-3, 0)]

static var maps := {} #"level:seed" -> [WorldMap, ctx, skin]

## A level's map for a seed with its recipe context (station lot reserved), built once per test run
func world(id: StringName, worldSeed: int) -> Array:
	var key := "%s:%d" % [id, worldSeed]
	if not maps.has(key):
		var def := Levels.get_def(id)
		var offset := Level.sprintOffsetPx(def.seconds, WorldGen.hashf(worldSeed, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0)
		var map := WorldMap.build(worldSeed, def, "sprint", offset)
		var skin := WorldSkin.new(def)
		var lots := [TileManager.lotRect(map.stationChunk)] if map.stationChunk != WorldGen.NO_CHUNK else []
		map.recipeContext = skin.recipeContext(lots, [])
		maps[key] = [map, map.recipeContext, skin]
	return maps[key]

func sampleChunks(map: WorldMap) -> Array:
	var start := WorldGen.chunkOf(map.startPosition)
	var out := [start]
	if map.stationChunk != WorldGen.NO_CHUNK: out.push_back(map.stationChunk)
	for d in AROUND: out.push_back(start + d)
	return out

func recipeFor(map: WorldMap, chunk: Vector2i) -> Dictionary:
	map.buildNow(chunk)
	return map.recipeOf(chunk)

func test_recipes_keep_their_budgets_and_rules():
	var worst := {}
	var timing := PackedStringArray()
	for id in Levels.ORDER:
		var maxima := {"nodes": 0, "occluders": 0, "pieces": 0, "props": 0, "pickups": 0, "decor": 0, "lines": 0}
		var usec := 0
		var count := 0
		var slowest := 0
		for worldSeed in SEEDS:
			var w := world(id, worldSeed)
			var map: WorldMap = w[0]
			for chunk in sampleChunks(map):
				var recipe := recipeFor(map, chunk)
				var label := "%s seed %d chunk %s" % [id, worldSeed, chunk]
				assert_false(recipe.is_empty(), label + ": a recipe")
				if recipe.is_empty(): continue
				usec += recipe.usec
				slowest = maxi(slowest, recipe.usec)
				count += 1
				for k in maxima: maxima[k] = maxi(maxima[k], recipe.counts[k])
				checkBudgets(recipe, label)
				checkPieces(recipe, map, chunk, label)
				checkPlacement(recipe, map, chunk, label)
		worst[id] = maxima
		timing.push_back("%s %.1f/%.1f ms" % [id, usec / 1000.0 / maxi(count, 1), slowest / 1000.0])
	print("  recipe build mean/worst (this thread): " + ", ".join(timing))
	for id in worst: print("  %s max per chunk: %s" % [id, worst[id]])

func checkBudgets(recipe: Dictionary, label: String) -> void:
	var c: Dictionary = recipe.counts
	assert_true(c.nodes <= ChunkRecipe.MAX_NODES, "%s: nodes %d" % [label, c.nodes])
	assert_true(c.occluders <= ChunkRecipe.MAX_OCCLUDERS, "%s: occluders %d" % [label, c.occluders])
	assert_true(c.pieces <= ChunkRecipe.MAX_PIECES, "%s: static pieces %d" % [label, c.pieces])
	assert_eq(c.pieces, recipe.pieces.size(), label + ": piece count")
	for poly in recipe.occluders:
		var box := ChunkRecipe.bounds(poly)
		assert_true(box.size.x <= ChunkRecipe.SPAN + 0.5 && box.size.y <= ChunkRecipe.SPAN + 0.5, "%s: occluder within %d px (%s)" % [label, ChunkRecipe.SPAN, box.size])
	for line in recipe.lines:
		var box := ChunkRecipe.bounds(line[1])
		assert_true(box.size.x <= ChunkRecipe.SPAN + 0.5 && box.size.y <= ChunkRecipe.SPAN + 0.5, "%s: line within the span" % label)
	assert_eq(recipe.control.size(), ChunkRecipe.RW * ChunkRecipe.RH * 4, label + ": control block")

func checkPieces(recipe: Dictionary, map: WorldMap, chunk: Vector2i, label: String) -> void:
	for piece in recipe.pieces:
		assert_true(isConvex(piece), "%s: piece is convex %s" % [label, piece])
		for p in piece:
			assert_true(p.x >= -0.5 && p.y >= -0.5 && p.x <= ChunkRecipe.CHUNK.x + 0.5 && p.y <= ChunkRecipe.CHUNK.y + 0.5, "%s: piece inside the chunk" % label)
	#collision agrees with the wall field: well inside a wall is solid, well outside is not
	var wall: PackedFloat32Array = map.rasters[chunk].wall
	var misses := 0
	var phantoms := 0
	for j in range(1, ChunkRecipe.FH + 1):
		for i in range(1, ChunkRecipe.FW + 1):
			var f := wall[j * ChunkRecipe.RW + i]
			if absf(f) < 0.2: continue
			var p := Vector2(i - 0.5, j - 0.5) * ChunkRecipe.FINE
			var inside := false
			for piece in recipe.pieces:
				if Geometry2D.is_point_in_polygon(p, piece):
					inside = true
					break
			if f < 0.0 && not inside: misses += 1
			if f > 0.0 && inside: phantoms += 1
	assert_eq(misses, 0, label + ": wall cells without collision")
	assert_eq(phantoms, 0, label + ": collision on open ground")

static func isConvex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3: return false
	var sign := 0.0
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var c := poly[(k + 2) % n]
		var cr := (b - a).cross(c - b)
		if absf(cr) < 1.0: continue
		if sign == 0.0: sign = signf(cr)
		elif signf(cr) != sign: return false
	return true

func checkPlacement(recipe: Dictionary, map: WorldMap, chunk: Vector2i, label: String) -> void:
	var origin := Vector2(chunk) * ChunkRecipe.CHUNK
	var lots := []
	if map.stationChunk != WorldGen.NO_CHUNK: lots.push_back(TileManager.lotRect(map.stationChunk))
	var things := []
	for p in recipe.props: things.push_back(["prop " + p[0], p[1]])
	for p in recipe.pickups: things.push_back(["pickup " + p[0], p[1]])
	for thing in things:
		var w: Vector2 = origin + thing[1]
		var t := map.terrainAt(w)
		var what := "%s: %s at %s" % [label, thing[0], w]
		assert_true(World.isSpawnable(t) && not World.isLethal(t) && t != Root.terrain.SHALLOWS && t != Root.terrain.BRIDGE, "%s on %s" % [what, World.letter(t)])
		assert_true(w.distance_to(map.startPosition) >= ChunkRecipe.START_CORE, what + " in the start's core")
		for lot in lots: assert_false(lot.has_point(w), what + " in the station lot")
	var bits := {}
	for p in recipe.pickups:
		if p[2] < 0: continue
		assert_false(bits.has(p[2]), label + ": pickup bits are unique")
		bits[p[2]] = true
		assert_true(p[2] < 32, label + ": pickup bits are 0-31")
	for p in recipe.props:
		if p[4] >= 0: assert_true(p[4] >= 32 && p[4] <= 62, label + ": breakable bits are 32-62")

func test_the_same_input_gives_the_same_recipe():
	for id in [&"prairie", &"bayou", &"city", &"crusher"]:
		var w := world(id, 2)
		var map: WorldMap = w[0]
		var other := WorldMap.build(2, Levels.get_def(id), "sprint", Level.sprintOffsetPx(Levels.get_def(id).seconds, WorldGen.hashf(2, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0))
		other.recipeContext = w[1]
		for chunk in sampleChunks(map):
			var a := recipeFor(map, chunk)
			var b := recipeFor(other, chunk)
			var label := "%s %s" % [id, chunk]
			for key in ["control", "pieces", "occluders", "lines", "props", "pickups", "decor", "spots", "counts"]:
				assert_eq(var_to_str(a[key]), var_to_str(b[key]), "%s: %s repeats" % [label, key])

#a stand-in for the TileManager's side of ChunkView
class FakeManager extends Node2D:
	var map: WorldMap
	var groundLayer := Node2D.new()
	var edgeLayer := Node2D.new()
	var decorLayer := Node2D.new()
	var wallLayer := Node2D.new()
	var objectLayer := Node2D.new()
	func _init() -> void:
		for layer in [groundLayer, edgeLayer, decorLayer, wallLayer, objectLayer]: add_child(layer)
	func isTaken(chunk: Vector2i, bit: int) -> bool: return map.isTaken(chunk, bit)
	func reservedAt(_p: Vector2, _r: float) -> bool: return false
	func decoratesChunk(_chunk: Vector2i) -> bool: return false
	func chunkRng(_chunk: Vector2i, _purpose := "") -> RandomNumberGenerator: return RandomNumberGenerator.new()

func pickupsIn(view: ChunkView) -> Array:
	var out := []
	for node in view.objects.get_children():
		if node.has_meta(&"worldSlot") && node is Powerup: out.push_back(node)
	return out

func test_an_applied_chunk_keeps_the_node_budget_and_the_taken_set():
	var w := world(&"prairie", 1)
	var map: WorldMap = w[0]
	var skin: WorldSkin = w[2]
	var tm := FakeManager.new()
	tm.map = map
	add_child_autofree(tm)
	var chunk := WorldGen.chunkOf(map.startPosition) + Vector2i(1, 0)
	var recipe := recipeFor(map, chunk)
	assert_false(recipe.is_empty(), "a recipe")
	if recipe.is_empty(): return
	var view := ChunkView.new(chunk, recipe)
	while not view.step(skin, tm, Time.get_ticks_usec() + 100000): pass
	assert_true(view.isDone())
	assert_true(view.nodeCount() <= ChunkRecipe.MAX_NODES, "applied world nodes %d" % view.nodeCount())
	assert_eq(view.quads.size(), 8, "eight ground quads")
	var pickups := pickupsIn(view)
	assert_gt(pickups.size(), 0, "the chunk has pickups")
	#collecting one marks its bit through its metadata
	var saved = Root.worldMap
	Root.worldMap = map
	var collected: Node = pickups[0]
	var slot: Vector3i = collected.get_meta(&"worldSlot")
	WorldMap.takeNode(collected)
	Root.worldMap = saved
	assert_true(map.isTaken(chunk, slot.z), "the pickup's bit is taken")
	while not view.release(skin, Time.get_ticks_usec() + 100000): pass
	var again := ChunkView.new(chunk, map.recipeOf(chunk))
	while not again.step(skin, tm, Time.get_ticks_usec() + 100000): pass
	var back := pickupsIn(again)
	assert_eq(back.size(), pickups.size() - 1, "a collected pickup stays gone")
	for node in back: assert_true(node.get_meta(&"worldSlot").z != slot.z, "and it is the collected one")
	while not again.release(skin, Time.get_ticks_usec() + 100000): pass
	map.taken.clear()

func test_time_sliced_apply_takes_several_frames_and_pools_nodes():
	var w := world(&"canyon", 1)
	var map: WorldMap = w[0]
	var skin: WorldSkin = w[2]
	var tm := FakeManager.new()
	tm.map = map
	add_child_autofree(tm)
	var chunk := WorldGen.chunkOf(map.startPosition) + Vector2i(-1, 1)
	var recipe := recipeFor(map, chunk)
	assert_false(recipe.is_empty(), "a recipe")
	if recipe.is_empty(): return
	var view := ChunkView.new(chunk, recipe)
	var steps := 0
	while not view.step(skin, tm, 0): steps += 1 #a zero budget: one piece per call
	assert_gt(steps, 6, "applied over several steps")
	while not view.release(skin, 0): pass
	assert_true(skin.pools.get("quad", []).size() >= 8, "ground quads went back to the pool")

#a profile, not a check: per level, the mean raster and recipe phase times (this thread) over a strip of chunks
#round the start, so a change to the recipe's hot spots can be measured. Prints one line per level.
func test_recipe_profile():
	var all := {}
	var rasterAll := 0
	var recipeAll := 0
	var worstAll := 0
	var n := 0
	for id in Levels.ORDER:
		var w := world(id, 1)
		var map: WorldMap = w[0]
		var start := WorldGen.chunkOf(map.startPosition)
		var phases := {}
		var print_ := PackedStringArray()
		var raster := 0
		var recipe := 0
		var worst := 0
		var count := 0
		for k in 24:
			var chunk := start + Vector2i(k % 6 - 3, k / 6 - 2)
			#the fastest of three builds (this box is noisy), phases from that build
			var r := {}
			var rr := {}
			for rep in 3:
				if map.fine.has(chunk): map.forget(chunk)
				map.buildNow(chunk)
				var got := map.recipeOf(chunk)
				if got.is_empty(): break
				if not r.is_empty():
					for key in ["control", "pieces", "occluders", "lines", "props", "pickups", "decor", "spots"]:
						assert_eq(var_to_str(got[key]).md5_text(), var_to_str(r[key]).md5_text(), "%s %s: a rebuild repeats %s" % [id, chunk, key])
				if r.is_empty() || got.usec + map.rasters[chunk].usec < r.usec + rr.usec:
					r = got
					rr = map.rasters[chunk]
			if r.is_empty(): continue
			print_.push_back(var_to_str([rr.terrain, rr.water, rr.wall]).md5_text())
			for key in ["control", "pieces", "occluders", "lines", "props", "pickups", "decor", "spots"]: print_.push_back(var_to_str(r[key]).md5_text())
			raster += rr.usec
			recipe += r.usec
			worst = maxi(worst, r.usec + rr.usec)
			count += 1
			for key in r.get("phases", {}):
				phases[key] = phases.get(key, 0) + r.phases[key]
				all[key] = all.get(key, 0) + r.phases[key]
		var parts := PackedStringArray()
		for key in phases: parts.push_back("%s %.2f" % [key, phases[key] / 1000.0 / maxi(count, 1)])
		print("  FINGERPRINT %s %s" % [id, "".join(print_).md5_text()])
		print("  PROFILE %s raster %.2f recipe %.2f worst(raster+recipe) %.1f ms | %s" % [id, raster / 1000.0 / maxi(count, 1), recipe / 1000.0 / maxi(count, 1), worst / 1000.0, ", ".join(parts)])
		rasterAll += raster
		recipeAll += recipe
		worstAll = maxi(worstAll, worst)
		n += count
	var parts := PackedStringArray()
	for key in all: parts.push_back("%s %.2f" % [key, all[key] / 1000.0 / maxi(n, 1)])
	print("  PROFILE all raster %.2f recipe %.2f worst %.1f ms | %s" % [rasterAll / 1000.0 / maxi(n, 1), recipeAll / 1000.0 / maxi(n, 1), worstAll / 1000.0, ", ".join(parts)])
	assert_gt(n, 0)

#a profile of the raster's parts: making the WorldField (noise objects, lattices) and sampling it 924 times
func test_raster_profile():
	var parts := PackedStringArray()
	for id in Levels.ORDER:
		var w := world(id, 1)
		var map: WorldMap = w[0]
		var t0 := Time.get_ticks_usec()
		var f: WorldField
		for k in 20: f = WorldField.make(map.worldSeed, map.snapshot)
		var make := (Time.get_ticks_usec() - t0) / 20.0
		var origin := map.startPosition + Vector2(7000, 3000)
		t0 = Time.get_ticks_usec()
		for j in 22:
			for i in 42: f.sample(origin.x + i * 128.0, origin.y + j * 128.0)
		var samples := Time.get_ticks_usec() - t0
		parts.push_back("%s make %.2f sample924 %.2f" % [id, make / 1000.0, samples / 1000.0])
	print("  RASTER_PROFILE " + ", ".join(parts))

#a profile of what ChunkView's slowest single steps cost: making a pickup and a stateful prop and adding it to
#the tree (first time and the median of the next eight)
func test_apply_step_profile():
	var parent := Node2D.new()
	add_child_autofree(parent)
	var parts := PackedStringArray()
	for id in ["coin", "fuel", "health", "purse", "slotmachine"]:
		var times := []
		for k in 9:
			var t0 := Time.get_ticks_usec()
			var node: Node2D = Pickups.make(id)
			parent.add_child(node)
			times.push_back(Time.get_ticks_usec() - t0)
		var rest: Array = times.slice(1)
		rest.sort()
		parts.push_back("%s first %.2f median %.2f" % [id, times[0] / 1000.0, rest[4] / 1000.0])
	var skin: WorldSkin = world(&"prairie", 1)[2]
	for id in [&"crate", &"haybale", &"fence", &"hedge"]:
		if not skin.propScenes.has(id): continue
		var times := []
		for k in 9:
			var t0 := Time.get_ticks_usec()
			var node: StaticBody2D = skin.propScenes[id].instantiate()
			if skin.breakableScript: node.set_script(skin.breakableScript)
			parent.add_child(node)
			times.push_back(Time.get_ticks_usec() - t0)
		var rest: Array = times.slice(1)
		rest.sort()
		parts.push_back("%s first %.2f median %.2f" % [id, times[0] / 1000.0, rest[4] / 1000.0])
	print("  APPLY_PROFILE " + ", ".join(parts))

#every district gets a landmark cell near its middle, and the recipe of that chunk stands the faction's
#landmark there (on open ground, within the budgets, checked like any prop)
func test_districts_get_their_landmarks():
	var report := PackedStringArray()
	for id in Levels.ORDER:
		var map: WorldMap = world(id, 1)[0]
		var withCell := 0
		for d in map.districts:
			if d.get("landmark", Vector2.INF) != Vector2.INF: withCell += 1
		assert_true(withCell >= map.districts.size() * 0.8, "%s: %d of %d districts have a landmark spot" % [id, withCell, map.districts.size()])
		var tried := 0
		var placed := 0
		for chunk in map.landmarks:
			if tried >= 6: break
			tried += 1
			var recipe := recipeFor(map, chunk)
			var label := "%s landmark chunk %s" % [id, chunk]
			checkBudgets(recipe, label)
			checkPlacement(recipe, map, chunk, label)
			for entry in map.landmarks[chunk]:
				for p in recipe.props:
					if p[0] == entry[0] && (Vector2(chunk) * ChunkRecipe.CHUNK + p[1]).distance_to(entry[1]) <= ChunkRecipe.LANDMARK_STEP * ChunkRecipe.LANDMARK_RINGS + 1.0:
						placed += 1
						break
		assert_true(placed >= tried * 0.8, "%s: %d of %d landmarks stood" % [id, placed, tried])
		report.push_back("%s %d/%d" % [id, placed, tried])
	print("  landmarks placed: " + ", ".join(report))

#city rooftops: the recipe dresses BUILDING cells with the rooftop atlas, well inside the parapet, and adds no
#collision for it
func test_city_roofs_are_dressed_and_add_no_collision():
	var map: WorldMap = world(&"city", 1)[0]
	var start := WorldGen.chunkOf(map.startPosition)
	var dressed := 0
	for k in 12:
		var chunk := start + Vector2i(k % 4 - 2, k / 4 - 1)
		var recipe := recipeFor(map, chunk)
		if not recipe.decor.has("rooftop"): continue
		var buf: PackedFloat32Array = recipe.decor["rooftop"]
		assert_eq(buf.size() % 12, 0)
		var raster: Dictionary = map.rasters[chunk]
		for n in range(0, buf.size(), 12):
			var p := Vector2(buf[n + 3], buf[n + 7])
			var t: int = raster.terrain[clampi(floori(p.y / 128.0), 0, 19) * 40 + clampi(floori(p.x / 128.0), 0, 39)]
			assert_eq(t, Root.terrain.BUILDING, "%s: rooftop decor on a roof" % chunk)
			assert_true(ChunkRecipe.fieldAt(raster.wall, p) <= -ChunkRecipe.ROOF_INSET + 0.001, "%s: inside the parapet" % chunk)
			dressed += 1
	assert_gt(dressed, 0, "some roofs are dressed")
	print("  city rooftop decor near the start: %d" % dressed)

#the control block's flags byte carries the district tint code in its high bits
func test_control_carries_the_district_tint():
	var map: WorldMap = world(&"prairie", 1)[0]
	var chunk := WorldGen.chunkOf(map.startPosition) + Vector2i(1, 0)
	var recipe := recipeFor(map, chunk)
	var tints := map.chunkTints(chunk)
	for j in ChunkRecipe.FH:
		for i in ChunkRecipe.FW:
			var k := ((j + 1) * ChunkRecipe.RW + i + 1) * 4 + 3
			var want: int = tints[(j / 10) * 4 + i / 10]
			assert_eq(recipe.control[k] >> 4, want, "cell %d,%d tint code" % [i, j])
			assert_true(recipe.control[k] & 15 < 16)
			if recipe.control[k] >> 4 != want: return
