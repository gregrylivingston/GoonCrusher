class_name ChunkRecipe extends RefCounted
## What one chunk of the run's world is made of (docs/WORLD.md, "Chunk recipe"). Built on a worker thread
## right after the chunk's fine raster (WorldMap.chunkTask), cached with it, and applied on the main thread by
## ChunkView. Pure and worker-safe: it touches only its job Dictionary (no nodes, no autoloads, no global
## RNG; every random stream is WorldGen.ihash of the world seed, a tag and the chunk), so the same input
## always gives the same recipe.
##
## Job keys (besides the raster's, see WorldGen.fineRaster): ctx (WorldSkin.recipeContext: the level's
## tables, made once on the main thread and only read here), factions (PackedInt32Array: the district
## faction of the chunk's 8 coarse cells, -1 on a barrier), aux (the coarse aux bytes: belt directions).
## Writes job.recipe, a Dictionary in chunk-local px (the chunk's top-left corner is 0, 0):
##   control:  PackedByteArray, 42 x 22 RGBA8 (the chunk's 40 x 20 fine cells plus a one-cell apron) for the
##             ground shader: R the material layer of the cell's surface (water and wall cells take a
##             neighbour's surface), G the water field and B the wall field (FIELD_RANGE units either way of
##             0.5, linear), A flags (FLAG_*)
##   pieces:   Array of convex PackedVector2Array: the walls' collision (one StaticBody2D)
##   occluders: Array of open PackedVector2Array polylines along the walls, solid on the right (cull_mode 2)
##   lines:    Array of [strip index (ctx.strips), PackedVector2Array]: the shore foam and wall lips for
##             Line2D, barrier on the left, so the strip's top (v = 0) lies on it
##   decor:    {decor id: PackedFloat32Array}: a MultiMesh buffer (2D transform + custom data, 12 floats)
##   props:    Array of [id, pos, rotation, variant, bit (taken-set bit, -1 for none), occluder (bool)]
##   pickups:  Array of [pickup id (Pickups), pos, bit]
##   spots:    Array of Vector2: open places for PickupWorld.decorateChunk's props
##   counts:   {nodes, occluders, pieces, props, pickups, decor, lines, dropped}
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

#terrain ids (Root.terrain, mirrored: worker code never touches the autoload)
const WATER := 3
const SHALLOWS := 11
const ASPHALT := 8
const OIL := 10
const CONVEYOR := 13
const MUDPIT := 14
const BRIDGE := 18

