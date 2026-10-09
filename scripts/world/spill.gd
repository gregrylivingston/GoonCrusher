class_name Spill extends RefCounted
## Interactive props (package 14, P-4; docs/WORLD.md "Interactive props"): props that let something loose when
## they go. One hook, `release`, called when a prop in DEFS breaks (BreakableProp.smashNode: the car at its
## smash speed, a goon cutting it loose, or a blast), plus the crane, which drops its container when rammed
## hard (PropReactions). What comes out by kind:
##   logs   the log pile: LOGS logs roll out along the release direction, flattening goons (crushes for the
##          player) and knocking the car, then lie where they stop as ordinary log props (Snapper spawns too)
##   wave   the water tower: a flood flattens the goons around it ("SPLASH")
##   fall   the billboard: it topples away from the car (its broken state is the board lying flat) and
##          flattens whatever is under it
##   swarm  the beehive: a swarm that hunts the nearest goons for SWARM_SECONDS and stings the car if it is close
##   drop   the crane: its container falls off the jib's tip onto whatever is below, then stays as a prop
## Goons whose Goons.DATA "seeks" says so walk to a log pile near the car and cut it loose, aimed at the car,
## or knock a hive (GoonVerbs.Verb.seekProp). What spilled is recorded per chunk on the TileManager (addSpilled), so a
## reloaded chunk shows the logs and containers where they came to rest and a crane drops only once.
## Every kill here goes through flatten with its source (logs, splash, fall, bees, drop), which SpawnManager.creditCrush
## credits to the player, Critter Chain included, when it happens within CRITTER_CREDIT_PX of the car.
## Roosts (ROOSTS): crowns Buzzards sit in (Goons.DATA seeks "roost"); a ram on the trunk (ram) knocks them down.
## Region 1 (The Wilds; docs/GOONS.md "Wild instincts"):
##   stash  the Bandit den: Bandits carry stolen loot home to it (stash); smashing it bursts every stashed
##          pickup out ("LOOT RECOVERED"). The stash outlives a chunk reload (a record on the TileManager).
##   burrow a Jackalope burrow caves in: the one hiding in it is thrown out stunned, it spawns no more, and when
##          every burrow of its warren (the `group` meta ChunkView sets from the motif) is down: WARREN CLEARED
## Lures (R-10; through Pickups.lures): the Dinner Bell, rammed at BELL_RAM, calls every goon within BELL_LURE to
## it for BELL_SECONDS, once per bell; a Salt Lick is a permanent lure for heavies (rank 3) while its chunk is loaded.
## PropReactions.addHero calls arm() for every prop that streams in (and disarm() when its chunk goes), which
## restores per-prop state (a den's sacks, a rung bell) and registers a salt lick's lure.

const DEFS := {
	&"logpile": {"kind": "logs"}, &"watertower": {"kind": "wave"}, &"billboard": {"kind": "fall"},
	&"beehive": {"kind": "swarm"}, &"crane": {"kind": "drop"},
	&"den": {"kind": "stash"}, &"burrow": {"kind": "burrow"},
}
## Props a spill leaves behind: WorldSkin loads them with the level whenever the spilling prop is in its dressing
const PRODUCTS := {&"logpile": [&"log"], &"crane": [&"container"]}
const PILE_GROUP := &"prop_logpile"
const SPILL_GROUP := &"prop_spill"

