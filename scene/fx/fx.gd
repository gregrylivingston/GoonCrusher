class_name Fx extends Node2D
## The run's effects, by event (docs/roadmap/ROADMAP_JUICE.md). The level owns one (Level.fx) and callers name
## what happened and how big it was; what that looks, sounds and feels like is decided here.
##   blast(pos, size)  everything round an explosion's fireball (ExplosionPool draws that): a flash, a shockwave
##                     ring, flames, flung debris, a smoke column that hangs, embers, a scorch mark on the
##                     ground, the boom, and a camera shake and pad rumble that fall off with distance.
##   scorch(pos, r)    a burn mark left on the ground; it fades after SCORCH_LIFE.
##   sparks(pos, ...)  a burst of hot streaks (a wall hit, a scrape, two cars meeting)
##   burn(pos, r, dt)  a frame of a fire of radius `r`: flames, embers and smoke. Call it every frame the
##                     fire burns; false at Minimal, when the caller draws its own plain fire.
##   splash(pos, k)    something went into water: ripples, a crown of droplets and foam, sized by `k`
## It owns the screen layer (ScreenFx: flashes, the hurt edge, speed streaks) and the heat: 0 to 1 from the
## player's Crush Combo, which effects scale by (Fx.heatNow), so the game gets louder as a run goes well.
## Show only: it has its own random numbers and never touches the car, goons or rewards. Blast Effects
## (gfx/blast_fx) sizes it (Minimal: the scorch and the boom only); Reduce Flashing drops the flash and Screen
## Shake scales the shake (CrushFeel). Flames, embers and the ring draw unshaded, so they show at night.

enum Size { POP, BLAST, BIG }
## Per Size: `core` scales the fireball, `ring` is the shockwave's reach (world px), `scorch` the burn mark's
## radius, `reach` the distance at which the shake and the boom die away.
const BLAST := [
	{"core": 0.6, "ring": 110.0, "smoke": 4, "flames": 6, "debris": 4, "embers": 5, "scorch": 42.0, "trauma": 0.15, "reach": 800.0, "pitch": 1.35},
	{"core": 1.0, "ring": 210.0, "smoke": 9, "flames": 12, "debris": 10, "embers": 10, "scorch": 80.0, "trauma": 0.35, "reach": 1300.0, "pitch": 1.0},
	{"core": 1.7, "ring": 360.0, "smoke": 16, "flames": 20, "debris": 18, "embers": 16, "scorch": 135.0, "trauma": 0.7, "reach": 2000.0, "pitch": 0.72},
]
const AMOUNT := [0.0, 0.5, 1.0]  #share of the particles, by Blast Effects
const POOLS := [[0, 0, 0, 24], [72, 96, 128, 64], [144, 192, 256, 128]] #[smoke and debris, blast flames and embers, fire, sparks], by Blast Effects
const SPARK := Color(1.0, 0.75, 0.35)
const FLAMES_PER_SECOND := 60.0  #for a fire FIRE_SIZE across, at Full
const FIRE_SIZE := 40.0
const RIPPLE_LIFE := 0.9
const MAX_RIPPLES := 24
const WATER := Color(0.82, 0.93, 1.0)
const FLASH_NEAR := 0.6          #screen flash of a blast on top of the car, times its trauma
const RING_LIFE := 0.32
const FLASH_LIFE := 0.1
const MAX_SCORCH := 40
const SCORCH_LIFE := 50.0
const SCORCH_FADE := 8.0         #seconds a mark takes to go, at the end of its life
const SMOKE_Z := 7               #over goons and the car, under the canopies (PropReactions.CANOPY_Z)
const BOOM := preload("res://sound/fx/explosion/explosion-6055.mp3")
const BOOM_QUIET_DB := -22.0     #at the edge of `reach`

