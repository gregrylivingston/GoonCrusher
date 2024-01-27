extends CanvasLayer

var isGameSummary: bool = true #alternative is achievements menu for now
var levelCompleted: bool = false #did the player successfully complete their run.

# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if isGameSummary: buildGameSummary()
	else: buildAchievementSummary()

	
func buildGameSummary():
	
	%wasSuccessful.visible = true
	if levelCompleted:
		SaveManager.currentLevelPassed()
	else:
		%wasSuccessful.text = "LEVEL FAILED"
	
	var carStats = SaveManager.getCarByName(Root.playerCar.carId)
	
			#"records":{"time":0,"gem":0,"coin":0,"speed":0,"goonsCrushed":0,"slotMachines":0,"powerups":0,},
	var crushed = Root.playerCar.currentGoonsCrushed
	if crushed > carStats.records.goonsCrushed: 
		carStats.records.goonsCrushed = crushed
	$Panel/Panel2/VBoxContainer/HBoxContainer6/goonsCrushed.text = str(Root.playerCar.currentGoonsCrushed)
	
	var topSpeed = int(Root.playerCar._highest_measured_speed/10)
	if topSpeed > carStats.records.speed: 
		carStats.records.speed = topSpeed
	$Panel/Panel2/VBoxContainer/HBoxContainer3/topSpeed.text = str(topSpeed) + " MPH" 
	
	$Panel/Panel2/VBoxContainer/HBoxContainer7/time.text = str( get_tree().get_first_node_in_group("runTimer").text )
	
	var coin = Root.playerCar.coin
	if coin > carStats.records.coin: 
		carStats.records.coin = coin
	$Panel/Panel2/VBoxContainer/HBoxContainer2/coinsCollected.text = str(Root.playerCar.coin)
	
	var powerups = Root.playerCar.powerupsCollected
	if powerups > carStats.records.powerups: 
		carStats.records.powerups = powerups
	$Panel/Panel2/VBoxContainer/HBoxContainer4/powerups.text = str( powerups )
	
	var gem = Root.playerCar.gem
	if gem > carStats.records.gem: 
		carStats.records.gem = gem
	$Panel/Panel2/VBoxContainer/HBoxContainer5/gems.text = str(gem)
	
	var slotMachines = Root.playerCar.slotMachines
	if slotMachines > carStats.records.slotMachines: 
		carStats.records.slotMachines = slotMachines

	$Panel/Panel2/VBoxContainer/HBoxContainer8/slotMachines.text = str(slotMachines)
	Root.earnedCoins = coin
	Root.earnedGems = gem
	SaveManager.save_character_data()
	


func buildAchievementSummary():
	var carStats = SaveManager.getCarByName(Root.playerCar.carId)
	$Panel/Panel2/VBoxContainer/HBoxContainer6/goonsCrushed.text = str(carStats.records.goonsCrushed)
	$Panel/Panel2/VBoxContainer/HBoxContainer3/topSpeed.text = str(carStats.records.speed) + " MPH" 
	$Panel/Panel2/VBoxContainer/HBoxContainer7/time.visible = false
	
	$Panel/Panel2/VBoxContainer/HBoxContainer2/coinsCollected.text = str(carStats.records.coin)
	$Panel/Panel2/VBoxContainer/HBoxContainer4/powerups.text = str( carStats.records.powerups )
	$Panel/Panel2/VBoxContainer/HBoxContainer5/gems.text = str(carStats.records.gem)
	
	$Panel/Panel2/VBoxContainer/HBoxContainer8/slotMachines.text = str(carStats.records.slotMachines)
	



func _on_continue_pressed():
	queue_free()
	if isGameSummary:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")
	
