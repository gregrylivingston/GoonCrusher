extends CanvasLayer

#The end of a run (docs/UI.md, "Results"), and the same ticket for a driver's records.
#Results: the run freezes where it ended and the camera pulls back, the stamp says how it ended, then the ticket
#prints in on the right while the world stays in view on the left. Its rows reveal one at a time (Accept or a
#click shows the rest at once), new bests get a badge, the payout is coins x the star multiplier
#(Root.computePayout), and the run's score rolls up a 25-step ladder to its rank (RunRank). The buttons go on
#from here: Retry, Next, Level Options or the garage.
#The payout and records are saved when the ticket opens, so quitting here can't lose the run.

var isGameSummary: bool = true #false: the selected driver's records, opened from the main menu
var levelCompleted: bool = false #did the player successfully complete their run.
var reason #why did I win or lose.  this is an enum, Root.endCondition
var autoAction := "" #Level.endLevel's `then`: pay the run and go straight on, with no ticket (the pause menu's Restart)

const MENU_SCENE := "res://scene/player/menu/main/main2.tscn"
const INPUT_DELAY_MSEC = 500 #presses are ignored this long after the summary opens
const PRESS_ACTIONS = ["ui_accept", "ui_select", "ui_cancel"] #polled too, in case events don't reach this node
const INK := Color(0.165, 0.102, 0.063)
const FADED_INK := Color(0.42, 0.33, 0.25)
const WIN_INK := Color(0.12, 0.42, 0.19)
const LOSS_INK := Color(0.6, 0.13, 0.09)
const STAMP_GOOD := Color(0.17, 0.55, 0.26)
const STAMP_BAD := Color(0.78, 0.14, 0.11)
const STAMPS := {
	Root.endCondition.SUCCESS: ["CLEARED", STAMP_GOOD],
	Root.endCondition.ABANDONED: ["ABANDONED", Color(0.55, 0.38, 0.16)],
	Root.endCondition.NOGAS: ["OUT OF GAS", STAMP_BAD],
	Root.endCondition.NOTIME: ["TIME'S UP", STAMP_BAD],
	Root.endCondition.NOHEALTH: ["WRECKED", STAMP_BAD],
	Root.endCondition.BASEDESTROYED: ["OVERRUN", STAMP_BAD],
	Root.endCondition.OUTRUN: ["OUTRUN", STAMP_BAD],
}
#the layout, on the 1600 x 900 canvas: the results ticket on the right, the world on the left
const TICKET_AT := Vector2(1010, 24)
const TICKET_WIDTH := 540.0
const TICKET_MAX_HEIGHT := 852.0 #a longer ticket is scaled down to fit
const RECORDS_AT := Vector2(540, 34)
const RECORDS_SIZE := Vector2(520, 730)
const STAMP_AT := Vector2(80, 64)
const RANK_AT := Vector2(70, 486)
const ACTIONS_AT := Vector2(70, 766)
const FOOTER_AT := Vector2(70, 840)
const PULL_BACK := 0.72 #the camera's zoom as the run ends, as a share of where it was: more of the map round the car
const PULL_SECONDS := 0.9
const STEP_SECONDS := 0.16 #between one row printing and the next
#the buttons: what each says, and its own key when it isn't the primary one (which takes Accept)
const ACTION_TEXT := {"retry": "RETRY", "next": "NEXT", "options": "LEVEL OPTIONS", "garage": "GARAGE"}
const ACTION_KEYS := {"retry": "ui_records", "options": "ui_cancel", "garage": "ui_upgrade"}

var summaryTimer: float = 0.0
var summaryComplete: bool = false
var revealHeld := false #the ticket is still on its way in: nothing prints yet
var openedAtMsec := Time.get_ticks_msec()
var continued := false
var freshPress := false
var reveal: Array[Control] = [] #unseen until advanceSummary shows them, in order
var rows := VBoxContainer.new() #the mode's own result (results), or every row (records)
var stats := GridContainer.new() #the run's numbers, two to a line
var bonuses := VBoxContainer.new() #what the run earned on top of its payout
var news := HFlowContainer.new() #what the run opened, as chips
var continueButton: Button #the primary button (the harnesses and tests press it)
var buttons := {} #action -> Button
var primary := ""
var actionBar: HBoxContainer
var footer: VBoxContainer #under the buttons, shown with them
var stamp: Control
var dim: Control
#the run this ticket is for: Retry plays it again, Level Options goes back to it
var runLevel := 0
var runMode := 0
var runTier: int = ModeTiers.EASY
var nextUp := {} #the run the Next button starts (nextRun); {} when there is none

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputGlyphs.ensureMenuActions()
	if not isGameSummary: add_to_group("menuOverlay")
	if isGameSummary: buildGameSummary()
	else: buildAchievementSummary()
	if autoAction != "":
		hideHud()
		get_node("ticketRoot").visible = false
		act.call_deferred(autoAction)
		return
	intro()

func _process(delta):
	if isGameSummary && not summaryComplete && not revealHeld:
		summaryTimer += delta
		if summaryTimer > STEP_SECONDS:
			summaryTimer = 0.0
			if advanceSummary(): $AudioStreamPlayer2_lowImpact.play()
			else: summaryComplete = true
	var late: bool = Time.get_ticks_msec() - openedAtMsec >= INPUT_DELAY_MSEC
	for action in PRESS_ACTIONS:
		if InputMap.has_action(action) && Input.is_action_just_pressed(action): freshPress = true
	var pressed := freshPress && late
	freshPress = false
	if continued: return
	if not isGameSummary:
		if pressed: closeRecords()
		return
	if not summaryComplete:
		if pressed: finishReveal()
		return
	if not late: return
	#the buttons take Accept and clicks themselves; polled as well, in case events don't reach this node
	if Input.is_action_just_pressed("ui_accept"):
		var focused = buttons.find_key(get_viewport().gui_get_focus_owner())
		act(focused if focused != null else primary)
		return
	for kind in buttons:
		var key: String = ACTION_KEYS.get(kind, "")
		if key != "" && InputMap.has_action(key) && Input.is_action_just_pressed(key):
			act(kind)
			return

