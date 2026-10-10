class_name Landscapes extends RefCounted
## The landscape registry (docs/WORLD.md, "Landscapes"): one Landscape per res://world/landscapes/<id>.tres.
## A level names one (LevelDef.landscape); its skin is the landscape's own once its art is in world/art, else its
## fallback's (skinOf, checked once per landscape). `-- --landscape=<id>` puts every level in that landscape
## (forcedId; playtests, benchmarks and the world preview).

const DIR := "res://world/landscapes/"
## The order tools and tests list landscapes in
const ORDER: Array[StringName] = [&"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city", &"scrapyard",
	&"forest", &"forest_snow", &"coast", &"ghosttown", &"saltflats", &"volcano", &"suburbs"]

static var cache := {}     #id -> Landscape
static var skins := {}     #id -> the Landscape whose skin it uses
static var forced := &"?"  #the --landscape= id, read once; &"" for none

static func path(id: StringName) -> String:
	return DIR + String(id) + ".tres"

static func has(id: StringName) -> bool:
	return StringName(id) in ORDER

## The landscape with this id, or null
static func get_def(id: StringName) -> Landscape:
	id = StringName(id)
	if cache.has(id): return cache[id]
	if not has(id) || not ResourceLoader.exists(path(id)): return null
	var land := load(path(id)) as Landscape
	cache[id] = land
	return land

## `-- --landscape=<id>`: every level is built in this landscape (LevelDef.resolve). &"" when not given.
static func forcedId() -> StringName:
	if forced == &"?":
		forced = &""
		for arg in OS.get_cmdline_user_args():
			if not arg.begins_with("--landscape="): continue
			var id := StringName(arg.get_slice("=", 1))
			if has(id): forced = id
			else: push_warning("--landscape: unknown landscape %s (%s)" % [id, ", ".join(ORDER)])
	return forced

## The art a landscape's skin needs that world/art doesn't have yet: ground materials and its wall strip
static func missingArt(land: Landscape) -> Array:
	var out := []
	var names: Array = land.materials.values()
	names.push_back(land.roofMaterial)
	for name in names:
		if not ResourceLoader.exists(WorldSkin.GROUND_DIR + String(name) + ".png") && not "ground/" + String(name) in out: out.push_back("ground/" + String(name))
	if not ResourceLoader.exists(WorldSkin.EDGE_DIR + land.wallStrip + ".png"): out.push_back("edges/" + land.wallStrip)
	return out

## The landscape whose skin (materials, walls, roofs, borders) a level in `id` is drawn with: its own when its
## art is all there, else its fallback's (and so on), checked once per landscape
static func skinOf(id: StringName) -> Landscape:
	id = StringName(id)
	if skins.has(id): return skins[id]
	var land := get_def(id)
	var skin := land
	var seen := {}
	while skin != null && skin.fallback != &"" && not missingArt(skin).is_empty() && not seen.has(skin.id):
		seen[skin.id] = true
		skin = get_def(skin.fallback)
	if skin == null: skin = land
	skins[id] = skin
	return skin
