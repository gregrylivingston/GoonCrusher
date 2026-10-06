class_name PitShop extends PickupMenu

#Marathon's pit shop: each station but the last sells three pickups for run coins. Coins spent here
#don't reach the payout, which is the trade. Leaving opens the station's free slot machine.

const PRICES := [30, 60, 150, 400, 900] #by rarity tier

var offers: Array = []
var buttons: Array[Button] = []
var info := Label.new()

static func open() -> void:
	if not is_instance_valid(Root.levelRoot): return
	Root.levelRoot.add_child(PitShop.new())

func build() -> void:
	title("PIT SHOP", "Spend run coins. What you spend here isn't paid out.")
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	body.add_child(list)
	for i in 3:
		var id := ""
		for attempt in 8:
			id = Pickups.rollAtLeast(Pickups.R.UNCOMMON)
			if id not in PickupDeal.NEVER && id not in offers: break
		offers.push_back(id)
		var b = MenuTheme.button("  %s  -  %d coins" % [Pickups.displayName(id), price(id)], PackedStringArray(), false, Pickups.texture(id))
		b.custom_minimum_size = Vector2(560, 64)
		b.add_theme_color_override("font_color", Pickups.rarityColor(Pickups.rarity(id)))
		b.tooltip_text = Pickups.def(id).get("text", "")
		b.pressed.connect(buy.bind(i))
		list.add_child(b)
		buttons.push_back(b)
	var leave = MenuTheme.button("BACK TO THE ROAD", PackedStringArray(["Brake"]), true)
	leave.pressed.connect(leaveShop)
	list.add_child(leave)
	buttons.push_back(leave)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(info)
	hints([[["ui_up", "ui_down"], "Browse"], [["Accelerate"], "Buy"], [["Brake"], "Leave"]])
	refresh()
	var first := buttons.filter(func(b): return not b.disabled)
	first[0].grab_focus.call_deferred()

func price(id: String) -> int:
	return PRICES[clampi(Pickups.rarity(id), 0, PRICES.size() - 1)]

func refresh() -> void:
	info.text = "Run coins: %d" % runCoins()
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
	buttons[index].text = "  SOLD"
	buttons[index].disabled = true
	PickupEffects.collect(Root.playerCar, id, Root.playerCar.global_position)
	refresh()
	moveFocus(1)

func leaveShop() -> void:
	close(false)
	if is_instance_valid(Root.levelRoot): Root.levelRoot.openFreeSlotMachine()
