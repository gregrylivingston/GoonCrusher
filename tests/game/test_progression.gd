extends GameTest

#Mode unlock chain, mode availability, payouts and the summary's input rule
#Nothing is written: SaveManager.playerData is swapped
#for a test copy and restored.

const M = Root.gameModes

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

#a save entry for Prairie Run: Sprint, Countdown, then Marathon, Rally Stage and Cannonball (LevelDef.featured)
func level(unlocked: bool, beaten: Array, id := "prairie") -> Dictionary:
	var beat = {}
	for mode in M.values(): beat[mode] = mode in beaten
	return {"id": id, "name": "test", "unlocked": unlocked, "gamemodeBeat": beat}

func test_a_level_plays_the_staples_and_its_three_featured_modes():
	assert_eq(Root.modePath(level(true, [])), [M.SPRINT, M.GOONCRUSHER, M.MARATHON, M.RALLY, M.CANNONBALL], "Sprint, Countdown, then its Crusher, Trial and Goon Cup mode")
	assert_eq(Root.modePath(0), Root.modePath(level(true, [])), "by index too")
	assert_eq(Root.featuredModes(0), [M.MARATHON, M.RALLY, M.CANNONBALL])
	assert_eq(Root.modePath({"unlocked": true}), Modes.DEFAULT_OPENERS, "an entry with no id has only the default openers")
	for i in Levels.count():
		var featured := Root.featuredModes(i)
		assert_eq(featured.map(func(m): return Modes.category(m)), Modes.CATEGORY_ORDER, "%s: one Crusher, one Trial, one Goon Cup" % Levels.ORDER[i])
		var openers := Root.openerModes(i)
		assert_eq(openers.size(), Root.OPENER_SLOTS, "%s: two openers" % Levels.ORDER[i])
		assert_ne(openers[0], openers[1], "%s: two different openers" % Levels.ORDER[i])
		assert_true(Modes.hasGoons(openers[0]) || Modes.hasGoons(openers[1]), "%s: at least one opener has goons" % Levels.ORDER[i])
		assert_true(Levels.defAt(i).openers.size() in [0, Root.OPENER_SLOTS], "%s names both openers or neither" % Levels.ORDER[i])
		for mode in featured: assert_false(mode in openers, "%s: an opener isn't featured too" % Levels.ORDER[i])
		assert_eq(Root.modePath(i).size(), 5, "%s plays five modes" % Levels.ORDER[i])
		assert_eq(Levels.defAt(i).featured.size(), 3, "%s names its three" % Levels.ORDER[i])
	for region in Territories.ORDER: #five Crusher modes, five stops: a region plays each once
		var crushers := {}
		for id in Territories.levelsOf(region): crushers[Root.featuredModes(Levels.indexOf(id))[0]] = true
		assert_eq(crushers.size(), Territories.STOPS, "%s plays every Crusher mode" % region)

func test_every_mode_has_its_words_and_an_icon():
	assert_eq(Modes.IDS.size(), M.size(), "an id per mode")
	for mode in M.values():
		assert_eq(Modes.byId(Modes.idOf(mode)), mode)
		assert_true(Modes.DATA.has(mode), "%s is in Modes.DATA" % M.find_key(mode))
		assert_true(Root.gameModeDescription[mode].name != "" && Root.gameModeDescription[mode].description != "", "%s has a name and a description" % M.find_key(mode))
		assert_true(Root.MODE_RULES.get(mode, "") != "", "%s says how it is won" % M.find_key(mode))
		assert_true(Root.MODE_AVAILABLE.has(mode), "%s is switched on or off" % M.find_key(mode))
		assert_true(HudTheme.MODE_ICONS.get(mode) is Texture2D, "%s has an icon" % M.find_key(mode))
	assert_eq(Modes.plays(M.BLACKOUT), M.GOONCRUSHER, "Blackout runs on Countdown's rules")
	assert_eq(Modes.plays(M.SPRINT), M.SPRINT)
	assert_eq(Modes.title(M.RALLY), "Rally Stage")

