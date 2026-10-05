extends CanvasLayer


enum menuModes{ RIDER , LEVEL , GAMEMODE }
var menuMode: menuModes = menuModes.RIDER



# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Root.mainMenu = self
	Settings.set_menu_context(true)
	$VersionTracker.text = Root.versionText()
	selectCar(SaveManager.playerData.cars[SaveManager.playerData.selectedCar])
	if Root.isRunActive:
		Root.isRunActive = false
		#gameSummary already credited and saved the payout; the menu only counts the display up
		var coin = SaveManager.playerData.coin
		if Root.earnedCoins > 0: animateCoins(coin - Root.earnedCoins, coin)
		Root.earnedCoins = 0
		Root.earnedGems = 0
	await get_tree().process_frame
	Settings.on_menu_ready() #the menu is drawn: this boot did not crash
	if Settings.safe_mode_prompt: add_child(SettingsDialog.safeModePrompt())
	elif Settings.detect_toast_pending || Settings.calibrate_pending:
		await Settings.calibrate_if_needed() #first run on this GPU only: may lower the detected tier
		if is_inside_tree() && Settings.detect_toast_pending: add_child(SettingsDialog.detectToast())

func _exit_tree():
	Settings.set_menu_context(false)

func _process(delta):
	if Settings.menu_open: return
	if Input.is_action_just_pressed("TurnLeft") || Input.is_action_just_pressed("ui_left"):selectPreviousCar()
	elif Input.is_action_just_pressed("TurnRight") || Input.is_action_just_pressed("ui_right"):selectNextCar()
	
