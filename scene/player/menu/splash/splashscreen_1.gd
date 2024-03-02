extends CanvasLayer

var splashIcon = load("res://scene/player/menu/splash/splashicon_1.tscn")
var myIcons

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func startExplosion():
	
	
	iconsplosion( getIconPosition(0.5) , myIcons[1] )
	$AudioStreamPlayer.play()
	await get_tree().create_timer(.5).timeout
	$AudioStreamPlayer.play()
	iconsplosion( getIconPosition(0.7) , myIcons[2] )
	await get_tree().create_timer(.5).timeout
	$AudioStreamPlayer.play()
	iconsplosion( getIconPosition(0.3) , myIcons[0] )
	await get_tree().create_timer(3.5).timeout
	queue_free()

func getIconPosition(xScreenDivisor:float) -> Vector2:
	return Vector2( get_viewport().get_visible_rect().size.x * xScreenDivisor , get_viewport().get_visible_rect().size.y / 3 )
	

func iconsplosion( myPosition , icon ):
	for i in 200:
		var newIcon = splashIcon.instantiate()
		newIcon.position = myPosition
		newIcon.texture = icon 
		add_child(newIcon)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
