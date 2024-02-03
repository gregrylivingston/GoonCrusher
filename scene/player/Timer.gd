extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	match SaveManager.playerData.gameMode:
		Root.gameModes.DEFENSE:
			timeIsCountingDown = 1
		Root.gameModes.GOONPOCALYPSE:
			timeIsCountingDown = 1
		
	await get_tree().process_frame
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	resetTimer()

var daylength = 120
var reset: bool = true  #prevents level from switching immediately, reset timer on daytimeaa
var timeIsCountingDown = -1 #set to negative one for a countdown game

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Root.levelRoot.seconds += delta * timeIsCountingDown
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	
	if int(Root.levelRoot.seconds )% daylength == 0 && Root.levelRoot.isDaytime && not reset:
		Root.levelRoot.isDaytime = false
		reset = true
		Root.levelRoot.setNighttime(true)
		resetTimer()
	elif int(Root.levelRoot.seconds )% daylength == 0 && not Root.levelRoot.isDaytime && not reset:
		Root.levelRoot.isDaytime = true
		reset = true
		Root.levelRoot.setNighttime(false)
		resetTimer()
		
	if Root.levelRoot.seconds <= 0.01:
		match SaveManager.playerData.gameMode:
			Root.gameModes.COUNTDOWN:Root.levelRoot.endLevel(true , Root.endCondition.SUCCESS )
			Root.gameModes.SPRINT:Root.levelRoot.endLevel(false , Root.endCondition.NOTIME )
			Root.gameModes.MARATHON:Root.levelRoot.endLevel(false , Root.endCondition.NOTIME )

func resetTimer():
	await get_tree().create_timer(20).timeout
	reset = false
	
