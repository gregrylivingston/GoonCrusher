extends GameTest

#Region 1, The Wilds (lane C2; docs/GOONS.md "Wild instincts", docs/PICKUPS.md): Bandit dens, burrows and
#warrens, bee yards, the Dinner Bell and the Salt Lick, scarecrow roosts, the one crate, the Region 1 spills
#(still, sluice, rockslide, TNT, topples, deadfall, pumpkins, gates, orchard oaks) and the level-owned world
#events (stampede, flash flood). Props are instanced straight from their baked scenes, as ChunkView would.

class UiStub extends RefCounted:
	func updateStats() -> void: pass
	func updateGoonsCrushed() -> void: pass

## A stand-in level root with a TileManager-named child (Spill keeps its records there) and a def
class LevelStub extends Node2D:
	var def: LevelDef
	var hasEnded := false
	func explode(_pos: Vector2) -> void: pass

## A stand-in TileManager: the once-only record (Spill.markUsed / isUsed), chunk-local like the real one
class TmStub extends Node:
	var used := []
	func chunkOf(at: Vector2) -> Vector2i: return Vector2i(floori(at.x / ChunkRecipe.CHUNK.x), floori(at.y / ChunkRecipe.CHUNK.y))
	func markSpillUsed(at: Vector2) -> void: used.push_back([chunkOf(at), at - Vector2(chunkOf(at)) * ChunkRecipe.CHUNK])
	func spillUsed(chunk: Vector2i, local: Vector2) -> bool:
		for u in used:
			if u[0] == chunk && u[1].distance_to(local) < 8.0: return true
		return false

## A stand-in WorldMap: terrain from a rule over world px
class RuleMap extends RefCounted:
	var rule: Callable
	func terrainAt(pos: Vector2) -> int: return rule.call(pos)
	func surfaceAt(pos: Vector2) -> int: return terrainAt(pos)
	func lethalAt(pos: Vector2) -> bool: return World.isLethal(terrainAt(pos))
	func blockedAt(pos: Vector2) -> bool: return World.isBlocked(terrainAt(pos))
	func spawnableAt(pos: Vector2) -> bool: return World.isSpawnable(terrainAt(pos))
	func markTaken(_chunk: Vector2i, _bit: int) -> void: pass

var savedMap
var savedManager
var savedCar
var savedLevel
var savedData
var savedLures: Array
var manager: SpawnManager
var stub: LevelStub

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
	stub = level(&"prairie")

func after_each():
	Root.worldMap = savedMap
	Root.spawnManager = savedManager
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null
	Root.levelRoot = savedLevel if is_instance_valid(savedLevel) else null
	SaveManager.playerData = savedData
	SaveManager.dirty = false
	Pickups.lures = savedLures
	PickupWorld.beacons.clear() #the events' edge arrows point at nodes these tests free

func level(id: StringName) -> LevelStub:
	var s := LevelStub.new()
	s.def = Levels.defAt(Levels.indexOf(id))
	var tm := TmStub.new()
	tm.name = "TileManager"
	s.add_child(tm)
	add_child_autofree(s)
	Root.levelRoot = s
	return s

func prop(id: String, at := Vector2.ZERO, rot := 0.0) -> StaticBody2D:
	var node: StaticBody2D = load("res://world/art/props/%s.tscn" % id).instantiate()
	node.position = at
	node.rotation = rot
	if node.has_meta(&"smashSpeed"): node.set_script(load("res://scripts/world/breakable.gd"))
	add_child_autofree(node)
	Spill.arm(node) #as ChunkView does through PropReactions.addHero
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

func flattened(g) -> bool:
	return not is_instance_valid(g) || g.dead

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func coinsOnLevel() -> int:
	return stub.get_children().filter(func(n): return n.scene_file_path == BreakableProp.COIN_SCENE).size()

const LOOT := "res://scene/powerup/fuel.tscn"

#--- R-6 dens -----------------------------------------------------------------------------------------------

func test_a_bandit_with_loot_runs_home_and_stashes_it():
	var car := makeCar(Vector2(0, 3000))
	var den := prop("den", Vector2(800, 0))
	assert_true(den.is_in_group(Spill.DEN_GROUP), "dens are tagged for Bandits")
	assert_eq(Goons.seekRow(Goons.DATA[&"bandit"], &"stash")[0], Spill.DEN_GROUP, "the Bandit's stash row names dens")
	var bandit := goon(&"bandit", Vector2(0, 0))
	await frames(2)
	bandit.verb.stolen = [{"scene": LOOT}, {"scene": LOOT}]
	bandit.setState(&"flee")
	for i in 400:
		await get_tree().physics_frame
		if flattened(bandit): break
	assert_true(flattened(bandit), "it got home and is gone")
	assert_eq(Spill.stashOf(den).size(), 2, "the loot is in the den")
	assert_eq(den.get_node("Sacks").frame, 2, "two sacks show")
	assert_eq(car.currentGoonsCrushed, 0, "no credit for a Bandit that got home")
	assert_eq(manager.fx.drops.size(), 0, "and nothing dropped")

