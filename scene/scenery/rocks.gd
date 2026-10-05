extends Sprite2D

#the collision hull is built from the occluder polygon. Instances of a rock scene share one shape,
#so each shape is built once instead of on every chunk load.
static var builtShapes = {}

func _ready():
	var shape = $StaticBody2D/CollisionShape2D.shape
	if builtShapes.has(shape): return
	shape.set_point_cloud($LightOccluder2D.occluder.polygon)
	builtShapes[shape] = true