var chunk := Vector2i.ZERO
var mapSeed := 0
var ctx := {}
var terrain := PackedByteArray()
var water := PackedFloat32Array()
var wall := PackedFloat32Array()
var factions := PackedInt32Array()
var majority := 0
var rng := RandomNumberGenerator.new()
var reserved: Array = [] #[centre, radius] of everything placed so far (props, pickups, spots)
var origin := Vector2.ZERO

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
	factions = job.get("factions", PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0]))
	origin = Vector2(chunk) * CHUNK
	var votes := {}
	for f in factions:
		if f >= 0: votes[f] = votes.get(f, 0) + 1
	majority = 0
	var best := -1
	for f in votes:
		if votes[f] > best:
			best = votes[f]
			majority = f
	rng.seed = WorldGen.ihash(mapSeed, TAG_RECIPE, chunk.x, chunk.y)

	var out := {"control": controlBytes(job.get("aux", PackedByteArray()), job.get("coarseW", WorldGen.W))}
	#walls: collision pieces, occluders and lips
	var wallGrid := paddedGrid(wall)
	var wallLoops := traceLoops(wallGrid, GW, GH, Vector2(-1.5, -1.5) * FINE, FINE)
	var walls := wallPieces(wallLoops)
	out.pieces = walls.pieces
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
	if waterStrip >= 0:
		var waterGrid := paddedGrid(water)
		var waterLoops := traceLoops(waterGrid, GW, GH, Vector2(-1.5, -1.5) * FINE, FINE)
		for line in splitSpan(offBridges(chains(waterLoops, LINE_SIMPLIFY, waterGrid)), SPAN): lines.push_back([waterStrip, reversed(line)])
	lines.sort_custom(func(a, b): return polyLength(a[1]) > polyLength(b[1]))
	while lines.size() > MAX_LINES:
		lines.pop_back()
		dropped += 1
	out.lines = lines

	#things on the ground: decorateChunk's spots first, then pickups, then props, then decor
	resetReservations()
	out.spots = placeSpots()
	out.pickups = placePickups()
	var props := placeProps()
	var decor := placeDecor()
	out.decor = decor.buffers

	#the node budget: ground quads, the body, occluders, lines, one MultiMesh per decor id, then props
	var fixed: int = GROUND_NODES + (1 if not out.pieces.is_empty() else 0) + occluders.size() + lines.size() + decor.buffers.size()
	var occluderRoom := MAX_OCCLUDERS - occluders.size()
	var nodes: int = fixed
	var kept: Array = []
	for p in props:
		var info: Dictionary = ctx.props[p[0]]
		var cost: int = info.nodes
		var occ: bool = info.occluder && occluderRoom > 0
		if info.occluder && not occ: cost -= 1 #placed without its occluder
		if nodes + cost > MAX_NODES:
			dropped += 1
			continue
		if occ: occluderRoom -= 1
		nodes += cost
		p[5] = occ
		kept.push_back(p)
	out.props = kept
	var propOccluders := 0
	for p in kept:
		if p[5]: propOccluders += 1
	out.counts = {"nodes": nodes, "occluders": occluders.size() + propOccluders, "pieces": out.pieces.size(),
		"props": kept.size(), "pickups": out.pickups.size(), "decor": decor.count, "lines": lines.size(),
		"dropped": dropped, "simplify": SIMPLIFY[walls.level]}
	return out

#--- control texture ---------------------------------------------------------------------------------

static func encodeField(f: float) -> int:
	return clampi(roundi((f / FIELD_RANGE * 0.5 + 0.5) * 255.0), 0, 255)

## The 42 x 22 RGBA8 control block (see the class comment)
func controlBytes(aux: PackedByteArray, coarseW: int) -> PackedByteArray:
	var blocked: PackedByteArray = ctx.blocked
	var layerOf: PackedByteArray = ctx.layerOf
	var mainLayer: int = ctx.get("mainLayer", 0)
	#surface ids over the apron: own cells, the apron copying the nearest own cell
	var surf := PackedInt32Array()
	surf.resize(RW * RH)
	for j in RH:
		for i in RW:
			surf[j * RW + i] = terrain[clampi(j - 1, 0, FH - 1) * FW + clampi(i - 1, 0, FW - 1)]
	#water and wall cells take a passable neighbour's surface (a few dilation passes, then the main ground)
	var layers := PackedInt32Array()
	layers.resize(RW * RH)
	for k in RW * RH:
		var t := surf[k]
		layers[k] = -1 if blocked[t] != 0 else layerOf[t]
	for pass_ in 6:
		var changed := false
		var next := layers.duplicate()
		for j in RH:
			for i in RW:
				var k := j * RW + i
				if layers[k] >= 0: continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var x: int = i + d.x
					var y: int = j + d.y
					if x < 0 || y < 0 || x >= RW || y >= RH: continue
					if layers[y * RW + x] >= 0:
						next[k] = layers[y * RW + x]
						changed = true
						break
		layers = next
		if not changed: break
	var out := PackedByteArray()
	out.resize(RW * RH * 4)
	var cell0 := WorldGen.cellOf(origin)
	for j in RH:
		for i in RW:
			var k := j * RW + i
			var t := surf[k]
			var flags := 0
			if t == BRIDGE:
				flags |= FLAG_BRIDGE
				if runLength(surf, i, j, Vector2i(0, 1)) > runLength(surf, i, j, Vector2i(1, 0)): flags |= FLAG_ROTATE
			elif t == CONVEYOR:
				flags |= FLAG_BELT
				var cx := clampi(floori(((i - 0.5) * FINE) / WorldGen.CELL), 0, 3) + cell0.x
				var cy := clampi(floori(((j - 0.5) * FINE) / WorldGen.CELL), 0, 1) + cell0.y
				var code := 1
				if not aux.is_empty() && cx >= 0 && cy >= 0 && cx < coarseW && cy * coarseW + cx < aux.size(): code = aux[cy * coarseW + cx]
				if code == 3 || code == 4: flags |= FLAG_ROTATE
				if code == 2 || code == 4: flags |= FLAG_REVERSE
			out[k * 4] = layers[k] if layers[k] >= 0 else mainLayer
			out[k * 4 + 1] = encodeField(water[k])
			out[k * 4 + 2] = encodeField(wall[k])
			out[k * 4 + 3] = flags
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
		for i in gw - 1:
			var a := v[j * gw + i]
			var b := v[j * gw + i + 1]
			var c := v[(j + 1) * gw + i + 1]
			var d := v[(j + 1) * gw + i]
			var code := (1 if a < 0.0 else 0) | (2 if b < 0.0 else 0) | (4 if c < 0.0 else 0) | (8 if d < 0.0 else 0)
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

