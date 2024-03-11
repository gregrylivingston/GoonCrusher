extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass
#	$pauseButton.updateText( Root.gameModes.keys()[SaveManager.playerData.gameMode] )

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_instance_valid(Root.playerCar):
		$Panel/HBoxContainer2/speed.text = str(int(Root.playerCar.velocity.length())/10) + " MPH"
		%ProgressBar_Health.value = Root.playerCar.health
		%ProgressBar_Fuel.value = Root.playerCar.fuel

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
	get_tree().paused = true
	add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )
