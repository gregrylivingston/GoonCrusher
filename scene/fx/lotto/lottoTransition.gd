extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready():
	var columns = get_viewport().size.x / 40
	var rows = get_viewport().size.y / 40
	var picker = randi_range(0,2)
	if picker == 0:fillFromTop(columns, rows)
	elif picker == 1: fillFromBottom(columns , rows)
	elif picker == 2: fillFromLeft(columns , rows)

var sizeIncreaser = 5

func fillFromTop(columns , rows):
	for y in rows + sizeIncreaser:
		for x in columns + sizeIncreaser:
			createIcon( Vector2( ( x-2) * 40 , (y-2) * 40 - 20) )
		await get_tree().process_frame

func fillFromBottom(columns, rows):
	for y in rows + sizeIncreaser:
		for x in columns + sizeIncreaser:
			createIcon( Vector2( (columns-x) * 40 , (rows-y) * 40 - 20) )
		await get_tree().process_frame

func fillFromLeft(columns , rows):
	for x in columns + sizeIncreaser:
		for y in rows + sizeIncreaser:
			createIcon( Vector2( (x-2) * 40 , (y-2) * 40 - 20) )
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
