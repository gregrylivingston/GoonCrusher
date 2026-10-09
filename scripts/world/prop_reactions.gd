class_name PropReactions extends Node2D
## How props answer the car (package 14, docs/WORLD.md "Prop reactions"). One per run, made by the TileManager;
## show only, apart from knocking cones over (they stop being walls).
##   - Canopies: a layered prop (trees, the crane's jib; docs/WORLD_ART.md "Layered props") draws its canopy
##     above the car and goons (CANOPY_Z). It fades to FADE_ALPHA while the player's car is under it, so the
##     player can see the car; it never fades for goons, so a crown can hide goons beneath it (by choice).
##   - Hits: the car's wall hits on a prop (overhead_car_body_2d.gd collideWithFixedObject) call hit(). The prop
##     answers by its id (REACT): a tree's canopy shakes and drops leaves (snow on snowy levels), bushes and
##     bales squash and spring back, signs and pumps wobble, sheds, tents and crates shake, rocks only thud and
##     dust, a hydrant sprays. A cone (or a mailbox) hit at KNOCK_SPEED flies off and stops being a wall until its chunk reloads.
##   - Blasts (BreakableProp.blastAt) shake the canopies in their radius.
## Everything is a damped spring on the prop's sprite (no tweens), and the bits are pooled particles drawn by two
## nodes. Driving Effects (gfx/driving_fx) sizes the particles (none at Minimal); Reduce Motion calms the springs.
## Pooled props are reset when ChunkView reuses them (reset) and forgotten when their chunk goes (forget).

const CANOPY_Z := 8 #over goons (up to 6) and the car; under the station roof (20) and the HUD
const BITS_Z := 9
const DUST_Z := 5
const FADE_ALPHA := 0.4
const FADE_RATE := 5.0     #alpha per second toward the target
const UNDER_PAD := 34.0    #world px the car may be outside a canopy's shape and still count as under it
const SQUARE_CANOPIES := [&"crane"] #canopy shapes tested as their box; the rest as the ellipse inside it

