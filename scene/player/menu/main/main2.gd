extends CanvasLayer

#The main menu, as cards (docs/UI.md).
#  GARAGE     a carousel of driver cards (DriverCard). LB/RB or Left/Right picks a driver, Accept
#             drives or unlocks, Records shows the driver's bests. Upgrades opens the driver focus: the
#             other drivers leave, the card moves to the left and its bench (DriverBench) opens beside it,
#             where upgrades are bought (Up/Down, then E / A; Accept still drives); Upgrades or Back returns to the drivers. The
#             dock under the card holds Upgrades, Drive and Pickups.
#  RUN SETUP  two steps. The road map picks the level: one region (Territories) at a time, its five stops
#             on a winding road (Q/E, LB/RB, Left/Right or 1-5), each with a glyph per mode in the colour
#             of the best medal won there and a bar under it for the current driver's own. A button at each
#             end of the road leads to the region before and after (Z/C or LT/RT; locked until that region
#             is open). SELECT, Accept or a click on the selected stop opens LEVEL OPTIONS
#             (optionsOpen): the five mode medallions (Left/Right), a card per tier (Up/Down; ModeTiers:
#             Easy, Medium, Hard) with its goal and pay, the car strip (which cars have won this mode,
#             level and tier; a click on an owned car drives it) and START. Back returns to the road map,
#             then to the garage. Medals (bronze, silver, gold) show the best tier beaten.
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
const STOP_SPOTS := [Vector2(230, 470), Vector2(515, 258), Vector2(800, 484), Vector2(1085, 270), Vector2(1370, 470)] #stop centres, 1st to 5th
const REGION_BUTTON := Vector2(124, 124) #the buttons at the road's ends: the region before and the one after
const REGION_SPOTS := [Vector2(78, 296), Vector2(1522, 296)] #their centres; the road runs from one to the other
const ROAD_BEND := 150.0 #the road's handles at each stop, flat, so it swings between them
const STOP_FOCUS_SCALE := 1.14
const TIER_CARD := Vector2(340, 228)
#a mode icon in one colour (a medal's): its light and dark kept as shades of the tint
const GLYPH_SHADER := "shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb * mix(0.4, 1.0, dot(t.rgb, vec3(0.299, 0.587, 0.114))), t.a * tint.a);
}"
const GLYPH_OPEN := Color(1, 1, 1, 0.36)   #a mode not won yet
const GLYPH_LOCKED := Color(1, 1, 1, 0.13)
const GLYPH_LOCKED_INDEX := 4              #glyphMaterials: a medal's index (ModeTiers.NONE to HARD), then locked
const CAR_CELL := Vector2(92, 36) #a side view in the car strip; the current driver's is CAR_CELL_BIG
const CAR_CELL_BIG := Vector2(124, 48)
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
const MODE_SLOTS := 5 #the medallions, left to right: Sprint, Countdown and the level's three featured modes (Root.modePath)
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
var actionDock := Panel.new() #the focused card's Upgrades, Drive and Pickups, in a tray at the bottom centre
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
var options := Control.new() #Level Options: the level, the medallions, the tier cards, the car strip, START
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
var optionsFacts := VBoxContainer.new()
var posters: Array[Control] = [] #one stop per level; only the selected region's five show
var pendingPosters := {}     #poster index -> level image path still loading
var regionBlurb := Label.new()
var road := Control.new()    #draws the road through the region's stops
var carStrip := HBoxContainer.new()
var carStripLabel := Label.new()
var carCells: Array[Button] = []
var outlineMaterial: ShaderMaterial
var medallions: Array[Control] = []
var modeTitle := Label.new()
var tierRow := HBoxContainer.new() #Easy, Medium, Hard (ModeTiers): a card each
var tierButtons: Array[Button] = []
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
	#the radio, under the icons: shows the song, a click changes station (docs/RADIO.md)
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
		card.upgradesRequested.connect(toggleFocus)
		card.pickupsRequested.connect(openPickups)
		card.selectRequested.connect(selectCar.bind(i))
		cards.push_back(card)
		card.car = cars[i]
		card.refresh()
	bench.position = BENCH_POS
	bench.visible = false
	garage.add_child(bench)
	#every card's Upgrades, Drive and Pickups sit in one tray at the bottom centre; only the focused card's show
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
	nextUnlock.position = Vector2(300, 818)
	nextUnlock.size = Vector2(1000, 28)
	nextUnlock.alignment = BoxContainer.ALIGNMENT_CENTER
	nextUnlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup.add_child(nextUnlock)
	refreshLoadout()

