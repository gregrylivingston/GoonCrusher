extends GameTest

#How props are laid out (package 14, P-3 and P-5; docs/WORLD.md "Props and decor"): fences and hedges only as
#field lines square to their region's lattice, motifs as tight clusters, road barriers along the road, the
#level tables (motifs, field densities, no dead feature keys), and the skin loading what motifs and spills need.

const SEED := 4

func recipes(id: StringName, count := 9) -> Array:
	var def := Levels.get_def(id)
	var map := WorldMap.build(SEED, def, "", Vector2.ZERO)
	var skin := WorldSkin.new(def)
	map.recipeContext = skin.recipeContext([], [])
	var start := WorldGen.chunkOf(map.startPosition)
	var out := []
	for k in count:
		var c: Vector2i = start + Vector2i(k % 3 - 1, k / 3 - 1)
		map.buildNow(c)
		out.push_back([c, map.recipeOf(c), map.recipeContext])
	return out

func test_fences_and_hedges_lie_on_their_region_lattice():
	var pieces := 0
	var paddock := Levels.get_def(&"prairie").startPosition + Vector2(ChunkRecipe.PADDOCK_AHEAD, 0.0)
	for entry in recipes(&"prairie"):
		var r := ChunkRecipe.new()
		r.mapSeed = SEED
		var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
		for p in entry[1].props:
			if not p[0] in ["fence", "hedge"]: continue
			if (origin + p[1]).distance_to(paddock) < ChunkRecipe.PADDOCK_HALF * 1.5: continue #the Home Paddock's own, square to the world
			pieces += 1
			var frame: Array = r.fieldFrame(ChunkRecipe.regionOf(origin + p[1]))
			var off := fposmod(p[2] - frame[2].angle(), PI * 0.5)
			assert_true(off < 0.001 || off > PI * 0.5 - 0.001, "%s at %s lies along the lattice" % [p[0], origin + p[1]])
	assert_true(pieces > 10, "Prairie has field lines (%d pieces)" % pieces)

func test_field_lines_keep_off_roads_and_water():
	var r := ChunkRecipe.new()
	r.terrain.resize(ChunkRecipe.FW * ChunkRecipe.FH)
	r.terrain.fill(ChunkRecipe.ASPHALT)
	r.water.resize(ChunkRecipe.RW * ChunkRecipe.RH)
	r.water.fill(1.0)
	r.wall = r.water.duplicate()
	r.spawnTable = PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var fence := {"w": 330.0, "h": 50.0}
	assert_false(r.fieldFits(Vector2(2000, 1000), 0.0, fence), "never on a road (tracks cut gaps in the runs)")
	r.terrain.fill(0)
	assert_true(r.fieldFits(Vector2(2000, 1000), 0.0, fence), "fine on open grass")

func test_road_barriers_line_the_road():
	var r := ChunkRecipe.new()
	r.terrain.resize(ChunkRecipe.FW * ChunkRecipe.FH)
	r.terrain.fill(0)
	for i in ChunkRecipe.FW:
		for j in [9, 10]: r.terrain[j * ChunkRecipe.FW + i] = ChunkRecipe.ASPHALT #a road along x
	var rot := r.roadAxis(Vector2(2000, 10 * ChunkRecipe.FINE), 1.0)
	assert_almost_eq(fposmod(rot, PI), 0.0, 0.01, "along the road")
	assert_eq(r.roadAxis(Vector2(2000, 2 * ChunkRecipe.FINE), 1.0), 1.0, "off the road: left as it was")

func test_motifs_place_tight_groups():
	var close := 0
	for entry in recipes(&"bayou"):
		var trees: Array = entry[1].props.filter(func(p): return p[0] == "cypress")
		for i in trees.size():
			for j in range(i + 1, trees.size()):
				if trees[i][1].distance_to(trees[j][1]) < 340.0: close += 1
	assert_true(close >= 2, "Bayou's cypress groves stand closer than the scatter allows (%d close pairs)" % close)

