extends CanvasLayer

#The main menu, as cards (docs/UI.md).
#  GARAGE     a carousel of driver cards (DriverCard). LB/RB or Left/Right picks a driver, Accept
#             drives or unlocks, Records shows the driver's bests. Upgrades opens the driver focus: the
#             other drivers leave, the card moves to the left and its bench (DriverBench) opens beside it,
#             where upgrades are bought (Up/Down, then E / A; Accept still drives); Upgrades or Back returns to the drivers. The
#             dock under the card holds Upgrades, Drive and Pickups.
#  RUN SETUP  two steps. The road map picks the level: one region (Territories) at a time, its five stops
#             on a winding road (Q/E, LB/RB, Left/Right or 1-5), each with a glyph per mode in the color
#             of the best medal won there and a bar under it for the current driver's own. A button at each
#             end of the road leads to the region before and after (Z/C or LT/RT; locked until that region
#             is open). SELECT, Accept or a click on the selected stop opens LEVEL OPTIONS
#             (optionsOpen): under the title, the region and its five stops (1-5 or a click changes level
#             here). The level across the top (its poster, and its goons, ground, props and rules as
#             tiles: Z/C, LT/RT or the mouse walks them and the card beside them says what each is), its
#             five modes as rows down the left (Up/Down) and one pane for the selected mode: its rule, a
#             three-way tier switch (Left/Right; ModeTiers: Easy, Medium, Hard) with each tier's goal and
#             pay, what a win opens and the first-clear bonus, and the car strip (which cars have won this
#             mode, level and tier). Bottom left, the records here: this driver's and the best by any car.
#             Bottom right, the launch cluster: the driver (Q/E), the gadget (F) and boost (V) slots and a
#             round START, which keeps the focus. Back (Esc / B) returns to the road map, then to the
#             garage. Medals (bronze, silver, gold) show the best tier beaten.
#The save holds every selection; this only draws it. Built in code with MenuTheme.
#  G / View opens the Pickups screen (pickup_shop.gd) and B / L3 the Goonopedia (goonopedia.gd), over either screen.
#Other scripts call: startLevel(path), animateCoins(from, to), statUpdatesUiUpdate(), add_child(menu).

enum Screen { GARAGE, SETUP }

#carousel slots by offset from the selected card: position and scale of a 380 x 560 card (the focused
#one's progress pill hangs under it)
const CARD_SLOTS := {
	0: [Vector2(610, 138), 1.0],
	-1: [Vector2(333, 246), 0.7], 1: [Vector2(1001, 246), 0.7],
	-2: [Vector2(92, 290), 0.58], 2: [Vector2(1288, 290), 0.58],
}
const DOCK_SIZE := Vector2(840, 84)  #the tray under the focused card: Upgrades, Drive, Pickups
const DOCK_BOTTOM := 68.0            #its foot above the screen's, clear of the hint bar
const FOCUS_CARD_POS := Vector2(80, 146) #the card in driver focus, with its bench at BENCH_POS
const BENCH_POS := Vector2(512, 142)
const POSTER_SIZE := Vector2(204, 196) #a stop on the road map: its art, the name band, then a glyph per mode
const POSTER_ART := 116.0
const POSTER_BAND := 36.0
const STOP_SPOTS := [Vector2(230, 470), Vector2(515, 258), Vector2(800, 484), Vector2(1085, 270), Vector2(1370, 470)] #stop centers, 1st to 5th
const REGION_BUTTON := Vector2(124, 124) #the buttons at the road's ends: the region before and the one after
const REGION_SPOTS := [Vector2(78, 296), Vector2(1522, 296)] #their centers; the road runs from one to the other
const ROAD_BEND := 150.0 #the road's handles at each stop, flat, so it swings between them
const STOP_FOCUS_SCALE := 1.14
const LEVEL_BAND := Rect2(60, 152, 1480, 124) #Level Options, top section, under the title row: the level
const MODE_LIST_POS := Vector2(60, 324)  #middle section: the mode rows, as tall as the pane beside them
const MODE_ROW := Vector2(440, 46) #at least; the rows share the pane's height
const OPTIONS_PANE := Rect2(520, 324, 1020, 302) #middle section: the selected mode and tier
const LEVEL_ART := Vector2(176, 100)
const FACT_ICON := 46.0 #a goon, a ground, a prop or a rule's tile in the level's facts
const FACT_CAPS := {"goons": 5, "ground": 4, "props": 4, "rules": 4}
const RECORDS_PANEL := Rect2(60, 674, 440, 112) #bottom section, under the mode rows: this driver's record here and the best
const LAUNCH_PLATE := Rect2(520, 674, 1020, 112) #bottom section, under the pane: driver, loadout, START, evenly spaced
const SLOT_SPOTS := [Vector2(884, 698), Vector2(1144, 698)] #the gadget's and the boost's round buttons on it
const PANEL_EDGE := Color(1, 1, 1, 0.22)
const TITLE_ROW := Rect2(60, 88, 1480, 44) #the level's name, its region and the stop buttons, on the sections' left edge
const TIER_SEGMENT := 126.0
const OPENS_TEXT := Color(0.6, 0.9, 0.45)
const START_SIZE := 100.0 #the round START (and the road map's SELECT), at the right end of the launch plate
const START_POS := Vector2(1404, 680)
const SLOT_SIZE := 64.0
const DRIVER_BUTTON := Rect2(554, 692, 296, 76)
const LOCK_TEXT := Color(1.0, 0.62, 0.55)
#a mode icon in one color (a medal's): its light and dark kept as shades of the tint
const GLYPH_SHADER := "shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb * mix(0.4, 1.0, dot(t.rgb, vec3(0.299, 0.587, 0.114))), t.a * tint.a);
}"
const GLYPH_OPEN := Color(1, 1, 1, 0.36)   #a mode not won yet
const GLYPH_LOCKED := Color(1, 1, 1, 0.13)
const GLYPH_LOCKED_INDEX := 4              #glyphMaterials: a medal's index (ModeTiers.NONE to HARD), then locked
const CAR_CELL := Vector2(84, 33) #a side view in the car strip; the current driver's is CAR_CELL_BIG
const CAR_CELL_BIG := Vector2(112, 44)
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
const MODE_SLOTS := 5 #the mode rows, top to bottom: the level's two openers and its three featured modes (Root.modePath)
const FREE_ROW_HEIGHT := 30.0 #the slim Free Play row under them
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
var actionDock := Panel.new() #the focused card's Upgrades, Drive and Pickups, in a tray at the bottom center
var focusOpen := false       #driver focus: the selected card at the left with its bench, the other drivers off screen
var bench := DriverBench.new()
var benchTween: Tween
var setup := Control.new()
var logo := Label.new()
var cards: Array[DriverCard] = []
var pendingInfos := {}       #card index -> CarInfo path still loading on a worker thread
var coinsLabel := Label.new()
var gemsLabel := Label.new()
var shownCoins := 0
var hintBar := HBoxContainer.new()
var optionsOpen := false     #run setup's second step: Level Options in place of the road map
var map := Control.new()     #the road map: region tabs, the stops, the level panel
var options := Control.new() #Level Options: the mode rows, the pane (tier switch, goal, pay, car strip, the level), START
var glyphMaterials: Array[ShaderMaterial] = []
var levelLock := Label.new() #what opens the highlighted stop, under SELECT
var selectButton: Button
var regionTitle := Label.new()
var regionButtons: Array[Button] = [] #[the region before, the region after]
var legendCar := Label.new()
var driverPic := TextureRect.new() #the current driver, top right of run setup: whose bars the glyphs carry
var driverName := Label.new()
var optionsTitle := Label.new()
var optionsRegion := Label.new()
var optionsArt := TextureRect.new()
var optionsBlurb := Label.new()
var optionsFacts := HBoxContainer.new() #the level's goons, ground and props, a group of tiles each (fillFacts)
var factsFor := -1           #the level they show
var factTiles: Array[Button] = []
var factAt := -1             #the tile Z/C has walked to (-1: none, the card shows the level's blurb)
var factStarts: Array[int] = [] #where each group of tiles starts (Shift+Z/C jumps a group)
var stopRow := HBoxContainer.new() #under the title: the region, then a button per stop
var stopButtons: Array[Button] = []
var stakes := HBoxContainer.new() #under the tier switch: why it can't start, what a win opens, the first clear
var recordsBox := HBoxContainer.new()
var startBadge := PanelContainer.new() #on START: the gems the loadout will take
var optionsPane: PanelContainer #the pane; its edge takes the mode's category color
var paneBody: VBoxContainer
var paneTween: Tween
var shownPick := [] #[level, mode, tier] last drawn, so a change can pop
var factTitle := Label.new() #the card beside the tiles: the tile walked to or under the mouse (optionsBlurb is its line)
var factChips := HBoxContainer.new()
var backButton: Button       #bottom left of run setup: to the road map, then the garage
var radioBar := NowPlaying.new() #top left, beside the buttons
var radioInline := Vector2.ZERO
var driverChip: PanelContainer #the road map's "DRIVER (car) Name"; Level Options has driverButton
var driverButton: Button     #the launch cluster's driver: a press takes the next car owned
var driverSide := TextureRect.new()
var driverLabel := Label.new()
var slotCaptions := {}       #loadout slot -> the lines beside its round button
var posters: Array[Control] = [] #one stop per level; only the selected region's five show
var pendingPosters := {}     #poster index -> level image path still loading
var regionBlurb := Label.new()
var road := Control.new()    #draws the road through the region's stops
var carStrip := HBoxContainer.new()
var carStripLabel := Label.new()
var carCells: Array[Button] = []
var outlineMaterial: ShaderMaterial
var modeRows: Array[Button] = []
var freeRow: Button #Free Play, under the five: any other mode once all five are won here (Root.freePlayOpen)
var modeTitle := Label.new()
var tierRow := HBoxContainer.new() #Easy, Medium, Hard (ModeTiers): a three-way switch
var tierButtons: Array[Button] = []
var modeText := Label.new()
var lockReason := ""         #why START is locked ("" when it isn't; the career harness reads it)
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
	logo.add_theme_font_size_override("font_size", 78) #clear of the radio beside the top-left buttons
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
	#top left: Quit, Settings and the Goonopedia, then the radio (it shows the song, a click skips to
	#the next one: docs/RADIO.md), narrower in the garage to stay clear of the logo (switchLayer)
	var left = HBoxContainer.new()
	left.position = Vector2(24, 24)
	left.add_theme_constant_override("separation", 10)
	for item in [[QUIT_ICON, "Quit game", func(): get_tree().quit()],
			[SETTINGS_ICON, "Settings", openSettings],
			[Goonopedia.ICON, "Goonopedia", openGoonopedia]]:
		left.add_child(barButton(item[0], item[1], item[2]))
	ui.add_child(left)
	radioBar.pinned = true
	radioBar.width = 270.0
	radioInline = Vector2(24.0 + left.get_combined_minimum_size().x + 10.0, 21)
	radioBar.position = radioInline
	ui.add_child(radioBar)
	#bottom left, level with the hint bar: the links out of the game
	var links = HBoxContainer.new()
	links.position = Vector2(24, 826)
	links.add_theme_constant_override("separation", 10)
	for item in [[DISCORD_ICON, "Discord", func(): OS.shell_open("https://discord.gg/CRwgEe4Gve")],
			[STEAM_ICON, "Wishlist on Steam", func(): OS.shell_open("https://store.steampowered.com/app/1941650/GOONCRUSHER/")]]:
		links.add_child(barButton(item[0], item[1], item[2]))
	ui.add_child(links)
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