func factionAt(p: Vector2) -> int:
	var f := factions[clampi(floori(p.y / WorldGen.CELL), 0, 1) * 4 + clampi(floori(p.x / WorldGen.CELL), 0, 3)]
	return f if f >= 0 else majority

## Outside every reservation: the start's core, station lots, Defense lanes, things already placed
func isFree(p: Vector2, radius: float) -> bool:
	var w := origin + p
	var start: Vector2 = ctx.get("start", Vector2.INF)
	if w.distance_to(start) < START_CORE + radius: return false
	for lot in ctx.get("lots", []):
		if lot.grow(radius).has_point(w): return false
	for lane in ctx.get("lanes", []):
		if Geometry2D.get_closest_point_to_segment(w, lane[0], lane[1]).distance_to(w) < LANE_HALF + radius: return false
	for r in reserved:
		if p.distance_to(r[0]) < r[1] + radius: return false
	return true

func resetReservations() -> void:
	reserved.clear()

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
		reserved.push_back([p, 450.0])
	return out

func spawnable(t: int) -> bool:
	var s: PackedByteArray = ctx.spawnable
	return t >= 0 && t < s.size() && s[t] != 0

## The level's pickups: pickupsPerChunk kinds from pickupTable, each on open spawnable ground. Bits number
## them for the taken set (coins one each); past bit 31 a pickup has none and comes back on a reload.
func placePickups() -> Array:
	var out: Array = []
	var table: Dictionary = ctx.get("pickupTable", {})
	var total := 0.0
	for k in table: total += float(table[k])
	if total <= 0.0: return out
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_PICKUP, chunk.x, chunk.y)
	var bit := 0
	for n in int(ctx.get("pickupsPerChunk", 0)):
		var roll := r.randf() * total
		var kind := ""
		for k in table:
			roll -= float(table[k])
			if roll < 0.0:
				kind = String(k)
				break
		if kind == "": kind = String(table.keys().back())
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
					reserved.push_back([c, 70.0])
				break
		else:
			var id: String = ctx.get("pickupIds", {}).get(kind, kind)
			for attempt in 30:
				var p := Vector2(r.randf_range(200.0, CHUNK.x - 200.0), r.randf_range(200.0, CHUNK.y - 200.0))
				if not pickupFits(p, 90.0): continue
				out.push_back([id, p, bit if bit < 32 else -1])
				bit += 1
				reserved.push_back([p, 90.0])
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

## Open share of the chunk (passable fine cells)
func openShare() -> float:
	var blocked: PackedByteArray = ctx.blocked
	var open := 0
	for t in terrain:
		if blocked[t] == 0: open += 1
	return float(open) / terrain.size()