func test_unlock_chain():
	var fresh = level(true, [])
	assert_true(Root.isModeUnlocked(fresh, M.SPRINT), "Sprint is open on an unlocked level")
	for mode in [M.GOONCRUSHER, M.MARATHON, M.RALLY, M.CANNONBALL]:
		assert_false(Root.isModeUnlocked(fresh, mode), "%s starts locked" % M.find_key(mode))
	var sprint = level(true, [M.SPRINT])
	assert_true(Root.isModeUnlocked(sprint, M.GOONCRUSHER), "Sprint beaten opens Countdown")
	for mode in [M.MARATHON, M.RALLY, M.CANNONBALL]: assert_false(Root.isModeUnlocked(sprint, mode))
	var both = level(true, [M.GOONCRUSHER, M.SPRINT])
	for mode in Root.modePath(both): assert_true(Root.isModeUnlocked(both, mode), "%s is open once Countdown is won" % M.find_key(mode))
	for mode in [M.DEFENSE, M.GOONPOCALYPSE, M.BLACKOUT]: assert_false(Root.isModeUnlocked(both, mode), "%s isn't a Prairie Run mode" % M.find_key(mode))
	assert_eq(Root.modeLockReason(both, M.DEFENSE), "Win All Five Modes Here")
	var countdownOnly = level(true, [M.GOONCRUSHER]) #a save from when Countdown came first
	assert_true(Root.isModeUnlocked(countdownOnly, M.MARATHON))
	assert_true(Root.isModeUnlocked(countdownOnly, M.GOONCRUSHER), "a beaten mode stays open")
	var locked = level(false, [M.GOONCRUSHER, M.SPRINT, M.MARATHON])
	for mode in M.values(): assert_false(Root.isModeUnlocked(locked, mode), "nothing is open on a locked level")

func test_missing_keys_read_as_not_beaten():
	var old = {"id": "prairie", "unlocked": true, "gamemodeBeat": {M.GOONCRUSHER: true, M.SPRINT: true}} #no key for the newer modes
	assert_true(Root.isModeUnlocked(old, M.RALLY))
	assert_false(Root.isModeUnlocked({"id": "prairie", "unlocked": true}, M.GOONCRUSHER), "no gamemodeBeat at all")
	assert_false(Root.isModeUnlocked({}, M.SPRINT), "no unlocked key means locked")

func test_unavailable_modes_cant_be_played_whatever_the_unlocks():
	var all = level(true, M.values())
	for mode in Root.modePath(all):
		assert_eq(Root.isModePlayable(all, mode), Root.isModeAvailable(mode), "%s playable only if available" % M.find_key(mode))
	for mode in [M.SPRINT, M.GOONCRUSHER, M.MARATHON, M.DEFENSE, M.GOONPOCALYPSE, M.BLACKOUT]: assert_true(Root.isModeAvailable(mode), "%s is built" % M.find_key(mode))
	for mode in M.values():
		if not Root.isModeAvailable(mode): assert_eq(Root.modeLockReason(all, mode), "Coming Soon", "%s says so" % M.find_key(mode))
	assert_eq(Root.modeLockReason(all, M.SPRINT), "")
	assert_eq(Root.modeLockReason(level(true, []), M.GOONCRUSHER), "Beat Sprint To Unlock")
	assert_eq(Root.modeLockReason(level(true, [M.SPRINT]), M.MARATHON), "Beat Countdown To Unlock")
	assert_false(Root.modeLockReason(level(true, [M.SPRINT]), M.GOONPOCALYPSE) == "", "a locked mode always has a reason")

func test_any_featured_mode_opens_the_road():
	for mode in Root.featuredModes(0):
		var won = level(true, [M.SPRINT, M.GOONCRUSHER, mode])
		assert_eq(Root.opensNextLevel(won), Root.isModeAvailable(mode), "%s opens the next level once it is built" % M.find_key(mode))
	assert_false(Root.opensNextLevel(level(true, [M.SPRINT, M.GOONCRUSHER])), "the staples alone don't, where a featured mode can be played")
	assert_eq(Root.roadModes(0), Root.featuredModes(0).filter(func(m): return Root.isModeAvailable(m)), "the road is the featured modes that are built")
	Root.devAllModesAvailable = true
	assert_eq(Root.roadModes(0), Root.featuredModes(0))
	assert_eq(Root.roadText(level(true, [])), "Marathon, Rally Stage or Cannonball")
	Root.devAllModesAvailable = false
	#a level none of whose featured modes is built yet opens the road on Countdown
	var none = {"unlocked": true, "gamemodeBeat": {M.SPRINT: true, M.GOONCRUSHER: true}}
	assert_eq(Root.roadModes(none), [M.GOONCRUSHER])
	assert_true(Root.opensNextLevel(none))

func test_every_default_level_has_every_mode_key():
	for lvl in PlayerData.new().levels:
		for mode in M.values(): assert_true(lvl.gamemodeBeat.has(mode), "%s lacks %s" % [lvl.name, M.find_key(mode)])

