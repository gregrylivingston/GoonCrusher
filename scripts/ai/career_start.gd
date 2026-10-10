class_name CareerStart extends RefCounted

#The progress a career playtest starts from (docs/AI_DRIVER.md, "Career playtests"): a new save, or one
#built to look like a player some way into the game. Every tier is a state real play can reach: levels open
#in order, a level's beaten modes follow the unlock chain (Root.isModeUnlocked), and only owned cars carry
#upgrades. The harness writes the result to its scratch save; the real save is never read or touched here.
#  levels   levels unlocked, from the first (a new save has only the first)
#  beaten   {level count: [modes]}: those modes are marked beaten (on `tier`) on that many levels, from the first;
#           Goonpocalypse and Defense only where the Marathon is (the unlock chain); a level whose Marathon is
#           won (on Medium at a finale) opens the next
#  tier     the tier the beaten modes are credited on (ModeTiers; Medium by default, so finales open)
#  carClears every owned car has cleared every beaten mode on that tier (meta.carClears)
#  cars     cars owned: the cheapest first (the order players can afford them)
#  upgrades every stat of every owned car at this level (capped at SaveManager.MAX_UPGRADE_LEVEL)
#  coins, gems  the bank
#  pickups  the rarest pickup tier unlocked (Pickups.R; missing: only the tree roots), following each tree
#           down from its root, so no pickup is open while its parent is locked
const G := Root.gameModes
#what a tier has beaten on a level: ROAD is Sprint, Countdown and the first featured mode that can be played
#(enough to open the next level); ALL_MODES is every mode the level plays that can be played
const ROAD := "road"
const ALL_MODES := "all"
const TIERS := {
	"fresh": {},
	#an hour or two in: The Wilds done (Tribe Country's first level open), a second car, a few upgrades
	"early": {"beaten": {5: ROAD}, "cars": 2, "upgrades": 3, "coins": 1500, "gems": 2, "pickups": Pickups.R.COMMON},
	#halfway: three regions down the road, four cars, mid upgrades
	"mid": {"beaten": {15: ROAD}, "cars": 4, "upgrades": 8, "coins": 8000, "gems": 5, "pickups": Pickups.R.UNCOMMON},
	#most of the way: five regions fully beaten (The Works open), all but the two dearest cars
	"late": {"beaten": {25: ALL_MODES}, "cars": 7, "upgrades": 14, "coins": 40000, "gems": 12, "pickups": Pickups.R.EPIC},
	#everything: every mode beaten on Hard everywhere by every car, every car maxed, a deep bank
	"maxed": {"beaten": {99: ALL_MODES}, "tier": ModeTiers.HARD, "carClears": true, "cars": 99, "upgrades": 99, "coins": 1000000, "gems": 99, "pickups": Pickups.R.LEGENDARY},
}
#one line per tier, for the console's `start` and the docs
const TIER_TEXT := {
	"fresh": "a new save",
	"early": "The Wilds done on Medium (Sprint, Countdown and a featured mode; Mudlick Marsh open), 2 cars, upgrades at 3, 1,500 coins, Common pickups",
	"mid": "3 regions done on Medium (Frostbite Pass open), 4 cars, upgrades at 8, 8,000 coins, pickups up to Uncommon",
	"late": "5 regions fully beaten on Medium (Blast Pits open), 7 cars, upgrades at 14, 40,000 coins, pickups up to Epic",
	"maxed": "all 30 levels beaten on Hard by every car, everything owned and unlocked, every upgrade maxed, 1,000,000 coins",
}
const STATS := [Root.upgrade.ENGINE, Root.upgrade.STEERING, Root.upgrade.TRACTION, Root.upgrade.ARMOR,
	Root.upgrade.HEADLIGHTS, Root.upgrade.OIL, Root.upgrade.CLOVER, Root.upgrade.LUCK]

