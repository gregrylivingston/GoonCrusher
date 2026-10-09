extends GameTest

#The prize games on the PickupMenu frame (docs/PICKUPS.md, "Prize games"): no game pays another, the winnings
#board says what each prize did, and each game's rules (claw grip, slot pay line, the Deal's deck, the
#shuffle's rounds, the press, pachinko and pusher).

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

func freeMenu(menu: PickupMenu) -> void:
	for node in [menu.root, menu.card, menu.body, menu.stage, menu.info, menu.board]: node.free()
	menu.free()

func test_claw_heap_settles():
	var claw := ClawCrane.new()
	for i in 14: claw.addPrize("coinstack" if i % 2 else "jerry", Vector2(150 + (i % 7) * 60.0, 220 + (i / 7) * 60.0))
	claw.settle(2.0)
	for p in claw.prizes:
		assert_true(p.pos.y <= ClawCrane.FLOOR_Y - p.r + 0.5 && p.pos.x >= ClawCrane.CHUTE_X, "a prize rests on the floor or the heap, not through it")
	for i in claw.prizes.size():
		for j in range(i + 1, claw.prizes.size()):
			var a: Dictionary = claw.prizes[i]
			var b: Dictionary = claw.prizes[j]
			assert_gt(a.pos.distance_to(b.pos), a.r + b.r - 3.0, "prizes barely overlap")
	freeMenu(claw)

## Lifts the claw with a prize between its prongs, held at `angle`; true if the prize came up with it
func lifted(angle: float, id: String) -> bool:
	var claw := ClawCrane.new()
	claw.clawX = 320.0
	claw.cable = 300.0
	claw.prong = angle
	var tip: Vector2 = claw.clawXform() * Vector2(0, 52 * ClawCrane.CLAW_SCALE)
	var p := claw.addPrize(id, tip)
	for i in 120: #half a second up at lift speed
		claw.cable -= ClawCrane.LIFT_SPEED * ClawCrane.STEP
		claw.stepPhysics(ClawCrane.STEP)
	var up: bool = p.pos.y < tip.y - 80.0
	freeMenu(claw)
	return up

func test_claw_holds_by_strength():
	var common := "coinstack"
	assert_true(lifted(ClawCrane.SHUT_ANGLE, common), "a shut claw lifts a prize")
	assert_false(lifted(ClawCrane.WEAK_ANGLE, common), "the weakest claw lets it drop")
	assert_true(ClawCrane.rollStrength(0, 4) > ClawCrane.rollStrength(0, 0) - 0.3, "a better box makes a stronger claw")

func test_claw_junk_costs():
	assert_true(PickupMenu.isJunk("junk:bomb") && not PickupMenu.isJunk("coinstack"))
	for id in PickupMenu.JUNK:
		assert_true(ClawCrane.textureOf(id) != null, "%s has an icon" % id)
		assert_false(Pickups.has(id), "junk is not a pickup")

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
	freeMenu(machine)

func test_deal_counts_what_beats_your_card():
	var common := gadget(Pickups.R.UNCOMMON)
	var legendary := gadget(Pickups.R.LEGENDARY)
	assert_eq(PickupDeal.beats(common, [legendary, common, legendary]), 2)
	assert_eq(PickupDeal.beats(legendary, [legendary, common]), 0)


func test_every_prize_game_opens():
	for g in CrushPrizes.GAMES: assert_true(CrushPrizes.game(g.id).has("icon") && CrushPrizes.texture(g.id) != null, "%s has an icon" % g.id)
	assert_eq(CrushPrizes.GAMES.map(func(g): return g.id), ["claw", "shuffle", "scratch", "press", "deal", "pachinko", "slot", "pusher"], "the ladder, weakest first")

func test_physics_rests_on_a_floor_and_bounces():
	var physics := PrizePhysics.new()
	var ball := physics.add(Vector2(100, 0), 10.0)
	var floor := [[Vector2(0, 200), Vector2(400, 200), 2.0]]
	for i in 480: physics.step(1.0 / 240.0, [floor[0]])
	assert_almost_eq(ball.pos.y, 188.0, 1.0, "it comes to rest on the floor")
	assert_true(ball.held, "held up by it")
	physics.bounce = 0.6
	ball.pos = Vector2(100, 100)
	ball.prev = ball.pos
	var lowest := 0.0
	var rose := false
	for i in 240:
		physics.step(1.0 / 240.0, [floor[0]])
		if ball.pos.y > lowest: lowest = ball.pos.y
		elif lowest > 180.0 && ball.pos.y < lowest - 5.0: rose = true
	assert_true(rose, "a bouncy ball comes back up off the floor")

func test_shuffle_rounds_get_better_and_harder():
	assert_gt(HubcapShuffle.roundTier(2, 0), HubcapShuffle.roundTier(0, 0), "later rounds are rarer")
	assert_gt(HubcapShuffle.swapCount(2, 0), HubcapShuffle.swapCount(0, 0), "and swap more")
	assert_true(HubcapShuffle.swapCount(0, 4) <= HubcapShuffle.swapCount(0, 0), "a better box swaps less")

func test_the_deal_deck():
	var deck := PickupDeal.dealDeck(Pickups.R.COMMON)
	assert_eq(deck.size(), PickupDeal.DECK)
	assert_true(deck.filter(func(id): return id in ["coin", "coinstack", "purse"]).size() >= PickupDeal.COIN_CARDS, "with coin cards in it")
	for id in deck: assert_false(id in Pickups.NOT_IN_GAMES, "never another game")