enum { NONE, CANOPY, SWAY, SHAKE, THUD, SQUASH, WOBBLE, KNOCK, SPRAY }
## What each prop does when the car hits it. Breakables only react below their smash speed (above it they smash).
const REACT := {
	&"oak": CANOPY, &"pine": CANOPY, &"cypress": CANOPY, &"deadtree": CANOPY, &"crane": CANOPY,
	&"saguaro": SWAY, &"totem": SWAY, &"billboard": SWAY, &"busstop": SWAY,
	&"sign": WOBBLE, &"gaspump": WOBBLE, &"fence": WOBBLE, &"barrel": WOBBLE, &"dumpster": WOBBLE,
	&"shack": SHAKE, &"tent": SHAKE, &"cabin": SHAKE, &"container": SHAKE, &"snowcat": SHAKE, &"scrapheap": SHAKE,
	&"crate": SHAKE, &"barricade": SHAKE, &"fortwall": SHAKE, &"jersey": SHAKE, &"wreck": SHAKE, &"firepit": SHAKE,
	&"tank": SHAKE, &"landmark_wild": SHAKE, &"landmark_tribe": SHAKE, &"landmark_scrap": SHAKE,
	&"rock": THUD, &"boulder": THUD, &"rock_white": THUD, &"rock_ice": THUD, &"rock_red": THUD, &"boulder_red": THUD,
	&"stump": THUD, &"log": THUD, &"carcass": THUD,
	&"hedge": SQUASH, &"haybale": SQUASH, &"tyres": SQUASH,
	&"cone": KNOCK, &"hydrant": SPRAY,
	&"logpile": SHAKE, &"watertower": SWAY, &"beehive": WOBBLE,
	#Road Atlas props (docs/WORLD_ART.md)
	&"pine_snow": CANOPY, &"palm": CANOPY,
	&"ranger_tower": SWAY, &"lifeguard_tower": SWAY, &"hunting_stand": SWAY, &"swingset": SWAY,
	&"mile_marker": WOBBLE,
	&"beach_hut": SHAKE, &"wagon": SHAKE, &"water_trough": SHAKE,
	&"landmark_big": SHAKE, &"landmark_swarm": SHAKE, &"landmark_war": SHAKE,
	&"fallen_trunk": THUD, &"salt_mound": THUD, &"rock_black": THUD,
	&"trampoline": SQUASH, &"trashbags": SQUASH,
	&"mailbox": KNOCK,
	#Region 1 (The Wilds) props
	&"bell": SWAY, &"scarecrow": SWAY,
	&"farmgate": WOBBLE, &"still": WOBBLE, &"tnt": WOBBLE,
	&"den": SHAKE, &"honeyshed": SHAKE, &"sluice": SHAKE,
	&"rockpile": THUD, &"rock_roll": THUD, &"saltlick": THUD,
	&"burrow": SQUASH, &"pumpkin": SQUASH,
}
const MIN_SPEED := 60.0    #px/s into the prop before anything reacts
const FULL_SPEED := 520.0  #...and for the full reaction
## Per kind: [amplitude at full speed, frequency Hz, decay per second]. Amplitude is radians for SWAY and
## WOBBLE, world px for SHAKE and CANOPY, a share of the scale for SQUASH.
const SPRING := {
	CANOPY: [9.0, 3.2, 3.2], SWAY: [0.05, 2.6, 3.0], WOBBLE: [0.2, 3.6, 3.4], SHAKE: [3.5, 14.0, 7.0],
	SQUASH: [0.16, 4.0, 4.5], SPRAY: [0.12, 4.0, 3.5],
}
const CANOPY_TILT := 0.035 #radians a canopy turns at full shake
const SETTLE := 0.03       #a spring this small is put back at rest
const LEAVES := Vector2i(3, 12)   #bits a tree drops on a soft and a hard hit (Driving Effects Full)
const BLAST_LEAVES := 6
const BIT_SECONDS := 1.5
const BIT_POOL := 72
const DUST := Color(0.72, 0.64, 0.52, 0.5)
const SNOW_DUST := Color(0.94, 0.96, 1.0, 0.65)
const WATER := Color(0.72, 0.84, 0.95, 0.75)
const SPRAY_SECONDS := 2.2
const SPRAY_RATE := 70.0   #droplets a second at Full
const KNOCK_SPEED := 120.0 #a cone hit this fast flies off...
const KNOCK_KEEP := 0.96   #...and the car keeps this share of its speed
const KNOCK_DISTANCE := Vector2(140.0, 230.0)
const KNOCK_SECONDS := 0.45
const PARTICLE_SCALE := [0.0, 0.5, 1.0] #by Driving Effects
const NEAR_SMASH := 0.7    #a breakable hit at this share of its smash speed or more cracks...
const CHIPS := Vector2(2.0, 5.0) #...and throws this many chips (at NEAR_SMASH, and just under the smash speed)
const CRACK_DB := -6.0

static var current: PropReactions

var snowy := false     #a snowy landscape's level (Landscape.snowy): snow dust, pines drop snow
var leafTextures := {}  #prop id -> the baked leaves strip (a row of 4 square cells)
var canopies: Array = [] #[prop root, canopy Sprite2D, local Rect2, square, reach (world px)]
var springs: Array = []  #[target Node2D, kind, age, amplitude, local direction, rest position, rest rotation, rest scale, prop root]
var sprays: Array = []   #[world position, seconds left]
var flights: Array = []  #[sprite, from, to, spin, age] knocked cones in the air
var bits: Bits
var dust: CarJuice.Particles
var tags: SmashTags #hero props and their MPH smash tags (R-12)
var particleScale := 1.0
var calm := false

func _init(snowyLevel := false, leaves := {}) -> void:
	snowy = snowyLevel
	leafTextures = leaves
	name = "PropReactions"
	process_mode = Node.PROCESS_MODE_PAUSABLE #the TileManager always runs; reactions stop with the game

