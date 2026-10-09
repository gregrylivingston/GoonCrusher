extends GameTest

#Landscapes and regions as data (Landscape, Landscapes, Territories, WorldSkin): the fifteen landscapes load and
#name real generators, materials, strips and props; today's eight draw exactly as they did before the move
#(material layers, wall and water layers, tints, borders, strips, roof decor); a landscape whose art is missing
#borrows its fallback's skin but keeps its own generator; lava glows; a region's props rise with distance.

#what WorldSkin built for the eight kept levels before the landscapes existed (commit e03a6cad): layers, water
#layer, wall layer, wall tint, organic, wall strip, roof decor, layerOf by terrain id
const BEFORE := {
	&"prairie": ["grass,moss,dirt,shallows,water,rock", 4, 5, Color(1, 1, 1), 1.0, "cliff_lip", "", [0, 0, 0, 4, 5, 1, 2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0]],
	&"bayou": ["moss,mud,grass,shallows,bridge,water,rock", 5, 6, Color(1, 1, 1), 1.0, "cliff_lip", "", [2, 0, 1, 5, 6, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 4]],
	&"canyon": ["dirt,sand,wash,rock,water,shallows", 4, 3, Color(1.16, 0.84, 0.7), 1.0, "mesa_lip", "", [0, 1, 0, 4, 3, 0, 0, 0, 0, 0, 0, 5, 2, 0, 0, 0, 0, 0, 0]],
	&"quarry": ["dirt,mud,lot,mudpit,rock,water,shallows", 5, 4, Color(1.04, 0.99, 0.93), 1.0, "cliff_lip", "", [0, 0, 1, 5, 4, 0, 0, 0, 0, 0, 0, 6, 0, 0, 3, 0, 2, 0, 0]],
	&"frostbite": ["snow,deepsnow,ice,rock,water,shallows", 4, 3, Color(1.12, 1.14, 1.2), 1.0, "snow_ridge", "", [0, 0, 0, 4, 3, 0, 0, 0, 0, 2, 0, 5, 0, 0, 0, 1, 0, 0, 0]],
	&"highway": ["sand,dirt,asphalt,oil,lot,rock,water,shallows", 6, 5, Color(1.1, 0.95, 0.82), 0.7, "cliff_lip", "", [0, 0, 0, 6, 5, 0, 1, 0, 2, 0, 3, 7, 0, 0, 0, 0, 4, 0, 0]],
	&"city": ["lot,asphalt,grass,moss,bridge,roof,water,shallows", 6, 5, Color(1, 1, 1), 0.2, "roof_edge", "rooftop", [2, 0, 0, 6, 0, 3, 0, 0, 1, 0, 0, 7, 0, 0, 0, 0, 0, 5, 4]],
	&"crusher": ["dirt,lot,oil,conveyor,rock,water,shallows", 5, 4, Color(0.78, 0.74, 0.7), 0.5, "scrapwall", "", [0, 0, 0, 5, 4, 0, 0, 0, 0, 0, 2, 6, 0, 3, 0, 0, 1, 0, 0]],
}
const GRAMMARS := [&"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city", &"yard"]

static var skins := {} #level id -> WorldSkin, built once

func skinFor(id: StringName) -> WorldSkin:
	if not skins.has(id): skins[id] = WorldSkin.new(Levels.get_def(id))
	return skins[id]

func after_each():
	Landscapes.forced = &""

func test_every_landscape_loads_and_names_real_things():
	assert_eq(Landscapes.ORDER.size(), 15, "today's eight, the six new ones and the snowy pines")
	var manifest := WorldSkin.loadManifest()
	for id in Landscapes.ORDER:
		var land := Landscapes.get_def(id)
		if land == null:
			fail("%s: loads" % id)
			continue
		assert_eq(land.id, id, "%s: id matches its file" % id)
		assert_true(land.grammar in GRAMMARS, "%s: a known generator (%s)" % [id, land.grammar])
		assert_true(Level.ROUTE_FACTOR.has(land.grammar), "%s: its generator has a route factor" % id)
		assert_true(land.displayName != "" && land.text != "", "%s: a name and Goonopedia text" % id)
		assert_false(land.features.is_empty() || land.baseTerrain.is_empty(), "%s: default generator features and terrain" % id)
		assert_eq(land.nameSecond.size(), 10, "%s: ten district second words" % id)
		assert_true(land.waterLook in [&"water", &"lava"], "%s: water look" % id)
		for t in land.materials: assert_between(int(t), 0, WorldSkin.MATERIAL_OF.size() - 1, "%s: material for a real terrain" % id)
		for prop in land.dressing: assert_true(manifest.has(String(prop)), "%s dresses with %s, which is in props.json" % [id, prop])
		for motif in land.motifs: assert_true(WorldSkin.MOTIFS.has(StringName(motif)), "%s: motif %s exists" % [id, motif])
		if land.fallback != &"":
			assert_true(Landscapes.has(land.fallback), "%s: its fallback %s exists" % [id, land.fallback])
			assert_true(Landscapes.missingArt(Landscapes.get_def(land.fallback)).is_empty(), "%s: its fallback has all its art" % id)
		else:
			assert_true(Landscapes.missingArt(land).is_empty(), "%s: has all its art (today's eight)" % id)
	for id in Levels.ORDER: assert_true(Landscapes.has(Levels.get_def(id).landscape), "%s: its landscape exists" % id)