#run setup's first step: the region tabs, the road and its stops, and the highlighted level's panel
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
	selectButton = MenuTheme.button("SELECT", PackedStringArray(["ui_accept"]), true)
	selectButton.position = Vector2(660, 622)
	selectButton.size = Vector2(280, 68)
	selectButton.add_theme_font_size_override("font_size", 28)
	selectButton.pressed.connect(openOptions)
	map.add_child(selectButton)
	levelLock.theme_type_variation = "BodyLabel"
	levelLock.add_theme_font_size_override("font_size", 17)
	levelLock.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	levelLock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levelLock.position = Vector2(300, 696)
	levelLock.size = Vector2(1000, 26)
	levelLock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.add_child(levelLock)
	#what the glyphs on the stops say
	var legend = HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 8)
	legend.position = Vector2(0, 730)
	legend.size = Vector2(1600, 24)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sample = MenuTheme.iconRect(HudTheme.MODE_ICONS[Root.FIRST_MODE], 20)
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

#run setup's second step, for the level picked on the road map
func buildOptions() -> void:
	options.visible = false
	optionsTitle.theme_type_variation = "TitleLabel"
	optionsTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	optionsTitle.position = Vector2(330, 18)
	optionsTitle.size = Vector2(940, 58)
	options.add_child(optionsTitle)
	optionsRegion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	optionsRegion.add_theme_font_size_override("font_size", 17)
	optionsRegion.position = Vector2(330, 80)
	optionsRegion.size = Vector2(940, 26)
	options.add_child(optionsRegion)
	#the level, down the left: what the Goonopedia's level page said
	var side = VBoxContainer.new()
	side.position = Vector2(60, 162)
	side.size = Vector2(370, 0)
	side.add_theme_constant_override("separation", 10)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = Panel.new()
	frame.custom_minimum_size = Vector2(370, 200)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.12, 0.1, 0.09), Color(0, 0, 0, 0), 16, 0))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	optionsArt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	optionsArt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	optionsArt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	optionsArt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(optionsArt)
	side.add_child(frame)
	optionsBlurb.theme_type_variation = "BodyLabel"
	optionsBlurb.add_theme_font_size_override("font_size", 16)
	optionsBlurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(optionsBlurb)
	optionsFacts.add_theme_constant_override("separation", 8)
	side.add_child(optionsFacts)
	options.add_child(side)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(470, 148)
	row.size = Vector2(1070, 150)
	for slot in MODE_SLOTS:
		var medallion = makeMedallion(slot)
		row.add_child(medallion)
		medallions.push_back(medallion)
	options.add_child(row)
	modeTitle.visible = false #the selected medallion names the mode
	options.add_child(modeTitle)
	for l in [modeText, modeLock]:
		l.theme_type_variation = "BodyLabel"
		l.add_theme_font_size_override("font_size", 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		options.add_child(l)
	modeText.position = Vector2(470, 302)
	modeText.size = Vector2(1070, 56)
	modeLock.position = Vector2(470, 664)
	modeLock.size = Vector2(1070, 56)
	modeLock.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	tierRow.alignment = BoxContainer.ALIGNMENT_CENTER
	tierRow.add_theme_constant_override("separation", 20)
	tierRow.position = Vector2(470, 364)
	tierRow.size = Vector2(1070, TIER_CARD.y)
	for tier in ModeTiers.TIERS: tierRow.add_child(makeTierButton(tier))
	options.add_child(tierRow)
	buildCarStrip()
	startButton = MenuTheme.button("START", PackedStringArray(["ui_accept"]), true)
	startButton.position = Vector2(620, 744)
	startButton.size = Vector2(360, 68)
	startButton.add_theme_font_size_override("font_size", 30)
	startButton.pressed.connect(onStartPressed)
	options.add_child(startButton)
	loadoutButton = loadoutSlotButton("ui_upgrade", Vector2(200, 744), cycleLoadout)
	boostButton = loadoutSlotButton("ui_boost", Vector2(1010, 744), cycleBoost)

#"DRIVER (side view) Name", top right under the bank, on both steps
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

#U / Y (B / RS for the boost) and clicks drive it; focus stays on START so Accept always starts
func loadoutSlotButton(action: String, at: Vector2, onPress: Callable) -> Button:
	var b := MenuTheme.button("", PackedStringArray([action]), false)
	b.position = at
	b.size = Vector2(390, 68)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(onPress)
	b.focus_mode = Control.FOCUS_NONE
	options.add_child(b)
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
		if Unlocks.canAfford(next.uid): parts.push_back("  in Pickups (%s)" % InputGlyphs.label("ui_pickups"))
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

## The modes of a level's medallions and poster glyphs, in order (Root.modePath)
func modeOrder(index := -1) -> Array:
	return Root.modePath(SaveManager.playerData.selectedLevel if index < 0 else index)

func onMedallionPressed(slot: int) -> void:
	var order := modeOrder()
	if slot >= order.size(): return
	SaveManager.setGameMode(order[slot])
	refreshSetup()

#one of run setup's five mode slots; refreshMedallion gives it the selected level's mode
func makeMedallion(slot: int) -> Control:
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 140)
	column.add_theme_constant_override("separation", 6)
	var disc = Button.new()
	disc.name = "disc"
	disc.custom_minimum_size = Vector2(96, 96)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.focus_mode = Control.FOCUS_NONE
	disc.expand_icon = true
	disc.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	disc.pressed.connect(onMedallionPressed.bind(slot))
	MenuTheme.addSounds(disc)
	column.add_child(disc)
	var label = Label.new()
	label.name = "name"
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
	var mine = ColorRect.new() #the current driver's own medal in this mode here
	mine.name = "mine"
	mine.custom_minimum_size = Vector2(56, 4)
	mine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(mine)
	return column

