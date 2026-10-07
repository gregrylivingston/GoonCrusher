class_name TransitionFx extends Node2D

#The grit for transitions (docs/UI.md, "Transitions"): soft puffs (dust, tire smoke, exhaust),
#falling chips and rubber skid marks, drawn in screen space by one node. Puffs scale with Exhaust
#Smoke (gfx/smoke) and marks with Tire Marks (gfx/tire_marks); Reduce Motion turns both off.
#Runs while the tree is paused, and frees itself once everything has faded if `autoFree`.

const DUST := Color(0.59, 0.52, 0.44)
const SMOKE := Color(0.78, 0.75, 0.69)
const DARK := Color(0.29, 0.27, 0.25)
const CHIPS := [Color("6b5f55"), Color("8a6a45")]

static var puffTexture: GradientTexture2D

var puffs: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var autoFree := true

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func ensureTexture() -> void:
	if puffTexture: return
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	puffTexture = GradientTexture2D.new()
	puffTexture.gradient = gradient
	puffTexture.fill = GradientTexture2D.FILL_RADIAL
	puffTexture.fill_from = Vector2(0.5, 0.5)
	puffTexture.fill_to = Vector2(1.0, 0.5)
	puffTexture.width = 64
	puffTexture.height = 64

#0 with smoke off or Reduce Motion, 0.4 on Low, 1 on Full: multiply puff counts by this
static func smokeAmount() -> float:
	if Settings.reduce_motion(): return 0.0
	return [0.0, 0.4, 1.0][clampi(Settings.get_value("gfx/smoke"), 0, 2)]

static func marksOn() -> bool:
	return not Settings.reduce_motion() && Settings.get_value("gfx/tire_marks") > 0

static func count(full: int) -> int:
	return int(round(full * smokeAmount()))

func puff(at: Vector2, velocity: Vector2, color: Color, life := 1.0, r0 := 10.0, r1 := 60.0, alpha := 0.55, delay := 0.0, drag := 2.2, gravity := 0.0) -> void:
	puffs.push_back({"p": at, "v": velocity, "c": color, "life": life, "r0": r0, "r1": r1, "a": alpha, "age": -delay, "drag": drag, "g": gravity, "chip": false})

func chip(at: Vector2, velocity: Vector2) -> void:
	puffs.push_back({"p": at, "v": velocity, "c": CHIPS[randi() % 2], "life": 0.62, "r0": randf_range(3, 6), "r1": 0.0, "a": 1.0, "age": 0.0, "drag": 0.0, "g": 1100.0, "chip": true, "spin": randf_range(-12, 12)})

#the dust a slammed door kicks up along its rail, with chips flying off
func dustLine(x0: float, x1: float, y: float, full := 24, chipCount := 10, spread := 320.0) -> void:
	for i in count(full):
		puff(Vector2(lerpf(x0, x1, randf()), y - randf() * 6), Vector2(randf_range(-0.5, 0.5) * spread, -(30 + randf() * 120)), DUST, randf_range(0.7, 1.3), 8, 46 + randf() * 50, 0.55, randf() * 0.04, 2.4, 40)
	if smokeAmount() > 0.0:
		for i in chipCount: chip(Vector2(lerpf(x0, x1, randf()), y - 8), Vector2(randf_range(-120, 120), -160 - randf() * 220))

#tire smoke from one point, pushed along `push`
func burst(at: Vector2, full: int, push := Vector2.ZERO, spread := 170.0, size := 110.0, life := 1.1, delay := 0.0) -> void:
	for i in count(full):
		puff(at + Vector2(randf_range(-10, 10), randf_range(-6, 6)), push + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)) * spread, DARK if randf() < 0.2 else SMOKE, life + randf() * 0.4, 16, size + randf() * size * 0.8, 0.65, delay + randf() * 0.05, 1.5)

#a wall of tire smoke over the whole screen, built up over `buildUp` seconds: big overlapping puffs
#on a jittered grid, so it reads as one cloud rather than separate blobs
func smokeWall(screen: Vector2, buildUp := 0.3, life := 2.0) -> void:
	var columns = 7
	var rows = 4
	var cell = Vector2(screen.x / columns, screen.y / rows)
	for y in rows:
		for x in columns:
			if randf() > maxf(smokeAmount(), 0.35 if smokeAmount() > 0.0 else 0.0): continue
			var at = Vector2((x + randf_range(0.1, 0.9)) * cell.x, (y + randf_range(0.1, 0.9)) * cell.y)
			puff(at, Vector2(randf_range(-60, 60), randf_range(-40, 10)), DARK if randf() < 0.3 else SMOKE, life + randf() * 0.6, 60, 300 + randf() * 120, 0.72, randf() * buildUp, 1.2)

#a rubber strip on the ground that fades out between `fadeFrom` and `fadeTo` seconds
func mark(from: Vector2, to: Vector2, width := 8.0, fadeFrom := 0.4, fadeTo := 1.0) -> void:
	if not marksOn(): return
	marks.push_back({"a": from, "b": to, "w": width, "age": 0.0, "f0": fadeFrom, "f1": fadeTo})

func _process(delta: float) -> void:
	for p in puffs:
		p.age += delta
		if p.age <= 0.0: continue
		if p.drag > 0.0: p.v *= exp(-p.drag * delta)
		p.v.y += p.g * delta
		p.p += p.v * delta
		if p.chip: p.r1 += p.spin * delta #r1 doubles as the chip's angle
	puffs = puffs.filter(func(p): return p.age < p.life)
	for m in marks: m.age += delta
	marks = marks.filter(func(m): return m.age < m.f1)
	queue_redraw()
	if autoFree && puffs.is_empty() && marks.is_empty(): queue_free()

func _draw() -> void:
	ensureTexture()
	for m in marks:
		var fade = 1.0 - clampf((m.age - m.f0) / maxf(0.01, m.f1 - m.f0), 0.0, 1.0)
		draw_line(m.a, m.b, Color(0.08, 0.06, 0.055, 0.8 * fade), m.w)
		draw_dashed_line(m.a, m.b, Color(0.23, 0.19, 0.16, 0.5 * fade), m.w * 0.7, 6.0)
	for p in puffs:
		if p.age <= 0.0: continue
		var k = p.age / p.life
		if p.chip:
			draw_set_transform(p.p, p.r1)
			draw_rect(Rect2(-p.r0 / 2.0, -p.r0 / 3.0, p.r0, p.r0 * 0.66), Color(p.c, 1.0 - k * k))
			draw_set_transform(Vector2.ZERO)
			continue
		var r = lerpf(p.r0, p.r1, 1.0 - pow(1.0 - k, 3.0))
		var a = p.a * minf(1.0, p.age / 0.07) * pow(1.0 - k, 1.5)
		draw_texture_rect(puffTexture, Rect2(p.p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(p.c, a))
