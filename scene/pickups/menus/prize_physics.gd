class_name PrizePhysics extends RefCounted

#A small position-based physics sim for the prize games that need loose objects (Pachinko Drop, Coin
#Pusher; docs/PICKUPS.md, "Prize games"): circles that fall, bounce a little, collide with one another and
#with segments, and come to rest only while something holds them up, so a heap neither jitters nor floats.
#Segments are [a, b, width, moveA, moveB] in stage space; moveA and moveB are how far each end moved this
#step (zero for static ones), so a moving segment (a pusher shelf) carries what it touches. A zero-length
#segment is a round peg. The game owns the bodies' extra fields (id, value...); step() only reads pos,
#prev, r, m and writes pos, prev, rot, held.

const MAX_MOVE := 8.0      #px per step at most, so a squeeze never launches anything
const REST := 0.06         #px per step: a supported body slower than this comes to rest

var bodies: Array = []
var gravity := 1500.0      #px/s²
var iterations := 4
var friction := 0.35       #share of sliding taken off at a contact
var bounce := 0.0          #restitution off segments, 0..1
var scatter := 0.0         #px of random sideways kick per bounce off a peg (luck, Pachinko)
var damp := 0.999
var left := 0.0            #walls; bodies are kept between them
var right := 640.0
var maxR := 24.0           #the largest radius, for the sweep

func add(at: Vector2, r: float, m := 1.0) -> Dictionary:
	var b := {"pos": at, "prev": at, "r": r, "m": m, "rot": randf_range(-0.3, 0.3), "held": false}
	bodies.push_back(b)
	maxR = maxf(maxR, r)
	return b

## Gives a body a velocity (px/s) for steps of `dt`
static func setVelocity(b: Dictionary, v: Vector2, dt: float) -> void:
	b.prev = b.pos - v * dt

static func velocity(b: Dictionary, dt: float) -> Vector2:
	return (b.pos - b.prev) / dt

func step(dt: float, segs: Array) -> void:
	for b in bodies:
		b.held = false
		var v: Vector2 = ((b.pos - b.prev) * damp).limit_length(MAX_MOVE)
		b.prev = b.pos
		b.pos += v + Vector2(0, gravity * dt * dt)
	bodies.sort_custom(func(a, c): return a.pos.x < c.pos.x) #sweep: only neighbors along x can touch
	for k in iterations:
		for i in bodies.size():
			var reach: float = bodies[i].pos.x + bodies[i].r + maxR
			for j in range(i + 1, bodies.size()):
				if bodies[j].pos.x > reach: break
				pair(bodies[i], bodies[j])
		for b in bodies:
			for s in segs: pushOut(b, s, k == 0)
			b.pos.x = clampf(b.pos.x, left + b.r, right - b.r)
	for b in bodies:
		var moved: Vector2 = b.pos - b.prev
		if b.held && moved.length() < REST: b.prev = b.pos
		elif absf(moved.x) > REST * 4.0: b.rot = clampf(b.rot + moved.x / b.r * 0.25, -0.6, 0.6)

func pair(a: Dictionary, b: Dictionary) -> void:
	var d: Vector2 = b.pos - a.pos
	var reach: float = a.r + b.r
	var dist := d.length()
	if dist >= reach || dist < 0.0001: return
	var n := d / dist
	if n.y > 0.4: a.held = true
	elif n.y < -0.4: b.held = true
	var total: float = a.m + b.m
	a.pos -= n * (reach - dist) * b.m / total
	b.pos += n * (reach - dist) * a.m / total

## Pushes a body out of a segment [a, b, width, moveA, moveB]; bounce and scatter apply once a step
func pushOut(body: Dictionary, s: Array, first: bool) -> void:
	var a: Vector2 = s[0]
	var ab: Vector2 = s[1] - a
	var len2 := ab.length_squared()
	var u := clampf((body.pos - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.0001 else 0.0
	var d: Vector2 = body.pos - (a + ab * u)
	var dist := d.length()
	var reach: float = body.r + s[2]
	if dist >= reach: return
	var n := d / dist if dist > 0.0001 else (Vector2(-ab.y, ab.x).normalized() if len2 > 0.0001 else Vector2.UP)
	body.pos += n * (reach - dist)
	if n.y < -0.4: body.held = true
	var segMove: Vector2 = (s[3] as Vector2).lerp(s[4], u) if s.size() > 4 else Vector2.ZERO
	var v: Vector2 = (body.pos - body.prev) - segMove
	var vn := v.dot(n)
	var slide := v - n * vn
	var out := slide * (1.0 - friction)
	if first && vn < 0.0 && bounce > 0.0: #moving into it: reflect part of that
		out -= n * vn * bounce
		if scatter > 0.0 && len2 < 0.0001: out += Vector2(-n.y, n.x) * randf_range(-scatter, scatter) * 0.01
	elif vn > 0.0: out += n * vn
	body.prev = body.pos - out - segMove
