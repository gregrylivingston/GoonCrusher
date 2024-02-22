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
			
			mapDict[y].push_back( {	
				"terrainType":terrainType,
				"region":-1
			} )

func getTerrainType(elevation):
	if elevation > 0.65: return Root.terrain.HILLS
	elif elevation > 0.55: return Root.terrain.MUD
	elif elevation > 0.35: return Root.terrain.GRASS
	elif elevation > 0.15: return Root.terrain.SAND
	else: return Root.terrain.WATER




