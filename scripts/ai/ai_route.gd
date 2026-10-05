class_name AIRoute extends RefCounted

#Long-range routing for the AI driver (docs/AI_DRIVER.md). A* over the terrain map, where water
#(instant death: its Area2D covers the whole chunk) and hills (walls) are solid. A chunk is
#5120x2560 px, so each is split into two square cells of 2560 px to keep A* distances true.
#Pure data: it reads the landscapeGenerator's terrainMap and never touches the scene.

const SPLIT = 2 #cells per chunk along x
const SLOW_WEIGHT = 1.4 #sand and mud: the car's top speed there is about 2/3 of grass
const SNOW_WEIGHT = 1.2

var grid := AStarGrid2D.new()
var terrain: PackedByteArray
var mapSize: Vector2i #in chunks
var chunkPx: Vector2
var cellPx: Vector2

func _init(terrainMap: PackedByteArray, mapSizeChunks: Vector2i, chunkSizePx: Vector2) -> void:
	terrain = terrainMap
	mapSize = mapSizeChunks
	chunkPx = chunkSizePx
	cellPx = Vector2(chunkPx.x / SPLIT, chunkPx.y)
	grid.region = Rect2i(0, 0, mapSize.x * SPLIT, mapSize.y)
	grid.cell_size = cellPx
	grid.offset = -Vector2(mapSize / 2) * chunkPx #cell (0,0) of chunk (0,0) is map cell size/2
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES #never cut a water corner
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	for y in mapSize.y:
		for x in mapSize.x:
			var type = terrain[y * mapSize.x + x]
			for sx in SPLIT:
				var cell = Vector2i(x * SPLIT + sx, y)
				if isBlocked(type): grid.set_point_solid(cell)
				elif type == Root.terrain.SAND || type == Root.terrain.MUD: grid.set_point_weight_scale(cell, SLOW_WEIGHT)
				elif type == Root.terrain.SNOW: grid.set_point_weight_scale(cell, SNOW_WEIGHT)

static func isBlocked(type: int) -> bool:
	return type == Root.terrain.WATER || type == Root.terrain.HILLS

#terrain under a world position; outside the map is water
func terrainAt(worldPosition: Vector2) -> int:
	var x = floori(worldPosition.x / chunkPx.x) + mapSize.x / 2
	var y = floori(worldPosition.y / chunkPx.y) + mapSize.y / 2
	if x < 0 || y < 0 || x >= mapSize.x || y >= mapSize.y: return Root.terrain.WATER
	return terrain[y * mapSize.x + x]

func cellOf(worldPosition: Vector2) -> Vector2i:
	return Vector2i(floori(worldPosition.x / cellPx.x) + mapSize.x / 2 * SPLIT, floori(worldPosition.y / cellPx.y) + mapSize.y / 2)

func cellCentre(cell: Vector2i) -> Vector2:
	return grid.offset + (Vector2(cell) + Vector2(0.5, 0.5)) * cellPx

#is the straight line from a to b on land, `margin` px clear of blocked chunks on both sides
func lineIsClear(a: Vector2, b: Vector2, margin: float = 300.0) -> bool:
	var length = a.distance_to(b)
	if length < 1.0: return not isBlocked(terrainAt(a))
	var along = (b - a) / length
	var side = along.orthogonal() * margin
	var steps = ceili(length / 400.0)
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
	if startSolid: grid.set_point_solid(a, false) #a car on a hill edge still gets a way out
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
