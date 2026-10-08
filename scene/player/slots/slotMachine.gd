extends CanvasLayer

@onready var activeSlots = [
	$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3
]

var isPlaying: bool = true
var isReady: bool = false
var inactiveSlots = []
var slotDelayTime = 1.8
var isGoonCrushBonus: bool = false #from a gift box (CrushPrizes)
var prizeTier := 0 #the gift box's tier: free bet levels on top of the bet (SlotSymbols.bonus)

var hatch: GameHatch #the skid in, the hatch over the reels and the peel out (docs/UI.md, "Transitions")
var dim := ColorRect.new()
# Called when the node enters the scene tree for the first time.
func _ready():
	if PickupMenu.runOver(): #added (deferred) in the frame the run ended: never over the results ticket
		queue_free()
		return
	add_to_group("slotMachine")
	SlotSymbols.bet = 0
	SlotSymbols.bonus = prizeTier
	restyle()
	Root.playerCar.slotMachines += 1
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	$Panel.visible = false

	create_tween().tween_property(dim, "color:a", 0.55, 0.25)
	$Panel.visible = true
	hatch = GameHatch.attach(self, $Panel, $Panel/Panel, spinTitle() if isGoonCrushBonus else "BONUS")
	hatch.enter(0.5) #the spin unlocks at slotDelayTime, just after the hatch is up


	$Panel/Panel/VBoxContainer/play_button.disabled = true
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playPurseRewardAudio()
	await get_tree().create_timer( slotDelayTime ).timeout
	isReady = true
	$Panel/Panel/VBoxContainer/play_button.disabled = false
	delayKeyPress = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func spinTitle() -> String:
	return "FREE SPIN" if prizeTier <= 0 else "%s SPIN" % CrushPrizes.tierName(prizeTier).to_upper()

func resetKeyPress():
	await get_tree().create_timer(keyPressDelay).timeout
	delayKeyPress = false

var keyPressDelay = .25
var delayKeyPress = true
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	syncButtons()
	if isReady && not betPaid && activeSlots.size() == 3 && delayKeyPress == false:
		if Input.is_action_just_pressed("TurnRight"): changeBet(1)
		elif Input.is_action_just_pressed("TurnLeft"): changeBet(-1)
	if Input.is_action_just_pressed("Accelerate") && delayKeyPress == false:
		if isReady:
			_on_play_button_pressed()
			delayKeyPress = true
			resetKeyPress()
		elif $Panel/Panel/VBoxContainer/claim_button.disabled == false && activeSlots.size() == 0 && not claimButtonPressed:
			_on_claim_button_pressed()
	if Input.is_action_just_released("Brake") && not isReady &&  $Panel/Panel/VBoxContainer/claim_button.disabled == false:
		_on_reroll_button_pressed()




#the menu look (docs/UI.md): a smoked panel, gold-framed reels and one row of themed buttons with
#key hints. The original buttons stay (hidden) because the logic reads and sets their state;
#syncButtons mirrors it onto the new row every frame. Accelerate and Brake work as before.
var spinButton: Button
var rerollButton: Button
var claimButton: Button

func restyle() -> void:
	InputGlyphs.ensureMenuActions()
	var panel: Panel = $Panel/Panel
	panel.theme = MenuTheme.theme()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.055, 0.047, 0.043, 0.94), HudTheme.RIM, 18, 4))
	var reels: Panel = $Panel/Panel/Panel2
	reels.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.05, 0.04, 0.035, 1.0), HudTheme.GOLD, 14, 4))
	reels.offset_left = 40
	reels.offset_right = -40
	reels.offset_bottom = -132
	$Panel/Panel/Panel/Label.text = spinTitle() if isGoonCrushBonus else "SLOT MACHINE"
	$Panel/Panel/VBoxContainer.visible = false
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = -108
	row.offset_bottom = -30
	panel.add_child(row)
	spinButton = MenuTheme.button("SPIN", PackedStringArray(["Accelerate"]), true)
	rerollButton = MenuTheme.button("Reroll  (1 gem)", PackedStringArray(["Brake"]), false, HudTheme.GEM_ICON)
	claimButton = MenuTheme.button("COLLECT", PackedStringArray(["Accelerate"]), true)
	betButton = MenuTheme.button("BET  0", PackedStringArray(["TurnRight"]), false, HudTheme.COIN_ICON)
	betButton.custom_minimum_size = Vector2(230, 70)
	betButton.focus_mode = Control.FOCUS_NONE
	betButton.pressed.connect(changeBet.bind(1))
	row.add_child(betButton)
	for entry in [[spinButton, _on_play_button_pressed, 300], [rerollButton, _on_reroll_button_pressed, 300], [claimButton, _on_claim_button_pressed, 300]]:
		entry[0].custom_minimum_size = Vector2(entry[2], 70)
		entry[0].focus_mode = Control.FOCUS_NONE #the keys drive it; buttons are for the mouse
		entry[0].pressed.connect(entry[1])
		row.add_child(entry[0])
	syncButtons()

