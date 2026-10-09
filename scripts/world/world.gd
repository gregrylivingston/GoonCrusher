class_name World extends RefCounted
## The terrain table and the runtime map queries (docs/WORLD.md). Static only.
##
## TERRAIN is indexed by Root.terrain id (append-only; Goons.T mirrors the enum and test_goons and
## test_world check all three agree). Fields:
##   name, letter (playtest --trace map), friction (on the car's scale; see effectiveFriction),
##   grip (multiplies the car's grip after gripFor's clamp), brake (multiplies the brake force),
##   push (conveyor speed in px/s), passable, lethal, wall, routeWeight (AIRoute A* weight; 0 when
##   blocked), spawnable (goons, pickups and objectives may go there), hurt (health per second the car loses
##   there before armor, through damage(): wading depth and deep water; OverheadCarBody2D.checkGround).
## `lethal` is deep water for everything but the car: goons drown in it, nothing spawns near it, the AI never
## plans through it, tethers break by it. The car survives a short swim; it hurts (`hurt`) and drags (its row).
##
## Runtime queries (terrainAt, surfaceAt, lethalAt, blockedAt, spawnableAt, pushAt) are called every
## physics tick by the car and ~900 times per AI plan through integrate(), so they never allocate and
## only touch cached references. They delegate to the live WorldMap (Root.worldMap: the fine raster of a
## loaded chunk, the coarse map elsewhere); anything standing in for it (tests) must provide
## terrainAt(pos) -> int, surfaceAt(pos) -> int, lethalAt(pos) -> bool, blockedAt(pos) -> bool and
## spawnableAt(pos) -> bool, and may provide beltDirAt(pos) -> Vector2. Without one they answer UNKNOWN
## (-1): no map is loaded yet (the menu, tests, the first frames of a run), nothing is lethal or blocked
## there, and the car keeps its own base friction.
##
## A real WorldMap mirrors its terrain into a native WorldGrid (native/src/world_grid.cpp), which Root's
## worldMap setter puts in `grid`; the queries then answer from it in one native call.

const UNKNOWN := -1
const GRASS_FRICTION := 0.13 #the off-road rule's baseline
const OFFROAD_ARMOR_SCALE := 200.0 #armor / this is the share of extra friction ignored...
const OFFROAD_ARMOR_MAX := 0.35    #...up to this share
const CHUNK_PX := Vector2(5120, 2560)

