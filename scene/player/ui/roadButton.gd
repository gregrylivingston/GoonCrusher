class_name roadButton extends Button

var animTransitionTimer = 0.15
@export var canGrabFocus: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/Label.text = text
	$HBoxContainer/TextureRect.texture = icon
	icon = null
	text = " "
	$HBoxContainer/Label.add_theme_font_size_override("font_size" ,get_theme_font_size("font_size"))
	if $HBoxContainer/TextureRect.texture == null:
		$HBoxContainer/TextureRect.visible = false
	else:
		updateIcon($HBoxContainer/TextureRect.texture)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_mouse_entered():
	if canGrabFocus && not has_focus(): 
		grab_focus()
		get_tree().create_tween().tween_property(self , "scale", Vector2(1.0,1.3),  animTransitionTimer)
		#get_tree().create_tween().tween_property(self , "position", position + Vector2(0,-10),  animTransitionTimer)
		$AudioStreamPlayer.play()
		get_tree().create_tween().tween_method(set3dAnimationAngle, PI/8, PI , animTransitionTimer)
		#set3dAnimationAngle(PI)

func set3dAnimationAngle(angle):
	if $HBoxContainer/TextureRect != null:
		if $HBoxContainer/TextureRect.material != null:
			$HBoxContainer/TextureRect.material.set_shader_parameter("angle" ,  angle )
	if $HBoxContainer/Label.material != null:
		$HBoxContainer/Label.material.set_shader_parameter("angle" ,  angle )


func _on_pressed():
	$AudioStreamPlayer2.play()

func updateText(newText):
	$HBoxContainer/Label.text = newText

func updateIcon(newIcon):
	$HBoxContainer/TextureRect.visible = true
	$HBoxContainer/TextureRect.texture = newIcon
	$HBoxContainer/TextureRect.material.set_shader_parameter("front_tex" , newIcon)
	$HBoxContainer/TextureRect.material.set_shader_parameter("back_tex" ,  newIcon )


func _on_focus_entered():
	get_tree().create_tween().tween_method(set3dAnimationAngle, PI/8, PI , animTransitionTimer)

func _on_focus_exited():removeFocusAnimation()

func _on_mouse_exited():
	if not has_focus() || not canGrabFocus:
		removeFocusAnimation()

func removeFocusAnimation():
	get_tree().create_tween().tween_method(set3dAnimationAngle, PI, PI/8 , animTransitionTimer)
	get_tree().create_tween().tween_property(self , "scale", Vector2(1.0,1.0),  animTransitionTimer)
#	get_tree().create_tween().tween_property(self , "position", position + Vector2(0 , 10),  animTransitionTimer)


