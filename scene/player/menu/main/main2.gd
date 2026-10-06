extends CanvasLayer

#The main menu, as cards (docs/UI.md).
#  GARAGE     a carousel of driver cards (DriverCard). LB/RB or Left/Right picks a driver, Accept
#             drives or unlocks, Upgrade hands focus to the stat rows, Records shows the driver's bests.
#  RUN SETUP  level poster cards with the five mode medallions under them. LB/RB picks a level,
#             Left/Right a mode, Accept starts the run, Back returns to the garage.
#The save holds every selection; this only draws it. Built in code with MenuTheme.
#  G / View opens the Goonopedia (goonopedia.gd) over either screen.
#Other scripts call: startLevel(path), animateCoins(from, to), statUpdatesUiUpdate(), add_child(menu).

enum Screen { GARAGE, SETUP }

#carousel slots by offset from the selected card: position and scale of a 380 x 640 card
const CARD_SLOTS := {
	0: [Vector2(610, 138), 1.0],
	-1: [Vector2(333, 246), 0.7], 1: [Vector2(1001, 246), 0.7],
	-2: [Vector2(92, 290), 0.58], 2: [Vector2(1288, 290), 0.58],
}
const POSTER_SIZE := Vector2(640, 340)
const POSTER_SLOTS := {0: [Vector2(480, 112), 1.0], -1: [Vector2(110, 196), 0.5], 1: [Vector2(1170, 196), 0.5]}
const SLIDE_SECONDS := 0.22
const MODE_ORDER := [Root.gameModes.GOONCRUSHER, Root.gameModes.SPRINT, Root.gameModes.MARATHON, Root.gameModes.DEFENSE, Root.gameModes.GOONPOCALYPSE]
const TEXT_SHADER := preload("res://shader/3dtext.gdshader")
const SETTINGS_ICON := preload("res://texture/icon/settings.svg")
const QUIT_ICON := preload("res://texture/icon/quit.svg")
const DISCORD_ICON := preload("res://texture/icon/discord.png")
const STEAM_ICON := preload("res://texture/icon/steam.png")
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")

var screen := Screen.GARAGE
var upgrading := false
var loadingLevel := false
var ui := Control.new()
var backgrounds: Array[TextureRect] = []
var frontBackground := 0
var garage := Control.new()
var setup := Control.new()
var logo := Label.new()
var cards: Array[DriverCard] = []
var pendingInfos := {}       #card index -> CarInfo path still loading on a worker thread
var coinsLabel := Label.new()
var gemsLabel := Label.new()
var shownCoins := 0
var hintBar := HBoxContainer.new()
var posters: Array[Control] = []
var pendingPosters := {}     #poster index -> level image path still loading
var medallions: Array[Control] = []
var modeTitle := Label.new()
var modeText := Label.new()
var modeLock := Label.new()
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
	if Root.isRunActive:
		Root.isRunActive = false
		#gameSummary already credited and saved the payout; the menu only counts the display up
		var coin = SaveManager.playerData.coin
		if Root.earnedCoins > 0: animateCoins(coin - Root.earnedCoins, coin)
		Root.earnedCoins = 0
		Root.earnedGems = 0
	await get_tree().process_frame
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
		card.upgradePressed.connect(onUpgradePressed)
		card.selectRequested.connect(selectCar.bind(i))
		cards.push_back(card)
		card.car = cars[i]
		card.refresh()

