class_name Spill extends RefCounted
## Interactive props (docs/WORLD.md "Interactive props"): props that let something loose when
## they go. One hook, `release`, called when a prop in DEFS breaks (BreakableProp.smashNode: the car at its
## smash speed, a goon cutting it loose, or a blast), plus the crane, which drops its container when rammed
## hard (PropReactions). What comes out by kind:
##   logs   the log pile: LOGS logs roll out along the release direction, flattening goons (crushes for the
##          player) and knocking the car, then lie where they stop as log props (Snapper spawns too). A log is a
##          wall while it rolls, and the car can roll any lying log on by hitting its side (kick).
##   wave   the water tower: a flood flattens the goons around it ("SPLASH")
##   fall   the billboard: it topples away from the car (its broken state is the board lying flat) and
##          flattens whatever is under it
##   swarm  the beehive: SWARM_KILLS big bees that fly straight at the nearest goons; each stings one flat and is gone
##          (SWARM_SECONDS at most); it stings the car that broke the hive only when no goon is in reach. Goons
##          never let the bees out (BreakableProp.GOON_PROOF): that is the player's call.
##   drop   the crane: its container falls off the jib's tip onto whatever is below, then stays as a prop
## Goons whose Goons.DATA "seeks" says so walk to a log pile near the car and cut it loose, aimed at the car
## (GoonVerbs.Verb.seekProp). What spilled is recorded per chunk on the TileManager (addSpilled), so a
## reloaded chunk shows the logs and containers where they came to rest and a crane drops only once.
## Every kill here goes through flatten with its source (logs, splash, fall, bees, drop), which SpawnManager.creditCrush
## credits to the player, Critter Chain included, when it happens within CRITTER_CREDIT_PX of the car.
## Roosts (ROOSTS): crowns Buzzards sit in (Goons.DATA seeks "roost"); a ram on the trunk (ram) knocks them down.
## Region 1 (The Wilds; docs/GOONS.md "Wild instincts"):
##   stash  the Bandit den: Bandits carry stolen loot home to it (stash); smashing it bursts every stashed
##          pickup out ("LOOT RECOVERED"). The stash outlives a chunk reload (a record on the TileManager).
##   burrow a Jackalope burrow caves in: the one hiding in it is thrown out stunned, it spawns no more, and when
##          every burrow of its warren (the `group` meta ChunkView sets from the motif) is down: WARREN CLEARED
##   logs   (again) the rock pile: a rockslide of ROCKS rolling boulders (rock_roll), credited as rocks
##   fall   (again) a hero saguaro (a short box and a ring of spines, SPINES) and the ranger tower (a long box)
##          topple away from whatever broke them
##   deadfall the leaning fallen trunk (its third variant) drops across the trail; the others just break
##   flood  the sluice gate: a flood capsule FLOOD_LENGTH long along the nearest channel flattens goons in the
##          shallows and on bridges (SPLASH)
##   splat  a pumpkin bursts (orange bits; it keeps the car's speed, BreakableProp.SPEED_KEEPS)
## The still and the TNT stack are explosives (BreakableProp.BLAST; the still leaves fire behind, BURNS). An
## orchard oak (levels whose rules have "oakCoins") drops that many coins on its first hard hit, once.
## Lures (R-10; through Pickups.lures): the Dinner Bell, rammed at BELL_RAM, calls every goon within BELL_LURE to
## it for BELL_SECONDS, once per bell; a Salt Lick is a permanent lure for heavies (rank 3) while its chunk is loaded.
## Farm gates (GATE_GROUP; "farm gates" below): half stand open from the start, each with a goon standing at
## it who shuts the gate on the car ("gatekeepers"). Goons also open and shut them on the move
## (Goons.DATA seeks "open" and "shut"). A bump too slow to smash a shut gate swings it open (pushGate). An open
## gate's gap is clear; its leaf, swung aside, is still solid.
## PropReactions.addHero calls arm() for every prop that streams in (and disarm() when its chunk goes), which
## restores per-prop state (a den's sacks, a rung bell, a gate standing open) and registers a salt lick's lure.

## Fall boxes: what lies under the fallen prop, prop-local px on its +y side (flipped when it falls the other way)
const FALL_BOX := Rect2(-195.0, 18.0, 390.0, 130.0)      #the billboard's board lying flat
const SAGUARO_BOX := Rect2(-70.0, 30.0, 140.0, 210.0)    #the fallen cactus (world_gen.js saguaro fallen state)
const TOWER_BOX := Rect2(-130.0, 60.0, 260.0, 360.0)     #the ranger tower's frame and cabin
const DEADFALL_BOX := Rect2(-240.0, -70.0, 480.0, 140.0) #the trunk dropping flat where it leaned (no flip)