var smoke: FxParticles
var glow: FxParticles
var fire: FxParticles
var streaks: FxParticles
var screen: ScreenFx
var heat := 0.0                  #0 to 1 from the player's Crush Combo (ScreenFx keeps it)
var ripples: Array[Dictionary] = []
var ground := Node2D.new()
var top := Node2D.new()
var rings: Array[Dictionary] = []
var flashes: Array[Dictionary] = []
var scorches: Array[Dictionary] = []
var scorchRedraw := 0.0
var amount := 1.0
var rng := RandomNumberGenerator.new() #its own, so show-only rolls never move the game's random numbers

func _init() -> void:
	name = "Fx"
	var lit := CanvasItemMaterial.new()
	lit.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	smoke = FxParticles.new(false, SMOKE_Z)
	glow = FxParticles.new(false, SMOKE_Z)
	glow.material = lit
	fire = FxParticles.new(false, SMOKE_Z)
	fire.material = lit
	streaks = FxParticles.new(true, SMOKE_Z)
	streaks.material = lit
	top.material = lit
	top.z_index = SMOKE_Z
	ground.z_index = -1 #on the ground, with the tire marks
	screen = ScreenFx.new(self)
	for n in [ground, smoke, glow, fire, streaks, top, screen]: add_child(n)
	ground.draw.connect(drawGround)
	top.draw.connect(drawTop)

func _ready() -> void:
	readSettings()
	Settings.changed.connect(onSettingChanged)

func onSettingChanged(key: String, _value) -> void:
	if key == "gfx/blast_fx": readSettings()

func readSettings() -> void:
	var level := clampi(Settings.get_value("gfx/blast_fx"), 0, AMOUNT.size() - 1)
	amount = AMOUNT[level]
	smoke.resize(POOLS[level][0])
	glow.resize(POOLS[level][1])
	fire.resize(POOLS[level][2])
	streaks.resize(POOLS[level][3])

#--- events -----------------------------------------------------------------------------------------

## Everything round an explosion at `pos` but its fireball
func blast(pos: Vector2, blastSize: int = Size.BLAST) -> void:
	var b: Dictionary = BLAST[clampi(blastSize, 0, BLAST.size() - 1)]
	scorch(pos, b.scorch)
	feel(pos, b)
	if amount <= 0.0: return
	var ring: float = b.ring
	rings.push_back({"pos": pos, "r": ring, "age": 0.0})
	if not Settings.get_value("access/reduce_flashing"): flashes.push_back({"pos": pos, "r": ring * 1.8, "age": 0.0})
	for i in count(b.flames):
		var dir := away()
		glow.spawn(pos + dir * rng.randf_range(0.0, ring * 0.2), dir * rng.randf_range(0.6, 2.4) * ring, rng.randf_range(0.25, 0.55), rng.randf_range(0.14, 0.26) * ring, Color(1.0, rng.randf_range(0.6, 0.85), 0.3, 0.9), FxParticles.Kind.FLAME)
	for i in count(b.smoke):
		var dir := away()
		var gray := rng.randf_range(0.1, 0.3)
		smoke.spawn(pos + dir * rng.randf_range(0.0, ring * 0.3), dir * rng.randf_range(0.2, 0.9) * ring, rng.randf_range(1.4, 2.8), rng.randf_range(0.16, 0.3) * ring, Color(gray, gray, gray * 1.05, 0.7), FxParticles.Kind.SMOKE)
	for i in count(b.debris):
		var shade := rng.randf_range(0.08, 0.25)
		smoke.spawn(pos, away() * rng.randf_range(1.2, 3.6) * ring, rng.randf_range(0.5, 0.95), rng.randf_range(2.5, 6.0), Color(shade * 1.3, shade, shade * 0.8), FxParticles.Kind.DEBRIS)
	for i in count(b.embers):
		glow.spawn(pos, away() * rng.randf_range(0.4, 1.6) * ring, rng.randf_range(0.8, 1.9), rng.randf_range(1.5, 3.2), Color(1.0, rng.randf_range(0.45, 0.8), 0.2), FxParticles.Kind.EMBER)
	set_process(true)

