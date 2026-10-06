extends GameTest

#Mode unlock chain, mode availability, payouts and the summary's input rule
#(GAMEPLAY_SUGGESTIONS T0-6, T0-7, T0-9). Nothing is written: SaveManager.playerData is swapped
#for a test copy and restored.

const M = Root.gameModes

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func level(unlocked: bool, beaten: Array) -> Dictionary:
	var beat = {}
	for mode in M.values(): beat[mode] = mode in beaten
	return {"name": "test", "unlocked": unlocked, "gamemodeBeat": beat}

func test_unlock_chain():
	var fresh = level(true, [])
	assert_true(Root.isModeUnlocked(fresh, M.GOONCRUSHER), "Countdown is open on an unlocked level")
	for mode in [M.SPRINT, M.MARATHON, M.DEFENSE, M.GOONPOCALYPSE]:
		assert_false(Root.isModeUnlocked(fresh, mode), "%s starts locked" % M.find_key(mode))
	var countdown = level(true, [M.GOONCRUSHER])
	assert_true(Root.isModeUnlocked(countdown, M.SPRINT), "Countdown beaten opens Sprint")
	assert_false(Root.isModeUnlocked(countdown, M.GOONPOCALYPSE), "Goonpocalypse needs Sprint too")
	assert_false(Root.isModeUnlocked(countdown, M.MARATHON))
	assert_false(Root.isModeUnlocked(countdown, M.DEFENSE))
	var both = level(true, [M.GOONCRUSHER, M.SPRINT])
	for mode in M.values(): assert_true(Root.isModeUnlocked(both, mode), "%s is open once Countdown and Sprint are beaten" % M.find_key(mode))
	var sprintOnly = level(true, [M.SPRINT]) #only reachable by an edited save; Goonpocalypse still needs both
	assert_true(Root.isModeUnlocked(sprintOnly, M.MARATHON))
	assert_false(Root.isModeUnlocked(sprintOnly, M.GOONPOCALYPSE))
	assert_true(Root.isModeUnlocked(sprintOnly, M.SPRINT), "a beaten mode stays open (older saves could beat Sprint first)")
	var locked = level(false, [M.GOONCRUSHER, M.SPRINT])
	for mode in M.values(): assert_false(Root.isModeUnlocked(locked, mode), "nothing is open on a locked level")

func test_missing_keys_read_as_not_beaten():
	var old = {"unlocked": true, "gamemodeBeat": {M.GOONCRUSHER: true, M.SPRINT: true}} #no GOONPOCALYPSE key
	assert_true(Root.isModeUnlocked(old, M.GOONPOCALYPSE))
	assert_false(Root.isModeUnlocked({"unlocked": true}, M.SPRINT), "no gamemodeBeat at all")
	assert_false(Root.isModeUnlocked({}, M.GOONCRUSHER), "no unlocked key means locked")

func test_unavailable_modes_cant_be_played_whatever_the_unlocks():
	var all = level(true, M.values())
	for mode in M.values():
		assert_eq(Root.isModePlayable(all, mode), Root.isModeAvailable(mode), "%s playable only if available" % M.find_key(mode))
	assert_eq(Root.isModeAvailable(M.MARATHON), not Root.IS_DEMO, "Marathon is full-game only")
	assert_eq(Root.isModeAvailable(M.DEFENSE), not Root.IS_DEMO, "Defense is full-game only")
	assert_true(Root.isModeAvailable(M.GOONCRUSHER))
	assert_true(Root.isModeAvailable(M.SPRINT))
	assert_eq(Root.isModeAvailable(M.GOONPOCALYPSE), not Root.IS_DEMO, "Goonpocalypse is full-game only")
	assert_eq(Root.modeLockReason(all, M.MARATHON), "Not Available In Demo" if Root.IS_DEMO else "")
	assert_eq(Root.modeLockReason(all, M.GOONCRUSHER), "")
	assert_eq(Root.modeLockReason(level(true, []), M.SPRINT), "Beat Countdown To Unlock")
	assert_false(Root.modeLockReason(level(true, [M.GOONCRUSHER]), M.GOONPOCALYPSE) == "", "a locked mode always has a reason")

func test_every_default_level_has_every_mode_key():
	for lvl in PlayerData.new().levels:
		for mode in M.values(): assert_true(lvl.gamemodeBeat.has(mode), "%s lacks %s" % [lvl.name, M.find_key(mode)])

func test_payout_is_coins_times_stars_but_never_zero_for_coins():
	assert_eq(Root.computePayout(120, 0), 120, "0 stars still pays the coins")
	assert_eq(Root.computePayout(120, 1), 120)
	assert_eq(Root.computePayout(120, 3), 360)
	assert_eq(Root.computePayout(0, 5), 0)
	assert_eq(Root.computePayout(50, -2), 50, "a negative star count can't pay less than the coins")

func test_any_beaten_mode_unlocks_the_next_level():
	var data = PlayerData.new()
	data.selectedLevel = 2
	data.gameMode = M.SPRINT
	SaveManager.playerData = data
	assert_false(data.levels[3].unlocked)
	SaveManager.currentLevelPassed()
	assert_true(data.levels[2].gamemodeBeat[M.SPRINT], "the mode is marked beaten")
	assert_true(data.levels[3].unlocked, "the next level opens")
	assert_eq(data.selectedLevel, 3, "and is selected")
	assert_eq(data.gameMode, M.GOONCRUSHER, "starting from Countdown")

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
