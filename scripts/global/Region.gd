extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _process(delta):
	if currentRegion.has("time"):
		currentRegion.time += delta
		if currentRegion.wave * 120 < currentRegion.time:
			currentRegion.wave += 1


var names: Dictionary = {
	Root.terrain.GRASS:[
		"Goon Fields" , "Goonvale" , "Peaceful Meadow" , "Goon Park"
	],
	Root.terrain.MUD:[
		"Mudtown" , "Dust Valley" , "Goon Pits" , "Muddy Barrens"
	],
	Root.terrain.SAND:[
		"Goon Beach" , "Sand Alley" , "The Dunes" , "Doonvale" 
	],
	Root.terrain.MOSS:[
		"Mossy Barrens",
	],
	Root.terrain.DIRT:[
		"Dusty Lane",
	],
	Root.terrain.SNOW:[
		"The Tundra",
	]
}

func resetRegions():
	regions = {
	-2:{
		"name":"Wasteland",
		"giantism":0,
	}}
	currentRegion = {}
	currentRegionNumber = -99

var regions: Dictionary = {
	-2:{
		"name":"Wasteland","giantism":0
	},
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
	
