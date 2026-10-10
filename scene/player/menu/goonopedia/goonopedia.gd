class_name Goonopedia extends CodexPage

#The Goonopedia (docs/UI.md): what's in the game, opened from the main menu's book button or B / L3.
#Tabs GOONS and SYSTEMS on the shared page frame (CodexPage); pickups are unlocked on their own screen
#(PickupShop), cars live in the garage (its driver focus, DriverBench) and levels and modes are described
#in run setup (main2: the road map's level panel and Level Options, which use regionRows). The entries and
#their numbers come from the game's own tables (Goons.DATA, the car's systems), so new goons show up by
#themselves; only the plain-language text is written here. A goon's DATA can carry "blurb" and "tip" strings to replace the text its verb gives it.
#Goons show as silhouettes until the player crushes one (PlayerData.goonsCrushed, credited by gameSummary).

enum Tab { GOONS, SYSTEMS }
const TAB_NAMES := ["GOONS", "SYSTEMS"]
const REVEAL_ALL := false #true shows every goon without crushing one first
const ICON := preload("res://texture/icon/goonopedia.svg")

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

var preview: GoonPreview
var pending := {}        #resource path -> Callable(resource) to run once it has loaded on a worker thread

static func open(parent: Node) -> Goonopedia:
	var page = Goonopedia.new()
	parent.add_child(page)
	return page

func _init() -> void:
	title = "GOONOPEDIA"
	icon = ICON

func tabNames() -> Array:
	return TAB_NAMES

func buildTab(index: int) -> void:
	match index:
		Tab.GOONS: buildGoons()
		Tab.SYSTEMS: buildSystems()

func drawDetail(entry: Dictionary) -> void:
	match entry.kind:
		"goon": goonDetail(entry)
		"system": systemDetail(entry)

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
	paragraph(behavior(d))
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
	var classes := Goons.classesOf(id)
	if not classes.is_empty(): rows.push_back(["Plays in", ", ".join(classes.map(Goons.className))])
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
