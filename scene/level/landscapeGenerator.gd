extends Node
class_name landscapeGenerator

@export var inputSeed:int = randi()
@export var inputRandomizeSeed:bool = true
@export var inputSizeX: int = 512
@export var inputSizeY: int = 512 
@export var inputSeaLevel:float = 0.1
@export_range(0,5) var inputNoiseType = 1
@export_range(1,4) var inputFractalType = 4 #"tectonic activity"
@export var inputSimulateLatitude: bool = false
@export_range(0.1,0.9) var inputAverageTemperature = 0.5
@export_range(0.05,0.35) var inputMountains = 0.25
@export var inputOceanEdgeH:bool = true
@export var inputOceanEdgeV:bool = true

var noiseImage
var desertNoiseImage
var mapDict = []

var baseTiles = {   #these vectors correspond to the base tile in tileset 0 for that terrain layer
	0:Vector2i(1,9), #grass
	1:Vector2i(28,3), #water
	3: Vector2i(19,15), #snow
	4: Vector2i(19,9), #desert
	5: Vector2i(13,3), #hills
}
var tilesByType = [[],[],[],[],[],[]] #list of tiles by type may be unnecessary...

	
func newSeed( ):
	var noise = FastNoiseLite.new()
	noise.noise_type = int(inputNoiseType)
	noise.fractal_type = int(inputFractalType)
	noise.seed = inputSeed
	noiseImage = noise.get_image(inputSizeX, inputSizeY)
	
	var desertNoise = FastNoiseLite.new()
	desertNoise.seed = randi()
	desertNoiseImage = desertNoise.get_image(inputSizeX, inputSizeY)


func createNewTerrain():
	mapDict = []
	if inputRandomizeSeed: newSeed()
	var size = Vector2i(inputSizeX, inputSizeY)
	for y in size.y:
		mapDict.push_back([])
		var latitudeBelt = absf((float(y) / size.y) - .5)
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
			
			var isWater = false
			if elevation < 0: isWater = true
			var snowChance = noiseImage.get_pixel(x,y).r - 0.5
			if inputSimulateLatitude: snowChance = noiseImage.get_pixel(x,y).r /4 + latitudeBelt
			var hasSnow = snowChance > inputAverageTemperature

			var myDictEntry
			if isWater:
				myDictEntry = {
					"elevation":elevation,
					"terrainInfoArray":[isWater, hasSnow, false, false],
				}
			else:
				#place mountains
				var hasHills = elevation > 0.4 - inputMountains
				#place deserts
				var desertLatitudeProbability = 0.07
				if inputSimulateLatitude:desertLatitudeProbability = absf(latitudeBelt - 0.15)
				var hasDesert = desertNoiseImage.get_pixel(x,y).r > 0.9-clampf(inputAverageTemperature,0.4,1.0) + desertLatitudeProbability * 3 + elevation
				
				myDictEntry = {	
					"elevation":elevation,
					"terrainInfoArray":[isWater,hasSnow,hasDesert,hasHills],
				}
					
			mapDict[y].push_back( myDictEntry )






