extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	fillFromTop()

func fillFromTop():
	for y in 50:
		for x in 50:
			createIcon( Vector2( x * 40 , y * 40 - 20) )
		await get_tree().process_frame


	
var slotAwardIcon = preload("res://scene/player/slots/slot_award_icon.tscn")
func createIcon( screenPosition: Vector2):
	var newIcon = slotAwardIcon.instantiate()
	var myFlavor = randi_range(0,slotContents.size()-1)
	newIcon.type = slotContents[myFlavor].type
	newIcon.texture = load( slotContents[myFlavor].icon )
	newIcon.position = screenPosition
	add_child(newIcon)


func destory():
	for i in get_children():i.queue_free()
	queue_free()
	
	
	
var slotContents =[{
		"type":"purse",
		"icon":"res://texture/icon/purse.png",
		},
		{
		"type":"armor",
		"icon":"res://texture/icon/shield.png",
	},
	{
		"type":"gem",
		"icon":"res://texture/icon/icons8-gem-48.png",
	},
	{
		"type":"traction",
		"icon":"res://texture/icon/wheel.png",
	},
	{
		"type":"steering",
		"icon":"res://texture/icon/steering.png",
	},
	{
		"type":"engine",
		"icon":"res://texture/icon/engine.png",
	},
	{
		"type":"fuel",
		"icon":"res://texture/icon/gas.png",
	},
	{
		"type":"health",
		"icon":"res://texture/icon/heart.png",
	},
	{
		"type":"coin",
		"icon":"res://texture/icon/icons8-coin-48 (1).png",
	},
]