func _ready() -> void:
	current = self
	bits = Bits.new()
	bits.resize(BIT_POOL)
	add_child(bits)
	dust = CarJuice.Particles.new(false, DUST_Z)
	dust.resize(96)
	add_child(dust)
	tags = SmashTags.new()
	add_child(tags)
	readSettings()
	Settings.changed.connect(onSettingChanged)

func _exit_tree() -> void:
	if current == self: current = null
	RenderingServer.global_shader_parameter_set("gc_car_pos", FAR)

func onSettingChanged(key: String, _value) -> void:
	if key in ["gfx/driving_fx", "access/reduce_motion"]: readSettings()

func readSettings() -> void:
	particleScale = PARTICLE_SCALE[clampi(int(Settings.get_value("gfx/driving_fx")), 0, PARTICLE_SCALE.size() - 1)]
	calm = Settings.reduce_motion()

#--- canopies ---------------------------------------------------------------------------------------

## A layered prop joined the world (ChunkView): its canopy now fades over the car
func addCanopy(prop: Node2D, canopy: Sprite2D) -> void:
	var rect := Rect2(-64, -64, 128, 128)
	if canopy.texture:
		var used: Rect2 = canopyRect(canopy.texture)
		rect = Rect2(used.position - canopy.texture.get_size() * 0.5, used.size)
	var reach := maxf(absf(rect.position.x), absf(rect.end.x)) * canopy.scale.x
	reach = maxf(reach, maxf(absf(rect.position.y), absf(rect.end.y)) * canopy.scale.y)
	canopy.modulate.a = 1.0
	canopies.push_back([prop, canopy, rect, BreakableProp.propId(prop) in SQUARE_CANOPIES, reach])

## A prop joined the world (ChunkView): its per-prop state comes back (Spill.arm: a den's stash...) and an
## interactive one (SmashTags.HEROES) gets a smash tag
func addHero(prop: Node2D) -> void:
	Spill.arm(prop)
	if is_instance_valid(tags): tags.add(prop)

static var rectCache := {} #texture path -> its opaque rect in texels
## The opaque part of a canopy texture (texels), once per texture; the whole texture without image data
static func canopyRect(tex: Texture2D) -> Rect2:
	var key := tex.resource_path
	if rectCache.has(key): return rectCache[key]
	var rect := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img != null && not img.is_empty():
		if img.is_compressed(): img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0: rect = Rect2(used)
	rectCache[key] = rect
	return rect

## Whether a world point is under a canopy (in its shape, grown by UNDER_PAD)
static func isUnder(canopy: Sprite2D, rect: Rect2, square: bool, at: Vector2) -> bool:
	var local := canopy.to_local(at)
	var pad := UNDER_PAD / maxf(canopy.scale.x, 0.01)
	var box := rect.grow(pad)
	if not box.has_point(local): return false
	if square: return true
	var half := box.size * 0.5
	var d := (local - box.get_center()) / half
	return d.length_squared() <= 1.0

func updateCanopies(delta: float) -> void:
	var car = Root.playerCar
	var carAt: Vector2 = car.global_position if is_instance_valid(car) && car.is_inside_tree() else Vector2.INF
	var step := FADE_RATE * delta
	for i in range(canopies.size() - 1, -1, -1):
		var entry: Array = canopies[i]
		var canopy: Sprite2D = entry[1]
		if not is_instance_valid(canopy) || not is_instance_valid(entry[0]) || not entry[0].is_inside_tree():
			canopies.remove_at(i)
			continue
		var target := 1.0
		if carAt != Vector2.INF:
			var reach: float = entry[4] + UNDER_PAD
			if canopy.global_position.distance_squared_to(carAt) < reach * reach && isUnder(canopy, entry[2], entry[3], carAt): target = FADE_ALPHA
		if canopy.modulate.a != target: canopy.modulate.a = move_toward(canopy.modulate.a, target, step)

#--- hits -------------------------------------------------------------------------------------------

## A prop that knocks over instead of stopping the car (a cone still standing); the AI driver plans through it
static func isKnockable(collider: Object) -> bool:
	return collider is Node2D && REACT.get(BreakableProp.propId(collider), NONE) == KNOCK && not collider.get_meta(&"knocked", false)

