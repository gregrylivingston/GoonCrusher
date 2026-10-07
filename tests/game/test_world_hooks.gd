extends GameTest

#The world's gameplay hooks (docs/WORLD.md "Gameplay hooks", docs/GOONS.md): goons against the grid
#(WorldHooks.slideStep, drowning and its crush credit), tethers and hazards near water, shells and shots
#against walls, breakable and explosive props (BreakableProp), prop groups for goon spawns, and the AI
#driver's water margin.

#a stand-in WorldMap: terrain from a rule over world px; records markTaken calls
class RuleMap extends RefCounted:
	var rule: Callable
	var taken := []
	func terrainAt(pos: Vector2) -> int: return rule.call(pos)
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))
	func markTaken(chunk: Vector2i, bit: int) -> void: taken.push_back([chunk, bit])

#the HUD a car reports rewards to, outside a run
class UiStub extends RefCounted:
	func updateStats() -> void: pass
	func updateGoonsCrushed() -> void: pass

var savedMap
var savedManager
var savedCar

func before_each():
	savedMap = Root.worldMap
	savedManager = Root.spawnManager
	savedCar = Root.playerCar

func after_each():
	Root.worldMap = savedMap
	Root.spawnManager = savedManager
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null

func useRule(rule: Callable) -> RuleMap:
	var map := RuleMap.new()
	map.rule = rule
	Root.worldMap = map
	return map

#deep water west of x = 0, grass east of it
func westWater() -> RuleMap:
	return useRule(func(p: Vector2) -> int: return Root.terrain.WATER if p.x < 0.0 else Root.terrain.GRASS)

func makeManager() -> SpawnManager:
	return add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())

func spawnGoon(id: StringName, at := Vector2.ZERO) -> Walker:
	var goon: Walker = load(Goons.scenePath(id)).instantiate()
	goon.position = at
	add_child_autofree(goon)
	return goon

#a stock sedan standing at `at`; its crush count is what creditCrush credits
func makeStubCar(at: Vector2) -> OverheadCarBody2D:
	var car: OverheadCarBody2D = load("res://scene/car/sedan/sedan.tscn").instantiate()
	car.position = at
	add_child_autofree(car)
	car.ui = UiStub.new()
	Root.playerCar = car
	return car

func prop(id: String, at := Vector2.ZERO) -> StaticBody2D:
	var node: StaticBody2D = load("res://world/art/props/%s.tscn" % id).instantiate()
	node.position = at
	add_child_autofree(node)
	return node

#--- goons against the grid ------------------------------------------------------------------------

func test_off_screen_steps_slide_along_barriers_and_hold_in_corners():
	westWater()
	assert_eq(WorldHooks.slideStep(Vector2(100, 0), Vector2(-20, 5)), Vector2(80, 5), "open ground: the whole step")
	assert_eq(WorldHooks.slideStep(Vector2(10, 0), Vector2(-20, 5)), Vector2(10, 5), "into the water: slides along the bank")
	assert_eq(WorldHooks.slideStep(Vector2(-50, 0), Vector2(-20, 0)), Vector2(-70, 0), "already in it: free to move (out)")
	useRule(func(p: Vector2) -> int: return Root.terrain.HILLS if p.x < 0.0 || p.y < 0.0 else Root.terrain.GRASS)
	assert_eq(WorldHooks.slideStep(Vector2(10, 10), Vector2(-20, -20)), Vector2(10, 10), "a corner: it holds")
	Root.worldMap = null
	assert_eq(WorldHooks.slideStep(Vector2(10, 10), Vector2(-20, -20)), Vector2(-10, -10), "no map: nothing blocks")

func test_drowning_counts_only_soon_after_a_touch():
	assert_true(WorldHooks.drownCredited(10.0, 7.5), "2.5 s after the touch")
	assert_false(WorldHooks.drownCredited(10.0, 6.9), "3.1 s after: on its own")
	assert_false(WorldHooks.drownCredited(10.0, -INF), "never touched")