#a tier's card under the medallions, filled by refreshTiers; a click picks it (focus stays on START)
func makeTierButton(tier: int) -> Button:
	var b := Button.new()
	b.name = ModeTiers.NAMES[tier]
	b.custom_minimum_size = TIER_CARD
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): SaveManager.setGameTier(tier); refreshSetup(false))
	MenuTheme.addSounds(b)
	var body = VBoxContainer.new()
	body.name = "body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 18
	body.offset_right = -18
	body.offset_top = 12
	body.offset_bottom = -12
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(body)
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

#each end's button names the region it leads to, in that region's colour; no button past the first and
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
		for state in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(state, style)
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
	while at < length: #the centre line's dashes, laid along the curve
		road.draw_line(curve.sample_baked(at), curve.sample_baked(minf(at + 14.0, length)), Color(HudTheme.GOLD, 0.8), 3.0, true)
		at += 30.0

func buildCarStrip() -> void:
	outlineMaterial = ShaderMaterial.new()
	outlineMaterial.shader = Shader.new()
	outlineMaterial.shader.code = OUTLINE_SHADER
	carStrip.alignment = BoxContainer.ALIGNMENT_CENTER
	carStrip.add_theme_constant_override("separation", 6)
	carStrip.position = Vector2(470, 602)
	carStrip.size = Vector2(1070, CAR_CELL_BIG.y + 6)
	carStripLabel.add_theme_font_size_override("font_size", 15)
	carStripLabel.custom_minimum_size = Vector2(120, 0)
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
	options.add_child(carStrip)

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

