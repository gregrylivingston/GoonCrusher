extends GameTest

#The GDExtension in native/ must be built and loaded (docs/NATIVE.md). If this fails, run
#`scons` in native/. The version must match NATIVE_VERSION in native/src/goon_native.cpp.
#The native code replaces GDScript that is still here, so these tests hold the two to the same answers:
#WorldGrid against WorldMap's queries and WorldHooks' grid walks on a generated map, and GoonBody's helpers
#against the rules they were moved from.

const NATIVE_VERSION = "2"

var savedMap
var savedView: Rect2
var savedManager

func before_each():
	savedMap = Root.worldMap
	savedView = GoonBody.getPhysicsView()
	savedManager = Root.spawnManager

func after_each():
	Root.worldMap = savedMap
	GoonBody.setPhysicsView(savedView)
	Root.spawnManager = savedManager

func test_native_library_loads():
	assert_true(ClassDB.class_exists("GoonNative"), "bin/windows has no gooncrusher DLL; run scons in native/")
	if not ClassDB.class_exists("GoonNative"): return
	assert_eq(ClassDB.class_call_static("GoonNative", "version"), NATIVE_VERSION, "stale DLL; rebuild native/")

#--- WorldGrid ---------------------------------------------------------------------------------------

#a map with water and walls, and the 3 x 3 chunks round its start rasterised
func builtMap() -> WorldMap:
	var map := WorldMap.build(1337, Levels.get_def(&"canyon"))
	var center := WorldGen.chunkOf(map.startPosition)
	for dy in range(-1, 2):
		for dx in range(-1, 2): map.buildNow(center + Vector2i(dx, dy))
	return map

#points over the rasterised chunks and the coarse map round them, plus chunk and cell edges
func samplePoints(map: WorldMap, count: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var span := World.CHUNK_PX * 2.5
	var out := PackedVector2Array()
	for i in count:
		out.push_back(map.startPosition + Vector2(rng.randf_range(-span.x, span.x), rng.randf_range(-span.y, span.y)))
	var corner := Vector2(WorldGen.chunkOf(map.startPosition)) * World.CHUNK_PX
	for e in [-0.01, 0.0, 0.01, WorldGen.FINE - 0.01, WorldGen.FINE]:
		out.push_back(corner + Vector2(e, e))
		out.push_back(corner + Vector2(World.CHUNK_PX.x + e, World.CHUNK_PX.y - e))
	out.push_back(Vector2(1e7, -1e7)) #off the map: water
	return out

func test_the_grid_answers_like_the_world_map():
	var map := builtMap()
	assert_eq(map.grid.chunkCount(), 9, "every stored raster is mirrored")
	var mismatches := 0
	for p in samplePoints(map, 4000):
		var t := map.terrainAt(p) #the GDScript query
		if map.grid.terrainAt(p) != t || map.grid.lethalAt(p) != World.isLethal(t) || map.grid.blockedAt(p) != World.isBlocked(t) \
			|| map.grid.spawnableAt(p) != World.isSpawnable(t) || map.grid.wallAt(p) != World.isWallTerrain(t):
			mismatches += 1
	assert_eq(mismatches, 0, "native and GDScript terrain agree")
	var chunk := WorldGen.chunkOf(map.startPosition)
	map.forget(chunk)
	assert_eq(map.grid.chunkCount(), 8, "a forgotten raster leaves the grid")
	var inside := Vector2(chunk) * World.CHUNK_PX + Vector2(700, 300)
	assert_eq(map.grid.terrainAt(inside), map.coarseTerrainAt(inside), "and its chunk reads the coarse map again")

func test_world_uses_the_grid_of_a_real_map_only():
	var map := builtMap()
	Root.worldMap = map
	assert_eq(World.grid, map.grid, "a WorldMap's grid answers World")
	assert_eq(WorldGrid.getCurrent(), map.grid, "and the goons")
	Root.worldMap = RefCounted.new()
	assert_null(World.grid, "a stand-in map goes through GDScript")
	assert_null(WorldGrid.getCurrent())
	Root.worldMap = null
	assert_null(World.grid)

func test_the_grid_walks_match_world_hooks():
	var map := builtMap()
	Root.worldMap = map
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mismatches := []
	for p in samplePoints(map, 1500):
		var step := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 200.0)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var radius := rng.randf_range(50.0, 500.0)
		var b := p + dir * rng.randf_range(0.0, 1500.0)
		var native := [WorldHooks.slideStep(p, step), WorldHooks.nearLethal(p, radius), WorldHooks.lethalAhead(p, dir, radius * 2.0),
			WorldHooks.lineClear(p, b), WorldHooks.bounce(p, step * 60.0, 1.0 / 60.0), WorldHooks.wallAt(p)]
		World.grid = null #the GDScript rules, through the same map
		var script := [WorldHooks.slideStep(p, step), WorldHooks.nearLethal(p, radius), WorldHooks.lethalAhead(p, dir, radius * 2.0),
			WorldHooks.lineClear(p, b), WorldHooks.bounce(p, step * 60.0, 1.0 / 60.0), WorldHooks.wallAt(p)]
		World.grid = map.grid
		if native != script: mismatches.push_back([p, native, script])
	assert_eq(mismatches.size(), 0, "native and GDScript hooks agree %s" % str(mismatches.slice(0, 3)))

