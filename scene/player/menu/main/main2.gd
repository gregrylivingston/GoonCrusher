extends CanvasLayer

#The main menu, as cards (docs/UI.md).
#  GARAGE     a carousel of driver cards (DriverCard). LB/RB or Left/Right picks a driver, Accept
#             drives or unlocks, Upgrades opens the driver's page in the Goonopedia (where upgrades are
#             bought), Records shows the driver's bests.
#  RUN SETUP  the road map: six region tabs (Territories; Z/C or LT/RT), the region's five stops on a road
#             (Q/E or LB/RB, 1-5), the five mode medallions under them (Left/Right), the tier chips
#             (Up/Down; ModeTiers: Easy, Medium, Hard), the car strip (which cars have won this mode,
#             level and tier; a click on an owned car drives it), Accept starts the run, Back returns to
#             the garage. Medals (bronze, silver, gold) show the best tier beaten.
#The save holds every selection; this only draws it. Built in code with MenuTheme.
#  G / View opens the Goonopedia (goonopedia.gd) over either screen.
#Other scripts call: startLevel(path), animateCoins(from, to), statUpdatesUiUpdate(), add_child(menu).

enum Screen { GARAGE, SETUP }

#carousel slots by offset from the selected card: position and scale of a 380 x 560 card (the focused
#one's progress pill hangs under it)
const CARD_SLOTS := {
	0: [Vector2(610, 138), 1.0],
	-1: [Vector2(333, 246), 0.7], 1: [Vector2(1001, 246), 0.7],
	-2: [Vector2(92, 290), 0.58], 2: [Vector2(1288, 290), 0.58],
}
const ACTION_DOCK_WIDTH := 280.0
const POSTER_SIZE := Vector2(250, 140) #a stop on the road map
const STOP_SPOTS := [Vector2(195, 262), Vector2(500, 214), Vector2(800, 262), Vector2(1100, 214), Vector2(1405, 262)] #stop centres, 1st to 5th
const STOP_FOCUS_SCALE := 1.18
const CAR_CELL := Vector2(112, 42) #a side view in the car strip; the current driver's is CAR_CELL_BIG
const CAR_CELL_BIG := Vector2(144, 54)
#the outline of a car not owned yet: its silhouette's edge only
const OUTLINE_SHADER := "shader_type canvas_item;
uniform vec4 line : source_color = vec4(1.0, 1.0, 1.0, 0.55);
void fragment() {
	vec2 p = TEXTURE_PIXEL_SIZE * 3.0;
	float a = texture(TEXTURE, UV).a;
	float n = max(max(texture(TEXTURE, UV + vec2(p.x, 0.0)).a, texture(TEXTURE, UV - vec2(p.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, p.y)).a, texture(TEXTURE, UV - vec2(0.0, p.y)).a));
	COLOR = vec4(line.rgb, line.a * clamp(n - a, 0.0, 1.0));
}"
const SLIDE_SECONDS := 0.22
const MODE_ORDER := Root.MODE_PATH #the medallions, left to right
const TEXT_SHADER := preload("res://shader/3dtext.gdshader")
const SETTINGS_ICON := preload("res://texture/icon/settings.svg")
const QUIT_ICON := preload("res://texture/icon/quit.svg")
const DISCORD_ICON := preload("res://texture/icon/discord.png")
const STEAM_ICON := preload("res://texture/icon/steam.png")
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")

var screen := Screen.GARAGE
var loadingLevel := false
var ui := Control.new()
var backgrounds: Array[TextureRect] = []
var frontBackground := 0
var garage := Control.new()
var actionDock := Control.new() #the focused card's Drive and Upgrades, at the bottom right
var setup := Control.new()
var logo := Label.new()
var cards: Array[DriverCard] = []
var pendingInfos := {}       #card index -> CarInfo path still loading on a worker thread
var coinsLabel := Label.new()
var gemsLabel := Label.new()
var shownCoins := 0
var hintBar := HBoxContainer.new()
var posters: Array[Control] = [] #one stop per level; only the selected region's five show
var pendingPosters := {}     #poster index -> level image path still loading
var regionTabs: Array[Button] = [] #Territories.ORDER
var regionBlurb := Label.new()
var road := Control.new()    #draws the road through the region's stops
var carStrip := HBoxContainer.new()
var carStripLabel := Label.new()
var carCells: Array[Button] = []
var outlineMaterial: ShaderMaterial
var medallions: Array[Control] = []
var modeTitle := Label.new()
var tierRow := HBoxContainer.new() #Easy, Medium, Hard (ModeTiers)
var tierButtons: Array[Button] = []
var goalRow := HBoxContainer.new() #the tier's goal and what winning pays, in symbols
var modeText := Label.new()
var modeLock := Label.new()
var nextUnlock := HBoxContainer.new() #run setup's "Next unlock" line (Unlocks.nextUnlock), in symbols
var startButton: Button
var buyPlayer := AudioStreamPlayer.new()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Root.mainMenu = self
	Settings.set_menu_context(true)
	InputGlyphs.ensureMenuActions()
	$VersionTracker.text = Root.versionText()
	buildUi()
	shownCoins = SaveManager.playerData.coin
	selectCar(SaveManager.playerData.selectedCar, false)
	#a door carried over from the run's results (Transition.carry), taken now: a loading door made after
	#this point (startLevel during the frame awaited below) must never be mistaken for it
	var returningDoor: Transition = Transition.active if Transition.busy() else null
	var payout = 0
	if Root.isRunActive:
		Root.isRunActive = false
		#gameSummary already credited and saved the payout; the menu only counts the display up
		payout = Root.earnedCoins
		if payout > 0: coinsLabel.text = DriverCard.formatCoins(SaveManager.playerData.coin - payout)
		Root.earnedCoins = 0
		Root.earnedGems = 0
	await get_tree().process_frame
	#back from a run behind the results' shutter: roll it up on the garage, then count the payout in
	if is_instance_valid(returningDoor) && not loadingLevel:
		returningDoor.open()
		await returningDoor.opened
	if payout > 0: animateCoins(SaveManager.playerData.coin - payout, SaveManager.playerData.coin)
	Settings.on_menu_ready() #the menu is drawn: this boot did not crash
	if Settings.safe_mode_prompt: add_child(SettingsDialog.safeModePrompt())
	elif Settings.detect_toast_pending || Settings.calibrate_pending:
		await Settings.calibrate_if_needed() #first run on this GPU only: may lower the detected tier
		if is_inside_tree() && Settings.detect_toast_pending: add_child(SettingsDialog.detectToast())

func _exit_tree():
	Settings.set_menu_context(false)

#---------- building ----------

func buildUi() -> void:
	ui.theme = MenuTheme.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	move_child(ui, 0)
	for i in 2:
		var bg = TextureRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.modulate = Color(0.4, 0.4, 0.42, 0.0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bg)
		backgrounds.push_back(bg)
	ui.add_child(shade())
	for layer in [garage, setup]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(layer)
	buildLogo()
	buildTopBar()
	buildGarage()
	buildSetup()
	var bar = PanelContainer.new()
	bar.theme_type_variation = "QuietPanel"
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -22
	hintBar.add_theme_constant_override("separation", 26)
	bar.add_child(hintBar)
	ui.add_child(bar)
	buyPlayer.stream = BUY_SOUND
	buyPlayer.bus = &"UI"
	add_child(buyPlayer)

#darkens the top and bottom so the logo and hints read over any art
func shade() -> TextureRect:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.8)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var rect = TextureRect.new()
	rect.texture = texture
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

#the GOONCRUSHER title in the game's extruded 3D text (shader/3dtext.gdshader)
func buildLogo() -> void:
	logo.text = "GOONCRUSHER"
	logo.add_theme_font_override("font", preload("res://style/font/Tektur/Tektur-Black.ttf"))
	logo.add_theme_font_size_override("font_size", 84)
	logo.add_theme_color_override("font_color", HudTheme.RIM)
	logo.add_theme_color_override("font_outline_color", Color(0.353, 0.071, 0.047))
	logo.add_theme_constant_override("outline_size", 14)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = -440
	logo.offset_right = 440
	logo.offset_top = 14
	logo.offset_bottom = 124
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.478, 0.122, 0.039), Color(0.306, 0.067, 0.043)])
	var side = GradientTexture1D.new()
	side.gradient = gradient
	var material = ShaderMaterial.new()
	material.shader = TEXT_SHADER
	material.set_shader_parameter("time_mode", 1)
	material.set_shader_parameter("angle", 6.8)
	material.set_shader_parameter("thickness", 7.0)
	material.set_shader_parameter("shear", Vector2(0, -0.35))
	material.set_shader_parameter("slices", 64)
	material.set_shader_parameter("outline", true)
	material.set_shader_parameter("outline_width", 2.0)
	material.set_shader_parameter("side_tex", side)
	logo.material = material
	ui.add_child(logo)

func buildTopBar() -> void:
	var left = HBoxContainer.new()
	left.position = Vector2(24, 24)
	left.add_theme_constant_override("separation", 10)
	for item in [[QUIT_ICON, "Quit game", func(): get_tree().quit()],
			[SETTINGS_ICON, "Settings", openSettings],
			[Goonopedia.ICON, "Goonopedia", openGoonopedia],
			[DISCORD_ICON, "Discord", func(): OS.shell_open("https://discord.gg/CRwgEe4Gve")],
			[STEAM_ICON, "Wishlist on Steam", func(): OS.shell_open("https://store.steampowered.com/app/1941650/GOONCRUSHER/")]]:
		var b = MenuTheme.button("", PackedStringArray(), false, item[0])
		b.tooltip_text = item[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(item[2])
		left.add_child(b)
	ui.add_child(left)
	#the radio, under the icons: shows the song, a click skips it, a right click turns the radio on or off (docs/RADIO.md)
	var radio = NowPlaying.new()
	radio.pinned = true
	radio.position = Vector2(24, 88)
	ui.add_child(radio)
	var pill = PanelContainer.new()
	pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -24
	pill.offset_top = 24
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(MenuTheme.iconRect(HudTheme.COIN_ICON, 34))
	coinsLabel.add_theme_font_size_override("font_size", 28)
	row.add_child(coinsLabel)
	var divider = ColorRect.new()
	divider.color = Color(1, 1, 1, 0.18)
	divider.custom_minimum_size = Vector2(2, 30)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	row.add_child(MenuTheme.iconRect(HudTheme.GEM_ICON, 28))
	gemsLabel.add_theme_font_size_override("font_size", 24)
	row.add_child(gemsLabel)
	pill.add_child(row)
	ui.add_child(pill)

func buildGarage() -> void:
	var cars = SaveManager.playerData.cars
	for i in cars.size():
		var card = DriverCard.new()
		garage.add_child(card)
		card.drivePressed.connect(goToSetup)
		card.unlockPressed.connect(onUnlockPressed)
		card.upgradesRequested.connect(openUpgrades)
		card.selectRequested.connect(selectCar.bind(i))
		cards.push_back(card)
		card.car = cars[i]
		card.refresh()
	#every card's Drive and Upgrades sit in one dock at the bottom right; only the focused card's show
	actionDock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actionDock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actionDock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	actionDock.offset_left = -24 - ACTION_DOCK_WIDTH
	actionDock.offset_right = -24
	actionDock.offset_top = -18 - DriverCard.BUTTON_HEIGHT
	actionDock.offset_bottom = -18
	actionDock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garage.add_child(actionDock)
	for card in cards:
		card.remove_child(card.actions)
		actionDock.add_child(card.actions)
		card.actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func buildSetup() -> void:
	setup.visible = false
	var tabs = HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	tabs.position = Vector2(392, 26)
	tabs.size = Vector2(880, 46)
	for r in Territories.ORDER.size(): tabs.add_child(makeRegionTab(r))
	setup.add_child(tabs)
	regionBlurb.theme_type_variation = "BodyLabel"
	regionBlurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	regionBlurb.add_theme_font_size_override("font_size", 16)
	regionBlurb.add_theme_color_override("font_color", HudTheme.MUTED)
	regionBlurb.position = Vector2(330, 80)
	regionBlurb.size = Vector2(940, 26)
	regionBlurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup.add_child(regionBlurb)
	road.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.draw.connect(drawRoad)
	setup.add_child(road)
	var levels = SaveManager.playerData.levels
	for i in levels.size():
		var poster = makePoster(i)
		poster.visible = false
		setup.add_child(poster)
		posters.push_back(poster)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 382)
	row.size = Vector2(1600, 140)
	for mode in MODE_ORDER:
		var medallion = makeMedallion(mode)
		row.add_child(medallion)
		medallions.push_back(medallion)
	setup.add_child(row)
	var info = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.position = Vector2(300, 524)
	info.size = Vector2(1000, 136)
	info.add_theme_constant_override("separation", 3)
	tierRow.alignment = BoxContainer.ALIGNMENT_CENTER
	tierRow.add_theme_constant_override("separation", 12)
	for tier in ModeTiers.TIERS: tierRow.add_child(makeTierButton(tier))
	info.add_child(tierRow)
	goalRow.alignment = BoxContainer.ALIGNMENT_CENTER
	goalRow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(goalRow)
	modeTitle.visible = false #the selected medallion names the mode
	for l in [modeTitle, modeText, modeLock]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
	modeTitle.theme_type_variation = "GoldLabel"
	modeText.theme_type_variation = "BodyLabel"
	modeLock.theme_type_variation = "BodyLabel"
	modeLock.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	setup.add_child(info)
	buildCarStrip()
	startButton =MenuTheme.button("START", PackedStringArray(["ui_accept"]), true)
	startButton.position = Vector2(620, 744)
	startButton.size = Vector2(360, 68)
	startButton.add_theme_font_size_override("font_size", 30)
	startButton.pressed.connect(onStartPressed)
	setup.add_child(startButton)
	nextUnlock.position = Vector2(300, 818)
	nextUnlock.size = Vector2(1000, 28)
	nextUnlock.alignment = BoxContainer.ALIGNMENT_CENTER
	nextUnlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup.add_child(nextUnlock)
	loadoutButton = loadoutSlotButton("ui_upgrade", Vector2(200, 744), cycleLoadout)
	boostButton = loadoutSlotButton("ui_boost", Vector2(1010, 744), cycleBoost)
	refreshLoadout()

