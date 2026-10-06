class_name CarBuffFx extends Node2D

#What the car's timed pickups look like, and the ones that act every tick (Magnet, Fire Trail,
#Wrecking Ball, Hot Potato, Shortcut Map). A child of the player's car: it draws in the car's space
#(+x is forward), and its `world` child draws in world space (fire, the ball and chain, route arrows).
#It only processes while something needs it.

const HALF := Vector2(105, 46) #the car's footprint, as in GoonFx
const FIRE_LIFE := 3.0
const FIRE_EVERY := 5          #ticks between fire points while moving
const FIRE_RADIUS := 55.0
const MAX_FIRE := 48
const CHAIN := 170.0
const BALL_RADIUS := 34.0
const GOLD := Color(1.0, 0.8, 0.25)

var car
var world := Node2D.new()
var fire: Array = []           #{pos, age}
var ball := Vector2.ZERO
var ballPrev := Vector2.ZERO
var route := PackedVector2Array()
var routeTimer := 0.0
var shieldFlashMs := 0
var floodLight: PointLight2D
var tick := 0
var baseSpriteScale := Vector2.ONE

func _ready() -> void:
	car = get_parent()
	baseSpriteScale = car.get_node("sprite").scale
	z_index = 1
	world.top_level = true
	world.z_index = 0
	world.draw.connect(drawWorld)
	add_child(world)
	updateProcessing()

func onBuff(id: String, on: bool) -> void:
	match id:
		"monster": car.get_node("sprite").scale = baseSpriteScale * (Pickups.DATA["monster"]["scale"] if on else 1.0)
		"golden": car.get_node("sprite").modulate = GOLD if on else Color.WHITE
		"wrecking":
			ball = car.to_global(Vector2(-HALF.x - CHAIN, 0))
			ballPrev = ball
		"flood": setFloodLight(on)
		"compass":
			route = PackedVector2Array()
			routeTimer = 0.0
	if not on && id == "wrecking": world.queue_redraw()
	updateProcessing()
	queue_redraw()

func shieldFlash() -> void:
	shieldFlashMs = Time.get_ticks_msec()

func setFloodLight(on: bool) -> void:
	if on && not is_instance_valid(floodLight):
		floodLight = PointLight2D.new()
		floodLight.texture = preload("res://texture/fx/circle_05.png")
		floodLight.texture_scale = 9.0
		floodLight.energy = 0.9
		floodLight.color = Color(1.0, 0.95, 0.8)
		add_child(floodLight)
	if is_instance_valid(floodLight): floodLight.visible = on

func needsProcessing() -> bool:
	return not car.buffs.is_empty() || car.turboKit || car.hasParcel || car.barricades > 0 || not fire.is_empty()

func updateProcessing() -> void:
	set_physics_process(needsProcessing())
	set_process(needsProcessing())

func _process(_delta: float) -> void:
	queue_redraw()
	if not fire.is_empty() || car.buffs.has("wrecking") || car.buffs.has("compass"): world.queue_redraw()

func _physics_process(delta: float) -> void:
	tick += 1
	var buffs: Dictionary = car.buffs
	if buffs.has("magnet") && tick % 3 == 0: pullPickups(Pickups.DATA["magnet"]["radius"])
	if buffs.has("firetrail") && tick % FIRE_EVERY == 0 && car.velocity.length() > 60.0:
		fire.push_back({"pos": car.to_global(Vector2(-HALF.x, 0)), "age": 0.0})
		if fire.size() > MAX_FIRE: fire.pop_front()
	if not fire.is_empty(): burn(delta)
	if buffs.has("wrecking"): swingBall()
	if buffs.has("potato") && tick % 6 == 0: checkPotato()
	if buffs.has("compass"):
		routeTimer -= delta
		if routeTimer <= 0.0:
			routeTimer = 2.0
			planRoute()
	if not needsProcessing(): updateProcessing()

#--- the effects ----------------------------------------------------------------------------------

func pullPickups(radius: float) -> void:
	for p in get_tree().get_nodes_in_group("pickup"):
		if not is_instance_valid(p) || not p.has_node("Area2D"): continue
		var d: float = p.global_position.distance_to(car.global_position)
		if d < radius: p.global_position = p.global_position.move_toward(car.global_position, 30.0 + (radius - d) * 0.08)

