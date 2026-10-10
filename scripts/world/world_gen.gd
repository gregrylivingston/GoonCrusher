class_name WorldGen extends RefCounted
## The world generator (docs/WORLD.md). Two jobs, both pure and worker-safe (they touch only their job
## Dictionary: no nodes, no autoloads, no global RNG):
##
## buildCoarse(job): the whole level as a coarse map of W x H cells of CELL px (4 x 2 per chunk), built
##   once per run. Per cell: a terrain id, FLAG bits, a district id and an aux byte (the conveyor
##   direction). It samples the level grammar's pure fields (WorldField) at every cell center, then applies
##   the guarantees in order: barrier share caps, the start bubble, crossings (no continuous barrier runs
##   more than MAX_RUN cells without one), connectivity (pockets under POCKET cells filled, larger islands
##   joined), the objectives (the station in the start component on clear cells; Defense's straight
##   lanes), districts (multi-source BFS from jittered seeds every DISTRICT_STEP cells), at least two exits
##   per district, and finally an AStarGrid2D over the passable cells with the route to the station.
##
## fineRaster(job): one chunk's fine map, FINE_W x FINE_H cells of FINE px, sampled from the same fields
##   with a one-cell apron (FIELD_W x FIELD_H) so neighboring chunks agree. The fine fields are clamped to
##   the coarse map so the two never disagree about passability: between the centers of two 4-adjacent
##   passable coarse cells the fine map is always open (at least 2 x 448 px wide), the center of a blocked
##   cell is always blocked, crossings (fords, bridges, passes) are opened at their full width.
##
## Random streams are ihash(seed, TAG, a, b): an integer mixer, so a run is the same for the same seed.

const CHUNK_PX := Vector2(5120, 2560)
const MAP_CHUNKS := Vector2i(96, 96) #chunk (0,0) is map cell (48,48); chunks -48..47
const CHUNK_LIMIT := 45 #objectives stay within this many chunks of the center on each axis
const CELL := 1280.0
const W := 384
const H := 192
const ORIGIN := Vector2(-245760.0, -122880.0) #world px of coarse cell (0,0)'s corner
const FINE := 128.0
const FINE_W := 40
const FINE_H := 20
const FIELD_W := 42 #with a one-cell apron
const FIELD_H := 22
const LOCAL_W := 7 #coarse cells round a chunk that its raster reads (4 x 2 plus a margin)
const LOCAL_H := 5
const NO_CHUNK := Vector2i(-99999, -99999)

#coarse cell flags
const BLOCKED := 1   #water or wall: A*, spawns and objectives keep out
const LETHAL := 2    #deep water
const CROSSING := 4  #a ford, bridge or pass cut through a barrier
const RESERVED := 8  #start bubble, objectives, set pieces, map edge: later passes leave it alone
const CROSS_X := 16  #a crossing traveled along x
const CROSS_Y := 32  #...along y
const FILL := 64     #a pocket filled in: the fine map fills it too
const START := 128   #in the start's component (reachable from the start)

const BAND := 0.4         #fields below this at a cell center block the coarse cell; also the shallows band
const WADE_DEPTH := 0.35  #the outer band of deep water (field 0 to -this, about 224 px) is wading depth (WADE) where WorldField.wade
const WADE_STEEP := 2.0   #...where water pillars and filled pockets fall this much faster, so they stay deep round a blocked cell's center
const A_LO := 0.3         #fine fields stay above (coarse envelope - A_LO): open corridors 896 px wide
const PILLAR_PX := 160.0  #fine fields are blocked within this of a blocked coarse cell's center
const MAX_RUN := 4        #barrier cells in a row before a crossing (spacing 5120 px)
const MAX_CUT := 4        #thickest barrier a crossing is cut through, in cells
const SHORT_BARRIER := 8  #barriers no longer than this (cells) are driven round, not cut
const DIAGONAL_RUN := 2   #runs this short (cells - 1 < this) chain diagonally
const POCKET := 12        #smaller enclosed areas are filled
const CONNECT_DEPTH := 6  #longest straight cut joining an island to the start component
const DISTRICT_STEP := 32 #district seeds every this many cells (about 40,000 px)
const DISTRICT_JITTER := 8
const EDGE_CELLS := 2
const WINDOW := Vector2i(12, 6) #3 x 3 chunks, for the barrier share
const LANDMARK_SEARCH := 10 #cells round a district's centroid its landmark may stand
const DEFENSE_LANE_PX := 4000.0
const DEFENSE_LANES := 3
const LANE_HALF_PX := 1000.0 #cells this close to a lane's line are cleared
const LOT_RECT := Rect2(-2600, -1400, 5300, 2800) #around the station (chunk center): the lot, 2000 px of approach east, room behind

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const SELF_AND_DIRS4: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

#hash tags
const TAG_RUN := 1
const TAG_SHARE := 2
const TAG_DISTRICT := 3
const TAG_LANE := 4
const TAG_SPRINT := 5
const TAG_LEG := 6
const TAG_SPAWNER := 7
const TAG_FACTION := 8
const TAG_NAME := 9
const TAG_TINT := 10
const TAG_GOONS := 11
const TAG_GIANT := 12
const TAG_FORD := 13 #mixed crossings: which bridges are fords
const TAG_SLOT := 14 #slot canyons: which passes are narrow

#terrain ids used here (Root.terrain)
const WATER := 3
const HILLS := 4
const SHALLOWS := 11
const BRIDGE := 18
const WADE := 19

#--- hashing -------------------------------------------------------------------------------------

static func mix(h: int) -> int:
	h = h & 0x7FFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0x7FFFFFFF
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0x7FFFFFFF
	return ((h >> 16) ^ h) & 0x7FFFFFFF

## A 31-bit hash of (seed, purpose tag, a, b): every random stream in the world comes from this
static func ihash(mapSeed: int, tag: int, a: int, b: int) -> int:
	return mix(mix(mix(mix(mapSeed ^ 0x2545F491) + tag) + a) + b)

## ihash as a float in [0, 1)
static func hashf(mapSeed: int, tag: int, a: int, b: int) -> float:
	return float(ihash(mapSeed, tag, a, b) & 0xFFFFFF) / 16777216.0

#--- geometry ------------------------------------------------------------------------------------

static func cellOf(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL))

static func cellCenter(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

static func inMap(c: Vector2i) -> bool:
	return c.x >= 0 && c.y >= 0 && c.x < W && c.y < H

static func chunkOf(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK_PX.x), floori(p.y / CHUNK_PX.y))

static func chunkCenter(chunk: Vector2i) -> Vector2:
	return (Vector2(chunk) + Vector2(0.5, 0.5)) * CHUNK_PX

## The coarse cells of a chunk: its top-left cell
static func chunkCell(chunk: Vector2i) -> Vector2i:
	return Vector2i(chunk.x * 4 + W / 2, chunk.y * 2 + H / 2)

## The chunks exactly `ring` steps (Chebyshev) from center, in a fixed order
static func ringChunks(center: Vector2i, ring: int) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	if ring == 0:
		chunks.push_back(center)
		return chunks
	for x in range(-ring, ring + 1):
		chunks.push_back(center + Vector2i(x, -ring))
		chunks.push_back(center + Vector2i(x, ring))
	for y in range(-ring + 1, ring):
		chunks.push_back(center + Vector2i(-ring, y))
		chunks.push_back(center + Vector2i(ring, y))
	return chunks