## A burn mark of radius `r` on the ground
func scorch(pos: Vector2, r: float) -> void:
	if scorches.size() >= MAX_SCORCH: scorches.pop_front()
	scorches.push_back({"pos": pos, "r": r, "age": 0.0, "turn": rng.randf() * TAU})
	ground.queue_redraw()
	set_process(true)

## A burst of `count` hot streaks at `pos`: along `dir` (within `spread` rad of it), or all round without one
func sparks(pos: Vector2, dir := Vector2.ZERO, count := 8, color := SPARK, speed := 380.0, spread := 0.9) -> void:
	for i in ceili(count * (1.0 + heat)):
		var d := away() if dir == Vector2.ZERO else dir.rotated(rng.randf_range(-spread, spread))
		streaks.spawn(pos, d * speed * rng.randf_range(0.4, 1.3), rng.randf_range(0.18, 0.42), rng.randf_range(1.5, 3.2), color)

## A frame of a fire of radius `r` at `pos`. False when nothing is drawn (Blast Effects Minimal).
func burn(pos: Vector2, r: float, delta: float) -> bool:
	if amount <= 0.0: return false
	var want := FLAMES_PER_SECOND * (r / FIRE_SIZE) * amount * delta
	for i in int(want) + (1 if rng.randf() < fmod(want, 1.0) else 0):
		var at := pos + away() * r * 0.8 * sqrt(rng.randf())
		var s := clampf(r * rng.randf_range(0.28, 0.5), 7.0, 46.0)
		fire.spawn(at, Vector2(rng.randf_range(-14.0, 14.0), -rng.randf_range(25.0, 70.0)), rng.randf_range(0.3, 0.6), s, Color(1.0, rng.randf_range(0.62, 0.9), 0.3, 0.8), FxParticles.Kind.FLAME)
		if rng.randf() < 0.1: fire.spawn(at, Vector2(rng.randf_range(-30.0, 30.0), -rng.randf_range(50.0, 130.0)), rng.randf_range(0.7, 1.5), rng.randf_range(1.2, 2.6), Color(1.0, 0.6, 0.2), FxParticles.Kind.EMBER)
		if rng.randf() < 0.07:
			var gray := rng.randf_range(0.1, 0.22)
			smoke.spawn(at + Vector2(0.0, -r * 0.5), Vector2(rng.randf_range(-10.0, 10.0), -rng.randf_range(15.0, 40.0)), rng.randf_range(1.2, 2.2), s * 0.9, Color(gray, gray, gray, 0.5), FxParticles.Kind.SMOKE)
	return true

## Something went into the water at `pos`: `k` is its size, about 0.3 (a goon) to 2 (the car at speed).
## `color` tints it (a lava landscape's embers).
func splash(pos: Vector2, k := 1.0, color := WATER) -> void:
	if amount <= 0.0: return
	if ripples.size() >= MAX_RIPPLES: ripples.pop_front()
	ripples.push_back({"pos": pos, "r": 70.0 + 70.0 * k, "age": 0.0, "col": color})
	for i in count(int(10.0 + 12.0 * k)): #the crown: droplets thrown up and out
		smoke.spawn(pos, away() * rng.randf_range(90.0, 260.0) * (0.6 + 0.4 * k), rng.randf_range(0.4, 0.8), rng.randf_range(2.0, 4.5), Color(color, 0.9), FxParticles.Kind.DEBRIS)
	for i in count(int(4.0 + 5.0 * k)): #the foam it leaves
		smoke.spawn(pos + away() * rng.randf_range(0.0, 30.0 * k), away() * rng.randf_range(10.0, 50.0), rng.randf_range(0.8, 1.5), rng.randf_range(10.0, 18.0) * (0.7 + 0.3 * k), Color(color, 0.5), FxParticles.Kind.PUFF)
	ground.queue_redraw()
	set_process(true)

## The heat of the current level, 0 without one (the menu, tests)
static func heatNow() -> float:
	var fx := current()
	return fx.heat if fx else 0.0

