extends GameTest

#Transitions and mouse support (docs/UI.md): the shutter swaps screens behind it, harness and
#headless runs skip the animation, clickable hints are mouse targets, and nothing inside a stat row
#swallows the click meant for the row. Nothing here writes the save.

func after_each():
	if Transition.busy(): Transition.active.free()

func test_headless_runs_skip_the_animation():
	assert_true(Transition.instant(), "the test runner is headless")

func test_play_runs_the_swap_behind_the_door_and_clears_it():
	var swapped = [false]
	await Transition.play(func(): swapped[0] = true)
	assert_true(swapped[0], "the swap ran")
	await get_tree().process_frame
	assert_false(Transition.busy(), "the door is gone")

func test_a_closed_door_waits_for_open():
	var door = Transition.close("TEST", "LOADING", 0.0)
	assert_true(Transition.busy())
	door.progress = 0.5
	assert_almost_eq(door.door.lamps, 0.5, 0.001, "progress lights the lamps")
	if not door.isShut: await door.shut
	door.open()
	await get_tree().process_frame
	assert_false(Transition.busy())

func test_a_second_play_while_busy_still_swaps():
	var door = Transition.close()
	var swapped = [false]
	await Transition.play(func(): swapped[0] = true)
	assert_true(swapped[0], "a change asked for mid-transition is never dropped")
	if is_instance_valid(door): door.free()

func test_the_game_hatch_is_skipped_by_the_harness():
	var stage = add_child_autofree(Control.new())
	var card = Control.new()
	stage.add_child(card)
	var hatch = GameHatch.attach(self, stage, card, "BONUS")
	hatch.enter()
	assert_null(hatch.door, "no hatch drawn when instant")
	await hatch.leave()
	assert_eq(stage.position.x, 0.0, "the stage never moved")
	hatch.free()

func test_shutter_door_lamps_and_rail():
	var door = add_child_autofree(ShutterDoor.new())
	door.size = Vector2(800, 400)
	assert_eq(door.railHeight(), 26.0)
	door.small = true
	assert_eq(door.railHeight(), 16.0)
	door.lamps = 1.0
	assert_eq(door.lamps, 1.0)

func test_clickable_hints_take_the_mouse_and_plain_ones_do_not():
	var plain = add_child_autofree(KeyHint.make(PackedStringArray(["ui_accept"]), "Drive"))
	assert_eq(plain.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a hint inside a button stays out of the way")
	var one = add_child_autofree(KeyHint.make(PackedStringArray(["ui_accept"]), "Drive", 15, true))
	assert_eq(one.mouse_filter, Control.MOUSE_FILTER_STOP, "one action: the whole hint is the button")
	var pair = add_child_autofree(KeyHint.make(PackedStringArray(["ui_tab_prev", "ui_tab_next"]), "Driver", 15, true))
	assert_eq(pair.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var chips = pair.get_children().filter(func(c): return c is PanelContainer)
	assert_eq(chips.size(), 2)
	for chip in chips: assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_STOP, "two actions: each chip is its own button")

func test_a_hint_bar_is_clickable():
	var row = add_child_autofree(KeyHint.bar([[["ui_cancel"], "Back"], [["ui_accept"], "Start"]]))
	for hint in row.get_children(): assert_true(hint.clickable)

#the original bug: a plain Control in a stat row defaults to MOUSE_FILTER_STOP and ate the click
func test_nothing_in_a_stat_row_swallows_its_click():
	var card = DriverCard.new()
	add_child(card)
	var info = load(CarInfo.pathFor("res://scene/car/sedan/sedan.tscn"))
	card.setup({"name": "sedan", "cost": 0, "upgrades": {}, "records": {}}, info, 0)
	card.setFocused(true)
	for row in card.statButtons + card.compactButtons:
		for node in row.find_children("*", "Control", true, false):
			assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s in a stat row must ignore the mouse" % node.name)
	card.free()

func test_upgrade_mode_opens_the_sheet_on_the_clicked_stat():
	var card = DriverCard.new()
	add_child(card)
	var info = load(CarInfo.pathFor("res://scene/car/sedan/sedan.tscn"))
	card.setup({"name": "sedan", "cost": 0, "upgrades": {}, "records": {}}, info, 0)
	card.setFocused(true)
	card.setUpgradeMode(true, false, Root.upgrade.ARMOR)
	assert_true(card.sheet.visible, "the sheet is open")
	assert_false(card.compact.visible, "the compact grid is folded away")
	assert_eq(card.get_viewport().gui_get_focus_owner(), card.statButtons[3], "focus starts on the stat that was clicked")
	assert_eq(card.upgradeButton.text, "Done")
	card.setUpgradeMode(false, false)
	assert_true(card.compact.visible)
	card.free()
