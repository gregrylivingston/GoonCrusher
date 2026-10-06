extends Panel


var isSpinning: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():

	
	for i in [$VBoxContainer/slotAwardIcon, $VBoxContainer/slotAwardIcon2, $VBoxContainer/slotAwardIcon3, $VBoxContainer/slotAwardIcon4, $VBoxContainer/slotAwardIcon5, $VBoxContainer/slotAwardIcon6, $VBoxContainer/slotAwardIcon7, $VBoxContainer/slotAwardIcon8]:
		var symbol = SlotSymbols.pick()
		i.texture = SlotSymbols.texture(symbol)
		i.type = symbol
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
const MAX_ROW_CHILDREN = 12 #the separator plus 11 icons; the row shows about 3
const ICON_PITCH = 180 #75px icon + 105px separation
func addNewIcon():
	var newIcon
	if $VBoxContainer.get_child_count() >= MAX_ROW_CHILDREN:
		#reuse the icon that scrolled off the top instead of growing the row for as long as it spins
		newIcon = $VBoxContainer.get_child(1)
		$VBoxContainer.move_child(newIcon, -1)
		$VBoxContainer.position.y += ICON_PITCH
		spins -= 1
	else:
		newIcon = slotAwardIcon.instantiate()
		$VBoxContainer.add_child(newIcon)
	var symbol = SlotSymbols.pick() #by rarity, with Dice and the machine's bet (slot_symbols.gd)
	newIcon.type = symbol
	newIcon.texture = SlotSymbols.texture(symbol)


func stopSpinning():
	isSpinning = false

func startSpinning():
	isSpinning = true
	
func getActiveType():
	return $VBoxContainer.get_child(spins).type
	
func getActiveTexture():
	return $VBoxContainer.get_child(spins).texture