## Props by the dressing of each spot's district faction (LOW, TALL, STATEFUL, WALL from props.json), Poisson
## spaced by dart throwing: never on a blocked, lethal, shallows, bridge or belt cell, never on a road
## unless the prop belongs there, clear of water and walls and of every reservation. Linear props (fences,
## hedges, barriers) come in short chains.
func placeProps() -> Array:
	var out: Array = []
	var tables: Dictionary = ctx.get("propTables", {})
	if tables.is_empty(): return out
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_PROP, chunk.x, chunk.y)
	var target := roundi(float(ctx.get("propsPerChunk", 16)) * openShare())
	var breakBit := 32
	for attempt in target * 14:
		if out.size() >= target: break
		var p := Vector2(r.randf_range(100.0, CHUNK.x - 100.0), r.randf_range(100.0, CHUNK.y - 100.0))
		var table: Dictionary = tables.get(factionAt(p), tables.get(majority, {}))
		if table.is_empty(): table = tables.values()[0]
		var id := pickFrom(table, r)
		if id == "": continue
		var info: Dictionary = ctx.props[id]
		var rot := r.randf() * TAU
		var count := 1
		if info.chain: count = r.randi_range(2, 4)
		var axis := Vector2.from_angle(rot)
		var step: float = info.w * 0.96
		var placed: Array = []
		for c in count:
			var q := p + axis * step * c
			if not propFits(q, rot, info, id): break
			placed.push_back(q)
		if placed.is_empty(): continue
		for q in placed:
			var bit := -1
			if info.breakable && breakBit < 63:
				bit = breakBit
				breakBit += 1
			out.push_back([id, q, rot, r.randi() % maxi(int(info.variants), 1), bit, info.occluder])
			reserved.push_back([q, info.radius + PROP_GAP * 0.5])
		if out.size() >= target: break
	return out

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
## picks the atlas cell), scattered over open ground by the faction's DECOR weights. {buffers, count}
func placeDecor() -> Dictionary:
	var buffers := {}
	var count := 0
	var tables: Dictionary = ctx.get("decorTables", {})
	if tables.is_empty(): return {"buffers": buffers, "count": 0}
	var r := RandomNumberGenerator.new()
	r.seed = WorldGen.ihash(mapSeed, TAG_DECOR, chunk.x, chunk.y)
	var target := roundi(float(ctx.get("decorPerChunk", 110)) * openShare())
	var decorInfo: Dictionary = ctx.get("decor", {})
	for attempt in target * 3:
		if count >= target: break
		var p := Vector2(r.randf() * CHUNK.x, r.randf() * CHUNK.y)
		var table: Dictionary = tables.get(factionAt(p), tables.get(majority, {}))
		if table.is_empty(): continue
		var id := pickFrom(table, r)
		if id == "": continue
		var info: Dictionary = decorInfo[id]
		var t := terrainAt(p)
		if not decorFits(t, p, info): continue
		var rot := r.randf() * TAU
		var s := r.randf_range(0.8, 1.2)
		var cell := r.randi() % 4
		var buf: PackedFloat32Array = buffers.get(id, PackedFloat32Array())
		var c := cos(rot) * s
		var sn := sin(rot) * s
		buf.append_array(PackedFloat32Array([c, -sn, 0.0, p.x, sn, c, 0.0, p.y, (cell + 0.5) / 4.0, 0.0, 0.0, 0.0]))
		buffers[id] = buf
		count += 1
	return {"buffers": buffers, "count": count}

func decorFits(t: int, p: Vector2, info: Dictionary) -> bool:
	var blocked: PackedByteArray = ctx.blocked
	if t < 0 || t >= blocked.size() || blocked[t] != 0 || t == BRIDGE || t == CONVEYOR: return false
	var road: bool = t == ASPHALT || t == OIL || t == ctx.get("lotTerrain", 16)
	match info.get("place", ""):
		"road": if not road: return false
		"wet": if t != SHALLOWS && fieldAt(water, p) > 0.6: return false
		"any": pass
		_: if t == ASPHALT || t == OIL || t == SHALLOWS: return false
	if fieldAt(wall, p) < 0.02: return false
	return t == SHALLOWS || fieldAt(water, p) >= 0.02
