extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready():
	$Panel2/HBoxContainer/coins.add_to_group("coinui")
	$Panel4/HBoxContainer/TextureRect.add_to_group("gemui")
	if is_instance_valid(Root.playerCar):
		updateStats()
	else: await get_tree().create_timer(1).timeout
	updateStats()
	Root.playerCar.ui = self
	$Panel/ProgressBar.value = 0
	$Panel/ProgressBar.max_value = awardBase
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Panel2/HBoxContainer/coins.text = str( Root.playerCar.coin )
	$Panel4/HBoxContainer/gem.text = str( Root.playerCar.gem )


func updateStats():$carPanel.updateStats()

var awardBase = 20
var crushingAwardLevel = 0
var nextCrushingAward = awardBase
@onready var crushProgressBar = $Panel/ProgressBar

func updateGoonsCrushed():
	$Panel/HBoxContainer/crushedGoons.text = str( Root.playerCar.currentGoonsCrushed )
	crushProgressBar.value = Root.playerCar.currentGoonsCrushed
	if Root.playerCar.currentGoonsCrushed >= nextCrushingAward:
		crushProgressBar.min_value = nextCrushingAward
		crushingAwardLevel += 1 
		nextCrushingAward = pow(( crushingAwardLevel + 1 ), 1.8) * awardBase
		crushProgressBar.max_value = nextCrushingAward

		#create award
		var slotMachineScene = preload("res://scene/player/slots/slotMachine.tscn")
		var newMachine = slotMachineScene.instantiate()
		Root.levelRoot.add_child(newMachine)
		get_tree().paused = true

	
#responsiveness
#aerodynamics
#weight
#armor

