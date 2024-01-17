extends Label


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

var isDaytime: bool = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	Root.levelRoot.seconds += delta
	var clockSeconds = int(Root.levelRoot.seconds )%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(Root.levelRoot.seconds /60)) + " : " + str(clockSeconds)
	
	if int(Root.levelRoot.seconds )==60 && isDaytime:
		isDaytime = false
		Root.levelRoot.setNighttime()
