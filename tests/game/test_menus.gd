extends GameTest

#The card menus (docs/UI.md): prompts follow the input device, driver cards show locks and prices,
#pause keeps Abandon and Quit apart, and the records ticket lists a driver's bests.
#Nothing here selects, buys or plays, so the save is never written.

var padBefore: bool

func before_each():
	padBefore = InputGlyphs.usingPad
	InputGlyphs.ensureMenuActions()

func after_each():
	InputGlyphs.usingPad = padBefore

func test_prompts_name_the_key_or_button_for_the_device():
	assert_eq(InputGlyphs.label("ui_accept", false), "Space", "the left hand's Accept")
	assert_eq(InputGlyphs.label("ui_accept", true), "A")
	assert_eq(InputGlyphs.label("ui_cancel", true), "B")
	assert_eq(InputGlyphs.label("ui_tab_prev", false), "Q")
	assert_eq(InputGlyphs.label("ui_tab_next", true), "RB")
	assert_eq(InputGlyphs.label("ui_menu", false), "Esc", "the Menu key is skipped for Esc")
	assert_eq(InputGlyphs.label("ui_upgrade", false), "F")
	assert_eq(InputGlyphs.label("ui_boost", false), "V")
	assert_eq(InputGlyphs.label("ui_up", false), "W", "WASD before the arrows")
	assert_eq(InputGlyphs.label("ui_right", false), "D")
	assert_eq(InputGlyphs.label("ui_upgrade", true), "Y")
	assert_eq(InputGlyphs.label("ui_records", true), "X")
	assert_eq(InputGlyphs.label("no_such_action"), "")

func test_the_last_device_used_wins():
	var pad = InputEventJoypadButton.new()
	pad.pressed = true
	InputGlyphs.note(pad)
	assert_true(InputGlyphs.usingPad, "a controller button")
	var key = InputEventKey.new()
	key.pressed = true
	InputGlyphs.note(key)
	assert_false(InputGlyphs.usingPad, "a key press")
	var drift = InputEventJoypadMotion.new()
	drift.axis_value = 0.2
	InputGlyphs.note(drift)
	assert_false(InputGlyphs.usingPad, "stick drift doesn't count")

func test_a_hint_switches_with_the_device():
	InputGlyphs.usingPad = false
	var hint = KeyHint.make(PackedStringArray(["ui_accept"]), "Drive")
	add_child(hint)
	assert_eq(chipText(hint), "Space")
	var pad = InputEventJoypadButton.new()
	pad.pressed = true
	hint._input(pad)
	assert_eq(chipText(hint), "A")
	var unbound = KeyHint.make(PackedStringArray(["no_such_action"]), "Nothing")
	add_child(unbound)
	assert_false(unbound.visible, "a hint with no binding hides")
	hint.free()
	unbound.free()

func test_left_hand_keys_go_first_and_enter_still_accepts():
	InputGlyphs.ensureMenuActions() #twice: idempotent
	var events = InputMap.action_get_events("ui_accept")
	var spaces = events.filter(func(e): return e is InputEventKey && (e.keycode == KEY_SPACE || e.physical_keycode == KEY_SPACE))
	assert_eq(spaces.size(), 1, "one Space, not a copy per call")
	assert_true(events.any(func(e): return e is InputEventKey && e.keycode == KEY_ENTER), "Enter still accepts")
	assert_true(InputMap.action_get_events("ui_left").any(func(e): return e is InputEventKey && e.keycode == KEY_LEFT), "the arrows still move")

func test_number_keys_name_a_digit():
	var key = InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_3
	assert_eq(InputGlyphs.digit(key), 3)
	key.physical_keycode = KEY_KP_8
	assert_eq(InputGlyphs.digit(key), 8, "the keypad too")
	key.physical_keycode = KEY_0
	assert_eq(InputGlyphs.digit(key), 0, "0 picks nothing")
	key.physical_keycode = KEY_F
	assert_eq(InputGlyphs.digit(key), 0)

func chipText(hint: KeyHint) -> String:
	for child in hint.get_children():
		if child is PanelContainer && not child.is_queued_for_deletion(): return child.get_child(0).text
	return ""

func test_a_locked_driver_is_a_silhouette_with_a_price():
	var card = DriverCard.new()
	add_child(card)
	var info = load("res://scene/car/van/van_info.tres")
	card.setup({"name": "van", "cost": 1000, "upgrades": {}, "records": {}}, info, 1)
	card.setFocused(true)
	assert_true(card.isLocked())
	assert_eq(card.portrait.modulate.r, 0.0, "silhouette")
	assert_false(card.stats.visible, "no stats on a locked card")
	assert_true(card.mainButton.text.begins_with("UNLOCK") || card.mainButton.text.begins_with("NEED"))
	card.free()