#an icon of the screen's corners that is its own button: no frame, it lights up and grows under the mouse
static func barButton(icon: Texture2D, tip: String, onPress: Callable) -> Button:
	var b = MenuTheme.button("", PackedStringArray(), false, icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	b.pivot_offset = Vector2(26, 26)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_constant_override("icon_max_width", 46)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_color_override("icon_normal_color", Color(0.82, 0.82, 0.82))
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", HudTheme.GOLD)
	b.add_theme_color_override("icon_hover_pressed_color", HudTheme.GOLD)
	b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.15, 1.15), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.08))
	b.pressed.connect(onPress)
	return b

func buildGarage() -> void:
	var cars = SaveManager.playerData.cars
	for i in cars.size():
		var card = DriverCard.new()
		garage.add_child(card)
		card.drivePressed.connect(goToSetup)
		card.unlockPressed.connect(onUnlockPressed)
		card.upgradesRequested.connect(toggleFocus)
		card.pickupsRequested.connect(openPickups)
		card.selectRequested.connect(selectCar.bind(i))
		cards.push_back(card)
		card.car = cars[i]
		card.refresh()
	bench.position = BENCH_POS
	bench.visible = false
	garage.add_child(bench)
	#every card's Upgrades, Drive and Pickups sit in one tray at the bottom center; only the focused card's show
	var tray := MenuTheme.box(Color(HudTheme.PANEL, 0.92), Color(HudTheme.RIM, 0.6), 14, 2)
	tray.border_width_top = 4
	actionDock.add_theme_stylebox_override("panel", tray)
	actionDock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	actionDock.offset_left = -DOCK_SIZE.x / 2.0
	actionDock.offset_right = DOCK_SIZE.x / 2.0
	actionDock.offset_top = -DOCK_BOTTOM - DOCK_SIZE.y
	actionDock.offset_bottom = -DOCK_BOTTOM
	actionDock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garage.add_child(actionDock)
	for card in cards:
		card.remove_child(card.actions)
		actionDock.add_child(card.actions)
		card.actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.actions.offset_left = 12
		card.actions.offset_right = -12
		card.actions.offset_top = 11
		card.actions.offset_bottom = -9

func buildSetup() -> void:
	setup.visible = false
	for layer in [map, options]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		setup.add_child(layer)
	var glyphShader := Shader.new()
	glyphShader.code = GLYPH_SHADER
	for color in [GLYPH_OPEN, ModeTiers.MEDAL_COLORS[ModeTiers.EASY], ModeTiers.MEDAL_COLORS[ModeTiers.MEDIUM], ModeTiers.MEDAL_COLORS[ModeTiers.HARD], GLYPH_LOCKED]:
		var material := ShaderMaterial.new()
		material.shader = glyphShader
		material.set_shader_parameter("tint", color)
		glyphMaterials.push_back(material)
	buildMap()
	buildOptions()
	buildDriverChip()
	backButton = MenuTheme.button("BACK", PackedStringArray(["ui_cancel"]))
	backButton.position = Vector2(176, 826) #bottom left, beside the links, on both steps
	backButton.size = Vector2(132, 52)
	backButton.add_theme_font_size_override("font_size", 18)
	backButton.focus_mode = Control.FOCUS_NONE
	backButton.pressed.connect(onBackPressed)
	setup.add_child(backButton)
	refreshLoadout()

#run setup's first step: the region buttons, the road and its stops
func buildMap() -> void:
	regionTitle.theme_type_variation = "GoldLabel"
	regionTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	regionTitle.position = Vector2(330, 26)
	regionTitle.size = Vector2(940, 46)
	regionTitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(regionTitle)
	regionBlurb.theme_type_variation = "BodyLabel"
	regionBlurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	regionBlurb.add_theme_font_size_override("font_size", 16)
	regionBlurb.add_theme_color_override("font_color", HudTheme.MUTED)
	regionBlurb.position = Vector2(330, 80)
	regionBlurb.size = Vector2(940, 26)
	regionBlurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(regionBlurb)
	road.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.draw.connect(drawRoad)
	map.add_child(road)
	for side in 2:
		var b := makeRegionButton(side)
		map.add_child(b)
		regionButtons.push_back(b)
	var levels = SaveManager.playerData.levels
	for i in levels.size():
		var poster = makePoster(i)
		poster.visible = false
		map.add_child(poster)
		posters.push_back(poster)
	selectButton = roundPrimary("SELECT") #round, bottom right: where START is on the next step
	selectButton.pressed.connect(openOptions)
	map.add_child(selectButton)
	levelLock.theme_type_variation = "BodyLabel"
	levelLock.add_theme_font_size_override("font_size", 17)
	levelLock.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	levelLock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	levelLock.position = Vector2(560, 750)
	levelLock.size = Vector2(856, 26)
	levelLock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(levelLock)
	#what the glyphs on the stops say
	var legend = HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 8)
	legend.position = Vector2(0, 730)
	legend.size = Vector2(1600, 24)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sample = MenuTheme.iconRect(HudTheme.MODE_ICONS[Root.gameModes.SPRINT], 20)
	sample.material = glyphMaterials[ModeTiers.HARD]
	legend.add_child(sample)
	var bar = ColorRect.new()
	bar.color = ModeTiers.MEDAL_COLORS[ModeTiers.MEDIUM]
	bar.custom_minimum_size = Vector2(26, 4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var best = Label.new()
	best.text = "best medal by any car      "
	for l in [best, legendCar]:
		l.theme_type_variation = "MutedLabel"
		l.add_theme_font_size_override("font_size", 15)
	legend.add_child(best)
	legend.add_child(bar)
	legend.add_child(legendCar)
	map.add_child(legend)

#run setup's second step, for the level picked on the road map: the level across the top, its modes down
#the left, one pane for the selected mode and tier, and the launch cluster at the bottom right
func buildOptions() -> void:
	options.visible = false
	var scrim = ColorRect.new() #keeps the level's art out from under the text
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.add_child(scrim)
	#the title row, on the sections' left edge: the level's name, its region, then the region's five stops
	#(1-5 or a click changes level without the road map)
	stopRow.add_theme_constant_override("separation", 6)
	stopRow.position = TITLE_ROW.position
	stopRow.size = TITLE_ROW.size
	optionsTitle.theme_type_variation = "TitleLabel"
	optionsTitle.add_theme_font_size_override("font_size", 36)
	stopRow.add_child(optionsTitle)
	for width in [20, 10]: #title, a gap, the region, a smaller gap, the stops
		var gap = Control.new()
		gap.custom_minimum_size.x = width
		stopRow.add_child(gap)
		if width == 20:
			optionsRegion.add_theme_font_size_override("font_size", 18)
			optionsRegion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stopRow.add_child(optionsRegion)
	for stop in Territories.STOPS:
		var b := Button.new()
		b.text = str(stop + 1)
		b.custom_minimum_size = Vector2(32, 28)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 15)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(optionsStop.bind(stop))
		MenuTheme.addSounds(b)
		stopRow.add_child(b)
		stopButtons.push_back(b)
	options.add_child(stopRow)
	#the level: its poster, its goons, ground and props as tiles, and the card that says what a tile is
	var band = PanelContainer.new()
	band.position = LEVEL_BAND.position
	band.size = LEVEL_BAND.size
	band.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(1, 1, 1, 0.22), 16, 2, Vector4(14, 12, 14, 12)))
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 22)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(strip)
	options.add_child(band)
	var frame = Panel.new()
	frame.custom_minimum_size = LEVEL_ART
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.12, 0.1, 0.09), Color(0, 0, 0, 0), 12, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	optionsArt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	optionsArt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	optionsArt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	optionsArt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(optionsArt)
	strip.add_child(frame)
	optionsFacts.add_theme_constant_override("separation", 22)
	optionsFacts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	optionsFacts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(optionsFacts)
	var card = VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_constant_override("separation", 2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true
	factTitle.theme_type_variation = "GoldLabel"
	factTitle.add_theme_font_size_override("font_size", 20)
	card.add_child(factTitle)
	factChips.add_theme_constant_override("separation", 12)
	card.add_child(factChips)
	optionsBlurb.theme_type_variation = "BodyLabel"
	optionsBlurb.add_theme_font_size_override("font_size", 15)
	optionsBlurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	optionsBlurb.max_lines_visible = 3
	optionsBlurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	optionsBlurb.custom_minimum_size.x = 240
	card.add_child(optionsBlurb)
	strip.add_child(card)
	var list = VBoxContainer.new()
	list.position = MODE_LIST_POS
	list.size = Vector2(MODE_ROW.x, OPTIONS_PANE.size.y) #the built rows share it (refreshModeRow)
	list.add_theme_constant_override("separation", 8)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot in MODE_SLOTS:
		var row = makeModeRow(slot)
		list.add_child(row)
		modeRows.push_back(row)
	freeRow = makeModeRow(MODE_SLOTS)
	freeRow.custom_minimum_size.y = FREE_ROW_HEIGHT
	list.add_child(freeRow)
	options.add_child(list)
	var pane = PanelContainer.new()
	pane.position = OPTIONS_PANE.position
	pane.size = OPTIONS_PANE.size
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(body)
	options.add_child(pane)
	optionsPane = pane
	paneBody = body
	#the mode: its name and rule
	var head = HBoxContainer.new() #the name, and at the right end a few words about it
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modeTitle.theme_type_variation = "GoldLabel"
	modeTitle.add_theme_font_size_override("font_size", 28)
	modeTitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modeTitle.mouse_filter = Control.MOUSE_FILTER_STOP #its tooltip is the full description
	head.add_child(modeTitle)
	modeText.theme_type_variation = "BodyLabel"
	modeText.add_theme_font_size_override("font_size", 18)
	modeText.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(modeText)
	body.add_child(head)
	tierRow.add_theme_constant_override("separation", 8)
	for tier in ModeTiers.TIERS: tierRow.add_child(makeTierButton(tier))
	body.add_child(tierRow)
	#under the switch: why it can't start, what a win opens and the first-clear bonus still to earn
	stakes.add_theme_constant_override("separation", 30)
	stakes.custom_minimum_size.y = 28
	stakes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(stakes)
	body.add_child(paneRule())
	buildCarStrip()
	body.add_child(carStrip)
	buildLaunch()
	var records = PanelContainer.new()
	records.position = RECORDS_PANEL.position
	records.size = RECORDS_PANEL.size
	records.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), PANEL_EDGE, 16, 2, Vector4(22, 8, 22, 8)))
	records.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recordsBox.add_theme_constant_override("separation", 28)
	recordsBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	records.add_child(recordsBox)
	options.add_child(records)

#the launch plate, the bottom section's right part, left to right in the order they are set: the driver, the
#gadget and boost slots, each with what it holds written beside it, and a round START with a badge for the
#gems the loadout takes
func buildLaunch() -> void:
	var plate = Panel.new()
	plate.position = LAUNCH_PLATE.position
	plate.size = LAUNCH_PLATE.size
	plate.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), PANEL_EDGE, 16, 2, Vector4.ZERO))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.add_child(plate)
	driverButton = Button.new()
	MenuTheme.addSounds(driverButton)
	driverButton.position = DRIVER_BUTTON.position
	driverButton.size = DRIVER_BUTTON.size
	driverButton.tooltip_text = "Next driver"
	driverButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	driverButton.focus_mode = Control.FOCUS_NONE
	roundStyles(driverButton, DRIVER_BUTTON.size.y / 2.0)
	driverButton.pressed.connect(stepDriver.bind(1))
	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -16
	row.add_theme_constant_override("separation", 10)
	driverSide.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	driverSide.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	driverSide.custom_minimum_size = Vector2(92, 36)
	driverSide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(driverSide)
	var words = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -4)
	words.add_child(paneTag("DRIVER"))
	driverLabel.add_theme_font_size_override("font_size", 18)
	driverLabel.clip_text = true
	driverLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(driverLabel)
	row.add_child(words)
	var keys = KeyHint.make(PackedStringArray(["ui_tab_prev", "ui_tab_next"]), "", 13)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(keys)
	driverButton.add_child(row)
	setMouseIgnore(row)
	options.add_child(driverButton)
	loadoutButton = loadoutSlotButton("loadout", "ui_upgrade", SLOT_SPOTS[0], cycleLoadout)
	boostButton = loadoutSlotButton("boostLoadout", "ui_boost", SLOT_SPOTS[1], cycleBoost)
	startButton = roundPrimary("START")
	startButton.pressed.connect(onStartPressed)
	options.add_child(startButton)
	startBadge.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.06, 0.07, 0.09), Color(0.3, 0.72, 1.0), 13, 2, Vector4(9, 0, 9, 0)))
	startBadge.position = Vector2(START_POS.x + START_SIZE - 60.0, START_POS.y - 8.0)
	startBadge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	startBadge.visible = false
	options.add_child(startBadge)