## A cone the car hits fast enough flies off (react) and stops being a wall: true when it did, so the car
## keeps its speed (overhead_car_body_2d.gd, before the wall branch)
static func knocks(collider: Object, moving: Vector2) -> bool:
	if current == null || not collider is Node2D || moving.length() < KNOCK_SPEED: return false
	if REACT.get(BreakableProp.propId(collider), NONE) != KNOCK || collider.get_meta(&"knocked", false): return false
	current.react(collider, moving, Vector2.INF)
	return true

## The car hit a prop (a wall hit, not a smash) moving at `moving`; `point` is the contact. Show only.
static func hit(prop: Object, moving: Vector2, point := Vector2.INF) -> void:
	if current == null || not prop is Node2D || not prop.has_meta(&"propId"): return
	current.react(prop, moving, point)

func react(prop: Node2D, moving: Vector2, point: Vector2) -> void:
	var kind: int = REACT.get(BreakableProp.propId(prop), NONE)
	var speed := moving.length()
	if kind == NONE || speed < MIN_SPEED || prop.get_meta(&"knocked", false): return
	var k := clampf((speed - MIN_SPEED) / (FULL_SPEED - MIN_SPEED), 0.15, 1.0)
	var at: Vector2 = point if point != Vector2.INF else prop.global_position
	var dir := moving / speed
	#a breakable hit too slow to smash wobbles by how close it came, and cracks near the line
	var near := 0.0
	if BreakableProp.isBreakable(prop) && not prop.get_meta(&"explosive", false):
		near = speed / BreakableProp.speedOf(prop)
		k = clampf(near, 0.15, 1.0)
		if near >= NEAR_SMASH: crack(prop, dir, near)
	var sprite: Node2D = prop.get_node_or_null("Sprite2D")
	match kind:
		CANOPY:
			var canopy: Node2D = prop.get_node_or_null("Canopy")
			if canopy: spring(prop, canopy, CANOPY, k, dir)
			dropLeaves(prop, roundi(lerpf(LEAVES.x, LEAVES.y, k)), dir)
			Spill.ram(prop, speed) #a hard ram drops the crane's container, or a roost's Buzzards
		THUD: pass
		KNOCK:
			if speed >= KNOCK_SPEED:
				knock(prop, dir, k)
				return
			if sprite: spring(prop, sprite, WOBBLE, k, dir)
		SPRAY:
			if sprite: spring(prop, sprite, WOBBLE, k, dir)
			sprays.push_back([prop.global_position, SPRAY_SECONDS * (0.5 + 0.5 * k)])
		_:
			if sprite: spring(prop, sprite, kind, k, dir)
	puff(at, dir, k, kind == THUD || kind == SHAKE)

## Nearly smashed: a crack and a few chips off the prop's debris strip, more the closer it came
func crack(prop: Node2D, dir: Vector2, near: float) -> void:
	Audio.play(Transition.SOUNDS["rattle"], CRACK_DB, randf_range(1.3, 1.5))
	var tex := BreakableProp.texture(prop.get_meta(&"debris", ""))
	var n := roundi(lerpf(CHIPS.x, CHIPS.y, inverse_lerp(NEAR_SMASH, 1.0, near)) * particleScale)
	if tex == null || n <= 0: return
	var cells := maxi(1, tex.get_width() / maxi(1, tex.get_height()))
	for i in n:
		var v := dir.rotated(randf_range(-0.9, 0.9)) * randf_range(60.0, 160.0)
		bits.spawn(tex, randi() % cells, cells, prop.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), v, randf() * TAU, randf_range(-8.0, 8.0), randf_range(0.6, 0.9), 0.5)

