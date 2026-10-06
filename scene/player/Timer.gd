extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	showTimer()
	Settings.changed.connect(onSettingChanged)
	#every mode counts down except Goonpocalypse, which counts up from 0
	if SaveManager.playerData.gameMode == Root.gameModes.GOONPOCALYPSE: timeIsCountingDown = 1

	await get_tree().process_frame
	showTime()
	resetTimer()

var daylength = 60
var reset: bool = true  #prevents level from switching immediately, reset timer on daytimeaa
var timeIsCountingDown = -1 #set to negative one for a countdown game

var clockReady := false #the clock waits for the level's final starting time (Level.onWorldReady)

var shownSecond = -1

#called by Level.onWorldReady (group "runTimer") once the starting time is final
func onClockReady() -> void:
	clockReady = true
	showTime()

func _process(delta):
	if not clockReady: return
	Root.levelRoot.seconds += delta * timeIsCountingDown
	Root.levelRoot.elapsed += delta
	Root.levelRoot.onClockTick()
	if timeIsCountingDown < 0 && Root.levelRoot.seconds <= 0.0:
		#the clock ran out: Countdown and Defense are won, Sprint and Marathon are lost (Level.timeUpCondition)
		Root.levelRoot.seconds = 0.0
		showTime()
		Root.levelRoot.timeRanOut()
		return
	showTime()

	if int(Root.levelRoot.seconds )% daylength == 0:dayNightCycle()

#a countdown shows the whole seconds left, rounded up so 0:00 means time is up; a count-up shows
#whole seconds elapsed. Never below 0:00.
func showTime() -> void:
	var displayed = ceili(Root.levelRoot.seconds) if timeIsCountingDown < 0 else int(Root.levelRoot.seconds)
	displayed = maxi(displayed, 0)
	if displayed != shownSecond:
		shownSecond = displayed
		text = formatClock(displayed)

static func formatClock(totalSeconds: int) -> String:
	totalSeconds = maxi(totalSeconds, 0)
	var clockSeconds = totalSeconds % 60
	return str(totalSeconds / 60) + " : " + ("0" if clockSeconds < 10 else "") + str(clockSeconds)

	

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
	