#the round primary button of run setup, bottom right on both steps (SELECT, then START): its word over its key
func roundPrimary(text: String) -> Button:
	var b := MenuTheme.button(text, PackedStringArray(), true)
	b.position = START_POS
	b.size = Vector2(START_SIZE, START_SIZE)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = MenuTheme.theme().get_stylebox(state, "PrimaryButton").duplicate()
		if style is StyleBoxFlat:
			style.set_corner_radius_all(int(START_SIZE / 2.0))
			style.corner_detail = 16
			style.content_margin_left = 4
			style.content_margin_right = 4
			style.content_margin_top = 0
			style.content_margin_bottom = 24 #the word sits over its key
		b.add_theme_stylebox_override(state, style)
	var key = KeyHint.make(PackedStringArray(["ui_accept"]), "", 13)
	key.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	key.offset_top = -40
	key.offset_bottom = -15
	key.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(key)
	setMouseIgnore(key)
	return b

#a dark round (or pill) button: its rim lights on hover
static func roundStyles(b: Button, radius: float) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style = MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(HudTheme.RIM, 0.9) if state == "hover" else Color(1, 1, 1, 0.3), int(radius), 2, Vector4.ZERO)
		style.corner_detail = 12
		b.add_theme_stylebox_override(state, style)

#a small muted heading in the pane ("GOAL", "GOONS")
static func paneTag(text: String) -> Label:
	var tag = Label.new()
	tag.text = text
	tag.theme_type_variation = "MutedLabel"
	tag.add_theme_font_size_override("font_size", 15)
	return tag

static func paneRule() -> ColorRect:
	var rule = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.14)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

#"DRIVER (side view) Name", top right under the bank, on the road map
func buildDriverChip() -> void:
	var chip = PanelContainer.new()
	chip.theme_type_variation = "QuietPanel"
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -24
	chip.offset_top = 88
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var tag = Label.new()
	tag.text = "DRIVER"
	tag.theme_type_variation = "MutedLabel"
	tag.add_theme_font_size_override("font_size", 14)
	row.add_child(tag)
	driverPic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	driverPic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	driverPic.custom_minimum_size = Vector2(84, 32)
	row.add_child(driverPic)
	driverName.add_theme_font_size_override("font_size", 18)
	row.add_child(driverName)
	chip.add_child(row)
	setup.add_child(chip)
	driverChip = chip

#a loadout slot on the launch plate: a round button showing the pickup it holds (or a plus) over its key,
#with what it holds written to its right (refreshLoadout). F / Y (V / RS for the boost) and clicks cycle it.
func loadoutSlotButton(slot: String, action: String, at: Vector2, onPress: Callable) -> Button:
	var b := Button.new()
	MenuTheme.addSounds(b)
	b.position = at
	b.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE #the focus stays on START
	roundStyles(b, SLOT_SIZE / 2.0)
	b.pressed.connect(onPress)
	var pic = TextureRect.new()
	pic.name = "pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2((SLOT_SIZE - 34.0) / 2.0, 6)
	pic.size = Vector2(34, 34)
	b.add_child(pic)
	var plus = Label.new()
	plus.name = "plus"
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 28)
	plus.add_theme_color_override("font_color", HudTheme.MUTED)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.position = pic.position
	plus.size = pic.size
	b.add_child(plus)
	var key = KeyHint.make(PackedStringArray([action]), "", 13)
	key.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	key.offset_top = -24
	key.offset_bottom = 2
	key.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(key)
	for child in [pic, plus, key]: setMouseIgnore(child)
	options.add_child(b)
	var caption = VBoxContainer.new()
	caption.position = Vector2(at.x + SLOT_SIZE + 12.0, at.y)
	caption.size = Vector2(180, SLOT_SIZE)
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override("separation", -2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.add_child(caption)
	slotCaptions[slot] = caption
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

#each slot: the chosen pickup's icon on the button (a plus when empty), and beside it the pickup's name over
#its uses and price, or "GADGET" over "from 1 (gem)"; the tooltip has the pickup's text and the key that
#fires it in the run. START's badge shows the gems both will take.
func refreshLoadout() -> void:
	for pair in [[loadoutButton, "loadout", "UseItem", "GADGET"], [boostButton, "boostLoadout", "UseMove", "BOOST"]]:
		var button: Button = pair[0]
		if not is_instance_valid(button): continue
		var id := slotPurchase(pair[1])
		var prices := slotPrices(pair[1])
		var key := InputGlyphs.label(pair[2])
		button.get_node("pic").texture = Pickups.texture(id) if id != "" else null
		button.get_node("plus").visible = id == ""
		var title: String = pair[3]
		var parts: Array
		if id != "":
			var uses: int = Pickups.DATA[id].get("charges", 1)
			title = Pickups.displayName(id).to_upper()
			parts = ["x%d   " % uses if uses > 1 else "", {"gem": prices[id]}]
			button.tooltip_text = "%s\nIn the run: press %s" % [Pickups.DATA[id].get("text", ""), key]
		elif prices.is_empty():
			parts = ["none unlocked"]
			button.tooltip_text = "Unlock one in Pickups (%s)" % InputGlyphs.label("ui_pickups")
		else:
			parts = ["from ", {"gem": prices.values().min()}]
			button.tooltip_text = "Start the run with one. In the run: press %s" % key
		var caption: VBoxContainer = slotCaptions[pair[1]]
		for child in caption.get_children():
			caption.remove_child(child)
			child.queue_free()
		var head := stakeLabel(title, HudTheme.TEXT if id != "" else HudTheme.MUTED, 16)
		head.clip_text = true
		caption.add_child(head)
		var line := MenuTheme.symbolRow(parts, 15, HudTheme.MUTED)
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		caption.add_child(line)
	#the gems Start will take, on the button
	var cost := 0
	for slot in SLOTS: cost += int(slotPrices(slot).get(slotPurchase(slot), 0))
	for child in startBadge.get_children():
		startBadge.remove_child(child)
		child.queue_free()
	startBadge.visible = cost > 0
	if cost > 0: startBadge.add_child(MenuTheme.symbolRow(["-", {"gem": cost}], 15))

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

#a level as a stop on the road: its poster art, "1  PRAIRIE RUN", a glyph per mode (the best medal won
#there, over a bar for the current driver's own) and a lock when locked
func makePoster(index: int) -> Control:
	var image := posterPath(index)
	var artSize := Vector2(POSTER_SIZE.x, POSTER_ART)
	var poster = Panel.new()
	poster.size = POSTER_SIZE
	poster.pivot_offset = POSTER_SIZE / 2.0
	poster.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.09, 0.075, 0.065), Color(0, 0, 0, 0), 18, 0))
	var art = TextureRect.new()
	art.name = "art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = artSize
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_child(art)
	if ResourceLoader.has_cached(image) || index == SaveManager.playerData.selectedLevel: art.texture = load(image)
	else:
		ResourceLoader.load_threaded_request(image)
		pendingPosters[index] = image
	var band = PanelContainer.new()
	band.name = "band"
	band.theme_type_variation = "BandPanel"
	band.position = Vector2(0, POSTER_ART)
	band.size = Vector2(POSTER_SIZE.x, POSTER_BAND)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label = Label.new()
	label.name = "name"
	label.theme_type_variation = "DarkLabel"
	label.add_theme_font_size_override("font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "%d  %s" % [index % Territories.STOPS + 1, levelName(index).to_upper()]
	band.add_child(label)
	poster.add_child(band)
	var glyphs = HBoxContainer.new()
	glyphs.name = "glyphs"
	glyphs.alignment = BoxContainer.ALIGNMENT_CENTER
	glyphs.add_theme_constant_override("separation", 11)
	glyphs.position = Vector2(0, POSTER_ART + POSTER_BAND)
	glyphs.size = Vector2(POSTER_SIZE.x, POSTER_SIZE.y - POSTER_ART - POSTER_BAND)
	glyphs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for mode in modeOrder(index):
		var cell = VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glyph = MenuTheme.iconRect(HudTheme.MODE_ICONS[mode], 26)
		glyph.name = "glyph"
		cell.add_child(glyph)
		var bar = ColorRect.new()
		bar.name = "bar"
		bar.custom_minimum_size = Vector2(26, 4)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(bar)
		glyphs.add_child(cell)
	poster.add_child(glyphs)
	var lock = VBoxContainer.new()
	lock.name = "lock"
	lock.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.size = artSize
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lockIcon = MenuTheme.iconRect(HudTheme.LOCK_ICON, 34)
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
	var catcher = Button.new() #a click on another stop selects it; a click on the selected one opens its options
	catcher.name = "catcher"
	catcher.flat = true
	catcher.focus_mode = Control.FOCUS_NONE
	catcher.size = POSTER_SIZE
	catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]: catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(onPosterPressed.bind(index))
	poster.add_child(catcher)
	return poster

func onPosterPressed(index: int) -> void:
	if index == SaveManager.playerData.selectedLevel: openOptions()
	else: stepLevelTo(index)

## The modes of a level's mode rows and poster glyphs, in order (Root.modePath)
func modeOrder(index := -1) -> Array:
	return Root.modePath(SaveManager.playerData.selectedLevel if index < 0 else index)

func onModeRowPressed(slot: int) -> void:
	var order := modeOrder()
	if slot == MODE_SLOTS:
		cycleFreePlay()
		return
	if slot >= order.size() || order[slot] == SaveManager.getGameMode(): return
	SaveManager.setGameMode(order[slot])
	refreshSetup()

## The Free Play row: each press picks the next mode this level doesn't play (Root.freePlayModes)
func cycleFreePlay() -> void:
	var level := selectedLevelForModes()
	var free := Root.freePlayModes(level)
	if free.is_empty() || not Root.freePlayOpen(level): return
	SaveManager.setGameMode(free[wrapi(free.find(SaveManager.getGameMode()) + 1, 0, free.size())])
	refreshSetup()

