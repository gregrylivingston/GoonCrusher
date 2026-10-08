extends GameTest

#Career playtests (docs/AI_DRIVER.md, "Career playtests"): the start tiers (CareerStart) and the personas'
#decisions (Personas). Pure: builds PlayerData in memory, never starts a run or touches the save.

const G := Root.gameModes
const U := Root.upgrade

func rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r

func run(level: int, mode: int, won: bool, payout := 100, car := "sedan", seconds := 120.0) -> Dictionary:
	return {"session": 1, "car": car, "level_index": level, "mode_id": mode, "won": won, "payout": payout, "level_time": seconds}

func test_fresh_is_a_new_save():
	var data := CareerStart.build("fresh")
	var defaults := PlayerData.new()
	assert_eq(data.coin, 0)
	assert_eq(data.gem, 0)
	assert_eq(data.cars.filter(func(c): return c.cost == 0).size(), 1, "only the sedan is owned")
	assert_eq(data.levels.filter(func(l): return l.unlocked).size(), 1, "only the first level is open")
	for i in data.levels.size():
		for mode in data.levels[i].gamemodeBeat: assert_false(data.levels[i].gamemodeBeat[mode], "nothing beaten")
	assert_eq(data.cars.size(), defaults.cars.size())

func test_every_tier_is_reachable_by_play():
	for tier in CareerStart.TIERS:
		var data := CareerStart.build(tier)
		assert_true(data != null, tier)
		for i in data.levels.size():
			var level: Dictionary = data.levels[i]
			for mode in level.gamemodeBeat:
				if not level.gamemodeBeat[mode]: continue
				assert_true(level.unlocked, "%s: a level with a beaten mode is open" % tier)
				if i + 1 < data.levels.size() && Root.opensNextLevel(level): assert_true(data.levels[i + 1].unlocked, "%s: level %d's beaten modes opened the next" % [tier, i])
				#the chain: Sprint needs Countdown, and so on, so every beaten mode was playable when it was beaten
				var without := level.duplicate(true)
				without.gamemodeBeat[mode] = false
				assert_true(Root.isModeUnlocked(without, mode), "%s: %s on level %d was unlocked before it was beaten" % [tier, Root.gameModeDescription[mode].name, i])
		for car in data.cars:
			if car.cost > 0: assert_true(car.upgrades.is_empty(), "%s: a locked car has no upgrades" % tier)
			for stat in car.upgrades: assert_true(car.upgrades[stat] <= SaveManager.MAX_UPGRADE_LEVEL, "%s: upgrades within the cap" % tier)
		assert_eq(data.cars[data.selectedCar].cost, 0, "%s: drives a car it owns" % tier)

func test_tiers_grow():
	var last := -1
	for tier in ["fresh", "early", "mid", "late", "maxed"]:
		var p := CareerStart.progress(CareerStart.build(tier))
		var score: int = p.modes_beaten * 1000 + p.cars_owned * 100 + p.upgrades
		assert_true(score > last, "%s is further on than the tier before" % tier)
		last = score
	var maxed := CareerStart.progress(CareerStart.build("maxed"))
	assert_eq(maxed.modes_beaten, maxed.modes_total, "maxed beats everything")
	assert_eq(maxed.cars_owned, maxed.cars_total)
	assert_eq(maxed.upgrades, maxed.upgrades_total)

func test_overrides_and_unknown_tiers():
	var data := CareerStart.build("fresh", {"coins": 5000, "gems": 3, "cars": 3, "upgrades": 2})
	assert_eq(data.coin, 5000)
	assert_eq(data.gem, 3)
	assert_eq(data.cars.filter(func(c): return c.cost == 0).size(), 3, "the three cheapest cars")
	assert_null(CareerStart.build("nope"))

func test_rookie_follows_the_path():
	var rookie := Personas.get_def("rookie")
	var data := CareerStart.build("fresh")
	var next := Personas.chooseRun(rookie, data, [], rng())
	assert_eq(next.mode, G.GOONCRUSHER, "a new player starts with Countdown")
	assert_eq(next.level, 0, "on the only open level")
	data.levels[next.level].gamemodeBeat[G.GOONCRUSHER] = true
	assert_eq(Personas.chooseRun(rookie, data, [], rng()).mode, G.SPRINT, "then the mode it opened")

func test_a_losing_streak_sends_the_rookie_back_to_farm():
	var rookie := Personas.get_def("rookie")
	var data := CareerStart.build("early") #two levels open, so there is somewhere to go back to
	var furthest := 1
	var history := []
	for i in rookie.retreat: history.push_back(run(furthest, G.GOONCRUSHER, false))
	var next := Personas.chooseRun(rookie, data, history, rng())
	assert_true(next.level < furthest || next.mode != G.GOONCRUSHER, "it stops banging its head on the same run")

func test_every_chosen_run_is_playable():
	for id in Personas.DATA:
		for tier in CareerStart.TIERS:
			var data := CareerStart.build(tier)
			var choice := Personas.chooseRun(Personas.get_def(id), data, [], rng())
			assert_true(Root.isModePlayable(data.levels[choice.level], choice.mode), "%s at %s picks a run the menu can start" % [id, tier])