## A new PlayerData at a tier, with `overrides` (the same keys as a tier) on top. Unknown tiers return null.
static func build(tier: String, overrides: Dictionary = {}) -> PlayerData:
	if not TIERS.has(tier): return null
	var spec: Dictionary = TIERS[tier].duplicate()
	spec.merge(overrides, true)
	var data: PlayerData = load("res://scene/player/save/playerData.tres").duplicate(true)
	data.levels = Levels.defaultEntries()
	if spec.has("levels"):
		for i in data.levels.size(): data.levels[i].unlocked = data.levels[i].unlocked || i < int(spec.levels)
	var winTier := ModeTiers.clampTier(int(spec.get("tier", ModeTiers.MEDIUM))) #Medium: finales ask for it (Root.opensNextLevel)
	for count in spec.get("beaten", {}):
		for i in mini(int(count), data.levels.size()):
			data.levels[i].unlocked = true
			for mode in beatenModes(i, spec.beaten[count]): SaveManager.passTier(data.levels[i], mode, winTier)
			#a won featured mode opens the next level
			if i + 1 < data.levels.size() && Root.opensNextLevel(data.levels[i]): data.levels[i + 1].unlocked = true
	var byPrice: Array = data.cars.duplicate()
	byPrice.sort_custom(func(a, b): return a.cost < b.cost)
	var owned := mini(int(spec.get("cars", 1)), byPrice.size())
	if spec.get("carClears", false): #every owned car has won every beaten mode on the tier
		var clears := {}
		for level in data.levels:
			for mode in level.gamemodeBeat:
				if not level.gamemodeBeat[mode]: continue
				var byCar: Dictionary = clears.get_or_add(str(level.id), {}).get_or_add(int(mode), {})
				for i in owned: byCar[str(byPrice[i].name)] = ModeTiers.best(level, mode)
		data.meta.carClears = clears
	for i in owned:
		byPrice[i].cost = 0
		var level := mini(int(spec.get("upgrades", 0)), SaveManager.MAX_UPGRADE_LEVEL)
		if level > 0:
			for stat in STATS: byPrice[i].upgrades[stat] = level
	data.meta.unlocks = {}
	if spec.has("pickups"):
		for kind in Pickups.KIND_ORDER:
			for id in Unlocks.treeOrder(kind): #parents come before their children
				var d: Dictionary = Pickups.DATA[id]
				var parentOpen: bool = d.get("parent", "") == "" || data.meta.unlocks.has("pickup:" + d.parent) || Pickups.DATA[d.parent].get("start", false)
				if not d.get("start", false) && d.rarity <= int(spec.pickups) && parentOpen: data.meta.unlocks["pickup:" + id] = true
	data.coin = int(spec.get("coins", 0))
	data.gem = int(spec.get("gems", 0))
	data.selectedCar = data.cars.find(byPrice[owned - 1]) if owned > 0 else 0 #the best car owned, as a player would drive
	data.selectedLevel = 0
	data.gameMode = Root.firstMode(0)
	data.saveVersion = SaveManager.SAVE_VERSION
	return data

## The modes a tier has beaten on level `index`: ROAD or ALL_MODES
static func beatenModes(index: int, what: String) -> Array:
	if what == ALL_MODES: return Root.modePath(index).filter(func(m): return Root.isModeAvailable(m))
	return Root.openerModes(index) + [Root.roadModes(index)[0]]

#---------- playing from a tier by hand (the console's `start`, the --play-start option) ----------

static var realSavePath := "" #the save in use before the first switch; "" while it is still in use

## The tier whose scratch save is in use, or "" for the real save
static func activeTier() -> String:
	if realSavePath == "": return ""
	return SaveManager.save_path.get_file().trim_prefix("human_").trim_suffix("_save.tres")

## Plays on a scratch save at `tier`, user://playtest/human_<tier>_save.tres, so the real save is never
## touched. One already there is carried on with unless `fresh`. Returns what happened, or "Error: ...".
static func useScratchSave(tier: String, fresh := false, overrides: Dictionary = {}) -> String:
	if not TIERS.has(tier): return "Error: unknown tier '%s' (have %s)" % [tier, ", ".join(TIERS.keys())]
	SaveManager.flush() #keep what the save in use has so far
	if realSavePath == "": realSavePath = SaveManager.save_path
	var path := "user://playtest/human_%s_save.tres" % tier
	DirAccess.make_dir_recursive_absolute("user://playtest")
	SaveManager.save_path = path
	if ResourceLoader.exists(path) && not fresh:
		SaveManager.playerData = SaveManager.load_data()
		return "Playing the %s save again (start %s fresh rebuilds it): %s" % [tier, tier, ProjectSettings.globalize_path(path)]
	SaveManager.playerData = build(tier, overrides)
	SaveManager.migrate()
	SaveManager.save_character_data()
	SaveManager.flush()
	return "Playing a new %s save (%s): %s" % [tier, TIER_TEXT[tier], ProjectSettings.globalize_path(path)]

## Back to the real save
static func useRealSave() -> String:
	if realSavePath == "": return "Already playing the real save"
	SaveManager.flush()
	SaveManager.save_path = realSavePath
	realSavePath = ""
	SaveManager.playerData = SaveManager.load_data()
	return "Back to the real save: " + ProjectSettings.globalize_path(SaveManager.save_path)

## How far a save has come, for the career log: levels open, modes beaten, cars owned, upgrades bought, bank.
static func progress(data: PlayerData) -> Dictionary:
	var beaten := 0
	var open := 0
	for level in data.levels:
		if level.unlocked: open += 1
		for mode in Root.modePath(level): if level.gamemodeBeat.get(mode, false): beaten += 1
	var owned := 0
	var upgrades := 0
	for car in data.cars:
		if car.cost == 0: owned += 1
		for value in car.upgrades.values(): upgrades += int(value)
	return {"levels_open": open, "modes_beaten": beaten, "modes_total": range(data.levels.size()).reduce(func(n, i): return n + beatenModes(i, ALL_MODES).size(), 0),
		"cars_owned": owned, "cars_total": data.cars.size(), "upgrades": upgrades,
		"upgrades_total": data.cars.size() * STATS.size() * SaveManager.MAX_UPGRADE_LEVEL, "coins": data.coin, "gems": data.gem,
		"pickups_open": pickupsOpen(data), "pickups_total": Pickups.DATA.size()}

## Pickups open in a save: the tree roots, Crush Combo and everything in its meta.unlocks
static func pickupsOpen(data: PlayerData) -> int:
	var open := 0
	for id in Pickups.DATA:
		var d: Dictionary = Pickups.DATA[id]
		if d.get("start", false) || d.rarity == Pickups.R.SYSTEM || data.meta.get("unlocks", {}).has("pickup:" + id): open += 1
	return open
