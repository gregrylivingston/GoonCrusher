extends GameTest

#The generated world art (docs/WORLD_ART.md): world/art/props.json parses and covers the prop catalog, every
#prop's textures and scene exist and agree with the manifest, hulls are small convex polygons, tall things and
#walls cast shadows, and every ground material, edge strip, station texture and level poster is baked.

const ART := "res://world/art/"
const CLASSES := ["DECOR", "LOW", "TALL", "STATEFUL", "WALL"]
const GROUNDS := ["grass", "moss", "dirt", "sand", "mud", "mudpit", "snow", "deepsnow", "ice", "asphalt", "lot", "wash",
	"oil", "shallows", "water", "conveyor", "rock", "roof", "bridge", "gravel",
	#Road Atlas landscapes (forest, coast, ghost town, salt flats, volcano, suburbs)
	"needles", "beach", "salt", "ash", "tar", "lava", "basalt", "roof_timber", "roof_shingle", "lawn"]
const EDGES := ["shore_foam", "cliff_lip", "canyon_rim", "mesa_lip", "kerb", "hedge", "scrapwall", "snow_ridge", "roof_edge",
	"basalt_lip", "timber_edge", "shingle_edge"]
const STATION := ["station_lot", "station_wall", "station_roof", "station_lamp", "station_pump"]
const POSTERS := ["prairie", "bayou", "canyon", "quarry", "frostbite", "highway", "city", "crusher"]
#the Road Atlas's new levels (baked ahead of their LevelDefs, so not read from Levels.ORDER)
const ROAD_ATLAS_POSTERS := ["orchard", "moosewoods", "mudlick", "stilttown", "lantern", "sawmill", "ghosttown", "saltflats",
	"raiderpass", "thunderroad", "frozenlake", "timberline", "tarpits", "summit", "manhole", "culdesac", "gridlock", "blockparty",
	"blastpits", "tankfarm", "slagfields", "theline"]
#the prop catalog of the world spec (section 6)
const CATALOG := ["rock", "boulder", "rock_white", "rock_ice", "oak", "pine", "cypress", "log", "stump", "saguaro", "deadtree",
	"carcass", "haybale", "fence", "hedge", "crate", "shack", "tent", "totem", "firepit", "tyres", "barricade", "barrel", "crane",
	"fortwall", "cabin", "snowcat", "wreck", "jersey", "cone", "gaspump", "sign", "billboard", "hydrant", "dumpster", "busstop",
	"manhole", "streetglow", "scrapheap", "container", "tank", "landmark_wild", "landmark_tribe", "landmark_scrap", "reeds",
	"tufts", "pebbles", "cracks", "bones", "paint", "oilstain"]
const BREAKABLE := ["haybale", "fence", "hedge", "crate", "barricade", "wagon", "water_trough", "mailbox", "trashbags"]
const EXPLOSIVE := ["barrel", "tank"]
#added after the spec: canyon's red rocks and the city's rooftop decor
const EXTRA := ["rock_red", "boulder_red", "rooftop"]
#the Road Atlas expansion's props (forest, coast, ghost town, salt flats, volcano, suburbs, the overlays, landmarks)
const ROAD_ATLAS := ["ranger_tower", "fallen_trunk", "pine_snow", "palm", "beach_hut", "lifeguard_tower", "wagon", "water_trough",
	"tumbleweed", "mile_marker", "salt_mound", "rock_black", "steam_vent", "mailbox", "swingset", "trampoline", "hunting_stand",
	"trashbags", "landmark_big", "landmark_swarm", "landmark_war"]
const LANDMARKS := ["landmark_wild", "landmark_tribe", "landmark_scrap", "landmark_big", "landmark_swarm", "landmark_war"]

func manifest() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ART + "props.json"))
	return data if data is Dictionary else {}

func props() -> Dictionary:
	return manifest().get("props", {})