func test_goons_drown_in_deep_water_and_the_car_gets_the_splash():
	makeManager()
	westWater()
	var car := makeStubCar(Vector2(5000, 0))
	var loner := spawnGoon(&"grunt", Vector2(-300, 0))
	assert_true(loner.checkWater(car), "over deep water: drowned")
	assert_true(loner.dead, "dead")
	assert_eq(car.currentGoonsCrushed, 0, "nobody pushed it: no crush")
	var pushed := spawnGoon(&"grunt", Vector2(-300, 400))
	pushed.touchedByCar()
	assert_true(pushed.checkWater(car), "drowned")
	assert_eq(car.currentGoonsCrushed, 1, "shoved in by the car: a crush")
	assert_eq(car.crushedById.get(&"grunt", 0), 1, "and it counts for the Goonopedia, like a bumper crush")
	assert_eq(car.crushedById.size(), 1, "the unpushed one doesn't")
	var dry := spawnGoon(&"grunt", Vector2(300, 0))
	assert_false(dry.checkWater(car), "on grass nothing happens")
	var hopper := spawnGoon(&"grunt", Vector2(-300, 800))
	hopper.setSolid(false)
	assert_false(hopper.checkWater(car), "not solid (hopping, flying, buried): immune")
	assert_false(hopper.dead)

func test_the_bumper_counts_as_a_touch():
	makeManager()
	westWater()
	var goon := spawnGoon(&"grunt", Vector2(300, 0))
	var car := makeStubCar(Vector2(380, 0))
	goon.checkWater(car)
	assert_true(WorldHooks.drownCredited(GoonVerbs.now(), goon.lastCarTouch), "a car alongside is pushing it")

func test_a_drowned_bandits_loot_washes_up_on_the_bank():
	westWater()
	var bank := WorldHooks.bankNear(Vector2(-200, 0))
	assert_false(World.lethalAt(bank), "the bank is dry")
	assert_true(bank.distance_to(Vector2(-200, 0)) <= WorldHooks.FINE * 2.0 + 1.0, "and close by")
	useRule(func(_p: Vector2) -> int: return Root.terrain.WATER)
	assert_eq(WorldHooks.bankNear(Vector2(5, 5)), Vector2(5, 5), "no bank in reach: where it sank")

func test_goons_stuck_on_a_barrier_are_flagged_for_the_sweep():
	makeManager()
	var goon := spawnGoon(&"grunt")
	assert_false(goon.isStuck())
	goon.stuckTime = WorldHooks.STUCK_SECONDS
	assert_true(goon.isStuck(), "four seconds pressing a wall")

#--- tethers, hazards, shots and shells ----------------------------------------------------------

func test_tethers_break_near_deep_water():
	westWater()
	assert_true(WorldHooks.tetherMustBreak(Vector2(350, 0)), "350 px from the water")
	assert_false(WorldHooks.tetherMustBreak(Vector2(500, 0)), "500 px away holds")
	Root.worldMap = null
	assert_false(WorldHooks.tetherMustBreak(Vector2(0, 0)), "no map: holds")

func test_oil_and_slime_keep_off_shallows_and_the_waters_edge():
	useRule(func(p: Vector2) -> int:
		if p.x < 0.0: return Root.terrain.WATER
		return Root.terrain.SHALLOWS if p.x < 200.0 else Root.terrain.GRASS)
	assert_false(WorldHooks.hazardAllowed(Vector2(100, 0)), "on shallows")
	assert_false(WorldHooks.hazardAllowed(Vector2(-100, 0)), "in the water")
	assert_true(WorldHooks.hazardAllowed(Vector2(600, 0)), "dry ground")
	westWater()
	assert_false(WorldHooks.hazardAllowed(Vector2(60, 0)), "within a fine cell of deep water")
	var manager := makeManager()
	manager.fx.addHazard("oil", Vector2(60, 0), 44.0, 8.0)
	manager.fx.addHazard("fire", Vector2(60, 0), 34.0, 3.0)
	manager.fx.addHazard("slime", Vector2(900, 0), 64.0, 6.0)
	assert_eq(manager.fx.hazards.map(func(h): return h.kind), ["fire", "slime"], "the oil at the edge was never laid")

