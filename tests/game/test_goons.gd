extends GameTest

#The goon roster (docs/GOONS.md): every registry entry has baked art and a known verb, every faction can fill
#a region on every terrain, regions get factions by distance and level, and crush rules hold.

const PLAYABLE := [Goons.T.GRASS, Goons.T.SAND, Goons.T.MUD, Goons.T.MOSS, Goons.T.DIRT, Goons.T.SNOW]
const VERBS := [&"lunge", &"dodger", &"lobber", &"shooter", &"trapper", &"bomber", &"hitcher", &"turtle", &"boss", &"burrow",
	&"pack", &"roller", &"slammer", &"charger", &"hopper", &"thief", &"striker", &"spiky", &"flyer", &"herd", &"rider"]
const ANIMS := {&"walk": 8, &"idle": 4, &"windup": 4, &"attack": 6, &"special": 8, &"stun": 4}

var savedManager
var savedCar

func before_each():
	savedManager = Root.spawnManager
	savedCar = Root.playerCar

func after_each():
	Root.spawnManager = savedManager
	Root.playerCar = savedCar

func makeManager() -> SpawnManager:
	return add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())

func test_terrain_mirror_matches_root():
	for key in Root.terrain: assert_eq(Goons.T[key], Root.terrain[key], "Goons.T.%s" % key)

func test_every_goon_has_baked_art_and_a_known_verb():
	for id in Goons.DATA:
		var d: Dictionary = Goons.DATA[id]
		assert_true(d.verb in VERBS, "%s: verb %s" % [id, d.verb])
		assert_true(ResourceLoader.exists(Goons.scenePath(id)), "%s: scene baked" % id)
		var scene: PackedScene = load(Goons.scenePath(id))
		if scene == null: continue
		var goon = scene.instantiate()
		assert_eq(goon.goonId, id, "%s: goonId" % id)
		assert_true(goon.decal != null, "%s: crush decal" % id)
		var frames: SpriteFrames = goon.get_node("Sprite").sprite_frames
		for anim in ANIMS: assert_eq(frames.get_frame_count(anim), ANIMS[anim], "%s: %s frames" % [id, anim])
		goon.free()

func test_every_faction_fills_a_region_on_every_terrain():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for f in [Goons.faction.WILD, Goons.faction.TRIBE, Goons.faction.SCRAP]:
		for t in PLAYABLE:
			assert_true(Goons.pool(f, t).size() >= 3, "%s on terrain %d has 3+ goons" % [Goons.factionName(f), t])
			var three := Goons.regionGoons(f, t, rng)
			assert_eq(three.size(), 3, "three goons")
			for id in three:
				assert_eq(Goons.DATA[id].faction, f, "%s belongs to %s" % [id, Goons.factionName(f)])
				assert_true(t in Goons.DATA[id].biomes, "%s lives on terrain %d" % [id, t])
			assert_eq(Goons.DATA[three[0]].rank, Goons.pool(f, t).map(func(id): return Goons.DATA[id].rank).min(), "the first goon is the faction's lowest rank there")

func test_factions_rise_with_distance_and_level():
	assert_eq(Goons.factionFor(0.0, 0, 0.0), Goons.faction.WILD, "the start of level 1 is wild")
	assert_eq(Goons.factionFor(Goons.CHUNK_PX * 4.0, 0, 0.0), Goons.faction.TRIBE, "four chunks out is tribal")
	assert_eq(Goons.factionFor(Goons.CHUNK_PX * 8.0, 0, 0.0), Goons.faction.SCRAP, "far out is the Scrap Gang")
	assert_eq(Goons.factionFor(0.0, 7, 0.0), Goons.faction.TRIBE, "the start of the last level is already tribal")

func test_waves_bring_goons_two_and_three():
	for i in 50: assert_true(Goons.pickSlot(1, i / 50.0) < 2, "wave 1 never spawns goon 3")
	var seen := {}
	for i in 100: seen[Goons.pickSlot(4, i / 100.0)] = true
	assert_eq(seen.size(), 3, "wave 4 spawns all three")

func test_regions_get_a_faction_and_its_goons():
	var region: Dictionary = Region.createRegion(Root.terrain.SAND)
	assert_true(region.has("faction"), "faction stored")
	for key in ["name", "giantism", "time", "wave", "goon"]: assert_true(region.has(key), "keeps %s for the HUD" % key)
	for id in region.goon: assert_eq(Goons.DATA[id].faction, region.faction, "%s matches the region" % id)

func spawnGoon(id: StringName, at := Vector2.ZERO) -> Walker:
	var goon: Walker = load(Goons.scenePath(id)).instantiate()
	goon.position = at
	add_child_autofree(goon)
	return goon

func makeCar():
	return add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())

func test_shields_block_head_on_but_not_from_the_side():
	makeManager()
	var car = makeCar()
	var goon := spawnGoon(&"hubcap")
	goon.rotation = 0.0 #facing +x
	car.global_position = Vector2(80, 0) #in front of the shield
	assert_false(goon.tryCrush(car, 250.0), "head-on below 380 is blocked")
	goon.resistTimer = 0.0
	car.global_position = Vector2(0, 80) #beside it
	assert_true(goon.tryCrush(car, 250.0), "from the side it crushes")

func test_heavies_need_speed_and_shells_need_a_kick():
	makeManager()
	var car = makeCar()
	var yeti := spawnGoon(&"yeti")
	assert_false(yeti.tryCrush(car, 300.0), "the yeti shrugs off 300 px/s")
	assert_true(yeti.tryCrush(car, 400.0), "but not 400")
	var shell := spawnGoon(&"shellback", Vector2(500, 0))
	shell.setState(&"hidden")
	shell.invulnerable = true
	assert_false(shell.tryCrush(car, 600.0), "a hidden shell can't be crushed")
	assert_eq(shell.state, &"slide", "a fast hit kicks it instead")

func test_ai_driver_modes_follow_the_tell():
	makeManager()
	var goon := spawnGoon(&"grunt")
	goon.setState(&"windup")
	assert_eq(goon.myMode, Walker.mode.PREPAREATTACK, "the tell reads as PREPAREATTACK")
	goon.setState(&"attack")
	assert_eq(goon.myMode, Walker.mode.ATTACK, "the lunge reads as ATTACK")
	goon.destroy(&"drown")
	assert_true(goon.isDying(), "dead goons report it")
