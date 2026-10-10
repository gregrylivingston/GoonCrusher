extends GameTest

#The unlock system (scripts/global/unlocks.gd, docs/PICKUPS.md "Unlocks"): the nine pickup trees are sound,
#locked pickups never drop or get offered, prices and play conditions open them, and cars cost gems too.
#SaveManager.playerData is swapped for a new save and restored, so nothing is written.

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()
	SaveManager.migrate()
	Unlocks.allOpen = false
	Pickups.resetRun()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false
	Unlocks.allOpen = true
	Pickups.resetRun()

func data() -> PlayerData:
	return SaveManager.playerData

func test_every_kind_has_one_tree_inside_it():
	var roots := {}
	for id in Pickups.DATA:
		var d: Dictionary = Pickups.DATA[id]
		if d.rarity == Pickups.R.SYSTEM:
			assert_false(d.has("parent") || d.has("start"), "%s is always on, outside the trees" % id)
			continue
		if not d.has("parent"):
			roots.get_or_add(d.kind, []).push_back(id)
			continue
		assert_false(d.has("start"), "%s: only a root can start open" % id)
		assert_true(Pickups.DATA.has(d.get("parent", "")), "%s has a real parent" % id)
		assert_eq(Pickups.DATA[d.parent].kind, d.kind, "%s's parent is of its kind" % id)
		var seen := {}
		var at: String = id
		while at != "" && not seen.has(at): #every chain climbs to a root without a loop
			seen[at] = true
			at = Pickups.DATA[at].get("parent", "")
		assert_eq(at, "", "%s climbs to a root" % id)
	for kind in Pickups.K.values(): assert_true(roots.has(kind), "kind %d has a root" % kind)
	assert_eq(roots[Pickups.K.SUPPLY], ["fuel", "health"], "Supplies have two roots, the Fuel Can and the Repair Kit")
	assert_eq(Pickups.DATA.keys().filter(func(id): return Pickups.DATA[id].get("start", false)), ["fuel", "coin", "claw"], "what a new save starts with")
	assert_eq(roots[Pickups.K.LOOT], ["coin"], "Loot starts with the Coin")
	var listed := 0
	for kind in Pickups.KIND_ORDER: listed += Unlocks.treeOrder(kind).size()
	assert_eq(listed, Pickups.DATA.size(), "the tree order lists every pickup once")

func test_every_condition_parses():
	for id in Pickups.DATA:
		for need in Pickups.DATA[id].get("needs", []): assert_true(Unlocks.isValidNeed(need), "%s: %s" % [id, need])

func test_a_new_save_opens_only_the_roots():
	for id in Pickups.DATA:
		var d: Dictionary = Pickups.DATA[id]
		assert_eq(Unlocks.isPickupOpen(id), d.get("start", false) || d.rarity == Pickups.R.SYSTEM, id)
	assert_eq(Unlocks.state("pickup:purse"), Unlocks.S.READY, "the Coin's children can be bought")
	assert_eq(Unlocks.state("pickup:strongbox"), Unlocks.S.HIDDEN, "the Purse's are still ???")
	for id in ["health", "engine", "magnet", "horn", "nitro", "speedtrap", "ffwd"]:
		assert_eq(Unlocks.state("pickup:" + id), Unlocks.S.READY, "%s: a locked root is for sale from the start" % id)
		assert_false(Unlocks.pickupPrice(id).is_empty(), "%s has a price" % id)
	assert_eq(Unlocks.state("pickup:emp"), Unlocks.S.HIDDEN, "what is under a locked root is still ???")
	Unlocks.grant("pickup:horn")
	assert_eq(Unlocks.state("pickup:emp"), Unlocks.S.SHOWN, "a play unlock waits for its condition")