#U / Y (B / RS for the boost) and clicks drive it; focus stays on START so Accept always starts
func loadoutSlotButton(action: String, at: Vector2, onPress: Callable) -> Button:
	var b := MenuTheme.button("", PackedStringArray([action]), false)
	b.position = at
	b.size = Vector2(390, 68)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(onPress)
	b.focus_mode = Control.FOCUS_NONE
	setup.add_child(b)
	return b

#---------- the loadout ----------
#Banked gems buy a consumable for each of the car's two slots to start a run with: a gadget for the
#Fire slot (Pickups.LOADOUT, kept in meta.records.loadout) and a boost for the Boost slot
#(Pickups.BOOST_LOADOUT, meta.records.boostLoadout). Each button says which key fires it in the run.
#The gems are spent when the run starts, the gadget's first.
const SLOTS := ["loadout", "boostLoadout"]
var loadoutButton: Button #the gadget's (the career harness presses it)
var boostButton: Button

static func slotPrices(slot: String) -> Dictionary:
	return Pickups.openLoadout(Pickups.LOADOUT if slot == "loadout" else Pickups.BOOST_LOADOUT) #only unlocked ones are sold

static func slotChoice(slot: String) -> String:
	var id: String = SaveManager.playerData.meta.get("records", {}).get(slot, "")
	return id if slotPrices(slot).has(id) else ""

## What the slot will really buy at Start: its choice, or "" when the gems left after the slots before
## it don't cover it
static func slotPurchase(slot: String) -> String:
	var gems: int = SaveManager.playerData.gem
	for s in SLOTS:
		var id := slotChoice(s)
		var cost: int = slotPrices(s).get(id, 0)
		var buys := id != "" && gems >= cost
		if buys: gems -= cost
		if s == slot: return id if buys else ""
	return ""

func loadoutChoice() -> String:
	return slotChoice("loadout")

func cycleLoadout() -> void:
	cycleSlot("loadout")

func cycleBoost() -> void:
	cycleSlot("boostLoadout")

## The next choice the gems cover alongside the other slot's, or none
func cycleSlot(slot: String) -> void:
	var prices := slotPrices(slot)
	var other: String = SLOTS[1 - SLOTS.find(slot)]
	var budget: int = SaveManager.playerData.gem - slotPrices(other).get(slotPurchase(other), 0)
	var options := [""] + prices.keys()
	var at := options.find(slotChoice(slot))
	for i in options.size():
		at = wrapi(at + 1, 0, options.size())
		if options[at] == "" || budget >= prices[options[at]]: break
	SaveManager.playerData.meta.records[slot] = options[at]
	SaveManager.save_character_data()
	refreshLoadout()

func refreshLoadout() -> void:
	for pair in [[loadoutButton, "loadout", "UseItem", "GADGET"], [boostButton, "boostLoadout", "UseMove", "BOOST"]]:
		var button: Button = pair[0]
		if not is_instance_valid(button): continue
		var id := slotPurchase(pair[1])
		var key := InputGlyphs.label(pair[2])
		if id == "":
			button.text = "%s:  NONE
Start with one, fired with %s" % [pair[3], key]
			button.tooltip_text = ""
		else:
			var cost: int = slotPrices(pair[1])[id]
			var uses: int = Pickups.DATA[id].get("charges", 1)
			button.text = "%s%s  -  %d GEM%s
In the run: press %s" % [Pickups.displayName(id).to_upper(), "  x%d" % uses if uses > 1 else "", cost, "" if cost == 1 else "S", key]
			button.tooltip_text = Pickups.DATA[id].get("text", "")
		button.icon = Pickups.texture(id) if id != "" else null
		button.add_theme_constant_override("icon_max_width", 34)

## "NEXT UNLOCK  (purse) Purse  900 (coin)", with the bank's progress toward it or its play condition, as
## symbol parts (MenuTheme.symbolRow); [] when nothing is waiting (Unlocks.nextUnlock)
static func nextUnlockParts() -> Array:
	var next := Unlocks.nextUnlock()
	if next.is_empty(): return []
	var id: String = next.uid.trim_prefix("pickup:")
	var parts := ["NEXT UNLOCK  ", Pickups.texture(id), next.name, "  "]
	var cost := Unlocks.pickupPrice(id)
	if Unlocks.state(next.uid) == Unlocks.S.READY && not cost.is_empty():
		parts.push_back(cost)
		if Unlocks.canAfford(next.uid): parts.push_back("  in the Goonopedia (%s)" % InputGlyphs.label("ui_codex"))
		else: parts.append_array(["  (", DriverCard.formatCoins(next.have), "/", DriverCard.formatCoins(next.need), ")"])
	else: parts.push_back("%s  (%d / %d)" % [next.text, next.have, next.need])
	return parts

#the level at a save index as the registry describes it (Levels): poster art, name and scene
static func levelDef(index: int) -> LevelDef:
	return Levels.defAt(index)

static func posterPath(index: int) -> String:
	var def := levelDef(index)
	return def.poster if def else str(SaveManager.playerData.levels[index].get("image", ""))

static func levelName(index: int) -> String:
	var def := levelDef(index)
	return def.displayName if def else str(SaveManager.playerData.levels[index].get("name", ""))

static func levelScene(index: int) -> String:
	var def := levelDef(index)
	return def.scenePath() if def else str(SaveManager.playerData.levels[index].get("scene", ""))

