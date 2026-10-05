extends GameTest

#Every paid upgrade must do what its label says (GAMEPLAY_SUGGESTIONS T0-8). Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func test_more_oil_always_burns_less_fuel():
	var last := INF
	for oil in range(0, 1001):
		var burn = OverheadCarBody2D.fuelBurn(1.0, oil)
		assert_true(is_finite(burn), "burn is finite at oil %d" % oil)
		assert_gt(burn, 0.0, "full throttle always burns some fuel at oil %d" % oil)
		if burn >= last: fail("burn must drop as oil rises: oil %d burns %s, oil %d burned %s" % [oil, burn, oil - 1, last])
		last = burn
	assert_almost_eq(OverheadCarBody2D.fuelBurn(1.0, 0), OverheadCarBody2D.FUEL_BURN_BASE, 0.00001, "oil 0 burns the base rate")
	assert_almost_eq(OverheadCarBody2D.fuelBurn(1.0, 50), OverheadCarBody2D.FUEL_BURN_BASE / 2.0, 0.00001, "oil 50 halves the burn")
	assert_eq(OverheadCarBody2D.fuelBurn(0.0, 10), 0.0, "no throttle burns nothing")
	assert_eq(OverheadCarBody2D.fuelBurn(-1.0, 10), OverheadCarBody2D.fuelBurn(1.0, 10), "reverse burns like forward")
	assert_almost_eq(OverheadCarBody2D.fuelBurn(1.0, -40), OverheadCarBody2D.FUEL_BURN_BASE, 0.00001, "negative oil can't divide by zero")

func test_luck_raises_high_value_prizes_without_touching_the_table():
	var table = {Root.upgrade.COIN: 100, Root.upgrade.PURSE: 4, Root.upgrade.GEM: 4, Root.upgrade.SLOTMACHINE: 1, Root.upgrade.FUEL: 20}
	var copy = table.duplicate()
	var lucky = Root.luckAdjustedWeights(table, 50)
	assert_eq(table, copy, "the goon's table is not changed")
	assert_eq(lucky[Root.upgrade.COIN], 100, "coins keep their weight")
	assert_eq(lucky[Root.upgrade.FUEL], 20, "other drops keep their weight")
	assert_almost_eq(lucky[Root.upgrade.PURSE], 4 + 0.3 * 50, 0.0001)
	assert_almost_eq(lucky[Root.upgrade.GEM], 4 + 0.1 * 50, 0.0001)
	assert_almost_eq(lucky[Root.upgrade.SLOTMACHINE], 1 + 0.02 * 50, 0.0001)
	var luckier = Root.luckAdjustedWeights(table, 100)
	assert_gt(luckier[Root.upgrade.PURSE], lucky[Root.upgrade.PURSE], "more luck, more purses")
	assert_gt(luckier[Root.upgrade.GEM], lucky[Root.upgrade.GEM], "more luck, more gems")
	assert_false(Root.luckAdjustedWeights({Root.upgrade.COIN: 100}, 50).has(Root.upgrade.PURSE), "prizes a goon doesn't drop are not added")

func test_weighted_pick_covers_each_range_once():
	var table = {Root.upgrade.COIN: 2.0, Root.upgrade.PURSE: 1.0, Root.upgrade.GEM: 1.0}
	assert_eq(Root.pickWeighted(table, 0.0), Root.upgrade.COIN)
	assert_eq(Root.pickWeighted(table, 1.99), Root.upgrade.COIN)
	assert_eq(Root.pickWeighted(table, 2.0), Root.upgrade.PURSE)
	assert_eq(Root.pickWeighted(table, 3.99), Root.upgrade.GEM)
	assert_null(Root.pickWeighted({}, 0.0), "an empty table picks nothing")

func test_getPowerupFromWeights_leaves_the_walker_table_alone():
	var table = {Root.upgrade.COIN: 100, Root.upgrade.PURSE: 4}
	var copy = table.duplicate()
	for i in 20:
		var drop = Root.getPowerupFromWeights(table)
		assert_true(drop is Powerup)
		drop.free()
	assert_eq(table, copy)

func test_traction_adds_grip_within_bounds():
	var stock = OverheadCarBody2D.gripFor(0.1, 0, OverheadCarBody2D.GRIP_FAST_MAX)
	assert_almost_eq(stock, 0.1, 0.0001)
	assert_gt(OverheadCarBody2D.gripFor(0.1, 25, OverheadCarBody2D.GRIP_FAST_MAX), stock, "traction adds grip")
	assert_eq(OverheadCarBody2D.gripFor(0.1, 1000, OverheadCarBody2D.GRIP_FAST_MAX), OverheadCarBody2D.GRIP_FAST_MAX)
	assert_eq(OverheadCarBody2D.gripFor(0.7, 1000, OverheadCarBody2D.GRIP_SLOW_MAX), OverheadCarBody2D.GRIP_SLOW_MAX)
	assert_eq(OverheadCarBody2D.gripFor(0.0, -100, OverheadCarBody2D.GRIP_FAST_MAX), OverheadCarBody2D.GRIP_MIN)

func test_powerups_stop_at_the_stat_cap():
	var cap = OverheadCarBody2D.STAT_CAP
	assert_eq(OverheadCarBody2D.addCapped(10, 1.0), 11)
	assert_eq(OverheadCarBody2D.addCapped(cap - 1, 1.0), cap)
	assert_eq(OverheadCarBody2D.addCapped(cap, 1.0), cap, "no powerup past the cap")
	assert_eq(OverheadCarBody2D.addCapped(cap + 30, 1.0), cap + 30, "an old save above the cap is not lowered")

func test_upgrades_stop_at_the_max_level():
	var data = PlayerData.new()
	data.coin = 1000000000
	var upgrades = data.cars[data.selectedCar].upgrades
	upgrades[Root.upgrade.ENGINE] = SaveManager.MAX_UPGRADE_LEVEL
	upgrades[Root.upgrade.OIL] = SaveManager.MAX_UPGRADE_LEVEL + 7 #bought before the cap existed
	SaveManager.playerData = data
	assert_true(SaveManager.isUpgradeMaxed(Root.upgrade.ENGINE))
	assert_false(SaveManager.requestStatUpgrade(Root.upgrade.ENGINE), "a maxed stat can't be bought")
	assert_false(SaveManager.requestStatUpgrade(Root.upgrade.OIL), "nor one above the max")
	assert_eq(data.coin, 1000000000, "a refused upgrade costs nothing")
	assert_eq(SaveManager.getUpgradeLevel(Root.upgrade.ENGINE), SaveManager.MAX_UPGRADE_LEVEL)
	assert_eq(SaveManager.getUpgradeLevel(Root.upgrade.OIL), SaveManager.MAX_UPGRADE_LEVEL + 7, "levels above the cap are kept")
	assert_false(SaveManager.isUpgradeMaxed(Root.upgrade.ARMOR), "an unbought stat is not maxed")
	assert_false(SaveManager.dirty, "nothing was saved")

#fixing luck put COIN back into the walker's table; its weight must not crowd out fuel and health
func test_walker_drops_still_favour_fuel_and_health():
	var walker = Walker.new()
	var weights = Root.luckAdjustedWeights(walker.powerupDropDict, 1)
	walker.free()
	var total := 0.0
	for weight in weights.values(): total += weight
	assert_gt(weights[Root.upgrade.FUEL] / total, 0.15, "fuel stays a common drop")
	assert_gt(weights[Root.upgrade.HEALTH] / total, 0.08, "health stays a common drop")
	assert_gt(0.40, weights[Root.upgrade.COIN] / total, "coins don't dominate")
