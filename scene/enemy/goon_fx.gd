class_name GoonFx extends Node2D
## Everything goons leave in the world besides themselves: telegraphs (the red ground marks before every
## threat), projectiles, hazards (fire, slime, oil, spikes), blasts, tethers, crush decals, bits, labels,
## delayed pickup drops and the crush itself (squashed or flung corpses, goo spatter, impact bursts). The SpawnManager owns one. Every list is capped, so a full pool just skips the
## effect, and everything is delta-based. Telegraphs, projectiles and fire draw unshaded, so night makes
## goons harder to see but never hides what they are about to do. docs/GOONS.md.

const MAX_DECALS := 64
const MAX_HAZARDS := 24
const MAX_PROJECTILES := 24
const MAX_TELEGRAPHS := 48
const MAX_BITS := 140
const MAX_LABELS := 12
const MAX_CORPSES := 16    #squashed and flung goons in flight (Crush Effects Reduced: 6)
const MAX_SPLATS := 48
const MAX_IMPACTS := 12
const FLING_SPEED := 430.0 #a crush this fast, or a blast, launches the goon instead of flattening it
const SQUASH_TIME := 0.13
const IMPACT_LIFE := 0.16
const LABEL_LIFE := 1.1
#goo spatter per faction (Goons.faction): Wild, Tribe, Scrap
const GOO := [Color(0.37, 0.17, 0.11, 0.8), Color(0.36, 0.24, 0.48, 0.8), Color(0.12, 0.22, 0.22, 0.85)]
const DECAL_LIFE := 8.0
const TELE := Color(1.0, 0.36, 0.19)
const ORANGE := Color(0.88, 0.47, 0.17)
const CAR_HALF := Vector2(105, 46) #the car's footprint in its own space, for hit tests

var ground: Node2D #under goons: hazards, telegraphs, buff rings, crumbs
var top: Node2D #over goons: projectiles, blasts, tethers, stars, labels, bits
var decalPool: Array[Sprite2D] = []
var decalNext := 0
var treadTexture: ImageTexture

var telegraphs: Array = []
var projectiles: Array = []
var hazards: Array = []
var flamesByFx := false #this frame's fires were drawn by Fx.burn (else the plain flames in drawGround)
var blasts: Array = []
var pendingBlasts: Array = []
var tethers: Array = []
var bitsList: Array = []
var labels: Array = []
var crumbs: Array = []
var drops: Array = []
var rings: Array = []
var corpses: Array = []          #{s, kind ("squash" or "fling"), t, T, ...}
var corpseFree: Array[Sprite2D] = []
var splats: Array = []           #{drops: PackedVector3Array (x, y, radius), col, age}
var impacts: Array = []
var lastCarRotation := 0.0
var carSpin := 0.0

func _ready() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ground = Node2D.new()
	ground.z_index = -1
	ground.material = unshaded
	ground.draw.connect(drawGround)
	add_child(ground)
	top = Node2D.new()
	top.z_index = 6
	top.material = unshaded
	top.draw.connect(drawTop)
	add_child(top)
	#a tire print: dark band with tread bars, laid across each crush decal along the car's heading
	var img := Image.create(32, 10, false, Image.FORMAT_RGBA8)
	for x in 32:
		for y in 10:
			img.set_pixel(x, y, Color(0.11, 0.09, 0.08, 0.75) if x % 4 > 1 else Color(0.32, 0.29, 0.25, 0.6))
	treadTexture = ImageTexture.create_from_image(img)

#--- the API the goons use ------------------------------------------------------------------------

func telegraph(owner: Walker, kind: String, duration: float, radius: float) -> void:
	if telegraphs.size() >= MAX_TELEGRAPHS: return
	telegraphs.push_back({"owner": weakref(owner), "kind": kind, "t": 0.0, "T": maxf(duration, 0.05), "r": radius, "pos": owner.lockPos})

## Floating text over the world. `size` is the font size before the pop; `col` (default: the HUD's text
## color) tints it, e.g. gold for a crush bonus.
func label(pos: Vector2, text: String, size := 18, col := Color.TRANSPARENT) -> void:
	if labels.size() >= MAX_LABELS: labels.pop_front()
	labels.push_back({"pos": pos + Vector2(0, -30), "text": text, "age": 0.0, "size": size, "col": HudTheme.TEXT if col.a == 0.0 else col})

func addDecal(tex: Texture2D, pos: Vector2, rot: float, scl: float, carHeading: float, tread: bool) -> void:
	if tex == null: return
	var s: Sprite2D
	if decalPool.size() < MAX_DECALS:
		s = Sprite2D.new()
		s.z_index = -2
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var t := Sprite2D.new()
		t.name = "tread"
		t.texture = treadTexture
		s.add_child(t)
		add_child(s)
		decalPool.push_back(s)
	else:
		s = decalPool[decalNext]
		decalNext = (decalNext + 1) % MAX_DECALS
	s.texture = tex
	s.global_position = pos
	s.rotation = rot
	s.scale = Vector2.ONE * scl
	s.modulate = Color.WHITE
	s.visible = true
	s.set_meta("age", 0.0)
	var t: Sprite2D = s.get_node("tread")
	t.visible = tread
	t.rotation = carHeading - rot
	t.scale = Vector2(tex.get_width() * 0.9 / 32.0, 1.6)

## The closest crush decal under `maxDist` that a buzzard could land on, or null.
func nearestDecal(pos: Vector2, maxDist: float):
	var best = null
	var bestD := maxDist
	for s in decalPool:
		if s.visible && s.get_meta("age", 99.0) < DECAL_LIFE - 3.0:
			var d := pos.distance_to(s.global_position)
			if d < bestD:
				bestD = d
				best = s.global_position
	return best

## Bits in the faction's colors. With a direction, two in three spray along it at up to `power` px/s (the
## car's speed); the rest scatter all round.
func bits(pos: Vector2, faction: int, dir := Vector2.ZERO, power := 0.0, count := 7) -> void:
	var cols = [[Color("#8a7050"), Color("#5b4636")], [Color("#9a8aa8"), ORANGE, Color("#3a3046")], [Color("#8d8f8c"), Color("#2aa6a1"), Color("#4a4c4f")]][clampi(faction, 0, 2)]
	for i in count:
		if bitsList.size() >= MAX_BITS: return
		var v := Vector2.from_angle(randf() * TAU) * randf_range(120.0, 340.0)
		if dir != Vector2.ZERO && i % 3 != 0: v = dir.rotated(randf_range(-0.7, 0.7)) * maxf(power, 250.0) * randf_range(0.45, 0.95)
		bitsList.push_back({"pos": pos, "vel": v, "age": 0.0, "life": randf_range(0.5, 0.9), "col": cols[i % cols.size()], "s": randf_range(2.5, 5.0)})

