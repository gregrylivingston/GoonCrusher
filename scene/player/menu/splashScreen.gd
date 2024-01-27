extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	if is_instance_valid(Root.mainMenu):Root.mainMenu.queue_free()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
