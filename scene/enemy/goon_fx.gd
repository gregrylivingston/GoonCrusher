class_name GoonFx extends Node2D
## Everything goons leave in the world besides themselves: telegraphs (the red ground marks before every
## threat), projectiles, hazards (fire, slime, oil, spikes), blasts, tethers, crush decals, bits, labels and
## delayed pickup drops. The SpawnManager owns one. Every list is capped, so a full pool just skips the
## effect, and everything is delta-based. Telegraphs, projectiles and fire draw unshaded, so night makes
## goons harder to see but never hides what they are about to do. docs/GOONS.md.

const MAX_DECALS := 64
const MAX_HAZARDS := 24
const MAX_PROJECTILES := 24
const MAX_TELEGRAPHS := 48
const MAX_BITS := 90
const MAX_LABELS := 12
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
var blasts: Array = []
var pendingBlasts: Array = []
var tethers: Array = []
var bitsList: Array = []
var labels: Array = []
var crumbs: Array = []
var drops: Array = []
var rings: Array = []
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
	#a tyre print: dark band with tread bars, laid across each crush decal along the car's heading
	var img := Image.create(32, 10, false, Image.FORMAT_RGBA8)
	for x in 32:
		for y in 10:
			img.set_pixel(x, y, Color(0.11, 0.09, 0.08, 0.75) if x % 4 > 1 else Color(0.32, 0.29, 0.25, 0.6))
	treadTexture = ImageTexture.create_from_image(img)

#--- the API the goons use ------------------------------------------------------------------------

func telegraph(owner: Walker, kind: String, duration: float, radius: float) -> void:
	if telegraphs.size() >= MAX_TELEGRAPHS: return
	telegraphs.push_back({"owner": weakref(owner), "kind": kind, "t": 0.0, "T": maxf(duration, 0.05), "r": radius, "pos": owner.lockPos})

func label(pos: Vector2, text: String) -> void:
	if labels.size() >= MAX_LABELS: labels.pop_front()
	labels.push_back({"pos": pos + Vector2(0, -30), "text": text, "age": 0.0})

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

func bits(pos: Vector2, faction: int) -> void:
	var cols = [[Color("#8a7050"), Color("#5b4636")], [Color("#9a8aa8"), ORANGE, Color("#3a3046")], [Color("#8d8f8c"), Color("#2aa6a1"), Color("#4a4c4f")]][clampi(faction, 0, 2)]
	for i in 7:
		if bitsList.size() >= MAX_BITS: return
		var v := Vector2.from_angle(randf() * TAU) * randf_range(120.0, 340.0)
		bitsList.push_back({"pos": pos, "vel": v, "age": 0.0, "life": randf_range(0.5, 0.9), "col": cols[i % cols.size()], "s": randf_range(2.5, 5.0)})

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

func shoot(pos: Vector2, dir: Vector2, speed: float, life: float, dmg: float, sys: String, kind: String) -> void:
	if projectiles.size() >= MAX_PROJECTILES: return
	projectiles.push_back({"kind": kind, "pos": pos, "vel": dir * speed, "t": 0.0, "life": life, "dmg": dmg, "sys": sys})

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
## behind them. Goons it kills count as crushes. Explosive props in reach go off in turn (BreakableProp).
func blast(pos: Vector2, r: float, dmg: float) -> void:
	blasts.push_back({"pos": pos, "r": r, "age": 0.0})
	label(pos, "BOOM")
	var car = Root.playerCar
	if is_instance_valid(car) && car.global_position.distance_to(pos) < r + 40.0 && WorldHooks.lineClear(pos, car.global_position):
		car.damage(dmg)
		if car.has_method("wearSystem"): car.wearSystem("engine", dmg * 2.0)
	for o in Root.spawnManager.goonsNear(pos, r):
		if not o.dead && WorldHooks.lineClear(pos, o.global_position):
			o.destroy(&"boom")
			Root.spawnManager.creditCrush(o.global_position, o)
	if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("explode"): Root.levelRoot.explode(pos) #pooled, at most 16 live
	if is_inside_tree(): BreakableProp.blastAt(get_tree(), pos, r) #barrels and tanks: a hop per CHAIN_DELAY, each once

func blastLater(pos: Vector2, delay: float, r: float, dmg: float) -> void:
	pendingBlasts.push_back({"pos": pos, "t": delay, "r": r, "dmg": dmg})

#--- simulation -------------------------------------------------------------------------------------

func insideCar(car: Node2D, p: Vector2, pad := 0.0) -> bool:
	var l: Vector2 = car.to_local(p)
	return absf(l.x) < CAR_HALF.x + pad && absf(l.y) < CAR_HALF.y + pad

func hurtCar(car: Node2D, dmg: float, sys: String) -> void:
	car.damage(dmg)
	if sys != "hull" && car.has_method("wearSystem"): car.wearSystem(sys, dmg * 3.0)

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
	for h in hazards.duplicate():
		h.age += delta
		h.cd = maxf(0.0, h.cd - delta)
		if h.age > h.life:
			hazards.erase(h)
			continue
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
			blast(b.pos, b.r, b.dmg)
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
		if l.age > 1.1: labels.erase(l)
	for c in crumbs.duplicate():
		c.age += delta
		if c.age > 1.2: crumbs.erase(c)
	for r in rings.duplicate():
		r.age += delta
		if r.age > r.life: rings.erase(r)
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
	for h in hazards:
		var fade: float = clampf((h.life - h.age) * 2.0, 0.0, 1.0)
		match h.kind:
			"fire":
				g.draw_circle(h.pos, h.r, Color(0.12, 0.08, 0.04, 0.35 * fade))
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
			if o.isBuffed(): g.draw_circle(o.global_position, o.bodyRadius * 1.3, Color(ORANGE, 0.28))
			if o.def.get("shield", false) && (o.state == &"move" || o.state == &"windup") && o.facing(Root.playerCar):
				var a: float = o.rotation
				g.draw_arc(o.global_position + Vector2.from_angle(a) * o.bodyRadius * 1.1, 14.0, a - 1.1, a + 1.1, 8, Color(1, 1, 0.94, 0.45 + 0.35 * sin(Time.get_ticks_msec() / 125.0)), 3.0)
			if o.state == &"buried" && o.global_position.distance_to(carPos) < 260.0:
				g.draw_arc(o.global_position, 26.0, 0.0, TAU, 24, tele(0.45), 2.0)

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
		var a: float = 1.0 - l.age / 1.1
		var fontSize := int(18.0 + 7.0 * maxf(0.0, 1.0 - l.age / 0.12))
		g.draw_string_outline(font, l.pos + Vector2(-90, 0), l.text, HORIZONTAL_ALIGNMENT_CENTER, 180, fontSize, 6, Color(HudTheme.OUTLINE, 0.85 * a))
		g.draw_string(font, l.pos + Vector2(-90, 0), l.text, HORIZONTAL_ALIGNMENT_CENTER, 180, fontSize, Color(HudTheme.TEXT, a))
