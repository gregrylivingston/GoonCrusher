extends GameTest

#Water and the car (docs/WORLD.md, "Water and the car"): wading depth (WADE) and deep WATER hurt the car
#through damage() once a tick and drag it through their rows in integrate(); a stock sedan crosses a short
#strip of deep water flat out and survives, and sitting in it wrecks the car as a drowning. Goons still drown
#in deep water and wade slowly through WADE. The raster puts a wading band inside deep water on grammars with
#shallows and none on the city's canals or lava; the native grid answers WADE like the GDScript.

const DT := 1.0 / 60.0
const SEDAN := "res://scene/car/sedan/sedan_info.tres"

#deep water between x0 and x1, a wading band `wade` px wide either side of it, grass elsewhere
class StripMap extends RefCounted:
	var x0 := 0.0
	var x1 := 300.0
	var wade := 0.0
	func terrainAt(pos: Vector2) -> int:
		if pos.x >= x0 && pos.x < x1: return Root.terrain.WATER
		if wade > 0.0 && pos.x >= x0 - wade && pos.x < x1 + wade: return Root.terrain.WADE
		return Root.terrain.GRASS
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))

#one terrain everywhere
class FlatMap extends RefCounted:
	var terrain := 0
	func terrainAt(_pos: Vector2) -> int: return terrain
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))

#counts destroy() instead of exploding (no level in the tests)
class TestCar extends OverheadCarBody2D:
	var destroyed := 0
	func destroy():
		destroyed += 1
		isWrecked = true

var savedMap
var savedManager
var savedCar
var cars: Array = []

func before_each():
	savedMap = Root.worldMap
	savedManager = Root.spawnManager
	savedCar = Root.playerCar

func after_each():
	Root.worldMap = savedMap
	Root.spawnManager = savedManager if is_instance_valid(savedManager) else null
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null
	World.resetCache()
	for car in cars: car.free()
	cars.clear()

## A stock sedan (its CarInfo's stats, no upgrades), outside the tree
func sedan() -> TestCar:
	var car := TestCar.new()
	car.info = load(SEDAN)
	cars.push_back(car)
	return car

func flat(terrain: int) -> FlatMap:
	var map := FlatMap.new()
	map.terrain = terrain
	Root.worldMap = map
	return map

func throttle() -> OverheadCarBody2D.CarInput:
	var i := OverheadCarBody2D.CarInput.new()
	i.acceleration = 1.0
	return i

## Drives the car flat out along +x from `from` (a long run-up on grass) until it is `past` px beyond the
## strip, as the car's tick does: checkGround, then integrate. [health lost, seconds over deep water, speed in]
func cross(car: TestCar, map: StripMap, from := -12000.0, past := 300.0) -> Array:
	var pos := Vector2(from, 0)
	var vel := Vector2.ZERO
	var forward := Vector2.RIGHT
	var input := throttle()
	var deepTicks := 0
	var speedIn := 0.0
	var start := car.health
	for tick in 60 * 120:
		car.checkGround(pos)
		if World.isLethal(World.surfaceAt(pos)):
			if deepTicks == 0: speedIn = vel.length()
			deepTicks += 1
		var next = car.integrate(pos, forward, vel, input, DT)
		forward = next[0]
		vel = next[1]
		pos += vel * DT
		if pos.x > map.x1 + map.wade + past || car.isWrecked: break
	return [start - car.health, deepTicks * DT, speedIn]

func strip(width: float, wade := 0.0) -> StripMap:
	var map := StripMap.new()
	map.x1 = width
	map.wade = wade
	Root.worldMap = map
	return map

#--- the table ---------------------------------------------------------------------------------------

func test_wade_is_a_slow_passable_band_and_water_stays_lethal_for_the_world():
	var t = Root.terrain
	assert_true(World.isPassable(t.WADE), "wading depth can be driven")
	assert_false(World.isLethal(t.WADE), "and drowns nothing")
	assert_false(World.isSpawnable(t.WADE), "but nothing spawns there")
	assert_false(World.isBlocked(t.WADE))
	assert_almost_eq(World.routeWeight(t.WADE), 2.5, 0.001, "the AI may route through it, dearly")
	assert_gt(World.friction(t.WADE), World.friction(t.SHALLOWS), "it drags more than shallows")
	assert_gt(World.grip(t.SHALLOWS), World.grip(t.WADE), "and grips less")
	assert_gt(1.0, World.brake(t.WADE), "and brakes worse")
	assert_true(World.isLethal(t.WATER) && World.isBlocked(t.WATER), "deep water stays lethal and solid for goons, spawns and the AI")
	assert_gt(World.hurt(t.WATER), World.hurt(t.WADE) * 10.0, "deep water hurts far faster than wading")
	assert_gt(World.hurt(t.WADE), 0.0)
	for name in ["GRASS", "SHALLOWS", "BRIDGE", "MUD", "ICE"]:
		assert_eq(World.hurt(t[name]), 0.0, "%s never hurts" % name)
	assert_eq(World.hurt(World.UNKNOWN), 0.0, "no map: nothing hurts")
	assert_eq(World.letter(t.WADE), "v")

