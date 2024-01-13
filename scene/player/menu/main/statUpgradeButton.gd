extends roadButton

@export var myStat: String

# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	refresh()
	
func refresh():
	text = str(SaveManager.requestStatCost(myStat)) + "  +1 " + myStat


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_upgrade_pressed():
	SaveManager.requestStatUpgrade(myStat)