const LOGS := 5
const LOG_DISTANCE := Vector2(260.0, 560.0) #px each log rolls
const LOG_SPREAD := 0.55                    #radians either way of the release direction
const LOG_SECONDS := 1.1
const LOG_CRUSH := 64.0                     #px from a rolling log's centre line that flattens a goon
const LOG_CAR_DAMAGE := 6.0
const WAVE_RADIUS := 340.0
const FALL_BOX := Rect2(-195.0, 18.0, 390.0, 130.0) #the board lying flat on its +y side, prop-local px
const FALL_CAR_DAMAGE := 8.0
const SWARM_SECONDS := 12.0
const SWARM_SPEED := 300.0
const SWARM_REACH := 700.0                  #px it looks for goons
const SWARM_KILLS := 8
const SWARM_STING := 0.5                    #car damage per sting, every STING_GAP while it is on the car
const STING_GAP := 0.4
const STING_WINDOW := 3.0                   #s after the car broke a hive in which its swarm may sting the car
const SWARM_CAP := 3
const DROP_SPEED := 320.0                   #px/s into the crane that shakes the container loose
const DROP_TIP := Vector2(265.0, -16.0)     #the jib's tip, crane-local px (world_gen.js crane canopy)
const DROP_SECONDS := 0.7
const DROP_BOX := Rect2(-240.0, -94.0, 480.0, 188.0) #the container, container-local px
const DROP_CAR_DAMAGE := 10.0
## Goons that release piles: the car must be this close to the pile, the goon this close to it, to try (the
## "release" rows in Goons.DATA seeks carry the same numbers)
const LURE_CAR := 900.0
const LURE_GOON := 650.0
const REACH := 150.0                        #px from the pile's centre where a goon can cut it loose
## Roosts by prop id: how many Buzzards a crown holds, the ram (px/s into the trunk) that knocks them down, how
## long they lie stunned, and how far from the trunk they sit. Scarecrows (Orchard Lanes) join with a row here.
const ROOSTS := {&"deadtree": {"perches": 3, "knock": 250.0, "stun": 1.5, "ring": 46.0},
	&"scarecrow": {"perches": 2, "knock": 250.0, "stun": 1.5, "ring": 36.0}}
const ROOST_SECONDS := Vector2(9.0, 14.0)  #how long a Buzzard sits before it flies off again
const SPIN_SECONDS := 0.7                  #a knocked scarecrow's spin

## A spilling prop broke: let its contents loose. `dir` is where they go (the car's travel, or toward the car
## when a goon cut it loose); `byPlayer` whether the player gets the crushes (always, today: the chaos is theirs).
static func release(node: Node2D, dir: Vector2) -> void:
	var def: Dictionary = DEFS.get(BreakableProp.propId(node), {})
	if def.is_empty() || not node.is_inside_tree(): return
	if dir.length_squared() < 0.01: dir = Vector2.from_angle(randf() * TAU)
	dir = dir.normalized()
	match def.kind:
		"logs": spillLogs(node, dir)
		"wave": wave(node.global_position)
		"fall": fall(node)
		"swarm": swarm(node)
		"stash": releaseStash(node, dir)
		"burrow": collapseBurrow(node)

## A prop streamed in (PropReactions.addHero, from ChunkView): its per-prop state comes back
static func arm(prop: Node2D) -> void:
	match BreakableProp.propId(prop):
		&"den": loadStash(prop)
		&"bell": prop.set_meta(&"spilled", isUsed(prop.global_position)) #rung once a run
		&"saltlick": Pickups.addLure(prop.global_position, SALT_LURE, INF, &"", SALT_RANK, SALT_LOOSE, prop.get_instance_id())

## Its chunk is going (PropReactions.forget): a salt lick's lure goes with it
static func disarm(prop: Node2D) -> void:
	if BreakableProp.propId(prop) == &"saltlick": Pickups.removeLure(prop.get_instance_id())

static func fx() -> GoonFx:
	return Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null

## A prop a spill leaves behind: the run's loaded scene (WorldSkin loads PRODUCTS), else from the manifest
static func productScene(id: StringName) -> PackedScene:
	var tm := tileManager()
	var skin = tm.get("skin") if tm else null
	if skin != null && skin.propScenes.has(id): return skin.propScenes[id]
	var path: String = WorldSkin.loadManifest().get(String(id), {}).get("scene", "")
	return load(path) if path != "" && ResourceLoader.exists(path) else null

static func tileManager() -> Node:
	return Root.levelRoot.get_node_or_null("TileManager") if is_instance_valid(Root.levelRoot) else null