#a level as a stop on the road: its poster art, "1  PRAIRIE RUN" with a star per mode beaten, and a lock when locked
func makePoster(index: int) -> Control:
	var image := posterPath(index)
	var poster = Panel.new()
	poster.size = POSTER_SIZE
	poster.pivot_offset = POSTER_SIZE / 2.0
	poster.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.12, 0.1, 0.09), Color(0, 0, 0, 0), 18, 0))
	var art = TextureRect.new()
	art.name = "art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = POSTER_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_child(art)
	if ResourceLoader.has_cached(image) || index == SaveManager.playerData.selectedLevel: art.texture = load(image)
	else:
		ResourceLoader.load_threaded_request(image)
		pendingPosters[index] = image
	var band = PanelContainer.new()
	band.name = "band"
	band.theme_type_variation = "BandPanel"
	band.position = Vector2(0, POSTER_SIZE.y - 40)
	band.size = Vector2(POSTER_SIZE.x, 40)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bandRow = HBoxContainer.new()
	bandRow.name = "row"
	bandRow.alignment = BoxContainer.ALIGNMENT_CENTER
	bandRow.add_theme_constant_override("separation", 8)
	var label = Label.new()
	label.name = "name"
	label.theme_type_variation = "DarkLabel"
	label.add_theme_font_size_override("font_size", 15)
	label.text = "%d  %s" % [index % Territories.STOPS + 1, levelName(index).to_upper()]
	bandRow.add_child(label)
	var stars = HBoxContainer.new()
	stars.name = "stars"
	stars.add_theme_constant_override("separation", 1)
	bandRow.add_child(stars)
	band.add_child(bandRow)
	poster.add_child(band)
	var lock = VBoxContainer.new()
	lock.name = "lock"
	lock.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.size = Vector2(POSTER_SIZE.x, POSTER_SIZE.y - 40)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lockIcon = MenuTheme.iconRect(HudTheme.LOCK_ICON, 40)
	lockIcon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.add_child(lockIcon)
	var lockText = Label.new()
	lockText.name = "text"
	lockText.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lockText.add_theme_font_size_override("font_size", 17)
	lock.add_child(lockText)
	poster.add_child(lock)
	var frame = Panel.new()
	frame.name = "frame"
	frame.size = POSTER_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_child(frame)
	var catcher = Button.new() #a click on another stop selects it
	catcher.name = "catcher"
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.size = POSTER_SIZE
	catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(stepLevelTo.bind(index))
	poster.add_child(catcher)
	return poster

func makeMedallion(mode: int) -> Control:
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 140)
	column.add_theme_constant_override("separation", 6)
	var disc = Button.new()
	disc.name = "disc"
	disc.custom_minimum_size = Vector2(96, 96)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.focus_mode = Control.FOCUS_NONE
	disc.icon = HudTheme.MODE_ICONS[mode]
	disc.expand_icon = true
	disc.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	disc.pressed.connect(func(): SaveManager.setGameMode(mode); refreshSetup())
	MenuTheme.addSounds(disc)
	column.add_child(disc)
	var label = Label.new()
	label.name = "name"
	label.text = Root.gameModeDescription[mode].name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	column.add_child(label)
	var medals = HBoxContainer.new() #the best tier beaten here: bronze, silver, gold
	medals.name = "medals"
	medals.alignment = BoxContainer.ALIGNMENT_CENTER
	medals.add_theme_constant_override("separation", 2)
	medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for tier in ModeTiers.TIERS: medals.add_child(MenuTheme.iconRect(HudTheme.STAR_ICON, 14))
	column.add_child(medals)
	return column

#a tier chip under the medallions; a click picks it (focus stays on START)
func makeTierButton(tier: int) -> Button:
	var b := Button.new()
	b.text = ModeTiers.NAMES[tier].to_upper()
	b.custom_minimum_size = Vector2(150, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = HudTheme.STAR_ICON
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_size_override("font_size", 17)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): SaveManager.setGameTier(tier); refreshSetup(false))
	MenuTheme.addSounds(b)
	tierButtons.push_back(b)
	return b

#a region tab over the road map; a click opens that region at its furthest open stop
func makeRegionTab(region: int) -> Button:
	var def := Territories.get_def(Territories.ORDER[region])
	var b := Button.new()
	b.text = "%d  %s" % [region + 1, str(def.get("name", "")).to_upper()]
	b.custom_minimum_size = Vector2(140, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(selectRegion.bind(region))
	MenuTheme.addSounds(b)
	regionTabs.push_back(b)
	return b

#the selected region's tab lit in its colour; a demo-locked region carries a lock
func refreshRegionTabs(region: int) -> void:
	for i in regionTabs.size():
		var b := regionTabs[i]
		var def := Territories.get_def(Territories.ORDER[i])
		var color: Color = def.get("color", HudTheme.RIM)
		var on := i == region
		var style = MenuTheme.box(HudTheme.PANEL.lerp(color, 0.28) if on else HudTheme.PANEL, color if on else Color(color, 0.35), 12, 3 if on else 2, Vector4(10, 4, 10, 4))
		for state in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(state, style)
		var hover = style.duplicate()
		hover.border_color = color
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_color_override("font_color", HudTheme.TEXT if on else HudTheme.MUTED)
		b.add_theme_color_override("font_hover_color", HudTheme.TEXT)
		var demoLocked: bool = Root.IS_DEMO && not def.get("demo", true)
		b.icon = HudTheme.LOCK_ICON if demoLocked else null
		b.modulate = Color.WHITE if on || not demoLocked else Color(1, 1, 1, 0.6)

func selectedRegion() -> int:
	return SaveManager.playerData.selectedLevel / Territories.STOPS

#a region tab (or Z/C): its furthest stop that can be started, else its first
func selectRegion(region: int) -> void:
	region = wrapi(region, 0, Territories.ORDER.size())
	var first := region * Territories.STOPS
	var pick := first
	for stop in Territories.STOPS:
		if first + stop < posters.size() && isLevelSelectable(first + stop): pick = first + stop
	stepLevelTo(pick)

#the road through the region's five stops, in from the left edge and out to the right
func drawRoad() -> void:
	var color: Color = Territories.get_def(Territories.ORDER[selectedRegion()]).get("color", HudTheme.RIM)
	var points := PackedVector2Array([Vector2(-40, STOP_SPOTS[0].y + 30)])
	for spot in STOP_SPOTS: points.push_back(spot + Vector2(0, 30))
	points.push_back(Vector2(1640, STOP_SPOTS[-1].y + 30))
	road.draw_polyline(points, Color(color, 0.45), 40.0, true)
	road.draw_polyline(points, Color(0.13, 0.12, 0.11, 0.95), 30.0, true)
	for i in points.size() - 1: road.draw_dashed_line(points[i], points[i + 1], Color(HudTheme.GOLD, 0.8), 3.0, 14.0)

func buildCarStrip() -> void:
	outlineMaterial = ShaderMaterial.new()
	outlineMaterial.shader = Shader.new()
	outlineMaterial.shader.code = OUTLINE_SHADER
	carStrip.alignment = BoxContainer.ALIGNMENT_CENTER
	carStrip.add_theme_constant_override("separation", 6)
	carStrip.position = Vector2(0, 664)
	carStrip.size = Vector2(1600, CAR_CELL_BIG.y + 6)
	carStripLabel.add_theme_font_size_override("font_size", 15)
	carStripLabel.custom_minimum_size = Vector2(150, 0)
	carStripLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	carStripLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	carStrip.add_child(carStripLabel)
	for i in SaveManager.playerData.cars.size():
		var cell := Button.new()
		cell.flat = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.size_flags_vertical = Control.SIZE_SHRINK_END
		for state in ["normal", "hover", "pressed", "focus"]: cell.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var pic := TextureRect.new()
		pic.name = "pic"
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.offset_bottom = -6
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pic)
		var bar := ColorRect.new() #the current driver's orange bar
		bar.name = "bar"
		bar.color = HudTheme.NEEDLE
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = -4
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(bar)
		cell.pressed.connect(onCarCellPressed.bind(i))
		carStrip.add_child(cell)
		carCells.push_back(cell)
	setup.add_child(carStrip)