func test_level_tables_name_real_motifs_and_props():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for key in ["reedDensity", "pineDensity", "pileupDensity"]: assert_false(def.features.has(key), "%s: %s is gone (nothing read it)" % [id, key])
		for motif in def.motifs: assert_true(WorldSkin.MOTIFS.has(StringName(motif)), "%s: motif %s exists" % [id, motif])
		for hero in def.heroes:
			var spec := WorldSkin.heroSpec(def.heroes[hero])
			assert_true(WorldSkin.MOTIFS.has(StringName(hero)) || WorldSkin.loadManifest().has(String(hero)), "%s: hero %s is a motif or a baked prop" % [id, hero])
			assert_true(spec[1] in ChunkRecipe.ANCHORS, "%s: hero %s's anchor %s" % [id, hero, spec[1]])
	for region in Territories.ORDER:
		for zone in Territories.get_def(region).get("heroes", []):
			for hero in zone: assert_true(WorldSkin.MOTIFS.has(StringName(hero)) || WorldSkin.loadManifest().has(String(hero)), "%s: overlay hero %s" % [region, hero])
	for motif in WorldSkin.MOTIFS:
		for m in WorldSkin.MOTIFS[motif].members: assert_true(WorldSkin.loadManifest().has(m[0]), "%s: %s is baked" % [motif, m[0]])
	var prairie := Levels.get_def(&"prairie")
	assert_true(prairie.features.get("fenceDensity", 0.0) > 0.0 && prairie.features.get("hedgeDensity", 0.0) > 0.0, "Prairie's field densities are read now")

#--- Region 1 layout (R-2 heroes, motifs, the Home Paddock, L-8 hedgerows, mixed crossings, slots, thickets) ---

const WILDS := [&"prairie", &"orchard", &"bayou", &"canyon", &"moosewoods"]

## Recipes of a wider block of chunks round the start (5 x 3), for counting rarer things
func wideRecipes(id: StringName, worldSeed := SEED) -> Array:
	var def := Levels.get_def(id)
	var map := WorldMap.build(worldSeed, def, "", Vector2.ZERO)
	var skin := WorldSkin.new(def)
	map.recipeContext = skin.recipeContext([], [])
	var start := WorldGen.chunkOf(map.startPosition)
	var out := []
	for k in 15:
		var c: Vector2i = start + Vector2i(k % 5 - 2, k / 5 - 1)
		map.buildNow(c)
		out.push_back([c, map.recipeOf(c), map])
	return out

func test_heroes_come_first_on_their_anchors_and_survive_the_budget():
	var report := PackedStringArray()
	for id in WILDS:
		var heroes := 0
		var byId := {}
		var paddock := Levels.get_def(id).startPosition + Vector2(ChunkRecipe.PADDOCK_AHEAD, 0.0)
		for entry in wideRecipes(id):
			var recipe: Dictionary = entry[1]
			var map: WorldMap = entry[2]
			var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
			assert_eq(recipe.counts.heroesDropped, 0, "%s %s: no hero dropped by the node budget" % [id, entry[0]])
			#heroes come right after the landmark and the Home Paddock
			var seenOther := false
			for p in recipe.props:
				if p[7]:
					assert_false(seenOther, "%s %s: %s placed before the field lines, motifs and scatter" % [id, entry[0], p[0]])
					heroes += 1
					byId[p[0]] = byId.get(p[0], 0) + 1
					checkAnchor(id, p, origin + p[1], map)
				elif not p[0].begins_with("landmark") && (origin + p[1]).distance_to(paddock) > ChunkRecipe.PADDOCK_HALF + 450.0:
					seenOther = true
		assert_gt(heroes, 3, "%s has heroes near the start (%s)" % [id, byId])
		report.push_back("%s %d %s" % [id, heroes, byId])
	print("  heroes in 15 chunks round the start: " + "; ".join(report))

