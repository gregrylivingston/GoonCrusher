class_name PitShop extends PickupMenu

#Marathon's pit shop: each station but the last sells three pickups for run coins. Coins spent here
#don't reach the payout, which is the trade. A bought offer says what it did (PickupMenu.outcome).
#Leaving opens the station's free slot machine.

const PRICES := [30, 60, 150, 400, 900] #by rarity tier

var offers: Array = []
var buttons: Array[Button] = []

static func open() -> void:
	if not is_instance_valid(Root.levelRoot): return
	Root.levelRoot.add_child(PitShop.new())

func build() -> void:
	title("PIT SHOP", "Spend run coins. What you spend here isn't paid out.")
	addStage()
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 40
	list.offset_right = -40
	list.offset_top = 40
	list.alignment = BoxContainer.ALIGNMENT_BEGIN
	stage.add_child(list)
	for i in 3:
		var id := Pickups.rollOffer(Pickups.R.UNCOMMON, Pickups.NOT_IN_GAMES, offers)
		offers.push_back(id)
		var b = MenuTheme.button("  %s  -  %d coins" % [Pickups.displayName(id), price(id)], PackedStringArray(), false, Pickups.texture(id))
		b.custom_minimum_size = Vector2(STAGE.x - 80, 72)
		b.add_theme_color_override("font_color", Pickups.rarityColor(Pickups.rarity(id)))
		b.tooltip_text = Pickups.def(id).get("text", "")
		b.pressed.connect(buy.bind(i))
		list.add_child(b)
		buttons.push_back(b)
	var leave = MenuTheme.button("BACK TO THE ROAD", PackedStringArray(["Brake"]), true)
	leave.custom_minimum_size = Vector2(STAGE.x - 80, 72)
	leave.pressed.connect(leaveShop)
	list.add_child(leave)
	buttons.push_back(leave)
	hints([[["TurnLeft", "TurnRight"], "Browse"], [["Accelerate"], "Buy"], [["Brake"], "Leave"]])
	refresh()
	var first := buttons.filter(func(b): return not b.disabled)
	first[0].grab_focus.call_deferred()

func price(id: String) -> int:
	return PRICES[clampi(Pickups.rarity(id), 0, PRICES.size() - 1)]

func refresh() -> void:
	say("Run coins: %d" % runCoins())
	for i in offers.size():
		if offers[i] != "": buttons[i].disabled = runCoins() < price(offers[i])

func onAction(action: String) -> void:
	match action:
		"Accelerate":
			var focused = root.get_viewport().gui_get_focus_owner()
			if focused is Button && not focused.disabled: focused.pressed.emit()
			else: leaveShop() #nothing affordable is selected
		"Brake", "ui_cancel": leaveShop()
		"TurnLeft": moveFocus(-1)
		"TurnRight": moveFocus(1)

func moveFocus(step: int) -> void:
	var at := buttons.find(root.get_viewport().gui_get_focus_owner())
	for k in buttons.size():
		at = wrapi(at + step, 0, buttons.size())
		if not buttons[at].disabled:
			buttons[at].grab_focus()
			return

func buy(index: int) -> void:
	var id: String = offers[index]
	if id == "" || runCoins() < price(id): return
	Root.playerCar.coin -= price(id)
	offers[index] = ""
	award(id)
	buttons[index].text = "  SOLD: %s" % winnings.back().line
	buttons[index].disabled = true
	refresh()
	moveFocus(1)

func leaveShop() -> void:
	close(false)
	if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("openFreeSlotMachine"): Root.levelRoot.openFreeSlotMachine()
