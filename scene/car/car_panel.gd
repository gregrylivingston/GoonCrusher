extends Panel

#The car's stat list, shown only while the run is paused (group "visibleWhenPaused"). Health, fuel and
#speed moved to the HUD gauges in scene/player/hud.

func updateStats():
	%attributeIndicator_engine.setValue("Engine   " + str(Root.playerCar.engine))
	%attributeIndicator_steering.setValue("Steering   " + str(Root.playerCar.steering))
	%attributeIndicator_aero.setValue("Traction   " + str(Root.playerCar.traction ))
	%attributeIndicator_armor.setValue("Armor   " + str(Root.playerCar.armor))
	%attributeIndicator_oil.setValue("Oil   " + str(Root.playerCar.oil))
	%attributeIndicator_headlights.setValue("Lights   " + str(Root.playerCar.headlights))
	%attributeIndicator_clover.setValue("Clover   " + str(Root.playerCar.clover))
	%attributeIndicator_luck.setValue("Dice   " + str(Root.playerCar.luck))