func test_prices_are_spread_out_inside_a_rarity():
	var byRarity := {}
	for id in Pickups.DATA:
		var cost := Unlocks.pickupPrice(id)
		if cost.is_empty() || Pickups.DATA[id].has("price"): continue
		byRarity.get_or_add(Pickups.rarity(id), []).push_back(int(cost.get("coin", 0)) + 100000 * int(cost.get("gem", 0)))
	var commons: Array = byRarity[Pickups.R.COMMON]
	assert_eq(commons.min(), 40, "the cheapest Common is pocket change")
	assert_eq(commons.max(), 2000, "and the dearest about two thousand")
	for r in [Pickups.R.COMMON, Pickups.R.UNCOMMON, Pickups.R.RARE]:
		var seen := {}
		for p in byRarity[r]: seen[p] = true
		assert_eq(seen.size(), byRarity[r].size(), "no two %s pickups cost the same" % Pickups.RARITY_NAMES[r])
	assert_true(byRarity[Pickups.R.UNCOMMON].min() > commons.max() && byRarity[Pickups.R.RARE].min() > byRarity[Pickups.R.UNCOMMON].max(), "a rarer pickup costs more")
	for id in Pickups.DATA: #inside a rarity, deeper in a tree never costs less
		var parent: String = Pickups.DATA[id].get("parent", "")
		if parent == "" || Pickups.DATA[id].has("price") || Pickups.DATA[parent].has("price"): continue
		var mine := Unlocks.pickupPrice(id)
		var above := Unlocks.pickupPrice(parent)
		if mine.is_empty() || above.is_empty() || Pickups.rarity(id) != Pickups.rarity(parent): continue
		assert_true(int(mine.get("coin", 0)) >= int(above.get("coin", 0)), "%s costs at least what %s does" % [id, parent])

func test_locked_pickups_never_drop_or_get_offered():
	for i in 400:
		var id := Pickups.roll(10.0, Root.gameModes.GOONCRUSHER, true, -1, i % 3)
		assert_true(Unlocks.isPickupOpen(id), "a drop: %s" % id)
		id = Pickups.rollAtLeast(Pickups.R.RARE)
		assert_true(Unlocks.isPickupOpen(id), "a supply drop: %s" % id)
		id = Pickups.rollOffer(Pickups.R.UNCOMMON, PickupDeal.NEVER, [])
		assert_true(Unlocks.isPickupOpen(id) && id not in PickupDeal.NEVER, "an offer: %s" % id)
		id = SlotSymbols.pick()
		assert_true(id == SlotSymbols.STAR || Unlocks.isPickupOpen(id), "a reel: %s" % id)
	assert_true(Pickups.openLoadout(Pickups.LOADOUT).is_empty() && Pickups.openLoadout(Pickups.BOOST_LOADOUT).is_empty(), "run setup sells no gadget or boost until one is unlocked")
	Unlocks.grant("pickup:horn")
	Unlocks.grant("pickup:nitro")
	assert_eq(Pickups.openLoadout(Pickups.LOADOUT).keys(), ["horn"], "then only the Air Horn")
	assert_eq(Pickups.openLoadout(Pickups.BOOST_LOADOUT).keys(), ["nitro"], "and Nitro")

func test_fixed_rewards_fall_back_to_an_open_ancestor():
	assert_eq(Pickups.openOr("coinstack"), "coin")
	assert_eq(Pickups.openOr("strongbox"), "coin", "two steps up")
	assert_eq(Pickups.openOr("crate"), "coin", "a tree whose root is still locked falls back to the Coin")
	Unlocks.grant("pickup:engine")
	assert_eq(Pickups.openOr("crate"), "engine")
	assert_eq(Pickups.openOr("engine"), "engine", "an open pickup is itself")
	var ids := WorldSkin.pickupIds()
	assert_eq(ids.purse, "coin", "a chunk's purse is a coin until the Purse is unlocked")
	assert_eq(ids.fuel, "fuel")

