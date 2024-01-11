extends CanvasLayer

var carPanel = preload("res://scene/car/menuCar.tscn")


# Called when the node enters the scene tree for the first time.
func _ready():
	Root.mainMenu = self
	pass # Replace with function body.
	for car in Root.cars:
		var newPanel = carPanel.instantiate()
		newPanel.carData = Root.cars[car]
		
		var newCar = Root.cars[car].scene.instantiate()
		newPanel.setTexture(newCar.get_node("sprite").texture )
		newCar.queue_free()
	
		newPanel.scale = Vector2(.5,.5)
		$TabContainer/Ride/carGrid.add_child(newPanel)
		
	selectCar(Root.cars.sedan)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_begin_button_pressed():
	get_tree().change_scene_to_file("res://scene/level/levelRoot.tscn")


func _on_quit_button_pressed():
	get_tree().quit()


func selectCar(car):
	Root.selectedCar = car
	var targetPosition = $carSpawnTarget.position
	var targetRotation = 0
	if is_instance_valid(Root.playerCar):
		targetPosition = Root.playerCar.position
		targetRotation = Root.playerCar.rotation
		Root.playerCar.queue_free()
	await get_tree().process_frame
	Root.playerCar = car.scene.instantiate()
	Root.playerCar.position = targetPosition
	Root.playerCar.rotation = targetRotation
	
	get_parent().add_child(Root.playerCar)
	$carStatsContainer.updateStats()


