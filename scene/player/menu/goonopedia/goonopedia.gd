class_name Goonopedia extends Control

#The Goonopedia (docs/UI.md): what's in the game, opened from the main menu with G / View.
#Tabs GOONS, CARS, LEVELS, PICKUPS, MODES and SYSTEMS. Each tab is a grid of entries on the left and a
#detail card for the focused entry on the right. The entries and their numbers come from the game's own
#tables (Goons.DATA, the save's cars and levels, Root.powerup, Root.gameModeDescription, the car's
#systems), so new goons, cars and levels show up by themselves; only the plain-language text is written
#here. A goon's DATA can carry "blurb" and "tip" strings to replace the text its verb gives it.
#Goons show as silhouettes until the player crushes one (PlayerData.goonsCrushed, credited by gameSummary).
#The Pickups tab is also where pickups are unlocked (Unlocks): each kind's tree in order, a locked tile
#shows its price or play condition, and Accept (or a click) buys a ready one.

signal closed

#the pages with something to unlock come first; the Goonopedia opens on Pickups
enum Tab { PICKUPS, CARS, LEVELS, MODES, GOONS, SYSTEMS }
const TAB_NAMES := ["PICKUPS", "CARS", "LEVELS", "MODES", "GOONS", "SYSTEMS"]
const REVEAL_ALL := false #true shows every goon without crushing one first
const ICON := preload("res://texture/icon/goonopedia.svg")
const SHADOW := Color(0, 0, 0, 0.88) #silhouette tint for undiscovered goons and locked cars
const LIST_WIDTH := 720.0
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")
const UPGRADE_ICON := preload("res://texture/icon/upgrade.svg")

#---------- text ----------

const RANK_NAMES := {0: "SPAWN", 1: "FODDER", 2: "SPECIAL", 3: "HEAVY"}
const TERRAIN_NAMES := ["Grass", "Sand", "Mud", "Water", "Hills", "Moss", "Dirt", "Snow"] #Goons.T order
const FACTION_COLORS := [Color(0.533, 0.776, 0.388), Color(0.604, 0.541, 0.659), Color(0.69, 0.718, 0.745)]
const FACTION_TEXT := [
	"Critters of the open country. You meet them near the start and on the early levels.",
	"One mutant tribe in rags and car junk. They hold the land further out.",
	"Anything with wheels or an engine. They rule the far edges and the late levels.",
]
const SYSTEM_NAMES := {"hull": "Hull", "tires": "Tires", "engine": "Engine", "steering": "Steering", "lights": "Lights", "tank": "Fuel Tank"}

#verb -> [what it does, how to beat it]. Unknown verbs fall back to the generic line.
const VERB_TEXT := {
	&"lunge": ["Walks up to you, crouches, and lunges.", "Watch for the crouch, then swerve. It's open while it recovers."],
	&"dodger": ["Zig-zags in and sidesteps once when you bear down on it at speed.", "Fake it out. Once the sidestep is spent, it's yours."],
	&"lobber": ["Keeps its distance and lobs something where you're about to be.", "Change course as soon as the landing mark appears."],
	&"shooter": ["Keeps its distance and shoots along a dotted aim line.", "Get off the dotted line before it fires."],
	&"trapper": ["Runs ahead of you and unrolls a spike strip across your path.", "Drive around the strip, or flatten it before the strip is down."],
	&"bomber": ["Lights a fuse near you and rushes in. The blast hurts your car and flattens goons too.", "Crushing it still sets it off. Keep your speed and get clear."],
	&"hitcher": ["Leaps onto your car and sabotages it while it rides along.", "A hard swerve throws it off."],
	&"turtle": ["Pulls into its car-roof shell when you rush it.", "Kick the shell above %s and it slides away, flattening goons in its path."],
	&"boss": ["Hangs back with a megaphone. Goons near it move faster.", "Take it out first and the whole crowd slows down."],
	&"burrow": ["Waits out of sight, then surfaces right next to you to bite.", "It can't be crushed while it's hidden. Wait for it to come up."],
	&"pack": ["Runs in a pack. They scatter when you come in fast, then close in again.", "Ease off, let them bunch up, then drive through."],
	&"roller": ["Tucks into a ball and rolls straight at you. Rolling, it's as hard as a rock.", "Dodge the roll. Afterwards it's dizzy and easy to crush."],
	&"slammer": ["Raises a sledgehammer and slams the ground ahead of it.", "Stay out of the slam. The hammer sticks afterwards, so strike then."],
	&"charger": ["Charges in a long straight line it can't turn out of.", "Step aside and T-bone it. It's stunned after a charge."],
	&"hopper": ["Moves in hops, and can't be hit in the air.", "Time it for the landing."],
	&"thief": ["Steals pickups and runs off with them.", "Crush it to get them back, with interest."],
	&"striker": ["Stops at its reach and strikes. A ring shows how far it reaches.", "Stay outside the ring until it strikes, then go in."],
	&"spiky": ["Bristles and fires a ring of quills.", "Hit it fast. Crushing it slowly costs your tires."],
	&"flyer": ["Circles overhead out of reach, and swoops at your lights. It lands to feed on crushed goons.", "Get it on the ground while it's feeding."],
	&"herd": ["A herd that stampedes across your path and ignores you.", "It's heavy, so hit it fast."],
	&"rider": ["Drives like a car.", "Head-on it's armoured. T-bone it."],
}
#Scrap Gang riders: act -> what it does
const ACT_TEXT := {
	"ram": "Lines up and rams you.", "swipe": "Pulls alongside and swipes at you.", "tailgate": "Tailgates you and shoves you from behind.",
	"burn": "Leaves a trail of fire behind it.", "oil": "Drops oil slicks behind it.", "harpoon": "Fires a harpoon that hooks your car.",
	"bomb": "Lobs bombs where you're about to be.", "boost": "Rockets straight at you and explodes.", "saw": "Weaves in close with a buzzsaw.",
	"shoot": "Keeps its distance and shoots along an aim line.", "magnet": "Drags your car toward it with a magnet.",
}
#DATA flags -> a line under the behaviour
const TRAIT_TEXT := {
	"night": "Sleeps by day. At night it keeps out of your headlights.", "wander": "Ignores you until you get close.",
	"shield": "Carries a front shield and turns slowly.", "deathFire": "Leaves fire where it dies.",
	"log": "Lies still as a log until you pass.", "flank": "Circles round to hit you from the side.",
}

#Root.upgrade -> [name, what it does]
const PICKUP_TEXT := {
	Root.upgrade.HEALTH: ["Repair Kit", "Patches up %d hull."],
	Root.upgrade.FUEL: ["Fuel Can", "Adds %d fuel."],
	Root.upgrade.ENGINE: ["Engine", "+%d Engine for this run: harder acceleration."],
	Root.upgrade.STEERING: ["Steering", "+%d Steering for this run: the wheels turn further."],
	Root.upgrade.TRACTION: ["Traction", "+%d Traction for this run: more grip and better brakes."],
	Root.upgrade.ARMOR: ["Armor", "+%d Armor for this run: every hit does less damage."],
	Root.upgrade.HEADLIGHTS: ["Headlights", "+%d Headlights for this run: you see further at night."],
	Root.upgrade.OIL: ["Oil", "+%d Oil for this run: the engine burns less fuel."],
	Root.upgrade.CLOVER: ["Clover", "+%d Clover for this run: crushed goons drop pickups more often."],
	Root.upgrade.LUCK: ["Dice", "+%d Dice for this run: drops are more often purses, gems and slot machines."],
	Root.upgrade.COIN: ["Coin", "+%d coin. Stars multiply what a run pays."],
	Root.upgrade.PURSE: ["Purse", "+%d coins in one go."],
	Root.upgrade.GEM: ["Gem", "+%d gem. Gems pay for slot machine rerolls."],
	Root.upgrade.SLOTMACHINE: ["Slot Machine", "Opens the slot machine: three reels of prizes, free to spin."],
}
const STAT_UPGRADES := [Root.upgrade.ENGINE, Root.upgrade.STEERING, Root.upgrade.TRACTION, Root.upgrade.ARMOR,
	Root.upgrade.HEADLIGHTS, Root.upgrade.OIL, Root.upgrade.CLOVER, Root.upgrade.LUCK]

#Root.gameModes -> how a run in it is won and lost
const MODE_RULES := {
	Root.gameModes.GOONCRUSHER: "The clock counts down from the level's time. Still driving when it hits zero? You win.",
	Root.gameModes.SPRINT: "Reach the gas station before the clock runs out. The further away the station, the more time you get.",
	Root.gameModes.MARATHON: "A relay of stations against the clock. Each one refuels and repairs you, and its pit shop sells pickups for run coins.",
	Root.gameModes.DEFENSE: "Hold the station until the clock runs out. Barricade Kits patch its walls and Sentry Turrets help guard them.",
	Root.gameModes.GOONPOCALYPSE: "No finish line. The clock counts up, and the run lasts as long as you do.",
}
const MODE_UNLOCK := {
	Root.gameModes.GOONCRUSHER: "Open on every unlocked level.",
	Root.gameModes.SPRINT: "Beat Countdown on a level to unlock it there.",
	Root.gameModes.MARATHON: "Beat Sprint on a level to unlock it there.",
	Root.gameModes.DEFENSE: "Beat Sprint on a level to unlock it there.",
	Root.gameModes.GOONPOCALYPSE: "Beat Countdown and Sprint on a level to unlock it there.",
}

