extends Node2D
class_name TileManager

#Streams the level's chunks round the car (docs/WORLD.md). The world is a WorldMap that WorldGen builds on a
#worker thread when the level starts. Each chunk's recipe (ChunkRecipe: ground control, wall pieces,
#occluders, edges, decor, props, pickups) is built on the worker pool with its fine raster as the chunk
#nears the camera; a ChunkView applies it here on the main thread, a few nodes at a time within
#APPLY_BUDGET_USEC per frame, from the WorldSkin's pools, and hands them back the same way when the chunk
#unloads. The car's chunk never waits for the budget: its ground and collision go in at once (and if its
#recipe isn't built yet, the main thread waits for the worker; it never builds one itself).

var tilesPerChunk: Vector2 = Vector2(40,40)
var pixelsPerTile: Vector2 = Vector2(128,64)
var tilesize: Vector2

var views := {}             #chunk -> ChunkView (applied or being applied)
var applyQueue: Array = []  #ChunkViews still being applied, nearest first
var releaseQueue: Array = [] #ChunkViews being handed back
var pinnedChunks = {}       #chunks that are never unloaded (the station)
var stationNodes := {}      #chunk -> the station placed there (freed once its chunk unloads unpinned)
var loadQueue: Array[Vector2i] = []
var queueTimer: float = 0.0
var mapReady: bool = false

#emitted once at the end of _ready, when the map is built and every station is placed and in the
#tree. Anything that reads Root.station waits for it (or checks isWorldReady first).
signal world_ready
var isWorldReady := false

const KEEP_RADIUS = 2       #chunks further than this (Chebyshev) from the player are unloaded
const PREFETCH_SECONDS = 1.0
const RASTER_PREFETCH_SECONDS = 1.5 #rasters and recipes are queued this far ahead of the car
const APPLY_BUDGET_USEC = 1500      #main-thread time per frame for applying and releasing chunks (a step may run past it: about 2 ms in all)
const START_BUDGET_USEC = 10000     #...for the first START_FRAMES frames (behind the countdown)
const START_FRAMES = 120
const NEW_VIEWS_PER_FRAME = 2

## The run's world (scripts/world/world_map.gd), also Root.worldMap once built
var worldMap: WorldMap
## The level's art and node pools (scripts/world/world_skin.gd)
var skin: WorldSkin
## The map seed. -1 rolls one when the level starts; the playtest and bench harnesses set it first.
var worldSeed := -1
var buildTask := -1
var buildJob := {}
## Route length (px, A* on the coarse map) to the station last placed: Sprint's and every Marathon leg's clock
var lastRouteLength := 0.0
var legsPlaced := 0
var lots: Array = []  #station lots (Rect2, world px): no props or pickups there
var lanes: Array = [] #Defense lanes [from, to]: no props there

#draw order: ground, edges, decor, walls (collision and occluders), then props and pickups
var groundLayer: Node2D
var edgeLayer: Node2D
var decorLayer: Node2D
var wallLayer: Node2D
var objectLayer: Node2D
var reactions: PropReactions #canopies over the car, props answering hits (package 14)

## Main-thread ms spent applying and releasing chunks since the bench last read it (bench.gd chunk_ms)
var chunkMs := 0.0
var applyStats := {"frames": 0, "busyFrames": 0, "overBudget": 0, "maxUsec": 0, "totalUsec": 0, "applied": 0, "released": 0}
var framesSinceReady := 0

func _ready():
	tilesize = tilesPerChunk * pixelsPerTile
	Root.worldMap = null #never answer from an earlier run's map
	for layer in ["groundLayer", "edgeLayer", "decorLayer", "wallLayer", "objectLayer"]:
		var node := Node2D.new()
		node.name = layer
		add_child(node)
		set(layer, node)

	await buildWorld()
	if not is_inside_tree(): return

	Root.station = null #never point at a station left over from an earlier run

	await get_tree().process_frame

	mapReady = true
	#Root.levelRoot is set by now: LevelRoot._ready ran while this waited for the map and the frame above
	placeStations()
	updateChunks()

	isWorldReady = true
	world_ready.emit()

## The level's def: the parent level's own, else the selected level's
func levelDef() -> LevelDef:
	var level = get_parent()
	if level is Level && level.def != null: return level.def
	return Levels.current()