## Kills a goon with crush credit: a spill counts as the player's, like a blast, near the car (creditCrush).
## `source` names the kill in the Critter Chain (PickupEffects.CHAIN_NAMES).
static func flatten(goon: Node2D, from: Vector2, cause: StringName = &"crush", source: StringName = &"logs") -> void:
	if goon.get("dead"): return
	goon.set("killedFrom", from)
	goon.destroy(cause)
	if is_instance_valid(Root.spawnManager): Root.spawnManager.creditCrush(goon.global_position, goon, source)

static func goonsNear(pos: Vector2, radius: float) -> Array:
	return Root.spawnManager.goonsNear(pos, radius) if is_instance_valid(Root.spawnManager) else []

## A goon cut a log pile loose (or knocked a hive over): it spills toward the car
static func goonRelease(pile: Node2D, goon: Node2D, car: Node2D) -> void:
	if pile.get_meta(&"smashed", false): return
	var to: Vector2 = (car.global_position - pile.global_position) if is_instance_valid(car) else Vector2.ZERO
	pile.set_meta(&"spillDir", to)
	BreakableProp.smashNode(pile, null)
	if fx() && BreakableProp.propId(pile) == &"logpile": fx().label(goon.global_position, "TIMBER!")

#--- roosts -----------------------------------------------------------------------------------------

## The car rammed a prop at `speed` (PropReactions, a crown's hit): a crane drops its container, a roost drops
## its Buzzards
static func ram(prop: Node2D, speed: float) -> void:
	var id := BreakableProp.propId(prop)
	if DEFS.get(id, {}).get("kind", "") == "drop": ramCrane(prop, speed)
	if ROOSTS.has(id): knockRoost(prop, speed)
	if id == &"bell": ringBell(prop, speed)

## The ram that does something to a rammed (not smashed) prop: a crane's drop, a bell's ring, a roost's knock;
## INF once spent, -1 for a prop rams don't work on (SmashTags shows it like a smash speed)
static func ramSpeed(prop: Node2D) -> float:
	match BreakableProp.propId(prop):
		&"crane": return INF if prop.get_meta(&"spilled", false) else DROP_SPEED
		&"bell": return INF if prop.get_meta(&"spilled", false) else BELL_RAM
	var roost: Dictionary = ROOSTS.get(BreakableProp.propId(prop), {})
	if not roost.is_empty() && BreakableProp.isBreakable(prop): return INF if prop.get_meta(&"smashed", false) else float(roost.knock)
	return -1.0

## Where perch `slot` of a roost is
static func roostSpot(prop: Node2D, slot: int) -> Vector2:
	var def: Dictionary = ROOSTS.get(BreakableProp.propId(prop), {})
	return prop.global_position + Vector2.from_angle(prop.global_rotation + 0.5 + slot * TAU / maxi(int(def.get("perches", 3)), 1)) * float(def.get("ring", 46.0))

## The goons roosting on (or flying in to) a prop
static func roosting(prop: Node2D) -> Array:
	var out := []
	if not is_instance_valid(Root.spawnManager): return out
	for goon in Root.spawnManager.goons:
		if is_instance_valid(goon) && not goon.dead && goon.verb != null && goon.verb.get("roostAt") == prop: out.push_back(goon)
	return out

## A ram on a roost's trunk at its knock speed: every Buzzard in the crown drops, stunned and crushable.
## Returns how many fell.
static func knockRoost(prop: Node2D, speed: float) -> int:
	var def: Dictionary = ROOSTS.get(BreakableProp.propId(prop), {})
	if def.is_empty() || speed < float(def.knock): return 0
	var n := 0
	for goon in roosting(prop):
		if goon.state != &"roost": continue
		goon.verb.dropFromRoost(float(def.stun))
		n += 1
	if n > 0 && fx(): fx().label(prop.global_position, "KNOCKED DOWN" if n == 1 else "KNOCKED DOWN x%d" % n, 20)
	if BreakableProp.propId(prop) == &"scarecrow" && not prop.get_meta(&"smashed", false): spin(prop)
	return n

