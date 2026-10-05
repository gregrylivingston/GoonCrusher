extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$StaticBody2D/CollisionShape2D.shape.set_point_cloud($LightOccluder2D.occluder.polygon)
