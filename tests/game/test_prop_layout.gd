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
	for entry in recipes(&"prairie"):
		var r := ChunkRecipe.new()
		r.mapSeed = SEED
		var origin := Vector2(entry[0]) * ChunkRecipe.CHUNK
		for p in entry[1].props:
			if not p[0] in ["fence", "hedge"]: continue
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
		for faction in def.motifs:
			for motif in def.motifs[faction]: assert_true(WorldSkin.MOTIFS.has(StringName(motif)), "%s: motif %s exists" % [id, motif])
	for motif in WorldSkin.MOTIFS:
		for m in WorldSkin.MOTIFS[motif].members: assert_true(WorldSkin.loadManifest().has(m[0]), "%s: %s is baked" % [motif, m[0]])
	var prairie := Levels.get_def(&"prairie")
	assert_true(prairie.features.get("fenceDensity", 0.0) > 0.0 && prairie.features.get("hedgeDensity", 0.0) > 0.0, "Prairie's field densities are read now")

func test_the_skin_loads_motif_members_and_spill_leftovers():
	var skin := WorldSkin.new(Levels.get_def(&"prairie"))
	for id in [&"tent", &"firepit", &"wreck", &"log", &"logpile", &"watertower", &"beehive"]: assert_true(skin.propScenes.has(id), "Prairie loads %s" % id)
	var ctx := skin.recipeContext([], [])
	assert_true(ctx.fieldDensity.has("fence") && ctx.fieldDensity.has("hedge"), "field props for the workers")
	assert_true(ctx.motifs.size() > 0 && ctx.motifDefs.has("orchard"), "motifs for the workers")
	assert_eq(ctx.props["oak"].nodes, 5, "an oak costs its canopy too")