const DEFS := {
	&"logpile": {"kind": "logs", "product": &"log", "count": 5, "source": &"logs", "label": "TIMBER!"},
	&"rockpile": {"kind": "logs", "product": &"rock_roll", "count": 4, "source": &"rocks", "label": "ROCKSLIDE!", "spin": true},
	&"watertower": {"kind": "wave"}, &"billboard": {"kind": "fall", "box": FALL_BOX, "damage": 8.0, "label": "FLATTENED"},
	&"saguaro": {"kind": "fall", "box": SAGUARO_BOX, "damage": 6.0, "spines": 150.0, "label": "TIMBER!"},
	&"ranger_tower": {"kind": "fall", "box": TOWER_BOX, "damage": 10.0, "label": "TIMBER!"},
	&"fallen_trunk": {"kind": "deadfall", "box": DEADFALL_BOX, "damage": 8.0, "label": "DEADFALL!"},
	&"beehive": {"kind": "swarm"}, &"crane": {"kind": "drop"},
	&"den": {"kind": "stash"}, &"burrow": {"kind": "burrow"},
	&"sluice": {"kind": "flood"}, &"pumpkin": {"kind": "splat"},
}
## Props a spill leaves behind: WorldSkin loads them with the level whenever the spilling prop is in its dressing
const PRODUCTS := {&"logpile": [&"log"], &"rockpile": [&"rock_roll"], &"crane": [&"container"]}
const PILE_GROUP := &"prop_logpile"
const SPILL_GROUP := &"prop_spill"

const LOGS := 5
const LOG_DISTANCE := Vector2(260.0, 560.0) #px each log rolls
const LOG_SPREAD := 0.55                    #radians either way of the release direction
const LOG_SECONDS := 1.1
const LOG_CRUSH := 64.0                     #px from a rolling log's center line that flattens a goon
const LOG_CAR_DAMAGE := 6.0
const WAVE_RADIUS := 340.0
const SPINE_RANK := 1                       #a saguaro's spines flatten fodder only
const SAGUARO_SMASH := 380.0                #a hero saguaro topples at 38 MPH (the scattered ones are scenery)
const FLOOD_LENGTH := 900.0                 #a sluice's flood capsule along the channel...
const FLOOD_RADIUS := 170.0                 #...and its half width
const OAK_SHAKE := 200.0                    #px/s into an orchard oak that shakes its apples down
const SWARM_SECONDS := 12.0
const SWARM_SPEED := 600.0                  #faster than any goon
const SWARM_TURN := 10.0                    #how fast it comes round to its target (share of the way per second)
const SWARM_REACH := 700.0                  #px it looks for goons
const SWARM_KILLS := 3                      #goons it flattens before it is gone
const SWARM_STING := 0.5                    #car damage per sting, every STING_GAP while it is on the car
const STING_GAP := 0.4
const STING_WINDOW := 3.0                   #s after the car broke a hive in which its swarm may sting the car
const SWARM_CAP := 3
const DROP_SPEED := 320.0                   #px/s into the crane that shakes the container loose
const DROP_TIP := Vector2(265.0, -16.0)     #the jib's tip, crane-local px (world_gen.js crane canopy)
const DROP_SECONDS := 0.7
const DROP_BOX := Rect2(-240.0, -94.0, 480.0, 188.0) #the container, container-local px
const DROP_CAR_DAMAGE := 10.0
## Goons that release piles: how close the car and the goon must be to try is in the "release" rows of Goons.DATA seeks
const REACH := 150.0                        #px from the pile's center where a goon can cut it loose
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
		"fall": fall(node, dir)
		"deadfall": deadfall(node, dir)
		"flood": flood(node)
		"splat": splat(node, dir)
		"swarm": swarm(node)
		"stash": releaseStash(node, dir)
		"burrow": collapseBurrow(node)

## A prop streamed in (PropReactions.addHero, from ChunkView): its per-prop state comes back
static func arm(prop: Node2D) -> void:
	match BreakableProp.propId(prop):
		&"den": loadStash(prop)
		&"bell", &"oak": prop.set_meta(&"spilled", isUsed(prop.global_position)) #rung or shaken once a run
		&"saguaro": armSaguaro(prop)
		&"fallen_trunk": prop.set_meta(&"deadfall", leans(prop))
		&"farmgate": armGate(prop)
		&"saltlick": Pickups.addLure(prop.global_position, SALT_LURE, INF, &"", SALT_RANK, SALT_LOOSE, prop.get_instance_id())

## Its chunk is going (PropReactions.forget): a salt lick's lure goes with it, a gate's waiting keeper too
static func disarm(prop: Node2D) -> void:
	match BreakableProp.propId(prop):
		&"saltlick": Pickups.removeLure(prop.get_instance_id())
		&"farmgate": dismissKeeper(prop)

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

## A goon cut a log pile loose: it spills toward the car
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
	if id == &"oak": shakeOak(prop, speed)

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

