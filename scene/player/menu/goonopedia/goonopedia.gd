class_name Goonopedia extends CodexPage

#The Goonopedia (docs/UI.md): the goons and their achievements, opened from the main menu's book button or
#B / L3. A tab per faction on the shared page frame (CodexPage); pickups are unlocked on their own screen
#(PickupShop), cars live in the garage (its driver focus, DriverBench) and levels and modes are described
#in run setup (main2: the road map's level panel and Level Options, which use regionRows). The entries and
#their numbers come from the game's own tables (Goons.DATA), so new goons show up by
#themselves; only the plain-language text is written here. A goon's DATA can carry "blurb" and "tip" strings to replace the text its verb gives it.
#Goons show as silhouettes until the player crushes one (PlayerData.goonsCrushed, credited by gameSummary).
#Each goon has an achievement with three tiers (Achievements); a tier's reward is claimed here: Accept on the
#goon's tile (a second click, or the card's button), or CLAIM ALL. Badges count what waits on each tab.

const REVEAL_ALL := false #true shows every goon without crushing one first
const ICON := preload("res://texture/icon/goonopedia.svg")
const CLAIM_ALL_ACTION := "ui_upgrade"
const PIP_SIZE := Vector2(14, 6) #a tile's three tier marks
const PIP_UNEARNED := Color(0.25, 0.22, 0.2)

#---------- text ----------

const RANK_NAMES := {0: "SPAWN", 1: "FODDER", 2: "SPECIAL", 3: "HEAVY"}
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
	&"rider": ["Drives like a car.", "Head-on it's armored. T-bone it."],
}
#Scrap Gang riders: act -> what it does
const ACT_TEXT := {
	"ram": "Lines up and rams you.", "swipe": "Pulls alongside and swipes at you.", "tailgate": "Tailgates you and shoves you from behind.",
	"burn": "Leaves a trail of fire behind it.", "oil": "Drops oil slicks behind it.", "harpoon": "Fires a harpoon that hooks your car.",
	"bomb": "Lobs bombs where you're about to be.", "boost": "Rockets straight at you and explodes.", "saw": "Weaves in close with a buzzsaw.",
	"shoot": "Keeps its distance and shoots along an aim line.", "magnet": "Drags your car toward it with a magnet.",
}
#DATA flags -> a line under the behavior
const TRAIT_TEXT := {
	"night": "Sleeps by day. At night it keeps out of your headlights.", "wander": "Ignores you until you get close.",
	"shield": "Carries a front shield and turns slowly.", "deathFire": "Leaves fire where it dies.",
	"log": "Lies still as a log until you pass.", "flank": "Circles round to hit you from the side.",
}

var preview: GoonPreview
var pending := {}        #resource path -> Callable(resource) to run once it has loaded on a worker thread
var badges: Array[CountBadge] = [] #one per tab: the rewards waiting there
var claimAllButton: Button

static func open(parent: Node) -> Goonopedia:
	var page = Goonopedia.new()
	parent.add_child(page)
	return page

func _init() -> void:
	title = "GOONOPEDIA"
	icon = ICON
	sellsThings = true #rewards land in the bank
	hints = [[["ui_tab_prev", "ui_tab_next"], "Faction"], [["ui_up", "ui_down"], "Browse"], [["ui_accept"], "Claim"], [[CLAIM_ALL_ACTION], "Claim all"], [["ui_cancel"], "Back"]]

#---------- tabs ----------

## One tab per faction (Goons.faction)
static func tabTitles() -> Array:
	return Goons.FACTION_NAMES.map(func(n): return n.to_upper())

func tabNames() -> Array:
	return tabTitles()

## A faction's goons, weakest rank first
static func tabGoons(index: int) -> Array:
	var ids = Goons.DATA.keys().filter(func(id): return Goons.DATA[id].faction == index)
	ids.sort_custom(func(a, b): return Goons.DATA[a].rank < Goons.DATA[b].rank if Goons.DATA[a].rank != Goons.DATA[b].rank else String(a) < String(b))
	return ids

## The first tab with a reward to claim
func startTab() -> int:
	for i in tabTitles().size():
		if Achievements.claimableCount(tabGoons(i).map(Achievements.forGoon)) > 0: return i
	return 0

## A tab opens on a goon with a reward waiting
func firstFocus() -> Button:
	for id in tabGoons(tab):
		if Achievements.claimable(Achievements.forGoon(id)) > 0 && tileFor(id): return tileFor(id)
	return super()

## The tabs with a badge each, and CLAIM ALL at the end of the row
func buildTabs() -> Control:
	var row := super()
	for i in tabButtons.size(): badges.push_back(CountBadge.on(tabButtons[i], i * 0.2))
	claimAllButton = MenuTheme.button("", PackedStringArray([CLAIM_ALL_ACTION]))
	claimAllButton.focus_mode = Control.FOCUS_NONE
	claimAllButton.custom_minimum_size = Vector2(240, 44)
	claimAllButton.pressed.connect(claimAll)
	row.add_child(claimAllButton)
	var holder = MarginContainer.new() #room above the tabs for their badges
	holder.add_theme_constant_override("margin_top", 16)
	holder.add_child(row)
	return holder

