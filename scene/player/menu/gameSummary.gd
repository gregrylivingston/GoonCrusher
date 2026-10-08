extends CanvasLayer

#The end of a run, printed as a ticket (docs/UI.md), and the same ticket for a driver's records.
#Results: rows reveal one at a time (a fresh press speeds that up, the next one continues), new
#bests get a badge, the payout is coins x the star multiplier (Root.computePayout) and a stamp says how it ended.
#The payout and records are saved when the ticket opens, so quitting here can't lose the run.

var isGameSummary: bool = true #false: the selected driver's records, opened from the main menu
var levelCompleted: bool = false #did the player successfully complete their run.
var reason #why did I win or lose.  this is an enum, Root.endCondition

const INPUT_DELAY_MSEC = 500 #presses are ignored this long after the summary opens
const PRESS_ACTIONS = ["ui_accept", "ui_select", "ui_cancel", "Accelerate", "Brake"] #polled too, in case events don't reach this node
const INK := Color(0.165, 0.102, 0.063)
const FADED_INK := Color(0.42, 0.33, 0.25)
const PAPER := Color(0.953, 0.906, 0.812)
const STAMPS := {
	Root.endCondition.SUCCESS: ["CLEARED", Color(0.17, 0.55, 0.26)],
	Root.endCondition.ABANDONED: ["ABANDONED", Color(0.55, 0.38, 0.16)],
	Root.endCondition.NOGAS: ["OUT OF GAS", Color(0.78, 0.14, 0.11)],
	Root.endCondition.NOTIME: ["TIME'S UP", Color(0.78, 0.14, 0.11)],
	Root.endCondition.NOHEALTH: ["WRECKED", Color(0.78, 0.14, 0.11)],
	Root.endCondition.BASEDESTROYED: ["OVERRUN", Color(0.78, 0.14, 0.11)],
}

var summaryTimer: float = -2.0
var summaryComplete: bool = false
var summaryTimerLength: float = 0.5
var openedAtMsec := Time.get_ticks_msec()
var continued := false
var freshPress := false
var reveal: Array[Control] = [] #hidden until advanceSummary shows them, in order
var rows := VBoxContainer.new()
var continueButton: Button
var stamp: Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputGlyphs.ensureMenuActions()
	if not isGameSummary: add_to_group("menuOverlay")
	if isGameSummary: buildGameSummary()
	else: buildAchievementSummary()
	intro()

func _process(delta):
	if isGameSummary && not summaryComplete:
		summaryTimer += delta
		if summaryTimer > summaryTimerLength:
			if advanceSummary():
				summaryTimer = 0.0
				$AudioStreamPlayer2_lowImpact.play()
			else: summaryComplete = true
	for action in PRESS_ACTIONS:
		if InputMap.has_action(action) && Input.is_action_just_pressed(action): freshPress = true
	if freshPress:
		freshPress = false
		if Time.get_ticks_msec() - openedAtMsec >= INPUT_DELAY_MSEC: onFreshPress()

func _input(event):
	if isFreshPress(event): freshPress = true

#only a fresh press counts (not a key still held from driving, not key repeat), and only after
#INPUT_DELAY_MSEC: the first one speeds the reveal up, one after the reveal continues
func onFreshPress():
	if isGameSummary && not summaryComplete:
		if summaryTimerLength != 0.1:
			summaryTimerLength = 0.1
			summaryTimer = 1.0
	else: _on_continue_pressed()

static func isFreshPress(event: InputEvent) -> bool:
	if event is InputEventKey: return event.is_pressed() && not event.is_echo()
	if event is InputEventMouseButton: return event.is_pressed() && (event as InputEventMouseButton).button_index <= MOUSE_BUTTON_MIDDLE #not the wheel
	return event is InputEventJoypadButton && event.is_pressed()

#shows the next hidden part of the ticket; false when everything is showing
func advanceSummary():
	while not reveal.is_empty():
		var next = reveal.pop_front()
		if not is_instance_valid(next): continue
		next.visible = true
		if next == stamp: slam(stamp)
		elif next != continueButton: arrive(next)
		if next == continueButton: continueButton.grab_focus()
		return true
	return false