#one of Level Options' five mode rows: the mode's icon in a ring (a lock while it can't be started), its
#name, and at the right three medals over the current driver's bar; a mode that isn't built yet is
#a slim row that says so. refreshModeRow fills it.
func makeModeRow(slot: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = MODE_ROW
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(onModeRowPressed.bind(slot))
	MenuTheme.addSounds(b)
	var row = HBoxContainer.new()
	row.name = "row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -18
	row.add_theme_constant_override("separation", 14)
	var disc = Panel.new()
	disc.name = "disc"
	disc.custom_minimum_size = Vector2(40, 40)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon = TextureRect.new()
	icon.name = "icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]: icon.set(side, 7)
	for side in ["offset_right", "offset_bottom"]: icon.set(side, -7)
	disc.add_child(icon)
	row.add_child(disc)
	var words = VBoxContainer.new()
	words.name = "words"
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -3)
	var label = Label.new()
	label.name = "name"
	label.add_theme_font_size_override("font_size", 22)
	label.clip_text = true
	words.add_child(label)
	row.add_child(words)
	var soon = Label.new() #an unbuilt mode's slim row
	soon.name = "soon"
	soon.text = "Coming soon"
	soon.theme_type_variation = "MutedLabel"
	soon.add_theme_font_size_override("font_size", 15)
	row.add_child(soon)
	var marks = VBoxContainer.new()
	marks.name = "marks"
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 6)
	var medals = HBoxContainer.new() #the best tier beaten here: bronze, silver, gold
	medals.name = "medals"
	medals.add_theme_constant_override("separation", 5)
	for tier in ModeTiers.TIERS: medals.add_child(medalDot(20))
	marks.add_child(medals)
	var mine = ColorRect.new() #the current driver's own medal in this mode here
	mine.name = "mine"
	mine.custom_minimum_size = Vector2(70, 4)
	marks.add_child(mine)
	row.add_child(marks)
	b.add_child(row)
	setMouseIgnore(row)
	return b

#a medal: a disc in the tier's color once it is won (setMedal), a dark ring until then
static func medalDot(size: float) -> Panel:
	var dot = Panel.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setMedal(dot, ModeTiers.NONE)
	return dot

static func setMedal(dot: Panel, tier: int) -> void:
	var won := tier > ModeTiers.NONE
	var color: Color = ModeTiers.MEDAL_COLORS[tier] if won else Color(1, 1, 1, 0.06)
	var style = MenuTheme.box(color, color.lightened(0.5) if won else Color(1, 1, 1, 0.26), int(dot.custom_minimum_size.x / 2.0), 2, Vector4.ZERO)
	style.corner_detail = 10
	dot.add_theme_stylebox_override("panel", style)

#a tier's segment of the switch: its medal (or a lock) and name over its goal and its pay, filled by
#refreshTiers; a click picks it (the focus stays on START)
func makeTierButton(tier: int) -> Button:
	var b := Button.new()
	b.name = ModeTiers.NAMES[tier]
	b.custom_minimum_size = Vector2(0, TIER_SEGMENT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body = VBoxContainer.new()
	body.name = "body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10
	body.offset_right = -10
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 4)
	var head = HBoxContainer.new()
	head.name = "head"
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 9)
	var medal := medalDot(20)
	medal.name = "medal"
	head.add_child(medal)
	var lock = MenuTheme.iconRect(HudTheme.LOCK_ICON, 20)
	lock.name = "lock"
	head.add_child(lock)
	var label = Label.new()
	label.name = "name"
	label.text = ModeTiers.NAMES[tier].to_upper()
	label.add_theme_font_size_override("font_size", 22)
	head.add_child(label)
	body.add_child(head)
	var goal = Label.new()
	goal.name = "goal"
	goal.theme_type_variation = "BodyLabel"
	goal.add_theme_font_size_override("font_size", 16) #the longest goal ("Beat the bronze time over the stage") fits a segment
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.clip_text = true
	body.add_child(goal)
	var pay = HBoxContainer.new()
	pay.name = "pay"
	pay.alignment = BoxContainer.ALIGNMENT_CENTER
	pay.custom_minimum_size.y = 24
	body.add_child(pay)
	b.add_child(body)
	setMouseIgnore(body)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(selectTier.bind(tier))
	MenuTheme.addSounds(b)
	tierButtons.push_back(b)
	return b

#a button at the road's start (side 0: the region before) or end (side 1: the one after): the key that
#goes there, the region's name and a lock while it is closed; a click goes there (refreshRegionButtons)
func makeRegionButton(side: int) -> Button:
	var b := Button.new()
	b.name = "regionNext" if side == 1 else "regionPrev"
	b.position = REGION_SPOTS[side] - REGION_BUTTON / 2.0
	b.size = REGION_BUTTON
	b.pivot_offset = REGION_BUTTON / 2.0
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(stepRegion.bind(1 if side == 1 else -1))
	MenuTheme.addSounds(b)
	var body = VBoxContainer.new()
	body.name = "body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 8
	body.offset_right = -8
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 5)
	var hint = KeyHint.make(PackedStringArray(["ui_region_next" if side == 1 else "ui_region_prev"]), "", 15)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(hint)
	var label = Label.new()
	label.name = "name"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_constant_override("line_spacing", -2)
	body.add_child(label)
	var lock = HBoxContainer.new()
	lock.name = "lock"
	lock.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.add_theme_constant_override("separation", 4)
	lock.add_child(MenuTheme.iconRect(HudTheme.LOCK_ICON, 18))
	var lockText = Label.new()
	lockText.name = "text"
	lockText.theme_type_variation = "MutedLabel"
	lockText.add_theme_font_size_override("font_size", 12)
	lock.add_child(lockText)
	body.add_child(lock)
	b.add_child(body)
	setMouseIgnore(body)
	return b

#each end's button names the region it leads to, in that region's color; no button past the first and
#last regions; a lock on a region that isn't open yet
func refreshRegionButtons(region: int) -> void:
	for side in 2:
		var b := regionButtons[side]
		var target := region + (1 if side == 1 else -1)
		b.visible = target >= 0 && target < Territories.ORDER.size()
		if not b.visible: continue
		var def := Territories.get_def(Territories.ORDER[target])
		var color: Color = def.get("color", HudTheme.RIM)
		var open := isRegionOpen(target)
		var style = MenuTheme.box(HudTheme.PANEL.lerp(color, 0.2), Color(color, 0.85 if open else 0.4), 14, 3, Vector4(8, 6, 8, 6))
		for state in ["normal", "pressed"]: b.add_theme_stylebox_override(state, style)
		var hover = style.duplicate()
		hover.border_color = color if open else Color(color, 0.4)
		hover.bg_color = HudTheme.PANEL.lerp(color, 0.32 if open else 0.2)
		b.add_theme_stylebox_override("hover", hover)
		var label: Label = b.get_node("body/name")
		label.text = "%d  %s" % [target + 1, str(def.get("name", "")).to_upper()]
		label.add_theme_color_override("font_color", HudTheme.TEXT if open else HudTheme.MUTED)
		b.get_node("body/lock").visible = not open
		b.get_node("body/lock/text").text = "NOT IN DEMO" if Root.IS_DEMO && not def.get("demo", true) else "LOCKED"
		b.modulate = Color.WHITE if open else Color(1, 1, 1, 0.7)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
		b.tooltip_text = "" if open else "Win the Marathon on Medium at the finale of the region before it"

func selectedRegion() -> int:
	return SaveManager.playerData.selectedLevel / Territories.STOPS

#a region is open once its first stop is (and the demo offers it)
func isRegionOpen(region: int) -> bool:
	var first := region * Territories.STOPS
	return region >= 0 && first < posters.size() && isLevelSelectable(first)

#a region button, or Z/C: the region before or after, when it is open (the button shakes when it isn't)
func stepRegion(direction: int) -> void:
	var target := selectedRegion() + direction
	if target < 0 || target >= Territories.ORDER.size(): return
	if isRegionOpen(target): selectRegion(target)
	else: Juice.shake(regionButtons[1 if direction > 0 else 0])

#a region opens at its furthest stop that can be started, else its first
func selectRegion(region: int) -> void:
	region = wrapi(region, 0, Territories.ORDER.size())
	var first := region * Territories.STOPS
	var pick := first
	for stop in Territories.STOPS:
		if first + stop < posters.size() && isLevelSelectable(first + stop): pick = first + stop
	stepLevelTo(pick)

#the road from one end's button to the other's (or the screen's edge where there is none), swinging
#through the region's five stops
func roadCurve() -> Curve2D:
	var curve := Curve2D.new()
	var bend := Vector2(ROAD_BEND, 0)
	var start: Vector2 = REGION_SPOTS[0] if regionButtons[0].visible else Vector2(-60, REGION_SPOTS[0].y)
	var end: Vector2 = REGION_SPOTS[1] if regionButtons[1].visible else Vector2(1660, REGION_SPOTS[1].y)
	curve.add_point(start, -bend * 0.5, bend * 0.5)
	for spot in STOP_SPOTS: curve.add_point(spot + Vector2(0, 20), -bend, bend)
	curve.add_point(end, -bend * 0.5, bend * 0.5)
	return curve

func drawRoad() -> void:
	var color: Color = Territories.get_def(Territories.ORDER[selectedRegion()]).get("color", HudTheme.RIM)
	var curve := roadCurve()
	var points := curve.get_baked_points()
	road.draw_polyline(points, Color(color, 0.45), 40.0, true)
	road.draw_polyline(points, Color(0.13, 0.12, 0.11, 0.95), 30.0, true)
	var length := curve.get_baked_length()
	var at := 0.0
	while at < length: #the center line's dashes, laid along the curve
		road.draw_line(curve.sample_baked(at), curve.sample_baked(minf(at + 14.0, length)), Color(HudTheme.GOLD, 0.8), 3.0, true)
		at += 30.0

func buildCarStrip() -> void:
	outlineMaterial = ShaderMaterial.new()
	outlineMaterial.shader = Shader.new()
	outlineMaterial.shader.code = OUTLINE_SHADER
	carStrip.add_theme_constant_override("separation", 6)
	carStrip.custom_minimum_size.y = CAR_CELL_BIG.y + 6
	carStripLabel.add_theme_font_size_override("font_size", 14)
	carStripLabel.custom_minimum_size = Vector2(96, 0)
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

static func isCarOwned(index: int) -> bool:
	return int(SaveManager.playerData.cars[index].cost) == 0 && not (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT)

#which cars have won this mode here on this tier: in color = cleared, dim = owned but not cleared,
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
		pic.modulate = Color.WHITE if cleared || not owned else Color(0.3, 0.3, 0.34)
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if owned && not current else Control.CURSOR_ARROW
		var carName: String = cards[i].info.charName
		cell.tooltip_text = "%s: %s" % [carName, ("won on " + ModeTiers.NAMES[best]) if cleared else ("not won yet" if owned else "not owned")]
	var full := SaveManager.isFullGarage(index, mode, tier)
	carStripLabel.text = "FULL\nGARAGE" if full else "WON HERE\n%d / %d" % [SaveManager.carsCleared(index, mode, tier), cars.size()]
	carStripLabel.add_theme_color_override("font_color", HudTheme.GOLD if full else HudTheme.MUTED)

#a click on an owned car in the strip makes it the driver
func onCarCellPressed(index: int) -> void:
	if not isCarOwned(index) || index == SaveManager.playerData.selectedCar: return
	selectCar(index, false)
	refreshSetup(false)