func test_a_bandit_with_no_den_near_just_flees():
	makeCar(Vector2(0, 3000))
	prop("den", Vector2(Goons.seekRow(Goons.DATA[&"bandit"], &"stash")[3] + 400.0, 0))
	var bandit := goon(&"bandit", Vector2(0, 0))
	await frames(2)
	bandit.verb.stolen = [{"scene": LOOT}]
	bandit.setState(&"flee")
	await frames(10)
	assert_false(bandit.verb.goHome(0.6), "too far to run home")
	assert_true(bandit.global_position.y < 0.0, "so it runs from the car")

func test_a_smashed_den_bursts_the_loot_out_once():
	var car := makeCar(Vector2(-300, 0))
	car.velocity = Vector2(400, 0)
	var den := prop("den", Vector2(0, 0))
	Spill.stash(den, [{"scene": LOOT}, {"scene": LOOT}, {"scene": LOOT}])
	assert_eq(den.get_node("Sacks").frame, 3, "three sacks")
	var before := manager.fx.drops.size()
	BreakableProp.smashNode(den, car)
	assert_eq(manager.fx.drops.size() - before, 3, "every stashed pickup bursts out")
	BreakableProp.smashNode(den, car)
	assert_eq(manager.fx.drops.size() - before, 3, "once")
	await get_tree().process_frame
	assert_eq(coinsOnLevel(), BreakableProp.COIN_SPILL[&"den"], "plus the den's own coins")
	assert_true(Spill.stashOf(den).is_empty(), "the den is empty")
	assert_false(den.get_node("Sacks").visible, "no sacks on a broken den")

func test_a_stash_outlives_a_chunk_reload():
	makeCar(Vector2(0, 3000))
	var den := prop("den", Vector2(500, 200))
	Spill.stash(den, [{"scene": LOOT}])
	den.free()
	var again := prop("den", Vector2(500, 200))
	assert_eq(Spill.stashOf(again).size(), 1, "the reloaded den still holds it")
	assert_eq(again.get_node("Sacks").frame, 1)
	var other := prop("den", Vector2(5000, 200))
	assert_true(Spill.stashOf(other).is_empty(), "another den holds nothing")

#--- R-7 burrows and warrens ---------------------------------------------------------------------------------

func test_jackalopes_spawn_out_of_burrows():
	makeCar(Vector2(0, 0))
	var burrow := prop("burrow", Vector2(3000, 0))
	assert_true(burrow.is_in_group(&"prop_burrow"), "burrows are tagged")
	var spot := manager.preferredSpot(&"jackalope", Vector2(3200, 300))
	assert_almost_eq(spot.distance_to(burrow.global_position), SpawnManager.SPAWN_OFFSET[&"jackalope"], 1.0, "beside the mound")

func test_a_jackalope_dives_into_a_burrow_when_the_car_bears_down():
	var car := makeCar(Vector2(-380, 0))
	var burrow := prop("burrow", Vector2(120, 60))
	var j := goon(&"jackalope", Vector2(0, 0), true)
	await frames(2)
	j.setState(&"move")
	car.velocity = Vector2.ZERO
	assert_false(j.verb.tryHide(1.0, car), "a parked car scares nobody")
	car.velocity = Vector2(400, 0)
	assert_true(j.verb.tryHide(1.0, car), "a car coming fast does")
	assert_eq(burrow.get_meta(&"occupant"), j, "the burrow knows who is in it")
	await frames(int(GoonVerbs.Hopper.HIDE_DIVE * 60) + 4)
	assert_eq(j.state, &"hidden", "down the hole")
	assert_true(j.invulnerable && j.collision_layer == 0, "out of reach")
	assert_false(j.sprite.visible, "and out of sight")
	var j2 := goon(&"jackalope", Vector2(40, 0), true)
	await frames(2)
	j2.setState(&"move")
	assert_false(j2.verb.tryHide(1.0, car), "one to a burrow")

