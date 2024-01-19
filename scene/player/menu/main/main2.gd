extends CanvasLayer


var levelSelectMode: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	Root.mainMenu = self
	selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])
	
var selectCarDelay = 0.3
func selectCar(car):
	if is_instance_valid(Root.playerCar):Root.playerCar.free()
	Root.selectedCar = car
	Root.playerCar = car.scene.instantiate()

	showNewBackgroundImage(Root.playerCar.backgroundPic)
	
	%charTexture2.texture = Root.playerCar.profilePic
	%charTexture2.position = Vector2( $Control.size.x , $Control.size.y )
	%charTexture.position = Vector2( 0,0 )
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
	
func showNewBackgroundImage(newImage:Texture2D):
	$backgroundTexture2.texture = newImage
	$backgroundTexture2.position = Vector2( -get_viewport().size.x , 0 )
	$backgroundTexture.position = Vector2( 0, 0)
	get_tree().create_tween().tween_property($backgroundTexture2, "position" , Vector2(0,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property($backgroundTexture, "position" , Vector2(get_viewport().size.x,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	

	
	
func _on_next_car_button_pressed():selectNextCar()
	
func selectNextCar():
	if levelSelectMode:
		pass
	else:
		if Root.selectedCarNum + 1 < Root.cars.keys().size():Root.selectedCarNum += 1
		else: Root.selectedCarNum = 0
		selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])
	
func _on_previous_car_button_pressed():selectPreviousCar()

func selectPreviousCar():
	if levelSelectMode:
		pass
	else:
		if Root.selectedCarNum > 0:Root.selectedCarNum -= 1
		else: Root.selectedCarNum = Root.cars.keys().size() - 1
		selectCar(Root.cars[Root.cars.keys()[Root.selectedCarNum]])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_level_select_pressed():
	goToLevelSelect(true)
	

var menuTweenSpeed = 0.12
func goToLevelSelect(setting: bool): #true if adancing to level select
	levelSelectMode = setting
	var mainMenuScale = %mainMenuPanel.scale
	var topMenuScale = $carStatsContainer.scale
	get_tree().create_tween().tween_property(%mainMenuPanel , "scale" , Vector2(mainMenuScale.x * 0.8 ,0) , menuTweenSpeed)
	if setting: 
		get_tree().create_tween().tween_property($carStatsContainer , "scale" , Vector2(0 ,topMenuScale.y) , menuTweenSpeed)
		showNewBackgroundImage(load("res://scene/level/instances/1. fields_of_goonery/levelbackground_fieldsOfGoonery.png"))
		$HBoxContainer/Panel/driverName.text = "Fields Of Goonery"
	else:
		showNewBackgroundImage(Root.playerCar.backgroundPic)
		$HBoxContainer/Panel/driverName.text = Root.playerCar.charName
	await get_tree().create_timer(menuTweenSpeed + 0.02).timeout #animation halfway complete
	
	for i in 	get_tree().get_nodes_in_group("levelMenu"): i.visible = setting
	for i in 	get_tree().get_nodes_in_group("characterMenu"): i.visible = not setting
	
	get_tree().create_tween().tween_property(%mainMenuPanel, "scale" ,  mainMenuScale  , menuTweenSpeed)
	$carStatsContainer.scale = topMenuScale
	
	if setting && $voicePlayer.playing == false:
		$voicePlayer.stream = Root.playerCar.introAudio[randi_range(0 , Root.playerCar.introAudio.size()-1)]
		$voicePlayer.play()
	

func _on_quit_button_pressed():	get_tree().quit()
func _on_settings_button_pressed():	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())
func _on_records_button_pressed():
	var scene = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	scene.isGameSummary = false
	add_child(scene)



func _on_back_button_pressed():
	goToLevelSelect(false)


func _on_begin_pressed():get_tree().change_scene_to_file("res://scene/level/levelRoot.tscn")
