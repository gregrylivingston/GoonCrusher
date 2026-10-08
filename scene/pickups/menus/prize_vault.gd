class_name PrizeVault extends PickupMenu

#The Vault, the strongest gift box game (CrushPrizes): five sealed boxes of Rare or better, and you open
#two (three in a Diamond box). Gold and Diamond boxes fill it with Epic or better. Steer to choose,
#Accelerate to open; each prize is credited as its box opens. Once the picks are spent the rest are shown,
#and Accelerate leaves.

const COUNT := 5

var tier := 0
var contents: Array = []
var opened: Array = []
var picksLeft := 2
var buttons: Array[Button] = []
var focus := 2
var phase := "pick" #pick, done
var row := HBoxContainer.new()
var info := Label.new()

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var vault := PrizeVault.new()
	vault.tier = boxTier
	vault.picksLeft = 3 if boxTier >= CrushPrizes.TOP_TIER else 2
	Root.levelRoot.add_child(vault)

static func minTierFor(boxTier: int) -> int:
	return mini(Pickups.R.RARE + boxTier / 3, Pickups.R.LEGENDARY)

func build() -> void:
	title("THE VAULT", "Gift box: open %d of the %d boxes." % [picksLeft, COUNT])
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(info)
	hints([[["TurnLeft", "TurnRight"], "Choose"], [["Accelerate"], "Open / Leave"]])
	for i in COUNT:
		contents.push_back(Pickups.rollOffer(minTierFor(tier), PickupDeal.NEVER, contents))
		opened.push_back(false)
		buttons.push_back(makeBox(i))
	updateInfo()
	buttons[focus].grab_focus.call_deferred()

func makeBox(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 230)
	MenuTheme.addSounds(b)
	b.pressed.connect(choose.bind(index))
	b.focus_entered.connect(func(): focus = index)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 14
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	b.set_meta("face", v) #not get_child(0): MenuTheme.addSounds adds its players to the button
	var icon := MenuTheme.iconRect(CrushPrizes.texture("vault"), 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.name = "Icon"
	v.add_child(icon)
	for part in [["Rarity", 14], ["Name", 18]]:
		var l := Label.new()
		l.name = part[0]
		l.add_theme_font_size_override("font_size", part[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	row.add_child(b)
	styleBox(index, b)
	return b

## A sealed box shows the vault door; an open one its prize, rarity and short name (dimmed when it was
## only revealed at the end).
func styleBox(index: int, b: Button = null) -> void:
	if b == null: b = buttons[index]
	var shown: bool = opened[index] || phase == "done"
	var id: String = contents[index]
	var col := Pickups.rarityColor(Pickups.rarity(id)) if shown else HudTheme.RIM
	var won: bool = opened[index]
	b.add_theme_stylebox_override("normal", MenuTheme.box(Color(0.1, 0.08, 0.07, 0.97), Color(col, 0.6 if won || not shown else 0.25), 14, 3))
	b.add_theme_stylebox_override("hover", MenuTheme.box(Color(0.16, 0.12, 0.09, 0.97), col, 14, 5))
	b.add_theme_stylebox_override("focus", MenuTheme.box(Color(0.16, 0.12, 0.09, 0.97), col, 14, 5))
	var v: Control = b.get_meta("face")
	var icon: TextureRect = v.get_node("Icon")
	icon.texture = Pickups.texture(id) if shown else CrushPrizes.texture("vault")
	icon.modulate = Color(1, 1, 1, 1.0 if won || not shown else 0.4)
	var rarity: Label = v.get_node("Rarity")
	rarity.text = Pickups.RARITY_NAMES[Pickups.rarity(id)].to_upper() if shown else "SEALED"
	rarity.add_theme_color_override("font_color", col)
	var label: Label = v.get_node("Name")
	label.text = Pickups.shortName(id).to_upper() if shown else "?"
	label.add_theme_color_override("font_color", HudTheme.TEXT if won || not shown else HudTheme.MUTED)

func updateInfo() -> void:
	info.text = "Picks left %d" % picksLeft if phase == "pick" else "Accelerate to leave."

func onAction(action: String) -> void:
	match action:
		"TurnLeft": move(-1)
		"TurnRight": move(1)
		"Accelerate", "ui_accept":
			if phase == "pick": choose(focus)
			else: close()

func move(step: int) -> void:
	focus = wrapi(focus + step, 0, buttons.size())
	buttons[focus].grab_focus()

func choose(index: int) -> void:
	if phase != "pick":
		close()
		return
	if closed || index >= COUNT || opened[index]: return
	opened[index] = true
	picksLeft -= 1
	PickupEffects.collect(Root.playerCar, contents[index], Root.playerCar.global_position)
	Transition.sound("pop", -6.0)
	if picksLeft <= 0:
		phase = "done"
		for i in COUNT: styleBox(i)
	else:
		styleBox(index)
		for step in COUNT: #on to the next sealed box, so holding Accelerate opens them in turn
			var next := (index + 1 + step) % COUNT
			if not opened[next]:
				move(next - focus)
				break
	updateInfo()
