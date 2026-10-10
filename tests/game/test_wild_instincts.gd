extends GameTest

#Region 1, The Wilds (lane A; docs/GOONS.md "Wild instincts"): the Critter Chain (kills the player sets up join the
#Crush Combo near the car, with a variety XP bonus), charges that break things, trampling, the seeks table, farm
#gates goons open and shut, the lure
#list, herds that graze and stampede, the Bullmoose daze, slime that slows goons, quills that hit goons, Rattlers
#sunning on rocks, Buzzard roosts, smash tags and the Golden Jackalope.

class UiStub extends RefCounted:
	func updateStats() -> void: pass
	func updateGoonsCrushed() -> void: pass

## A stand-in level root: Levels.current() reads its def
class LevelStub extends Node2D:
	var def: LevelDef
	var hasEnded := false

var savedMap
var savedManager
var savedCar
var savedLevel
var savedData
var savedLures: Array
var manager: SpawnManager

func before_each():
	savedMap = Root.worldMap
	savedManager = Root.spawnManager
	savedCar = Root.playerCar
	savedLevel = Root.levelRoot
	savedData = SaveManager.playerData
	savedLures = Pickups.lures.duplicate()
	SaveManager.playerData = PlayerData.new() #nothing here may touch the real save
	Root.worldMap = null
	manager = add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())

func after_each():
	Root.worldMap = savedMap
	Root.spawnManager = savedManager
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null
	Root.levelRoot = savedLevel if is_instance_valid(savedLevel) else null
	SaveManager.playerData = savedData
	SaveManager.dirty = false
	Pickups.lures = savedLures

func prop(id: String, at := Vector2.ZERO, rot := 0.0) -> StaticBody2D:
	var node: StaticBody2D = load("res://world/art/props/%s.tscn" % id).instantiate()
	node.position = at
	node.rotation = rot
	if node.has_meta(&"smashSpeed"): node.set_script(load("res://scripts/world/breakable.gd"))
	add_child_autofree(node)
	return node

func goon(id: StringName, at: Vector2, still := false) -> Walker:
	var g: Walker = load(Goons.scenePath(id)).instantiate()
	g.position = at
	add_child_autofree(g)
	manager.registerGoon(g)
	if still: g.speed = 0.0
	return g

func makeCar(at: Vector2) -> OverheadCarBody2D:
	var car: OverheadCarBody2D = load("res://scene/car/sedan/sedan.tscn").instantiate()
	car.position = at
	add_child_autofree(car)
	car.ui = UiStub.new()
	Root.playerCar = car
	return car

func level(id: StringName) -> LevelStub:
	var stub := LevelStub.new()
	stub.def = Levels.defAt(Levels.indexOf(id))
	add_child_autofree(stub)
	Root.levelRoot = stub
	return stub

func flattened(g) -> bool:
	return not is_instance_valid(g) || g.dead

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

#--- R-1 Critter Chain -------------------------------------------------------------------------------

func test_kills_near_the_car_join_the_chain_and_far_ones_credit_nothing():
	var car := makeCar(Vector2.ZERO)
	var near := goon(&"grunt", Vector2(SpawnManager.CRITTER_CREDIT_PX - 50.0, 0))
	near.destroy(&"boom")
	assert_true(manager.creditCrush(near.global_position, near, &"logs"), "inside the radius: credited")
	assert_eq(car.currentGoonsCrushed, 1, "a crush")
	assert_eq(car.comboCount, 1, "it joined the Crush Combo")
	assert_eq(car.chainSources, ["LOGS"], "named by its source")
	var far := goon(&"grunt", Vector2(SpawnManager.CRITTER_CREDIT_PX + 50.0, 0))
	far.destroy(&"boom")
	assert_false(manager.creditCrush(far.global_position, far, &"trample"), "outside it: nothing")
	assert_eq(car.currentGoonsCrushed, 1, "no crush")
	assert_eq(car.comboCount, 1, "the chain didn't move")
	assert_eq(car.crushedById.get(&"grunt", 0), 1, "nor the Goonopedia")
	var aimed := goon(&"grunt", Vector2(5000, 0))
	aimed.destroy(&"boom")
	assert_true(manager.creditCrush(aimed.global_position, aimed, &"gadget"), "the player's own gadget counts anywhere")
	assert_eq(car.currentGoonsCrushed, 2)
	assert_eq(car.comboCount, 1, "but only joins the chain near the car")