#Records: any fresh press closes them. Results: while the ticket is still printing, Accept, Back or a click
#shows the rest of it, and is taken here so it can't also press the button that gets the focus. Driving keys
#do nothing, so a foot still on the gas can't pick an action.
func _input(event):
	if not isFreshPress(event): return
	if not isGameSummary:
		freshPress = true
		return
	if summaryComplete || continued: return
	var counts: bool = event is InputEventMouseButton
	for action in PRESS_ACTIONS:
		if InputMap.has_action(action) && event.is_action(action): counts = true
	if not counts: return
	freshPress = true
	get_viewport().set_input_as_handled()

#only a fresh press counts (not a key still held from driving, not key repeat)
static func isFreshPress(event: InputEvent) -> bool:
	if event is InputEventKey: return event.is_pressed() && not event.is_echo()
	if event is InputEventMouseButton: return event.is_pressed() && (event as InputEventMouseButton).button_index <= MOUSE_BUTTON_MIDDLE #not the wheel
	return event is InputEventJoypadButton && event.is_pressed()

#shows the next unseen part of the ticket; false when everything is showing
func advanceSummary() -> bool:
	while not reveal.is_empty():
		var next = reveal.pop_front()
		if not is_instance_valid(next): continue
		showPart(next, true)
		return true
	return false

#one part of the ticket coming into view: printed in (animated) or simply there
func showPart(part: Control, animated: bool) -> void:
	if part == actionBar:
		actionBar.visible = true
		footer.visible = true
		continueButton.grab_focus()
		return
	if part == rankBox:
		rankBox.modulate.a = 1.0
		if animated && not Transition.instant() && not Settings.reduce_motion(): rollRank()
		else: landRank(false)
		return
	if part == payoutBlock: countBank(animated)
	if animated: arrive(part)
	else: part.modulate.a = 1.0

#everything still to come, at once: the ticket in place, every row, the rank, the buttons
func finishReveal() -> void:
	settleIntro()
	while not reveal.is_empty():
		var next = reveal.pop_front()
		if is_instance_valid(next): showPart(next, false)
	landRank(false)
	summaryComplete = true

#a part of the ticket that prints in later: it keeps its place in the layout, unseen
func conceal(part: Control) -> void:
	part.modulate.a = 0.0
	reveal.push_back(part)

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
		Root.endCondition.OUTRUN:[
			"Outrun. All You Saw Was Tail Lights.",
			"Beaten To The Line. Gooned.",
			"Too Slow. Someone Else Took It.",
		],
	}
	var lines: Array = reasonDict.get(reason, ["Run Over"])
	return lines[randi() % lines.size()]