func test_payout_is_coins_times_the_star_multiplier():
	assert_eq(Root.computePayout(120, 0), 120, "0 stars still pays the coins")
	assert_eq(Root.computePayout(120, 1), 132, "each star adds 0.1 to the multiplier")
	assert_eq(Root.computePayout(120, 3), 156)
	assert_eq(Root.computePayout(1000, 20), 3000, "20 stars pay x3")
	assert_eq(Root.computePayout(1000, 50), 3000, "and no more: the multiplier stops at STAR_MULT_MAX")
	assert_eq(Root.computePayout(0, 5), 0)
	assert_eq(Root.computePayout(50, -2), 50, "a negative star count can't pay less than the coins")
	assert_eq(Root.multiplierText(16), "2.6")
	assert_eq(Root.multiplierText(26), "3.0", "the multiplier stops at STAR_MULT_MAX")

func test_a_featured_mode_opens_the_next_level():
	var data = PlayerData.new()
	var keep = SaveManager.playerData
	SaveManager.playerData = data
	data.selectedLevel = 0 #Prairie Run: the Marathon is its Crusher mode
	assert_false(data.levels[1].unlocked)
	data.gameMode = M.SPRINT
	SaveManager.currentLevelPassed()
	assert_true(data.levels[0].gamemodeBeat[M.SPRINT], "the mode is marked beaten")
	assert_false(data.levels[1].unlocked, "Sprint isn't enough")
	assert_eq(data.gameMode, M.GOONCRUSHER, "the menu offers the mode it opened")
	assert_eq(SaveManager.openLeft(0), "Win %s here" % Root.roadText(data.levels[0]))
	SaveManager.currentLevelPassed()
	assert_false(data.levels[1].unlocked, "nor Countdown")
	assert_eq(data.gameMode, M.MARATHON, "then the first featured mode that can be played")
	SaveManager.currentLevelPassed()
	assert_true(data.levels[1].unlocked, "a featured mode opens the next level")
	assert_eq(data.selectedLevel, 1, "and it is selected")
	assert_eq(data.gameMode, Root.firstMode(1), "starting from its first opener")
	assert_eq(SaveManager.openLeft(0), "")
	SaveManager.playerData = keep

func test_a_finale_opens_the_next_region_on_medium():
	var data = PlayerData.new()
	var keep = SaveManager.playerData
	SaveManager.playerData = data
	var finale := Levels.indexOf(&"moosewoods")
	assert_true(Levels.defAt(finale).isFinale())
	data.levels[finale].unlocked = true
	var road: int = Root.roadModes(finale)[0]
	SaveManager.currentLevelPassed(finale, road, ModeTiers.EASY)
	assert_false(data.levels[finale + 1].unlocked, "an Easy win doesn't open the next region")
	assert_eq(Root.openLeftText(data.levels[finale]), "Win %s on Medium here" % Root.roadText(data.levels[finale]))
	assert_true(Root.openRuleText(data.levels[finale]).contains("on Medium"))
	SaveManager.currentLevelPassed(finale, road, ModeTiers.MEDIUM)
	assert_true(data.levels[finale + 1].unlocked, "Medium does")
	assert_false(Root.isFinale(data.levels[0]), "Prairie Run is no finale")
	assert_false(Root.openRuleText(data.levels[0]).contains("Medium"))
	SaveManager.playerData = keep

func test_an_older_save_gets_the_level_a_featured_win_now_opens():
	var data = PlayerData.new()
	var keep = SaveManager.playerData
	SaveManager.playerData = data
	data.saveVersion = 11
	var bayou := Levels.indexOf(&"bayou") #the Marathon isn't featured here; Blackout is
	data.levels[bayou].unlocked = true
	for mode in [M.SPRINT, M.GOONCRUSHER, M.MARATHON]: SaveManager.passTier(data.levels[bayou], mode, ModeTiers.EASY)
	SaveManager.migrate()
	assert_false(data.levels[bayou + 1].unlocked, "an old Marathon win on a level that doesn't feature it opens nothing")
	data.saveVersion = 11
	SaveManager.passTier(data.levels[bayou], M.BLACKOUT, ModeTiers.EASY)
	SaveManager.migrate()
	assert_true(data.levels[bayou + 1].unlocked, "a featured win does")
	SaveManager.playerData = keep

#the run's own level, mode and tier are credited, not the menu's selection (which can move while the ticket waits)
func test_the_run_is_credited_not_the_menu_selection():
	var data = PlayerData.new()
	var keep = SaveManager.playerData
	SaveManager.playerData = data
	data.levels[1].unlocked = true
	data.selectedLevel = 0
	data.gameMode = M.SPRINT
	data.gameTier = ModeTiers.EASY
	SaveManager.currentLevelPassed(1, M.GOONCRUSHER, ModeTiers.MEDIUM)
	assert_eq(ModeTiers.best(data.levels[1], M.GOONCRUSHER), ModeTiers.MEDIUM, "the run's level, mode and tier")
	assert_false(data.levels[0].gamemodeBeat[M.SPRINT], "the menu's selection is untouched")
	assert_eq(data.gameMode, M.SPRINT, "and so is its mode")
	SaveManager.playerData = keep