#Bet: run coins that tilt the reels toward rarer prizes (SlotSymbols.weights). Chosen before the first
#spin with Steer Left and Right, and paid when it starts.
var betButton: Button
var betPaid := false

func changeBet(step: int) -> void:
	if betPaid: return
	var level = wrapi(SlotSymbols.bet + step, 0, SlotSymbols.BETS.size())
	while level > 0 && Root.playerCar.coin < SlotSymbols.BETS[level]: level -= 1
	SlotSymbols.bet = level
	betButton.text = "BET  %d" % SlotSymbols.BETS[level]

func syncButtons() -> void:
	if not is_instance_valid(spinButton): return
	if is_instance_valid(betButton): betButton.visible = not betPaid && activeSlots.size() == 3
	spinButton.disabled = $Panel/Panel/VBoxContainer/play_button.disabled
	rerollButton.disabled = $Panel/Panel/VBoxContainer/reroll_button.disabled
	claimButton.disabled = $Panel/Panel/VBoxContainer/claim_button.disabled
	claimButton.visible = not claimButton.disabled
	spinButton.visible = not claimButton.visible

#no spin, lever or win sounds (they clashed with the radio): each reel's stop clanks (SlotRow.settle)
func _on_play_button_pressed():
	if not isReady: return null
	if not betPaid:
		betPaid = true
		Root.playerCar.coin -= SlotSymbols.BETS[SlotSymbols.bet]
	if activeSlots.size() > 0:   #keep playing
		activeSlots[0].stopSpinning()
		inactiveSlots.push_back( activeSlots.pop_front() )
	if activeSlots.size() == 0:   #slots are over
		if Root.playerCar.gem > 0: $Panel/Panel/VBoxContainer/reroll_button.disabled = false
		$Panel/Panel/VBoxContainer/claim_button.disabled = false
		$Panel/Panel/VBoxContainer/play_button.disabled = true
		isReady = false

		


func _on_reroll_button_pressed():
	if not Root.playerCar.spendGems(1): return null
	for i in inactiveSlots:
		i.startSpinning()
		activeSlots.push_back(i)

		$Panel/Panel/VBoxContainer/reroll_button.disabled = true
		$Panel/Panel/VBoxContainer/claim_button.disabled = true
	inactiveSlots = []
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playPurseRewardAudio()
	await get_tree().create_timer( slotDelayTime ).timeout
	$Panel/Panel/VBoxContainer/play_button.disabled = false
	isReady = true

var countdownScreen = load("res://scene/player/countdown.tscn")
var claimButtonPressed = false
func _on_claim_button_pressed():
	if claimButtonPressed: return
	claimButtonPressed = true
	$Panel/Panel/VBoxContainer/claim_button.disabled = true
	$Panel/Panel/VBoxContainer/reroll_button.disabled = true
	var rows = [$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3]
	var reels = rows.map(func(row): return row.getActiveType())
	#Dice: a luck / 500 chance that reel 3 lands on reel 2's symbol
	if randf() < Root.playerCar.luck / 500.0: reels[2] = reels[1]
	var pays := payReels(reels) #credited now: the chute below is only the look
	var prizes: Array = []
	for id in pays:
		for i in maxi(1, pays[id]): prizes.push_back(SlotSymbols.texture(id))
	if is_instance_valid(hatch):
		var card: Rect2 = $Panel/Panel.get_global_rect()
		await hatch.leave(func(): await PayoutChute.pour(self, card, prizes))
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Root.playerCar.add_child(countdownScreen.instantiate())
	queue_free()
		

#Paylines (SlotSymbols.payouts): a pair pays its symbol twice, a triple five times; one or two stars are
#Star Fragments, three are the jackpot (+1 star and a purse rain). Credited now, before the chute pours.
func payReels(reels: Array) -> Dictionary:
	var car = Root.playerCar
	var pays := SlotSymbols.payouts(reels)
	SlotSymbols.bet = 0
	SlotSymbols.bonus = 0
	for id in pays:
		if id == SlotSymbols.STAR:
			if pays[id] == 3:
				car.star += 1
				for i in 5: PickupEffects.dropAndCollect(car, "purse", car.global_position)
				PickupEffects.toast("JACKPOT  -  +1 STAR", HudTheme.GOLD, HudTheme.STAR_ICON)
			else:
				for i in pays[id]: PickupEffects.addStarFragment(car)
			continue
		if pays[id] > 1: PickupEffects.toast("%s  -  %s x%d" % ["TRIPLE" if reels.count(id) == 3 else "PAIR", Pickups.displayName(id).to_upper(), pays[id]], Pickups.rarityColor(Pickups.rarity(id)), Pickups.texture(id))
		for i in pays[id]: PickupEffects.collect(car, id, car.global_position)
	return pays
