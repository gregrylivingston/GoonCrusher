extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	Root.timer
	resetTimer()

var daylength = 120
var reset: bool = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Root.levelRoot.seconds -= delta
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
		Root.levelRoot.endLevel(true)

func resetTimer():
	await get_tree().create_timer(20).timeout
	reset = false
	