## Starts (or kicks again) a spring on one of a prop's sprites
func spring(prop: Node2D, target: Node2D, kind: int, k: float, worldDir: Vector2) -> void:
	var amp: float = SPRING[kind][0] * k * (0.4 if calm else 1.0)
	var local := worldDir.rotated(-target.global_rotation)
	for entry in springs:
		if entry[0] == target:
			entry[2] = 0.0
			entry[3] = minf(maxf(entry[3] * exp(-SPRING[kind][2] * entry[2]), 0.0) + amp, SPRING[kind][0] * 1.5)
			entry[4] = local
			return
	springs.push_back([target, kind, 0.0, amp, local, target.position, target.rotation, target.scale, prop])

func updateSprings(delta: float) -> void:
	for i in range(springs.size() - 1, -1, -1):
		var e: Array = springs[i]
		var target: Node2D = e[0]
		if not is_instance_valid(target):
			springs.remove_at(i)
			continue
		e[2] += delta
		var spec: Array = SPRING[e[1]]
		var env: float = e[3] * exp(-spec[2] * e[2])
		if env < SETTLE * spec[0]:
			target.position = e[5]
			target.rotation = e[6]
			target.scale = e[7]
			springs.remove_at(i)
			continue
		var wave := sin(TAU * spec[1] * e[2]) * env
		var dir: Vector2 = e[4]
		match e[1]:
			CANOPY:
				target.position = e[5] + dir * wave
				target.rotation = e[6] + CANOPY_TILT * wave / spec[0] * signf(dir.x + dir.y)
			SHAKE: target.position = e[5] + dir * wave
			SWAY, WOBBLE, SPRAY: target.rotation = e[6] + wave * signf(dir.x - dir.y)
			SQUASH:
				var squash := Vector2(1.0 - wave, 1.0 + wave * 0.5) if absf(dir.x) > absf(dir.y) else Vector2(1.0 + wave * 0.5, 1.0 - wave)
				target.scale = e[7] * squash

## A knocked cone: the sprite flies off along the hit and lands; the prop stops being a wall
func knock(prop: Node2D, dir: Vector2, k: float) -> void:
	prop.set_meta(&"knocked", true)
	var shape: CollisionShape2D = prop.get_node_or_null("CollisionShape2D")
	if shape: shape.set_deferred("disabled", true)
	var sprite: Node2D = prop.get_node_or_null("Sprite2D")
	if sprite == null: return
	var spread := dir.rotated(randf_range(-0.5, 0.5)) * lerpf(KNOCK_DISTANCE.x, KNOCK_DISTANCE.y, k)
	var from := sprite.position
	flights.push_back([sprite, from, from + spread.rotated(-prop.global_rotation), randf_range(-14.0, 14.0), 0.0])
	Audio.play(Transition.SOUNDS["clank"], -10.0, randf_range(1.5, 1.8))
	puff(prop.global_position, dir, k, false)

func updateFlights(delta: float) -> void:
	for i in range(flights.size() - 1, -1, -1):
		var f: Array = flights[i]
		var sprite: Node2D = f[0]
		if not is_instance_valid(sprite):
			flights.remove_at(i)
			continue
		f[4] += delta
		var t := minf(f[4] / KNOCK_SECONDS, 1.0)
		var ease := 1.0 - (1.0 - t) * (1.0 - t)
		sprite.position = f[1].lerp(f[2], ease)
		sprite.rotation += f[3] * (1.0 - t) * delta
		sprite.scale = Vector2.ONE * 1.3333 * (1.0 + 0.35 * sin(PI * t)) #up and down again
		if t >= 1.0: flights.remove_at(i)

## A ChunkView reuses a pooled prop: everything a reaction changed goes back
static func reset(prop: Node2D) -> void:
	if current: current.forget(prop)
	var sprite: Node2D = prop.get_node_or_null("Sprite2D")
	if prop.get_meta(&"knocked", false):
		prop.remove_meta(&"knocked")
		var shape: CollisionShape2D = prop.get_node_or_null("CollisionShape2D")
		if shape: shape.disabled = false
		if sprite:
			sprite.position = Vector2.ZERO
			sprite.rotation = 0.0
			sprite.scale = Vector2.ONE * 1.3333
	var canopy: Node2D = prop.get_node_or_null("Canopy")
	if canopy: canopy.modulate.a = 1.0

