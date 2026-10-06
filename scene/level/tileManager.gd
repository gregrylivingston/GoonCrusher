extends Node2D

var tilesPerChunk: Vector2 = Vector2(40,40)
var pixelsPerTile: Vector2 = Vector2(128,64)
var tilesize: Vector2



@export_range(0,3) var landscapeType: int = 0 # 0-grass 1-sand 2-dirt 3-snow
var landscapeMap = [
	preload("res://scene/level/terrain/landscapeMap.tscn"),
	preload("res://scene/level/terrain/landscapeMap2.tscn"),
	preload("res://scene/level/terrain/landscapeMap_mud.tscn"),
	preload("res://scene/level/terrain/landscapeMap_water.tscn"),
	preload("res://scene/level/terrain/landscapeMap_hill.tscn"),
	preload("res://scene/level/terrain/landscapeMap_shortGrass.tscn"),#moss
	preload("res://scene/level/terrain/landscapeMap_dirt.tscn"),
	preload("res://scene/level/terrain/landscapeMap_snow.tscn")
]

enum objectTypes { ROCKS , COINS , BONUS_ROCKS , EMPTY , SAND }
@export var requestedObjectTiles: Array[objectTypes] = [objectTypes.ROCKS]
var AllObjectTiles = {
	objectTypes.ROCKS:[
		preload("res://scene/level/levelObjects/level_rocks_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_2.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_3.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_4.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_5.tscn"),
	],
	objectTypes.COINS:[
		preload("res://scene/level/levelObjects/level_coins_1.tscn"),
		preload("res://scene/level/levelObjects/level_coins_2.tscn"),
		preload("res://scene/level/levelObjects/level_coins_3.tscn"),
		preload("res://scene/level/levelObjects/level_coins_4.tscn"),
		preload("res://scene/level/levelObjects/level_coins_5.tscn"),
	],
	objectTypes.BONUS_ROCKS:[
		preload("res://scene/level/levelObjects/level_rocks_fuel_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_2.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_3.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_4.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_purse_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_heart_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_slot_1.tscn")
		
	],
	objectTypes.EMPTY:[
		preload("res://scene/level/levelObjects/level_empty.tscn"),
		preload("res://scene/level/levelObjects/level_empty.tscn"),
		preload("res://scene/level/levelObjects/level_empty.tscn"),
	],
	objectTypes.SAND:[
		preload("res://scene/level/levelObjects/level_sandtrap_1.tscn"),
		preload("res://scene/level/levelObjects/level_sand_fuel_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocksand_1.tscn")
	]
}

var objectTiles = []
var loadedLandscapes = {}
var loadedObjects = {}
var pinnedChunks = {}       #chunks that are never unloaded (the station)
var loadQueue: Array[Vector2i] = []
var queueTimer: float = 0.0
var mapReady: bool = false

#emitted once at the end of _ready, when the map is built and every station is placed and in the
#tree. Anything that reads Root.station waits for it (or checks isWorldReady first).
signal world_ready
var isWorldReady := false

const KEEP_RADIUS = 2       #chunks further than this (Chebyshev) from the player are freed
const PREFETCH_SECONDS = 1.0

func _ready():
	for i in requestedObjectTiles:
		objectTiles.append_array(AllObjectTiles[i])
	tilesize = tilesPerChunk * pixelsPerTile
	
	await $landscapeGenerator.createNewTerrain()
	
	setupByGamemode()

	await get_tree().process_frame

	mapReady = true
	updateChunks()

	#Root.levelRoot is set by now: LevelRoot._ready ran while this waited for the map and the frame above
	placeStations()

	#clear the start chunk's rocks, but never a pinned objective (Defense's station is at the start)
	if loadedObjects.has(playerChunk) && not pinnedChunks.has(playerChunk):
		loadedObjects[playerChunk].queue_free()
		loadedObjects.erase(playerChunk)

	isWorldReady = true
	world_ready.emit()

func setupByGamemode() -> void:
	Root.station = null #never point at a station left over from an earlier run
	match SaveManager.playerData.gameMode:
		Root.gameModes.GOONCRUSHER:setupNoStations()
		Root.gameModes.GOONPOCALYPSE:setupNoStations()
		Root.gameModes.SPRINT:
			loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())
		Root.gameModes.MARATHON:
			loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())
		#DEFENSE: its station is placed with the others in placeStations

