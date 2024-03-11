extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	$HBoxContainer/engine.setValue("Engine   " + str(Root.playerCar.engine + SaveManager.getUpgradeLevel(Root.upgrade.ENGINE)) )
	$HBoxContainer/steering.setValue("Steering   " + str(Root.playerCar.steering +SaveManager.getUpgradeLevel(Root.upgrade.STEERING) ))
	$HBoxContainer/traction.setValue("Traction   " + str( Root.playerCar.traction + SaveManager.getUpgradeLevel(Root.upgrade.TRACTION) ))
	$HBoxContainer/armor.setValue("Armor   "   + str(Root.playerCar.armor + SaveManager.getUpgradeLevel(Root.upgrade.ARMOR) ))
	%coin.setValue( SaveManager.playerData.coin )
	
	%headlights.setValue("Lights   " + str(Root.playerCar.headlights + SaveManager.getUpgradeLevel(Root.upgrade.HEADLIGHTS) ))
	%oil.setValue("Oil   " + str(Root.playerCar.oil +SaveManager.getUpgradeLevel(Root.upgrade.OIL) ))
	%clover.setValue("Luck  " + str(Root.playerCar.clover + SaveManager.getUpgradeLevel(Root.upgrade.CLOVER) ))
	%luck.setValue("Dice   " + str(Root.playerCar.luck + SaveManager.getUpgradeLevel(Root.upgrade.LUCK) ))
	
	for i in [$HBoxContainer2/statUpgrade, $HBoxContainer2/statUpgrade2, $HBoxContainer2/statUpgrade3, $HBoxContainer2/statUpgrade4]:
		i.refresh()
	for i in [$HBoxContainer4/statUpgrade, $HBoxContainer4/statUpgrade2, $HBoxContainer4/statUpgrade3, $HBoxContainer4/statUpgrade4]:
		i.refresh()
