extends GameTest

#Mode tiers (ModeTiers; GAMEPLAY_SUGGESTIONS package 1, B-1 and B-2): Easy, Medium and Hard per mode and level,
#what each pays, how the save keeps them and the unlock condition that counts them. Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

const M = Root.gameModes

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func test_beating_a_tier_credits_it_and_the_ones_below():
	var data = PlayerData.new()
	SaveManager.playerData = data
	data.selectedLevel = 0
	data.gameMode = M.GOONCRUSHER
	data.gameTier = ModeTiers.MEDIUM
	assert_eq(ModeTiers.best(data.levels[0], M.GOONCRUSHER), ModeTiers.NONE)
	assert_eq(SaveManager.currentLevelPassed(), ModeTiers.NONE, "returns the best tier before the run")
	assert_eq(ModeTiers.best(data.levels[0], M.GOONCRUSHER), ModeTiers.MEDIUM)
	assert_true(data.levels[0].gamemodeBeat[M.GOONCRUSHER], "any tier counts as beaten for the unlock chain")
	data.gameMode = M.GOONCRUSHER
	data.gameTier = ModeTiers.EASY
	SaveManager.currentLevelPassed()
	assert_eq(ModeTiers.best(data.levels[0], M.GOONCRUSHER), ModeTiers.MEDIUM, "an easier win never lowers the medal")

func test_hard_opens_once_medium_is_beaten():
	var level := {"unlocked": true, "gamemodeBeat": {}, "tiers": {}}
	assert_true(ModeTiers.isOpen(level, M.SPRINT, ModeTiers.EASY))
	assert_true(ModeTiers.isOpen(level, M.SPRINT, ModeTiers.MEDIUM))
	assert_false(ModeTiers.isOpen(level, M.SPRINT, ModeTiers.HARD))
	assert_true(ModeTiers.lockReason(level, M.SPRINT, ModeTiers.HARD) != "")
	SaveManager.passTier(level, M.SPRINT, ModeTiers.MEDIUM)
	assert_true(ModeTiers.isOpen(level, M.SPRINT, ModeTiers.HARD))
	assert_false(ModeTiers.isOpen(level, M.MARATHON, ModeTiers.HARD), "per mode")

func test_a_save_from_before_the_tiers_counts_beaten_modes_as_easy():
	var old := [{"id": "prairie", "unlocked": true, "gamemodeBeat": {M.GOONCRUSHER: true, M.SPRINT: false}}]
	var merged := SaveManager.mergeLevels(old)
	assert_eq(merged[0].tiers[M.GOONCRUSHER], ModeTiers.EASY)
	assert_eq(merged[0].tiers[M.SPRINT], ModeTiers.NONE)
	var newer := [{"id": "prairie", "unlocked": true, "gamemodeBeat": {M.GOONCRUSHER: true}, "tiers": {M.GOONCRUSHER: ModeTiers.HARD}}]
	assert_eq(SaveManager.mergeLevels(newer)[0].tiers[M.GOONCRUSHER], ModeTiers.HARD, "tiers are kept")
	assert_eq(ModeTiers.best({"gamemodeBeat": {M.DEFENSE: true}}, M.DEFENSE), ModeTiers.EASY, "an entry with no tiers at all")

func test_win_bonus_grows_with_tier_and_level():
	for mode in M.values():
		var easy := ModeTiers.winBonus(mode, ModeTiers.EASY, 0)
		assert_gt(easy, 0, "%s pays a win bonus" % M.find_key(mode))
		assert_gt(ModeTiers.winBonus(mode, ModeTiers.MEDIUM, 0), easy, "Medium pays more")
		assert_gt(ModeTiers.winBonus(mode, ModeTiers.HARD, 0), ModeTiers.winBonus(mode, ModeTiers.MEDIUM, 0), "Hard more again")
		assert_gt(ModeTiers.winBonus(mode, ModeTiers.EASY, 7), easy, "later levels pay more")

func test_win_bonus_is_paid_by_the_minute_so_short_goals_cant_be_farmed():
	var def := Levels.defAt(0)
	for mode in M.values():
		for tier in ModeTiers.TIERS:
			var minutes := ModeTiers.goalSeconds(mode, tier, def.seconds, def.sprintSlack) / 60.0
			assert_gt(minutes, 0.5, "%s %s has a goal length" % [M.find_key(mode), ModeTiers.NAMES[tier]])
			var perMinute := ModeTiers.winBonus(mode, tier, 0) / minutes
			assert_between(perMinute, 30.0, 300.0, "%s %s pays %d a minute of its goal" % [M.find_key(mode), ModeTiers.NAMES[tier], perMinute])

func test_first_clear_pays_each_new_tier_once():
	var first := ModeTiers.firstClear(ModeTiers.NONE, ModeTiers.EASY, 0)
	assert_eq(first.coin, ModeTiers.FIRST_CLEAR_COINS[ModeTiers.EASY])
	assert_eq(ModeTiers.firstClear(ModeTiers.EASY, ModeTiers.EASY, 0).coin, 0, "nothing for a tier already won")
	var jump := ModeTiers.firstClear(ModeTiers.EASY, ModeTiers.HARD, 0)
	assert_eq(jump.coin, ModeTiers.FIRST_CLEAR_COINS[ModeTiers.MEDIUM] + ModeTiers.FIRST_CLEAR_COINS[ModeTiers.HARD], "every tier newly credited pays")
	assert_eq(jump.gem, ModeTiers.FIRST_CLEAR_GEMS[ModeTiers.MEDIUM] + ModeTiers.FIRST_CLEAR_GEMS[ModeTiers.HARD])
	assert_eq(ModeTiers.firstClear(ModeTiers.HARD, ModeTiers.MEDIUM, 0).coin, 0)