func buildGameSummary():
	var level = Root.levelRoot
	var progressNote := ""
	var levelIndex: int = level.runLevel #the save's selection may move on to the next level or mode below
	var gameMode: int = level.runMode
	runLevel = levelIndex
	runMode = gameMode
	runTier = level.tier
	#a Goonpocalypse run that survived its target beat the mode, even when it was abandoned afterwards
	var won: bool = levelCompleted && (reason != Root.endCondition.ABANDONED || level.targetReached)
	var firstClear := {"coin": 0, "gem": 0}
	var car = Root.playerCar
	var carClear := {"tiers": [], "coin": 0, "gem": 0, "fullGarage": []}
	var roadOpened := ""
	var counts: bool = not level.freePlay #a Free Play run pays its coins and credits nothing else
	if won && counts:
		var nextWasOpen: bool = levelIndex + 1 >= SaveManager.playerData.levels.size() || SaveManager.playerData.levels[levelIndex + 1].unlocked
		var before := SaveManager.currentLevelPassed(levelIndex, gameMode, level.tier) #the run's own, not the menu's selection
		firstClear = ModeTiers.firstClear(before, level.tier, levelIndex)
		carClear = SaveManager.creditCarClear(levelIndex, gameMode, level.tier, str(car.carId))
		firstClear.coin += carClear.coin
		firstClear.gem += carClear.gem
		level.firstClear = firstClear
		progressNote = nextLevelNote(levelIndex, nextWasOpen)
		if not nextWasOpen && levelIndex + 1 < SaveManager.playerData.levels.size() && SaveManager.playerData.levels[levelIndex + 1].unlocked: roadOpened = roadText(levelIndex + 1)
		nextUp = nextRun(levelIndex, gameMode, level.tier)
	elif not won:
		$AudioStreamPlayer_highImpact.play()
	var records = SaveManager.getCarByName(car.carId).records
	var mode = Root.gameModeDescription[gameMode].name
	var body = buildTicket("%s%s %s  -  %s  -  %s" % ["FREE PLAY  -  " if level.freePlay else "", ModeTiers.NAMES[level.tier].to_upper(), mode, SaveManager.playerData.levels[levelIndex].name.to_upper(), car.charName.to_upper()],
		reasonLine(), WIN_INK if won else LOSS_INK, TICKET_AT, Vector2(TICKET_WIDTH, 0))

	#records: compare before updating, so a beaten record gets its badge
	var crushed = car.currentGoonsCrushed
	var topSpeed = int(car._highest_measured_speed / 10)
	var lottery = PickupEffects.payLottery(car, topSpeed) #before the payout, so stars multiply it
	var bonus: int = level.winBonus() if won else 0
	var paid: int = level.runPayout(won)
	var grade: Dictionary = level.runRank() #after the lottery, so it grades what the run really paid
	var powerups = car.powerupsCollected
	var timer = get_tree().get_first_node_in_group("runTimer")
	var newBest = {"time": false, "score": false}
	if gameMode == Root.gameModes.GOONPOCALYPSE && counts:
		newBest = SaveManager.recordGoonpocalypse(levelIndex, car.carId, int(level.elapsed), level.runScore())
	#the mode's own result first
	if level.course: #a fixed course: the stage time goes in the record book when the stage is won
		var stage := {"time": false}
		var lapped: bool = gameMode == Root.gameModes.HOTLAP #its record is the best lap, not the run
		if won && counts: stage = SaveManager.recordCourse(levelIndex, gameMode, car.carId, level.course.bestLap() if lapped else level.elapsed, level.course.lapTimes if level.course.laps > 1 else level.course.splits)
		addRow("Best lap" if lapped else "Stage time", Course.clock(level.course.bestLap() if lapped else level.elapsed), stage.time)
		if level.course.laps > 1: addRow("Laps", "%d / %d" % [level.course.lap, level.course.laps], false)
		if level.overshot: addRow("Too fast at the line", "+%d s" % int(ModeTiers.FLATOUT_PENALTY), false)
		if level.rivals && level.finishPlace > 0: addRow("Place", "%s of %d" % [Rivals.placeWord(level.finishPlace).capitalize(), level.rivals.field()], false)
		addRow(level.course.gateWord.capitalize() + "s", "%d / %d" % [level.course.next, level.course.total()], false)
		if gameMode == Root.gameModes.CONES: addRow("Cones hit", str(level.course.conesHit), false)
	elif level.trial: #a score Trial: the time to its target is the record
		var quick := {"time": false}
		if won && counts: quick = SaveManager.recordCourse(levelIndex, gameMode, car.carId, level.elapsed, [])
		addRow("Time", Course.clock(level.elapsed), quick.time)
		addRow("Drift score" if gameMode == Root.gameModes.DRIFT else "Smashed", "%d / %d" % [level.trial.score, level.trial.target], false)
	else: addRow("Time", timer.text if is_instance_valid(timer) else "-", newBest.time)
	match gameMode: #one row for the mode's own goal
		Root.gameModes.GOONPOCALYPSE: addRow("Score", str(level.runScore()), newBest.score)
		Root.gameModes.MARATHON: addRow("Stations", "%d / %d" % [level.leg - (0 if reason == Root.endCondition.SUCCESS else 1), level.legs()], false)
		Root.gameModes.DERBY: addRow("Wrecked", "%d / %d" % [level.wrecks, level.rivals.field() - 1] if level.rivals else "-", false)
		Root.gameModes.KEEPCUP:
			if level.cup: addRow("Cup held", "%d / %d s" % [int(level.cup.playerSeconds()), int(level.cup.need)], false)
		Root.gameModes.PURSUIT: addRow("Runner", "Wrecked" if won else "Got away", false)
		Root.gameModes.CANNONBALL:
			if level.rivals: addRow("Place", "%s of %d" % [Rivals.placeWord(level.finishPlace).capitalize(), level.rivals.field()] if level.finishPlace > 0 else "Not placed", false)
		Root.gameModes.BOUNTY:
			if level.bounty: addRow("Marks", "%d / %d" % [level.bounty.caught, level.bounty.total], false)
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station): addRow("Barrier", "%d%%" % ceili(100.0 * Root.station.barrier / Root.station.BARRIER_MAX), false)
	#then the run's numbers, two to a line: the ones that happened
	body.add_child(Dashes.new())
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 0)
	body.add_child(stats)
	addStat("Top speed", Settings.speed_text(car._highest_measured_speed), topSpeed > records.speed)
	addStat("Goons", str(crushed), crushed > records.goonsCrushed)
	if car.bestCombo >= 3: addStat("Combo", str(car.bestCombo), car.bestCombo > records.get("combo", 0))
	if powerups > 0: addStat("Powerups", str(powerups), powerups > records.powerups)
	if car.gem > 0: addStat("Gems", str(car.gem), car.gem > records.gem)
	if car.slotMachines > 0: addStat("Slots", str(car.slotMachines), car.slotMachines > records.slotMachines)
	if not car.lotteryTickets.is_empty():
		var lotteryRow := makeRow("Lottery", "+%d  (%d matched)" % lottery, false, "", 16, 18, 28)
		if lottery[1] > 0: lotteryRow.set_meta("stamp", "MATCH!")
		body.add_child(lotteryRow)
		conceal(lotteryRow)
	addPayout(body, car.coin, bonus, car.star, paid, paid > records.coin)
	bonuses.add_theme_constant_override("separation", 0)
	body.add_child(bonuses)
	var medalClear := {"coin": firstClear.coin - carClear.coin, "gem": firstClear.gem - carClear.gem}
	if medalClear.coin > 0 || medalClear.gem > 0:
		addBonus("First clear  (%s medal)" % ModeTiers.MEDALS[level.tier], ["+", medalClear], ModeTiers.MEDALS[level.tier].to_upper())
	if carClear.coin > 0: addBonus("New car clear  (%s)" % car.charName, ["+", {"coin": carClear.coin}], "NEW CAR")
	if not carClear.fullGarage.is_empty():
		addBonus("Full Garage  (%s)" % ", ".join(carClear.fullGarage.map(func(t): return ModeTiers.NAMES[t])), ["+", {"gem": carClear.gem}], "FULL GARAGE")
	records.goonsCrushed = maxi(records.goonsCrushed, crushed)
	records.speed = maxi(records.speed, topSpeed)
	records.coin = maxi(records.coin, paid)
	records.powerups = maxi(records.powerups, powerups)
	records.gem = maxi(records.gem, car.gem)
	records.slotMachines = maxi(records.slotMachines, car.slotMachines)
	records.combo = maxi(records.get("combo", 0), car.bestCombo)
	var ranked := {"best": false, "before": int(SaveManager.bestRank(levelIndex, gameMode).get("score", 0))}
	if counts: ranked = SaveManager.recordRank(levelIndex, gameMode, str(car.carId), level.tier, grade.score, grade.rank)
	var discovered = Goonopedia.creditCrushes(car.crushedById)
	if counts: Unlocks.countRun(won, gameMode, level.nightsSeen, car.giantsCrushed, Root.playerRoot.boxLevel if is_instance_valid(Root.playerRoot) else 0)
	if OS.is_debug_build(): RunLog.append(car, level, reason, paid)

	var blueprinted = PickupEffects.creditBlueprints(car) #free garage upgrades, however the run ended

	#pay now and save, so quitting from the summary can't lose the run; the ticket and the menu only animate it
	SaveManager.addCoins(paid + firstClear.coin)
	SaveManager.addGems(car.gem + firstClear.gem)
	bankTo = SaveManager.playerData.coin
	bankFrom = bankTo - paid - firstClear.coin
	setBank(bankFrom)
	var unlocked := Unlocks.refresh() #after the crushes and records are in, so their conditions count
	Root.earnedCoins = paid + firstClear.coin
	Root.earnedGems = car.gem + firstClear.gem
	SaveManager.save_character_data()
	SaveManager.flush()

	#what the run opened, as chips under the money
	news.add_theme_constant_override("h_separation", 6)
	news.add_theme_constant_override("v_separation", 5)
	if roadOpened != "": addChip("Road open: " + roadOpened)
	if not unlocked.is_empty(): addChip("New pickup: " + listed(unlocked.map(Pickups.displayName), 3))
	if not discovered.is_empty(): addChip("Goonopedia: " + listed(discovered, 3))
	if not blueprinted.is_empty(): addChip("Blueprint: " + listed(blueprinted, 3))
	var next := Unlocks.nextUnlock()
	if unlocked.is_empty() && not next.is_empty() && Unlocks.canAfford(next.uid): addChip("Ready to unlock: " + str(next.name), FADED_INK)
	if news.get_child_count() > 0:
		var gap = Control.new()
		gap.custom_minimum_size.y = 6
		body.add_child(gap)
		body.add_child(news)
		conceal(news)
	if progressNote != "": body.add_child(wrapped(progressNote))

	var stampInfo = STAMPS.get(reason, ["GAME OVER", STAMP_BAD])
	if level.targetReached: stampInfo = ["SURVIVED", STAMP_GOOD]
	stamp = makeStamp(stampInfo[0], stampInfo[1])
	buildRank(grade, ranked, counts)
	conceal(rankBox)
	var kinds := ["retry", "options", "garage"]
	if won: kinds = ["next", "retry", "options", "garage"] if not nextUp.is_empty() else ["options", "retry", "garage"]
	addActions(kinds)
	reveal.push_back(actionBar)
	addFooter(Settings.take_advisor_message())
	fitTicket()