func test_a_collapsed_burrow_flushes_its_jackalope_out_stunned():
	var car := makeCar(Vector2(-380, 0))
	car.velocity = Vector2(400, 0)
	var burrow := prop("burrow", Vector2(120, 60))
	var j := goon(&"jackalope", Vector2(0, 0), true)
	await frames(2)
	j.setState(&"move")
	j.verb.tryHide(1.0, car)
	await frames(int(GoonVerbs.Hopper.HIDE_DIVE * 60) + 4)
	assert_almost_eq(BreakableProp.speedKeep(burrow), 0.95, 0.001, "a mound barely slows the car")
	BreakableProp.smashNode(burrow, car)
	assert_eq(j.state, &"stun", "thrown out stunned")
	assert_false(j.invulnerable, "crushable")
	assert_true(j.collision_layer != 0 && j.sprite.visible, "solid and seen")
	assert_false(burrow.is_in_group(&"prop_burrow"), "it spawns no more")
	await get_tree().process_frame
	assert_eq(coinsOnLevel(), 1, "a coin")

func test_clearing_a_warren_pays_once():
	var car := makeCar(Vector2(0, 300))
	var burrows := []
	for i in 3:
		var b := prop("burrow", Vector2(i * 200.0, 0))
		b.set_meta(&"group", 77)
		burrows.push_back(b)
	var loner := prop("burrow", Vector2(0, 600))
	var coins := car.coin
	var xp := car.crushXp
	BreakableProp.smashNode(burrows[0], car)
	BreakableProp.smashNode(burrows[1], car)
	assert_eq(car.coin, coins, "two of three: nothing yet")
	BreakableProp.smashNode(burrows[2], car)
	assert_eq(car.coin, coins + Spill.WARREN_COINS, "WARREN CLEARED")
	assert_almost_eq(car.crushXp - xp, Spill.WARREN_XP, 0.001, "and its crush XP")
	BreakableProp.smashNode(loner, car)
	assert_eq(car.coin, coins + Spill.WARREN_COINS, "a burrow in no warren pays no bonus")
	car.global_position = Vector2(0, 5000)
	for i in 2:
		var b := prop("burrow", Vector2(i * 200.0, 1200))
		b.set_meta(&"group", 78)
		BreakableProp.smashNode(b, null)
	assert_eq(car.coin, coins + Spill.WARREN_COINS, "nor one cleared far from the car")

#--- R-9 bee yards -----------------------------------------------------------------------------------------

func liveSwarms() -> Array:
	return get_children().filter(func(n): return n is Spill.Swarm && not n.leaving())

func test_a_swarm_stings_the_car_only_when_the_car_broke_its_hive():
	var car := makeCar(Vector2(30, 0))
	var hive := prop("beehive", Vector2(0, 0))
	BreakableProp.smashNode(hive, null) #a goon knocked it
	var health := car.health
	await frames(40)
	assert_eq(car.health, health, "not the car's doing: no stings")
	var before := coinsOnLevel()
	BreakableProp.smashNode(prop("beehive", Vector2(0, 2500)), null)
	await get_tree().process_frame
	assert_eq(coinsOnLevel() - before, BreakableProp.COIN_SPILL[&"beehive"], "a hive spills its honey coins")
	car.global_position = Vector2(3030, 0)
	var hive2 := prop("beehive", Vector2(3000, 0))
	BreakableProp.smashNode(hive2, car)
	await frames(40)
	assert_true(car.health < health, "the car broke this one: stung")

func test_live_swarms_are_capped():
	makeCar(Vector2(0, 4000))
	for i in Spill.SWARM_CAP + 2: BreakableProp.smashNode(prop("beehive", Vector2(i * 600.0, 0)), null)
	assert_eq(liveSwarms().size(), Spill.SWARM_CAP, "the oldest go when a new one comes")

func test_a_raiding_bandit_is_stung_first():
	makeCar(Vector2(0, 4000))
	var hive := prop("beehive", Vector2(0, 0))
	var bystander := goon(&"grunt", Vector2(60, 0), true)
	var bandit := goon(&"bandit", Vector2(-300, 0), true)
	hive.set_meta(&"raider", bandit)
	BreakableProp.smashNode(hive, null)
	var swarm: Spill.Swarm = liveSwarms()[0]
	assert_eq(swarm.first, bandit, "the swarm knows who raided it")
	for i in 120:
		await get_tree().physics_frame
		if flattened(bandit): break
	assert_true(flattened(bandit), "the raider is stung")
	assert_eq(swarm.kills, 1 if not flattened(bystander) else 2, "the raider before anything else")