func test_harder_tiers_ask_more():
	for i in range(ModeTiers.EASY, ModeTiers.HARD):
		assert_gt(ModeTiers.CLOCK[i + 1], ModeTiers.CLOCK[i], "Countdown runs longer")
		assert_gt(ModeTiers.POCALYPSE_TARGET[i + 1], ModeTiers.POCALYPSE_TARGET[i])
		assert_gt(ModeTiers.DEFENSE_HOLD[i + 1], ModeTiers.DEFENSE_HOLD[i])
		assert_gt(ModeTiers.SLACK[i], ModeTiers.SLACK[i + 1], "Sprint's clock is tighter")
		assert_gt(ModeTiers.LEGS[i + 1], ModeTiers.LEGS[i])
		assert_true(ModeTiers.ESCALATION[i] <= ModeTiers.ESCALATION[i + 1] && ModeTiers.SPAWN_TIMER[i] >= ModeTiers.SPAWN_TIMER[i + 1], "the world is tougher")
	for mode in M.values(): assert_true(ModeTiers.goalText(mode, ModeTiers.MEDIUM, 300.0) != "", "%s has a goal line" % M.find_key(mode))

func test_the_level_reads_its_tier():
	var data = PlayerData.new()
	SaveManager.playerData = data
	data.gameMode = M.MARATHON
	data.gameTier = ModeTiers.HARD
	var def := Levels.get_def(&"prairie")
	var level = load(Levels.scenePath(&"prairie")).instantiate()
	level.readRun()
	level.applyDef()
	assert_eq(level.tier, ModeTiers.HARD)
	assert_eq(level.runMode, M.MARATHON)
	assert_eq(level.legs(), ModeTiers.LEGS[ModeTiers.HARD])
	assert_almost_eq(level.slack(), def.sprintSlack * ModeTiers.SLACK[ModeTiers.HARD], 0.0001)
	assert_almost_eq(level.get_node("SpawnManager").escalationSpeed, def.escalationSpeed * ModeTiers.ESCALATION[ModeTiers.HARD], 0.0001)
	level.free()

func test_clears_condition_counts_medals():
	var data = PlayerData.new()
	SaveManager.playerData = data
	assert_true(Unlocks.isValidNeed("clears:medium:3"))
	assert_false(Unlocks.isValidNeed("clears:extreme:3"))
	assert_eq(Unlocks.progressOf("clears:medium:2").have, 0)
	SaveManager.passTier(data.levels[0], M.GOONCRUSHER, ModeTiers.HARD)
	SaveManager.passTier(data.levels[1], M.SPRINT, ModeTiers.MEDIUM)
	SaveManager.passTier(data.levels[1], M.DEFENSE, ModeTiers.EASY)
	assert_eq(Unlocks.progressOf("clears:easy:1").have, 3)
	assert_eq(Unlocks.progressOf("clears:medium:2").have, 2, "a Hard clear counts as Medium too")
	assert_eq(Unlocks.progressOf("clears:hard:1").have, 1)
	assert_true(Unlocks.needsMet(["clears:medium:2"]))

func test_personas_pick_a_tier_they_can_start():
	var data = PlayerData.new()
	SaveManager.playerData = data
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for id in ["rookie", "grinder", "explorer"]:
		var run := Personas.chooseRun(Personas.get_def(id), data, [], rng)
		assert_true(ModeTiers.isOpen(data.levels[run.level], run.mode, run.tier), "%s picks an open tier" % id)
	SaveManager.passTier(data.levels[0], M.GOONCRUSHER, ModeTiers.MEDIUM)
	var run := {"level": 0, "mode": M.GOONCRUSHER}
	assert_eq(Personas.chooseTier(Personas.get_def("rookie"), data, [], run, rng), ModeTiers.MEDIUM, "the Rookie stops at Medium")
	assert_eq(Personas.chooseTier(Personas.get_def("grinder"), data, [], run, rng), ModeTiers.HARD, "the Grinder goes for gold")

func test_gift_boxes_are_counted_for_unlocks():
	var data = PlayerData.new()
	SaveManager.playerData = data
	assert_true(Unlocks.isValidNeed("boxes:5"))
	Unlocks.countRun(false, M.GOONCRUSHER, 0, 0, 3)
	Unlocks.countRun(false, M.GOONCRUSHER, 0, 0, 1)
	assert_eq(Unlocks.progressOf("boxes:5").have, 4, "boxes add up over runs")
	assert_eq(int(data.meta.lifetime.bestBox), 3, "and the best run is kept")

func test_later_acts_need_medium_wins_to_open_the_next_level():
	var data = PlayerData.new()
	SaveManager.playerData = data
	var quarry: Dictionary = data.levels[Levels.indexOf(&"quarry")] #act 2: one of the three on Medium
	assert_eq(Root.mediumToOpenNext(quarry), 1)
	assert_eq(Root.mediumToOpenNext(data.levels[Levels.indexOf(&"city")]), 2, "act 3 asks for two")
	assert_eq(Root.mediumToOpenNext(data.levels[0]), 0, "act 1 asks for none")
	for mode in [M.GOONCRUSHER, M.SPRINT, M.GOONPOCALYPSE]: SaveManager.passTier(quarry, mode, ModeTiers.EASY)
	assert_false(Root.opensNextLevel(quarry), "three Easy wins aren't enough in act 2")
	assert_eq(Root.openLeftText(quarry), "Win 1 more on Medium here")
	SaveManager.passTier(quarry, M.SPRINT, ModeTiers.MEDIUM)
	assert_true(Root.opensNextLevel(quarry))
	assert_eq(Root.openLeftText(quarry), "")
	assert_true(Root.openRuleText(quarry).contains("1 on Medium"))