#--- the crush ------------------------------------------------------------------------------------
#How a goon dies under the car (Walker.destroy). How big the moment feels (camera, hit-stop, bonuses) is
#CrushFeel's; how much is drawn is Settings gfx/crush_fx: 0 the decal and bits only, 1 adds the death
#styles below (at most 6 bodies at once), the spatter and the squash, 2 more bodies, bits and impact bursts.
#
#A crush by the car picks one of four death styles (deathStyle), weighted by speed and where the car hit:
#  splat  flattened where it stood, goo thrown ahead
#  shove  pushed along the line of the hit (a nudge when slow, a long tumble when fast) with a smear, then laid down
#  hood   rides the hood, then is thrown off by a hard turn or braking, slides off the side, or goes under the wheels
#  fling  launched spinning through the air, landing as a decal (always, from a blast)
#Giants are too heavy for anything but a splat.

const STYLE_WEIGHTS := [ #[top speed of the band, {style: weight}]
	[350.0, {&"splat": 9.0, &"shove": 1.0, &"hood": 0.0, &"fling": 0.0}], #under 35 mph: nearly always a splat
	[FLING_SPEED, {&"splat": 5.0, &"shove": 2.0, &"hood": 3.0, &"fling": 1.0}],
	[INF, {&"splat": 3.0, &"shove": 2.0, &"hood": 3.0, &"fling": 4.0}],
]
const CORNER_SHOVE := 2.0  #a hit on the car's corner or side shoves more often...
const CORNER_HOOD := 0.2   #...and rarely lands on the hood
const HOOD_MIN_SPEED := 350.0
const HOOD_MAX := 2        #riders on the hood at once
const HOOD_THROW_SPIN := 2.4 #rad/s of car turn that throws a rider off
const HOOD_BRAKE_SPEED := 140.0 #below this a rider keeps going forward off the hood
const SHOVE_FRICTION := 0.04 #share of a shoved body's speed left after a second
const SMEAR_STEP := 24.0
const SMEAR_MAX := 14

static func crushLevel() -> int:
	return Settings.get_value("gfx/crush_fx")

## How a goon crushed at `speed` dies; `local` is where it was in the car's space (+x ahead), `roll` in [0, 1).
static func deathStyle(speed: float, local: Vector2, giant: bool, roll: float) -> StringName:
	if giant: return &"splat"
	var weights: Dictionary = {}
	for band in STYLE_WEIGHTS:
		if speed < band[0]:
			weights = band[1].duplicate()
			break
	if absf(local.y) > CAR_HALF.y * 0.55 || local.x < CAR_HALF.x * 0.3: #a corner or the side, not the nose
		weights[&"shove"] *= CORNER_SHOVE
		weights[&"hood"] *= CORNER_HOOD
	if speed < HOOD_MIN_SPEED: weights[&"hood"] = 0.0
	var total := 0.0
	for k in weights: total += weights[k]
	var pick := roll * total
	for k in weights:
		pick -= weights[k]
		if pick < 0.0: return k
	return &"splat"

## A goon crushed by the car or killed by a blast (`from`: the blast's center, else INF)
func crushed(goon: Walker, cause: StringName, from: Vector2) -> void:
	var car = Root.playerCar
	var hasCar := is_instance_valid(car)
	var pos := goon.global_position
	var spr: AnimatedSprite2D = goon.sprite
	var faction: int = goon.def.get("faction", 1)
	var heading: float = car.rotation if hasCar else goon.rotation
	var level := crushLevel()
	var byCar := cause == &"crush"
	var dir := Vector2.from_angle(heading)
	var power: float = car.velocity.length() if hasCar && byCar else 0.0
	if not byCar:
		dir = (pos - from).normalized() if from != Vector2.INF && not pos.is_equal_approx(from) else Vector2.ZERO
		power = FLING_SPEED + 120.0 if dir != Vector2.ZERO else 0.0
	var slam: Vector2 = car.crushHitVel if hasCar && byCar else Vector2.ZERO #swatted by the car's side or tail
	if slam != Vector2.ZERO:
		dir = slam.normalized()
		power = slam.length()
	var placed := false
	var src := bodyOf(goon)
	if level > 0 && not src.is_empty() && corpses.size() < (MAX_CORPSES if level > 1 else 6):
		if not byCar:
			if power > 0.0 && not goon.isGiant: placed = fling(src, dir, power)
		elif slam != Vector2.ZERO: #a slam sends it the way that part of the car was moving
			placed = fling(src, dir, power) if power >= FLING_SPEED * 0.8 else shove(src, dir, power)
		elif hasCar:
			var local: Vector2 = car.to_local(pos)
			var style := deathStyle(power, local, goon.isGiant, randf())
			if style == &"hood" && hoodRiders() >= HOOD_MAX: style = &"shove"
			match style:
				&"fling": placed = fling(src, dir, power)
				&"shove": placed = shove(src, shoveDir(car, local), power)
				&"hood": placed = hood(src, car, local)
	if not placed:
		addDecal(goon.decal, pos, spr.global_rotation, spr.global_scale.x, heading, byCar)
		if level > 0 && byCar && not src.is_empty(): squash(src)
	bits(pos, faction, dir, power, [7, 9, 12][clampi(level, 0, 2)] * (2 if goon.isGiant else 1))
	if level == 0: return
	if not placed && dir != Vector2.ZERO: splat(pos, dir, faction, goon.isGiant)
	if goon.isGiant:
		ring(pos, goon.bodyRadius * goon.scale.x * 2.2)
		dust(pos)
	if level > 1 && byCar: impact(pos, dir, goon.bodyRadius * goon.scale.x)

## What a corpse needs from the goon: its last frame, decal, place, turn, scale and faction ({} if no frame)
func bodyOf(goon: Walker) -> Dictionary:
	var spr: AnimatedSprite2D = goon.sprite
	var tex := frameTexture(spr)
	if tex == null: return {}
	return {"tex": tex, "decal": goon.decal, "pos": spr.global_position, "rot": spr.global_rotation, "scale": spr.global_scale, "faction": goon.def.get("faction", 1)}