## A log pile (or a rock pile: a rockslide) lets its logs (boulders) roll out along `dir`
static func spillLogs(pile: Node2D, dir: Vector2) -> void:
	var def: Dictionary = DEFS.get(BreakableProp.propId(pile), {})
	var product: StringName = def.get("product", &"log")
	var count: int = def.get("count", LOGS)
	var scene := productScene(product)
	var parent := pile.get_parent()
	if scene == null || parent == null: return
	for i in count:
		var d := dir.rotated(lerpf(-LOG_SPREAD, LOG_SPREAD, (i + randf() * 0.6) / count))
		var piece: StaticBody2D = scene.instantiate()
		var roller := Roller.new(piece, pile.global_position + d * 40.0 + d.orthogonal() * randf_range(-60.0, 60.0), d, randf_range(LOG_DISTANCE.x, LOG_DISTANCE.y))
		roller.id = product
		roller.source = def.get("source", &"logs")
		roller.spin = def.get("spin", false)
		parent.add_child(roller)
	if fx(): fx().label(pile.global_position, def.get("label", "TIMBER!"))

## A log rolling out of a pile (or kicked on by the car): a log prop rolled side-on along `dir` and slowing (a
## boulder tumbles instead); goons in its path are flattened, the car is knocked once; when it stops it becomes a
## prop where it lies. It is a wall while it rolls, except to a car within LOG_GRACE of where it starts.
class Roller extends Node2D:
	var piece: StaticBody2D
	var dir: Vector2
	var distance: float
	var age := 0.0
	var from: Vector2
	var hitCar := false
	var id := &"log"        #the prop it settles as
	var source := &"logs"   #its kills' name in the Critter Chain
	var spin := false       #a boulder tumbles; a log rolls side-on
	var shape: CollisionShape2D

	## `rot`: the piece's own angle to keep (a kicked log); NAN turns it side-on to the roll
	func _init(node: StaticBody2D, at: Vector2, d: Vector2, dist: float, rot := NAN) -> void:
		piece = node
		dir = d
		distance = dist
		from = at
		top_level = true
		global_position = at
		shape = piece.get_node_or_null("CollisionShape2D")
		if shape: shape.disabled = true #until it is clear of the car
		piece.rotation = d.angle() + PI * 0.5 if is_nan(rot) else rot #rolls side-on
		add_child(piece)

	func _physics_process(delta: float) -> void:
		age += delta
		if shape && shape.disabled && (not is_instance_valid(Root.playerCar) || Root.playerCar.global_position.distance_to(global_position) > Spill.LOG_GRACE): shape.disabled = false
		var t := minf(age / Spill.LOG_SECONDS, 1.0)
		var along := distance * (1.0 - (1.0 - t) * (1.0 - t))
		global_position = from + dir * along
		var sprite: Node2D = piece.get_node_or_null("Sprite2D")
		if sprite && spin: sprite.rotation = along * 0.022 #a boulder tumbling over
		elif sprite: sprite.scale.y = 1.3333 * (1.0 + 0.08 * sin(along * 0.08)) #the bark turning over
		for goon in Spill.goonsNear(global_position, Spill.LOG_CRUSH + 140.0):
			var off: Vector2 = goon.global_position - global_position
			if absf(off.dot(dir)) < Spill.LOG_CRUSH && absf(off.dot(dir.orthogonal())) < 140.0: Spill.flatten(goon, global_position - dir * 40.0, &"crush", source)
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
		if shape: shape.set_deferred("disabled", false)
		Spill.record(id, at, rot)
		queue_free()

#--- kicking a log -------------------------------------------------------------------------------------

## Lying pieces the car can send rolling (a pile's logs once they settle, the world's own scattered logs, a
## rockslide's boulders), and their kills' name in the Critter Chain
const KICKS := {&"log": &"logs", &"rock_roll": &"rocks"}
const KICK_SPEED := 150.0  #px/s into a lying log, across its length, that sends it rolling
const KICK_SIDE := 0.5     #a log only rolls when the hit is at least this much across its length (0.5: within 60 degrees of square)
const KICK_CARRY := 1.1    #px it rolls per px/s of the hit, up to LOG_DISTANCE.y
const LOG_GRACE := 170.0   #a rolling log is no wall to the car until it is this far from it (it starts beside the car)

## The way a lying piece rolls when hit moving at `moving`, scaled by the speed that goes into the roll: a log
## rolls across its length, to the side the hit pushes it (ZERO for a hit on its end); a boulder goes any way
static func rollPush(piece: Node2D, moving: Vector2) -> Vector2:
	if BreakableProp.propId(piece) != &"log": return moving
	var across := piece.global_transform.y.normalized()
	var into := moving.dot(across)
	if absf(into) < moving.length() * KICK_SIDE: return Vector2.ZERO
	return across * into

