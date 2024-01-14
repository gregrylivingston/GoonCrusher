extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_full_screen_pressed():
	if $VBoxContainer/HBoxContainer/fullScreen.button_pressed: # Disabled (default)
		get_tree().root.set_mode(Window.MODE_FULLSCREEN)
	else: # Fullscreen
		get_tree().root.set_mode(Window.MODE_WINDOWED)



func _on_vsync_pressed():
	if $VBoxContainer/HBoxContainer/fullScreen.button_pressed: # Disabled (default)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	else: # Fullscreen
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