#--- GoonBody ----------------------------------------------------------------------------------------

#deep water west of x = 0, grass east of it (no native grid: GoonBody calls back into GDScript)
class WestWater extends RefCounted:
	func terrainAt(pos: Vector2) -> int: return Root.terrain.WATER if pos.x < 0.0 else Root.terrain.GRASS
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))

func spawnGoon(at := Vector2.ZERO) -> Walker:
	add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())
	var goon: Walker = load(Goons.scenePath(&"grunt")).instantiate()
	goon.position = at
	add_child_autofree(goon)
	return goon

func test_goon_fields_and_state_live_on_the_native_body():
	var goon := spawnGoon()
	assert_true(goon is GoonBody)
	assert_almost_eq(goon.speed, float(Goons.DATA[&"grunt"].get("speed", 110.0)), 0.001, "tuning comes from Goons.DATA")
	assert_gt(goon.bodyRadius, 0.0, "the baked scene sets bodyRadius")
	goon.setState(&"windup")
	assert_eq(goon.myMode, Walker.mode.PREPAREATTACK)
	goon.setState(&"roll")
	assert_eq(goon.myMode, Walker.mode.ATTACK)
	goon.setState(&"flee")
	assert_eq(goon.myMode, Walker.mode.MOVE)
	goon.setState(&"stun")
	assert_eq(goon.myMode, Walker.mode.IDLE)
	assert_eq(goon.state, &"stun")
	assert_eq(goon.stateTime, 0.0)
	var base: float = goon.speedNow()
	goon.buffUntil = GoonVerbs.now() + 10.0
	assert_true(goon.isBuffed())
	assert_almost_eq(goon.speedNow(), base * Goons.DATA[&"foreman"]["buff"], 0.001, "a foreman's buff")

func test_goons_turn_at_their_turn_rate():
	var goon := spawnGoon()
	goon.rotation = 0.0
	goon.turnRate = 2.0
	goon.faceTo(PI / 2, 0.1)
	assert_almost_eq(goon.rotation, 0.2, 0.0001, "turnRate x delta per tick")
	goon.faceTo(0.25, 1.0, 10.0)
	assert_almost_eq(goon.rotation, 0.25, 0.0001, "and never past the target")

func test_off_screen_goons_slide_on_the_grid():
	var goon := spawnGoon(Vector2(10, 0))
	Root.worldMap = WestWater.new()
	GoonBody.setPhysicsView(Rect2(5000, 5000, 100, 100)) #the goon is off screen
	assert_false(GoonBody.needsFullPhysics(goon.global_position))
	goon.advance(Vector2(-600, 300), 1.0 / 60.0)
	assert_almost_eq(goon.global_position.x, 10.0, 0.001, "it won't walk into the water unseen")
	assert_almost_eq(goon.global_position.y, 5.0, 0.001, "but slides along the shore")
	goon.global_position = Vector2(-10, 0)
	assert_true(goon.overDeepWater(goon), "standing in the lake")
	GoonBody.setPhysicsView(Rect2())
	assert_true(GoonBody.needsFullPhysics(Vector2(1e6, 1e6)), "no view: full physics everywhere")

#--- WorldGenNative ----------------------------------------------------------------------------------

#a coarse build stopped where the crossings are cut (WorldGen.run's steps up to there)
func buildUpToCrossings(id: StringName) -> WorldGen:
	var job := WorldMap.jobFor(1337, Levels.get_def(id))
	var b := WorldGen.new()
	b.seedValue = int(job.seed)
	b.def = job.def
	b.weights = job.weights
	b.field = WorldField.make(b.seedValue, b.def)
	if not b.field.colFlag.is_empty(): b.def["_lattice"] = b.field.lattice()
	b.startPos = b.def.get("startPosition", Vector2.ZERO)
	var cell := WorldGen.cellOf(b.startPos)
	b.startIndex = cell.y * WorldGen.W + cell.x
	b.sampleCells()
	b.grammarPost()
	b.shareCaps()
	b.startBubble()
	return b

func test_native_hash_matches():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var args := [rng.randi() - 2147483648, rng.randi_range(0, 20), rng.randi_range(-100000, 100000), rng.randi_range(-5, 5)]
		assert_eq(WorldGenNative.ihash(args[0], args[1], args[2], args[3]), WorldGen.ihash(args[0], args[1], args[2], args[3]), str(args))

func test_native_crossings_match_the_gdscript_build():
	for id in [&"prairie", &"canyon", &"crusher"]:
		var native := buildUpToCrossings(id)
		var script := buildUpToCrossings(id)
		assert_eq(native.flags, script.flags, "%s: the same start" % id)
		var short := WorldGen.barrierExtents(native.flags)
		assert_eq(short, WorldGen.barrierExtentsGDScript(script.flags), "%s: short barriers" % id)
		native.shortBarrier = short
		script.shortBarrier = short
		for alongX in [true, false, true]:
			native.cutCrossings(alongX)
			script.cutCrossingsGDScript(alongX)
		assert_gt(script.crossings.size(), 0, "%s cuts crossings" % id)
		assert_eq(native.crossings, script.crossings, "%s: crossings" % id)
		assert_eq(native.flags, script.flags, "%s: flags" % id)
		assert_eq(native.terrain, script.terrain, "%s: terrain" % id)
		assert_eq(native.cover, script.cover, "%s: cover" % id)
