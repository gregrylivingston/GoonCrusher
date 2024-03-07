class_name GameUI
extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if is_instance_valid(Root.playerCar):
		updateStats()
	else: await get_tree().create_timer(1).timeout
	updateGoonsCrushed()
	updateStats()
	Root.playerRoot = self
	%ProgressBar.value = 0
	%ProgressBar.max_value = awardBase
	add_child(load("res://scene/player/countdown.tscn").instantiate())
	


	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_menu") && get_tree().get_nodes_in_group("pauseMenu").size() == 0 && not get_tree().paused:
		get_tree().paused = true
		for i in get_tree().get_nodes_in_group("visibleWhenPaused"):i.visible = true
		add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )
	%coins.text = str( Root.playerCar.coin )
	%gem.text = str( Root.playerCar.gem )
	%star.text = str(Root.playerCar.star)
	%coinProjection.text = str(Root.playerCar.coin * Root.playerCar.star)

func updateStats():$carPanel.updateStats()

var awardBase = 12
var crushingAwardLevel = 0
var nextCrushingAward = awardBase
@onready var crushProgressBar = %ProgressBar

func updateGoonsCrushed():
	%crushedGoons.text = str( int(nextCrushingAward) - Root.playerCar.currentGoonsCrushed  )
	crushProgressBar.value = Root.playerCar.currentGoonsCrushed
	if Root.playerCar.currentGoonsCrushed >= nextCrushingAward && not Root.playerCar.isDestroyed && not get_tree().paused:
		crushProgressBar.min_value = nextCrushingAward
		crushingAwardLevel += 1
		Root.playerCar.star += 1


		get_tree().paused = true
		
		#create award
		var slotMachineScene = preload("res://scene/player/slots/slotMachine.tscn")
		var newMachine = slotMachineScene.instantiate()
		newMachine.isGoonCrushBonus = true
		Root.levelRoot.add_child(newMachine)





func updatePlayerRegion(tile) ->void:
	%regionUi.updatePlayerRegion(tile)


func animateNewGoonCrushGoal(animatebackwards: bool = true) -> void:
	if animatebackwards:
		$AnimationPlayer.play_backwards("NewGoonCrushBonus")
		nextCrushingAward = pow(( crushingAwardLevel + 1 ), 1.8) * awardBase
		crushProgressBar.max_value = nextCrushingAward
		%crushedGoons.text = str( int(nextCrushingAward) - Root.playerCar.currentGoonsCrushed  )		
	else:
		$AnimationPlayer.play("NewGoonCrushBonus")
		
func animateNewRegion(animatebackwards: bool = true) -> void:
	if animatebackwards:
		$AnimationPlayer.play_backwards("NewWave")
	else:
		$AnimationPlayer.play("NewWave")
