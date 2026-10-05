extends HBoxContainer


func updateStats():
	$HBoxContainer/engine.setValue("Engine   " + str(Root.carInfo.engine + SaveManager.getUpgradeLevel(Root.upgrade.ENGINE)) )
	$HBoxContainer/steering.setValue("Steering   " + str(Root.carInfo.steering +SaveManager.getUpgradeLevel(Root.upgrade.STEERING) ))
	$HBoxContainer/traction.setValue("Traction   " + str( Root.carInfo.traction + SaveManager.getUpgradeLevel(Root.upgrade.TRACTION) ))
	$HBoxContainer/armor.setValue("Armor   "   + str(Root.carInfo.armor + SaveManager.getUpgradeLevel(Root.upgrade.ARMOR) ))
	%coin.setValue( SaveManager.playerData.coin )
	
	%headlights.setValue("Lights   " + str(Root.carInfo.headlights + SaveManager.getUpgradeLevel(Root.upgrade.HEADLIGHTS) ))
	%oil.setValue("Oil   " + str(Root.carInfo.oil +SaveManager.getUpgradeLevel(Root.upgrade.OIL) ))
	%clover.setValue("Clover   " + str(Root.carInfo.clover + SaveManager.getUpgradeLevel(Root.upgrade.CLOVER) ))
	%luck.setValue("Dice   " + str(Root.carInfo.luck + SaveManager.getUpgradeLevel(Root.upgrade.LUCK) ))
	
	for i in [$HBoxContainer2/statUpgrade, $HBoxContainer2/statUpgrade2, $HBoxContainer2/statUpgrade3, $HBoxContainer2/statUpgrade4]:
		i.refresh()
	for i in [$HBoxContainer4/statUpgrade, $HBoxContainer4/statUpgrade2, $HBoxContainer4/statUpgrade3, $HBoxContainer4/statUpgrade4]:
		i.refresh()

func setCoinDisplay(value: int) -> void:
	%coin.setValue(value)
