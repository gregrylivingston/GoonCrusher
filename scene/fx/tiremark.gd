class_name Tiremark extends Line2D


# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().create_timer(20).timeout
	queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update(gposition: Vector2):
	add_point(gposition - position)
