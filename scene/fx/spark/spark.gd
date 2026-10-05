extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	rotation = randi()%360


func _on_animation_finished():
	queue_free()