#--- R-10 lures ----------------------------------------------------------------------------------------------

func test_lures_can_take_heavies_only_and_let_go_near_the_car():
	Pickups.lures = []
	Pickups.addLure(Vector2.ZERO, 800.0, INF, &"", 3, 400.0, 99)
	assert_eq(Pickups.lureFor(Vector2(300, 0), &"lunge", 3, 2000.0), Vector2.ZERO, "a heavy is drawn")
	assert_eq(Pickups.lureFor(Vector2(300, 0), &"lunge", 1, 2000.0), Vector2.INF, "fodder isn't")
	assert_eq(Pickups.lureFor(Vector2(300, 0), &"lunge", 3, 300.0), Vector2.INF, "nor a heavy the car is on")
	Pickups.removeLure(99)
	assert_true(Pickups.lures.is_empty(), "taken back")

func test_the_dinner_bell_calls_every_goon_near_once():
	makeCar(Vector2(-2000, 0))
	Pickups.lures = []
	var reactions: PropReactions = add_child_autofree(PropReactions.new())
	var bell := prop("bell", Vector2(0, 0))
	var g := goon(&"grunt", Vector2(900, 0))
	await frames(2)
	PropReactions.hit(bell, Vector2(Spill.BELL_RAM - 40.0, 0))
	assert_true(Pickups.lures.is_empty(), "a nudge doesn't ring it")
	assert_eq(SmashTags.smashSpeed(bell), Spill.BELL_RAM, "its tag shows the ram that rings it")
	PropReactions.hit(bell, Vector2(Spill.BELL_RAM + 50.0, 0))
	assert_eq(Pickups.lures.size(), 1, "CLANG")
	assert_eq(Pickups.lureFor(g.global_position, &"lunge", 1, 2000.0), bell.global_position, "goons in range go to it")
	assert_eq(Pickups.lureFor(Vector2(Spill.BELL_LURE + 100.0, 0), &"lunge", 1, 2000.0), Vector2.INF, "not beyond it")
	await frames(3)
	assert_eq(g.state, &"lured", "the grunt walks over")
	assert_false(Spill.ringBell(bell, 9999.0), "once per bell")
	assert_eq(SmashTags.smashSpeed(bell), INF, "no tag once rung")
	reactions.queue_free()

func test_a_salt_lick_lures_heavies_while_loaded():
	makeCar(Vector2(0, 5000))
	Pickups.lures = []
	var lick := prop("saltlick", Vector2(0, 0))
	assert_eq(Pickups.lureFor(Vector2(600, 0), &"lunge", 3, 3000.0), lick.global_position, "a Bullmoose drifts to it")
	assert_eq(Pickups.lureFor(Vector2(600, 0), &"pack", 1, 3000.0), Vector2.INF, "a Yipper doesn't")
	Spill.disarm(lick)
	assert_eq(Pickups.lureFor(Vector2(600, 0), &"lunge", 3, 3000.0), Vector2.INF, "gone with its chunk")

func test_a_salt_lick_costs_the_fodder_nothing_and_heavies_a_look_every_few_ticks():
	makeCar(Vector2(0, 5000))
	Pickups.lures = []
	var lick := prop("saltlick", Vector2(0, 0))
	var due := 0
	for phase in Pickups.LURE_POLL:
		assert_false(Pickups.lureCheckDue(1, false, phase), "a rank-1 goon never reads it")
		if Pickups.lureCheckDue(3, false, phase): due += 1
	assert_eq(due, 1, "a heavy looks once every LURE_POLL ticks")
	assert_true(Pickups.lureCheckDue(3, true, 1), "a lured heavy keeps looking")
	Pickups.addLure(Vector2(0, 0), 500.0, 5.0)
	assert_true(Pickups.lureCheckDue(1, false, 1), "a timed lure is read by everyone every tick")
	Spill.disarm(lick)

#--- R-11 scarecrows ---------------------------------------------------------------------------------------

func test_buzzards_roost_on_scarecrows_and_a_ram_drops_them():
	var car := makeCar(Vector2(0, 2000))
	var crow := prop("scarecrow", Vector2(0, 0))
	assert_true(crow.is_in_group(BreakableProp.ROOST_GROUP), "a scarecrow is a roost")
	var bird := goon(&"buzzard", Vector2(300, 0))
	await frames(2)
	bird.cooldown = 0.0
	for i in 200:
		await get_tree().physics_frame
		if bird.state == &"roost": break
	assert_eq(bird.state, &"roost", "it perches on the scarecrow")
	assert_eq(SmashTags.smashSpeed(crow), Spill.ROOSTS[&"scarecrow"].knock, "its tag shows the knock")
	assert_eq(Spill.knockRoost(crow, Spill.ROOSTS[&"scarecrow"].knock + 10.0), 1, "a ram knocks it down")
	assert_eq(bird.state, &"stun")
	assert_true(crow.get_node("Sprite2D").has_meta(&"spinning"), "the scarecrow spins")
	BreakableProp.smashNode(crow, car)
	assert_false(crow.is_in_group(BreakableProp.ROOST_GROUP), "a smashed one is no roost")

