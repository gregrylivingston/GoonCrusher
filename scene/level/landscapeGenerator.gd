extends Node
class_name landscapeGenerator

@export var inputSeed:int = randi()
@export var inputRandomizeSeed:bool = true
@export var inputSizeX: int = 512
@export var inputSizeY: int = 512 
@export var inputSeaLevel:float = 0.1
@export_range(0,5) var inputNoiseType = 1
@export_range(0,3) var inputFractalType = 0 #"tectonic activity". Was 4, an invalid value that FastNoiseLite treats as 0 (no fractal)
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
	#read the noise as raw bytes (same values as get_pixel().r, without 65k Color allocations)
	if noiseImage.get_format() != Image.FORMAT_L8: noiseImage.convert(Image.FORMAT_L8)
	var noiseBytes = noiseImage.get_data()
	for y in size.y:
		mapDict.push_back([])
		for x in size.x:
			var elevation = noiseBytes[y * size.x + x] / 255.0 - float(inputSeaLevel)
			
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
	
	
#Regions are connected areas of one terrain type, labelled by an iterative flood fill.
#The start region is labelled at once; the rest is labelled within a few ms per frame,
#which finishes during the countdown.
const REGION_BUDGET_USEC = 3000

func setupRegions():
	var frameStart = Time.get_ticks_usec()
	for y in inputSizeY:
		for x in inputSizeX:
			if mapDict[y][x].region == -1:
				floodRegion([Vector2i(x,y)], nextRegionToAdd, mapDict[y][x].terrain)
				nextRegionToAdd += 1
				if Time.get_ticks_usec() - frameStart > REGION_BUDGET_USEC:
					if not is_instance_valid(get_tree()): return
					await get_tree().process_frame
					frameStart = Time.get_ticks_usec()
					
var nextRegionToAdd: int = 2

func setupStartingTerrain():
	mapDict[inputSizeX/2][inputSizeY/2].terrain = Root.terrain.GRASS
	mapDict[inputSizeY/2][inputSizeX/2].region = 0
	var startTiles: Array[Vector2i] = [Vector2i(inputSizeX/2, inputSizeY/2)]
	for x in randi()%4 + 3:
		for y in randi()%3 + 3:
			for tile in [Vector2i(inputSizeX/2 + x, inputSizeY/2 + y), Vector2i(inputSizeX/2 - x, inputSizeY/2 - y), Vector2i(inputSizeX/2 + x, inputSizeY/2 - y)]:
				mapDict[tile.y][tile.x].terrain = Root.terrain.GRASS
				mapDict[tile.y][tile.x].region = -1
				startTiles.push_back(tile)
	mapDict[inputSizeY/2][inputSizeX/2].region = -1
	floodRegion(startTiles, 0, Root.terrain.GRASS)

#labels every tile of `terrain` connected to `seeds` that has no region yet
func floodRegion(seeds: Array, requestedRegion: int, terrain: int) -> void:
	var stack: Array[Vector2i] = []
	for tile in seeds:
		if mapDict[tile.y][tile.x].region == -1:
			mapDict[tile.y][tile.x].region = requestedRegion
			stack.push_back(tile)
	while not stack.is_empty():
		var tile = stack.pop_back()
		for next in [tile + Vector2i(0,-1), tile + Vector2i(0,1), tile + Vector2i(-1,0), tile + Vector2i(1,0)]:
			if next.y < 0 || next.y >= mapDict.size() || next.x < 0 || next.x >= mapDict[0].size(): continue
			var cell = mapDict[next.y][next.x]
			if cell.region == -1 && cell.terrain == terrain:
				cell.region = requestedRegion
				stack.push_back(next)
				
			
func getTerrainType(elevation: float) -> int: #returns Root.terrain
	if elevation > 0.9: return Root.terrain.HILLS
	elif elevation > 0.75: return Root.terrain.SNOW
	elif elevation > 0.6: return Root.terrain.DIRT  #.35
	elif elevation > 0.45: return Root.terrain.MUD  #.15 (this was too high)
	elif elevation > 0.35: return Root.terrain.GRASS   #.15 (this was too high)
	elif elevation > 0.1: return Root.terrain.MOSS   #.15 (this was too high)
	elif elevation > -0.21: return Root.terrain.SAND   #.15 (this was too high)
	else: return Root.terrain.WATER