## The car hit a lying log (or boulder) moving at `moving` (PropReactions.react, after the wall hit): pushed across
## its length at KICK_SPEED or more it rolls on, flattening goons like any rolling log, and the knock costs the
## player's car LOG_CAR_DAMAGE on top of the wall hit. Hit on its end it is a wall. True when it rolled.
static func kick(piece: Node2D, moving: Vector2) -> bool:
	var id := BreakableProp.propId(piece)
	var parent := piece.get_parent()
	if not KICKS.has(id) || parent == null || parent is Roller || not piece is StaticBody2D: return false
	var push := rollPush(piece, moving)
	var speed := push.length()
	if speed < KICK_SPEED: return false
	var at := piece.global_position
	var rot := piece.global_rotation
	leaveHome(piece, id, at)
	if PropReactions.current: PropReactions.current.forget(piece)
	parent.remove_child(piece)
	piece.position = Vector2.ZERO
	var roller := Roller.new(piece, at, push / speed, clampf(speed * KICK_CARRY, 120.0, LOG_DISTANCE.y), rot)
	roller.id = id
	roller.source = KICKS[id]
	roller.spin = id == &"rock_roll"
	roller.hitCar = true #it rolls away from the car that kicked it
	parent.add_child(roller)
	var car = Root.playerCar
	if is_instance_valid(car) && car.global_position.distance_to(at) < 260.0: car.damage(LOG_CAR_DAMAGE)
	return true

## A lying piece is about to roll off: a spilled one's record goes (it is recorded again where it stops); one
## of the world's own is marked gone from its chunk for the run (ChunkView.applyProp skips it) and its chunk
## lets go of the node, so it isn't pooled from wherever it ends up
static func leaveHome(piece: Node2D, id: StringName, at: Vector2) -> void:
	var tm := tileManager()
	if tm == null: return
	if tm.has_method("removeSpilled") && tm.removeSpilled(id, at): return
	if not BreakableProp.markTaken(piece): markUsed(at)
	if tm.has_method("disownProp"): tm.disownProp(piece)

#--- the water tower, the billboard, the beehive ------------------------------------------------------

static func wave(pos: Vector2) -> void:
	for goon in goonsNear(pos, WAVE_RADIUS):
		if WorldHooks.lineClear(pos, goon.global_position): flatten(goon, pos, &"boom", &"splash")
	if PropReactions.current: PropReactions.current.splash(pos, WAVE_RADIUS)
	if fx(): fx().label(pos, "SPLASH!", 24)

## A prop topples (the billboard, a hero saguaro, the ranger tower) away from what broke it: the car, or along
## `dir` when a charge or a blast did (spillDir). Its broken sprite (lying on its +y side) is flipped when it
## falls the other way, and whatever lies under its box is flattened. A deadfall drops flat where it leaned.
static func fall(prop: Node2D, dir := Vector2.ZERO) -> void:
	var def: Dictionary = DEFS.get(BreakableProp.propId(prop), {})
	var box: Rect2 = def.get("box", FALL_BOX)
	var car = Root.playerCar
	var side := 1.0
	if def.get("kind", "") == "deadfall": side = 1.0
	elif prop.has_meta(&"spillDir"): side = -1.0 if dir.dot(prop.global_transform.y) < 0.0 else 1.0
	elif is_instance_valid(car) && prop.to_local(car.global_position).y > 0.0: side = -1.0
	var sprite: Node2D = prop.get_node_or_null("Sprite2D")
	if sprite: sprite.scale.y = absf(sprite.scale.y) * side
	if side < 0.0: box = Rect2(box.position.x, -box.end.y, box.size.x, box.size.y)
	var center := prop.to_global(box.get_center())
	for goon in goonsNear(center, box.size.length() * 0.5 + 40.0):
		if box.has_point(prop.to_local(goon.global_position)): flatten(goon, prop.global_position, &"crush", &"fall")
	if is_instance_valid(car) && box.has_point(prop.to_local(car.global_position)): car.damage(float(def.get("damage", 8.0)))
	if def.has("spines"): spines(prop.to_global(Vector2(0.0, box.end.y if side > 0.0 else box.position.y)), def.spines)
	if PropReactions.current: PropReactions.current.puff(center, Vector2.from_angle(prop.global_rotation + PI * 0.5 * side), 1.0, true)
	if fx(): fx().label(prop.global_position, def.get("label", "FLATTENED"), 22)

## A ring of saguaro spines where the crown lands: fodder (rank SPINE_RANK or less) within `radius` is flattened
static func spines(at: Vector2, radius: float) -> void:
	for goon in goonsNear(at, radius):
		if not goon.dead && int(goon.def.get("rank", 1)) <= SPINE_RANK && WorldHooks.lineClear(at, goon.global_position): flatten(goon, at, &"boom", &"spines")
	if fx(): fx().ring(at, radius)

