extends Polygon2D


# Called when the node enters the scene tree for the first time.
func _ready():
	$StaticBody2D/CollisionShape2D.shape.set_point_cloud(polygon)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