## A scarecrow rammed hard spins round once on its post
static func spin(prop: Node2D) -> void:
	var sprite: Node2D = prop.get_node_or_null("Sprite2D")
	if sprite == null || sprite.has_meta(&"spinning"): return
	sprite.set_meta(&"spinning", true)
	var rest := sprite.rotation
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "rotation", rest + TAU, SPIN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		sprite.rotation = rest
		sprite.remove_meta(&"spinning"))

#--- lures: the Dinner Bell, the Salt Lick (R-10) ---------------------------------------------------------

const BELL_RAM := 150.0     #px/s into the bell that rings it (15 MPH)
const BELL_LURE := 1200.0
const BELL_SECONDS := 6.0
const SALT_LURE := 900.0
const SALT_RANK := 3        #heavies only
const SALT_LOOSE := 500.0   #a heavy at the lick goes back to the car once the car is this close to it

## CLANG: every goon within BELL_LURE walks to the bell for BELL_SECONDS (a grazing herd stampedes away from
## it instead). Once per bell, even after its chunk reloads. True when it rang.
static func ringBell(bell: Node2D, speed: float) -> bool:
	if speed < BELL_RAM || bell.get_meta(&"spilled", false): return false
	bell.set_meta(&"spilled", true)
	markUsed(bell.global_position)
	var at := bell.global_position
	Pickups.addLure(at, BELL_LURE, BELL_SECONDS)
	for goon in goonsNear(at, BELL_LURE):
		if not goon.dead && goon.verb is GoonVerbs.Herd && goon.state == &"graze": goon.verb.spook(at)
	Audio.play(Transition.SOUNDS["clank"], 0.0, 0.55)
	if fx():
		fx().ring(at, BELL_LURE * 0.5)
		fx().ring(at, BELL_LURE)
		fx().label(at, "CLANG!", 26, HudTheme.GOLD)
	return true

## Whether a once-only prop at `at` has been used this run (markUsed; the crane's record)
static func isUsed(at: Vector2) -> bool:
	var tm := tileManager()
	if tm == null || not tm.has_method("spillUsed"): return false
	var chunk: Vector2i = tm.chunkOf(at)
	return tm.spillUsed(chunk, at - Vector2(chunk) * ChunkRecipe.CHUNK)

#--- logs --------------------------------------------------------------------------------------------

static func spillLogs(pile: Node2D, dir: Vector2) -> void:
	var scene := productScene(&"log")
	var parent := pile.get_parent()
	if scene == null || parent == null: return
	for i in LOGS:
		var d := dir.rotated(lerpf(-LOG_SPREAD, LOG_SPREAD, (i + randf() * 0.6) / LOGS))
		var piece: StaticBody2D = scene.instantiate()
		var roller := Roller.new(piece, pile.global_position + d * 40.0 + d.orthogonal() * randf_range(-60.0, 60.0), d, randf_range(LOG_DISTANCE.x, LOG_DISTANCE.y))
		parent.add_child(roller)
	if fx(): fx().label(pile.global_position, "TIMBER!")

