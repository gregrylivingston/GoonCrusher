extends GameTest

#The run's score and rank (RunRank), its par lookup, the save's best rank, and where the results ticket's
#Next button goes. Nothing is written: SaveManager.playerData is swapped for a test copy and restored.

const M = Root.gameModes
const PAR := {"crushed": 100.0, "combo": 10.0, "speed": 600.0, "paid": 400.0, "time": 120.0}

var original: PlayerData

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

#a run exactly at par
func atPar(won: bool) -> Dictionary:
	return {"won": won, "progress": 1.0 if won else 0.5, "timed": true, "time": 120.0, "crushed": 100, "giants": 0, "combo": 10, "speed": 600.0, "paid": 400, "fuel": 50.0}

func test_the_ladder_has_25_ranks_from_goon_to_gooncrusher():
	assert_eq(RunRank.TITLES.size(), RunRank.RANKS)
	assert_eq(RunRank.title(1), "Goon")
	assert_eq(RunRank.title(18), "Derby King")
	assert_eq(RunRank.title(25), "GoonCrusher")
	assert_eq(RunRank.rankOf(0), 1)
	assert_eq(RunRank.rankOf(RunRank.MAX_SCORE), RunRank.RANKS)
	assert_eq(RunRank.rankOf(RunRank.MAX_SCORE * 3), RunRank.RANKS, "never past the top")
	var shares := 0.0
	for part in RunRank.SHARES: shares += RunRank.SHARES[part]
	assert_almost_eq(shares, 1.0, 0.001, "the parts share the whole score")

func test_a_win_at_par_lands_mid_ladder_and_more_on_a_harder_tier():
	var hard: Dictionary = RunRank.grade(atPar(true), PAR, ModeTiers.HARD)
	var easy: Dictionary = RunRank.grade(atPar(true), PAR, ModeTiers.EASY)
	assert_between(hard.score, 640, 680, "two thirds of the score at par")
	assert_gt(hard.score, easy.score, "the tier scales it")
	assert_eq(hard.title, RunRank.title(hard.rank))
	assert_eq(hard.highlight, "", "nothing stood out")

func test_the_top_rank_needs_a_hard_run_well_past_par():
	var great := {"won": true, "progress": 1.0, "timed": true, "time": 60.0, "crushed": 300, "giants": 4, "combo": 40, "speed": 1200.0, "paid": 2000, "fuel": 50.0}
	assert_eq(RunRank.grade(great, PAR, ModeTiers.HARD).rank, RunRank.RANKS)
	assert_gt(RunRank.RANKS, RunRank.grade(great, PAR, ModeTiers.EASY).rank, "out of reach on Easy")
	assert_eq(RunRank.grade(great, PAR, ModeTiers.HARD).highlight, "Giant Killer")

func test_a_lost_run_tops_out_mid_ladder():
	var loss := {"won": false, "progress": 0.99, "timed": true, "time": 60.0, "crushed": 300, "giants": 0, "combo": 40, "speed": 1200.0, "paid": 2000, "fuel": 0.0}
	var graded: Dictionary = RunRank.grade(loss, PAR, ModeTiers.HARD)
	assert_eq(graded.score, RunRank.LOSS_CAP)
	assert_eq(graded.rank, 13)
	assert_gt(RunRank.grade(atPar(true), PAR, ModeTiers.HARD).score, RunRank.grade(atPar(false), PAR, ModeTiers.HARD).score, "a win at par scores more than a loss at par")

func test_a_quicker_win_scores_more_where_time_counts():
	var slow := atPar(true)
	var quick := atPar(true)
	quick.time = 90.0
	assert_gt(RunRank.grade(quick, PAR, ModeTiers.MEDIUM).parts.goal, RunRank.grade(slow, PAR, ModeTiers.MEDIUM).parts.goal)
	slow.time = 300.0
	assert_eq(RunRank.grade(slow, PAR, ModeTiers.MEDIUM).parts.goal, RunRank.grade(atPar(true), PAR, ModeTiers.MEDIUM).parts.goal, "a slow win is still a win")
	var survived := atPar(true) #no pace to measure: a win counts as far past par as the rest of the run
	survived.timed = false
	survived.crushed = 150
	survived.paid = 600
	survived.combo = 15
	survived.speed = 900.0
	assert_eq(RunRank.grade(survived, PAR, ModeTiers.HARD).score, RunRank.MAX_SCORE)

