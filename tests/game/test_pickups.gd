extends GameTest

#Pickups (scripts/global/pickups.gd, docs/PICKUPS.md): the registry is complete, drops roll by rarity
#tier and mode, timed power-ups run on physics ticks, and the car's buffs, gadget slot and crush
#overrides behave. The save's meta.pickups is swapped for a scratch dictionary, so nothing is written.

const SCRIPTS := ["res://scene/pickups/pickup.gd", "res://scene/pickups/pickup_effects.gd", "res://scene/pickups/car_buff_fx.gd",
	"res://scene/pickups/gadgets.gd", "res://scene/pickups/pickup_nodes.gd", "res://scene/pickups/world_props.gd",
	"res://scene/pickups/pickup_world.gd", "res://scene/pickups/menus/pickup_menu.gd", "res://scene/pickups/menus/pickup_deal.gd",
	"res://scene/pickups/menus/claw_crane.gd", "res://scene/pickups/menus/pit_shop.gd", "res://scene/player/hud/hud_items.gd",
	"res://scene/player/hud/hud_chance.gd", "res://scene/player/slots/slot_symbols.gd"]

var savedMeta

func before_each():
	savedMeta = SaveManager.playerData.meta.get("pickups")
	SaveManager.playerData.meta["pickups"] = {}
	Pickups.resetRun()

func after_each():
	if savedMeta == null: SaveManager.playerData.meta.erase("pickups")
	else: SaveManager.playerData.meta["pickups"] = savedMeta
	Pickups.resetRun()

func car() -> OverheadCarBody2D:
	return add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())

func test_every_new_script_compiles():
	for path in SCRIPTS:
		var script: Script = load(path)
		assert_true(script != null && script.can_instantiate(), path)

func test_every_pickup_is_complete():
	for id in Pickups.DATA:
		var d: Dictionary = Pickups.DATA[id]
		for key in ["name", "kind", "rarity", "w", "icon", "text", "ui"]: assert_true(d.has(key), "%s has %s" % [id, key])
		assert_true(ResourceLoader.exists("res://texture/icon/%s.svg" % d.icon), "%s: icon %s.svg" % [id, d.icon])
		if d.kind == Pickups.K.BOOST: assert_gt(Pickups.ticks(id), 0, "%s lasts" % id)
		if d.kind == Pickups.K.GADGET: assert_true(d.has("charges"), "%s has charges" % id)
		if d.has("scene"): assert_true(ResourceLoader.exists(d.scene), "%s scene" % id)

func test_every_pickup_flies_to_a_hud_widget():
	var hud = load("res://scene/player/playerRoot.tscn").instantiate()
	hud.get_node("TopCenter/Timer").free()
	add_child(hud)
	await get_tree().process_frame
	for id in Pickups.DATA:
		var target = get_tree().get_first_node_in_group(Pickups.uiGroup(id))
		assert_true(is_instance_valid(target) && hud.is_ancestor_of(target), "%s flies to %s" % [id, Pickups.uiGroup(id)])
	hud.free()

func test_generic_pickups_take_their_look_from_the_registry():
	for id in ["nitro", "wrench", "nuke", "starfrag"]:
		var node = add_child_autofree(Pickups.make(id))
		assert_true(node is GenericPickup, id)
		assert_eq(node.texture, Pickups.texture(id), id + " icon")
		assert_eq(node.powerup, id, "the AI driver reads powerup")
	assert_false(Pickups.make("fuel") is GenericPickup, "originals keep their scenes")

func test_every_tier_has_something_in_every_mode():
	for mode in Root.gameModes.values():
		for tier in [Pickups.R.COMMON, Pickups.R.UNCOMMON, Pickups.R.RARE, Pickups.R.EPIC, Pickups.R.LEGENDARY]:
			assert_false(Pickups.candidates(tier, mode, false).is_empty(), "mode %d tier %d by day" % [mode, tier])

func test_dice_raises_the_rare_tiers_only():
	var plain = Pickups.tierWeights(0.0)
	var lucky = Pickups.tierWeights(40.0)
	assert_eq(lucky[0], plain[0], "common keeps its weight")
	for t in range(1, 5): assert_gt(lucky[t], plain[t], "tier %d rises" % t)
	assert_eq(Pickups.pickTier([1.0, 1.0], 0.25), 0)
	assert_eq(Pickups.pickTier([1.0, 1.0], 0.75), 1)

func test_rolls_respect_mode_and_night():
	for i in 400:
		var id := Pickups.roll(0.0, Root.gameModes.GOONCRUSHER, false)
		assert_true(Pickups.allowedIn(id, Root.gameModes.GOONCRUSHER), "%s allowed in Countdown" % id)
		assert_false(Pickups.def(id).get("night", false), "%s is night-only" % id)
		assert_true(Pickups.def(id).get("w", 0) > 0, "%s is a drop" % id)

func test_pity_gives_a_rare_after_a_dry_spell():
	Pickups.dropsSinceRare = Pickups.PITY - 1
	assert_true(Pickups.rarity(Pickups.roll(0.0, Root.gameModes.GOONCRUSHER, false)) >= Pickups.R.RARE)
	assert_eq(Pickups.dropsSinceRare, 0)

func test_goon_drop_tables_roll_through_the_registry():
	var walker = Walker.new()
	walker.def = {"faction": Goons.faction.SCRAP}
	var table = walker.dropTable()
	assert_true(table.has(Pickups.ROLL), "goons drop by rarity")
	walker.free()
	var drop = add_child_autofree(Root.getPowerupFromWeights(table))
	assert_true(drop is Powerup, "a pickup node")

