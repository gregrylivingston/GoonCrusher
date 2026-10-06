extends GameTest

#The level registry (Levels, LevelDef, LevelRoster): every level has a def and a thin scene, the
#numbers escalate with the order, rosters name real goons of the right faction and can fill a region,
#and the faction band holds.

const IDS := [&"prairie", &"bayou", &"canyon", &"quarry", &"frostbite", &"highway", &"city", &"crusher"]
const GRAMMARS := [&"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city", &"yard"]

var savedLevel: int

func before_each():
	savedLevel = SaveManager.playerData.selectedLevel

func after_each():
	SaveManager.playerData.selectedLevel = savedLevel

func test_registry_order():
	assert_eq(Levels.count(), 8)
	assert_eq(Levels.ORDER, IDS, "the eight levels in order")
	for i in IDS.size():
		assert_eq(Levels.indexOf(IDS[i]), i)
		assert_eq(Levels.defAt(i), Levels.get_def(IDS[i]), "%s: defAt and get_def agree" % IDS[i])
	assert_null(Levels.get_def(&"nowhere"), "unknown ids have no def")
	assert_null(Levels.defAt(-1))
	assert_null(Levels.defAt(Levels.count()))

func test_ids_are_unique():
	var seen := {}
	for id in Levels.ORDER:
		assert_false(seen.has(id), "%s listed once" % id)
		seen[id] = true

func test_every_def_loads_and_is_valid():
	var lastAct := 1
	var last: LevelDef = null
	for i in Levels.count():
		var id: StringName = Levels.ORDER[i]
		assert_true(ResourceLoader.exists(Levels.defPath(id)), "%s: def file" % id)
		var def := Levels.defAt(i)
		if def == null:
			fail("%s: def does not load" % id)
			continue
		assert_eq(def.id, id, "%s: id matches its file" % id)
		assert_eq(def.order, i, "%s: order matches the registry" % id)
		assert_eq(def.grammar, GRAMMARS[i], "%s: grammar" % id)
		assert_true(Levels.GRAMMAR_TEXT.has(def.grammar), "%s: grammar has Goonopedia text" % id)
		assert_true(def.displayName != "", "%s: display name" % id)
		assert_true(def.blurb != "", "%s: blurb" % id)
		assert_true(ResourceLoader.exists(def.poster), "%s: poster %s exists" % [id, def.poster])
		assert_between(def.act, lastAct, 3, "%s: acts never go back" % id)
		lastAct = def.act
		assert_true(def.factionBand.x < def.factionBand.y, "%s: faction band min < max" % id)
		assert_between(def.sprintSlack, 1.1, 1.5, "%s: sprint slack" % id)
		assert_gt(def.pickupsPerChunk, 0, "%s: pickups per chunk" % id)
		assert_false(def.pickupTable.is_empty(), "%s: pickup table" % id)
		assert_false(def.baseTerrain.is_empty(), "%s: base terrain" % id)
		for f in 3: assert_true(def.dressing.has(f), "%s: dressing for faction %d" % [id, f])
		assert_true(def.modes.is_empty(), "%s: every mode on offer" % id)
		if last != null:
			assert_true(def.seconds >= last.seconds, "%s: the clock never shrinks" % id)
			assert_true(def.spawnTimer <= last.spawnTimer, "%s: goons never come slower" % id)
			assert_true(def.giantOdds >= last.giantOdds, "%s: giants never get rarer" % id)
			assert_true(def.sprintSlack <= last.sprintSlack, "%s: slack never grows" % id)
		last = def
	assert_eq(Levels.defAt(0).seconds, 250, "the first level keeps the old Easy clock")
	assert_eq(Levels.defAt(7).seconds, 540, "the last keeps Northern Wastes'")

func test_rosters_name_real_goons_of_their_faction():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for f in def.roster:
			for goon in def.roster[f]:
				assert_true(Goons.DATA.has(goon), "%s: %s is in Goons.DATA" % [id, goon])
				if Goons.DATA.has(goon): assert_eq(Goons.DATA[goon].faction, int(f), "%s: %s belongs to faction %d" % [id, goon, f])

func test_every_faction_roster_can_fill_a_region():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for f in 3:
			var ids := LevelRoster.rosterFor(def, f)
			var source := LevelRoster.rosterFaction(def, f)
			assert_gt(ids.filter(func(g): return Goons.DATA[g].rank == 1).size(), 0, "%s/%d: a rank-1 goon" % [id, f])
			assert_true(ids.filter(func(g): return Goons.DATA[g].rank >= 2).size() >= 2, "%s/%d: two rank-2+ goons" % [id, f])
			for g in ids:
				assert_eq(Goons.DATA[g].faction, source, "%s/%d: %s from the roster's faction" % [id, f, g])
			for i in ids.size() - 1:
				assert_true(Goons.DATA[ids[i]].rank <= Goons.DATA[ids[i + 1]].rank, "%s/%d: lowest rank first" % [id, f])