#--- the car in deep water ------------------------------------------------------------------------------

func test_a_stock_sedan_flat_out_crosses_a_short_strip_of_deep_water():
	var report := []
	for width in [300.0, 400.0, 500.0]:
		var car := sedan()
		var crossed := cross(car, strip(width))
		report.push_back("%d px: -%.1f health in %.2f s from %.0f px/s" % [width, crossed[0], crossed[1], crossed[2]])
		assert_false(car.isWrecked, "%d px: it survives" % width)
		assert_eq(car.destroyed, 0)
		if width <= 400.0: assert_between(crossed[0], 12.0, 28.0, "%d px costs about 15-25 health" % width)
		else: assert_between(crossed[0], 15.0, 60.0, "%d px costs more, still survivable" % width)
		assert_gt(car.waterHealthLost, crossed[0] - 0.01, "the water's damage is counted")
	print("  deep water crossings (stock sedan, flat out): " + "; ".join(report))

func test_the_wading_band_costs_a_little_on_the_way_in_and_out():
	var bare := sedan()
	var plain: Array = cross(bare, strip(300.0))
	var waded := sedan()
	var banded: Array = cross(waded, strip(300.0, 224.0))
	print("  300 px of deep water with a 224 px wading band either side: -%.1f health (%.1f without the band)" % [banded[0], plain[0]])
	assert_false(waded.isWrecked, "still survives")
	assert_gt(banded[0], plain[0], "the band slows the car, so the deep water takes longer and the wading adds a little")

func test_sitting_in_deep_water_wrecks_the_car_as_a_drowning():
	flat(Root.terrain.WATER)
	var car := sedan()
	var ticks := 0
	while not car.isWrecked && ticks < 60 * 10:
		car.checkGround(Vector2(10, 10))
		ticks += 1
	print("  parked in deep water: wrecked after %.2f s" % (ticks * DT))
	assert_true(car.isWrecked, "deep water wrecks a car that stays in it")
	assert_between(ticks * DT, 2.4, 3.6, "in about 3 s")
	assert_true(car.drowned, "a drowning (the playtest's WATER)")
	assert_eq(car.destroyed, 1, "once")

func test_deep_water_ignores_shields_but_not_a_hop():
	flat(Root.terrain.WATER)
	var shielded := sedan()
	shielded.buffs["shield"] = 30.0
	shielded.shieldHits = 3
	for i in 60: shielded.checkGround(Vector2.ZERO)
	assert_gt(95.0, shielded.health, "a shield doesn't keep the water out")
	assert_eq(shielded.shieldHits, 3, "and isn't used up by it")
	var hopping := sedan()
	hopping.airborneTicks = 1000
	for i in 60: hopping.checkGround(Vector2.ZERO)
	assert_almost_eq(hopping.health, 100.0, 0.001, "airborne over it: dry")
	assert_eq(hopping.deepTicks, 0)

func test_the_defibrillator_saves_a_drowning_car_once():
	flat(Root.terrain.WATER)
	var car := sedan()
	car.tDefib = true
	var ticks := 0
	while not car.isWrecked && ticks < 60 * 10:
		car.checkGround(Vector2.ZERO)
		ticks += 1
	assert_true(car.defibUsed, "the shock fired in the water")
	assert_true(car.isWrecked && car.drowned, "and the water still won in the end")
	assert_gt(ticks * DT, 3.4, "but it bought about a second")

func test_armor_softens_the_water():
	flat(Root.terrain.WATER)
	var bare := sedan()
	var armored := sedan()
	armored.armor = 60
	for i in 60:
		bare.checkGround(Vector2.ZERO)
		armored.checkGround(Vector2.ZERO)
	assert_gt(armored.health, bare.health + 5.0, "armor applies once, through damage()")

