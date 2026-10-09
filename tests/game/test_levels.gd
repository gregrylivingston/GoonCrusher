extends GameTest

#The level registry (Levels, LevelDef, LevelRoster, Territories): every level has a def and a thin scene, five
#stops in each of six regions, the numbers escalate along each region's road, line-ups name real goons of their
#region's class and can fill a district.

const IDS := [&"prairie", &"orchard", &"bayou", &"canyon", &"moosewoods", &"mudlick", &"stilttown", &"lantern", &"sawmill", &"quarry",
	&"highway", &"ghosttown", &"saltflats", &"raiderpass", &"thunderroad", &"frostbite", &"frozenlake", &"timberline", &"tarpits", &"summit",
	&"city", &"manhole", &"culdesac", &"gridlock", &"blockparty", &"blastpits", &"tankfarm", &"slagfields", &"theline", &"crusher"]
const KEPT := {&"prairie": &"meadow", &"bayou": &"bayou", &"canyon": &"canyon", &"quarry": &"quarry", &"frostbite": &"mountain",
	&"highway": &"highway", &"city": &"city", &"crusher": &"yard"}
const LANDSCAPES := [&"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city", &"scrapyard", &"forest", &"forest_snow",
	&"coast", &"ghosttown", &"saltflats", &"volcano", &"suburbs"]

var savedLevel: int

func before_each():
	savedLevel = SaveManager.playerData.selectedLevel

func after_each():
	SaveManager.playerData.selectedLevel = savedLevel

func test_registry_order():
	assert_eq(Levels.count(), 30)
	assert_eq(Levels.ORDER, IDS, "the thirty levels in road order")
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

func test_six_regions_of_five_stops():
	assert_eq(Territories.ORDER.size(), 6)
	for r in Territories.ORDER.size():
		var region: StringName = Territories.ORDER[r]
		var ids := Territories.levelsOf(region)
		assert_eq(ids.size(), Territories.STOPS, "%s: five stops" % region)
		for s in ids.size():
			var def := Levels.get_def(ids[s])
			assert_eq(def.region, region, "%s: in %s" % [ids[s], region])
			assert_eq(def.stop, s + 1, "%s: stop %d" % [ids[s], s + 1])
			assert_eq(def.isFinale(), s == Territories.STOPS - 1, "%s: only stop 5 is a finale" % ids[s])
			assert_eq(Levels.regionAt(Levels.indexOf(ids[s])), region)
		var d := Territories.get_def(region)
		assert_true(Goons.CLASSES.has(d.class), "%s: its class exists" % region)
		assert_eq(d.nameFirst.size(), 10, "%s: ten district first words" % region)
		assert_eq(d.dressing.size(), 3, "%s: dressing for three zones" % region)
		assert_eq(d.motifs.size(), 3, "%s: motifs for three zones" % region)
		for key in ["speed", "damage", "crush"]: assert_between(float(d.step[key]), 1.0, 1.3, "%s: a light %s step" % [region, key])
	assert_eq(Territories.ORDER.map(Territories.classOf), Goons.CLASS_ORDER, "one class per region, in order")
	assert_eq(Territories.ORDER.filter(Territories.isDemo), [&"wilds", &"tribe"], "the demo is the first two regions")

func test_every_def_loads_and_is_valid():
	for i in Levels.count():
		var id: StringName = Levels.ORDER[i]
		assert_true(ResourceLoader.exists(Levels.defPath(id)), "%s: def file" % id)
		var def := Levels.defAt(i)
		if def == null:
			fail("%s: def does not load" % id)
			continue
		assert_eq(def.id, id, "%s: id matches its file" % id)
		assert_eq(def.order, i, "%s: order matches the registry" % id)
		assert_true(def.landscape in LANDSCAPES, "%s: landscape %s is one of the fourteen (+ snow)" % [id, def.landscape])
		if KEPT.has(id): assert_eq(def.grammar, KEPT[id], "%s: a kept level keeps its grammar" % id)
		assert_true(Level.ROUTE_FACTOR.has(def.grammar), "%s: grammar %s" % [id, def.grammar])
		assert_true(def.displayName != "", "%s: display name" % id)
		assert_true(def.blurb != "", "%s: blurb" % id)
		assert_true(ResourceLoader.exists(def.poster), "%s: poster %s exists" % [id, def.poster])
		assert_between(def.sprintSlack, 1.1, 1.5, "%s: sprint slack" % id)
		assert_gt(def.pickupsPerChunk, 0, "%s: pickups per chunk" % id)
		assert_false(def.pickupTable.is_empty(), "%s: pickup table" % id)
		assert_false(def.baseTerrain.is_empty(), "%s: base terrain" % id)
		assert_between(def.lineup.size(), 3, 6, "%s: a line-up of 3 to 6" % id)
		if def.rules.has("nightShare"): assert_between(float(def.rules.nightShare), 0.0, 1.0, "%s: night share" % id)
		for kind in def.rules.get("events", {}): assert_true(kind in PickupWorld.EVENTS, "%s: event %s exists" % [id, kind])
	assert_eq(Levels.get_def(&"bayou").displayName, "Snapper Bayou")
	assert_eq(Levels.get_def(&"lantern").rules.get("nightShare", 0.0), 0.75, "Lantern Marsh is mostly night")