static func isCarOwned(index: int) -> bool:
	return int(SaveManager.playerData.cars[index].cost) == 0 && not (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT)

#which cars have won this mode here on this tier: in colour = cleared, dark = owned but not cleared,
#an outline = not owned; the current driver is bigger, over an orange bar
func refreshCarStrip(index: int, mode: int, tier: int) -> void:
	var cars = SaveManager.playerData.cars
	for i in carCells.size():
		if cards[i].info == null: finishCarLoad(i, true)
		var cell := carCells[i]
		var pic: TextureRect = cell.get_node("pic")
		pic.texture = cards[i].info.sidePic
		var current: bool = i == SaveManager.playerData.selectedCar
		var owned := isCarOwned(i)
		var best := SaveManager.carClearTier(index, mode, str(cars[i].name))
		var cleared := owned && best >= tier
		cell.custom_minimum_size = (CAR_CELL_BIG if current else CAR_CELL) + Vector2(0, 6)
		cell.get_node("bar").visible = current
		pic.material = null if owned else outlineMaterial
		pic.modulate = Color.WHITE if cleared || not owned else Color(0.07, 0.07, 0.08)
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if owned && not current else Control.CURSOR_ARROW
		var carName: String = cards[i].info.charName
		cell.tooltip_text = "%s: %s" % [carName, ("won on " + ModeTiers.NAMES[best]) if cleared else ("not won yet" if owned else "not owned")]
	var full := SaveManager.isFullGarage(index, mode, tier)
	carStripLabel.text = "FULL GARAGE" if full else "CARS  %d / %d" % [SaveManager.carsCleared(index, mode, tier), cars.size()]
	carStripLabel.add_theme_color_override("font_color", HudTheme.GOLD if full else HudTheme.MUTED)

#a click on an owned car in the strip makes it the driver
func onCarCellPressed(index: int) -> void:
	if not isCarOwned(index) || index == SaveManager.playerData.selectedCar: return
	selectCar(index, false)
	refreshSetup(false)

#each chip: lit while selected, its star in the medal colour once that tier is beaten, dim while locked
func refreshTiers(level: Dictionary, mode: int) -> void:
	var selected := SaveManager.getGameTier()
	var best := ModeTiers.best(level, mode)
	for i in tierButtons.size():
		var b := tierButtons[i]
		var tier: int = ModeTiers.TIERS[i]
		var on := tier == selected
		var style = MenuTheme.box(HudTheme.PANEL, HudTheme.RIM if on else Color(1, 1, 1, 0.22), 20, 3 if on else 2, Vector4(14, 4, 14, 4))
		if on:
			style.shadow_color = Color(HudTheme.GOLD, 0.4)
			style.shadow_size = 8
		for state in ["normal", "pressed", "focus", "hover"]: b.add_theme_stylebox_override(state, style)
		b.add_theme_color_override("font_color", HudTheme.GOLD if on else HudTheme.TEXT)
		b.add_theme_color_override("font_hover_color", HudTheme.GOLD)
		b.add_theme_color_override("icon_normal_color", ModeTiers.MEDAL_COLORS[tier if best >= tier else 0])
		b.icon = HudTheme.STAR_ICON if ModeTiers.isOpen(level, mode, tier) else HudTheme.LOCK_ICON
		b.modulate = Color.WHITE if ModeTiers.isOpen(level, mode, tier) || on else Color(1, 1, 1, 0.55)

## The goal line: what the tier asks here, what a win pays and the first-clear bonus still to earn
func goalParts(level: Dictionary, mode: int, tier: int, index: int) -> Array:
	var def := levelDef(index)
	var parts: Array = [ModeTiers.goalText(mode, tier, def.seconds if def else 300.0), "     WIN  +", {"coin": ModeTiers.winBonus(mode, tier, index)}]
	var first := ModeTiers.firstClear(ModeTiers.best(level, mode), tier, index)
	if first.coin > 0 || first.gem > 0: parts.append_array(["     FIRST CLEAR  +", first])
	return parts

#---------- garage ----------

func selectCar(index: int, animate := true) -> void:
	var cars = SaveManager.playerData.cars
	index = wrapi(index, 0, cars.size())
	if index != SaveManager.playerData.selectedCar:
		SaveManager.playerData.selectedCar = index
		SaveManager.save_character_data()
	if cards[index].info == null: finishCarLoad(index, true)
	Root.selectedCar = cars[index]
	Root.playerCar = null #the menu shows a car from its CarInfo, without loading the car scene
	Root.carInfo = cards[index].info
	layoutCards(animate)
	showBackground(Root.carInfo.backgroundPic, animate)
	if Root.carInfo.introAudio.size() > 0:
		$voicePlayer.stream = Root.carInfo.introAudio[randi_range(0, Root.carInfo.introAudio.size() - 1)]
		$voicePlayer.play()
	statUpdatesUiUpdate()
	updateHints()

func layoutCards(animate: bool) -> void:
	var count = cards.size()
	var selected = SaveManager.playerData.selectedCar
	for i in count:
		var card = cards[i]
		var offset = wrapi(i - selected + count / 2, 0, count) - count / 2
		var slot = CARD_SLOTS.get(offset)
		var target: Vector2 = slot[0] if slot else Vector2(800 + signf(offset) * 1000 - 190, 300)
		var scale: float = slot[1] if slot else 0.5
		var tint = Color.WHITE if offset == 0 else (Color(0.6, 0.6, 0.6) if slot else Color(0.6, 0.6, 0.6, 0.0))
		if slot && card.info == null && not pendingInfos.has(i): requestCarInfo(i)
		if card.focused != (offset == 0): card.setFocused(offset == 0, animate)
		if animate && slot && not card.visible: #sliding in from off screen
			card.position = target + Vector2(signf(offset) * 300, 0)
			card.modulate = Color(tint, 0.0)
			card.visible = true
		if animate && card.visible:
			var tween = card.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", target, SLIDE_SECONDS)
			tween.tween_property(card, "scale", Vector2(scale, scale), SLIDE_SECONDS)
			tween.tween_property(card, "modulate", tint, SLIDE_SECONDS)
		else:
			card.position = target
			card.scale = Vector2(scale, scale)
			card.modulate = tint
		card.visible = slot != null || animate
	stackByDistance(garage, cards, selected)
	if screen == Screen.GARAGE: cards[selected].mainButton.grab_focus()

