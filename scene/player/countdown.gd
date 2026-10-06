extends Label

var countdownSecondLength = 0.9

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().paused = true
	nextCount("3")
	$AudioStreamPlayer.play()
	await get_tree().create_timer(countdownSecondLength + 0.1).timeout
	nextCount("2")
	await get_tree().create_timer(countdownSecondLength + 0.1).timeout
	nextCount("1")
	await get_tree().create_timer(countdownSecondLength + 0.1).timeout
	get_tree().paused = false #the run starts now; GO! shows over it without holding anything up
	add_theme_color_override("font_color", HudTheme.OK)
	add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.08))
	nextCount("GO!")
	await get_tree().create_timer(0.5).timeout
	get_parent().queue_free()

func nextCount(num: String):
	text = num
	#scale = Vector2(0,0)
	#position = get_viewport_rect().size / 2
	#get_tree().create_tween().tween_property(self , "scale" , Vector2(1,1) , countdownSecondLength)
	#get_tree().create_tween().tween_property(self , "position" , Vector2(0,0) , countdownSecondLength)
	$AnimationPlayer.stop()
	$AnimationPlayer.current_animation = "countdown"
	$AnimationPlayer.seek(0)
	$AnimationPlayer.play()