#Every station goes through placeObjective (on land, inside the map) and is pinned.
func placeStations() -> void:
	var startChunk = startChunkOf()
	var levelSeconds: float = Root.levelRoot.levelSeconds
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			#by distance: SPRINT_DRIVE_FRACTION of the level's seconds at REFERENCE_SPEED. Level.onWorldReady
			#then sets the clock from the real distance to where the station landed. Marathon's first leg is
			#a Sprint; placeNextStation places the rest.
			var offset: Vector2 = Level.sprintOffsetPx(levelSeconds, randf_range(-1.0, 1.0))
			placeStation(startChunk + Vector2i(roundi(offset.x / tilesize.x), roundi(offset.y / tilesize.y)))
		Root.gameModes.DEFENSE:
			placeStation(startChunk)

func placeStation(desiredChunk: Vector2i, forbidden := NO_CHUNK) -> void:
	var myStation = load("res://scene/level/station.tscn").instantiate()
	Root.station = myStation
	pinChunk(placeObjective(desiredChunk, forbidden), myStation)

#Marathon's next leg: the reached station is retired and unpinned (it unloads once the car leaves),
#and a new one goes a Sprint's distance from it along `heading`. Returns the new station.
func placeNextStation(from: Vector2, heading: float, levelSeconds: float) -> Node2D:
	var fromChunk = chunkOf(from)
	if is_instance_valid(Root.station) && Root.station.has_method("retire"): Root.station.retire()
	unpinChunk(fromChunk)
	var offset: Vector2 = Level.sprintOffsetPx(levelSeconds, randf_range(-1.0, 1.0)).rotated(heading)
	placeStation(chunkOf(from + offset), fromChunk)
	return Root.station

func startChunkOf() -> Vector2i:
	return chunkOf(Root.levelRoot.startPosition) if is_instance_valid(Root.levelRoot) else Vector2i.ZERO

const OBJECTIVE_MAX_CHUNKS = 100 #objectives stay within this many chunks of the map centre, on each axis

#The chunk an objective should go in: desiredChunk clamped to the map, then the nearest land chunk
#(not WATER or HILLS), preferring one whose neighbours are land too, and never `forbidden`. Sprint and
#Marathon never get the start chunk unless another chunk is forbidden.
const NO_CHUNK = Vector2i(-99999, -99999)
func placeObjective(desiredChunk: Vector2i, forbidden := NO_CHUNK) -> Vector2i:
	var generator = $landscapeGenerator
	if forbidden == NO_CHUNK && SaveManager.playerData.gameMode in [Root.gameModes.SPRINT, Root.gameModes.MARATHON]: forbidden = startChunkOf()
	return findObjectiveChunk(generator.terrainMap, Vector2i(generator.inputSizeX, generator.inputSizeY), desiredChunk, forbidden, OBJECTIVE_MAX_CHUNKS)

const OBJECTIVE_NEIGHBOUR_SEARCH = 3 #rings searched past the first land chunk for one with land neighbours

#Pure: deterministic for a given map. Chunk (0,0) is map cell (size / 2). Searches square rings
#outward from the clamped chunk; in each ring the closest candidate wins (ties in scan order).
static func findObjectiveChunk(terrain: PackedByteArray, mapSize: Vector2i, desiredChunk: Vector2i, forbidden: Vector2i, maxChunks: int) -> Vector2i:
	var limit = Vector2i(mini(maxChunks, mapSize.x / 2 - 1), mini(maxChunks, mapSize.y / 2 - 1))
	var centre = desiredChunk.clamp(-limit, limit)
	var fallback = Vector2i(-99999, -99999) #the closest land chunk, used if none nearby has land neighbours
	var fallbackRing = -1
	for ring in range(0, 2 * maxi(limit.x, limit.y) + 1):
		if fallbackRing >= 0 && ring > fallbackRing + OBJECTIVE_NEIGHBOUR_SEARCH: return fallback
		var best = Vector2i(-99999, -99999)
		var bestDistance = INF
		var bestPlain = Vector2i(-99999, -99999)
		var bestPlainDistance = INF
		for chunk in ringChunks(centre, ring):
			if chunk == forbidden || absi(chunk.x) > limit.x || absi(chunk.y) > limit.y: continue
			if not isLandChunk(terrain, mapSize, chunk): continue
			var distance = (chunk - centre).length_squared()
			if distance < bestPlainDistance:
				bestPlain = chunk
				bestPlainDistance = distance
			if distance < bestDistance && hasLandNeighbours(terrain, mapSize, chunk):
				best = chunk
				bestDistance = distance
		if bestDistance < INF: return best
		if bestPlainDistance < INF && fallbackRing < 0:
			fallback = bestPlain
			fallbackRing = ring
	return fallback if fallbackRing >= 0 else centre

