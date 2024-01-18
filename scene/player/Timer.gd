extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

var daylength = 60
var isDaytime: bool = true
var reset: bool = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Root.levelRoot.seconds += delta
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	
	if int(Root.levelRoot.seconds )% daylength == 0 && isDaytime && not reset:
		isDaytime = false
		reset = true
		Root.levelRoot.setNighttime(true)
		resetTimer()
	elif int(Root.levelRoot.seconds )% daylength == 0 && not isDaytime && not reset:
		isDaytime = true
		reset = true
		Root.levelRoot.setNighttime(false)
		resetTimer()

func resetTimer():
	await get_tree().create_timer(10).timeout
	reset = false
	