static func deadfall(trunk: Node2D, dir: Vector2) -> void:
	if isDeadfall(trunk): fall(trunk, dir)

static func splat(pumpkin: Node2D, dir: Vector2) -> void:
	if PropReactions.current: PropReactions.current.splatter(pumpkin.global_position, dir, PropReactions.PUMPKIN)

## The leaning fallen trunk (its third variant, fallen_trunk_v2) is the deadfall; the others just break. Read when
## it is armed (the smash swaps the sprite for the broken one).
static func isDeadfall(trunk: Node2D) -> bool:
	return trunk.get_meta(&"deadfall", false)

static func leans(trunk: Node2D) -> bool:
	var sprite: Sprite2D = trunk.get_node_or_null("Sprite2D")
	return sprite != null && sprite.texture != null && sprite.texture.resource_path.ends_with("_v2.png")

## Only hero-placed saguaros (the `hero` meta, or a taken-set bit) topple: they get the smash speed and their
## fallen and spine states (props.json "states"); the scattered ones stay scenery. A pooled one is put back.
static func armSaguaro(prop: Node2D) -> void:
	if prop.get_meta(&"smashed", false) && not prop.has_meta(&"worldSlot"): BreakableProp.unsmash(prop)
	var hero: bool = prop.get_meta(&"hero", false) || prop.has_meta(&"worldSlot")
	if not hero:
		for key in [&"smashSpeed", &"broken", &"debris"]:
			if prop.has_meta(key): prop.remove_meta(key)
		if prop.is_in_group(SPILL_GROUP): prop.remove_from_group(SPILL_GROUP)
		return
	var states: Dictionary = WorldSkin.loadManifest().get("saguaro", {}).get("states", {})
	prop.set_meta(&"smashSpeed", SAGUARO_SMASH)
	prop.set_meta(&"broken", states.get("fallen", ""))
	prop.set_meta(&"debris", states.get("chunks", ""))
	if not prop.is_in_group(SPILL_GROUP): prop.add_to_group(SPILL_GROUP)

#--- the sluice (a flood along the channel) -------------------------------------------------------------

## The sluice gate burst: a flood runs FLOOD_LENGTH along the nearest channel, flattening goons wading in the
## shallows or on bridges within FLOOD_RADIUS of its line. Returns how many.
static func flood(sluice: Node2D) -> int:
	var at := sluice.global_position
	var axis := channelAxis(at, sluice.global_transform.x.normalized())
	var a := at - axis * FLOOD_LENGTH * 0.5
	var b := at + axis * FLOOD_LENGTH * 0.5
	var n := 0
	for goon in goonsNear(at, FLOOD_LENGTH * 0.5 + FLOOD_RADIUS):
		var p: Vector2 = goon.global_position
		var on := Geometry2D.get_closest_point_to_segment(p, a, b)
		if on.distance_to(p) > FLOOD_RADIUS || not wetAt(p): continue
		flatten(goon, on, &"boom", &"splash")
		n += 1
	if PropReactions.current:
		for k in 3: PropReactions.current.splash(a.lerp(b, k * 0.5), FLOOD_RADIUS)
	if fx(): fx().label(at, "FLOOD!" if n == 0 else "SPLASH x%d" % n, 24)
	return n

## Wading water a flood sweeps: the shallows and bridge decks
static func wetAt(p: Vector2) -> bool:
	var t := World.terrainAt(p)
	return t == Root.terrain.SHALLOWS || t == Root.terrain.BRIDGE

## The channel's direction at `at`: of 8 directions, the one with the most water, shallows and bridge along it
## (5 samples each way, 100 px apart); `fallback` when there is none (no map)
static func channelAxis(at: Vector2, fallback: Vector2) -> Vector2:
	var best := fallback
	var bestN := 0
	for k in 8:
		var d := Vector2.from_angle(k * PI / 8.0)
		var count := 0
		for j in range(1, 6):
			for s in [-1.0, 1.0]:
				var t := World.terrainAt(at + d * s * j * 100.0)
				if t == Root.terrain.WATER || t == Root.terrain.SHALLOWS || t == Root.terrain.BRIDGE: count += 1
		if count > bestN:
			bestN = count
			best = d
	return best

#--- the orchard oak ------------------------------------------------------------------------------------

## Coins an orchard oak drops on its first hard hit: the level's rules "oakCoins" (0: none)
static func oakCoins() -> int:
	var def := Levels.current()
	return int(def.rules.get("oakCoins", 0)) if def else 0

