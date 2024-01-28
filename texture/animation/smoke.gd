extends AnimatedSprite2D

@export var temporary: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	play()
	rotation = randi()%360
	if not temporary:createSmokePuff()
	else:
		z_index = 5
		modulate.a = 0.5
		get_tree().create_tween().tween_property(self, "scale", Vector2(3,3), 2)
		get_tree().create_tween().tween_property(self, "modulate", Color(1.0,1.0,1.0,0.0), 2)
		await get_tree().create_timer(2).timeout
		queue_free()

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



var smokePuff = load("res://texture/animation/smoke.tscn").duplicate()
func createSmokePuff():
	if is_instance_valid(Root.levelRoot) && visible && get_tree().paused == false:
		var newSmoke = smokePuff.instantiate()
		newSmoke.temporary = true
		Root.levelRoot.add_child(newSmoke)
		newSmoke.global_position = global_position
	await get_tree().create_timer(0.06).timeout
	createSmokePuff()