#system -> [icon, what wear does]. The car's CONDITION_FLOOR supplies the numbers.
const SYSTEMS := [
	["hull", preload("res://texture/icon/health.svg"), "Your car's health. Goon attacks and crashes take it down, Armor softens every hit, and at zero the car is wrecked."],
	["tires", preload("res://texture/icon/traction.svg"), "Worn tires grip less."],
	["engine", preload("res://texture/icon/engine.svg"), "A damaged engine pulls less."],
	["steering", preload("res://texture/icon/steering.svg"), "Damaged steering turns less."],
	["lights", preload("res://texture/icon/headlights.svg"), "Broken lights reach less far, which matters at night."],
	["tank", preload("res://texture/icon/fuel.svg"), "A damaged tank makes Oil count for less, and below half it leaks fuel."],
]
const SYSTEM_STAT_NAMES := {"lights": "headlight reach", "engine": "engine power", "steering": "steering", "tires": "traction", "tank": "Oil"}

#---------- state ----------

var tab := Tab.PICKUPS
var tabButtons: Array[Button] = []
var list := VBoxContainer.new()
var listScroll := ScrollContainer.new()
var detail := VBoxContainer.new()
var into: VBoxContainer = detail #where the card helpers add rows: the detail card, or a showcase's side column
var progressLabel := Label.new()
var bankRow := HBoxContainer.new() #the header's coins and gems, as symbols
var tiles: Array[Button] = []
var shown = null #the entry in the detail card
var preview: GoonPreview
var pending := {}        #resource path -> Callable(resource) to run once it has loaded on a worker thread
var carInfos := {}       #car index -> CarInfo

static func open(parent: Node) -> Goonopedia:
	var page = Goonopedia.new()
	parent.add_child(page)
	return page

func _ready() -> void:
	add_to_group("menuOverlay")
	InputGlyphs.ensureMenuActions()
	theme = MenuTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim = ColorRect.new()
	scrim.color = Color(0.03, 0.025, 0.02, 0.97)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_right = -48
	root.offset_top = 26
	root.offset_bottom = -22
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.add_child(buildHeader())
	root.add_child(buildTabs())
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	var left = PanelContainer.new()
	left.theme_type_variation = "QuietPanel"
	left.custom_minimum_size.x = LIST_WIDTH
	listScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	listScroll.follow_focus = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	listScroll.add_child(list)
	left.add_child(listScroll)
	body.add_child(left)
	var right = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detailScroll = ScrollContainer.new()
	detailScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	detailScroll.add_child(detail)
	right.add_child(detailScroll)
	body.add_child(right)
	root.add_child(KeyHint.bar([[["ui_tab_prev", "ui_tab_next"], "Tab"], [["ui_up", "ui_down"], "Browse"], [["ui_accept"], "Buy"], [["ui_cancel"], "Back"]]))
	setTab(Tab.PICKUPS)
	Juice.dropIn(self, 30.0)

func buildHeader() -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(MenuTheme.iconRect(ICON, 56))
	var title = Label.new()
	title.text = "GOONOPEDIA"
	title.theme_type_variation = "TitleLabel"
	row.add_child(title)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	progressLabel.theme_type_variation = "GoldLabel"
	progressLabel.add_theme_font_size_override("font_size", 24)
	progressLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(progressLabel)
	bankRow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bankRow.custom_minimum_size.x = 20
	row.add_child(bankRow)
	var close = MenuTheme.button("BACK", PackedStringArray(["ui_cancel"]))
	close.custom_minimum_size = Vector2(150, 48)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(closePage)
	row.add_child(close)
	return row

func buildTabs() -> Control:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(KeyHint.make(PackedStringArray(["ui_tab_prev"]), "", 15, true))
	for i in TAB_NAMES.size():
		var b = Button.new()
		b.text = "%d  %s" % [i + 1, TAB_NAMES[i]] #number keys pick a tab, like the level posters
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(setTab.bind(i))
		MenuTheme.addSounds(b)
		row.add_child(b)
		tabButtons.push_back(b)
	row.add_child(KeyHint.make(PackedStringArray(["ui_tab_next"]), "", 15, true))
	return row

#---------- tabs and tiles ----------

func setTab(value: int) -> void:
	tab = wrapi(value, 0, TAB_NAMES.size())
	for i in tabButtons.size(): tabButtons[i].set_pressed_no_signal(i == tab)
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	tiles.clear()
	shown = null
	match tab:
		Tab.GOONS: buildGoons()
		Tab.CARS: buildCars()
		Tab.LEVELS: buildLevels()
		Tab.PICKUPS: buildPickups()
		Tab.MODES: buildModes()
		Tab.SYSTEMS: buildSystems()
	listScroll.scroll_vertical = 0
	refreshBank()
	if not tiles.is_empty(): tiles[0].grab_focus()

## The bank in the header, on the tabs that sell things: "3,000 (coin)  4 (gem)"
func refreshBank() -> void:
	for child in bankRow.get_children():
		bankRow.remove_child(child)
		child.queue_free()
	if tab != Tab.PICKUPS && tab != Tab.CARS: return
	var data := SaveManager.playerData
	var pill = PanelContainer.new() #a pill like the garage's bank, apart from the page's count
	pill.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0.35), Color(HudTheme.RIM, 0.55), 12, 2, Vector4(14, 3, 14, 3)))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := MenuTheme.symbolRow([DriverCard.formatCoins(data.coin), HudTheme.COIN_ICON, str(data.gem), HudTheme.GEM_ICON], 24, HudTheme.GOLD)
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	bankRow.add_child(pill)

func section(title: String, note := "", color := HudTheme.RIM) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch = ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(6, 26)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)
	if note != "":
		var extra = Label.new()
		extra.text = note
		extra.theme_type_variation = "MutedLabel"
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(extra)
	list.add_child(row)

func grid(columns: int) -> GridContainer:
	var g = GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	list.add_child(g)
	return g

#a tile: a picture over a name. `entry` is what showDetail gets when the tile has focus.
func tile(parent: Control, entry: Dictionary, picture: Texture2D, caption: String, tileSize: Vector2, dim := false) -> Button:
	var b = Button.new()
	b.custom_minimum_size = tileSize
	b.clip_contents = true
	MenuTheme.addSounds(b)
	var art = TextureRect.new()
	art.name = "art"
	art.texture = picture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = entry.get("stretch", TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset = entry.get("inset", 12.0)
	art.offset_left = inset
	art.offset_right = -inset
	art.offset_top = inset * 0.6
	art.offset_bottom = -30
	if dim: art.modulate = SHADOW
	b.add_child(art)
	var label = Label.new()
	label.name = "caption"
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -28
	label.offset_bottom = -4
	b.add_child(label)
	b.set_meta("key", entry.get("key"))
	b.focus_entered.connect(showDetail.bind(entry))
	parent.add_child(b)
	tiles.push_back(b)
	return b

#loads `path` on a worker thread and hands it to `then`; at once when it's already cached
func loadThen(path: String, then: Callable) -> void:
	if path == "" || not ResourceLoader.exists(path): return
	if ResourceLoader.has_cached(path):
		then.call(load(path))
		return
	if pending.has(path):
		var first: Callable = pending[path]
		pending[path] = func(r): first.call(r); then.call(r)
		return
	ResourceLoader.load_threaded_request(path)
	pending[path] = then

func _process(_delta: float) -> void:
	for path in pending.keys():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		var then: Callable = pending[path]
		pending.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED: then.call(ResourceLoader.load_threaded_get(path))

func _exit_tree() -> void:
	for path in pending.keys(): #don't leave finished loads parked in the loader
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(path)

#sets a tile's picture once it loads, if the tile is still there
#(`b` is untyped: a typed Button argument errors before the body runs when the tile was freed)
static func setTileArt(texture: Texture2D, b) -> void:
	if is_instance_valid(b) && texture: b.get_node("art").texture = texture

#a goon card's animation, if the card is still showing
static func setPreviewFrames(frames, shown) -> void:
	if is_instance_valid(shown): shown.setFrames(frames)

#the same for a TextureRect itself (a level card's banner)
static func setTexture(texture: Texture2D, rect) -> void:
	if is_instance_valid(rect) && texture: rect.texture = texture

#a goon's frame cropped to a square around the goon, so it fills its tile
static func setGoonTileArt(texture: Texture2D, b) -> void:
	if texture == null: return
	var focus := artBounds(texture)
	var side := maxf(focus.size.x, focus.size.y) * 1.08
	var crop := Rect2(focus.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)).intersection(Rect2(Vector2.ZERO, texture.get_size()))
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = crop
	setTileArt(atlas, b)

static var boundsCache := {} #texture path -> Rect2 of its visible pixels

## The part of `texture` that isn't transparent (a goon and its soft shadow), in texture pixels; the
## whole texture when its pixels can't be read (headless).
static func artBounds(texture: Texture2D) -> Rect2:
	var whole := Rect2(Vector2.ZERO, texture.get_size())
	var key := texture.resource_path
	if key != "" && boundsCache.has(key): return boundsCache[key]
	var image := texture.get_image()
	if image == null || image.is_empty(): return whole
	if image.is_compressed(): image.decompress()
	var used := Rect2(image.get_used_rect())
	if used.size.x < 1.0 || used.size.y < 1.0: used = whole
	if key != "": boundsCache[key] = used
	return used

#---------- detail card helpers ----------

