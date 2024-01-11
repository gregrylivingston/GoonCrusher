extends Label

var seconds = 0.0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	seconds += delta
	var clockSeconds = int(seconds)%60
	if clockSeconds < 10: clockSeconds = "0" + str(clockSeconds)
	text = str(int(seconds/60)) + " : " + str(clockSeconds)
