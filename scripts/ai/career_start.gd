class_name CareerStart extends RefCounted

#The progress a career playtest starts from (docs/AI_DRIVER.md, "Career playtests"): a new save, or one
#built to look like a player some way into the game. Every tier is a state real play can reach: levels open
#in order, a level's beaten modes follow the unlock chain (Root.isModeUnlocked), and only owned cars carry
#upgrades. The harness writes the result to its scratch save; the real save is never read or touched here.
#  levels   levels unlocked, from the first (a new save has Root.DEMO_LEVEL_COUNT)
#  beaten   {level count: [modes]}: those modes are marked beaten on that many levels, from the first
#  cars     cars owned: the cheapest first (the order players can afford them)
#  upgrades every stat of every owned car at this level (capped at SaveManager.MAX_UPGRADE_LEVEL)
#  coins, gems  the bank
const G := Root.gameModes
const ALL_MODES := [G.GOONCRUSHER, G.SPRINT, G.GOONPOCALYPSE, G.MARATHON, G.DEFENSE]
const TIERS := {
	"fresh": {},
	#an hour in: Countdown and Sprint beaten on the first level, a second car, a few upgrades
	"early": {"beaten": {1: [G.GOONCRUSHER, G.SPRINT]}, "cars": 2, "upgrades": 3, "coins": 1500, "gems": 2},
	#halfway: the first four levels cleared through Goonpocalypse, four cars, mid upgrades
	"mid": {"beaten": {4: [G.GOONCRUSHER, G.SPRINT, G.GOONPOCALYPSE]}, "cars": 4, "upgrades": 8, "coins": 8000, "gems": 5},
	#most of the way: every level open, all but the last fully beaten, all but the two dearest cars
	"late": {"beaten": {7: ALL_MODES}, "cars": 7, "upgrades": 14, "coins": 40000, "gems": 12},
	#everything: every mode beaten everywhere, every car maxed, a deep bank
	"maxed": {"beaten": {99: ALL_MODES}, "cars": 99, "upgrades": 99, "coins": 1000000, "gems": 99},
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
	for count in spec.get("beaten", {}):
		for i in mini(int(count), data.levels.size()):
			data.levels[i].unlocked = true
			for mode in spec.beaten[count]: data.levels[i].gamemodeBeat[mode] = true
			if i + 1 < data.levels.size(): data.levels[i + 1].unlocked = true #beating a mode opens the next level
	var byPrice: Array = data.cars.duplicate()
	byPrice.sort_custom(func(a, b): return a.cost < b.cost)
	var owned := mini(int(spec.get("cars", 1)), byPrice.size())
	for i in owned:
		byPrice[i].cost = 0
		var level := mini(int(spec.get("upgrades", 0)), SaveManager.MAX_UPGRADE_LEVEL)
		if level > 0:
			for stat in STATS: byPrice[i].upgrades[stat] = level
	data.coin = int(spec.get("coins", 0))
	data.gem = int(spec.get("gems", 0))
	data.selectedCar = data.cars.find(byPrice[owned - 1]) if owned > 0 else 0 #the best car owned, as a player would drive
	data.selectedLevel = 0
	data.gameMode = G.GOONCRUSHER
	data.saveVersion = SaveManager.SAVE_VERSION
	return data

## How far a save has come, for the career log: levels open, modes beaten, cars owned, upgrades bought, bank.
static func progress(data: PlayerData) -> Dictionary:
	var beaten := 0
	var open := 0
	for level in data.levels:
		if level.unlocked: open += 1
		for mode in ALL_MODES: if level.gamemodeBeat.get(mode, false): beaten += 1
	var owned := 0
	var upgrades := 0
	for car in data.cars:
		if car.cost == 0: owned += 1
		for value in car.upgrades.values(): upgrades += int(value)
	return {"levels_open": open, "modes_beaten": beaten, "modes_total": data.levels.size() * ALL_MODES.size(),
		"cars_owned": owned, "cars_total": data.cars.size(), "upgrades": upgrades,
		"upgrades_total": data.cars.size() * STATS.size() * SaveManager.MAX_UPGRADE_LEVEL, "coins": data.coin, "gems": data.gem}
