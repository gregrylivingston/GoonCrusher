extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	showTimer()
	Settings.changed.connect(onSettingChanged)
	match SaveManager.playerData.gameMode:
		Root.gameModes.DEFENSE:
			timeIsCountingDown = 1
		Root.gameModes.GOONPOCALYPSE:
			timeIsCountingDown = 1
		Root.gameModes.GOONCRUSHER:
			timeIsCountingDown = 1
		
	await get_tree().process_frame
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	resetTimer()

var daylength = 60
var reset: bool = true  #prevents level from switching immediately, reset timer on daytimeaa
var timeIsCountingDown = -1 #set to negative one for a countdown game

var shownSecond = -1

func _process(delta):
	Root.levelRoot.seconds += delta * timeIsCountingDown
	if int(Root.levelRoot.seconds) != shownSecond:
		shownSecond = int(Root.levelRoot.seconds)
		var clockSeconds = shownSecond % 60
		text = str(shownSecond / 60) + " : " + ("0" if clockSeconds < 10 else "") + str(clockSeconds)
	
	if int(Root.levelRoot.seconds )% daylength == 0:dayNightCycle()
	
	
	#There are no longer any game modes counting down.  When there was this code would end the game.
	#if Root.levelRoot.seconds <= 0.01:
	#	match SaveManager.playerData.gameMode:
	#		Root.gameModes.GOONCRUSHER:Root.levelRoot.endLevel(true , Root.endCondition.SUCCESS )
	#		Root.gameModes.SPRINT:Root.levelRoot.endLevel(false , Root.endCondition.NOTIME )
	#		Root.gameModes.MARATHON:Root.levelRoot.endLevel(false , Root.endCondition.NOTIME )

	

func dayNightCycle() -> void:
	if Root.levelRoot.isDaytime && not reset:
		Root.levelRoot.isDaytime = false
		reset = true
		Root.levelRoot.setNighttime(true)
		resetTimer()
	elif  not Root.levelRoot.isDaytime && not reset:
		Root.levelRoot.isDaytime = true
		reset = true
		Root.levelRoot.setNighttime(false)
		resetTimer()


func onSettingChanged(key: String, _value) -> void:
	if key == "gameplay/show_timer": showTimer()

#hidden with modulate so the HUD layout does not shift
func showTimer() -> void:
	modulate.a = 1.0 if Settings.get_value("gameplay/show_timer") else 0.0

func resetTimer():
	await get_tree().create_timer(20).timeout
	reset = false
	