func test_short_rosters_are_padded_and_empty_ones_fall_back_to_the_tribe():
	var prairie := Levels.get_def(&"prairie")
	var scrap := LevelRoster.rosterFor(prairie, Goons.faction.SCRAP)
	for g in [&"spoke", &"karter", &"sawbot"]: assert_true(g in scrap, "authored %s kept" % g)
	assert_true(scrap.size() >= 5, "two rank-2+ Scrap goons padded in")
	var crusher := Levels.get_def(&"crusher")
	assert_eq(LevelRoster.rosterFaction(crusher, Goons.faction.WILD), Goons.faction.TRIBE, "The Crusher has no Wild Things")
	for g in LevelRoster.rosterFor(crusher, Goons.faction.WILD): assert_eq(Goons.DATA[g].faction, Goons.faction.TRIBE)

func test_invalid_roster_ids_are_dropped():
	var def := LevelDef.new()
	def.id = &"test_bad_roster"
	def.roster = {Goons.faction.WILD: [&"jackalope", &"no_such_goon", &"grunt", &"goonling"]}
	var ids := LevelRoster.rosterFor(def, Goons.faction.WILD)
	assert_true(&"jackalope" in ids)
	assert_false(&"no_such_goon" in ids, "unknown ids are dropped")
	assert_false(&"grunt" in ids, "another faction's goons are dropped")
	assert_false(&"goonling" in ids, "rank 0 never spawns from regions")
	LevelRoster.cache.erase("test_bad_roster:0")

func test_pick_goons_lowest_rank_first_and_seeded():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for f in 3:
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var three := LevelRoster.pickGoons(def, f, rng)
			assert_eq(three.size(), 3, "%s/%d: three goons" % [id, f])
			var roster := LevelRoster.rosterFor(def, f)
			assert_eq(Goons.DATA[three[0]].rank, Goons.DATA[roster[0]].rank, "%s/%d: slot 1 is the lowest rank" % [id, f])
			for g in three.slice(1): assert_gt(Goons.DATA[g].rank, Goons.DATA[three[0]].rank, "%s/%d: %s outranks slot 1" % [id, f, g])
			for g in three: assert_true(g in roster, "%s/%d: %s from the roster" % [id, f, g])
			var again := RandomNumberGenerator.new()
			again.seed = 11
			assert_eq(LevelRoster.pickGoons(def, f, again), three, "%s/%d: same seed, same goons" % [id, f])

func test_faction_band_clamps_the_score():
	var prairie := Levels.get_def(&"prairie")
	assert_eq(LevelRoster.factionAt(prairie, 0.0, 0.0), Goons.faction.WILD, "the prairie starts wild")
	assert_eq(LevelRoster.factionAt(prairie, Goons.CHUNK_PX * 40.0, 0.4), Goons.faction.TRIBE, "and never reaches the Scrap Gang")
	var crusher := Levels.get_def(&"crusher")
	assert_eq(LevelRoster.factionAt(crusher, 0.0, -0.4), Goons.faction.SCRAP, "The Crusher is Scrap from the start")
	var quarry := Levels.get_def(&"quarry")
	for d in [0.0, Goons.CHUNK_PX * 40.0]:
		for j in [-0.4, 0.4]: assert_eq(LevelRoster.factionAt(quarry, d, j), Goons.faction.TRIBE, "the quarry is the Tribe's")
	assert_almost_eq(LevelRoster.factionScore(Goons.CHUNK_PX * 2.0, 0.1, Vector2(0, 5)), 0.8, 0.0001, "Goons.factionFor's score without the level term")

func test_region_uses_the_selected_level():
	SaveManager.playerData.selectedLevel = Levels.indexOf(&"crusher")
	var region: Dictionary = Region.createRegion(Root.terrain.GRASS)
	assert_eq(region.faction, Goons.faction.SCRAP, "The Crusher's band makes every region Scrap")
	var roster := LevelRoster.rosterFor(Levels.get_def(&"crusher"), Goons.faction.SCRAP)
	for g in region.goon: assert_true(g in roster, "%s from The Crusher's roster" % g)
	SaveManager.playerData.selectedLevel = Levels.indexOf(&"prairie")
	region = Region.createRegion(Root.terrain.SAND)
	assert_eq(region.faction, Goons.faction.WILD, "the prairie's start is wild")
	for g in region.goon: assert_true(g in Levels.get_def(&"prairie").roster[Goons.faction.WILD] || g in LevelRoster.rosterFor(Levels.get_def(&"prairie"), Goons.faction.WILD))