#---------- results ----------

func reasonLine() -> String:
	var reasonDict = {
		Root.endCondition.SUCCESS:["Level Complete"],
		Root.endCondition.ABANDONED:[
			"Run Abandoned. Goons Unimpressed.",
			"Bailed Out. The Goons Saw Everything.",
			"Abandoned. Coins Kept, Pride Lost.",
		],
		Root.endCondition.NOGAS:[
			"Empty tank. Full stop. Gooned.",
			"Gasless? Game over, pal.",
			"Out of fuel? Out of luck.",
			"No gas. Big crash. You're done.",
			"Fuel's gone. So's your chance.",
			"Empty tank equals gooned fate.",
			"Ran dry. Goons win. Good Bye!",
			"No juice? No win. Restart?",
			"Fuel fail. Goons cheer. Oops.",
			"Dry tank. End game. Gooned."
		],
		Root.endCondition.NOTIME:[
			"Too slow? Gooned. Time's up.",
			"Time's out! Speed or get gooned.",
			"Too Slow. Goons feasted. Finished.",
			"Lingered long? Goons gobbled. You're Gone.",
			"Slow and steady got you gooned.",
			"Ran out of time, got gooned.",
			"Time expired, you are officially gooned.",
			"Delay meant defeat, thoroughly gooned."
		],
		Root.endCondition.NOHEALTH:[
			"You Got Gooned.",
			"You Got Gooned Again.",
			"Crashed. Smashed. Gooned. Game Over.",
			"Wrecked Ride, Better Luck Next Time!",
			"Gooned Again? Drive Smarter!",
			"Hit, Run, Crash, Burn, Goodbye.",
			"Smash Fail. Goons Laugh. The End.",
			"Ride Wrecked. Dreams Dashed.",
			"Crash Course In Defeat!",
			"Gooned! Car Kaput. Retry?"
		],
		Root.endCondition.BASEDESTROYED:[
			"The Walls Fell. The Goons Moved In.",
			"Station Overrun. Goons Pumping Gas.",
			"Barrier Down. Goons Everywhere.",
			"They Got Through. Hold It Longer Next Time.",
		],
	}
	var lines: Array = reasonDict.get(reason, ["Run Over"])
	return lines[randi() % lines.size()]

