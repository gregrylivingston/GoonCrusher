class_name WorldMap extends RefCounted
## The run's world (docs/WORLD.md), owned by the TileManager and reachable as Root.worldMap; World's
## static queries delegate here. It holds:
##   - the coarse map from WorldGen.buildCoarse (terrain, flags, district and aux per 1280 px cell), its
##     AStarGrid2D, the station and Defense lanes the generator placed, and the route length to the station;
##   - the district table, with each district's faction, three goons, name, tint and giantism decided here
##     on the main thread, deterministically from the world seed;
##   - an LRU cache of fine rasters (WorldGen.fineRaster, 40 x 20 cells of 128 px per chunk) and, once the
##     TileManager has set recipeContext, the chunk recipes built from them (ChunkRecipe: ground control,
##     wall pieces, occluders, edges, decor, props, pickups), both on one WorkerThreadPool task per chunk when
##     it enters the prefetch set. The car's chunk is never without them: ensure() waits for its task (the
##     main thread never builds one during a run; buildNow is for tests and tools);
##   - `taken`, the per-chunk bitmask of collected pickups and smashed breakables (chunk -> int): pickups
##     bits 0-31, breakables 32-62. markTaken / isTaken; a re-applied chunk skips what is taken.
## The queries (terrainAt, surfaceAt, lethalAt, blockedAt, spawnableAt) read the fine raster where it is
## loaded and the coarse map elsewhere. They run every physics tick for the car and every goon and ~900 times
## per AI plan, so `grid`, a native WorldGrid, mirrors the coarse map and every cached raster and answers them
## (World.grid while this is Root.worldMap). The GDScript queries below are the same rule, kept for tools and
## the parity tests; the last chunk's raster is cached so they don't allocate.

const LRU := 24
const W := WorldGen.W
const H := WorldGen.H
const CHUNK_X := 5120.0
const CHUNK_Y := 2560.0
const WATER := 3
const HILLS := 4

## Name halves for districts: a faction word, then a grammar word ("Tusker Flats", "Rust Junction")
const NAME_FIRST := [
	["Tusker", "Jackalope", "Thornback", "Wildroot", "Howling", "Bramble", "Snapjaw", "Feral", "Burrow", "Antler"],
	["Totem", "Warpaint", "Grunt", "Bonefire", "Drumskull", "Spearhead", "Mudmask", "Hubcap", "Tusk", "Warband"],
	["Rust", "Sprocket", "Gearhead", "Scrapper", "Chrome", "Piston", "Rivet", "Junker", "Sawtooth", "Busted"],
]
const NAME_SECOND := {
	&"meadow": ["Flats", "Meadow", "Fields", "Hollow", "Creekside", "Downs", "Pasture", "Commons", "Green", "Bottoms"],
	&"bayou": ["Bog", "Marsh", "Bayou", "Slough", "Backwater", "Mire", "Landing", "Swamp", "Fen", "Shallows"],
	&"canyon": ["Gulch", "Mesa", "Canyon", "Wash", "Butte", "Gorge", "Bluffs", "Draw", "Arroyo", "Narrows"],
	&"quarry": ["Pit", "Diggings", "Quarry", "Cut", "Spoil", "Workings", "Tailings", "Dig", "Shaft", "Benches"],
	&"mountain": ["Pass", "Ridge", "Peaks", "Col", "Drift", "Summit", "Glacier", "Saddle", "Notch", "Crags"],
	&"highway": ["Junction", "Overpass", "Exit", "Turnpike", "Truckstop", "Mile", "Interchange", "Strip", "Bypass", "Rest Stop"],
	&"city": ["Heights", "Blocks", "Plaza", "Row", "Square", "Quarter", "Projects", "Downtown", "Avenue", "Docks"],
	&"yard": ["Yard", "Heap", "Lot", "Stacks", "Pile", "Compound", "Depot", "Crusher", "Pens", "Scrapline"],
}
const CENTRE_FIRST: Array[int] = [1, 2, 5, 6, 0, 3, 4, 7] #a chunk's 8 coarse cells (row-major, 4 x 2), middle ones first

