extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	$Panel/Panel2/VBoxContainer/HBoxContainer6/goonsCrushed.text = str(Root.playerCar.currentGoonsCrushed)
	$Panel/Panel2/VBoxContainer/HBoxContainer3/topSpeed.text = str(int(Root.playerCar._highest_measured_speed/10)) + " MPH" 
	$Panel/Panel2/VBoxContainer/HBoxContainer7/time.text = str( get_tree().get_first_node_in_group("runTimer").text )
	
	$Panel/Panel2/VBoxContainer/HBoxContainer2/coinsCollected.text = str(Root.playerCar.coin)
	$Panel/Panel2/VBoxContainer/HBoxContainer4/powerups.text = str( Root.playerCar.powerupsCollected )
	$Panel/Panel2/VBoxContainer/HBoxContainer5/gems.text = str(Root.playerCar.gem)
	
	Root.earnedCoins = Root.playerCar.coin
	Root.earnedGems = Root.playerCar.gem
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_continue_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/player/menu/main/mainMenuCamera.tscn")