## The same for a corpse that changes style (a hood rider thrown off)
static func bodyOfCorpse(c: Dictionary) -> Dictionary:
	var s: Sprite2D = c.s
	return {"tex": s.texture, "decal": c.decal, "pos": s.global_position, "rot": s.global_rotation, "scale": c.base, "faction": c.faction}

static func frameTexture(spr: AnimatedSprite2D) -> Texture2D:
	if spr == null || spr.sprite_frames == null || not spr.sprite_frames.has_animation(spr.animation): return null
	return spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)

## Along the line of the hit: the way the car is traveling, deflected a little toward the side of the
## bumper that hit it (at most about 20 degrees, on the corner)
static func shoveDir(car: Node2D, local: Vector2) -> Vector2:
	var travel: Vector2 = car.velocity.normalized() if car.velocity.length() > 1.0 else Vector2.from_angle(car.rotation)
	var off := clampf(local.y / CAR_HALF.y, -1.0, 1.0)
	return (travel + travel.orthogonal() * off * 0.35).normalized().rotated(randf_range(-0.1, 0.1))

func hoodRiders() -> int:
	var n := 0
	for c in corpses:
		if c.kind == "hood": n += 1
	return n

func takeCorpse(src: Dictionary) -> Sprite2D:
	var s: Sprite2D = corpseFree.pop_back() if not corpseFree.is_empty() else null
	if s == null:
		s = Sprite2D.new()
		s.z_index = 4
		add_child(s)
	s.texture = src.tex
	s.global_position = src.pos
	s.global_rotation = src.rot
	s.scale = src.scale
	s.modulate = Color.WHITE
	s.z_index = 4
	s.visible = true
	return s

func addCorpse(src: Dictionary, kind: String, T: float, extra: Dictionary) -> void:
	var c := {"s": takeCorpse(src), "kind": kind, "t": 0.0, "T": T, "base": src.scale, "decal": src.decal, "faction": src.faction}
	c.merge(extra)
	corpses.push_back(c)

## Splat: the goon's last frame flattens into its decal (the decal is already laid underneath)
func squash(src: Dictionary) -> void:
	if corpses.size() >= MAX_CORPSES: return
	addCorpse(src, "squash", SQUASH_TIME, {})

## Fling: launched along `dir`, spinning, in an arc (it grows as it rises; its shadow stays on the ground).
## A wall or a cliff in the way stops it short.
func fling(src: Dictionary, dir: Vector2, power: float) -> bool:
	var pos: Vector2 = src.pos
	var aim := dir.rotated(randf_range(-0.55, 0.55))
	var reach := clampf(power * randf_range(0.45, 0.7), 160.0, 520.0)
	var to := pos + aim * reach
	for i in 2:
		if not WorldHooks.wallAt(to) && WorldHooks.lineClear(pos, to): break
		to = pos + (to - pos) * 0.45
	addCorpse(src, "fling", clampf(reach / 900.0, 0.3, 0.55), {"from": pos, "to": to, "ground": pos,
		"h": clampf(power * 0.16, 50.0, 120.0), "spin": randf_range(9.0, 16.0) * (1.0 if randf() < 0.5 else -1.0), "dir": aim})
	return true

## Shove: knocked along `dir`, tumbling flat along the ground and smearing goo until friction or a wall stops it
func shove(src: Dictionary, dir: Vector2, power: float) -> bool:
	#a slow hit only nudges it (about 40 px at 300 px/s); a fast one sends it tumbling (about 200 px at 700)
	var v := clampf(power * lerpf(0.4, 0.9, clampf((power - 250.0) / 450.0, 0.0, 1.0)) * randf_range(0.85, 1.1), 60.0, 760.0)
	var smear := {"drops": PackedVector3Array(), "col": GOO[clampi(src.faction, 0, 2)], "age": 0.0}
	if splats.size() >= MAX_SPLATS: splats.pop_front()
	splats.push_back(smear)
	addCorpse(src, "shove", 1.2, {"vel": dir * v, "v0": v, "spin": randf_range(4.0, 9.0) * (1.0 if randf() < 0.5 else -1.0),
		"smear": smear, "lastSmear": src.pos, "dir": dir})
	#on the ground and limp: under the car and darkened, so it never reads as a live goon being driven over
	var s: Sprite2D = corpses[-1].s
	s.z_index = -1
	s.modulate = Color(0.72, 0.72, 0.72)
	return true

## Hood ride: stuck to the car's nose where it was hit, wobbling, for a moment (stepHood decides how it leaves)
func hood(src: Dictionary, car: Node2D, local: Vector2) -> bool:
	var at := Vector2(CAR_HALF.x * randf_range(0.35, 0.7), clampf(local.y, -CAR_HALF.y * 0.6, CAR_HALF.y * 0.6))
	addCorpse(src, "hood", randf_range(0.45, 1.0), {"car": weakref(car), "local": at, "localRot": src.rot - car.rotation, "phase": randf() * TAU})
	return true

## Spokes bursting out from the point of impact for a moment (no white flash with Reduce Flashing)
func impact(pos: Vector2, dir: Vector2, r: float) -> void:
	if impacts.size() >= MAX_IMPACTS: impacts.pop_front()
	impacts.push_back({"pos": pos, "dir": dir, "r": maxf(r, 22.0), "age": 0.0})

## Goo droplets thrown ahead of the crush along `dir`, fading with the decals
func splat(pos: Vector2, dir: Vector2, faction: int, big: bool) -> void:
	if splats.size() >= MAX_SPLATS: splats.pop_front()
	var drops := PackedVector3Array()
	var side := dir.orthogonal()
	var reach := 140.0 if big else 90.0
	for i in (10 if big else 6):
		var along := randf_range(12.0, reach)
		var p := pos + dir * along + side * randf_range(-24.0, 24.0) * (1.0 + along / 100.0)
		drops.push_back(Vector3(p.x, p.y, randf_range(3.5, 10.0) * (1.6 if big else 1.0) * (1.0 - along / (reach * 2.0))))
	splats.push_back({"drops": drops, "col": GOO[clampi(faction, 0, 2)], "age": 0.0})

