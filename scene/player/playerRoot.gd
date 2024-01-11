extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready():
	$Panel2/HBoxContainer/coins.add_to_group("coinui")
	if is_instance_valid(Root.playerCar):
		updateStats()
	else: await get_tree().create_timer(1).timeout
	updateStats()
	Root.playerCar.ui = self
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Panel/HBoxContainer/crushedGoons.text = str( Root.currentGoonsCrushed )
	$Panel2/HBoxContainer/coins.text = str( Root.playerCar.coin )
	$Panel4/HBoxContainer/gem.text = str( Root.playerCar.gem )


func updateStats():$carPanel.updateStats()

	
	
	
#responsiveness
#aerodynamics
#weight
#armor