var worldSeed := 0
var def: LevelDef
var snapshot := {} #the def as worker jobs see it
var grammar: StringName = &"meadow"
var startPosition := Vector2.ZERO
var terrain := PackedByteArray()
var flags := PackedByteArray()
var aux := PackedByteArray()
var district := PackedInt32Array()
var districts: Array = [] #id -> {id, cells, centroid, neighbours, inStart, faction, goons, name, tint, giantism}
var crossings := PackedInt32Array()
var cover := PackedByteArray() #share of each blocked cell its barrier really covers (0..255)
var astar: AStarGrid2D
var station := Vector2.INF
var stationChunk := WorldGen.NO_CHUNK
var lanes: Array = []
var route := PackedVector2Array()
var routeLength := 0.0
var buildMs := {}
var taken := {} #chunk (Vector2i) -> int bitmask: pickups bits 0-31, breakables 32-62

var fine := {}    #chunk -> PackedByteArray of terrain ids (FINE_W x FINE_H)
var rasters := {} #chunk -> the whole fineRaster result (fields for the art)
var recipes := {} #chunk -> its ChunkRecipe (when recipeContext is set)
## WorldSkin.recipeContext: what the chunk recipes are built with; empty builds rasters only
var recipeContext := {}
var lru: Array[Vector2i] = []
var pending := {} #chunk -> [task id, job]
var keep := {}    #chunks never evicted now (round the car)
var grid := WorldGrid.new() #native mirror of terrain and `fine` (set up by fromJob, kept in step by store)
var fineStats := {"count": 0, "usec": 0, "maxUsec": 0, "waits": 0}
var recipeStats := {"count": 0, "usec": 0, "maxUsec": 0}
var spawnCounter := 0
## chunk -> Array of [landmark prop id, world position]: each district's landmark (setupDistricts)
var landmarks := {}
## district id -> its tint as a 4-bit code (0..15) for the ground shader (ChunkRecipe puts it in the control
## block's flags byte); TINT_LOW..TINT_HIGH on screen
var tintCodes := PackedByteArray()
const LANDMARK_IDS := ["landmark_wild", "landmark_tribe", "landmark_scrap"]

var _cx := 1 << 30
var _cy := 0
var _fine := PackedByteArray()

#--- building --------------------------------------------------------------------------------------

## The coarse job for a level and seed. objective: "sprint" (a station stationOffset px from the start),
## "defense" (the station at the start, lanes) or "" (no station). Main thread: it reads the def and World.
static func jobFor(mapSeed: int, levelDef: LevelDef, objective: String = "", stationOffset := Vector2.ZERO) -> Dictionary:
	var snap := levelDef.snapshot()
	var bands := PackedByteArray()
	for t in levelDef.baseTerrain: bands.push_back(int(t))
	if bands.is_empty(): bands.push_back(0)
	snap["_main"] = WorldField.mainTerrain(bands)
	var weights := PackedFloat32Array()
	for row in World.TERRAIN: weights.push_back(row.routeWeight)
	return {"seed": mapSeed, "def": snap, "objective": objective, "stationOffset": stationOffset, "weights": weights}

## Builds a level's world on the calling thread (tests and tools; a run builds it on a worker)
static func build(mapSeed: int, levelDef: LevelDef, objective: String = "", stationOffset := Vector2.ZERO) -> WorldMap:
	var job := jobFor(mapSeed, levelDef, objective, stationOffset)
	WorldGen.buildCoarse(job)
	return fromJob(job, levelDef)