func test_demo_is_the_first_three():
	assert_eq(Root.DEMO_LEVEL_COUNT, 3)
	assert_eq(Levels.ORDER.slice(0, Root.DEMO_LEVEL_COUNT), [&"prairie", &"bayou", &"canyon"])
	var levels = PlayerData.new().levels
	for i in levels.size(): assert_eq(levels[i].unlocked, i < 3, "%s open in a new save" % levels[i].id)

func test_thin_scenes_exist_and_set_their_def():
	for id in Levels.ORDER:
		var path := Levels.scenePath(id)
		assert_true(ResourceLoader.exists(path), "%s: thin scene" % id)
		var packed: PackedScene = load(path)
		if packed == null: continue
		var state := packed.get_state()
		var def = null
		var others := []
		for p in state.get_node_property_count(0):
			var name := state.get_node_property_name(0, p)
			if name == &"def": def = state.get_node_property_value(0, p)
			else: others.push_back(name)
		assert_true(def is LevelDef, "%s: sets def" % id)
		if def is LevelDef: assert_eq(def.resource_path, Levels.defPath(id), "%s: its own def" % id)
		assert_eq(state.get_node_count(), 1, "%s: overrides nothing below the root" % id)
		assert_eq(state.get_base_scene_state().get_path(), "res://scene/level/levelRoot.tscn", "%s: inherits levelRoot" % id)

func test_level_root_copies_the_def():
	var def := Levels.get_def(&"canyon")
	var level = load(Levels.scenePath(&"canyon")).instantiate()
	level.applyDef()
	assert_eq(level.seconds, def.seconds, "clock")
	var spawn = level.get_node("SpawnManager")
	assert_eq(spawn.spawnTimer, def.spawnTimer, "spawn timer")
	assert_eq(spawn.giantOdds, def.giantOdds, "giants")
	assert_almost_eq(spawn.escalationSpeed, def.escalationSpeed, 0.0001, "escalation")
	assert_almost_eq(level.slack(), def.sprintSlack, 0.0001, "sprint slack")
	assert_eq(Array(level.get_node("TileManager").requestedObjectTiles), Array(def.objectTiles), "the interim object pools")
	level.seconds = 99
	level.applyDef()
	assert_eq(level.seconds, 99, "applied once, so the bench's later overrides stand")
	level.free()

func test_resolve_level_arguments():
	assert_eq(Levels.resolve("prairie"), &"prairie")
	assert_eq(Levels.resolve("0"), &"prairie", "0-based index")
	assert_eq(Levels.resolve("7"), &"crusher")
	assert_eq(Levels.resolve("level_city"), &"city", "scene basename")
	assert_eq(Levels.resolve("res://scene/level/levels/level_bayou.tscn"), &"bayou", "scene path")
	assert_eq(Levels.resolve("level_grass_1"), &"prairie", "old scene names map by index")
	assert_eq(Levels.resolve("level_snow_1"), &"crusher")
	assert_eq(Levels.resolve("nowhere"), &"")
	assert_eq(Levels.resolve("8"), &"")

func test_sprint_clocks_fit_the_stock_sedan():
	const SEDAN_SLOWEST_TOP_SPEED = 499.0
	const SEDAN_TANK_SECONDS = 87.0
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for yRoll in [-1.0, 0.0, 1.0]:
			var distance = Level.sprintOffsetPx(def.seconds, yRoll).length()
			var clock = Level.sprintSeconds(distance, def.seconds, def.sprintSlack)
			assert_gt(clock, distance / Level.REFERENCE_SPEED, "%s: slack above 1" % id)
			assert_gt(SEDAN_SLOWEST_TOP_SPEED, distance / clock, "%s: the sedan is fast enough even on sand" % id)
			assert_gt(SEDAN_TANK_SECONDS * 0.8, distance / SEDAN_SLOWEST_TOP_SPEED, "%s: one tank is enough" % id)

func test_snapshot_is_a_plain_copy():
	var def := Levels.get_def(&"prairie")
	var snap := def.snapshot()
	assert_eq(snap.id, &"prairie")
	assert_eq(snap.seconds, def.seconds)
	snap.roster[Goons.faction.WILD].push_back(&"grunt")
	assert_false(&"grunt" in def.roster[Goons.faction.WILD], "deep copy: the def is untouched")