func burn(delta: float) -> void:
	for f in fire.duplicate():
		f.age += delta
		if f.age > FIRE_LIFE: fire.erase(f)
	if tick % 12 != 0 || not is_instance_valid(Root.spawnManager): return
	for f in fire:
		for goon in Root.spawnManager.goonsNear(f.pos, FIRE_RADIUS):
			kill(goon)

func swingBall() -> void:
	var anchor: Vector2 = car.to_global(Vector2(-HALF.x + 10, 0))
	var v := (ball - ballPrev) * 0.97
	ballPrev = ball
	ball += v
	var off := ball - anchor
	if off.length() > CHAIN: ball = anchor + off.normalized() * CHAIN
	if is_instance_valid(Root.spawnManager):
		for goon in Root.spawnManager.goonsNear(ball, BALL_RADIUS + 20.0): kill(goon)

func checkPotato() -> void:
	if not is_instance_valid(Root.spawnManager): return
	var r: float = Pickups.DATA["potato"]["radius"]
	if Root.spawnManager.goonsNear(car.global_position, r).size() < Pickups.DATA["potato"]["need"]: return
	car.endBuff("potato")
	Root.spawnManager.fx.blast(car.global_position, r, 0.0) #flattens the crowd and credits it; no damage to the car
	PickupEffects.label(car.global_position, "HOT POTATO!")

func planRoute() -> void:
	if not is_instance_valid(Root.station) || not is_instance_valid(Root.levelRoot): return
	var tm = Root.levelRoot.get_node_or_null("TileManager")
	if tm == null: return
	var gen = tm.get_node("landscapeGenerator")
	var planner := AIRoute.new(gen.terrainMap, Vector2i(gen.inputSizeX, gen.inputSizeY), tm.tilesize)
	var plan := planner.plan(car.global_position, Root.station.global_position)
	route = plan.points
	if route.size() > 0: route[0] = car.global_position
	route.push_back(Root.station.global_position)

static func kill(goon) -> void:
	if not is_instance_valid(goon) || goon.dead: return
	goon.destroy(&"boom")
	Root.spawnManager.creditCrush(goon.global_position)

