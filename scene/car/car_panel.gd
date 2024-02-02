extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	$pauseButton.updateText( Root.gameModes.keys()[SaveManager.playerData.gameMode] )
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_engine.add_to_group("max_engine_powerui")
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_steering.add_to_group("max_steering_degreesui")
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_aero.add_to_group("wheelui")
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_armor.add_to_group("armorui")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_instance_valid(Root.playerCar):
		$Panel/HBoxContainer2/speed.text = str(int(Root.playerCar.velocity.length())/10) + " MPH"
		$HBoxContainer/ProgressBar_Health.value = Root.playerCar.health
		$HBoxContainer2/ProgressBar_Fuel.value = Root.playerCar.fuel

func updateStats():
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_engine.setValue(Root.playerCar.engine)
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_steering.setValue(Root.playerCar.steering)
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_aero.setValue( Root.playerCar.traction )
	$VBoxContainer/Panel/HBoxContainer/attributeIndicator_armor.setValue(Root.playerCar.armor)
	
func setTexture(texture):
	$VBoxContainer/CenterContainer/TextureRect.texture = texture




func _on_pause_button_pressed():
	get_tree().paused = true
	add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )
