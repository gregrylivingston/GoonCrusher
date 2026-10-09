class_name Levels extends RefCounted

#The level registry: the road atlas's 30 levels, five stops in each of six regions (Territories), in the
#order the menu, the save and the unlock chain use. Each id has a LevelDef at res://world/levels/<id>.tres
#and a thin scene at res://scene/level/levels/level_<id>.tscn. The demo offers the first
#Root.DEMO_LEVEL_COUNT (the first two regions). Appending is save-safe; reordering moves unlocks
#(SaveManager.migrate() matches saved entries by id, but unlocks advance by index).

const ORDER := [
	&"prairie", &"orchard", &"bayou", &"canyon", &"moosewoods",          #The Wilds
	&"mudlick", &"stilttown", &"lantern", &"sawmill", &"quarry",         #Tribe Country
	&"highway", &"ghosttown", &"saltflats", &"raiderpass", &"thunderroad", #Raider Road
	&"frostbite", &"frozenlake", &"timberline", &"tarpits", &"summit",   #Hunting Grounds
	&"city", &"manhole", &"culdesac", &"gridlock", &"blockparty",        #The Sprawl
	&"blastpits", &"tankfarm", &"slagfields", &"theline", &"crusher",    #The Works
]
const DEF_DIR := "res://world/levels/"
const SCENE_DIR := "res://scene/level/levels/"

## What each grammar means for the player, for the Goonopedia
const GRAMMAR_TEXT := {
	&"meadow": "Open meadow cut by a creek. Ford it at the shallows; the deep pools drown.",
	&"bayou": "Lakes and braided channels. Boardwalks cross the deep water.",
	&"canyon": "Canyon walls and mesas. Passes open every chunk; wash lanes run fast.",
	&"quarry": "Haul roads between the pit, the junk fort and the tyre camps. Mind the mud pits.",
	&"mountain": "Ranges with passes, frozen lakes and deep snow. Ice gives no grip.",
	&"highway": "A highway runs east. Fast asphalt, oil slicks, barriers and pile-ups.",
	&"city": "A street grid between buildings, parks, lots and canals. Bridges cross at the streets.",
	&"yard": "Scrap yard plots walled by scrap mountains, container rows and conveyor lanes.",
}

static func count() -> int:
	return ORDER.size()

## "prairie, bayou, ..." for messages
static func idsText() -> String:
	var ids := PackedStringArray()
	for id in ORDER: ids.push_back(String(id))
	return ", ".join(ids)

static func indexOf(id: StringName) -> int:
	return ORDER.find(StringName(id))

static func defPath(id: StringName) -> String:
	return DEF_DIR + String(id) + ".tres"

static func scenePath(id: StringName) -> String:
	return SCENE_DIR + "level_" + String(id) + ".tscn"

## The def for a level id, or null for an unknown id
static func get_def(id: StringName) -> LevelDef:
	if indexOf(id) < 0: return null
	return load(defPath(id)) as LevelDef

## The def at an index in ORDER, or null when out of range
static func defAt(index: int) -> LevelDef:
	if index < 0 || index >= ORDER.size(): return null
	return get_def(ORDER[index])

## The def of the level being played: a running level's own (a level launched directly), else the save's
## selected level, which the menu, playtest and bench set before a run starts
static func current() -> LevelDef:
	var level = Root.levelRoot
	if is_instance_valid(level) && level.is_inside_tree() && not level.get("hasEnded") && level.get("def") is LevelDef: return level.def
	var data = SaveManager.playerData if SaveManager else null
	return defAt(clampi(data.selectedLevel, 0, ORDER.size() - 1) if data else 0)

## A level named on a command line: its id, its scene's name or path, or its index in ORDER (0-based).
## &"" when it names no level.
static func resolve(arg: String) -> StringName:
	var text := arg.strip_edges().trim_suffix(".tscn").get_file()
	if indexOf(StringName(text)) >= 0: return StringName(text)
	if text.begins_with("level_") && indexOf(StringName(text.trim_prefix("level_"))) >= 0: return StringName(text.trim_prefix("level_"))
	if text.is_valid_int() && int(text) >= 0 && int(text) < ORDER.size(): return ORDER[int(text)]
	return &""

## The region (Territories) of the level at an index
static func regionAt(index: int) -> StringName:
	var def := defAt(index)
	return def.region if def else Territories.regionAt(index)

## "1-3": the level's region number and stop, for lists
static func stopText(index: int) -> String:
	var def := defAt(index)
	if def == null: return str(index + 1)
	return "%d-%d" % [Territories.indexOf(def.region) + 1, def.stop]

## The save's level list for a new save (PlayerData.levels): one entry per level in ORDER
static func defaultEntries() -> Array:
	var out := []
	for i in ORDER.size():
		out.push_back(defaultEntry(i))
	return out

## A new save's entry for the level at `index`. Only the first starts unlocked; the rest open by play
## (Marathon beaten on the level before, on Medium at a finale: Root.opensNextLevel). Saves keep whatever
## they had already opened.
static func defaultEntry(index: int) -> Dictionary:
	var id: StringName = ORDER[index]
	var def := get_def(id)
	var beat := {}
	var tiers := {}
	for mode in Root.gameModes.values():
		beat[mode] = false
		tiers[mode] = ModeTiers.NONE
	return {
		"id": String(id),
		"name": def.displayName if def else String(id).capitalize(),
		"image": def.poster if def else "",
		"unlocked": index == 0,
		"scene": scenePath(id),
		"gamemodeBeat": beat,
		"tiers": tiers, #the best tier beaten per mode (ModeTiers)
	}
