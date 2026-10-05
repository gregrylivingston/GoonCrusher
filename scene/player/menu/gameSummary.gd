extends CanvasLayer

var isGameSummary: bool = true #alternative is achievements menu for now
var levelCompleted: bool = false #did the player successfully complete their run.
var reason #why did I win or lose.  this is an enum, Root.endCondition

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if isGameSummary: buildGameSummary()
	else: buildAchievementSummary()


var summaryTimer:float = -2.0
var summaryComplete: bool = false
var summaryTimerLength: float = 0.5
const INPUT_DELAY_MSEC = 500 #presses are ignored this long after the summary opens
const PRESS_ACTIONS = ["ui_accept", "ui_select", "ui_cancel", "Accelerate", "Brake"] #polled too, in case events don't reach this node
var openedAtMsec := Time.get_ticks_msec()
var continued := false
var freshPress := false

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
	if not summaryComplete:
		if summaryTimerLength != 0.1:
			summaryTimerLength = 0.1
			summaryTimer = 1.0
	else: _on_continue_pressed()

static func isFreshPress(event: InputEvent) -> bool:
	if event is InputEventKey: return event.is_pressed() && not event.is_echo()
	if event is InputEventMouseButton: return event.is_pressed() && (event as InputEventMouseButton).button_index <= MOUSE_BUTTON_MIDDLE #not the wheel
	return event is InputEventJoypadButton && event.is_pressed()
		
func advanceSummary():
	for i in $Panel/Panel2/VBoxContainer.get_children():
		if i.visible == false:
			i.visible = true
			if i ==	$Panel/Panel2/VBoxContainer/continue:i.grab_focus()
			return true
	return false #returns false if there is nothing left to make visible



func buildGameSummary():
	

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
	var textreason = reasonDict[reason][ randi() % reasonDict[reason].size() - 1  ]
	
	%wasSuccessful.text = textreason
	%wasSuccessful.self_modulate.a = 1.0
	$Panel/Panel2.self_modulate.a = 0.0
	Root.playerRoot.visible = false
	if levelCompleted && reason != Root.endCondition.ABANDONED:
		SaveManager.currentLevelPassed()
	else:
		$AudioStreamPlayer_highImpact.play()			

	
	var carStats = SaveManager.getCarByName(Root.playerCar.carId)
	
			#"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
	var crushed = Root.playerCar.currentGoonsCrushed
	if crushed > carStats.records.goonsCrushed: 
		carStats.records.goonsCrushed = crushed
	$Panel/Panel2/VBoxContainer/HBoxContainer6/goonsCrushed.text = str(Root.playerCar.currentGoonsCrushed)
	
	var topSpeed = int(Root.playerCar._highest_measured_speed/10)
	if topSpeed > carStats.records.speed: 
		carStats.records.speed = topSpeed
	$Panel/Panel2/VBoxContainer/HBoxContainer3/topSpeed.text = Settings.speed_text(Root.playerCar._highest_measured_speed)
	
	$Panel/Panel2/VBoxContainer/HBoxContainer7/time.text = str( get_tree().get_first_node_in_group("runTimer").text )
	
	var coin = Root.computePayout(Root.playerCar.coin, Root.playerCar.star)
	if coin > carStats.records.coin: 
		carStats.records.coin = coin
	$Panel/Panel2/VBoxContainer/HBoxContainer2/coinsCollected.text = str(Root.playerCar.coin)
	addPaidRow(Root.playerCar.coin, Root.playerCar.star, coin)
	
	var powerups = Root.playerCar.powerupsCollected
	if powerups > carStats.records.powerups: 
		carStats.records.powerups = powerups
	$Panel/Panel2/VBoxContainer/HBoxContainer4/powerups.text = str( powerups )
	
	var gem = Root.playerCar.gem
	if gem > carStats.records.gem: 
		carStats.records.gem = gem
	$Panel/Panel2/VBoxContainer/HBoxContainer5/gems.text = str(gem)
	
	var slotMachines = Root.playerCar.slotMachines
	if slotMachines > carStats.records.slotMachines: 
		carStats.records.slotMachines = slotMachines

	$Panel/Panel2/VBoxContainer/HBoxContainer8/slotMachines.text = str(slotMachines)
	#pay now and save, so quitting from the summary can't lose the run; the menu only animates it
	SaveManager.addCoins(coin)
	SaveManager.addGems(gem)
	Root.earnedCoins = coin
	Root.earnedGems = gem
	SaveManager.save_character_data()
	SaveManager.flush()
	var advice = Settings.take_advisor_message()
	if advice != "":
		var label = Label.new()
		label.text = advice
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		label.position.y -= 60
		$Panel.add_child(label)
	


#"Paid  120 x 2 = 240" under the coin row: what the run actually pays (Root.computePayout)
func addPaidRow(coin: int, star: int, paid: int) -> void:
	var coinRow = $Panel/Panel2/VBoxContainer/HBoxContainer2
	var paidRow = coinRow.duplicate()
	paidRow.name = "paidRow"
	paidRow.visible = false #revealed in turn by advanceSummary
	paidRow.get_node("Label").text = "Paid (Coins x Stars)"
	paidRow.get_node("coinsCollected").text = "%d x %d = %d" % [coin, maxi(1, star), paid]
	coinRow.add_sibling(paidRow)

func buildAchievementSummary():
	for i in $Panel/Panel2/VBoxContainer.get_children():i.visible = true
	
	var carStats = SaveManager.getCarByName(Root.carInfo.carId)
	$Panel/Panel2/VBoxContainer/HBoxContainer6/goonsCrushed.text = str(carStats.records.goonsCrushed)
	$Panel/Panel2/VBoxContainer/HBoxContainer3/topSpeed.text = Settings.speed_text(carStats.records.speed * 10.0)
	$Panel/Panel2/VBoxContainer/HBoxContainer7/time.visible = false
	
	$Panel/Panel2/VBoxContainer/HBoxContainer2/Label.text = "Best Payout" #records.coin holds the best paid amount
	$Panel/Panel2/VBoxContainer/HBoxContainer2/coinsCollected.text = str(carStats.records.coin)
	$Panel/Panel2/VBoxContainer/HBoxContainer4/powerups.text = str( carStats.records.powerups )
	$Panel/Panel2/VBoxContainer/HBoxContainer5/gems.text = str(carStats.records.gem)
	
	$Panel/Panel2/VBoxContainer/HBoxContainer8/slotMachines.text = str(carStats.records.slotMachines)
	



func _on_continue_pressed():
	if continued: return
	continued = true
	queue_free()
	if isGameSummary:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")
	