## A log rolling out of a pile: a log prop with its collision off, rolled side-on along `dir` and slowing;
## goons in its path are flattened, the car is knocked once; when it stops it becomes a plain log prop where it lies
class Roller extends Node2D:
	var piece: StaticBody2D
	var dir: Vector2
	var distance: float
	var age := 0.0
	var from: Vector2
	var hitCar := false

	func _init(node: StaticBody2D, at: Vector2, d: Vector2, dist: float) -> void:
		piece = node
		dir = d
		distance = dist
		from = at
		top_level = true
		global_position = at
		var shape: CollisionShape2D = piece.get_node_or_null("CollisionShape2D")
		if shape: shape.disabled = true
		piece.rotation = d.angle() + PI * 0.5 #rolls side-on
		add_child(piece)

	func _physics_process(delta: float) -> void:
		age += delta
		var t := minf(age / Spill.LOG_SECONDS, 1.0)
		var along := distance * (1.0 - (1.0 - t) * (1.0 - t))
		global_position = from + dir * along
		var sprite: Node2D = piece.get_node_or_null("Sprite2D")
		if sprite: sprite.scale.y = 1.3333 * (1.0 + 0.08 * sin(along * 0.08)) #the bark turning over
		for goon in Spill.goonsNear(global_position, Spill.LOG_CRUSH + 140.0):
			var off: Vector2 = goon.global_position - global_position
			if absf(off.dot(dir)) < Spill.LOG_CRUSH && absf(off.dot(dir.orthogonal())) < 140.0: Spill.flatten(goon, global_position - dir * 40.0, &"crush", &"logs")
		var car = Root.playerCar
		if not hitCar && is_instance_valid(car) && car.global_position.distance_to(global_position) < 110.0 && t < 0.9:
			hitCar = true
			car.damage(Spill.LOG_CAR_DAMAGE)
			age = maxf(age, Spill.LOG_SECONDS * 0.9) #a log that hits the car stops against it
		if t >= 1.0: settle()

	func settle() -> void:
		set_physics_process(false)
		var sprite: Node2D = piece.get_node_or_null("Sprite2D")
		if sprite: sprite.scale = Vector2.ONE * 1.3333
		var at := global_position
		var rot := piece.global_rotation
		var tm := Spill.tileManager()
		var parent: Node = tm.objectsAt(at) if tm && tm.has_method("objectsAt") else null
		if parent == null: parent = get_parent() #the chunk it rolled into isn't applied: it goes with the pile's
		remove_child(piece)
		parent.add_child(piece)
		piece.global_position = at
		piece.global_rotation = rot
		var shape: CollisionShape2D = piece.get_node_or_null("CollisionShape2D")
		if shape: shape.set_deferred("disabled", false)
		Spill.record(&"log", at, rot)
		queue_free()

#--- the water tower, the billboard, the beehive ------------------------------------------------------

static func wave(pos: Vector2) -> void:
	for goon in goonsNear(pos, WAVE_RADIUS):
		if WorldHooks.lineClear(pos, goon.global_position): flatten(goon, pos, &"boom", &"splash")
	if PropReactions.current: PropReactions.current.splash(pos, WAVE_RADIUS)
	if fx(): fx().label(pos, "SPLASH!", 24)

## The billboard topples away from the car: its broken sprite (the board flat on its +y side) is flipped when
## the car came from that side, and whatever lies under the board is flattened
static func fall(board: Node2D) -> void:
	var car = Root.playerCar
	var side := 1.0
	if is_instance_valid(car) && board.to_local(car.global_position).y > 0.0: side = -1.0
	var sprite: Node2D = board.get_node_or_null("Sprite2D")
	if sprite: sprite.scale.y = absf(sprite.scale.y) * side
	var box := FALL_BOX
	if side < 0.0: box = Rect2(box.position.x, -box.end.y, box.size.x, box.size.y)
	for goon in goonsNear(board.global_position, box.size.length()):
		if box.has_point(board.to_local(goon.global_position)): flatten(goon, board.global_position, &"crush", &"fall")
	if is_instance_valid(car) && box.has_point(board.to_local(car.global_position)): car.damage(FALL_CAR_DAMAGE)
	if PropReactions.current: PropReactions.current.puff(board.to_global(box.get_center()), Vector2.from_angle(board.global_rotation + PI * 0.5 * side), 1.0, true)
	if fx(): fx().label(board.global_position, "FLATTENED", 22)

## Live swarms, oldest first: at most SWARM_CAP (each scans the goons every tick); a new one sends the oldest off
static var swarms: Array = []

static func swarm(hive: Node2D) -> void:
	var parent := hive.get_parent()
	if parent == null: return
	swarms = swarms.filter(func(s): return is_instance_valid(s) && not s.is_queued_for_deletion() && not s.leaving())
	while swarms.size() >= SWARM_CAP: swarms.pop_front().disperse()
	var s := Swarm.new(hive.global_position)
	#it stings the car only if the car broke this hive just now (STING_WINDOW); a raiding Bandit is its first target
	s.stingUntil = float(hive.get_meta(&"carBrokeAt", -INF)) + STING_WINDOW
	if hive.has_meta(&"raider") && is_instance_valid(hive.get_meta(&"raider")): s.first = hive.get_meta(&"raider")
	parent.add_child(s)
	swarms.push_back(s)
	if fx(): fx().label(hive.global_position, "BEES!", 22)