func test_explorer_covers_the_least_played():
	var explorer := Personas.get_def("explorer")
	var data := CareerStart.build("early")
	var history := [run(0, G.GOONCRUSHER, true), run(0, G.SPRINT, true), run(1, G.GOONCRUSHER, false)]
	var next := Personas.chooseRun(explorer, data, history, rng())
	assert_eq(Personas.coverage(history, next, "sedan"), 0, "an unplayed level and mode")

func test_shopping_spends_only_what_is_in_the_bank():
	for id in Personas.DATA:
		var persona := Personas.get_def(id)
		var data := CareerStart.build("fresh", {"coins": 3000})
		for i in 200:
			var want := Personas.nextPurchase(persona, data, [], rng())
			if want.is_empty(): break
			if want.has("unlock"):
				assert_true(data.coin >= data.cars[want.unlock].cost, "%s can afford the car" % id)
				data.coin -= data.cars[want.unlock].cost
				data.cars[want.unlock].cost = 0
			else:
				assert_eq(data.cars[want.car].cost, 0, "%s upgrades a car it owns" % id)
				var level := int(data.cars[want.car].upgrades.get(want.upgrade, 0))
				assert_true(level < SaveManager.MAX_UPGRADE_LEVEL, "%s stays under the cap" % id)
				var cost := SaveManager.upgradePrice(level, str(data.cars[want.car].name))
				assert_true(cost <= data.coin, "%s can afford the upgrade" % id)
				data.coin -= cost
				data.cars[want.car].upgrades[want.upgrade] = level + 1
		assert_true(data.coin >= 0, "%s never goes negative" % id)

func test_upgrade_cost_matches_the_garage():
	var data := CareerStart.build("fresh")
	var keep := SaveManager.playerData
	SaveManager.playerData = data
	for car in [0, data.cars.size() - 1]: #the sedan and the priciest car (UPGRADE_COST_SCALE)
		data.selectedCar = car
		for level in [0, 1, 5, 19]:
			data.cars[car].upgrades[U.ENGINE] = level
			assert_eq(SaveManager.upgradePrice(level, str(data.cars[car].name)), SaveManager.requestStatCost(U.ENGINE), "%s level %d" % [data.cars[car].name, level])
	assert_gt(SaveManager.upgradePrice(5, "ambulance"), SaveManager.upgradePrice(5, "sedan"), "advanced cars' upgrades cost more")
	SaveManager.playerData = keep

func test_grinder_saves_for_a_car_within_reach():
	var grinder := Personas.get_def("grinder")
	var data := CareerStart.build("fresh", {"coins": 800})
	var history := [run(0, G.GOONCRUSHER, true, 400), run(0, G.GOONCRUSHER, true, 400)]
	assert_true(Personas.nextPurchase(grinder, data, history, rng()).is_empty(), "the van (1000) is one run away: save")
	data.coin = 1000
	assert_true(Personas.nextPurchase(grinder, data, history, rng()).has("unlock"), "and buy it once affordable")

func test_in_run_choices_are_valid():
	for id in Personas.DATA:
		var persona := Personas.get_def(id)
		var cards := ["jerry", "wrench", "fuel"]
		var pick := Personas.dealPick(persona, cards, rng())
		assert_true(pick >= 0 && pick < cards.size(), "%s picks a card" % id)
		var bet := Personas.slotBet(persona, 1000, rng())
		assert_true(bet >= 0 && bet < SlotSymbols.BETS.size(), "%s bets a real level" % id)
		var prizes := [{"id": "fuel", "pos": Vector2(100, 300)}, {"id": "jerry", "pos": Vector2(400, 300)}]
		var target := Personas.clawTarget(persona, prizes, 320.0, rng())
		assert_true(target >= 0 && target < prizes.size(), "%s aims at a prize" % id)
		var buys := Personas.pitBuys(persona, ["jerry", "", "fuel"], [60, 0, 30], 70)
		for i in buys: assert_true(i != 1, "%s doesn't buy a sold slot" % id)
		assert_false(Personas.slotReroll(persona, 0, {}, rng()), "%s can't reroll without gems" % id)
		var gadget := Personas.chooseLoadout(persona, 0, rng())
		assert_eq(gadget, "", "%s buys no gadget without gems" % id)
		assert_eq(Personas.chooseBoost(persona, 0, rng()), "", "%s buys no boost without gems" % id)
		for gems in [1, 3, 9, 99]:
			var g := Personas.chooseLoadout(persona, gems, rng())
			if g != "": assert_true(Pickups.LOADOUT[g] <= gems, "%s's gadget is affordable" % id)
			var b := Personas.chooseBoost(persona, gems, rng())
			if b != "": assert_true(Pickups.BOOST_LOADOUT[b] <= gems, "%s's boost is affordable" % id)
	assert_eq(Personas.get_def("rookie").profile, "rookie")
	for id in Personas.DATA: assert_true(AIProfiles.PROFILES.has(Personas.get_def(id).profile), "%s drives a real profile" % id)

func test_rookie_profile_is_imperfect_and_the_rest_unchanged():
	var rookie := AIProfiles.resolve("rookie")
	assert_true(rookie.reactionTicks > 0 && rookie.planSlop > 0.0, "the rookie reacts late and misjudges")
	for name in AIProfiles.PROFILES:
		if name == "rookie": continue
		var p := AIProfiles.resolve(name)
		assert_eq(p.reactionTicks, 0, "%s reacts at once" % name)
		assert_eq(p.planSlop, 0.0, "%s plans without noise" % name)