#the road a won Marathon opened: the next level's name, and its region's when it starts a new one
static func roadText(index: int) -> String:
	var def := Levels.defAt(index)
	var name: String = def.displayName if def else str(SaveManager.playerData.levels[index].get("name", ""))
	if def && def.stop == 1: return "%s, %s" % [name, Territories.displayName(def.region)]
	return name

#after a win: the next level just opened, or what is left here to open it (the Marathon, on Medium at a
#region's finale: Root.openLeftText)
static func nextLevelNote(index: int, wasOpen: bool) -> String:
	var levels: Array = SaveManager.playerData.levels
	if wasOpen || index + 1 >= levels.size(): return ""
	var nextName: String = str(levels[index + 1].get("name", "the next level"))
	var left: String = SaveManager.openLeft(index)
	if left == "": return "%s is open" % nextName
	return "%s to open %s" % [left, nextName]

## The run the Next button starts after a win of `mode` at level `index`: the first mode on that level's path
## that isn't won yet and can be started, else the first such mode on the next level when it is open. On the
## run's tier where that is open there, else the highest that is. {} when there is nothing to go on to.
static func nextRun(index: int, mode: int, tier: int) -> Dictionary:
	var levels: Array = SaveManager.playerData.levels
	for at in [index, index + 1]:
		if at >= levels.size() || not levels[at].get("unlocked", false) || (Root.IS_DEMO && at >= Root.DEMO_LEVEL_COUNT): continue
		var level: Dictionary = levels[at]
		for m in Root.modePath(level):
			if (at == index && m == mode) || level.get("gamemodeBeat", {}).get(m, false) || not Root.isModePlayable(level, m): continue
			var t := ModeTiers.clampTier(tier)
			while t > ModeTiers.EASY && not ModeTiers.isOpen(level, m, t): t -= 1
			return {"level": at, "mode": m, "tier": t}
	return {}

#---------- records ----------

