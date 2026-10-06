extends CanvasLayer

#The end of a run, printed as a ticket (docs/UI.md), and the same ticket for a driver's records.
#Results: rows reveal one at a time (a fresh press speeds that up, the next one continues), new
#bests get a badge, the payout is coins x stars (Root.computePayout) and a stamp says how it ended.
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
	}
	var lines: Array = reasonDict.get(reason, ["Run Over"])
	return lines[randi() % lines.size()]

func buildGameSummary():
	Root.playerRoot.visible = false
	if levelCompleted && reason != Root.endCondition.ABANDONED:
		SaveManager.currentLevelPassed()
	else:
		$AudioStreamPlayer_highImpact.play()
	var car = Root.playerCar
	var records = SaveManager.getCarByName(car.carId).records
	var level = SaveManager.playerData.levels[SaveManager.playerData.selectedLevel]
	var mode = Root.gameModeDescription[SaveManager.playerData.gameMode].name
	var body = buildTicket("%s  -  %s  -  %s" % [mode, level.name.to_upper(), car.charName.to_upper()], reasonLine())

	#records: compare before updating, so a beaten record gets its badge
	var crushed = car.currentGoonsCrushed
	var topSpeed = int(car._highest_measured_speed / 10)
	var paid = Root.computePayout(car.coin, car.star)
	var powerups = car.powerupsCollected
	var timer = get_tree().get_first_node_in_group("runTimer")
	addRow("Time", timer.text if is_instance_valid(timer) else "-", false)
	addRow("Top speed", Settings.speed_text(car._highest_measured_speed), topSpeed > records.speed)
	addRow("Goons crushed", str(crushed), crushed > records.goonsCrushed)
	addRow("Coins", str(car.coin), false)
	addRow("Powerups", str(powerups), powerups > records.powerups)
	addRow("Gems", str(car.gem), car.gem > records.gem)
	addRow("Slot machines", str(car.slotMachines), car.slotMachines > records.slotMachines)
	addPayout(body, car.coin, car.star, paid, paid > records.coin)
	records.goonsCrushed = maxi(records.goonsCrushed, crushed)
	records.speed = maxi(records.speed, topSpeed)
	records.coin = maxi(records.coin, paid)
	records.powerups = maxi(records.powerups, powerups)
	records.gem = maxi(records.gem, car.gem)
	records.slotMachines = maxi(records.slotMachines, car.slotMachines)
	var discovered = Goonopedia.creditCrushes(car.crushedById)

	#pay now and save, so quitting from the summary can't lose the run; the menu only animates it
	SaveManager.addCoins(paid)
	SaveManager.addGems(car.gem)
	Root.earnedCoins = paid
	Root.earnedGems = car.gem
	SaveManager.save_character_data()
	SaveManager.flush()
	var stampInfo = STAMPS.get(reason, ["GAME OVER", Color(0.78, 0.14, 0.11)])
	stamp = makeStamp(stampInfo[0], stampInfo[1])
	reveal.push_back(stamp)
	addContinue("CONTINUE", "Any button speeds up the count")
	var notes = []
	if not discovered.is_empty(): notes.push_back("New in the Goonopedia: " + ", ".join(discovered))
	var advice = Settings.take_advisor_message()
	if advice != "": notes.push_back(advice)
	if not notes.is_empty(): addFooterNote("   -   ".join(notes))

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

#"TOP SPEED ........ 61 MPH", with a NEW BEST badge when a record fell
func addRow(name: String, value: String, isBest: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 38
	row.add_child(ink(name.to_upper(), 20, INK, HudTheme.BODY))
	if isBest:
		var badge = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.GAIN, Color(0, 0, 0, 0), 6, 0, Vector4(7, 0, 7, 0)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(ink("NEW BEST", 13, INK, HudTheme.BOLD))
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
	sum.add_child(ink("COINS x STARS", 20, INK, HudTheme.BODY))
	var gap = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum.add_child(gap)
	sum.add_child(ink("%s x %d" % [DriverCard.formatCoins(coin), maxi(1, star)], 22, INK, HudTheme.BOLD))
	block.add_child(sum)
	var total = HBoxContainer.new()
	total.add_child(ink("PAID", 26, INK, HudTheme.BOLD))
	if isBest:
		var badge = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.GAIN, Color(0, 0, 0, 0), 6, 0, Vector4(7, 0, 7, 0)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(ink("NEW BEST", 13, INK, HudTheme.BOLD))
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

func slam(target: Control) -> void:
	$AudioStreamPlayer_highImpact.play()
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2(1.8, 1.8)
	target.create_tween().tween_property(target, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	label.position = Vector2(300, 860)
	label.size = Vector2(1000, 30)
	get_node("ticketRoot").add_child(label)

func _on_continue_pressed():
	if continued: return
	continued = true
	queue_free()
	if isGameSummary:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")

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
