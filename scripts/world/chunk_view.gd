class_name ChunkView extends RefCounted
## One applied chunk (docs/WORLD.md, "Apply"): the nodes a ChunkRecipe turns into, taken from the WorldSkin's
## pools on the main thread a few at a time (step) and handed back the same way (release), so neither a
## load nor an unload costs more than the TileManager's per-frame budget. Stages, in order:
##   GROUND   the chunk's control block into the ring (one step), then 8 ground quads of 1280 x 1280 (another)
##   BODY     one StaticBody2D (layer 1) with a ConvexPolygonShape2D per wall piece
##   OCCLUDE  wall occluders (LightOccluder2D, open polylines, metadata gc_world), one a step
##   LINES    shore foam and wall lips (Line2D, the baked strips tiled), one a step
##   DECOR    one MultiMeshInstance2D per decor id, one a step
##   PROPS    pooled prop scenes (TALL, LOW, WALL); STATEFUL ones instanced, with their taken-set bit; a layered
##            prop's canopy gets its variant's texture and joins PropReactions (fades over the car)
##   PICKUPS  the recipe's pickups, skipping the ones the taken set says were collected (from the skin's
##            stock of ready-made pickups when it has one)
##   EXTRAS   PickupWorld.decorateChunk's props, moved onto the recipe's open spots; then a few steps topping
##            up the skin's pickup stock, so the next chunk's pickup steps only add nodes to the tree
## Every step is one piece: the longest is a single node (a prop, a pickup) or the control blit.

enum { GROUND, BODY, OCCLUDE, LINES, DECOR, PROPS, PICKUPS, EXTRAS, DONE }

var chunk := Vector2i.ZERO
var recipe := {}
var origin := Vector2.ZERO
var stage := GROUND
var index := 0
var quads: Array = []
var body: StaticBody2D
var shapes: Array = []
var occluders: Array = []
var lines: Array = []
var mmis: Array = []   #[decor id, node]
var props: Array = []  #[prop id, node, pooled]
var objects: Node2D    #the chunk's own node (at its centre): props, pickups, decorateChunk's extras
var extras: Node2D
var releaseStage := 0
## The longest single step of each stage so far (a prop, a pickup, the ground...), in usec: the apply budget's floor
static var stageMaxUsec: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]

func _init(at: Vector2i, chunkRecipe: Dictionary) -> void:
	chunk = at
	recipe = chunkRecipe
	origin = Vector2(at) * ChunkRecipe.CHUNK

func isDone() -> bool:
	return stage == DONE

## Applies the next pieces until the deadline (Time.get_ticks_usec) passes; true once everything is in.
## The first stages (ground and collision) are never split.
func step(skin: WorldSkin, tm: Node, deadline: int) -> bool:
	while stage != DONE:
		var began := Time.get_ticks_usec()
		var was := stage
		match stage:
			GROUND: applyGround(skin, tm)
			BODY: applyBody(skin, tm)
			OCCLUDE:
				if applyOccluder(skin, tm): nextStage()
			LINES:
				if applyLine(skin, tm): nextStage()
			DECOR:
				if applyDecor(skin, tm): nextStage()
			PROPS:
				if applyProp(skin, tm): nextStage()
			PICKUPS:
				if applyPickup(skin, tm): nextStage()
			EXTRAS: applyExtras(skin, tm)
		var took := Time.get_ticks_usec() - began
		if took > stageMaxUsec[was]: stageMaxUsec[was] = took
		if Time.get_ticks_usec() >= deadline: break
	return stage == DONE

func nextStage() -> void:
	stage += 1
	index = 0

func applyGround(skin: WorldSkin, tm: Node) -> void:
	if index == 0:
		skin.writeControl(chunk, recipe.control)
		index = 1
		return
	for k in 8:
		var quad := skin.newQuad()
		quad.position = origin + Vector2(k % 4, k / 4) * WorldSkin.QUAD
		tm.groundLayer.add_child(quad)
		quads.push_back(quad)
	objects = Node2D.new()
	objects.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	objects.position = origin + ChunkRecipe.CHUNK * 0.5
	tm.objectLayer.add_child(objects)
	nextStage()

