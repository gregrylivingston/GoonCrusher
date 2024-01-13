extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func updateStats():
	$Panel/TextureRect.texture = Root.playerCar.profilePic
	$engine.setValue(Root.playerCar.engine )
	$steering.setValue(Root.playerCar.steering)
	$aero.setValue(Root.playerCar.traction)
	$armor.setValue(Root.playerCar.armor)