func buildGameSummary():
	Root.playerRoot.visible = false
	var level = Root.levelRoot
	var progressNote := ""
	var levelIndex: int = level.runLevel #the save's selection may move on to the next level or mode below
	var gameMode: int = level.runMode
	#a Goonpocalypse run that survived its target beat the mode, even when it was abandoned afterwards
	var won: bool = levelCompleted && (reason != Root.endCondition.ABANDONED || level.targetReached)
	var firstClear := {"coin": 0, "gem": 0}
	if won:
		var nextWasOpen: bool = levelIndex + 1 >= SaveManager.playerData.levels.size() || SaveManager.playerData.levels[levelIndex + 1].unlocked
		var before := SaveManager.currentLevelPassed()
		firstClear = ModeTiers.firstClear(before, level.tier, levelIndex)
		level.firstClear = firstClear
		progressNote = nextLevelNote(levelIndex, nextWasOpen)
	else:
		$AudioStreamPlayer_highImpact.play()
	var car = Root.playerCar
	var records = SaveManager.getCarByName(car.carId).records
	var mode = Root.gameModeDescription[gameMode].name
	var body = buildTicket("%s %s  -  %s  -  %s" % [ModeTiers.NAMES[level.tier].to_upper(), mode, SaveManager.playerData.levels[levelIndex].name.to_upper(), car.charName.to_upper()], reasonLine())

	#records: compare before updating, so a beaten record gets its badge
	var crushed = car.currentGoonsCrushed
	var topSpeed = int(car._highest_measured_speed / 10)
	var lottery = PickupEffects.payLottery(car, topSpeed) #before the payout, so stars multiply it
	var bonus: int = level.winBonus() if won else 0
	var paid: int = level.runPayout(won)
	var powerups = car.powerupsCollected
	var timer = get_tree().get_first_node_in_group("runTimer")
	var newBest = {"time": false, "score": false}
	if gameMode == Root.gameModes.GOONPOCALYPSE:
		newBest = SaveManager.recordGoonpocalypse(levelIndex, car.carId, int(level.elapsed), level.runScore())
	addRow("Time", timer.text if is_instance_valid(timer) else "-", newBest.time)
	match gameMode: #one row for the mode's own goal
		Root.gameModes.GOONPOCALYPSE: addRow("Score", str(level.runScore()), newBest.score)
		Root.gameModes.MARATHON: addRow("Stations", "%d / %d" % [level.leg - (0 if reason == Root.endCondition.SUCCESS else 1), level.legs()], false)
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station): addRow("Barrier", "%d%%" % ceili(100.0 * Root.station.barrier / Root.station.BARRIER_MAX), false)
	addRow("Top speed", Settings.speed_text(car._highest_measured_speed), topSpeed > records.speed)
	addRow("Goons crushed", str(crushed), crushed > records.goonsCrushed)
	addRow("Coins", str(car.coin), false)
	addRow("Powerups", str(powerups), powerups > records.powerups)
	addRow("Gems", str(car.gem), car.gem > records.gem)
	addRow("Slot machines", str(car.slotMachines), car.slotMachines > records.slotMachines)
	if not car.lotteryTickets.is_empty():
		addRow("Lottery", "+%d  (%d matched)" % lottery, false)
		if lottery[1] > 0: rows.get_child(rows.get_child_count() - 1).set_meta("stamp", "MATCH!")
	if car.bestCombo >= 3: addRow("Best combo", str(car.bestCombo), car.bestCombo > records.get("combo", 0))
	if bonus > 0: addRow("Win bonus  (%s)" % ModeTiers.NAMES[level.tier], "+%s" % DriverCard.formatCoins(bonus), false)
	addPayout(body, car.coin + bonus, car.star, paid, paid > records.coin)
	if firstClear.coin > 0 || firstClear.gem > 0:
		addRow("First clear  (%s medal)" % ModeTiers.MEDALS[level.tier], "+%s%s" % [DriverCard.formatCoins(firstClear.coin), "  +%d gem%s" % [firstClear.gem, "" if firstClear.gem == 1 else "s"] if firstClear.gem > 0 else ""], true, ModeTiers.MEDALS[level.tier].to_upper())
	records.goonsCrushed = maxi(records.goonsCrushed, crushed)
	records.speed = maxi(records.speed, topSpeed)
	records.coin = maxi(records.coin, paid)
	records.powerups = maxi(records.powerups, powerups)
	records.gem = maxi(records.gem, car.gem)
	records.slotMachines = maxi(records.slotMachines, car.slotMachines)
	records.combo = maxi(records.get("combo", 0), car.bestCombo)
	var discovered = Goonopedia.creditCrushes(car.crushedById)
	Unlocks.countRun(won, gameMode, level.nightsSeen, car.giantsCrushed, Root.playerRoot.boxLevel if is_instance_valid(Root.playerRoot) else 0)
	if OS.is_debug_build(): RunLog.append(car, level, reason, paid)

	var blueprinted = PickupEffects.creditBlueprints(car) #free garage upgrades, however the run ended

	#pay now and save, so quitting from the summary can't lose the run; the menu only animates it
	SaveManager.addCoins(paid + firstClear.coin)
	SaveManager.addGems(car.gem + firstClear.gem)
	var unlocked := Unlocks.refresh() #after the crushes and records are in, so their conditions count
	if not unlocked.is_empty(): #the count on the row, the names wrapped under it: a long list once ran the ticket off the screen
		addRow("Unlocked", str(unlocked.size()), true, "NEW PICKUP")
		addWrapped(listed(unlocked.map(Pickups.displayName), 8))
	Root.earnedCoins = paid + firstClear.coin
	Root.earnedGems = car.gem + firstClear.gem
	SaveManager.save_character_data()
	SaveManager.flush()
	var stampInfo = STAMPS.get(reason, ["GAME OVER", Color(0.78, 0.14, 0.11)])
	if level.targetReached: stampInfo = ["SURVIVED", Color(0.17, 0.55, 0.26)]
	stamp = makeStamp(stampInfo[0], stampInfo[1])
	if rows.get_child_count() > 7: stamp.position.y += 40 * (rows.get_child_count() - 7) #stays under the payout
	reveal.push_back(stamp)
	addContinue("CONTINUE", "Any button speeds up the count")
	var notes = []
	if progressNote != "": notes.push_back(progressNote)
	if not discovered.is_empty(): notes.push_back("New in the Goonopedia: " + listed(discovered, 4))
	if not blueprinted.is_empty(): notes.push_back("Blueprint: a free upgrade to " + listed(blueprinted, 4))
	var next := Unlocks.nextUnlock()
	if unlocked.is_empty() && not next.is_empty() && Unlocks.canAfford(next.uid): notes.push_back("Ready to buy in the Goonopedia: " + next.name)
	var advice = Settings.take_advisor_message()
	if advice != "": notes.push_back(advice)
	if not notes.is_empty(): addFooterNote("   -   ".join(notes))