## A cloud of bees out of a smashed hive: it flies at the goon that raided the hive, else the nearest goon within
## SWARM_REACH, and flattens what it reaches (SWARM_KILLS at most). It goes for the car, and stings it while on it,
## only when the car broke the hive in the last STING_WINDOW s. It disperses after SWARM_SECONDS.
class Swarm extends Node2D:
	const DOTS := 26
	const LOOK_EVERY := 3 #ticks between target searches
	var age := 0.0
	var kills := 0
	var stingT := 0.0
	var stingUntil := -INF #GoonVerbs.now() seconds
	var first = null #the goon that raided the hive (a Bandit): stung first
	var vel := Vector2.ZERO
	var target := Vector2.INF
	var seeds := PackedVector2Array()

	func _init(at: Vector2) -> void:
		top_level = true
		z_as_relative = false
		z_index = PropReactions.BITS_Z
		global_position = at
		for i in DOTS: seeds.push_back(Vector2(randf() * TAU, randf_range(0.6, 1.8)))

	func leaving() -> bool:
		return age >= Spill.SWARM_SECONDS || kills >= Spill.SWARM_KILLS

	func disperse() -> void:
		age = maxf(age, Spill.SWARM_SECONDS)

	func angry() -> bool:
		return GoonVerbs.now() < stingUntil

	func _physics_process(delta: float) -> void:
		age += delta
		if leaving():
			modulate.a -= delta * 2.0
			if modulate.a <= 0.0: queue_free()
			queue_redraw()
			return
		var car = Root.playerCar
		if (Engine.get_physics_frames() + get_instance_id()) % LOOK_EVERY == 0: target = pickTarget(car)
		elif is_instance_valid(first) && not first.dead: target = first.global_position
		var want := (target - global_position).normalized() * Spill.SWARM_SPEED if target != Vector2.INF else Vector2.ZERO
		vel = vel.lerp(want, minf(4.0 * delta, 1.0))
		global_position += vel * delta
		for goon in Spill.goonsNear(global_position, 40.0):
			if not goon.get("dead") && kills < Spill.SWARM_KILLS:
				kills += 1
				Spill.flatten(goon, global_position, &"crush", &"bees")
		stingT -= delta
		if angry() && is_instance_valid(car) && car.global_position.distance_to(global_position) < 70.0 && stingT <= 0.0:
			stingT = Spill.STING_GAP
			car.damage(Spill.SWARM_STING)
		queue_redraw()

	## The raider first, then the nearest goon in reach, then the car if it broke the hive just now
	func pickTarget(car) -> Vector2:
		if is_instance_valid(first) && not first.dead: return first.global_position
		var at := Vector2.INF
		var best := Spill.SWARM_REACH * Spill.SWARM_REACH
		for goon in Spill.goonsNear(global_position, Spill.SWARM_REACH):
			if goon.get("dead"): continue
			var d: float = goon.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				at = goon.global_position
		if at == Vector2.INF && angry() && is_instance_valid(car) && car.global_position.distance_to(global_position) < 500.0: at = car.global_position
		return at

	func _draw() -> void:
		for i in DOTS:
			var s := seeds[i]
			var p := Vector2(sin(age * 6.0 * s.y + s.x) * 34.0, cos(age * 7.3 * s.y + s.x * 1.7) * 26.0)
			draw_circle(p, 2.6, Color(0.16, 0.13, 0.08, 0.9))
			draw_circle(p + Vector2(1.2, 0), 1.4, Color(0.88, 0.7, 0.24, 0.95))

#--- the crane --------------------------------------------------------------------------------------

## A hard ram on a crane drops its container off the jib's tip, once per crane (PropReactions calls it)
static func ramCrane(crane: Node2D, speed: float) -> void:
	if speed < DROP_SPEED || crane.get_meta(&"spilled", false): return
	var scene := productScene(&"container")
	var parent := crane.get_parent()
	if scene == null || parent == null: return
	crane.set_meta(&"spilled", true)
	markUsed(crane.global_position)
	var box: StaticBody2D = scene.instantiate()
	parent.add_child(Drop.new(box, crane.to_global(DROP_TIP), crane.global_rotation))
	if fx(): fx().label(crane.global_position, "LOOK OUT", 20)

