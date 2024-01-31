extends CanvasLayer


var menuMode: String = "main"

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Root.mainMenu = self
	selectCar(SaveManager.playerData.cars[SaveManager.playerData.selectedCar])
	if Root.isRunActive:
		Root.isRunActive = false
		SaveManager.addCoins( Root.earnedCoins )
		SaveManager.addGems( Root.earnedGems )
		Root.earnedCoins = 0
		Root.earnedGems = 0
	%levelSelect.grab_focus()
	
var selectCarDelay = 0.3
func selectCar(car):
	if is_instance_valid(Root.playerCar):Root.playerCar.free()
	Root.selectedCar = car
	Root.playerCar = car.scene.instantiate()

	disableLockedCars(car)
	showNewBackgroundImage(Root.playerCar.backgroundPic)
	
	%charTexture2.texture = Root.playerCar.profilePic
	%charTexture2.position = Vector2( $Control.size.x , $Control.size.y )
	%charTexture.position = Vector2( 0,0 )
	get_tree().create_tween().tween_property(%charTexture2, "position" , Vector2( 0 , 0 ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property(%charTexture, "position" , Vector2( $Control.size.x  , $Control.size.y ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	
	$carStatsContainer.updateStats()
	%levelSelect.updateText( Root.playerCar.charName )
	$voicePlayer.stream = Root.playerCar.introAudio[randi_range(0 , Root.playerCar.introAudio.size()-1)]
	$voicePlayer.play()
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = Root.playerCar.backgroundPic
	%charTexture.texture = Root.playerCar.profilePic
	%charTexture2.position = Vector2( 0 , 0 )
	
func disableLockedCars(car):
	var thisCar =  SaveManager.getCarByName(Root.playerCar.carId)
	if thisCar.cost != 0:
		%levelSelect.visible = false
		%unlock.visible = true
		var unlockCost = thisCar.cost
		%unlock.updateText( "" +str(unlockCost) )
		if thisCar.cost > SaveManager.playerData.coin:%unlock.disabled = true
		else: %unlock.disabled = false
	else:
		%levelSelect.visible = true
		%unlock.visible = false
	
	
func showNewBackgroundImage(newImage:Texture2D):
	$backgroundTexture2.texture = newImage
	$backgroundTexture2.position = Vector2( -get_viewport().size.x , 0 )
	$backgroundTexture.position = Vector2( 0, 0)
	get_tree().create_tween().tween_property($backgroundTexture2, "position" , Vector2(0,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property($backgroundTexture, "position" , Vector2(get_viewport().size.x,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	

	
	
func _on_next_car_button_pressed():selectNextCar()
	
func selectNextCar():
	if menuMode == "level":
		setupLevel(SaveManager.selectNextLevel())
	elif menuMode == "main":
		selectCar(SaveManager.selectNextCar())
	
func _on_previous_car_button_pressed():selectPreviousCar()

func selectPreviousCar():
	if menuMode == "level":
		setupLevel(SaveManager.selectPreviousLevel())
	elif menuMode == "main":
		selectCar(SaveManager.selectPreviousCar())

func setupLevel(level):
	$VBoxContainer2/levelDifficultyPanel.modulate.a = 1.0
	showNewBackgroundImage(load(level.image))
	%levelSelect.updateText( str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name)
	%levelDifficulty.text = level.difficulty
	%levelTime.text = level.time
	if level.unlocked:
		%begin.updateText(str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name)
		%begin.disabled = false
	else:
		%begin.updateText("LOCKED")
		%begin.disabled = true
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = load(level.image)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_level_select_pressed():
	goToLevelSelect(true)
	

var menuTweenSpeed = 0.12
func goToLevelSelect(setting: bool): #true if adancing to level select
	var mainMenuScale = %mainMenuPanel.scale
	var topMenuScale = $carStatsContainer.scale
	get_tree().create_tween().tween_property(%mainMenuPanel , "scale" , Vector2(mainMenuScale.x * 0.8 ,0) , menuTweenSpeed)
	if setting: 
		menuMode = "level"
		get_tree().create_tween().tween_property($carStatsContainer , "scale" , Vector2(0 ,topMenuScale.y) , menuTweenSpeed)
		setupLevel(SaveManager.playerData.levels[SaveManager.playerData.selectedLevel])
	await get_tree().create_timer(menuTweenSpeed + 0.02).timeout #animation halfway complete
	
	for i in 	get_tree().get_nodes_in_group("levelMenu"): i.visible = setting
	for i in 	get_tree().get_nodes_in_group("characterMenu"): i.visible = not setting
	
	if not setting:
		menuMode = "main"
		selectCar(SaveManager.getCarByName(Root.playerCar.carId))
		$VBoxContainer2/levelDifficultyPanel.modulate.a = 0.0
	
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


func _on_begin_pressed():
	get_tree().change_scene_to_file( SaveManager.playerData.levels[SaveManager.playerData.selectedLevel].scene)


func _on_unlock_pressed():
	if SaveManager.unlockCar():
		selectCar(SaveManager.getCarByName(Root.playerCar.carId))
		
func statUpdatesUiUpdate():
	$carStatsContainer.updateStats()
