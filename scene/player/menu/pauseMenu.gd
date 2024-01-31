extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_continue_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	queue_free()	
	get_tree().paused = false

func _on_quit_pressed():
	get_tree().quit()

func _on_abandon_pressed():
	get_tree().paused = false	
	get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")


func _on_settings_pressed():
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())
