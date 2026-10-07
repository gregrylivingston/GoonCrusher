extends Powerup


	
	
var slotMachineScene = preload("res://scene/player/slots/slotMachine.tscn")

func sendReward(body, forShowOnly: bool = false):
	Pickups.discover("slotmachine")
	Pickups.countCollected(body, "slotmachine")
	var newMachine = slotMachineScene.instantiate()
	Root.levelRoot.add_child(newMachine)
	queue_free()
	get_tree().paused = true
