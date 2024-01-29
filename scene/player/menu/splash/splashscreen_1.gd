extends CanvasLayer

var splashIcon = load("res://scene/player/menu/splash/splashicon_1.tscn")
var myIcons

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func startExplosion():
	
	
	iconsplosion( 0.5 , myIcons[1] )
	$AudioStreamPlayer.play()
	await get_tree().create_timer(.5).timeout
	$AudioStreamPlayer.play()
	iconsplosion( 0.7 , myIcons[2] )
	await get_tree().create_timer(.5).timeout
	$AudioStreamPlayer.play()
	iconsplosion( 0.3 , myIcons[0] )
	await get_tree().create_timer(3.5).timeout
	queue_free()

func iconsplosion( xScreenDivisor , icon ):
	for i in 300:
		var newIcon = splashIcon.duplicate().instantiate()
		var targetVelocity = Vector2( randf_range(-1,1),randf_range(-1,1)).normalized()
		targetVelocity.x = targetVelocity.x * randf_range(0,18)
		targetVelocity.y = ( targetVelocity.y -1.95 ) * randf_range(0,15)
		newIcon.velocity =  targetVelocity#Vector2( randf_range(-25.0,25.0) , randf_range(-18.5,2.5) )
		newIcon.position = Vector2( get_viewport().get_visible_rect().size.x * xScreenDivisor , get_viewport().get_visible_rect().size.y / 3 )
		newIcon.texture = icon 
		add_child(newIcon)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
