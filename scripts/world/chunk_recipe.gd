class_name ChunkRecipe extends RefCounted
## What one chunk of the run's world is made of (docs/WORLD.md, "Chunk recipe"). Built on a worker thread
## right after the chunk's fine raster (WorldMap.chunkTask), cached with it, and applied on the main thread by
## ChunkView. Pure and worker-safe: it touches only its job Dictionary (no nodes, no autoloads, no global
## RNG; every random stream is WorldGen.ihash of the world seed, a tag and the chunk), so the same input
## always gives the same recipe.
##
## Job keys (besides the raster's, see WorldGen.fineRaster): ctx (WorldSkin.recipeContext: the level's
## tables, made once on the main thread and only read here), zones (PackedInt32Array: the district
## zone of the chunk's 8 coarse cells, Territories.zoneFor, -1 on a barrier), aux (the coarse aux bytes: belt directions),
## tints (PackedByteArray: the district tint code, 0-15, of the 8 coarse cells), landmarks (Array of [prop
## id, world position]: the districts' landmarks that stand in this chunk; WorldMap.landmarks).
## Writes job.recipe, a Dictionary in chunk-local px (the chunk's top-left corner is 0, 0):
##   control:  PackedByteArray, 42 x 22 RGBA8 (the chunk's 40 x 20 fine cells plus a one-cell apron) for the
##             ground shader: R the material layer of the cell's surface (water and wall cells take a
##             neighbour's surface), G the water field and B the wall field (FIELD_RANGE units either way of
##             0.5, linear), A flags (FLAG_*, low 4 bits) and the district's tint code (high 4 bits, job.tints)
##   pieces:   Array of convex PackedVector2Array: the walls' collision (one StaticBody2D)
##   occluders: Array of open PackedVector2Array polylines along the walls, solid on the right (cull_mode 2)
##   lines:    Array of [strip index (ctx.strips), PackedVector2Array]: the shore foam and wall lips for
##             Line2D, barrier on the left, so the strip's top (v = 0) lies on it
##   decor:    {decor id: PackedFloat32Array}: a MultiMesh buffer (2D transform + custom data, 12 floats);
##             in the city also the rooftop dressing (ctx.roofDecor) on BUILDING cells
##   props:    Array of [id, pos, rotation, variant, bit (taken-set bit, -1 for none), occluder (bool), group
##             (int: the motif instance it belongs to, 0 for none; ChunkView sets it as metadata `group`), hero
##             (bool: placed by the hero pass; metadata `hero`)]; a district landmark first (it is placed before
##             anything else), then the Home Paddock and the heroes, so the node budget keeps them
##   fieldWalls: Array of convex PackedVector2Array: unbreakable field lines (Orchard Lanes' hedgerows), added
##             to the chunk's wall body by ChunkView; drawn as decor (ctx.fieldWalls' decor id in `decor`) with
##             their occluders among `occluders`
##   pickups:  Array of [pickup id (Pickups), pos, bit]
##   spots:    Array of Vector2: open places for PickupWorld.decorateChunk's props
##   counts:   {nodes, occluders, pieces, props, pickups, decor, lines, dropped, heroes, bits, fieldWalls}
##   usec:     build time

const CHUNK := Vector2(5120, 2560)
const FINE := 128.0
const FW := 40
const FH := 20
const RW := 42 #raster fields (with the apron)
const RH := 22
const GW := 44 #contour grids: the raster fields plus a ring of open ground, so every contour closes
const GH := 24
const FIELD_RANGE := 1.0 #field units (640 px) the control bytes span either way of 0.5

#budgets (spec section 7)
const MAX_NODES := 100     #world nodes per chunk (pickups counted apart)
const MAX_OCCLUDERS := 16
const MAX_PIECES := 48
const MAX_LINES := 24
const SPAN := 1280.0       #occluders and lines are cut so neither side of their box passes this
const SIMPLIFY: Array[float] = [16.0, 32.0, 64.0, 128.0]
const LINE_SIMPLIFY := 6.0
const MIN_PIECE_AREA := 64.0
const MIN_LOOP_AREA := 2500.0 #smaller wall blobs and holes are noise: blobs dropped, holes filled
const GROUND_NODES := 8    #ground quads per chunk

#placement
const START_CORE := 1200.0   #no prop or pickup this close to the start
const PROP_GAP := 150.0      #open ground between props, so a car can weave through
const PROP_MARGIN := 0.12    #field units (77 px) props keep from water and walls
const PICKUP_MARGIN := 0.2   #128 px
const COINS_PER_LINE := 7
const COIN_STEP := 130.0
const SPOT_CLEAR := 0.75     #field units (480 px) round a decorateChunk spot
const SPOTS := 3
const LANE_HALF := 450.0     #Defense lanes stay clear of props

#control flags (A)
const FLAG_BRIDGE := 1
const FLAG_ROTATE := 2
const FLAG_BELT := 4
const FLAG_REVERSE := 8

#hash tags
const TAG_RECIPE := 201
const TAG_PICKUP := 202
const TAG_PROP := 203
const TAG_DECOR := 204
const TAG_SPOT := 205
const TAG_ROOF := 206 #field lines 207-211, motifs 212 (below)

#terrain ids (Root.terrain, mirrored: worker code never touches the autoload)
const WATER := 3
const SHALLOWS := 11
const ASPHALT := 8
const OIL := 10
const DIRT := 6
const HILLS := 4
const CONVEYOR := 13
const MUDPIT := 14
const BRIDGE := 18
const BUILDING := 17

#rooftops (city): decor on BUILDING cells this far inside the roof's edge (field units), spaced, square to
#the street grid, at most ROOF_MAX a chunk
const ROOF_INSET := 0.3
const ROOF_GAP := 190.0
const ROOF_MAX := 48
const ROOF_TRIES := 6 #darts per interior roof cell
#landmarks: searched outward from the district's spot in rings of LANDMARK_STEP px
const LANDMARK_STEP := 128.0
const LANDMARK_RINGS := 8

var chunk := Vector2i.ZERO
var mapSeed := 0
var ctx := {}
var terrain := PackedByteArray()
var water := PackedFloat32Array()
var wall := PackedFloat32Array()
var zones := PackedInt32Array()
var tints := PackedByteArray()
var majority := 0
var rng := RandomNumberGenerator.new()
var resPos := PackedVector2Array() #centres and radii of everything placed so far (props, pickups, spots)
var resRad := PackedFloat64Array()
var origin := Vector2.ZERO
#read from ctx once per recipe (the hot placement loops would look them up thousands of times)
var startAt := Vector2.INF
var lotRects: Array = []
var laneSegs: Array = []
var spawnTable := PackedByteArray()
var blockedTable := PackedByteArray()
var lotTerrain := 16
var minWater := 0.0 #the lowest raster field values (controlBytes): no contour to trace when neither is below 0
var minWall := 0.0

static func build(job: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var r := ChunkRecipe.new()
	job.recipe = r.run(job)
	job.recipe.usec = Time.get_ticks_usec() - t0

func run(job: Dictionary) -> Dictionary:
	var raster: Dictionary = job.result
	chunk = job.chunk
	mapSeed = int(job.seed)
	ctx = job.ctx
	terrain = raster.terrain
	water = raster.water
	wall = raster.wall
	zones = job.get("zones", PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0]))
	tints = job.get("tints", PackedByteArray())
	origin = Vector2(chunk) * CHUNK
	var votes := {}
	for f in zones:
		if f >= 0: votes[f] = votes.get(f, 0) + 1
	majority = 0
	var best := -1
	for f in votes:
		if votes[f] > best:
			best = votes[f]
			majority = f
	rng.seed = WorldGen.ihash(mapSeed, TAG_RECIPE, chunk.x, chunk.y)
	startAt = ctx.get("start", Vector2.INF)
	lotRects = ctx.get("lots", [])
	laneSegs = ctx.get("lanes", [])
	spawnTable = ctx.spawnable
	blockedTable = ctx.blocked
	lotTerrain = ctx.get("lotTerrain", 16)
	crossRuns = raster.get("crossings", [])
	tracks = raster.get("tracks", PackedByteArray())
	bitProps = ctx.get("bitProps", {})
	heroBreakable = ctx.get("heroBreakable", {})

	var t := Time.get_ticks_usec()
	var phases := {}
	var out := {"control": controlBytes(job.get("aux", PackedByteArray()), job.get("coarseW", WorldGen.W))}
	t = lap(phases, "control", t)
	#walls: collision pieces, occluders and lips
	var wallGrid := PackedFloat32Array()
	var wallLoops: Array = []
	if minWall < 0.0:
		wallGrid = paddedGrid(wall)
		wallLoops = traceLoops(wallGrid, GW, GH, Vector2(-1.5, -1.5) * FINE, FINE)
	t = lap(phases, "trace", t)
	var walls := wallPieces(wallLoops)
	out.pieces = walls.pieces
	t = lap(phases, "pieces", t)
	var occluders := chains(wallLoops, SIMPLIFY[walls.level], wallGrid)
	occluders = splitSpan(occluders, SPAN)
	occluders.sort_custom(func(a, b): return polyLength(a) > polyLength(b))
	var dropped := 0
	while occluders.size() > MAX_OCCLUDERS:
		occluders.pop_back()
		dropped += 1
	out.occluders = occluders
	var lines: Array = []
	var wallStrip: int = ctx.get("wallStrip", -1)
	if wallStrip >= 0:
		for line in splitSpan(chains(wallLoops, LINE_SIMPLIFY, wallGrid), SPAN): lines.push_back([wallStrip, reversed(line)])
	#water: the shore foam (the shader draws the water itself from the field)
	var waterStrip: int = ctx.get("waterStrip", -1)
	if waterStrip >= 0 && minWater < 0.0:
		var waterGrid := paddedGrid(water)
		var waterLoops := traceLoops(waterGrid, GW, GH, Vector2(-1.5, -1.5) * FINE, FINE)
		for line in splitSpan(offBridges(chains(waterLoops, LINE_SIMPLIFY, waterGrid)), SPAN): lines.push_back([waterStrip, reversed(line)])
	lines.sort_custom(func(a, b): return polyLength(a[1]) > polyLength(b[1]))
	while lines.size() > MAX_LINES:
		lines.pop_back()
		dropped += 1
	out.lines = lines
	t = lap(phases, "lines", t)

	#things on the ground: decorateChunk's spots first, then pickups, then props, then decor
	resetReservations()
	var landmarks := placeLandmarks(job.get("landmarks", []))
	reservePaddock()
	#hedgerow walls are layout, like the terrain's: laid before the spots, pickups and props, which keep off them
	wallRoom = MAX_PIECES - out.pieces.size()
	breakBit = 32
	wallFrom = resPos.size()
	wallGates = placeFieldLines(true)
	out.spots = placeSpots()
	out.pickups = placePickups()
	t = lap(phases, "pickups", t)
	var props := landmarks + placeProps()
	out.fieldWalls = fieldWalls
	for occ in wallOccluders:
		if occluders.size() >= MAX_OCCLUDERS: break
		occluders.push_back(occ)
	t = lap(phases, "props", t)
	var decor := placeDecor()
	var roofs := placeRoofs()
	if roofs.count > 0:
		decor.buffers[roofs.id] = roofs.buffer
		decor.count += roofs.count
	if not wallDecor.is_empty():
		decor.buffers[wallDecorId] = wallDecor
		decor.count += wallDecor.size() / 12
	out.decor = decor.buffers
	t = lap(phases, "decor", t)

	#the node budget: ground quads, the body, occluders, lines, one MultiMesh per decor id, then props
	var fixed: int = GROUND_NODES + (1 if not out.pieces.is_empty() || not fieldWalls.is_empty() else 0) + occluders.size() + lines.size() + decor.buffers.size()
	var occluderRoom := MAX_OCCLUDERS - occluders.size()
	var nodes: int = fixed
	var kept: Array = []
	var heroesDropped := 0
	for p in props:
		var info: Dictionary = ctx.props[p[0]]
		var cost: int = info.nodes
		var occ: bool = info.occluder && occluderRoom > 0
		if info.occluder && not occ: cost -= 1 #placed without its occluder
		if nodes + cost > MAX_NODES:
			dropped += 1
			if p[7]: heroesDropped += 1
			continue
		if occ: occluderRoom -= 1
		nodes += cost
		p[5] = occ
		kept.push_back(p)
	out.props = kept
	var propOccluders := 0
	var heroes := 0
	for p in kept:
		if p[5]: propOccluders += 1
		if p[7]: heroes += 1
	out.counts = {"nodes": nodes, "occluders": occluders.size() + propOccluders, "pieces": out.pieces.size(),
		"props": kept.size(), "pickups": out.pickups.size(), "decor": decor.count, "lines": lines.size(),
		"dropped": dropped, "simplify": SIMPLIFY[walls.level], "heroes": heroes, "heroesDropped": heroesDropped,
		"bits": breakBit - 32, "fieldWalls": fieldWalls.size()}
	lap(phases, "rest", t)
	out.phases = phases
	return out

