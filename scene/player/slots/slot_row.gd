extends Panel


var isSpinning: bool = false
var slotContents =[{ ###note coin shows up twice
		"type":Root.upgrade.PURSE,
		"icon":"res://texture/icon/purse.svg",
		},
		{
		"type":Root.upgrade.ARMOR,
		"icon":"res://texture/icon/armor.svg",
	},
	{
		"type":Root.upgrade.GEM,
		"icon":"res://texture/icon/gem.svg",
	},
	{
		"type":Root.upgrade.TRACTION,
		"icon":"res://texture/icon/traction.svg",
	},
	{
		"type":Root.upgrade.COIN,
		"icon":"res://texture/icon/coin.svg",
	},
	{
		"type":Root.upgrade.STEERING,
		"icon":"res://texture/icon/steering.svg",
	},
	{
		"type":Root.upgrade.ENGINE,
		"icon":"res://texture/icon/engine.svg",
	},
	{
		"type":Root.upgrade.FUEL,
		"icon":"res://texture/icon/fuel.svg",
	},
	{
		"type":Root.upgrade.HEALTH,
		"icon":"res://texture/icon/health.svg",
	},
	{
		"type":Root.upgrade.COIN,
		"icon":"res://texture/icon/coin.svg",
	},
	{
		"type":Root.upgrade.OIL,
		"icon":"res://texture/icon/oil.svg",
	},
	{
		"type":Root.upgrade.HEADLIGHTS,
		"icon":"res://texture/icon/headlights.svg",
	},
	{
		"type":Root.upgrade.CLOVER,
		"icon":"res://texture/icon/clover.svg",
	},
	{
		"type":Root.upgrade.LUCK,
		"icon":"res://texture/icon/luck.svg",
	},
]


# Called when the node enters the scene tree for the first time.
func _ready():

	
	for i in [$VBoxContainer/slotAwardIcon, $VBoxContainer/slotAwardIcon2, $VBoxContainer/slotAwardIcon3, $VBoxContainer/slotAwardIcon4, $VBoxContainer/slotAwardIcon5, $VBoxContainer/slotAwardIcon6, $VBoxContainer/slotAwardIcon7, $VBoxContainer/slotAwardIcon8]:
		var randomNum = randi_range(0,slotContents.size()-1)
		i.texture = load( slotContents[randomNum].icon )
		i.type = slotContents[randomNum].type
	#wind-up and spin advance per physics tick, not per frame, so a frame cap cannot desync the reels
	for i in 100:
		$VBoxContainer.position.y -= 0.18 * i
		await get_tree().physics_frame
	isSpinning = true

var spinFrameTracker = 0 #icons are 75px, 75px in between, every 150 frams is one cycle
var spins = 7


func _physics_process(_delta):
	if isSpinning || spinFrameTracker != 6:
		$VBoxContainer.position.y -= 18
		spinFrameTracker += 1
		if spinFrameTracker == 10:
			spinFrameTracker = 0
			spins += 1
			addNewIcon()
		#	
var slotAwardIcon = preload("res://scene/player/slots/slot_award_icon.tscn")
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
	
func getActiveTexture():
	return $VBoxContainer.get_child(spins).texture