func test_deep_water_drags_and_no_tyre_trait_swims():
	var car := sedan()
	flat(Root.terrain.GRASS)
	var dry: Vector2 = car.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(600, 0), throttle(), DT)[1]
	flat(Root.terrain.WATER)
	var wet: Vector2 = car.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(600, 0), throttle(), DT)[1]
	assert_gt(dry.length(), wet.length() + 5.0, "deep water drags the car down hard")
	var offroad := sedan()
	offroad.tOffroad = true
	assert_almost_eq(offroad.groundFriction(Root.terrain.WATER), car.groundFriction(Root.terrain.WATER), 0.0001, "Off-Road doesn't ford deep water")
	assert_almost_eq(offroad.surfaceGrip(Root.terrain.WATER), World.grip(Root.terrain.WATER), 0.0001, "or grip in it")
	assert_gt(offroad.surfaceGrip(Root.terrain.WADE), World.grip(Root.terrain.WADE), "but it does help in wading depth")

func test_integrate_stays_pure_in_water():
	flat(Root.terrain.WATER)
	var car := sedan()
	car.velocity = Vector2(500, 0)
	car.integrate(Vector2.ZERO, Vector2.RIGHT, car.velocity, throttle(), DT)
	assert_eq(car.velocity, Vector2(500, 0))
	assert_almost_eq(car.health, 100.0, 0.0001, "the damage is checkGround's, never integrate()'s")

#--- the car in wading depth ----------------------------------------------------------------------------

func test_wading_hurts_lightly_and_wrecks_the_handling():
	flat(Root.terrain.WADE)
	var car := sedan()
	for i in 60: car.checkGround(Vector2.ZERO)
	var lost := 100.0 - car.health
	assert_between(lost, 1.0, 3.0, "about 2 health a second")
	assert_false(car.drowned)
	assert_eq(car.deepTicks, 0, "it isn't deep water")
	#a hard turn at speed: the travel follows the nose far less than on grass
	var turn := throttle()
	turn.steering = 1.0
	var headings := {}
	for ground in [Root.terrain.GRASS, Root.terrain.SHALLOWS, Root.terrain.WADE]:
		flat(ground)
		var vel := Vector2(500, 0)
		var forward := Vector2.RIGHT
		for t in 30:
			var next = car.integrate(Vector2.ZERO, forward, vel, turn, DT)
			forward = next[0]
			vel = next[1]
		headings[ground] = absf(vel.angle())
	assert_gt(headings[Root.terrain.GRASS], headings[Root.terrain.WADE] + 0.05, "wading grips far less than grass")
	assert_gt(headings[Root.terrain.SHALLOWS], headings[Root.terrain.WADE], "and less than shallows")

#--- goons --------------------------------------------------------------------------------------------

func test_goons_still_drown_in_deep_water_and_wade_slowly():
	add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())
	var map := strip(400.0, 300.0) #wading -300..0, deep 0..400
	var car: OverheadCarBody2D = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	car.position = Vector2(5000, 0)
	var deep: Walker = load(Goons.scenePath(&"grunt")).instantiate()
	deep.position = Vector2(200, 0)
	add_child_autofree(deep)
	assert_true(deep.checkWater(car), "deep water drowns a goon at once, as before")
	var wader: Walker = load(Goons.scenePath(&"grunt")).instantiate()
	wader.position = Vector2(-150, 0)
	add_child_autofree(wader)
	assert_false(wader.checkWater(car), "wading depth never drowns one")
	assert_almost_eq(WorldHooks.wadeScaleAt(wader.global_position), WorldHooks.WADE_SLOW, 0.0001, "it slows it")
	assert_almost_eq(WorldHooks.wadeScaleAt(Vector2(-1000, 0)), 1.0, 0.0001, "dry ground doesn't")
	wader.applyWade()
	assert_true(wader.isBuffed(), "through the buff scale, like slime")
	assert_almost_eq(wader.buffScale, WorldHooks.WADE_SLOW, 0.0001)
	assert_almost_eq(wader.speedNow(), wader.speed * WorldHooks.WADE_SLOW, 0.001)
	wader.buffScale = 0.5 #slime: the stronger slow is kept
	wader.buffUntil = GoonVerbs.now() + 1.0
	wader.applyWade()
	assert_almost_eq(wader.buffScale, 0.5, 0.0001, "a stronger slow stays")
	assert_true(map != null)