#the chunks exactly `ring` steps (Chebyshev) from centre, in a fixed order
static func ringChunks(centre: Vector2i, ring: int) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	if ring == 0:
		chunks.push_back(centre)
		return chunks
	for x in range(-ring, ring + 1):
		chunks.push_back(centre + Vector2i(x, -ring))
		chunks.push_back(centre + Vector2i(x, ring))
	for y in range(-ring + 1, ring):
		chunks.push_back(centre + Vector2i(-ring, y))
		chunks.push_back(centre + Vector2i(ring, y))
	return chunks

static func isLandChunk(terrain: PackedByteArray, mapSize: Vector2i, chunk: Vector2i) -> bool:
	var cell = chunk + mapSize / 2
	if cell.x < 0 || cell.y < 0 || cell.x >= mapSize.x || cell.y >= mapSize.y || terrain.is_empty(): return false
	var type = terrain[cell.y * mapSize.x + cell.x]
	return type != Root.terrain.WATER && type != Root.terrain.HILLS

static func hasLandNeighbours(terrain: PackedByteArray, mapSize: Vector2i, chunk: Vector2i) -> bool:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not isLandChunk(terrain, mapSize, chunk + step): return false
	return true

func setupNoStations():
	Root.station = null
	loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())

func pinChunk(chunk: Vector2i, myScene) -> void:
	pinnedChunks[chunk] = true
	unloadChunk(chunk, true)
	loadChunk(chunk, myScene)

#the chunk unloads by distance again, objects and all, like any other
func unpinChunk(chunk: Vector2i) -> void:
	pinnedChunks.erase(chunk)


var playerChunk: Vector2i = Vector2i(-999,-999)

func chunkOf(worldPosition: Vector2) -> Vector2i:
	return Vector2i(floori(worldPosition.x / tilesize.x), floori(worldPosition.y / tilesize.y))

#map cell for a chunk; chunk (0,0) is the centre of the map. Outside the map is water.
func tileAt(chunk: Vector2i) -> Dictionary:
	var generator = $landscapeGenerator
	return generator.cellAt(chunk.x + generator.inputSizeX / 2, chunk.y + generator.inputSizeY / 2)

func getTile(coordinates) -> Dictionary:
	return tileAt(chunkOf(Vector2(coordinates)))


func _process(delta):
	if mapReady: updateChunks(delta)

func updateChunks(delta: float = 1.0) -> void:
	if not is_instance_valid(Root.playerCar): return
	var chunk = chunkOf(Root.playerCar.global_position)
	queueTimer -= delta
	if chunk != playerChunk:
		playerChunk = chunk
		var myTile = loadChunk(chunk) #the chunk under the car loads immediately
		if is_instance_valid(Root.playerRoot):Region.updatePlayerRegion(myTile)
		for loaded in loadedLandscapes.keys():
			if not pinnedChunks.has(loaded) && maxi(absi(loaded.x - chunk.x), absi(loaded.y - chunk.y)) > KEEP_RADIUS:
				unloadChunk(loaded)
		queueTimer = 0.0
	if queueTimer <= 0.0:
		queueTimer = 0.2
		queueNeededChunks()
	#at most one chunk per frame, nearest first
	while not loadQueue.is_empty():
		var next = loadQueue.pop_front()
		if not loadedLandscapes.has(next):
			loadChunk(next)
			break

