extends Node
class_name landscapeGenerator

@export var inputSeed:int = randi()
@export var inputRandomizeSeed:bool = true
@export var inputSizeX: int = 512
@export var inputSizeY: int = 512 
@export var inputSeaLevel:float = 0.1
@export_range(0,5) var inputNoiseType = 1
@export_range(1,4) var inputFractalType = 4 #"tectonic activity"
@export var inputOceanEdgeH:bool = true
@export var inputOceanEdgeV:bool = true

var noiseImage

var mapDict = []

	
func newSeed( ):
	var noise = FastNoiseLite.new()
	noise.noise_type = int(inputNoiseType)
	noise.fractal_type = int(inputFractalType)
	noise.seed = inputSeed
	noiseImage = noise.get_image(inputSizeX, inputSizeY)

func createNewTerrain():
	mapDict = []
	if inputRandomizeSeed: newSeed()
	var size = Vector2i(inputSizeX, inputSizeY)
	for y in size.y:
		mapDict.push_back([])
		for x in size.x:
			var elevation = noiseImage.get_pixel(x,y).r - float(inputSeaLevel)
			
			if inputOceanEdgeH:
				if x < 20:
					elevation = elevation - ( 20 - x ) * 0.04
				if x > size.x - 20:
					elevation = elevation - (20 + x - size.x )*0.04
			
			if inputOceanEdgeV:
				if y < 20:
					elevation = elevation - ( 20 - y ) * 0.05
				if y > size.y - 20:
					elevation = elevation - (20 + y - size.y )*0.05
			
			var terrainType: int = getTerrainType(elevation)
			var region:int = -1
			if terrainType == Root.terrain.WATER || terrainType == Root.terrain.HILLS:
				region = -2
			mapDict[y].push_back( {	
				"terrain":terrainType,
				"region":region
			} )
	await get_tree().process_frame
	setupStartingTerrain()
	await get_tree().process_frame
	setupRegions()
	
	
func setupRegions():
	for y in inputSizeY:
		for x in inputSizeX:
			if mapDict[y][x].region == -1:
				await recursiveAddToRegion(Vector2i(x,y) , nextRegionToAdd , mapDict[y][x].terrain)
				nextRegionToAdd += 1
				await get_tree().process_frame
				
var nextRegionToAdd: int = 2

func setupStartingTerrain():
	mapDict[inputSizeX/2][inputSizeY/2].terrain = Root.terrain.GRASS
	mapDict[inputSizeY/2][inputSizeX/2].region = 0
	for x in randi()%4 + 3:
		for y in randi()%3 + 3:
			mapDict[inputSizeY/2 + y][inputSizeX/2 + x].terrain = Root.terrain.GRASS
			mapDict[inputSizeY/2 - y][inputSizeX/2 - x].terrain = Root.terrain.GRASS
			mapDict[inputSizeY/2 - y][inputSizeX/2 + x].terrain = Root.terrain.GRASS
			mapDict[inputSizeY/2 - y][inputSizeX/2 + x].terrain = Root.terrain.GRASS
			mapDict[inputSizeY/2 + y][inputSizeX/2 + x].region = 0
			mapDict[inputSizeY/2 - y][inputSizeX/2 - x].region = 0
			mapDict[inputSizeY/2 - y][inputSizeX/2 + x].region = 0
			mapDict[inputSizeY/2 - y][inputSizeX/2 + x].region = 0
	recursiveAddToRegion(Vector2i(inputSizeX/2,inputSizeY/2 ) , 0 , Root.terrain.GRASS)

func recursiveAddToRegion(tileLocation: Vector2i , requestedRegion: int , terrain: int ):
	if mapDict[tileLocation.y][tileLocation.x].region != -1: return
	mapDict[tileLocation.y][tileLocation.x].region = requestedRegion
	await get_tree().process_frame
	if tileLocation.y - 1 >= 0:
		if mapDict[tileLocation.y - 1][tileLocation.x].terrain == terrain:
			recursiveAddToRegion(tileLocation + Vector2i(0,-1) , requestedRegion , terrain)
	if tileLocation.y + 1 < mapDict.size() :
		if mapDict[tileLocation.y + 1][tileLocation.x].terrain == terrain:
			recursiveAddToRegion(tileLocation + Vector2i(0,1) , requestedRegion , terrain)	
	if tileLocation.x - 1 >= 0:
		if mapDict[tileLocation.y][tileLocation.x - 1].terrain == terrain:
			recursiveAddToRegion(tileLocation + Vector2i(-1,0) , requestedRegion , terrain)
	if tileLocation.x + 1 < mapDict[1].size() :
		if mapDict[tileLocation.y ][tileLocation.x + 1].terrain == terrain:
			recursiveAddToRegion(tileLocation + Vector2i(1,0) , requestedRegion , terrain)	
			
			
var currentTerrainType:int = -10
func createTerrainGroups():
	var size = Vector2i(inputSizeX, inputSizeY)
	for y in size.y:
		for x in size.x:
			var tile = mapDict[y][x]
			if tile.region == -1:
				match tile.terrainType:
					Root.terrain.WATER:tile.region = -2
					Root.terrain.HILLS:tile.region = -3

#func setRegion(terrainType):
	
		
					
func searchForRegionByTile(y,x):
	if mapDict.has(y):
		if mapDict.has(x):
			if mapDict[y][x].terrain == currentTerrainType:
				pass
			
func getTerrainType(elevation: float) -> int: #returns Root.terrain
	if elevation > 0.9: return Root.terrain.HILLS
	elif elevation > 0.75: return Root.terrain.SNOW
	elif elevation > 0.6: return Root.terrain.DIRT  #.35
	elif elevation > 0.45: return Root.terrain.MUD  #.15 (this was too high)
	elif elevation > 0.35: return Root.terrain.GRASS   #.15 (this was too high)
	elif elevation > 0.1: return Root.terrain.MOSS   #.15 (this was too high)
	elif elevation > -0.21: return Root.terrain.SAND   #.15 (this was too high)
	else: return Root.terrain.WATER




