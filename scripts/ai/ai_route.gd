class_name AIRoute extends RefCounted

#Long-range routing for the AI driver (docs/AI_DRIVER.md). A* over a grid of square cells (the world's
#coarse map: 1280 px cells, WorldGen), where every terrain World's table calls impassable (lethal water,
#walls) is solid and the rest are weighted by its routeWeight (sand and mud 1.4: the car's top speed there
#is about 2/3 of grass). The map's crossings (fords, bridges, passes) are passable cells, so routes use them.
#forWorld shares the WorldMap's own AStarGrid2D, built with the map on a worker thread; terrainAt and
#lineIsClear then read the world's fine map where it is loaded. Pure data: it never touches the scene.

var grid: AStarGrid2D
var terrain: PackedByteArray
var mapSize: Vector2i #in cells
var cellPx: Vector2
var origin: Vector2 #world px of cell (0,0)'s corner; world (0,0) is the corner of cell mapSize / 2
var map: WorldMap #the run's world, when there is one

## A route over a terrain grid (row-major, mapSizeCells cells of cellSizePx). grid: a ready AStarGrid2D for
## it (the WorldMap's) instead of building one.
func _init(terrainMap: PackedByteArray, mapSizeCells: Vector2i, cellSizePx: Vector2, sharedGrid: AStarGrid2D = null, world: WorldMap = null) -> void:
	terrain = terrainMap
	mapSize = mapSizeCells
	cellPx = cellSizePx
	origin = -Vector2(mapSize / 2) * cellPx
	map = world
	if sharedGrid != null:
		grid = sharedGrid
		return
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, mapSize.x, mapSize.y)
	grid.cell_size = cellPx
	grid.offset = origin
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES #never cut a water corner
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for y in mapSize.y:
		for x in mapSize.x:
			var type = terrain[y * mapSize.x + x]
			var cell = Vector2i(x, y)
			if isBlocked(type): grid.set_point_solid(cell)
			elif World.routeWeight(type) != 1.0: grid.set_point_weight_scale(cell, World.routeWeight(type))

## The route for the run's world: its coarse map and its A* grid
static func forWorld(world: WorldMap) -> AIRoute:
	return AIRoute.new(world.terrain, Vector2i(WorldGen.W, WorldGen.H), Vector2(WorldGen.CELL, WorldGen.CELL), world.astar, world)

static func isBlocked(type: int) -> bool:
	return not World.isPassable(type)

#terrain under a world position: the world's (fine where loaded); without one, the grid's. Off the grid is water.
func terrainAt(worldPosition: Vector2) -> int:
	if map != null: return map.terrainAt(worldPosition)
	var cell = cellOf(worldPosition)
	if cell.x < 0 || cell.y < 0 || cell.x >= mapSize.x || cell.y >= mapSize.y: return Root.terrain.WATER
	return terrain[cell.y * mapSize.x + cell.x]

func cellOf(worldPosition: Vector2) -> Vector2i:
	return Vector2i(floori((worldPosition.x - origin.x) / cellPx.x), floori((worldPosition.y - origin.y) / cellPx.y))

func cellCentre(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cellPx

const LINE_STEP := 256.0 #px between samples: two per fine-raster cell pair, so a narrow channel isn't skipped

#is the straight line from a to b on land, `margin` px clear of blocked ground on both sides
func lineIsClear(a: Vector2, b: Vector2, margin: float = 300.0) -> bool:
	var length = a.distance_to(b)
	if length < 1.0: return not isBlocked(terrainAt(a))
	var along = (b - a) / length
	var side = along.orthogonal() * margin
	var steps = ceili(length / LINE_STEP)
	for i in steps + 1:
		var p = a + along * (length * i / steps)
		if isBlocked(terrainAt(p)) || isBlocked(terrainAt(p + side)) || isBlocked(terrainAt(p - side)): return false
	return true

#world points from `from` towards `to` through land, the first being the start cell's centre.
#Empty when the start is cut off. `reached` in the result says whether the path ends at `to` (an
#island station gives a partial path to the closest reachable cell).
func plan(from: Vector2, to: Vector2) -> Dictionary:
	var a = cellOf(from)
	var b = cellOf(to)
	if not grid.is_in_boundsv(a) || not grid.is_in_boundsv(b): return {"points":PackedVector2Array(), "reached":false}
	var startSolid = grid.is_point_solid(a)
	if startSolid: grid.set_point_solid(a, false) #a car on a barrier's edge still gets a way out
	var ids = grid.get_id_path(a, b, true)
	if startSolid: grid.set_point_solid(a, true)
	var points = PackedVector2Array()
	for id in ids: points.push_back(cellCentre(id))
	return {"points":points, "reached":not ids.is_empty() && ids[ids.size() - 1] == b}

#length in px of a polyline
static func pathLength(points: PackedVector2Array) -> float:
	var total = 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	return total
