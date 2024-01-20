extends roadButton

@export var myStat: String

# Called when the node enters the scene tree for the first time.
func _ready():
	refresh()
	
func refresh():
	if is_instance_valid(Root.playerCar):
		var requestCost = SaveManager.requestStatCost(myStat)
		text = str(SaveManager.requestStatCost(myStat))
		if requestCost > SaveManager.playerData.coin: 
			disabled = true
			modulate.a = 0.0
		else: 
			disabled = false
			modulate.a = 1.0
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		refresh()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_upgrade_pressed():
	if SaveManager.requestStatUpgrade(myStat):
		#sendReward(Root.playerCar)
		refresh()
		Root.mainMenu.statUpdatesUiUpdate()
	

	
func sendReward(body):
	var powerupScene = load("res://scene/powerup/" + myStat + ".tscn")
	var newPowerup = powerupScene.instantiate()
	newPowerup.global_position = Root.playerCar.global_position
	Root.playerCar.get_parent().add_child(newPowerup)
	newPowerup.sendReward(body, true)
	body.playPurseRewardAudio()	
	Root.mainMenu.uiUpdate()