func buildSetup() -> void:
	setup.visible = false
	var title = Label.new()
	title.text = "CHOOSE YOUR RUN"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 36
	setup.add_child(title)
	var levels = SaveManager.playerData.levels
	for i in levels.size():
		var poster = makePoster(i)
		setup.add_child(poster)
		posters.push_back(poster)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 486)
	row.size = Vector2(1600, 150)
	for mode in MODE_ORDER:
		var medallion = makeMedallion(mode)
		row.add_child(medallion)
		medallions.push_back(medallion)
	setup.add_child(row)
	var info = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.position = Vector2(300, 640)
	info.size = Vector2(1000, 90)
	info.add_theme_constant_override("separation", 4)
	for l in [modeTitle, modeText, modeLock]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)
	modeTitle.theme_type_variation = "GoldLabel"
	modeText.theme_type_variation = "BodyLabel"
	modeLock.theme_type_variation = "BodyLabel"
	modeLock.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	setup.add_child(info)
	startButton = MenuTheme.button("START", PackedStringArray(["ui_accept"]), true)
	startButton.position = Vector2(620, 744)
	startButton.size = Vector2(360, 68)
	startButton.add_theme_font_size_override("font_size", 30)
	startButton.pressed.connect(onStartPressed)
	setup.add_child(startButton)
	loadoutButton = MenuTheme.button("", PackedStringArray(["ui_upgrade"]), false)
	loadoutButton.position = Vector2(200, 744)
	loadoutButton.size = Vector2(390, 68)
	loadoutButton.pressed.connect(cycleLoadout)
	setup.add_child(loadoutButton)
	refreshLoadout()

#---------- the gadget loadout ----------
#Banked gems buy one gadget to start a run with (Pickups.LOADOUT). The choice is kept in
#meta.records.loadout; the gems are spent when the run starts.
var loadoutButton: Button

func loadoutChoice() -> String:
	var id: String = SaveManager.playerData.meta.get("records", {}).get("loadout", "")
	return id if Pickups.LOADOUT.has(id) else ""

func cycleLoadout() -> void:
	var options := [""] + Pickups.LOADOUT.keys()
	var at := options.find(loadoutChoice())
	for i in options.size():
		at = wrapi(at + 1, 0, options.size())
		if options[at] == "" || SaveManager.playerData.gem >= Pickups.LOADOUT[options[at]]: break
	SaveManager.playerData.meta.records["loadout"] = options[at]
	SaveManager.save_character_data()
	refreshLoadout()

func refreshLoadout() -> void:
	if not is_instance_valid(loadoutButton): return
	var id := loadoutChoice()
	if id != "" && SaveManager.playerData.gem < Pickups.LOADOUT[id]: id = ""
	loadoutButton.text = "GADGET:  NONE" if id == "" else "%s  -  %d GEM%s" % [Pickups.displayName(id).to_upper(), Pickups.LOADOUT[id], "" if Pickups.LOADOUT[id] == 1 else "S"]
	loadoutButton.icon = Pickups.texture(id) if id != "" else null
	loadoutButton.add_theme_constant_override("icon_max_width", 34)

#a level as a poster: its art, "1  EASY" with a star per mode beaten, and a lock when locked
func makePoster(index: int) -> Control:
	var level = SaveManager.playerData.levels[index]
	var poster = Panel.new()
	poster.size = POSTER_SIZE
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
	if ResourceLoader.has_cached(level.image) || index == SaveManager.playerData.selectedLevel: art.texture = load(level.image)
	else:
		ResourceLoader.load_threaded_request(level.image)
		pendingPosters[index] = level.image
	var band = PanelContainer.new()
	band.name = "band"
	band.theme_type_variation = "BandPanel"
	band.position = Vector2(0, POSTER_SIZE.y - 64)
	band.size = Vector2(POSTER_SIZE.x, 64)
	var bandRow = HBoxContainer.new()
	bandRow.name = "row"
	bandRow.alignment = BoxContainer.ALIGNMENT_CENTER
	bandRow.add_theme_constant_override("separation", 14)
	var label = Label.new()
	label.name = "name"
	label.theme_type_variation = "DarkLabel"
	label.text = "%d   %s" % [index + 1, level.name.to_upper()]
	bandRow.add_child(label)
	var stars = HBoxContainer.new()
	stars.name = "stars"
	stars.add_theme_constant_override("separation", 3)
	bandRow.add_child(stars)
	band.add_child(bandRow)
	poster.add_child(band)
	var lock = VBoxContainer.new()
	lock.name = "lock"
	lock.alignment = BoxContainer.ALIGNMENT_CENTER
	lock.size = Vector2(POSTER_SIZE.x, POSTER_SIZE.y - 64)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lockIcon = MenuTheme.iconRect(HudTheme.LOCK_ICON, 72)
	lockIcon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.add_child(lockIcon)
	var lockText = Label.new()
	lockText.name = "text"
	lockText.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lockText.add_theme_font_size_override("font_size", 30)
	lock.add_child(lockText)
	poster.add_child(lock)
	var frame = Panel.new()
	frame.name = "frame"
	frame.size = POSTER_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.add_child(frame)
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
	disc.icon = HudTheme.STAR_ICON
	disc.expand_icon = true
	disc.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.pressed.connect(func(): SaveManager.setGameMode(mode); refreshSetup())
	MenuTheme.addSounds(disc)
	column.add_child(disc)
	var label = Label.new()
	label.name = "name"
	label.text = Root.gameModeDescription[mode].name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	column.add_child(label)
	return column