#after a win: the next level just opened, or what is left here to open it (LevelDef.unlockModes, and in
#later acts some on Medium: Root.mediumToOpenNext)
static func nextLevelNote(index: int, wasOpen: bool) -> String:
	var levels: Array = SaveManager.playerData.levels
	if wasOpen || index + 1 >= levels.size(): return ""
	var nextName: String = str(levels[index + 1].get("name", "the next level"))
	var left: String = SaveManager.openLeft(index)
	if left == "": return "%s is open" % nextName
	return "%s to open %s" % [left, nextName]

#---------- records ----------

func buildAchievementSummary():
	var info: CarInfo = Root.carInfo
	var records = SaveManager.getCarByName(info.carId).records
	buildTicket("RECORDS  -  %s  -  %s" % [info.charName.to_upper(), info.carId.to_upper()], "Best of every run with this driver")
	addRow("Best payout", DriverCard.formatCoins(records.coin), false)
	addRow("Top speed", Settings.speed_text(records.speed * 10.0), false)
	addRow("Goons crushed", str(records.goonsCrushed), false)
	addRow("Powerups", str(records.powerups), false)
	addRow("Gems", str(records.gem), false)
	addRow("Slot machines", str(records.slotMachines), false)
	if records.get("combo", 0) >= 3: addRow("Best combo", str(records.combo), false)
	if records.get("time", 0) > 0: addRow("Longest Goonpocalypse", "%d:%02d" % [records.time / 60, records.time % 60], false)
	if records.get("score", 0) > 0: addRow("Goonpocalypse score", str(records.score), false)
	var life: Dictionary = SaveManager.playerData.meta.get("lifetime", {})
	if int(life.get("boxes", 0)) > 0: addRow("Gift boxes (every driver)", "%d  (best run %d)" % [int(life.boxes), int(life.get("bestBox", 0))], false)
	var medals := ModeTiers.clears(SaveManager.playerData.levels, ModeTiers.EASY)
	if medals > 0: addRow("Medals (every driver)", "%d  /  %d gold" % [medals, ModeTiers.clears(SaveManager.playerData.levels, ModeTiers.HARD)], false)
	addContinue("CLOSE", "")
	for part in reveal: part.visible = true
	reveal.clear()
	summaryComplete = true
	continueButton.grab_focus()

#---------- the ticket ----------

