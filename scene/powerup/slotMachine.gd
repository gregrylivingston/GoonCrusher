extends Powerup


	
	
func sendReward(body, forShowOnly: bool = false):
	Pickups.discover("slotmachine")
	Pickups.countCollected(body, "slotmachine")
	SlotMachine.open()
	queue_free()
	get_tree().paused = true
