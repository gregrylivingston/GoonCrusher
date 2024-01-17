extends Node

var playerCar: OverheadCarBody2D
var selectedCar


var mainMenu: CanvasLayer
var levelRoot
var spawnManager



var isRunActive: bool = false
var earnedCoins: int
var earnedGems: int


@onready var powerup = {
	"health":preload("res://scene/powerup/health.tscn"),
	"fuel":preload("res://scene/powerup/fuel.tscn"),
	"steering":preload("res://scene/powerup/steering.tscn"),
	"engine":preload("res://scene/powerup/engine.tscn"),
	"armor":preload("res://scene/powerup/armor.tscn"),
	"coin":preload("res://scene/powerup/coin.tscn"),
	"purse":preload("res://scene/powerup/purse.tscn"),
	"gem":preload("res://scene/powerup/gem.tscn"),
	"traction":preload("res://scene/powerup/traction.tscn"),
	"slotMachine":preload("res://scene/powerup/slotMachine.tscn"),
	"currentGoonsCrushed":preload("res://scene/powerup/currentGoonsCrushed.tscn"),
}



@onready var cars = {
	"sedan":{
		"scene":preload("res://scene/car/sedan/sedan.tscn"),
	},
	"van":{
		"scene":preload("res://scene/car/van/van.tscn"),
	},
	"taxi":{
		"scene":preload("res://scene/car/taxi/taxi.tscn"),
	},	
	"pickup":{
		"scene":preload("res://scene/car/pickup/pickup.tscn"),
	},
	"semi":{
		"scene":preload("res://scene/car/semi/semi.tscn"),
	},
	"audi":{
		"scene":preload("res://scene/car/audi/audi.tscn")
	},
	"racer":{
		"scene":preload("res://scene/car/racer/racer.tscn")
	},
	"police":{
		"scene":preload("res://scene/car/police/police.tscn"),
	},
	"ambulance":{
		"scene":preload("res://scene/car/ambulance/ambulance.tscn"),
	},

}





# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func getPowerup():
	var randomizer = randf_range(0,100)
	if randomizer > 50:return powerup.coin.instantiate()
	elif randomizer > 48: return powerup.slotMachine.instantiate()	
	elif randomizer > 46: return powerup.purse.instantiate()
	elif randomizer > 44: return powerup.gem.instantiate()	
	elif randomizer > 39: return powerup.health.instantiate()
	elif randomizer > 14: return powerup.fuel.instantiate()	
	elif randomizer > 11: return powerup.engine.instantiate()
	elif randomizer > 8: return powerup.steering.instantiate()
	elif randomizer > 4: return powerup.traction.instantiate()		
	else: return powerup.armor.instantiate()
	
func getSpecificPowerup(pName: String):
	return powerup[pName].instantiate()


func getGoon():return spawnManager.getGoon()

	
