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
		var carData = load("res://scene/player/save/playerData.tres")
		save_character_data(carData)
		return carData

func save_character_data(data):
	ResourceSaver.save(data, save_path)