func test_regions_dress_with_real_props():
	var manifest := WorldSkin.loadManifest()
	for region in Territories.ORDER:
		var d := Territories.get_def(region)
		for zone in WorldSkin.ZONES:
			for prop in d.dressing[zone]: assert_true(manifest.has(String(prop)), "%s zone %d: %s is in props.json" % [region, zone, prop])
			for motif in d.motifs[zone]: assert_true(WorldSkin.MOTIFS.has(StringName(motif)), "%s zone %d: motif %s" % [region, zone, motif])
		assert_true(manifest.has(String(Territories.landmark(region))), "%s: its landmark is baked" % region)
		assert_true(StringName(Territories.landmark(region)) in WorldSkin.LANDMARKS, "%s: its landmark is listed with the beacons" % region)
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		for prop in def.dressing: assert_true(manifest.has(String(prop)), "%s: its own dressing %s is in props.json" % [id, prop])

#today's eight are drawn as they were before their tables moved into world/landscapes
func test_kept_levels_draw_as_before():
	for id in BEFORE:
		var want: Array = BEFORE[id]
		var skin := skinFor(id)
		var m := skin.groundMaterial
		var ctx := skin.recipeContext([], [])
		assert_eq(",".join(skin.layers), want[0], "%s: material layers" % id)
		assert_eq(int(m.get_shader_parameter("water_layer")), want[1], "%s: water layer" % id)
		assert_eq(int(m.get_shader_parameter("wall_layer")), want[2], "%s: wall layer" % id)
		var tint: Color = m.get_shader_parameter("wall_tint")
		assert_true(tint.is_equal_approx(want[3]), "%s: wall tint %s" % [id, tint])
		assert_almost_eq(float(m.get_shader_parameter("organic")), want[4], 0.0001, "%s: organic borders" % id)
		assert_eq(skin.stripNames[ctx.wallStrip], want[5], "%s: wall strip" % id)
		assert_eq(skin.stripNames[ctx.waterStrip], "shore_foam", "%s: shore foam" % id)
		assert_eq(ctx.roofDecor, want[6], "%s: roof decor" % id)
		assert_eq(Array(skin.layerOf), want[7], "%s: layer by terrain" % id)
		var glow: Color = m.get_shader_parameter("water_glow")
		assert_eq(glow.a, 0.0, "%s: plain water" % id)
		assert_eq(skin.look, skin.land, "%s: its own skin" % id)

#a landscape whose art is missing borrows its fallback's skin, checked once, and keeps its own generator
func test_missing_art_falls_back_to_the_fallback_skin():
	var fake := Landscape.new()
	fake.id = &"test_land"
	fake.grammar = &"canyon"
	fake.materials = {0: "no_such_ground"}
	fake.fallback = &"meadow"
	Landscapes.cache[&"test_land"] = fake
	Landscapes.skins.erase(&"test_land")
	assert_eq(Landscapes.missingArt(fake), ["ground/no_such_ground"])
	assert_eq(Landscapes.skinOf(&"test_land"), Landscapes.get_def(&"meadow"), "drawn with the fallback's skin")
	fake.wallStrip = "no_such_strip"
	assert_true(Landscapes.missingArt(fake).has("edges/no_such_strip"), "a missing strip counts too")
	Landscapes.cache.erase(&"test_land")
	Landscapes.skins.erase(&"test_land")
	#the new landscapes: each draws with an existing skin until its art lands, generator unchanged
	for id in Landscapes.ORDER:
		var land := Landscapes.get_def(id)
		var skin := Landscapes.skinOf(id)
		assert_true(Landscapes.missingArt(skin).is_empty(), "%s: drawn with a skin whose art is all there (%s)" % [id, skin.id])
		if not Landscapes.missingArt(land).is_empty(): assert_eq(skin.id, land.fallback, "%s: missing art, so its fallback" % id)
	var tarpits := skinFor(&"tarpits")
	assert_eq(tarpits.grammar, &"canyon", "Tar Pits keeps the volcano's generator")
	assert_eq(tarpits.land.id, &"volcano")