## A body comes to rest: its decal, a puff, a few bits and a spatter, or a splash in deep water
func layDown(c: Dictionary, at: Vector2, dir: Vector2, tread := false) -> void:
	if World.lethalAt(at):
		ring(at, 40.0)
		if Fx.current(): Fx.current().splash(at, 0.5)
		return
	addDecal(c.decal, at, c.s.global_rotation, c.base.x, dir.angle() if not tread else c.get("treadHeading", dir.angle()), tread)
	dust(at)
	bits(at, c.faction, dir, 220.0, 4)
	splat(at, dir, c.faction, false)

func stepCorpse(c: Dictionary, delta: float) -> void:
	c.t += delta
	var s: Sprite2D = c.s
	var done := false
	match c.kind:
		"squash":
			var u: float = minf(1.0, c.t / c.T)
			s.scale = Vector2(c.base.x * (1.0 + 0.45 * u), c.base.y * (1.0 - 0.85 * u))
			var shade := 1.0 - 0.45 * u
			s.modulate = Color(shade, shade, shade, 1.0 - u * u)
			done = u >= 1.0
		"fling":
			var u: float = minf(1.0, c.t / c.T)
			var e := 1.0 - (1.0 - u) * (1.0 - u)
			var h: float = sin(PI * u) * c.h
			c.ground = c.from.lerp(c.to, e)
			s.global_position = c.ground - Vector2(0.0, h * 0.6)
			s.rotation += c.spin * delta
			s.scale = c.base * (1.0 + h / 220.0)
			if u >= 1.0:
				done = true
				layDown(c, c.to, c.dir)
		"shove": done = stepShove(c, s, delta)
		"hood": done = stepHood(c, s, delta)
	if not done || c.kind == "gone": return #a thrown-off hood rider has already handed its sprite on
	s.visible = false
	corpses.erase(c)
	corpseFree.push_back(s)

func stepShove(c: Dictionary, s: Sprite2D, delta: float) -> bool:
	c.vel *= pow(SHOVE_FRICTION, delta)
	var speed: float = c.vel.length()
	var next: Vector2 = s.global_position + c.vel * delta
	var bonk := WorldHooks.wallAt(next)
	if not bonk: s.global_position = next
	s.rotation += c.spin * delta * speed / c.v0
	if s.global_position.distance_to(c.lastSmear) >= SMEAR_STEP && c.smear.drops.size() < SMEAR_MAX:
		c.lastSmear = s.global_position
		var drops: PackedVector3Array = c.smear.drops
		var p: Vector2 = s.global_position + c.dir.orthogonal() * randf_range(-6.0, 6.0)
		drops.push_back(Vector3(p.x, p.y, randf_range(3.0, 6.5) * (0.6 + 0.4 * speed / c.v0)))
		c.smear.drops = drops
	if World.lethalAt(s.global_position):
		ring(s.global_position, 40.0)
		if Fx.current(): Fx.current().splash(s.global_position, 0.5)
		return true
	if bonk || speed < 40.0 || c.t >= c.T:
		layDown(c, s.global_position, c.dir)
		if bonk: label(s.global_position, "SPLAT", 16)
		return true
	return false

func stepHood(c: Dictionary, s: Sprite2D, delta: float) -> bool:
	var car = c.car.get_ref()
	if car == null || not is_instance_valid(car) || car.get("isDestroyed"):
		layDown(c, s.global_position, Vector2.from_angle(s.global_rotation))
		return true
	var wobble := sin(c.t * 18.0 + c.phase) * 4.0
	s.global_position = car.to_global(c.local + Vector2(-absf(wobble) * 0.5, wobble))
	s.global_rotation = car.rotation + c.localRot + sin(c.t * 11.0 + c.phase) * 0.15
	var speed: float = car.velocity.length()
	var heading := Vector2.from_angle(car.rotation)
	if speed < HOOD_BRAKE_SPEED: #braked or stopped: it keeps going, over the nose
		throwOff(c, &"fling", heading, maxf(c.get("lastSpeed", 400.0), 380.0))
		return true
	c.lastSpeed = speed
	if absf(carSpin) > HOOD_THROW_SPIN: #thrown to the outside of the turn
		throwOff(c, &"shove", (heading * 0.5 + heading.orthogonal() * -signf(carSpin)).normalized(), speed)
		return true
	if c.t < c.T: return false
	if randf() < 0.5: #slides off the side it sat on
		throwOff(c, &"shove", (heading * 0.6 + heading.orthogonal() * (signf(c.local.y) if c.local.y != 0.0 else 1.0)).normalized(), speed * 0.7)
	else: #under the wheels: flattened with a tire print
		c.treadHeading = car.rotation
		layDown(c, car.to_global(Vector2(-CAR_HALF.x * 0.2, c.local.y)), heading, true)
		label(s.global_position, "SQUISH", 16)
	return true

## A hood rider leaves as a fling or a shove (its sprite goes back to the pool first, so the new style reuses it)
func throwOff(c: Dictionary, kind: StringName, dir: Vector2, power: float) -> void:
	var src := bodyOfCorpse(c)
	c.s.visible = false
	corpses.erase(c)
	corpseFree.push_back(c.s)
	c.kind = "gone" #stepCorpse's caller must not free the sprite again
	if kind == &"fling": fling(src, dir, power)
	else: shove(src, dir, power)

func dust(pos: Vector2) -> void:
	rings.push_back({"pos": pos, "r": 30.0, "age": 0.0, "life": 0.5, "dust": true})

func ring(pos: Vector2, r: float) -> void:
	rings.push_back({"pos": pos, "r": r, "age": 0.0, "life": 0.45, "dust": false})

func crumb(pos: Vector2) -> void:
	if crumbs.size() < 120: crumbs.push_back({"pos": pos, "age": 0.0})

func dropLater(pos: Vector2, table: Dictionary) -> void:
	drops.push_back({"pos": pos, "t": 0.5, "table": table, "scene": ""})

func dropAt(pos: Vector2, scenePath: String) -> void:
	drops.push_back({"pos": pos, "t": 0.0, "table": {}, "scene": scenePath})

## `shooter`: the goon that fired it, which its own quills never hit (quillsHitGoons)
func shoot(pos: Vector2, dir: Vector2, speed: float, life: float, dmg: float, sys: String, kind: String, shooter: Node = null) -> void:
	if projectiles.size() >= MAX_PROJECTILES: return
	projectiles.push_back({"kind": kind, "pos": pos, "vel": dir * speed, "t": 0.0, "life": life, "dmg": dmg, "sys": sys,
		"shooter": shooter.get_instance_id() if shooter else 0})

