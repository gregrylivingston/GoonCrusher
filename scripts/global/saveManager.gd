extends Node


var playerData

# Called when the node enters the scene tree for the first time.
func _ready():
	reset_save()
	playerData = load_data()



var save_path = "user://userData.tres"

func load_data():
	if ResourceLoader.exists(save_path):
		return load(save_path)
	else:reset_save()

func reset_save():
	playerData = load("res://scene/player/save/playerData.tres").duplicate()
	save_character_data()
	return playerData

func save_character_data():
	var result = ResourceSaver.save(playerData, save_path)
	
	
var coinScene = preload("res://scene/powerup/coin.tscn")

func addCoins(num: int):
	for i in num/10:
#		var newCoin = coinScene.instantiate()
#		newCoin.global_position = Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
#		Root.mainMenu.get_parent().add_child(newCoin)
#		newCoin.sendReward( Root.playerCar )
		playerData.coin += 10
		Root.mainMenu.statUpdatesUiUpdate()
		await get_tree().process_frame
	playerData.coin += num%10 
	save_character_data()
	

var gemScene = preload("res://scene/powerup/gem.tscn")
	
func addGems(num: int):
	for i in num:
#		var newCoin = gemScene.instantiate()
#		newCoin.global_position = Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
#		Root.mainMenu.get_parent().add_child(newCoin)
#		newCoin.sendReward( Root.playerCar )
		playerData.gem += 1
		Root.mainMenu.statUpdatesUiUpdate()
		await get_tree().process_frame
	save_character_data()

func unlockCar():
	var thisCar = getCarByName(Root.playerCar.carId)
	if playerData.coin >= thisCar.cost:
		playerData.coin -= thisCar.cost
		thisCar.cost = 0
		save_character_data()
		return true
	else: return false
	
func requestStatCost(statString: String):
	return int(pow( getCarByName(Root.playerCar.carId).upgrades[statString] + 1 , 1.8 ) * 15)

func requestStatUpgrade(statString: String):
	var requestCost = requestStatCost(statString)
	if playerData.coin >= requestCost:
		playerData.coin -= requestCost
		getCarByName(Root.playerCar.carId).upgrades[statString] += 1
		save_character_data()
		Root.mainMenu.statUpdatesUiUpdate()
		return true
	else: return false


func setVolume(settingName: String , value: int):
	playerData.settings.volume[settingName] = value
	save_character_data()

func getVolume(settingName: String):
	return playerData.settings.volume[settingName]
	
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
	if not playerData.levels[playerData.selectedLevel + 1].unlocked:
		playerData.levels[playerData.selectedLevel + 1].unlocked = true
		playerData.selectedLevel += 1
	save_character_data()

var carNameToFind
func getCarByName(carName):
	carNameToFind = carName
	return playerData.cars.filter(findCar)[0]
	
	
func findCar(car):
	return car.name == carNameToFind