#the curve rises along each region's road: stop by stop within a region, and each region's opener eases one
#step below the finale before it
func test_numbers_rise_by_region():
	var last: LevelDef = null
	for i in Levels.count():
		var def := Levels.defAt(i)
		if last != null && def.region == last.region:
			assert_true(def.seconds >= last.seconds, "%s: the clock never shrinks along a road" % def.id)
			assert_true(def.spawnTimer <= last.spawnTimer, "%s: goons never come slower" % def.id)
			assert_true(def.giantOdds >= last.giantOdds, "%s: giants never get rarer" % def.id)
			assert_true(def.escalationSpeed >= last.escalationSpeed, "%s: escalation never slows" % def.id)
			assert_true(def.sprintSlack <= last.sprintSlack, "%s: slack never grows" % def.id)
		elif last != null:
			assert_true(def.seconds <= last.seconds, "%s: a region's opener eases after the finale before it" % def.id)
			var opener := Levels.defAt(i - Territories.STOPS)
			assert_gt(def.seconds, opener.seconds, "%s: but is harder than the last region's opener" % def.id)
		last = def
	assert_eq(Levels.defAt(0).seconds, 240, "the first level's clock")
	assert_eq(Levels.defAt(29).seconds, 530, "the last's")

#every class member plays in its region, except a goon its region hands to another class (the Tribe's Yeti and
#Boulder play in Big Game), which must play there instead
func test_line_ups_are_their_class_and_cover_it():
	var everywhere := {}
	for id in Levels.ORDER:
		for goon in Levels.get_def(id).lineup: everywhere[goon] = true
	for region in Territories.ORDER:
		var members := Goons.classMembers(Territories.classOf(region))
		var covered := {}
		for id in Territories.levelsOf(region):
			var def := Levels.get_def(id)
			for goon in def.lineup:
				assert_true(Goons.DATA.has(goon), "%s: %s is in Goons.DATA" % [id, goon])
				assert_true(goon in members, "%s: %s is of %s's class" % [id, goon, region])
				covered[goon] = true
			assert_eq(LevelRoster.lineupFor(def).size(), def.lineup.size(), "%s: every line-up goon is valid" % id)
		for goon in members:
			assert_true(covered.has(goon) || everywhere.has(goon), "%s: %s plays in its region or another's" % [region, goon])
		assert_true(covered.size() >= members.size() - 2, "%s: its levels field nearly all of its class" % region)

func test_classes_hold_their_factions_and_elites():
	for c in Goons.CLASS_ORDER:
		var members := Goons.classMembers(c)
		assert_gt(members.size(), 9, "%s: ten or more goons" % c)
		var f: int = Goons.CLASSES[c].faction
		for g in members:
			assert_true(Goons.DATA.has(g), "%s: %s exists" % [c, g])
			assert_gt(int(Goons.DATA[g].rank), 0, "%s: %s spawns from districts" % [c, g])
			if f >= 0: assert_eq(int(Goons.DATA[g].faction), f, "%s: %s is of its faction" % [c, g])
		if f >= 0: #a faction's class is every rank-1+ member
			var all := Goons.DATA.keys().filter(func(id): return Goons.DATA[id].faction == f && Goons.DATA[id].rank > 0)
			assert_eq(members.size(), all.size(), "%s: every member of the faction" % c)
		else:
			assert_true(Goons.isElite(c), "%s: elite" % c)
			var factions := {}
			for g in members: factions[Goons.DATA[g].faction] = true
			assert_gt(factions.size(), 1, "%s: drawn from more than one faction" % c)
	assert_eq(Goons.classesOf(&"tusker"), [&"wild", &"biggame"])
	assert_eq(Goons.classesOf(&"goonling"), [], "the Goonling is spawn-only")

func test_invalid_line_up_ids_are_dropped():
	var def := LevelDef.new()
	def.id = &"test_bad_lineup"
	def.region = &"wilds"
	def.lineup = [&"jackalope", &"no_such_goon", &"goonling", &"tusker"]
	var ids := LevelRoster.lineupFor(def)
	assert_eq(ids, [&"jackalope", &"tusker"], "unknown and rank-0 ids are dropped")
	LevelRoster.cache.erase("test_bad_lineup")
	def.id = &"test_empty_lineup"
	def.lineup = []
	assert_eq(LevelRoster.lineupFor(def), LevelRoster.validIds(Goons.classMembers(&"wild")), "an empty line-up falls back to the region's class")
	LevelRoster.cache.erase("test_empty_lineup")

