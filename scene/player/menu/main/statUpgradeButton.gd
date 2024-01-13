extends roadButton

@export var myStat: String




# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	refresh()
	
func refresh():
	var requestCost = SaveManager.requestStatCost(myStat)
	text = str(SaveManager.requestStatCost(myStat)) + "  +1 " + myStat
	if requestCost > SaveManager.playerData.coin: disabled = true
	else: disabled = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_upgrade_pressed():
	if SaveManager.requestStatUpgrade(myStat):
		sendReward(Root.playerCar)
	
	

	
func sendReward(body):
	var powerupScene = load("res://scene/powerup/" + myStat + ".tscn")
	var newPowerup = powerupScene.instantiate()
	newPowerup.global_position = Root.playerCar.global_position
	Root.playerCar.get_parent().add_child(newPowerup)
	newPowerup.sendReward(body, true)
	body.playPurseRewardAudio()	
	Root.mainMenu.uiUpdate()

