extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var playerCar

func _ready():
	
	#add my car
	var newPosition = $Car.position
	$Car.queue_free()
	if is_instance_valid(Root.playerCar): Root.playerCar.queue_free()
	Root.playerCar = Root.selectedCar.scene.instantiate()
	Root.playerCar.position = newPosition
	add_child(Root.playerCar)

	Root.levelRoot = self
	
	Root.playerCar.ui = get_tree().get_nodes_in_group("playerGameUi")[0]
	Root.playerCar.ui.get_node("carPanel").setTexture( Root.playerCar.get_node("sprite").texture )
	Root.playerCar.ui.updateStats()
	
	newSpawner( Vector2i(3000,250))
	newSpawner( Vector2i(3000,-250))
	newSpawner( Vector2i(3000,250))
	newSpawner( Vector2i(2500,1500))
	newSpawner( Vector2i(2500,-1500))
	newSpawner( Vector2i(-2500,0))	
	
func newSpawner( spawnerPosition: Vector2i ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	Root.playerCar.add_child(newSpawner)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
