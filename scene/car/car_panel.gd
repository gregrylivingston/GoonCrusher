extends Panel

var speedTimer: float = 0.0

func _process(delta):
	if is_instance_valid(Root.playerCar):
		speedTimer -= delta
		if speedTimer <= 0.0: #the speedometer text updates 10 times a second
			speedTimer = 0.1
			$Panel/HBoxContainer2/speed.text = Settings.speed_text(Root.playerCar.velocity.length())
		if %ProgressBar_Health.value != Root.playerCar.health: %ProgressBar_Health.value = Root.playerCar.health
		if %ProgressBar_Fuel.value != Root.playerCar.fuel: %ProgressBar_Fuel.value = Root.playerCar.fuel

func updateStats():
	%attributeIndicator_engine.setValue("Engine   " + str(Root.playerCar.engine))
	%attributeIndicator_steering.setValue("Steering   " + str(Root.playerCar.steering))
	%attributeIndicator_aero.setValue("Traction   " + str(Root.playerCar.traction ))
	%attributeIndicator_armor.setValue("Armor   " + str(Root.playerCar.armor))
	%attributeIndicator_oil.setValue("Oil   " + str(Root.playerCar.oil))
	%attributeIndicator_headlights.setValue("Lights   " + str(Root.playerCar.headlights))
	%attributeIndicator_clover.setValue("Luck   " + str(Root.playerCar.clover))
	%attributeIndicator_luck.setValue("Dice   " + str(Root.playerCar.luck))

func _on_pause_button_pressed():
	Root.playerRoot.openPause()
