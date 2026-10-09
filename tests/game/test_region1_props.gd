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

func level(id: StringName) -> LevelStub:
	var s := LevelStub.new()
	s.def = Levels.defAt(Levels.indexOf(id))
	var tm := Node.new()
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