func refreshTabs() -> void:
	for i in badges.size(): badges[i].setCount(Achievements.claimableCount(tabGoons(i).map(Achievements.forGoon)))
	var waiting := Achievements.claimableCount()
	claimAllButton.disabled = waiting == 0
	MenuTheme.setButtonParts(claimAllButton, ["CLAIM ALL", waiting] if waiting > 0 else ["CLAIM ALL"], 18)

func buildTab(index: int) -> void:
	buildGoons(index)
	refreshTabs()

func drawDetail(entry: Dictionary) -> void:
	match entry.kind:
		"goon": goonDetail(entry)

func _input(event: InputEvent) -> void:
	if not Settings.menu_open && event.is_action_pressed(CLAIM_ALL_ACTION) && not event.is_echo():
		claimAll()
		get_viewport().set_input_as_handled()
		return
	super(event)

func clearDetail() -> void:
	preview = null
	super()

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

func buildGoons(f: int) -> void:
	var ids := tabGoons(f)
	section(Goons.factionName(f).to_upper(), "%d / %d found.  %s" % [ids.filter(isDiscovered).size(), ids.filter(isMeetable).size(), FACTION_TEXT[f]], FACTION_COLORS[f])
	var g = grid(5)
	for id in ids:
		var known = isDiscovered(id)
		var b = tile(g, {"kind": "goon", "key": id}, null, Goons.DATA[id].name if known else "???", Vector2(124, 124), not known)
		loadThen(goonArt(id), setGoonTileArt.bind(b))
		addTierPips(b, Achievements.forGoon(id))
		if Achievements.claimable(Achievements.forGoon(id)) > 0: PickupShop.addTileTag(b, ["CLAIM"], HudTheme.GOLD)
		elif not known && not isMeetable(id): PickupShop.addTileTag(b, ["FULL GAME"], HudTheme.MUTED)
		b.pressed.connect(onGoonTilePressed.bind(id))
	progressLabel.text = "GOONS FOUND  %d / %d" % [Goons.DATA.keys().filter(isDiscovered).size(), Goons.DATA.keys().filter(isMeetable).size()]

## Three marks in a tile's top left corner, one per tier: gold once claimed, white while its reward waits
static func addTierPips(b: Button, id: String) -> void:
	var row = HBoxContainer.new()
	row.name = "pips"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.position = Vector2(7, 7)
	for tier in Achievements.TIER_NAMES.size():
		var pip = ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = HudTheme.GOLD if tier < Achievements.claimed(id) else (Color.WHITE if tier < Achievements.earned(id) else PIP_UNEARNED)
		row.add_child(pip)
	b.add_child(row)

#---------- claiming ----------

## Accept on a goon's tile claims its reward. A click that only just focused the tile just shows it.
func onGoonTilePressed(id: StringName) -> void:
	if isPickingClick(id): return
	claimGoon(id)

## Claims a goon's waiting tiers, else shakes its tile
func claimGoon(id: StringName) -> void:
	if Achievements.claim(Achievements.forGoon(id)).is_empty():
		if tileFor(id): Juice.shake(tileFor(id))
		return
	claimedSomething(id)

func claimAll() -> void:
	if Achievements.claimAll().is_empty(): return
	var focused := get_viewport().gui_get_focus_owner()
	claimedSomething(focused.get_meta("key") if focused != null && focused.has_meta("key") else null)

## After a claim: the sound, the save, the garage behind the page, and the tab redrawn with `key`'s tile lit
func claimedSomething(key) -> void:
	Audio.play(PickupShop.BUY_SOUND)
	SaveManager.flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()
	var scroll := listScroll.scroll_vertical
	setTab(tab)
	listScroll.scroll_vertical = scroll
	var b := tileFor(key)
	if b == null: return
	b.grab_focus()
	Juice.flash(b, HudTheme.GOLD, 0.6, 18)
	Juice.pop(b, 1.08, 0.4)

