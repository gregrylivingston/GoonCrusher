extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	Root.mainMenu = self
	selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])
	
var selectCarDelay = 0.3
func selectCar(car):
	if is_instance_valid(Root.playerCar):Root.playerCar.free()
	Root.selectedCar = car
	Root.playerCar = car.scene.instantiate()

	$backgroundTexture2.texture = Root.playerCar.backgroundPic
	$backgroundTexture2.position = Vector2( -get_viewport().size.x , 0 )
	$backgroundTexture.position = Vector2( 0, 0)
	get_tree().create_tween().tween_property($backgroundTexture2, "position" , Vector2(0,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property($backgroundTexture, "position" , Vector2(get_viewport().size.x,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	
	%charTexture2.texture = Root.playerCar.profilePic
	%charTexture2.position = Vector2( $Control.size.x , $Control.size.y )
	get_tree().create_tween().tween_property(%charTexture2, "position" , Vector2( 0 , 0 ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property(%charTexture, "position" , Vector2( $Control.size.x  , $Control.size.y ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	
	$carStatsContainer.updateStats()
	$HBoxContainer/Panel/driverName.text = Root.playerCar.charName
	$voicePlayer.stream = Root.playerCar.introAudio[randi_range(0 , Root.playerCar.introAudio.size()-1)]
	$voicePlayer.play()
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = Root.playerCar.backgroundPic
	%charTexture.texture = Root.playerCar.profilePic
	%charTexture2.position = Vector2( 0 , 0 )
	
	
	
func _on_next_car_button_pressed():selectNextCar()
	
func selectNextCar():
	if Root.selectedCarNum + 1 < Root.cars.keys().size():Root.selectedCarNum += 1
	else: Root.selectedCarNum = 0
	selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])
	
func _on_previous_car_button_pressed():selectPreviousCar()

func selectPreviousCar():
	if Root.selectedCarNum > 0:Root.selectedCarNum -= 1
	else: Root.selectedCarNum = Root.cars.keys().size() - 1
	selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



