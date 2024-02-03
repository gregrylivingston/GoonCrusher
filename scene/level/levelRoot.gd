class_name Level extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var playerCar: OverheadCarBody2D
var playerController
@export var seconds = 600

var isDaytime: bool = true

func _ready():

	#add my car
	var newPosition = $Car.position
	$Car.queue_free()
	if is_instance_valid(Root.playerCar): Root.playerCar.queue_free()
	Root.playerCar = Root.selectedCar.scene.instantiate()
	Root.playerCar.position = newPosition
	add_child(Root.playerCar)

	Root.levelRoot = self
	Root.isRunActive = true
	
	Root.playerRoot = get_tree().get_nodes_in_group("playerGameUi")[0]
	Root.playerRoot.get_node("carPanel").setTexture( Root.playerCar.get_node("sprite").texture )
	Root.playerRoot.updateStats()
	
	newSpawner( Vector2i(4000,250))
	newSpawner( Vector2i(4000,-250))
	newSpawner( Vector2i(4000,250))
	newSpawner( Vector2i(3500,1500))
	newSpawner( Vector2i(3500,-1500))
	newSpawner( Vector2i(-3500,0))
	
	match SaveManager.playerData.gameMode:
		Root.gameModes.DEFENSE:
			seconds = 0
		Root.gameModes.GOONPOCALYPSE:
			seconds = 0



func setNighttime(isNighttime: bool):

	if isNighttime:
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(.0,.0,.0,1.0) , 5)
			#if canvasmodulate this is set to .05 powerups and giants glow at night.  If set to 0 they don't
		await get_tree().create_timer(2).timeout
		Root.station.setNighttime(isNighttime)
		$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(1).timeout
		Root.playerCar.turnOnHeadlights(true)
	else: 
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(1.0,1.0,1.0,1.0) , 5)
		await get_tree().create_timer(1).timeout
		Root.station.setNighttime(isNighttime)
		#$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(2).timeout
		Root.playerCar.turnOnHeadlights(false)
	
func newSpawner( spawnerPosition: Vector2i ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	Root.playerCar.add_child(newSpawner)
	


	
func endLevel(levelCompleted: bool):
	var gameSummary = load("res://scene/player/menu/gameSummary.tscn").instantiate() 
	if levelCompleted:
		$AudioStreamPlayer.stream = load("res://sound/fx/slotmachine/winner_3.mp3")
		$AudioStreamPlayer.play()
		gameSummary.levelCompleted = true
	add_child( gameSummary )
	get_tree().paused = true