## Adds the usec since `since` to phases[key]; returns now
static func lap(phases: Dictionary, key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	phases[key] = phases.get(key, 0) + now - since
	return now

#--- control texture ---------------------------------------------------------------------------------

static func encodeField(f: float) -> int:
	return clampi(roundi((f / FIELD_RANGE * 0.5 + 0.5) * 255.0), 0, 255)

## The 42 x 22 RGBA8 control block (see the class comment)
func controlBytes(aux: PackedByteArray, coarseW: int) -> PackedByteArray:
	var blocked: PackedByteArray = ctx.blocked
	var layerOf: PackedByteArray = ctx.layerOf
	var mainLayer: int = ctx.get("mainLayer", 0)
	#surface ids over the apron: own cells, the apron copying the nearest own cell; water and wall cells
	#(-1 in layers) take a passable neighbour's surface below
	var surf := PackedInt32Array()
	surf.resize(RW * RH)
	var layers := PackedInt32Array()
	layers.resize(RW * RH)
	var open := PackedInt32Array() #the blocked cells still without a layer
	for j in RH:
		var row := clampi(j - 1, 0, FH - 1) * FW
		for i in RW:
			var k := j * RW + i
			var t: int = terrain[row + clampi(i - 1, 0, FW - 1)]
			surf[k] = t
			if blocked[t] != 0:
				layers[k] = -1
				open.push_back(k)
			else:
				layers[k] = layerOf[t]
	#a few dilation passes: each blocked cell takes the first of its +x, -x, +y, -y neighbours that had a layer
	#before the pass (the rest keep the main ground)
	for pass_ in 6:
		if open.is_empty(): break
		var still := PackedInt32Array()
		var setK := PackedInt32Array()
		var setV := PackedInt32Array()
		for k in open:
			var i := k % RW
			var v := -1
			if i + 1 < RW && layers[k + 1] >= 0: v = layers[k + 1]
			elif i > 0 && layers[k - 1] >= 0: v = layers[k - 1]
			elif k + RW < RW * RH && layers[k + RW] >= 0: v = layers[k + RW]
			elif k >= RW && layers[k - RW] >= 0: v = layers[k - RW]
			if v >= 0:
				setK.push_back(k)
				setV.push_back(v)
			else:
				still.push_back(k)
		if setK.is_empty(): break
		for n in setK.size(): layers[setK[n]] = setV[n]
		open = still
	var out := PackedByteArray()
	out.resize(RW * RH * 4)
	var cell0 := WorldGen.cellOf(origin)
	#each cell's district tint (the coarse cell's; the apron takes its nearest own cell's), as the flags' high bits
	var tintBits := PackedInt32Array()
	tintBits.resize(RW * RH)
	if tints.size() == 8:
		for j in RH:
			var cy := 0 if j <= FH / 2 else 1
			for i in RW:
				var cx := clampi(floori((clampi(i - 1, 0, FW - 1) * FINE) / WorldGen.CELL), 0, 3)
				tintBits[j * RW + i] = (tints[cy * 4 + cx] & 15) << 4
	else:
		tintBits.fill(8 << 4)
	var k4 := 0
	minWater = water[0]
	minWall = wall[0]
	for k in RW * RH:
		var t := surf[k]
		var flags := 0
		if t == BRIDGE || t == CONVEYOR:
			var i := k % RW
			var j := k / RW
			if t == BRIDGE:
				flags |= FLAG_BRIDGE
				if runLength(surf, i, j, Vector2i(0, 1)) > runLength(surf, i, j, Vector2i(1, 0)): flags |= FLAG_ROTATE
			else:
				flags |= FLAG_BELT
				var cx := clampi(floori(((i - 0.5) * FINE) / WorldGen.CELL), 0, 3) + cell0.x
				var cy := clampi(floori(((j - 0.5) * FINE) / WorldGen.CELL), 0, 1) + cell0.y
				var code := 1
				if not aux.is_empty() && cx >= 0 && cy >= 0 && cx < coarseW && cy * coarseW + cx < aux.size(): code = aux[cy * coarseW + cx]
				if code == 3 || code == 4: flags |= FLAG_ROTATE
				if code == 2 || code == 4: flags |= FLAG_REVERSE
		var layer := layers[k]
		out[k4] = layer if layer >= 0 else mainLayer
		#encodeField, inlined (FIELD_RANGE is 1)
		var fw := water[k]
		var fh := wall[k]
		if fw < minWater: minWater = fw
		if fh < minWall: minWall = fh
		out[k4 + 1] = clampi(roundi((fw * 0.5 + 0.5) * 255.0), 0, 255)
		out[k4 + 2] = clampi(roundi((fh * 0.5 + 0.5) * 255.0), 0, 255)
		out[k4 + 3] = flags | tintBits[k]
		k4 += 4
	return out

static func runLength(surf: PackedInt32Array, i: int, j: int, d: Vector2i) -> int:
	var n := 1
	for s in [1, -1]:
		var x: int = i + d.x * s
		var y: int = j + d.y * s
		while x >= 0 && y >= 0 && x < RW && y < RH && surf[y * RW + x] == BRIDGE:
			n += 1
			x += d.x * s
			y += d.y * s
	return n

#--- contours --------------------------------------------------------------------------------------

## A raster field (RW x RH) with a ring of open ground round it (GW x GH): every contour closes outside the chunk
static func paddedGrid(field: PackedFloat32Array) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(GW * GH)
	g.fill(1.0)
	for j in RH:
		for i in RW:
			g[(j + 1) * GW + i + 1] = field[j * RW + i]
	return g

## Bilinear value of a GW x GH grid at a chunk-local point (grid point (i, j) sits at (i - 1.5, j - 1.5) * FINE)
static func gridAt(g: PackedFloat32Array, p: Vector2) -> float:
	var u := p.x / FINE + 1.5
	var v := p.y / FINE + 1.5
	var i0 := clampi(floori(u), 0, GW - 2)
	var j0 := clampi(floori(v), 0, GH - 2)
	var fx := clampf(u - i0, 0.0, 1.0)
	var fy := clampf(v - j0, 0.0, 1.0)
	var k := j0 * GW + i0
	return lerpf(lerpf(g[k], g[k + 1], fx), lerpf(g[k + GW], g[k + GW + 1], fx), fy)

## Closed contour loops of {value < 0} over a gw x gh grid whose point (i, j) is at at0 + (i, j) * step, by
## marching squares (saddles resolved by the square's mean). Each loop has the inside on its right (screen
## coordinates, y down): outer boundaries run clockwise on screen (positive shoelace), holes the other way.
static func traceLoops(v: PackedFloat32Array, gw: int, gh: int, at0: Vector2, step: float) -> Array:
	var pts := {}
	var nxt := {}
	for j in gh - 1:
		#a sliding window along the row: the square's right corners become the next one's left corners
		var top := j * gw
		var bottom := top + gw
		var b := v[top]
		var c := v[bottom]
		var right := (1 if b < 0.0 else 0) | (2 if c < 0.0 else 0) #b below 0: bit 1, c: bit 2 (as a, d next)
		for i in gw - 1:
			var a := b
			var d := c
			var left := right
			b = v[top + i + 1]
			c = v[bottom + i + 1]
			right = (1 if b < 0.0 else 0) | (2 if c < 0.0 else 0)
			var code := (left & 1) | (right & 1) << 1 | (right & 2) << 1 | (left & 2) << 2
			if code == 0 || code == 15: continue
			#edges: 0 top, 1 right, 2 bottom, 3 left
			var segs: Array = []
			if code == 5 || code == 10:
				var centreIn := (a + b + c + d) * 0.25 < 0.0
				if (code == 5) == centreIn: segs = [[0, 1], [2, 3]]
				else: segs = [[0, 3], [1, 2]]
			else:
				var crossed: Array = []
				if (code & 1 != 0) != (code & 2 != 0): crossed.push_back(0)
				if (code & 2 != 0) != (code & 4 != 0): crossed.push_back(1)
				if (code & 8 != 0) != (code & 4 != 0): crossed.push_back(2)
				if (code & 1 != 0) != (code & 8 != 0): crossed.push_back(3)
				segs = [crossed]
			var corners := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			var values := [a, b, c, d]
			for seg in segs:
				var ids: Array = []
				var ps: Array = []
				for e in seg:
					var id := 0
					var p := Vector2.ZERO
					match e:
						0:
							id = (j * gw + i) * 2
							p = Vector2(i + a / (a - b), j)
						1:
							id = (j * gw + i + 1) * 2 + 1
							p = Vector2(i + 1, j + b / (b - c))
						2:
							id = ((j + 1) * gw + i) * 2
							p = Vector2(i + d / (d - c), j + 1)
						_:
							id = (j * gw + i) * 2 + 1
							p = Vector2(i, j + a / (a - d))
					ids.push_back(id)
					ps.push_back(p)
				#orient: the inside on the right (cross > 0 on screen). A segment between adjacent edges cuts off
				#their shared corner, which decides (in a saddle the far side is mixed); between opposite edges
				#every corner on a side agrees, so the one furthest from the segment decides.
				var dir: Vector2 = ps[1] - ps[0]
				var bestCross := 0.0
				var bestInside := false
				var e0: int = seg[0]
				var e1: int = seg[1]
				if (e0 + e1) % 2 == 1:
					var k: int = 0 if (e0 == 3 || e1 == 3) && (e0 == 0 || e1 == 0) else maxi(e0, e1)
					bestCross = dir.cross(corners[k] - ps[0])
					bestInside = values[k] < 0.0
				else:
					for k in 4:
						var cr := dir.cross(corners[k] - ps[0])
						if absf(cr) > absf(bestCross):
							bestCross = cr
							bestInside = values[k] < 0.0
				var from: int = ids[0]
				var to: int = ids[1]
				var pf: Vector2 = ps[0]
				var pt: Vector2 = ps[1]
				if (bestCross > 0.0) != bestInside:
					from = ids[1]
					to = ids[0]
					pf = ps[1]
					pt = ps[0]
				pts[from] = at0 + pf * step
				pts[to] = at0 + pt * step
				nxt[from] = to
	var loops: Array = []
	var seen := {}
	for start in nxt:
		if seen.has(start): continue
		var loop := PackedVector2Array()
		var id = start
		while id != null && not seen.has(id):
			seen[id] = true
			var p: Vector2 = pts[id]
			if loop.is_empty() || loop[loop.size() - 1].distance_squared_to(p) > 0.01: loop.push_back(p)
			id = nxt.get(id)
		if loop.size() >= 3: loops.push_back(loop)
	return loops

## Shoelace sum (screen coordinates): positive for loops running clockwise on screen
static func signedArea(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5

static func polyLength(poly: PackedVector2Array) -> float:
	var s := 0.0
	for k in range(1, poly.size()): s += poly[k - 1].distance_to(poly[k])
	return s

static func reversed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.reverse()
	return out

static func rectPoly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

static func onRectEdge(p: Vector2, r: Rect2) -> bool:
	return absf(p.x - r.position.x) < 0.01 || absf(p.x - r.end.x) < 0.01 || absf(p.y - r.position.y) < 0.01 || absf(p.y - r.end.y) < 0.01

#--- walls -----------------------------------------------------------------------------------------

## The walls' solid region inside the chunk as convex pieces: outer loops clipped to the chunk, holes cut out,
## simplified (Douglas-Peucker, the points on the chunk's edge kept so neighbours meet), decomposed. The
## simplification grows until the pieces fit MAX_PIECES. {pieces, level (index into SIMPLIFY)}
func wallPieces(loops: Array) -> Dictionary:
	var rect := Rect2(Vector2.ZERO, CHUNK)
	var regions := solidRegions(loops, rect)
	var pieces: Array = []
	var level := 0
	for l in SIMPLIFY.size():
		level = l
		pieces = []
		for region in regions:
			#Douglas-Peucker moves the outline by at most eps; losing more than that means it broke the polygon
			var lowest := absf(signedArea(region)) - polyLength(region) * SIMPLIFY[l] * 0.6
			var got := sanePieces(simplifyRing(region, SIMPLIFY[l], rect), rect)
			if piecesArea(got) < lowest: got = sanePieces(region, rect) #the exact outline instead
			pieces.append_array(got)
		if pieces.size() <= MAX_PIECES: break
	return {"pieces": pieces, "level": level}

## Convex pieces of a polygon that simplification may have made self-touching: Clipper redraws it as simple
## polygons first (clipped to the chunk grown by a px, which changes nothing else)
static func sanePieces(poly: PackedVector2Array, rect: Rect2) -> Array:
	var out: Array = []
	if poly.size() < 3: return out
	for part in Geometry2D.intersect_polygons(poly, rectPoly(rect.grow(1.0))):
		if not Geometry2D.is_polygon_clockwise(part): out.append_array(convexPieces(part))
	return out

static func piecesArea(pieces: Array) -> float:
	var s := 0.0
	for p in pieces: s += absf(signedArea(p))
	return s

static func solidRegions(loops: Array, rect: Rect2) -> Array:
	var outers: Array = []
	var holes: Array = []
	for loop in loops:
		var a := signedArea(loop)
		if absf(a) < MIN_LOOP_AREA: continue
		if a > 0.0: outers.push_back(loop)
		else: holes.push_back(loop)
	var box := rectPoly(rect)
	var out: Array = []
	for o in outers:
		for piece in Geometry2D.intersect_polygons(o, box):
			if not Geometry2D.is_polygon_clockwise(piece) && absf(signedArea(piece)) >= MIN_PIECE_AREA: out.push_back(piece)
	for h in holes:
		var next: Array = []
		for p in out: next.append_array(subtractHole(p, h, 0))
		out = next
	return out

## A polygon minus a hole loop. Godot can't return a polygon with a hole, so a hole that lies inside is cut
## out by splitting the polygon through it first.
static func subtractHole(p: PackedVector2Array, hole: PackedVector2Array, depth: int) -> Array:
	var res := Geometry2D.clip_polygons(p, hole)
	var holed := false
	for r in res:
		if Geometry2D.is_polygon_clockwise(r): holed = true
	var out: Array = []
	if not holed:
		for r in res:
			if absf(signedArea(r)) >= MIN_PIECE_AREA: out.push_back(r)
		return out
	if depth >= 3: return [p] #give up: the hole is filled
	var box := bounds(p)
	var hb := bounds(hole)
	var cut := hb.get_center().x
	var halves := [Rect2(box.position - Vector2.ONE, Vector2(cut - box.position.x + 1.0, box.size.y + 2.0)),
		Rect2(Vector2(cut, box.position.y - 1.0), Vector2(box.end.x - cut + 1.0, box.size.y + 2.0))]
	for half in halves:
		for q in Geometry2D.intersect_polygons(p, rectPoly(half)):
			if Geometry2D.is_polygon_clockwise(q) || absf(signedArea(q)) < MIN_PIECE_AREA: continue
			out.append_array(subtractHole(q, hole, depth + 1))
	return out

static func bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly: r = r.expand(p)
	return r

## Convex pieces of a simple polygon; a polygon Godot can't decompose (self-touching after simplification)
## falls back to triangles
static func convexPieces(poly: PackedVector2Array) -> Array:
	var out: Array = []
	poly = cleanRing(poly)
	if poly.size() < 3 || absf(signedArea(poly)) < MIN_PIECE_AREA: return out
	var parts: Array = Geometry2D.decompose_polygon_in_convex(poly) if isSimple(poly) else []
	if parts.is_empty():
		var tri := Geometry2D.triangulate_polygon(poly)
		for k in range(0, tri.size(), 3):
			parts.push_back(PackedVector2Array([poly[tri[k]], poly[tri[k + 1]], poly[tri[k + 2]]]))
	for part in parts:
		if part.size() >= 3 && absf(signedArea(part)) >= MIN_PIECE_AREA: out.push_back(part)
	return out

## Drops repeated and collinear points
static func cleanRing(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for k in n:
		var p := poly[k]
		if not out.is_empty() && out[out.size() - 1].distance_squared_to(p) < 1.0: continue
		out.push_back(p)
	if out.size() > 1 && out[0].distance_squared_to(out[out.size() - 1]) < 1.0: out.remove_at(out.size() - 1)
	var changed := true
	while changed && out.size() > 3:
		changed = false
		for k in out.size():
			var a := out[(k + out.size() - 1) % out.size()]
			var b := out[k]
			var c := out[(k + 1) % out.size()]
			if absf((b - a).cross(c - b)) < 0.5:
				out.remove_at(k)
				changed = true
				break
	return out

## No two non-adjacent edges cross (O(n^2); rings here are short)
static func isSimple(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 && j == n - 1: continue
			if Geometry2D.segment_intersects_segment(a, b, poly[j], poly[(j + 1) % n]) != null: return false
	return true

## Douglas-Peucker on a closed ring, keeping every point on the rect's edge (so the pieces of neighbouring
## chunks meet exactly where their contours cross the shared edge)
static func simplifyRing(poly: PackedVector2Array, eps: float, rect: Rect2) -> PackedVector2Array:
	var n := poly.size()
	if n <= 4: return poly
	var anchors: Array[int] = []
	for k in n:
		if onRectEdge(poly[k], rect): anchors.push_back(k)
	if anchors.size() < 2:
		var far := 0
		for k in n:
			if poly[k].distance_squared_to(poly[0]) > poly[far].distance_squared_to(poly[0]): far = k
		anchors.clear()
		anchors.push_back(0)
		anchors.push_back(far if far != 0 else n / 2)
	var out := PackedVector2Array()
	for a in anchors.size():
		var from := anchors[a]
		var to := anchors[(a + 1) % anchors.size()]
		var chain := PackedVector2Array()
		var k := from
		while true:
			chain.push_back(poly[k])
			if k == to: break
			k = (k + 1) % n
		var simple := dpOpen(chain, eps)
		for s in simple.size() - 1: out.push_back(simple[s])
	return out

## Douglas-Peucker on an open polyline (both ends kept)
static func dpOpen(chain: PackedVector2Array, eps: float) -> PackedVector2Array:
	var n := chain.size()
	if n <= 2: return chain
	var keep := PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	keep[0] = 1
	keep[n - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, n - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var a := chain[span.x]
		var b := chain[span.y]
		var best := -1.0
		var bestK := -1
		for k in range(span.x + 1, span.y):
			var d := Geometry2D.get_closest_point_to_segment(chain[k], a, b).distance_to(chain[k])
			if d > best:
				best = d
				bestK = k
		if bestK >= 0 && best > eps:
			keep[bestK] = 1
			stack.push_back(Vector2i(span.x, bestK))
			stack.push_back(Vector2i(bestK, span.y))
	var out := PackedVector2Array()
	for k in n:
		if keep[k] != 0: out.push_back(chain[k])
	return out

## The contour loops as open polylines inside the chunk (the parts outside it dropped), simplified, each with
## the inside (value < 0 in grid) on its right
static func chains(loops: Array, eps: float, grid: PackedFloat32Array) -> Array:
	var box := rectPoly(Rect2(Vector2.ZERO, CHUNK))
	var out: Array = []
	for loop in loops:
		if absf(signedArea(loop)) < MIN_LOOP_AREA: continue
		var closed: PackedVector2Array = loop.duplicate()
		closed.push_back(loop[0])
		for part in Geometry2D.intersect_polyline_with_polygon(closed, box):
			if part.size() < 2 || polyLength(part) < 24.0: continue
			var simple := dpOpen(part, eps)
			#Godot may hand an open path back reversed: keep the inside on the right
			var a := simple[0]
			var b := simple[1]
			var side := (a + b) * 0.5 + (b - a).normalized().orthogonal() * -12.0 #12 px to the right on screen
			if gridAt(grid, side) > 0.0: simple.reverse()
			out.push_back(simple)
	return out

## Polylines cut so that neither side of each piece's box passes `span` (consecutive pieces share a point)
static func splitSpan(lines: Array, span: float) -> Array:
	var out: Array = []
	for line in lines:
		var piece := PackedVector2Array([line[0]])
		var box := Rect2(line[0], Vector2.ZERO)
		for k in range(1, line.size()):
			var p: Vector2 = line[k]
			var grown := box.expand(p)
			if (grown.size.x > span || grown.size.y > span) && piece.size() >= 2:
				out.push_back(piece)
				var last: Vector2 = line[k - 1]
				piece = PackedVector2Array([last])
				box = Rect2(last, Vector2.ZERO).expand(p)
			else:
				box = grown
			#a single segment longer than the span is cut in pieces
			var from := piece[piece.size() - 1]
			var len := from.distance_to(p)
			if len > span:
				var steps := ceili(len / span)
				for s in range(1, steps):
					var q := from.lerp(p, float(s) / steps)
					piece.push_back(q)
					out.push_back(piece)
					piece = PackedVector2Array([q])
				box = Rect2(piece[0], Vector2.ZERO).expand(p)
			piece.push_back(p)
		if piece.size() >= 2: out.push_back(piece)
	return out

## Shore lines broken where they pass over a bridge deck
func offBridges(lines: Array) -> Array:
	var out: Array = []
	for line in lines:
		var piece := PackedVector2Array()
		for p in line:
			if terrainAt(p) == BRIDGE:
				if piece.size() >= 2: out.push_back(piece)
				piece = PackedVector2Array()
			else:
				piece.push_back(p)
		if piece.size() >= 2: out.push_back(piece)
	return out

#--- placement -------------------------------------------------------------------------------------

func terrainAt(p: Vector2) -> int:
	return terrain[clampi(floori(p.y / FINE), 0, FH - 1) * FW + clampi(floori(p.x / FINE), 0, FW - 1)]

## On a dirt track (the meadow raster's track mask; elsewhere any DIRT), not a dirt patch of the base ground
func trackAt(p: Vector2) -> bool:
	var k := clampi(floori(p.y / FINE), 0, FH - 1) * FW + clampi(floori(p.x / FINE), 0, FW - 1)
	return tracks[k] != 0 if not tracks.is_empty() else terrain[k] == DIRT

## Bilinear raster field at a chunk-local point (centre of raster cell (i, j) at ((i - 0.5), (j - 0.5)) * FINE)
static func fieldAt(field: PackedFloat32Array, p: Vector2) -> float:
	var u := p.x / FINE + 0.5
	var v := p.y / FINE + 0.5
	var i0 := clampi(floori(u), 0, RW - 2)
	var j0 := clampi(floori(v), 0, RH - 2)
	var fx := clampf(u - i0, 0.0, 1.0)
	var fy := clampf(v - j0, 0.0, 1.0)
	var k := j0 * RW + i0
	return lerpf(lerpf(field[k], field[k + 1], fx), lerpf(field[k + RW], field[k + RW + 1], fx), fy)

func clearOf(p: Vector2, margin: float) -> bool:
	return fieldAt(water, p) >= margin && fieldAt(wall, p) >= margin

func zoneAt(p: Vector2) -> int:
	var f := zones[clampi(floori(p.y / WorldGen.CELL), 0, 1) * 4 + clampi(floori(p.x / WorldGen.CELL), 0, 3)]
	return f if f >= 0 else majority

## Outside every reservation: the start's core, station lots, Defense lanes, things already placed (the first
## `upTo` reservations only, when given)
func isFree(p: Vector2, radius: float, upTo := -1) -> bool:
	var w := origin + p
	if w.distance_to(startAt) < START_CORE + radius: return false
	for lot in lotRects:
		if lot.grow(radius).has_point(w): return false
	for lane in laneSegs:
		if Geometry2D.get_closest_point_to_segment(w, lane[0], lane[1]).distance_to(w) < LANE_HALF + radius: return false
	for n in resPos.size() if upTo < 0 else mini(upTo, resPos.size()):
		if p.distance_to(resPos[n]) < resRad[n] + radius: return false
	#the field walls keep everything after them off their whole length (not checked for what came before them)
	if upTo < 0:
		for n in range(0, wallSegs.size(), 2):
			if Geometry2D.get_closest_point_to_segment(p, wallSegs[n], wallSegs[n + 1]).distance_to(p) < WALL_DRAW_HALF + PROP_GAP * 0.5 + radius: return false
	return true

var wallSegs := PackedVector2Array() #the field walls' centre lines, two points each

func resetReservations() -> void:
	resPos.clear()
	resRad.clear()

func reserve(p: Vector2, radius: float) -> void:
	resPos.push_back(p)
	resRad.push_back(radius)

func inChunk(p: Vector2, margin: float) -> bool:
	return p.x >= margin && p.y >= margin && p.x <= CHUNK.x - margin && p.y <= CHUNK.y - margin

## Open places for PickupWorld.decorateChunk's props (crates, the Speed Trap...)
func placeSpots() -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_SPOT, chunk.x, chunk.y)
	for attempt in 40:
		if out.size() >= SPOTS: break
		var p := Vector2(r.randf_range(700.0, CHUNK.x - 700.0), r.randf_range(500.0, CHUNK.y - 500.0))
		if not clearOf(p, SPOT_CLEAR) || not isFree(p, 500.0): continue
		var ok := true
		for d in [Vector2(400, 0), Vector2(-400, 0), Vector2(0, 300), Vector2(0, -300)]:
			var q: Vector2 = p + d
			if not spawnable(terrainAt(q)) || not clearOf(q, 0.3): ok = false
		if not ok: continue
		out.push_back(p)
		reserve(p, 450.0)
	return out

## The districts' landmarks standing in this chunk (TALL props, placed before anything else): each at the
## first spot round its district's cell, ring by ring, where it fits like any prop (open spawnable ground off
## the roads, clear of water and walls, outside the start's core, station lots and lanes). Same entries as
## placeProps. A landmark with no room in the chunk is left out.
func placeLandmarks(list: Array) -> Array:
	var out: Array = []
	for entry in list:
		var id: String = entry[0]
		if not ctx.props.has(id): continue
		var info: Dictionary = ctx.props[id]
		var want: Vector2 = entry[1] - origin
		var at := Vector2.INF
		for ring in LANDMARK_RINGS + 1:
			var steps := maxi(1, ring * 8)
			for s in steps:
				var p := want + Vector2.from_angle(TAU * s / steps) * ring * LANDMARK_STEP
				if propFits(p, 0.0, info, id):
					at = p
					break
			if at != Vector2.INF: break
		if at == Vector2.INF: continue
		out.push_back(propEntry(id, at, 0.0, 0, -1, info.occluder))
		reserve(at, info.radius + PROP_GAP * 0.5)
	return out

## Roof dressing on the wall tops (ctx.roofTerrain cells): ctx.roofDecor's atlas cells well inside the wall's
## edge, spaced. The city's rooftops (AC units, vents) square to the street grid; Moose Woods' pine crowns
## over its thickets turned any way, denser (ctx.roofStyle). No collision (decor). {id, buffer, count}
func placeRoofs() -> Dictionary:
	var id: String = ctx.get("roofDecor", "")
	var out := {"id": id, "buffer": PackedFloat32Array(), "count": 0}
	var style: Dictionary = ctx.get("roofStyle", {})
	var inset: float = style.get("inset", ROOF_INSET)
	var gap: float = style.get("gap", ROOF_GAP)
	var most: int = style.get("max", ROOF_MAX)
	var square: bool = style.get("square", true)
	var scale: Vector2 = style.get("scale", Vector2(1.15, 1.6))
	var roofT: int = ctx.get("roofTerrain", BUILDING)
	var tries: int = style.get("tries", ROOF_TRIES)
	if id == "" || minWall >= -inset: return out
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_ROOF, chunk.x, chunk.y)
	var placed := PackedVector2Array()
	var buf := PackedFloat32Array()
	for j in FH:
		for i in FW:
			if terrain[j * FW + i] != roofT: continue
			for dart in tries:
				if out.count >= most: break
				var p := Vector2((i + r.randf()) * FINE, (j + r.randf()) * FINE)
				var roll := r.randf()
				var quarter := r.randi() % 4
				var sc := r.randf_range(scale.x, scale.y)
				if fieldAt(wall, p) > -inset: continue
				var near := false
				for q in placed:
					if q.distance_squared_to(p) < gap * gap:
						near = true
						break
				if near: continue
				#AC units and vents are common, tanks and skylights rarer; crowns any of the four, any way round
				var cell := 0 if roll < 0.38 else (1 if roll < 0.68 else (3 if roll < 0.86 else 2))
				var rot := quarter * PI * 0.5
				if not square:
					cell = mini(floori(roll * 4.0), 3)
					rot = fposmod(roll * 37.0, 1.0) * TAU
				var c := cos(rot) * sc
				var sn := sin(rot) * sc
				buf.append_array([c, -sn, 0.0, p.x, sn, c, 0.0, p.y, (cell + 0.5) / 4.0, 0.0, 0.0, 0.0])
				placed.push_back(p)
				out.count += 1
	out.buffer = buf
	return out

func spawnable(t: int) -> bool:
	return t >= 0 && t < spawnTable.size() && spawnTable[t] != 0

## The level's pickups: pickupsPerChunk kinds from pickupTable, each on open spawnable ground ("none" places
## nothing, so a table can leave chunks empty). Bits number them for the taken set (coins one each); past
## bit 31 a pickup has none and comes back on a reload.
func placePickups() -> Array:
	var out: Array = []
	var table: Dictionary = ctx.get("pickupTable", {})
	var total := 0.0
	for k in table: total += float(table[k])
	if total <= 0.0: return out
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_PICKUP, chunk.x, chunk.y)
	var bit := 0
	#a slot canyon's coin line (L-6: the risky way through pays): along its centre line, each chunk laying the
	#coins that fall inside it
	for run in crossRuns:
		if not run.get("slot", false): continue
		var c: Vector2 = run.centre - origin
		for k in COINS_PER_LINE:
			var p: Vector2 = c + run.axis * (k - (COINS_PER_LINE - 1) * 0.5) * COIN_STEP
			if not pickupFits(p, 60.0): continue
			out.push_back(["coin", p, bit if bit < 32 else -1])
			bit += 1
			reserve(p, 70.0)
	for n in int(ctx.get("pickupsPerChunk", 0)):
		var roll := r.randf() * total
		var kind := ""
		for k in table:
			roll -= float(table[k])
			if roll < 0.0:
				kind = String(k)
				break
		if kind == "": kind = String(table.keys().back())
		if kind == "none": continue
		if kind == "coinline":
			for attempt in 30:
				var p := Vector2(r.randf_range(300.0, CHUNK.x - 300.0), r.randf_range(300.0, CHUNK.y - 300.0))
				var dir := Vector2.from_angle(r.randf() * TAU)
				var bend := r.randf_range(-0.12, 0.12)
				var coins: Array = []
				for c in COINS_PER_LINE:
					coins.push_back(p)
					p += dir * COIN_STEP
					dir = dir.rotated(bend)
				if not pickupLineFits(coins): continue
				for c in coins:
					out.push_back(["coin", c, bit if bit < 32 else -1])
					bit += 1
					reserve(c, 70.0)
				break
		else:
			var id: String = ctx.get("pickupIds", {}).get(kind, kind)
			for attempt in 30:
				var p := Vector2(r.randf_range(200.0, CHUNK.x - 200.0), r.randf_range(200.0, CHUNK.y - 200.0))
				if not pickupFits(p, 90.0): continue
				out.push_back([id, p, bit if bit < 32 else -1])
				bit += 1
				reserve(p, 90.0)
				break
	return out

func pickupFits(p: Vector2, radius: float) -> bool:
	return inChunk(p, 64.0) && spawnable(terrainAt(p)) && clearOf(p, PICKUP_MARGIN) && isFree(p, radius)

func pickupLineFits(points: Array) -> bool:
	for p in points:
		if not pickupFits(p, 60.0): return false
	return true

## A weighted pick from {id: weight}; "" for an empty table
func pickFrom(table: Dictionary, r: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in table: total += float(table[k])
	if total <= 0.0: return ""
	var roll := r.randf() * total
	for k in table:
		roll -= float(table[k])
		if roll < 0.0: return String(k)
	return String(table.keys().back())

## The zone tables of a ctx entry ({zone: {id: weight}}) as [ids, weights, total] per zone, so a pick
## doesn't walk a Dictionary twice. pickFrom's result, roll for roll.
static func pickTables(tables: Dictionary) -> Dictionary:
	var out := {}
	for f in tables:
		var table: Dictionary = tables[f]
		var ids := PackedStringArray()
		var weights := PackedFloat64Array()
		var total := 0.0
		for k in table:
			ids.push_back(String(k))
			weights.push_back(float(table[k]))
			total += float(table[k])
		out[f] = [ids, weights, total]
	return out

static func pickFast(entry: Array, r: RandomNumberGenerator) -> String:
	var total: float = entry[2]
	if total <= 0.0: return ""
	var ids: PackedStringArray = entry[0]
	var weights: PackedFloat64Array = entry[1]
	var roll := r.randf() * total
	for n in ids.size():
		roll -= weights[n]
		if roll < 0.0: return ids[n]
	return ids[ids.size() - 1]

## Open share of the chunk (passable fine cells)
func openShare() -> float:
	if openShareCache < 0.0:
		var open := 0
		for t in terrain:
			if blockedTable[t] == 0: open += 1
		openShareCache = float(open) / terrain.size()
	return openShareCache

var openShareCache := -1.0

## Props by the dressing of each spot's district zone (LOW, TALL, STATEFUL, WALL from props.json), in these
## passes: the Home Paddock (a level's fixed opener, placeHomePaddock), heroes (interactive props and set
## pieces on layout anchors, placeHeroes), edge props (Moose Woods' pines along its thickets), field lines
## (fences and hedges on a lattice, placeFieldLines), motifs (small set pieces: camps, groves, wreck piles,
## placeMotifs), then Poisson-spaced scatter by dart throwing for the rest. Every prop stands on spawnable
## ground off blocked, lethal, shallows, bridge and belt cells, off roads unless it belongs there, clear of
## water, walls and every reservation. Other chain props (barriers, fort walls) come in short chains; a chain
## on a road lies along it. A paying breakable (coins, a spill) that gets no taken-set bit is left out, so
## nothing pays twice (the no-farming rule).
func placeProps() -> Array:
	var out: Array = []
	var tables: Dictionary = ctx.get("propTables", {})
	if tables.is_empty(): return out
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_PROP, chunk.x, chunk.y)
	var target := float(ctx.get("propsPerChunk", 16)) * openShare()
	out.append_array(placeHomePaddock())
	var heroes := placeHeroes()
	out.append_array(heroes)
	target -= heroes.size() * HERO_COST
	#the hedgerows' farm gates (laid with the walls), bits after the heroes'
	for g in wallGates:
		var info: Dictionary = ctx.props[g[0]]
		g[4] = nextBit(info, g[0])
		if not lacksBit(info, g[4]): out.push_back(g)
	var edge := placeEdgeProps()
	out.append_array(edge)
	target -= edge.size() * FIELD_COST
	var field := placeFieldLines()
	out.append_array(field)
	target -= field.size() * FIELD_COST
	var motifs := placeMotifs()
	out.append_array(motifs)
	target -= motifs.size() * MOTIF_COST
	#the scatter draws from the tables without the field props (they only come in lines)
	var fieldIds: Dictionary = ctx.get("fieldDensity", {})
	var scatterTables := tables
	if not fieldIds.is_empty():
		scatterTables = {}
		for f in tables:
			var t := {}
			for id in tables[f]:
				if not fieldIds.has(String(id)): t[id] = tables[f][id]
			scatterTables[f] = t
	var picks := pickTables(scatterTables)
	var want := maxi(0, roundi(target))
	var placedScatter := 0
	for attempt in want * 14:
		if placedScatter >= want: break
		var p := Vector2(r.randf_range(100.0, CHUNK.x - 100.0), r.randf_range(100.0, CHUNK.y - 100.0))
		var entry: Array = picks.get(zoneAt(p), picks.get(majority, EMPTY_PICK))
		if entry[0].is_empty(): entry = picks.values()[0]
		var id := pickFast(entry, r)
		if id == "": continue
		var info: Dictionary = ctx.props[id]
		var rot := r.randf() * TAU
		var count := 1
		if info.chain:
			count = r.randi_range(2, 4)
			if info.road: rot = roadAxis(p, rot) #barriers line the road instead of lying across it at random
		var axis := Vector2.from_angle(rot)
		var step: float = info.w * 0.96
		var placed: Array = []
		for c in count:
			var q := p + axis * step * c
			if not propFits(q, rot, info, id): break
			placed.push_back(q)
		if placed.is_empty(): continue
		for q in placed:
			var variant := r.randi() % maxi(int(info.variants), 1)
			var bit := nextBit(info, id)
			if lacksBit(info, bit): continue
			out.push_back(propEntry(id, q, rot, variant, bit, info.occluder))
			reserve(q, info.radius + PROP_GAP * 0.5)
		placedScatter += 1
	return out

## A recipe prop entry (see the class comment)
static func propEntry(id: String, pos: Vector2, rot: float, variant: int, bit: int, occluder: bool, group := 0, hero := false) -> Array:
	return [id, pos, rot, variant, bit, occluder, group, hero]

var breakBit := 32
var bitProps := {}      #ctx.bitProps: ids that take a taken-set bit though they don't break (Orchard Lanes' oaks shake apples down once)
var heroBreakable := {} #ctx.heroBreakable: ids that break only when the hero pass placed them (Red Canyon's saguaros)
## The next taken-set bit (32-62) for a breakable, a bitProps id, or a heroBreakable one placed as a hero; -1 for
## anything else or once they run out
func nextBit(info: Dictionary, id := "", hero := false) -> int:
	if not (info.breakable || bitProps.has(id) || (hero && heroBreakable.has(id))) || breakBit >= 63: return -1
	breakBit += 1
	return breakBit - 1

## A paying breakable (coins or a spill: ctx.props "paying") that got no bit: left out, or reloading its chunk
## would pay it again
static func lacksBit(info: Dictionary, bit: int) -> bool:
	return bit < 0 && info.get("paying", false)

#--- field lines (package 14, P-3) -----------------------------------------------------------------
#Fences and hedges lie on the edges of a field lattice in world space: one lattice per FIELD_REGION square,
#turned by an angle from the seed, so runs line up across chunks. Each lattice edge is a fence, a hedge or
#nothing (ctx.fieldDensity from features "fenceDensity" and "hedgeDensity": the chance per edge), and every
#run has a gap the car's width (a gate; two on long runs). A chunk places only the pieces whose centres are
#inside it, in the dressing of the district there. Hedgerows get an oak at some corners; a lattice cell fenced
#on PADDOCK_EDGES sides or more is a paddock with a few hay bales inside.
const TAG_FIELD := 207
const TAG_MOTIF := 212
const FIELD_REGION := 10240.0
const FIELD_ANGLE := 0.6     #radians either way of the world axes
const FIELD_COST := 0.5      #share of a scattered prop each field piece counts as
const FIELD_GATE_LONG := 6   #a run of this many pieces or more gets a second gate
const CORNER_TREE := 0.45    #chance of an oak at the corner a hedgerow starts from
const PADDOCK_EDGES := 3
const PADDOCK_BALES := Vector2i(2, 4)

## The lattice of a field region: [region, centre (world px), u axis, v axis], turned up to ctx.fieldAngle
## (features "fieldAngle", FIELD_ANGLE by default) from the world axes
func fieldFrame(region: Vector2i) -> Array:
	var ang := (WorldGen.hashf(mapSeed, TAG_FIELD, region.x, region.y) - 0.5) * 2.0 * float(ctx.get("fieldAngle", FIELD_ANGLE))
	var u := Vector2.from_angle(ang)
	return [region, (Vector2(region) + Vector2(0.5, 0.5)) * FIELD_REGION, u, u.orthogonal()]

static func regionOf(w: Vector2) -> Vector2i:
	return Vector2i(floori(w.x / FIELD_REGION), floori(w.y / FIELD_REGION))

## What lies on a lattice edge (dir 0 runs along u from lattice point (a, b), 1 along v): a field prop id or ""
func edgeKind(region: Vector2i, a: int, b: int, dir: int, dens: Dictionary) -> String:
	var roll := WorldGen.hashf(mapSeed, TAG_FIELD, (a * 2 + dir) * 7919 + region.x, b * 7919 + region.y)
	for id in dens:
		roll -= float(dens[id])
		if roll < 0.0: return String(id)
	return ""

## wallsOnly: only the edges laid as walls (ctx.fieldWalls), placed before everything but the landmarks and the
## paddock (run); returns their gates, bits still to give. Otherwise every other edge, the paddocks and corner oaks.
func placeFieldLines(wallsOnly := false) -> Array:
	var out: Array = []
	var dens: Dictionary = ctx.get("fieldDensity", {})
	if dens.is_empty(): return out
	var spacing: float = ctx.get("fieldSpacing", 1400.0)
	var tables: Dictionary = ctx.get("propTables", {})
	var walls: Dictionary = ctx.get("fieldWalls", {})
	if wallsOnly && walls.is_empty(): return out
	var box := [origin, origin + Vector2(CHUNK.x, 0), origin + Vector2(0, CHUNK.y), origin + CHUNK]
	var regions := {}
	for c in box: regions[regionOf(c)] = true
	var placed: Array = [] #[local pos, rot, info]
	for region in regions:
		var frame := fieldFrame(region)
		var centre: Vector2 = frame[1]
		var u: Vector2 = frame[2]
		var v: Vector2 = frame[3]
		#the lattice coordinates the chunk covers (its corners projected onto the axes)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c in box:
			var d: Vector2 = c - centre
			var q := Vector2(d.dot(u), d.dot(v)) / spacing
			lo = lo.min(q)
			hi = hi.max(q)
		for a in range(floori(lo.x) - 1, ceili(hi.x) + 1):
			for b in range(floori(lo.y) - 1, ceili(hi.y) + 1):
				var at: Vector2 = centre + (u * a + v * b) * spacing
				for dir in 2:
					var id := edgeKind(region, a, b, dir, dens)
					if id == "" || not ctx.props.has(id): continue
					var info: Dictionary = ctx.props[id]
					var along: Vector2 = u if dir == 0 else v
					var rot := along.angle()
					var n := maxi(2, floori(spacing / (info.w * 0.96)))
					var gateHash := WorldGen.ihash(mapSeed, TAG_FIELD + 1, a * 2 + dir + region.x * 131, b + region.y * 131)
					var gate := posmod(gateHash, n)
					var gate2 := posmod(gate + n / 2, n) if n >= FIELD_GATE_LONG else -1
					if walls.has(id):
						if wallsOnly: out.append_array(placeWallEdge(region, a, b, dir, n, gate, gate2, id, walls[id], dens, tables, placed))
						continue
					if wallsOnly: continue
					for k in n:
						if k == gate || k == gate2: continue
						var w: Vector2 = at + along * spacing * (k + 0.5) / n
						if not fieldPieceHere(w, region, id, tables): continue
						var local := w - origin
						if fieldFits(local, rot, info):
							var bit := nextBit(info, id)
							if lacksBit(info, bit): continue
							out.push_back(propEntry(id, local, rot, posmod(gateHash >> (k % 16), maxi(int(info.variants), 1)), bit, info.occluder))
							placed.push_back([local, rot, info])
					#an oak at the corner a hedgerow starts from
					if id == "hedge" && ctx.props.has("oak") && WorldGen.hashf(mapSeed, TAG_FIELD + 2, a * 2 + dir + region.x * 131, b + region.y * 131) < CORNER_TREE:
						if fieldPieceHere(at, region, "oak", tables):
							var oak: Dictionary = ctx.props["oak"]
							var local := at - origin
							if propFits(local, 0.0, oak, "oak") && clearOfPlaced(local, oak.radius * 0.4, placed):
								out.push_back(propEntry("oak", local, WorldGen.hashf(mapSeed, TAG_FIELD + 3, a, b) * TAU, posmod(gateHash, maxi(int(oak.variants), 1)), nextBit(oak, "oak"), oak.occluder))
								reserve(local, oak.radius + PROP_GAP * 0.5)
				#a paddock: this cell fenced on PADDOCK_EDGES of its four sides
				if not wallsOnly && ctx.props.has("haybale"):
					var fences := 0
					for e in [[a, b, 0], [a, b, 1], [a, b + 1, 0], [a + 1, b, 1]]:
						if edgeKind(region, e[0], e[1], e[2], dens) == "fence": fences += 1
					if fences >= PADDOCK_EDGES:
						var bale: Dictionary = ctx.props["haybale"]
						var count := PADDOCK_BALES.x + posmod(WorldGen.ihash(mapSeed, TAG_FIELD + 4, a + region.x * 131, b + region.y * 131), PADDOCK_BALES.y - PADDOCK_BALES.x + 1)
						for i in count:
							var f := Vector2(WorldGen.hashf(mapSeed, TAG_FIELD + 5, a * 8 + i, b + region.x), WorldGen.hashf(mapSeed, TAG_FIELD + 6, b * 8 + i, a + region.y))
							var w: Vector2 = centre + (u * (a + 0.25 + f.x * 0.5) + v * (b + 0.25 + f.y * 0.5)) * spacing
							if not fieldPieceHere(w, region, "haybale", tables): continue
							var local := w - origin
							var rot := u.angle() + (PI * 0.5 if i % 2 else 0.0)
							if propFits(local, rot, bale, "haybale") && clearOfPlaced(local, bale.radius, placed):
								var bit := nextBit(bale, "haybale")
								if lacksBit(bale, bit): continue
								out.push_back(propEntry("haybale", local, rot, i % maxi(int(bale.variants), 1), bit, bale.occluder))
								reserve(local, bale.radius + PROP_GAP * 0.5)
	#the pieces keep later props off their whole length, not only a disc round each centre (walls: wallSegs)
	if wallsOnly: return out
	for e in placed:
		var axis: Vector2 = Vector2.from_angle(e[1]) * (e[2].w * 0.33)
		for s in [-1.0, 0.0, 1.0]: reserve(e[0] + axis * s, e[2].h * 0.5 + PROP_GAP * 0.5)
	return out

## A field prop belongs at world point w: inside this chunk, in the lattice's region, and in the dressing of
## the district there
func fieldPieceHere(w: Vector2, region: Vector2i, id: String, tables: Dictionary) -> bool:
	var local := w - origin
	if local.x < 0.0 || local.y < 0.0 || local.x >= CHUNK.x || local.y >= CHUNK.y || regionOf(w) != region: return false
	var table: Dictionary = tables.get(zoneAt(local), {})
	return float(table.get(id, 0.0)) > 0.0

## propFits for a field piece: the same ground rules (never on a road, so tracks cut gaps in the runs), but
## it keeps clear only of what was placed before the field pass: pieces of one run touch end to end
func fieldFits(p: Vector2, rot: float, info: Dictionary) -> bool:
	var along: Vector2 = Vector2.from_angle(rot) * (info.w * 0.5 * 0.85)
	var across: Vector2 = Vector2.from_angle(rot).orthogonal() * (info.h * 0.5 * 0.85)
	for q in [p, p + along, p - along, p + across, p - across]:
		if not inChunk(q, 0.0): return false
		var t := terrainAt(q)
		if not spawnable(t) || t == CONVEYOR || t == MUDPIT || t == BRIDGE || t == ASPHALT || t == OIL: return false
		if not clearOf(q, PROP_MARGIN): return false
	for s in [-0.33, 0.0, 0.33]:
		if not isFree(p + Vector2.from_angle(rot) * info.w * s, info.h * 0.5 + 40.0): return false
	return true

## Clear of the field pieces placed so far (each a box along its rotation), by `radius`
static func clearOfPlaced(p: Vector2, radius: float, placed: Array) -> bool:
	for e in placed:
		var axis: Vector2 = Vector2.from_angle(e[1])
		var off: Vector2 = p - e[0]
		if absf(off.dot(axis)) < e[2].w * 0.5 + radius && absf(off.dot(axis.orthogonal())) < e[2].h * 0.5 + radius: return false
	return true

#--- field walls (L-8: cheap walls from field lines) ------------------------------------------------
#On a level with features "hedgeWalls" (Orchard Lanes), a hedge lattice edge is no row of 4-node breakable
#props but an unbreakable hedgerow: boxes in the chunk's own wall body (fieldWalls), occluder loops and one
#decor MultiMesh (the hedgerow atlas: straights, end caps; docs/WORLD_ART.md "Hedgerow"), so a dense lattice
#costs almost no nodes. Each edge is cut into the same slots as a run of props; the gate slot gets a farm gate
#(breakable) most of the time, and slots that don't fit (roads, tracks, water, reservations) are gaps. The
#chunk holding a slot's centre owns it; consecutive owned slots make one box. Caps close a run at a gate, a
#gap or a lattice point no other hedgerow meets.
const WALL_HALF := 50.0      #the collision box's half width (the art: an 80 px hedge on a 112 px base)
const WALL_OCC_HALF := 40.0
const WALL_DRAW_HALF := 56.0 #the base, for the keep-off reservations
const WALL_CELL := 192.0     #decor cell length
const WALL_CAP := 80.0       #how far an end cap's hedge reaches into its cell
const WALL_OCCLUDERS := 10   #at most this many of a chunk's occluders are hedgerows
const TAG_GATE := 216

var fieldWalls: Array = []           #convex boxes (out.fieldWalls)
var wallOccluders: Array = []        #closed loops, inside on the right
var wallDecor := PackedFloat32Array() #MultiMesh buffer for wallDecorId
var wallDecorId := ""
var wallRoom := MAX_PIECES           #wall pieces still allowed (MAX_PIECES less the terrain's)
var wallGates: Array = []           #the gates placeWallEdge laid, given their bits in placeProps
var wallFrom := -1                   #reservations made before the walls (the walls keep clear of only those)

## One lattice edge as a hedgerow wall; returns the gate props it placed. spec: ctx.fieldWalls[id]
## ({decor, gate, gateChance}).
func placeWallEdge(region: Vector2i, a: int, b: int, dir: int, n: int, gate: int, gate2: int, id: String, spec: Dictionary, dens: Dictionary, tables: Dictionary, placed: Array) -> Array:
	var out: Array = []
	var frame := fieldFrame(region)
	var spacing: float = ctx.get("fieldSpacing", 1400.0)
	var along: Vector2 = frame[2] if dir == 0 else frame[3]
	var at: Vector2 = frame[1] + (frame[2] * a + frame[3] * b) * spacing
	var rot := along.angle()
	var slotLen := spacing / n
	#each slot: 0 a wall here, 1 a gate, 2 open (doesn't fit, or not this field), 3 another chunk's (taken as a wall)
	var state := PackedInt32Array()
	state.resize(n)
	for k in n:
		var w: Vector2 = at + along * spacing * (k + 0.5) / n
		var local := w - origin
		var mine := local.x >= 0.0 && local.y >= 0.0 && local.x < CHUNK.x && local.y < CHUNK.y
		if regionOf(w) != region: state[k] = 2
		elif k == gate || k == gate2: state[k] = 1
		elif not mine: state[k] = 3
		elif float(tables.get(zoneAt(local), {}).get(id, 0.0)) <= 0.0: state[k] = 2
		else: state[k] = 0 if wallSlotFits(local, rot, slotLen) else 2
		#a farm gate in an owned gate slot, most of the time (the rest stay open: "turn at the open end")
		if state[k] == 1 && mine && float(tables.get(zoneAt(local), {}).get(id, 0.0)) > 0.0:
			var gateId: String = spec.get("gate", "")
			if gateId != "" && ctx.props.has(gateId) && WorldGen.hashf(mapSeed, TAG_GATE, a * 2 + dir + region.x * 131, b + region.y * 131) < float(spec.get("gateChance", 1.0)):
				var g: Dictionary = ctx.props[gateId]
				if not trackAt(local) && setPieceFits(local, rot, g, wallFrom) && isFree(local, g.h * 0.5 + 30.0, wallFrom):
					out.push_back(propEntry(gateId, local, rot, posmod(a + b, maxi(int(g.variants), 1)), -1, g.occluder)) #its bit comes after the heroes'
					reserve(local, 200.0)
	#runs of consecutive owned wall slots
	var k := 0
	while k < n:
		if state[k] != 0:
			k += 1
			continue
		var k0 := k
		while k < n && state[k] == 0: k += 1
		var k1 := k - 1
		if wallRoom <= 0: continue
		wallRoom -= 1
		var startCap := (latticeEndFree(region, a, b, dir, true, dens) if k0 == 0 else state[k0 - 1] != 3)
		var endCap := (latticeEndFree(region, a, b, dir, false, dens) if k1 == n - 1 else state[k1 + 1] != 3)
		var from: Vector2 = at + along * slotLen * k0 - origin
		var len := slotLen * (k1 - k0 + 1)
		addWall(from, along, len, startCap, endCap, a * 31 + b * 17 + k0, spec)
		placed.push_back([from + along * len * 0.5, rot, {"w": len, "h": WALL_DRAW_HALF * 2.0}])
	return out

## Whether the lattice point at one end of an edge (the start: (a, b); the end: the next point along it) has no
## other hedgerow wall meeting it, so the run ends there in a cap
func latticeEndFree(region: Vector2i, a: int, b: int, dir: int, start: bool, dens: Dictionary) -> bool:
	var walls: Dictionary = ctx.get("fieldWalls", {})
	var pa := a if start || dir == 1 else a + 1
	var pb := b if start || dir == 0 else b + 1
	#the four edges touching lattice point (pa, pb), less this one
	for e in [[pa, pb, 0], [pa, pb, 1], [pa - 1, pb, 0], [pa, pb - 1, 1]]:
		if e[0] == a && e[1] == b && e[2] == dir: continue
		if walls.has(edgeKind(region, e[0], e[1], e[2], dens)): return false
	return true

## A hedgerow slot fits: its box clear of roads, dirt tracks (so the farm tracks are the lanes), belts, mud
## pits, bridges and water, and of every reservation; the parts outside the chunk are judged on its apron
func wallSlotFits(p: Vector2, rot: float, len: float) -> bool:
	var u := Vector2.from_angle(rot)
	var v := u.orthogonal()
	for s in [-0.45, -0.15, 0.15, 0.45]:
		for o in [-1.0, 1.0]:
			var q: Vector2 = p + u * len * s + v * WALL_DRAW_HALF * o
			var t := terrainAt(q)
			if not spawnable(t) || t == CONVEYOR || t == MUDPIT || t == BRIDGE || t == ASPHALT || t == OIL || trackAt(q): return false
			if not clearOf(q, PROP_MARGIN * 0.5): return false
	for s in [-0.4, 0.0, 0.4]:
		if not isFree(p + u * len * s, WALL_DRAW_HALF + 30.0, wallFrom): return false #runs meet and cross: only what came before the walls
	return true

## A hedgerow run from `from` (chunk-local) along u for len px: its collision box, its occluder loop (while
## there is room), its decor cells and its keep-off line (wallSegs, read by isFree)
func addWall(from: Vector2, u: Vector2, len: float, startCap: bool, endCap: bool, salt: int, spec: Dictionary) -> void:
	var v := u.orthogonal()
	var c := from + u * len * 0.5
	var box := PackedVector2Array([c - u * len * 0.5 + v * WALL_HALF, c + u * len * 0.5 + v * WALL_HALF, c + u * len * 0.5 - v * WALL_HALF, c - u * len * 0.5 - v * WALL_HALF])
	if Geometry2D.is_polygon_clockwise(box): box.reverse() #the same winding as the terrain's pieces
	fieldWalls.push_back(box)
	if wallOccluders.size() < WALL_OCCLUDERS:
		#clockwise on screen, closed: the inside on the right, like the terrain's occluders
		var h := len * 0.5
		wallOccluders.push_back(PackedVector2Array([c - u * h + v * WALL_OCC_HALF, c + u * h + v * WALL_OCC_HALF,
			c + u * h - v * WALL_OCC_HALF, c - u * h - v * WALL_OCC_HALF, c - u * h + v * WALL_OCC_HALF]))
	wallDecorId = String(spec.get("decor", ""))
	if wallDecorId != "":
		var rot := u.angle()
		var a := WALL_CAP if startCap else 0.0
		var b := len - (WALL_CAP if endCap else 0.0)
		var span := b - a
		if span > 1.0:
			var cells := maxi(1, roundi(span / WALL_CELL))
			for i in cells: wallCell(from + u * (a + (i + 0.5) * span / cells), rot, span / (cells * WALL_CELL), (salt + i) & 1)
		#a cap's hedge runs from its cell's -x edge to WALL_CAP in: its cell sits 16 px past the run's end
		if endCap: wallCell(from + u * (len + WALL_CELL * 0.5 - WALL_CAP), rot, 1.0, 2)
		if startCap: wallCell(from - u * (WALL_CELL * 0.5 - WALL_CAP), rot + PI, 1.0, 2)
	wallSegs.push_back(from)
	wallSegs.push_back(from + u * len)

## One hedgerow decor cell (atlas `cell`), stretched along its run by sx
func wallCell(p: Vector2, rot: float, sx: float, cell: int) -> void:
	var c := cos(rot)
	var s := sin(rot)
	wallDecor.append_array([c * sx, -s, 0.0, p.x, s * sx, c, 0.0, p.y, (cell + 0.5) / 4.0, 0.0, 0.0, 0.0])

## A set piece's member fits where the layout puts it: its centre in this chunk, the ground under the parts of its
## box inside the chunk open (as propFits), clear of the reservations made before the set piece (`upTo`)
func setPieceFits(p: Vector2, rot: float, info: Dictionary, upTo := -1) -> bool:
	if p.x < 0.0 || p.y < 0.0 || p.x >= CHUNK.x || p.y >= CHUNK.y: return false
	var along: Vector2 = Vector2.from_angle(rot) * (info.w * 0.5 * 0.85)
	var across: Vector2 = Vector2.from_angle(rot).orthogonal() * (info.h * 0.5 * 0.85)
	for q in [p, p + along, p - along, p + across, p - across]:
		if not inChunk(q, 0.0): continue
		var t := terrainAt(q)
		if not spawnable(t) || t == CONVEYOR || t == MUDPIT || t == BRIDGE || t == ASPHALT || t == OIL: return false
		if not clearOf(q, PROP_MARGIN): return false
	return isFree(p, info.radius * 0.3, upTo)

#--- the Home Paddock (Prairie Run's opener) ---------------------------------------------------------
#A fixed set piece PADDOCK_AHEAD px ahead of the start along +x (where Sprint goes; outside START_CORE): a
#fenced paddock with its gate toward the start, a three-crate stash and two hay bales inside, a log pile at the
#far corner above the dirt track that runs past it (WorldField.PADDOCK_TRACK_Y). It is laid out in world space
#and each chunk places the members whose centres it holds, so it may straddle a seam; decorateChunk skips the
#start's chunk, which is why the recipe builds it. features "homePaddock" (ctx.homePaddock) turns it on.
const PADDOCK_AHEAD := 2600.0
const PADDOCK_HALF := 480.0
const TAG_PADDOCK := 217
## [prop id, offset from the paddock's centre, rotation, in the crate stash's group]
const PADDOCK := [
	["fence", Vector2(-317, -480), 0.0, false], ["fence", Vector2(0, -480), 0.0, false], ["fence", Vector2(317, -480), 0.0, false],
	["fence", Vector2(-317, 480), 0.0, false], ["fence", Vector2(0, 480), 0.0, false], ["fence", Vector2(317, 480), 0.0, false],
	["fence", Vector2(480, -317), PI * 0.5, false], ["fence", Vector2(480, 0), PI * 0.5, false], ["fence", Vector2(480, 317), PI * 0.5, false],
	["fence", Vector2(-480, -317), PI * 0.5, false], ["fence", Vector2(-480, 317), PI * 0.5, false], #the gate faces the start
	["crate", Vector2(200, -200), 0.3, true], ["crate", Vector2(310, -110), 1.1, true], ["crate", Vector2(170, -70), 2.0, true],
	["haybale", Vector2(-190, 210), 0.0, false], ["haybale", Vector2(-20, 270), PI * 0.5, false],
	["logpile", Vector2(680, -600), 0.0, false],
]
var paddockFrom := -1 #reservations before the paddock's own (its members check only those)

## The paddock's centre (chunk-local), or INF when the level has none or it is nowhere near this chunk
func paddockCentre() -> Vector2:
	if not ctx.get("homePaddock", false) || startAt == Vector2.INF: return Vector2.INF
	var c: Vector2 = startAt + Vector2(PADDOCK_AHEAD, 0.0) - origin
	return c if Rect2(Vector2.ZERO, CHUNK).grow(PADDOCK_HALF + 600.0).has_point(c) else Vector2.INF

## Keeps the spots and pickups off the paddock (placed before the props)
func reservePaddock() -> void:
	var c := paddockCentre()
	if c == Vector2.INF: return
	paddockFrom = resPos.size()
	reserve(c, PADDOCK_HALF + 250.0)

func placeHomePaddock() -> Array:
	var out: Array = []
	var c := paddockCentre()
	if c == Vector2.INF: return out
	var key := maxi(1, WorldGen.ihash(mapSeed, TAG_PADDOCK, 0, 0))
	var fits: Array = []
	for m in PADDOCK:
		if not ctx.props.has(m[0]): continue
		var info: Dictionary = ctx.props[m[0]]
		var p: Vector2 = c + m[1]
		if setPieceFits(p, m[2], info, paddockFrom): fits.push_back([m, info, p])
	for i in fits.size():
		var m: Array = fits[i][0]
		var info: Dictionary = fits[i][1]
		var bit := nextBit(info, m[0])
		if lacksBit(info, bit): continue
		out.push_back(propEntry(m[0], fits[i][2], m[2], i % maxi(int(info.variants), 1), bit, info.occluder, key if m[3] else 0))
	for f in fits: reserve(f[2], f[1].radius * 0.5 + 40.0)
	return out

#--- heroes (R-2: interactive props first, anchored to the layout) ----------------------------------
#ctx.heroTables is {zone: {id: [weight, anchor, variant]}}: a prop id or a motif (WorldSkin.MOTIFS) placed on a
#layout anchor before the field lines and motifs, so the node budget keeps them. ctx.heroesPerChunk (features
#"heroes") are wanted in a fully open chunk. Anchors are cheap raster reads:
#  ford      HERO_NEAR px from a ford crossing (WorldGen.crossingRuns)
#  bank      BANK_CELLS fine cells from water, shallows or a deck (beside creeks, channels and lakes)
#  track     TRACK_OFF px off a dirt track (the raster's track mask; not on it), turned so its +y faces the track
#  pass      PASS_NEAR px from a pass cut through walls, where the wall field is within PASS_WALL (a wall's foot)
#  clearing  open ground all round within CLEARING_R
#  edge      a thicket's edge (the wall field within EDGE_FIELD)
#  any       anywhere a prop fits
#Everything a hero pass places carries hero = true; a motif's members share a group key.
const TAG_HERO := 213
const TAG_GROUP := 214
const TAG_EDGE := 215
const HERO_COST := 1.0
const HERO_PICKS := 4   #ids tried per hero wanted (an anchor the chunk lacks moves on to another)
const HERO_TRIES := 16  #darts per id
const HERO_NEAR := Vector2(600.0, 1400.0) #from a ford's middle: past its shallows onto the bank
const BANK_CELLS := Vector2i(2, 5) #fine cells (128 px) from water, shallows or a deck
const TRACK_OFF := Vector2(250.0, 500.0)
const TRACK_CLEAR := 200.0
const PASS_NEAR := Vector2(350.0, 1000.0)
const PASS_WALL := Vector2(0.15, 0.8)
const CLEARING_R := 640.0
const CLEARING_SHARE := 0.9
const EDGE_FIELD := Vector2(0.3, 0.6)
const ANCHORS := ["ford", "bank", "track", "pass", "clearing", "edge", "any", "bridge"]

var crossRuns: Array = []  #the raster's crossings round the chunk (WorldGen.crossingRuns)
var tracks := PackedByteArray() #the raster's track mask (meadow), FW x FH
var anchorCache := {}      #anchor -> PackedVector2Array of seed points
var motifSerial := 0       #motif instances placed in this chunk, for their group keys

func placeHeroes() -> Array:
	var out: Array = []
	var tables: Dictionary = ctx.get("heroTables", {})
	var table: Dictionary = tables.get(majority, {})
	if table.is_empty(): return out
	var hr := RandomNumberGenerator.new()
	hr.seed = WorldGen.ihash(mapSeed, TAG_HERO, chunk.x, chunk.y)
	var expect: float = float(ctx.get("heroesPerChunk", 1.0)) * openShare()
	var count := floori(expect) + (1 if hr.randf() < expect - floori(expect) else 0)
	var weights := {}
	for id in table: weights[id] = float(table[id][0])
	var entry: Array = pickTables({0: weights})[0]
	for n in count:
		for attempt in HERO_PICKS:
			var id := pickFast(entry, hr)
			if id == "": break
			var got := placeHero(id, table[id], hr)
			if not got.is_empty():
				out.append_array(got)
				break
	return out

## One hero on its anchor: the props it placed (a motif's members), or [] when nothing fits
func placeHero(id: String, spec: Array, hr: RandomNumberGenerator) -> Array:
	var anchor: String = spec[1] if spec.size() > 1 else "any"
	var variant: int = int(spec[2]) if spec.size() > 2 else -1
	var defs: Dictionary = ctx.get("motifDefs", {})
	var isMotif := defs.has(id)
	if not isMotif && not ctx.props.has(id): return []
	for dart in HERO_TRIES:
		var a := anchorPoint(anchor, hr)
		if a.is_empty():
			if anchor != "any" && anchor != "clearing" && anchorSeeds(anchor).is_empty(): return [] #no such place here
			continue
		var p: Vector2 = a[0]
		if isMotif:
			var def: Dictionary = defs[id]
			if not isFree(p, PROP_GAP): continue
			var group := motifGroup(p, def, hr)
			if group.size() < int(def.get("min", 2)): continue
			return emitMotif(group, hr, true)
		var info: Dictionary = ctx.props[id]
		var rot: float = hr.randf() * TAU if is_nan(a[1]) else a[1]
		if not propFits(p, rot, info, id): continue
		var bit := nextBit(info, id, true)
		if lacksBit(info, bit): return []
		var v := clampi(variant, 0, maxi(int(info.variants), 1) - 1) if variant >= 0 else hr.randi() % maxi(int(info.variants), 1)
		reserve(p, info.radius + PROP_GAP * 0.5)
		return [propEntry(id, p, rot, v, bit, info.occluder, 0, true)]
	return []

## A spot for an anchor: [chunk-local point, facing (the rotation turning the prop's +y toward what it is
## anchored to, NAN for any)], or [] for a miss
func anchorPoint(anchor: String, r: RandomNumberGenerator) -> Array:
	match anchor:
		"any":
			return [Vector2(r.randf_range(150.0, CHUNK.x - 150.0), r.randf_range(150.0, CHUNK.y - 150.0)), NAN]
		"clearing":
			var p := Vector2(r.randf_range(500.0, CHUNK.x - 500.0), r.randf_range(500.0, CHUNK.y - 500.0))
			return [p, NAN] if clearingAt(p) else []
		"bank", "edge":
			var seeds := anchorSeeds(anchor)
			if seeds.is_empty(): return []
			return [seeds[r.randi() % seeds.size()] + Vector2(r.randf_range(-60.0, 60.0), r.randf_range(-60.0, 60.0)), NAN]
		"ford", "pass", "bridge":
			var seeds := anchorSeeds(anchor)
			if seeds.is_empty(): return []
			var s := seeds[r.randi() % seeds.size()]
			var near := PASS_NEAR if anchor == "pass" else HERO_NEAR
			#a crossing may lie just outside the chunk (the raster sees the cells round it): darts that land inside
			var p := Vector2.INF
			for k in 8:
				var q := s + Vector2.from_angle(r.randf() * TAU) * r.randf_range(near.x, near.y)
				if inChunk(q, 120.0):
					p = q
					break
			if p == Vector2.INF: return []
			if anchor == "pass":
				var f := fieldAt(wall, p)
				if f < PASS_WALL.x || f > PASS_WALL.y: return []
			return [p, (s - p).angle() - PI * 0.5]
		"track":
			var seeds := anchorSeeds(anchor)
			if seeds.is_empty(): return []
			var s := seeds[r.randi() % seeds.size()]
			var p := s + Vector2.from_angle(r.randf() * TAU) * r.randf_range(TRACK_OFF.x, TRACK_OFF.y)
			if trackAt(p): return []
			for k in 6:
				if trackAt(p + Vector2.from_angle(TAU * k / 6.0) * TRACK_CLEAR): return []
			return [p, (s - p).angle() - PI * 0.5]
	return []

## The raster points an anchor starts from (chunk-local), worked out once per recipe
func anchorSeeds(anchor: String) -> PackedVector2Array:
	if anchorCache.has(anchor): return anchorCache[anchor]
	var out := PackedVector2Array()
	match anchor:
		"ford", "pass", "bridge":
			var reach := Rect2(Vector2.ZERO, CHUNK).grow(maxf(HERO_NEAR.y, PASS_NEAR.y) - 120.0)
			for run in crossRuns:
				if run.kind == anchor && reach.has_point(run.centre - origin): out.push_back(run.centre - origin)
		"bank":
			#dry cells BANK_CELLS steps (4-connected) from water, shallows or a deck: a breadth-first search from
			#the wet cells (the water field's lake fbm is too rough a distance for this)
			var dist := PackedInt32Array()
			dist.resize(FW * FH)
			dist.fill(BANK_CELLS.y + 1)
			var queue := PackedInt32Array()
			for k in FW * FH:
				var t := terrain[k]
				if t == WATER || t == SHALLOWS || t == BRIDGE:
					dist[k] = 0
					queue.push_back(k)
			var head := 0
			while head < queue.size():
				var k := queue[head]
				head += 1
				var d := dist[k] + 1
				if d > BANK_CELLS.y: continue
				var i := k % FW
				if i > 0 && dist[k - 1] > d:
					dist[k - 1] = d
					queue.push_back(k - 1)
				if i < FW - 1 && dist[k + 1] > d:
					dist[k + 1] = d
					queue.push_back(k + 1)
				if k >= FW && dist[k - FW] > d:
					dist[k - FW] = d
					queue.push_back(k - FW)
				if k + FW < FW * FH && dist[k + FW] > d:
					dist[k + FW] = d
					queue.push_back(k + FW)
			for k in FW * FH:
				if dist[k] >= BANK_CELLS.x && dist[k] <= BANK_CELLS.y && spawnable(terrain[k]): out.push_back(Vector2(k % FW + 0.5, k / FW + 0.5) * FINE)
		"edge":
			for j in FH:
				for i in FW:
					var v := wall[(j + 1) * RW + i + 1]
					if v >= EDGE_FIELD.x && v <= EDGE_FIELD.y && spawnable(terrain[j * FW + i]): out.push_back(Vector2(i + 0.5, j + 0.5) * FINE)
		"track":
			for j in FH:
				for i in FW:
					if trackAt(Vector2(i + 0.5, j + 0.5) * FINE): out.push_back(Vector2(i + 0.5, j + 0.5) * FINE)
	anchorCache[anchor] = out
	return out

## Open ground all round p: at least CLEARING_SHARE of 17 points out to CLEARING_R are passable and well off
## walls and water
func clearingAt(p: Vector2) -> bool:
	var open := 0
	var total := 0
	for ring in 3:
		var steps := 1 if ring == 0 else 8
		for s in steps:
			var q := p + Vector2.from_angle(TAU * s / steps + ring * 0.4) * CLEARING_R * ring * 0.5
			total += 1
			var t := terrainAt(q)
			if t >= 0 && t < blockedTable.size() && blockedTable[t] == 0 && fieldAt(wall, q) >= 0.4 && fieldAt(water, q) >= 0.4: open += 1
	return open >= total * CLEARING_SHARE

## A motif's members as recipe entries sharing one group key (the motif instance, for C2's warren and apiary
## counts), reserved; hero = placed by the hero pass. A paying member that gets no bit is left out.
func emitMotif(group: Array, r: RandomNumberGenerator, hero: bool) -> Array:
	var out: Array = []
	motifSerial += 1
	var key := maxi(1, WorldGen.ihash(mapSeed, TAG_GROUP, (chunk.x + 512) * 1024 + chunk.y + 512, motifSerial))
	for g in group:
		var info: Dictionary = ctx.props[g[0]]
		var vs: Array = g[3]
		var variant := r.randi() % maxi(int(info.variants), 1)
		if not vs.is_empty(): variant = clampi(int(vs[variant % vs.size()]), 0, maxi(int(info.variants), 1) - 1)
		var bit := nextBit(info, g[0], hero)
		if lacksBit(info, bit): continue
		out.push_back(propEntry(g[0], g[1], g[2], variant, bit, info.occluder, key, hero))
	for g in group: reserve(g[1], ctx.props[g[0]].radius + PROP_GAP * 0.5)
	return out

## Props along a thicket's edge (features "edgeProps": {id: count}; Moose Woods' pines): the only real trees
## round its walls, which are drawn as pine crowns
func placeEdgeProps() -> Array:
	var out: Array = []
	var spec: Dictionary = ctx.get("edgeProps", {})
	if spec.is_empty(): return out
	var seeds := anchorSeeds("edge")
	if seeds.is_empty(): return out
	var er := RandomNumberGenerator.new()
	er.seed = WorldGen.ihash(mapSeed, TAG_EDGE, chunk.x, chunk.y)
	for id in spec:
		if not ctx.props.has(id): continue
		var info: Dictionary = ctx.props[id]
		var want := int(spec[id])
		var placed := 0
		for attempt in want * 6:
			if placed >= want: break
			var p := seeds[er.randi() % seeds.size()] + Vector2(er.randf_range(-64.0, 64.0), er.randf_range(-64.0, 64.0))
			var rot := er.randf() * TAU
			if not propFits(p, rot, info, id): continue
			var bit := nextBit(info, id)
			if lacksBit(info, bit): continue
			out.push_back(propEntry(id, p, rot, er.randi() % maxi(int(info.variants), 1), bit, info.occluder))
			reserve(p, info.radius + PROP_GAP * 0.5)
			placed += 1
	return out

## The road's direction at p: the heading (of 8) with the longest run of road through p, else `fallback`
func roadAxis(p: Vector2, fallback: float) -> float:
	var best := 0
	var bestRot := fallback
	for k in 8:
		var rot := PI * k / 8.0
		var d := Vector2.from_angle(rot) * 96.0
		var run := 0
		for s in range(-6, 7):
			var t := terrainAt(p + d * s)
			if t == ASPHALT || t == OIL: run += 1
		if run > best:
			best = run
			bestRot = rot
	return bestRot if best >= 5 else fallback

#--- motifs (package 14, P-5) ----------------------------------------------------------------------
#Small set pieces placed before the scatter: ctx.motifs is {zone: {motif id: weight}} and ctx.motifDefs the
#motifs (WorldSkin.MOTIFS): members in a ring, scattered in a disc, in a grid or a line turned to the field
#lattice, or at the centre. Members keep MOTIF_GAP from each other instead of PROP_GAP; the motif keeps
#PROP_GAP from everything else. features "motifs" is how many a fully open chunk gets on average (ctx.motifsPerChunk).
const MOTIF_GAP := 70.0
const MOTIF_TRIES := 10
const MOTIF_COST := 1.0      #share of a scattered prop each motif member counts as

func placeMotifs() -> Array:
	var out: Array = []
	var tables: Dictionary = ctx.get("motifs", {})
	var defs: Dictionary = ctx.get("motifDefs", {})
	if tables.is_empty() || defs.is_empty(): return out
	var mr := RandomNumberGenerator.new()
	mr.seed = WorldGen.ihash(mapSeed, TAG_MOTIF, chunk.x, chunk.y)
	var expect: float = float(ctx.get("motifsPerChunk", 1.0)) * openShare()
	var count := floori(expect) + (1 if mr.randf() < expect - floori(expect) else 0)
	var picks := pickTables(tables)
	for n in count:
		for attempt in MOTIF_TRIES:
			var c := Vector2(mr.randf_range(600.0, CHUNK.x - 600.0), mr.randf_range(500.0, CHUNK.y - 500.0))
			var entry: Array = picks.get(zoneAt(c), EMPTY_PICK)
			var mid := pickFast(entry, mr)
			if mid == "": break
			if not defs.has(mid): continue
			var def: Dictionary = defs[mid]
			if not isFree(c, PROP_GAP): continue
			var group := motifGroup(c, def, mr)
			if group.size() < int(def.get("min", 2)): continue
			out.append_array(emitMotif(group, mr, false))
			break
	return out

## A motif's members round centre c that fit: [[id, pos, rot, variants (the member's "variants" option, or
## []), a pen piece], ...]. A member is [id, count (an int, or [low, high]), radius px, shape, options]; options
## (optional): "variants" (the variant indices it picks from) and "offset" (px a line stands off the centre,
## across the lattice). Shapes: centre, ring, disc, grid, line, and pen (count pieces round a square of half
## side `radius`, one left out as the gate; pen pieces touch end to end).
func motifGroup(c: Vector2, def: Dictionary, mr: RandomNumberGenerator) -> Array:
	var group: Array = []
	var grid := fieldFrame(regionOf(origin + c))[2] as Vector2
	var turn := mr.randf() * TAU
	for m in def.members:
		var id: String = m[0]
		if not ctx.props.has(id): continue
		var info: Dictionary = ctx.props[id]
		var n: int = m[1] if m[1] is int else mr.randi_range(int(m[1][0]), int(m[1][1]))
		var radius: float = m[2]
		var shape: String = m[3]
		var opts: Dictionary = m[4] if m.size() > 4 else {}
		var offset := grid.orthogonal() * float(opts.get("offset", 0.0))
		var pen := shape == "pen"
		var perSide := maxi(1, n / 4)
		var gateAt := mr.randi() % (perSide * 4) if pen else -1
		for i in n:
			var p := c
			var rot := mr.randf() * TAU
			match shape:
				"ring":
					var a := turn + TAU * i / n + mr.randf_range(-0.15, 0.15)
					p = c + Vector2.from_angle(a) * radius
					rot = a + PI * 0.5
				"disc": p = c + Vector2.from_angle(mr.randf() * TAU) * radius * sqrt(mr.randf())
				"grid":
					var cols := ceili(sqrt(float(n)))
					var rows := ceili(float(n) / cols)
					var cell := Vector2(i % cols, i / cols) - Vector2(cols - 1, rows - 1) * 0.5
					p = c + (grid * cell.x + grid.orthogonal() * cell.y) * radius
				"line":
					p = c + offset + grid * (i - (n - 1) * 0.5) * radius
					rot = grid.angle()
				"pen":
					if i >= perSide * 4 || i == gateAt: continue
					var side := i / perSide
					var along := -radius + (i % perSide + 0.5) * radius * 2.0 / perSide
					var axis := grid if side % 2 == 0 else grid.orthogonal()
					var normal := grid.orthogonal() if side % 2 == 0 else grid
					p = c + axis * along + normal * radius * (-1.0 if side < 2 else 1.0)
					rot = axis.angle()
			if not motifFits(p, rot, info, group, pen): continue
			group.push_back([id, p, rot, opts.get("variants", []), pen])
	return group

func motifFits(p: Vector2, rot: float, info: Dictionary, group: Array, pen := false) -> bool:
	if not inChunk(p, 32.0) || not isFree(p, info.radius + PROP_GAP * 0.5): return false
	for g in group:
		var other: Dictionary = ctx.props[g[0]]
		if pen || g[4]:
			#a pen piece is a long thin box: pieces of one pen touch end to end, the rest keep off its box
			if pen && g[4]: continue
			var boxAt: Vector2 = p if pen else g[1]
			var boxRot: float = rot if pen else g[2]
			var box: Dictionary = info if pen else other
			var disc: Vector2 = g[1] if pen else p
			var r: float = (other.radius if pen else info.radius) * 0.75 + MOTIF_GAP * 0.5
			var axis := Vector2.from_angle(boxRot)
			var off := disc - boxAt
			if absf(off.dot(axis)) < box.w * 0.5 + r && absf(off.dot(axis.orthogonal())) < box.h * 0.5 + r: return false
		elif p.distance_to(g[1]) < (info.radius + other.radius) * 0.75 + MOTIF_GAP: return false
	var along: Vector2 = Vector2.from_angle(rot) * (info.w * 0.5 * 0.85)
	var across: Vector2 = Vector2.from_angle(rot).orthogonal() * (info.h * 0.5 * 0.85)
	for q in [p, p + along, p - along, p + across, p - across]:
		if not inChunk(q, 0.0): return false
		var t := terrainAt(q)
		if not spawnable(t) || t == CONVEYOR || t == MUDPIT || t == BRIDGE: return false
		if (t == ASPHALT || t == OIL) && not info.road: return false
		if not clearOf(q, PROP_MARGIN): return false
	return true

func propFits(p: Vector2, rot: float, info: Dictionary, id: String) -> bool:
	var radius: float = info.radius
	if not inChunk(p, 32.0) || not isFree(p, radius + PROP_GAP * 0.5): return false
	var along: Vector2 = Vector2.from_angle(rot) * (info.w * 0.5 * 0.85)
	var across: Vector2 = Vector2.from_angle(rot).orthogonal() * (info.h * 0.5 * 0.85)
	var roads: bool = info.road
	for q in [p, p + along, p - along, p + across, p - across]:
		if not inChunk(q, 0.0): return false
		var t := terrainAt(q)
		if not spawnable(t) || t == CONVEYOR || t == MUDPIT || t == BRIDGE: return false
		if (t == ASPHALT || t == OIL) && not roads: return false
		if not clearOf(q, PROP_MARGIN): return false
	return true

## Decor: MultiMesh buffers per decor id (12 floats an instance: the 2D transform, then custom data whose x
## picks the atlas cell), scattered over open ground by the zone's DECOR weights. {buffers, count}
func placeDecor() -> Dictionary:
	var buffers := {}
	var count := 0
	var tables: Dictionary = ctx.get("decorTables", {})
	if tables.is_empty(): return {"buffers": buffers, "count": 0}
	var picks := pickTables(tables)
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_DECOR, chunk.x, chunk.y)
	var target := roundi(float(ctx.get("decorPerChunk", 110)) * openShare())
	var decorInfo: Dictionary = ctx.get("decor", {})
	#instances go into one flat list first (each with its id's index), then one buffer per id in the order the
	#ids first came up: appending to a buffer held in a Dictionary would copy it every time
	var order := PackedStringArray()
	var slotOf := {}
	var slots := PackedInt32Array()
	var flat := PackedFloat32Array()
	for attempt in target * 3:
		if count >= target: break
		var p := Vector2(r.randf() * CHUNK.x, r.randf() * CHUNK.y)
		var entry: Array = picks.get(zoneAt(p), picks.get(majority, EMPTY_PICK))
		if entry[0].is_empty(): continue
		var id := pickFast(entry, r)
		if id == "": continue
		var info: Dictionary = decorInfo[id]
		var t := terrainAt(p)
		if not decorFits(t, p, info): continue
		var rot := r.randf() * TAU
		var sc := r.randf_range(0.8, 1.2)
		var cell := r.randi() % 4
		var slot: int = slotOf.get(id, -1)
		if slot < 0:
			slot = order.size()
			slotOf[id] = slot
			order.push_back(id)
		var c := cos(rot) * sc
		var sn := sin(rot) * sc
		slots.push_back(slot)
		flat.append_array([c, -sn, 0.0, p.x, sn, c, 0.0, p.y, (cell + 0.5) / 4.0, 0.0, 0.0, 0.0])
		count += 1
	for slot in order.size():
		var buf := PackedFloat32Array()
		for n in slots.size():
			if slots[n] == slot: buf.append_array(flat.slice(n * 12, n * 12 + 12))
		buffers[order[slot]] = buf
	return {"buffers": buffers, "count": count}

static var EMPTY_PICK := [PackedStringArray(), PackedFloat64Array(), 0.0]

func decorFits(t: int, p: Vector2, info: Dictionary) -> bool:
	if t < 0 || t >= blockedTable.size() || blockedTable[t] != 0 || t == BRIDGE || t == CONVEYOR: return false
	var road: bool = t == ASPHALT || t == OIL || t == lotTerrain
	match info.get("place", ""):
		"road": if not road: return false
		"wet": if t != SHALLOWS && fieldAt(water, p) > 0.6: return false
		"any": pass
		_: if t == ASPHALT || t == OIL || t == SHALLOWS: return false
	if fieldAt(wall, p) < 0.02: return false
	return t == SHALLOWS || fieldAt(water, p) >= 0.02