#--- one crate ---------------------------------------------------------------------------------------------

func test_chunk_crates_are_the_baked_crate_and_pay_once():
	var car := makeCar(Vector2(0, 3000))
	var objects: Node2D = add_child_autofree(Node2D.new())
	var rng := RandomNumberGenerator.new()
	for s in 400:
		rng.seed = s
		PickupWorld.decorateChunk(objects, rng)
		if objects.get_children().any(func(n): return BreakableProp.propId(n) == &"crate"): break
		for n in objects.get_children(): n.free()
	var crates := objects.get_children().filter(func(n): return BreakableProp.propId(n) == &"crate")
	assert_true(crates.size() >= 2, "a chunk's crates")
	var crate: StaticBody2D = crates[0]
	assert_true(crate.is_in_group(&"prop_crate"), "Bandits know them")
	assert_true(BreakableProp.isBreakable(crate) && crate.get_meta(&"oneShot", false), "a baked breakable, remembered by position")
	assert_eq(BreakableProp.PICKUP_SPILL[&"crate"], 0.35)
	assert_eq(BreakableProp.spillPickup(&"crate", Vector2.ZERO, Vector2.RIGHT, 0.99), "", "most crates pay coins only")
	assert_ne(BreakableProp.spillPickup(&"crate", Vector2.ZERO, Vector2.RIGHT, 0.0), "", "some pay a pickup too")
	var at := crate.global_position
	BreakableProp.smashNode(crate, car)
	assert_true(Spill.isUsed(at), "a smashed one is remembered")
	var again: Node2D = Spill.productScene(&"crate").instantiate()
	BreakableProp.makeOneShot(again)
	again.position = at
	add_child(again)
	await get_tree().process_frame
	assert_false(is_instance_valid(again), "so a reloaded chunk doesn't bring it back")

#--- spills and breakables ---------------------------------------------------------------------------------

func test_every_hero_tag_is_a_prop_that_does_something():
	var m := WorldSkin.loadManifest()
	for id in SmashTags.HEROES:
		var e: Dictionary = m.get(String(id), {})
		assert_false(e.is_empty(), "%s is a baked prop" % id)
		var acts: bool = e.get("breakable") is Dictionary || e.get("explosive", false) || id in [&"crane", &"bell", &"saguaro"]
		assert_true(acts, "%s breaks, blows or answers a ram" % id)
	for id in [&"den", &"burrow", &"farmgate", &"pumpkin", &"still", &"sluice", &"rockpile", &"tnt", &"saguaro", &"ranger_tower", &"fallen_trunk", &"bell", &"scarecrow"]:
		assert_true(SmashTags.HEROES.has(id), "%s has a smash tag and a first-meeting hint" % id)

func test_a_still_blows_up_burns_and_chains():
	makeCar(Vector2(0, 4000))
	var still := prop("still", Vector2(0, 0))
	var barrel := prop("barrel", Vector2(BreakableProp.BLAST[&"still"].x - 40.0, 0))
	var g := goon(&"grunt", Vector2(0, BreakableProp.BLAST[&"still"].x - 30.0))
	var out := goon(&"grunt", Vector2(0, BreakableProp.BLAST[&"still"].x + 120.0))
	BreakableProp.smashNode(still, null)
	await get_tree().process_frame
	assert_true(flattened(g), "inside the blast")
	assert_false(flattened(out), "outside it")
	assert_true(manager.fx.hazards.any(func(h): return h.kind == "fire"), "it leaves fire behind")
	await frames(int(BreakableProp.CHAIN_DELAY * 60) + 6)
	assert_true(barrel.get_meta(&"smashed", false), "and sets the barrel off")

func test_tnt_is_an_explosive_with_its_own_blast():
	makeCar(Vector2(0, 4000))
	var tnt := prop("tnt", Vector2(0, 0))
	assert_true(tnt.is_in_group(BreakableProp.EXPLOSIVE_GROUP), "TNT chains")
	var g := goon(&"grunt", Vector2(BreakableProp.BLAST[&"tnt"].x - 30.0, 0))
	BreakableProp.smashNode(tnt, null)
	await get_tree().process_frame
	assert_true(flattened(g), "BOOM")
	assert_false(manager.fx.hazards.any(func(h): return h.kind == "fire"), "no fire from TNT")