func test_the_results_ticket_says_what_opens_next():
	var data = PlayerData.new()
	var keep = SaveManager.playerData
	SaveManager.playerData = data
	var summary = load("res://scene/player/menu/gameSummary.gd")
	data.levels[2].gamemodeBeat[M.GOONCRUSHER] = true
	assert_eq(summary.nextLevelNote(2, false), "Win %s here to open %s" % [Root.roadText(data.levels[2]), data.levels[3].name])
	data.levels[2].gamemodeBeat[M.SPRINT] = true
	data.levels[2].gamemodeBeat[Root.roadModes(2)[0]] = true
	data.levels[3].unlocked = true
	assert_eq(summary.nextLevelNote(2, false), "%s is open" % data.levels[3].name)
	assert_eq(summary.nextLevelNote(2, true), "", "nothing to say when it was already open")
	assert_eq(summary.roadText(3), data.levels[3].name, "Road open names the next level")
	assert_eq(summary.roadText(5), "Mudlick Marsh, Tribe Country", "and the next region after a finale")
	SaveManager.playerData = keep

func test_summary_needs_a_fresh_press():
	var summary = load("res://scene/player/menu/gameSummary.gd")
	var key = InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	assert_true(summary.isFreshPress(key), "a new key press")
	key.echo = true
	assert_false(summary.isFreshPress(key), "key repeat from a held key")
	key.echo = false
	key.pressed = false
	assert_false(summary.isFreshPress(key), "a release")
	var pad = InputEventJoypadButton.new()
	pad.pressed = true
	assert_true(summary.isFreshPress(pad), "a controller button")
	var axis = InputEventJoypadMotion.new()
	axis.axis_value = 1.0
	assert_false(summary.isFreshPress(axis), "a held trigger or stick")
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	assert_false(summary.isFreshPress(wheel), "the mouse wheel")
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(summary.isFreshPress(click), "a click")

#a level names its own two openers (LevelDef.openers): the chain goes by slot, whatever the modes are
func test_a_level_with_its_own_openers_chains_by_slot():
	var id := "orchard"
	var path := Root.modePath(level(true, [], id))
	assert_eq(path.slice(0, 2), [M.SMASH, M.GOONCRUSHER], "Orchard Lanes opens on Smash Run, then Countdown")
	assert_eq(Root.firstMode(level(true, [], id)), M.SMASH)
	var fresh := level(true, [], id)
	assert_true(Root.isModeUnlocked(fresh, M.SMASH), "the first opener is open with the level")
	assert_false(Root.isModeUnlocked(fresh, M.GOONCRUSHER), "the second waits for the first")
	assert_false(Root.isModeUnlocked(fresh, M.SPRINT), "Sprint isn't one of its modes")
	assert_eq(Root.modeLockReason(fresh, M.GOONCRUSHER), "Beat Smash Run To Unlock")
	var first := level(true, [M.SMASH], id)
	assert_true(Root.isModeUnlocked(first, M.GOONCRUSHER))
	assert_false(Root.isModeUnlocked(first, path[2]), "the featured modes wait for the second opener")
	assert_eq(Root.modeLockReason(first, path[2]), "Beat Countdown To Unlock")
	var both := level(true, [M.SMASH, M.GOONCRUSHER], id)
	for mode in path: assert_true(Root.isModeUnlocked(both, mode), "%s is open" % M.find_key(mode))

#Free Play: all five won opens every other mode on the level; it is never part of the chain
func test_free_play_opens_when_all_five_are_won():
	var path := Root.modePath(level(true, []))
	var four := level(true, path.slice(0, 4))
	assert_false(Root.freePlayOpen(four), "four of five isn't enough")
	assert_false(Root.isModePlayable(four, M.DEFENSE))
	var all := level(true, path)
	assert_true(Root.freePlayOpen(all))
	assert_false(Root.freePlayOpen(level(false, path)), "never on a locked level")
	var free := Root.freePlayModes(all)
	assert_eq(free.size(), M.size() - 5, "every mode the level doesn't play")
	for mode in free:
		assert_true(Root.isFreePlay(all, mode))
		assert_true(Root.isModePlayable(all, mode), "%s can be started in Free Play" % M.find_key(mode))
		assert_false(Root.isModeUnlocked(all, mode), "but it isn't one of the level's modes")
		assert_true(ModeTiers.isOpen(all, mode, ModeTiers.HARD), "Free Play keeps no medals, so every tier is open")
	for mode in path: assert_false(Root.isFreePlay(all, mode))
	assert_eq(Root.modesBeaten(all), 5, "Free Play modes never count as beaten here")
