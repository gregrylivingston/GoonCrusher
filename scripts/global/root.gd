extends Node

enum gameModes {  COUNTDOWN, SPRINT, MARATHON, DEFENSE, GOONPOCALYPSE }
enum endCondition { NOGAS , NOHEALTH , NOTIME , SUCCESS }
enum upgrade { HEALTH , FUEL , ARMOR , ENGINE , TRACTION , STEERING , CLOVER , LUCK , HEADLIGHTS , OIL , COIN , PURSE , GEM , SLOTMACHINE, CURRENTGOONSCRUSHED}
enum terrain { GRASS , SAND , MUD , WATER , HILLS , MOSS , DIRT , SNOW}
enum goon { DEVIL , SPARTAN , SAMURAI , FIREKIN, PIKEMAN }

var playerCar: OverheadCarBody2D
var station  #this is the gas-station / house thing
var selectedCar: Dictionary


var mainMenu: CanvasLayer
var levelRoot: Node2D
var spawnManager: SpawnManager
var playerRoot: GameUI #this is basically the inlevel UI

var isRunActive: bool = false
var earnedCoins: int
var earnedGems: int


@onready var powerup = {
	upgrade.HEALTH:preload("res://scene/powerup/health.tscn"),
	upgrade.FUEL:preload("res://scene/powerup/fuel.tscn"),
	upgrade.STEERING:preload("res://scene/powerup/steering.tscn"),
	upgrade.ENGINE:preload("res://scene/powerup/engine.tscn"),
	upgrade.ARMOR:preload("res://scene/powerup/armor.tscn"),
	upgrade.TRACTION:preload("res://scene/powerup/traction.tscn"),
	
	upgrade.COIN:preload("res://scene/powerup/coin.tscn"),
	upgrade.PURSE:preload("res://scene/powerup/purse.tscn"),
	upgrade.GEM:preload("res://scene/powerup/gem.tscn"),
	upgrade.SLOTMACHINE:preload("res://scene/powerup/slotMachine.tscn"),
	upgrade.CURRENTGOONSCRUSHED:preload("res://scene/powerup/currentGoonsCrushed.tscn"),
}
	
func getPowerupFromWeights( powerupWeightDict:Dictionary ) -> Powerup:
	var weightTotal = 0
	for i in powerupWeightDict:
		weightTotal += powerupWeightDict[i]
	var myRandomNumber = randi_range(0 , weightTotal)
	for i in powerupWeightDict:
		weightTotal -= powerupWeightDict[i]
		if weightTotal <= myRandomNumber:
			return powerup[i].instantiate()
	return powerup[upgrade.COIN].instantiate()

func getSpecificPowerup(pName: upgrade) -> Powerup:
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
	
	