#draws the selected item last and the farthest first, by child order (z_index would also lift the
#cards over overlays such as Settings)
func stackByDistance(parent: Control, items: Array, selected: int) -> void:
	var count = items.size()
	var order = range(count)
	order.sort_custom(func(a, b): return absi(wrapi(a - selected + count / 2, 0, count) - count / 2) > absi(wrapi(b - selected + count / 2, 0, count) - count / 2))
	var first = items[0].get_index()
	for i in count: first = mini(first, items[i].get_index())
	for i in count: parent.move_child(items[order[i]], first + i)

#cards load their CarInfo (portrait, background, intro lines) only when they come into view
func requestCarInfo(index: int) -> void:
	var path = CarInfo.pathFor(SaveManager.playerData.cars[index].scene)
	if ResourceLoader.has_cached(path):
		cards[index].setup(SaveManager.playerData.cars[index], load(path), index)
		return
	ResourceLoader.load_threaded_request(path)
	pendingInfos[index] = path

#a CarInfo the carousel needs now: take it from the worker thread, waiting only if `wait`
func finishCarLoad(index: int, wait: bool) -> void:
	var path = pendingInfos.get(index, CarInfo.pathFor(SaveManager.playerData.cars[index].scene))
	if pendingInfos.has(index):
		if not wait && ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return
		pendingInfos.erase(index)
		cards[index].setup(SaveManager.playerData.cars[index], ResourceLoader.load_threaded_get(path), index)
	else: cards[index].setup(SaveManager.playerData.cars[index], load(path), index)

func showBackground(texture: Texture2D, animate := true) -> void:
	var front = backgrounds[frontBackground]
	if front.texture == texture && front.modulate.a > 0.0: return
	frontBackground = 1 - frontBackground
	var next = backgrounds[frontBackground]
	next.texture = texture
	ui.move_child(next, 1)
	var tween = create_tween().set_parallel()
	tween.tween_property(next, "modulate:a", 1.0, SLIDE_SECONDS if animate else 0.0)
	tween.tween_property(front, "modulate:a", 0.0, SLIDE_SECONDS if animate else 0.0)

#Upgrades (or a stat on the focused card): the driver's page in the Goonopedia, on that stat's upgrade
func openUpgrades(stat := -1) -> void:
	var index: int = SaveManager.playerData.selectedCar
	if screen != Screen.GARAGE || cards[index].isLocked() || overlayOpen(): return
	Goonopedia.openCar(self, index, stat).closed.connect(onOverlayClosed)

func onUnlockPressed() -> void:
	var before = SaveManager.playerData.coin
	var card = cards[SaveManager.playerData.selectedCar]
	if SaveManager.unlockCar():
		buyPlayer.play()
		animateCoins(before, SaveManager.playerData.coin)
		Juice.flash(card, HudTheme.GOLD, 0.6, 18)
		Juice.pop(card.portrait, 1.08, 0.4)
		card.mainButton.grab_focus()
	else: Juice.shake(card.mainButton)

#---------- run setup ----------

#the garage and run setup swap behind the shutter (Transition)
func goToSetup() -> void:
	if cards[SaveManager.playerData.selectedCar].isLocked() || screen == Screen.SETUP: return
	Transition.play(showSetup, "GOONCRUSHER", "RUN SETUP")

func showSetup() -> void:
	screen = Screen.SETUP
	SaveManager.setGameMode(defaultGameMode())
	switchLayer(setup, garage)
	refreshSetup(false)
	startButton.grab_focus()

func goToGarage() -> void:
	if screen == Screen.GARAGE: return
	Transition.play(showGarage, "GOONCRUSHER", "GARAGE 07")

func showGarage() -> void:
	screen = Screen.GARAGE
	switchLayer(garage, setup)
	showBackground(Root.carInfo.backgroundPic)
	updateHints()
	cards[SaveManager.playerData.selectedCar].mainButton.grab_focus()

func switchLayer(show: Control, hide: Control) -> void:
	hide.visible = false
	show.visible = true
	logo.visible = show == garage

func refreshSetup(animate := true) -> void:
	var levels = SaveManager.playerData.levels
	var selected = SaveManager.playerData.selectedLevel
	var region := selectedRegion()
	var first := region * Territories.STOPS
	for i in levels.size(): #the region's five stops on the road; the selected one bigger
		var poster = posters[i]
		var stop := i - first
		if stop < 0 || stop >= Territories.STOPS || stop >= STOP_SPOTS.size():
			poster.visible = false
			continue
		var target: Vector2 = STOP_SPOTS[stop] - POSTER_SIZE / 2.0
		var focused: bool = i == selected
		var scale = Vector2.ONE * (STOP_FOCUS_SCALE if focused else 1.0)
		var tint = Color.WHITE if focused else Color(0.72, 0.72, 0.72)
		if not poster.visible: #a region just opened: its stops drop onto the road
			poster.position = target + Vector2(0, -24)
			poster.modulate.a = 0.0
			poster.visible = true
		if animate:
			var tween = poster.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(poster, "position", target, SLIDE_SECONDS)
			tween.tween_property(poster, "scale", scale, SLIDE_SECONDS)
			tween.tween_property(poster, "modulate", tint, SLIDE_SECONDS)
		else:
			poster.position = target
			poster.scale = scale
			poster.modulate = tint
		refreshPoster(i, focused)
		poster.get_node("catcher").visible = not focused
	var top := 0
	for poster in posters: top = maxi(top, poster.get_index())
	setup.move_child(posters[selected], top) #the selected stop over its neighbours
	refreshRegionTabs(region)
	var territory := Territories.get_def(Territories.ORDER[region])
	regionBlurb.text = str(territory.get("blurb", ""))
	road.queue_redraw()
	var level = levels[selected]
	if posters[selected].get_node("art").texture == null: finishPosterLoad(selected, true)
	showBackground(posters[selected].get_node("art").texture, animate)
	var mode = SaveManager.getGameMode()
	var forModes = selectedLevelForModes()
	for i in MODE_ORDER.size(): refreshMedallion(medallions[i], MODE_ORDER[i], MODE_ORDER[i] == mode, forModes)
	var tier := SaveManager.getGameTier()
	refreshTiers(forModes, mode)
	for child in goalRow.get_children():
		goalRow.remove_child(child)
		child.queue_free()
	goalRow.add_child(MenuTheme.symbolRow(goalParts(forModes, mode, tier, selected), 18, HudTheme.GOLD))
	refreshCarStrip(selected, mode, tier)
	modeTitle.text = Root.gameModeDescription[mode].name
	modeText.text = Root.gameModeDescription[mode].description
	if mode == Root.gameModes.GOONPOCALYPSE:
		var best = SaveManager.bestGoonpocalypse(selected, SaveManager.playerData.cars[SaveManager.playerData.selectedCar].name)
		if best.time > 0: modeText.text += "\nBest here: %d:%02d, score %d" % [best.time / 60, best.time % 60, best.score]
	var reason = "" if isLevelSelectable(selected) else ("Not in the demo" if isDemoLockedLevel(selected) else Root.openRuleText(SaveManager.playerData.levels[selected - 1] if selected > 0 else {}))
	if reason == "": reason = Root.modeLockReason(forModes, mode)
	if reason == "": reason = ModeTiers.lockReason(forModes, mode, tier)
	modeLock.text = reason
	modeLock.visible = reason != ""
	for child in nextUnlock.get_children():
		nextUnlock.remove_child(child)
		child.queue_free()
	var parts := nextUnlockParts()
	if not parts.is_empty(): nextUnlock.add_child(MenuTheme.symbolRow(parts, 17, HudTheme.MUTED))
	var playable = isLevelSelectable(selected) && Root.isModePlayable(forModes, mode) && ModeTiers.isOpen(forModes, mode, tier)
	startButton.disabled = not playable
	startButton.text = "START" if playable else ("COMING SOON" if reason == "Coming Soon" else "LOCKED")
	updateHints()

