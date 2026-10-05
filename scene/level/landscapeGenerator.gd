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

#the map, one entry per cell at index y * inputSizeX + x. Empty until createNewTerrain finishes.
var terrainMap := PackedByteArray()   #Root.terrain
var regionMap := PackedInt32Array()   #region id; -2 for water and hills (no region)
var nextRegionToAdd: int = 2          #one past the highest region id

const EDGE = 20 #cells from the map edge that slope down into the ocean
var buildTask: int = -1

func newSeed( ):
	var noise = FastNoiseLite.new()
	noise.noise_type = int(inputNoiseType)
	noise.fractal_type = int(inputFractalType)
	noise.seed = inputSeed
	noiseImage = noise.get_image(inputSizeX, inputSizeY)

#the cell at map coordinates (x, y), as {"terrain", "region"}. Outside the map is water.
func cellAt(x: int, y: int) -> Dictionary:
	if x < 0 || y < 0 || x >= inputSizeX || y >= inputSizeY || terrainMap.is_empty():
		return {"terrain":Root.terrain.WATER, "region":-2}
	var i = y * inputSizeX + x
	return {"terrain":terrainMap[i], "region":regionMap[i]}

#Builds the map on a worker thread so the level's first frames don't stall; returns when it is done.
func createNewTerrain():
	if inputRandomizeSeed: newSeed()
	#read the noise as raw bytes (same values as get_pixel().r)
	if noiseImage.get_format() != Image.FORMAT_L8: noiseImage.convert(Image.FORMAT_L8)
	#away from the edges a cell's terrain depends only on its noise byte
	var lut := PackedByteArray()
	lut.resize(256)
	for b in 256: lut[b] = getTerrainType(b / 255.0 - float(inputSeaLevel))
	#the start area is rolled here from the global RNG, which is not safe to use from the worker
	var startArea := PackedByteArray() #one entry per column: how many rows
	for x in randi()%4 + 3: startArea.push_back(randi()%3 + 3)
	var job = {
		"noise":noiseImage.get_data(), "lut":lut, "size":Vector2i(inputSizeX, inputSizeY),
		"sea":float(inputSeaLevel), "edgeH":inputOceanEdgeH, "edgeV":inputOceanEdgeV, "startArea":startArea,
	}
	buildTask = WorkerThreadPool.add_task(buildMap.bind(job), false, "Terrain map")
	while not WorkerThreadPool.is_task_completed(buildTask):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(buildTask)
	buildTask = -1
	regionMap = job.regions
	nextRegionToAdd = job.nextRegion
	terrainMap = job.terrain

func _exit_tree():
	if buildTask != -1:
		WorkerThreadPool.wait_for_task_completion(buildTask)
		buildTask = -1

#Runs on a worker thread: touches only `job`.
static func buildMap(job: Dictionary) -> void:
	var size: Vector2i = job.size
	var noiseBytes: PackedByteArray = job.noise
	var lut: PackedByteArray = job.lut
	var terrain := PackedByteArray()
	terrain.resize(size.x * size.y)
	var edgeH: bool = job.edgeH
	var edgeV: bool = job.edgeV
	for y: int in size.y:
		var row: int = y * size.x
		var edgeY: bool = edgeV && (y < EDGE || y > size.y - EDGE)
		for x: int in size.x:
			var i: int = row + x
			if edgeY || (edgeH && (x < EDGE || x > size.x - EDGE)):
				terrain[i] = getTerrainType(edgeElevation(noiseBytes[i], x, y, size, job.sea, edgeH, edgeV))
			else:
				terrain[i] = lut[noiseBytes[i]]
	#the start area is always grass, and its region is 0
	var centre = size / 2
	var startTiles := PackedInt32Array([centre.y * size.x + centre.x])
	terrain[startTiles[0]] = Root.terrain.GRASS
	var startArea: PackedByteArray = job.startArea
	for x in startArea.size():
		for y in startArea[x]:
			for tile in [centre + Vector2i(x, y), centre - Vector2i(x, y), centre + Vector2i(x, -y)]:
				var i = tile.y * size.x + tile.x
				terrain[i] = Root.terrain.GRASS
				startTiles.push_back(i)
	var regions := PackedInt32Array()
	regions.resize(size.x * size.y)
	for i: int in regions.size():
		regions[i] = -2 if terrain[i] == Root.terrain.WATER || terrain[i] == Root.terrain.HILLS else -1
	floodRegion(regions, terrain, size.x, startTiles, 0, Root.terrain.GRASS)
	#Regions are connected areas of one terrain type, numbered in scan order from 2
	var nextRegion: int = 2
	for i: int in regions.size():
		if regions[i] == -1:
			floodRegion(regions, terrain, size.x, PackedInt32Array([i]), nextRegion, terrain[i])
			nextRegion += 1
	job.terrain = terrain
	job.regions = regions
	job.nextRegion = nextRegion

static func edgeElevation(noiseByte: int, x: int, y: int, size: Vector2i, seaLevel: float, edgeH: bool, edgeV: bool) -> float:
	var elevation = noiseByte / 255.0 - seaLevel
	if edgeH:
		if x < EDGE:
			elevation = elevation - ( EDGE - x ) * 0.04
		if x > size.x - EDGE:
			elevation = elevation - (EDGE + x - size.x )*0.04
	if edgeV:
		if y < EDGE:
			elevation = elevation - ( EDGE - y ) * 0.05
		if y > size.y - EDGE:
			elevation = elevation - (EDGE + y - size.y )*0.05
	return elevation

#labels every cell of `terrainType` connected to `seeds` (cell indices) with `requestedRegion`.
#Seeds are labelled whatever they held; other cells only if they had no region yet (-1).
static func floodRegion(regions: PackedInt32Array, terrain: PackedByteArray, width: int, seeds: PackedInt32Array, requestedRegion: int, terrainType: int) -> void:
	var stack := PackedInt32Array()
	for i in seeds:
		if regions[i] != requestedRegion:
			regions[i] = requestedRegion
			stack.push_back(i)
	var count: int = regions.size()
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x: int = i % width
		#up, down, left, right
		if i >= width && regions[i - width] == -1 && terrain[i - width] == terrainType:
			regions[i - width] = requestedRegion
			stack.push_back(i - width)
		if i + width < count && regions[i + width] == -1 && terrain[i + width] == terrainType:
			regions[i + width] = requestedRegion
			stack.push_back(i + width)
		if x > 0 && regions[i - 1] == -1 && terrain[i - 1] == terrainType:
			regions[i - 1] = requestedRegion
			stack.push_back(i - 1)
		if x < width - 1 && regions[i + 1] == -1 && terrain[i + 1] == terrainType:
			regions[i + 1] = requestedRegion
			stack.push_back(i + 1)


static func getTerrainType(elevation: float) -> int: #returns Root.terrain
	if elevation > 0.9: return Root.terrain.HILLS
	elif elevation > 0.75: return Root.terrain.SNOW
	elif elevation > 0.6: return Root.terrain.DIRT  #.35
	elif elevation > 0.45: return Root.terrain.MUD  #.15 (this was too high)
	elif elevation > 0.35: return Root.terrain.GRASS   #.15 (this was too high)
	elif elevation > 0.1: return Root.terrain.MOSS   #.15 (this was too high)
	elif elevation > -0.21: return Root.terrain.SAND   #.15 (this was too high)
	else: return Root.terrain.WATER
