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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass




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


func _on_claim_button_pressed():
	get_tree().paused = false
	myBackground.destory()
	visible = false
	for slot in [$Panel/Panel/Panel2/HBoxContainer/slotRow, $Panel/Panel/Panel2/HBoxContainer/slotRow2, $Panel/Panel/Panel2/HBoxContainer/slotRow3]:
		var newPowerup = Root.getSpecificPowerup(slot.getActiveType())
		newPowerup.global_position = Root.playerCar.global_position
		Root.levelRoot.add_child(newPowerup)
		#newPowerup.sendReward(Root.playerCar, false)
	Root.levelRoot.playMusic()
	queue_free()
		
