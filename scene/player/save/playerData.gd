extends Resource
class_name playerData

var coin: int = 1200
var gem: int = 3
var selectedCar: int = 0
var selectedLevel: int = 0

var cars = {
	"sedan":{
		"cost":0,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/sedan/sedan.tscn"),
	},
	"van":{
		"cost":0,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/van/van.tscn"),
	},
	"taxi":{
		"cost":1000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/taxi/taxi.tscn"),
	},	
	"pickup":{
		"cost":2500,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/pickup/pickup.tscn"),
	},
	"semi":{
		"cost":5000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/semi/semi.tscn"),
	},
	"audi":{
		"cost":20000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/audi/audi.tscn")
	},
	"racer":{
		"cost":25000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/racer/racer.tscn")
	},
	"police":{
		"cost":50000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/police/police.tscn"),
	},
	"ambulance":{
		"cost":75000,
		"upgrades":{"traction":0,"engine":0,"armor":0,"steering":0},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":preload("res://scene/car/ambulance/ambulance.tscn"),
	}
}


var settings = {
	"volume":{
		"master":0,"voice":0,"music":0,"fx":0,
	}
}


var levels = [
	{
		"name":"Goon Park",
		"image":"res://texture/background/background_level_1.png",
		"unlocked":true,
		"scene":"res://scene/level/levels/level_grass_1.tscn",
		"difficulty":"VERY EASY",
		"time":"1",
	},
	{
		"name":"Park Bully",
		"image":"res://texture/background/background_level_2.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_grass_2.tscn",
		"difficulty":"VERY EASY",
		"time":"1",
	},
	{
		"name":"Field of Giants",
		"image":"res://texture/background/background_grass_3.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_grass_3.tscn",
		"difficulty":"VERY EASY",
		"time":"2",
	},
	{
		"name":"Muddy Barrens",
		"image":"res://texture/background/mud_background1.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_1.tscn",
		"difficulty":"EASY",
		"time":"2",
	},
	{
		"name":"Pikes of Mud",
		"image":"res://texture/background/mud_background2.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_2.tscn",
		"difficulty":"EASY",
		"time":"2",
	},
	{
		"name":"Pools of Agony",
		"image":"res://texture/background/mud_background3.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_3.tscn",
		"difficulty":"MEDIUM",
		"time":"3",
	},
	{
		"name":"...",
		"image":"res://texture/background/desertBackground.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_sand_1.tscn",
		"difficulty":"MEDIUM",
		"time":"3",
	},
	{
		"name":"...",
		"image":"res://texture/background/iceBackground.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_snow_1.tscn",
		"difficulty":"VERY HARD",
		"time":"4",
	},
]