## A hero stands where its anchor says
func checkAnchor(id: StringName, p: Array, w: Vector2, map: WorldMap) -> void:
	var label := "%s: hero %s at %s" % [id, p[0], w]
	match [id, p[0]]:
		[&"prairie", "logpile"], [&"prairie", "bell"], [&"moosewoods", "ranger_tower"], [&"moosewoods", "fallen_trunk"]:
			assert_false(onTrack(map, w), label + " off the track")
			assert_true(trackWithin(map, w, ChunkRecipe.TRACK_OFF.y + 200.0), label + " beside a track")
		[&"canyon", "rockpile"], [&"canyon", "tnt"]:
			assert_true(crossingWithin(map, w, ChunkRecipe.PASS_NEAR.y + 1300.0, false), label + " at a pass")
		[&"bayou", "log"], [&"bayou", "still"]:
			assert_true(waterWithin(map, w, 1.3 * WorldField.UNIT + 100.0), label + " on a bank")
		[&"prairie", "watertower"], [&"bayou", "sluice"]:
			assert_true(crossingWithin(map, w, ChunkRecipe.HERO_NEAR.y + 1300.0, true), label + " by a ford")
	if p[0] == "fallen_trunk": assert_eq(p[3], 2, label + ": the deadfall variant")

## On a dirt track by the meadow raster's track mask (a built chunk's)
func onTrack(map: WorldMap, w: Vector2) -> bool:
	var chunk := WorldGen.chunkOf(w)
	var raster: Dictionary = map.rasters.get(chunk, {})
	var tracks: PackedByteArray = raster.get("tracks", PackedByteArray())
	if tracks.is_empty(): return map.terrainAt(w) == Root.terrain.DIRT
	var local := w - Vector2(chunk) * ChunkRecipe.CHUNK
	return tracks[clampi(floori(local.y / ChunkRecipe.FINE), 0, ChunkRecipe.FH - 1) * ChunkRecipe.FW + clampi(floori(local.x / ChunkRecipe.FINE), 0, ChunkRecipe.FW - 1)] != 0

func trackWithin(map: WorldMap, w: Vector2, r: float) -> bool:
	for k in 24:
		for d in [r * 0.5, r * 0.75, r]:
			if onTrack(map, w + Vector2.from_angle(TAU * k / 24.0) * d): return true
	return false

func waterWithin(map: WorldMap, w: Vector2, r: float) -> bool:
	for k in 24:
		for d in [r * 0.33, r * 0.66, r]:
			var t := map.terrainAt(w + Vector2.from_angle(TAU * k / 24.0) * d)
			if t == Root.terrain.WATER || t == Root.terrain.SHALLOWS || t == Root.terrain.BRIDGE: return true
	return false

## A crossing (a ford when `ford`, else a pass) whose cell center is within r
func crossingWithin(map: WorldMap, w: Vector2, r: float, ford: bool) -> bool:
	var c := WorldGen.cellOf(w)
	var cells := ceili(r / WorldGen.CELL) + 1
	for dy in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var cell := c + Vector2i(dx, dy)
			var i := map.cellIndex(cell)
			if i < 0 || map.flags[i] & WorldGen.CROSSING == 0 || WorldGen.cellCenter(cell).distance_to(w) > r: continue
			if (map.terrain[i] == Root.terrain.SHALLOWS) == ford: return true
	return false