func test_a_part_with_no_par_counts_as_met():
	var noGoons := {"crushed": 0.0, "combo": 0.0, "speed": 600.0, "paid": 400.0, "time": 0.0}
	var run := atPar(true)
	run.crushed = 0
	run.combo = 0
	assert_eq(RunRank.grade(run, noGoons, ModeTiers.HARD).score, RunRank.grade(atPar(true), PAR, ModeTiers.HARD).score)

func test_par_falls_back_from_the_level_to_the_mode():
	var keep = RunRank.table
	var wasRead = RunRank.tableRead
	RunRank.tableRead = true
	RunRank.table = {"prairie/sprint/1": {"crushed": 10.0, "combo": 2.0, "speed": 500.0, "paid": 100.0, "time": 50.0},
		"bayou/sprint/1": {"crushed": 30.0, "combo": 4.0, "speed": 700.0, "paid": 300.0, "time": 70.0},
		"bayou/sprint/2": {"crushed": 90.0, "combo": 4.0, "speed": 700.0, "paid": 300.0, "time": 70.0}}
	assert_eq(RunRank.parFor("prairie", "sprint", 1).crushed, 10.0, "its own")
	assert_eq(RunRank.parFor("quarry", "sprint", 1).crushed, 20.0, "the mode on that tier over the levels that have one")
	assert_eq(RunRank.parFor("quarry", "sprint", 3).crushed, 130.0 / 3.0, "then the mode on any tier")
	assert_eq(RunRank.parFor("quarry", "derby", 1), RunRank.FALLBACK, "then the fallback")
	RunRank.table = keep
	RunRank.tableRead = wasRead

func test_the_save_keeps_the_best_rank_of_a_mode_on_a_level():
	assert_true(SaveManager.bestRank(0, M.SPRINT).is_empty())
	var first := SaveManager.recordRank(0, M.SPRINT, "sedan", ModeTiers.EASY, 500, 13)
	assert_true(first.best)
	assert_eq(first.before, 0)
	var worse := SaveManager.recordRank(0, M.SPRINT, "sedan", ModeTiers.EASY, 300, 8)
	assert_false(worse.best)
	assert_eq(worse.before, 500)
	assert_eq(SaveManager.bestRank(0, M.SPRINT).rank, 13)
	assert_eq(SaveManager.getCarByName("sedan").records.rank, 13, "and the car's own best")
	assert_true(SaveManager.bestRank(0, M.GOONCRUSHER).is_empty(), "per mode")
	assert_true(SaveManager.bestRank(1, M.SPRINT).is_empty(), "per level")

func test_next_goes_to_the_next_mode_not_won_then_the_next_level():
	var summary = load("res://scene/player/menu/gameSummary.gd")
	var data: PlayerData = SaveManager.playerData
	var path := Root.modePath(0)
	SaveManager.passTier(data.levels[0], path[0], ModeTiers.EASY)
	var next: Dictionary = summary.nextRun(0, path[0], ModeTiers.HARD)
	assert_eq(next.level, 0)
	assert_eq(next.mode, path[1], "the second opener, which the first one opened")
	assert_eq(next.tier, ModeTiers.MEDIUM, "Hard isn't open there until Medium is beaten")
	for mode in path: SaveManager.passTier(data.levels[0], mode, ModeTiers.EASY)
	assert_true(summary.nextRun(0, path[-1], ModeTiers.EASY).is_empty(), "nothing left here, and the next level is locked")
	data.levels[1].unlocked = true
	next = summary.nextRun(0, path[-1], ModeTiers.EASY)
	assert_eq(next.level, 1)
	assert_eq(next.mode, Root.firstMode(1))

func test_selecting_a_run_sets_what_the_next_run_and_run_setup_read():
	RunLauncher.select(1, M.GOONCRUSHER, ModeTiers.MEDIUM)
	var data: PlayerData = SaveManager.playerData
	assert_eq(data.selectedLevel, 1)
	assert_eq(data.gameMode, M.GOONCRUSHER)
	assert_eq(SaveManager.getGameTier(), ModeTiers.MEDIUM)
