extends Panel


var isSpinning: bool = false
var slotContents =[
	"res://texture/icon/purse.png",
	"res://texture/icon/shield.png",
	"res://texture/icon/icons8-gem-48.png",
	"res://texture/icon/wheel.png",
	"res://texture/icon/steering.png",
	"res://texture/icon/icons8-coin-48 (1).png"
]

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in 100:
		$VBoxContainer.position.y -= 0.18 * i
		await get_tree().process_frame
	isSpinning = true

var spinFrameTracker = 0 #icons are 75px, 75px in between, every 150 frams is one cycle
var slotAwardIcon = preload("res://scene/player/slots/slot_award_icon.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if isSpinning || spinFrameTracker != 6:
		$VBoxContainer.position.y -= 18
		spinFrameTracker += 1
		if spinFrameTracker == 10:
			spinFrameTracker = 0
		#	$VBoxContainer/HSeparator.size.y += 150
			#$VBoxContainer.get_child(1).queue_free()
			var newIcon = slotAwardIcon.instantiate()
			newIcon.texture = load( slotContents[randi_range(0,slotContents.size()-1)] )
			$VBoxContainer.add_child(newIcon)
			
func stopSpinning():
	isSpinning = false

func startSpinning():
	isSpinning = true
