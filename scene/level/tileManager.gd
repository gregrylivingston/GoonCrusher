extends Node2D
class_name TileManager

#Streams the level's chunks round the car (docs/WORLD.md). The world itself is a WorldMap that WorldGen
#builds on a worker thread when the level starts; until phase 3's ground, each chunk still shows one of the
#old per-terrain TileMap scenes (WorldMap.chunkTile) and one of the old object prefabs.

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
const RASTER_PREFETCH_SECONDS = 1.5 #fine rasters are queued this far ahead of the car

## The run's world (scripts/world/world_map.gd), also Root.worldMap once built
var worldMap: WorldMap
## The map seed. -1 rolls one when the level starts; the playtest and bench harnesses set it first.
var worldSeed := -1
var buildTask := -1
var buildJob := {}
## Route length (px, A* on the coarse map) to the station last placed: Sprint's and every Marathon leg's clock
var lastRouteLength := 0.0
var legsPlaced := 0

func _ready():
	for i in requestedObjectTiles:
		objectTiles.append_array(AllObjectTiles[i])
	tilesize = tilesPerChunk * pixelsPerTile
	Root.worldMap = null #never answer from an earlier run's map

	await buildWorld()
	if not is_inside_tree(): return

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

## The level's def: the parent level's own, else the selected level's
func levelDef() -> LevelDef:
	var level = get_parent()
	if level is Level && level.def != null: return level.def
	return Levels.current()

#Builds the coarse world map on a worker thread (WorldGen.buildCoarse) so the level's first frames don't
#stall, then the start chunk's fine raster, and hands the districts to Region.
func buildWorld() -> void:
	if worldSeed < 0: worldSeed = randi()
	var def := levelDef()
	var objective := ""
	var offset := Vector2.ZERO
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			objective = "sprint"
			var parent = get_parent()
			var seconds: float = parent.seconds if parent is Level else def.seconds
			offset = Level.sprintOffsetPx(seconds, WorldGen.hashf(worldSeed, WorldGen.TAG_SPRINT, 0, 0) * 2.0 - 1.0)
		Root.gameModes.DEFENSE: objective = "defense"
	buildJob = WorldMap.jobFor(worldSeed, def, objective, offset)
	var started := Time.get_ticks_msec()
	buildTask = WorkerThreadPool.add_task(WorldGen.buildCoarse.bind(buildJob), false, "World map")
	while not WorkerThreadPool.is_task_completed(buildTask):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(buildTask)
	buildTask = -1
	worldMap = WorldMap.fromJob(buildJob, def)
	buildJob = {}
	Root.worldMap = worldMap
	Region.setDistricts(worldMap)
	var startChunk := chunkOf(def.startPosition)
	worldMap.buildNow(startChunk)
	print("WORLD_BUILD level=%s seed=%d grammar=%s coarse_ms=%.0f (worker; %d ms wall) districts=%d crossings=%d start_raster_ms=%.1f" % [
		def.id, worldSeed, def.grammar, worldMap.buildMs.total, Time.get_ticks_msec() - started, worldMap.districts.size(),
		worldMap.crossings.size(), worldMap.fineStats.usec / 1000.0])

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

#The generator placed the station (WorldGen: in the start's component, on clear cells) and measured the
#route to it; every station is pinned.
func placeStations() -> void:
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT, Root.gameModes.MARATHON, Root.gameModes.DEFENSE:
			var chunk := worldMap.stationChunk
			if chunk == WorldGen.NO_CHUNK: chunk = worldMap.findStationChunk(startChunkOf(), WorldGen.NO_CHUNK)
			placeStation(chunk)
			if worldMap.station != Vector2.INF: lastRouteLength = worldMap.routeLength
			else: lastRouteLength = worldMap.routeBetween(Root.levelRoot.startPosition, Root.station.global_position).length

func placeStation(chunk: Vector2i) -> void:
	var myStation = load("res://scene/level/station.tscn").instantiate()
	Root.station = myStation
	pinChunk(chunk, myStation)

#Marathon's next leg: the reached station is retired and unpinned (it unloads once the car leaves),
#and a new one goes a Sprint's distance from it along `heading`, in a reachable chunk with a clear lot
#(WorldGen.findStationChunk); lastRouteLength is the A* route to it. Returns the new station.
func placeNextStation(from: Vector2, heading: float, levelSeconds: float) -> Node2D:
	var fromChunk = chunkOf(from)
	if is_instance_valid(Root.station) && Root.station.has_method("retire"): Root.station.retire()
	unpinChunk(fromChunk)
	legsPlaced += 1
	var roll := WorldGen.hashf(worldSeed, WorldGen.TAG_LEG, legsPlaced, 1) * 2.0 - 1.0
	var offset: Vector2 = Level.sprintOffsetPx(levelSeconds, roll).rotated(heading)
	placeStation(worldMap.findStationChunk(chunkOf(from + offset), fromChunk))
	lastRouteLength = worldMap.routeBetween(from, Root.station.global_position).length
	return Root.station