func buildAchievementSummary():
	var info: CarInfo = Root.carInfo
	var records = SaveManager.getCarByName(info.carId).records
	buildTicket("RECORDS  -  %s  -  %s" % [info.charName.to_upper(), info.carId.to_upper()], "Best of every run with this driver", LOSS_INK, RECORDS_AT, RECORDS_SIZE)
	addRow("Best payout", DriverCard.formatCoins(records.coin), false)
	addRow("Top speed", Settings.speed_text(records.speed * 10.0), false)
	addRow("Goons crushed", str(records.goonsCrushed), false)
	addRow("Powerups", str(records.powerups), false)
	addRow("Gems", str(records.gem), false)
	addRow("Slot machines", str(records.slotMachines), false)
	if records.get("combo", 0) >= 3: addRow("Best combo", str(records.combo), false)
	if int(records.get("rank", 0)) > 0: addRow("Best run rank", "%d  %s" % [int(records.rank), RunRank.title(int(records.rank))], false)
	if records.get("time", 0) > 0: addRow("Longest Goonpocalypse", "%d:%02d" % [records.time / 60, records.time % 60], false)
	if records.get("score", 0) > 0: addRow("Goonpocalypse score", str(records.score), false)
	var life: Dictionary = SaveManager.playerData.meta.get("lifetime", {})
	if int(life.get("boxes", 0)) > 0: addRow("Gift boxes (every driver)", "%d  (best run %d)" % [int(life.boxes), int(life.get("bestBox", 0))], false)
	var medals := ModeTiers.clears(SaveManager.playerData.levels, ModeTiers.EASY)
	if medals > 0: addRow("Medals (every driver)", "%d  /  %d gold" % [medals, ModeTiers.clears(SaveManager.playerData.levels, ModeTiers.HARD)], false)
	continueButton = MenuTheme.button("CLOSE", PackedStringArray(["ui_accept"]), true)
	continueButton.position = Vector2(640, 786)
	continueButton.size = Vector2(320, 66)
	continueButton.pressed.connect(closeRecords)
	get_node("ticketRoot").add_child(continueButton)
	for part in reveal: part.modulate.a = 1.0
	reveal.clear()
	summaryComplete = true
	continueButton.grab_focus()

func closeRecords() -> void:
	if continued: return
	continued = true
	await outro()
	queue_free()

#---------- the ticket ----------

#the dimmed screen, the paper and its header; returns the column the rows go in. The paper grows down from
#`at` to fit what it holds, starting at `size` (the records ticket keeps a full sheet).
func buildTicket(subtitle: String, line: String, lineColor: Color, at: Vector2, size: Vector2) -> VBoxContainer:
	var root = Control.new()
	root.name = "ticketRoot"
	root.theme = MenuTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	dim = makeDim()
	root.add_child(dim)
	var sheet = TicketPaper.new()
	sheet.name = "ticket"
	sheet.position = at
	sheet.custom_minimum_size = size
	sheet.size = size
	for side in ["left", "right"]: sheet.add_theme_constant_override("margin_" + side, 38)
	sheet.add_theme_constant_override("margin_top", 30)
	sheet.add_theme_constant_override("margin_bottom", 28)
	root.add_child(sheet)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	sheet.add_child(body)
	body.add_child(ink("GOONCRUSHER", 32, INK, HudTheme.BOLD, true))
	body.add_child(ink(subtitle, 14, FADED_INK, HudTheme.BODY, true))
	body.add_child(ink(line, 18, lineColor, HudTheme.BOLD, true))
	body.add_child(Dashes.new())
	rows.add_theme_constant_override("separation", 0)
	body.add_child(rows)
	return body

#Records: an even dim. Results: light over the world on the left, dark behind the ticket on the right.
func makeDim() -> Control:
	if not isGameSummary:
		var flat = ColorRect.new()
		flat.color = Color(0, 0, 0, 0.62)
		flat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return flat
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.66, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.7)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var shade = TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return shade

#a ticket too long for the screen (a win with every bonus) is scaled down from its top right corner
func fitTicket() -> void:
	await get_tree().process_frame #the containers have sized it by now
	if not is_inside_tree(): return
	var sheet = paper()
	if sheet.size.y <= TICKET_MAX_HEIGHT: return
	sheet.pivot_offset = Vector2(sheet.size.x, 0)
	sheet.scale = Vector2.ONE * (TICKET_MAX_HEIGHT / sheet.size.y)

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

#text over the world, outlined so it reads on any ground
func chalk(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", HudTheme.BOLD)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", HudTheme.OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(6, size / 6))
	return label

#"a, b, c and 5 more": keeps a list short enough for one line or two
static func listed(names: Array, most: int) -> String:
	if names.size() <= most: return ", ".join(names)
	return "%s and %d more" % [", ".join(names.slice(0, most)), names.size() - most]

#a centered line in faded ink that wraps inside the ticket (at most 3 lines)
func wrapped(text: String) -> Label:
	var label = ink(text, 15, FADED_INK, HudTheme.BODY, true)
	label.max_lines_visible = 3
	return label

#a small badge in the ticket's gold ("NEW BEST")
func badge(text: String, size := 13) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.GAIN, Color(0, 0, 0, 0), 6, 0, Vector4(7, 0, 7, 0)))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(ink(text, size, INK, HudTheme.BOLD))
	panel.name = "badge"
	return panel

#"TOP SPEED ........ 61 MPH", with a badge when a record fell
func makeRow(name: String, value: String, isBest: bool, badgeText: String, nameSize: int, valueSize: int, height: float) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = height
	row.add_child(ink(name.to_upper(), nameSize, INK, HudTheme.BODY))
	if isBest: row.add_child(badge(badgeText, maxi(10, nameSize - 6)))
	var dots = Dots.new()
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dots)
	row.add_child(ink(value, valueSize, INK, HudTheme.BOLD))
	return row