#the switch: the selected tier lit, a locked one dim under a lock; each segment has its medal once that tier
#is beaten, its goal and what a win pays, so the three compare at a glance. Under it (stakes): `reason`, why
#the run can't be started, or what a win opens (opensText), and the first-clear bonus still to earn.
func refreshTiers(level: Dictionary, mode: int, index: int, reason: String) -> void:
	var selected := SaveManager.getGameTier()
	var best := ModeTiers.best(level, mode)
	var def := levelDef(index)
	for i in tierButtons.size():
		var b := tierButtons[i]
		var tier: int = ModeTiers.TIERS[i]
		var on := tier == selected
		var open := ModeTiers.isOpen(level, mode, tier)
		var style = MenuTheme.box(HudTheme.PANEL.lerp(HudTheme.RIM, 0.16) if on else Color(HudTheme.PANEL, 0.6), HudTheme.RIM if on else Color(1, 1, 1, 0.22), 12, 3 if on else 2, Vector4(8, 4, 8, 4))
		for state in ["normal", "pressed"]: b.add_theme_stylebox_override(state, style)
		var hover = style.duplicate()
		hover.border_color = HudTheme.GOLD if on else Color(HudTheme.RIM, 0.8)
		b.add_theme_stylebox_override("hover", hover)
		b.modulate = Color.WHITE if open || on else Color(1, 1, 1, 0.6)
		var medal: Panel = b.get_node("body/head/medal")
		medal.visible = open
		setMedal(medal, tier if best >= tier else ModeTiers.NONE)
		b.get_node("body/head/lock").visible = not open
		b.get_node("body/head/name").add_theme_color_override("font_color", HudTheme.GOLD if on else HudTheme.TEXT)
		b.get_node("body/goal").text = ModeTiers.goalText(mode, tier, def.seconds if def else 300.0, def.sprintSlack if def else 1.3)
		var pay: HBoxContainer = b.get_node("body/pay")
		for child in pay.get_children():
			pay.remove_child(child)
			child.queue_free()
		var win := ModeTiers.winBonus(mode, tier, index)
		if not open: pay.add_child(stakeLabel("Beat Medium first", LOCK_TEXT, 15))
		elif win > 0: pay.add_child(MenuTheme.symbolRow(["+", {"coin": win}], 20, HudTheme.GOLD))
		setMouseIgnore(pay)
	for child in stakes.get_children():
		stakes.remove_child(child)
		child.queue_free()
	if reason != "" && reason != ModeTiers.lockReason(level, mode, selected): stakes.add_child(stakeLabel(reason, LOCK_TEXT)) #a locked tier says so itself
	elif reason == "":
		var opens := opensText(level, index, mode, selected)
		if opens != "": stakes.add_child(stakeLabel(opens, OPENS_TEXT))
	if ModeTiers.winBonus(mode, selected, index) > 0: #a mode that isn't built yet pays nothing
		var first := ModeTiers.firstClear(best, selected, index)
		if first.coin > 0 || first.gem > 0: stakes.add_child(MenuTheme.symbolRow(["FIRST CLEAR  +", first], 17, HudTheme.GOLD))
		else: stakes.add_child(stakeLabel("First clear paid", HudTheme.MUTED, 15))

static func stakeLabel(text: String, color: Color, fontSize := 17) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", fontSize)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

## What winning this mode on this tier would open, "" when nothing new: Countdown behind Sprint, the level's
## featured modes behind Countdown, and the next level behind a road mode (Root.roadModes; a finale needs Medium)
func opensText(level: Dictionary, index: int, mode: int, tier: int) -> String:
	var beat: Dictionary = level.get("gamemodeBeat", {})
	if mode == Root.gameModes.SPRINT:
		return "" if beat.get(mode, false) else "A win opens Countdown here"
	if mode == Root.gameModes.GOONCRUSHER && not beat.get(mode, false):
		var names := Root.featuredModes(level).filter(func(m): return Root.isModeAvailable(m)).map(func(m): return Root.modeName(m).capitalize())
		if not names.is_empty(): return "A win opens %s here" % ", ".join(names)
	var levels = SaveManager.playerData.levels
	var next := index + 1
	if mode not in Root.roadModes(level) || Root.opensNextLevel(level) || next >= levels.size() || levels[next].unlocked || isDemoLockedLevel(next): return ""
	var need := Root.tierToOpenNext(level)
	var place := levelName(next).to_upper()
	return "A win opens %s" % place if tier >= need else "A win on %s opens %s" % [ModeTiers.NAMES[need], place]

## The records here, bottom left: the current driver's best medal on this level and mode beside the best by
## any car and who holds it, with the record book's time or score where the mode keeps one
func refreshRecords(index: int, mode: int) -> void:
	for child in recordsBox.get_children():
		recordsBox.remove_child(child)
		child.queue_free()
	var cars = SaveManager.playerData.cars
	var me: int = SaveManager.playerData.selectedCar
	var bestTier := ModeTiers.NONE
	var holders := []
	for i in cars.size():
		var t := SaveManager.carClearTier(index, mode, str(cars[i].name))
		if t > bestTier:
			bestTier = t
			holders = [i]
		elif t == bestTier && t > ModeTiers.NONE: holders.push_back(i)
	recordsBox.add_child(recordColumn("%s HERE" % driverOf(me).to_upper(), SaveManager.carClearTier(index, mode, str(cars[me].name)), recordText(index, mode, str(cars[me].name))))
	var who := ", ".join(holders.slice(0, 3).map(driverOf)) + (" +%d" % (holders.size() - 3) if holders.size() > 3 else "")
	var bestBook := ""
	for i in holders: bestBook = recordText(index, mode, str(cars[i].name)) if bestBook == "" else bestBook
	recordsBox.add_child(recordColumn("BEST BY ANY CAR", bestTier, who + ("  -  " + bestBook if bestBook != "" else "")))

func driverOf(carIndex: int) -> String:
	var card := cards[carIndex]
	return card.info.charName if card.info else str(SaveManager.playerData.cars[carIndex].name).capitalize()

func recordColumn(title: String, tier: int, detail: String) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -2)
	column.add_child(paneTag(title))
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 9)
	var medal := medalDot(20)
	setMedal(medal, tier)
	line.add_child(medal)
	line.add_child(stakeLabel("Won on %s" % ModeTiers.NAMES[tier] if tier > ModeTiers.NONE else "Not won yet", HudTheme.TEXT if tier > ModeTiers.NONE else HudTheme.MUTED, 20))
	column.add_child(line)
	var small := stakeLabel(detail, HudTheme.MUTED, 15)
	small.clip_text = true
	small.visible = detail != ""
	column.add_child(small)
	return column

#the record book's line for a car here: a fixed course's best time, Goonpocalypse's best time and score
func recordText(index: int, mode: int, carName: String) -> String:
	if Modes.isFixedMap(mode):
		var course := SaveManager.bestCourse(index, mode, carName)
		if course.is_empty(): return ""
		var t := float(course.get("time", 0.0))
		return "Best time %d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
	if mode == Root.gameModes.GOONPOCALYPSE:
		var best := SaveManager.bestGoonpocalypse(index, carName)
		if best.time > 0: return "Best %d:%02d, score %d" % [best.time / 60, best.time % 60, best.score]
	return ""

#children of a clickable card let the click through (docs/UI.md, "Mouse")
static func setMouseIgnore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): setMouseIgnore(child)

## A level's facts as groups of tiles: GOONS (the line-up; one not crushed yet is a question mark), GROUND (a
## swatch of each surface), PROPS (what stands on the level) and RULES (its night, its events and its own
## rules, from LevelDef.rules). Z/C (LT/RT) walk the tiles (stepFact; with Shift, a group at a time) and the
## tile walked to, or the one under the mouse, fills the card beside them (showFact); a click on a goon's
## tile opens the Goonopedia.
func fillFacts(index: int) -> void:
	if index == factsFor: return
	factsFor = index
	factAt = -1
	factTiles.clear()
	factStarts.clear()
	for child in optionsFacts.get_children():
		optionsFacts.remove_child(child)
		child.queue_free()
	var def := levelDef(index)
	if def == null: return
	def.resolve()
	var goons := factGroup("GOONS")
	for id in LevelRoster.lineupFor(def).slice(0, FACT_CAPS.goons):
		var d: Dictionary = Goons.DATA[id]
		var tile: Button
		if Goonopedia.isDiscovered(id) && ResourceLoader.exists(Goonopedia.goonArt(id)):
			var art: Texture2D = load(Goonopedia.goonArt(id))
			var crop = AtlasTexture.new() #the goon without the frame's empty margin
			crop.atlas = art
			crop.region = Goonopedia.artBounds(art)
			tile = factTile(crop, {"title": str(d.name).to_upper(), "line": Goonopedia.behavior(d), "chips": [[Goonopedia.RANK_NAMES.get(d.rank, "GOON"), HudTheme.RIM]]})
		else: tile = factTile(null, {"title": "???", "line": "Crush one to find out what it does.", "chips": []}, false, "?")
		tile.pressed.connect(openGoonopedia)
		goons.get_node("tiles").add_child(tile)
	var rows := Goonopedia.regionRows(def)
	if rows.size() > 3: #an elite region's step
		var tag: Label = goons.get_child(0)
		tag.text = "GOONS  ELITE"
		tag.add_theme_color_override("font_color", LOCK_TEXT)
		tag.tooltip_text = "Elite goons: %s" % rows[3][1]
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
	var ground := factGroup("GROUND")
	var land := Landscapes.get_def(def.landscape)
	var seen := []
	for t in def.baseTerrain + def.accents:
		var terrain := int(t)
		if terrain in seen || seen.size() >= FACT_CAPS.ground || terrain < 0 || terrain >= World.count(): continue
		var material: String = land.materialOf(terrain) if land else WorldSkin.MATERIAL_OF[terrain]
		var path := WorldSkin.GROUND_DIR + material + ".png"
		if not ResourceLoader.exists(path): continue
		seen.push_back(terrain)
		var info := World.def(terrain)
		var feel := "slick" if info.grip <= 0.5 else ("slow" if info.friction >= 0.3 else ("fast" if info.friction <= 0.05 else ""))
		var chips := [["Friction %.2f" % info.friction, HudTheme.MUTED], ["Grip %.1f" % info.grip, HudTheme.MUTED]]
		if feel != "": chips.push_front([feel.to_upper(), {"slick": LOCK_TEXT, "slow": HudTheme.RIM, "fast": OPENS_TEXT}[feel]])
		var line: String = {"fast": "Fast ground: the car keeps its speed.", "slow": "Slow ground: it drags the car down.", "slick": "Slick: the tires let go easily."}.get(feel, "Ordinary ground.")
		var tile: Texture2D = load(path)
		var swatch = AtlasTexture.new() #a corner of the tile
		swatch.atlas = tile
		swatch.region = Rect2(Vector2.ZERO, Vector2(96, 96).min(tile.get_size()))
		ground.get_node("tiles").add_child(factTile(swatch, {"title": material.capitalize().to_upper(), "line": line, "chips": chips}, true))
	var props := factGroup("PROPS")
	var manifest := WorldSkin.loadManifest()
	var ids := []
	for id in WorldSkin.FIELD_PROPS:
		if float(def.features.get(WorldSkin.FIELD_PROPS[id], 0.0)) > 0.0: ids.push_back(String(id))
	for id in def.heroes: ids.push_back(String(id))
	for id in def.dressing:
		if float(def.dressing[id]) > 0.0: ids.push_back(String(id))
	var shown := []
	for id in ids:
		var entry = manifest.get(id)
		if id in shown || shown.size() >= FACT_CAPS.props || not entry is Dictionary || entry.get("variants", []).is_empty(): continue
		if not ResourceLoader.exists(entry.variants[0]): continue
		shown.push_back(id)
		var breaks: bool = entry.get("breakable") is Dictionary
		var chips := []
		if breaks: chips.push_back(["Smashes at %s" % Settings.speed_text(float(entry.breakable.get("smashSpeed", 0.0))), HudTheme.RIM])
		else: chips.push_back(["SOLID", LOCK_TEXT])
		if StringName(id) in WorldSkin.PAYING_PROPS: chips.push_back(["Pays coins", HudTheme.GOLD])
		if entry.get("occluder", false): chips.push_back(["Blocks light", HudTheme.MUTED])
		var line := "Hit it at speed to smash through." if breaks else "It doesn't break. Steer around it."
		props.get_node("tiles").add_child(factTile(squarish(load(entry.variants[0])), {"title": id.capitalize().to_upper(), "line": line, "chips": chips}))
	var rules := factGroup("RULES")
	for fact in levelRules(def).slice(0, FACT_CAPS.rules):
		rules.get_node("tiles").add_child(factTile(fact.icon, fact))
	for group in [goons, ground, props, rules]:
		var count: int = group.get_node("tiles").get_child_count()
		if count == 0:
			group.queue_free()
			continue
		optionsFacts.add_child(group)
	var at := 0 #the tiles were made in group order
	for group in optionsFacts.get_children():
		factStarts.push_back(at)
		at += group.get_node("tiles").get_child_count()

