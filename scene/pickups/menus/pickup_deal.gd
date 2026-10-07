class_name PickupDeal extends PickupMenu

#The Deal: pick one of three face-up cards. A gem deals a new hand; run coins raise the hand a rarity
#tier (and cost double each time). It comes as a drop, and every other crush goal deals one instead of
#the slot machine (playerRoot.updateGoonsCrushed).

const RAISE_COST := 100
const BASE_TIER := Pickups.R.UNCOMMON
const NEVER := ["deal", "mystery", "slotmachine", "claw"] #no menu opens another

var crushGoal := false
var minTier := BASE_TIER
var raises := 0
var cards: Array = []
var buttons: Array[Button] = []
var focus := 1
var row := HBoxContainer.new()
var raiseHint: KeyHint
var info := Label.new()

static func open(isCrushGoal: bool) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var deal = PickupDeal.new()
	deal.crushGoal = isCrushGoal
	Root.levelRoot.add_child.call_deferred(deal) #a crush can come from a node leaving the level (a Bait popping), while the level can't take children

func build() -> void:
	if crushGoal && is_instance_valid(Root.playerRoot): Root.playerRoot.animateNewGoonCrushGoal(false, "THE DEAL")
	title("THE DEAL", "Crush goal reached: +1 star. Pick a card." if crushGoal else "Pick a card.")
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(info)
	hints([[["TurnLeft", "TurnRight"], "Choose"], [["Accelerate"], "Take"], [["Brake"], "New hand  (1 gem)"], [["UseItem"], "Raise"]])
	deal()

func deal() -> void:
	cards.clear()
	for i in 3:
		var id := ""
		for attempt in 8:
			id = Pickups.rollAtLeast(minTier)
			if id not in NEVER && id not in cards: break
		cards.push_back(id)
	for b in buttons: b.queue_free()
	buttons.clear()
	for i in 3: buttons.push_back(makeCard(cards[i], i))
	focus = 1
	buttons[focus].grab_focus.call_deferred()
	info.text = "Coins %d   -   Gems %d   -   Raise: %d coins for a rarer hand" % [runCoins(), Root.playerCar.gem if is_instance_valid(Root.playerCar) else 0, raiseCost()]

func raiseCost() -> int:
	return RAISE_COST << raises

func makeCard(id: String, index: int) -> Button:
	var r := Pickups.rarity(id)
	var col := Pickups.rarityColor(r)
	var b = Button.new()
	b.custom_minimum_size = Vector2(270, 380)
	b.add_theme_stylebox_override("normal", MenuTheme.box(Color(0.1, 0.08, 0.07, 0.97), Color(col, 0.6), 16, 3))
	b.add_theme_stylebox_override("hover", MenuTheme.box(Color(0.16, 0.12, 0.09, 0.97), col, 16, 5))
	b.add_theme_stylebox_override("focus", MenuTheme.box(Color(0.16, 0.12, 0.09, 0.97), col, 16, 5))
	MenuTheme.addSounds(b)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 14
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icon = MenuTheme.iconRect(Pickups.texture(id), 110)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	for part in [[Pickups.RARITY_NAMES[r].to_upper(), 15, col], [Pickups.displayName(id).to_upper(), 24, HudTheme.TEXT]]:
		var l = Label.new()
		l.text = part[0]
		l.add_theme_font_size_override("font_size", part[1])
		l.add_theme_color_override("font_color", part[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	var text = Label.new()
	text.text = Pickups.def(id).get("text", "")
	text.theme_type_variation = "MutedLabel"
	text.add_theme_font_size_override("font_size", 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(text)
	b.pressed.connect(take.bind(index))
	b.focus_entered.connect(func(): focus = index)
	row.add_child(b)
	return b

func onAction(action: String) -> void:
	match action:
		"TurnLeft": move(-1)
		"TurnRight": move(1)
		"Accelerate": take(focus)
		"Brake": reroll()
		"UseItem": raise()

func move(step: int) -> void:
	focus = wrapi(focus + step, 0, buttons.size())
	buttons[focus].grab_focus()

func reroll() -> void:
	if not is_instance_valid(Root.playerCar) || not Root.playerCar.spendGems(1):
		info.text = "No gems to deal a new hand."
		return
	deal()

func raise() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || minTier >= Pickups.R.LEGENDARY: return
	if car.coin < raiseCost():
		info.text = "A raise costs %d coins; you have %d." % [raiseCost(), car.coin]
		return
	car.coin -= raiseCost()
	raises += 1
	minTier += 1
	deal()

func take(index: int) -> void:
	if closed || index >= cards.size(): return
	var id: String = cards[index]
	if crushGoal && is_instance_valid(Root.playerRoot): Root.playerRoot.animateNewGoonCrushGoal()
	close()
	PickupEffects.collect(Root.playerCar, id, Root.playerCar.global_position)