var selectCarDelay = 0.3
func selectCar(car):
	Root.selectedCar = car
	Root.playerCar = null #the menu shows a car from its CarInfo, without loading the car scene
	Root.carInfo = load(CarInfo.pathFor(car.scene))

	disableLockedCars(car)
	showNewBackgroundImage(Root.carInfo.backgroundPic)
	
	%charTexture2.texture = Root.carInfo.profilePic
	%charTexture2.position = Vector2( $Control.size.x , $Control.size.y )
	%charTexture.position = Vector2( 0,0 )
	get_tree().create_tween().tween_property(%charTexture2, "position" , Vector2( 0 , 0 ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property(%charTexture, "position" , Vector2( $Control.size.x  , $Control.size.y ) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	
	$carStatsContainer.updateStats()
	#%levelSelect.updateText( "Ride with " + Root.carInfo.charName )
	%driverName.text = Root.carInfo.charName
	$voicePlayer.stream = Root.carInfo.introAudio[randi_range(0 , Root.carInfo.introAudio.size()-1)]
	$voicePlayer.play()
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = Root.carInfo.backgroundPic
	%charTexture.texture = Root.carInfo.profilePic
	%charTexture2.position = Vector2( 0 , 0 )
	prefetchNeighbourCars()

#start loading the cars either side in the background so the arrows switch instantly
func prefetchNeighbourCars() -> void:
	var cars = SaveManager.playerData.cars
	var index = SaveManager.playerData.selectedCar
	for offset in [-1, 1]:
		var path = CarInfo.pathFor(cars[wrapi(index + offset, 0, cars.size())].scene)
		if not ResourceLoader.has_cached(path): ResourceLoader.load_threaded_request(path)
	
func disableLockedCars(car) -> void:
	var thisCar =  SaveManager.getCarByName(Root.carInfo.carId)
	if Root.IS_DEMO && SaveManager.playerData.selectedCar >= Root.DEMO_CAR_COUNT:
		%levelSelect.visible = true
		%levelSelect.disabled = true
		%levelSelect.updateText( "NOT IN DEMO" )
		%unlock.visible = false
	elif thisCar.cost != 0:
		%levelSelect.visible = false
		%unlock.visible = true
		if thisCar.cost > 9999:
			var unlockCost = thisCar.cost / 1000
			%unlock.updateText( str(unlockCost) + "k to Unlock" )
		else: %unlock.updateText( str(thisCar.cost) + " to Unlock" )
		if thisCar.cost > SaveManager.playerData.coin:%unlock.disabled = true
		else: %unlock.disabled = false

	else:
		%unlock.visible = false
		%levelSelect.updateText( "Select Driver")
		%levelSelect.disabled = false
		%levelSelect.visible = true

	
	
func showNewBackgroundImage(newImage:Texture2D):
	$backgroundTexture2.texture = newImage
	$backgroundTexture2.position = Vector2( -get_viewport().get_visible_rect().size.x , 0 )
	$backgroundTexture.position = Vector2( 0, 0)
	get_tree().create_tween().tween_property($backgroundTexture2, "position" , Vector2(0,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_tween().tween_property($backgroundTexture, "position" , Vector2(get_viewport().get_visible_rect().size.x,0) , selectCarDelay).set_ease(Tween.EASE_IN_OUT)
	

	
	
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
	#%levelSelect.updateText( str(SasetupLevelveManager.playerData.selectedLevel + 1) + ". " + level.name)
	%driverName2.text =  Root.carInfo.charName
	%driverName.text = str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name
	
	if isLevelSelectable(SaveManager.playerData.selectedLevel):
		%begin.updateText("Select Level")
		%begin.disabled = false
	else:
		%begin.updateText("NOT IN DEMO" if isDemoLockedLevel(SaveManager.playerData.selectedLevel) else "LOCKED")
		%begin.disabled = true
	
	setupGameModeStars(level)
	for i in get_tree().get_nodes_in_group("gameModeStar"):get_tree().create_tween().tween_property(i , "custom_minimum_size", Vector2(48,48), menuTweenSpeed)
	
	await get_tree().create_timer( selectCarDelay ).timeout
	$backgroundTexture.texture = load(level.image)


func isDemoLockedLevel(index: int) -> bool:
	return Root.IS_DEMO && index >= Root.DEMO_LEVEL_COUNT

func isLevelSelectable(index: int) -> bool:
	return SaveManager.playerData.levels[index].unlocked && not isDemoLockedLevel(index)

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

	await get_tree().create_timer(menuTweenSpeed + 0.03).timeout #animation halfway complete
	
	var isRiderMenu: bool = false  #this is really awkard - just using it to hide which parts of main menu get shown....
	if menuMode == menuModes.RIDER:
		isRiderMenu = true
		
	for i in get_tree().get_nodes_in_group("characterMenu"): i.visible = isRiderMenu
	for i in get_tree().get_nodes_in_group("levelMenu"): i.visible = not isRiderMenu

	
	match menuMode:
		menuModes.RIDER:selectCar(SaveManager.getCarByName(Root.carInfo.carId))
		menuModes.GAMEMODE:selectGameMode(SaveManager.setGameMode(defaultGameMode()))
		menuModes.LEVEL:
			$VBoxContainer2/levelNameContainer.visible = false
			$gameModeInfo.visible = false
			%begin.text = "Select Level"
	
	get_tree().create_tween().tween_property(%mainMenuPanel, "scale" ,  mainMenuScale  , menuTweenSpeed)
	get_tree().create_tween().tween_property($VBoxContainer2 , "scale", selectedTextScale, menuTweenSpeed)
	$carStatsContainer.scale = topMenuScale
	
	if isRiderMenu && $voicePlayer.playing == false:
		$voicePlayer.stream = Root.carInfo.introAudio[randi_range(0 , Root.carInfo.introAudio.size()-1)]
		$voicePlayer.play()


var Mat_Star_Beat = load("res://shader/mat_star_yellow.tres")
var Mat_Star_Locked = load("res://shader/Mat_Star_Grey.tres")
var Mat_Star_Unlocked = load("res://shader/Mat_Star_White.tres") 

#the five stars in scene order. Countdown's star is in group "COUNTDOWN", and TextureRect2 is Marathon.
@onready var modeStars = {
	Root.gameModes.GOONCRUSHER: $VBoxContainer2/starContainer/TextureRect,
	Root.gameModes.SPRINT: $VBoxContainer2/starContainer/TextureRect3,
	Root.gameModes.MARATHON: $VBoxContainer2/starContainer/TextureRect2,
	Root.gameModes.DEFENSE: $VBoxContainer2/starContainer/TextureRect4,
	Root.gameModes.GOONPOCALYPSE: $VBoxContainer2/starContainer/TextureRect5,
}

#the selected level as the mode rules see it: a level the demo doesn't offer counts as locked
func selectedLevelForModes() -> Dictionary:
	var index = SaveManager.playerData.selectedLevel
	var level: Dictionary = SaveManager.playerData.levels[index]
	if isDemoLockedLevel(index): return level.merged({"unlocked": false}, true)
	return level

#yellow when beaten, white when it can be started, grey when locked or not available yet
func setupGameModeStars(_level = null):
	var level = selectedLevelForModes()
	for mode in modeStars:
		var playable = Root.isModePlayable(level, mode)
		if playable && level.gamemodeBeat.get(mode, false): modeStars[mode].material = Mat_Star_Beat
		elif playable: modeStars[mode].material = Mat_Star_Unlocked
		else: modeStars[mode].material = Mat_Star_Locked

func setGameModeUnlocked():
	%begin.updateText( "Start" )
	%begin.disabled = false
	%unlockCondition.visible = false
	%lock.visible = false

func setGameModeLocked(reason: String):
	%begin.disabled = true
	%begin.updateText("Coming Soon" if reason == "Coming Soon" else "Locked")
	%unlockCondition.visible = true
	%lock.visible = true
	%unlockCondition.text = " " + reason

#the mode shown when the mode menu opens: the saved one if it can be started here, else Countdown
func defaultGameMode() -> int:
	var mode = SaveManager.getGameMode()
	return mode if Root.isModePlayable(selectedLevelForModes(), mode) else Root.gameModes.GOONCRUSHER

func selectGameMode(newGameMode):
	var level = selectedLevelForModes()
	var reason = Root.modeLockReason(level, newGameMode)
	if reason == "": setGameModeUnlocked()
	else: setGameModeLocked(reason)

	var gameModeName = Root.gameModeDescription[newGameMode].name
	$VBoxContainer2/levelNameContainer.visible = true
	$VBoxContainer2/levelNameContainer/levelName.text = str(SaveManager.playerData.selectedLevel + 1) + ". " + level.name
	%driverName.text = gameModeName

	$gameModeInfo/gameModeLabel.text = gameModeName
	$gameModeInfo.visible = true
	$gameModeInfo/gameModeDescription.text = Root.gameModeDescription[newGameMode].description
	setupGameModeStars()
	highlightAGameModeStar(newGameMode)

func highlightAGameModeStar(mode: int):
	for i in get_tree().get_nodes_in_group("gameModeStar"):
		get_tree().create_tween().tween_property(i , "custom_minimum_size", Vector2(48,48), menuTweenSpeed)
	var myStar = modeStars.get(mode)
	if is_instance_valid(myStar):
		get_tree().create_tween().tween_property(myStar , "custom_minimum_size",  Vector2(84,84), menuTweenSpeed)





func _on_records_button_pressed():
	var scene = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	scene.isGameSummary = false
	add_child(scene)



func _on_back_button_pressed():
	match menuMode:
		menuModes.LEVEL:goToMenuMode(menuModes.RIDER)
		menuModes.GAMEMODE:goToMenuMode(menuModes.LEVEL)
			
		
#RIDER -> LEVEL (levelSelect button) -> GAMEMODE (begin) -> start the run (begin). The checks read the
#save, not the button state, so a press during a menu tween can't start a locked level or mode.
func _on_begin_pressed():
	match menuMode:
		menuModes.LEVEL:
			if isLevelSelectable(SaveManager.playerData.selectedLevel): goToMenuMode(menuModes.GAMEMODE)
		menuModes.GAMEMODE:
			if Root.isModePlayable(selectedLevelForModes(), SaveManager.getGameMode()):
				startLevel(SaveManager.playerData.levels[SaveManager.playerData.selectedLevel].scene)

var loadingLevel := false
#loads the level on a worker thread behind a "Loading" label instead of freezing the menu
func startLevel(path: String) -> void:
	if loadingLevel: return
	loadingLevel = true
	Region.resetRegions()
	SaveManager.flush()
	var label = Label.new()
	label.text = "Loading..."
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(label)
	ResourceLoader.load_threaded_request(path)
	var carScene = Root.selectedCar.scene #the menu only loaded the car's CarInfo; levelRoot instantiates the scene
	if not ResourceLoader.has_cached(carScene): ResourceLoader.load_threaded_request(carScene)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			|| ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_LOADED:
		Root.selectedCarScene = ResourceLoader.load_threaded_get(carScene) #held so the cache keeps it
	await get_tree().process_frame #let the label draw before the level is built
	var scene = ResourceLoader.load_threaded_get(path)
	if scene: get_tree().change_scene_to_node(RunView.wrap(scene.instantiate()))
	else: get_tree().change_scene_to_file(path)

func _on_unlock_pressed():
	if SaveManager.unlockCar():
		selectCar(SaveManager.getCarByName(Root.carInfo.carId))
		
func statUpdatesUiUpdate():
	$carStatsContainer.updateStats()

#run payout: the coins are already credited and saved; this only counts the display up
func animateCoins(from: int, to: int) -> void:
	$carStatsContainer.updateStats()
	var tween = create_tween()
	tween.tween_method(func(v): $carStatsContainer.setCoinDisplay(int(v)), float(from), float(to), clampf((to - from) / 300.0, 0.3, 1.5))
	tween.tween_callback(statUpdatesUiUpdate)