#---------- garage ----------

func selectCar(index: int, animate := true) -> void:
	var cars = SaveManager.playerData.cars
	index = wrapi(index, 0, cars.size())
	if index != SaveManager.playerData.selectedCar:
		SaveManager.playerData.selectedCar = index
		SaveManager.save_character_data()
	setUpgrading(false)
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
		if card.focused != (offset == 0): card.setFocused(offset == 0)
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

func setUpgrading(on: bool) -> void:
	if on && (screen != Screen.GARAGE || cards[SaveManager.playerData.selectedCar].isLocked()): return
	upgrading = on
	cards[SaveManager.playerData.selectedCar].setUpgradeMode(on)
	updateHints()

#a stat row (or the Upgrade button, stat -1) was pressed on the focused card
func onUpgradePressed(stat: int) -> void:
	if stat < 0:
		setUpgrading(not upgrading)
		return
	if SaveManager.requestStatUpgrade(stat): buyPlayer.play() #requestStatUpgrade calls statUpdatesUiUpdate

func onUnlockPressed() -> void:
	if SaveManager.unlockCar():
		buyPlayer.play()
		statUpdatesUiUpdate()
		cards[SaveManager.playerData.selectedCar].mainButton.grab_focus()

#---------- run setup ----------

func goToSetup() -> void:
	if cards[SaveManager.playerData.selectedCar].isLocked(): return
	setUpgrading(false)
	screen = Screen.SETUP
	SaveManager.setGameMode(defaultGameMode())
	switchLayer(setup, garage)
	refreshSetup(false)
	startButton.grab_focus()

func goToGarage() -> void:
	screen = Screen.GARAGE
	switchLayer(garage, setup)
	showBackground(Root.carInfo.backgroundPic)
	updateHints()
	cards[SaveManager.playerData.selectedCar].mainButton.grab_focus()

func switchLayer(show: Control, hide: Control) -> void:
	hide.visible = false
	show.visible = true
	show.modulate.a = 0.0
	create_tween().tween_property(show, "modulate:a", 1.0, SLIDE_SECONDS)
	logo.visible = show == garage

