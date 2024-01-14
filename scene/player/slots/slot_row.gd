extends Panel


var isSpinning: bool = false
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


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in [$VBoxContainer/slotAwardIcon, $VBoxContainer/slotAwardIcon2, $VBoxContainer/slotAwardIcon3, $VBoxContainer/slotAwardIcon4, $VBoxContainer/slotAwardIcon5, $VBoxContainer/slotAwardIcon6, $VBoxContainer/slotAwardIcon7, $VBoxContainer/slotAwardIcon8]:
		i.texture = load( slotContents[randi_range(0,slotContents.size()-1)].icon )
	for i in 100:
		$VBoxContainer.position.y -= 0.18 * i
		await get_tree().process_frame
	isSpinning = true

var spinFrameTracker = 0 #icons are 75px, 75px in between, every 150 frams is one cycle
var spins = 7
var slotAwardIcon = preload("res://scene/player/slots/slot_award_icon.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if isSpinning || spinFrameTracker != 6:
		$VBoxContainer.position.y -= 18
		spinFrameTracker += 1
		if spinFrameTracker == 10:
			spinFrameTracker = 0
			spins += 1
			addNewIcon()
		#	
func addNewIcon():
	var newIcon = slotAwardIcon.instantiate()
	var myFlavor = randi_range(0,slotContents.size()-1)
	newIcon.type = slotContents[myFlavor].type
	newIcon.texture = load( slotContents[myFlavor].icon )
	$VBoxContainer.add_child(newIcon)


func stopSpinning():
	isSpinning = false

func startSpinning():
	isSpinning = true
	
func getActiveType():
	return $VBoxContainer.get_child(spins).type