#each card: lit while selected, dim while locked; its star in the medal colour once that tier is beaten,
#the tier's goal, what a win pays, the first-clear bonus still to earn, whether the current driver has won
#it and how many have
func refreshTiers(level: Dictionary, mode: int, index: int) -> void:
	var selected := SaveManager.getGameTier()
	var best := ModeTiers.best(level, mode)
	var def := levelDef(index)
	var data = SaveManager.playerData
	var card := cards[data.selectedCar]
	var mine := SaveManager.carClearTier(index, mode, str(data.cars[data.selectedCar].name))
	var driver: String = card.info.charName if card.info else str(data.cars[data.selectedCar].name)
	for i in tierButtons.size():
		var b := tierButtons[i]
		var tier: int = ModeTiers.TIERS[i]
		var on := tier == selected
		var open := ModeTiers.isOpen(level, mode, tier)
		var style = MenuTheme.box(Color(HudTheme.PANEL, 0.94), HudTheme.RIM if on else Color(1, 1, 1, 0.22), 16, 4 if on else 2)
		if on:
			style.shadow_color = Color(HudTheme.GOLD, 0.4)
			style.shadow_size = 10
		for state in ["normal", "pressed", "focus"]: b.add_theme_stylebox_override(state, style)
		var hover = style.duplicate()
		hover.border_color = HudTheme.GOLD if on else Color(HudTheme.RIM, 0.8)
		b.add_theme_stylebox_override("hover", hover)
		b.modulate = Color.WHITE if open || on else Color(1, 1, 1, 0.55)
		var body: VBoxContainer = b.get_node("body")
		for child in body.get_children():
			body.remove_child(child)
			child.queue_free()
		var head = HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var star = MenuTheme.iconRect(HudTheme.STAR_ICON if open else HudTheme.LOCK_ICON, 22)
		if open: star.modulate = ModeTiers.MEDAL_COLORS[tier] if best >= tier else GLYPH_OPEN
		head.add_child(star)
		var title = Label.new()
		title.text = ModeTiers.NAMES[tier].to_upper()
		title.add_theme_font_size_override("font_size", 19)
		title.add_theme_color_override("font_color", HudTheme.GOLD if on else HudTheme.TEXT)
		head.add_child(title)
		body.add_child(head)
		var goal = Label.new()
		goal.text = ModeTiers.goalText(mode, tier, def.seconds if def else 300.0)
		goal.add_theme_font_size_override("font_size", 20)
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.custom_minimum_size.y = 54 #two lines, so the cards' rows line up
		body.add_child(goal)
		var pay := [MenuTheme.symbolRow(["WIN  +", {"coin": ModeTiers.winBonus(mode, tier, index)}], 17, HudTheme.GOLD)]
		var first := ModeTiers.firstClear(best, tier, index)
		if first.coin > 0 || first.gem > 0: pay.push_back(MenuTheme.symbolRow(["FIRST CLEAR  +", first], 17, HudTheme.GOLD))
		for line in pay: line.alignment = BoxContainer.ALIGNMENT_BEGIN
		if pay.size() == 1: pay.push_back(cardLine("FIRST CLEAR  paid", HudTheme.MUTED))
		for line in pay: body.add_child(line)
		var rule = ColorRect.new()
		rule.color = Color(1, 1, 1, 0.14)
		rule.custom_minimum_size = Vector2(0, 2)
		body.add_child(rule)
		var won := mine >= tier
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if card.info:
			var pic = TextureRect.new()
			pic.texture = card.info.sidePic
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(58, 22)
			pic.modulate = Color.WHITE if won else Color(0.3, 0.3, 0.32)
			row.add_child(pic)
		row.add_child(cardLine(("Won with %s" if won else "Not won with %s yet") % driver, ModeTiers.MEDAL_COLORS[tier] if won else MenuTheme.BODY_TEXT))
		body.add_child(row)
		var full := SaveManager.isFullGarage(index, mode, tier)
		body.add_child(cardLine("FULL GARAGE" if full else "CARS  %d / %d" % [SaveManager.carsCleared(index, mode, tier), data.cars.size()], HudTheme.GOLD if full else HudTheme.MUTED))
		for child in body.get_children(): setMouseIgnore(child)

#a small line on a tier card
static func cardLine(text: String, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "BodyLabel"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

#children of a clickable card let the click through (docs/UI.md, "Mouse")
static func setMouseIgnore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): setMouseIgnore(child)

## A level's facts, as the Goonopedia's level page gave them: who lives there (class, line-up, an elite
## region's step) and, with `full`, its barrier and surfaces. `stacked` puts each tag over its text.
func fillFacts(into: VBoxContainer, index: int, full: bool, stacked: bool) -> void:
	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()
	var def := levelDef(index)
	if def == null: return
	var rows := Goonopedia.regionRows(def)
	var facts := [["WHO LIVES HERE", "%s: %s" % [rows[1][1], rows[2][1]]]]
	if rows.size() > 3: facts.push_back(["ELITE", rows[3][1]])
	if full: facts.append_array([["BARRIER", def.barrier], ["SURFACES", def.surfaces]])
	for fact in facts:
		if fact[1] == "": continue
		var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
		row.add_theme_constant_override("separation", 0 if stacked else 12)
		var tag = Label.new()
		tag.text = fact[0]
		tag.theme_type_variation = "MutedLabel"
		tag.add_theme_font_size_override("font_size", 13)
		if not stacked: tag.custom_minimum_size.x = 140
		row.add_child(tag)
		var text = Label.new()
		text.text = fact[1]
		text.theme_type_variation = "BodyLabel"
		text.add_theme_font_size_override("font_size", 15 if stacked else 16)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		into.add_child(row)

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
	if focusOpen: refreshBench()
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
	map.move_child(posters[selected], top) #the selected stop over its neighbours
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
	if mode not in modeOrder(selected): mode = Root.FIRST_MODE #the saved mode isn't one this level plays
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
	#Level Options
	optionsTitle.text = title
	optionsRegion.text = str(territory.get("name", "")).to_upper()
	optionsRegion.add_theme_color_override("font_color", territory.get("color", HudTheme.RIM))
	optionsArt.texture = posters[selected].get_node("art").texture
	optionsBlurb.text = def.blurb if def else ""
	optionsBlurb.visible = optionsBlurb.text != ""
	fillFacts(optionsFacts, selected, true, true)
	var order := modeOrder(selected)
	for i in medallions.size():
		medallions[i].visible = i < order.size()
		if i < order.size(): refreshMedallion(medallions[i], order[i], order[i] == mode, forModes, SaveManager.carClearTier(selected, order[i], driverCar))
	var tier := SaveManager.getGameTier()
	refreshTiers(forModes, mode, selected)
	refreshCarStrip(selected, mode, tier)
	modeTitle.text = Root.gameModeDescription[mode].name
	modeText.text = "%s%s %s" % ["" if mode in Root.STAPLE_MODES else Modes.categoryName(mode).to_upper() + ": ", Root.gameModeDescription[mode].description, Root.MODE_RULES.get(mode, "")]
	if mode == Root.gameModes.GOONPOCALYPSE:
		var best = SaveManager.bestGoonpocalypse(selected, SaveManager.playerData.cars[SaveManager.playerData.selectedCar].name)
		if best.time > 0: modeText.text += "\nBest here: %d:%02d, score %d" % [best.time / 60, best.time % 60, best.score]
	var reason = "" if open else ("Not in the demo" if isDemoLockedLevel(selected) else Root.openRuleText(SaveManager.playerData.levels[selected - 1] if selected > 0 else {}))
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
	var car := str(SaveManager.playerData.cars[SaveManager.playerData.selectedCar].name)
	var glyphs = poster.get_node("glyphs")
	var order := modeOrder(index)
	for i in order.size(): #a glyph per mode in the colour of the best medal won with it here; the bar is this driver's own
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