func refreshPoster(index: int, isFocused: bool) -> void:
	var poster = posters[index]
	var level = SaveManager.playerData.levels[index]
	var open = isLevelSelectable(index)
	poster.get_node("lock").visible = not open
	poster.get_node("lock/text").text = "NOT IN DEMO" if isDemoLockedLevel(index) else "LOCKED"
	poster.get_node("art").modulate = Color.WHITE if open else Color(0.35, 0.35, 0.35)
	var stars: HBoxContainer = poster.get_node("band/row/stars")
	for child in stars.get_children(): child.queue_free()
	for mode in MODE_ORDER: #one star per mode, in the colour of the best medal won with it here
		var star = MenuTheme.iconRect(HudTheme.STAR_ICON, 13)
		star.modulate = ModeTiers.MEDAL_COLORS[ModeTiers.best(level, mode)]
		stars.add_child(star)
	var style = MenuTheme.box(Color(0, 0, 0, 0), HudTheme.RIM if isFocused else Color(1, 1, 1, 0.22), 18, 5 if isFocused else 3)
	style.draw_center = false
	poster.get_node("frame").add_theme_stylebox_override("panel", style)

func finishPosterLoad(index: int, wait: bool) -> void:
	if not pendingPosters.has(index): return
	var path = pendingPosters[index]
	if not wait && ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return
	pendingPosters.erase(index)
	posters[index].get_node("art").texture = ResourceLoader.load_threaded_get(path)

#gold star when beaten here, a dim star when it can be started, a lock when it can't
func refreshMedallion(column: Control, mode: int, selected: bool, level: Dictionary) -> void:
	var disc: Button = column.get_node("disc")
	var playable = Root.isModePlayable(level, mode)
	var beaten = playable && level.gamemodeBeat.get(mode, false)
	disc.icon = HudTheme.MODE_ICONS[mode] if playable else HudTheme.LOCK_ICON
	disc.modulate = Color.WHITE if beaten || not playable else Color(0.85, 0.85, 0.85)
	var style = MenuTheme.box(HudTheme.PANEL, HudTheme.RIM if selected else Color(1, 1, 1, 0.25), 48, 4 if selected else 2, Vector4(16, 16, 16, 16))
	if selected:
		style.shadow_color = Color(HudTheme.GOLD, 0.45)
		style.shadow_size = 14
	for state in ["normal", "pressed", "focus"]: disc.add_theme_stylebox_override(state, style)
	var hover = style.duplicate()
	hover.border_color = HudTheme.GOLD if selected else Color(HudTheme.RIM, 0.8)
	hover.bg_color = HudTheme.PANEL.lerp(HudTheme.RIM, 0.12)
	disc.add_theme_stylebox_override("hover", hover)
	var best := ModeTiers.best(level, mode) if playable else ModeTiers.NONE
	var medals = column.get_node("medals")
	for i in medals.get_child_count(): medals.get_child(i).modulate = ModeTiers.MEDAL_COLORS[ModeTiers.TIERS[i] if best >= ModeTiers.TIERS[i] else 0]
	var label: Label = column.get_node("name")
	label.theme_type_variation = "GoldLabel" if selected else ""
	label.add_theme_font_size_override("font_size", 19 if selected else 16)
	column.modulate = Color.WHITE if playable || selected else Color(1, 1, 1, 0.55)

func onStartPressed() -> void:
	var index = SaveManager.playerData.selectedLevel
	if screen == Screen.SETUP && isLevelSelectable(index) && Root.isModePlayable(selectedLevelForModes(), SaveManager.getGameMode()) && ModeTiers.isOpen(selectedLevelForModes(), SaveManager.getGameMode(), SaveManager.getGameTier()):
		var gadget := slotPurchase("loadout")
		var boost := slotPurchase("boostLoadout") #worked out before either is paid for
		if gadget != "":
			SaveManager.playerData.gem -= Pickups.LOADOUT[gadget]
			Pickups.loadout = gadget #the car takes both in _ready
		if boost != "":
			SaveManager.playerData.gem -= Pickups.BOOST_LOADOUT[boost]
			Pickups.boostLoadout = boost
		startLevel(levelScene(index))

#the mode shown when run setup opens: the saved one if it can be started here, else Countdown
func defaultGameMode() -> int:
	var mode = SaveManager.getGameMode()
	return mode if Root.isModePlayable(selectedLevelForModes(), mode) else Root.gameModes.GOONCRUSHER

#the selected level as the mode rules see it: a level the demo doesn't offer counts as locked
func selectedLevelForModes() -> Dictionary:
	var index = SaveManager.playerData.selectedLevel
	var level: Dictionary = SaveManager.playerData.levels[index]
	if isDemoLockedLevel(index): return level.merged({"unlocked": false}, true)
	return level

func isDemoLockedLevel(index: int) -> bool:
	return Root.IS_DEMO && index >= Root.DEMO_LEVEL_COUNT

func isLevelSelectable(index: int) -> bool:
	return SaveManager.playerData.levels[index].unlocked && not isDemoLockedLevel(index)

#---------- input ----------

func _process(_delta):
	for index in pendingInfos.keys(): finishCarLoad(index, false)
	for index in pendingPosters.keys(): finishPosterLoad(index, false)