#Builds the coarse world map on a worker thread (WorldGen.buildCoarse) so the level's first frames don't
#stall, hands the districts to Region, sets up the level's art, then has the start chunk's raster and recipe
#built on the worker pool too.
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
	var skinStart := Time.get_ticks_usec()
	skin = WorldSkin.new(def)
	skin.prewarm()
	reactions = PropReactions.new(def.grammar, skin.leaves)
	add_child(reactions)
	if objective != "" && worldMap.stationChunk != WorldGen.NO_CHUNK: lots.push_back(lotRect(worldMap.stationChunk))
	if objective == "defense" && worldMap.station != Vector2.INF:
		for mouth in worldMap.lanes:
			lanes.push_back([worldMap.station + (mouth - worldMap.station).normalized() * 900.0, mouth])
	worldMap.recipeContext = skin.recipeContext(lots, lanes)
	var skinMs := (Time.get_ticks_usec() - skinStart) / 1000.0
	var startChunk := chunkOf(def.startPosition)
	worldMap.request(startChunk)
	while worldMap.pending.has(startChunk) && not WorkerThreadPool.is_task_completed(worldMap.pending[startChunk][0]):
		await get_tree().process_frame
	worldMap.ensure(startChunk)
	var recipe := worldMap.recipeOf(startChunk)
	print("WORLD_BUILD level=%s seed=%d grammar=%s coarse_ms=%.0f (worker; %d ms wall) districts=%d crossings=%d skin_ms=%.1f start_raster_ms=%.1f start_recipe_ms=%.1f layers=%s" % [
		def.id, worldSeed, def.grammar, worldMap.buildMs.total, Time.get_ticks_msec() - started, worldMap.districts.size(),
		worldMap.crossings.size(), skinMs, worldMap.fineStats.usec / 1000.0, recipe.get("usec", 0) / 1000.0, ",".join(skin.layers)])

## A station lot (world px) round a chunk's centre
static func lotRect(chunk: Vector2i) -> Rect2:
	return Rect2(WorldGen.chunkCentre(chunk) + WorldGen.LOT_RECT.position, WorldGen.LOT_RECT.size)

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
	placeStation(worldMap.findStationChunk(chunkOf(from + offset), fromChunk, fromChunk)) #not much nearer than a Sprint's distance
	lastRouteLength = worldMap.routeBetween(from, Root.station.global_position).length
	return Root.station

func startChunkOf() -> Vector2i:
	return chunkOf(Root.levelRoot.startPosition) if is_instance_valid(Root.levelRoot) else Vector2i.ZERO

const NO_CHUNK = WorldGen.NO_CHUNK

#A station: placed at the chunk's centre and pinned, its lot reserved (no props or pickups; a chunk already
#applied there is applied again without them). A lot reserved during the run (Marathon's later stations)
#also drops the recipes already built round it, so they are built again with the lot kept clear, as the
#first station's are (props kept their margin from it, decorateChunk's spots stay out of it).
func pinChunk(chunk: Vector2i, myScene) -> void:
	pinnedChunks[chunk] = true
	var lot := lotRect(chunk)
	if not lot in lots:
		lots.push_back(lot)
		if worldMap != null && skin != null:
			worldMap.recipeContext = skin.recipeContext(lots, lanes)
			var around := lot.grow(ChunkRecipe.PROP_GAP * 2.0)
			var lo := WorldGen.chunkOf(around.position)
			var hi := WorldGen.chunkOf(around.end)
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var c := Vector2i(x, y)
					#a neighbour on screen keeps its recipe (its props and pickups in the lot are skipped as it applies)
					if c == chunk || not views.has(c): worldMap.forget(c)
	if views.has(chunk):
		unloadChunk(chunk, true)
		loadChunk(chunk, chunk == playerChunk)
	if myScene != null:
		stationNodes[chunk] = myScene
		myScene.position = WorldGen.chunkCentre(chunk)
		objectLayer.add_child(myScene)

#the chunk unloads by distance again, its station with it
func unpinChunk(chunk: Vector2i) -> void:
	pinnedChunks.erase(chunk)

var playerChunk: Vector2i = Vector2i(-999,-999)
var playerCell := Vector2i(-99999, -99999) #the car's coarse cell, for district changes

func chunkOf(worldPosition: Vector2) -> Vector2i:
	return Vector2i(floori(worldPosition.x / tilesize.x), floori(worldPosition.y / tilesize.y))

## A chunk at a glance (WorldMap.chunkTile): {"terrain", "region"}. Outside the map is water.
func tileAt(chunk: Vector2i) -> Dictionary:
	if worldMap == null: return {"terrain":Root.terrain.WATER, "region":-2}
	return worldMap.chunkTile(chunk)

func getTile(coordinates) -> Dictionary:
	return tileAt(chunkOf(Vector2(coordinates)))

#--- the taken set and the chunk props' hooks ---------------------------------------------------------

func isTaken(chunk: Vector2i, bit: int) -> bool:
	return worldMap != null && worldMap.isTaken(chunk, bit)

## A pickup collected or a breakable smashed (also WorldMap.markTaken; WorldMap.takeNode reads a node's slot)
func markTaken(chunk: Vector2i, bit: int) -> void:
	if worldMap != null: worldMap.markTaken(chunk, bit)