## A container falling off the crane: it shrinks from jib height to the ground over DROP_SECONDS, then lands
## on whatever is under it and stays as a prop
class Drop extends Node2D:
	var box: StaticBody2D
	var age := 0.0

	func _init(node: StaticBody2D, at: Vector2, rot: float) -> void:
		box = node
		top_level = true
		z_as_relative = false
		z_index = PropReactions.CANOPY_Z
		global_position = at
		var shape: CollisionShape2D = box.get_node_or_null("CollisionShape2D")
		if shape: shape.disabled = true
		box.rotation = rot
		add_child(box)

	func _physics_process(delta: float) -> void:
		age += delta
		var t := minf(age / Spill.DROP_SECONDS, 1.0)
		box.scale = Vector2.ONE * (1.0 + 0.45 * (1.0 - t * t))
		if t >= 1.0: land()

	func land() -> void:
		set_physics_process(false)
		box.scale = Vector2.ONE
		for goon in Spill.goonsNear(global_position, Spill.DROP_BOX.size.length() * 0.5):
			if Spill.DROP_BOX.has_point(box.to_local(goon.global_position)): Spill.flatten(goon, global_position, &"crush", &"drop")
		var car = Root.playerCar
		if is_instance_valid(car) && Spill.DROP_BOX.grow(30.0).has_point(box.to_local(car.global_position)): car.damage(Spill.DROP_CAR_DAMAGE)
		var at := global_position
		var rot := box.global_rotation
		var tm := Spill.tileManager()
		var parent: Node = tm.objectsAt(at) if tm && tm.has_method("objectsAt") else null
		if parent == null: parent = get_parent()
		remove_child(box)
		parent.add_child(box)
		box.global_position = at
		box.global_rotation = rot
		var shape: CollisionShape2D = box.get_node_or_null("CollisionShape2D")
		if shape: shape.set_deferred("disabled", false)
		if PropReactions.current: PropReactions.current.puff(at, Vector2.RIGHT.rotated(rot), 1.0, true)
		Audio.play(Transition.SOUNDS["thud"], -2.0, 0.7)
		Spill.record(&"container", at, rot)
		queue_free()

#--- the Bandit den (R-6) ------------------------------------------------------------------------------

const DEN_GROUP := &"prop_den"
const DEN_REACH := 95.0   #px past a Bandit's body from the den's centre where it stashes (the hut's hull is ~75)
const SACKS_SHOWN := 3    #the den's sack overlay has frames 0-3
const STASH_META := &"denStash" #the TileManager's record: {den key: [{"scene": path}, ...]}

## A den's key in the record: its position, which a chunk rebuilds the same every time
static func denKey(den: Node2D) -> Vector2i:
	return Vector2i(den.global_position.round())

static func stashRecord() -> Dictionary:
	var tm := tileManager()
	if tm == null: return {}
	if not tm.has_meta(STASH_META): tm.set_meta(STASH_META, {})
	return tm.get_meta(STASH_META)

## What a den holds: [{"scene": path}, ...]
static func stashOf(den: Node2D) -> Array:
	return den.get_meta(&"stash", [])

## A Bandit got home: its loot goes into the den (and the record) and shows as sacks
static func stash(den: Node2D, loot: Array) -> void:
	if loot.is_empty() || den.get_meta(&"smashed", false): return
	var held: Array = stashOf(den).duplicate()
	held.append_array(loot)
	den.set_meta(&"stash", held)
	stashRecord()[denKey(den)] = held #without a TileManager (a test) the record is a throwaway
	showSacks(den)
	if fx(): fx().label(den.global_position, "STASHED", 18)

## A den streamed back in: what it held before its chunk went
static func loadStash(den: Node2D) -> void:
	var held: Array = stashRecord().get(denKey(den), [])
	den.set_meta(&"stash", held.duplicate())
	showSacks(den)

