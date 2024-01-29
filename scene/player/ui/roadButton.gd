class_name roadButton extends Button


# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/Label.text = text
	$HBoxContainer/TextureRect.texture = icon
	icon = null
	text = ""
	$HBoxContainer/Label.add_theme_font_size_override("font_size" ,get_theme_font_size("font_size"))
	if $HBoxContainer/TextureRect.texture == null:
		$HBoxContainer/TextureRect.visible = false
		$HBoxContainer/TextureRect.queue_free()
	else:
		updateIcon($HBoxContainer/TextureRect.texture)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_mouse_entered():
	$AudioStreamPlayer.play()

func _on_pressed():
	$AudioStreamPlayer2.play()

func updateText(newText):
	$HBoxContainer/Label.text = newText

func updateIcon(newIcon):
	$HBoxContainer/TextureRect.texture = newIcon
	$HBoxContainer/TextureRect.material.set_shader_parameter("front_tex" , newIcon)
	$HBoxContainer/TextureRect.material.set_shader_parameter("back_tex" ,  newIcon )
	$HBoxContainer/TextureRect.material.set_shader_parameter("side_tex" ,  newIcon )
	
