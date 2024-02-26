extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.




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
}

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
		"goon":[
			getRandomGoon(),getRandomGoon(),getRandomGoon(),
		],
	}
	return thisRegion


func getRandomGoon():
	return Root.goon[ Root.goon.keys()[randi()%Root.goon.size() - 1 ] ]
	
	
	
	
	
	#still needs at least....
	#terrain objects
	#objectives
	#goons
	
