class_name WorldSkin extends RefCounted
## The run's world art and the node pools the chunks are drawn with (docs/WORLD.md, "Rendering";
## docs/WORLD_ART.md for the art). Made once per level by the TileManager, on the main thread:
##   - the ground: one ShaderMaterial (shader/ground.gdshader) shared by every ground quad, the level's
##     materials as one Texture2DArray, the macro noise, and the control ring: an RGBA8 texture of RING x RING
##     chunks of fine cells that each applied chunk writes its block into (ChunkRecipe.control), addressed by
##     world cell modulo its size, so one material serves every chunk and bilinear fields run across seams;
##   - the edge strips, the decor atlases and their materials, the props' scenes and variant textures;
##   - recipeContext(): the plain tables ChunkRecipe reads on the worker threads;
##   - pools of ground quads, bodies, shapes, occluders, lines, MultiMeshes and props, all bounded.

const MANIFEST := "res://world/art/props.json"
const GROUND_DIR := "res://world/art/ground/"
const EDGE_DIR := "res://world/art/edges/"
const MACRO := "res://world/art/ground/macro_noise.png"
const GROUND_SHADER := "res://shader/ground.gdshader"
const DECOR_SHADER := "res://shader/world_decor.gdshader"
const GLOW_SHADER := "res://shader/world_decor_glow.gdshader"
const BREAKABLE := "res://scripts/world/breakable.gd"
const STRIPS: Array[String] = ["shore_foam", "cliff_lip", "canyon_rim", "mesa_lip", "kerb", "snow_ridge", "hedge", "scrapwall", "roof_edge"]
## Ground material by terrain id (Root.terrain order)
const MATERIAL_OF: Array[String] = ["grass", "sand", "mud", "water", "rock", "moss", "dirt", "snow", "asphalt", "ice",
	"oil", "shallows", "wash", "conveyor", "mudpit", "deepsnow", "lot", "roof", "bridge"]