## Drops a prop's springs, flights and canopy (its chunk is going): put at rest at once
func forget(prop: Node2D) -> void:
	for i in range(springs.size() - 1, -1, -1):
		var e: Array = springs[i]
		if e[8] != prop: continue
		if is_instance_valid(e[0]):
			e[0].position = e[5]
			e[0].rotation = e[6]
			e[0].scale = e[7]
		springs.remove_at(i)
	for i in range(flights.size() - 1, -1, -1):
		if is_instance_valid(flights[i][0]) && flights[i][0].get_parent() == prop:
			flights[i][0].position = flights[i][2]
			flights.remove_at(i)
	for i in range(canopies.size() - 1, -1, -1):
		if canopies[i][0] == prop: canopies.remove_at(i)
	if is_instance_valid(tags): tags.forget(prop)

## A blast at `pos` shakes the canopies within `radius` (BreakableProp.blastAt)
static func blast(pos: Vector2, radius: float) -> void:
	if current == null: return
	for entry in current.canopies:
		var prop: Node2D = entry[0]
		if not is_instance_valid(prop): continue
		var off := prop.global_position - pos
		if off.length() > radius + entry[4]: continue
		var dir := off.normalized() if off.length() > 1.0 else Vector2.RIGHT
		current.spring(prop, entry[1], CANOPY, 0.8, dir)
		current.dropLeaves(prop, BLAST_LEAVES, dir)

#--- bits -------------------------------------------------------------------------------------------

## Leaves (or needles, twigs, snow) falling out of a shaken crown, flung along the hit
func dropLeaves(prop: Node2D, count: int, dir: Vector2) -> void:
	var tex: Texture2D = leafTextures.get(BreakableProp.propId(prop))
	var canopy: Node2D = prop.get_node_or_null("Canopy")
	count = roundi(count * particleScale)
	if tex == null || canopy == null || count <= 0: return
	var cells := maxi(1, tex.get_width() / maxi(1, tex.get_height()))
	var reach := 60.0
	for entry in canopies:
		if entry[0] == prop: reach = entry[4] * 0.8
	for i in count:
		var cell := randi() % cells
		if cells == 4 && BreakableProp.propId(prop) == &"pine": cell = (2 + randi() % 2) if snowy && randf() < 0.75 else randi() % 2
		var from := prop.global_position + Vector2.from_angle(randf() * TAU) * reach * sqrt(randf())
		var vel := (dir * randf_range(30.0, 110.0) + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 50.0))
		bits.spawn(tex, cell, cells, from, vel, randf() * TAU, randf_range(-5.0, 5.0), BIT_SECONDS * randf_range(0.7, 1.2))

## A flood bursting out (Spill's water tower): a ring of droplets thrown to `radius`
func splash(at: Vector2, radius: float) -> void:
	var n := roundi(70.0 * particleScale)
	for i in n:
		var v := Vector2.from_angle(TAU * i / maxi(n, 1) + randf_range(-0.1, 0.1)) * radius * randf_range(1.2, 2.0)
		dust.spawn(at, v, randf_range(0.5, 0.9), randf_range(3.0, 6.0), WATER, CarJuice.Kind.SPRAY)
	for i in roundi(10 * particleScale): dust.spawn(at + Vector2.from_angle(randf() * TAU) * radius * 0.5, Vector2.ZERO, 0.9, 30.0, Color(WATER, 0.35), CarJuice.Kind.PUFF)

func puff(at: Vector2, dir: Vector2, k: float, heavy: bool) -> void:
	var n := roundi((5.0 if heavy else 3.0) * (0.5 + k) * particleScale)
	var col := SNOW_DUST if snowy else DUST
	for i in n:
		var v := (-dir * randf_range(20.0, 70.0)).rotated(randf_range(-1.2, 1.2))
		dust.spawn(at + Vector2(randf_range(-14, 14), randf_range(-14, 14)), v, randf_range(0.5, 0.9), randf_range(10.0, 18.0) * (1.0 + k * 0.5), col, CarJuice.Kind.PUFF)