func clearDetail() -> void:
	preview = null
	into = detail
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()

func hero(height := 250.0) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size.y = height
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.1, 0.085, 0.075), Color(0, 0, 0, 0), 12, 0))
	into.add_child(panel)
	return panel

func heroPicture(panel: Control, texture: Texture2D, stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED, inset := 0.0) -> TextureRect:
	var picture = TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = stretch
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = inset
	picture.offset_top = inset
	picture.offset_right = -inset
	picture.offset_bottom = -inset
	panel.add_child(picture)
	return picture

#a square art panel with a column beside it: the card helpers fill the column until endShowcase(), then
#continue full width below. For art that is an object (goons, pickups, icons); wide pictures use hero().
func showcase(side: float, glow: Color) -> Panel:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	detail.add_child(row)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(side, side)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(0.1, 0.085, 0.075), Color(glow, 0.35), 14, 2))
	row.add_child(panel)
	var halo = Glow.new()
	halo.color = glow
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(halo)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.y = side
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	into = column
	return panel

func endShowcase() -> void:
	into = detail

#the entry's name, with chips after it: [text, color]
func titleRow(title: String, chips := []) -> void:
	var row = HFlowContainer.new() #chips wrap under the name in a showcase's narrow column
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 6)
	var label = Label.new()
	label.text = title
	label.theme_type_variation = "GoldLabel"
	label.add_theme_font_size_override("font_size", 36)
	row.add_child(label)
	for c in chips: row.add_child(chip(c[0], c[1]))
	into.add_child(row)

static func chip(text: String, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(color, 0.18), Color(color, 0.8), 7, 2, Vector4(10, 2, 10, 2)))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	panel.add_child(label)
	return panel

func paragraph(text: String, type := "BodyLabel") -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = type
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	into.add_child(label)
	return label

#a gold TIP chip and a line of advice
func tipRow(text: String) -> void:
	if text == "": return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var c = chip("TIP", HudTheme.GOLD)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(c)
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "BodyLabel"
	label.add_theme_color_override("font_color", HudTheme.GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	into.add_child(row)

#a chip naming a fact and its text (a level's barrier, its surfaces); nothing for empty text
func factRow(tag: String, text: String, color: Color) -> void:
	if text == "": return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var c = chip(tag, color)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size.x = 112
	row.add_child(c)
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "BodyLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	into.add_child(row)

#a car's stats as statTable shows them, each with a button that buys its next upgrade (price, or MAX)
func upgradeTable(index: int, rows: Array) -> void:
	var table = GridContainer.new()
	table.columns = 5
	table.add_theme_constant_override("h_separation", 12)
	table.add_theme_constant_override("v_separation", 6)
	for i in DriverCard.STATS.size():
		var stat: int = DriverCard.STATS[i][1]
		var r: Array = rows[i]
		table.add_child(MenuTheme.iconRect(r[4], 24))
		var name = Label.new()
		name.text = r[0]
		name.theme_type_variation = "MutedLabel"
		name.add_theme_font_size_override("font_size", 18)
		name.custom_minimum_size.x = 120
		table.add_child(name)
		var barHolder = Control.new()
		barHolder.custom_minimum_size = Vector2(180, 24)
		var bar = DriverCard.StatBar.new()
		bar.base = int(r[2])
		bar.bought = int(r[3])
		bar.position = Vector2(0, 9)
		bar.size = Vector2(180, 7)
		barHolder.add_child(bar)
		table.add_child(barHolder)
		var level: int = int(r[3])
		var value := MenuTheme.symbolRow([str(int(r[2]) + level)], 20)
		value.alignment = BoxContainer.ALIGNMENT_BEGIN
		if level > 0: value.add_child(MenuTheme.symbolRow(["+%d" % level], 15, HudTheme.GOLD))
		value.custom_minimum_size.x = 80
		table.add_child(value)
		var maxed := SaveManager.isUpgradeMaxed(stat, index)
		var cost := SaveManager.requestStatCost(stat, index)
		var affordable := not maxed && cost <= SaveManager.playerData.coin
		var buy = MenuTheme.button("", PackedStringArray(), affordable)
		buy.custom_minimum_size = Vector2(150, 36)
		buy.disabled = maxed
		buy.set_meta("stat", stat)
		MenuTheme.setButtonParts(buy, ["MAX"] if maxed else [UPGRADE_ICON, {"coin": cost}], 17)
		if not affordable && not maxed: buy.get_node("parts").modulate = Color(1, 1, 1, 0.55)
		buy.tooltip_text = "" if maxed else "Next %s upgrade (%d / %d)" % [r[0], level + 1, SaveManager.MAX_UPGRADE_LEVEL]
		buy.pressed.connect(buyUpgrade.bind(index, stat))
		table.add_child(buy)
	into.add_child(table)

#rows of [label, value text] or [label, value text, bar 0-100, bonus 0-100, icon]
func statTable(rows: Array) -> void:
	var table = GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 6)
	for r in rows:
		var icon: Texture2D = r[4] if r.size() > 4 else null
		var holder = Control.new()
		holder.custom_minimum_size = Vector2(24, 24)
		if icon:
			var picture = MenuTheme.iconRect(icon, 24)
			holder.add_child(picture)
		table.add_child(holder)
		var name = Label.new()
		name.text = r[0]
		name.theme_type_variation = "MutedLabel"
		name.add_theme_font_size_override("font_size", 18)
		name.custom_minimum_size.x = 150
		table.add_child(name)
		var barHolder = Control.new()
		barHolder.custom_minimum_size = Vector2(220, 24)
		if r.size() > 2 && r[2] != null:
			var bar = DriverCard.StatBar.new()
			bar.base = int(r[2])
			bar.bought = int(r[3]) if r.size() > 3 && r[3] != null else 0
			bar.position = Vector2(0, 9)
			bar.size = Vector2(220, 7)
			barHolder.add_child(bar)
		table.add_child(barHolder)
		var value = Label.new()
		value.text = r[1]
		value.add_theme_font_size_override("font_size", 18)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART #long values wrap instead of widening the card
		value.custom_minimum_size.x = 120
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(value)
	into.add_child(table)

func showDetail(entry: Dictionary) -> void:
	shown = entry
	clearDetail()
	match entry.kind:
		"goon": goonDetail(entry)
		"car": carDetail(entry)
		"level": levelDetail(entry)
		"pickup": pickupDetail(entry)
		"prize": prizeDetail(entry)
		"mode": modeDetail(entry)
		"system": systemDetail(entry)

#redraws the detail card if it's still showing `entry` (after something it shows has loaded)
func refreshIfShown(kind: String, key) -> void:
	if shown != null && shown.kind == kind && shown.key == key: showDetail(shown)

#---------- goons ----------

static func isDiscovered(id: StringName) -> bool:
	return REVEAL_ALL || SaveManager.playerData.goonsCrushed.get(String(id), 0) > 0

#adds a run's crushes (goon id -> count) to the save; returns the names of goons crushed for the first time
static func creditCrushes(crushed: Dictionary) -> Array:
	var found = []
	var total: Dictionary = SaveManager.playerData.goonsCrushed
	for id in crushed:
		var key = String(id)
		if total.get(key, 0) == 0 && Goons.DATA.has(StringName(key)): found.push_back(Goons.DATA[StringName(key)].name)
		total[key] = total.get(key, 0) + crushed[id]
	return found

static func goonArt(id: StringName, pose := "idle0") -> String:
	return "res://scene/enemy/goons/%s/art/%s_%s.png" % [id, id, pose]

static func goonFrames(id: StringName) -> String:
	return "res://scene/enemy/goons/%s/%s_frames.tres" % [id, id]

func buildGoons() -> void:
	var found := 0
	for f in Goons.FACTION_NAMES.size():
		var ids = Goons.DATA.keys().filter(func(id): return Goons.DATA[id].faction == f)
		ids.sort_custom(func(a, b): return Goons.DATA[a].rank < Goons.DATA[b].rank if Goons.DATA[a].rank != Goons.DATA[b].rank else String(a) < String(b))
		var here = ids.filter(isDiscovered).size()
		found += here
		section(Goons.factionName(f).to_upper(), "%d / %d found" % [here, ids.size()], FACTION_COLORS[f])
		var g = grid(5)
		for id in ids:
			var known = isDiscovered(id)
			var b = tile(g, {"kind": "goon", "key": id}, null, Goons.DATA[id].name if known else "???", Vector2(124, 124), not known)
			loadThen(goonArt(id), setGoonTileArt.bind(b))
	progressLabel.text = "GOONS FOUND  %d / %d" % [found, Goons.DATA.size()]