func test_buying_spends_the_bank_and_shows_the_children():
	var purse: int = Unlocks.pickupPrice("purse").coin
	data().coin = purse + 100
	assert_true(Unlocks.buy("pickup:purse"))
	assert_eq(data().coin, 100, "a Purse costs its rarity's price")
	assert_true(Unlocks.isPickupOpen("purse"))
	assert_eq(Unlocks.state("pickup:strongbox"), Unlocks.S.READY, "the Strongbox comes into view")
	assert_false(Unlocks.buy("pickup:strongbox"), "100 coins don't cover a Rare")
	assert_eq(data().coin, 100, "a refused buy spends nothing")
	assert_false(Unlocks.buy("pickup:purse"), "an open pickup can't be bought again")
	assert_false(Unlocks.buy("pickup:goldgoon"), "nor a hidden one")
	data().gem = int(Unlocks.pickupPrice("nuke").gem)
	data().meta.unlocks["pickup:airstrike"] = true
	assert_true(Unlocks.buy("pickup:nuke"), "a Legendary costs gems")
	assert_eq(data().gem, 0)

func test_play_conditions_open_on_the_results_ticket():
	for id in ["horn", "engine", "speedtrap"]: Unlocks.grant("pickup:" + id) #the roots above them, bought
	assert_false(Unlocks.isPickupOpen("flare"))
	Unlocks.countRun(false, Root.gameModes.GOONCRUSHER, 1, 0)
	assert_eq(Unlocks.lifetime("nights"), 1)
	var opened := Unlocks.refresh()
	assert_true("flare" in opened && "headlights" in opened, "a night opens the Flare and Headlights: %s" % [opened])
	assert_eq(Unlocks.state("pickup:pocket"), Unlocks.S.READY, "the Flare's child comes into view")
	assert_false("delivery" in opened, "a Delivery needs a won Sprint")
	data().meta.unlocks["pickup:rings"] = true
	Unlocks.countRun(true, Root.gameModes.SPRINT, 0, 0)
	assert_true("delivery" in Unlocks.refresh())
	data().goonsCrushed = {"grunt": 0}
	for id in Goons.DATA:
		if Goons.DATA[id].faction == Goons.faction.SCRAP:
			data().goonsCrushed[String(id)] = 150
			break
	assert_true("emp" in Unlocks.refresh(), "150 Scrap goons open the EMP")
	assert_true(Unlocks.refresh().is_empty(), "a second pass opens nothing new")

func test_unlocks_stay_open():
	data().meta.unlocks["pickup:magnet"] = true
	data().meta.unlocks["pickup:flood"] = true
	assert_true(Unlocks.isPickupOpen("flood"), "opened stays open, whatever its condition says now")

func test_advanced_cars_cost_gems_too():
	var semi = Unlocks.carEntry("semi")
	assert_gt(int(semi.get("gems", 0)), 0, "the Semi costs gems")
	assert_eq(int(Unlocks.carEntry("van").get("gems", 0)), 0, "the Van costs coins only")
	data().coin = 100000
	data().gem = 0
	var semiCost: int = semi.cost
	data().selectedCar = data().cars.find(semi)
	assert_false(SaveManager.unlockCar(), "coins alone don't buy the Semi")
	data().gem = semi.gems
	assert_true(SaveManager.unlockCar())
	assert_eq(semi.cost, 0)
	assert_eq(data().gem, 0)
	assert_eq(data().coin, 100000 - semiCost)

func test_the_demo_caps_pickups_at_uncommon():
	if not Root.IS_DEMO:
		assert_eq(Unlocks.DEMO_MAX_RARITY, Pickups.R.UNCOMMON)
		return
	data().meta.unlocks["pickup:strongbox"] = true
	assert_false(Unlocks.isPickupOpen("strongbox"))

func test_next_unlock_names_something_to_aim_for():
	var next := Unlocks.nextUnlock()
	assert_false(next.is_empty(), "a new save has something next")
	assert_true(Unlocks.state(next.uid) in [Unlocks.S.READY, Unlocks.S.SHOWN])
	data().coin = 1000
	next = Unlocks.nextUnlock()
	assert_true(Unlocks.canAfford(next.uid), "an affordable one comes first: %s" % next.name)

