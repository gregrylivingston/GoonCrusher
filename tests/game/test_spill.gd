extends GameTest

#Interactive props (package 14, P-4; docs/WORLD.md "Interactive props"): log piles roll logs that flatten goons
#and settle as props, water towers flood goons flat, billboards topple away from the car, hives let a swarm
#loose, cranes drop their container once, goons with "releases" cut a pile loose at the car, blasts set spills
#off, and the TileManager remembers what spilled.

class UiStub extends RefCounted:
	func updateStats() -> void: pass
	func updateGoonsCrushed() -> void: pass

var savedMap
var savedManager
var savedCar
var manager: SpawnManager

func before_each():
	savedMap = Root.worldMap
	savedManager = Root.spawnManager
	savedCar = Root.playerCar
	Root.worldMap = null
	manager = add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())

func after_each():
	Root.worldMap = savedMap
	Root.spawnManager = savedManager
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null

func prop(id: String, at := Vector2.ZERO, rot := 0.0) -> StaticBody2D:
	var node: StaticBody2D = load("res://world/art/props/%s.tscn" % id).instantiate()
	node.position = at
	node.rotation = rot
	if node.has_meta(&"smashSpeed"): node.set_script(load("res://scripts/world/breakable.gd"))
	add_child_autofree(node)
	return node

func goon(id: StringName, at: Vector2) -> Walker:
	var g: Walker = load(Goons.scenePath(id)).instantiate()
	g.position = at
	add_child_autofree(g)
	manager.registerGoon(g)
	return g

func makeCar(at: Vector2) -> OverheadCarBody2D:
	var car: OverheadCarBody2D = load("res://scene/car/sedan/sedan.tscn").instantiate()
	car.position = at
	add_child_autofree(car)
	car.ui = UiStub.new()
	Root.playerCar = car
	return car

## dead, or already freed after its death
func flattened(g) -> bool:
	return not is_instance_valid(g) || g.dead

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func test_spilling_props_are_baked_and_tagged():
	var m := WorldSkin.loadManifest()
	for id in ["logpile", "watertower", "beehive", "billboard"]:
		assert_true(m.get(id, {}).get("breakable") is Dictionary, "%s breaks (and so spills)" % id)
		assert_true(Spill.DEFS.has(StringName(id)), "%s has a spill" % id)
	var pile := prop("logpile")
	assert_true(pile.is_in_group(Spill.PILE_GROUP), "goons can find a log pile")
	assert_true(pile.is_in_group(Spill.SPILL_GROUP), "blasts can find it")
	assert_true(Spill.productScene(&"log") != null && Spill.productScene(&"container") != null, "what spills is loadable")

func test_a_log_pile_rolls_logs_that_flatten_goons_and_settle():
	var car := makeCar(Vector2(-4000, 0))
	var pile := prop("logpile")
	var victim := goon(&"grunt", Vector2(300, 0))
	var bystander := goon(&"grunt", Vector2(0, 900))
	pile.set_meta(&"spillDir", Vector2.RIGHT)
	BreakableProp.smashNode(pile, null)
	var rollers := get_children().filter(func(n): return n is Spill.Roller)
	assert_eq(rollers.size(), Spill.LOGS, "the logs roll out")
	await frames(int(Spill.LOG_SECONDS * 60) + 10)
	assert_true(flattened(victim), "a goon in the way is flattened")
	assert_false(flattened(bystander), "one off to the side is not")
	assert_true(car.currentGoonsCrushed >= 1, "and it counts as the player's crush")
	var logs := get_children().filter(func(n): return n is StaticBody2D && n.get_meta(&"propId", &"") == &"log")
	assert_eq(logs.size(), Spill.LOGS, "every log lies where it stopped as a prop")
	for l in logs:
		assert_true(l.global_position.x > 150.0, "downhill of the pile")
		assert_false(l.get_node("CollisionShape2D").disabled, "and is solid again")

func test_a_water_tower_floods_goons_flat():
	makeCar(Vector2(-4000, 0))
	var tower := prop("watertower")
	var near := goon(&"grunt", Vector2(200, 0))
	var far := goon(&"grunt", Vector2(Spill.WAVE_RADIUS + 300.0, 0))
	BreakableProp.smashNode(tower, null)
	assert_true(flattened(near), "inside the flood")
	assert_false(flattened(far), "outside it")