## The current level's Fx, or null (the menu, tests)
static func current() -> Fx:
	var level = Root.levelRoot
	if not is_instance_valid(level): return null
	return level.get("fx") as Fx

## The boom, and the shake and rumble on the player's car, all falling off to nothing at the blast's reach
func feel(pos: Vector2, b: Dictionary) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var near := nearness(car.global_position.distance_to(pos), b.reach)
	if near <= 0.0: return
	Audio.play(BOOM, lerpf(BOOM_QUIET_DB, 0.0, near), b.pitch * rng.randf_range(0.92, 1.08))
	var crushFeel = car.get("crushFeel")
	if is_instance_valid(crushFeel): crushFeel.addTrauma(b.trauma * near)
	Settings.vibrate(0.5 * near, near, 0.15 + 0.3 * b.trauma)
	screen.flash(FLASH_NEAR * near * near * (0.4 + b.trauma))

## 1 at a blast's center, 0 at `reach` and beyond; it falls away faster near the edge
static func nearness(distance: float, reach: float) -> float:
	var n := clampf(1.0 - distance / maxf(reach, 1.0), 0.0, 1.0)
	return n * (2.0 - n)

func count(full: int) -> int:
	return ceili(full * amount)

func away() -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU)

#--- each frame -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	for list in [rings, flashes, scorches, ripples]:
		for e in list: e.age += delta
	var rippled := not ripples.is_empty()
	ripples = ripples.filter(func(e): return e.age < RIPPLE_LIFE)
	rings = rings.filter(func(e): return e.age < RING_LIFE)
	flashes = flashes.filter(func(e): return e.age < FLASH_LIFE)
	var marks := scorches.size()
	scorches = scorches.filter(func(e): return e.age < SCORCH_LIFE)
	top.queue_redraw()
	#the marks only change while one fades: a redraw four times a second is enough for that
	scorchRedraw -= delta
	if scorches.size() != marks || scorchRedraw <= 0.0 || rippled:
		scorchRedraw = 0.25
		ground.queue_redraw()
	if rings.is_empty() && flashes.is_empty() && scorches.is_empty() && ripples.is_empty(): set_process(false)

func drawGround() -> void:
	var tex := FxParticles.cloud()
	for s in scorches:
		var a: float = clampf((SCORCH_LIFE - s.age) / SCORCH_FADE, 0.0, 1.0)
		var r: float = s.r
		ground.draw_set_transform(s.pos, s.turn)
		ground.draw_texture_rect(tex, Rect2(-r * 1.3, -r * 1.3, r * 2.6, r * 2.6), false, Color(0.05, 0.04, 0.03, 0.55 * a))
		ground.draw_texture_rect(FxParticles.SOFT, Rect2(-r * 0.7, -r * 0.7, r * 1.4, r * 1.4), false, Color(0.0, 0.0, 0.0, 0.6 * a))
	ground.draw_set_transform(Vector2.ZERO)
	for e in ripples: #two rings, the second a beat behind
		for lag in [0.0, 0.25]:
			var u: float = e.age / RIPPLE_LIFE - lag
			if u <= 0.0: continue
			ground.draw_arc(e.pos, e.r * (0.2 + 0.8 * sqrt(u)), 0.0, TAU, 36, Color(e.col, 0.6 * (1.0 - u) * (1.0 - lag)), 2.0 + 4.0 * (1.0 - u))

func drawTop() -> void:
	for f in flashes:
		var u: float = f.age / FLASH_LIFE
		var r: float = f.r
		top.draw_texture_rect(FxParticles.SOFT, Rect2(f.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.95, 0.8, 0.9 * (1.0 - u)))
	for e in rings:
		var u: float = e.age / RING_LIFE
		var r: float = e.r * (0.25 + 0.75 * (1.0 - (1.0 - u) * (1.0 - u))) #fast out, then slowing
		top.draw_arc(e.pos, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.7, 0.7 * (1.0 - u)), 3.0 + 14.0 * (1.0 - u))