## Terrains a grammar adds to the level's base and accents (the ocean's water and shallows are always in)
const GRAMMAR_TERRAIN := {
	&"meadow": [6, 11], &"bayou": [11, 18], &"canyon": [12, 1, 6, 4], &"quarry": [6, 2, 16, 14, 4],
	&"mountain": [9, 15, 7, 4], &"highway": [8, 10, 6, 16, 4], &"city": [8, 16, 0, 5, 18, 17], &"yard": [6, 16, 10, 13, 4],
}
const WALL_STRIP := {&"canyon": "mesa_lip", &"mountain": "snow_ridge", &"city": "roof_edge", &"yard": "scrapwall"}
## Decor the recipe lays on rooftops (BUILDING cells), by grammar
const ROOF_DECOR := {&"city": &"rooftop"}
## Every level loads these (one per district, ChunkRecipe.placeLandmarks), whatever its dressing
const LANDMARKS: Array[StringName] = [&"landmark_wild", &"landmark_tribe", &"landmark_scrap"]
const WALL_TINT := {
	&"canyon": Color(1.16, 0.84, 0.7), &"mountain": Color(1.12, 1.14, 1.2), &"quarry": Color(1.04, 0.99, 0.93),
	&"highway": Color(1.1, 0.95, 0.82), &"yard": Color(0.78, 0.74, 0.7),
}
## How far borders between surfaces wander (ground.gdshader): crisper on built-up levels
const ORGANIC := {&"city": 0.2, &"yard": 0.5, &"highway": 0.7}
const RING := 8
const CTL_SIZE := Vector2i(RING * ChunkRecipe.FW, RING * ChunkRecipe.FH)
const QUAD := 1280.0
## Props that may stand on a road (the rest keep off asphalt and oil)
const ROAD_PROPS := [&"cone", &"jersey", &"wreck", &"manhole", &"barricade", &"sign"]
## Props laid in short chains, end to end
const CHAIN_PROPS := [&"fence", &"hedge", &"jersey", &"fortwall"]
## Props laid only as field lines (ChunkRecipe.placeFieldLines), by the features key giving the chance per lattice edge
const FIELD_PROPS := {&"fence": "fenceDensity", &"hedge": "hedgeDensity"}
## Set pieces (ChunkRecipe.placeMotifs), chosen per faction by LevelDef.motifs. members: [prop id, count, radius px,
## shape]: "centre", "ring" (evenly round the radius), "disc" (scattered inside it), "grid" or "line" (turned to the
## field lattice, `radius` apart). min: fewer members than this that fit and the motif is skipped. Members are
## loaded with the level whether its dressing names them or not.
const MOTIFS := {
	&"camp": {"min": 3, "members": [["firepit", 1, 0.0, "centre"], ["tent", 3, 300.0, "ring"], ["totem", 1, 470.0, "ring"], ["crate", 1, 430.0, "disc"]]},
	&"cabincamp": {"min": 2, "members": [["cabin", 1, 0.0, "centre"], ["firepit", 1, 340.0, "ring"], ["pine", 2, 560.0, "ring"]]},
	&"wreckpile": {"min": 3, "members": [["wreck", 3, 330.0, "disc"], ["tyres", 2, 400.0, "disc"], ["barrel", 1, 380.0, "disc"]]},
	&"junkyard": {"min": 3, "members": [["scrapheap", 1, 0.0, "centre"], ["container", 2, 580.0, "ring"], ["tyres", 2, 460.0, "disc"], ["barrel", 1, 430.0, "disc"]]},
	&"pinestand": {"min": 4, "members": [["pine", 7, 560.0, "disc"], ["stump", 1, 500.0, "disc"]]},
	&"cypressgrove": {"min": 3, "members": [["cypress", 4, 470.0, "disc"], ["log", 1, 430.0, "disc"]]},
	&"orchard": {"min": 4, "members": [["oak", 6, 400.0, "grid"]]},
	&"boneyard": {"min": 3, "members": [["deadtree", 1, 0.0, "centre"], ["carcass", 2, 340.0, "disc"], ["rock_red", 2, 400.0, "disc"]]},
	&"roadblock": {"min": 3, "members": [["barricade", 3, 300.0, "line"], ["cone", 2, 360.0, "disc"], ["tyres", 1, 380.0, "disc"]]},
	&"pileup": {"min": 3, "members": [["wreck", 3, 300.0, "disc"], ["cone", 4, 420.0, "disc"], ["sign", 1, 420.0, "disc"]]},
}
## Where decor goes: "road" (asphalt, oil, lots), "wet" (shallows and banks), "any"; others off roads
## Decor that bends away from the car (world_decor.gdshader `bend`: world px a corner moves right under it)
const BEND_DECOR := {&"tufts": 14.0, &"reeds": 18.0}
const DECOR_PLACE := {&"paint": "road", &"streetglow": "road", &"oilstain": "any", &"reeds": "wet", &"cracks": "any"}
const PICKUP_IDS := {"fuel": "fuel", "health": "health", "purse": "purse", "slot": "slotmachine"}
const POOL_CAP := {"quad": 200, "body": 16, "occluder": 160, "line": 160, "mmi": 24, "prop": 40}
## PICKUP_IDS with each locked pickup swapped for its nearest open ancestor (Unlocks), worked out on the
## main thread for the recipe job
static func pickupIds() -> Dictionary:
	var out := {}
	for kind in PICKUP_IDS: out[kind] = Pickups.openOr(PICKUP_IDS[kind])
	return out

## Ready-made pickups kept out of the tree (ChunkView takes them, then tops the stock up in spare steps): coins
## come in lines, so more of them
const PICKUP_STOCK := {"coin": 14, "other": 2}

static var manifestCache := {}

var def: LevelDef
var grammar: StringName
var layers: Array[String] = []
var layerOf := PackedByteArray()
var groundMaterial: ShaderMaterial
var ctlImage: Image
var ctlTexture: ImageTexture
var ctlDirty := false
var slotOwner := {} #ring slot (Vector2i) -> the chunk whose block is there
var quadMesh: ArrayMesh
var strips: Array[Texture2D] = []
var decorMeshes := {}    #decor id -> QuadMesh
var decorMaterials := {} #decor id -> ShaderMaterial
var decorTextures := {}  #decor id -> Texture2D
var propScenes := {}     #prop id -> PackedScene
var variants := {}       #prop id -> Array of Texture2D
var canopies := {}       #layered prop id -> Array of Texture2D, one per variant (the over-the-car layer)
var leaves := {}         #layered prop id -> its leaves strip (PropReactions)
var manifest := {}
var breakableScript: Script
var pools := {}          #pool key -> Array of nodes or shapes outside the tree

