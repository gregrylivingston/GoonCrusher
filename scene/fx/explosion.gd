extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var myScale = randf_range(0.5,5.5)
	scale = Vector2( myScale , myScale )


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_animation_finished():
	queue_free()
