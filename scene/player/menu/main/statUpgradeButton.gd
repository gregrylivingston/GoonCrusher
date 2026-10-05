extends roadButton

@export var myStat: Root.upgrade

# Called when the node enters the scene tree for the first time.
func _ready():
	super()
	refresh()
	
func refresh():
	if is_instance_valid(Root.carInfo):
		var requestCost = SaveManager.requestStatCost(myStat)
		var carLocked = SaveManager.getCarByName(Root.carInfo.carId).cost != 0
		var maxed = SaveManager.isUpgradeMaxed(myStat)
		updateText("MAX" if maxed else str(requestCost))
		$HBoxContainer/TextureRect.visible = not maxed #the coin icon goes with a price

		#a maxed stat shows "MAX" (locked); if the player cannot afford the cost or has not unlocked the car hide and lock this button.
		if maxed && not carLocked:
			disabled = true
			modulate.a = 1.0
		elif requestCost > SaveManager.playerData.coin || carLocked:
			disabled = true
			modulate.a = 0.0
		else: 
			disabled = false
			modulate.a = 1.0
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		refresh()


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
