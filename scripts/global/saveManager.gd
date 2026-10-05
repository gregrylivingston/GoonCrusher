extends Node

#Progress save. Settings live in user://settings.cfg (see Settings); only progress is kept here.
#The demo and the full game share this file, so demo progress carries over: load_data() merges
#each save with the current defaults (migrate()) before anything reads it.

const SAVE_VERSION := 1
var save_path = "user://saveData_0.1.tres"
var playerData: PlayerData
var saveTimer: Timer
var dirty := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	saveTimer = Timer.new()
	saveTimer.one_shot = true
	saveTimer.wait_time = 1.0
	saveTimer.timeout.connect(flush)
	add_child(saveTimer)
	#reset_save()   ###add this line here, start the game, then remove it
	playerData = load_data()
	if get_tree().has_signal("scene_changed"): get_tree().connect("scene_changed", flush)

func _exit_tree():
	flush()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST: flush()

func load_data():
	if ResourceLoader.exists(save_path):
		var data = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if data is PlayerData:
			Settings.import_legacy_volume(data.settings.get("volume", {}))
			playerData = data
			if migrate(): save_character_data()
			return playerData
	return reset_save()

func reset_save():
	playerData = load("res://scene/player/save/playerData.tres").duplicate(true)
	playerData.saveVersion = SAVE_VERSION
	save_character_data()
	flush()
	return playerData

#Merge the saved file with the current defaults. New cars and levels are added, moved scene
#paths and new record keys are picked up, and price changes reach cars that are still locked.
#Returns true when anything changed.
func migrate() -> bool:
	var defaults = PlayerData.new()
	var before = var_to_str([playerData.cars, playerData.levels, playerData.saveVersion])
	for defaultCar in defaults.cars:
		var saved = playerData.cars.filter(func(c): return c.name == defaultCar.name)
		if saved.is_empty():
			playerData.cars.push_back(defaultCar.duplicate(true))
			continue
		var car = saved[0]
		car.scene = defaultCar.scene
		if car.cost != 0: car.cost = defaultCar.cost
		for key in defaultCar:
			if not car.has(key): car[key] = defaultCar[key].duplicate(true) if defaultCar[key] is Dictionary else defaultCar[key]
		for key in defaultCar.records:
			if not car.records.has(key): car.records[key] = 0
	#levels were not saved before version 1, so older saves get the defaults here
	var mergedLevels = []
	for i in defaults.levels.size():
		var level = defaults.levels[i].duplicate(true)
		if i < playerData.levels.size():
			var saved = playerData.levels[i]
			level.unlocked = saved.get("unlocked", level.unlocked)
			for mode in saved.get("gamemodeBeat", {}): level.gamemodeBeat[mode] = saved.gamemodeBeat[mode]
		mergedLevels.push_back(level)
	playerData.levels = mergedLevels
	playerData.selectedCar = clampi(playerData.selectedCar, 0, playerData.cars.size() - 1)
	playerData.selectedLevel = clampi(playerData.selectedLevel, 0, playerData.levels.size() - 1)
	playerData.saveVersion = SAVE_VERSION
	return before != var_to_str([playerData.cars, playerData.levels, playerData.saveVersion])

#marks the save dirty; it is written one second after the last change, on scene change and on exit
func save_character_data():
	dirty = true
	if is_instance_valid(saveTimer) && saveTimer.is_inside_tree(): saveTimer.start()

func flush():
	if not dirty || playerData == null: return
	dirty = false
	ResourceSaver.save(playerData, save_path)


#credits the whole amount and saves first; the menu then counts the display up
func addCoins(num: int):
	if num == 0: return
	var start = playerData.coin
	playerData.coin += num
	save_character_data()
	flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.animateCoins(start, playerData.coin)

func addGems(num: int):
	if num == 0: return
	playerData.gem += num
	save_character_data()
	flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()

func unlockCar():
	var thisCar = getCarByName(Root.playerCar.carId)
	if playerData.coin >= thisCar.cost:
		playerData.coin -= thisCar.cost
		thisCar.cost = 0
		save_character_data()
		return true
	else: return false

#how much the next upgrade will cost
func requestStatCost(statString: Root.upgrade) -> int:
	return int(pow( getUpgradeLevel(statString) + 1 , 1.6 ) * 15)

func requestStatUpgrade(statString: Root.upgrade) -> bool:
	var requestCost = requestStatCost(statString)
	if playerData.coin >= requestCost:
		playerData.coin -= requestCost
		var upgrades = getCarByName(Root.playerCar.carId).upgrades
		upgrades[statString] = upgrades.get(statString, 0) + 1
		save_character_data()
		Root.mainMenu.statUpdatesUiUpdate()
		return true #true because upgrade went through
	else: return false #false if upgrade not allowed

#gets the current cars upgrade value for a specific upgrade type
func getUpgradeLevel(upgradeType:Root.upgrade) -> int:
	return playerData.cars[playerData.selectedCar].upgrades.get(upgradeType, 0)

func selectNextLevel():
	if playerData.selectedLevel < playerData.levels.size() - 1:
		playerData.selectedLevel += 1
	else: playerData.selectedLevel = 0
	save_character_data()
	return playerData.levels[playerData.selectedLevel]

func selectPreviousLevel():
	if playerData.selectedLevel > 0:playerData.selectedLevel -= 1
	else: playerData.selectedLevel = playerData.levels.size() - 1
	save_character_data()
	return playerData.levels[playerData.selectedLevel]


func selectNextCar():
	if playerData.selectedCar < playerData.cars.size() - 1:
		playerData.selectedCar += 1
	else: playerData.selectedCar = 0
	save_character_data()
	return playerData.cars[playerData.selectedCar]

func selectPreviousCar():
	if playerData.selectedCar > 0: playerData.selectedCar -= 1
	else: playerData.selectedCar = playerData.cars.size() - 1
	save_character_data()
	return playerData.cars[playerData.selectedCar]


func currentLevelPassed():
	playerData.levels[playerData.selectedLevel].gamemodeBeat[playerData.gameMode] = true
	var next = playerData.selectedLevel + 1
	if next < playerData.levels.size() && not playerData.levels[next].unlocked:
		playerData.levels[next].unlocked = true
		playerData.selectedLevel = next
		playerData.gameMode = Root.gameModes.GOONCRUSHER
	save_character_data()

var carNameToFind
func getCarByName(carName):
	carNameToFind = carName
	return playerData.cars.filter(findCar)[0]


func findCar(car):
	return car.name == carNameToFind

func getGameMode():
	return playerData.gameMode

func selectNextGameMode():
	playerData.gameMode = wrap( playerData.gameMode + 1, 0 , Root.gameModes.size() )
	save_character_data()
	return playerData.gameMode

func selectPreviousGameMode():
	playerData.gameMode = wrap( playerData.gameMode  -1, 0 , Root.gameModes.size() )
	save_character_data()
	return playerData.gameMode
