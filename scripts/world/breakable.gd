class_name BreakableProp extends StaticBody2D
## Breakable and explosive props (docs/WORLD.md, docs/WORLD_ART.md "Props"). The baked prop scenes in
## world/art/props/ carry everything as metadata on their StaticBody2D root: `smashSpeed`, `broken` and
## `debris` (texture paths) on breakables, `explosive` on the barrel and the tank (the tank's smashSpeed is
## 100000: only a blast sets it off). So the statics here work on any such prop, script or not; this file
## may also be attached as the prop's script, which gives it the `smashSpeed` property and `smash(car)` the
## car looks for.
##
## - The car (overhead_car_body_2d.gd) smashes a prop it hits at or above its smashSpeed, with no wall damage:
##   smashNode swaps in the broken sprite, throws a short pooled debris burst (tweens, nothing per frame once
##   it settles), turns the collision and occluder off, spills a few coin pickups from a haybale, fence or
##   crate (collected the usual way, so nothing is credited from the animation), and marks the prop taken in
##   the run's persistent set (WorldMap.markTaken) by the slot ChunkView gave it (metadata worldSlot).
## ChunkView attaches this script to every STATEFUL prop it instantiates (WorldSkin.breakableScript).
## - An explosive goes off instead: detonate() is deferred and runs once per prop, then blasts through GoonFx
##   (car damage, goons flattened with crush credit, the pooled explosion). Every blast calls blastAt(), which
##   sets off other explosives in its radius CHAIN_DELAY later, so a chain spreads a hop per 0.12 s and each
##   prop only ever detonates once: bounded.
## - tag() puts the props goons care about into groups (SpawnManager calls it from SceneTree.node_added):
##   prop_log (Snapper spawns), prop_manhole (Rat Pack spawns), prop_crate (Bandit bait), prop_carcass
##   (Buzzard perches), prop_hive (Yippers knock, Bandits raid), prop_rock (Rattlers sun on red rocks),
##   prop_den (Bandits stash loot, Spill.stash), prop_burrow (Jackalope spawns and hides),
##   prop_roost (Buzzard roosts, Spill.ROOSTS), prop_explosive. Goons.DATA "seeks" names the groups a goon uses.

const SPEED_KEEP := 0.85 #share of the car's speed kept through a smash
## Props that barely slow the car (speedKeep): a burrow mound caves in, a pumpkin splats
const SPEED_KEEPS := {&"burrow": 0.95, &"pumpkin": 0.98}
## Coins a smash throws out, once (every paying prop has a taken-set bit, or Spill.markUsed for one without)
const COIN_SPILL := {&"haybale": 2, &"fence": 1, &"crate": 3, &"den": 4, &"burrow": 1, &"beehive": 2}
const BLAST := {&"barrel": Vector2(170.0, 8.0), &"tank": Vector2(320.0, 16.0)} #radius px, car damage
const DEFAULT_BLAST := Vector2(170.0, 8.0)
const CHAIN_DELAY := 0.12
const COIN_SCENE := "res://scene/powerup/coin.tscn"
## Chance a smash also throws out a Common or Uncommon pickup (a Coin Stack past that): the crate, the one crate
## the game has (Bandits raid it; PickupWorld.decorateChunk's crates are the same baked prop)
const PICKUP_SPILL := {&"crate": 0.35}
const SCRIPT_PATH := "res://scripts/world/breakable.gd"
const GROUPS := {&"log": &"prop_log", &"manhole": &"prop_manhole", &"crate": &"prop_crate", &"carcass": &"prop_carcass", &"logpile": &"prop_logpile",
	&"beehive": &"prop_hive", &"rock_red": &"prop_rock", &"den": &"prop_den", &"burrow": &"prop_burrow"}
const ROOST_GROUP := &"prop_roost" #crowns Buzzards roost in (Spill.ROOSTS)
const EXPLOSIVE_GROUP := &"prop_explosive"
const DEBRIS_PIECES := 5
const DEBRIS_POOL_MAX := 30
const DEBRIS_SECONDS := 0.6

static var textures := {} #path -> Texture2D, loaded on first use
static var debrisPool: Array[Sprite2D] = []

#--- as the prop's own script (optional) -------------------------------------------------------------

var smashSpeed: float:
	get: return BreakableProp.speedOf(self)