func test_hazards_and_loot_keep_out_of_wading_depth():
	strip(400.0, 300.0)
	assert_false(WorldHooks.hazardAllowed(Vector2(-150, 0)), "no oil or slime in wading depth")
	var bank := WorldHooks.bankNear(Vector2(-100, 0))
	assert_ne(World.terrainAt(bank), Root.terrain.WADE, "a drowned bandit's loot washes up past the wading band")
	assert_false(World.lethalAt(bank))
	assert_false(WorldHooks.tetherMustBreak(Vector2(-450, 0)), "tethers only fear deep water: 450 px from it holds")

#--- the raster ---------------------------------------------------------------------------------------

## Fine terrain counts over the chunks round the first few deep-water coarse cells near the start
func fineCounts(levelId: StringName, worldSeed := 1) -> Dictionary:
	var map := WorldMap.build(worldSeed, Levels.get_def(levelId))
	var start := map.coarseCell(map.startPosition)
	var chunks := {}
	for r in range(1, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var c := start + Vector2i(dx, dy)
				if not WorldGen.inMap(c): continue
				if map.terrain[c.y * WorldGen.W + c.x] == Root.terrain.WATER: chunks[WorldGen.chunkOf(WorldGen.cellCentre(c))] = true
		if chunks.size() >= 4: break
	var counts := {}
	for chunk in chunks:
		map.buildNow(chunk)
		for t in map.fine[chunk]: counts[t] = counts.get(t, 0) + 1
	return counts

func test_the_raster_puts_a_wading_band_inside_deep_water_with_shallows():
	for id in [&"prairie", &"bayou"]:
		var counts := fineCounts(id)
		var wade: int = counts.get(Root.terrain.WADE, 0)
		var deep: int = counts.get(Root.terrain.WATER, 0)
		print("  %s: %d wading cells, %d deep, %d shallows" % [id, wade, deep, counts.get(Root.terrain.SHALLOWS, 0)])
		assert_gt(wade, 0, "%s has a wading band" % id)
		assert_gt(deep, 0, "%s still has deep water" % id)

func test_city_canals_and_lava_stay_sheer():
	for id in [&"city", &"slagfields"]: #the city's canals; the volcano's lava
		var counts := fineCounts(id)
		assert_eq(counts.get(Root.terrain.WADE, 0), 0, "%s: no wading band" % id)
	assert_false(WorldField.hasWade(&"city", true), "the city grammar has no shallows, so no wading band")
	assert_true(WorldField.hasWade(&"meadow", true))
	assert_true(WorldField.hasWade(&"bayou", true))
	assert_false(WorldField.hasWade(&"canyon", false), "a landscape may opt out (lava)")
	assert_false(Landscapes.get_def(&"volcano").wade, "the volcano's lava does")

func test_the_native_grid_answers_wading_depth_like_gdscript():
	var map := WorldMap.build(1, Levels.get_def(&"prairie"))
	var start := map.coarseCell(map.startPosition)
	var chunk := Vector2i(999, 999)
	for r in range(1, 60):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var c := start + Vector2i(dx, dy)
				if WorldGen.inMap(c) && map.terrain[c.y * WorldGen.W + c.x] == Root.terrain.WATER: chunk = WorldGen.chunkOf(WorldGen.cellCentre(c))
			if chunk.x != 999: break
		if chunk.x != 999: break
	assert_ne(chunk, Vector2i(999, 999), "deep water near the start")
	for dy in range(-1, 2):
		for dx in range(-1, 2): map.buildNow(chunk + Vector2i(dx, dy))
	var wades := 0
	var mismatches := 0
	var origin := Vector2(chunk - Vector2i(1, 1)) * World.CHUNK_PX
	for j in WorldGen.FINE_H * 3:
		for i in WorldGen.FINE_W * 3:
			var p := origin + Vector2(i + 0.5, j + 0.5) * WorldGen.FINE
			var t := map.terrainAt(p)
			if t == Root.terrain.WADE: wades += 1
			if map.grid.terrainAt(p) != t || map.grid.lethalAt(p) != World.isLethal(t) || map.grid.blockedAt(p) != World.isBlocked(t) \
				|| map.grid.spawnableAt(p) != World.isSpawnable(t) || map.grid.wallAt(p) != World.isWallTerrain(t):
				mismatches += 1
	assert_gt(wades, 0, "the sample has wading depth")
	assert_eq(mismatches, 0, "native and GDScript agree on it")
