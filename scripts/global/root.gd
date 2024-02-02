extends Node

enum gameModes {  COUNTDOWN, SPRINT, MARATHON, DEFENSE, GOONPOCALYPSE }
var gameMode: gameModes = gameModes.COUNTDOWN

var playerCar: OverheadCarBody2D
var selectedCar: Dictionary
var timer: float #the timer during a game run


var mainMenu: CanvasLayer
var levelRoot: Node2D
var spawnManager
var playerRoot #this is basically the inlevel UI

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

var defaultPowerupWeights = {
	"gem":4,
	"coin":100,
	"purse":4,
	"slotMachine":1,
	"health":10,
	"fuel":10,
	"traction":4,
	"steering":4,
	"armor":4,
	"engine":4,
}

func getPowerup():
	return getPowerupFromWeights( defaultPowerupWeights )

	
func oldGetPowerup():
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
	
func getPowerupFromWeights( powerupWeightDict ):
	var weightTotal = 0
	for i in powerupWeightDict:
		weightTotal += powerupWeightDict[i]
	var myRandomNumber = randi_range(0 , weightTotal)
	for i in powerupWeightDict:
		weightTotal -= powerupWeightDict[i]
		if weightTotal <= myRandomNumber:
			return powerup[i].instantiate()
		
	
func getSpecificPowerup(pName: String) -> Powerup:
	return powerup[pName].instantiate()


func getGoon():return spawnManager.getGoon()


var gameModeDescription: Dictionary = {
	Root.gameModes.COUNTDOWN:{
		"description":"Survive the countdown while crushing increasing powerful waves of goon.",
	},
	Root.gameModes.SPRINT:{
		"description":"Race against the goons, rocks, and clocks to reach the finish line.",
	},
	Root.gameModes.DEFENSE:{
		"description":"Stop the goons from reaching the barrier.",
	},
	Root.gameModes.MARATHON:{
		"description":"Outlast, outwit, and survive in this marathon race.",
	},
	Root.gameModes.GOONPOCALYPSE:{
		"description":"Survive as long as you can against increasingly powerful waves of goon.",
	},
}
	
