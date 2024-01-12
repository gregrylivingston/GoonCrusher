extends Node


var playerData

# Called when the node enters the scene tree for the first time.
func _ready():
	playerData = load_data()



var save_path = "user://userData.save"

func load_data():
	if ResourceLoader.exists(save_path):
		return load(save_path)
	else:
		var data = load("res://scene/player/save/playerData.tres")
		save_character_data()
		return data

func save_character_data():
	ResourceSaver.save(playerData, save_path)
	
	
var coinScene = preload("res://scene/powerup/coin.tscn")

func addCoins(num: int):
	for i in num/10:
		var newCoin = coinScene.instantiate()
		newCoin.global_position = Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
		Root.mainMenu.get_parent().add_child(newCoin)
		newCoin.sendReward( Root.playerCar )
		playerData.coin += 10
		Root.mainMenu.uiUpdate()
		await get_tree().process_frame
	playerData.coin += num%10 
	save_character_data()
	

var gemScene = preload("res://scene/powerup/gem.tscn")
	
func addGems(num: int):
	for i in num:
		var newCoin = gemScene.instantiate()
		newCoin.global_position = Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
		Root.mainMenu.get_parent().add_child(newCoin)
		newCoin.sendReward( Root.playerCar )
		playerData.gem += 1
		Root.mainMenu.uiUpdate()
		await get_tree().process_frame
	save_character_data()