#the dimmed screen, the paper and its header; returns the column the rows go in
func buildTicket(subtitle: String, line: String) -> VBoxContainer:
	var root = Control.new()
	root.name = "ticketRoot"
	root.theme = MenuTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var paper = TicketPaper.new()
	paper.name = "ticket"
	paper.position = Vector2(540, 34)
	paper.size = Vector2(520, 730)
	root.add_child(paper)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	paper.add_child(margin)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	margin.add_child(body)
	body.add_child(ink("GOONCRUSHER", 34, INK, HudTheme.BOLD, true))
	body.add_child(ink(subtitle, 15, FADED_INK, HudTheme.BODY, true))
	body.add_child(ink(line, 19, Color(0.6, 0.13, 0.09), HudTheme.BOLD, true))
	body.add_child(Dashes.new())
	rows.add_theme_constant_override("separation", 2)
	body.add_child(rows)
	return body

func ink(text: String, size: int, color: Color, font: Font, centered := false) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	if centered: #header lines wrap across the ticket; row labels and values never wrap
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

#"a, b, c and 5 more": keeps a list short enough for one line or two
static func listed(names: Array, most: int) -> String:
	if names.size() <= most: return ", ".join(names)
	return "%s and %d more" % [", ".join(names.slice(0, most)), names.size() - most]

#a centred line under the row before it that wraps inside the ticket (at most 3 lines), revealed in turn
func addWrapped(text: String) -> void:
	var label = ink(text, 16, FADED_INK, HudTheme.BODY, true)
	label.max_lines_visible = 3
	label.visible = false
	rows.add_child(label)
	reveal.push_back(label)

#"TOP SPEED ........ 61 MPH", with a NEW BEST badge when a record fell
func addRow(name: String, value: String, isBest: bool, badgeText := "NEW BEST") -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 38
	row.add_child(ink(name.to_upper(), 20, INK, HudTheme.BODY))
	if isBest:
		var badge = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.GAIN, Color(0, 0, 0, 0), 6, 0, Vector4(7, 0, 7, 0)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(ink(badgeText, 13, INK, HudTheme.BOLD))
		badge.name = "badge"
		row.add_child(badge)
	var dots = Dots.new()
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dots)
	row.add_child(ink(value, 22, INK, HudTheme.BOLD))
	row.visible = false
	rows.add_child(row)
	reveal.push_back(row)

func addPayout(body: VBoxContainer, coin: int, star: int, paid: int, isBest: bool) -> void:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.add_child(Dashes.new())
	var sum = HBoxContainer.new()
	sum.add_child(ink("COINS x STARS (%d)" % maxi(0, star), 20, INK, HudTheme.BODY))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum.add_child(gap)
	sum.add_child(ink("%s x %s" % [DriverCard.formatCoins(coin), Root.multiplierText(star)], 22, INK, HudTheme.BOLD))
	block.add_child(sum)
	var total = HBoxContainer.new()
	total.add_child(ink("PAID", 26, INK, HudTheme.BOLD))
	if isBest:
		var badge = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.GAIN, Color(0, 0, 0, 0), 6, 0, Vector4(7, 0, 7, 0)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(ink("NEW BEST", 13, INK, HudTheme.BOLD))
		badge.name = "badge"
		total.add_child(badge)
	var gap2 = Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(gap2)
	total.add_child(ink(DriverCard.formatCoins(paid), 58, Color(0.72, 0.34, 0.06), HudTheme.BOLD))
	block.add_child(total)
	block.visible = false
	body.add_child(block)
	reveal.push_back(block)

func makeStamp(text: String, color: Color) -> Control:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0), color, 12, 6, Vector4(20, 2, 20, 2)))
	holder.add_child(ink(text, 60, color, HudTheme.BOLD))
	holder.modulate.a = 0.86
	holder.position = Vector2(640, 600) #in the space under the payout
	holder.rotation = deg_to_rad(-13)
	holder.visible = false
	get_node("ticketRoot").add_child(holder)
	return holder