func test_shots_and_blasts_stop_at_walls():
	useRule(func(p: Vector2) -> int: return Root.terrain.HILLS if p.x > 500.0 && p.x < 700.0 else Root.terrain.GRASS)
	assert_true(WorldHooks.lineClear(Vector2(0, 0), Vector2(450, 100)), "open ground")
	assert_false(WorldHooks.lineClear(Vector2(0, 0), Vector2(900, 0)), "through the ridge")
	useRule(func(p: Vector2) -> int: return Root.terrain.WATER if p.x > 500.0 && p.x < 700.0 else Root.terrain.GRASS)
	assert_true(WorldHooks.lineClear(Vector2(0, 0), Vector2(900, 0)), "water doesn't stop them")
	var manager := makeManager()
	useRule(func(p: Vector2) -> int: return Root.terrain.HILLS if p.x > 500.0 && p.x < 700.0 else Root.terrain.GRASS)
	manager.fx.shoot(Vector2(480, 0), Vector2.RIGHT, 600.0, 2.0, 1.0, "hull", "bolt")
	for i in 6: manager.fx._physics_process(1.0 / 60.0)
	assert_eq(manager.fx.projectiles.size(), 0, "the bolt hit the ridge")

func test_a_kicked_shell_rebounds_off_wall_cells():
	useRule(func(p: Vector2) -> int: return Root.terrain.HILLS if p.x > 100.0 else Root.terrain.GRASS)
	assert_eq(WorldHooks.bounce(Vector2(95, 0), Vector2(600, 0), 1.0 / 60.0), Vector2(-600, 0), "head-on: straight back")
	assert_eq(WorldHooks.bounce(Vector2(95, 0), Vector2(600, 300), 1.0 / 60.0), Vector2(-600, 300), "at an angle: the blocked axis flips")
	assert_eq(WorldHooks.bounce(Vector2(0, 0), Vector2(600, 300), 1.0 / 60.0), Vector2(600, 300), "clear: unchanged")

#--- breakables and explosives ------------------------------------------------------------------

func test_breakables_need_their_smash_speed_and_mark_the_taken_set():
	var map := westWater()
	var crate := prop("crate", Vector2(400, 0))
	assert_true(BreakableProp.isBreakable(crate), "a crate carries smashSpeed")
	assert_almost_eq(OverheadCarBody2D.smashSpeedOf(crate), 150.0, 0.001, "the car reads its metadata")
	assert_false(BreakableProp.isBreakable(prop("rock")), "a rock is just a wall")
	crate.set_meta(&"world_chunk", Vector2i(2, -1))
	crate.set_meta(&"world_bit", 37)
	BreakableProp.smashNode(crate, null)
	assert_true(crate.get_meta(&"smashed", false), "smashed")
	assert_eq(crate.get_node("Sprite2D").texture.resource_path, crate.get_meta(&"broken"), "the broken sprite shows")
	assert_eq(map.taken, [[Vector2i(2, -1), 37]], "the run remembers it")
	assert_eq(OverheadCarBody2D.smashSpeedOf(crate), INF, "it can't be smashed twice")
	BreakableProp.smashNode(crate, null)
	assert_eq(map.taken.size(), 1, "once only")
	await get_tree().physics_frame
	assert_true(crate.get_node("CollisionShape2D").disabled, "the car drives over what's left")
	assert_eq(BreakableProp.COIN_SPILL.get(&"crate", 0), 3, "a crate spills coins")
	var hedge := prop("hedge")
	BreakableProp.smashNode(hedge, null)
	assert_false(hedge.get_node("LightOccluder2D").visible, "no night shadow once broken")
	assert_false(hedge.get_node("LightOccluder2D").get_meta("gc_vis"), "and Settings keeps it off")