func test_career_tiers_open_pickups_down_each_tree():
	var mid := CareerStart.build("mid")
	for key in mid.meta.unlocks:
		var id: String = str(key).trim_prefix("pickup:")
		assert_true(Pickups.rarity(id) <= Pickups.R.UNCOMMON, "mid opens up to Uncommon: %s" % id)
		var parent: String = Pickups.DATA[id].get("parent", "")
		assert_true(parent == "" || Pickups.DATA[parent].get("start", false) || mid.meta.unlocks.has("pickup:" + parent), "%s's parent is open" % id)
	assert_true(CareerStart.build("fresh").meta.unlocks.is_empty(), "a fresh save has only the roots")
	assert_eq(CareerStart.pickupsOpen(CareerStart.build("maxed")), Pickups.DATA.size(), "maxed has everything")

func test_the_pickups_screen_draws_each_kind_as_a_tree_on_its_tab():
	var page = add_child_autofree(PickupShop.new())
	assert_eq(page.tabButtons.size(), PickupShop.TABS.size())
	assert_eq(page.tabNames()[0], "LOOT", "Loot comes first")
	var kinds := []
	for t in PickupShop.TABS: kinds.append_array(t.kinds)
	kinds.sort()
	var every: Array = Pickups.KIND_ORDER.duplicate()
	every.sort()
	assert_eq(kinds, every, "every kind is on exactly one tab")
	assert_eq(PickupShop.tabOf("pickup:hop"), PickupShop.tabOf("pickup:horn"), "boosts share the gadgets' tab")
	assert_eq(PickupShop.tabOf("pickup:ffwd"), PickupShop.tabOf("pickup:magnet"), "mode specials share the power-ups' tab")
	for g in CrushPrizes.GAMES: assert_eq(PickupShop.tabOf(CrushPrizes.uid(g.id)), PickupShop.tabOf("pickup:claw"), "%s is on the Casino tab" % g.id)
	var at := {}
	for i in PickupShop.tabCount():
		page.setTab(i)
		assert_eq(page.tiles.size(), PickupShop.tabUids(i).size(), "%s: one tile per unlock" % page.tabNames()[i])
		for b in page.tiles:
			at[b.get_meta("key")] = b.get_global_rect()
			b.focus_entered.emit()
			assert_true(page.detail.get_child_count() > 0, "a card for %s" % b.get_meta("key"))
	assert_eq(at.size(), Pickups.DATA.size(), "one tile per pickup over the tabs")
	for id in Pickups.DATA:
		for above in Unlocks.prerequisites(id): assert_gt(at[id].position.y, at[above].position.y, "%s sits below %s" % [id, above])
	for i in PickupShop.tabCount(): #no two tiles on a tab overlap
		var keys: Array = PickupShop.tabUids(i).map(PickupShop.keyOf)
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				assert_false(at[keys[a]].intersects(at[keys[b]]), "%s and %s overlap" % [keys[a], keys[b]])

func test_the_pickups_screen_opens_where_there_is_something_to_buy():
	data().coin = 0
	data().gem = 0
	var broke = add_child_autofree(PickupShop.new())
	assert_true(PickupShop.tabUids(broke.tab).any(PickupShop.isReady), "with an empty bank, the first tab with something to work toward")
	assert_eq(broke.badges.filter(func(b): return b.count > 0).size(), 0, "and no tab wears a badge")
	data().coin = int(Unlocks.pickupPrice("purse").coin)
	var page = add_child_autofree(PickupShop.new())
	var buyable: Array = PickupShop.tabUids(page.tab).filter(PickupShop.isBuyable)
	assert_false(buyable.is_empty(), "the screen opens on a tab the bank can buy from")
	assert_eq(str(page.firstFocus().get_meta("key")), PickupShop.keyOf(buyable[0]), "on a tile it can buy")
	assert_eq(page.badges[page.tab].count, buyable.size(), "and the tab's badge counts them")
	var total := 0
	for b in page.badges: total += b.count
	assert_eq(total, Unlocks.buyableCount(), "the tabs' badges add up to the launch bar's")