## What spilled out of interactive props and came to rest (Spill.record), and the cranes that already dropped
## their container (Spill.markUsed), per chunk: {"props": [[prop id, chunk-local pos, rotation]], "used": [chunk-local pos]}.
## ChunkView puts the props back when it applies the chunk again and marks the used cranes.
var spilled := {}

func spillEntry(chunk: Vector2i) -> Dictionary:
	if not spilled.has(chunk): spilled[chunk] = {"props": [], "used": []}
	return spilled[chunk]

func addSpilled(id: StringName, at: Vector2, rot: float) -> void:
	var chunk := chunkOf(at)
	spillEntry(chunk).props.push_back([id, at - Vector2(chunk) * ChunkRecipe.CHUNK, rot])

func markSpillUsed(at: Vector2) -> void:
	var chunk := chunkOf(at)
	spillEntry(chunk).used.push_back(at - Vector2(chunk) * ChunkRecipe.CHUNK)

func spilledIn(chunk: Vector2i) -> Array:
	return spilled.get(chunk, {}).get("props", [])

func spillUsed(chunk: Vector2i, local: Vector2) -> bool:
	for u in spilled.get(chunk, {}).get("used", []):
		if u.distance_to(local) < 8.0: return true
	return false

## The node an applied chunk keeps its props in, for a world point; null while it isn't applied
func objectsAt(at: Vector2) -> Node2D:
	var view = views.get(chunkOf(at))
	return view.objects if view != null && is_instance_valid(view.objects) else null

## Inside a station lot (grown by radius): props and pickups keep out
func reservedAt(worldPosition: Vector2, radius: float) -> bool:
	for lot in lots:
		if lot.grow(radius).has_point(worldPosition): return true
	return false

## PickupWorld.decorateChunk runs for every chunk but the start's and a station's
func decoratesChunk(chunk: Vector2i) -> bool:
	return chunk != startChunkOf() && not pinnedChunks.has(chunk) && not stationNodes.has(chunk)

#each chunk rolls its extras from its own seed, so a chunk that is freed and reloaded looks the same
func chunkRng(chunk: Vector2i, purpose := "") -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([worldSeed, chunk.x, chunk.y])
	if purpose != "": rng.seed = hash([rng.seed, purpose])
	return rng

#--- streaming ---------------------------------------------------------------------------------------

func _process(delta):
	if mapReady: updateChunks(delta)

func updateChunks(delta: float = 1.0) -> void:
	if worldMap != null: worldMap.poll()
	if not is_instance_valid(Root.playerCar): return
	var frameStart := Time.get_ticks_usec()
	var carPosition: Vector2 = Root.playerCar.global_position
	var chunk = chunkOf(carPosition)
	queueTimer -= delta
	if chunk != playerChunk:
		playerChunk = chunk
		var around := []
		for y in range(-1, 2):
			for x in range(-1, 2): around.push_back(chunk + Vector2i(x, y))
		worldMap.setKeep(around)
		worldMap.ensure(chunk) #the car's chunk always has its raster and recipe
		loadChunk(chunk, true) #its ground and collision go in now
		for loaded in views.keys():
			if not pinnedChunks.has(loaded) && distance(loaded, chunk) > KEEP_RADIUS:
				unloadChunk(loaded)
		for at in stationNodes.keys():
			if not pinnedChunks.has(at) && not views.has(at) && distance(at, chunk) > KEEP_RADIUS: freeStation(at)
		applyQueue.sort_custom(func(a, b): return distance(a.chunk, chunk) < distance(b.chunk, chunk))
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
	#new views for queued chunks whose recipes are ready, nearest first
	var opened := 0
	var k := 0
	while k < loadQueue.size() && opened < NEW_VIEWS_PER_FRAME:
		var next: Vector2i = loadQueue[k]
		if views.has(next):
			loadQueue.remove_at(k)
			continue
		if not worldMap.recipeOf(next).is_empty():
			loadChunk(next)
			loadQueue.remove_at(k)
			opened += 1
			continue
		worldMap.request(next)
		k += 1
	processViews(frameStart)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

## Applies and releases chunks within the frame's budget; the car's urgent work (since frameStart) counts too
func processViews(frameStart: int) -> void:
	framesSinceReady += 1
	var budget := START_BUDGET_USEC if framesSinceReady < START_FRAMES else APPLY_BUDGET_USEC
	var deadline := Time.get_ticks_usec() + budget
	var busy := not releaseQueue.is_empty() || not applyQueue.is_empty()
	while not releaseQueue.is_empty() && Time.get_ticks_usec() < deadline:
		if releaseQueue[0].release(skin, deadline):
			releaseQueue.pop_front()
			applyStats.released += 1
	while not applyQueue.is_empty() && Time.get_ticks_usec() < deadline:
		if applyQueue[0].step(skin, self, deadline):
			applyQueue.pop_front()
			applyStats.applied += 1
	if skin: skin.flush()
	var used := Time.get_ticks_usec() - frameStart
	chunkMs += used / 1000.0
	applyStats.frames += 1
	if busy || used > 300:
		applyStats.busyFrames += 1
		applyStats.totalUsec += used
		applyStats.maxUsec = maxi(applyStats.maxUsec, used)
		if used > APPLY_BUDGET_USEC + 500 && framesSinceReady >= START_FRAMES: applyStats.overBudget += 1