#--- the build state (one instance per coarse job) -----------------------------------------------

var seedValue := 0
var def := {}
var field: WorldField
var weights := PackedFloat32Array()
var terrain := PackedByteArray()
var flags := PackedByteArray()
var surf := PackedByteArray()
var aux := PackedByteArray()
var cover := PackedByteArray() #how much of a blocked cell the barrier really covers, 0..255 (from its field at the center)
var district := PackedInt32Array()
var shortBarrier := PackedByteArray()
var comp := PackedInt32Array()
var compSizes := PackedInt32Array()
var crossings := PackedInt32Array()
var startPos := Vector2.ZERO
var startIndex := 0
var station := Vector2.INF
var stationChunk := NO_CHUNK
var lanes: Array = []
var districtCount := 0

## Job keys: seed (int), def (LevelDef.snapshot() plus "_main"), objective ("sprint", "defense" or ""),
## stationOffset (Vector2, px from the start, for "sprint"), weights (PackedFloat32Array: A* weight per
## terrain id). Writes job.result: terrain, flags, aux, district (PackedInt32Array), districts (Array of
## {id, cells, centroid, seedCell, neighbors, inStart}), crossings, station (Vector2, INF without one),
## stationChunk, lanes (Array of Vector2 mouths), route (PackedVector2Array), routeLength, astar
## (AStarGrid2D), startCell, ms (timings).
static func buildCoarse(job: Dictionary) -> void:
	var build := WorldGen.new()
	build.run(job)