func test_props_without_a_slot_still_break():
	Root.worldMap = null
	var fence := prop("fence")
	assert_false(BreakableProp.markTaken(fence), "no world_chunk/world_bit: nothing to record")
	BreakableProp.smashNode(fence, null)
	assert_true(fence.get_meta(&"smashed", false))

func test_explosives_chain_once_each():
	makeManager()
	Root.worldMap = null
	Root.playerCar = null
	var barrels := [prop("barrel", Vector2(0, 0)), prop("barrel", Vector2(150, 0)), prop("barrel", Vector2(300, 0)), prop("barrel", Vector2(3000, 0))]
	for b in barrels: assert_true(b.is_in_group(BreakableProp.EXPLOSIVE_GROUP), "the spawn manager tags explosives")
	assert_true(BreakableProp.detonate(barrels[0]), "set off")
	assert_false(BreakableProp.detonate(barrels[0]), "a barrel goes off once")
	await get_tree().create_timer(0.6).timeout
	for i in 3: assert_true(barrels[i].get_meta(&"smashed", false), "barrel %d caught the chain" % i)
	assert_false(barrels[3].get_meta(&"smashed", false), "the far one is out of reach")
	assert_eq(BreakableProp.blastAt(get_tree(), Vector2(150, 0), 400.0), 0, "spent barrels never go off again")
	var tank := prop("tank", Vector2(6000, 0))
	assert_true(BreakableProp.speedOf(tank) > 10000.0, "a tank only blows to a blast")

func test_blasts_kill_goons_in_the_open_only():
	var manager := makeManager()
	useRule(func(p: Vector2) -> int: return Root.terrain.HILLS if p.x > 100.0 && p.x < 200.0 else Root.terrain.GRASS)
	var car := makeStubCar(Vector2(9000, 0))
	var open := spawnGoon(&"grunt", Vector2(-80, 0))
	var sheltered := spawnGoon(&"grunt", Vector2(260, 0))
	manager.registerGoon(open)
	manager.registerGoon(sheltered)
	manager.fx.blast(Vector2(0, 0), 300.0, 5.0)
	assert_true(open.dead, "in the open: flattened")
	assert_false(sheltered.dead, "behind the ridge: safe")
	assert_eq(car.currentGoonsCrushed, 1, "the kill counts as a crush")

#--- props goons use -------------------------------------------------------------------------------

func test_prop_groups_and_spawn_spots():
	var manager := makeManager()
	Root.worldMap = null
	var manhole := prop("manhole", Vector2(800, 0))
	var log := prop("log", Vector2(-900, 300))
	assert_true(manhole.is_in_group(&"prop_manhole"), "manholes are Rat Pack doors")
	assert_true(log.is_in_group(&"prop_log"), "logs hide Snappers")
	assert_true(prop("carcass").is_in_group(&"prop_carcass"), "carcasses are perches")
	makeStubCar(Vector2(20000, 0))
	assert_eq(manager.preferredSpot(&"rat", Vector2.ZERO), Vector2(800, 0), "the Rat Pack comes out of the manhole")
	assert_true(manager.preferredSpot(&"snapper", Vector2.ZERO).distance_to(log.global_position) < 100.0, "a Snapper by the log")
	assert_eq(manager.preferredSpot(&"grunt", Vector2(5, 5)), Vector2(5, 5), "others keep their spot")
	makeStubCar(Vector2(900, 0))
	assert_eq(manager.preferredSpot(&"rat", Vector2.ZERO), Vector2.ZERO, "never out of a manhole the car can see")

#--- the AI driver -------------------------------------------------------------------------------

func makeDriver() -> AIDriver:
	var driver := AIDriver.new()
	var cells := PackedByteArray()
	cells.resize(16)
	driver.route = AIRoute.new(cells, Vector2i(4, 4), Vector2(1280, 1280))
	autofree.push_back(driver)
	return driver

