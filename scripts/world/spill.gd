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
## Goons with "releases" in Goons.DATA walk to a log pile near the car and cut it loose, aimed at the car
## (GoonVerbs.Verb.seekRelease). What spilled is recorded per chunk on the TileManager (addSpilled), so a
## reloaded chunk shows the logs and containers where they came to rest and a crane drops only once.

const DEFS := {
	&"logpile": {"kind": "logs"}, &"watertower": {"kind": "wave"}, &"billboard": {"kind": "fall"},
	&"beehive": {"kind": "swarm"}, &"crane": {"kind": "drop"},
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
const SWARM_STING := 1.5                    #car damage per sting, every STING_GAP while it is on the car
const STING_GAP := 0.4
const DROP_SPEED := 320.0                   #px/s into the crane that shakes the container loose
const DROP_TIP := Vector2(265.0, -16.0)     #the jib's tip, crane-local px (world_gen.js crane canopy)
const DROP_SECONDS := 0.7
const DROP_BOX := Rect2(-240.0, -94.0, 480.0, 188.0) #the container, container-local px
const DROP_CAR_DAMAGE := 10.0
## Goons with "releases": the car must be this close to the pile, the goon this close to it, to try
const LURE_CAR := 900.0
const LURE_GOON := 650.0
const REACH := 150.0                        #px from the pile's centre where a goon can cut it loose

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

## Kills a goon with crush credit (a spill counts as the player's, like a blast)
static func flatten(goon: Node2D, from: Vector2, cause: StringName = &"crush") -> void:
	if goon.get("dead"): return
	goon.set("killedFrom", from)
	goon.destroy(cause)
	if is_instance_valid(Root.spawnManager): Root.spawnManager.creditCrush(goon.global_position, goon)

static func goonsNear(pos: Vector2, radius: float) -> Array:
	return Root.spawnManager.goonsNear(pos, radius) if is_instance_valid(Root.spawnManager) else []

## A goon cut a log pile loose: it spills toward the car
static func goonRelease(pile: Node2D, goon: Node2D, car: Node2D) -> void:
	if pile.get_meta(&"smashed", false): return
	var to: Vector2 = (car.global_position - pile.global_position) if is_instance_valid(car) else Vector2.ZERO
	pile.set_meta(&"spillDir", to)
	BreakableProp.smashNode(pile, null)
	if fx(): fx().label(goon.global_position, "TIMBER!")

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
			if absf(off.dot(dir)) < Spill.LOG_CRUSH && absf(off.dot(dir.orthogonal())) < 140.0: Spill.flatten(goon, global_position - dir * 40.0)
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
		if WorldHooks.lineClear(pos, goon.global_position): flatten(goon, pos, &"boom")
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
		if box.has_point(board.to_local(goon.global_position)): flatten(goon, board.global_position)
	if is_instance_valid(car) && box.has_point(board.to_local(car.global_position)): car.damage(FALL_CAR_DAMAGE)
	if PropReactions.current: PropReactions.current.puff(board.to_global(box.get_center()), Vector2.from_angle(board.global_rotation + PI * 0.5 * side), 1.0, true)
	if fx(): fx().label(board.global_position, "FLATTENED", 22)

static func swarm(hive: Node2D) -> void:
	var parent := hive.get_parent()
	if parent == null: return
	var s := Swarm.new(hive.global_position)
	parent.add_child(s)
	if fx(): fx().label(hive.global_position, "BEES!", 22)

## A cloud of bees out of a smashed hive: it flies at the nearest goon within SWARM_REACH and flattens what it
## reaches (SWARM_KILLS at most), stings the car while it is on it, and disperses after SWARM_SECONDS
class Swarm extends Node2D:
	const DOTS := 26
	var age := 0.0
	var kills := 0
	var stingT := 0.0
	var vel := Vector2.ZERO
	var seeds := PackedVector2Array()

	func _init(at: Vector2) -> void:
		top_level = true
		z_as_relative = false
		z_index = PropReactions.BITS_Z
		global_position = at
		for i in DOTS: seeds.push_back(Vector2(randf() * TAU, randf_range(0.6, 1.8)))

	func _physics_process(delta: float) -> void:
		age += delta
		if age >= Spill.SWARM_SECONDS || kills >= Spill.SWARM_KILLS:
			modulate.a -= delta * 2.0
			if modulate.a <= 0.0: queue_free()
			queue_redraw()
			return
		var target := Vector2.INF
		var best := Spill.SWARM_REACH * Spill.SWARM_REACH
		for goon in Spill.goonsNear(global_position, Spill.SWARM_REACH):
			if goon.get("dead"): continue
			var d: float = goon.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				target = goon.global_position
		var car = Root.playerCar
		if target == Vector2.INF && is_instance_valid(car) && car.global_position.distance_to(global_position) < 500.0: target = car.global_position
		var want := (target - global_position).normalized() * Spill.SWARM_SPEED if target != Vector2.INF else Vector2.ZERO
		vel = vel.lerp(want, minf(4.0 * delta, 1.0))
		global_position += vel * delta
		for goon in Spill.goonsNear(global_position, 40.0):
			if not goon.get("dead") && kills < Spill.SWARM_KILLS:
				kills += 1
				Spill.flatten(goon, global_position)
		stingT -= delta
		if is_instance_valid(car) && car.global_position.distance_to(global_position) < 70.0 && stingT <= 0.0:
			stingT = Spill.STING_GAP
			car.damage(Spill.SWARM_STING)
		queue_redraw()

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
			if Spill.DROP_BOX.has_point(box.to_local(goon.global_position)): Spill.flatten(goon, global_position)
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

#--- the record ---------------------------------------------------------------------------------------

## A spilled prop came to rest: the chunk shows it there from now on (TileManager.addSpilled)
static func record(id: StringName, at: Vector2, rot: float) -> void:
	var tm := tileManager()
	if tm && tm.has_method("addSpilled"): tm.addSpilled(id, at, rot)

## A crane at `at` has dropped its container: it never drops another, even after its chunk reloads
static func markUsed(at: Vector2) -> void:
	var tm := tileManager()
	if tm && tm.has_method("markSpillUsed"): tm.markSpillUsed(at)