func test_manifest_parses_and_covers_the_catalog():
	var m := manifest()
	assert_true(m.has("props"), "props.json parses and has props")
	for id in CATALOG: assert_true(props().has(id), "%s is in the manifest" % id)
	for id in props():
		var p: Dictionary = props()[id]
		assert_true(p["class"] in CLASSES, "%s: class %s" % [id, p["class"]])
		assert_eq(p.sizePx.size(), 2, "%s: sizePx is [w, h]" % id)
		assert_true(p.sizePx[0] > 0 && p.sizePx[1] > 0, "%s: sizePx is positive" % id)
		assert_true(p.tags is Dictionary && p.tags.has("levels") && p.tags.has("faction"), "%s: tags" % id)
	for id in BREAKABLE: assert_true(props()[id].breakable is Dictionary, "%s is breakable" % id)
	for id in EXPLOSIVE: assert_true(props()[id].explosive, "%s is explosive" % id)

func test_every_variant_and_state_exists():
	for id in props():
		var p: Dictionary = props()[id]
		assert_true(p.variants.size() >= 1, "%s has a variant" % id)
		for path in p.variants: assert_true(ResourceLoader.exists(path), "%s: %s" % [id, path])
		if p.breakable is Dictionary:
			assert_true(p.breakable.smashSpeed > 0, "%s: smash speed" % id)
			assert_true(ResourceLoader.exists(p.breakable.broken), "%s: broken state" % id)
			assert_true(ResourceLoader.exists(p.breakable.debris), "%s: debris strip" % id)
		if p["class"] == "DECOR":
			assert_true(p.has("atlas") && p.atlas.cells >= 1, "%s: decor atlas cells" % id)
			var tex: Texture2D = load(p.variants[0])
			if tex: assert_eq(tex.get_width(), tex.get_height() * int(p.atlas.cells), "%s: atlas is a row of square cells" % id)

func test_hulls_are_small_convex_polygons():
	for id in props():
		var p: Dictionary = props()[id]
		if p["class"] == "DECOR": continue
		var hull := PackedVector2Array()
		for q in p.hull: hull.push_back(Vector2(q[0], q[1]))
		assert_between(hull.size(), 3, 10, "%s: hull has 3-10 points" % id)
		var turn := 0.0
		var convex := true
		for i in hull.size():
			var a := hull[i]; var b := hull[(i + 1) % hull.size()]; var c := hull[(i + 2) % hull.size()]
			var bend := (b - a).cross(c - b)
			if absf(bend) < 0.001: continue
			if turn == 0.0: turn = signf(bend)
			elif signf(bend) != turn: convex = false
		assert_true(convex, "%s: hull is convex" % id)
		var box := Rect2(hull[0], Vector2.ZERO)
		for v in hull: box = box.expand(v)
		assert_true(box.get_center().length() < maxf(p.sizePx[0], p.sizePx[1]) * 0.5, "%s: hull sits on the sprite" % id)

func test_tall_props_and_walls_cast_shadows():
	for id in props():
		var p: Dictionary = props()[id]
		if p["class"] in ["TALL", "WALL"]: assert_true(p.occluder, "%s (%s) has an occluder" % [id, p["class"]])
		if p["class"] == "DECOR": assert_false(p.occluder, "%s: decor never occludes" % id)

