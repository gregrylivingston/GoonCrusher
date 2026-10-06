extends CanvasLayer

@onready var activeSlots = [
	$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3
]

var isPlaying: bool = true
var isReady: bool = false
var inactiveSlots = []
var slotDelayTime = 1.8
var isGoonCrushBonus: bool = false

var myBackground 
var slotTransition = preload("res://scene/fx/lotto/lottoTransition.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("slotMachine")
	SlotSymbols.bet = 0
	restyle()
	Root.playerCar.slotMachines += 1
	$slotMachineBonusSound.stream = load(winSound[ randi_range( 0 , winSound.size() -1 ) ] )
	$slotMachineBonusSound.play()
	$Panel.position.y = get_viewport().get_visible_rect().size.y
	
	if isGoonCrushBonus:
		Root.playerRoot.animateNewGoonCrushGoal(false)
		await get_tree().create_timer(1.5).timeout
	
	myBackground = slotTransition.instantiate()
	Root.levelRoot.add_child( myBackground )


	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	tween.tween_property($Panel , "position" , Vector2(0.0,0.0) , 1.1)

	
	$Panel/Panel/VBoxContainer/play_button.disabled = true
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playPurseRewardAudio()
	$slotMahineSound.volume_db = -12.0
	$slotMahineLever.volume_db = 4.0
	$slotMachineBonusSound.volume_db = 4.0
	await get_tree().create_timer( slotDelayTime ).timeout
	$slotMahineSound.play()
	isReady = true
	$Panel/Panel/VBoxContainer/play_button.disabled = false
	delayKeyPress = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
	$Panel/Panel/Panel/Label.text = "FREE SPIN" if isGoonCrushBonus else "SLOT MACHINE"
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

var bonusSound = [
	"res://sound/fx/slotmachine/bonus_1.mp3",
	"res://sound/fx/slotmachine/bonus_2.mp3",
	"res://sound/fx/slotmachine/bonus_3.mp3"
]

var winSound = [
	"res://sound/fx/slotmachine/winner_1.mp3",
	"res://sound/fx/slotmachine/winner_2.mp3",
	"res://sound/fx/slotmachine/winner_3.mp3",
	"res://sound/fx/slotmachine/winner_4.mp3",
	"res://sound/fx/slotmachine/winner_5.mp3"
]

func _on_play_button_pressed():
	if not isReady: return null
	if not betPaid:
		betPaid = true
		Root.playerCar.coin -= SlotSymbols.BETS[SlotSymbols.bet]
	$slotMahineLever.play()
	if activeSlots.size() > 0:   #keep playing
		$slotMachineBonusSound.stream = load(bonusSound[ randi_range( 0 , bonusSound.size() -1 ) ] )
		$slotMachineBonusSound.play()
		activeSlots[0].stopSpinning()
		inactiveSlots.push_back( activeSlots.pop_front() )
	if activeSlots.size() == 0:   #slots are over
		$slotMahineSound.stop()
		if Root.playerCar.gem > 0: $Panel/Panel/VBoxContainer/reroll_button.disabled = false
		$Panel/Panel/VBoxContainer/claim_button.disabled = false
		$Panel/Panel/VBoxContainer/play_button.disabled = true
		$slotMachineBonusSound.stream = load(winSound[ randi_range( 0 , winSound.size() -1 ) ] )
		$slotMachineBonusSound.play()
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
	$slotMahineSound.play()
	isReady = true

var countdownScreen = load("res://scene/player/countdown.tscn")
var claimButtonPressed = false
func _on_claim_button_pressed():
	claimButtonPressed = true

	myBackground.destory()
	visible = false
	var myIconArray: Array[Texture2D] = []   #used to pass icons to splash
	var rows = [$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3]
	var reels = rows.map(func(row): return row.getActiveType())
	#Dice: a luck / 500 chance that reel 3 lands on reel 2's symbol
	if randf() < Root.playerCar.luck / 500.0: reels[2] = reels[1]
	for reel in reels: myIconArray.push_back(SlotSymbols.texture(reel))
	payReels(reels)
	var splashScreen = load("res://scene/player/menu/splash/splashscreen_1.tscn").instantiate()
	splashScreen.myIcons = myIconArray
	Root.levelRoot.add_child(splashScreen)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if isGoonCrushBonus: Root.playerRoot.animateNewGoonCrushGoal()
	splashScreen.startExplosion()
	

	Root.playerCar.add_child(countdownScreen.instantiate())
	queue_free()
		

#Paylines (SlotSymbols.payouts): a pair pays its symbol twice, a triple five times; one or two stars are
#Star Fragments, three are the jackpot (+1 star and a purse rain). Credited now, before the splash.
func payReels(reels: Array) -> void:
	var car = Root.playerCar
	var pays := SlotSymbols.payouts(reels)
	SlotSymbols.bet = 0
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
