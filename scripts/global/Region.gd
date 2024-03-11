extends Node

var waveLength: int = 60

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _process(delta):
	if currentRegion.has("time") && Root.isRunActive:
		currentRegion.time += delta
		if currentRegion.wave * waveLength < currentRegion.time && currentRegion.wave < 4:
			currentRegion.wave += 1
			Root.playerCar.star += 1
			Root.playerRoot.animateNewRegion(true)


var names: Dictionary = {
	Root.terrain.GRASS: [
		"Goon Fields", "Goonvale", "Peaceful Meadow", "Goon Park",
		"Emerald Expanse", "Whisperwind Plains", "Verdant Valley", "Greenhaven Glade",
		"Sunlit Savanna", "Bloomridge Field", "Meadowbrook Glade", "Serenity Fields"
	],
	Root.terrain.MUD: [
		"Mudtown", "Dust Valley", "Goon Pits", "Muddy Barrens",
		"Slick Quarry", "Claymore Canyon", "Mudslide Domain", "Bogland Basin",
		"Sludge Hollow", "Grimy Gulch", "Swampland Shallows", "Marshland Maze"
	],
	Root.terrain.SAND: [
		"Goon Beach", "Sand Alley", "The Dunes", "Doonvale",
		"Golden Sands Shore", "Desert Mirage", "Sandy Oasis", "Sunset Dunes",
		"Quicksand Quarters", "Dune Labyrinth", "Silica Valley", "Scorching Plains"
	],
	Root.terrain.MOSS: [
		"Mossy Barrens",
		"Verdigris Forest", "Mossblanket Vale", "Lichen Ledge",
		"Ferngully Thicket", "Sporing Grounds", "Emerald Moss Marsh", "Velvet Verdure"
	],
	Root.terrain.DIRT: [
		"Dusty Lane",
		"Barren Bluffs", "Gravel Grounds", "Loam Lands",
		"Earthenway Path", "Clodhopper Row", "Tilled Fields", "Soilrich Hollow"
	],
	Root.terrain.SNOW: [
		"The Tundra",
		"Frostbite Fields", "Snowdrift Valley", "Icicle Isle",
		"Glacial Basin", "Winter's Edge", "Permafrost Plains", "Chillwind Wastes"
	]
}

func resetRegions():
	regions = {
	-2:{
		"name":"Wasteland",
		"giantism":0,
		"terrain_modulate":1.0,
	},
	0:getRegion(0,Root.terrain.GRASS)
	}
	currentRegion = {}
	currentRegionNumber = -99

@onready var regions: Dictionary = {
	-2:{
		"name":"Wasteland","giantism":0,"terrain_modulate":1.0,
	},
	0:getRegion(0,Root.terrain.GRASS)
}
var currentRegion: Dictionary
var currentRegionNumber: int = -99

func getRegion(regionNumber: int , terrainType: int) -> Dictionary:
	if regions.has(regionNumber) || regionNumber == -2:
		currentRegion = regions[regionNumber]
		currentRegionNumber = regionNumber
		return regions[regionNumber]
	else:
		var newRegion = createRegion(terrainType)
		regions.merge({regionNumber:newRegion})
		currentRegion = newRegion
		currentRegionNumber = regionNumber
		return newRegion
		
func createRegion(terrain: int) -> Dictionary:#terrain is Enum Root.terrain
	var thisRegion = {
		"name": names[ terrain ][ randi()%names[terrain].size() - 1 ],
		"terrain":terrain,
		"giantism":randi()%100,
		"time":0.0,
		"wave":1,
		"goon":[
			getRandomGoon(terrain),getRandomGoon(terrain),getRandomGoon(terrain),
		],
		"terrain_modulate":randf_range(0.8,1.2),
	}
	return thisRegion

var terrainGoons = {
	Root.terrain.SAND:[
		Root.goon.FIREKIN, Root.goon.SHELLBACK, Root.goon.SKELETON
	],
	Root.terrain.MOSS:[
		Root.goon.SHELLBACK, Root.goon.RAT, Root.goon.GREMLIN, Root.goon.LIZARD
	],
	Root.terrain.GRASS:[
		Root.goon.DEVIL, Root.goon.PIKEMAN, Root.goon.SAMURAI, Root.goon.SPARTAN, Root.goon.SOLDIER
	],
	Root.terrain.MUD:[
		Root.goon.ZULU, Root.goon.SMASHER, Root.goon.IMMORTAL, Root.goon.VIKING, Root.goon.SPARTAN,  Root.goon.SOLDIER
	],
	Root.terrain.DIRT:[
		Root.goon.ROCKMAN, Root.goon.DOOMCART, Root.goon.GREMLIN, Root.goon.SKELETON
	],
	Root.terrain.SNOW:[
		Root.goon.GOONBEAR, Root.goon.ROCKMAN, Root.goon.LIZARD,  Root.goon.SKELETON
	],
}

func getRandomGoon(terrain: int): #accepts Root.terrain
	return terrainGoons[terrain][ randi()%terrainGoons[terrain].size()-1 ]
	
	
	
func updatePlayerRegion(tile):
	if currentRegionNumber != tile.region:
		Root.playerRoot.animateNewRegion(true)
	currentRegionNumber = tile.region
	currentRegion = getRegion(tile.region , tile.terrain)
	
	await get_tree().process_frame
	Root.playerRoot.updatePlayerRegion(tile)
	Root.playerCar.setTerrain(tile.terrain)
	
	if currentRegion.has("goon"):Root.spawnManager.basicGoons = currentRegion.goon
	
	
	#still needs at least....
	#terrain objects
	#objectives
	#goons
	
