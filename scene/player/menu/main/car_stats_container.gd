extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	$engine.setValue(Root.playerCar.max_engine_power )
	$steering.setValue(Root.playerCar.max_steering_degrees)
	$aero.setValue(Root.playerCar.brakes)
	$armor.setValue(Root.playerCar.armor)