## The map from a finished coarse job
static func fromJob(job: Dictionary, levelDef: LevelDef) -> WorldMap:
	var map := WorldMap.new()
	var r: Dictionary = job.result
	map.worldSeed = int(job.seed)
	map.def = levelDef
	map.snapshot = job.def
	map.grammar = StringName(job.def.get("grammar", &"meadow"))
	map.startPosition = job.def.get("startPosition", Vector2.ZERO)
	map.terrain = r.terrain
	map.flags = r.flags
	map.aux = r.aux
	map.district = r.district
	map.crossings = r.crossings
	map.cover = r.cover
	map.astar = r.astar
	map.station = r.station
	map.stationChunk = r.stationChunk
	map.lanes = r.lanes
	map.route = r.route
	map.routeLength = r.routeLength
	map.buildMs = r.ms
	map.setupGrid()
	map.setupDistricts(r.districts)
	return map

## The native grid's table and coarse map (fine rasters are added as they are stored)
func setupGrid() -> void:
	grid.setTable(World._flags)
	grid.setFineLayout(Vector2(CHUNK_X, CHUNK_Y), WorldGen.FINE, Vector2i(WorldGen.FINE_W, WorldGen.FINE_H))
	grid.setCoarse(terrain, Vector2i(W, H), WorldGen.ORIGIN, WorldGen.CELL, WATER)

## Faction, goons, name, tint and giantism for every district, seeded per district
func setupDistricts(table: Array) -> void:
	districts.clear()
	landmarks.clear()
	tintCodes.clear()
	var usedNames := {}
	var seconds: Array = NAME_SECOND.get(grammar, NAME_SECOND[&"meadow"])
	var startIndex := coarseIndex(startPosition)
	var startDistrict := district[startIndex] if startIndex >= 0 else -1
	for entry in table:
		var d: Dictionary = entry.duplicate()
		var id: int = d.id
		var jitter := (WorldGen.hashf(worldSeed, WorldGen.TAG_FACTION, id, 0) * 2.0 - 1.0) * Goons.FACTION_JITTER
		#scored by the centroid's distance from the start; the start's own district counts as the start
		var distance: float = 0.0 if id == startDistrict else d.centroid.distance_to(startPosition)
		var faction := LevelRoster.factionAt(def, distance, jitter)
		var rng := RandomNumberGenerator.new()
		rng.seed = WorldGen.ihash(worldSeed, WorldGen.TAG_GOONS, id, 0)
		var goons: Array = LevelRoster.pickGoons(def, faction, rng) if def else []
		if not goons.is_empty(): faction = Goons.DATA[goons[0]].faction
		d.faction = faction
		d.goons = goons
		var firsts: Array = NAME_FIRST[clampi(faction, 0, NAME_FIRST.size() - 1)]
		var pick := WorldGen.ihash(worldSeed, WorldGen.TAG_NAME, id, 0)
		var name := ""
		for k in firsts.size() * seconds.size():
			var n := (pick + k * 7) % (firsts.size() * seconds.size())
			name = "%s %s" % [firsts[n % firsts.size()], seconds[n / firsts.size()]]
			if not usedNames.has(name): break
		usedNames[name] = true
		d.name = name
		d.tint = 0.9 + 0.18 * WorldGen.hashf(worldSeed, WorldGen.TAG_TINT, id, 0)
		d.giantism = WorldGen.ihash(worldSeed, WorldGen.TAG_GIANT, id, 0) % 100
		tintCodes.push_back(clampi(roundi((d.tint - 0.9) / 0.18 * 15.0), 0, 15))
		var at: Vector2 = d.get("landmark", Vector2.INF)
		if at != Vector2.INF:
			var chunk := WorldGen.chunkOf(at)
			landmarks.get_or_add(chunk, []).push_back([LANDMARK_IDS[clampi(faction, 0, 2)], at])
		districts.push_back(d)

#--- fine rasters ------------------------------------------------------------------------------------

static func chunkInMap(chunk: Vector2i) -> bool:
	return absi(chunk.x * 2 + 1) <= WorldGen.MAP_CHUNKS.x && absi(chunk.y * 2 + 1) <= WorldGen.MAP_CHUNKS.y

func fineJob(chunk: Vector2i) -> Dictionary:
	var job := {"chunk": chunk, "seed": worldSeed, "def": snapshot, "terrain": terrain, "flags": flags}
	if not recipeContext.is_empty():
		job.ctx = recipeContext
		job.aux = aux
		job.factions = chunkFactions(chunk)
		job.tints = chunkTints(chunk)
		var here: Array = landmarks.get(chunk, [])
		if not here.is_empty(): job.landmarks = here.duplicate(true)
	return job

