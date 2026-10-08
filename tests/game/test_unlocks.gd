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
		if d.get("start", false):
			roots.get_or_add(d.kind, []).push_back(id)
			assert_false(d.has("parent"), "root %s has no parent" % id)
			continue
		assert_true(Pickups.DATA.has(d.get("parent", "")), "%s has a real parent" % id)
		assert_eq(Pickups.DATA[d.parent].kind, d.kind, "%s's parent is of its kind" % id)
		var seen := {}
		var at: String = id
		while at != "" && not seen.has(at): #every chain climbs to a root without a loop
			seen[at] = true
			at = Pickups.DATA[at].get("parent", "")
		assert_eq(at, "", "%s climbs to a root" % id)
	for kind in Pickups.K.values(): assert_true(roots.has(kind), "kind %d has a root" % kind)
	assert_eq(roots[Pickups.K.SUPPLY].size(), 2, "Supplies start with the Fuel Can and the Repair Kit")
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
	assert_eq(Unlocks.state("pickup:emp"), Unlocks.S.SHOWN, "a play unlock waits for its condition")

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
	assert_eq(Pickups.openLoadout(Pickups.LOADOUT).keys(), ["horn"], "run setup sells only the Air Horn")
	assert_eq(Pickups.openLoadout(Pickups.BOOST_LOADOUT).keys(), ["nitro"], "and Nitro")

func test_fixed_rewards_fall_back_to_an_open_ancestor():
	assert_eq(Pickups.openOr("coinstack"), "coin")
	assert_eq(Pickups.openOr("strongbox"), "coin", "two steps up")
	assert_eq(Pickups.openOr("crate"), "engine")
	assert_eq(Pickups.openOr("nitro"), "nitro", "an open pickup is itself")
	var ids := WorldSkin.pickupIds()
	assert_eq(ids.purse, "coin", "a chunk's purse is a coin until the Purse is unlocked")
	assert_eq(ids.fuel, "fuel")

func test_buying_spends_the_bank_and_shows_the_children():
	data().coin = 1000
	assert_true(Unlocks.buy("pickup:purse"))
	assert_eq(data().coin, 100, "a Purse is 900 coins")
	assert_true(Unlocks.isPickupOpen("purse"))
	assert_eq(Unlocks.state("pickup:strongbox"), Unlocks.S.READY, "the Strongbox comes into view")
	assert_false(Unlocks.buy("pickup:strongbox"), "100 coins don't cover a Rare")
	assert_eq(data().coin, 100, "a refused buy spends nothing")
	assert_false(Unlocks.buy("pickup:purse"), "an open pickup can't be bought again")
	assert_false(Unlocks.buy("pickup:goldgoon"), "nor a hidden one")
	data().gem = 12
	data().meta.unlocks["pickup:airstrike"] = true
	assert_true(Unlocks.buy("pickup:nuke"), "a Legendary costs gems")
	assert_eq(data().gem, 0)

func test_play_conditions_open_on_the_results_ticket():
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
	data().selectedCar = data().cars.find(semi)
	assert_false(SaveManager.unlockCar(), "coins alone don't buy the Semi")
	data().gem = semi.gems
	assert_true(SaveManager.unlockCar())
	assert_eq(semi.cost, 0)
	assert_eq(data().gem, 0)
	assert_eq(data().coin, 100000 - 5000)

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
	data().coin = 300
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