#menu navigation runs before the GUI so Left/Right switch cards instead of moving focus
func _input(event: InputEvent) -> void:
	if Settings.menu_open || loadingLevel || overlayOpen() || Transition.busy() || not event.is_pressed() || event.is_echo(): return
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP || event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var step = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if screen == Screen.GARAGE: selectCar(SaveManager.playerData.selectedCar + step)
			else: stepLevelTo(SaveManager.playerData.selectedLevel + step)
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if screen == Screen.GARAGE:
		if event.is_action_pressed("ui_tab_prev") || event.is_action_pressed("ui_left"): selectCar(SaveManager.playerData.selectedCar - 1)
		elif event.is_action_pressed("ui_tab_next") || event.is_action_pressed("ui_right"): selectCar(SaveManager.playerData.selectedCar + 1)
		elif event.is_action_pressed("ui_upgrade"): openUpgrades()
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: cards[SaveManager.playerData.selectedCar].onMainPressed()
		else: handled = false
	else:
		if event.is_action_pressed("ui_cancel"): goToGarage()
		elif event.is_action_pressed("ui_tab_prev"): stepLevelTo(SaveManager.playerData.selectedLevel - 1)
		elif event.is_action_pressed("ui_tab_next"): stepLevelTo(SaveManager.playerData.selectedLevel + 1)
		elif event.is_action_pressed("ui_region_prev") && triggerEdge(event, "ui_region_prev"): selectRegion(selectedRegion() - 1)
		elif event.is_action_pressed("ui_region_next") && triggerEdge(event, "ui_region_next"): selectRegion(selectedRegion() + 1)
		elif event.is_action_pressed("ui_left"): stepMode(-1)
		elif event.is_action_pressed("ui_right"): stepMode(1)
		elif event.is_action_pressed("ui_up"): stepTier(-1)
		elif event.is_action_pressed("ui_down"): stepTier(1)
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif event.is_action_pressed("ui_upgrade"): cycleLoadout()
		elif event.is_action_pressed("ui_boost"): cycleBoost()
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: onStartPressed()
		elif InputGlyphs.digit(event) > 0 && InputGlyphs.digit(event) <= Territories.STOPS: stepLevelTo(selectedRegion() * Territories.STOPS + InputGlyphs.digit(event) - 1) #the stop's number
		else: handled = false
	if handled: get_viewport().set_input_as_handled()

#a clicked stop, a number key, Q/E or the mouse wheel: select that level (Q/E past a region's ends move
#into the next region; the road wraps)
func stepLevelTo(index: int) -> void:
	index = wrapi(index, 0, SaveManager.playerData.levels.size())
	if index != SaveManager.playerData.selectedLevel:
		SaveManager.playerData.selectedLevel = index
		SaveManager.save_character_data()
	refreshSetup()

#LT/RT are axes, sending events while held: only the press that first crosses the deadzone counts
func triggerEdge(event: InputEvent, action: String) -> bool:
	return not event is InputEventJoypadMotion || Input.is_action_just_pressed(action)

func stepMode(direction: int) -> void:
	var at = MODE_ORDER.find(SaveManager.getGameMode())
	SaveManager.setGameMode(MODE_ORDER[wrapi(at + direction, 0, MODE_ORDER.size())])
	refreshSetup()

#Up is the easier tier, Down the harder (the chips read Easy, Medium, Hard left to right)
func stepTier(direction: int) -> void:
	SaveManager.setGameTier(SaveManager.getGameTier() + direction)
	refreshSetup(false)

func overlayOpen() -> bool:
	return get_tree().get_nodes_in_group("menuOverlay").size() > 0

func updateHints() -> void:
	for child in hintBar.get_children():
		hintBar.remove_child(child)
		child.queue_free()
	var hints: Array
	if screen == Screen.SETUP:
		hints = [[["ui_region_prev", "ui_region_next"], "Region"], [["ui_tab_prev", "ui_tab_next"], "Stop"], [["ui_left", "ui_right"], "Mode"], [["ui_up", "ui_down"], "Tier"], [["ui_accept"], "Start"], [["ui_upgrade"], "Gadget"], [["ui_boost"], "Boost"], [["ui_records"], "Records"], [["ui_codex"], "Goonopedia"], [["ui_cancel"], "Back"]]
	else:
		var locked = cards[SaveManager.playerData.selectedCar].isLocked()
		hints = [[["ui_tab_prev", "ui_tab_next"], "Driver"], [["ui_accept"], "Unlock" if locked else "Drive"]]
		if not locked: hints.push_back([["ui_upgrade"], "Upgrades"])
		hints.append_array([[["ui_records"], "Records"], [["ui_codex"], "Goonopedia"], [["ui_menu"], "Settings"]])
	for hint in hints: hintBar.add_child(KeyHint.make(PackedStringArray(hint[0]), hint[1], 16, true))

#---------- overlays and runs ----------

func openSettings() -> void:
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())

func openGoonopedia() -> void:
	if overlayOpen(): return
	Goonopedia.open(self).closed.connect(onOverlayClosed)

#focus back to the screen under an overlay
func onOverlayClosed() -> void:
	if not is_inside_tree(): return
	statUpdatesUiUpdate() #the Goonopedia may have spent coins and gems on unlocks
	if screen == Screen.SETUP: refreshSetup(false)
	if screen == Screen.SETUP: startButton.grab_focus()
	else: cards[SaveManager.playerData.selectedCar].mainButton.grab_focus()

func openRecords() -> void:
	var scene = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	scene.isGameSummary = false
	scene.tree_exited.connect(onOverlayClosed) #the ticket had focus on its Continue button
	add_child(scene)

#loads the level on a worker thread behind the shutter, which shows the level's name and lights its
#lamps with load progress; the level rolls it up once its world is built (Level.revealRun)
func startLevel(path: String) -> void:
	if loadingLevel: return
	loadingLevel = true
	Region.resetRegions()
	SaveManager.flush()
	var door = Transition.close(levelName(SaveManager.playerData.selectedLevel).to_upper(), "LOADING", 0.0)
	ResourceLoader.load_threaded_request(path)
	var carScene = Root.selectedCar.scene #the menu only loaded the car's CarInfo; levelRoot instantiates the scene
	if not ResourceLoader.has_cached(carScene): ResourceLoader.load_threaded_request(carScene)
	var progress = []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS 			|| ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty() && is_instance_valid(door): door.progress = maxf(door.progress, progress[0] * 0.5)
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_LOADED:
		Root.selectedCarScene = ResourceLoader.load_threaded_get(carScene) #held so the cache keeps it
	if is_instance_valid(door):
		door.progress = 0.5
		if not door.isShut: await door.shut #change scenes only once the slam has landed
	var scene = ResourceLoader.load_threaded_get(path)
	if scene: get_tree().change_scene_to_node(RunView.wrap(scene.instantiate()))
	else: get_tree().change_scene_to_file(path)

#coins, gems, prices and lock states after anything that spends or earns
func statUpdatesUiUpdate() -> void:
	shownCoins = SaveManager.playerData.coin
	coinsLabel.text = DriverCard.formatCoins(shownCoins)
	gemsLabel.text = str(SaveManager.playerData.gem)
	refreshLoadout()
	for card in cards: card.refresh()
	updateHints()

#run payout: the coins are already credited and saved; this only counts the display up
func animateCoins(from: int, to: int) -> void:
	statUpdatesUiUpdate()
	if coinTween: coinTween.kill()
	coinTween = create_tween()
	coinTween.tween_method(func(v): coinsLabel.text = DriverCard.formatCoins(int(v)), float(from), float(to), clampf(absf(to - from) / 300.0, 0.3, 1.5))
	Juice.pop(coinsLabel, 1.2 if to > from else 1.12)

var coinTween: Tween