func refreshSetup(animate := true) -> void:
	var levels = SaveManager.playerData.levels
	var selected = SaveManager.playerData.selectedLevel
	var count = levels.size()
	for i in count:
		var poster = posters[i]
		var offset = wrapi(i - selected + count / 2, 0, count) - count / 2
		var slot = POSTER_SLOTS.get(offset)
		if not slot:
			poster.visible = false
			continue
		if not poster.visible: #sliding in from the side
			poster.position = slot[0] + Vector2(signf(offset) * 300, 0)
			poster.modulate.a = 0.0
			poster.visible = true
		var target: Vector2 = slot[0]
		var scale = Vector2(slot[1], slot[1])
		var tint = Color.WHITE if offset == 0 else Color(0.5, 0.5, 0.5)
		if animate:
			var tween = poster.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(poster, "position", target, SLIDE_SECONDS)
			tween.tween_property(poster, "scale", scale, SLIDE_SECONDS)
			tween.tween_property(poster, "modulate", tint, SLIDE_SECONDS)
		else:
			poster.position = target
			poster.scale = scale
			poster.modulate = tint
		refreshPoster(i, offset == 0)
	stackByDistance(setup, posters, selected)
	var level = levels[selected]
	if posters[selected].get_node("art").texture == null: finishPosterLoad(selected, true)
	showBackground(posters[selected].get_node("art").texture, animate)
	var mode = SaveManager.getGameMode()
	var forModes = selectedLevelForModes()
	for i in MODE_ORDER.size(): refreshMedallion(medallions[i], MODE_ORDER[i], MODE_ORDER[i] == mode, forModes)
	modeTitle.text = Root.gameModeDescription[mode].name
	modeText.text = Root.gameModeDescription[mode].description
	if mode == Root.gameModes.GOONPOCALYPSE:
		var best = SaveManager.bestGoonpocalypse(selected, SaveManager.playerData.cars[SaveManager.playerData.selectedCar].name)
		if best.time > 0: modeText.text += "\nBest here: %d:%02d, score %d" % [best.time / 60, best.time % 60, best.score]
	var reason = "" if isLevelSelectable(selected) else ("Not in the demo" if isDemoLockedLevel(selected) else "Beat the level before it to unlock")
	if reason == "": reason = Root.modeLockReason(forModes, mode)
	modeLock.text = reason
	modeLock.visible = reason != ""
	var playable = isLevelSelectable(selected) && Root.isModePlayable(forModes, mode)
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
	var beaten = 0
	for mode in MODE_ORDER: if level.gamemodeBeat.get(mode, false): beaten += 1
	for i in MODE_ORDER.size():
		var star = MenuTheme.iconRect(HudTheme.STAR_ICON, 24)
		if i >= beaten: star.modulate = Color(0.2, 0.15, 0.1, 0.55)
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
	disc.icon = HudTheme.STAR_ICON if playable else HudTheme.LOCK_ICON
	disc.modulate = Color.WHITE if beaten || not playable else Color(0.85, 0.85, 0.85)
	var style = MenuTheme.box(HudTheme.PANEL, HudTheme.RIM if selected else Color(1, 1, 1, 0.25), 48, 4 if selected else 2, Vector4(16, 16, 16, 16))
	if selected:
		style.shadow_color = Color(HudTheme.GOLD, 0.45)
		style.shadow_size = 14
	for state in ["normal", "hover", "pressed", "focus"]: disc.add_theme_stylebox_override(state, style)
	var label: Label = column.get_node("name")
	label.theme_type_variation = "GoldLabel" if selected else ""
	label.add_theme_font_size_override("font_size", 19 if selected else 16)
	column.modulate = Color.WHITE if playable || selected else Color(1, 1, 1, 0.55)

func onStartPressed() -> void:
	var index = SaveManager.playerData.selectedLevel
	if screen == Screen.SETUP && isLevelSelectable(index) && Root.isModePlayable(selectedLevelForModes(), SaveManager.getGameMode()):
		var gadget := loadoutChoice()
		if gadget != "" && SaveManager.playerData.gem >= Pickups.LOADOUT[gadget]:
			SaveManager.playerData.gem -= Pickups.LOADOUT[gadget]
			Pickups.loadout = gadget #the car takes it in its first tick (OverheadCarBody2D.tickPickups)
		startLevel(SaveManager.playerData.levels[index].scene)

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

#menu navigation runs before the GUI so Left/Right switch cards instead of moving focus;
#in upgrade mode the arrows go to the GUI, which moves between the stat rows
func _input(event: InputEvent) -> void:
	if Settings.menu_open || loadingLevel || overlayOpen() || not event.is_pressed() || event.is_echo(): return
	var handled := true
	if screen == Screen.GARAGE && upgrading:
		if event.is_action_pressed("ui_cancel") || event.is_action_pressed("ui_upgrade"): setUpgrading(false)
		else: handled = false
	elif screen == Screen.GARAGE:
		if event.is_action_pressed("ui_tab_prev") || event.is_action_pressed("ui_left"): selectCar(SaveManager.playerData.selectedCar - 1)
		elif event.is_action_pressed("ui_tab_next") || event.is_action_pressed("ui_right"): selectCar(SaveManager.playerData.selectedCar + 1)
		elif event.is_action_pressed("ui_upgrade"): setUpgrading(true)
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: cards[SaveManager.playerData.selectedCar].onMainPressed()
		else: handled = false
	else:
		if event.is_action_pressed("ui_cancel"): goToGarage()
		elif event.is_action_pressed("ui_tab_prev"):
			SaveManager.selectPreviousLevel()
			refreshSetup()
		elif event.is_action_pressed("ui_tab_next"):
			SaveManager.selectNextLevel()
			refreshSetup()
		elif event.is_action_pressed("ui_left"): stepMode(-1)
		elif event.is_action_pressed("ui_right"): stepMode(1)
		elif event.is_action_pressed("ui_records"): openRecords()
		elif event.is_action_pressed("ui_codex"): openGoonopedia()
		elif event.is_action_pressed("ui_menu"): openSettings()
		elif event.is_action_pressed("ui_upgrade"): cycleLoadout()
		elif event.is_action_pressed("ui_accept") && get_viewport().gui_get_focus_owner() == null: onStartPressed()
		else: handled = false
	if handled: get_viewport().set_input_as_handled()