static func loadManifest() -> Dictionary:
	if manifestCache.is_empty():
		var text := FileAccess.get_file_as_string(MANIFEST)
		var parsed = JSON.parse_string(text) if text != "" else null
		manifestCache = parsed.get("props", {}) if parsed is Dictionary else {}
	return manifestCache

func _init(levelDef: LevelDef) -> void:
	def = levelDef
	grammar = levelDef.grammar
	manifest = loadManifest()
	setupGround()
	setupStrips()
	setupProps()
	if ResourceLoader.exists(BREAKABLE):
		var script = load(BREAKABLE)
		if script is Script && ClassDB.is_parent_class("StaticBody2D", script.get_instance_base_type()): breakableScript = script

#--- ground ------------------------------------------------------------------------------------------

## The terrains this level can show: base, accents, the grammar's own, water and shallows
func levelTerrains() -> Array:
	var ids := {}
	for t in def.baseTerrain: ids[int(t)] = true
	for t in def.accents: ids[int(t)] = true
	for t in GRAMMAR_TERRAIN.get(grammar, []): ids[int(t)] = true
	ids[Root.terrain.WATER] = true
	ids[Root.terrain.SHALLOWS] = true
	return ids.keys()

func setupGround() -> void:
	var main := WorldField.mainTerrain(PackedByteArray(def.baseTerrain if not def.baseTerrain.is_empty() else [0]))
	var wanted: Array[String] = [MATERIAL_OF[main]]
	for t in levelTerrains():
		var name: String = MATERIAL_OF[t]
		if not name in wanted: wanted.push_back(name)
	var wallName := "roof" if grammar == &"city" else "rock"
	if not wallName in wanted: wanted.push_back(wallName)
	layers = wanted
	layerOf.resize(MATERIAL_OF.size())
	for t in MATERIAL_OF.size():
		var at := layers.find(MATERIAL_OF[t])
		layerOf[t] = at if at >= 0 else 0
	var shader: Shader = load(GROUND_SHADER)
	groundMaterial = ShaderMaterial.new()
	groundMaterial.shader = shader
	groundMaterial.set_shader_parameter("materials", materialArray())
	groundMaterial.set_shader_parameter("macro_noise", load(MACRO))
	groundMaterial.set_shader_parameter("water_layer", float(layers.find("water")))
	groundMaterial.set_shader_parameter("wall_layer", float(layers.find(wallName)))
	groundMaterial.set_shader_parameter("wall_tint", WALL_TINT.get(grammar, Color.WHITE))
	groundMaterial.set_shader_parameter("ctl_size", Vector2(CTL_SIZE))
	groundMaterial.set_shader_parameter("organic", ORGANIC.get(grammar, 1.0))
	ctlImage = Image.create_empty(CTL_SIZE.x, CTL_SIZE.y, false, Image.FORMAT_RGBA8)
	ctlImage.fill(Color(0, 1, 1, 0)) #nothing written yet: open ground of layer 0
	ctlTexture = ImageTexture.create_from_image(ctlImage)
	groundMaterial.set_shader_parameter("ctl", ctlTexture)
	quadMesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(QUAD, 0), Vector2(QUAD, QUAD), Vector2(0, QUAD)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quadMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

## The level's materials as one Texture2DArray (the baked BC7 images with their mipmaps). Without image data
## (headless runs) or when the formats differ, small flat placeholders.
func materialArray() -> Texture2DArray:
	var images: Array[Image] = []
	var ok := true
	for name in layers:
		var tex: Texture2D = load(GROUND_DIR + name + ".png")
		var img: Image = tex.get_image() if tex else null
		if img == null || img.is_empty():
			ok = false
			break
		images.push_back(img)
	if ok:
		for img in images:
			if img.get_format() != images[0].get_format() || img.get_size() != images[0].get_size() || img.has_mipmaps() != images[0].has_mipmaps(): ok = false
	if not ok:
		images.clear()
		for name in layers:
			var flat := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
			flat.fill(placeholderColor(name))
			images.push_back(flat)
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	return arr

func placeholderColor(name: String) -> Color:
	match name:
		"water": return Color("#284a57")
		"shallows": return Color("#4f7a7a")
		"rock", "roof": return Color("#6b6560")
		"asphalt": return Color("#3c3d40")
		"snow", "deepsnow", "ice": return Color("#c5cbd1")
		"sand", "wash": return Color("#b59a6a")
	return def.palette.get(&"ground", Color("#6b8c4d"))