func goonDetail(entry: Dictionary) -> void:
	var id: StringName = entry.key
	var d: Dictionary = Goons.DATA[id]
	var known = isDiscovered(id)
	var faction: int = d.faction
	var panel = showcase(390.0, FACTION_COLORS[faction])
	preview = GoonPreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.silhouette = not known
	panel.add_child(preview)
	if ResourceLoader.exists(goonArt(id)): preview.still = load(goonArt(id))
	loadThen(goonFrames(id), setPreviewFrames.bind(preview)) #bound, not captured: browsing on frees the preview first
	titleRow(d.name.to_upper() if known else "???", [[Goons.factionName(faction).to_upper(), FACTION_COLORS[faction]], [RANK_NAMES.get(d.rank, "GOON"), HudTheme.RIM]])
	paragraph(habitat(id), "MutedLabel")
	if not known:
		paragraph(FACTION_TEXT[faction])
		tipRow("Crush one to fill in this page.")
		return
	paragraph(behaviour(d))
	tipRow(tip(d))
	endShowcase()
	var rows = [["Speed", "%d" % d.get("speed", 110), d.get("speed", 110) / 3.2]]
	if d.has("dmg"): rows.push_back(["Hits for", str(d.dmg), d.dmg * 100.0 / 12.0])
	var crush: float = d.get("crush", 100.0)
	rows.push_back(["Crush at", Settings.speed_text(crush) + "+", crush / 5.0])
	var front: float = d.get("front", 0.0)
	if front >= 9999.0: rows.push_back(["Head-on", "Can't be crushed"])
	elif front > 0.0: rows.push_back(["Head-on", "Needs " + Settings.speed_text(front) + "+"])
	if d.has("sys"): rows.push_back(["Wears your", SYSTEM_NAMES.get(d.sys, d.sys)])
	if d.has("pack"): rows.push_back(["Comes in", "groups of %d" % d.pack])
	rows.push_back(["You've crushed", DriverCard.formatCoins(SaveManager.playerData.goonsCrushed.get(String(id), 0))])
	statTable(rows)

#where a goon lives, or what it comes out of
static func habitat(id: StringName) -> String:
	var d: Dictionary = Goons.DATA[id]
	if d.rank == 0 || d.biomes.is_empty():
		var parents = Goons.DATA.keys().filter(func(other): return Goons.DATA[other].get("split", &"") == id)
		if parents.is_empty(): return "Only turns up in special places."
		return "Only appears when a %s is crushed." % " or ".join(parents.map(func(p): return Goons.DATA[p].name))
	return "Found on " + ", ".join(d.biomes.map(func(t): return TERRAIN_NAMES[t] if t < TERRAIN_NAMES.size() else "?"))

static func behaviour(d: Dictionary) -> String:
	if d.has("blurb"): return d.blurb
	var lines = []
	var verbText = VERB_TEXT.get(d.get("verb", &"lunge"), ["Keeps you guessing.", ""])
	if d.get("verb") == &"rider": lines.push_back(ACT_TEXT.get(d.get("act", "ram"), "") + " " + verbText[0])
	else: lines.push_back(verbText[0])
	for key in TRAIT_TEXT: if d.get(key, false): lines.push_back(TRAIT_TEXT[key])
	if d.has("split"): lines.push_back("Bursts into %ss when crushed." % Goons.DATA.get(d.split, {"name": "goon"}).name.to_lower())
	if d.has("aura"): lines.push_back("Its shouting reaches %d px." % d.aura)
	return " ".join(lines)

static func tip(d: Dictionary) -> String:
	if d.has("tip"): return d.tip
	var verb = d.get("verb", &"lunge")
	var text: String = VERB_TEXT.get(verb, ["", ""])[1]
	if verb == &"turtle": text = text % Settings.speed_text(460)
	if verb == &"rider" && d.get("front", 0.0) >= 9999.0: text = "Its plow can't be beaten head-on. Hit it from the side."
	elif verb == &"rider" && d.get("front", 0.0) <= 0.0: text = "Hit it from any side."
	return text

#---------- cars ----------

func buildCars() -> void:
	var cars = SaveManager.playerData.cars
	var owned = cars.filter(func(c): return c.cost == 0).size()
	progressLabel.text = "CARS OWNED  %d / %d" % [owned, cars.size()]
	section("DRIVERS", "%d / %d owned" % [owned, cars.size()])
	var g = grid(4)
	for i in cars.size():
		var locked = isCarLocked(i)
		var b = tile(g, {"kind": "car", "key": i, "inset": 6.0}, null, str(cars[i].name).capitalize(), Vector2(162, 170), locked)
		if locked && not (Root.IS_DEMO && i >= Root.DEMO_CAR_COUNT):
			addTileTag(b, [Unlocks.price("car:" + str(cars[i].name))], HudTheme.GOLD if Unlocks.canAfford("car:" + str(cars[i].name)) else HudTheme.MUTED)
		b.pressed.connect(onCarTilePressed.bind(i))
		loadThen(CarInfo.pathFor(cars[i].scene), onCarInfo.bind(i, b))

## Accept on a car tile: buys a locked car, or moves to an owned car's first upgrade button
func onCarTilePressed(index: int) -> void:
	if isPickingClick(index): return
	if isCarLocked(index):
		buyCar(index)
		return
	var first := upgradeButton(Root.upgrade.ENGINE)
	if first != null: first.grab_focus()

func buyCar(index: int) -> void:
	var car: Dictionary = SaveManager.playerData.cars[index]
	var b := tileFor(index)
	if not isCarLocked(index) || (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT): return
	if not Unlocks.buy("car:" + str(car.name)):
		if b: Juice.shake(b)
		return
	purchased()
	setTab(Tab.CARS)
	b = tileFor(index)
	if b:
		b.grab_focus()
		Juice.flash(b, HudTheme.GOLD, 0.6, 18)
		Juice.pop(b, 1.08, 0.4)

## Buys the next level of a stat on a car (the garage's price and cap) and keeps the focus on its button
func buyUpgrade(index: int, stat: int) -> void:
	var button := upgradeButton(stat)
	if not SaveManager.requestStatUpgrade(stat, index):
		if button: Juice.shake(button)
		return
	purchased()
	refreshIfShown("car", index)
	button = upgradeButton(stat)
	if button:
		button.grab_focus()
		Juice.flash(button.get_parent(), HudTheme.GOLD, 0.45, 10)

## The upgrade button for a stat on the car card showing, or null
func upgradeButton(stat: int) -> Button:
	for b in detail.find_children("*", "Button", true, false):
		if b.get_meta("stat", -1) == stat: return b
	return null

## After anything is bought here: the sound, the save, and the garage behind the page
func purchased() -> void:
	Audio.play(BUY_SOUND)
	SaveManager.flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()

## What the bank lacks for a price, as a cost ({} when it covers it)
static func shortfall(cost: Dictionary) -> Dictionary:
	var out := {}
	var coins: int = int(cost.get("coin", 0)) - SaveManager.playerData.coin
	var gems: int = int(cost.get("gem", 0)) - SaveManager.playerData.gem
	if coins > 0: out.coin = coins
	if gems > 0: out.gem = gems
	return out

## The card's big gold button for an unlock: "UNLOCK 2,500 (coin)", or "NEED 300 (coin) MORE" (disabled)
## when the bank is short. Full width under the picture, where it has room; Accept on the tile buys too.
func unlockButton(cost: Dictionary, onPress: Callable) -> Button:
	endShowcase()
	var short := shortfall(cost)
	var buy = MenuTheme.button("", PackedStringArray(["ui_accept"]), true)
	buy.focus_mode = Control.FOCUS_NONE
	buy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	buy.custom_minimum_size = Vector2(320, 58)
	buy.disabled = not short.is_empty()
	MenuTheme.setButtonParts(buy, ["UNLOCK", cost] if short.is_empty() else ["NEED", short, "MORE"], 24)
	buy.pressed.connect(onPress)
	into.add_child(buy)
	return buy

static func isCarLocked(index: int) -> bool:
	return SaveManager.playerData.cars[index].cost != 0 || (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT)

func onCarInfo(info: CarInfo, index: int, b) -> void:
	carInfos[index] = info
	if is_instance_valid(b):
		setTileArt(info.profilePic, b)
		b.get_node("caption").text = info.charName
	refreshIfShown("car", index)