func updateSprays(delta: float) -> void:
	for i in range(sprays.size() - 1, -1, -1):
		var s: Array = sprays[i]
		s[1] -= delta
		if s[1] <= 0.0:
			sprays.remove_at(i)
			continue
		var n := SPRAY_RATE * particleScale * delta
		var whole := int(n) + (1 if randf() < n - int(n) else 0)
		for j in whole:
			var v := Vector2.from_angle(randf() * TAU) * randf_range(60.0, 160.0)
			dust.spawn(s[0], v, randf_range(0.4, 0.8), randf_range(2.0, 4.0), WATER, CarJuice.Kind.SPRAY)

## Where the player's car is, for the decor that bends away from it (world_decor.gdshader)
const FAR := Vector2(1e6, 1e6)
var carShown := FAR
func updateCarPos() -> void:
	var car = Root.playerCar
	var at: Vector2 = car.global_position if is_instance_valid(car) && car.is_inside_tree() else FAR
	if at.distance_squared_to(carShown) < 1.0: return
	carShown = at
	RenderingServer.global_shader_parameter_set("gc_car_pos", at)

func _process(delta: float) -> void:
	updateCarPos()
	updateCanopies(delta)
	if not springs.is_empty(): updateSprings(delta)
	if not flights.is_empty(): updateFlights(delta)
	if not sprays.is_empty(): updateSprays(delta)

## Falling bits from a baked strip (a row of square cells), drawn by one node: they drift along the hit,
## spin, shrink from canopy height to the ground and fade
class Bits extends Node2D:
	var tex: Array = []
	var cell := PackedInt32Array()
	var cells := PackedInt32Array()
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var rot := PackedFloat32Array()
	var spin := PackedFloat32Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var scl := PackedFloat32Array()
	var next := 0
	var alive := 0

	func _init() -> void:
		top_level = true
		z_as_relative = false
		z_index = PropReactions.BITS_Z
		set_process(false)

	func resize(n: int) -> void:
		tex.resize(n)
		for a in [cell, cells]: a.resize(n)
		for a in [pos, vel]: a.resize(n)
		for a in [rot, spin, age, scl]: a.resize(n)
		life.resize(n)
		life.fill(0.0)

	func spawn(t: Texture2D, c: int, n: int, at: Vector2, v: Vector2, r: float, s: float, seconds: float, size := 1.0) -> void:
		if pos.is_empty(): return
		if life[next] <= 0.0: alive += 1
		tex[next] = t
		cell[next] = c
		cells[next] = n
		pos[next] = at
		vel[next] = v
		rot[next] = r
		spin[next] = s
		age[next] = 0.0
		life[next] = seconds
		scl[next] = size
		next = (next + 1) % pos.size()
		set_process(true)

	func _process(delta: float) -> void:
		for i in pos.size():
			if life[i] <= 0.0: continue
			age[i] += delta
			if age[i] >= life[i]:
				life[i] = 0.0
				alive -= 1
				continue
			var t := age[i] / life[i]
			var air := 1.0 - minf(t / 0.65, 1.0) #falling for the first 65%, then lying on the ground
			pos[i] += (vel[i] + Vector2(sin(age[i] * 7.0 + i) * 40.0, 0.0)) * delta * air
			rot[i] += spin[i] * delta * air
		queue_redraw()
		if alive <= 0:
			alive = 0
			set_process(false)

	func _draw() -> void:
		for i in pos.size():
			if life[i] <= 0.0: continue
			var t := age[i] / life[i]
			var h: float = tex[i].get_height()
			var s := 1.3333 * scl[i] * (1.0 + 0.45 * (1.0 - minf(t / 0.65, 1.0)))
			draw_set_transform(pos[i], rot[i], Vector2(s, s))
			draw_texture_rect_region(tex[i], Rect2(-h * 0.5, -h * 0.5, h, h), Rect2(cell[i] * h, 0, h, h), Color(1, 1, 1, 1.0 - smoothstep(0.7, 1.0, t)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