#the stamp lands like the shared Stamp (Stamp.gd): 140% to 100% in 110 ms, a clank and a 4 px rumble
func slam(target: Control) -> void:
	$AudioStreamPlayer_highImpact.play()
	target.pivot_offset = target.size * 0.5
	if Settings.reduce_motion():
		target.modulate.a = 0.0
		target.create_tween().tween_property(target, "modulate:a", 0.86, Transition.FADE_SECONDS)
		return
	target.scale = Vector2(1.4, 1.4)
	var t = target.create_tween()
	t.tween_property(target, "scale", Vector2.ONE, Stamp.SLAM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		Transition.sound("clank", -4.0)
		Juice.rumble(get_node("ticketRoot"), "position", 4.0, 0.14))

#a row printing onto the ticket: it fades in sliding 6 px from the left, and a NEW BEST badge pops
func arrive(row: Control) -> void:
	row.modulate.a = 0.0
	var fade = row.create_tween()
	fade.tween_property(row, "modulate:a", 1.0, 0.18)
	var badge = row.find_child("badge", true, false)
	if Settings.reduce_motion(): return
	await get_tree().process_frame #the container has placed it by now
	if not is_instance_valid(row): return
	var home = row.position.x
	row.position.x = home - 6.0
	row.create_tween().tween_property(row, "position:x", home, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if badge: Juice.pop(badge, 1.2, 0.25)
	if row.has_meta("stamp"): #a lottery match
		var at = row.get_global_rect()
		Stamp.slam(get_node("ticketRoot"), row.get_meta("stamp"), Vector2(at.end.x + 70.0, at.get_center().y), Color(0.17, 0.55, 0.26), 30, -1.0, -0.15)

func addContinue(text: String, note: String) -> void:
	var root = get_node("ticketRoot")
	continueButton = MenuTheme.button(text, PackedStringArray(["ui_accept"]), true)
	continueButton.position = Vector2(640, 786)
	continueButton.size = Vector2(320, 66)
	continueButton.pressed.connect(_on_continue_pressed)
	continueButton.visible = false
	root.add_child(continueButton)
	reveal.push_back(continueButton)
	if note != "": addFooterNote(note)

func addFooterNote(text: String) -> void:
	var label = Label.new()
	label.theme_type_variation = "HintLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART #wraps under the button instead of running off the screen
	label.max_lines_visible = 2
	label.position = Vector2(300, 856)
	label.size = Vector2(1000, 30)
	get_node("ticketRoot").add_child(label)

func _on_continue_pressed():
	if continued: return
	continued = true
	await outro()
	queue_free()
	if isGameSummary:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")

#---------- in and out (Transition, docs/UI.md) ----------
#Results: a wreck ends in tire smoke and the ticket skids in from the left; every other ending
#slams the garage shutter over the run and the ticket feeds up out of its rail. Leaving pulls the
#ticket back in and carries the door (or slams one) across to the menu, which rolls it up.
#Records (from the menu) just drop in and lift out.

var door: ShutterDoor
var fx: TransitionFx

func paper() -> Control:
	return get_node("ticketRoot/ticket")

func intro() -> void:
	if Transition.instant(): return
	var root: Control = get_node("ticketRoot")
	var sheet = paper()
	var home = sheet.position
	var dim: ColorRect = root.get_child(0)
	if Settings.reduce_motion():
		root.modulate.a = 0.0
		create_tween().tween_property(root, "modulate:a", 1.0, Transition.FADE_SECONDS)
		return
	if not isGameSummary: #records: a short drop with a bounce
		sheet.position.y = home.y - 120
		sheet.modulate.a = 0.0
		var t = create_tween().set_parallel()
		t.tween_property(sheet, "position:y", home.y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sheet, "modulate:a", 1.0, 0.12)
		Transition.sound("clank", -10.0)
		return
	var screen = get_viewport().get_visible_rect().size
	fx = TransitionFx.new()
	fx.autoFree = false
	root.add_child(fx)
	root.move_child(fx, 1)
	if reason == Root.endCondition.NOHEALTH:
		#a spin-out: a wall of tire smoke, then the ticket skids in and brakes
		Transition.sound("screech", -2.0)
		dim.color.a = 0.0
		create_tween().tween_property(dim, "color:a", 0.62, 0.5)
		fx.smokeWall(screen, 0.3)
		sheet.position = Vector2(-sheet.size.x - 40, home.y)
		sheet.pivot_offset = sheet.size / 2.0
		sheet.rotation = -0.25
		var t = create_tween()
		t.tween_interval(0.3)
		t.tween_property(sheet, "position:x", home.x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(sheet, "rotation", -0.02, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(func():
			Transition.sound("skid", -4.0)
			Juice.rumble(root, "position", 2.0, 0.12)
			for y in [home.y + 60, home.y + sheet.size.y - 60]: fx.mark(Vector2(0, y), Vector2(home.x + 20, y), 9.0, 0.6, 1.3))
		return
	#the shutter slams over the run, then the ticket prints up out of its rail
	door = ShutterDoor.new()
	door.size = screen
	door.labelSize = 150
	door.label = "GOONCRUSHER"
	door.sub = "RUN OVER"
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(door)
	root.move_child(door, 1)
	door.position.y = -screen.y - 12
	sheet.position.y = screen.y + 20
	Transition.sound("whoosh", -6.0)
	var t = create_tween()
	t.tween_property(door, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		Transition.sound("thud")
		Transition.sound("clank", -4.0)
		Juice.rumble(root, "position", Transition.SHAKE, 0.22)
		fx.dustLine(0, screen.x, screen.y - 4, 32, 14))
	t.tween_property(door, "position:y", -12.0, 0.045)
	t.tween_property(door, "position:y", 0.0, 0.045)
	t.tween_interval(0.15)
	for step in 6: #a receipt printer: six short pushes
		t.tween_property(sheet, "position:y", lerpf(screen.y + 20, home.y, (step + 1) / 6.0), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.02)

func outro() -> void:
	if Transition.instant():
		if isGameSummary: Transition.carry()
		return
	var sheet = paper()
	if not isGameSummary:
		var t = create_tween().set_parallel()
		t.tween_property(sheet, "position:y", sheet.position.y - 80, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(get_node("ticketRoot"), "modulate:a", 0.0, 0.14)
		await t.finished
		return
	if is_instance_valid(door) && not Settings.reduce_motion():
		var screen = get_viewport().get_visible_rect().size
		var t = create_tween()
		for step in 4: t.tween_property(sheet, "position:y", lerpf(sheet.position.y, screen.y + 20, (step + 1) / 4.0), 0.07)
		await t.finished
		Transition.carry("GOONCRUSHER", "RUN OVER")
		return
	var shutter = Transition.close("GOONCRUSHER", "RUN OVER")
	if not shutter.isShut: await shutter.shut

#cream paper with a zigzag torn edge top and bottom, and a soft shadow
class TicketPaper extends Control:
	const TOOTH := 12.0
	func _draw() -> void:
		var points = PackedVector2Array()
		var w = size.x
		var h = size.y
		var teeth = int(w / (TOOTH * 2.0))
		var step = w / teeth
		for i in teeth + 1: points.append_array([Vector2(i * step, 0), Vector2(minf(i * step + step * 0.5, w), TOOTH)])
		for i in range(teeth, -1, -1): points.append_array([Vector2(i * step, h), Vector2(maxf(i * step - step * 0.5, 0), h - TOOTH)])
		var shadow = PackedVector2Array()
		for p in points: shadow.push_back(p + Vector2(8, 12))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		draw_colored_polygon(points, Color(0.953, 0.906, 0.812))

#a dashed rule across the ticket
class Dashes extends Control:
	func _init() -> void:
		custom_minimum_size.y = 16
	func _draw() -> void:
		var x = 0.0
		while x < size.x:
			draw_line(Vector2(x, size.y * 0.5), Vector2(minf(x + 8, size.x), size.y * 0.5), Color(0.42, 0.33, 0.25), 2.0)
			x += 14.0

#the dotted leader between a row's name and value
class Dots extends Control:
	func _draw() -> void:
		var x = 4.0
		while x < size.x - 4:
			draw_circle(Vector2(x, size.y * 0.66), 1.4, Color(0.72, 0.65, 0.56))
			x += 7.0
