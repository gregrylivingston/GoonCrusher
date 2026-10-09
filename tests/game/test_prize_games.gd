extends GameTest

#The prize games on the PickupMenu frame (docs/PICKUPS.md, "Prize games"): no game pays another, the winnings
#board says what each prize did, and each game's rules (claw grip, slot pay line, wheel power, the Deal's
#deck, the Vault's dial).

var wasAllOpen := false

func before_each() -> void:
	wasAllOpen = Unlocks.allOpen
	Unlocks.allOpen = true

func after_each() -> void:
	Unlocks.allOpen = wasAllOpen

func test_no_game_pays_another():
	for id in Pickups.DATA:
		if Pickups.DATA[id].kind == Pickups.K.CASINO: assert_true(id in Pickups.NOT_IN_GAMES, "%s is a game, so no game pays it" % id)
	for i in 200:
		assert_false(Pickups.rollOffer(Pickups.R.UNCOMMON, Pickups.NOT_IN_GAMES, []) in Pickups.NOT_IN_GAMES, "an offer is never a game")
		assert_false(SlotSymbols.pick() in Pickups.NOT_IN_GAMES, "a reel is never a game")
	assert_eq(PickupDeal.NEVER, Pickups.NOT_IN_GAMES)
	assert_eq(SlotSymbols.NEVER, Pickups.NOT_IN_GAMES)

func gadget(rarity: int) -> String:
	for id in Pickups.DATA:
		if Pickups.DATA[id].kind == Pickups.K.GADGET && Pickups.rarity(id) == rarity: return id
	return ""

func test_the_board_says_what_a_prize_did():
	var common := gadget(Pickups.R.UNCOMMON)
	var legendary := gadget(Pickups.R.LEGENDARY)
	assert_true(common != "" && legendary != "", "there are gadgets to test with")
	var car := {"heldItem": "", "moveItem": ""}
	assert_true(PickupMenu.outcome(car, common).begins_with("Ready"), "an empty slot holds it")
	car.heldItem = legendary
	assert_true(PickupMenu.outcome(car, common).begins_with("Sold"), "a rarer gadget held: it is sold, and the board says so")
	car.heldItem = common
	assert_true(PickupMenu.outcome(car, common).begins_with("+"), "the same gadget adds charges")
	assert_true(PickupMenu.outcome(car, legendary).contains("replaces"), "a rarer one replaces it")
	assert_true(PickupMenu.outcome(car, "jerry") != "", "a supply says what it does")

func test_claw_grip():
	var r: float = ClawCrane.RADIUS[Pickups.R.COMMON]
	assert_gt(ClawCrane.gripFor(0.0, r, 0, 0), ClawCrane.gripFor(15.0, r, 0, 0), "centred grips harder")
	assert_gt(ClawCrane.gripFor(15.0, r, 0, 3), ClawCrane.gripFor(15.0, r, 0, 0), "a better box grips harder")
	#a typical trip: about a second up and a second over to the chute, with a little swing
	var trip := 2.2
	for rarity in [Pickups.R.COMMON, Pickups.R.LEGENDARY]:
		var held: float = ClawCrane.gripFor(0.0, ClawCrane.RADIUS[rarity], 0, 0) - ClawCrane.GRIP_DRAIN * ClawCrane.WEIGHT[rarity] * trip
		assert_gt(held, ClawCrane.LET_GO, "a centred grab holds a %s prize all the way" % Pickups.RARITY_NAMES[rarity])
	var sloppy: float = ClawCrane.gripFor(ClawCrane.RADIUS[Pickups.R.LEGENDARY], ClawCrane.RADIUS[Pickups.R.LEGENDARY], 0, 0) - ClawCrane.GRIP_DRAIN * ClawCrane.WEIGHT[Pickups.R.LEGENDARY] * trip
	assert_true(sloppy < ClawCrane.LET_GO, "an edge grab on a heavy prize slips")

func test_slot_pays_what_the_line_shows():
	var machine := SlotMachine.new()
	machine.strips = [[], [], []]
	for r in 3:
		for i in SlotMachine.STRIP: machine.strips[r].push_back("coin" if i % 2 == 0 else "gem")
	machine.target = [4, 6, 7]
	assert_eq(machine.line(), ["coin", "coin", "gem"], "a stopped reel's line symbol is its target's")
	machine.target = [-1, -1, -1]
	machine.pos = [3.6, 0.2, 9.4]
	assert_eq(machine.line(), ["coin", "coin", "gem"], "a spinning reel shows the nearest symbol")
	for node in [machine.root, machine.card, machine.body, machine.stage, machine.info, machine.board]: node.free()
	machine.free()

func test_wheel_power():
	assert_eq(PrizeWheelMenu.powerAt(0.0), 0.0)
	assert_almost_eq(PrizeWheelMenu.powerAt(PrizeWheelMenu.SWEEP), 1.0, 0.001, "full after one sweep")
	assert_almost_eq(PrizeWheelMenu.powerAt(PrizeWheelMenu.SWEEP * 2.0), 0.0, 0.001, "and empty again")

func test_deal_counts_what_beats_your_card():
	var common := gadget(Pickups.R.UNCOMMON)
	var legendary := gadget(Pickups.R.LEGENDARY)
	assert_eq(PickupDeal.beats(common, [legendary, common, legendary]), 2)
	assert_eq(PickupDeal.beats(legendary, [legendary, common]), 0)

func test_vault_dial():
	assert_eq(PrizeVault.gap(1, 39), 2, "the dial wraps")
	assert_eq(PrizeVault.gap(39, 1), 2)
	assert_eq(PrizeVault.listen(12, 12), 1.0, "on the number")
	assert_eq(PrizeVault.listen(12 + int(PrizeVault.HEAR), 12), 0.0, "out of hearing")
	assert_gt(PrizeVault.listen(14, 12), PrizeVault.listen(16, 12), "louder when closer")
