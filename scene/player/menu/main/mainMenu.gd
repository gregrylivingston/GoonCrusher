extends CanvasLayer




func _ready():
	Root.mainMenu = self
	createCarArray()
	selectCar(Root.cars.sedan)
	await get_tree().process_frame
	if Root.isRunActive:
		Root.isRunActive = false
		SaveManager.addCoins( Root.earnedCoins )
		SaveManager.addGems( Root.earnedGems )
		Root.earnedCoins = 0
		Root.earnedGems = 0
	uiUpdate()

var carPanel = preload("res://scene/car/menuCar.tscn")
func createCarArray():
	for i in $TabContainer/Ride/carGrid.get_children():i.queue_free()
	for car in Root.cars:
		var newPanel = carPanel.instantiate()
		newPanel.carData = Root.cars[car]
		
		var newCar = Root.cars[car].scene.instantiate()
		newPanel.setTexture(newCar.get_node("sprite").texture )
		newCar.queue_free()
	
		if SaveManager.playerData.cars[car].cost != 0:
			newPanel.setLocked()
	
		newPanel.scale = Vector2(.3,.3)
		$TabContainer/Ride/carGrid.add_child(newPanel)


func _on_begin_button_pressed():
	get_tree().change_scene_to_file("res://scene/level/levelRoot.tscn")


func _on_quit_button_pressed():
	get_tree().quit()


func selectCar(car):
	Root.selectedCar = car
	var targetPosition = $carSpawnTarget.position
	var targetRotation = 0
	if is_instance_valid(Root.playerCar):
		targetPosition = Root.playerCar.position
		targetRotation = Root.playerCar.rotation
		Root.playerCar.queue_free()
	await get_tree().process_frame
	Root.playerCar = car.scene.instantiate()
	Root.playerCar.position = targetPosition
	Root.playerCar.rotation = targetRotation
	
	get_parent().add_child(Root.playerCar)
	$carStatsContainer.updateStats()
	$carStatUpgrades/Panel/charName.text = Root.playerCar.charName
	
	if Root.playerCar.introAudio.size() > 0:
		$voicePlayer.stream = Root.playerCar.introAudio[randi_range(0 , Root.playerCar.introAudio.size()-1)]
		$voicePlayer.play()
		
	var statUpgradeButtons = [$carStatUpgrades/statUpgrade, $carStatUpgrades/statUpgrade2, $carStatUpgrades/statUpgrade3, $carStatUpgrades/statUpgrade4]
	var unlockButton = $carStatUpgrades/unlockButton
	
	if SaveManager.playerData.cars[Root.playerCar.carId].cost != 0:
		for i in statUpgradeButtons:i.visible = false
		unlockButton.visible = true
		unlockButton.text = "Unlock      " + str( SaveManager.playerData.cars[Root.playerCar.carId].cost )
		$Panel2/VBoxContainer/beginButton.disabled = true
	else:
		for i in statUpgradeButtons:i.visible = true
		unlockButton.visible = false
		$Panel2/VBoxContainer/beginButton.disabled = false
		

func uiUpdate():
	$myCoins.setValue( SaveManager.playerData.coin )
	$myGems.setValue ( SaveManager.playerData.gem )


func _on_free_money_button_pressed():
	SaveManager.addGems( 25 )
	SaveManager.addCoins( 1000 )

	


func _on_unlock_button_pressed():
	if SaveManager.unlockCar():
		createCarArray()
		selectCar(Root.cars[Root.playerCar.carId])
		uiUpdate()
