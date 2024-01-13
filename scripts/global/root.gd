extends Node

var playerCar: OverheadCarBody2D
var selectedCar
var mainMenu: CanvasLayer
var levelRoot

var isRunActive: bool = false
var earnedCoins: int
var earnedGems: int


var color = [
	Color("#8E9B90"),
	Color("#93C0A4"),
	Color("#B6C4A2"),
	Color("#D4CDAB"),
	Color("#DCE2BD"),
]

@onready var powerup = {
	"health":preload("res://scene/powerup/health.tscn"),
	"fuel":preload("res://scene/powerup/fuel.tscn"),
	"steering":preload("res://scene/powerup/steering.tscn"),
	"engine":preload("res://scene/powerup/engine.tscn"),
	"armor":preload("res://scene/powerup/armor.tscn"),
	"coin":preload("res://scene/powerup/coin.tscn"),
	"purse":preload("res://scene/powerup/purse.tscn"),
	"gem":preload("res://scene/powerup/gem.tscn"),
	"brakes":preload("res://scene/powerup/brakes.tscn"),
}

@onready var goon = {
	"devil":preload("res://scene/enemy/walker/devil/devil.tscn"),
	"spartan":preload("res://scene/enemy/walker/spartan/spartan.tscn"),
	"samurai":preload("res://scene/enemy/walker/samurai/samurai.tscn"),
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

var currentGoonsCrushed = 0
var selectedCarType


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func getPowerup():
	var randomizer = randf_range(0,100)
	if randomizer > 58:return powerup.coin.instantiate()
	elif randomizer > 52: return powerup.purse.instantiate()
	elif randomizer > 50: return powerup.gem.instantiate()	
	elif randomizer > 30: return powerup.health.instantiate()
	elif randomizer > 10: return powerup.fuel.instantiate()	
	elif randomizer > 7.5: return powerup.engine.instantiate()
	elif randomizer > 5.0: return powerup.steering.instantiate()
	elif randomizer > 2.5: return powerup.brakes.instantiate()		
	else: return powerup.armor.instantiate()
	
func getGoon():
	var randomizer = randf_range(0,100)
	if randomizer > 30:return goon.devil.instantiate()
	elif randomizer > 10: return goon.spartan.instantiate()
	else: return goon.samurai.instantiate()
		