#--- drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	var buffs: Dictionary = car.buffs
	var now := Time.get_ticks_msec()
	var flick := 0.8 + 0.2 * sin(now * 0.04)
	var throttle: bool = car._car_input.acceleration > 0.5
	if buffs.has("nitro") || (car.turboKit && throttle):
		var length := (90.0 if buffs.has("nitro") else 45.0) * flick
		for y in [-18.0, 18.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(-HALF.x, y - 10), Vector2(-HALF.x - length, y), Vector2(-HALF.x, y + 10)]), Color(1.0, 0.55, 0.1, 0.85))
			draw_colored_polygon(PackedVector2Array([Vector2(-HALF.x, y - 5), Vector2(-HALF.x - length * 0.6, y), Vector2(-HALF.x, y + 5)]), Color(0.6, 0.85, 1.0, 0.9))
	if buffs.has("plow"):
		var blade := PackedVector2Array([Vector2(HALF.x + 4, -HALF.y - 22), Vector2(HALF.x + 34, -HALF.y - 8), Vector2(HALF.x + 40, 0), Vector2(HALF.x + 34, HALF.y + 8), Vector2(HALF.x + 4, HALF.y + 22)])
		draw_colored_polygon(blade, Color(0.96, 0.66, 0.13))
		draw_polyline(blade, Color(0.25, 0.15, 0.05), 3.0)
		for y in [-36.0, -12.0, 12.0, 36.0]: draw_line(Vector2(HALF.x + 12, y - 6), Vector2(HALF.x + 30, y + 6), Color(0.15, 0.15, 0.17), 5.0)
	if buffs.has("spikes"):
		for x in [-62.0, 62.0]:
			for side in [-1.0, 1.0]:
				var c := Vector2(x, side * (HALF.y + 4))
				for i in 5:
					var a := now * 0.01 + i * TAU / 5.0
					draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a) * 8.0, c + Vector2.from_angle(a + 0.4) * 22.0, c + Vector2.from_angle(a + 0.8) * 8.0]), Color(0.75, 0.78, 0.82))
	if buffs.has("shield"):
		var flash := clampf(1.0 - (now - shieldFlashMs) / 250.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 135.0, Color(0.5, 0.82, 1.0, 0.12 + 0.3 * flash))
		draw_arc(Vector2.ZERO, 135.0, 0.0, TAU, 48, Color(0.75, 0.92, 1.0, 0.7), 3.0, true)
		for i in car.shieldHits: draw_circle(Vector2(-30 + i * 30, -HALF.y - 34), 7.0, Color(0.75, 0.92, 1.0))
	if buffs.has("golden"):
		for i in 6:
			var a := now * 0.003 + i * TAU / 6.0
			draw_circle(Vector2.from_angle(a) * Vector2(130, 70), 5.0 * flick, Color(1.0, 0.9, 0.4, 0.9))
	if buffs.has("potato"):
		var c := Vector2(-10, 0)
		draw_circle(c, 24.0, Color(0.16, 0.16, 0.19))
		draw_circle(c + Vector2(-8, -8), 6.0, Color(0.45, 0.45, 0.5))
		draw_line(c + Vector2(14, -14), c + Vector2(26, -26), Color(0.8, 0.7, 0.5), 3.0)
		draw_circle(c + Vector2(27, -27), 7.0 * flick, Color(1.0, 0.6, 0.1))
		var left: float = car.buffs["potato"] / float(Pickups.TICKS)
		HudTheme.text(self, c + Vector2(0, 9), str(ceili(left)), 24, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	if car.hasParcel:
		draw_rect(Rect2(Vector2(-58, -16), Vector2(32, 32)), Color(0.77, 0.48, 0.2))
		draw_rect(Rect2(Vector2(-58, -16), Vector2(32, 32)), Color(0.3, 0.16, 0.04), false, 2.0)
		draw_line(Vector2(-42, -16), Vector2(-42, 16), Color(1.0, 0.95, 0.86), 4.0)
	if car.barricades > 0:
		for i in car.barricades:
			draw_rect(Rect2(Vector2(-90 + i * 6, -30 + i * 6), Vector2(44, 12)), Color(0.94, 0.54, 0.11))
			draw_rect(Rect2(Vector2(-90 + i * 6, -30 + i * 6), Vector2(44, 12)), Color(1, 1, 1, 0.8), false, 2.0)

func drawWorld() -> void:
	for f in fire:
		var life: float = 1.0 - f.age / FIRE_LIFE
		var wob := sin(Time.get_ticks_msec() * 0.02 + f.pos.x) * 4.0
		world.draw_circle(f.pos, FIRE_RADIUS * 0.75 * life + wob, Color(1.0, 0.35, 0.05, 0.55 * life))
		world.draw_circle(f.pos, FIRE_RADIUS * 0.4 * life, Color(1.0, 0.85, 0.3, 0.8 * life))
	if car.buffs.has("wrecking"):
		var anchor: Vector2 = car.to_global(Vector2(-HALF.x + 10, 0))
		var links := 9
		for i in links:
			world.draw_circle(anchor.lerp(ball, (i + 0.5) / links), 5.0, Color(0.55, 0.57, 0.6))
		world.draw_circle(ball, BALL_RADIUS, Color(0.17, 0.17, 0.2))
		world.draw_circle(ball + Vector2(-10, -10), 9.0, Color(0.42, 0.42, 0.48))
	if car.buffs.has("compass") && route.size() > 1:
		var spacing := 220.0
		var carried := 0.0
		for i in range(1, route.size()):
			var a := route[i - 1]
			var b := route[i]
			var seg := a.distance_to(b)
			var dir := (b - a).normalized()
			var t := spacing - carried
			while t < seg:
				var p := a + dir * t
				if p.distance_to(car.global_position) > 160.0:
					world.draw_colored_polygon(PackedVector2Array([p + dir * 34.0, p + dir.orthogonal() * 22.0 - dir * 10.0, p - dir.orthogonal() * 22.0 - dir * 10.0]), Color(1.0, 0.83, 0.42, 0.85))
				t += spacing
			carried = seg - (t - spacing)
