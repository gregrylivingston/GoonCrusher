class_name CodexPage extends Control

#The frame the Goonopedia and the Pickups screen share (docs/UI.md): a full-screen overlay with a header, a
#row of tabs, the tab's tiles on the left and a detail card for the focused tile on the right, and the
#helpers that fill them. A page says what its tabs are (tabNames), builds one (buildTab) and draws the
#card for a tile's entry (drawDetail).

signal closed

const SHADOW := Color(0, 0, 0, 0.88) #silhouette tint for undiscovered goons and hidden pickups

#---------- state ----------

var title := ""            #the header's name and icon
var icon: Texture2D
var listWidth := 720.0     #the tile panel; the detail card takes the rest
var barWidth := 220.0      #a stat table's bars
var sellsThings := false   #shows the bank in the header
var closeAction := "ui_codex" #the key that opened the page closes it too
var hints := [[["ui_tab_prev", "ui_tab_next"], "Tab"], [["ui_up", "ui_down"], "Browse"], [["ui_cancel"], "Back"]] #the bar along the bottom
var tab := 0
var tabButtons: Array[Button] = []
var list := VBoxContainer.new()
var listScroll := ScrollContainer.new()
var detail := VBoxContainer.new()
var into: VBoxContainer = detail #where the card helpers add rows: the detail card, or a showcase's side column
var progressLabel := Label.new()
var detailScroll := ScrollContainer.new() #the detail card's scroll
var bankRow := HBoxContainer.new() #the header's coins and gems, as symbols
var tiles: Array[Button] = []
var mouseDownMsec := -100000 #the last left mouse press, and the key of the tile that had focus then
var mouseDownOn = null
var shown = null #the entry in the detail card

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
	left.custom_minimum_size.x = listWidth
	listScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	listScroll.follow_focus = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	listScroll.add_child(list)
	left.add_child(listScroll)
	body.add_child(left)
	var right = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detailScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detailScroll.follow_focus = true #an upgrade button moved to with keys scrolls into view
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	detailScroll.add_child(detail)
	right.add_child(detailScroll)
	body.add_child(right)
	root.add_child(KeyHint.bar(hints))
	setTab(startTab())
	Juice.dropIn(self, 30.0)

func buildHeader() -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(MenuTheme.iconRect(icon, 56))
	var heading = Label.new()
	heading.text = title
	heading.theme_type_variation = "TitleLabel"
	row.add_child(heading)
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
	var names := tabNames()
	for i in names.size():
		var b = Button.new()
		b.text = "%d  %s" % [i + 1, names[i]] #number keys pick a tab, like the level posters
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
	tab = wrapi(value, 0, tabNames().size())
	for i in tabButtons.size(): tabButtons[i].set_pressed_no_signal(i == tab)
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	tiles.clear()
	shown = null
	buildTab(tab)
	listScroll.scroll_vertical = 0
	refreshBank()
	var first := firstFocus()
	if first: first.grab_focus()

#---------- what a page supplies ----------

func tabNames() -> Array:
	return []

## Fills `list` with tab `index`'s tiles
func buildTab(_index: int) -> void:
	pass

## Fills the detail card for a tile's entry
func drawDetail(_entry: Dictionary) -> void:
	pass

func startTab() -> int:
	return 0

## The tile a freshly built tab gives the focus
func firstFocus() -> Button:
	return tiles[0] if not tiles.is_empty() else null

## The bank in the header, on the tabs that sell things: "3,000 (coin)  4 (gem)"
func refreshBank() -> void:
	for child in bankRow.get_children():
		bankRow.remove_child(child)
		child.queue_free()
	if not sellsThings: return
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
		extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART #a long note wraps instead of widening the panel
		extra.custom_minimum_size.x = 200
		extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

#---------- detail card helpers ----------

func clearDetail() -> void:
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
		barHolder.custom_minimum_size = Vector2(barWidth, 24)
		if r.size() > 2 && r[2] != null:
			var bar = DriverCard.StatBar.new()
			bar.base = int(r[2])
			bar.bought = int(r[3]) if r.size() > 3 && r[3] != null else 0
			bar.position = Vector2(0, 9)
			bar.size = Vector2(barWidth, 7)
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
	drawDetail(entry)

#redraws the detail card if it's still showing `entry` (after something it shows has loaded)
func refreshIfShown(kind: String, key) -> void:
	if shown != null && shown.kind == kind && shown.key == key: showDetail(shown)

#---------- input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
		var focused := get_viewport().gui_get_focus_owner()
		mouseDownMsec = Time.get_ticks_msec()
		mouseDownOn = focused.get_meta("key") if focused != null && focused.has_meta("key") else null
	if Settings.menu_open || not event.is_pressed() || event.is_echo(): return
	var handled := true
	if event.is_action_pressed("ui_cancel") || event.is_action_pressed(closeAction): closePage()
	elif event.is_action_pressed("ui_tab_prev"): setTab(tab - 1)
	elif event.is_action_pressed("ui_tab_next"): setTab(tab + 1)
	elif InputGlyphs.digit(event) > 0 && InputGlyphs.digit(event) <= tabNames().size(): setTab(InputGlyphs.digit(event) - 1)
	else: handled = false
	if handled: get_viewport().set_input_as_handled()

func closePage() -> void:
	if is_queued_for_deletion(): return
	closed.emit()
	queue_free()

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