func startChunkOf() -> Vector2i:
	return chunkOf(Root.levelRoot.startPosition) if is_instance_valid(Root.levelRoot) else Vector2i.ZERO

const NO_CHUNK = WorldGen.NO_CHUNK

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
var playerCell := Vector2i(-99999, -99999) #the car's coarse cell, for district changes

func chunkOf(worldPosition: Vector2) -> Vector2i:
	return Vector2i(floori(worldPosition.x / tilesize.x), floori(worldPosition.y / tilesize.y))

#what the chunk shows until phase 3's ground: {"terrain": the landscape scene, "region": its district}
#(WorldMap.chunkTile). Outside the map is water.
func tileAt(chunk: Vector2i) -> Dictionary:
	if worldMap == null: return {"terrain":Root.terrain.WATER, "region":-2}
	return worldMap.chunkTile(chunk)

func getTile(coordinates) -> Dictionary:
	return tileAt(chunkOf(Vector2(coordinates)))


func _process(delta):
	if mapReady: updateChunks(delta)

func updateChunks(delta: float = 1.0) -> void:
	if worldMap != null: worldMap.poll()
	if not is_instance_valid(Root.playerCar): return
	var carPosition: Vector2 = Root.playerCar.global_position
	var chunk = chunkOf(carPosition)
	queueTimer -= delta
	if chunk != playerChunk:
		playerChunk = chunk
		var around := []
		for y in range(-1, 2):
			for x in range(-1, 2): around.push_back(chunk + Vector2i(x, y))
		worldMap.setKeep(around)
		worldMap.ensure(chunk) #the car's chunk always has its fine raster
		loadChunk(chunk) #the chunk under the car loads immediately
		for loaded in loadedLandscapes.keys():
			if not pinnedChunks.has(loaded) && maxi(absi(loaded.x - chunk.x), absi(loaded.y - chunk.y)) > KEEP_RADIUS:
				unloadChunk(loaded)
		queueTimer = 0.0
	#districts: checked whenever the car enters another coarse cell; a barrier cell keeps the last one
	var cell := worldMap.coarseCell(carPosition)
	if cell != playerCell:
		playerCell = cell
		var id := worldMap.districtOfCell(cell)
		if id >= 0 && id != Region.currentRegionNumber && is_instance_valid(Root.playerRoot):
			Region.updatePlayerRegion({"terrain":worldMap.terrain[worldMap.cellIndex(cell)], "region":id})
	if queueTimer <= 0.0:
		queueTimer = 0.2
		queueNeededChunks()
	#at most one chunk per frame, nearest first
	while not loadQueue.is_empty():
		var next = loadQueue.pop_front()
		if not loadedLandscapes.has(next):
			loadChunk(next)
			break

#every chunk the camera can see now, or will see after PREFETCH_SECONDS of travel; the fine rasters of
#the car's 3x3 and of what the camera will see RASTER_PREFETCH_SECONDS ahead are queued on the worker pool
func queueNeededChunks() -> void:
	var car = Root.playerCar
	var zoom = car.get_node("Camera2D").zoom if car.has_node("Camera2D") else Vector2.ONE
	var half = get_viewport().get_visible_rect().size / zoom / 2.0 + Vector2(256, 256)
	var view = Rect2(car.global_position - half, half * 2.0)
	var ahead = view.merge(Rect2(view.position + car.velocity * RASTER_PREFETCH_SECONDS, view.size))
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
	for c in worldMap.keep: worldMap.request(c)
	var aheadFirst = chunkOf(ahead.position)
	var aheadLast = chunkOf(ahead.end)
	for y in range(aheadFirst.y, aheadLast.y + 1):
		for x in range(aheadFirst.x, aheadLast.x + 1):
			var c = Vector2i(x, y)
			if maxi(absi(c.x - playerChunk.x), absi(c.y - playerChunk.y)) <= KEEP_RADIUS: worldMap.request(c)

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
	rng.seed = hash([worldSeed, chunk.x, chunk.y])
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
		if myScene != null || World.isPassable(tile.terrain):
			var newObjectTile = createNewTileObject(targetPosition, chunkRng(chunk), myScene)
			if myScene == null: #pickup props (crates, skill challenges); never in a station's or the start chunk
				var propRng = chunkRng(chunk)
				propRng.seed = hash([propRng.seed, "props"])
				PickupWorld.decorateChunk(newObjectTile, propRng)
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
	if buildTask != -1:
		WorkerThreadPool.wait_for_task_completion(buildTask)
		buildTask = -1
	if worldMap != null: worldMap.shutdown()
	if Root.worldMap == worldMap: Root.worldMap = null
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