func test_an_owned_driver_shows_stats_and_drive():
	var card = DriverCard.new()
	add_child(card)
	var info = load("res://scene/car/sedan/sedan_info.tres")
	card.setup({"name": "sedan", "cost": 0, "upgrades": {}, "records": {}}, info, 0)
	card.setFocused(true)
	assert_eq(card.mainButton.text, "DRIVE")
	assert_true(card.stats.visible)
	assert_eq(card.statButtons.size(), 8, "every upgradeable stat")
	card.setFocused(false)
	assert_false(card.stats.visible, "side cards show only the name and type")
	card.free()

func test_the_focused_upgrade_row_shows_buy():
	var card = DriverCard.new()
	add_child(card)
	card.setup({"name": "sedan", "cost": 0, "upgrades": {}, "records": {}}, load("res://scene/car/sedan/sedan_info.tres"), 0)
	card.setFocused(true)
	var row: Button = card.statButtons[2]
	assert_eq(row.action_mode, BaseButton.ACTION_MODE_BUTTON_PRESS, "buys on the press, so holding repeats from there")
	card.showBuy(row, true)
	var buy = row.get_node_or_null("line/price/buy")
	if SaveManager.isUpgradeMaxed(DriverCard.STATS[2][1]):
		assert_null(buy, "no BUY on a maxed stat")
	else:
		assert_true(buy.visible, "the focused row's price is a BUY button")
		assert_false(row.get_node("line/price/plain").visible)
		card.showBuy(row, false)
		assert_false(buy.visible)
		assert_true(row.get_node("line/price/plain").visible, "other rows show the plain price")
	card.free()

func test_holding_accept_on_an_upgrade_row_repeats():
	var card = DriverCard.new()
	add_child(card)
	card.setup({"name": "sedan", "cost": 0, "upgrades": {}, "records": {}}, load("res://scene/car/sedan/sedan_info.tres"), 0)
	card.setFocused(true)
	card.setUpgradeMode(true, false, DriverCard.STATS[0][1])
	var bought = []
	card.upgradePressed.connect(func(stat): bought.push_back(stat)) #not wired to the save: nothing is bought
	Input.action_press("ui_accept")
	card._process(DriverCard.HOLD_DELAY * 0.5)
	assert_eq(bought.size(), 0, "a tap doesn't repeat")
	card._process(DriverCard.HOLD_DELAY * 0.5)
	card._process(DriverCard.HOLD_REPEAT)
	if DriverCard.canBuy(DriverCard.STATS[0][1]): assert_eq(bought.size(), 2, "after the delay, one buy per repeat")
	else: assert_eq(bought.size(), 0, "never a buy it can't afford")
	Input.action_release("ui_accept")
	card._process(1.0)
	assert_eq(card.holdTime, 0.0, "letting go resets the hold")
	card.free()

func test_coin_amounts_get_thousands_separators():
	assert_eq(DriverCard.formatCoins(37), "37")
	assert_eq(DriverCard.formatCoins(1000), "1,000")
	assert_eq(DriverCard.formatCoins(1234567), "1,234,567")

func test_pause_keeps_abandon_and_quit_apart():
	var pause = load("res://scene/player/menu/pauseMenu.tscn").instantiate()
	add_child(pause)
	assert_true(pause.abandonButton != pause.quitButton)
	assert_true(pause.abandonButton.text.begins_with("Abandon run"))
	assert_eq(pause.quitButton.text, "Quit game")
	assert_true(pause.continueButton.has_focus(), "Continue starts focused")
	pause._on_continue_pressed() #restores the menu context and unpauses
	await get_tree().process_frame

func test_records_ticket_lists_a_drivers_bests():
	var before = Root.carInfo
	var keep = SaveManager.playerData
	SaveManager.playerData = PlayerData.new() #a new save's records: the machine's own save may hold a combo or Goonpocalypse best, which add rows
	Root.carInfo = load("res://scene/car/sedan/sedan_info.tres")
	var records = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	records.isGameSummary = false
	add_child(records)
	assert_true(records.is_in_group("menuOverlay"), "the main menu ignores input under it")
	assert_between(records.rows.get_child_count(), 6, 9, "6 rows, plus best combo and Goonpocalypse ones when the save has them")
	assert_true(records.continueButton.visible, "records show at once")
	records.free()
	Root.carInfo = before
	SaveManager.playerData = keep