func test_a_billboard_topples_away_from_the_car():
	var car := makeCar(Vector2(0, -600))
	var board := prop("billboard")
	var under := goon(&"grunt", Vector2(0, 90))
	var behindCar := goon(&"grunt", Vector2(0, -90))
	BreakableProp.smashNode(board, car)
	assert_true(flattened(under), "the far side is flattened")
	assert_false(flattened(behindCar), "the car's side is not")
	assert_true(board.get_node("Sprite2D").scale.y > 0.0, "drawn falling away from the car")
	var other := prop("billboard", Vector2(3000, 0))
	car.global_position = Vector2(3000, 600)
	BreakableProp.smashNode(other, car)
	assert_true(other.get_node("Sprite2D").scale.y < 0.0, "hit from the other side, it falls the other way")

func test_a_hive_lets_a_swarm_loose_on_goons():
	makeCar(Vector2(-4000, 0))
	var hive := prop("beehive")
	var g := goon(&"grunt", Vector2(250, 0))
	BreakableProp.smashNode(hive, null)
	assert_eq(get_children().filter(func(n): return n is Spill.Swarm).size(), 1, "a swarm")
	await frames(90)
	assert_true(flattened(g), "it found the goon")

func test_a_crane_drops_its_container_once():
	makeCar(Vector2(-4000, 0))
	var crane := prop("crane")
	var tip := crane.to_global(Spill.DROP_TIP)
	var under := goon(&"grunt", tip + Vector2(30, 0))
	Spill.ramCrane(crane, Spill.DROP_SPEED * 0.5)
	assert_false(crane.get_meta(&"spilled", false), "a soft hit does nothing")
	Spill.ramCrane(crane, Spill.DROP_SPEED + 10.0)
	assert_true(crane.get_meta(&"spilled", false), "a hard one drops it")
	Spill.ramCrane(crane, 9999.0)
	assert_eq(get_children().filter(func(n): return n is Spill.Drop).size(), 1, "once")
	await frames(int(Spill.DROP_SECONDS * 60) + 6)
	assert_true(flattened(under), "whatever was under it")
	assert_eq(get_children().filter(func(n): return n is StaticBody2D && n.get_meta(&"propId", &"") == &"container").size(), 1, "the container stays as a prop")

func test_releasing_goons_cut_a_pile_loose_at_the_car():
	var car := makeCar(Vector2(0, 600))
	var pile := prop("logpile")
	var g := goon(&"grunt", Vector2(300, 0))
	assert_true(Goons.DATA[&"grunt"].get("releases", false), "grunts release piles")
	var verb = g.verb
	for i in 120:
		if pile.get_meta(&"smashed", false): break
		verb.seekRelease(1.0 / 60.0, car)
		await get_tree().physics_frame
	assert_true(pile.get_meta(&"smashed", false), "it walked over and cut it loose")
	assert_true(pile.get_meta(&"spillDir", Vector2.ZERO).dot(Vector2.DOWN) > 0.5, "aimed at the car")
	var far := makeCar(Vector2(0, 5000))
	var pile2 := prop("logpile", Vector2(3000, 0))
	var g2 := goon(&"grunt", Vector2(3300, 0))
	assert_false(g2.verb.seekRelease(0.6, far), "no car about: it does its own thing")
	assert_false(pile2.get_meta(&"smashed", false))
	assert_false(goon(&"tusker", Vector2(-300, 0)).verb.seekRelease(0.6, car), "only goons with releases do it")

func test_blasts_set_spills_off():
	makeCar(Vector2(-4000, 0))
	var pile := prop("logpile", Vector2(100, 0))
	var crane := prop("crane", Vector2(0, 2000))
	BreakableProp.blastAt(get_tree(), Vector2.ZERO, 200.0)
	BreakableProp.blastAt(get_tree(), Vector2(0, 2000), 200.0)
	await get_tree().process_frame
	assert_true(pile.get_meta(&"smashed", false), "the pile bursts")
	assert_true(pile.get_meta(&"spillDir", Vector2.ZERO).x > 0.0, "away from the blast")
	assert_true(crane.get_meta(&"spilled", false), "the crane lets go")

func test_the_tile_manager_remembers_spills():
	var tm: TileManager = load("res://scene/level/tileManager.gd").new()
	tm.tilesize = ChunkRecipe.CHUNK
	tm.addSpilled(&"log", Vector2(5200, 100), 0.5)
	tm.markSpillUsed(Vector2(100, 100))
	assert_eq(tm.spilledIn(Vector2i(1, 0)), [[&"log", Vector2(80, 100), 0.5]], "kept in its chunk, chunk-local")
	assert_true(tm.spillUsed(Vector2i(0, 0), Vector2(102, 99)), "a used crane stays used")
	assert_false(tm.spillUsed(Vector2i(0, 0), Vector2(900, 99)), "only that one")
	tm.free()