func applyBody(skin: WorldSkin, tm: Node) -> void:
	if not recipe.pieces.is_empty():
		body = skin.newBody()
		body.position = origin
		var owner: int = body.get_meta("shapeOwner")
		for piece in recipe.pieces:
			var shape := skin.takeShape()
			shape.points = piece
			body.shape_owner_add_shape(owner, shape)
			shapes.push_back(shape)
		tm.wallLayer.add_child(body)
	nextStage()

## One occluder; true when there are no more
func applyOccluder(skin: WorldSkin, tm: Node) -> bool:
	if index >= recipe.occluders.size(): return true
	var occ := skin.newOccluder()
	occ.occluder.polygon = recipe.occluders[index]
	occ.position = origin
	tm.wallLayer.add_child(occ)
	occluders.push_back(occ)
	index += 1
	return false

## One edge line; true when there are no more
func applyLine(skin: WorldSkin, tm: Node) -> bool:
	if index >= recipe.lines.size(): return true
	var entry: Array = recipe.lines[index]
	index += 1
	var line := skin.newLine()
	line.texture = skin.strips[entry[0]]
	line.default_color = skin.stripColors[entry[0]] #white, or a lava shore's foam
	line.points = entry[1]
	line.position = origin
	tm.edgeLayer.add_child(line)
	lines.push_back(line)
	return false

## One decor MultiMesh; true when there are no more
func applyDecor(skin: WorldSkin, tm: Node) -> bool:
	var ids: Array = recipe.decor.keys()
	if index >= ids.size(): return true
	var id = ids[index]
	index += 1
	var sid := StringName(id)
	if not skin.decorMeshes.has(sid): return false
	var buffer: PackedFloat32Array = recipe.decor[id]
	var mmi := skin.newMultiMesh(sid)
	mmi.multimesh.instance_count = buffer.size() / 12
	mmi.multimesh.buffer = buffer
	mmi.position = origin
	tm.decorLayer.add_child(mmi)
	mmis.push_back([sid, mmi])
	return false

## One prop; true when there are no more
func applyProp(skin: WorldSkin, tm: Node) -> bool:
	if index >= recipe.props.size(): return true
	var p: Array = recipe.props[index]
	index += 1
	var id := StringName(p[0])
	if not skin.propScenes.has(id) || tm.reservedAt(origin + p[1], 0.0): return false
	var bit: int = p[4]
	if bit >= 0 && tm.isTaken(chunk, bit): return false
	var stateful: bool = bit >= 0 || skin.manifest.get(String(id), {}).get("class", "") == "STATEFUL"
	var node: StaticBody2D = skin.propScenes[id].instantiate() if stateful else skin.newProp(id)
	if not stateful: PropReactions.reset(node) #a pooled prop may come back mid-wobble or knocked over
	node.position = p[1] - ChunkRecipe.CHUNK * 0.5
	node.rotation = p[2]
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	var textures: Array = skin.variants.get(id, [])
	if sprite && not textures.is_empty(): sprite.texture = textures[clampi(p[3], 0, textures.size() - 1)]
	var canopy: Sprite2D = node.get_node_or_null("Canopy")
	var tops: Array = skin.canopies.get(id, [])
	if canopy && not tops.is_empty(): canopy.texture = tops[clampi(p[3], 0, tops.size() - 1)]
	var occ: LightOccluder2D = node.get_node_or_null("LightOccluder2D")
	if occ:
		if not node.has_meta("occluderPolygon"): node.set_meta("occluderPolygon", occ.occluder)
		occ.occluder = node.get_meta("occluderPolygon") if p[5] else null
	if Spill.DEFS.has(id): node.set_meta(&"spilled", tm.has_method("spillUsed") && tm.spillUsed(chunk, p[1])) #a crane drops its container once
	if stateful:
		node.set_meta(&"worldChunk", chunk)
		node.set_meta(&"worldBit", bit)
		if bit >= 0: node.set_meta(&"worldSlot", Vector3i(chunk.x, chunk.y, bit))
		if skin.breakableScript: node.set_script(skin.breakableScript)
	objects.add_child(node)
	props.push_back([id, node, not stateful])
	if canopy && PropReactions.current: PropReactions.current.addCanopy(node, canopy)
	if PropReactions.current: PropReactions.current.addHero(node) #interactive ones get a smash tag (SmashTags)
	return false