## The sack overlay: one sack per stashed thing, up to SACKS_SHOWN; hidden on a broken den
static func showSacks(den: Node2D) -> void:
	var sacks: Sprite2D = den.get_node_or_null("Sacks")
	if sacks == null: return
	sacks.visible = not den.get_meta(&"smashed", false)
	sacks.frame = clampi(stashOf(den).size(), 0, mini(SACKS_SHOWN, sacks.hframes - 1))

## The den was smashed: every stashed pickup bursts out along `dir` (its own coins come from COIN_SPILL)
static func releaseStash(den: Node2D, dir: Vector2) -> int:
	var held := stashOf(den)
	den.set_meta(&"stash", [])
	stashRecord().erase(denKey(den))
	showSacks(den)
	if held.is_empty() || fx() == null: return 0
	for i in held.size():
		var scene: String = held[i].get("scene", "")
		if scene == "": continue
		fx().dropAt(den.global_position + dir.rotated((i - (held.size() - 1) * 0.5) * 0.5) * 150.0, scene)
	fx().label(den.global_position, "LOOT RECOVERED" if held.size() == 1 else "LOOT RECOVERED x%d" % held.size(), 22, HudTheme.GOLD)
	return held.size()

#--- burrows and warrens (R-7) ----------------------------------------------------------------------------

const WARREN_GROUP := &"prop_warren" #every burrow, smashed or not (BreakableProp.tag), for the warren count
const BURROW_STUN := 1.5
const WARREN_COINS := 20
const WARREN_XP := 15.0

## A burrow caved in: its occupant is flushed out stunned; the last of a warren pays the warren bonus
static func collapseBurrow(burrow: Node2D) -> void:
	var o = occupant(burrow)
	if burrow.has_meta(&"occupant"): burrow.remove_meta(&"occupant")
	if o != null && not o.dead && o.verb is GoonVerbs.Hopper: o.verb.flush(BURROW_STUN)
	if warrenCleared(burrow): payWarren(burrow.global_position)

## The goon hiding in (or diving into) a burrow, or null
static func occupant(burrow: Node2D) -> Node2D:
	if not burrow.has_meta(&"occupant"): return null
	var o = burrow.get_meta(&"occupant")
	return o if is_instance_valid(o) else null

## Whether every burrow sharing this one's warren (`group` meta, 0 for none) is down
static func warrenCleared(burrow: Node2D) -> bool:
	var key: int = burrow.get_meta(&"group", 0)
	if key == 0 || not burrow.is_inside_tree(): return false
	for n in burrow.get_tree().get_nodes_in_group(WARREN_GROUP):
		if n != burrow && int(n.get_meta(&"group", 0)) == key && not n.get_meta(&"smashed", false): return false
	return true

## WARREN CLEARED: coins and crush XP to the player, credited now, when the car is near (CRITTER_CREDIT_PX)
static func payWarren(at: Vector2) -> bool:
	var car = Root.playerCar
	if not is_instance_valid(car) || car.global_position.distance_to(at) > SpawnManager.CRITTER_CREDIT_PX: return false
	car.reward("coin", WARREN_COINS)
	if car.get("isPlayer"): car.crushXp += WARREN_XP * car.crushXpMult
	RewardFlyers.flyUpgrade(Root.upgrade.PURSE, at)
	if fx(): fx().label(at, "WARREN CLEARED  +%d" % WARREN_COINS, 24, HudTheme.GOLD)
	return true

#--- the record ---------------------------------------------------------------------------------------

## A spilled prop came to rest: the chunk shows it there from now on (TileManager.addSpilled)
static func record(id: StringName, at: Vector2, rot: float) -> void:
	var tm := tileManager()
	if tm && tm.has_method("addSpilled"): tm.addSpilled(id, at, rot)

## A crane at `at` has dropped its container: it never drops another, even after its chunk reloads
static func markUsed(at: Vector2) -> void:
	var tm := tileManager()
	if tm && tm.has_method("markSpillUsed"): tm.markSpillUsed(at)
