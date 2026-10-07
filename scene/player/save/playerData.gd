class_name PlayerData extends Resource

#Renaming or moving this file breaks existing saves: the .tres embeds this script path.
#SaveManager.migrate() merges every loaded save with the defaults below.
@export var saveVersion: int = 0
@export var coin: int = 0
@export var gem: int = 0
@export var selectedCar: int = 0
@export var selectedLevel: int = 0
@export var gameMode: int = 0
#goon id (Goons.DATA) -> how many the player has crushed, over every run; the Goonopedia reveals a goon
#once it is crushed. Credited by gameSummary when a run ends.
@export var goonsCrushed := {}
#Everything that isn't a car or a level, one section per feature. migrate() adds any section an
#older save lacks. records: best runs per level and car (SaveManager.recordGoonpocalypse); hints: one-time
#tips already shown; lifetime: totals over every run; medals and achievements: earned ids.
@export var meta := {"records":{}, "hints":{}, "lifetime":{}, "medals":{}, "achievements":{}}

@export var cars = [
	{	"name":"sedan",
		"cost":0,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/sedan/sedan.tscn",
	},
	{	"name":"van",
		"cost":1000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/van/van.tscn",
	},
	{	"name":"taxi",
		"cost":2000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/taxi/taxi.tscn",
	},	
	{	"name":"pickup",
		"cost":2500,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/pickup/pickup.tscn",
	},
	{	"name":"semi",
		"cost":5000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/semi/semi.tscn",
	},
	{	"name":"audi",
		"cost":10000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/audi/audi.tscn"
	},
	{	"name":"racer",
		"cost":10000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/racer/racer.tscn"
	},
	{	"name":"police",
		"cost":25000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/police/police.tscn",
	},
	{	"name":"ambulance",
		"cost":35000,
		"upgrades":{},
		"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,"score":0,"combo":0,},
		"scene":"res://scene/car/ambulance/ambulance.tscn",
	}
]


#Demo-era volumes. Read once by Settings.import_legacy_volume(), never written. Keep it for
#one release so old saves still load, then delete it.
@export var settings = {
	"volume":{
		"master":0,"voice":0,"music":0,"fx":0,
	}
}


#One entry per level in Levels.ORDER: {id, name, image, unlocked, scene, gamemodeBeat}. The level's content
#lives in its LevelDef (Levels.get_def(id)); name, image and scene are copies migrate() refreshes on load.
@export var levels: Array = Levels.defaultEntries()
