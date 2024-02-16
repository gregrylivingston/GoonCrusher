extends Resource

@export var coin: int = 200
@export var gem: int = 3
@export var selectedCar: int = 0
@export var selectedLevel: int = 0
@export var gameMode: int = 0

@export var cars = [
	{	"name":"sedan",
		"cost":0,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/sedan/sedan.tscn",
	},
	{	"name":"van",
		"cost":1000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/van/van.tscn",
	},
	{	"name":"taxi",
		"cost":5000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/taxi/taxi.tscn",
	},	
	{	"name":"pickup",
		"cost":10000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/pickup/pickup.tscn",
	},
	{	"name":"semi",
		"cost":20000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/semi/semi.tscn",
	},
	{	"name":"audi",
		"cost":40000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/audi/audi.tscn"
	},
	{	"name":"racer",
		"cost":50000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/racer/racer.tscn"
	},
	{	"name":"police",
		"cost":75000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/police/police.tscn",
	},
	{	"name":"ambulance",
		"cost":100000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
		"scene":"res://scene/car/ambulance/ambulance.tscn",
	}
]


@export var settings = {
	"volume":{
		"master":0,"voice":0,"music":0,"fx":0,
	}
}


@export var levels = [
	{
		"name":"Goon Park",
		"image":"res://texture/background/background_level_1.png",
		"unlocked":true,
		"scene":"res://scene/level/levels/level_grass_1.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
		"time":"1",
	},
	{
		"name":"Park Bully",
		"image":"res://texture/background/background_level_2.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_grass_2.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"Field of Giants",
		"image":"res://texture/background/background_grass_3.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_grass_3.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"Muddy Barrens",
		"image":"res://texture/background/mud_background1.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_1.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"Pikes of Mud",
		"image":"res://texture/background/mud_background2.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_2.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"Pools of Agony",
		"image":"res://texture/background/mud_background3.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_mud_3.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"The Dunes",
		"image":"res://texture/background/desertBackground.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_sand_1.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
	{
		"name":"Northern Wastes",
		"image":"res://texture/background/iceBackground.png",
		"unlocked":false,
		"scene":"res://scene/level/levels/level_snow_1.tscn",
		"gamemodeBeat":{ Root.gameModes.COUNTDOWN: false ,  Root.gameModes.SPRINT: false ,  Root.gameModes.MARATHON: false ,  Root.gameModes.DEFENSE: false  },
	},
]