func test_a_mixed_chain_pays_variety_xp_and_reads_as_a_critter_chain():
	assert_almost_eq(CrushPrizes.varietyBonus(0), 1.0, 0.001, "no chain")
	assert_almost_eq(CrushPrizes.varietyBonus(1), 1.0, 0.001, "one source: no bonus")
	assert_almost_eq(CrushPrizes.varietyBonus(3), 1.2, 0.001, "+10% per source past the first")
	assert_almost_eq(CrushPrizes.varietyBonus(9), 1.0 + CrushPrizes.VARIETY_MAX, 0.001, "capped")
	var car := makeCar(Vector2.ZERO)
	var a := goon(&"grunt", Vector2(100, 0))
	car.crushGoon(a, 500.0)
	var xpOne := car.crushXp
	var b := goon(&"grunt", Vector2(200, 0))
	b.destroy(&"boom")
	manager.creditCrush(b.global_position, b, &"bees")
	assert_eq(car.chainSources, ["CRUSH", "BEES"], "the bumper and the bees")
	var expected := CrushPrizes.crushXp(Goons.DATA[&"grunt"], false, 2, false, false, CrushPrizes.varietyBonus(2))
	assert_almost_eq(car.crushXp - xpOne, expected, 0.001, "the second kill pays the variety bonus")
	assert_eq(HudChance.comboText(9, 3, ["LOGS", "BEES", "SPLASH"]), "CRITTER CHAIN x9: LOGS + BEES + SPLASH   +3")
	assert_eq(HudChance.comboText(4, 2, ["CRUSH"]), "COMBO 4   +2", "one source is the plain combo")
	car.comboTick -= 100000 #the chain breaks
	var c := goon(&"grunt", Vector2(300, 0))
	car.crushGoon(c, 500.0)
	assert_eq(car.chainSources, ["CRUSH"], "a new chain starts clean")

#--- R-3, R-4: charges break things, heavies trample ---------------------------------------------------

func test_breakables_give_way_to_a_fast_enough_goon():
	makeCar(Vector2(0, 4000))
	var fence := prop("fence", Vector2(0, 0))
	assert_false(BreakableProp.smashedByGoon(fence, 100.0, Vector2.RIGHT), "too slow: it holds")
	assert_false(fence.get_meta(&"smashed", false))
	assert_true(BreakableProp.smashedByGoon(fence, 400.0, Vector2.RIGHT), "a charge breaks it")
	assert_true(fence.get_meta(&"smashed", false))
	assert_eq(fence.get_meta(&"spillDir"), Vector2.RIGHT, "spills go along the charge")
	assert_false(BreakableProp.smashedByGoon(prop("rock", Vector2(0, 900)), 9999.0, Vector2.RIGHT), "a rock is a wall")

func test_a_tusker_charge_bursts_through_a_breakable_and_bonks_on_what_holds():
	makeCar(Vector2(0, 5000))
	var tusker := goon(&"tusker", Vector2(-200, 0))
	var fence := prop("fence", Vector2(0, 0), PI / 2.0)
	await frames(2)
	tusker.lockDir = Vector2.RIGHT
	tusker.setState(&"attack")
	for i in 40:
		await get_tree().physics_frame
		if fence.get_meta(&"smashed", false): break
	assert_true(fence.get_meta(&"smashed", false), "the fence went")
	await frames(3)
	assert_eq(tusker.state, &"attack", "and the charge kept going")
	var tusker2 := goon(&"tusker", Vector2(-400, 1500))
	var tower := prop("watertower", Vector2(0, 1500))
	await frames(2)
	tusker2.lockDir = Vector2.RIGHT
	tusker2.setState(&"attack")
	for i in 60:
		await get_tree().physics_frame
		if tusker2.state == &"stun": break
	assert_eq(tusker2.state, &"stun", "a water tower (420) is too much for a 396 charge: BONK")
	assert_false(tower.get_meta(&"smashed", false))