func test_lava_glows_and_its_shore_burns():
	var skin := skinFor(&"tarpits")
	var glow: Color = skin.groundMaterial.get_shader_parameter("water_glow")
	assert_gt(glow.a, 0.5, "the water layer glows")
	assert_true(glow.r > glow.b, "in a lava colour")
	var foam: int = skin.stripNames.find("shore_foam")
	assert_eq(skin.stripColors[foam], Landscapes.get_def(&"volcano").waterFoam, "the shore foam takes the lava's colour")
	assert_eq(skinFor(&"prairie").stripColors[foam], Color.WHITE, "water keeps white foam")
	assert_true(World.isLethal(Root.terrain.WATER), "lava is the water terrain: it kills like deep water")

func test_new_levels_take_their_landscapes_world():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		var land := Landscapes.get_def(def.landscape)
		assert_false(def.features.is_empty() || def.baseTerrain.is_empty(), "%s: a resolved world" % id)
		if not id in BEFORE:
			assert_eq(def.grammar, land.grammar, "%s: its landscape's generator" % id)
			assert_eq(def.features, land.features, "%s: and its features" % id)
	var forest := Levels.get_def(&"moosewoods")
	assert_false(forest.features.has("fenceDensity"), "Moose Woods has no field lines")

func test_a_forced_landscape_replaces_the_levels_world():
	var def := LevelDef.new()
	def.id = &"test_forced"
	def.landscape = &"meadow"
	def.grammar = &"meadow"
	def.features = {"creekWidth": 1.0}
	Landscapes.forced = &"volcano"
	def.resolve()
	assert_eq(def.landscape, &"volcano")
	assert_eq(def.grammar, &"canyon")
	assert_eq(def.features, Landscapes.get_def(&"volcano").features)
	Landscapes.forced = &""

#the region's props are laid over the landscape's, more of them the further out
func test_region_props_rise_with_distance():
	for id in [&"prairie", &"quarry", &"highway", &"frostbite", &"city", &"crusher"]:
		var skin := skinFor(id)
		var land := skin.land
		var share := []
		for zone in WorldSkin.ZONES:
			var tables := skin.zoneTables(zone)
			var total := 0.0
			var own := 0.0
			for prop in tables.dressing:
				total += tables.dressing[prop]
				own += tables.dressing[prop] - float(land.dressing.get(prop, 0.0))
			share.push_back(own / maxf(total, 0.001))
		assert_gt(share[2], share[0], "%s: the region's share rises from zone 0 (%.2f) to 2 (%.2f)" % [id, share[0], share[2]])
		for prop in land.dressing: assert_true(skin.zoneTables(0).dressing.has(StringName(prop)), "%s: the landscape's %s near the start" % [id, prop])
	assert_true(skinFor(&"quarry").zoneTables(2).dressing.has(&"tent"), "the Tribe camps far out in Goon Quarry")
	assert_false(skinFor(&"prairie").zoneTables(2).dressing.has(&"tent"), "but not on The Wilds' prairie")
	var ctx := skinFor(&"quarry").recipeContext([], [])
	assert_eq(ctx.propTables.size(), WorldSkin.ZONES, "one prop table per zone for the workers")

#mountain and the snowy pines (their ground mostly snow) throw snow dust and drop snow (PropReactions)
func test_snowy_landscapes_are_the_snowbound_ones():
	for id in Landscapes.ORDER:
		var land := Landscapes.get_def(id)
		var snow: int = land.baseTerrain.count(Root.terrain.SNOW) + land.baseTerrain.count(Root.terrain.DEEPSNOW)
		assert_eq(land.snowy, snow * 2 > land.baseTerrain.size(), "%s: snowy exactly when its ground is mostly snow" % id)
	assert_true(Landscapes.get_def(&"forest_snow").snowy, "the snowy pines")

func test_landmarks_are_the_regions():
	assert_eq(Territories.landmark(&"wilds"), &"landmark_wild")
	var big := Territories.landmark(&"hunting")
	assert_eq(big, &"landmark_big", "Big Game's skull")
	assert_true(skinFor(&"frostbite").propScenes.has(big), "the level loads its region's landmark")
	var map := WorldMap.build(3, Levels.get_def(&"crusher"))
	for chunk in map.landmarks:
		for entry in map.landmarks[chunk]: assert_eq(entry[0], String(Territories.landmark(&"works")), "every district shows The Works' landmark")
	var seconds: Array = Landscapes.get_def(&"scrapyard").nameSecond
	for d in map.districts: assert_true(d.name.get_slice(" ", d.name.get_slice_count(" ") - 1) in seconds || d.name.ends_with("Rest Stop"), "%s: a scrapyard word" % d.name)
