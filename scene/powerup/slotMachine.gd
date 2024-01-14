extends Powerup


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	
var slotMachineScene = preload("res://scene/player/slots/slotMachine.tscn")

func sendReward(body, forShowOnly: bool = false):
	var newMachine = slotMachineScene.instantiate()
	Root.levelRoot.add_child(newMachine)
	queue_free()
	get_tree().paused = true