func test_a_rock_pile_sets_off_a_rockslide():
	var car := makeCar(Vector2(0, -600))
	var pile := prop("rockpile", Vector2(0, 0))
	var victim := goon(&"grunt", Vector2(320, 0))
	pile.set_meta(&"spillDir", Vector2.RIGHT)
	BreakableProp.smashNode(pile, null)
	var rollers := get_children().filter(func(n): return n is Spill.Roller)
	assert_eq(rollers.size(), Spill.DEFS[&"rockpile"].count, "the boulders roll out")
	assert_true(rollers.all(func(r): return r.id == &"rock_roll" && r.spin), "as tumbling boulders")
	await frames(int(Spill.LOG_SECONDS * 60) + 10)
	assert_true(flattened(victim), "flattening what is in the way")
	assert_true("ROCKS" in car.chainSources, "named ROCKS in the chain")
	var rocks := get_children().filter(func(n): return n is StaticBody2D && n.get_meta(&"propId", &"") == &"rock_roll")
	assert_eq(rocks.size(), Spill.DEFS[&"rockpile"].count, "and lying where they stop")

func waterRule(p: Vector2) -> int:
	if absf(p.y) < 120.0: return Root.terrain.WATER
	if absf(p.y) < 260.0: return Root.terrain.SHALLOWS
	return Root.terrain.GRASS

func test_a_sluice_floods_the_shallows_along_its_channel():
	makeCar(Vector2(0, 3000))
	var map := RuleMap.new()
	map.rule = waterRule
	Root.worldMap = map
	assert_eq(Spill.channelAxis(Vector2(0, 0), Vector2.DOWN).abs(), Vector2.RIGHT, "the channel runs along x")
	var sluice := prop("sluice", Vector2(0, -200), PI / 2.0)
	var wading := goon(&"grunt", Vector2(380, -190), true)
	var other := goon(&"grunt", Vector2(-300, -240), true)
	var dry := goon(&"grunt", Vector2(100, -330), true)
	var beyond := goon(&"grunt", Vector2(Spill.FLOOD_LENGTH * 0.5 + 250.0, -200), true)
	BreakableProp.smashNode(sluice, null)
	assert_true(flattened(wading), "a goon wading in the flood's path is swept away")
	assert_true(flattened(other), "on either bank's shallows")
	assert_false(flattened(dry), "one on the grass is not")
	assert_false(flattened(beyond), "nor one past the flood's reach")

func test_only_hero_saguaros_topple():
	var car := makeCar(Vector2(0, -400))
	var plain := prop("saguaro", Vector2(3000, 0))
	assert_false(BreakableProp.isBreakable(plain), "a scattered saguaro is scenery")
	assert_false(plain.is_in_group(Spill.SPILL_GROUP), "and no blast topples it")
	var hero: StaticBody2D = load("res://world/art/props/saguaro.tscn").instantiate()
	hero.set_meta(&"hero", true)
	add_child_autofree(hero)
	Spill.arm(hero)
	assert_eq(BreakableProp.speedOf(hero), Spill.SAGUARO_SMASH, "a hero one topples at 38 MPH")
	var under := goon(&"grunt", Vector2(0, 150), true)
	var spiked := goon(&"grunt", Vector2(110, Spill.SAGUARO_BOX.end.y + 60.0), true)
	var heavy := goon(&"tusker", Vector2(-110, Spill.SAGUARO_BOX.end.y + 60.0), true)
	var behind := goon(&"grunt", Vector2(0, -150), true)
	BreakableProp.smashNode(hero, car)
	assert_true(flattened(under), "it falls away from the car onto what is there")
	assert_true(flattened(spiked), "its spines flatten fodder round the crown")
	assert_false(flattened(heavy), "not a heavy")
	assert_false(flattened(behind), "the car's side is clear")
	assert_true("SPINES" in car.chainSources)