## A hard hit on an orchard oak shakes its apples down: coins, once per tree. True when it did.
static func shakeOak(oak: Node2D, speed: float) -> bool:
	if speed < OAK_SHAKE || oak.get_meta(&"spilled", false): return false
	var n := oakCoins()
	if n <= 0: return false
	oak.set_meta(&"spilled", true)
	markUsed(oak.global_position)
	BreakableProp.throwCoins(n, oak.global_position, Vector2.from_angle(randf() * TAU))
	if fx(): fx().label(oak.global_position, "APPLES!", 20, HudTheme.GOLD)
	return true

## Live swarms, oldest first: at most SWARM_CAP (each scans the goons every tick); a new one sends the oldest off
static var swarms: Array = []

static func swarm(hive: Node2D) -> void:
	var parent := hive.get_parent()
	if parent == null: return
	swarms = swarms.filter(func(s): return is_instance_valid(s) && not s.is_queued_for_deletion() && not s.leaving())
	while swarms.size() >= SWARM_CAP: swarms.pop_front().disperse()
	var s := Swarm.new(hive.global_position)
	#it stings the car only if the car broke this hive just now (STING_WINDOW)
	s.stingUntil = float(hive.get_meta(&"carBrokeAt", -INF)) + STING_WINDOW
	parent.add_child(s)
	swarms.push_back(s)
	if fx(): fx().label(hive.global_position, "BEES!", 22)

## The bees out of a smashed hive, SWARM_KILLS of them, drawn big enough to read: from its first tick the swarm
## flies fast at the nearest goon within SWARM_REACH. Each goon it reaches costs one bee its sting (three bees, then
## two, then one); with none left (or after SWARM_SECONDS) it is gone. With no goon in reach it goes for the car,
## and stings it while on it, only when the car broke the hive in the last STING_WINDOW s.
class Swarm extends Node2D:
	const ORBIT := 30.0     #px each bee circles from the swarm's center
	const BEE_SCALE := 1.25 #a bee is about 45 px long
	const DARK := Color(0.13, 0.1, 0.07)
	const YELLOW := Color(0.98, 0.78, 0.16)
	const WING := Color(0.93, 0.97, 1.0, 0.8)
	const LOOK_EVERY := 3 #ticks between target searches
	var age := 0.0
	var kills := 0
	var stingT := 0.0
	var stingUntil := -INF #GoonVerbs.now() seconds
	var vel := Vector2.ZERO
	var target := Vector2.INF
	var looked := false #it picks a target on its first tick, then every LOOK_EVERY
	var seeds := PackedVector2Array()

	func _init(at: Vector2) -> void:
		top_level = true
		z_as_relative = false
		z_index = PropReactions.BITS_Z
		global_position = at
		for i in Spill.SWARM_KILLS: seeds.push_back(Vector2(randf() * TAU, randf_range(0.85, 1.15)))

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
		if not looked || (Engine.get_physics_frames() + get_instance_id()) % LOOK_EVERY == 0:
			looked = true
			target = pickTarget(car)
		var want := (target - global_position).normalized() * Spill.SWARM_SPEED if target != Vector2.INF else Vector2.ZERO
		vel = vel.lerp(want, minf(Spill.SWARM_TURN * delta, 1.0))
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

	## The nearest goon in reach, else the car if it broke the hive just now
	func pickTarget(car) -> Vector2:
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

	## The bees still to sting
	func bees() -> int:
		return maxi(Spill.SWARM_KILLS - kills, 0)

	## Each bee circles the swarm's center, nose along the way it flies
	func _draw() -> void:
		var heading := vel.angle() if vel.length() > 20.0 else 0.0
		for i in bees():
			var s := seeds[i]
			var a := age * 5.0 * s.y + s.x + i * TAU / Spill.SWARM_KILLS
			var p := Vector2(cos(a), sin(a) * 0.8) * ORBIT
			drawBee(p, heading + sin(age * 9.0 + s.x) * 0.35, age * 60.0 + s.x)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## One bee, nose along +x: a dark outline, a striped yellow body, a stinger and two beating wings
	func drawBee(at: Vector2, rot: float, beat: float) -> void:
		draw_set_transform(at, rot, Vector2.ONE * BEE_SCALE)
		for part in [[Vector2(-9.0, 0.0), 9.5], [Vector2(1.0, 0.0), 8.5], [Vector2(10.0, 0.0), 6.5]]: draw_circle(part[0], part[1], DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(-16.0, -3.5), Vector2(-25.0, 0.0), Vector2(-16.0, 3.5)]), DARK)
		draw_circle(Vector2(-9.0, 0.0), 7.5, YELLOW)
		draw_circle(Vector2(1.0, 0.0), 6.5, YELLOW)
		draw_circle(Vector2(10.0, 0.0), 4.5, DARK)
		for x in [-12.0, -6.5]: draw_line(Vector2(x, -6.5), Vector2(x, 6.5), DARK, 3.0)
		var flap := 0.75 + 0.25 * sin(beat)
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(-1.0, side * 11.0 * flap), 7.5, Color(DARK, 0.35))
			draw_circle(Vector2(-1.0, side * 11.0 * flap), 6.5, WING)