func run(job: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	seedValue = int(job.seed)
	def = job.def
	weights = job.get("weights", PackedFloat32Array())
	field = WorldField.make(seedValue, def)
	if not field.colFlag.is_empty(): def["_lattice"] = field.lattice() #the chunk rasters reuse it (job.def becomes the map's snapshot)
	startPos = def.get("startPosition", Vector2.ZERO)
	var startCell := cellOf(startPos)
	startIndex = startCell.y * W + startCell.x
	sampleCells()
	var t1 := Time.get_ticks_usec()
	var steps := {}
	var mark := t1
	grammarPost()
	shareCaps()
	steps.share = (Time.get_ticks_usec() - mark) / 1000.0
	mark = Time.get_ticks_usec()
	startBubble()
	markShortBarriers()
	cutCrossings(true)
	cutCrossings(false)
	cutCrossings(true) #the second pass's cuts can split runs the first found too thick: look again
	steps.crossings = (Time.get_ticks_usec() - mark) / 1000.0
	mark = Time.get_ticks_usec()
	connectIslands()
	steps.islands = (Time.get_ticks_usec() - mark) / 1000.0
	var t2 := Time.get_ticks_usec()
	markStart()
	match String(job.get("objective", "")):
		"sprint": placeSprintStation(job.get("stationOffset", Vector2(28000, 0)))
		"defense": placeDefense()
	steps.objectives = (Time.get_ticks_usec() - t2) / 1000.0
	mark = Time.get_ticks_usec()
	buildDistricts()
	steps.bfs = (Time.get_ticks_usec() - mark) / 1000.0
	mark = Time.get_ticks_usec()
	repairExits()
	mixCrossings()
	steps.exits = (Time.get_ticks_usec() - mark) / 1000.0
	mark = Time.get_ticks_usec()
	markStart()
	steps.start = (Time.get_ticks_usec() - mark) / 1000.0
	var t3 := Time.get_ticks_usec()
	var astar := makeAStar(terrain, flags, weights)
	var route := {"points": PackedVector2Array(), "length": 0.0, "reached": false}
	if station != Vector2.INF: route = routeBetween(astar, startPos, station)
	var t4 := Time.get_ticks_usec()
	job.result = {
		"terrain": terrain, "flags": flags, "aux": aux, "district": district, "districts": districtTable(),
		"crossings": crossings, "cover": cover, "station": station, "stationChunk": stationChunk, "lanes": lanes,
		"route": route.points, "routeLength": route.length, "routeReached": route.reached, "astar": astar,
		"startCell": startCell, "main": field.main, "grammar": field.grammar,
		"ms": {"sample": (t1 - t0) / 1000.0, "rules": (t2 - t1) / 1000.0, "districts": (t3 - t2) / 1000.0, "astar": (t4 - t3) / 1000.0, "total": (t4 - t0) / 1000.0, "steps": steps},
	}

## A field value at a cell center as the share of the cell its barrier covers (0..255): 1 deep inside
## (-1 unit, 640 px), half on the edge, none a unit outside
static func coverOf(fieldValue: float) -> int:
	return int(clampf(0.5 - fieldValue * 0.5, 0.0, 1.0) * 255.0)

func isBlocked(i: int) -> bool:
	return flags[i] & BLOCKED != 0

#every cell center through the grammar's fields
func sampleCells() -> void:
	var n := W * H
	terrain.resize(n)
	flags.resize(n)
	surf.resize(n)
	aux.resize(n)
	cover.resize(n)
	flags.fill(0)
	aux.fill(0)
	cover.fill(0)
	for cy in H:
		var y := ORIGIN.y + (cy + 0.5) * CELL
		var row := cy * W
		var edgeRow := cy < EDGE_CELLS || cy >= H - EDGE_CELLS
		for cx in W:
			var i := row + cx
			var v := field.sample(ORIGIN.x + (cx + 0.5) * CELL, y)
			surf[i] = int(v.z)
			if edgeRow || cx < EDGE_CELLS || cx >= W - EDGE_CELLS:
				terrain[i] = WATER
				flags[i] = BLOCKED | LETHAL | RESERVED
				cover[i] = 255
			elif v.y < BAND:
				terrain[i] = field.wallTerrain
				flags[i] = BLOCKED
				cover[i] = coverOf(v.y)
			elif v.x < BAND:
				terrain[i] = WATER
				flags[i] = BLOCKED | LETHAL
				cover[i] = coverOf(v.x)
			else:
				terrain[i] = int(v.z)

#grammar specifics the fields alone don't say: city bridges, belt directions, set-piece reservations
func grammarPost() -> void:
	match field.grammar:
		WorldField.Grammar.CITY:
			for cy in H:
				var wy := cy - H / 2
				if field.streetRow(wy) != 2: continue
				for cx in W:
					var i := cy * W + cx
					if field.isStreetCol(cx - W / 2) && flags[i] & RESERVED == 0:
						openCell(i, CROSS_Y)
						flags[i] |= RESERVED
		WorldField.Grammar.YARD:
			for i in W * H:
				var c := Vector2i(i % W, i / W)
				if terrain[i] == WorldField.CONVEYOR: aux[i] = field.beltCode(c.y - H / 2)
				if field.isTankFarm(c.x - W / 2, c.y - H / 2): flags[i] |= RESERVED
		WorldField.Grammar.QUARRY:
			var rect := Rect2(ORIGIN, Vector2(W, H) * CELL)
			for piece in field.piecesIn(rect):
				reserveDisc(piece[1], piece[2] + 600.0)
				#each ramp or gate is a crossing through the ring: the gap is narrower than a cell, so the
				#cells its center line runs through are opened, or the coarse ring could stay shut
				for k in piece[4]:
					var dir := Vector2.from_angle(piece[3] + k * TAU / piece[4])
					var how := CROSS_X if absf(dir.x) > absf(dir.y) else CROSS_Y
					for t in range(-1600, 1601, 256):
						var cell := cellOf(piece[1] + dir * (piece[2] + t))
						if not inMap(cell) || isEdge(cell): continue
						openCell(cell.y * W + cell.x, how)
		WorldField.Grammar.HIGHWAY:
			#gas station lots beside the highways near the middle of the map
			for k in range(-5, 6):
				for gi in range(-16, 17):
					reserveDisc(field.gasStation(gi, k), 1100.0)

static func isEdge(cell: Vector2i) -> bool:
	return cell.x < EDGE_CELLS || cell.y < EDGE_CELLS || cell.x >= W - EDGE_CELLS || cell.y >= H - EDGE_CELLS

func reserveDisc(center: Vector2, radius: float) -> void:
	var lo := cellOf(center - Vector2(radius, radius))
	var hi := cellOf(center + Vector2(radius, radius))
	for cy in range(maxi(lo.y, 0), mini(hi.y, H - 1) + 1):
		for cx in range(maxi(lo.x, 0), mini(hi.x, W - 1) + 1):
			if cellCenter(Vector2i(cx, cy)).distance_to(center) < radius + CELL * 0.5: flags[cy * W + cx] |= RESERVED

## Opens a blocked cell: a crossing (how = CROSS_X or CROSS_Y: a ford or bridge over water, a pass through a
## wall) or a plain clearing (how = 0: share caps, the start bubble, objectives)
func openCell(i: int, how: int) -> void:
	if not isBlocked(i): return
	var wasWater := terrain[i] == WATER
	flags[i] = flags[i] & RESERVED
	terrain[i] = surf[i]
	cover[i] = 0
	if how != 0:
		flags[i] |= CROSSING | how
		if wasWater: terrain[i] = field.waterCrossing
		crossings.push_back(i)

#--- share caps ------------------------------------------------------------------------------------

#Hard barriers may cover at most field.barrierCap of any 3x3-chunk window (chunk-aligned, every chunk
#offset), measured by `cover` (what the barrier really covers, not whole coarse cells: a creek 1100 px
#wide blocks a full row of cells but covers 86% of it). Over the cap, cells are removed from blob edges
#first (the most blocked neighbors), so lakes and mesas shrink before thin barriers get holes. Reserved
#cells (set pieces, the map edge) don't count.
func shareCaps() -> void:
	var maxCells := int(floor(field.barrierCap * WINDOW.x * WINDOW.y * 255.0))
	#a summed-area table of the barrier cells; trims only remove barrier, so a window it calls under the
	#cap is, and one it calls over is recounted before trimming
	var sat := PackedInt32Array()
	sat.resize((W + 1) * (H + 1))
	sat.fill(0)
	for y in H:
		var rowSum := 0
		for x in W:
			if flags[y * W + x] & (BLOCKED | RESERVED) == BLOCKED: rowSum += cover[y * W + x]
			sat[(y + 1) * (W + 1) + x + 1] = sat[y * (W + 1) + x + 1] + rowSum
	for wy in range(0, H - WINDOW.y + 1, 2):
		for wx in range(0, W - WINDOW.x + 1, 4):
			var x1 := wx + WINDOW.x
			var y1 := wy + WINDOW.y
			var stale := sat[y1 * (W + 1) + x1] - sat[wy * (W + 1) + x1] - sat[y1 * (W + 1) + wx] + sat[wy * (W + 1) + wx]
			if stale <= maxCells: continue
			var count := 0
			for y in range(wy, y1):
				for x in range(wx, x1):
					if flags[y * W + x] & (BLOCKED | RESERVED) == BLOCKED: count += cover[y * W + x]
			if count > maxCells: trimWindow(wx, wy, count - maxCells)

func trimWindow(wx: int, wy: int, excess: int) -> void:
	for attempt in 4:
		var candidates: Array = []
		for y in range(wy, wy + WINDOW.y):
			for x in range(wx, wx + WINDOW.x):
				var i := y * W + x
				if flags[i] & (BLOCKED | RESERVED) != BLOCKED: continue
				var blockedAround := 0
				var openAround := 0
				for d in DIRS8:
					var c := Vector2i(x, y) + d
					if not inMap(c): continue
					if isBlocked(c.y * W + c.x): blockedAround += 1
					elif d.x == 0 || d.y == 0: openAround += 1
				if openAround == 0: continue
				candidates.push_back(blockedAround * 4096 + (ihash(seedValue, TAG_SHARE, i, 0) & 4095))
				candidates.push_back(i)
		if candidates.is_empty(): return
		var order: Array = []
		for k in range(0, candidates.size(), 2): order.push_back([candidates[k], candidates[k + 1]])
		order.sort_custom(func(a, b): return a[0] > b[0])
		for entry in order:
			if excess <= 0: return
			excess -= cover[entry[1]]
			openCell(entry[1], 0)
		if excess <= 0: return

#--- start bubble ----------------------------------------------------------------------------------

#No barrier within START_CLEAR px of the start (the fields already open it; this clears the coarse cells
#round it too, so the fine map can't close in), and the start's surroundings are reserved.
func startBubble() -> void:
	var radius := WorldField.START_CLEAR + CELL * 1.5
	var lo := cellOf(startPos - Vector2(radius, radius))
	var hi := cellOf(startPos + Vector2(radius, radius))
	for cy in range(maxi(lo.y, 0), mini(hi.y, H - 1) + 1):
		for cx in range(maxi(lo.x, 0), mini(hi.x, W - 1) + 1):
			if cellCenter(Vector2i(cx, cy)).distance_to(startPos) >= radius: continue
			var i := cy * W + cx
			if isEdge(Vector2i(cx, cy)): continue
			openCell(i, 0)
			flags[i] |= RESERVED

#--- crossings ---------------------------------------------------------------------------------------

#Along every continuous barrier, a crossing at least every MAX_RUN cells. alongX scans the map column by
#column for barriers that run along x (each column holds a vertical run of barrier cells; runs that touch
#the previous column's, diagonally included, continue its count) and cuts crossings traveled along y; the
#other pass does the same for barriers along y. A crossing goes through a run at most MAX_CUT cells thick
#with open ground on both sides; a thicker stretch keeps counting until a thin one comes.
#The build runs it natively (WorldGenNative.cutCrossings, docs/NATIVE.md: it was the build's slowest step);
#cutCrossingsGDScript is the same rule, kept for the parity test.
func cutCrossings(alongX: bool) -> void:
	var out := WorldGenNative.cutCrossings(flags, terrain, cover, surf, shortBarrier, crossings, seedValue, alongX, field.waterCrossing)
	flags = out[0]
	terrain = out[1]
	cover = out[2]
	crossings = out[3]

func cutCrossingsGDScript(alongX: bool) -> void:
	var outer := W if alongX else H
	var inner := H if alongX else W
	var prev: Array = []
	for o in outer:
		var cur: Array = []
		var k := 0
		while k < inner:
			if not cuttable(cellIndex(o, k, alongX)):
				k += 1
				continue
			var a0 := k
			while k < inner && cuttable(cellIndex(o, k, alongX)): k += 1
			var a1 := k - 1
			var count := 0
			if not nearCrossing(o, a0, a1, alongX):
				for r in prev:
					if runsChain(r[0], r[1], a0, a1): count = maxi(count, r[2])
				count += 1
			var limit := MAX_RUN - (ihash(seedValue, TAG_RUN, o * 1024 + a0, 1 if alongX else 0) & 1)
			if count > limit && a1 - a0 + 1 <= MAX_CUT && a0 > 0 && a1 < inner - 1 \
					&& not isBlocked(cellIndex(o, a0 - 1, alongX)) && not isBlocked(cellIndex(o, a1 + 1, alongX)):
				for a in range(a0, a1 + 1): openCell(cellIndex(o, a, alongX), CROSS_Y if alongX else CROSS_X)
				count = 0
			cur.push_back([a0, a1, count])
		prev = cur

## The first cell of the crossing a crossing cell belongs to: walked back against its direction of travel
## while the cells are crossings the same way. Every cell of one crossing (1-4 cells through a barrier) has
## the same root, so a choice hashed on it (a ford or a bridge, a slot or a wide pass) holds for the whole way.
static func crossingRoot(flagArray: PackedByteArray, i: int) -> int:
	var how := flagArray[i] & (CROSS_X | CROSS_Y)
	var step := -1 if how == CROSS_X else -W
	for k in MAX_CUT + CONNECT_DEPTH:
		var j := i + step
		if j < 0 || (how == CROSS_X && j % W == W - 1): break
		if flagArray[j] & CROSSING == 0 || flagArray[j] & (CROSS_X | CROSS_Y) != how: break
		i = j
	return i

## Whether the pass through crossing cell i is a slot canyon (WorldField.slotShare of them, by its root)
static func isSlot(mapSeed: int, flagArray: PackedByteArray, i: int, share: float) -> bool:
	return share > 0.0 && hashf(mapSeed, TAG_SLOT, crossingRoot(flagArray, i), 0) < share

## Mixed crossings (features "fordShare", L-6): on a grammar that bridges its water, a hashed share of the
## water crossings become fords (SHALLOWS) instead, each crossing as a whole. The fine raster opens a ford
## at fordHalf, a bridge at bridgeHalf, by the coarse terrain.
func mixCrossings() -> void:
	if field.fordShare <= 0.0 || field.waterCrossing != BRIDGE: return
	for i in crossings:
		if terrain[i] != BRIDGE || flags[i] & CROSSING == 0: continue
		if hashf(seedValue, TAG_FORD, crossingRoot(flags, i), 0) < field.fordShare: terrain[i] = SHALLOWS

## Whether a run of barrier cells (a0..a1 along a column or row) continues the previous column's run
## (p0..p1): they overlap, or touch diagonally when both are short (a diagonal line of barrier). Longer runs
## touching only at a corner are perpendicular walls meeting, not one barrier.
static func runsChain(p0: int, p1: int, a0: int, a1: int) -> bool:
	if p0 <= a1 && p1 >= a0: return true
	if p1 - p0 >= DIAGONAL_RUN || a1 - a0 >= DIAGONAL_RUN: return false
	return p1 == a0 - 1 || p0 == a1 + 1

func nearCrossing(o: int, a0: int, a1: int, alongX: bool) -> bool:
	return crossingNear(flags, o, a0, a1, alongX)

## Whether a crossing touches a run (8-neighbors): the barrier already has a way through here
static func crossingNear(flagArray: PackedByteArray, o: int, a0: int, a1: int, alongX: bool) -> bool:
	for a in range(a0 - 1, a1 + 2):
		for d in range(-1, 2):
			var x := o + d if alongX else a
			var y := a if alongX else o + d
			if x < 0 || y < 0 || x >= W || y >= H: continue
			if flagArray[y * W + x] & CROSSING != 0: return true
	return false

func cellIndex(o: int, k: int, alongX: bool) -> int:
	return k * W + o if alongX else o * W + k

func cuttable(i: int) -> bool:
	return flags[i] & (BLOCKED | RESERVED) == BLOCKED && shortBarrier[i] == 0

## Marks the cells of short barriers (8-connected barrier components no more than SHORT_BARRIER cells across:
## mesas, ponds, short walls): the car goes round them, so they get no crossings.
func markShortBarriers() -> void:
	shortBarrier = barrierExtents(flags)

## 1 for every cell of an 8-connected component of blocked, unreserved cells whose bounding box is at most
## SHORT_BARRIER cells on its longer side, else 0. Native (WorldGenNative); the GDScript below is the parity copy.
static func barrierExtents(flagArray: PackedByteArray) -> PackedByteArray:
	return WorldGenNative.barrierExtents(flagArray)

static func barrierExtentsGDScript(flagArray: PackedByteArray) -> PackedByteArray:
	var n := W * H
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var stack := PackedInt32Array()
	var members := PackedInt32Array()
	for s in n:
		if seen[s] != 0 || flagArray[s] & (BLOCKED | RESERVED) != BLOCKED: continue
		seen[s] = 1
		stack.push_back(s)
		members.clear()
		var lo := Vector2i(s % W, s / W)
		var hi := lo
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			members.push_back(i)
			var x := i % W
			var y := i / W
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
			for d in DIRS8:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 || ny < 0 || nx >= W || ny >= H: continue
				var j := ny * W + nx
				if seen[j] == 0 && flagArray[j] & (BLOCKED | RESERVED) == BLOCKED:
					seen[j] = 1
					stack.push_back(j)
		if maxi(hi.x - lo.x, hi.y - lo.y) + 1 <= SHORT_BARRIER:
			for i in members: out[i] = 1
	return out

#--- connectivity ------------------------------------------------------------------------------------

## Labels the 4-connected passable components (comp, -1 where blocked); returns how many
func components() -> int:
	var n := W * H
	comp.resize(n)
	comp.fill(-1)
	compSizes = PackedInt32Array()
	var stack := PackedInt32Array()
	var count := 0
	for s in n:
		if comp[s] != -1 || flags[s] & BLOCKED != 0: continue
		comp[s] = count
		stack.push_back(s)
		var size := 0
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			var x := i % W
			if x > 0 && comp[i - 1] == -1 && flags[i - 1] & BLOCKED == 0:
				comp[i - 1] = count
				stack.push_back(i - 1)
			if x < W - 1 && comp[i + 1] == -1 && flags[i + 1] & BLOCKED == 0:
				comp[i + 1] = count
				stack.push_back(i + 1)
			if i >= W && comp[i - W] == -1 && flags[i - W] & BLOCKED == 0:
				comp[i - W] = count
				stack.push_back(i - W)
			if i + W < n && comp[i + W] == -1 && flags[i + W] & BLOCKED == 0:
				comp[i + W] = count
				stack.push_back(i + W)
		compSizes.push_back(size)
		count += 1
	return count

#Pockets smaller than POCKET cells are filled (FILL: blocked, the barrier round them); larger islands are
#joined to the start's component by the shortest straight cut (a crossing) of at most CONNECT_DEPTH cells.
#An island no cut reaches stays as it is: nothing is placed there, and A* never routes to it.
func connectIslands() -> void:
	var count := components()
	var startComp := comp[startIndex]
	var members: Array = []
	for c in count: members.push_back(PackedInt32Array())
	for i in W * H:
		if comp[i] >= 0: members[comp[i]].push_back(i)
	var order: Array = range(count)
	order.sort_custom(func(a, b): return compSizes[a] > compSizes[b] || (compSizes[a] == compSizes[b] && a < b))
	for c in order:
		if c != startComp && compSizes[c] < POCKET: fillPocket(members[c])
	var connected := {startComp: true}
	for pass_ in 3:
		var changed := false
		for c in order:
			if connected.has(c) || compSizes[c] < POCKET: continue
			if joinIsland(members[c], connected):
				connected[c] = true
				changed = true
		if not changed: break

func fillPocket(cells: PackedInt32Array) -> void:
	var water := 0
	var wall := 0
	for i in cells:
		for j in [i - 1, i + 1, i - W, i + W]:
			if j < 0 || j >= W * H || not isBlocked(j): continue
			if terrain[j] == WATER: water += 1
			else: wall += 1
	for i in cells:
		var keep := flags[i] & RESERVED
		if water >= wall:
			terrain[i] = WATER
			flags[i] = BLOCKED | LETHAL | FILL | keep
		else:
			terrain[i] = field.wallTerrain
			flags[i] = BLOCKED | FILL | keep
		comp[i] = -1

## The shortest straight cut from an island's edge to a connected component; true when one was cut
func joinIsland(cells: PackedInt32Array, connected: Dictionary) -> bool:
	var bestLength := CONNECT_DEPTH + 1
	var bestFrom := -1
	var bestDir := Vector2i.ZERO
	for i in cells:
		var from := Vector2i(i % W, i / W)
		for dir in DIRS4:
			for step in range(1, CONNECT_DEPTH + 1):
				var c: Vector2i = from + dir * step
				if not inMap(c): break
				var j := c.y * W + c.x
				if isBlocked(j):
					if flags[j] & RESERVED != 0: break
					continue
				if step > 1 && comp[j] >= 0 && connected.has(comp[j]) && step - 1 < bestLength:
					bestLength = step - 1
					bestFrom = i
					bestDir = dir
				break
	if bestFrom < 0: return false
	var from := Vector2i(bestFrom % W, bestFrom / W)
	for step in range(1, bestLength + 1):
		var c := from + bestDir * step
		openCell(c.y * W + c.x, CROSS_X if bestDir.x != 0 else CROSS_Y)
	return true

## Recomputes components and sets START on the start's
func markStart() -> void:
	components()
	var startComp := comp[startIndex]
	for i in W * H:
		if comp[i] == startComp: flags[i] |= START
		else: flags[i] &= ~START

#--- objectives --------------------------------------------------------------------------------------

## The cells of the station lot rect around a chunk's center
static func lotCells(chunk: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	var center := chunkCenter(chunk)
	var lo := cellOf(center + LOT_RECT.position)
	var hi := cellOf(center + LOT_RECT.end - Vector2.ONE)
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			if inMap(Vector2i(cx, cy)): out.push_back(cy * W + cx)
	return out

## The four cells round a chunk's center (the station's footprint): all passable, and in the start component
## when needStart
static func stationCoreOk(flagArray: PackedByteArray, chunk: Vector2i, needStart: bool) -> bool:
	var c := chunkCell(chunk) + Vector2i(1, 0) #the cell left of and above the center corner
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cell: Vector2i = c + d
		if not inMap(cell): return false
		var f := flagArray[cell.y * W + cell.x]
		if f & BLOCKED != 0: return false
		if needStart && f & START == 0: return false
	return true

static func lotClear(flagArray: PackedByteArray, chunk: Vector2i) -> bool:
	var cells := lotCells(chunk)
	if cells.size() < 24: return false
	for i in cells:
		if flagArray[i] & BLOCKED != 0: return false
	return true

## The chunk for a station near `desired`: the nearest chunk (square rings outward, clamped to CHUNK_LIMIT)
## whose center cells are passable and reachable (START) and whose lot rect is clear; failing that within
## three more rings, the nearest with a good center. Never `forbidden`. {chunk, clear}
## With an `origin` (the start, or Marathon's last station), only chunks at least STATION_MIN_SHARE as far
## from it as `desired` count: the nearest good chunk could lie back toward the start, which once put a
## Crusher Sprint station 11,812 px out instead of 32,000. If none qualifies, any chunk does, as before.
const STATION_MIN_SHARE := 0.85
static func findStationChunk(flagArray: PackedByteArray, desired: Vector2i, forbidden: Vector2i, needStart := true, origin := NO_CHUNK) -> Dictionary:
	if origin != NO_CHUNK:
		var far := findStationChunkFrom(flagArray, desired, forbidden, needStart, origin, STATION_MIN_SHARE)
		if far.chunk != NO_CHUNK: return far
	return findStationChunkFrom(flagArray, desired, forbidden, needStart, NO_CHUNK, 0.0, true)

## findStationChunk's search. Chunks closer to `origin` than `minShare` of desired's distance are skipped;
## {chunk: NO_CHUNK} when nothing qualifies, unless `orCenter` (then the clamped center, as before)
static func findStationChunkFrom(flagArray: PackedByteArray, desired: Vector2i, forbidden: Vector2i, needStart: bool, origin: Vector2i, minShare: float, orCenter := false) -> Dictionary:
	var limit := Vector2i(CHUNK_LIMIT, CHUNK_LIMIT)
	var center := desired.clamp(-limit, limit)
	var minDistance := 0.0
	if origin != NO_CHUNK: minDistance = Vector2(center - origin).length() * minShare
	var fallback := NO_CHUNK
	var fallbackRing := -1
	for ring in range(0, 2 * CHUNK_LIMIT + 1):
		if fallbackRing >= 0 && ring > fallbackRing + 3: break
		var best := NO_CHUNK
		var bestDistance := INF
		var bestPlainDistance := INF
		for chunk in ringChunks(center, ring):
			if chunk == forbidden || absi(chunk.x) > CHUNK_LIMIT || absi(chunk.y) > CHUNK_LIMIT: continue
			if minDistance > 0.0 && Vector2(chunk - origin).length() < minDistance: continue
			if not stationCoreOk(flagArray, chunk, needStart): continue
			var distance := float((chunk - center).length_squared())
			if fallbackRing < 0 && distance < bestPlainDistance:
				bestPlainDistance = distance
				fallback = chunk
			if distance < bestDistance && lotClear(flagArray, chunk):
				best = chunk
				bestDistance = distance
		if best != NO_CHUNK: return {"chunk": best, "clear": true}
		if fallback != NO_CHUNK && fallbackRing < 0: fallbackRing = ring
	return {"chunk": fallback if fallback != NO_CHUNK else (center if orCenter else NO_CHUNK), "clear": false}

func placeSprintStation(offset: Vector2) -> void:
	var startChunk := chunkOf(startPos)
	var found := findStationChunk(flags, chunkOf(startPos + offset), startChunk, true, startChunk)
	stationChunk = found.chunk
	station = chunkCenter(stationChunk)
	clearLot(stationChunk)

func clearLot(chunk: Vector2i) -> void:
	for i in lotCells(chunk):
		if isEdge(Vector2i(i % W, i / W)): continue #the ocean round the map
		openCell(i, 0)
		flags[i] |= RESERVED | START #next to reachable cells; the end recounts anyway

#Defense: the station is the start's own chunk; DEFENSE_LANES straight lanes DEFENSE_LANE_PX long run
#out from it at seeded angles, cleared and reserved, and the spawners sit at their mouths.
func placeDefense() -> void:
	var startChunk := chunkOf(startPos)
	var found := findStationChunk(flags, startChunk, NO_CHUNK)
	stationChunk = found.chunk
	station = chunkCenter(stationChunk)
	clearLot(stationChunk)
	var turn := hashf(seedValue, TAG_LANE, 0, 0) * TAU
	for k in DEFENSE_LANES:
		var angle := turn + k * TAU / DEFENSE_LANES + (hashf(seedValue, TAG_LANE, k + 1, 0) - 0.5) * 0.6
		var dir := Vector2.from_angle(angle)
		var from := station + dir * 900.0
		var to := station + dir * (DEFENSE_LANE_PX + 900.0)
		var lo := cellOf(Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2.ONE * LANE_HALF_PX)
		var hi := cellOf(Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2.ONE * LANE_HALF_PX)
		for cy in range(maxi(lo.y, 0), mini(hi.y, H - 1) + 1):
			for cx in range(maxi(lo.x, 0), mini(hi.x, W - 1) + 1):
				var c := cellCenter(Vector2i(cx, cy))
				if Geometry2D.get_closest_point_to_segment(c, from, to).distance_to(c) > LANE_HALF_PX: continue
				var i := cy * W + cx
				if isEdge(Vector2i(cx, cy)): continue
				openCell(i, 0)
				flags[i] |= RESERVED
		lanes.push_back(station + dir * DEFENSE_LANE_PX)

#--- districts ---------------------------------------------------------------------------------------

#Multi-source BFS over passable cells from seeds every DISTRICT_STEP cells (jittered), so barriers become
#borders; cells no seed reaches (islands) get districts of their own.
func buildDistricts() -> void:
	var n := W * H
	district.resize(n)
	district.fill(-1)
	var queue := PackedInt32Array()
	districtCount = 0
	for sy in range(0, H, DISTRICT_STEP):
		for sx in range(0, W, DISTRICT_STEP):
			var jx := ihash(seedValue, TAG_DISTRICT, sx, sy) % (2 * DISTRICT_JITTER + 1) - DISTRICT_JITTER
			var jy := ihash(seedValue, TAG_DISTRICT + 100, sx, sy) % (2 * DISTRICT_JITTER + 1) - DISTRICT_JITTER
			var want := Vector2i(clampi(sx + DISTRICT_STEP / 2 + jx, 0, W - 1), clampi(sy + DISTRICT_STEP / 2 + jy, 0, H - 1))
			var cell := nearestPassable(want, DISTRICT_JITTER)
			if cell < 0 || district[cell] != -1: continue
			district[cell] = districtCount
			queue.push_back(cell)
			districtCount += 1
	flood(queue)
	for i in n:
		if district[i] != -1 || flags[i] & BLOCKED != 0: continue
		district[i] = districtCount
		districtCount += 1
		flood(PackedInt32Array([i]))

func nearestPassable(c: Vector2i, radius: int) -> int:
	for r in radius + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var cell := c + Vector2i(dx, dy)
				if inMap(cell) && not isBlocked(cell.y * W + cell.x): return cell.y * W + cell.x
	return -1

func flood(queue: PackedInt32Array) -> void:
	var head := 0
	var n := W * H
	while head < queue.size():
		var i := queue[head]
		head += 1
		var id := district[i]
		var x := i % W
		if x > 0 && district[i - 1] == -1 && flags[i - 1] & BLOCKED == 0:
			district[i - 1] = id
			queue.push_back(i - 1)
		if x < W - 1 && district[i + 1] == -1 && flags[i + 1] & BLOCKED == 0:
			district[i + 1] = id
			queue.push_back(i + 1)
		if i >= W && district[i - W] == -1 && flags[i - W] & BLOCKED == 0:
			district[i - W] = id
			queue.push_back(i - W)
		if i + W < n && district[i + W] == -1 && flags[i + W] & BLOCKED == 0:
			district[i + W] = id
			queue.push_back(i + W)

## Every district's neighboring districts (4-adjacent passable cells), as Array of Dictionary sets
func districtNeighbors() -> Array:
	var out: Array = []
	for d in districtCount: out.push_back({})
	for i in W * H:
		var d := district[i]
		if d < 0: continue
		if i % W < W - 1:
			var e := district[i + 1]
			if e >= 0 && e != d:
				out[d][e] = true
				out[e][d] = true
		if i + W < W * H:
			var e := district[i + W]
			if e >= 0 && e != d:
				out[d][e] = true
				out[e][d] = true
	return out

#Every district of the start component gets at least two exits (neighboring districts): a district with
#fewer gets the shortest straight cut (at most MAX_CUT cells) from its edge to a district it doesn't
#border yet.
func repairExits() -> void:
	var neighbors := districtNeighbors()
	var members: Array = []
	for d in districtCount: members.push_back(PackedInt32Array())
	for i in W * H:
		if district[i] >= 0: members[district[i]].push_back(i)
	for d in districtCount:
		if neighbors[d].size() >= 2: continue
		var cells: PackedInt32Array = members[d]
		if cells.is_empty() || flags[cells[0]] & START == 0: continue
		var bestLength := MAX_CUT + 1
		var bestFrom := -1
		var bestDir := Vector2i.ZERO
		for i in cells:
			var from := Vector2i(i % W, i / W)
			for dir in DIRS4:
				for step in range(1, MAX_CUT + 2):
					var c: Vector2i = from + dir * step
					if not inMap(c): break
					var j := c.y * W + c.x
					if isBlocked(j):
						if flags[j] & RESERVED != 0: break
						continue
					var e := district[j]
					if step > 1 && e >= 0 && e != d && not neighbors[d].has(e) && step - 1 < bestLength:
						bestLength = step - 1
						bestFrom = i
						bestDir = dir
					break
		if bestFrom < 0: continue
		var from := Vector2i(bestFrom % W, bestFrom / W)
		var target := district[(from + bestDir * (bestLength + 1)).y * W + (from + bestDir * (bestLength + 1)).x]
		for step in range(1, bestLength + 1):
			var c := from + bestDir * step
			var j := c.y * W + c.x
			openCell(j, CROSS_X if bestDir.x != 0 else CROSS_Y)
			district[j] = d
		neighbors[d][target] = true
		neighbors[target][d] = true

## The district table: id, cell count, centroid (px), seed cell, neighbor ids, whether it is reachable
func districtTable() -> Array:
	var neighbors := districtNeighbors()
	var sums: Array = []
	for d in districtCount: sums.push_back([0, Vector2.ZERO, -1, false])
	for i in W * H:
		var d := district[i]
		if d < 0: continue
		var entry: Array = sums[d]
		entry[0] += 1
		entry[1] += cellCenter(Vector2i(i % W, i / W))
		if entry[2] < 0: entry[2] = i
		if flags[i] & START != 0: entry[3] = true
	var table: Array = []
	for d in districtCount:
		var entry: Array = sums[d]
		var ids := PackedInt32Array(neighbors[d].keys())
		ids.sort()
		var centroid: Vector2 = entry[1] / maxf(entry[0], 1.0)
		table.push_back({"id": d, "cells": entry[0], "centroid": centroid,
			"firstCell": entry[2], "neighbors": ids, "inStart": entry[3], "landmark": landmarkCell(d, centroid)})
	return table

## Where a district's landmark stands: the center of the open cell nearest its centroid (in the district,
## not reserved, all eight neighbors passable, so it never narrows a way through), searched in growing
## squares; INF when none is near enough. ChunkRecipe finds the exact spot round it.
func landmarkCell(d: int, centroid: Vector2) -> Vector2:
	var c := cellOf(centroid)
	for r in LANDMARK_SEARCH + 1:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var cell := c + Vector2i(dx, dy)
				if cell.x < 1 || cell.y < 1 || cell.x >= W - 1 || cell.y >= H - 1: continue
				var i := cell.y * W + cell.x
				if district[i] != d || flags[i] & (BLOCKED | RESERVED) != 0: continue
				var open := true
				for n in DIRS8:
					if flags[i + n.y * W + n.x] & BLOCKED != 0:
						open = false
						break
				if open: return cellCenter(cell)
	return Vector2.INF

#--- routing -----------------------------------------------------------------------------------------

## An AStarGrid2D over the coarse map: blocked cells solid, others weighted by the terrain's route weight
static func makeAStar(terrainArray: PackedByteArray, flagArray: PackedByteArray, routeWeights: PackedFloat32Array) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, W, H)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = ORIGIN + Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES #never cut a barrier's corner
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for i in W * H:
		var c := Vector2i(i % W, i / W)
		if flagArray[i] & BLOCKED != 0: grid.set_point_solid(c)
		else:
			var t := terrainArray[i]
			var weight := routeWeights[t] if t < routeWeights.size() else 1.0
			if weight > 0.0 && weight != 1.0: grid.set_point_weight_scale(c, weight)
	return grid

## The A* route from a to b on the coarse map: {points (a, the cell centers between, b), length (px),
## reached}. A start inside a blocked cell still gets a way out. Never shorter than a.distance_to(b).
static func routeBetween(grid: AStarGrid2D, a: Vector2, b: Vector2) -> Dictionary:
	var ca := cellOf(a)
	var cb := cellOf(b)
	var points := PackedVector2Array()
	if not grid.is_in_boundsv(ca) || not grid.is_in_boundsv(cb): return {"points": points, "length": a.distance_to(b), "reached": false}
	var startSolid := grid.is_point_solid(ca)
	if startSolid: grid.set_point_solid(ca, false)
	var ids := grid.get_id_path(ca, cb, true)
	if startSolid: grid.set_point_solid(ca, true)
	points.push_back(a)
	for id in ids: points.push_back(cellCenter(id))
	var reached := not ids.is_empty() && ids[ids.size() - 1] == cb
	if reached: points.push_back(b)
	var length := 0.0
	for k in range(1, points.size()): length += points[k - 1].distance_to(points[k])
	return {"points": points, "length": maxf(length, a.distance_to(b)), "reached": reached}

#--- fine raster -------------------------------------------------------------------------------------

## Job keys: chunk (Vector2i), seed, def (as for buildCoarse), terrain and flags (the coarse map's arrays,
## read only). Writes job.result: chunk, terrain (FINE_W x FINE_H terrain ids), water and wall (FIELD_W x
## FIELD_H signed fields at the fine cell centers, apron included: negative inside deep water / a wall;
## the water under a bridge stays negative), usec.
static func fineRaster(job: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var chunk: Vector2i = job.chunk
	var f := WorldField.make(int(job.seed), job.def)
	var coarseTerrain: PackedByteArray = job.terrain
	var coarseFlags: PackedByteArray = job.flags
	var origin := Vector2(chunk) * CHUNK_PX
	var water := PackedFloat32Array()
	var wall := PackedFloat32Array()
	var out := PackedByteArray()
	water.resize(FIELD_W * FIELD_H)
	wall.resize(FIELD_W * FIELD_H)
	out.resize(FINE_W * FINE_H)
	#the coarse cells round the chunk (LOCAL_W x LOCAL_H from cell lo): +1 open, -1 blocked, per field
	var lo := cellOf(origin) - Vector2i(1, 1)
	var signW := PackedFloat32Array()
	var signH := PackedFloat32Array()
	var fillW := PackedFloat32Array()
	var fillH := PackedFloat32Array()
	var kind := PackedByteArray() #0 open, 1 water, 2 wall
	signW.resize(LOCAL_W * LOCAL_H)
	signH.resize(LOCAL_W * LOCAL_H)
	fillW.resize(LOCAL_W * LOCAL_H)
	fillH.resize(LOCAL_W * LOCAL_H)
	kind.resize(LOCAL_W * LOCAL_H)
	var special := false #a crossing or a filled pocket nearby: the slow path
	for ly in LOCAL_H:
		for lx in LOCAL_W:
			var l := ly * LOCAL_W + lx
			var c := lo + Vector2i(lx, ly)
			signW[l] = 1.0
			signH[l] = 1.0
			fillW[l] = 1.0
			fillH[l] = 1.0
			kind[l] = 0
			if not inMap(c):
				signW[l] = -1.0
				kind[l] = 1
				continue
			var idx := c.y * W + c.x
			var fl := coarseFlags[idx]
			if fl & (CROSSING | FILL) != 0: special = true
			if fl & BLOCKED == 0: continue
			var isWater := coarseTerrain[idx] == WATER
			kind[l] = 1 if isWater else 2
			if isWater: signW[l] = -1.0
			else: signH[l] = -1.0
			if fl & FILL != 0:
				if isWater: fillW[l] = -1.0
				else: fillH[l] = -1.0
	var wallT := f.wallTerrain
	var shallowsOn := f.shallows
	var wadeDrop := WADE_DEPTH if f.wade else 0.0
	var steep := WADE_STEEP if f.wade else 1.0 #water pillars and filled pockets: the same edge and shallows, deep sooner
	var slots := {} #coarse index -> whether that pass is a slot canyon (isSlot, cached for the samples)
	var seedValue := int(job.seed)
	var meadowTracks := f.grammar == WorldField.Grammar.MEADOW
	var tracks := PackedByteArray() #meadow: 1 where a fine cell is on a dirt track (WorldField.onTrack)
	if meadowTracks:
		tracks.resize(FINE_W * FINE_H)
		tracks.fill(0)
	#what depends only on the column, worked out once (the same doubles the loop used to compute per cell)
	var colX := PackedFloat64Array()
	var colTx := PackedFloat64Array()
	var colAx := PackedFloat64Array() #1 - tx
	var colL := PackedInt32Array()    #i0 - lo.x
	var colOwn := PackedInt32Array()  #the nearest coarse center's x
	for i in FIELD_W:
		var x := origin.x + (i - 0.5) * FINE
		var u := (x - ORIGIN.x) / CELL - 0.5
		var i0 := floori(u)
		var tx := u - i0
		colX.push_back(x)
		colTx.push_back(tx)
		colAx.push_back(1.0 - tx)
		colL.push_back(i0 - lo.x)
		colOwn.push_back(floori(u + 0.5))
	for j in FIELD_H:
		var y := origin.y + (j - 0.5) * FINE
		var w := (y - ORIGIN.y) / CELL - 0.5
		var j0 := floori(w)
		var ty := w - j0
		var ay := 1.0 - ty
		var rowL := (j0 - lo.y) * LOCAL_W
		var ownY := floori(w + 0.5)
		var rowOwn := (ownY - lo.y) * LOCAL_W - lo.x
		for i in FIELD_W:
			var x := colX[i]
			var tx := colTx[i]
			var ax := colAx[i]
			var l := rowL + colL[i]
			var w00 := ax * ay
			var w10 := tx * ay
			var w01 := ax * ty
			var w11 := tx * ty
			var cw := signW[l] * w00 + signW[l + 1] * w10 + signW[l + LOCAL_W] * w01 + signW[l + LOCAL_W + 1] * w11
			var ch := signH[l] * w00 + signH[l + 1] * w10 + signH[l + LOCAL_W] * w01 + signH[l + LOCAL_W + 1] * w11
			var v := f.sample(x, y)
			var waterField := maxf(v.x, cw - A_LO)
			var wallField := maxf(v.y, ch - A_LO)
			var t := int(v.z)
			#the nearest center: a blocked cell is always blocked round its center
			var ownX := colOwn[i]
			var ownKind := kind[rowOwn + ownX]
			if ownKind != 0:
				var oc := cellCenter(Vector2i(ownX, ownY))
				var pillar := -0.5 + sqrt((x - oc.x) * (x - oc.x) + (y - oc.y) * (y - oc.y)) / (PILLAR_PX * 2.0)
				if ownKind == 1: waterField = minf(waterField, minf(pillar, pillar * steep))
				else: wallField = minf(wallField, pillar)
			var bridge := false
			var ford := false
			var inPass := false
			if special:
				var fw := fillW[l] * w00 + fillW[l + 1] * w10 + fillW[l + LOCAL_W] * w01 + fillW[l + LOCAL_W + 1] * w11
				var fh := fillH[l] * w00 + fillH[l + 1] * w10 + fillH[l + LOCAL_W] * w01 + fillH[l + LOCAL_W + 1] * w11
				waterField = minf(waterField, minf(fw + 0.7, (fw + 0.7) * steep))
				wallField = minf(wallField, fh + 0.7)
				#crossings in this cell or a 4-neighbor open their full width
				var own := Vector2i(ownX, ownY)
				for k in 5:
					var cell: Vector2i = own + SELF_AND_DIRS4[k]
					if not inMap(cell): continue
					var idx := cell.y * W + cell.x
					var fl := coarseFlags[idx]
					if fl & CROSSING == 0: continue
					var c := cellCenter(cell)
					var along := absf(x - c.x) if fl & CROSS_X != 0 else absf(y - c.y)
					var across := absf(y - c.y) if fl & CROSS_X != 0 else absf(x - c.x)
					if along >= CELL: continue
					match coarseTerrain[idx]:
						SHALLOWS:
							if across < f.fordHalf:
								ford = true
								waterField = maxf(waterField, 0.05)
						BRIDGE:
							if across < f.bridgeHalf: bridge = true
						_:
							var slot: bool = slots[idx] if slots.has(idx) else isSlot(seedValue, coarseFlags, idx, f.slotShare)
							slots[idx] = slot
							if slot:
								#a slot canyon: the natural wall stands right up to slotHalf of the way through,
								#closer than the coarse envelope's corridor would leave it
								wallField = minf(wallField, maxf(v.y, (f.slotHalf - across) / WorldField.UNIT))
								if across < f.slotHalf: inPass = true
							elif across < f.passHalf:
								wallField = maxf(wallField, 0.45)
								inPass = true
			#a pass is driven ground: Frostbite's deep snow and ice there stuck heavy cars
			if inPass && (t == WorldField.DEEPSNOW || t == WorldField.ICE): t = WorldField.SNOW
			if wallField < 0.0: t = wallT
			elif bridge && v.x < BAND: t = BRIDGE
			elif waterField < -wadeDrop: t = WATER
			elif waterField < 0.0: t = WADE
			elif (ford || shallowsOn) && waterField < BAND: t = SHALLOWS
			if bridge && v.x < 0.0: waterField = v.x #the water under the deck, for the art
			water[j * FIELD_W + i] = waterField
			wall[j * FIELD_W + i] = wallField
			if i >= 1 && i <= FINE_W && j >= 1 && j <= FINE_H:
				out[(j - 1) * FINE_W + i - 1] = t
				if meadowTracks && f.onTrack && t == WorldField.DIRT: tracks[(j - 1) * FINE_W + i - 1] = 1
	job.result = {"chunk": chunk, "terrain": out, "water": water, "wall": wall, "crossings": crossingRuns(coarseFlags, coarseTerrain, lo, seedValue, f.slotShare) if special else [],
		"tracks": tracks, "usec": Time.get_ticks_usec() - t0}

## The crossings round a chunk (its raster's LOCAL_W x LOCAL_H coarse cells from `lo`), one entry per crossing
## (cells grouped by crossingRoot): {center (world px, the mean of its cells there), axis (the way through:
## RIGHT or DOWN), kind ("ford", "bridge" or "pass"), slot (a slot canyon), cells}. The recipe anchors heroes
## to them (fords, passes) and lays a coin line through a slot.
static func crossingRuns(coarseFlags: PackedByteArray, coarseTerrain: PackedByteArray, lo: Vector2i, mapSeed: int, slotShare: float) -> Array:
	var runs := {}
	for ly in LOCAL_H:
		for lx in LOCAL_W:
			var c := lo + Vector2i(lx, ly)
			if not inMap(c): continue
			var idx := c.y * W + c.x
			var fl := coarseFlags[idx]
			if fl & CROSSING == 0 || fl & BLOCKED != 0: continue
			var root := crossingRoot(coarseFlags, idx)
			var run: Dictionary = runs.get(root, {})
			if run.is_empty():
				var t := coarseTerrain[idx]
				var kind := "ford" if t == SHALLOWS else ("bridge" if t == BRIDGE else "pass")
				run = {"center": Vector2.ZERO, "axis": Vector2.RIGHT if fl & CROSS_X != 0 else Vector2.DOWN, "kind": kind,
					"slot": kind == "pass" && isSlot(mapSeed, coarseFlags, idx, slotShare), "cells": 0}
				runs[root] = run
			run.center += cellCenter(c)
			run.cells += 1
	var out: Array = []
	for root in runs:
		var run: Dictionary = runs[root]
		run.center /= float(run.cells)
		out.push_back(run)
	return out

#--- debug -------------------------------------------------------------------------------------------

## The coarse map as text: one character per cell from the terrain table's letters ('+' a pass, '#'
## nothing reachable), `marks` (Vector2i cell -> one character) on top. Main thread (reads World).
static func ascii(result: Dictionary, center: Vector2i, w: int, h: int, marks := {}) -> PackedStringArray:
	var lines := PackedStringArray()
	var terrainArray: PackedByteArray = result.terrain
	var flagArray: PackedByteArray = result.flags
	for cy in range(center.y - h / 2, center.y - h / 2 + h):
		var line := ""
		for cx in range(center.x - w / 2, center.x - w / 2 + w):
			var c := Vector2i(cx, cy)
			if marks.has(c):
				line += marks[c]
				continue
			if not inMap(c):
				line += " "
				continue
			var i := cy * W + cx
			var fl := flagArray[i]
			if fl & CROSSING != 0 && fl & BLOCKED == 0 && terrainArray[i] != SHALLOWS && terrainArray[i] != BRIDGE: line += "+"
			else: line += World.letter(terrainArray[i])
		lines.push_back(line)
	return lines