func test_pick_goons_lowest_rank_first_and_seeded():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var three := LevelRoster.pickGoons(def, rng)
		assert_eq(three.size(), 3, "%s: three goons" % id)
		var lineup := LevelRoster.lineupFor(def)
		var lowest := 9
		for g in lineup: lowest = mini(lowest, Goons.DATA[g].rank)
		assert_eq(Goons.DATA[three[0]].rank, lowest, "%s: slot 1 is the line-up's lowest rank" % id)
		for g in three: assert_true(g in lineup, "%s: %s from the line-up" % [id, g])
		assert_ne(three[1], three[0], "%s: slot 2 is another goon" % id)
		var again := RandomNumberGenerator.new()
		again.seed = 11
		assert_eq(LevelRoster.pickGoons(def, again), three, "%s: same seed, same goons" % id)
	var short := RandomNumberGenerator.new()
	assert_eq(LevelRoster.pickFrom([&"grunt"], short), [&"grunt", &"grunt", &"grunt"], "one goon fills all three slots")

func test_zones_rise_with_distance():
	assert_eq(Territories.zoneFor(0.0, 0.0), 0, "the start is zone 0")
	assert_eq(Territories.zoneFor(Goons.CHUNK_PX * 4.0, 0.0), 1, "four chunks out is zone 1")
	assert_eq(Territories.zoneFor(Goons.CHUNK_PX * 8.0, 0.0), 2, "far out is zone 2")

func test_region_uses_the_selected_level():
	SaveManager.playerData.selectedLevel = Levels.indexOf(&"crusher")
	var region: Dictionary = Region.createRegion(Root.terrain.GRASS)
	var lineup := LevelRoster.lineupFor(Levels.get_def(&"crusher"))
	for g in region.goon: assert_true(g in lineup, "%s from The Crusher's line-up" % g)
	assert_eq(region.faction, Goons.DATA[region.goon[0]].faction, "the region's faction is its first goon's")
	SaveManager.playerData.selectedLevel = Levels.indexOf(&"prairie")
	region = Region.createRegion(Root.terrain.SAND)
	for g in region.goon: assert_true(g in Levels.get_def(&"prairie").lineup, "%s from the prairie's line-up" % g)

func test_demo_is_the_first_two_regions():
	assert_eq(Root.DEMO_LEVEL_COUNT, 10)
	assert_eq(Root.DEMO_MODES, [Root.gameModes.GOONCRUSHER, Root.gameModes.SPRINT, Root.gameModes.MARATHON])
	for i in Levels.count(): assert_eq(i < Root.DEMO_LEVEL_COUNT, Territories.isDemo(Levels.defAt(i).region), "%s: in the demo by its region" % Levels.ORDER[i])
	var levels = PlayerData.new().levels
	for i in levels.size(): assert_eq(levels[i].unlocked, i == 0, "%s: only the first is open in a new save" % levels[i].id)

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
	var tier: int = level.tier
	assert_almost_eq(spawn.spawnTimer, def.spawnTimer * ModeTiers.SPAWN_TIMER[tier], 0.0001, "spawn timer, by tier")
	assert_eq(spawn.giantOdds, def.giantOdds + ModeTiers.GIANT_ODDS[tier], "giants, by tier")
	assert_almost_eq(spawn.escalationSpeed, def.escalationSpeed * ModeTiers.ESCALATION[tier], 0.0001, "escalation, by tier")
	assert_almost_eq(level.slack(), def.sprintSlack * ModeTiers.SLACK[tier], 0.0001, "sprint slack, by tier")
	assert_eq(level.strength, Territories.step(&"wilds"), "the region's strength step")
	level.seconds = 99
	level.applyDef()
	assert_eq(level.seconds, 99, "applied once, so the bench's later overrides stand")
	level.free()

func test_elite_regions_step_goons_up():
	for region in [&"wilds", &"tribe", &"raiders"]: assert_eq(Territories.step(region), Territories.NO_STEP, "%s: the factions are x1" % region)
	assert_almost_eq(float(Territories.step(&"hunting").crush), 1.1, 0.001, "Big Game is harder to crush")
	assert_almost_eq(float(Territories.step(&"sprawl").speed), 1.1, 0.001, "the Swarm is faster")
	assert_almost_eq(float(Territories.step(&"works").damage), 1.2, 0.001, "War Machine hits harder")
	var walker = Walker.new()
	walker.speed = 100.0
	walker.attackDamage = 10.0
	walker.crushSpeed = 200.0
	walker.frontArmor = 99999.0
	walker.applyStrength(Territories.step(&"works"))
	assert_almost_eq(walker.speed, 110.0, 0.01)
	assert_almost_eq(walker.attackDamage, 12.0, 0.01)
	assert_almost_eq(walker.crushSpeed, 220.0, 0.01)
	assert_eq(walker.frontArmor, 99999.0, "an uncrushable front stays uncrushable")
	walker.free()

