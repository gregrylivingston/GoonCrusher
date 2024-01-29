extends CanvasLayer

@onready var activeSlots = [
	$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3
]

var isPlaying: bool = true
var isReady: bool = false
var inactiveSlots = []
var slotDelayTime = 1.8

var myBackground 
var slotTransition = preload("res://scene/fx/lotto/lottoTransition.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	Root.playerCar.slotMachines += 1
	$slotMachineBonusSound.stream = load(winSound[ randi_range( 0 , winSound.size() -1 ) ] )
	$slotMachineBonusSound.play()
	myBackground = slotTransition.instantiate()
	Root.levelRoot.add_child( myBackground )

	$Panel.position.y = get_viewport().size.y
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	tween.tween_property($Panel , "position" , Vector2(0.0,0.0) , 1.1)

	
	$Panel/Panel/VBoxContainer/play_button.disabled = true
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playPurseRewardAudio()
	$slotMahineSound.volume_db = SaveManager.getVolume("fx") - 12.0
	$slotMahineLever.volume_db = SaveManager.getVolume("fx") + 4
	$slotMachineBonusSound.volume_db = SaveManager.getVolume("fx") + 4
	await get_tree().create_timer( slotDelayTime ).timeout
	Root.levelRoot.reduceMusic()
	$slotMahineSound.play()
	isReady = true
	$Panel/Panel/VBoxContainer/play_button.disabled = false
	delayKeyPress = false


func resetKeyPress():
	await get_tree().create_timer(keyPressDelay).timeout
	delayKeyPress = false

var keyPressDelay = .25
var delayKeyPress = true
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("Accelerate") && delayKeyPress == false:
		if isReady:
			_on_play_button_pressed()
			delayKeyPress = true
			resetKeyPress()
		elif $Panel/Panel/VBoxContainer/claim_button.disabled == false && activeSlots.size() == 0 && not claimButtonPressed:
			_on_claim_button_pressed()
	if Input.is_action_just_released("Brake") && not isReady &&  $Panel/Panel/VBoxContainer/claim_button.disabled == false:
		_on_reroll_button_pressed()




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
	for slot in [$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3]:
		myIconArray.push_back( slot.getActiveTexture() )
		var newPowerup = Root.getSpecificPowerup(slot.getActiveType())
		newPowerup.global_position = Root.playerCar.global_position
		newPowerup.process_mode = Node.PROCESS_MODE_ALWAYS
		Root.levelRoot.add_child(newPowerup)
		newPowerup.sendReward(Root.playerCar, false)
	
	var splashScreen = load("res://scene/player/menu/splash/splashscreen_1.tscn").instantiate()
	splashScreen.myIcons = myIconArray
	Root.levelRoot.add_child(splashScreen)

	splashScreen.startExplosion()
	
	Root.levelRoot.playMusic()
	Root.playerCar.add_child(countdownScreen.instantiate())
	queue_free()
		
