extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	$HBoxContainer/engine.setValue(Root.playerCar.engine + SaveManager.getUpgradeLevel(Root.upgrade.ENGINE) )
	$HBoxContainer/steering.setValue(Root.playerCar.steering +SaveManager.getUpgradeLevel(Root.upgrade.STEERING) )
	$HBoxContainer/traction.setValue(Root.playerCar.traction + SaveManager.getUpgradeLevel(Root.upgrade.TRACTION) )
	$HBoxContainer/armor.setValue(Root.playerCar.armor + SaveManager.getUpgradeLevel(Root.upgrade.ARMOR) )
	$HBoxContainer/coin.setValue( SaveManager.playerData.coin )
	$HBoxContainer2/gem.setValue ( SaveManager.playerData.gem )
	for i in [$HBoxContainer2/statUpgrade, $HBoxContainer2/statUpgrade2, $HBoxContainer2/statUpgrade3, $HBoxContainer2/statUpgrade4]:
		i.refresh()