#gold star when beaten here, a dim star when it can be started, a lock when it can't
func refreshMedallion(column: Control, mode: int, selected: bool, level: Dictionary, mine: int) -> void:
	var disc: Button = column.get_node("disc")
	var playable = Root.isModePlayable(level, mode)
	var beaten = playable && level.gamemodeBeat.get(mode, false)
	disc.icon = HudTheme.MODE_ICONS[mode] if playable else HudTheme.LOCK_ICON
	disc.modulate = Color.WHITE if beaten || not playable else Color(0.85, 0.85, 0.85)
	#a featured mode's ring is its category's colour: Crusher, Trial or Goon Cup (Modes.CATEGORY_COLORS)
	var ring := Color(1, 1, 1, 0.25) if mode in Root.STAPLE_MODES else Color(Modes.categoryColor(mode), 0.75)
	var style = MenuTheme.box(HudTheme.PANEL, HudTheme.RIM if selected else ring, 48, 4 if selected else 2, Vector4(16, 16, 16, 16))
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
	column.get_node("mine").color = ModeTiers.MEDAL_COLORS[mine] if playable && mine > ModeTiers.NONE else Color(0, 0, 0, 0)
	var label: Label = column.get_node("name")
	label.text = Root.gameModeDescription[mode].name
	label.theme_type_variation = "GoldLabel" if selected else ""
	label.add_theme_font_size_override("font_size", 19 if selected else 16)
	column.modulate = Color.WHITE if playable || selected else Color(1, 1, 1, 0.55)

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

#the mode shown when run setup opens: the saved one if it can be started here, else Countdown
func defaultGameMode() -> int:
	var mode = SaveManager.getGameMode()
	return mode if Root.isModePlayable(selectedLevelForModes(), mode) else Root.FIRST_MODE

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
		if event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_pickups"): openPickups()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif optionsOpen:
			if event.is_action_pressed("ui_cancel"): closeOptions()
			elif event.is_action_pressed("ui_left"): stepMode(-1)
			elif event.is_action_pressed("ui_right"): stepMode(1)
			elif event.is_action_pressed("ui_up"): stepTier(-1)
			elif event.is_action_pressed("ui_down"): stepTier(1)
			elif event.is_action_pressed("ui_upgrade"): cycleLoadout()
			elif event.is_action_pressed("ui_boost"): cycleBoost()
			elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: onStartPressed()
			else: handled = false
		elif event.is_action_pressed("ui_cancel"): goToGarage()
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

func stepMode(direction: int) -> void:
	var order := modeOrder()
	var at = maxi(order.find(SaveManager.getGameMode()), 0)
	SaveManager.setGameMode(order[wrapi(at + direction, 0, order.size())])
	refreshSetup()

#Up is the easier tier, Down the harder (the cards read Easy, Medium, Hard left to right)
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
		if optionsOpen: hints = [[["ui_left", "ui_right"], "Mode"], [["ui_up", "ui_down"], "Tier"], [["ui_accept"], "Start"], [["ui_upgrade"], "Gadget"], [["ui_boost"], "Boost"], [["ui_records"], "Records"], [["ui_pickups"], "Pickups"], [["ui_cancel"], "Back"]]
		else: hints = [[["ui_region_prev", "ui_region_next"], "Region"], [["ui_tab_prev", "ui_tab_next"], "Stop"], [["ui_accept"], "Select"], [["ui_records"], "Records"], [["ui_pickups"], "Pickups"], [["ui_codex"], "Goonopedia"], [["ui_cancel"], "Back"]]
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
