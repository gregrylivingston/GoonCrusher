extends GameTest

#Gift boxes (CrushPrizes): crush XP, the box curve and tiers, the game ladder and its unlocks, the games'
#box versions, and the pickup name tags (Pickups.shortName).

var savedPrizes := {}
var wasAllOpen := false

func before_each() -> void:
	wasAllOpen = Unlocks.allOpen
	Unlocks.allOpen = false
	savedPrizes.clear()
	var saved := Unlocks.saved()
	for key in saved.keys():
		if String(key).begins_with("prize:"):
			savedPrizes[key] = saved[key]
			saved.erase(key)

func after_each() -> void:
	var saved := Unlocks.saved()
	for key in saved.keys():
		if String(key).begins_with("prize:"): saved.erase(key)
	saved.merge(savedPrizes)
	Unlocks.allOpen = wasAllOpen

func test_crush_xp_by_rank_size_and_style():
	assert_eq(CrushPrizes.crushXp({"rank": 1}, false, 1, false, false), 1.0, "fodder is 1")
	assert_eq(CrushPrizes.crushXp({"rank": 3}, false, 1, false, false), 8.0, "a heavy is 8")
	assert_eq(CrushPrizes.crushXp({"rank": 1}, true, 1, false, false), 4.0, "a giant is worth 4 times")
	assert_eq(CrushPrizes.crushXp({"rank": 1, "verb": &"boss"}, true, 1, false, false), 10.0, "a boss is 10 times, not also a giant")
	assert_almost_eq(CrushPrizes.crushXp({"rank": 1}, false, 11, false, false), 1.5, 0.001, "+5% per chained crush")
	assert_almost_eq(CrushPrizes.crushXp({"rank": 1}, false, 500, false, false), 2.0, 0.001, "the combo bonus caps at +100%")
	assert_almost_eq(CrushPrizes.crushXp({"rank": 2}, false, 1, true, true), 6.0, 0.001, "slam or drift +50%, night +50%")
	assert_almost_eq(CrushPrizes.crushXp({"rank": 1}, false, 1, false, false, 2.0), 2.0, 0.001, "a multiplier from pickups or perks")

func test_boxes_need_more_xp_each_time():
	assert_eq(CrushPrizes.boxAt(0), 0.0)
	assert_eq(CrushPrizes.boxAt(1), CrushPrizes.XP_BASE, "the first box")
	var last := 0.0
	for level in range(1, 12):
		var need := CrushPrizes.boxXp(level)
		assert_gt(need, last, "box %d needs more than the one before" % level)
		assert_almost_eq(CrushPrizes.boxAt(level) - CrushPrizes.boxAt(level - 1), need, 0.001, "leftover XP carries on")
		last = need

func test_tiers_climb_to_diamond():
	assert_eq(CrushPrizes.tierName(CrushPrizes.tierFor(1)), "Cardboard")
	assert_eq(CrushPrizes.tierName(CrushPrizes.tierFor(3)), "Silver")
	assert_eq(CrushPrizes.tierFor(5), CrushPrizes.TOP_TIER)
	assert_eq(CrushPrizes.tierFor(40), CrushPrizes.TOP_TIER, "Diamond is the top")

func test_only_the_weakest_game_starts_open():
	assert_eq(CrushPrizes.openGames(), [CrushPrizes.GAMES[0].id], "a new save boxes only the weakest game")
	assert_eq(CrushPrizes.state(CrushPrizes.GAMES[1].id), Unlocks.S.READY, "the next one up can be unlocked")
	assert_eq(CrushPrizes.state(CrushPrizes.GAMES[3].id), Unlocks.S.SHOWN, "the ladder opens in order")
	for tier in 5:
		for i in 20: assert_eq(CrushPrizes.pickGame(tier, i / 20.0, CrushPrizes.openGames()), CrushPrizes.GAMES[0].id, "nothing locked is ever boxed")
	CrushPrizes.grant(CrushPrizes.GAMES[1].id)
	assert_true(CrushPrizes.isOpen(CrushPrizes.GAMES[1].id), "granted: saved in meta.unlocks")
	assert_eq(CrushPrizes.state(CrushPrizes.GAMES[2].id), Unlocks.S.READY)
	Unlocks.allOpen = true
	assert_eq(CrushPrizes.openGames().size(), CrushPrizes.GAMES.size(), "harnesses open every game")

func test_higher_boxes_favour_stronger_games():
	var all := CrushPrizes.GAMES.map(func(g): return g.id)
	var low := {}
	var high := {}
	for i in 200:
		var a := CrushPrizes.pickGame(0, i / 200.0, all)
		var b := CrushPrizes.pickGame(CrushPrizes.TOP_TIER, i / 200.0, all)
		low[a] = low.get(a, 0) + 1
		high[b] = high.get(b, 0) + 1
	assert_gt(low.get(all[0], 0), 60, "a Cardboard box is mostly the weakest game")
	assert_gt(high.get(all[-1], 0), 60, "a Diamond box is mostly the strongest")
	assert_eq(low.get(all[-1], 0) < high.get(all[-1], 0), true)

func test_every_game_has_a_name_and_icon():
	for g in CrushPrizes.GAMES:
		assert_true(CrushPrizes.texture(g.id) != null, "%s has an icon" % g.id)
		assert_true(g.get("start", false) || not CrushPrizes.price(g.id).is_empty(), "%s has a price or starts open" % g.id)

func test_every_pickup_name_tag_fits():
	for id in Pickups.DATA:
		var tag := Pickups.shortName(id)
		assert_true(tag != "", "%s has a tag" % id)
		assert_true(HudTheme.textWidth(tag, Pickups.TAG_SIZE, HudTheme.BODY) <= Pickups.TAG_MAX_PX, "%s's tag \"%s\" fits" % [id, tag])
	for id in Pickups.SHORT_NAMES: assert_true(Pickups.DATA.has(id), "short name for a real pickup: %s" % id)