#every chunk the camera can see now, or will see after PREFETCH_SECONDS of travel; the rasters and recipes
#of the car's 3x3 and of what the camera will see RASTER_PREFETCH_SECONDS ahead are queued on the worker pool
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
			if not views.has(c) && WorldMap.chunkInMap(c) && distance(c, playerChunk) <= KEEP_RADIUS + 1:
				loadQueue.push_back(c)
	loadQueue.sort_custom(func(a, b): return (a - playerChunk).length_squared() < (b - playerChunk).length_squared())
	for c in worldMap.keep: worldMap.request(c)
	var aheadFirst = chunkOf(ahead.position)
	var aheadLast = chunkOf(ahead.end)
	for y in range(aheadFirst.y, aheadLast.y + 1):
		for x in range(aheadFirst.x, aheadLast.x + 1):
			var c = Vector2i(x, y)
			if distance(c, playerChunk) <= KEEP_RADIUS: worldMap.request(c)

## Starts applying a chunk (a no-op when it is already in). urgent (the car's chunk): its recipe is waited
## for if need be, and its ground and collision go in at once, whatever the budget.
func loadChunk(chunk: Vector2i, urgent := false) -> void:
	var view: ChunkView = views.get(chunk)
	if view == null:
		var recipe := worldMap.recipeOf(chunk)
		if recipe.is_empty() && urgent:
			worldMap.ensure(chunk)
			recipe = worldMap.recipeOf(chunk)
		if recipe.is_empty(): return
		view = ChunkView.new(chunk, recipe)
		views[chunk] = view
		applyQueue.push_back(view)
	if urgent:
		while view.stage <= ChunkView.BODY: view.step(skin, self, 0)
		applyQueue.erase(view)
		if not view.isDone(): applyQueue.push_front(view)

func unloadChunk(chunk: Vector2i, force := false):
	if pinnedChunks.has(chunk) && not force: return
	var view: ChunkView = views.get(chunk)
	if view != null:
		views.erase(chunk)
		applyQueue.erase(view)
		releaseQueue.push_back(view)
	if not pinnedChunks.has(chunk): freeStation(chunk)

func freeStation(chunk: Vector2i) -> void:
	var station = stationNodes.get(chunk)
	stationNodes.erase(chunk)
	if station != null && is_instance_valid(station) && station != Root.station: station.queue_free()

## Loaded chunks (GameStats, the bench)
func loadedCount() -> int:
	return views.size()

## Worker recipe times and main-thread apply times, for the log and the bench
func chunkReport() -> String:
	var rs: Dictionary = worldMap.recipeStats if worldMap else {"count": 0, "usec": 0, "maxUsec": 0}
	var fs: Dictionary = worldMap.fineStats if worldMap else {"count": 0, "usec": 0, "maxUsec": 0, "waits": 0}
	return "WORLD_CHUNKS recipes=%d recipe_avg_ms=%.1f recipe_max_ms=%.1f raster_avg_ms=%.1f raster_max_ms=%.1f waits=%d applied=%d released=%d apply_frames=%d apply_avg_ms=%.2f apply_max_ms=%.2f over_budget=%d" % [
		rs.count, rs.usec / 1000.0 / maxi(rs.count, 1), rs.maxUsec / 1000.0, fs.usec / 1000.0 / maxi(fs.count, 1), fs.maxUsec / 1000.0,
		fs.waits, applyStats.applied, applyStats.released, applyStats.busyFrames,
		applyStats.totalUsec / 1000.0 / maxi(applyStats.busyFrames, 1), applyStats.maxUsec / 1000.0, applyStats.overBudget] + " step_max_ms(ground,body,occluders,lines,decor,prop,pickup,extras)=" + ",".join(ChunkView.stageMaxUsec.slice(0, 8).map(func(u): return "%.2f" % (u / 1000.0)))

func _exit_tree():
	if buildTask != -1:
		WorkerThreadPool.wait_for_task_completion(buildTask)
		buildTask = -1
	if worldMap != null:
		print(chunkReport())
		worldMap.shutdown()
	if Root.worldMap == worldMap: Root.worldMap = null
	if skin != null: skin.freeAll()
