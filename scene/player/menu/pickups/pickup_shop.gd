class_name PickupShop extends CodexPage

#The Pickups screen (docs/UI.md): where pickups and prize games are unlocked (Unlocks), opened from the
#garage dock's Pickups button or G / View. Seven tabs on the shared page frame (CodexPage), each holding
#one or two kinds' unlock trees side by side (TABS). The gift box games are Casino pickups (CrushPrizes.GAMES).
#An open pickup shows in full; one whose
#parent is open shows dimmed with its price or PLAY; the rest are "???". Accept on a tile (a second click,
#or the card's button) buys a ready one. It opens on the first tab with something the bank covers, on that
#tile, and every tab shows how many it has open and a badge for what can be bought now.

const TITLE := "PICKUPS"
const ICON := preload("res://texture/icon/gift.svg")
const BUY_SOUND := preload("res://sound/fx/short-success-sound-glockenspie.mp3")
const BADGE_REST := Vector2(6, -27) #a tab's badge sits above its name, not over it
## The tabs, left to right: the kinds whose trees a tab shows side by side, and a note that replaces the
## kind's own (Pickups.KIND_NOTES) where it needs one
const TABS := [
	{"name": "LOOT", "kinds": [Pickups.K.LOOT]},
	{"name": "SUPPLIES", "kinds": [Pickups.K.SUPPLY]},
	{"name": "TUNE-UPS", "kinds": [Pickups.K.TUNE]},
	{"name": "POWER-UPS", "kinds": [Pickups.K.BOOST, Pickups.K.MODE], "note": "Timed effects; their rings drain on the HUD's items row. Mode specials only drop in the mode they help."},
	{"name": "GADGETS", "kinds": [Pickups.K.GADGET, Pickups.K.MOVE], "note": "Two slots, each with its own button: one holds a gadget, the other a boost."},
	{"name": "CASINO", "kinds": [Pickups.K.CASINO], "note": "Games of chance, weakest first. Goons drop most of them, and gift boxes hold the eight prize games among them."},
	{"name": "SKILL", "kinds": [Pickups.K.SKILL]},
]
const GROUP_LABEL := 26.0 #the strip over a tab's trees that names each kind, when it shows two
const GROUP_GAP := 0.4 #columns between two kinds' trees

var badges: Array[CountBadge] = [] #one per tab: what the bank covers there

static func open(parent: Node) -> PickupShop:
	var page = PickupShop.new()
	parent.add_child(page)
	return page

func _init() -> void:
	title = TITLE
	icon = ICON
	sellsThings = true
	closeAction = "ui_pickups"
	listWidth = 960.0
	barWidth = 130.0
	hints = [[["ui_tab_prev", "ui_tab_next"], "Category"], [["ui_up", "ui_down"], "Browse"], [["ui_accept"], "Unlock"], [["ui_cancel"], "Back"]]

#---------- tabs ----------

func tabNames() -> Array:
	return TABS.map(func(t): return t.name)

static func tabCount() -> int:
	return TABS.size()

## The unlock ids on a tab ("pickup:<id>"), in tree order
static func tabUids(index: int) -> Array:
	var out := []
	for kind in TABS[index].kinds: out.append_array(Unlocks.treeOrder(kind).map(func(id): return "pickup:" + str(id)))
	return out

## The tab an unlock id is on (-1: none)
static func tabOf(uid: String) -> int:
	for i in tabCount():
		if tabUids(i).has(uid): return i
	return -1

## Ready, with a price the bank covers (what the dock's badge counts, Unlocks.buyableCount)
static func isBuyable(uid: String) -> bool:
	return Unlocks.state(uid) == Unlocks.S.READY && not Unlocks.price(uid).is_empty() && Unlocks.canAfford(uid)

static func isReady(uid: String) -> bool:
	return Unlocks.state(uid) == Unlocks.S.READY

static func isOpenNow(uid: String) -> bool:
	return Unlocks.state(uid) == Unlocks.S.OPEN

## A tile's key for an unlock id: pickups go by their plain id
static func keyOf(uid: String) -> String:
	return uid.trim_prefix("pickup:")