## An arc: lands at `to` after `T` seconds and becomes fire, slime or a bomb blast.
func lob(from: Vector2, to: Vector2, T: float, payload: String) -> void:
	if projectiles.size() >= MAX_PROJECTILES: return
	projectiles.push_back({"kind": "arc", "from": from, "to": to, "pos": from, "t": 0.0, "T": T, "payload": payload})

func harpoon(owner: Walker, dir: Vector2) -> void:
	if projectiles.size() >= MAX_PROJECTILES: return
	projectiles.push_back({"kind": "harpoon", "pos": owner.global_position + dir * owner.bodyRadius * 1.5, "vel": dir * 700.0, "t": 0.0, "life": 0.6, "owner": weakref(owner)})

func addHazard(kind: String, pos: Vector2, r: float, life: float, rot := 0.0) -> void:
	if (kind == "oil" || kind == "slime") && not WorldHooks.hazardAllowed(pos): return #never on shallows or at the water's edge
	if hazards.size() >= MAX_HAZARDS: hazards.pop_front()
	hazards.push_back({"kind": kind, "pos": pos, "r": r, "life": life, "age": 0.0, "rot": rot, "cd": 0.0, "side": 1.0 if randf() < 0.5 else -1.0})

## A tether from a goon to the car (harpoon, magnet) that drags it for `T` seconds or until it breaks.
func tether(owner: Walker, T: float, kind: String) -> void:
	for x in tethers:
		if x.owner.get_ref() == owner: return
	tethers.push_back({"owner": weakref(owner), "t": 0.0, "T": T, "kind": kind})
	label(owner.global_position, "HOOKED" if kind == "harpoon" else "MAGNET")

## Hurts the car and flattens goons inside `r`; walls (wall cells: WorldHooks.lineClear) shelter what's
## behind them. Goons it kills count as crushes near the car (SpawnManager.creditCrush; `source` &"gadget" for
## the player's own: they count anywhere). Herds within SPOOK_PAD past the edge stampede away from it.
## Explosive props in reach go off in turn (BreakableProp).
const SPOOK_PAD := 450.0
func blast(pos: Vector2, r: float, dmg: float, source: StringName = &"blast") -> void:
	blasts.push_back({"pos": pos, "r": r, "age": 0.0})
	label(pos, "BOOM")
	var car = Root.playerCar
	if is_instance_valid(car) && car.global_position.distance_to(pos) < r + 40.0 && WorldHooks.lineClear(pos, car.global_position):
		car.damage(dmg)
		if car.has_method("wearSystem"): car.wearSystem("engine", dmg * 2.0)
	for o in Root.spawnManager.goonsNear(pos, r + SPOOK_PAD):
		if o.dead: continue
		if o.global_position.distance_to(pos) > r || not WorldHooks.lineClear(pos, o.global_position):
			if o.verb is GoonVerbs.Herd: o.verb.spook(pos)
			continue
		o.killedFrom = pos #flung away from the blast
		o.destroy(&"boom")
		Root.spawnManager.creditCrush(o.global_position, o, source)
	if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("explode"): Root.levelRoot.explode(pos) #pooled, at most 16 live
	if is_inside_tree(): BreakableProp.blastAt(get_tree(), pos, r) #barrels and tanks: a hop per CHAIN_DELAY, each once

func blastLater(pos: Vector2, delay: float, r: float, dmg: float, source: StringName = &"blast") -> void:
	pendingBlasts.push_back({"pos": pos, "t": delay, "r": r, "dmg": dmg, "source": source})

#--- simulation -------------------------------------------------------------------------------------

func insideCar(car: Node2D, p: Vector2, pad := 0.0) -> bool:
	var l: Vector2 = car.to_local(p)
	return absf(l.x) < CAR_HALF.x + pad && absf(l.y) < CAR_HALF.y + pad

func hurtCar(car: Node2D, dmg: float, sys: String) -> void:
	car.damage(dmg)
	if sys != "hull" && car.has_method("wearSystem"): car.wearSystem(sys, dmg * 3.0)

## Quill friendly fire (G-10): a Quill's volley flattens fodder (rank QUILL_KILL_RANK or less, solid) it flies
## through, credited near the car like any kill the player set up ("quill"). Only while quills fly: one pass over
## the goons a tick, skipping those outside the volley's bounds, and no allocation.
const QUILL_KILL_RANK := 1
const QUILL_HIT := 8.0 #px added to a goon's radius
func quillsHitGoons() -> void:
	var bounds := Rect2()
	var any := false
	for p in projectiles:
		if p.kind != "quill": continue
		bounds = bounds.expand(p.pos) if any else Rect2(p.pos, Vector2.ZERO)
		any = true
	if not any || not is_instance_valid(Root.spawnManager): return
	bounds = bounds.grow(60.0)
	for o in Root.spawnManager.goons:
		if not is_instance_valid(o) || o.dead || o.collision_layer == 0 || not bounds.has_point(o.global_position): continue
		if int(o.def.get("rank", 1)) > QUILL_KILL_RANK: continue
		var reach: float = o.bodyRadius * o.scale.x + QUILL_HIT
		var id := o.get_instance_id()
		for p in projectiles:
			if p.kind != "quill" || p.shooter == id || p.pos.distance_squared_to(o.global_position) > reach * reach: continue
			projectiles.erase(p)
			Spill.flatten(o, p.pos - p.vel.normalized() * 30.0, &"boom", &"quill")
			break

## Spitter slime slows goons too (G-9): every SLIME_EVERY ticks, solid goons in a puddle run at SLIME_SLOW of
## their speed for a moment (the buff scale the Foreman's aura uses; GoonBody.speedNow)
const SLIME_EVERY := 4
const SLIME_SLOW := 0.5
const SLIME_HOLD := 0.25 #s the slow lasts after the last check that found the goon in it
func slowGoons(h: Dictionary) -> void:
	if not is_instance_valid(Root.spawnManager): return
	var until := GoonVerbs.now() + SLIME_HOLD
	for o in Root.spawnManager.goonsNear(h.pos, h.r):
		if o.dead || o.collision_layer == 0: continue #flying, buried or mid-hop: over it
		o.buffScale = SLIME_SLOW
		o.buffUntil = until