## Writes a chunk's control block (42 x 22 RGBA8, apron included) into its ring slot, and its apron into
## the neighbours' slots unless they hold their own chunk, so a seam next to an unloaded chunk still blends
func writeControl(chunk: Vector2i, control: PackedByteArray) -> void:
	var img := Image.create_from_data(ChunkRecipe.RW, ChunkRecipe.RH, false, Image.FORMAT_RGBA8, control)
	var slot := slotOf(chunk)
	var fw := ChunkRecipe.FW
	var fh := ChunkRecipe.FH
	ctlImage.blit_rect(img, Rect2i(1, 1, fw, fh), Vector2i(slot.x * fw, slot.y * fh))
	slotOwner[slot] = chunk
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 && dy == 0: continue
			var n: Vector2i = chunk + Vector2i(dx, dy)
			var ns := slotOf(n)
			if slotOwner.get(ns) == n: continue
			var src := Rect2i(0 if dx == -1 else (1 if dx == 0 else fw + 1), 0 if dy == -1 else (1 if dy == 0 else fh + 1),
				fw if dx == 0 else 1, fh if dy == 0 else 1)
			ctlImage.blit_rect(img, src, Vector2i(ns.x * fw + (fw - 1 if dx == -1 else 0), ns.y * fh + (fh - 1 if dy == -1 else 0)))
	ctlDirty = true

static func slotOf(chunk: Vector2i) -> Vector2i:
	return Vector2i(posmod(chunk.x, RING), posmod(chunk.y, RING))

## Uploads the control ring once a frame if a chunk wrote to it
func flush() -> void:
	if ctlDirty:
		ctlDirty = false
		ctlTexture.update(ctlImage)

func setupStrips() -> void:
	for name in STRIPS: strips.push_back(load(EDGE_DIR + name + ".png"))

#--- props and decor ---------------------------------------------------------------------------------

## The ids the level's dressing names, by class: {"decor": [...], "props": [...]}
func dressingIds() -> Dictionary:
	var decor := []
	var props := []
	for faction in def.dressing:
		for id in def.dressing[faction]:
			var entry: Dictionary = manifest.get(String(id), {})
			if entry.is_empty(): continue
			var list := decor if entry.get("class", "") == "DECOR" else props
			if not StringName(id) in list: list.push_back(StringName(id))
	for faction in def.motifs:
		for motif in def.motifs[faction]:
			for m in MOTIFS.get(StringName(motif), {}).get("members", []):
				var mid := StringName(m[0])
				if manifest.get(String(mid), {}).get("class", "DECOR") != "DECOR" && not mid in props: props.push_back(mid)
	var roof: StringName = ROOF_DECOR.get(grammar, &"")
	if roof != &"" && manifest.has(String(roof)) && not roof in decor: decor.push_back(roof)
	for id in LANDMARKS:
		if manifest.has(String(id)) && not id in props: props.push_back(id)
	#what interactive props leave behind (logs from a log pile, a crane's container)
	for id in props.duplicate():
		for product in Spill.PRODUCTS.get(id, []):
			if manifest.has(String(product)) && not product in props: props.push_back(product)
	return {"decor": decor, "props": props}

func setupProps() -> void:
	var ids := dressingIds()
	for id in ids.decor:
		var entry: Dictionary = manifest[String(id)]
		var atlas: Dictionary = entry.get("atlas", {})
		var cellPx: Array = atlas.get("cellPx", entry.get("sizePx", [64, 64]))
		var mesh := QuadMesh.new()
		mesh.size = Vector2(cellPx[0], cellPx[1])
		decorMeshes[id] = mesh
		var mat := ShaderMaterial.new()
		mat.shader = load(GLOW_SHADER if atlas.get("blend", "mix") == "add" else DECOR_SHADER)
		mat.set_shader_parameter("cells", float(atlas.get("cells", 4)))
		if BEND_DECOR.has(id): mat.set_shader_parameter("bend", BEND_DECOR[id])
		decorMaterials[id] = mat
		decorTextures[id] = load(entry.variants[0])
	for id in ids.props:
		var entry: Dictionary = manifest[String(id)]
		if not entry.has("scene") || not ResourceLoader.exists(entry.scene): continue
		propScenes[id] = load(entry.scene)
		var textures := []
		for path in entry.variants: textures.push_back(load(path))
		variants[id] = textures
		if entry.get("canopy") is Array:
			var tops := []
			for path in entry.canopy: tops.push_back(load(path))
			canopies[id] = tops
		if entry.get("leaves", "") != "" && ResourceLoader.exists(entry.leaves): leaves[id] = load(entry.leaves)