func test_motif_members_share_a_group_and_the_view_tags_them():
	var groups := {}
	var hero := 0
	var recs := wideRecipes(&"prairie")
	for entry in recs:
		var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
		for p in entry[1].props:
			if p[6] == 0: continue
			groups.get_or_add(p[6], []).push_back([p[0], origin + p[1]])
	assert_gt(groups.size(), 2, "Prairie places grouped set pieces")
	for key in groups:
		var members: Array = groups[key]
		for m in members: assert_true(m[1].distance_to(members[0][1]) < 1400.0, "group %d: %s stands with its set piece" % [key, m[0]])
	#ChunkView puts the group and hero flags on the nodes, and clears them on pooled props
	var map: WorldMap = recs[0][2]
	var skin := WorldSkin.new(Levels.get_def(&"prairie"))
	var tm := FakeManager.new()
	tm.map = map
	add_child_autofree(tm)
	for entry in recs:
		var recipe: Dictionary = entry[1]
		var wanted := 0
		for p in recipe.props:
			if p[6] != 0 || p[7]: wanted += 1
		if wanted == 0: continue
		var view := ChunkView.new(entry[0], recipe)
		while not view.step(skin, tm, Time.get_ticks_usec() + 100000): pass
		var tagged := 0
		for e in view.props:
			var node: Node = e[1]
			if node.has_meta(&"group") || node.has_meta(&"hero"): tagged += 1
			if node.has_meta(&"hero"): hero += 1
		assert_eq(tagged, wanted, "%s: every grouped or hero prop is tagged" % entry[0])
		while not view.release(skin, Time.get_ticks_usec() + 100000): pass
		break
	assert_gt(hero, 0, "hero props carry metadata hero")

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

func test_the_home_paddock_stands_ahead_of_the_start():
	var def := Levels.get_def(&"prairie")
	var center := def.startPosition + Vector2(ChunkRecipe.PADDOCK_AHEAD, 0.0)
	for worldSeed in [1, 2, 3]:
		var counts := {}
		var stash := {}
		var recs := wideRecipes(&"prairie", worldSeed)
		var trackAt: Vector2 = def.startPosition + Vector2(3200.0, WorldField.PADDOCK_TRACK_Y)
		assert_true(onTrack(recs[0][2], trackAt), "seed %d: the dirt track runs past the paddock" % worldSeed)
		for entry in recs:
			var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
			for p in entry[1].props:
				var w: Vector2 = origin + p[1]
				if p[0] == "logpile" && w.distance_to(center + Vector2(680, -600)) < 10.0: counts.logpile = counts.get("logpile", 0) + 1
				if w.distance_to(center) > ChunkRecipe.PADDOCK_HALF + 120.0: continue
				counts[p[0]] = counts.get(p[0], 0) + 1
				if p[0] == "crate" && p[6] != 0: stash[p[6]] = stash.get(p[6], 0) + 1
		var label := "seed %d: %s" % [worldSeed, counts]
		assert_true(counts.get("fence", 0) >= 9, label + ": a fenced paddock")
		assert_eq(counts.get("crate", 0), 3, label + ": a three-crate stash")
		assert_eq(stash.values(), [3], label + ": the stash is one group")
		assert_eq(counts.get("haybale", 0), 2, label + ": two hay bales")
		assert_true(counts.get("logpile", 0) >= 1, label + ": a log pile at the far corner")
	assert_false(WorldSkin.new(Levels.get_def(&"orchard")).recipeContext([], []).homePaddock, "only where a level asks for it")

func test_orchard_hedgerows_are_walls_with_gates():
	var walls := 0
	var gates := 0
	var cells := 0
	for entry in wideRecipes(&"orchard"):
		var recipe: Dictionary = entry[1]
		var map: WorldMap = entry[2]
		var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
		for p in recipe.props:
			assert_ne(p[0], "hedge", "no breakable hedges on Orchard Lanes")
			if p[0] == "farmgate": gates += 1
		assert_true(recipe.pieces.size() + recipe.fieldWalls.size() <= ChunkRecipe.MAX_PIECES, "%s: pieces in budget" % entry[0])
		for box in recipe.fieldWalls:
			walls += 1
			assert_eq(box.size(), 4, "a box")
			var c: Vector2 = (box[0] + box[2]) * 0.5
			assert_true(Geometry2D.decompose_polygon_in_convex(box).size() == 1, "convex")
			assert_false(onTrack(map, origin + c), "%s: hedgerows keep off the farm tracks (the lanes)" % (origin + c))
			assert_false(map.blockedAt(origin + c), "%s: on open ground" % (origin + c))
		if recipe.decor.has("hedgerow"): cells += recipe.decor["hedgerow"].size() / 12
		if not recipe.fieldWalls.is_empty(): assert_true(recipe.decor.has("hedgerow"), "%s: walls are drawn" % entry[0])
	assert_gt(walls, 20, "Orchard Lanes has hedgerow walls")
	assert_gt(gates, 3, "with farm gates in the gaps")
	assert_gt(cells, walls, "drawn as hedgerow decor")
	print("  orchard: %d hedgerow boxes, %d gates, %d decor cells in 15 chunks" % [walls, gates, cells])
	#nearly straight lanes
	var r := ChunkRecipe.new()
	r.mapSeed = SEED
	r.ctx = WorldSkin.new(Levels.get_def(&"orchard")).recipeContext([], [])
	for k in 12:
		var u: Vector2 = r.fieldFrame(Vector2i(k - 6, k % 3))[2]
		assert_true(absf(u.angle()) <= 0.1201, "lattice turned %.3f rad at most 0.12" % u.angle())

