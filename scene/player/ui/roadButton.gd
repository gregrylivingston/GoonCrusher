class_name roadButton extends Button


var animTransitionTimer = 0.15
@export var canGrabFocus: bool = true
var animationMin = 0 # PI/8

# Called when the node enters the scene tree for the first time.
func _ready():
	if text != null:
		$HBoxContainer/Label.text = text
	if icon != null:
		$HBoxContainer/TextureRect.texture = icon

	text = " "
	$HBoxContainer/Label.add_theme_font_size_override("font_size" ,get_theme_font_size("font_size"))
	if icon == null:
		$HBoxContainer/TextureRect.visible = false
	else:
		updateIcon($HBoxContainer/TextureRect.texture)
		icon = null


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_mouse_entered():startFocusAnimation()


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
	startFocusAnimation()

func _on_focus_exited():removeFocusAnimation()

func _on_mouse_exited():
	if not has_focus() || not canGrabFocus:
		removeFocusAnimation()

func removeFocusAnimation():
	get_tree().create_tween().tween_method(set3dAnimationAngle, PI, animationMin , animTransitionTimer)
	get_tree().create_tween().tween_property(self , "scale", Vector2(1.0,1.0),  animTransitionTimer)
#	get_tree().create_tween().tween_property(self , "position", position + Vector2(0 , 10),  animTransitionTimer)

func startFocusAnimation():
	if canGrabFocus && not has_focus(): 
		grab_focus()
		get_tree().create_tween().tween_property(self , "scale", Vector2(1.0,1.15),  animTransitionTimer)
		#get_tree().create_tween().tween_property(self , "position", position + Vector2(0,-10),  animTransitionTimer)
		$AudioStreamPlayer.play()
		get_tree().create_tween().tween_method(set3dAnimationAngle, animationMin, PI , animTransitionTimer)
		#set3dAnimationAngle(PI)