func _physics_process(delta: float) -> void:
	var car = Root.playerCar
	var hasCar := is_instance_valid(car)
	if hasCar:
		carSpin = angle_difference(lastCarRotation, car.rotation) / delta
		lastCarRotation = car.rotation
	for p in projectiles.duplicate():
		p.t += delta
		if p.kind == "arc":
			var u: float = minf(1.0, p.t / p.T)
			p.pos = p.from.lerp(p.to, u)
			if u >= 1.0:
				projectiles.erase(p)
				if p.payload != "bomb" && WorldHooks.wallAt(p.to): continue #splashed on a cliff or a roof
				match p.payload:
					"fire": addHazard("fire", p.to, 58.0, 3.0)
					"slime": addHazard("slime", p.to, 64.0, 6.0)
					"bomb": blast(p.to, 90.0, 6.0)
			continue
		p.pos += p.vel * delta
		if WorldHooks.wallAt(p.pos): #shots, quills and harpoons stop at walls: cover is cover
			projectiles.erase(p)
			dust(p.pos)
			continue
		if hasCar && insideCar(car, p.pos):
			projectiles.erase(p)
			if p.kind == "harpoon":
				var o = p.owner.get_ref()
				if o && not o.dead: tether(o, 3.0, "harpoon")
			else: hurtCar(car, p.dmg, p.sys)
		elif p.t > p.life: projectiles.erase(p)
	quillsHitGoons()
	var slimeTick := Engine.get_physics_frames() % SLIME_EVERY == 0
	for h in hazards.duplicate():
		h.age += delta
		h.cd = maxf(0.0, h.cd - delta)
		if h.age > h.life:
			if h.kind == "fire" && Fx.current(): Fx.current().scorch(h.pos, h.r * 0.9)
			hazards.erase(h)
			continue
		if slimeTick && h.kind == "slime": slowGoons(h)
		if not hasCar: continue
		var on := false
		if h.kind == "spikes":
			var l: Vector2 = (car.global_position - h.pos).rotated(-h.rot)
			on = absf(l.x) < h.r + 30.0 && absf(l.y) < 40.0
		else: on = car.global_position.distance_to(h.pos) < h.r + 36.0
		if not on: continue
		match h.kind:
			"fire":
				if h.cd <= 0.0:
					h.cd = 0.5
					hurtCar(car, 1.5, "tires")
			"slime":
				car.velocity *= 0.985
				if h.cd <= 0.0:
					h.cd = 0.5
					if car.has_method("wearSystem"): car.wearSystem("tires", 1.0)
			"oil":
				car.velocity = car.velocity.rotated(0.025 * h.side) * 0.996
			"spikes":
				if h.cd <= 0.0:
					h.cd = 1.0
					hurtCar(car, 2.0, "tires")
					if car.has_method("wearSystem"): car.wearSystem("tires", 10.0)
					label(car.global_position, "TIRES")
	for t in tethers.duplicate():
		t.t += delta
		var o = t.owner.get_ref()
		if not hasCar || o == null || o.dead || t.t > t.T || o.global_position.distance_to(car.global_position) > 650.0 || (t.kind == "harpoon" && absf(carSpin) > 2.0):
			tethers.erase(t)
			continue
		if WorldHooks.tetherMustBreak(car.global_position): #a tether never drags the car into deep water
			tethers.erase(t)
			label(car.global_position, "SNAPPED")
			continue
		var dir: Vector2 = (o.global_position - car.global_position).normalized()
		if t.kind == "harpoon":
			car.velocity = car.velocity * 0.975 + dir * 8.0
		else:
			car.velocity = car.velocity * 0.99 + dir * 14.0
	for b in pendingBlasts.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			pendingBlasts.erase(b)
			blast(b.pos, b.r, b.dmg, b.source)
	for d in drops.duplicate():
		d.t -= delta
		if d.t > 0.0: continue
		drops.erase(d)
		if not is_instance_valid(Root.levelRoot): continue
		var pickup: Node2D = load(d.scene).instantiate() if d.scene != "" else Root.getPowerupFromWeights(d.table)
		pickup.position = d.pos
		Root.levelRoot.add_child(pickup)

func _process(delta: float) -> void:
	for s in decalPool:
		if not s.visible: continue
		var age: float = s.get_meta("age", 0.0) + delta
		s.set_meta("age", age)
		if age > DECAL_LIFE: s.visible = false
		elif age > DECAL_LIFE - 2.0: s.modulate.a = (DECAL_LIFE - age) / 2.0
	for t in telegraphs.duplicate():
		t.t += delta
		if t.t > t.T || t.owner.get_ref() == null: telegraphs.erase(t)
	for b in blasts.duplicate():
		b.age += delta
		if b.age > 0.55: blasts.erase(b)
	for b in bitsList.duplicate():
		b.age += delta
		b.pos += b.vel * delta
		b.vel *= pow(0.05, delta)
		if b.age > b.life: bitsList.erase(b)
	for l in labels.duplicate():
		l.age += delta
		l.pos.y -= 24.0 * delta
		if l.age > LABEL_LIFE: labels.erase(l)
	for c in crumbs.duplicate():
		c.age += delta
		if c.age > 1.2: crumbs.erase(c)
	for r in rings.duplicate():
		r.age += delta
		if r.age > r.life: rings.erase(r)
	for c in corpses.duplicate(): stepCorpse(c, delta)
	for p in splats.duplicate():
		p.age += delta
		if p.age > DECAL_LIFE: splats.erase(p)
	for m in impacts.duplicate():
		m.age += delta
		if m.age > IMPACT_LIFE: impacts.erase(m)
	var levelFx := Fx.current()
	flamesByFx = false
	if levelFx:
		for h in hazards:
			if h.kind == "fire": flamesByFx = levelFx.burn(h.pos, h.r * clampf((h.life - h.age) * 2.0, 0.0, 1.0), delta)
	ground.queue_redraw()
	top.queue_redraw()

#--- drawing --------------------------------------------------------------------------------------

func tele(a: float) -> Color: return Color(TELE.r, TELE.g, TELE.b, a)

func dashedCircle(n: Node2D, c: Vector2, r: float, col: Color, w: float) -> void:
	var seg := maxi(12, int(r / 9.0))
	for i in seg:
		if i % 2 == 0: n.draw_arc(c, r, TAU * i / seg, TAU * (i + 1) / seg, 4, col, w)