## What ChunkRecipe reads on the workers: plain tables only. lots: Array of Rect2 (station lots, world px);
## lanes: Array of [from, to] (Defense lanes, world px).
func recipeContext(lots: Array, lanes: Array) -> Dictionary:
	var blocked := PackedByteArray()
	var spawnable := PackedByteArray()
	for t in World.count():
		blocked.push_back(0 if World.isPassable(t) else 1)
		spawnable.push_back(1 if World.isSpawnable(t) else 0)
	var props := {}
	for id in propScenes:
		var entry: Dictionary = manifest[String(id)]
		var size: Array = entry.get("sizePx", [100, 100])
		var occluder: bool = entry.get("occluder", false)
		props[String(id)] = {"w": float(size[0]), "h": float(size[1]), "radius": maxf(size[0], size[1]) * 0.5,
			"nodes": 3 + (1 if occluder else 0) + (1 if entry.get("beacon") else 0) + (1 if entry.get("canopy") else 0), "occluder": occluder,
			"chain": id in CHAIN_PROPS, "breakable": entry.get("breakable") != null, "variants": entry.variants.size(),
			"road": id in ROAD_PROPS}
	var decor := {}
	for id in decorMeshes: decor[String(id)] = {"place": DECOR_PLACE.get(id, "")}
	var propTables := {}
	var decorTables := {}
	for faction in def.dressing:
		var pt := {}
		var dt := {}
		for id in def.dressing[faction]:
			var w := float(def.dressing[faction][id])
			if props.has(String(id)): pt[String(id)] = w
			elif decor.has(String(id)): dt[String(id)] = w
		propTables[int(faction)] = pt
		decorTables[int(faction)] = dt
	var motifTables := {}
	for faction in def.motifs:
		var mt := {}
		for motif in def.motifs[faction]:
			if MOTIFS.has(StringName(motif)): mt[String(motif)] = float(def.motifs[faction][motif])
		motifTables[int(faction)] = mt
	var motifDefs := {}
	for motif in MOTIFS: motifDefs[String(motif)] = MOTIFS[motif].duplicate(true)
	var fieldDensity := {}
	for id in FIELD_PROPS:
		var chance := float(def.features.get(FIELD_PROPS[id], 0.0))
		if chance > 0.0 && props.has(String(id)): fieldDensity[String(id)] = chance
	var pickupTable := {}
	for kind in def.pickupTable: pickupTable[String(kind)] = float(def.pickupTable[kind])
	var wallStrip: String = WALL_STRIP.get(grammar, "cliff_lip")
	return {
		"layerOf": layerOf, "mainLayer": 0, "blocked": blocked, "spawnable": spawnable,
		"wallStrip": STRIPS.find(wallStrip), "waterStrip": STRIPS.find("shore_foam"),
		"props": props, "decor": decor, "propTables": propTables, "decorTables": decorTables,
		"pickupTable": pickupTable, "pickupsPerChunk": def.pickupsPerChunk, "pickupIds": pickupIds(),
		"motifs": motifTables, "motifDefs": motifDefs, "motifsPerChunk": float(def.features.get("motifs", 1.0)),
		"fieldDensity": fieldDensity, "fieldSpacing": float(def.features.get("fieldSpacing", 1400.0)),
		"propsPerChunk": int(def.features.get("props", 16)), "decorPerChunk": int(def.features.get("decor", 110)),
		"start": def.startPosition, "lots": lots, "lanes": lanes, "lotTerrain": Root.terrain.LOT,
		"roofDecor": String(ROOF_DECOR.get(grammar, &"")) if decorMeshes.has(ROOF_DECOR.get(grammar, &"")) else "",
	}