func test_scenes_match_the_manifest():
	for id in props():
		var p: Dictionary = props()[id]
		if p["class"] == "DECOR":
			assert_false(p.has("scene"), "%s: decor has no scene" % id)
			continue
		var path: String = p.get("scene", "")
		assert_eq(path, ART + "props/%s.tscn" % id, "%s: scene path" % id)
		assert_true(ResourceLoader.exists(path), "%s: scene exists" % id)
		var scene: PackedScene = load(path)
		if scene == null: continue
		var node = scene.instantiate()
		assert_true(node is StaticBody2D, "%s: root is a StaticBody2D" % id)
		assert_eq(String(node.name), id, "%s: root is named after the id" % id)
		assert_eq(node.collision_layer, 1, "%s: layer 1" % id)
		assert_eq(node.collision_mask, 0, "%s: mask 0" % id)
		var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
		assert_true(sprite != null && sprite.texture != null, "%s: sprite with a texture" % id)
		var shape: CollisionShape2D = node.get_node_or_null("CollisionShape2D")
		assert_true(shape != null && shape.shape is ConvexPolygonShape2D, "%s: convex collision shape" % id)
		if shape && shape.shape is ConvexPolygonShape2D: assert_eq(shape.shape.points.size(), p.hull.size(), "%s: shape is the hull" % id)
		if shape: assert_eq(shape.disabled, not p.get("solid", true), "%s: collision on unless the prop is not solid" % id)
		var occ: LightOccluder2D = node.get_node_or_null("LightOccluder2D")
		assert_eq(occ != null, p.occluder, "%s: occluder node matches the manifest" % id)
		if occ: assert_true(occ.get_meta("gc_world", false), "%s: occluder is marked gc_world" % id)
		if p.breakable is Dictionary: assert_eq(node.get_meta("smashSpeed", -1.0), float(p.breakable.smashSpeed), "%s: smashSpeed metadata" % id)
		assert_eq(node.get_meta("explosive", false), p.explosive, "%s: explosive metadata" % id)
		var canopy: Sprite2D = node.get_node_or_null("Canopy")
		assert_eq(canopy != null, p.get("canopy") is Array, "%s: a Canopy node exactly when the manifest names canopies" % id)
		if canopy:
			assert_eq(canopy.texture.resource_path, p.canopy[0], "%s: the canopy shows variant 0" % id)
			assert_eq(p.canopy.size(), p.variants.size(), "%s: a canopy per variant" % id)
			for top in p.canopy: assert_true(ResourceLoader.exists(top), "%s: %s" % [id, top])
		var beacon: Sprite2D = node.get_node_or_null("Beacon")
		assert_eq(beacon != null, p.has("beacon"), "%s: a Beacon node exactly when the manifest names one" % id)
		if beacon:
			assert_true(beacon.texture != null && beacon.texture.resource_path == p.beacon, "%s: the beacon's glow texture" % id)
			assert_true(beacon.material is ShaderMaterial && beacon.material.shader.resource_path == "res://shader/world_beacon.gdshader", "%s: the shared beacon material" % id)
		node.free()

func test_landmarks_have_beacons_and_extras_exist():
	for id in LANDMARKS: assert_true(props().get(id, {}).has("beacon"), "%s: a beacon" % id)
	for id in EXTRA: assert_true(props().has(id), "%s: in the manifest" % id)
	for id in ROAD_ATLAS: assert_true(props().has(id), "%s (Road Atlas): in the manifest" % id)
	for id in ["tumbleweed", "steam_vent"]: assert_eq(props().get(id, {}).get("class", ""), "DECOR", "%s is decor" % id)
	for id in ["pine_snow", "palm"]: assert_true(props().get(id, {}).get("canopy") is Array, "%s is layered" % id)
	assert_eq(props().get("rooftop", {}).get("class", ""), "DECOR", "rooftop is decor (no collision)")

func test_level_dressing_names_known_props():
	for id in Levels.ORDER:
		var def := Levels.get_def(id)
		if def == null: continue
		for faction in def.dressing:
			for prop in def.dressing[faction]: assert_true(props().has(String(prop)), "%s dresses with %s, which is baked" % [id, prop])

func test_ground_edges_station_and_posters_exist():
	for name in GROUNDS + ["macro_noise"]:
		var path := ART + "ground/%s.png" % name
		assert_true(ResourceLoader.exists(path), "ground %s" % name)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex: assert_eq(tex.get_width(), 256 if name == "macro_noise" else 512, "ground %s size" % name)
	for name in EDGES:
		var tex: Texture2D = load(ART + "edges/%s.png" % name) if ResourceLoader.exists(ART + "edges/%s.png" % name) else null
		assert_true(tex != null, "edge strip %s" % name)
		if tex: assert_eq(tex.get_height(), 96, "edge strip %s is 96 texels across" % name)
	for name in STATION: assert_true(ResourceLoader.exists(ART + "station/%s.png" % name), "station %s" % name)
	for id in POSTERS:
		var path := ART + "posters/%s.png" % id
		assert_true(ResourceLoader.exists(path), "poster %s" % id)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex: assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(1792, 1024), "poster %s size" % id)

func test_road_atlas_posters_exist():
	assert_eq(ROAD_ATLAS_POSTERS.size(), 22, "one poster per new level")
	for id in ROAD_ATLAS_POSTERS:
		var path := ART + "posters/%s.png" % id
		assert_true(ResourceLoader.exists(path), "poster %s" % id)
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex: assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(1792, 1024), "poster %s size" % id)