#--- farm gates -------------------------------------------------------------------------------------

const GATE_GROUP := &"prop_gate"
const GATE_HINGE := Vector2(-158.0, 0.0) #the hinge post, gate-local px (world_gen.js farmgate)
const GATE_SWING := 1.4                  #radians an open gate stands at, about its hinge
const GATE_SECONDS := 0.3                #its swing
const GATE_REACH := 190.0                #px past a goon's body from the gate's center where it can work it
const GATE_CLEAR := 230.0                #a gate never shuts on a car this close to it
const GATE_AHEAD := 1200.0               #a goon shuts a gate the car is heading at from within this...
const GATE_CAR_SPEED := 120.0            #...at this speed or more
const GATE_OPEN_SHARE := 0.5             #the share of gates that stand open when they stream in
const GATE_PUSH := 40.0                  #px/s: a bump this fast, under its smash speed, swings a shut gate open
const GATE_TAG := 0x6A7E

static func isOpen(gate: Node2D) -> bool:
	return gate.get_meta(&"open", false)

## Whether the gate at `at` stands open when it streams in: by its place, so the same every time. What goons do
## to a gate lasts until its chunk goes.
static func gateStartsOpen(at: Vector2) -> bool:
	return WorldGen.hashf(0, GATE_TAG, roundi(at.x), roundi(at.y)) < GATE_OPEN_SHARE