## Loads and pools a few of everything a chunk uses before the run starts (behind the loading), so the first
## chunks don't pay for loading scenes: two of each pooled prop, the pickups' scenes, a few ground quads
var keepLoaded: Array = []
func prewarm() -> void:
	for id in propScenes:
		if manifest[String(id)].get("class", "") == "STATEFUL": continue
		for k in 2: give("prop:" + id, newProp(id), POOL_CAP.prop)
	for kind in def.pickupTable:
		if String(kind) == "none": continue
		var id: String = pickupIds().get(String(kind), "coin")
		var scene: String = Pickups.def(id).get("scene", Pickups.GENERIC_SCENE)
		keepLoaded.push_back(load(scene))
		if not id in stockIds: stockIds.push_back(id)
	keepLoaded.push_back(load(Pickups.def("coin").get("scene", Pickups.GENERIC_SCENE)))
	if not "coin" in stockIds: stockIds.push_front("coin")
	while stockPickup(): pass
	for k in 24: give("quad", newQuad(), POOL_CAP.quad)

#--- the pickup stock ---------------------------------------------------------------------------------

var stockIds: Array[String] = [] #the level's pickup ids (prewarm)

## A pickup for a chunk: a ready-made one when the stock has it, else a new one
func takePickup(id: String) -> Node2D:
	var node = take("pickup:" + id)
	return node if node != null else Pickups.make(id)

## Makes one pickup the stock is short of; false when it is full
func stockPickup() -> bool:
	for id in stockIds:
		var want: int = PICKUP_STOCK.coin if id == "coin" else PICKUP_STOCK.other
		var pool: Array = pools.get_or_add("pickup:" + id, [])
		if pool.size() < want:
			pool.push_back(Pickups.make(id))
			return true
	return false

#--- pools -------------------------------------------------------------------------------------------

func take(key: String):
	var pool: Array = pools.get(key, [])
	return pool.pop_back() if not pool.is_empty() else null

## Back to its pool (out of the tree), or freed when the pool is full
func give(key: String, node: Node, cap: int) -> void:
	var pool: Array = pools.get_or_add(key, [])
	if node.get_parent(): node.get_parent().remove_child(node)
	if pool.size() >= cap:
		node.free()
		return
	pool.push_back(node)

func takeShape() -> ConvexPolygonShape2D:
	var shape = take("shape")
	return shape if shape != null else ConvexPolygonShape2D.new()

func giveShape(shape: ConvexPolygonShape2D) -> void:
	var pool: Array = pools.get_or_add("shape", [])
	if pool.size() < 600: pool.push_back(shape)

func newQuad() -> MeshInstance2D:
	var quad: MeshInstance2D = take("quad")
	if quad == null:
		quad = MeshInstance2D.new()
		quad.mesh = quadMesh
		quad.material = groundMaterial
	return quad

func newBody() -> StaticBody2D:
	var body: StaticBody2D = take("body")
	if body == null:
		body = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("shapeOwner", body.create_shape_owner(body))
	return body

func newOccluder() -> LightOccluder2D:
	var occ: LightOccluder2D = take("occluder")
	if occ == null:
		occ = LightOccluder2D.new()
		occ.occluder = OccluderPolygon2D.new()
		occ.occluder.closed = false
		occ.occluder.cull_mode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
		occ.set_meta("gc_world", true)
	return occ

func newLine() -> Line2D:
	var line: Line2D = take("line")
	if line == null:
		line = Line2D.new()
		line.width = 128.0
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = false
	return line

func newMultiMesh(id: StringName) -> MultiMeshInstance2D:
	var mmi: MultiMeshInstance2D = take("mmi:" + id)
	if mmi == null:
		mmi = MultiMeshInstance2D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = decorMeshes[id]
		mm.custom_aabb = AABB(Vector3(-400, -400, -1), Vector3(ChunkRecipe.CHUNK.x + 800, ChunkRecipe.CHUNK.y + 800, 2))
		mmi.multimesh = mm
		mmi.texture = decorTextures[id]
		mmi.material = decorMaterials[id]
	return mmi

## A pooled prop scene, its occluder kept aside so a prop placed over the occluder budget can go without
func newProp(id: StringName) -> StaticBody2D:
	var prop: StaticBody2D = take("prop:" + id)
	if prop == null:
		prop = propScenes[id].instantiate()
		var occ: LightOccluder2D = prop.get_node_or_null("LightOccluder2D")
		if occ: prop.set_meta("occluderPolygon", occ.occluder)
	return prop

func freeAll() -> void:
	for key in pools:
		for item in pools[key]:
			if item is Node: item.free()
	pools.clear()