func test_heavies_trample_fodder_near_the_car_for_credit():
	var car := makeCar(Vector2(0, 400))
	var tusker := goon(&"tusker", Vector2.ZERO, true)
	var fodder := goon(&"grunt", Vector2(30, 0), true)
	var special := goon(&"hubcap", Vector2(-30, 0), true)
	for i in Walker.TRAMPLE_EVERY:
		tusker.trample()
		await get_tree().physics_frame
	assert_true(flattened(fodder), "rank 1 is trampled")
	assert_false(flattened(special), "a special stands its ground")
	assert_eq(car.currentGoonsCrushed, 1, "credited: the car is near")
	assert_true("TRAMPLE" in car.chainSources, "and it joins the chain")
	car.global_position = Vector2(0, 5000)
	var far := goon(&"grunt", Vector2(0, 30), true)
	for i in Walker.TRAMPLE_EVERY:
		tusker.trample()
		await get_tree().physics_frame
	assert_true(flattened(far), "far from the car it still kills")
	assert_eq(car.currentGoonsCrushed, 1, "but credits nothing")
	var grunt := goon(&"grunt", Vector2(500, 0), true)
	var fodder2 := goon(&"grunt", Vector2(530, 0), true)
	for i in Walker.TRAMPLE_EVERY: grunt.trample()
	assert_false(flattened(fodder2), "only goons with tramples do it")

#--- R-5 seeks, the lure list ---------------------------------------------------------------------------

func test_the_seeks_table_is_well_formed():
	var groups := BreakableProp.GROUPS.values()
	groups.push_back(BreakableProp.ROOST_GROUP)
	for id in Goons.DATA:
		for row in Goons.DATA[id].get("seeks", []):
			assert_eq(row.size(), 4, "%s: [group, action, carRange, goonRange]" % id)
			assert_true(row[0] in groups, "%s seeks a tagged group (%s)" % [id, row[0]])
			assert_true(row[1] in [&"release", &"raid", &"open", &"shut", &"perch", &"roost", &"stash", &"hide"], "%s: a known action" % id)
			assert_gt(float(row[3]), 0.0, "%s looks somewhere" % id)
	var yipper: Array = Goons.DATA[&"yipper"].seeks.map(func(r): return r[1])
	assert_eq(yipper, [&"release", &"open"], "Yippers release piles and open gates")
	assert_eq(Goons.DATA[&"bandit"].seeks.map(func(r): return r[0]), [&"prop_crate", &"prop_gate", &"prop_den"], "Bandits raid crates, shut gates and stash in dens")
	assert_eq(Goons.DATA[&"buzzard"].seeks.map(func(r): return r[1]), [&"perch", &"roost"], "Buzzards perch and roost")
	assert_true(prop("farmgate", Vector2(9000, 0)).is_in_group(Spill.GATE_GROUP), "farm gates are tagged")
	assert_true(prop("rock_red", Vector2(9000, 900)).is_in_group(&"prop_rock"), "so are red rocks")
	assert_true(prop("deadtree", Vector2(9000, 1800)).is_in_group(BreakableProp.ROOST_GROUP), "and dead trees are roosts")

func test_goons_never_let_the_bees_out():
	makeCar(Vector2(0, 4000))
	var hive := prop("beehive")
	assert_false(BreakableProp.smashedByGoon(hive, 9999.0, Vector2.RIGHT), "a hive holds against any charge")
	assert_false(hive.get_meta(&"smashed", false))
	for id in Goons.DATA:
		for row in Goons.DATA[id].get("seeks", []): assert_ne(row[0], &"prop_hive", "%s leaves hives alone" % id)

