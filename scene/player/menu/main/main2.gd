extends CanvasLayer


enum menuModes{ RIDER , LEVEL , GAMEMODE }
var menuMode: menuModes = menuModes.RIDER



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
	#%levelSelect.updateText( "Ride with " + Root.playerCar.charName )
	%driverName.text = Root.playerCar.charName
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
		var unlockCost = thisCar.cost / 1000
		%unlock.updateText( str(unlockCost) + "k to Unlock" )
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
	match menuMode:
		menuModes.RIDER:selectCar(SaveManager.selectNextCar())
		menuModes.LEVEL:setupLevel(SaveManager.selectNextLevel())
		menuModes.GAMEMODE:selectGameMode(SaveManager.selectNextGameMode())
	
func _on_previous_car_button_pressed():selectPreviousCar()

func selectPreviousCar():
	match menuMode:
		menuModes.RIDER:selectCar(SaveManager.selectPreviousCar())
		menuModes.LEVEL:setupLevel(SaveManager.selectPreviousLevel())
		menuModes.GAMEMODE:selectGameMode(SaveManager.selectPreviousGameMode())
		

func setupLevel(level):

	showNewBackgroundImage(load(level.image))
	#%levelSelect.updateText( str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name)
	%driverName2.text =  Root.playerCar.charName
	%driverName.text = str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name
	if level.unlocked:
		%begin.updateText("Select Level")

		%begin.disabled = false
	else:
		%begin.updateText("LOCKED")
		%begin.disabled = true
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = load(level.image)


func _on_level_select_pressed():
	match menuMode:
		menuModes.RIDER:goToMenuMode(menuModes.LEVEL)
	

var menuTweenSpeed = 0.12
func goToMenuMode(myMenuMode: menuModes): #true if adancing to level select
	menuMode = myMenuMode

	var mainMenuScale = %mainMenuPanel.scale
	var topMenuScale = $carStatsContainer.scale	
	var selectedTextScale = $VBoxContainer2.scale
	get_tree().create_tween().tween_property(%mainMenuPanel , "scale" , Vector2(mainMenuScale.x * 0.8 ,0) , menuTweenSpeed)
	get_tree().create_tween().tween_property($VBoxContainer2 , "scale", Vector2(0, 1 ), menuTweenSpeed)

	match menuMode:
		menuModes.LEVEL:		
			get_tree().create_tween().tween_property($carStatsContainer , "scale" , Vector2(0 ,topMenuScale.y) , menuTweenSpeed)
			setupLevel(SaveManager.playerData.levels[SaveManager.playerData.selectedLevel])

	await get_tree().create_timer(menuTweenSpeed + 0.02).timeout #animation halfway complete
	
	var isRiderMenu: bool = false  #this is really awkard - just using it to hide which parts of main menu get shown....
	if menuMode == menuModes.RIDER:
		isRiderMenu = true

	for i in get_tree().get_nodes_in_group("levelMenu"): i.visible = not isRiderMenu
	for i in get_tree().get_nodes_in_group("characterMenu"): i.visible = isRiderMenu
	
	match menuMode:
		menuModes.RIDER:selectCar(SaveManager.getCarByName(Root.playerCar.carId))
		menuModes.GAMEMODE:selectGameMode(SaveManager.getGameMode())
		menuModes.LEVEL:
			$VBoxContainer2/levelNameContainer.visible = false
			$gameModeInfo.visible = false
			%begin.text = "Select Level"
	
	get_tree().create_tween().tween_property(%mainMenuPanel, "scale" ,  mainMenuScale  , menuTweenSpeed)
	get_tree().create_tween().tween_property($VBoxContainer2 , "scale", selectedTextScale, menuTweenSpeed)
	$carStatsContainer.scale = topMenuScale
	
	if isRiderMenu && $voicePlayer.playing == false:
		$voicePlayer.stream = Root.playerCar.introAudio[randi_range(0 , Root.playerCar.introAudio.size()-1)]
		$voicePlayer.play()


func selectGameMode(newGameMode):
	%begin.updateText( "Select Game Mode" )
	var gameModeString = (Root.gameModes.keys()[newGameMode])
	$VBoxContainer2/levelNameContainer.visible = true
	var selectedLevel =  SaveManager.playerData.levels[SaveManager.playerData.selectedLevel]
	$VBoxContainer2/levelNameContainer/levelName.text = str(SaveManager.playerData.selectedLevel + 1) + ". " + selectedLevel.name
	%driverName.text = gameModeString

	$gameModeInfo/gameModeLabel.text = Root.gameModes.keys()[newGameMode]
	$gameModeInfo.visible = true
	$gameModeInfo/gameModeDescription.text = Root.gameModeDescription[newGameMode].description
	highlightAGameModeStar(gameModeString)
	
func highlightAGameModeStar(starNodeGroup: String):
	for i in get_tree().get_nodes_in_group("gameModeStar"):get_tree().create_tween().tween_property(i , "custom_minimum_size", Vector2(48,48), menuTweenSpeed)
	var myStar = get_tree().get_first_node_in_group(starNodeGroup)
	if is_instance_valid(myStar):get_tree().create_tween().tween_property(myStar , "custom_minimum_size",  Vector2(72,72), menuTweenSpeed)

func _on_quit_button_pressed():	get_tree().quit()
func _on_settings_button_pressed():	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())
func _on_records_button_pressed():
	var scene = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	scene.isGameSummary = false
	add_child(scene)



func _on_back_button_pressed():
	match menuMode:
		menuModes.LEVEL:goToMenuMode(menuModes.RIDER)
		menuModes.GAMEMODE:goToMenuMode(menuModes.LEVEL)
			
		
func _on_begin_pressed():
	match menuMode:
		menuModes.GAMEMODE:get_tree().change_scene_to_file( SaveManager.playerData.levels[SaveManager.playerData.selectedLevel].scene)
		menuModes.LEVEL:goToMenuMode(menuModes.GAMEMODE)

func _on_unlock_pressed():
	if SaveManager.unlockCar():
		selectCar(SaveManager.getCarByName(Root.playerCar.carId))
		
func statUpdatesUiUpdate():
	$carStatsContainer.updateStats()