#a long prop (a fence is 317 x 21) as its middle, at most twice as long as it is wide, so it fills a tile
static func squarish(texture: Texture2D) -> Texture2D:
	var size := texture.get_size()
	var longest := 2.0 * minf(size.x, size.y)
	if maxf(size.x, size.y) <= longest: return texture
	var crop = AtlasTexture.new()
	crop.atlas = texture
	var keep := Vector2(minf(size.x, longest), minf(size.y, longest))
	crop.region = Rect2((size - keep) / 2.0, keep)
	return crop

const EVENT_FACTS := {
	"goldgoon": ["GOLDEN GOON", "A golden goon breaks cover. Run it down for a payout."],
	"truck": ["LOOT TRUCK", "A truck full of loot drives through. Ram it."],
	"bowling": ["GOON BOWLING", "A lane of pins to knock down."],
	"rings": ["RING RUN", "A run of rings to drive through."],
	"stampede": ["STAMPEDE", "A Thunderhoof herd breaks cover across your path."],
	"flood": ["FLASH FLOOD", "Water runs down a wash and sweeps goons away."],
	"haywagon": ["HAY WAGON", "The Loot Truck as a hay wagon. Ram it."],
	"barge": ["BANDIT BARGE", "The Loot Truck as a barge. Ram it."],
}

## A level's rules as facts for its RULES tiles (LevelDef.rules): how much of each day is night, its own
## rules, then its events, the likeliest first
static func levelRules(def: LevelDef) -> Array:
	var out := []
	var night := float(def.rules.get("nightShare", 0.5))
	out.push_back({"title": "NIGHT", "icon": iconOr("moon"), "chips": [["%d%% of each day" % roundi(night * 100.0), HudTheme.MUTED]],
		"line": ("Long nights." if night >= 0.5 else "Short nights.") + " Only your headlights show the road."})
	if def.rules.get("dazeHeavies", false): out.push_back({"title": "DAZED HEAVIES", "icon": iconOr("wrecking"), "chips": [["RULE", HudTheme.RIM]],
		"line": "A heavy that charges into a wall is dazed and easier to crush."})
	if int(def.rules.get("oakCoins", 0)) > 0: out.push_back({"title": "OAK COINS", "icon": iconOr("coinstack"), "chips": [["RULE", HudTheme.RIM]],
		"line": "An oak drops coins on its first hard hit."})
	var events: Dictionary = def.rules.get("events", {})
	var order := events.keys().filter(func(id): return float(events[id]) > 0.0 && EVENT_FACTS.has(str(id)))
	order.sort_custom(func(a, b): return float(events[a]) > float(events[b]))
	for id in order:
		var words: Array = EVENT_FACTS[str(id)]
		out.push_back({"title": words[0], "icon": iconOr(str(id), PickupWorld.worldEventIcon(str(id))), "chips": [["EVENT", HudTheme.GOLD]], "line": words[1]})
	return out

#an icon by name from texture/icon (also without a plural s), or `fallback`
static func iconOr(id: String, fallback: Texture2D = null) -> Texture2D:
	for name in [id, id.trim_suffix("s")]:
		var path := "res://texture/icon/%s.svg" % name
		if ResourceLoader.exists(path): return load(path)
	return fallback

#a group of the level's facts: its tag over its tiles
static func factGroup(title: String) -> VBoxContainer:
	var group = VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(paneTag(title))
	var tiles = HBoxContainer.new()
	tiles.name = "tiles"
	tiles.add_theme_constant_override("separation", 5)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(tiles)
	return group

#a goon, a ground, a prop or a rule on a pale tile; `fill` covers the tile (a ground swatch) and `glyph`
#stands in for a picture (an unknown goon's question mark). The mouse on it shows `fact` in the card;
#markFact rings the one Z/C walked to.
func factTile(texture: Texture2D, fact: Dictionary, fill := false, glyph := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(FACT_ICON, FACT_ICON)
	b.set_meta("fact", fact)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, MenuTheme.box(Color(1, 1, 1, 0.09), Color(HudTheme.RIM, 0.9 if state == "hover" else 0.0), 8, 2, Vector4.ZERO))
	var pic = TextureRect.new()
	pic.name = "pic"
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE if fill else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 3.0 if fill else 5.0
	for side in ["offset_left", "offset_top"]: pic.set(side, inset)
	for side in ["offset_right", "offset_bottom"]: pic.set(side, -inset)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	if glyph != "":
		var mark = Label.new()
		mark.text = glyph
		mark.theme_type_variation = "MutedLabel"
		mark.add_theme_font_size_override("font_size", 24)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(mark)
	b.mouse_entered.connect(showFact.bind(fact))
	b.mouse_exited.connect(restoreFact)
	factTiles.push_back(b)
	return b

#the card beside the tiles: a tile's name, what matters about it and one line; {} shows the level's blurb
func showFact(fact: Dictionary) -> void:
	for child in factChips.get_children():
		factChips.remove_child(child)
		child.queue_free()
	var def := levelDef(SaveManager.playerData.selectedLevel)
	factTitle.text = fact.get("title", "")
	factTitle.visible = factTitle.text != ""
	factChips.visible = not fact.get("chips", []).is_empty()
	optionsBlurb.text = fact.get("line", def.blurb if def else "")
	optionsBlurb.add_theme_color_override("font_color", MenuTheme.BODY_TEXT if not fact.is_empty() else HudTheme.MUTED)
	for chip in fact.get("chips", []):
		var label := paneTag(chip[0])
		label.add_theme_color_override("font_color", chip[1])
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		factChips.add_child(label)

#back to the fact of the tile Z/C walked to (the mouse left another), or to the blurb
func restoreFact() -> void:
	showFact(factTiles[factAt].get_meta("fact") if factAt >= 0 && factAt < factTiles.size() else {})

#Z/C (LT/RT) in Level Options: on to the next tile of the level's facts, or with `byGroup` (Shift) to the
#next group's first; past either end is no tile (the blurb)
func stepFact(direction: int, byGroup := false) -> void:
	if byGroup && not factStarts.is_empty():
		var group := -1
		for i in factStarts.size():
			if factAt >= factStarts[i]: group = i
		if direction < 0 && group >= 0 && factAt > factStarts[group]: group += 1 #back to this group's first
		group = wrapi(group + direction + 1, 0, factStarts.size() + 1) - 1
		factAt = factStarts[group] if group >= 0 else -1
	else: factAt = wrapi(factAt + direction + 1, 0, factTiles.size() + 1) - 1
	markFact()
	restoreFact()

#a white ring on the tile walked to
func markFact() -> void:
	for i in factTiles.size():
		factTiles[i].add_theme_stylebox_override("normal", MenuTheme.box(Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.92 if i == factAt else 0.0), 8, 2, Vector4.ZERO))

#another mode or level: the pane's content slides in from the right as it fades up
func slidePane() -> void:
	if paneTween: paneTween.kill()
	optionsPane.position.x = OPTIONS_PANE.position.x + 20.0
	paneBody.modulate.a = 0.2
	paneTween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	paneTween.tween_property(optionsPane, "position:x", OPTIONS_PANE.position.x, 0.18)
	paneTween.tween_property(paneBody, "modulate:a", 1.0, 0.18)

#a stop's button beside the title (or its number key): that level's options, if it is open
func optionsStop(stop: int) -> void:
	var index := selectedRegion() * Territories.STOPS + stop
	if index == SaveManager.playerData.selectedLevel || index >= SaveManager.playerData.levels.size(): return
	if not isLevelSelectable(index):
		Juice.shake(stopButtons[stop], 4.0)
		return
	SaveManager.playerData.selectedLevel = index
	SaveManager.save_character_data()
	SaveManager.setGameMode(defaultGameMode())
	refreshSetup(false)

#---------- garage ----------

func selectCar(index: int, animate := true) -> void:
	var cars = SaveManager.playerData.cars
	index = wrapi(index, 0, cars.size())
	var switched: bool = index != SaveManager.playerData.selectedCar #the driver speaks on a switch, not when the menu loads
	if switched:
		SaveManager.playerData.selectedCar = index
		SaveManager.save_character_data()
	if cards[index].info == null: finishCarLoad(index, true)
	Root.selectedCar = cars[index]
	Root.playerCar = null #the menu shows a car from its CarInfo, without loading the car scene
	Root.carInfo = cards[index].info
	if focusOpen: refreshBench()
	layoutCards(animate)
	showBackground(Root.carInfo.backgroundPic, animate)
	if switched && Root.carInfo.introAudio.size() > 0:
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
		if focusOpen: slot = [FOCUS_CARD_POS, 1.0] if offset == 0 else null #the other drivers leave
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
	if screen == Screen.GARAGE: focusGarage()

#the garage's focus: the bench's row in driver focus (the one it was on last), else the dock's main button
func focusGarage() -> void:
	var button: Button = bench.focusButton() if focusOpen else null
	if button == null: button = cards[SaveManager.playerData.selectedCar].mainButton
	button.grab_focus()

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
	if focusOpen: refreshBench() #its strong and weak line is against every car loaded

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

#---------- driver focus ----------
#Upgrades (F / Y, or the dock's button) opens it on the selected driver and closes it again: the other cards
#drive off, the card skids to the left and its bench slides in beside it. Q/E still change driver.

func toggleFocus(_stat := -1) -> void:
	if screen != Screen.GARAGE || overlayOpen(): return
	setFocusOpen(not focusOpen)

func setFocusOpen(open: bool, animate := true) -> void:
	if open == focusOpen: return
	focusOpen = open
	for card in cards: card.benchOpen = open
	if open:
		for i in cards.size(): #the strong and weak line compares every car
			if cards[i].info == null && not pendingInfos.has(i): requestCarInfo(i)
		refreshBench()
	else:
		for card in cards: card.mainButton.focus_neighbor_top = NodePath() #linked to the bench's last row while it was open
	slideBench(animate)
	layoutCards(animate)
	statUpdatesUiUpdate()

func refreshBench() -> void:
	var card := cards[SaveManager.playerData.selectedCar]
	if card.info == null: return
	bench.setup(card.index, card.info, cards.filter(func(c): return c.info != null).map(func(c): return c.info))
	bench.linkFocus(card.mainButton)