## A goon's three tiers on its card: the goal, how far along, the reward, and CLAIM when one waits
func tierRows(goon: StringName) -> void:
	var id := Achievements.forGoon(goon)
	var count := Achievements.progress(id)
	var goals := Achievements.goals(id)
	var table = GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 6)
	for tier in goals.size():
		var done: bool = tier < Achievements.claimed(id)
		var ready: bool = not done && tier < Achievements.earned(id)
		var color: Color = HudTheme.GOLD if done || ready else HudTheme.MUTED
		table.add_child(chip(Achievements.TIER_NAMES[tier], color))
		var bar = DriverCard.StatBar.new()
		bar.base = roundi(100.0 * clampf(float(count) / goals[tier], 0.0, 1.0))
		bar.custom_minimum_size = Vector2(barWidth, 7)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		table.add_child(bar)
		var progress = Label.new()
		progress.text = "%s / %s" % [DriverCard.formatCoins(mini(count, goals[tier])), DriverCard.formatCoins(goals[tier])]
		progress.add_theme_font_size_override("font_size", 18)
		progress.custom_minimum_size.x = 150
		table.add_child(progress)
		var pay := MenuTheme.symbolRow([Achievements.reward(id, tier), "CLAIMED" if done else ("READY" if ready else "")], 18, color)
		pay.alignment = BoxContainer.ALIGNMENT_BEGIN
		table.add_child(pay)
	into.add_child(table)
	var waiting := Achievements.pending(id)
	if waiting.is_empty(): return
	var button = MenuTheme.button("", PackedStringArray(["ui_accept"]), true)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size = Vector2(320, 58)
	MenuTheme.setButtonParts(button, ["CLAIM", waiting], 24)
	button.pressed.connect(claimGoon.bind(goon))
	into.add_child(button)

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
		if isMeetable(id): tipRow("Crush one to fill in this page.")
		return
	paragraph(behavior(d))
	tipRow(tip(d))
	endShowcase()
	tierRows(id)
	var rows = [["Speed", "%d" % d.get("speed", 110), d.get("speed", 110) / 3.2]]
	if d.has("dmg"): rows.push_back(["Hits for", str(d.dmg), d.dmg * 100.0 / 12.0])
	var crush: float = d.get("crush", 100.0)
	rows.push_back(["Crush at", Settings.speed_text(crush) + "+", crush / 5.0])
	var front: float = d.get("front", 0.0)
	if front >= 9999.0: rows.push_back(["Head-on", "Can't be crushed"])
	elif front > 0.0: rows.push_back(["Head-on", "Needs " + Settings.speed_text(front) + "+"])
	if d.has("sys"): rows.push_back(["Wears your", SYSTEM_NAMES.get(d.sys, d.sys)])
	if d.has("pack"): rows.push_back(["Comes in", "groups of %d" % d.pack])
	var classes := Goons.classesOf(id)
	if not classes.is_empty(): rows.push_back(["Plays in", ", ".join(classes.map(Goons.className))])
	rows.push_back(["You've crushed", DriverCard.formatCoins(SaveManager.playerData.goonsCrushed.get(String(id), 0))])
	statTable(rows)

## The levels whose line-up fields a goon (LevelRoster), in road order; the demo's levels only in the demo
static func levelsOf(id: StringName) -> Array:
	var out := []
	for i in (mini(Levels.count(), Root.DEMO_LEVEL_COUNT) if Root.IS_DEMO else Levels.count()):
		if id in LevelRoster.lineupFor(Levels.defAt(i)): out.push_back(Levels.defAt(i))
	return out

## The goons that burst into `id` when crushed
static func parentsOf(id: StringName) -> Array:
	return Goons.DATA.keys().filter(func(other): return Goons.DATA[other].get("split", &"") == id)

## Can this goon be met in this build? In the demo, only the goons of its levels and what they burst into.
static func isMeetable(id: StringName) -> bool:
	return not Root.IS_DEMO || not levelsOf(id).is_empty() || parentsOf(id).any(func(p): return not levelsOf(p).is_empty())

#where a goon lives, or what it comes out of
static func habitat(id: StringName) -> String:
	var levels := levelsOf(id)
	if not levels.is_empty(): return "Found in " + ", ".join(levels.map(func(def): return def.displayName))
	var parents := parentsOf(id)
	if not parents.is_empty(): return "Only appears when a %s is crushed." % " or ".join(parents.map(func(p): return Goons.DATA[p].name))
	return "In the full game." if Root.IS_DEMO else "Only turns up in special places."

static func behavior(d: Dictionary) -> String:
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

#---------- levels ----------

## Who lives on a level: its region, the region's class, the line-up (??? until met) and an elite region's
## strength step
static func regionRows(def: LevelDef) -> Array:
	var rows := [["Region", "%s  (%d of %d)" % [Territories.displayName(def.region), def.stop, Territories.STOPS]],
		["Class", Goons.className(Territories.classOf(def.region))],
		["Line-up", ", ".join(LevelRoster.lineupFor(def).map(func(id): return Goons.DATA[id].name if isDiscovered(id) else "???"))]]
	var step := Territories.step(def.region)
	var parts := []
	for key in [["speed", "faster"], ["damage", "harder hits"], ["crush", "tougher to crush"]]:
		var x := float(step.get(key[0], 1.0))
		if x > 1.0: parts.push_back("+%d%% %s" % [roundi((x - 1.0) * 100.0), key[1]])
	if not parts.is_empty(): rows.push_back(["Elite", ", ".join(parts)])
	return rows

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
		draw_texture_rect(texture, Rect2(origin, texture.get_size() * zoom), false, CodexPage.SHADOW if silhouette else Color.WHITE)