## One pickup (a coin line's coins one each); true when there are no more
func applyPickup(skin: WorldSkin, tm: Node) -> bool:
	if index >= recipe.pickups.size(): return true
	var p: Array = recipe.pickups[index]
	index += 1
	var bit: int = p[2]
	if bit >= 0 && tm.isTaken(chunk, bit): return false
	if tm.reservedAt(origin + p[1], 0.0): return false
	var node: Node2D = skin.takePickup(p[0])
	node.position = p[1] - ChunkRecipe.CHUNK * 0.5
	if bit >= 0: node.set_meta(&"worldSlot", Vector3i(chunk.x, chunk.y, bit))
	objects.add_child(node)
	return false

## PickupWorld.decorateChunk's props (crates, the Speed Trap...), never in the start's or a station's chunk.
## It scatters them round the chunk's middle; each group (things within 500 px of the first) is moved onto
## one of the recipe's open spots, and a group with no spot left is dropped. They join the tree once placed.
func applyExtras(skin: WorldSkin, tm: Node) -> void:
	if index > 0:
		#the extras are in: top the pickup stock up, one pickup a step
		if not skin.stockPickup(): nextStage()
		return
	index = 1
	#what spilled out of interactive props and came to rest here (Spill.record)
	if tm.has_method("spilledIn"):
		for e in tm.spilledIn(chunk):
			if not skin.propScenes.has(e[0]): continue
			var node: Node2D = skin.propScenes[e[0]].instantiate()
			node.position = e[1] - ChunkRecipe.CHUNK * 0.5
			node.rotation = e[2]
			objects.add_child(node)
	if tm.decoratesChunk(chunk):
		extras = Node2D.new()
		PickupWorld.decorateChunk(extras, tm.chunkRng(chunk, "props"))
		var spots: Array = recipe.get("spots", [])
		var used := 0
		var anchor := Vector2.INF
		var delta := Vector2.ZERO
		var drop := false
		for node in extras.get_children():
			if anchor != Vector2.INF && node.position.distance_to(anchor) < 500.0:
				if drop: node.free()
				else: node.position += delta
				continue
			anchor = node.position
			drop = used >= spots.size()
			if drop:
				node.free()
				continue
			delta = (spots[used] - ChunkRecipe.CHUNK * 0.5) - node.position
			used += 1
			node.position += delta
		objects.add_child(extras)

## Hands the nodes back a few at a time; true once everything is out
func release(skin: WorldSkin, deadline: int) -> bool:
	while true:
		match releaseStage:
			0:
				while not props.is_empty():
					var entry: Array = props.pop_back()
					if not is_instance_valid(entry[1]): continue
					if PropReactions.current: PropReactions.current.forget(entry[1])
					if entry[2]: skin.give("prop:" + entry[0], entry[1], WorldSkin.POOL_CAP.prop)
					if Time.get_ticks_usec() >= deadline: return false
				releaseStage = 1
			1:
				if is_instance_valid(objects): objects.queue_free() #pickups, stateful props, extras
				objects = null
				for quad in quads: skin.give("quad", quad, WorldSkin.POOL_CAP.quad)
				quads.clear()
				releaseStage = 2
			2:
				if body:
					var owner: int = body.get_meta("shapeOwner")
					body.shape_owner_clear_shapes(owner)
					skin.give("body", body, WorldSkin.POOL_CAP.body)
					body = null
				for shape in shapes: skin.giveShape(shape)
				shapes.clear()
				for occ in occluders: skin.give("occluder", occ, WorldSkin.POOL_CAP.occluder)
				occluders.clear()
				releaseStage = 3
			3:
				for line in lines: skin.give("line", line, WorldSkin.POOL_CAP.line)
				lines.clear()
				for entry in mmis: skin.give("mmi:" + entry[0], entry[1], WorldSkin.POOL_CAP.mmi)
				mmis.clear()
				return true
		if Time.get_ticks_usec() >= deadline: return false
	return true

## World nodes this chunk holds now (pickups and extras not counted), for tests and the budget check
func nodeCount() -> int:
	var n := quads.size() + (1 if body else 0) + occluders.size() + lines.size() + mmis.size()
	for entry in props:
		if is_instance_valid(entry[1]): n += 1 + entry[1].get_child_count()
	return n