func test_bayou_mixes_fords_and_bridges():
	var fords := 0
	var bridges := 0
	for worldSeed in [1, 2, 3]:
		var map := WorldMap.build(worldSeed, Levels.get_def(&"bayou"), "", Vector2.ZERO)
		var kinds := {}
		for i in map.crossings:
			if map.flags[i] & WorldGen.CROSSING == 0: continue
			var t := map.terrain[i]
			if t != Root.terrain.SHALLOWS && t != Root.terrain.BRIDGE: continue
			var root := WorldGen.crossingRoot(map.flags, i)
			assert_true(kinds.get(root, t) == t, "a crossing is all ford or all bridge (root %d)" % root)
			kinds[root] = t
		for root in kinds:
			if kinds[root] == Root.terrain.SHALLOWS: fords += 1
			else: bridges += 1
	var share := float(fords) / maxf(fords + bridges, 1.0)
	assert_between(share, 0.2, 0.6, "about 40%% of Snapper Bayou's crossings are fords (%d fords, %d bridges)" % [fords, bridges])
	#a ford opens at its full width in the fine raster
	var map := WorldMap.build(1, Levels.get_def(&"bayou"), "", Vector2.ZERO)
	var checked := 0
	for i in map.crossings:
		if map.terrain[i] != Root.terrain.SHALLOWS || checked >= 4: continue
		var cell := Vector2i(i % WorldGen.W, i / WorldGen.W)
		var center := WorldGen.cellCenter(cell)
		map.buildNow(WorldGen.chunkOf(center))
		assert_false(map.lethalAt(center), "the ford at %s is passable" % center)
		checked += 1
	assert_gt(checked, 0, "fords to check")

func test_canyon_slots_are_narrow_and_hold_a_coin_line():
	var def := Levels.get_def(&"canyon")
	var map := WorldMap.build(2, def, "", Vector2.ZERO)
	var skin := WorldSkin.new(def)
	map.recipeContext = skin.recipeContext([], [])
	var share: float = def.features.slotShare
	var slots := 0
	var passes := 0
	var narrow := 0
	var wide := 0
	var coins := 0
	var seen := {}
	for i in map.crossings:
		if map.flags[i] & WorldGen.CROSSING == 0 || map.terrain[i] == Root.terrain.SHALLOWS || map.terrain[i] == Root.terrain.BRIDGE: continue
		var cell := Vector2i(i % WorldGen.W, i / WorldGen.W)
		var center := WorldGen.cellCenter(cell)
		if absf(center.x) > 50000.0 || absf(center.y) > 25000.0: continue
		var root := WorldGen.crossingRoot(map.flags, i)
		if seen.has(root): continue
		seen[root] = true
		var slot := WorldGen.isSlot(map.worldSeed, map.flags, i, share)
		if slot: slots += 1
		else: passes += 1
		if slots + passes > 40: break
		#the open width across the way through, at the crossing's first cell's center
		var across := Vector2.DOWN if map.flags[i] & WorldGen.CROSS_X != 0 else Vector2.RIGHT
		map.buildNow(WorldGen.chunkOf(center))
		var width := 0.0
		for s in [-1.0, 1.0]:
			for d in range(32, 1400, 32):
				var q: Vector2 = center + across * s * d
				map.buildNow(WorldGen.chunkOf(q))
				if map.blockedAt(q):
					width += d
					break
				if d >= 1368: width += 1400.0
		if slot && width < def.features.passWidth * 0.75: narrow += 1
		if not slot && width >= def.features.slotWidth * 1.4: wide += 1
		if slot && coins == 0:
			var chunk := WorldGen.chunkOf(center)
			var recipe := map.recipeOf(chunk)
			for p in recipe.get("pickups", []):
				if p[0] == "coin" && (Vector2(chunk) * ChunkRecipe.CHUNK + p[1]).distance_to(center) < WorldGen.CELL * 2.0: coins += 1
	assert_gt(slots, 0, "Red Canyon has slot canyons")
	assert_gt(passes, 0, "and wide passes")
	assert_between(float(slots) / (slots + passes), 0.1, 0.55, "about 30%% are slots (%d of %d)" % [slots, slots + passes])
	assert_gt(narrow, 0, "slots are narrower than passes (%d narrow of %d slots)" % [narrow, slots])
	assert_gt(wide, 0, "passes stay wide")
	assert_gt(coins, 2, "a coin line runs through a slot (%d coins)" % coins)