func test_level_rules_weigh_events_and_night():
	var open := ["goldgoon", "truck", "bowling", "rings"]
	for i in 20: assert_eq(PickupWorld.pickEvent(open, {"rings": 3}), "rings", "only the weighted event")
	assert_eq(PickupWorld.pickEvent(["truck"], {"rings": 3}), "", "an open event weighing 0 never starts")
	assert_true(PickupWorld.pickEvent(open, {}) in open, "no weights: any open event")
	assert_eq(PickupWorld.pickEvent([], {}), "")
	assert_eq(Levels.get_def(&"saltflats").rules.events.rings, 3, "Salt Flats favour Ring Runs")
	assert_eq(Levels.get_def(&"culdesac").rules.nightShare, 0.75, "Cul-de-Sac is mostly night")
	assert_false(Levels.get_def(&"prairie").rules.has("nightShare"), "Prairie keeps the old cycle")

func test_resolve_level_arguments():
	assert_eq(Levels.resolve("prairie"), &"prairie")
	assert_eq(Levels.resolve("0"), &"prairie", "0-based index")
	assert_eq(Levels.resolve("29"), &"crusher")
	assert_eq(Levels.resolve("9"), &"quarry")
	assert_eq(Levels.resolve("level_city"), &"city", "scene basename")
	assert_eq(Levels.resolve("res://scene/level/levels/level_bayou.tscn"), &"bayou", "scene path")
	assert_eq(Levels.resolve("nowhere"), &"")
	assert_eq(Levels.resolve("30"), &"")
	assert_eq(Levels.stopText(9), "2-5", "Goon Quarry is Tribe Country's finale")

func test_sprint_distance_grows_by_region():
	var last := 0.0
	for region in Territories.ORDER:
		var d := Territories.sprintDistance(region)
		assert_gt(d, last, "%s: a longer drive than the region before" % region)
		last = d
	assert_almost_eq(Territories.sprintDistance(&"wilds"), 20000.0, 0.01)
	assert_almost_eq(Territories.sprintDistance(&"works"), 34000.0, 0.01)
	assert_almost_eq(Level.sprintDistance(Levels.get_def(&"city")), Territories.sprintDistance(&"sprawl"), 0.01)

func test_sprint_clocks_fit_the_stock_sedan():
	const SEDAN_SLOWEST_TOP_SPEED = 499.0
	const SEDAN_TANK_SECONDS = 87.0
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for yRoll in [-1.0, 0.0, 1.0]:
			var distance = Level.sprintOffsetPx(Level.sprintDistance(def), yRoll).length()
			var clock = Level.sprintSeconds(distance, def.seconds, def.sprintSlack)
			assert_gt(clock, distance / Level.REFERENCE_SPEED, "%s: slack above 1" % id)
			assert_gt(SEDAN_SLOWEST_TOP_SPEED, distance / clock, "%s: the sedan is fast enough even on sand" % id)
			assert_gt(SEDAN_TANK_SECONDS * 0.8, distance / SEDAN_SLOWEST_TOP_SPEED, "%s: one tank is enough" % id)

#the coarse route underestimates the drive: every grammar adds a share and the lot approach on top
func test_sprint_clock_allows_for_the_real_drive():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		assert_true(Level.ROUTE_FACTOR.has(def.grammar), "%s: its grammar (%s) has a route factor" % [id, def.grammar])
		var drive = Level.driveLengthFor(30000.0, def.grammar)
		assert_gt(drive, 30000.0 + Level.STATION_APPROACH_PX, "%s: longer than the route plus the approach" % id)
		assert_gt(30000.0 * 1.25 + Level.STATION_APPROACH_PX, drive, "%s: but not by more than a quarter" % id)
	assert_almost_eq(Level.driveLengthFor(10000.0, &"nowhere"), 10000.0 * Level.ROUTE_FACTOR_DEFAULT + Level.STATION_APPROACH_PX, 0.01, "unknown grammar: the default")

func test_snapshot_is_a_plain_copy():
	var def := Levels.get_def(&"prairie")
	var snap := def.snapshot()
	assert_eq(snap.id, &"prairie")
	assert_eq(snap.seconds, def.seconds)
	snap.features["creekWidth"] = -1.0
	assert_ne(def.features.get("creekWidth"), -1.0, "deep copy: the def is untouched")
