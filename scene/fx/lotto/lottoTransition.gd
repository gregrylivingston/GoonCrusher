extends CanvasLayer


#Slot Celebration setting: Minimal = a dim fade, Reduced = about 150 large icons,
#Full = the 40 px icon wall as designed. Sized from the logical 1600x900 rect, so a 4K
#screen builds the same number of icons as a 900p one.
const CELL_SIZES = [0, 100, 40]
var cell: int = 40

func _ready():
	var level = Settings.celebration_level()
	if level == 0:
		dimFade()
		return
	cell = CELL_SIZES[level]
	var columns = int(get_viewport().get_visible_rect().size.x / cell)
	var rows = int(get_viewport().get_visible_rect().size.y / cell)
	var picker = randi_range(0,2)
	if picker == 0:fillFromTop(columns, rows)
	elif picker == 1: fillFromBottom(columns , rows)
	elif picker == 2: fillFromLeft(columns , rows)

var sizeIncreaser = 5

func dimFade() -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.55, 0.4)

#one row or column per physics tick, independent of frame rate
func fillFromTop(columns , rows):
	for y in rows + sizeIncreaser:
		for x in columns + sizeIncreaser:
			createIcon( Vector2( ( x-2) * cell , (y-2) * cell - cell / 2) )
		await get_tree().physics_frame

func fillFromBottom(columns, rows):
	for y in rows + sizeIncreaser:
		for x in columns + sizeIncreaser:
			createIcon( Vector2( (columns-x) * cell , (rows-y) * cell - cell / 2) )
		await get_tree().physics_frame

func fillFromLeft(columns , rows):
	for x in columns + sizeIncreaser:
		for y in rows + sizeIncreaser:
			createIcon( Vector2( (x-2) * cell , (y-2) * cell - cell / 2) )
		await get_tree().physics_frame


	
var slotAwardIcon = preload("res://scene/player/slots/slot_award_icon.tscn")
func createIcon( screenPosition: Vector2):
	var newIcon = slotAwardIcon.instantiate()
	var myFlavor = randi_range(0,slotContents.size()-1)
	newIcon.type = slotContents[myFlavor].type
	newIcon.texture =  slotContents[myFlavor].icon 
	newIcon.position = screenPosition
	if cell != 40: newIcon.scale = Vector2.ONE * cell / 40.0
	add_child(newIcon)


func destory():
	queue_free()
	
	
	
var slotContents =[{
		"type":"purse",
		"icon":preload("res://texture/icon/purse.svg"),
		},
		{
		"type":"armor",
		"icon":preload("res://texture/icon/armor.svg"),
	},
	{
		"type":"gem",
		"icon":preload("res://texture/icon/gem.svg"),
	},
	{
		"type":"traction",
		"icon":preload("res://texture/icon/traction.svg"),
	},
	{
		"type":"steering",
		"icon":preload("res://texture/icon/steering.svg"),
	},
	{
		"type":"engine",
		"icon":preload("res://texture/icon/engine.svg"),
	},
	{
		"type":"fuel",
		"icon":preload("res://texture/icon/fuel.svg"),
	},
	{
		"type":"health",
		"icon":preload("res://texture/icon/health.svg"),
	},
	{
		"type":"coin",
		"icon":preload("res://texture/icon/coin.svg"),
	},
]
