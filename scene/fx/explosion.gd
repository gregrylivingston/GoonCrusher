extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var myScale = randf_range(0.5,5.5)
	scale = Vector2( myScale , myScale )


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
#	$PointLight2D.texture = sprite_frames.get_frame_texture("default", frame)
	pass

func _on_animation_finished():
	queue_free()
