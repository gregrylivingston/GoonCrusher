extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	var myUpdates =  SaveManager.playerData.cars[Root.playerCar.carId].upgrades
	$HBoxContainer/engine.setValue(Root.playerCar.engine + myUpdates.engine)
	$HBoxContainer/steering.setValue(Root.playerCar.steering + myUpdates.steering)
	$HBoxContainer/traction.setValue(Root.playerCar.traction + myUpdates.traction)
	$HBoxContainer/armor.setValue(Root.playerCar.armor + myUpdates.armor)
	$HBoxContainer/coin.setValue( SaveManager.playerData.coin )
	$HBoxContainer2/gem.setValue ( SaveManager.playerData.gem )
	for i in [$HBoxContainer2/statUpgrade, $HBoxContainer2/statUpgrade2, $HBoxContainer2/statUpgrade3, $HBoxContainer2/statUpgrade4]:
		i.refresh()