func smash(car: Node2D) -> void:
	BreakableProp.smashNode(self, car)

## A one-shot prop (makeOneShot) already smashed this run doesn't come back; one that stays joins the smash tags
func _ready() -> void:
	if not get_meta(&"oneShot", false): return
	if Spill.isUsed(global_position):
		queue_free()
		return
	if PropReactions.current: PropReactions.current.addHero(self)

## A breakable placed outside the recipe (decorateChunk's crates) has no taken-set bit: it is remembered by its
## position instead (Spill.markUsed), so a reloaded chunk doesn't bring a smashed one back to pay again
static func makeOneShot(node: Node) -> void:
	node.set_script(load(SCRIPT_PATH))
	node.set_meta(&"oneShot", true)

#--- queries -----------------------------------------------------------------------------------------

## A prop the car can smash or set off
static func isBreakable(node: Object) -> bool:
	return node != null && (node.has_meta(&"smashSpeed") || node.get_meta(&"explosive", false))

## The speed that smashes it: its smashSpeed, INF once smashed (or for an explosive with none)
static func speedOf(node: Object) -> float:
	if node.get_meta(&"smashed", false): return INF
	return float(node.get_meta(&"smashSpeed", INF))

## A goon attacking at `speed` along `dir` breaks it (a Tusker's charge, a Bullmoose's lunge: Goons.DATA
## "smashes"): spills and coins go along `dir`, and the goon keeps going. False when it holds (a wall to it).
static func smashedByGoon(node: Object, speed: float, dir: Vector2) -> bool:
	if not node is Node2D || not isBreakable(node) || speedOf(node) > speed: return false
	node.set_meta(&"spillDir", dir)
	smashNode(node, null)
	return true

static func propId(node: Object) -> StringName:
	return StringName(node.get_meta(&"propId", &""))

## The share of the car's speed it keeps through smashing this prop (overhead_car_body_2d.gd)
static func speedKeep(node: Object) -> float:
	return SPEED_KEEPS.get(propId(node), SPEED_KEEP)

## Groups for the props goons look for; cheap enough to run on every StaticBody2D added to the tree
static func tag(node: Node) -> void:
	if not node.has_meta(&"propId") || node.get_meta(&"smashed", false): return
	var group: StringName = GROUPS.get(propId(node), &"")
	if group != &"": node.add_to_group(group)
	if node.get_meta(&"explosive", false): node.add_to_group(EXPLOSIVE_GROUP)
	if Spill.DEFS.has(propId(node)): node.add_to_group(Spill.SPILL_GROUP)
	if Spill.ROOSTS.has(propId(node)): node.add_to_group(ROOST_GROUP)
	if propId(node) == &"burrow": node.add_to_group(Spill.WARREN_GROUP) #kept when it caves in: the warren count

#--- smashing ----------------------------------------------------------------------------------------

## The car hit it fast enough (or a goon broke it: car is then null). Once only.
static func smashNode(node: Node2D, car: Node2D = null) -> void:
	if not is_instance_valid(node) || node.get_meta(&"smashed", false): return
	if node.get_meta(&"explosive", false):
		detonate(node)
		return
	node.set_meta(&"smashed", true)
	if is_instance_valid(car): node.set_meta(&"carBrokeAt", GoonVerbs.now()) #a hive's swarm stings the car that broke it (Spill.Swarm)
	var pos := node.global_position
	#along the car's travel, or the direction a goon (a charge, a cut), or a blast gave it
	var dir: Vector2 = node.get_meta(&"spillDir", car.velocity if is_instance_valid(car) else Vector2.ZERO)
	breakVisual(node)
	debris(node)
	if not node.get_meta(&"dropped", false): #the semi's dropped cargo (Drop the Load) pays nothing
		spillCoins(propId(node), pos, dir)
		spillPickup(propId(node), pos, dir)
	markTaken(node)
	if node.get_meta(&"oneShot", false): Spill.markUsed(pos)
	#a log pile, water tower, billboard or hive lets its contents loose (Spill)
	Spill.release(node, dir)
	if Spill.ROOSTS.has(propId(node)): Spill.knockRoost(node, INF) #a smashed scarecrow drops its Buzzards
	var fx = Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null
	if fx: fx.dust(pos)

## The broken sprite in place, collision and the night shadow off, out of the goons' groups
static func breakVisual(node: Node) -> void:
	var sprite = node.get_node_or_null("Sprite2D")
	var broken := texture(node.get_meta(&"broken", ""))
	if sprite is Sprite2D && broken != null: sprite.texture = broken
	for child in node.get_children():
		if child is CollisionShape2D || child is CollisionPolygon2D: child.set_deferred("disabled", true)
		elif child is LightOccluder2D:
			child.set_meta("gc_vis", false) #Settings re-applies lighting from this
			child.visible = false
	for group in [GROUPS.get(propId(node), &""), EXPLOSIVE_GROUP, Spill.SPILL_GROUP, ROOST_GROUP]:
		if group != &"" && node.is_in_group(group): node.remove_from_group(group)

## Coin pickups thrown out along `dir` (the car's travel, or a charge's); the car collects them like any other
static func spillCoins(id: StringName, pos: Vector2, dir: Vector2) -> int:
	return throwCoins(COIN_SPILL.get(id, 0), pos, dir)

## Sometimes a pickup too (PICKUP_SPILL), collected the usual way; its id, or "" for none
static func spillPickup(id: StringName, pos: Vector2, dir: Vector2, roll := -1.0) -> String:
	if roll < 0.0: roll = randf()
	if roll >= float(PICKUP_SPILL.get(id, 0.0)) || not is_instance_valid(Root.levelRoot): return ""
	var pick := Pickups.rollAtLeast(Pickups.R.COMMON)
	if Pickups.rarity(pick) > Pickups.R.UNCOMMON: pick = "coinstack"
	var ahead: Vector2 = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	PickupEffects.spawnPickup(pick, pos + ahead * 70.0) #spawnPickup goes through Pickups.openOr
	return pick

## `count` coin pickups thrown out along `dir` from `pos` (spillCoins; an orchard oak's apples, a cleared warren)
static func throwCoins(count: int, pos: Vector2, dir: Vector2) -> int:
	if count <= 0 || not is_instance_valid(Root.levelRoot): return 0
	var scene: PackedScene = load(COIN_SCENE)
	var ahead: Vector2 = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	for i in count:
		var coin := scene.instantiate()
		coin.position = pos + ahead.rotated((i - (count - 1) / 2.0) * 0.6) * 140.0
		Root.levelRoot.add_child.call_deferred(coin)
	return count

## Records the smash in the run's taken set (WorldMap or TileManager markTaken), so the chunk keeps it
## broken when it is rebuilt. False when the prop has no slot or nothing records it yet.
static func markTaken(node: Node) -> bool:
	var slot := takenSlot(node)
	if slot.z < 0: return false
	var chunk := Vector2i(slot.x, slot.y)
	var bit := slot.z
	for owner in [Root.worldMap, Root.levelRoot.get_node_or_null("TileManager") if is_instance_valid(Root.levelRoot) else null]:
		if owner != null && owner.has_method("markTaken"):
			owner.markTaken(chunk, bit)
			return true
	return false

## The prop's slot in the taken set as (chunk x, chunk y, bit), z = -1 for none. ChunkView sets `worldSlot`
## (Vector3i) and `worldChunk`/`worldBit`; `world_chunk`/`world_bit` are accepted too.
static func takenSlot(node: Node) -> Vector3i:
	if node.has_meta(&"worldSlot"): return node.get_meta(&"worldSlot")
	for keys in [[&"worldChunk", &"worldBit"], [&"world_chunk", &"world_bit"]]:
		if node.has_meta(keys[0]) && node.has_meta(keys[1]):
			var chunk: Vector2i = node.get_meta(keys[0])
			return Vector3i(chunk.x, chunk.y, int(node.get_meta(keys[1])))
	return Vector3i(0, 0, -1)

#--- explosives --------------------------------------------------------------------------------------

## Sets an explosive off on the next frame (never inside the physics callback that hit it). Once per prop.
static func detonate(node: Node2D, delay := 0.0) -> bool:
	if not is_instance_valid(node) || node.get_meta(&"smashed", false) || not node.is_inside_tree(): return false
	node.set_meta(&"smashed", true) #from now on it can't be set off again: chains are bounded
	if delay > 0.0: node.get_tree().create_timer(delay, false, true).timeout.connect(explode.bind(node))
	else: explode.call_deferred(node)
	return true

static func explode(node: Node2D) -> void:
	if not is_instance_valid(node): return
	var pos := node.global_position
	var blast: Vector2 = BLAST.get(propId(node), DEFAULT_BLAST)
	breakVisual(node)
	debris(node)
	markTaken(node)
	var fx = Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null
	if fx: fx.blast(pos, blast.x, blast.y) #car damage, goons with crush credit, the pooled explosion, chains
	else:
		if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("explode"): Root.levelRoot.explode(pos)
		blastAt(node.get_tree(), pos, blast.x)

## A blast at `pos` sets off every explosive prop within `radius` (and in the clear: walls stop it),
## CHAIN_DELAY later. Returns how many it set off.
static func blastAt(tree: SceneTree, pos: Vector2, radius: float) -> int:
	if tree == null: return 0
	PropReactions.blast(pos, radius) #nearby crowns shake and drop leaves
	#spilling props in the blast go too: a log pile bursts away from it, a crane loses its container
	for node in tree.get_nodes_in_group(Spill.SPILL_GROUP):
		if not node is Node2D || node.get_meta(&"smashed", false) || node.get_meta(&"spilled", false): continue
		if node.global_position.distance_to(pos) > radius + 60.0 || not WorldHooks.lineClear(pos, node.global_position): continue
		if propId(node) == &"crane": Spill.ramCrane.call_deferred(node, Spill.DROP_SPEED)
		else:
			node.set_meta(&"spillDir", node.global_position - pos)
			smashNode.call_deferred(node, null)
	var count := 0
	for node in tree.get_nodes_in_group(EXPLOSIVE_GROUP):
		if not node is Node2D || node.get_meta(&"smashed", false): continue
		if node.global_position.distance_to(pos) > radius + 30.0 || not WorldHooks.lineClear(pos, node.global_position): continue
		if detonate(node, CHAIN_DELAY): count += 1
	return count

#--- art ---------------------------------------------------------------------------------------------

static func texture(path: String) -> Texture2D:
	if path == "": return null
	if not textures.has(path): textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

## A short burst of the prop's debris cells (a row of square cells): pooled sprites on tweens
static func debris(node: Node2D) -> void:
	var tex := texture(node.get_meta(&"debris", ""))
	var parent = node.get_parent()
	if tex == null || parent == null || not node.is_inside_tree(): return
	var cells := maxi(1, tex.get_width() / maxi(1, tex.get_height()))
	var cell := tex.get_height()
	var scale: float = node.get_node("Sprite2D").scale.x if node.has_node("Sprite2D") else 1.3333
	for i in DEBRIS_PIECES:
		var s := takeDebris(parent)
		if s == null: return
		var atlas := s.texture as AtlasTexture
		if atlas == null:
			atlas = AtlasTexture.new()
			s.texture = atlas
		atlas.atlas = tex
		atlas.region = Rect2((i % cells) * cell, 0, cell, cell)
		var dir := Vector2.from_angle(i * TAU / DEBRIS_PIECES + randf() * 0.8)
		s.global_position = node.global_position
		s.rotation = randf() * TAU
		s.scale = Vector2.ONE * scale * 0.6
		s.modulate = Color.WHITE
		s.visible = true
		var tween := s.create_tween().set_parallel(true)
		tween.tween_property(s, "global_position", node.global_position + dir * randf_range(70.0, 150.0), DEBRIS_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(s, "rotation", s.rotation + randf_range(-4.0, 4.0), DEBRIS_SECONDS)
		tween.tween_property(s, "modulate:a", 0.0, DEBRIS_SECONDS * 0.5).set_delay(DEBRIS_SECONDS * 0.5)
		tween.chain().tween_callback(s.hide)

## A hidden pooled sprite moved under `parent`, or a new one while the pool is small; null when all are busy
static func takeDebris(parent: Node) -> Sprite2D:
	for i in range(debrisPool.size() - 1, -1, -1):
		if not is_instance_valid(debrisPool[i]): debrisPool.remove_at(i)
	for s in debrisPool:
		if not s.visible:
			if s.get_parent() != parent: s.reparent(parent, false)
			return s
	if debrisPool.size() >= DEBRIS_POOL_MAX: return null
	var s := Sprite2D.new()
	s.z_index = 1
	s.visible = false
	parent.add_child(s)
	debrisPool.push_back(s)
	return s