func test_the_pickups_screen_buys_pickups_and_the_bench_buys_upgrades():
	var purse: int = Unlocks.pickupPrice("purse").coin
	data().coin = purse + 1000
	var page = add_child_autofree(PickupShop.new())
	assert_false(Goonopedia.TAB_NAMES.has("CARS") || Goonopedia.TAB_NAMES.has("PICKUPS"), "cars live in the garage and pickups on their own screen, not in the Goonopedia")
	page.setTab(PickupShop.tabOf("pickup:purse"))
	page.buyPickup("purse")
	assert_true(Unlocks.isPickupOpen("purse"), "a pickup bought on its tile")
	assert_eq(data().coin, 1000)
	assert_eq(page.tab, PickupShop.tabOf("pickup:purse"), "buying stays on the tab")
	var bench: DriverBench = add_child_autofree(DriverBench.new())
	var sedan := data().cars.find(Unlocks.carEntry("sedan"))
	bench.setup(sedan, load("res://scene/car/sedan/sedan_info.tres"), [])
	assert_true(bench.upgradeButton(Root.upgrade.ENGINE) != null, "an owned car's bench has a buy button per stat")
	var level := int(data().cars[sedan].upgrades.get(Root.upgrade.ENGINE, 0))
	var before: int = data().coin
	var cost := SaveManager.upgradePrice(level, "sedan")
	bench.upgradeButton(Root.upgrade.ENGINE).pressed.emit()
	assert_eq(int(data().cars[sedan].upgrades.get(Root.upgrade.ENGINE, 0)), level + 1, "an upgrade bought on the bench")
	assert_eq(data().coin, before - cost, "at the garage's price")
	assert_eq(bench.rowFor(Root.upgrade.ENGINE).level.text, "%d / %d" % [level + 1, SaveManager.MAX_UPGRADE_LEVEL], "the row shows it")
	var locked := data().cars.find(Unlocks.carEntry("ambulance"))
	bench.setup(locked, load("res://scene/car/ambulance/ambulance_info.tres"), [])
	assert_eq(bench.title.text, "STATS", "a locked car's sheet is read only")
	assert_true(bench.upgradeButton(Root.upgrade.ENGINE) == null, "with no buy buttons")
	bench.buyUpgrade(Root.upgrade.ENGINE)
	assert_eq(int(data().cars[locked].upgrades.get(Root.upgrade.ENGINE, 0)), 0, "a locked car can't be upgraded")

func test_the_dock_badges_count_what_the_bank_can_buy():
	var sedan := data().cars.find(Unlocks.carEntry("sedan"))
	data().cars[sedan].upgrades = {}
	data().coin = 0
	data().gem = 0
	assert_eq(DriverCard.affordableUpgrades(sedan), 0, "nothing with an empty bank")
	assert_eq(Unlocks.buyableCount(), 0)
	data().coin = SaveManager.upgradePrice(0, "sedan")
	assert_eq(DriverCard.affordableUpgrades(sedan), DriverCard.STATS.size(), "each stat counts on its own")
	data().cars[sedan].upgrades[Root.upgrade.ENGINE] = SaveManager.MAX_UPGRADE_LEVEL
	assert_eq(DriverCard.affordableUpgrades(sedan), DriverCard.STATS.size() - 1, "a maxed stat doesn't count")
	data().coin = 10000000
	data().gem = 1000
	var ready := 0
	for id in Pickups.DATA:
		if Unlocks.state("pickup:" + str(id)) == Unlocks.S.READY && not Unlocks.pickupPrice(str(id)).is_empty(): ready += 1
	assert_gt(ready, 0, "a new save has something ready to unlock")
	assert_eq(Unlocks.buyableCount(), ready, "every ready pickup and prize game a full bank covers")