#a full-width row in the ticket's first group: the mode's own result (or, for records, every row)
func addRow(name: String, value: String, isBest: bool, badgeText := "NEW BEST") -> void:
	var row := makeRow(name, value, isBest, badgeText, 19, 21, 33)
	rows.add_child(row)
	conceal(row)

#one of the run's numbers, half the ticket wide
func addStat(name: String, value: String, isBest: bool) -> void:
	var cell := makeRow(name, value, isBest, "BEST", 16, 18, 28)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(cell)
	conceal(cell)

#a bonus row whose value is amounts with the game's symbols ("+30 (coin)"; MenuTheme.symbolRow parts), in ink
func addBonus(name: String, parts: Array, badgeText: String) -> void:
	var row := makeRow(name, "", true, badgeText, 16, 18, 28)
	var value := row.get_child(row.get_child_count() - 1)
	row.remove_child(value)
	value.queue_free()
	var symbols := MenuTheme.symbolRow(parts, 19, INK, 0)
	symbols.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(symbols)
	bonuses.add_child(row)
	conceal(row)

#a chip of news: one thing the run opened
func addChip(text: String, color := WIN_INK) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0), color, 5, 2, Vector4(8, 1, 8, 1)))
	var label = ink(text.to_upper(), 13, color, HudTheme.BOLD)
	var widest := TICKET_WIDTH - 96.0
	if HudTheme.BOLD.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > widest: #a long list is cut short, never wider than the ticket
		label.custom_minimum_size.x = widest
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(label)
	news.add_child(panel)

#the money: the win bonus, coins x stars, what the run paid, and the bank counting up to its new total
var payoutBlock: VBoxContainer
var bankLabel: Label
var bankFrom := 0
var bankTo := 0
var bankTween: Tween

func addPayout(body: VBoxContainer, coin: int, bonus: int, star: int, paid: int, isBest: bool) -> void:
	payoutBlock = VBoxContainer.new()
	payoutBlock.add_theme_constant_override("separation", 0)
	payoutBlock.add_child(Dashes.new())
	if bonus > 0: payoutBlock.add_child(makeRow("Win bonus  (%s)" % ModeTiers.NAMES[runTier], "+%s" % DriverCard.formatCoins(bonus), false, "", 16, 18, 26))
	payoutBlock.add_child(makeRow("Coins x stars (%d)" % maxi(0, star), "%s x %s" % [DriverCard.formatCoins(coin + bonus), Root.multiplierText(star)], false, "", 16, 18, 26))
	var total = HBoxContainer.new()
	total.add_child(ink("PAID", 24, INK, HudTheme.BOLD))
	if isBest: total.add_child(badge("NEW BEST"))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(gap)
	total.add_child(ink(DriverCard.formatCoins(paid), 52, Color(0.72, 0.34, 0.06), HudTheme.BOLD))
	payoutBlock.add_child(total)
	var bank = HBoxContainer.new()
	bank.add_theme_constant_override("separation", 6)
	bank.add_child(ink("BANK", 16, FADED_INK, HudTheme.BODY))
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank.add_child(space)
	bankLabel = ink("", 18, FADED_INK, HudTheme.BOLD)
	bank.add_child(bankLabel)
	var coinIcon := MenuTheme.iconRect(HudTheme.COIN_ICON, 20)
	coinIcon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bank.add_child(coinIcon)
	payoutBlock.add_child(bank)
	body.add_child(payoutBlock)
	conceal(payoutBlock)

func setBank(amount: int) -> void:
	if is_instance_valid(bankLabel): bankLabel.text = DriverCard.formatCoins(amount)

