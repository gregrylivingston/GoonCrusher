extends CanvasLayer

var isGameSummary: bool = true #alternative is achievements menu for now
var levelCompleted: bool = false #did the player successfully complete their run.

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if isGameSummary: buildGameSummary()
	else: buildAchievementSummary()
	$Panel/Panel2/VBoxContainer/continue.grab_focus()

var summaryTimer:float = -2.0
var summaryComplete: bool = false

func _process(delta):
	if isGameSummary && not summaryComplete:
		summaryTimer += delta
		if summaryTimer > 0.5:
			if advanceSummary():
				summaryTimer = 0.0
				$AudioStreamPlayer2_lowImpact.play()
			else: summaryComplete = true
		
func advanceSummary():
	for i in $Panel/Panel2/VBoxContainer.get_children():
		if i.visible == false:
			i.visible = true
			return true
	return false #returns false if there is nothing left to make visible



func buildGameSummary():
	
	%wasSuccessful.self_modulate.a = 1.0
	$Panel/Panel2.self_modulate.a = 0.0
	Root.playerRoot.visible = false
	if levelCompleted:
		SaveManager.currentLevelPassed()
	else:
		%wasSuccessful.text = "YOU GOT GOONED"
		$AudioStreamPlayer_highImpact.play()			

	
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
	for i in $Panel/Panel2/VBoxContainer.get_children():i.visible = true
	
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
	