func carDetail(entry: Dictionary) -> void:
	var index: int = entry.key
	var car: Dictionary = SaveManager.playerData.cars[index]
	var info: CarInfo = carInfos.get(index)
	var locked = isCarLocked(index)
	var panel = hero(250 if locked else 170) #an owned car's card needs the room for its upgrade rows
	if info:
		var back = heroPicture(panel, info.backgroundPic, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		back.modulate = Color(0.55, 0.55, 0.58)
		var face = heroPicture(panel, info.profilePic, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 8.0)
		if locked: face.modulate = SHADOW
	var status: Array
	if Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT: status = ["NOT IN DEMO", HudTheme.MUTED]
	elif car.cost != 0: status = ["LOCKED", HudTheme.MUTED]
	else: status = ["OWNED", HudTheme.OK]
	titleRow((info.charName if info else str(car.name)).to_upper(), [[str(car.name).capitalize().to_upper(), HudTheme.SKY], status])
	if info == null: return
	paragraph(carTraits(info))
	signatureRows(info)
	if locked && not (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT):
		unlockButton(Unlocks.price("car:" + str(car.name)), buyCar.bind(index))
	var rows = []
	var bought := 0
	for s in DriverCard.STATS:
		var base: int = info.get(s[0])
		var level: int = car.upgrades.get(s[1], 0)
		bought += level
		rows.push_back([PICKUP_TEXT[s[1]][0], str(base + level) if level == 0 else "%d  (+%d)" % [base + level, level], base, level, s[2]])
	if locked: statTable(rows)
	else: upgradeTable(index, rows)
	var records: Dictionary = car.records
	var bestLine = "Upgrades bought: %d / %d" % [bought, DriverCard.STATS.size() * SaveManager.MAX_UPGRADE_LEVEL]
	if records.get("goonsCrushed", 0) > 0:
		bestLine += "     Best run: %d crushed, %s paid" % [records.goonsCrushed, DriverCard.formatCoins(records.coin)]
	paragraph(bestLine, "MutedLabel")

#the car's signature features (CarTraits): icon, name, what kind of feature it is, and what it does
func signatureRows(info: CarInfo) -> void:
	var ids := info.traits.filter(func(id): return CarTraits.has(id))
	if ids.is_empty(): return
	var head = Label.new()
	head.text = "SIGNATURE"
	head.theme_type_variation = "MutedLabel"
	head.add_theme_font_size_override("font_size", 15)
	into.add_child(head)
	for id in ids:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var icon := MenuTheme.iconRect(CarTraits.texture(id), 44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 2)
		var title = HBoxContainer.new()
		title.add_theme_constant_override("separation", 10)
		var name = Label.new()
		name.text = CarTraits.displayName(id)
		name.theme_type_variation = "GoldLabel"
		name.add_theme_font_size_override("font_size", 21)
		title.add_child(name)
		var kind = chip(CarTraits.KIND_NAMES[CarTraits.kind(id)], CarTraits.color(id))
		title.add_child(kind)
		if CarTraits.kind(id) == CarTraits.Kind.ABILITY: title.add_child(chip(InputGlyphs.label("Ability"), HudTheme.GOLD))
		column.add_child(title)
		var text = Label.new()
		text.text = CarTraits.DATA[id].text
		text.theme_type_variation = "BodyLabel"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 200
		column.add_child(text)
		row.add_child(column)
		into.add_child(row)

#"Strong engine and armor. Weak headlights." against the average of every car whose info has loaded
func carTraits(info: CarInfo) -> String:
	if carInfos.size() < 2: return ""
	var ratios = []
	for s in DriverCard.STATS:
		var total := 0.0
		for i in carInfos: total += carInfos[i].get(s[0])
		var mean = maxf(total / carInfos.size(), 1.0)
		ratios.push_back([PICKUP_TEXT[s[1]][0].to_lower(), info.get(s[0]) / mean])
	ratios.sort_custom(func(a, b): return a[1] > b[1])
	var strong = ratios.filter(func(r): return r[1] >= 1.2).slice(0, 2).map(func(r): return r[0])
	var weak = ratios.filter(func(r): return r[1] <= 0.8)
	var parts = []
	if not strong.is_empty(): parts.push_back("Strong " + " and ".join(strong) + ".")
	if not weak.is_empty(): parts.push_back("Weak " + weak.back()[0] + ".")
	return " ".join(parts) if not parts.is_empty() else "An all-rounder."

#---------- levels ----------

#Every level in the registry (Levels, LevelDef); unlocks and beaten modes come from the save's entry at the same index
func buildLevels() -> void:
	var levels = SaveManager.playerData.levels
	var open = range(levels.size()).filter(func(i): return isLevelOpen(i)).size()
	progressLabel.text = "LEVELS OPEN  %d / %d" % [open, levels.size()]
	section("LEVELS", "%d / %d open" % [open, levels.size()])
	var g = grid(2)
	for i in levels.size():
		var def := Levels.defAt(i)
		var b = tile(g, {"kind": "level", "key": i, "stretch": TextureRect.STRETCH_KEEP_ASPECT_COVERED, "inset": 4.0},
			null, "%d   %s" % [i + 1, levelName(i).to_upper()], Vector2(334, 200))
		if not isLevelOpen(i): b.get_node("art").modulate = Color(0.35, 0.35, 0.35)
		loadThen(def.poster if def else str(levels[i].get("image", "")), setTileArt.bind(b))

static func isLevelOpen(index: int) -> bool:
	return SaveManager.playerData.levels[index].unlocked && not (Root.IS_DEMO && index >= Root.DEMO_LEVEL_COUNT)

static func levelName(index: int) -> String:
	var def := Levels.defAt(index)
	return def.displayName if def else str(SaveManager.playerData.levels[index].get("name", ""))

func levelDetail(entry: Dictionary) -> void:
	var index: int = entry.key
	var level: Dictionary = SaveManager.playerData.levels[index]
	var def := Levels.defAt(index)
	var panel = hero(230)
	var art = heroPicture(panel, null, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	loadThen(def.poster if def else str(level.get("image", "")), setTexture.bind(art)) #bound, not captured: the card may be gone by then
	var status = ["OPEN", HudTheme.OK] if isLevelOpen(index) else (["NOT IN DEMO", HudTheme.MUTED] if level.unlocked else ["LOCKED", HudTheme.BAD])
	var chips = [status]
	if def: chips.push_front(["ACT %d" % def.act, HudTheme.RIM])
	titleRow("%d  %s" % [index + 1, levelName(index).to_upper()], chips)
	if not isLevelOpen(index) && level.unlocked == false: paragraph(Root.openRuleText(SaveManager.playerData.levels[index - 1] if index > 0 else {}) + ".", "MutedLabel")
	if def:
		if def.blurb != "": paragraph(def.blurb)
		var grammar: String = Levels.GRAMMAR_TEXT.get(def.grammar, "")
		if grammar != "": paragraph(grammar, "MutedLabel")
		factRow("BARRIER", def.barrier, HudTheme.RIM)
		factRow("SURFACES", def.surfaces, HudTheme.RIM)
	var beatRow = HBoxContainer.new()
	beatRow.add_theme_constant_override("separation", 8)
	var beatLabel = Label.new()
	beatLabel.text = "BEATEN"
	beatLabel.theme_type_variation = "MutedLabel"
	beatRow.add_child(beatLabel)
	for mode in MODE_ORDER:
		if not Root.isModeAvailable(mode): continue
		var beaten = level.gamemodeBeat.get(mode, false)
		var c = chip(Root.gameModeDescription[mode].name, HudTheme.GOLD if beaten else HudTheme.MUTED)
		if not beaten: c.modulate.a = 0.55
		beatRow.add_child(c)
	detail.add_child(beatRow)
	if def == null: return
	var stats := levelStats(def)
	statTable([
		["Clock", "%d:%02d" % [floori(stats.seconds / 60.0), int(stats.seconds) % 60]],
		["Goons", "one every %.1f s at first" % stats.spawn, clampf(6.0 / maxf(stats.spawn, 0.5) * 16.0, 0.0, 100.0)],
		["Giants", "%d%% at first, rising" % clampi(stats.giants, 0, 100), clampf(stats.giants, 0.0, 100.0)],
	])
	var label = Label.new()
	label.text = "WHO HOLDS THE LAND"
	label.theme_type_variation = "MutedLabel"
	detail.add_child(label)
	var road = FactionRoad.new()
	road.band = def.factionBand
	road.custom_minimum_size = Vector2(0, 58)
	detail.add_child(road)
	var rows = []
	for f in factionsOn(def):
		var names = LevelRoster.rosterFor(def, f).map(func(id): return Goons.DATA[id].name if isDiscovered(id) else "???")
		rows.push_back([Goons.factionName(f), ", ".join(names)])
	statTable(rows)

## The level's clock and starting spawn tuning, as levelRoot copies them from the def
static func levelStats(def: LevelDef) -> Dictionary:
	return {"seconds": float(def.seconds), "spawn": def.spawnTimer, "giants": def.giantOdds}

## The factions that can hold land on the level: those its faction band reaches (the band clamps the jittered score)
static func factionsOn(def: LevelDef) -> Array:
	var out := []
	var low := LevelRoster.factionForScore(minf(def.factionBand.x, def.factionBand.y))
	var high := LevelRoster.factionForScore(LevelRoster.bandTop(def.factionBand))
	for f in range(low, high + 1):
		var source := LevelRoster.rosterFaction(def, f)
		if source == f: out.push_back(f)
		elif not source in out: out.push_back(source)
	return out

#---------- pickups ----------

#Every pickup in Pickups.DATA, by kind, in its unlock tree's order (Unlocks.treeOrder). An open pickup shows
#in full; one whose parent is open shows its picture dimmed with its price or condition; the rest are "???".
func buildPickups() -> void:
	var ids := Pickups.DATA.keys()
	progressLabel.text = "PICKUPS  %d / %d" % [ids.filter(Unlocks.isPickupOpen).size(), ids.size()]
	var legend = Label.new()
	legend.text = "Starters sit at the top of each tree. A solid line leads to a pickup you can unlock now, a dashed one to a ??? behind a locked pickup; a pickup with no line below it is the end of its branch."
	legend.theme_type_variation = "MutedLabel"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size.x = 200
	list.add_child(legend)
	section("PRIZE GAMES", "What gift boxes hold. A box rolls among the games you've unlocked.", HudTheme.GOLD)
	buildPrizeLadder()
	for kind in Pickups.KIND_ORDER:
		section(Pickups.KIND_NAMES[kind].to_upper(), Pickups.KIND_NOTES[kind], Pickups.rarityColor(kind % 5))
		buildPickupTree(kind)

#---------- prize games ----------
#The gift box games (CrushPrizes.GAMES), weakest first, as a ladder that opens in order. They are bought
#here like pickups ("prize:<id>" through Unlocks).
const PRIZE_TEXT := {
	"claw": "Steer the claw over the prize pile and drop it. One grab is free; run coins buy more.",
	"scratch": "Three cells scratch open one by one. Two alike pay once, three alike pay three times.",
	"wheel": "Drive the spin: the wedge under the pointer pays out, or busts.",
	"deal": "Three cards face up. Take one, raise the hand with run coins, or pay a gem for a new one.",
	"slot": "Three reels of prizes, with bets and paylines. A spin can pay three things.",
	"vault": "Five sealed boxes of Rare or better. Open two of them, or three from a Diamond box.",
}

func buildPrizeLadder() -> void:
	var count := CrushPrizes.GAMES.size()
	var colWidth := minf(TREE_WIDTH / count, 150.0)
	var left := (TREE_WIDTH - colWidth * count) / 2.0
	var ladder = Control.new()
	ladder.custom_minimum_size = Vector2(TREE_WIDTH, TREE_TILE.y + 6.0)
	ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(ladder)
	var edges := []
	for i in count:
		var id: String = CrushPrizes.GAMES[i].id
		var key := CrushPrizes.uid(id)
		var state := CrushPrizes.state(id)
		var b = tile(ladder, {"kind": "prize", "key": key, "inset": 10.0}, CrushPrizes.texture(id), CrushPrizes.gameName(id), TREE_TILE, false)
		b.position = Vector2(left + i * colWidth + (colWidth - TREE_TILE.x) / 2.0, 0)
		b.size = TREE_TILE
		b.get_node("caption").add_theme_font_size_override("font_size", 13)
		if state != Unlocks.S.OPEN:
			b.get_node("art").modulate = Color(0.45, 0.42, 0.4, 0.9)
			addTileTag(b, [CrushPrizes.price(id)], HudTheme.GOLD if state == Unlocks.S.READY && Unlocks.canAfford(key) else HudTheme.MUTED)
		b.pressed.connect(onPrizeTilePressed.bind(id))
		if i > 0:
			var y := TREE_TILE.y / 2.0
			var color: Color = TREE_LINE_OPEN if state == Unlocks.S.OPEN else (TREE_LINE_NEXT if state == Unlocks.S.READY else TREE_LINE_HIDDEN)
			edges.push_back([Vector2(b.position.x - (colWidth - TREE_TILE.x), y), Vector2(b.position.x, y), color, state == Unlocks.S.SHOWN])
	ladder.draw.connect(drawTreeEdges.bind(ladder, edges))

func onPrizeTilePressed(id: String) -> void:
	if isPickingClick(CrushPrizes.uid(id)): return
	buyPrize(id)

func buyPrize(id: String) -> void:
	var key := CrushPrizes.uid(id)
	var b := tileFor(key)
	if CrushPrizes.isOpen(id): return
	if not Unlocks.buy(key):
		if b: Juice.shake(b)
		return
	purchased()
	var scroll := listScroll.scroll_vertical
	setTab(Tab.PICKUPS)
	listScroll.scroll_vertical = scroll
	b = tileFor(key)
	if b:
		b.grab_focus()
		Juice.flash(b, HudTheme.GOLD, 0.6, 18)
		Juice.pop(b, 1.08, 0.4)

func prizeDetail(entry: Dictionary) -> void:
	var id: String = str(entry.key).trim_prefix("prize:")
	var state := CrushPrizes.state(id)
	var rank := CrushPrizes.rank(id)
	var panel = showcase(260.0, HudTheme.GOLD if state == Unlocks.S.OPEN else HudTheme.MUTED)
	var picture = heroPicture(panel, CrushPrizes.texture(id), TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 64.0)
	if state != Unlocks.S.OPEN: picture.modulate = Color(0.6, 0.57, 0.55)
	titleRow(CrushPrizes.gameName(id).to_upper(), [["PRIZE GAME %d / %d" % [rank + 1, CrushPrizes.GAMES.size()], HudTheme.GOLD], ["OPEN" if state == Unlocks.S.OPEN else "LOCKED", HudTheme.OK if state == Unlocks.S.OPEN else HudTheme.MUTED]])
	paragraph(PRIZE_TEXT.get(id, ""))
	if state == Unlocks.S.READY: unlockButton(CrushPrizes.price(id), buyPrize.bind(id))
	else:
		if state == Unlocks.S.SHOWN: paragraph("Unlock %s first: the games open weakest first." % CrushPrizes.gameName(CrushPrizes.GAMES[rank - 1].id), "MutedLabel")
		endShowcase()
	tipRow("Crushing goons earns crush XP toward a gift box. Each box holds one game you have unlocked; higher boxes favour the stronger games.")

const TREE_TILE := Vector2(100, 108)
const TREE_ROW := 146.0 #from one depth of a tree to the next
const TREE_WIDTH := 660.0
const TREE_LINE_OPEN := Color(1.0, 0.761, 0.239) #to an unlocked pickup
const TREE_LINE_NEXT := Color(0.902, 0.863, 0.796, 0.9) #to one you can unlock or work toward now
const TREE_LINE_HIDDEN := Color(0.5, 0.46, 0.42, 0.55) #to a ??? behind a locked pickup

## One kind's unlock tree: roots on the top row, each pickup's children on the row below it, spread over the
## columns its leaves take, and lines from each pickup down to its children (Unlocks.children).
func buildPickupTree(kind: int) -> void:
	var order := Unlocks.treeOrder(kind)
	var spots := {} #id -> Vector2(column, depth)
	var columns := [0]
	for id in order:
		if Pickups.DATA[id].get("parent", "") == "": placeTreeNode(id, 0, spots, columns)
	var depth := 0
	for id in spots: depth = maxi(depth, int(spots[id].y))
	var count := float(columns[0])
	var colWidth := minf(TREE_WIDTH / maxf(count, 1.0), 150.0)
	var left := (TREE_WIDTH - colWidth * count) / 2.0
	var tree = Control.new()
	tree.custom_minimum_size = Vector2(TREE_WIDTH, depth * TREE_ROW + TREE_TILE.y + 6.0)
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(tree)
	var at := {}
	for id in order: #in tree order, so Tab and the harnesses meet them root first
		at[id] = Vector2(left + spots[id].x * colWidth + (colWidth - TREE_TILE.x) / 2.0, spots[id].y * TREE_ROW)
		var b := pickupTile(tree, id, TREE_TILE)
		b.position = at[id]
		b.size = TREE_TILE
	var edges := []
	for id in order:
		var parent: String = Pickups.DATA[id].get("parent", "")
		if parent == "" || not at.has(parent): continue
		var state := Unlocks.state("pickup:" + id)
		var color: Color = TREE_LINE_OPEN if state == Unlocks.S.OPEN else (TREE_LINE_HIDDEN if state == Unlocks.S.HIDDEN else TREE_LINE_NEXT)
		edges.push_back([at[parent] + Vector2(TREE_TILE.x / 2.0, TREE_TILE.y), at[id] + Vector2(TREE_TILE.x / 2.0, 0.0), color, state == Unlocks.S.HIDDEN])
	tree.draw.connect(drawTreeEdges.bind(tree, edges))

## Leaves take the next free column; a parent sits over the middle of its children
static func placeTreeNode(id: String, depth: int, spots: Dictionary, columns: Array) -> void:
	var kids := Unlocks.children(id)
	if kids.is_empty():
		spots[id] = Vector2(columns[0], depth)
		columns[0] += 1
		return
	for kid in kids: placeTreeNode(kid, depth + 1, spots, columns)
	spots[id] = Vector2((spots[kids[0]].x + spots[kids[-1]].x) / 2.0, depth)

## Elbow lines from each parent's bottom to its children's tops; dashed toward a ??? (behind the tiles)
static func drawTreeEdges(tree: Control, edges: Array) -> void:
	for e in edges:
		var from: Vector2 = e[0]
		var to: Vector2 = e[1]
		var mid := (from.y + to.y) / 2.0
		var points := [from, Vector2(from.x, mid), Vector2(to.x, mid), to]
		for i in 3:
			if e[3]: tree.draw_dashed_line(points[i], points[i + 1], e[2], 2.0, 7.0)
			else: tree.draw_line(points[i], points[i + 1], e[2], 3.0, true)

## A pickup's tile in its tree: its picture and name, dimmed while locked, "???" while hidden, its price or
## PLAY in the corner
func pickupTile(parent: Control, id: String, tileSize: Vector2) -> Button:
	var state := Unlocks.state("pickup:" + id)
	var b = tile(parent, {"kind": "pickup", "key": id, "inset": 10.0}, Pickups.texture(id), Pickups.displayName(id) if state != Unlocks.S.HIDDEN else "???", tileSize, state == Unlocks.S.HIDDEN)
	b.get_node("caption").add_theme_font_size_override("font_size", 13)
	if state == Unlocks.S.SHOWN || state == Unlocks.S.READY: b.get_node("art").modulate = Color(0.45, 0.42, 0.4, 0.9) #a preview, still locked
	var tag := pickupTag(id, state)
	if not tag.is_empty(): addTileTag(b, tag, HudTheme.GOLD if state == Unlocks.S.READY && Unlocks.canAfford("pickup:" + id) else HudTheme.MUTED)
	b.pressed.connect(onPickupTilePressed.bind(id))
	return b

## The corner tag on a locked pickup's tile, as symbol parts (MenuTheme.symbolRow): its price, PLAY (a play
## condition) or FULL GAME (the demo's cap); [] for none
static func pickupTag(id: String, state: int) -> Array:
	if state == Unlocks.S.OPEN || state == Unlocks.S.HIDDEN: return []
	if Root.IS_DEMO && Pickups.rarity(id) > Unlocks.DEMO_MAX_RARITY: return ["FULL GAME"]
	var cost := Unlocks.pickupPrice(id)
	return ["PLAY"] if cost.is_empty() else [cost]

## A tag in a tile's top right corner: a price as numbers and symbols, or a word
static func addTileTag(b: Button, parts: Array, color: Color) -> void:
	var flat := []
	for part in parts: #prices in short numbers, so a dear one still fits the corner
		if part is Dictionary: flat.append_array(MenuTheme.costParts(part, true))
		else: flat.push_back(part)
	var tag := MenuTheme.symbolRow(flat, 13, color)
	tag.name = "tag"
	tag.add_theme_constant_override("separation", 2)
	tag.alignment = BoxContainer.ALIGNMENT_END
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -b.custom_minimum_size.x + 6
	tag.offset_right = -6
	tag.offset_top = 3
	tag.offset_bottom = 21
	b.add_child(tag)

## Accept on a pickup tile buys it. A click that only just focused the tile (the same press) just shows it,
## so browsing with the mouse never buys; a second click, or the card's BUY button, does.
func onPickupTilePressed(id: String) -> void:
	if isPickingClick(id): return
	buyPickup(id)

## Is this press the mouse click that picked tile `key` (it had no focus when the button went down)?
func isPickingClick(key) -> bool:
	return Time.get_ticks_msec() - mouseDownMsec < 1000 && not sameKey(mouseDownOn, key)

var mouseDownMsec := -100000 #the last left mouse press, and the tile that had focus then (onPickupTilePressed)
var mouseDownOn = null

## Buys a pickup when it is ready and paid for, else shakes its tile
func buyPickup(id: String) -> void:
	var b := tileFor(id)
	if Unlocks.isPickupOpen(id) || not is_instance_valid(b): return
	if not Unlocks.buy("pickup:" + id):
		Juice.shake(b)
		return
	Audio.play(BUY_SOUND)
	SaveManager.flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()
	var scroll := listScroll.scroll_vertical
	setTab(Tab.PICKUPS) #children may have come into view
	listScroll.scroll_vertical = scroll
	b = tileFor(id)
	if is_instance_valid(b):
		b.grab_focus()
		Juice.flash(b, HudTheme.GOLD, 0.6, 18)
		Juice.pop(b, 1.08, 0.4)

func tileFor(key) -> Button:
	for b in tiles:
		if is_instance_valid(b) && b.has_meta("key") && sameKey(b.get_meta("key"), key): return b
	return null

## Tile keys are pickup ids (String) or car indices (int); == between the two is an error
static func sameKey(a, b) -> bool:
	return typeof(a) == typeof(b) && a == b

static func pickupKnown(id: String) -> bool:
	return Unlocks.isPickupOpen(id) || Pickups.isDiscovered(id)

## A pickup's share of goon drops in `mode` (a Root.gameModes value; -1: the selected mode), before
## Dice, faction and the pity counter, counting night-only pickups as if it were night.
static func dropShare(id: String, mode := -1) -> float:
	if mode < 0: mode = SaveManager.playerData.gameMode if SaveManager.playerData else 0
	var d := Pickups.def(id)
	if d.get("w", 0) <= 0 || not Pickups.allowedIn(id, mode) || not Unlocks.isPickupOpen(id): return 0.0
	var tiers := Pickups.tierWeights(0.0)
	var tierTotal := 0.0
	for t in tiers.size():
		if not Pickups.candidates(t, mode, true).is_empty(): tierTotal += tiers[t]
	var inTier := Pickups.candidates(d.rarity, mode, true)
	var total := 0.0
	for k in inTier: total += inTier[k]
	if total <= 0.0 || tierTotal <= 0.0: return 0.0
	return tiers[d.rarity] / tierTotal * inTier[id] / total * 100.0

func pickupDetail(entry: Dictionary) -> void:
	var id: String = entry.key
	var d := Pickups.def(id)
	var state := Unlocks.state("pickup:" + id)
	var r := Pickups.rarity(id)
	var panel = showcase(260.0, Pickups.rarityColor(r) if state != Unlocks.S.HIDDEN else HudTheme.MUTED)
	var picture = heroPicture(panel, Pickups.texture(id), TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 64.0)
	if state == Unlocks.S.HIDDEN: picture.modulate = SHADOW
	elif state != Unlocks.S.OPEN: picture.modulate = Color(0.6, 0.57, 0.55)
	var chips := [[Pickups.RARITY_NAMES[r].to_upper(), Pickups.rarityColor(r)], [Pickups.KIND_NAMES[d.kind].to_upper(), HudTheme.SKY]]
	if state != Unlocks.S.OPEN: chips.push_back(["LOCKED", HudTheme.MUTED])
	titleRow(Pickups.displayName(id).to_upper() if state != Unlocks.S.HIDDEN else "???", chips)
	if state == Unlocks.S.HIDDEN:
		paragraph("Unlock %s first to see what this is." % Pickups.displayName(d.get("parent", "")), "MutedLabel")
		return
	paragraph(d.get("text", ""))
	if state != Unlocks.S.OPEN:
		unlockRows(id)
		return
	var next := Unlocks.children(id).filter(func(c): return not Unlocks.isPickupOpen(c))
	if not next.is_empty(): paragraph("Unlocks: " + ", ".join(next.map(Pickups.displayName)), "MutedLabel")
	if d.get("stat", false):
		paragraph("Run pickups stack up to %d per stat. Upgrades bought in the garage stay for good." % OverheadCarBody2D.STAT_CAP, "MutedLabel")
	endShowcase()
	var rows = []
	var share = dropShare(id)
	if share > 0.0: rows.push_back(["Share of drops", "%.1f%%" % share if share >= 0.1 else "%.2f%%" % share, minf(share * 4.0, 100.0)])
	if d.has("secs") && (d.kind == Pickups.K.BOOST || id == "nitro"): rows.push_back(["Lasts", "%d s" % d.secs])
	if d.has("charges"): rows.push_back(["Uses", str(d.charges)])
	if d.has("modes"): rows.push_back(["Modes", ", ".join(d.modes.map(func(m): return Root.gameModeDescription[m].name))])
	if d.get("night", false): rows.push_back(["When", "Night only"])
	var factions: Dictionary = d.get("fac", {})
	if not factions.is_empty(): rows.push_back(["More from", ", ".join(factions.keys().map(func(f): return Goons.factionName(f)))])
	if not rows.is_empty(): statTable(rows)
	match d.kind:
		Pickups.K.GADGET: tipRow("Gadgets wait in the slot above the systems strip. Press %s to fire one. A rarer gadget replaces the one you hold; a commoner one is sold for coins." % InputGlyphs.label("UseItem"))
		Pickups.K.MOVE: tipRow("Boosts wait in their own slot, beside the gadget. Press %s to fire one. A rarer boost replaces the one you hold; a commoner one is sold for coins." % InputGlyphs.label("UseMove"))
		Pickups.K.BOOST: tipRow("Up to four power-ups run at once; their rings drain above the systems strip.")
		_: tipRow("A crushed goon drops a pickup about %d%% of the time, plus about half a percent per point of Clover. Dice makes the drop rarer." % roundi(10.0 / 201.0 * 100.0))

## A locked pickup's way in: its price and a BUY button, or its play condition with a progress bar
func unlockRows(id: String) -> void:
	var uid := "pickup:" + id
	if Root.IS_DEMO && Pickups.rarity(id) > Unlocks.DEMO_MAX_RARITY:
		paragraph("In the full game.", "MutedLabel")
		endShowcase()
		return
	var cost := Unlocks.pickupPrice(id)
	if not cost.is_empty(): unlockButton(cost, buyPickup.bind(id))
	else:
		var p := Unlocks.progress(uid)
		if p.is_empty(): paragraph("Opens at the end of your next run.")
		else:
			paragraph("Opens by play: %s." % p.text)
			statTable([["Progress", "%d / %d" % [p.have, p.need], 100.0 * clampf(float(p.have) / maxf(p.need, 1.0), 0.0, 1.0)]])
	endShowcase()
	var next := Unlocks.children(id)
	if not next.is_empty(): paragraph("Leads to: " + ", ".join(next.map(func(c): return Pickups.displayName(c) if Unlocks.state("pickup:" + c) != Unlocks.S.HIDDEN else "???")), "MutedLabel")

#---------- modes ----------

const MODE_ORDER := [Root.gameModes.GOONCRUSHER, Root.gameModes.SPRINT, Root.gameModes.GOONPOCALYPSE, Root.gameModes.MARATHON, Root.gameModes.DEFENSE]

func buildModes() -> void:
	var available = MODE_ORDER.filter(func(m): return Root.isModeAvailable(m)).size()
	progressLabel.text = "MODES  %d" % available
	section("MODES", "unlocked one level at a time")
	var g = grid(3)
	for mode in MODE_ORDER:
		var open = Root.isModeAvailable(mode)
		tile(g, {"kind": "mode", "key": mode, "inset": 34.0}, HudTheme.MODE_ICONS[mode] if open else HudTheme.LOCK_ICON, Root.gameModeDescription[mode].name, Vector2(216, 150), false)

func modeDetail(entry: Dictionary) -> void:
	var mode: int = entry.key
	var open = Root.isModeAvailable(mode)
	var panel = showcase(220.0, HudTheme.GOLD if open else HudTheme.MUTED)
	heroPicture(panel, HudTheme.MODE_ICONS[mode] if open else HudTheme.LOCK_ICON, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 50.0)
	var reason = Root.modeLockReason({"unlocked": true}, mode) if not open else ""
	titleRow(Root.gameModeDescription[mode].name, [[reason.to_upper(), HudTheme.MUTED]] if reason != "" else [])
	paragraph(Root.gameModeDescription[mode].description)
	endShowcase()
	paragraph(MODE_RULES.get(mode, ""))
	if Root.isModeAvailable(mode):
		tipRow("Stars from waves survived and Star Fragments raise the coins a run pays.")
		var levels = SaveManager.playerData.levels
		var beaten = levels.filter(func(l): return l.gamemodeBeat.get(mode, false)).size()
		paragraph(MODE_UNLOCK.get(mode, ""), "MutedLabel")
		statTable([["Beaten on", "%d / %d levels" % [beaten, levels.size()], beaten * 100.0 / maxf(levels.size(), 1)]])

#---------- systems ----------

func buildSystems() -> void:
	progressLabel.text = "CAR SYSTEMS  %d" % SYSTEMS.size()
	section("YOUR CAR", "what goons and walls break")
	var g = grid(3)
	for s in SYSTEMS:
		tile(g, {"kind": "system", "key": s[0], "inset": 30.0}, s[1], SYSTEM_NAMES[s[0]], Vector2(216, 150))

#goons whose attack wears `system` (attacks without a "sys" wear the hull)
static func attacks(d: Dictionary, system: String) -> bool:
	return d.rank > 0 && d.get("sys", "hull") == system && (d.has("sys") || d.has("dmg"))

func systemDetail(entry: Dictionary) -> void:
	var system: String = entry.key
	var s = SYSTEMS.filter(func(x): return x[0] == system)[0]
	var panel = showcase(220.0, HudTheme.RIM)
	heroPicture(panel, s[1], TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 50.0)
	titleRow(SYSTEM_NAMES[system].to_upper())
	paragraph(s[2])
	endShowcase()
	if OverheadCarBody2D.CONDITION_FLOOR.has(system):
		paragraph("At 0%% it still keeps %d%% of your %s." % [roundi(OverheadCarBody2D.CONDITION_FLOOR[system] * 100.0), SYSTEM_STAT_NAMES.get(system, system)], "MutedLabel")
		tipRow("Wall hits wear the side that hit. A Wrench, a Toolbox or the system's own part repairs it on the road; the gas station repairs everything in modes where it isn't the finish.")
	var attackers = Goons.DATA.keys().filter(func(id): return attacks(Goons.DATA[id], system))
	var known = attackers.filter(isDiscovered).map(func(id): return Goons.DATA[id].name)
	var hidden = attackers.size() - known.size()
	var line = ", ".join(known) if not known.is_empty() else ""
	if hidden > 0: line += (" and " if line != "" else "") + "%d you haven't met" % hidden
	if line != "": statTable([["Goons that hit it", line]])

#---------- input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
		var focused := get_viewport().gui_get_focus_owner()
		mouseDownMsec = Time.get_ticks_msec()
		mouseDownOn = focused.get_meta("key") if focused != null && focused.has_meta("key") else null
	if Settings.menu_open || not event.is_pressed() || event.is_echo(): return
	var handled := true
	if event.is_action_pressed("ui_cancel") || event.is_action_pressed("ui_codex"): closePage()
	elif event.is_action_pressed("ui_tab_prev"): setTab(tab - 1)
	elif event.is_action_pressed("ui_tab_next"): setTab(tab + 1)
	elif InputGlyphs.digit(event) > 0 && InputGlyphs.digit(event) <= TAB_NAMES.size(): setTab(InputGlyphs.digit(event) - 1)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func closePage() -> void:
	if is_queued_for_deletion(): return
	closed.emit()
	queue_free()

#---------- drawing ----------

#a goon's baked flipbook, zoomed to the goon itself (its idle frame's visible pixels) rather than the padded
#frame: it walks, winds up, attacks, does its special and idles, then repeats. Silhouetted until discovered.
class GoonPreview extends Control:
	const FILL := 0.74 #of the panel the idle goon fills; attacks and specials reach past it
	const MAX_ZOOM := 4.0 #screen px per game px, so small goons aren't blown up past their baked detail
	const SEQUENCE := [[&"walk", 2.4], [&"windup", 0.0], [&"attack", 0.0], [&"special", 1.6], [&"idle", 1.4]] #0 = play once
	var frames: SpriteFrames
	var still: Texture2D
	var silhouette := false
	var step := 0
	var frame := 0
	var frameTime := 0.0
	var animTime := 0.0

	func setFrames(value: SpriteFrames) -> void:
		frames = value
		step = 0
		frame = 0
		queue_redraw()

	func _process(delta: float) -> void:
		if frames == null: return
		var anim: StringName = SEQUENCE[step][0]
		if not frames.has_animation(anim) || frames.get_frame_count(anim) == 0:
			step = (step + 1) % SEQUENCE.size()
			return
		var count = frames.get_frame_count(anim)
		var fps = maxf(frames.get_animation_speed(anim), 1.0)
		var length: float = SEQUENCE[step][1] if SEQUENCE[step][1] > 0.0 else count / fps
		frameTime += delta
		animTime += delta
		if frameTime >= 1.0 / fps:
			frameTime = 0.0
			frame = (frame + 1) % count if SEQUENCE[step][1] > 0.0 else mini(frame + 1, count - 1)
			queue_redraw()
		if animTime >= length:
			animTime = 0.0
			frame = 0
			step = (step + 1) % SEQUENCE.size()
			queue_redraw()

	func _draw() -> void:
		var texture = still
		if frames:
			var anim: StringName = SEQUENCE[step][0]
			if frames.has_animation(anim) && frames.get_frame_count(anim) > 0: texture = frames.get_frame_texture(anim, mini(frame, frames.get_frame_count(anim) - 1))
		var center = size * 0.5
		if texture == null:
			HudTheme.text(self, center + Vector2(0, 16), "?", 64, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			return
		#every frame of a goon has the same size and origin, so one zoom and offset from the still holds them all
		var focus := Goonopedia.artBounds(still if still else texture)
		var zoom := minf(MAX_ZOOM / Goons.ART_RES, minf(size.x * FILL / focus.size.x, size.y * FILL / focus.size.y))
		var origin: Vector2 = center - focus.get_center() * zoom
		draw_set_transform(Vector2(center.x, center.y + focus.size.y * zoom * 0.42), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, focus.size.x * zoom * 0.48, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(texture, Rect2(origin, texture.get_size() * zoom), false, SHADOW if silhouette else Color.WHITE)

#a soft round glow in `color` behind a showcase's art
class Glow extends Control:
	static var falloff: GradientTexture2D #white fading out from the centre, tinted per glow
	var color := Color.WHITE

	func _draw() -> void:
		if falloff == null:
			var gradient = Gradient.new()
			gradient.set_color(0, Color(1, 1, 1, 0.24))
			gradient.set_color(1, Color(1, 1, 1, 0))
			falloff = GradientTexture2D.new()
			falloff.gradient = gradient
			falloff.fill = GradientTexture2D.FILL_RADIAL
			falloff.fill_from = Vector2(0.5, 0.5)
			falloff.fill_to = Vector2(1.0, 0.5)
			falloff.width = 256
			falloff.height = 256
		draw_texture_rect(falloff, Rect2(Vector2.ZERO, size), false, color)

#who holds the land along the road out from the start on one level (LevelRoster.factionScore, clamped to
#the level's faction band): each slice is coloured by the chance of each faction there, jitter included
class FactionRoad extends Control:
	const CHUNKS := 9.0
	var band := Vector2(0.0, 3.6)

	func _draw() -> void:
		var bar = Rect2(0, 4, size.x, 22)
		var slices := 90
		for i in slices:
			var chunks = (i + 0.5) / slices * CHUNKS
			var score = chunks * Goons.DISTANCE_WEIGHT #the band clamps the jittered score
			var j = Goons.FACTION_JITTER
			var wild = 1.0 if band.y <= Goons.WILD_BELOW else (0.0 if band.x >= Goons.WILD_BELOW else clampf((Goons.WILD_BELOW - score + j) / (2.0 * j), 0.0, 1.0))
			var scrap = 1.0 if band.x >= Goons.TRIBE_BELOW else (0.0 if band.y <= Goons.TRIBE_BELOW else clampf((score - Goons.TRIBE_BELOW + j) / (2.0 * j), 0.0, 1.0))
			var tribe = maxf(0.0, 1.0 - wild - scrap)
			var color = FACTION_COLORS[0] * wild + FACTION_COLORS[1] * tribe + FACTION_COLORS[2] * scrap
			color.a = 1.0
			var w = size.x / slices
			draw_rect(Rect2(bar.position.x + i * w, bar.position.y, w + 0.5, bar.size.y), color)
		draw_rect(bar, Color(0, 0, 0, 0.6), false, 2.0)
		HudTheme.text(self, Vector2(0, 50), "START", 15, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 4)
		HudTheme.text(self, Vector2(size.x, 50), "FAR OUT", 15, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		var names = Goons.FACTION_NAMES.map(func(n): return n.to_upper())
		var total := 0.0
		for name in names: total += HudTheme.textWidth(name, 14) + 30.0
		var x = (size.x - total) * 0.5
		for f in names.size():
			draw_rect(Rect2(x, 38, 10, 10), FACTION_COLORS[f])
			HudTheme.text(self, Vector2(x + 15, 50), names[f], 14, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 4)
			x += HudTheme.textWidth(names[f], 14) + 30.0
