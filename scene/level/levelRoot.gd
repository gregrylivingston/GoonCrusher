extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var playerCar: OverheadCarBody2D
var playerController
var seconds = 0

func _ready():
	updateAudioLevels()
	#add my car
	var newPosition = $Car.position
	$Car.queue_free()
	if is_instance_valid(Root.playerCar): Root.playerCar.queue_free()
	Root.playerCar = Root.selectedCar.scene.instantiate()
	Root.playerCar.position = newPosition
	add_child(Root.playerCar)

	Root.levelRoot = self
	Root.isRunActive = true
	
	Root.playerCar.ui = get_tree().get_nodes_in_group("playerGameUi")[0]
	Root.playerCar.ui.get_node("carPanel").setTexture( Root.playerCar.get_node("sprite").texture )
	Root.playerCar.ui.updateStats()
	
	newSpawner( Vector2i(4000,250))
	newSpawner( Vector2i(4000,-250))
	newSpawner( Vector2i(4000,250))
	newSpawner( Vector2i(3500,1500))
	newSpawner( Vector2i(3500,-1500))
	newSpawner( Vector2i(-3500,0))
	



func setNighttime():
	get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(.0,.0,.0,1.0) , 10)
	await get_tree().create_timer(5).timeout
	$AudioStreamPlayer_wolf.play()
	await get_tree().create_timer(2).timeout
	Root.playerCar.turnOnHeadlights()
	
func newSpawner( spawnerPosition: Vector2i ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	Root.playerCar.add_child(newSpawner)
	
func updateAudioLevels():
	$AudioStreamPlayer2.volume_db = -8 + SaveManager.getVolume( "music" )
	
func reduceMusic():
	$AudioStreamPlayer2.volume_db = -18 + SaveManager.getVolume( "music" )
	
func playMusic():
	$AudioStreamPlayer2.volume_db = -8 + SaveManager.getVolume( "music" )
