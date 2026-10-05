extends CanvasLayer

var splashIcon = load("res://scene/player/menu/splash/splashicon_1.tscn")
var myIcons

	
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
	

#icons per reel for the Slot Celebration setting: Minimal, Reduced, Full
const BURST_SIZES = [8, 40, 200]

func iconsplosion( myPosition , icon ):
	for i in BURST_SIZES[Settings.celebration_level()]:
		var newIcon = splashIcon.instantiate()
		newIcon.position = myPosition
		newIcon.texture = icon 
		add_child(newIcon)
		