## The first tab with something to buy now; failing that, the first with something to work toward
func startTab() -> int:
	for i in tabCount():
		if tabUids(i).any(isBuyable): return i
	for i in tabCount():
		if tabUids(i).any(isReady): return i
	return 0

## A tab opens on what can be bought there, or on what is next
func firstFocus() -> Button:
	var uids := tabUids(tab)
	var want := uids.filter(isBuyable)
	if want.is_empty(): want = uids.filter(isReady)
	var b: Button = tileFor(keyOf(want[0])) if not want.is_empty() else null
	return b if b else super()

## A tab per tree: its starter's icon, its name over "open / all", and a badge for what the bank covers
func buildTabs() -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(KeyHint.make(PackedStringArray(["ui_tab_prev"]), "", 15, true))
	for i in tabCount():
		var b = Button.new()
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = Pickups.texture(keyOf(tabUids(i)[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_font_size_override("font_size", 17)
		for state in ["normal", "hover", "pressed", "hover_pressed"]: #two lines and an icon: less padding than a settings pill
			var box: StyleBox = theme.get_stylebox(state, "TabButton").duplicate()
			box.content_margin_left = 10
			box.content_margin_right = 8
			box.content_margin_top = 5
			box.content_margin_bottom = 5
			b.add_theme_stylebox_override(state, box)
		b.pressed.connect(setTab.bind(i))
		MenuTheme.addSounds(b)
		row.add_child(b)
		tabButtons.push_back(b)
		var badge := CountBadge.on(b, i * 0.2)
		badge.rest = BADGE_REST
		badge.offset_top = BADGE_REST.y
		badge.offset_bottom = BADGE_REST.y + CountBadge.HEIGHT
		badges.push_back(badge)
	row.add_child(KeyHint.make(PackedStringArray(["ui_tab_next"]), "", 15, true))
	var holder = MarginContainer.new() #room above the tabs for their badges
	holder.add_theme_constant_override("margin_top", 12)
	holder.add_child(row)
	return holder

func refreshTabs() -> void:
	var names := tabNames()
	for i in tabButtons.size():
		var uids := tabUids(i)
		tabButtons[i].text = "%s\n%d / %d" % [names[i], uids.filter(isOpenNow).size(), uids.size()]
		badges[i].setCount(uids.filter(isBuyable).size())

func buildTab(index: int) -> void:
	var ids := Pickups.DATA.keys()
	progressLabel.text = "%d / %d OPEN" % [ids.filter(Unlocks.isPickupOpen).size(), ids.size()]
	var entry: Dictionary = TABS[index]
	var kinds: Array = entry.kinds
	section(" & ".join(kinds.map(func(k): return Pickups.KIND_NAMES[k].to_upper())), entry.get("note", Pickups.KIND_NOTES[kinds[0]]), Pickups.rarityColor(kinds[0] % 5))
	buildPickupTree(kinds)
	refreshTabs()

func drawDetail(entry: Dictionary) -> void:
	match entry.kind:
		"pickup": pickupDetail(entry)

#---------- buying ----------

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

#---------- the trees ----------

const TREE_TILE := Vector2(112, 108)
const TREE_ROW := 146.0 #from one depth of a tree to the next
const TREE_WIDTH := 920.0
const TREE_HEIGHT := 580.0 #what a tab shows without scrolling: a deeper tree closes its rows up to fit
const TREE_LINE_OPEN := Color(1.0, 0.761, 0.239) #to an unlocked pickup
const TREE_LINE_NEXT := Color(0.902, 0.863, 0.796, 0.9) #to one you can unlock or work toward now
const TREE_LINE_HIDDEN := Color(0.5, 0.46, 0.42, 0.55) #to a ??? behind a locked pickup

## A tab's unlock trees, one kind after another: roots on the top row, each pickup's children on the row
## below it, spread over the columns its leaves take, and lines from each pickup down to its children
## (Unlocks.children). Two kinds get a name each over their columns, and tiles narrow to fit the columns.
func buildPickupTree(kinds: Array) -> void:
	var order := []
	var spots := {} #id -> Vector2(column, depth)
	var columns := [0.0]
	var spans := [] #[kind, its first column, the column after its last]
	for kind in kinds:
		if not spans.is_empty(): columns[0] += GROUP_GAP
		var first: float = columns[0]
		for id in Unlocks.treeOrder(kind):
			order.push_back(id)
			if Pickups.DATA[id].get("parent", "") == "": placeTreeNode(id, 0, spots, columns)
		spans.push_back([kind, first, columns[0]])
	for id in order: #tree order, so everything it needs is placed
		if Pickups.DATA[id].has("after"): placeJoined(id, spots)
	var depth := 0
	for id in spots: depth = maxi(depth, int(spots[id].y))
	var count: float = columns[0]
	var colWidth := minf(TREE_WIDTH / maxf(count, 1.0), 170.0)
	var tileSize := Vector2(minf(TREE_TILE.x, colWidth - 10.0), TREE_TILE.y)
	var left := (TREE_WIDTH - colWidth * count) / 2.0
	var top := GROUP_LABEL if spans.size() > 1 else 0.0
	var rowHeight := minf(TREE_ROW, (TREE_HEIGHT - top - TREE_TILE.y) / maxf(depth, 1.0))
	var tree = Control.new()
	tree.custom_minimum_size = Vector2(TREE_WIDTH, top + depth * rowHeight + TREE_TILE.y + 6.0)
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(tree)
	if spans.size() > 1:
		for span in spans:
			var label = Label.new()
			label.text = Pickups.KIND_NAMES[span[0]].to_upper()
			label.theme_type_variation = "MutedLabel"
			label.add_theme_font_size_override("font_size", 15)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.position = Vector2(left + span[1] * colWidth, 0)
			label.size = Vector2((span[2] - span[1]) * colWidth, GROUP_LABEL - 4.0)
			tree.add_child(label)
	var at := {}
	for id in order: #in tree order, so Tab and the harnesses meet them root first
		at[id] = Vector2(left + spots[id].x * colWidth + (colWidth - tileSize.x) / 2.0, top + spots[id].y * rowHeight)
		var b := pickupTile(tree, id, tileSize)
		b.position = at[id]
		b.size = tileSize
	var edges := []
	for id in order:
		var state := Unlocks.state("pickup:" + id)
		for above in Unlocks.prerequisites(id): #a line from each: dashed from one that is still locked
			if not at.has(above): continue
			var waiting: bool = state == Unlocks.S.HIDDEN || (state != Unlocks.S.OPEN && not Unlocks.isPickupOpen(above))
			var color: Color = TREE_LINE_OPEN if state == Unlocks.S.OPEN else (TREE_LINE_HIDDEN if waiting else TREE_LINE_NEXT)
			edges.push_back([at[above] + Vector2(tileSize.x / 2.0, tileSize.y), at[id] + Vector2(tileSize.x / 2.0, 0.0), color, waiting])
	tree.draw.connect(drawTreeEdges.bind(tree, edges))

## Leaves take the next free column; a parent sits over the middle of its children
static func placeTreeNode(id: String, depth: int, spots: Dictionary, columns: Array) -> void:
	var kids := Unlocks.children(id).filter(func(kid): return not Pickups.DATA[kid].has("after")) #placeJoined's
	if kids.is_empty():
		spots[id] = Vector2(columns[0], depth)
		columns[0] += 1
		return
	for kid in kids: placeTreeNode(kid, depth + 1, spots, columns)
	spots[id] = Vector2((spots[kids[0]].x + spots[kids[-1]].x) / 2.0, depth)

## A pickup that needs several others (`after`) sits a row under the lowest of them, below their middle, and
## takes no column of its own; whatever it leads to hangs under it
static func placeJoined(id: String, spots: Dictionary) -> void:
	var above := Unlocks.prerequisites(id).filter(func(p): return spots.has(p))
	if above.is_empty(): return
	var x := 0.0
	var depth := 0.0
	for p in above:
		x += spots[p].x
		depth = maxf(depth, spots[p].y)
	spots[id] = Vector2(x / above.size(), depth + 1.0)
	placeBelow(id, spots)

static func placeBelow(id: String, spots: Dictionary) -> void:
	var kids := Unlocks.children(id)
	for i in kids.size():
		spots[kids[i]] = spots[id] + Vector2(i - (kids.size() - 1) / 2.0, 1.0)
		placeBelow(kids[i], spots)

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
	if Root.IS_DEMO && not Unlocks.inDemo(id): return ["FULL GAME"]
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

## Buys a pickup when it is ready and paid for, else shakes its tile
func buyPickup(id: String) -> void:
	var b := tileFor(id)
	if Unlocks.isPickupOpen(id) || not is_instance_valid(b): return
	if not Unlocks.buy("pickup:" + id):
		Juice.shake(b)
		return
	purchased()
	var scroll := listScroll.scroll_vertical
	setTab(tab) #children may have come into view
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
	var panel = showcase(180.0, Pickups.rarityColor(r) if state != Unlocks.S.HIDDEN else HudTheme.MUTED)
	var picture = heroPicture(panel, Pickups.texture(id), TextureRect.STRETCH_KEEP_ASPECT_CENTERED, 40.0)
	if state == Unlocks.S.HIDDEN: picture.modulate = SHADOW
	elif state != Unlocks.S.OPEN: picture.modulate = Color(0.6, 0.57, 0.55)
	var chips := [[Pickups.RARITY_NAMES[r].to_upper(), Pickups.rarityColor(r)], [Pickups.KIND_NAMES[d.kind].to_upper(), HudTheme.SKY]]
	var boxed := CrushPrizes.forPickup(id) != "" #also a gift box game
	if boxed && state != Unlocks.S.HIDDEN: chips.push_back(["PRIZE GAME", HudTheme.GOLD])
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
	if boxed:
		tipRow("Gift boxes hold this game. Crushing goons earns crush XP toward a box; each box holds one game you have unlocked, and higher boxes favor the stronger games.")
		if d.get("w", 0) <= 0:
			paragraph("Only in gift boxes: goons don't drop it.", "MutedLabel")
			return
	match d.kind:
		Pickups.K.GADGET: tipRow("Gadgets wait in the slot above the systems strip. Press %s to fire one. A rarer gadget replaces the one you hold; a commoner one is sold for coins." % InputGlyphs.label("UseItem"))
		Pickups.K.MOVE: tipRow("Boosts wait in their own slot, beside the gadget. Press %s to fire one. A rarer boost replaces the one you hold; a commoner one is sold for coins." % InputGlyphs.label("UseMove"))
		Pickups.K.BOOST: tipRow("Up to four power-ups run at once; their rings drain on the HUD's items row.")
		_: tipRow("A crushed goon drops a pickup about %d%% of the time, plus about half a percent per point of Clover. Dice makes the drop rarer." % roundi(10.0 / 201.0 * 100.0))

## A locked pickup's way in: its price and a BUY button, or its play condition with a progress bar
func unlockRows(id: String) -> void:
	var uid := "pickup:" + id
	if Root.IS_DEMO && not Unlocks.inDemo(id):
		paragraph("In the full game.", "MutedLabel")
		endShowcase()
		return
	var cost := Unlocks.pickupPrice(id)
	var missing := Unlocks.missing(id)
	if not missing.is_empty(): #its parent is open, but it needs more (`after`)
		paragraph("Unlock %s first." % ", ".join(missing.map(Pickups.displayName)))
		if not cost.is_empty(): into.add_child(MenuTheme.symbolRow(["Then"] + MenuTheme.costParts(cost), 18, HudTheme.MUTED))
	elif not cost.is_empty(): unlockButton(cost, buyPickup.bind(id))
	else:
		var p := Unlocks.progress(uid)
		if p.is_empty(): paragraph("Opens at the end of your next run.")
		else:
			paragraph("Opens by play: %s." % p.text)
			statTable([["Progress", "%d / %d" % [p.have, p.need], 100.0 * clampf(float(p.have) / maxf(p.need, 1.0), 0.0, 1.0)]])
	endShowcase()
	var next := Unlocks.children(id)
	if not next.is_empty(): paragraph("Leads to: " + ", ".join(next.map(func(c): return Pickups.displayName(c) if Unlocks.state("pickup:" + c) != Unlocks.S.HIDDEN else "???")), "MutedLabel")
