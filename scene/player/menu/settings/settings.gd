extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/TabContainer/VBoxContainer2/HBoxContainer/Gameplay.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass





func viewMenu(num: int):
	for i in [$Panel/VBoxContainer/Gameplay, $Panel/VBoxContainer/Sound, $Panel/VBoxContainer/Graphics, $Panel/VBoxContainer/Input]:
		i.visible = false
	$Panel/VBoxContainer.get_child(num).visible = true	


func _on_gameplay_pressed():viewMenu(0)

func _on_sound_pressed():viewMenu(1)

func _on_graphics_pressed():viewMenu(2)

func _on_input_pressed():viewMenu(3)


func _on_continue_pressed():
	queue_free()