func test_timed_buffs_run_on_physics_ticks():
	var c = car()
	c.addBuff("nitro")
	assert_true(c.hasBuff("nitro"))
	for i in Pickups.ticks("nitro") - 1: c.tickPickups()
	assert_true(c.hasBuff("nitro"), "still on one tick before the end")
	c.tickPickups()
	assert_false(c.hasBuff("nitro"), "gone after its ticks")

func test_nitro_pulls_harder_inside_integrate():
	var c = car()
	var input = OverheadCarBody2D.CarInput.new()
	input.acceleration = 1.0
	var plain: Vector2 = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(200, 0), input, 1.0 / 60.0)[1]
	c.addBuff("nitro")
	var boosted: Vector2 = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(200, 0), input, 1.0 / 60.0)[1]
	assert_gt(boosted.x, plain.x, "nitro accelerates harder")

func test_a_fifth_buff_replaces_the_shortest():
	var c = car()
	for id in ["shield", "magnet", "frenzy", "plow"]: c.addBuff(id)
	c.buffs["magnet"] = 5
	c.addBuff("spikes")
	assert_eq(c.buffs.size(), OverheadCarBody2D.MAX_BUFFS)
	assert_false(c.hasBuff("magnet"), "the one with least time went")

func test_plow_crushes_ahead_only():
	var c = car()
	c.global_position = Vector2.ZERO
	var goon = add_child_autofree(Node2D.new())
	goon.global_position = Vector2(150, 0)
	assert_false(c.crushOverride(goon), "no buff, no override")
	c.addBuff("plow")
	assert_true(c.crushOverride(goon), "ahead")
	goon.global_position = Vector2(-150, 0)
	assert_false(c.crushOverride(goon), "behind")
	c.addBuff("monster")
	assert_true(c.crushOverride(goon), "monster tires crush anything")

func test_shield_soaks_hits_and_counts_real_ones():
	var c = car()
	c.addBuff("shield")
	var hull = c.health
	c.damage(5.0)
	assert_eq(c.health, hull, "a contact bump is soaked")
	assert_eq(c.shieldHits, 3, "and doesn't use a hit")
	for i in 3: c.damage(40.0)
	assert_eq(c.health, hull, "three real hits soaked")
	assert_false(c.hasBuff("shield"), "then it pops")
	c.damage(40.0)
	assert_true(c.health < hull, "the fourth lands")

func test_gadget_slot_keeps_the_rarer_one():
	var c = car()
	assert_true(c.giveItem("horn"))
	assert_eq(c.heldCharges, 3)
	assert_true(c.giveItem("horn"), "the same gadget stacks")
	assert_eq(c.heldCharges, 6)
	assert_true(c.giveItem("mine"), "rarer replaces")
	assert_eq(c.heldItem, "mine")
	assert_false(c.giveItem("oilslick"), "commoner is refused (sold)")
	assert_eq(c.heldItem, "mine")

func test_supplies_and_tune_ups():
	var c = car()
	c.setCondition("tires", 10.0)
	c.setCondition("engine", 50.0)
	PickupEffects.collect(c, "wrench", Vector2.ZERO)
	assert_eq(c.condition.tires, 45.0, "the wrench fixes the worst system")
	PickupEffects.collect(c, "tankpatch", Vector2.ZERO)
	c.setCondition("tank", 20.0)
	PickupEffects.collect(c, "tankpatch", Vector2.ZERO)
	assert_eq(c.condition.tank, 100.0)
	var engine = c.engine
	PickupEffects.collect(c, "turbo", Vector2.ZERO)
	assert_eq(c.engine, engine + Pickups.DATA.turbo.amount)
	PickupEffects.collect(c, "jerry", Vector2.ZERO)
	assert_true(Pickups.isDiscovered("jerry"), "collected pickups are discovered")

func test_star_fragments_make_stars():
	var c = car()
	var stars = c.star
	for i in 3: PickupEffects.addStarFragment(c)
	assert_eq(c.star, stars + 1)
	assert_eq(c.starFragments, 0)

func test_crush_combo_pays_from_the_third_crush():
	assert_eq(PickupEffects.comboCoins(2), 0)
	assert_eq(PickupEffects.comboCoins(3), 2)
	assert_eq(PickupEffects.comboCoins(6), 3)
	assert_eq(PickupEffects.comboCoins(12), 5)
	assert_eq(PickupEffects.comboCoins(40), 5)

func test_slot_paylines():
	var pays = SlotSymbols.payouts(["nitro", "nitro", "gem"])
	assert_eq(pays.nitro, 2, "a pair pays twice")
	assert_eq(pays.gem, 1)
	assert_eq(SlotSymbols.payouts(["wrench", "wrench", "wrench"]).wrench, 5, "a triple pays five times")
	assert_eq(SlotSymbols.payouts(["blueprint", "blueprint", "blueprint"]).blueprint, 1, "capped by rarity")
	assert_eq(SlotSymbols.payouts([SlotSymbols.STAR, SlotSymbols.STAR, SlotSymbols.STAR])[SlotSymbols.STAR], 3, "the jackpot")
	for i in 100: assert_false(SlotSymbols.pick() in SlotSymbols.NEVER, "no pausing pickup on the reels")

func test_lottery_pays_matching_digits():
	var c = car()
	c.currentGoonsCrushed = 23
	c.coin = 41
	c.lotteryTickets = [[3, 7, 1], [3, 0, 0]]
	var result = PickupEffects.payLottery(c, 57)
	assert_eq(result[0], 500 + 50, "all three, then one")
	assert_eq(c.coin, 41 + 550)