#in from the right behind the card, and back out; a fade with Reduce Motion, at once in the harnesses
func slideBench(animate: bool) -> void:
	if benchTween: benchTween.kill()
	var away := BENCH_POS + Vector2(1140, 0)
	if not animate || Transition.instant():
		bench.position = BENCH_POS
		bench.modulate.a = 1.0
		bench.visible = focusOpen
		return
	benchTween = create_tween()
	if Settings.reduce_motion():
		if not bench.visible: bench.modulate.a = 0.0
		bench.position = BENCH_POS
		bench.visible = true
		benchTween.tween_property(bench, "modulate:a", 1.0 if focusOpen else 0.0, 0.15)
	else:
		if not bench.visible: bench.position = away
		bench.modulate.a = 1.0
		bench.visible = true
		benchTween.tween_property(bench, "position", BENCH_POS if focusOpen else away, SLIDE_SECONDS + 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		Transition.sound("skid" if focusOpen else "whoosh", -14.0)
	if not focusOpen: benchTween.tween_callback(bench.hide)

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
	setFocusOpen(false, false) #back from run setup, the garage shows its drivers
	screen = Screen.SETUP
	SaveManager.setGameMode(defaultGameMode())
	optionsOpen = false
	switchLayer(setup, garage)
	refreshSetup(false)
	focusSetup()

#the road map's SELECT, a click on the selected stop or Accept: on to Level Options for that level
func openOptions() -> void:
	if screen != Screen.SETUP || optionsOpen: return
	if not isLevelSelectable(SaveManager.playerData.selectedLevel):
		Juice.shake(selectButton)
		return
	optionsOpen = true
	SaveManager.setGameMode(defaultGameMode())
	refreshSetup(false)
	options.position = Vector2.ZERO #a drop cut short by Back left it part-way
	if not Transition.instant(): Juice.dropIn(options, 30.0)
	focusSetup()

func closeOptions() -> void:
	if not optionsOpen: return
	optionsOpen = false
	refreshSetup(false)
	focusSetup()

#run setup's focus: START in Level Options, SELECT on the road map, so Accept always goes on
func focusSetup() -> void:
	(startButton if optionsOpen else selectButton).grab_focus()

func goToGarage() -> void:
	if screen == Screen.GARAGE: return
	Transition.play(showGarage, "GOONCRUSHER", "GARAGE 07")

func showGarage() -> void:
	screen = Screen.GARAGE
	switchLayer(garage, setup)
	showBackground(Root.carInfo.backgroundPic)
	updateHints()
	focusGarage()

func switchLayer(show: Control, hide: Control) -> void:
	hide.visible = false
	show.visible = true
	radioBar.width = 270.0 if show == garage else 330.0
	radioBar.custom_minimum_size = Vector2(radioBar.width, NowPlaying.SIZE.y)
	radioBar.size = radioBar.custom_minimum_size
	radioBar.queue_redraw()
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
	var top := 0
	for poster in posters: top = maxi(top, poster.get_index())
	map.move_child(posters[selected], top) #the selected stop over its neighbors
	map.visible = not optionsOpen
	options.visible = optionsOpen
	refreshRegionButtons(region)
	var territory := Territories.get_def(Territories.ORDER[region])
	regionTitle.text = "%d  %s" % [region + 1, str(territory.get("name", "")).to_upper()]
	regionTitle.add_theme_color_override("font_color", Color(territory.get("color", HudTheme.RIM)).lightened(0.25))
	regionBlurb.text = str(territory.get("blurb", ""))
	road.queue_redraw()
	var level = levels[selected]
	if posters[selected].get_node("art").texture == null: finishPosterLoad(selected, true)
	showBackground(posters[selected].get_node("art").texture, animate)
	var mode = SaveManager.getGameMode()
	if not Root.isModePlayable(SaveManager.playerData.levels[selected], mode) && mode not in modeOrder(selected): mode = Root.firstMode(selected) #the saved mode isn't one this level plays
	var forModes = selectedLevelForModes()
	var open := isLevelSelectable(selected)
	var data = SaveManager.playerData
	var driver := cards[data.selectedCar]
	var driverCar := str(data.cars[data.selectedCar].name)
	if driver.info:
		driverPic.texture = driver.info.sidePic
		driverName.text = driver.info.charName.to_upper()
		legendCar.text = "won with %s" % driver.info.charName
	var title := "%d  %s" % [selected % Territories.STOPS + 1, levelName(selected).to_upper()]
	var def := levelDef(selected)
	levelLock.text = "" if open else ("Not in the demo." if isDemoLockedLevel(selected) else Root.openRuleText(levels[selected - 1] if selected > 0 else {}) + ".")
	selectButton.disabled = not open
	selectButton.text = "SELECT" if open else "LOCKED"
	selectButton.add_theme_font_size_override("font_size", 22 if open else 17)
	for stop in stopButtons.size(): #the region's stops under the title: the current one lit, a locked one dim
		var at: int = first + stop
		var here: bool = at == selected
		var stopOpen: bool = at < levels.size() && isLevelSelectable(at)
		var b := stopButtons[stop]
		b.disabled = not stopOpen
		b.tooltip_text = levelName(at) if at < levels.size() else ""
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, MenuTheme.box(HudTheme.PANEL.lerp(HudTheme.RIM, 0.2) if here else Color(HudTheme.PANEL, 0.8), HudTheme.RIM if here || state == "hover" else Color(1, 1, 1, 0.2 if stopOpen else 0.08), 7, 2, Vector4(4, 0, 4, 0)))
		for state in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(state, HudTheme.GOLD if here else HudTheme.TEXT)
	#Level Options
	optionsTitle.text = title
	optionsRegion.text = str(territory.get("name", "")).to_upper()
	optionsRegion.add_theme_color_override("font_color", territory.get("color", HudTheme.RIM))
	optionsArt.texture = posters[selected].get_node("art").texture
	backButton.tooltip_text = "Back to the road map" if optionsOpen else "Back to the garage"
	driverChip.visible = not optionsOpen #Level Options has the driver in its launch cluster
	if driver.info:
		driverSide.texture = driver.info.sidePic
		driverLabel.text = driver.info.charName.to_upper()
	if optionsOpen:
		fillFacts(selected)
		restoreFact()
	var order := modeOrder(selected)
	for i in modeRows.size():
		modeRows[i].visible = i < order.size()
		if i < order.size(): refreshModeRow(modeRows[i], order[i], order[i] == mode, forModes, SaveManager.carClearTier(selected, order[i], driverCar))
	refreshFreeRow(forModes, mode)
	var tier := SaveManager.getGameTier()
	refreshCarStrip(selected, mode, tier)
	modeTitle.text = Root.gameModeDescription[mode].name
	#the pane's edge is the mode's category color
	optionsPane.add_theme_stylebox_override("panel", MenuTheme.box(Color(HudTheme.PANEL, 0.94), Color(Modes.categoryColor(mode), 0.75), 16, 2, Vector4(26, 12, 26, 12)))
	modeText.text = Modes.short(mode)
	modeTitle.tooltip_text = "%s %s" % [Root.gameModeDescription[mode].description, Root.MODE_RULES.get(mode, "")]
	var reason = "" if open else ("Not in the demo" if isDemoLockedLevel(selected) else Root.openRuleText(SaveManager.playerData.levels[selected - 1] if selected > 0 else {}))
	if reason == "": reason = Root.modeLockReason(forModes, mode)
	if reason == "": reason = ModeTiers.lockReason(forModes, mode, tier)
	lockReason = reason
	refreshTiers(forModes, mode, selected, reason)
	refreshRecords(selected, mode)
	var pick := [selected, mode, tier]
	if optionsOpen && animate && not shownPick.is_empty() && pick != shownPick && not Transition.instant() && not Settings.reduce_motion():
		if pick[1] != shownPick[1] || pick[0] != shownPick[0]: slidePane()
		else: Juice.pop(tierButtons[maxi(ModeTiers.TIERS.find(tier), 0)], 1.04, 0.2)
	shownPick = pick
	var playable = isLevelSelectable(selected) && Root.isModePlayable(forModes, mode) && ModeTiers.isOpen(forModes, mode, tier)
	startButton.disabled = not playable
	startButton.text = "START" if playable else ("COMING\nSOON" if reason == "Coming Soon" else "LOCKED")
	startButton.add_theme_font_size_override("font_size", 22 if playable else 16)
	updateHints()

func refreshPoster(index: int, isFocused: bool) -> void:
	var poster = posters[index]
	var level = SaveManager.playerData.levels[index]
	var open = isLevelSelectable(index)
	poster.get_node("lock").visible = not open
	poster.get_node("lock/text").text = "NOT IN DEMO" if isDemoLockedLevel(index) else "LOCKED"
	poster.get_node("art").modulate = Color.WHITE if open else Color(0.35, 0.35, 0.35)
	var car := str(SaveManager.playerData.cars[SaveManager.playerData.selectedCar].name)
	var glyphs = poster.get_node("glyphs")
	var order := modeOrder(index)
	for i in order.size(): #a glyph per mode in the color of the best medal won with it here; the bar is this driver's own
		var mode: int = order[i]
		var cell = glyphs.get_child(i)
		var playable: bool = open && Root.isModePlayable(level, mode)
		cell.get_node("glyph").material = glyphMaterials[ModeTiers.best(level, mode) if playable else GLYPH_LOCKED_INDEX]
		var mine := SaveManager.carClearTier(index, mode, car) if playable else ModeTiers.NONE
		cell.get_node("bar").color = ModeTiers.MEDAL_COLORS[mine] if mine > ModeTiers.NONE else Color(0, 0, 0, 0)
	var style = MenuTheme.box(Color(0, 0, 0, 0), HudTheme.RIM if isFocused else Color(1, 1, 1, 0.22), 18, 5 if isFocused else 3)
	style.draw_center = false
	poster.get_node("frame").add_theme_stylebox_override("panel", style)

func finishPosterLoad(index: int, wait: bool) -> void:
	if not pendingPosters.has(index): return
	var path = pendingPosters[index]
	if not wait && ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED: return
	pendingPosters.erase(index)
	posters[index].get_node("art").texture = ResourceLoader.load_threaded_get(path)

#a mode's row: lit while selected, dim under a lock while it can't be started (with the reason under its
#name); its three medals up to the best tier beaten, over the driver's own bar. A mode that isn't built yet
#(Root.MODE_AVAILABLE) is a slim row.
func refreshModeRow(b: Button, mode: int, selected: bool, level: Dictionary, mine: int) -> void:
	var playable = Root.isModePlayable(level, mode)
	var built := Root.isModeAvailable(mode)
	b.custom_minimum_size.y = MODE_ROW.y if built else 38.0
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL if built else Control.SIZE_FILL #the built rows fill the pane's height
	var style = MenuTheme.box(HudTheme.PANEL.lerp(HudTheme.RIM, 0.16) if selected else Color(HudTheme.PANEL, 0.9), HudTheme.RIM if selected else Color(1, 1, 1, 0.22), 14, 4 if selected else 2)
	if selected:
		style.shadow_color = Color(HudTheme.GOLD, 0.4)
		style.shadow_size = 10
	for state in ["normal", "pressed"]: b.add_theme_stylebox_override(state, style)
	var hover = style.duplicate()
	hover.border_color = HudTheme.GOLD if selected else Color(HudTheme.RIM, 0.8)
	b.add_theme_stylebox_override("hover", hover)
	#a mode's ring is its category's color: Crusher, Trial or Goon Cup (Modes.CATEGORY_COLORS)
	var ring := Color(Modes.categoryColor(mode), 0.75)
	b.get_node("row/disc").visible = built
	b.get_node("row/soon").visible = not built
	b.get_node("row/disc").add_theme_stylebox_override("panel", MenuTheme.box(HudTheme.PANEL, HudTheme.RIM if selected else ring, 30, 3, Vector4.ZERO))
	b.get_node("row/disc/icon").texture = HudTheme.MODE_ICONS[mode] if playable else HudTheme.LOCK_ICON
	var label: Label = b.get_node("row/words/name")
	label.text = Root.gameModeDescription[mode].name
	label.add_theme_font_size_override("font_size", 21 if built else 17)
	label.add_theme_color_override("font_color", HudTheme.GOLD if selected else HudTheme.TEXT)
	b.tooltip_text = Root.modeLockReason(level, mode) if not playable else Modes.short(mode) #a locked row's reason is also under the switch once it is picked
	var best := ModeTiers.best(level, mode) if playable else ModeTiers.NONE
	var medals = b.get_node("row/marks/medals")
	for i in medals.get_child_count(): setMedal(medals.get_child(i), ModeTiers.TIERS[i] if best >= ModeTiers.TIERS[i] else ModeTiers.NONE)
	b.get_node("row/marks").visible = playable
	b.get_node("row/marks/mine").color = ModeTiers.MEDAL_COLORS[mine] if playable && mine > ModeTiers.NONE else Color(0, 0, 0, 0)
	b.modulate = Color.WHITE if playable || selected else Color(1, 1, 1, 0.6)