func test_the_demo_can_unlock_the_casino_trees_first_tier():
	for id in ["scratch", "mystery", "shuffle"]: assert_true(Unlocks.inDemo(id), "%s: straight under the Claw Crane" % id)
	for id in ["press", "double", "lottery", "deal", "slotmachine", "pusher"]: assert_false(Unlocks.inDemo(id), "%s: the full game" % id)
	assert_true(Unlocks.inDemo("purse") && not Unlocks.inDemo("strongbox"), "elsewhere the demo stops at Uncommon")
	assert_false(Pickups.DATA.slotmachine.get("start", false) || Unlocks.pickupPrice("slotmachine").is_empty(), "the Slot Machine is bought, not given")

func test_the_toolbox_needs_all_four_system_parts():
	data().coin = 1000000
	assert_eq(Pickups.displayName("tire"), "Spare Tire")
	var parts := ["tire", "bulb", "sparkplug", "tierod"]
	assert_eq(Unlocks.prerequisites("toolbox"), parts)
	assert_eq(Unlocks.state("pickup:toolbox"), Unlocks.S.HIDDEN, "hidden until the Wrench and a part are open")
	Unlocks.grant("pickup:wrench")
	for i in parts.size():
		assert_false(Unlocks.buy("pickup:toolbox"), "not for sale with %d of 4 parts" % i)
		assert_true(Unlocks.buy("pickup:" + parts[i]))
	assert_eq(Unlocks.state("pickup:toolbox"), Unlocks.S.READY, "for sale once all four are open")
	assert_true(Unlocks.buy("pickup:toolbox"))
	for p in parts: data().meta.unlocks.erase("pickup:" + p)
	data().meta.unlocks.erase("pickup:toolbox")
	data().meta.unlocks.erase("pickup:wrench")

func test_a_casino_unlock_opens_the_drop_and_the_gift_box_game():
	data().coin = 100000
	var page = add_child_autofree(PickupShop.new())
	page.setTab(PickupShop.tabOf("pickup:claw"))
	assert_true(Unlocks.isPickupOpen("claw") && CrushPrizes.isOpen("claw"), "the Claw Crane, the tree's root, starts open")
	assert_eq(Unlocks.state("pickup:slotmachine"), Unlocks.S.HIDDEN, "the Slot Machine is at the far end")
	assert_eq(Unlocks.state("pickup:press"), Unlocks.S.HIDDEN, "the Goon Press waits for the Hubcap Shuffle")
	page.buyPickup("press")
	assert_false(CrushPrizes.isOpen("press"), "a hidden game can't be bought")
	page.buyPickup("shuffle")
	assert_true(CrushPrizes.isOpen("shuffle"), "one purchase puts the game in the boxes")
	assert_eq(data().coin, 100000 - int(Pickups.DATA.shuffle.price.coin), "at its price")
	assert_eq(Unlocks.state("pickup:press"), Unlocks.S.READY, "and the next one is for sale")
	assert_eq(Pickups.candidates(Pickups.R.RARE, 0, false).get("shuffle", 0.0), 0.0, "a box-only game never drops")
	page.buyPickup("scratch")
	assert_true(CrushPrizes.isOpen("scratch") && Pickups.candidates(Pickups.R.RARE, 0, false).has("scratch"), "the Scratch Card: the drop and the box game in one")
	for id in Unlocks.treeOrder(Pickups.K.CASINO): #least valuable first: nothing costs less than what it follows
		var parent: String = Pickups.DATA[id].get("parent", "")
		if parent == "" || Pickups.DATA[parent].get("start", false): continue
		assert_true(int(Unlocks.pickupPrice(id).get("coin", 0)) >= int(Unlocks.pickupPrice(parent).get("coin", 0)), "%s costs at least what %s does" % [id, parent])
	assert_eq(Pickups.rarity("claw"), Pickups.R.RARE, "the weakest prize game is a Rare drop")