func test_a_charge_topples_a_ranger_tower_along_it_and_a_deadfall_drops():
	makeCar(Vector2(0, 5000))
	var tower := prop("ranger_tower", Vector2(0, 0))
	assert_true(BreakableProp.speedOf(tower) > 110.0 * 3.6, "too much for a Tusker's charge")
	var g := goon(&"grunt", Vector2(0, -200), true)
	tower.set_meta(&"spillDir", Vector2.UP)
	BreakableProp.smashNode(tower, null)
	assert_true(flattened(g), "it falls the way it was pushed")
	var trunk := prop("fallen_trunk", Vector2(3000, 0))
	var plainVictim := goon(&"grunt", Vector2(3100, 0), true)
	BreakableProp.smashNode(trunk, null)
	assert_false(flattened(plainVictim), "a plain fallen trunk just breaks")
	var lean := prop("fallen_trunk", Vector2(6000, 0))
	lean.get_node("Sprite2D").texture = load("res://world/art/props/fallen_trunk_v2.png")
	Spill.arm(lean) #ChunkView gives it its variant before PropReactions.addHero arms it
	assert_true(Spill.isDeadfall(lean), "the leaning one is the deadfall")
	var victim := goon(&"grunt", Vector2(6100, 30), true)
	BreakableProp.smashNode(lean, null)
	assert_true(flattened(victim), "it drops across the trail")

func test_pumpkins_and_gates_pay_and_barely_slow_the_car():
	makeCar(Vector2(0, 5000))
	var pumpkin := prop("pumpkin", Vector2(0, 0))
	assert_almost_eq(BreakableProp.speedKeep(pumpkin), 0.98, 0.001)
	assert_eq(BreakableProp.speedOf(pumpkin), 40.0, "4 MPH")
	var gate := prop("farmgate", Vector2(0, 1500))
	BreakableProp.smashNode(pumpkin, null)
	BreakableProp.smashNode(gate, null)
	await get_tree().process_frame
	assert_eq(coinsOnLevel(), BreakableProp.COIN_SPILL[&"pumpkin"] + BreakableProp.COIN_SPILL[&"farmgate"], "a coin and two")

func test_an_orchard_oak_drops_apples_once():
	makeCar(Vector2(0, 5000))
	var oak := prop("oak", Vector2(0, 0))
	assert_false(Spill.shakeOak(oak, 9999.0), "not on Prairie Run")
	stub.def = stub.def.duplicate()
	stub.def.rules = {"oakCoins": 2}
	assert_false(Spill.shakeOak(oak, Spill.OAK_SHAKE - 50.0), "a tap does nothing")
	var reactions: PropReactions = add_child_autofree(PropReactions.new())
	PropReactions.hit(oak, Vector2(Spill.OAK_SHAKE + 100.0, 0))
	await get_tree().process_frame
	assert_eq(coinsOnLevel(), 2, "a hard hit shakes the apples down")
	assert_false(Spill.shakeOak(oak, 9999.0), "once")
	var again := prop("oak", Vector2(0, 0))
	assert_true(again.get_meta(&"spilled", false), "even after its chunk reloads")
	reactions.queue_free()

#--- world events and the levels' rules ---------------------------------------------------------------------

func test_world_events_start_only_where_a_level_weighs_them():
	assert_false(PickupWorld.openEvents({}).any(func(k): return k in PickupWorld.WORLD_EVENTS), "no weights: no world event")
	var open := PickupWorld.openEvents({"stampede": 4, "goldgoon": 2})
	assert_true("stampede" in open && not "flood" in open, "the level's own")
	for i in 20: assert_true(PickupWorld.pickEvent(open, {"stampede": 4, "goldgoon": 2}) in ["stampede", "goldgoon"])
	assert_true("haywagon" in PickupWorld.openEvents({"haywagon": 2}), "a truck re-skin opens with the truck")

func test_the_wilds_levels_rules():
	var want := {
		&"prairie": [0.25, {"goldgoon": 3, "rings": 2, "bowling": 1}],
		&"orchard": [0.3, {"rings": 3, "goldgoon": 2, "haywagon": 2, "stampede": 1}],
		&"bayou": [0.4, {"goldgoon": 2, "rings": 2, "barge": 1}],
		&"canyon": [0.35, {"flood": 3, "goldgoon": 2, "rings": 1}],
		&"moosewoods": [0.5, {"stampede": 4, "goldgoon": 2}],
	}
	for id in want:
		var rules: Dictionary = Levels.get_def(id).rules
		assert_almost_eq(float(rules.nightShare), want[id][0], 0.001, "%s: night share" % id)
		assert_eq(rules.events, want[id][1], "%s: events" % id)
		assert_true(rules.dazeHeavies, "%s: dazed heavies" % id)
	assert_false(Levels.get_def(&"prairie").rules.events.has("stampede"), "no out-of-line-up stampede on Prairie Run")
	assert_eq(Levels.get_def(&"orchard").rules.get("oakCoins", 0), 2, "Orchard Lanes' oaks drop apples")

