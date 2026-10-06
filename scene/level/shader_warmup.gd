class_name ShaderWarmup extends Node2D

#Draws one of each common gameplay visual for a few frames at the start of a level, almost
#transparent and under a shadow-casting light, so their shaders (lit and unlit) compile behind
#the countdown instead of hitching mid-run.

const FRAMES = 3
var SAMPLE_POWERUPS = [Root.upgrade.COIN, Root.upgrade.PURSE, Root.upgrade.HEALTH]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.02
	z_index = -5
	var light = PointLight2D.new()
	light.texture = preload("res://texture/fx/circle_05.png")
	light.texture_scale = 4.0
	light.shadow_enabled = true
	add_child(light)
	var occluder = LightOccluder2D.new()
	occluder.occluder = OccluderPolygon2D.new()
	occluder.occluder.polygon = PackedVector2Array([Vector2(40, -10), Vector2(60, -10), Vector2(60, 10), Vector2(40, 10)])
	add_child(occluder)

	var goonScene = Root.spawnManager.warmupScene() if is_instance_valid(Root.spawnManager) else null
	if goonScene:
		for giant in [false, true]:
			var goon = goonScene.instantiate()
			var sprite = goon.get_node("Sprite").duplicate()
			if not giant: sprite.material = null
			sprite.position = Vector2(-80 if giant else -40, 0)
			add_child(sprite)
			goon.free()
	for upgrade in SAMPLE_POWERUPS:
		var pickup = Root.getSpecificPowerup(upgrade)
		for child in pickup.get_children(): child.free() #keep only the sprite and its material
		pickup.set_script(null)
		add_child(pickup)
	#the world's ground and decor shaders (gc_ground_quality), lit and unlit
	for path in ["res://shader/ground.gdshader", "res://shader/world_decor.gdshader", "res://shader/world_decor_glow.gdshader"]:
		var quad = MeshInstance2D.new()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(32, 32)
		quad.mesh = mesh
		quad.material = ShaderMaterial.new()
		quad.material.shader = load(path)
		quad.position = Vector2(80, 0)
		add_child(quad)
	var puff = load("res://texture/animation/smoke.tscn").instantiate()
	puff.pooled = true
	add_child(puff)
	puff.visible = true
	var explosion = Root.levelRoot.explosionScene.instantiate()
	explosion.set_script(null)
	add_child(explosion)

	for i in FRAMES: await get_tree().process_frame
	queue_free()
