extends roadButton

@export var myStat: Root.upgrade

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	refresh()
	
func refresh():
	if is_instance_valid(Root.playerCar):
		var requestCost = SaveManager.requestStatCost(myStat)
		updateText(str(SaveManager.requestStatCost(myStat)))
		
		#if the player cannot afford the cost or has not unlocked the car hide and lock this button.
		if requestCost > SaveManager.playerData.coin || SaveManager.getCarByName(Root.playerCar.carId).cost != 0: 
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
		$AudioStreamPlayer3.play()
		refresh()
		Root.mainMenu.statUpdatesUiUpdate()
	

	
func sendReward(body):
	var powerupScene = load("res://scene/powerup/" + Root.upgrade.keys()[myStat].to_lower() + ".tscn")
	var newPowerup = powerupScene.instantiate()
	newPowerup.global_position = Root.playerCar.global_position
	Root.playerCar.get_parent().add_child(newPowerup)
	newPowerup.sendReward(body, true)
	body.playPurseRewardAudio()	
	Root.mainMenu.uiUpdate()