func test_moose_woods_thickets_are_walls_drawn_as_crowns():
	var def := Levels.get_def(&"moosewoods")
	var crowns := 0
	var pines := 0
	var treeline := 0
	for worldSeed in [1, 2]:
		var recs := wideRecipes(&"moosewoods", worldSeed)
		var map: WorldMap = recs[0][2]
		var hills := 0
		var open := 0
		for f in map.flags:
			if f & WorldGen.BLOCKED == 0: open += 1
		for i in map.terrain.size():
			if map.terrain[i] == Root.terrain.HILLS: hills += 1
		var share := float(hills) / map.terrain.size()
		assert_between(share, 0.05, 0.35, "seed %d: thickets cover %.1f%% of the map" % [worldSeed, share * 100.0])
		var ctx: Dictionary = map.recipeContext
		var stripName: String = WorldSkin.new(def).stripNames[ctx.wallStrip]
		assert_eq(stripName, "treeline", "thicket lips are the treeline strip")
		for entry in recs:
			var recipe: Dictionary = entry[1]
			if recipe.decor.has("pine_crown"):
				var buf: PackedFloat32Array = recipe.decor["pine_crown"]
				for n in range(0, buf.size(), 12):
					var p := Vector2(buf[n + 3], buf[n + 7])
					assert_true(ChunkRecipe.fieldAt(map.rasters[entry[0]].wall, p) < 0.0, "%s: a crown on a thicket" % entry[0])
					crowns += 1
			for line in recipe.lines:
				if line[0] == ctx.wallStrip: treeline += 1
			for p in recipe.props:
				if p[0] == "pine": pines += 1
	assert_gt(crowns, 50, "thickets are drawn as pine crowns")
	assert_gt(treeline, 10, "with a treeline lip")
	assert_gt(pines, 5, "real pines stand at their edges")
	print("  moose woods: %d crowns, %d treeline lines, %d pines in 30 chunks" % [crowns, treeline, pines])

func test_the_skin_loads_motif_members_and_spill_leftovers():
	var skin := WorldSkin.new(Levels.get_def(&"prairie"))
	for id in [&"log", &"logpile", &"watertower", &"beehive", &"carcass", &"deadtree", &"landmark_wild"]: assert_true(skin.propScenes.has(id), "Prairie loads %s" % id)
	assert_false(skin.propScenes.has(&"tent"), "no Tribe camps in The Wilds")
	var ctx := skin.recipeContext([], [])
	assert_true(ctx.fieldDensity.has("fence") && ctx.fieldDensity.has("hedge"), "field props for the workers")
	assert_true(ctx.motifs.size() > 0 && ctx.motifDefs.has("orchard"), "motifs for the workers")
	assert_eq(ctx.props["oak"].nodes, 5, "an oak costs its canopy too")