func drawGround() -> void:
	var g := ground
	for c in crumbs: g.draw_circle(c.pos, 3.0, Color(0.24, 0.18, 0.12, 0.7 * (1.0 - c.age / 1.2)))
	for p in splats:
		var col: Color = p.col
		col.a *= clampf((DECAL_LIFE - p.age) / 2.0, 0.0, 1.0)
		for d in p.drops: g.draw_circle(Vector2(d.x, d.y), d.z, col)
	for c in corpses: #a flung goon's shadow stays on the ground, shrinking as it rises
		if c.kind != "fling": continue
		var lift: float = sin(PI * minf(1.0, c.t / c.T))
		g.draw_set_transform(c.ground, 0.0, Vector2(1.0, 0.6))
		g.draw_circle(Vector2.ZERO, 44.0 * c.base.x * (1.0 - 0.35 * lift), Color(0, 0, 0, 0.3 * (1.0 - 0.5 * lift)))
		g.draw_set_transform(Vector2.ZERO)
	for h in hazards:
		var fade: float = clampf((h.life - h.age) * 2.0, 0.0, 1.0)
		match h.kind:
			"fire":
				g.draw_circle(h.pos, h.r, Color(0.12, 0.08, 0.04, 0.35 * fade))
				if flamesByFx: #Fx.burn draws the flames; the ring keeps the fire's edge readable
					g.draw_arc(h.pos, h.r, 0.0, TAU, 32, Color(1.0, 0.5, 0.12, 0.5 * fade), 3.0)
					continue
				var tt := Time.get_ticks_msec() / 1000.0
				for i in 7:
					var a := i * TAU / 7.0 + tt * 0.6
					var q: float = h.r * 0.55 * ((i * 37) % 7) / 7.0
					var rr: float = h.r * (0.3 + 0.1 * sin(tt * 9.0 + i))
					g.draw_circle(h.pos + Vector2.from_angle(a) * q, rr, Color(1.0, 0.5, 0.12, 0.45 * fade))
					g.draw_circle(h.pos + Vector2.from_angle(a) * q, rr * 0.45, Color(1.0, 0.9, 0.6, 0.6 * fade))
			"slime":
				g.draw_circle(h.pos, h.r, Color(0.45, 0.55, 0.2, 0.45 * fade))
				g.draw_circle(h.pos + Vector2(h.r * 0.3, -h.r * 0.2), h.r * 0.35, Color(0.7, 0.8, 0.35, 0.35 * fade))
			"oil":
				g.draw_circle(h.pos, h.r, Color(0.05, 0.05, 0.07, 0.8 * fade))
				g.draw_circle(h.pos + Vector2(-h.r * 0.3, -h.r * 0.25), h.r * 0.3, Color(0.35, 0.3, 0.55, 0.25 * fade))
			"spikes":
				g.draw_set_transform(h.pos, h.rot)
				g.draw_rect(Rect2(-h.r, -8, h.r * 2.0, 16), Color(0.15, 0.14, 0.13, fade))
				for x in range(int(-h.r) + 4, int(h.r) - 2, 9):
					for y in [-5.0, 4.0]:
						g.draw_colored_polygon(PackedVector2Array([Vector2(x, y + 3), Vector2(x + 3, y - 3), Vector2(x + 6, y + 3)]), Color(0.78, 0.79, 0.8, fade))
				g.draw_set_transform(Vector2.ZERO)
	for t in telegraphs:
		var o = t.owner.get_ref()
		if o == null: continue
		var p: float = clampf(t.t / t.T, 0.0, 1.0)
		match t.kind:
			"arrow":
				var length: float = t.r if t.r > 0.0 else 150.0
				var n := maxi(2, int(length / 26.0))
				var dir: Vector2 = o.lockDir
				for i in n:
					var u := (i + 0.5) / n
					var c: Vector2 = o.global_position + dir * length * u
					var a: float = 0.9 if u <= p else 0.28
					var side := dir.orthogonal() * 9.0
					g.draw_polyline(PackedVector2Array([c - dir * 6.0 - side, c + dir * 4.0, c - dir * 6.0 + side]), tele(a), 4.0)
			"ring":
				dashedCircle(g, o.global_position, t.r, tele(0.8), 3.0)
				g.draw_circle(o.global_position, t.r * p, tele(0.16))
			"land":
				dashedCircle(g, t.pos, t.r, tele(0.85), 3.0)
				g.draw_circle(t.pos, t.r * p, tele(0.18))
				g.draw_line(t.pos - Vector2(14, 0), t.pos + Vector2(14, 0), tele(0.9), 3.0)
				g.draw_line(t.pos - Vector2(0, 14), t.pos + Vector2(0, 14), tele(0.9), 3.0)
			"crack":
				dashedCircle(g, t.pos, t.r, tele(0.8), 3.0)
				for i in 7:
					g.draw_line(t.pos, t.pos + Vector2.from_angle(i * TAU / 7.0 + 0.3) * t.r * p, tele(0.6), 2.0)
			"aim":
				var dir := Vector2.from_angle(o.rotation)
				for i in 30:
					var a: Vector2 = o.global_position + dir * (o.bodyRadius + i * 14.0)
					g.draw_line(a, a + dir * 5.0, tele(0.35 + 0.5 * p), 3.0)
			"aura":
				dashedCircle(g, o.global_position, t.r * (0.6 + 0.4 * p), Color(ORANGE, 0.6 * (1.0 - p)), 3.0)
			"beam":
				var car = Root.playerCar
				if is_instance_valid(car): g.draw_line(o.global_position, car.global_position, Color(0.55, 0.85, 1.0, 0.25 + 0.4 * p), 3.0)
	#goon states the player has to read: shields up, buffed goons, hidden spots
	if is_instance_valid(Root.spawnManager) && is_instance_valid(Root.playerCar):
		var carPos: Vector2 = Root.playerCar.global_position
		for o in Root.spawnManager.goons:
			if not is_instance_valid(o) || o.dead: continue
			if o.isBuffed(): g.draw_circle(o.global_position, o.bodyRadius * 1.3, Color(ORANGE, 0.28) if o.buffScale > 1.0 else SLIMED)
			if o.def.get("shield", false) && (o.state == &"move" || o.state == &"windup") && o.facing(Root.playerCar):
				var a: float = o.rotation
				g.draw_arc(o.global_position + Vector2.from_angle(a) * o.bodyRadius * 1.1, 14.0, a - 1.1, a + 1.1, 8, Color(1, 1, 0.94, 0.45 + 0.35 * sin(Time.get_ticks_msec() / 125.0)), 3.0)
			if o.state == &"buried":
				var d2: float = o.global_position.distance_squared_to(carPos)
				if d2 < 260.0 * 260.0: g.draw_arc(o.global_position, 26.0, 0.0, TAU, 24, tele(0.45), 2.0)
				if d2 < BUBBLE_PX * BUBBLE_PX && o.def.get("log", false): bubbles(g, o)