## Opens or shuts a gate: the leaf swings aside on its hinge, to its +y side or (`side` -1) the other, and the
## gap is clear. The leaf is as solid and as breakable open as shut: its shape swings with it, at once, while the
## sprite takes GATE_SECONDS. `instant` skips the swing (a gate streaming in).
static func setGate(gate: Node2D, open: bool, instant := false, side := 1.0) -> void:
	if gate.get_meta(&"smashed", false) || (isOpen(gate) == open && not instant): return
	gate.set_meta(&"open", open)
	gate.set_meta(&"swingSide", side)
	var to := GATE_SWING * side if open else 0.0
	for child in gate.get_children():
		if child is CollisionShape2D || child is CollisionPolygon2D || child is LightOccluder2D:
			child.set_deferred("rotation", to)
			child.set_deferred("position", GATE_HINGE - GATE_HINGE.rotated(to))
	var sprite: Node2D = gate.get_node_or_null("Sprite2D")
	if sprite == null: return
	if PropReactions.current: PropReactions.current.rest(gate) #a wobble would put the leaf back where it was
	if sprite.has_meta(&"swing") && is_instance_valid(sprite.get_meta(&"swing")): sprite.get_meta(&"swing").kill()
	if instant || not gate.is_inside_tree():
		swingGate(to, sprite)
		return
	var tween := sprite.create_tween()
	tween.tween_method(swingGate.bind(sprite), sprite.rotation, to, GATE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sprite.set_meta(&"swing", tween)

## The leaf at `angle`, turned about its hinge post
static func swingGate(angle: float, sprite: Node2D) -> void:
	sprite.rotation = angle
	sprite.position = GATE_HINGE - GATE_HINGE.rotated(angle)

## Whether `a` and `b` are on opposite sides of the gate's line
static func acrossGate(gate: Node2D, a: Vector2, b: Vector2) -> bool:
	return gate.to_local(a).y * gate.to_local(b).y < 0.0

## The gate a goon at `from` would work now (Goons.DATA seeks "open" and "shut"), or null: to open, the nearest
## shut one within `reach` that stands between it and the car; to shut, the nearest open one the car is heading at
static func gateFor(tree: SceneTree, group: StringName, action: StringName, from: Vector2, car: Node2D, reach: float) -> Node2D:
	if tree == null || not is_instance_valid(car): return null
	var best: Node2D = null
	var bestD := reach * reach
	for gate in tree.get_nodes_in_group(group):
		if not gate is Node2D || not gate.is_inside_tree() || gate.get_meta(&"smashed", false): continue
		var d: float = gate.global_position.distance_squared_to(from)
		if d >= bestD: continue
		if action == &"open" && (isOpen(gate) || not acrossGate(gate, from, car.global_position)): continue
		if action == &"shut" && (not isOpen(gate) || not carHeadingAt(gate, car)): continue
		bestD = d
		best = gate
	return best

## The car is coming at the gate from within `ahead`, and is not yet in the gap
static func carHeadingAt(gate: Node2D, car: Node2D, ahead := GATE_AHEAD) -> bool:
	return car.global_position.distance_to(gate.global_position) > GATE_CLEAR && GoonVerbs.bearingDown(car, gate.global_position, ahead, GATE_CAR_SPEED)

## The car bumped a shut gate too slowly to smash it (PropReactions.knocks, before the wall hit): at GATE_PUSH
## or more it swings open away from the car, which keeps its speed. True when it did.
static func pushGate(gate: Object, moving: Vector2) -> bool:
	if not gate is Node2D || BreakableProp.propId(gate) != &"farmgate" || moving.length() < GATE_PUSH: return false
	if gate.get_meta(&"smashed", false) || isOpen(gate): return false
	setGate(gate, true, false, -1.0 if gate.to_local(gate.global_position - moving).y > 0.0 else 1.0)
	Audio.play(Transition.SOUNDS["rattle"], -8.0, 0.8)
	return true

#--- gatekeepers ---------------------------------------------------------------------------------------
## Every kept gate (gateKept, by its place) that streams in open gets a goon standing at it (postKeeper: the
## first goon of the level's line-up whose Goons.DATA says "keeps"), in the state &"keep": it waits there and
## slams the gate shut when the car heads for it from within KEEP_AHEAD (GoonVerbs.Verb.keepGate). A waiting
## keeper goes with its gate's chunk (disarm) and is never swept up as a straggler (SpawnManager.despawnSweep);
## once it has done its job the gate gets no other this run (markUsed).

const KEEP_STATE := &"keep"
const KEEP_AHEAD := 800.0    #px: the car this close and heading at the gate, and the keeper shuts it
const KEEP_WAKE := 220.0     #a car this close to the keeper itself and it gives the gate up and comes for the car
const GATE_KEPT_SHARE := 1.0 #the share of open gates that get a keeper
const KEEP_TAG := 0x6A7F

static func gateKept(at: Vector2) -> bool:
	return WorldGen.hashf(0, KEEP_TAG, roundi(at.x), roundi(at.y)) < GATE_KEPT_SHARE

## The goon keeping a gate, or null
static func keeperOf(gate: Node2D) -> Node2D:
	var k = gate.get_meta(&"keeper", null)
	return k if is_instance_valid(k) && not k.get("dead") else null

## Where a gate's keeper stands: by the latch post, on the side the open leaf isn't
static func keeperSpot(gate: Node2D) -> Vector2:
	return gate.to_global(Vector2(-GATE_HINGE.x, -80.0 * float(gate.get_meta(&"swingSide", 1.0))))

## The goon that keeps this level's gates: the first of its line-up that "keeps" (&"" for none)
static func keeperId() -> StringName:
	var def := Levels.current()
	for id in (def.lineup if def else []):
		if Goons.DATA.get(id, {}).get("keeps", false): return id
	return &""

## A gate streamed in (arm): it stands open or shut by its place, and a kept open one gets its keeper
static func armGate(gate: Node2D) -> void:
	var at := gate.global_position
	setGate(gate, gateStartsOpen(at), true)
	if isOpen(gate) && gateKept(at) && not isUsed(at): postKeeper(gate, keeperId())

## Stands a goon of `id` at an open gate as its keeper; null when it can't (no such goon, the goon cap)
static func postKeeper(gate: Node2D, id: StringName) -> Node2D:
	var sm = Root.spawnManager
	if id == &"" || not is_instance_valid(sm) || not is_instance_valid(Root.levelRoot) || not sm.canSpawn() || keeperOf(gate) != null: return null
	var goon: Node2D = sm.makeGoon(id)
	goon.position = keeperSpot(gate)
	goon.set_meta(&"spawnState", KEEP_STATE) #Walker._ready starts it there
	goon.set_meta(&"gate", gate)
	gate.set_meta(&"keeper", goon)
	sm.registerGoon(goon)
	Root.levelRoot.add_child(goon)
	return goon

## Its gate's chunk is going: a keeper still waiting goes with it
static func dismissKeeper(gate: Node2D) -> void:
	var k := keeperOf(gate)
	if k != null && k.get("state") == KEEP_STATE: k.queue_free()

## A goon at the gate works it. It never shuts one on a car in the gap (GATE_CLEAR). True when the gate moved.
static func goonGate(gate: Node2D, open: bool, car: Node2D) -> bool:
	if gate.get_meta(&"smashed", false) || isOpen(gate) == open: return false
	if not open && is_instance_valid(car) && car.global_position.distance_to(gate.global_position) <= GATE_CLEAR: return false
	setGate(gate, open, false, -1.0 if is_instance_valid(car) && gate.to_local(car.global_position).y > 0.0 else 1.0) #it swings away from the car
	Audio.play(Transition.SOUNDS["rattle" if open else "clank"], -8.0, 0.8)
	if fx(): fx().label(gate.global_position, "GATE OPEN" if open else "GATE SHUT", 18)
	return true

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
const DEN_REACH := 95.0   #px past a Bandit's body from the den's center where it stashes (the hut's hull is ~75)
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