## The district tint codes of a chunk's 8 coarse cells (row-major, 4 x 2). A cell on a barrier takes the
## nearest district's within a few cells (so a tint never stops short of a wall or a creek), else the middle.
func chunkTints(chunk: Vector2i) -> PackedByteArray:
	var out := PackedByteArray()
	var base := WorldGen.chunkCell(chunk)
	for k in 8:
		var cell := base + Vector2i(k % 4, k / 4)
		var d := districtOfCell(cell)
		if d < 0:
			for r in range(1, 4):
				for dy in range(-r, r + 1):
					for dx in range(-r, r + 1):
						if d >= 0 || maxi(absi(dx), absi(dy)) != r: continue
						d = districtOfCell(cell + Vector2i(dx, dy))
				if d >= 0: break
		out.push_back(tintCodes[d] if d >= 0 && d < tintCodes.size() else 8)
	return out

## The district faction of a chunk's 8 coarse cells (row-major, 4 x 2), -1 where there is none
func chunkFactions(chunk: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	var base := WorldGen.chunkCell(chunk)
	for k in 8:
		var cell := base + Vector2i(k % 4, k / 4)
		var d := districtOfCell(cell)
		out.push_back(int(districts[d].faction) if d >= 0 && d < districts.size() else -1)
	return out

## One chunk's worker task: its fine raster, then its recipe when the job carries a context
static func chunkTask(job: Dictionary) -> void:
	WorldGen.fineRaster(job)
	if job.has("ctx"): ChunkRecipe.build(job)

## Queues a chunk's raster (and recipe) on the worker pool (a no-op when cached, pending or off the map)
func request(chunk: Vector2i) -> void:
	if fine.has(chunk) || pending.has(chunk) || not chunkInMap(chunk): return
	var job := fineJob(chunk)
	pending[chunk] = [WorkerThreadPool.add_task(WorldMap.chunkTask.bind(job), false, "Chunk raster"), job]

## Takes in every finished raster (once a frame)
func poll() -> void:
	for chunk in pending.keys():
		if WorkerThreadPool.is_task_completed(pending[chunk][0]): finish(chunk)

func finish(chunk: Vector2i) -> void:
	var entry: Array = pending[chunk]
	pending.erase(chunk)
	WorkerThreadPool.wait_for_task_completion(entry[0])
	store(chunk, entry[1])

## The car's chunk always has its raster: waits for the task (queueing it first if need be)
func ensure(chunk: Vector2i) -> void:
	if fine.has(chunk):
		touch(chunk)
		return
	if not chunkInMap(chunk): return
	request(chunk)
	fineStats.waits += 1
	finish(chunk)

## Builds a raster on the calling thread (the level's first chunk; tests)
func buildNow(chunk: Vector2i) -> void:
	if fine.has(chunk) || not chunkInMap(chunk): return
	if pending.has(chunk):
		finish(chunk)
		return
	var job := fineJob(chunk)
	chunkTask(job)
	store(chunk, job)

## A chunk's recipe, or an empty Dictionary while it isn't built
func recipeOf(chunk: Vector2i) -> Dictionary:
	return recipes.get(chunk, {})

## Drops a chunk's cached raster and recipe, so the next request builds them again (one built before a
## station lot was reserved there)
func forget(chunk: Vector2i) -> void:
	if pending.has(chunk): finish(chunk)
	fine.erase(chunk)
	grid.eraseChunk(chunk)
	rasters.erase(chunk)
	recipes.erase(chunk)
	lru.erase(chunk)
	if chunk == Vector2i(_cx, _cy): _cx = 1 << 30

func store(chunk: Vector2i, job: Dictionary) -> void:
	var result: Dictionary = job.result
	fine[chunk] = result.terrain
	grid.setChunk(chunk, result.terrain)
	rasters[chunk] = result
	if job.has("recipe"):
		recipes[chunk] = job.recipe
		recipeStats.count += 1
		recipeStats.usec += job.recipe.usec
		recipeStats.maxUsec = maxi(recipeStats.maxUsec, job.recipe.usec)
	lru.erase(chunk)
	lru.push_back(chunk)
	fineStats.count += 1
	fineStats.usec += result.usec
	fineStats.maxUsec = maxi(fineStats.maxUsec, result.usec)
	if chunk == Vector2i(_cx, _cy): _cx = 1 << 30
	var i := 0
	while lru.size() > LRU && i < lru.size():
		var old := lru[i]
		if keep.has(old):
			i += 1
			continue
		lru.remove_at(i)
		fine.erase(old)
		grid.eraseChunk(old)
		rasters.erase(old)
		recipes.erase(old)
		if old == Vector2i(_cx, _cy): _cx = 1 << 30

func touch(chunk: Vector2i) -> void:
	if lru.is_empty() || lru[lru.size() - 1] != chunk:
		lru.erase(chunk)
		lru.push_back(chunk)

## The chunks that must stay cached (the car's 3 x 3)
func setKeep(chunks: Array) -> void:
	keep.clear()
	for c in chunks: keep[c] = true

## Waits for every queued raster (the level is leaving)
func shutdown() -> void:
	for chunk in pending.keys(): WorkerThreadPool.wait_for_task_completion(pending[chunk][0])
	pending.clear()

#--- the taken set -----------------------------------------------------------------------------------

## Marks a pickup (bits 0-31) or a breakable (32-62) of a chunk as gone for the rest of the run
func markTaken(chunk: Vector2i, bit: int) -> void:
	if bit < 0 || bit > 62: return
	taken[chunk] = int(taken.get(chunk, 0)) | (1 << bit)

func isTaken(chunk: Vector2i, bit: int) -> bool:
	return bit >= 0 && bit <= 62 && (int(taken.get(chunk, 0)) >> bit) & 1 == 1

## A collected pickup or smashed breakable: marks the bit in its metadata (worldSlot, Vector3i(chunk x,
## chunk y, bit), set by ChunkView), if it has one and a world is running
static func takeNode(node: Node) -> void:
	if Root.worldMap == null || not node.has_meta(&"worldSlot"): return
	var slot: Vector3i = node.get_meta(&"worldSlot")
	Root.worldMap.markTaken(Vector2i(slot.x, slot.y), slot.z)

#--- queries -----------------------------------------------------------------------------------------

## The terrain id under a world position: the fine raster's where loaded, else the coarse cell's.
## Outside the map is WATER.
func terrainAt(pos: Vector2) -> int:
	var cx := floori(pos.x / CHUNK_X)
	var cy := floori(pos.y / CHUNK_Y)
	if cx != _cx || cy != _cy:
		_cx = cx
		_cy = cy
		_fine = fine.get(Vector2i(cx, cy), PackedByteArray())
	if not _fine.is_empty():
		return _fine[(floori(pos.y / WorldGen.FINE) - cy * WorldGen.FINE_H) * WorldGen.FINE_W + floori(pos.x / WorldGen.FINE) - cx * WorldGen.FINE_W]
	return coarseTerrainAt(pos)

func coarseTerrainAt(pos: Vector2) -> int:
	var i := coarseIndex(pos)
	return WATER if i < 0 else terrain[i]

## The ground the car drives on (a bridge deck over water, say)
func surfaceAt(pos: Vector2) -> int:
	return terrainAt(pos)

## Deep water (fine field below 0 and not a bridge deck)
func lethalAt(pos: Vector2) -> bool:
	return World.isLethal(terrainAt(pos))

func blockedAt(pos: Vector2) -> bool:
	return World.isBlocked(terrainAt(pos))

func spawnableAt(pos: Vector2) -> bool:
	return World.isSpawnable(terrainAt(pos))

## The conveyor direction of the belt under a point (WorldField.beltCode: 1 +x, 2 -x, 3 +y, 4 -y)
func beltDirAt(pos: Vector2) -> Vector2:
	var i := coarseIndex(pos)
	match aux[i] if i >= 0 else 0:
		2: return Vector2.LEFT
		3: return Vector2.DOWN
		4: return Vector2.UP
	return Vector2.RIGHT

## The coarse cell (x, y) of a world position (may be off the map)
func coarseCell(pos: Vector2) -> Vector2i:
	return WorldGen.cellOf(pos)

## Index into the coarse arrays, -1 off the map
func coarseIndex(pos: Vector2) -> int:
	var x := floori((pos.x - WorldGen.ORIGIN.x) / WorldGen.CELL)
	var y := floori((pos.y - WorldGen.ORIGIN.y) / WorldGen.CELL)
	if x < 0 || y < 0 || x >= W || y >= H: return -1
	return y * W + x

func cellIndex(cell: Vector2i) -> int:
	return cell.y * W + cell.x if WorldGen.inMap(cell) else -1

## The district under a position, -1 on a barrier or off the map
func districtAt(pos: Vector2) -> int:
	var i := coarseIndex(pos)
	return district[i] if i >= 0 else -1

func districtOfCell(cell: Vector2i) -> int:
	var i := cellIndex(cell)
	return district[i] if i >= 0 else -1

func cellPassable(cell: Vector2i) -> bool:
	var i := cellIndex(cell)
	return i >= 0 && flags[i] & WorldGen.BLOCKED == 0

## Passable and reachable from the start
func cellReachable(cell: Vector2i) -> bool:
	var i := cellIndex(cell)
	return i >= 0 && flags[i] & (WorldGen.BLOCKED | WorldGen.START) == WorldGen.START

#--- objectives --------------------------------------------------------------------------------------

## A reachable station chunk near `desired`, never `forbidden`, and with an `origin` not much nearer to it
## than `desired` is (Marathon's next leg; WorldGen.findStationChunk)
func findStationChunk(desired: Vector2i, forbidden: Vector2i, origin := WorldGen.NO_CHUNK) -> Vector2i:
	return WorldGen.findStationChunk(flags, desired, forbidden, true, origin).chunk

## The A* route between two points on the coarse map: {points, length, reached}
func routeBetween(a: Vector2, b: Vector2) -> Dictionary:
	return WorldGen.routeBetween(astar, a, b)

## A seed for a spawner's own RNG: the world seed and a counter, so spawn offsets don't touch the global RNG
func nextSpawnerSeed() -> int:
	spawnCounter += 1
	return WorldGen.ihash(worldSeed, WorldGen.TAG_SPAWNER, spawnCounter, 0)

#--- chunk summary -----------------------------------------------------------------------------------

## A chunk at a glance: {"terrain": the commonest surface among its coarse cells (water or a wall only when
## the whole chunk is), "region": its district (-2 for none)}
func chunkTile(chunk: Vector2i) -> Dictionary:
	if not chunkInMap(chunk): return {"terrain": WATER, "region": -2}
	var base := WorldGen.chunkCell(chunk)
	var counts := {}
	var water := 0
	var walls := 0
	var best := -1
	var region := -2
	for k in CENTRE_FIRST: #the district at the chunk's middle, else any
		var i := (base.y + k / 4) * W + base.x + k % 4
		if district[i] >= 0:
			region = district[i]
			break
	for k in 8:
		var i := (base.y + k / 4) * W + base.x + k % 4
		if flags[i] & WorldGen.BLOCKED != 0:
			if terrain[i] == WATER: water += 1
			else: walls += 1
			continue
		var t: int = terrain[i]
		counts[t] = counts.get(t, 0) + 1
		if best < 0 || counts[t] > counts[best]: best = t
	if best < 0:
		if water + walls == 8: return {"terrain": WATER if water >= walls else HILLS, "region": -2}
		best = int(def.baseTerrain[0]) if def && not def.baseTerrain.is_empty() else 0
	return {"terrain": best, "region": region}