func stepMode(direction: int) -> void:
	var at = MODE_ORDER.find(SaveManager.getGameMode())
	SaveManager.setGameMode(MODE_ORDER[wrapi(at + direction, 0, MODE_ORDER.size())])
	refreshSetup()

func overlayOpen() -> bool:
	return get_tree().get_nodes_in_group("menuOverlay").size() > 0

func updateHints() -> void:
	for child in hintBar.get_children():
		hintBar.remove_child(child)
		child.queue_free()
	var hints: Array
	if screen == Screen.SETUP:
		hints = [[["ui_tab_prev", "ui_tab_next"], "Level"], [["ui_left", "ui_right"], "Mode"], [["ui_accept"], "Start"], [["ui_upgrade"], "Gadget"], [["ui_records"], "Records"], [["ui_codex"], "Goonopedia"], [["ui_cancel"], "Back"]]
	elif upgrading:
		hints = [[["ui_up", "ui_down"], "Choose"], [["ui_accept"], "Buy"], [["ui_cancel"], "Done"]]
	else:
		var locked = cards[SaveManager.playerData.selectedCar].isLocked()
		hints = [[["ui_tab_prev", "ui_tab_next"], "Driver"], [["ui_accept"], "Unlock" if locked else "Drive"]]
		if not locked: hints.push_back([["ui_upgrade"], "Upgrade"])
		hints.append_array([[["ui_records"], "Records"], [["ui_codex"], "Goonopedia"], [["ui_menu"], "Settings"]])
	for hint in hints: hintBar.add_child(KeyHint.make(PackedStringArray(hint[0]), hint[1], 16))

#---------- overlays and runs ----------

func openSettings() -> void:
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())

func openGoonopedia() -> void:
	if overlayOpen(): return
	Goonopedia.open(self).closed.connect(onOverlayClosed)

#focus back to the screen under an overlay
func onOverlayClosed() -> void:
	if screen == Screen.SETUP: startButton.grab_focus()
	else: cards[SaveManager.playerData.selectedCar].mainButton.grab_focus()

func openRecords() -> void:
	var scene = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	scene.isGameSummary = false
	add_child(scene)

var loadingPanel: PanelContainer
#loads the level on a worker thread behind a "Loading" panel instead of freezing the menu
func startLevel(path: String) -> void:
	if loadingLevel: return
	loadingLevel = true
	Region.resetRegions()
	SaveManager.flush()
	loadingPanel = PanelContainer.new()
	loadingPanel.theme = MenuTheme.theme()
	loadingPanel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loadingPanel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loadingPanel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var label = Label.new()
	label.text = "LOADING..."
	label.theme_type_variation = "GoldLabel"
	label.add_theme_font_size_override("font_size", 44)
	loadingPanel.add_child(label)
	add_child(loadingPanel)
	ResourceLoader.load_threaded_request(path)
	var carScene = Root.selectedCar.scene #the menu only loaded the car's CarInfo; levelRoot instantiates the scene
	if not ResourceLoader.has_cached(carScene): ResourceLoader.load_threaded_request(carScene)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			|| ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(carScene) == ResourceLoader.THREAD_LOAD_LOADED:
		Root.selectedCarScene = ResourceLoader.load_threaded_get(carScene) #held so the cache keeps it
	await get_tree().process_frame #let the panel draw before the level is built
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
	var tween = create_tween()
	tween.tween_method(func(v): coinsLabel.text = DriverCard.formatCoins(int(v)), float(from), float(to), clampf((to - from) / 300.0, 0.3, 1.5))