## The slim Free Play row: locked until all five modes are won here, then it names the mode picked (a press
## picks the next one). Free Play pays coins only, so it shows no medals.
func refreshFreeRow(level: Dictionary, mode: int) -> void:
	var free := Root.freePlayModes(level)
	freeRow.visible = not free.is_empty()
	if free.is_empty(): return
	var open := Root.freePlayOpen(level)
	var picked: bool = open && mode in free
	var style = MenuTheme.box(HudTheme.PANEL.lerp(HudTheme.RIM, 0.16) if picked else Color(HudTheme.PANEL, 0.9), HudTheme.RIM if picked else Color(1, 1, 1, 0.22), 14, 4 if picked else 2)
	for state in ["normal", "pressed"]: freeRow.add_theme_stylebox_override(state, style)
	var hover = style.duplicate()
	hover.border_color = HudTheme.GOLD if picked else Color(HudTheme.RIM, 0.8)
	freeRow.add_theme_stylebox_override("hover", hover)
	freeRow.get_node("row/disc").visible = false
	freeRow.get_node("row/marks").visible = false
	var label: Label = freeRow.get_node("row/words/name")
	label.text = "FREE PLAY:  %s" % Root.gameModeDescription[mode].name if picked else "FREE PLAY"
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", HudTheme.GOLD if picked else HudTheme.TEXT)
	var note: Label = freeRow.get_node("row/soon")
	note.visible = true
	note.text = ("Next mode" if picked else "Any mode, coins only") if open else "Win all five modes here"
	freeRow.tooltip_text = "Play any other mode on this level. Free Play pays coins and nothing else: no medals, records or unlocks." if open else Root.modeLockReason(level, free[0])
	freeRow.modulate = Color.WHITE if open else Color(1, 1, 1, 0.6)

func onStartPressed() -> void:
	var index = SaveManager.playerData.selectedLevel
	if screen == Screen.SETUP && optionsOpen && isLevelSelectable(index) && Root.isModePlayable(selectedLevelForModes(), SaveManager.getGameMode()) && ModeTiers.isOpen(selectedLevelForModes(), SaveManager.getGameMode(), SaveManager.getGameTier()):
		var gadget := slotPurchase("loadout")
		var boost := slotPurchase("boostLoadout") #worked out before either is paid for
		if gadget != "":
			SaveManager.playerData.gem -= Pickups.LOADOUT[gadget]
			Pickups.loadout = gadget #the car takes both in _ready
		if boost != "":
			SaveManager.playerData.gem -= Pickups.BOOST_LOADOUT[boost]
			Pickups.boostLoadout = boost
		startLevel(levelScene(index))

#the mode shown when run setup opens: the saved one if it can be started here, else the level's first
func defaultGameMode() -> int:
	var mode = SaveManager.getGameMode()
	return mode if Root.isModePlayable(selectedLevelForModes(), mode) else Root.firstMode(SaveManager.playerData.selectedLevel)

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
			elif not optionsOpen: stepLevelTo(SaveManager.playerData.selectedLevel + step)
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if screen == Screen.GARAGE:
		#on a bench row E (or A) buys it and Accept drives; E is also the next-driver key, so Buy is read first
		var onRow := focusOpen && bench.rowFocused()
		if onRow && event.is_action_pressed("ui_buy"): bench.buyUpgrade(bench.lastStat)
		elif onRow && event.is_action_pressed("ui_accept"): cards[SaveManager.playerData.selectedCar].onMainPressed()
		elif event.is_action_pressed("ui_tab_prev") || event.is_action_pressed("ui_left"): selectCar(SaveManager.playerData.selectedCar - 1)
		elif event.is_action_pressed("ui_tab_next") || event.is_action_pressed("ui_right"): selectCar(SaveManager.playerData.selectedCar + 1)
		elif event.is_action_pressed("ui_upgrade"): toggleFocus()
		elif focusOpen && (event.is_action_pressed("ui_cancel") || event.is_action_pressed("ui_menu")): setFocusOpen(false)
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_pickups"): openPickups()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: cards[SaveManager.playerData.selectedCar].onMainPressed()
		else: handled = false
	else:
		#Back before Settings: Esc is both ui_cancel and ui_menu, and here it goes back (Settings has the gear
		#button, and Start on a pad)
		if event.is_action_pressed("ui_cancel"): onBackPressed()
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_pickups"): openPickups()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif optionsOpen:
			if event.is_action_pressed("ui_up"): stepMode(-1)
			elif event.is_action_pressed("ui_down"): stepMode(1)
			elif event.is_action_pressed("ui_left"): stepTier(-1)
			elif event.is_action_pressed("ui_right"): stepTier(1)
			elif event.is_action_pressed("ui_region_prev") && triggerEdge(event, "ui_region_prev"): stepFact(-1, Input.is_key_pressed(KEY_SHIFT))
			elif event.is_action_pressed("ui_region_next") && triggerEdge(event, "ui_region_next"): stepFact(1, Input.is_key_pressed(KEY_SHIFT))
			elif InputGlyphs.digit(event) > 0 && InputGlyphs.digit(event) <= Territories.STOPS: optionsStop(InputGlyphs.digit(event) - 1) #the stop's number
			elif event.is_action_pressed("ui_tab_prev"): stepDriver(-1)
			elif event.is_action_pressed("ui_tab_next"): stepDriver(1)
			elif event.is_action_pressed("ui_upgrade"): cycleLoadout()
			elif event.is_action_pressed("ui_boost"): cycleBoost()
			elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: onStartPressed()
			else: handled = false
		elif event.is_action_pressed("ui_tab_prev") || event.is_action_pressed("ui_left"): stepLevelTo(SaveManager.playerData.selectedLevel - 1)
		elif event.is_action_pressed("ui_tab_next") || event.is_action_pressed("ui_right"): stepLevelTo(SaveManager.playerData.selectedLevel + 1)
		elif event.is_action_pressed("ui_region_prev") && triggerEdge(event, "ui_region_prev"): stepRegion(-1)
		elif event.is_action_pressed("ui_region_next") && triggerEdge(event, "ui_region_next"): stepRegion(1)
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: openOptions()
		elif InputGlyphs.digit(event) > 0 && InputGlyphs.digit(event) <= Territories.STOPS: stepLevelTo(selectedRegion() * Territories.STOPS + InputGlyphs.digit(event) - 1) #the stop's number
		else: handled = false
	if handled: get_viewport().set_input_as_handled()

#a clicked stop, a number key, Q/E or the mouse wheel: select that level (Q/E past a region's ends move
#into the next region when it is open; the road wraps)
func stepLevelTo(index: int) -> void:
	index = wrapi(index, 0, SaveManager.playerData.levels.size())
	var region := index / Territories.STOPS
	if region != selectedRegion() && not isRegionOpen(region): return
	if index != SaveManager.playerData.selectedLevel:
		SaveManager.playerData.selectedLevel = index
		SaveManager.save_character_data()
	refreshSetup()

#LT/RT are axes, sending events while held: only the press that first crosses the deadzone counts
func triggerEdge(event: InputEvent, action: String) -> bool:
	return not event is InputEventJoypadMotion || Input.is_action_just_pressed(action)

#Up / Down: the mode rows, top to bottom (they wrap), then Free Play's modes once it is open
func stepMode(direction: int) -> void:
	var order := modeOrder()
	if Root.freePlayOpen(selectedLevelForModes()): order = order + Root.freePlayModes(selectedLevelForModes())
	var at = maxi(order.find(SaveManager.getGameMode()), 0)
	SaveManager.setGameMode(order[wrapi(at + direction, 0, order.size())])
	refreshSetup()

#Left is the easier tier, Right the harder (the switch reads Easy, Medium, Hard)
func stepTier(direction: int) -> void:
	selectTier(ModeTiers.clampTier(SaveManager.getGameTier() + direction))

func selectTier(tier: int) -> void:
	if tier == SaveManager.getGameTier(): return
	SaveManager.setGameTier(tier)
	refreshSetup(false)

#Q/E in Level Options: the next car owned drives, so its wins here can be compared without the garage
func stepDriver(direction: int) -> void:
	var count: int = SaveManager.playerData.cars.size()
	var at: int = SaveManager.playerData.selectedCar
	for i in count - 1:
		at = wrapi(at + direction, 0, count)
		if isCarOwned(at):
			onCarCellPressed(at)
			return

#run setup's Back: Level Options to the road map, the road map to the garage
func onBackPressed() -> void:
	if optionsOpen: closeOptions()
	else: goToGarage()

func overlayOpen() -> bool:
	return get_tree().get_nodes_in_group("menuOverlay").size() > 0

func updateHints() -> void:
	for child in hintBar.get_children():
		hintBar.remove_child(child)
		child.queue_free()
	var hints: Array
	if screen == Screen.SETUP:
		if optionsOpen: hints = [[["ui_up", "ui_down"], "Mode"], [["ui_left", "ui_right"], "Tier"], [["ui_region_prev", "ui_region_next"], "Level Info"], [["ui_records"], "Records"], [["ui_pickups"], "Pickups"]] #Start, Driver, Gadget, Boost and Back show their keys themselves
		else: hints = [[["ui_region_prev", "ui_region_next"], "Region"], [["ui_tab_prev", "ui_tab_next"], "Stop"], [["ui_accept"], "Select"], [["ui_records"], "Records"], [["ui_pickups"], "Pickups"], [["ui_codex"], "Goonopedia"]]
	else:
		var locked = cards[SaveManager.playerData.selectedCar].isLocked()
		hints = [[["ui_left", "ui_right"] if focusOpen else ["ui_tab_prev", "ui_tab_next"], "Driver"]]
		if focusOpen:
			if locked: hints.push_back([["ui_accept"], "Unlock"])
			else: hints.append_array([[["ui_up", "ui_down"], "Stat"], [["ui_buy"], "Buy"], [["ui_accept"], "Drive"]])
			hints.append_array([[["ui_upgrade"], "Drivers"], [["ui_pickups"], "Pickups"], [["ui_records"], "Records"], [["ui_cancel"], "Back"]])
		else:
			hints.append_array([[["ui_accept"], "Unlock" if locked else "Drive"], [["ui_upgrade"], "Details" if locked else "Upgrades"],
				[["ui_pickups"], "Pickups"], [["ui_records"], "Records"], [["ui_codex"], "Goonopedia"], [["ui_menu"], "Settings"]])
	for hint in hints: hintBar.add_child(KeyHint.make(PackedStringArray(hint[0]), hint[1], 16, true))

#---------- overlays and runs ----------

func openSettings() -> void:
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())

func openGoonopedia() -> void:
	if overlayOpen(): return
	Goonopedia.open(self).closed.connect(onOverlayClosed)

func openPickups() -> void:
	if overlayOpen(): return
	PickupShop.open(self).closed.connect(onOverlayClosed)

#focus back to the screen under an overlay
func onOverlayClosed() -> void:
	if not is_inside_tree(): return
	statUpdatesUiUpdate() #the Pickups screen may have spent coins and gems on unlocks
	if screen == Screen.SETUP: refreshSetup(false)
	if screen == Screen.SETUP: focusSetup()
	else: focusGarage()

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
	if focusOpen: bench.refresh()
	updateHints()

#run payout: the coins are already credited and saved; this only counts the display up
func animateCoins(from: int, to: int) -> void:
	statUpdatesUiUpdate()
	if coinTween: coinTween.kill()
	coinTween = create_tween()
	coinTween.tween_method(func(v): coinsLabel.text = DriverCard.formatCoins(int(v)), float(from), float(to), clampf(absf(to - from) / 300.0, 0.3, 1.5))
	Juice.pop(coinsLabel, 1.2 if to > from else 1.12)

var coinTween: Tween