func test_a_stampede_crosses_ahead_of_the_car():
	var car := makeCar(Vector2(0, 0))
	car.velocity = Vector2(300, 0)
	var stampede: WorldProps.Stampede = PickupWorld.spawnStampede(car)
	await get_tree().process_frame
	assert_true(stampede.is_inside_tree(), "the dust is out")
	assert_almost_eq(stampede.global_position.x, WorldProps.Stampede.AHEAD, 1.0, "off to the side of the path ahead")
	assert_true(absf(stampede.dir.y) > 0.99, "and it will run across the path")
	assert_true(PickupWorld.beacons.any(func(b): return b[0] == stampede), "with an edge arrow")
	assert_true(stampede.herd.is_empty(), "the herd waits")
	await frames(int(WorldProps.Stampede.WARN * 60) + 4)
	assert_eq(stampede.herd.size(), WorldProps.Stampede.HERD, "then breaks cover")
	for h in stampede.herd:
		assert_eq(h.state, &"drive", "stampeding")
		assert_true(h.verb.dir.dot(stampede.dir) > 0.95, "across the car's path")
		assert_eq(h.verb.calm, &"move", "an ordinary herd after")

func washRule(p: Vector2) -> int:
	return Root.terrain.WASH if absf(p.y) < 450.0 else Root.terrain.GRASS

func test_a_flash_flood_runs_down_the_wash_ahead():
	var car := makeCar(Vector2(0, 0))
	car.velocity = Vector2(300, 0)
	var map := RuleMap.new()
	map.rule = washRule
	Root.worldMap = map
	var found := WorldProps.FlashFlood.locate(car)
	assert_false(found.is_empty(), "there is a wash ahead")
	assert_eq(found[1], Vector2.RIGHT, "it runs the way the car goes")
	assert_true(found[0].x < 500.0 && absf(found[0].y) < 450.0, "from upstream, on the wash")
	Root.worldMap = RuleMap.new()
	Root.worldMap.rule = func(_p): return Root.terrain.GRASS
	assert_true(WorldProps.FlashFlood.locate(car).is_empty(), "no wash, no flood")
	Root.worldMap = map

func test_a_flash_flood_sweeps_the_wash_and_carries_the_car():
	var car := makeCar(Vector2(-400, 600))
	var map := RuleMap.new()
	map.rule = washRule
	Root.worldMap = map
	var flood := WorldProps.FlashFlood.new()
	flood.dir = Vector2.RIGHT
	flood.age = WorldProps.FlashFlood.WARN
	flood.position = Vector2(-300, 0)
	add_child_autofree(flood)
	var onWash := goon(&"grunt", Vector2(150, 200), true)
	var onBank := goon(&"grunt", Vector2(150, 520), true)
	await frames(60)
	assert_true(flattened(onWash), "a goon on the wash is swept away")
	assert_false(flattened(onBank), "one on the bank is not")
	assert_true("SPLASH" in car.chainSources, "credited as SPLASH near the car")
	car.global_position = flood.global_position - Vector2(200, 0)
	car.velocity = Vector2.ZERO
	var health := car.health
	assert_true(flood.pushCar(), "the car on the wash behind the front...")
	assert_true(car.velocity.x > 0.0, "...is carried along")
	assert_eq(car.health, health, "never hurt")
	car.global_position = flood.global_position + Vector2(0, 600)
	assert_false(flood.pushCar(), "off the wash it is left alone")

func test_a_pooled_hero_saguaro_comes_back_whole():
	var car := makeCar(Vector2(0, 400)) #below it: it falls the other way
	var cactus: StaticBody2D = load("res://world/art/props/saguaro.tscn").instantiate()
	cactus.set_meta(&"hero", true)
	add_child_autofree(cactus)
	Spill.arm(cactus)
	BreakableProp.smashNode(cactus, car)
	assert_true(cactus.get_node("Sprite2D").scale.y < 0.0, "lying the other way")
	Spill.arm(cactus) #ChunkView hands the pooled prop out again
	await get_tree().physics_frame
	assert_false(cactus.get_meta(&"smashed", false), "standing again")
	assert_false(cactus.get_node("CollisionShape2D").disabled, "solid")
	assert_true(cactus.get_node("Sprite2D").scale.y > 0.0, "upright")
	cactus.remove_meta(&"hero")
	Spill.arm(cactus)
	assert_false(BreakableProp.isBreakable(cactus), "placed as scenery next time, it is scenery")
