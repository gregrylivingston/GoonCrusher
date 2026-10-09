class_name PickupNodes extends RefCounted

#Small things gadgets leave in the world. Each draws itself and frees itself when it is spent.
#They find goons through SpawnManager.goonsNear, so they need no physics layers.

## Base: a world-space node that lives `life` seconds and redraws while it lives.
class Timed extends Node2D:
	var life := 20.0
	var age := 0.0
	func _ready() -> void: z_index = -1
	func _physics_process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		step(delta)
	func _process(_delta: float) -> void: queue_redraw()
	func step(_delta: float) -> void: pass
	func goons(r: float) -> Array:
		return Root.spawnManager.goonsNear(global_position, r) if is_instance_valid(Root.spawnManager) else []

## Land Mine: arms after half a second and blows up the first goon that comes close.
class Mine extends Timed:
	func _init() -> void: life = 60.0
	func step(_delta: float) -> void:
		if age < 0.5 || Engine.get_physics_frames() % 4 != 0: return
		if not goons(70.0).is_empty():
			Root.spawnManager.fx.blast(global_position, Pickups.DATA["mine"]["radius"], 0.0, &"gadget")
			queue_free()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 22.0, Color(0.18, 0.18, 0.21))
		draw_circle(Vector2.ZERO, 13.0, Color(0.3, 0.3, 0.34))
		var on := age < 0.5 || int(age * 3.0) % 2 == 0
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.2, 0.15) if on else Color(0.35, 0.08, 0.06))

## Oil Slick: goons that cross it spin out.
class OilSlick extends Timed:
	var slipped := {}
	func _init() -> void: life = 20.0
	func step(_delta: float) -> void:
		if Engine.get_physics_frames() % 6 != 0: return
		var now := Time.get_ticks_msec()
		for goon in goons(Pickups.DATA["oilslick"]["radius"]):
			if now < slipped.get(goon.get_instance_id(), 0): continue
			slipped[goon.get_instance_id()] = now + 3000
			Gadgets.stun(goon, 2.0, Vector2.from_angle(randf() * TAU) * 220.0)
	func _draw() -> void:
		var r: float = Pickups.DATA["oilslick"]["radius"]
		var fade := clampf((life - age) / 2.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, r, Color(0.06, 0.06, 0.08, 0.8 * fade))
		draw_arc(Vector2(-10, -8), r * 0.55, 0.3, 2.2, 16, Color(0.5, 0.82, 1.0, 0.5 * fade), 5.0)
		draw_arc(Vector2(8, 10), r * 0.4, 3.4, 5.2, 16, Color(0.9, 0.3, 0.75, 0.45 * fade), 4.0)

## Flare: a big light for night, and Buzzards circle it instead of diving at the car.
class Flare extends Timed:
	func _init() -> void: life = Pickups.DATA["flare"]["secs"]
	func _ready() -> void:
		z_index = 0
		var light = PointLight2D.new()
		light.texture = preload("res://texture/fx/circle_05.png")
		light.texture_scale = 14.0
		light.energy = 1.3
		light.color = Color(1.0, 0.55, 0.35)
		add_child(light)
		Pickups.lures.push_back({"pos": global_position, "until": Time.get_ticks_msec() + int(life * 1000.0), "radius": 2200.0, "only": &"flyer"})
	func _draw() -> void:
		draw_line(Vector2(-10, 12), Vector2(10, -12), Color(0.82, 0.08, 0.2), 8.0)
		var f := 0.7 + 0.3 * sin(age * 30.0)
		draw_circle(Vector2(12, -14), 12.0 * f, Color(1.0, 0.75, 0.35))
		draw_circle(Vector2(12, -14), 6.0, Color(1.0, 1.0, 0.85))

## Goon Bait: goons nearby go for it, then it pops and flattens them.
class Bait extends Timed:
	func _init() -> void: life = Pickups.DATA["bait"]["secs"]
	func _ready() -> void:
		Pickups.lures.push_back({"pos": global_position, "until": Time.get_ticks_msec() + int(life * 1000.0), "radius": Pickups.DATA["bait"]["radius"], "only": &""})
	func _exit_tree() -> void:
		if is_instance_valid(Root.spawnManager) && age >= life - 0.05: Root.spawnManager.fx.blast(global_position, 150.0, 0.0, &"gadget")
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 20.0, Color(0.85, 0.25, 0.2))
		draw_circle(Vector2(-5, -5), 7.0, Color(1.0, 0.75, 0.68))
		draw_line(Vector2(14, 10), Vector2(30, 22), Color(0.96, 0.92, 0.82), 6.0)
		var ring := fmod(age, 1.0)
		draw_arc(Vector2.ZERO, 30.0 + 90.0 * ring, 0.0, TAU, 32, Color(1.0, 0.5, 0.4, 0.5 * (1.0 - ring)), 3.0)

## Homing Hubcap: flies to the nearest goon, crushes it, and bounces on to the next.
class Hubcap extends Timed:
	const SPEED := 950.0
	var bounces := 6
	var heading := Vector2.RIGHT
	var target = null
	var hit := {}
	func _init() -> void: life = 5.0
	func _ready() -> void: z_index = 2
	func step(delta: float) -> void:
		if target == null || not is_instance_valid(target) || target.dead: target = nextTarget()
		if target != null:
			heading = heading.lerp((target.global_position - global_position).normalized(), 0.25).normalized()
		global_position += heading * SPEED * delta
		if target != null && global_position.distance_to(target.global_position) < 40.0:
			hit[target.get_instance_id()] = true
			CarBuffFx.kill(target)
			target = null
			bounces -= 1
			if bounces <= 0: queue_free()
	func nextTarget():
		var best = null
		var bestD := 900.0
		for goon in goons(900.0):
			if goon.dead || goon.invulnerable || hit.has(goon.get_instance_id()): continue
			var d := global_position.distance_to(goon.global_position)
			if d < bestD:
				bestD = d
				best = goon
		return best
	func _draw() -> void:
		var tex := Pickups.texture("hubcap")
		draw_set_transform(Vector2.ZERO, age * 25.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-32, -32, 64, 64), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