#the bank was credited when the ticket opened; this only shows it
func countBank(animated: bool) -> void:
	if bankTween: bankTween.kill()
	if not animated || bankTo == bankFrom || Transition.instant():
		setBank(bankTo)
		return
	bankTween = create_tween()
	bankTween.tween_interval(0.25)
	bankTween.tween_method(setBank, bankFrom, bankTo, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

#how the run ended, stamped on the world at the top left
func makeStamp(text: String, color: Color) -> Control:
	var holder = PanelContainer.new()
	holder.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0.35), color, 12, 6, Vector4(20, 2, 20, 2)))
	holder.add_child(ink(text, 60, color, HudTheme.BOLD))
	holder.modulate.a = 0.92
	holder.position = STAMP_AT
	holder.rotation = deg_to_rad(-8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("ticketRoot").add_child(holder)
	return holder

#the stamp lands like the shared Stamp (Stamp.gd): 140% to 100% in 110 ms, a clank and a 4 px rumble
func slam(target: Control) -> void:
	$AudioStreamPlayer_highImpact.play()
	target.pivot_offset = target.size * 0.5
	if Settings.reduce_motion():
		target.modulate.a = 0.0
		target.create_tween().tween_property(target, "modulate:a", 0.92, Transition.FADE_SECONDS)
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
	var mark = row.find_child("badge", true, false)
	if Settings.reduce_motion(): return
	await get_tree().process_frame #the container has placed it by now
	if not is_instance_valid(row): return
	var home = row.position.x
	row.position.x = home - 6.0
	row.create_tween().tween_property(row, "position:x", home, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if mark: Juice.pop(mark, 1.2, 0.25)
	if row.has_meta("stamp"): #a lottery match
		var at = row.get_global_rect()
		Stamp.slam(get_node("ticketRoot"), row.get_meta("stamp"), Vector2(at.position.x - 60.0, at.get_center().y), STAMP_GOOD, 30, -1.0, -0.15)

#---------- the rank (RunRank) ----------
#Over the world, bottom left: the run's score and where it lands on the ladder. The title rolls up from rank 1
#and stops on the run's own.

var rankBox: VBoxContainer
var rankTag: Label
var rankTitle: Label
var rankScore: Label
var rankPips: Pips
var rankExtras: Array[Control] = [] #shown when the roll lands: the best here or a NEW BEST badge, and the highlight
var rankGrade := {}
var rankTween: Tween
var rankShown := 0
var rankLanded := false

func buildRank(grade: Dictionary, ranked: Dictionary, counts: bool) -> void:
	rankGrade = grade
	rankBox = VBoxContainer.new()
	rankBox.position = RANK_AT
	rankBox.add_theme_constant_override("separation", -2)
	rankBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rankTag = chalk("RUN RANK", 20, HudTheme.GOLD)
	rankBox.add_child(rankTag)
	rankTitle = chalk(RunRank.title(1).to_upper(), 66, HudTheme.TEXT)
	rankBox.add_child(rankTitle)
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	rankScore = chalk("SCORE 0", 26, HudTheme.TEXT)
	line.add_child(rankScore)
	if ranked.best && counts:
		var mark := badge("NEW BEST", 15)
		line.add_child(mark)
		rankExtras.push_back(mark)
	elif int(ranked.before) > 0:
		var best := chalk("BEST HERE %d" % int(ranked.before), 20, HudTheme.MUTED)
		best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(best)
		rankExtras.push_back(best)
	rankBox.add_child(line)
	var gap = Control.new()
	gap.custom_minimum_size.y = 10
	rankBox.add_child(gap)
	rankPips = Pips.new()
	rankBox.add_child(rankPips)
	if str(grade.highlight) != "":
		var gap2 = Control.new()
		gap2.custom_minimum_size.y = 8
		rankBox.add_child(gap2)
		var note := chalk(str(grade.highlight).to_upper(), 22, HudTheme.GOLD)
		rankBox.add_child(note)
		rankExtras.push_back(note)
	for extra in rankExtras: extra.modulate.a = 0.0
	get_node("ticketRoot").add_child(rankBox)

#the roll: up the ladder a rank at a time, slowing as it nears the run's own
func rollRank() -> void:
	var seconds: float = 0.4 + 0.04 * int(rankGrade.rank)
	summaryTimer = -seconds #the buttons wait for it
	rankTween = create_tween()
	rankTween.tween_method(setRoll, 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rankTween.tween_callback(landRank.bind(true))

func setRoll(k: float) -> void:
	var rank: int = 1 + int(k * (int(rankGrade.rank) - 1))
	rankScore.text = "SCORE %d" % int(k * int(rankGrade.score))
	rankPips.setLit(rank)
	if rank == rankShown: return
	rankShown = rank
	rankTitle.text = RunRank.title(rank).to_upper()
	$AudioStreamPlayer2_lowImpact.play()

func landRank(animated: bool) -> void:
	if rankLanded || rankBox == null: return
	rankLanded = true
	if rankTween: rankTween.kill()
	var rank: int = rankGrade.rank
	rankBox.modulate.a = 1.0
	rankTag.text = "RUN RANK  %d OF %d" % [rank, RunRank.RANKS]
	rankTitle.text = RunRank.title(rank).to_upper()
	rankScore.text = "SCORE %d" % int(rankGrade.score)
	rankPips.setLit(rank)
	for extra in rankExtras: extra.modulate.a = 1.0
	if not animated: return
	Transition.sound("clank", -5.0)
	rankTitle.pivot_offset = Vector2(0, rankTitle.size.y * 0.5)
	Juice.pop(rankTitle, 1.12, 0.3)
	for extra in rankExtras: Juice.pop(extra, 1.2, 0.25)

#---------- the buttons ----------

#the row of actions, the first one the primary button; each of the others has its own key
func addActions(kinds: Array) -> void:
	actionBar = HBoxContainer.new()
	actionBar.position = ACTIONS_AT
	actionBar.add_theme_constant_override("separation", 12)
	primary = kinds[0]
	for kind in kinds:
		var isPrimary: bool = kind == primary
		var text: String = ACTION_TEXT[kind]
		if kind == "next": text = "NEXT:  %s" % nextText()
		var b := MenuTheme.button(text, PackedStringArray(["ui_accept" if isPrimary else ACTION_KEYS[kind]]), isPrimary)
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24 if isPrimary else 20)
		b.pressed.connect(act.bind(kind))
		actionBar.add_child(b)
		buttons[kind] = b
	continueButton = buttons[primary]
	actionBar.visible = false
	get_node("ticketRoot").add_child(actionBar)

#what Next goes on to: the mode, and the level when it is another one
func nextText() -> String:
	var mode: String = Root.gameModeDescription[nextUp.mode].name
	return mode if nextUp.level == runLevel else "%s, %s" % [RunLauncher.levelName(nextUp.level).to_upper(), mode]

#under the buttons: what a new run will take for the gadget and boost, and the graphics advisor's note
func addFooter(advice: String) -> void:
	var column = VBoxContainer.new()
	footer = column
	column.visible = false
	column.position = FOOTER_AT
	column.size.x = 900
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cost := RunLauncher.loadoutCost()
	if cost > 0:
		var line := MenuTheme.symbolRow(["A new run starts with your gadget and boost:", {"gem": cost}], 16, HudTheme.MUTED)
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		column.add_child(line)
	if advice != "":
		var label = Label.new()
		label.theme_type_variation = "HintLabel"
		label.text = advice
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.custom_minimum_size.x = 900
		column.add_child(label)
	get_node("ticketRoot").add_child(column)

## One of the buttons. "retry" plays the run again and "next" the run after it (nextRun), both straight from
## here; "options" goes to the menu's Level Options for this level; anything else to the garage.
func act(kind: String) -> void:
	if continued: return
	continued = true
	layer = Transition.LAYER - 1 #under the shutter, which now covers the ticket
	if kind == "retry" || kind == "next":
		var run: Dictionary = nextUp if kind == "next" && not nextUp.is_empty() else {"level": runLevel, "mode": runMode, "tier": runTier}
		RunLauncher.select(run.level, run.mode, run.tier)
		RunLauncher.buyLoadout()
		RunLauncher.start(self, RunLauncher.levelScene(run.level), RunLauncher.levelName(run.level).to_upper())
		return
	if kind == "options":
		RunLauncher.select(runLevel, runMode, runTier)
		Root.menuReturn = "options"
	await outro()
	queue_free()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _on_continue_pressed():
	if isGameSummary: act(primary)
	else: closeRecords()

#---------- in and out (Transition, docs/UI.md) ----------
#Results: the run is frozen where it ended. The camera pulls back to show more of the map, the stamp lands on
#the world, then the HUD goes and the ticket skids in from the right. Leaving slams the shutter over it all:
#the menu rolls it up, and a new run loads behind it.
#Records (from the menu) just drop in and lift out.

var fx: TransitionFx
var introTween: Tween

func paper() -> Control:
	return get_node("ticketRoot/ticket")

func hideHud() -> void:
	if isGameSummary && is_instance_valid(Root.playerRoot): Root.playerRoot.visible = false

func intro() -> void:
	var root: Control = get_node("ticketRoot")
	var sheet = paper()
	var home = sheet.position
	if Transition.instant():
		hideHud()
		return
	if Settings.reduce_motion():
		hideHud()
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
	revealHeld = true
	fx = TransitionFx.new()
	fx.autoFree = false
	root.add_child(fx)
	root.move_child(fx, 1)
	dim.modulate.a = 0.0
	stamp.visible = false
	sheet.position.x = screen.x + 40
	sheet.set_meta("home", home)
	pullBack()
	if reason == Root.endCondition.NOHEALTH: #a spin-out: a screech and a puff of tire smoke where the car stopped
		Transition.sound("screech", -2.0)
		fx.burst(screen * 0.5, 10)
	introTween = create_tween()
	introTween.tween_interval(0.5)
	introTween.tween_callback(func():
		stamp.visible = true
		slam(stamp))
	introTween.tween_interval(0.4)
	introTween.tween_callback(func():
		hideHud()
		Transition.sound("whoosh", -8.0))
	introTween.tween_property(dim, "modulate:a", 1.0, 0.25)
	introTween.parallel().tween_property(sheet, "position:x", home.x, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	introTween.tween_callback(func():
		Transition.sound("skid" if reason == Root.endCondition.NOHEALTH else "clank", -6.0)
		Juice.rumble(root, "position", 2.0, 0.12)
		revealHeld = false)

#the intro cut short: everything where it ends up
func settleIntro() -> void:
	if not revealHeld: return
	revealHeld = false
	if introTween: introTween.kill()
	var sheet = paper()
	sheet.position = sheet.get_meta("home", sheet.position)
	dim.modulate.a = 1.0
	stamp.visible = true
	stamp.scale = Vector2.ONE
	hideHud()

#The camera eases back from the car, so the end of the run is seen with the map round it. The run is paused,
#so the world is a still; the car's camera runs while paused, and the chunks the wider view uncovers keep
#streaming in (as they do behind the loading shutter: Level.holdUnderShutter).
func pullBack() -> void:
	var car = Root.playerCar
	var camera: Camera2D = car.get_node_or_null("Camera2D") if is_instance_valid(car) else null
	if camera == null: return
	var tiles = Root.levelRoot.get_node_or_null("TileManager") if is_instance_valid(Root.levelRoot) else null
	if tiles: tiles.process_mode = Node.PROCESS_MODE_ALWAYS
	create_tween().tween_property(camera, "zoom", camera.zoom * PULL_BACK, PULL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func outro() -> void:
	if Transition.instant():
		if isGameSummary: Transition.carry()
		return
	if not isGameSummary:
		var sheet = paper()
		var t = create_tween().set_parallel()
		t.tween_property(sheet, "position:y", sheet.position.y - 80, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(get_node("ticketRoot"), "modulate:a", 0.0, 0.14)
		await t.finished
		return
	var shutter = Transition.close("GOONCRUSHER", "RUN OVER")
	if not shutter.isShut: await shutter.shut

#cream paper with a zigzag torn edge top and bottom, and a soft shadow; it grows to fit what it holds
class TicketPaper extends MarginContainer:
	const TOOTH := 12.0
	func _init() -> void:
		resized.connect(queue_redraw)
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
		custom_minimum_size.y = 14
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

#the ladder as 25 pips, lit up to the run's rank
class Pips extends Control:
	var lit := 0
	func _init() -> void:
		custom_minimum_size = Vector2(RunRank.RANKS * 22.0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func setLit(count: int) -> void:
		if count == lit: return
		lit = count
		queue_redraw()
	func _draw() -> void:
		for i in RunRank.RANKS:
			var at := Rect2(i * 22.0, 0, 18, 12)
			draw_rect(at.grow(2), Color(HudTheme.OUTLINE, 0.8))
			draw_rect(at, HudTheme.GOLD if i < lit else Color(1, 1, 1, 0.28))