func test_a_yipper_opens_the_gate_between_it_and_the_car():
	var car := makeCar(Vector2(0, 500))
	var gate := prop("farmgate")
	var g := goon(&"yipper", Vector2(0, -300))
	assert_true(Spill.acrossGate(gate, g.global_position, car.global_position), "the gate is between them")
	assert_eq(Spill.gateFor(get_tree(), Spill.GATE_GROUP, &"shut", g.global_position, car, 500.0), null, "a shut gate can't be shut")
	for i in 150:
		if Spill.isOpen(gate): break
		g.verb.seekProp(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_true(Spill.isOpen(gate), "it opened it")
	await frames(2)
	var shape: CollisionShape2D = gate.get_node("CollisionShape2D")
	assert_false(shape.disabled, "the open leaf is still solid")
	assert_almost_eq(shape.rotation, -Spill.GATE_SWING, 0.001, "swung aside with the leaf, away from the car")
	assert_almost_eq(shape.to_global(Spill.GATE_HINGE).distance_to(gate.to_global(Spill.GATE_HINGE)), 0.0, 0.01, "about its hinge")
	assert_true(gate.is_in_group(BreakableProp.BREAKABLE_GROUP), "and still smashes")
	var same := goon(&"yipper", Vector2(900, 400))
	var gate2 := prop("farmgate", Vector2(900, 0))
	car.global_position = Vector2(900, 800)
	assert_eq(Spill.gateFor(get_tree(), Spill.GATE_GROUP, &"open", same.global_position, car, 500.0), null, "a gate that isn't in its way stays shut")
	assert_false(Spill.isOpen(gate2))

func test_a_bandit_shuts_the_gate_the_car_is_heading_at():
	var car := makeCar(Vector2(0, 1000))
	var gate := prop("farmgate")
	Spill.setGate(gate, true, true)
	var g := goon(&"bandit", Vector2(200, -100))
	for i in 60:
		g.verb.seekProp(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_true(Spill.isOpen(gate), "the car isn't coming: it stays open")
	for i in 150:
		if not Spill.isOpen(gate): break
		car.velocity = Vector2(0, -200.0)
		g.verb.seekProp(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_false(Spill.isOpen(gate), "it shut it in the car's face")
	await frames(2)
	assert_almost_eq(gate.get_node("CollisionShape2D").rotation, 0.0, 0.001, "across the gap again")
	assert_eq(gate.get_node("CollisionShape2D").position, Vector2.ZERO)
	var gate2 := prop("farmgate", Vector2(5000, 0))
	Spill.setGate(gate2, true, true)
	car.global_position = Vector2(5000, Spill.GATE_CLEAR - 50.0)
	assert_false(Spill.goonGate(gate2, false, car), "never on a car in the gap")
	assert_true(Spill.isOpen(gate2))

func test_some_gates_stand_open_and_always_the_same_ones():
	var open := 0
	for i in 400:
		var at := Vector2(i * 1200.0, i * 37.0)
		assert_eq(Spill.gateStartsOpen(at), Spill.gateStartsOpen(at), "by its place")
		if Spill.gateStartsOpen(at): open += 1
	assert_between(open, 150, 250, "about half (%d of 400)" % open)

func test_a_light_bump_swings_a_gate_open_and_a_hard_hit_still_smashes_it():
	var car := makeCar(Vector2(0, 300))
	var gate := prop("farmgate")
	assert_false(Spill.pushGate(gate, Vector2(0, -Spill.GATE_PUSH + 10.0)), "a nudge does nothing")
	assert_true(PropReactions.knocks(gate, Vector2(0, -100.0)), "a light bump swings it open, and the car keeps its speed")
	assert_true(Spill.isOpen(gate))
	await frames(2)
	assert_almost_eq(gate.get_node("CollisionShape2D").rotation, -Spill.GATE_SWING, 0.001, "away from the car")
	assert_false(gate.get_meta(&"smashed", false), "not smashed")
	assert_false(Spill.pushGate(gate, Vector2(0, -100.0)), "an open leaf is a wall")
	var gate2 := prop("farmgate", Vector2(3000, 0))
	car.global_position = Vector2(3000, 300)
	await frames(2)
	for i in 90:
		car.velocity = Vector2(0, -400.0)
		await get_tree().physics_frame
		if gate2.get_meta(&"smashed", false): break
	assert_true(gate2.get_meta(&"smashed", false), "at speed it smashes as before")
	assert_false(Spill.isOpen(gate2))

func test_an_open_gate_has_a_keeper_that_shuts_it_on_the_car():
	var car := makeCar(Vector2(0, 3000))
	var stub := level(&"orchard")
	assert_eq(Spill.keeperId(), &"jackalope", "Orchard Lanes' gates are kept by its first goon that keeps")
	var gate := prop("farmgate")
	assert_eq(Spill.postKeeper(gate, &"yipper" if false else &""), null, "no keeper without a goon for it")
	Spill.setGate(gate, true, true)
	var g: Walker = Spill.postKeeper(gate, Spill.keeperId())
	assert_true(g != null && g.get_parent() == stub, "a goon stands at the gate")
	assert_eq(g.global_position, Spill.keeperSpot(gate), "at its post")
	assert_eq(Spill.postKeeper(gate, Spill.keeperId()), null, "one keeper a gate")
	await frames(5)
	assert_eq(g.state, Spill.KEEP_STATE, "it waits")
	assert_true(g.global_position.distance_to(Spill.keeperSpot(gate)) < 5.0, "without moving")
	manager.despawnSweep()
	assert_false(g.is_queued_for_deletion(), "and is never swept up as a straggler")
	car.global_position = Vector2(0, Spill.KEEP_AHEAD - 100.0)
	for i in 30:
		car.velocity = Vector2(0, -250.0)
		await get_tree().physics_frame
		if not Spill.isOpen(gate): break
	assert_false(Spill.isOpen(gate), "the car heads for the gate: shut in its face")
	assert_ne(g.state, Spill.KEEP_STATE, "and the keeper comes for the car")
	var gate2 := prop("farmgate", Vector2(6000, 0))
	Spill.setGate(gate2, true, true)
	var g2: Walker = Spill.postKeeper(gate2, &"bandit")
	await frames(3)
	Spill.disarm(gate2)
	assert_true(g2.is_queued_for_deletion(), "a keeper still waiting goes with its gate's chunk")

func test_a_bandit_raids_and_steals_only_where_the_player_sees_it():
	var car := makeCar(Vector2(0, 3000))
	var crate := prop("crate")
	var g := goon(&"bandit", Vector2(300, 0))
	var coin: Node2D = add_child_autofree(load(BreakableProp.COIN_SCENE).instantiate())
	coin.global_position = Vector2(300, -200)
	for i in 60:
		g.verb.seekProp(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_false(crate.get_meta(&"smashed", false), "the car is far off: the crate is left alone")
	assert_false(is_instance_valid(g.verb.target), "and so is the pickup")
	car.global_position = Vector2(150, 150)
	g.verb.lookT = 0.0
	g.verb.seekProp(1.0 / 60.0, car)
	assert_eq(g.verb.target, coin, "in sight of the car it goes for the pickup")
	coin.free()
	for i in 150:
		if crate.get_meta(&"smashed", false): break
		g.verb.seekProp(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_true(crate.get_meta(&"smashed", false), "it broke the crate open")

func test_lure_for_prunes_spent_lures_without_copying():
	var now := Time.get_ticks_msec()
	Pickups.lures = [
		{"pos": Vector2(100, 0), "until": now + 60000, "radius": 500.0, "only": &""},
		{"pos": Vector2(200, 0), "until": now - 10, "radius": 5000.0, "only": &""},
		{"pos": Vector2(300, 0), "until": now + 60000, "radius": 500.0, "only": &"flyer"},
		{"pos": Vector2(0, 0), "until": now - 10, "radius": 5000.0, "only": &""},
	]
	assert_eq(Pickups.lureFor(Vector2(150, 0), &"flyer"), Vector2(300, 0), "the newest lure in reach wins")
	assert_eq(Pickups.lures.size(), 3, "the spent one it passed is dropped")
	assert_eq(Pickups.lureFor(Vector2(150, 0), &"lunge"), Vector2(100, 0), "a flyers-only lure is skipped")
	assert_eq(Pickups.lures.size(), 2, "every spent one is gone")
	assert_eq(Pickups.lureFor(Vector2(5000, 0), &"lunge"), Vector2.INF, "out of reach")

#--- R-8 herds -------------------------------------------------------------------------------------------

func test_a_grazing_herd_stampedes_away_from_a_scare():
	makeCar(Vector2(0, 4000))
	level(&"prairie")
	var herd := manager.spawnGroup(&"thunderhoof", Vector2(1000, 0), 3, &"graze")
	assert_eq(herd.size(), 3, "a herd of three")
	await frames(2)
	for h in herd: assert_eq(h.state, &"graze", "grazing")
	herd[0].verb.spook(Vector2(600, 0))
	for h in herd:
		assert_eq(h.state, &"drive", "the whole herd runs")
		assert_true(h.verb.dir.dot(Vector2.RIGHT) > 0.9, "away from the scare")
	await frames(3)
	assert_true(herd[0].global_position.x > 1000.0 - 60.0, "and is driven that way")

func test_a_fast_close_pass_or_a_blast_spooks_a_herd():
	var car := makeCar(Vector2(0, 0))
	level(&"prairie")
	var herd := manager.spawnGroup(&"thunderhoof", Vector2(200, 0), 2, &"graze")
	await frames(2)
	car.velocity = Vector2(0, 40.0)
	await frames(2)
	assert_eq(herd[0].state, &"graze", "a slow car doesn't")
	car.velocity = Vector2(0, GoonVerbs.Herd.SPOOK_SPEED + 120.0)
	await frames(2)
	assert_eq(herd[0].state, &"drive", "a fast pass does")
	car.velocity = Vector2.ZERO
	var far := manager.spawnGroup(&"thunderhoof", Vector2(3000, 0), 2, &"graze")
	await frames(2)
	manager.fx.blast(Vector2(3000, 300), 100.0, 0.0)
	assert_eq(far[0].state, &"drive", "a blast nearby spooks it")
	assert_true(far[0].verb.dir.y < -0.5, "away from the blast")

#--- G-2 daze --------------------------------------------------------------------------------------------

func test_a_dazed_bullmoose_crushes_at_three_quarters():
	for id in Levels.ORDER: #Region 1 levels daze heavies, others don't
		var def := Levels.get_def(id)
		assert_eq(bool(def.rules.get("dazeHeavies", false)), def.region == &"wilds", "%s: dazeHeavies only in The Wilds" % id)
	var car := makeCar(Vector2(0, 3000))
	level(&"quarry")
	var plain := goon(&"bullmoose", Vector2(0, 0), true)
	assert_false(plain.dazes, "no rule, no daze")
	level(&"prairie")
	var moose := goon(&"bullmoose", Vector2(600, 0), true)
	assert_true(moose.dazes, "on Prairie Run it dazes")
	var dazedSpeed := moose.crushSpeed * Walker.DAZE_CRUSH
	assert_false(moose.tryCrush(car, dazedSpeed), "not dazed: 300 is too slow")
	moose.resistTimer = 0.0
	moose.daze()
	assert_true(moose.isDazed(), "BONK")
	assert_eq(moose.state, &"stun", "stunned for the moment")
	assert_false(moose.tryCrush(car, dazedSpeed - 5.0), "just under three quarters holds")
	moose.resistTimer = 0.0
	assert_true(moose.tryCrush(car, dazedSpeed), "three quarters crushes it")

func test_a_lunge_into_a_wall_dazes_the_bullmoose():
	makeCar(Vector2(0, 5000))
	level(&"prairie")
	var moose := goon(&"bullmoose", Vector2(-170, 0))
	prop("rock", Vector2(0, 0))
	await frames(2)
	moose.lockDir = Vector2.RIGHT
	moose.setState(&"attack")
	for i in 60:
		await get_tree().physics_frame
		if moose.isDazed(): break
	assert_true(moose.isDazed(), "it hit the rock and is dazed")

#--- G-9, G-10: slime and quills ---------------------------------------------------------------------------

func test_slime_slows_goons_in_it():
	makeCar(Vector2(0, 3000))
	var slimed := goon(&"grunt", Vector2(0, 0))
	var dry := goon(&"grunt", Vector2(600, 0))
	manager.fx.addHazard("slime", Vector2.ZERO, 64.0, 6.0)
	await frames(GoonFx.SLIME_EVERY + 1)
	assert_almost_eq(slimed.speedNow(), slimed.speed * GoonFx.SLIME_SLOW, 0.01, "half speed in the slime")
	assert_almost_eq(dry.speedNow(), dry.speed, 0.01, "full speed out of it")

func test_quills_hit_goons_and_credit_near_the_car():
	var car := makeCar(Vector2(0, 500))
	var quill := goon(&"quill", Vector2(0, 0), true)
	var victim := goon(&"grunt", Vector2(90, 0), true)
	var heavy := goon(&"hubcap", Vector2(-90, 0), true)
	manager.fx.shoot(Vector2(20, 0), Vector2.RIGHT, 420.0, 0.6, 2.0, "tires", "quill", quill)
	manager.fx.shoot(Vector2(-20, 0), Vector2.LEFT, 420.0, 0.6, 2.0, "tires", "quill", quill)
	manager.fx.shoot(Vector2(0, 0), Vector2.UP, 420.0, 0.6, 2.0, "tires", "quill", quill)
	await frames(20)
	assert_true(flattened(victim), "fodder in the volley is flattened")
	assert_false(flattened(heavy), "a special shrugs it off")
	assert_false(flattened(quill), "never its own quills")
	assert_eq(car.currentGoonsCrushed, 1, "credited: the car is near")
	car.global_position = Vector2(0, 5000)
	var far := goon(&"grunt", Vector2(0, 90), true)
	manager.fx.shoot(Vector2(0, 20), Vector2.DOWN, 420.0, 0.6, 2.0, "tires", "quill", quill)
	await frames(20)
	assert_true(flattened(far), "far from the car it still hits")
	assert_eq(car.currentGoonsCrushed, 1, "but credits nothing")

#--- G-11 Rattlers, R-11 roosts ----------------------------------------------------------------------------

func test_rattlers_spawn_sunning_beside_red_rocks():
	var car := makeCar(Vector2(0, 0))
	var rock := prop("rock_red", Vector2(3000, 0))
	var spot := manager.preferredSpot(&"rattler", Vector2(3200, 300))
	assert_almost_eq(spot.distance_to(rock.global_position), SpawnManager.SPAWN_OFFSET[&"rattler"], 1.0, "beside the rock")
	var rattler: Walker = load(Goons.scenePath(&"rattler")).instantiate()
	rattler.position = Vector2(1200, 0)
	rattler.set_meta(&"spawnState", SpawnManager.SPAWN_STATE[&"rattler"])
	add_child_autofree(rattler)
	manager.registerGoon(rattler)
	await frames(3)
	assert_eq(rattler.state, &"sun", "sunning")
	car.global_position = Vector2(1200 - GoonVerbs.Striker.SUN_WAKE + 100.0, 0)
	await frames(3)
	assert_eq(rattler.state, &"move", "it wakes when the car comes close")

func test_buzzards_roost_in_dead_trees_and_a_ram_knocks_them_down():
	var car := makeCar(Vector2(0, 2000))
	var tree := prop("deadtree", Vector2(0, 0))
	var bird := goon(&"buzzard", Vector2(300, 0))
	await frames(2)
	bird.cooldown = 0.0
	for i in 200:
		await get_tree().physics_frame
		if bird.state == &"roost": break
	assert_eq(bird.state, &"roost", "it roosts in the crown")
	assert_true(bird.invulnerable, "out of reach up there")
	assert_eq(Spill.roosting(tree), [bird], "the tree knows")
	assert_eq(Spill.knockRoost(tree, 100.0), 0, "a tap does nothing")
	assert_eq(Spill.knockRoost(tree, Spill.ROOSTS[&"deadtree"].knock + 10.0), 1, "a ram knocks it down")
	assert_eq(bird.state, &"stun", "stunned")
	assert_false(bird.invulnerable, "and crushable")
	assert_true(bird.collision_layer != 0, "solid on the ground")

#--- R-12 smash tags, R-14 Golden Jackalope ---------------------------------------------------------------

func test_smash_tags_show_on_heroes_the_car_heads_at_and_hint_once():
	makeCar(Vector2.ZERO)
	var hud: HudChance = add_child_autofree(HudChance.new())
	var tags: SmashTags = add_child_autofree(SmashTags.new())
	var pile := prop("logpile", Vector2(500, 0))
	tags.add(pile)
	tags.add(prop("rock", Vector2(400, 0)))
	assert_eq(tags.heroes.size(), 1, "walls and rocks get no tag")
	assert_true(SmashTags.headingAt(Vector2.ZERO, Vector2(300, 0), pile.global_position), "heading at it")
	assert_false(SmashTags.headingAt(Vector2.ZERO, Vector2(0, 300), pile.global_position), "driving past")
	assert_false(SmashTags.headingAt(Vector2.ZERO, Vector2(10, 0), pile.global_position), "crawling")
	assert_false(SmashTags.headingAt(Vector2(-400, 0), Vector2(300, 0), pile.global_position), "too far")
	Root.playerCar.velocity = Vector2(300, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(tags.shownProps.size() == 1 && tags.shownProps[0] == pile, "a tag over the pile")
	assert_true(SaveManager.playerData.meta.hints.get("smash_logpile", false), "the first meeting is remembered")
	assert_eq(hud.toasts.size(), 1, "with a hint")
	tags.forget(pile)
	tags.add(pile)
	await get_tree().process_frame
	assert_eq(hud.toasts.size(), 1, "once a save")
	assert_eq(SmashTags.smashSpeed(prop("crane", Vector2(0, 3000))), Spill.DROP_SPEED, "a crane's is the ram that drops its box")

func test_the_golden_goon_is_a_jackalope_in_the_wilds():
	makeCar(Vector2(0, 3000))
	level(&"prairie")
	assert_true(WorldProps.inWilds(), "Prairie Run is The Wilds")
	var gold: WorldProps.GoldenGoon = add_child_autofree(WorldProps.GoldenGoon.new())
	assert_true(gold.jackalope != null, "so the Golden Goon is a Golden Jackalope")
	var savedRegion: Dictionary = Region.currentRegion
	Region.currentRegion = {"faction": Goons.faction.TRIBE}
	var city := level(&"city")
	assert_false(WorldProps.inWilds(), "a level in another region isn't")
	var plain: WorldProps.GoldenGoon = add_child_autofree(WorldProps.GoldenGoon.new())
	assert_true(plain.jackalope == null, "the plain Golden Goon there")
	Region.currentRegion = {"faction": Goons.faction.WILD}
	assert_false(WorldProps.inWilds(), "the level's region wins over the district")
	city.def = city.def.duplicate()
	city.def.region = &""
	assert_true(WorldProps.inWilds(), "a level without a region goes by the district: a Wild one counts")
	Region.currentRegion = {"faction": Goons.faction.TRIBE}
	assert_false(WorldProps.inWilds(), "and a Tribe one doesn't")
	Region.currentRegion = savedRegion