func test_ai_keeps_its_targets_off_the_waters_edge():
	westWater()
	var driver := makeDriver()
	assert_true(driver.nearWater(Vector2(300, 0)), "300 px from deep water")
	assert_false(driver.nearWater(Vector2(900, 0)), "900 px is fine")
	useRule(func(p: Vector2) -> int: return Root.terrain.WATER if p.x < 0.0 else Root.terrain.BRIDGE)
	var cells := PackedByteArray()
	cells.resize(16)
	cells.fill(Root.terrain.BRIDGE)
	driver.route = AIRoute.new(cells, Vector2i(4, 4), Vector2(1280, 1280))
	assert_false(driver.nearWater(Vector2(300, 0)), "on a bridge deck the water is fine")

func test_ai_charges_for_deep_water_ahead():
	westWater()
	var driver := makeDriver()
	var toward := driver.waterAheadCost(Vector2(500, 0), Vector2(400, 0), 700.0)
	var away := driver.waterAheadCost(Vector2(300, 0), Vector2(400, 0), 700.0)
	var closer := driver.waterAheadCost(Vector2(300, 0), Vector2(200, 0), 700.0)
	assert_gt(toward, 0.0, "heading for the water costs")
	assert_eq(away, 0.0, "heading away doesn't")
	assert_gt(closer, toward, "closer costs more")
	assert_eq(driver.waterAheadCost(Vector2(500, 0), Vector2(400, 0), 80.0), 0.0, "crawling is safe")

#--- the station's contract ----------------------------------------------------------------------

#every wall rect of the station (StaticBody2D children with rectangle shapes, the house excluded), in world px
func stationWalls(station: Node2D) -> Array:
	var rects := []
	for body in station.find_children("*", "StaticBody2D", true, false):
		if body.name == "house": continue
		for shape in body.find_children("*", "CollisionShape2D", true, false):
			if shape.shape is RectangleShape2D && not shape.disabled:
				var size: Vector2 = shape.shape.size
				var centre: Vector2 = shape.global_position
				rects.push_back(Rect2(centre - size / 2.0, size))
	return rects

func segmentHits(rects: Array, a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / 8.0)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for r in rects:
			if r.has_point(p): return true
	return false

func test_station_keeps_its_lot_gap_and_driveway():
	var station: Node2D = add_child_autofree(load("res://scene/level/station.tscn").instantiate())
	var lot: Rect2 = station.LOT
	assert_eq(lot, Rect2(-770, -539, 1518, 1104), "the lot rect is the contract")
	var walls := stationWalls(station)
	assert_true(walls.size() >= 3, "walled on three sides")
	for r in walls: assert_true(lot.grow(2.0).encloses(r), "walls stay inside the lot: %s" % r)
	var driveway = station.get_node_or_null("driveway/CollisionShape2D")
	assert_true(driveway != null, "the AI and the run end read driveway/CollisionShape2D")
	if driveway == null: return
	var drive: Vector2 = driveway.global_position
	assert_true(lot.has_point(drive), "the driveway is on the lot")
	var centre := lot.get_center()
	assert_true(segmentHits(walls, centre, centre + Vector2(-1000, 0)), "closed to the west")
	assert_true(segmentHits(walls, centre, centre + Vector2(0, -800)), "closed to the north")
	assert_true(segmentHits(walls, centre, centre + Vector2(0, 800)), "closed to the south")
	assert_false(segmentHits(walls, drive, drive + Vector2(1000, 0)), "the gap is east of the driveway")
	assert_eq(station.nearestWallPoint(drive), drive, "inside the lot a point is its own nearest wall point")
	assert_eq(station.nearestWallPoint(Vector2(5000, 0)), Vector2(lot.end.x, 0), "outside it lands on the lot's edge")
	for wall in station.find_children("*", "LightOccluder2D", true, false):
		if wall.get_parent().name != "house": assert_true(wall.get_meta("gc_world", false), "%s stays on at Lighting Low" % wall.get_parent().name)
	station.startBarrier()
	station.damage(400.0)
	assert_almost_eq(station.barrier, station.BARRIER_MAX - 400.0, 0.01, "goons wear the barrier down")