const TERRAIN := [
	{"name":"GRASS",    "letter":"g", "friction":0.13, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"SAND",     "letter":"s", "friction":0.5,  "grip":0.9,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.4, "spawnable":true,  "hurt":0.0},
	{"name":"MUD",      "letter":"m", "friction":0.6,  "grip":0.8,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.4, "spawnable":true,  "hurt":0.0},
	{"name":"WATER",    "letter":"~", "friction":0.9,  "grip":0.3,  "brake":0.5, "push":0.0,   "passable":false, "lethal":true,  "wall":false, "routeWeight":0.0, "spawnable":false, "hurt":33.0},
	{"name":"HILLS",    "letter":"^", "friction":0.13, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":false, "lethal":false, "wall":true,  "routeWeight":0.0, "spawnable":false, "hurt":0.0},
	{"name":"MOSS",     "letter":"o", "friction":0.08, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"DIRT",     "letter":"d", "friction":0.03, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"SNOW",     "letter":"*", "friction":0.3,  "grip":0.85, "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.2, "spawnable":true,  "hurt":0.0},
	{"name":"ASPHALT",  "letter":"=", "friction":0.02, "grip":1.1,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"ICE",      "letter":"i", "friction":0.05, "grip":0.35, "brake":0.5, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.3, "spawnable":true,  "hurt":0.0},
	{"name":"OIL",      "letter":"%", "friction":0.03, "grip":0.25, "brake":0.4, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.3, "spawnable":true,  "hurt":0.0},
	{"name":"SHALLOWS", "letter":"-", "friction":0.45, "grip":0.7,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.4, "spawnable":false, "hurt":0.0},
	{"name":"WASH",     "letter":"w", "friction":0.02, "grip":0.9,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"CONVEYOR", "letter":">", "friction":0.03, "grip":1.0,  "brake":1.0, "push":250.0, "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"MUDPIT",   "letter":"@", "friction":1.0,  "grip":0.7,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":2.0, "spawnable":true,  "hurt":0.0},
	{"name":"DEEPSNOW", "letter":"#", "friction":0.6,  "grip":0.8,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.4, "spawnable":true,  "hurt":0.0},
	{"name":"LOT",      "letter":"l", "friction":0.03, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"BUILDING", "letter":"B", "friction":0.13, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":false, "lethal":false, "wall":true,  "routeWeight":0.0, "spawnable":false, "hurt":0.0},
	{"name":"BRIDGE",   "letter":"b", "friction":0.03, "grip":1.0,  "brake":1.0, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":1.0, "spawnable":true,  "hurt":0.0},
	{"name":"WADE",     "letter":"v", "friction":0.75, "grip":0.45, "brake":0.6, "push":0.0,   "passable":true,  "lethal":false, "wall":false, "routeWeight":2.5, "spawnable":false, "hurt":2.0},
]

#flat copies of the hot columns, built once from TERRAIN
static var _friction := PackedFloat32Array()
static var _grip := PackedFloat32Array()
static var _brake := PackedFloat32Array()
static var _push := PackedFloat32Array()
static var _hurt := PackedFloat32Array()
static var _flags := PackedByteArray() #FLAG_* bits
const FLAG_PASSABLE := 1
const FLAG_LETHAL := 2
const FLAG_WALL := 4
const FLAG_SPAWNABLE := 8

## The live WorldMap's native grid (set with Root.worldMap), or null for a stand-in or no map
static var grid: WorldGrid = null

static func _static_init() -> void:
	for d in TERRAIN:
		_friction.push_back(d.friction)
		_grip.push_back(d.grip)
		_brake.push_back(d.brake)
		_push.push_back(d.push)
		_hurt.push_back(d.hurt)
		_flags.push_back((FLAG_PASSABLE if d.passable else 0) | (FLAG_LETHAL if d.lethal else 0) \
			| (FLAG_WALL if d.wall else 0) | (FLAG_SPAWNABLE if d.spawnable else 0))

#--- the table -----------------------------------------------------------------------------------

static func count() -> int:
	return TERRAIN.size()

## The row for a terrain id (GRASS's for an unknown id).
static func def(t: int) -> Dictionary:
	return TERRAIN[t] if t >= 0 && t < TERRAIN.size() else TERRAIN[0]

static func _flag(t: int, flag: int) -> bool:
	return t >= 0 && t < _flags.size() && (_flags[t] & flag) != 0

static func isPassable(t: int) -> bool: return _flag(t, FLAG_PASSABLE)
static func isLethal(t: int) -> bool: return _flag(t, FLAG_LETHAL)
static func isWallTerrain(t: int) -> bool: return _flag(t, FLAG_WALL)
static func isSpawnable(t: int) -> bool: return _flag(t, FLAG_SPAWNABLE)
## Water or wall: what the chunk map, A* and the AI treat as solid.
static func isBlocked(t: int) -> bool: return t >= 0 && t < _flags.size() && (_flags[t] & FLAG_PASSABLE) == 0

static func friction(t: int) -> float: return _friction[t] if t >= 0 && t < _friction.size() else GRASS_FRICTION
static func grip(t: int) -> float: return _grip[t] if t >= 0 && t < _grip.size() else 1.0
static func brake(t: int) -> float: return _brake[t] if t >= 0 && t < _brake.size() else 1.0
static func push(t: int) -> float: return _push[t] if t >= 0 && t < _push.size() else 0.0
static func hurt(t: int) -> float: return _hurt[t] if t >= 0 && t < _hurt.size() else 0.0
static func routeWeight(t: int) -> float: return def(t).routeWeight
static func letter(t: int) -> String: return def(t).letter if t >= 0 && t < TERRAIN.size() else "?"

## The off-road rule: friction above grass is softened by armor (heavy cars plough through), at most
## OFFROAD_ARMOR_MAX of the extra. f_eff = 0.13 + (f - 0.13) * (1 - clamp(armor / 200, 0, 0.35)).
static func effectiveFriction(f: float, armor: float) -> float:
	if f <= GRASS_FRICTION: return f
	return GRASS_FRICTION + (f - GRASS_FRICTION) * (1.0 - clampf(armor / OFFROAD_ARMOR_SCALE, 0.0, OFFROAD_ARMOR_MAX))

## Something the car and goons bounce off: rocks, walls, station buildings (StaticBody2D) and the
## terrain TileMaps' collision. GoonBody::advance (native/src/goon_body.cpp) makes the same check for goons;
## moving terrain to TileMapLayer must update both.
static func isWall(collider: Object) -> bool:
	return collider is StaticBody2D || collider is TileMap

#--- runtime queries -----------------------------------------------------------------------------

## Kept for callers that reset between maps (tests); the queries hold no cache of their own any more
static func resetCache() -> void:
	pass

## The terrain id under a world position, UNKNOWN before a map is loaded. Outside the map is WATER.
static func terrainAt(pos: Vector2) -> int:
	if grid != null: return grid.terrainAt(pos)
	if Root.worldMap != null: return Root.worldMap.terrainAt(pos)
	return UNKNOWN

## The ground the car drives on (friction, grip, brake, push); a bridge deck over water, say.
static func surfaceAt(pos: Vector2) -> int:
	if grid != null: return grid.terrainAt(pos)
	if Root.worldMap != null: return Root.worldMap.surfaceAt(pos)
	return UNKNOWN

static func lethalAt(pos: Vector2) -> bool:
	if grid != null: return grid.lethalAt(pos)
	if Root.worldMap != null: return Root.worldMap.lethalAt(pos)
	return false

## Water or wall under the point (goons slide or hold, projectiles stop).
static func blockedAt(pos: Vector2) -> bool:
	if grid != null: return grid.blockedAt(pos)
	if Root.worldMap != null: return Root.worldMap.blockedAt(pos)
	return false

static func spawnableAt(pos: Vector2) -> bool:
	if grid != null: return grid.spawnableAt(pos)
	if Root.worldMap != null: return Root.worldMap.spawnableAt(pos)
	return false

## The conveyor push (px/s, as a vector) on surface `t` at `pos`. The belt direction is stored per
## coarse cell by the WorldMap (beltDirAt); a stand-in without one runs every belt along +x.
static func pushAt(pos: Vector2, t: int) -> Vector2:
	var speed := push(t)
	if speed <= 0.0: return Vector2.ZERO
	var dir := Vector2.RIGHT
	if Root.worldMap != null && Root.worldMap.has_method("beltDirAt"): dir = Root.worldMap.beltDirAt(pos)
	return dir * speed
