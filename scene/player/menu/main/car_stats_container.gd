extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	$HBoxContainer/engine.setValue(Root.playerCar.engine )
	$HBoxContainer/steering.setValue(Root.playerCar.steering)
	$HBoxContainer/traction.setValue(Root.playerCar.traction)
	$HBoxContainer/armor.setValue(Root.playerCar.armor)
	$HBoxContainer/coin.setValue( SaveManager.playerData.coin )
	$HBoxContainer2/gem.setValue ( SaveManager.playerData.gem )
