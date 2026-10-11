class_name FxParticles extends Node2D
## A ring of particles in world space, drawn by one node: the one particle kit of the run's effects (CarJuice,
## PropReactions, Fx). A full ring overwrites its oldest particle, so a caller never checks for room. How a
## particle moves and draws is its Kind:
##   PUFF    a soft dot that grows, slows and fades (dust, tire smoke)
##   BITS    a dot that flies and fades (clods, chips)
##   SPRAY   the same, for water
##   SMOKE   a billowing cloud that swells, turns and drifts with `wind`
##   FLAME   a soft dot that shrinks and cools from its color to a dark red (for an additive node)
##   EMBER   a small flickering dot (for an additive node)
##   DEBRIS  a spinning chip thrown in an arc
## A `streaks` node draws every particle as a short line along its travel instead (sparks).
## Show only, delta-based, and idle (no _process) while nothing is alive.

enum Kind { PUFF, BITS, SPRAY, SMOKE, FLAME, EMBER, DEBRIS }
const DRAG := [3.0, 1.5, 1.5, 2.2, 2.5, 1.2, 1.8] #share of its speed a particle loses a second, by Kind
const COOL := Color(0.7, 0.12, 0.03)  #what a flame cools to
const DEBRIS_ARC := 7.0               #a chip rises this many times its size at the top of its arc

static var SOFT := softDot() #white, fading to clear at the rim
static var cloudTex: ImageTexture

var streaks := false
var wind := Vector2(14.0, -20.0) #world px/s the smoke drifts
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var size := PackedFloat32Array()
var col := PackedColorArray()
var kind := PackedByteArray()
var next := 0
var alive := 0

static func softDot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

## A lumpy white cloud, clear at the rim: a soft core with six lobes round it. Built once.
static func cloud() -> ImageTexture:
	if cloudTex: return cloudTex
	const N := 64
	var lobes: Array[Vector3] = [Vector3(0.5, 0.5, 0.36)] #x, y, radius, in texture shares
	for i in 6:
		var a := i * TAU / 6.0 + 0.4
		lobes.push_back(Vector3(0.5 + cos(a) * 0.22, 0.5 + sin(a) * 0.22, 0.2 + 0.05 * (i % 3)))
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var p := Vector2(x + 0.5, y + 0.5) / N
			var clear := 1.0
			for l in lobes:
				clear *= 1.0 - 0.8 * smoothstep(l.z, l.z * 0.3, p.distance_to(Vector2(l.x, l.y)))
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 - clear))
	cloudTex = ImageTexture.create_from_image(img)
	return cloudTex

func _init(isStreaks: bool, z: int) -> void:
	streaks = isStreaks
	top_level = true
	z_as_relative = false
	z_index = z
	set_process(false)

func resize(n: int) -> void:
	pos.resize(n)
	vel.resize(n)
	age.resize(n)
	life.resize(n)
	size.resize(n)
	col.resize(n)
	kind.resize(n)
	life.fill(0.0)
	age.fill(0.0)
	next = 0
	alive = 0
	queue_redraw()

func spawn(at: Vector2, v: Vector2, seconds: float, s: float, c: Color, k := 0) -> void:
	var n := pos.size()
	if n == 0: return
	if life[next] <= 0.0: alive += 1
	pos[next] = at
	vel[next] = v
	age[next] = 0.0
	life[next] = seconds
	size[next] = s
	col[next] = c
	kind[next] = k
	next = (next + 1) % n
	set_process(true)

func _process(delta: float) -> void:
	for i in pos.size():
		if life[i] <= 0.0: continue
		age[i] += delta
		if age[i] >= life[i]:
			life[i] = 0.0
			alive -= 1
			continue
		var k := kind[i]
		pos[i] += vel[i] * delta
		if k == Kind.SMOKE: pos[i] += wind * delta * (age[i] / life[i])
		vel[i] *= 1.0 - minf(DRAG[k] * delta, 1.0)
	queue_redraw()
	if alive <= 0:
		alive = 0
		set_process(false)

func _draw() -> void:
	var turned := false
	for i in pos.size():
		if life[i] <= 0.0: continue
		var t := age[i] / life[i]
		var c := col[i]
		if streaks:
			c.a = 1.0 - t
			draw_line(pos[i], pos[i] - vel[i] * 0.03, c, size[i])
			continue
		match kind[i]:
			Kind.PUFF:
				c.a *= (1.0 - t) * minf(t * 6.0, 1.0)
				var r := size[i] * (1.0 + 2.0 * t)
				draw_texture_rect(SOFT, Rect2(pos[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
			Kind.SMOKE:
				c.a *= pow(1.0 - t, 1.5) * minf(t * 8.0, 1.0)
				var r := size[i] * (1.0 + 2.2 * t)
				draw_set_transform(pos[i], i * 1.7 + t * (0.7 if i % 2 == 0 else -0.7))
				draw_texture_rect(cloud(), Rect2(-r, -r, r * 2.0, r * 2.0), false, c)
				turned = true
			Kind.FLAME:
				var a := c.a * (1.0 - t)
				c = c.lerp(COOL, t)
				c.a = a
				var r := size[i] * (1.0 - 0.6 * t)
				if turned: draw_set_transform(Vector2.ZERO)
				turned = false
				draw_texture_rect(SOFT, Rect2(pos[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, c)
			Kind.EMBER:
				c.a *= (1.0 - t) * (0.65 + 0.35 * sin(age[i] * 30.0 + i))
				if turned: draw_set_transform(Vector2.ZERO)
				turned = false
				draw_circle(pos[i], size[i], c)
			Kind.DEBRIS:
				var lift := sin(PI * t)
				var s := size[i] * (1.0 + 0.8 * lift)
				c.a *= minf((1.0 - t) * 4.0, 1.0)
				draw_set_transform(pos[i] - Vector2(0.0, lift * size[i] * DEBRIS_ARC), age[i] * 12.0 + i)
				draw_rect(Rect2(-s, -s * 0.6, s * 2.0, s * 1.2), c)
				turned = true
			_:
				c.a *= 1.0 - t * t
				if turned: draw_set_transform(Vector2.ZERO)
				turned = false
				draw_circle(pos[i], size[i] * (1.0 - 0.4 * t), c)
	if turned: draw_set_transform(Vector2.ZERO)