#every chunk the camera can see now, or will see after PREFETCH_SECONDS of travel
func queueNeededChunks() -> void:
	var car = Root.playerCar
	var zoom = car.get_node("Camera2D").zoom if car.has_node("Camera2D") else Vector2.ONE
	var half = get_viewport().get_visible_rect().size / zoom / 2.0 + Vector2(256, 256)
	var view = Rect2(car.global_position - half, half * 2.0)
	view = view.merge(Rect2(view.position + car.velocity * PREFETCH_SECONDS, view.size))
	var first = chunkOf(view.position)
	var last = chunkOf(view.end)
	loadQueue.clear()
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var c = Vector2i(x, y)
			if not loadedLandscapes.has(c) && maxi(absi(c.x - playerChunk.x), absi(c.y - playerChunk.y)) <= KEEP_RADIUS + 1:
				loadQueue.push_back(c)
	loadQueue.sort_custom(func(a, b): return (a - playerChunk).length_squared() < (b - playerChunk).length_squared())

func unloadChunk(chunk: Vector2i, force := false):
	if pinnedChunks.has(chunk) && not force: return
	if loadedLandscapes.has(chunk):
		poolLandscape(loadedLandscapes[chunk])
		loadedLandscapes.erase(chunk)
	if loadedObjects.has(chunk):
		loadedObjects[chunk].queue_free()
		loadedObjects.erase(chunk)

#each chunk rolls its objects from its own seed, so a chunk that is freed and reloaded looks the same
func chunkRng(chunk: Vector2i) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([$landscapeGenerator.inputSeed, chunk.x, chunk.y])
	return rng

func getRandomTileObject(rng: RandomNumberGenerator):
	return objectTiles[rng.randi() % objectTiles.size()].instantiate()
	

func loadChunk(chunk:Vector2i , myScene = null): #if an instantiated scene isn't passed get a random one from the level dictionary.
	var tile = tileAt(chunk)
	if not loadedLandscapes.has(chunk):
		var targetPosition = Vector2( tilesize.x * chunk.x , tilesize.y * chunk.y )
		var newLandscapeMap = takeLandscape(tile.terrain)
		
		if Region.regions.has(tile.region):
			newLandscapeMap.self_modulate = newLandscapeMap.self_modulate * Region.regions[tile.region].terrain_modulate
			newLandscapeMap.self_modulate.a = 1.0
		
		newLandscapeMap.global_position = targetPosition
		loadedLandscapes[chunk] = newLandscapeMap
		add_child(newLandscapeMap)
		
		#a scene that was passed in (a station) is always added, so it can never be left out of the tree
		if myScene != null || (tile.terrain != Root.terrain.WATER && tile.terrain != Root.terrain.HILLS):
			var newObjectTile = createNewTileObject(targetPosition, chunkRng(chunk), myScene)
			loadedObjects[chunk] = newObjectTile
			add_child(newObjectTile)
	return tile
			

#Unloaded landscape TileMaps are kept out of the tree and reused, which is cheaper than
#instantiating a new one (objects are not pooled; they hold per-chunk state such as coins taken).
const POOL_PER_TERRAIN = 8
var landscapePool = {} #Root.terrain -> Array of TileMaps outside the tree

func takeLandscape(terrain: int) -> Node2D:
	var pool = landscapePool.get(terrain, [])
	if not pool.is_empty():
		var reused = pool.pop_back()
		reused.self_modulate = reused.get_meta("baseModulate")
		return reused
	var created = landscapeMap[terrain].instantiate()
	created.set_meta("terrain", terrain)
	created.set_meta("baseModulate", created.self_modulate)
	return created

func poolLandscape(landscape: Node2D) -> void:
	var pool = landscapePool.get_or_add(landscape.get_meta("terrain"), [])
	if pool.size() >= POOL_PER_TERRAIN:
		landscape.queue_free()
		return
	remove_child(landscape)
	pool.push_back(landscape)

func _exit_tree():
	for pool in landscapePool.values():
		for landscape in pool: landscape.free()
	landscapePool.clear()

#create objects like rocks and powerups that go over the landscapes
func createNewTileObject(targetPosition, rng: RandomNumberGenerator, myScene = null):
		var newObjectTile 
		if myScene == null: 
			newObjectTile = getRandomTileObject(rng)
			var myRotation = rng.randi() % 180
			newObjectTile.global_position = targetPosition + (tilesize / 2) + Vector2(rng.randi_range(tilesize.x/-4,tilesize.x/4),rng.randi_range(-200,200))		
			newObjectTile.rotation = myRotation
			for i in newObjectTile.get_children():
				if not i.has_method("isFixed"):i.rotation = -myRotation
		else: 
			newObjectTile = myScene
			newObjectTile.global_position = targetPosition + (tilesize / 2) 
		return newObjectTile