const SLIMED := Color(0.55, 0.7, 0.25, 0.3)
## Snapper's tell (G-8): a log that is really a Snapper blows bubbles while the car is within BUBBLE_PX, drawn
## unshaded like every telegraph, so a careful driver can tell it from the real logs, day or night
const BUBBLE_PX := 400.0
func bubbles(g: Node2D, o: Node2D) -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	var phase := float(o.get_instance_id() % 997)
	for i in 4:
		var u := fmod(tt * 0.9 + i * 0.25 + phase * 0.13, 1.0) #each bubble rises, swells and pops
		var at: Vector2 = o.global_position + Vector2(sin(phase + i * 2.1) * 18.0, -u * 26.0 + 6.0)
		g.draw_arc(at, 2.0 + 4.0 * u, 0.0, TAU, 10, Color(0.82, 0.93, 1.0, 0.85 * (1.0 - u * u)), 1.5)

func drawTop() -> void:
	var g := top
	var car = Root.playerCar
	for t in tethers:
		var o = t.owner.get_ref()
		if o == null || not is_instance_valid(car): continue
		if t.kind == "harpoon": g.draw_line(o.global_position, car.global_position, Color(0.85, 0.8, 0.7, 0.9), 2.0)
		else:
			var dir: Vector2 = car.global_position - o.global_position
			for k in 3:
				var u := fmod(Time.get_ticks_msec() / 500.0 + k / 3.0, 1.0)
				g.draw_arc(o.global_position + dir * u, 18.0 + u * 20.0, dir.angle() - 1.2, dir.angle() + 1.2, 10, Color(0.55, 0.85, 1.0, 0.7 * (1.0 - u)), 3.0)
	for p in projectiles:
		match p.kind:
			"arc":
				var u: float = minf(1.0, p.t / p.T)
				var h := sin(PI * u) * 70.0
				g.draw_circle(p.pos, 6.0, Color(0, 0, 0, 0.3))
				var col := Color(0.31, 0.42, 0.23) if p.payload != "bomb" else Color(0.36, 0.37, 0.39)
				if p.payload == "slime": col = Color(0.55, 0.7, 0.25)
				g.draw_circle(p.pos - Vector2(0, h), 5.0, col)
				if p.payload == "fire" || p.payload == "bomb": g.draw_circle(p.pos - Vector2(0, h + 6.0), 4.0, Color(1.0, 0.7, 0.25, 0.9))
			"harpoon":
				g.draw_line(p.pos, p.pos - p.vel.normalized() * 22.0, Color(0.8, 0.8, 0.82), 3.0)
			_:
				var len := 10.0 if p.kind == "bolt" else 7.0
				g.draw_line(p.pos, p.pos - p.vel.normalized() * len, Color(0.75, 0.76, 0.78) if p.kind == "bolt" else Color(0.92, 0.88, 0.8), 3.0)
	for b in blasts:
		var u: float = b.age / 0.55
		g.draw_circle(b.pos, b.r * (0.5 + 0.6 * u), Color(1.0, 0.55, 0.15, 0.55 * (1.0 - u)))
		g.draw_circle(b.pos, b.r * (0.3 + 0.3 * u), Color(1.0, 0.95, 0.8, 0.7 * (1.0 - u)))
	for r in rings:
		var u: float = r.age / r.life
		if r.dust: g.draw_circle(r.pos, r.r * (0.4 + u), Color(0.8, 0.75, 0.63, 0.3 * (1.0 - u)))
		else: g.draw_arc(r.pos, r.r * (0.6 + 0.4 * u), 0.0, TAU, 32, Color(0.9, 0.85, 0.75, 1.0 - u), 4.0 * (1.0 - u))
	var flash: bool = not Settings.get_value("access/reduce_flashing")
	for m in impacts:
		var u: float = m.age / IMPACT_LIFE
		var col := Color(1.0, 0.95, 0.78, 0.9 * (1.0 - u))
		if flash: g.draw_circle(m.pos, m.r * 0.9 * (1.0 - u), Color(1.0, 1.0, 0.9, 0.35 * (1.0 - u)))
		for i in 10:
			var d := Vector2.from_angle(m.dir.angle() + i * TAU / 10.0)
			var reach := 1.6 if i == 0 || i == 1 || i == 9 else 1.0 #the spokes ahead reach further
			g.draw_line(m.pos + d * m.r * (0.6 + 0.8 * u), m.pos + d * m.r * (1.0 + 1.4 * u) * reach, col, 1.0 + 4.0 * (1.0 - u))
	for b in bitsList:
		g.draw_rect(Rect2(b.pos - Vector2.ONE * b.s / 2.0, Vector2.ONE * b.s), Color(b.col, 1.0 - b.age / b.life))
	if is_instance_valid(Root.spawnManager):
		var tt := Time.get_ticks_msec() / 1000.0
		for o in Root.spawnManager.goons:
			if is_instance_valid(o) && not o.dead && o.state == &"stun":
				for i in 3:
					var a := tt * 5.0 + i * TAU / 3.0
					var c: Vector2 = o.global_position + Vector2(cos(a) * o.bodyRadius * 0.9, -o.bodyRadius * 0.6 + sin(a) * o.bodyRadius * 0.35)
					g.draw_circle(c, 3.5, Color(0.95, 0.83, 0.37))
	#the HUD's bold face with an outline; each label pops a little bigger for its first 0.12 s
	var font: Font = HudTheme.BOLD
	for l in labels:
		var a: float = 1.0 - l.age / LABEL_LIFE
		var fontSize := int(l.size * (1.0 + 0.4 * maxf(0.0, 1.0 - l.age / 0.12)))
		g.draw_string_outline(font, l.pos + Vector2(-180, 0), l.text, HORIZONTAL_ALIGNMENT_CENTER, 360, fontSize, 6, Color(HudTheme.OUTLINE, 0.85 * a))
		g.draw_string(font, l.pos + Vector2(-180, 0), l.text, HORIZONTAL_ALIGNMENT_CENTER, 360, fontSize, Color(l.col, a))
