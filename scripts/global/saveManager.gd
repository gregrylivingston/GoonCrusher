extends Node

#Progress save. Settings live in user://settings.cfg (see Settings); only progress is kept here.
#The demo and the full game share this file: load_data() merges each save with the current defaults
#(migrate()) before anything reads it.

const SAVE_VERSION := 14 #14: levels pick their own two openers (keepOpenerWins). 13: the pickup "tyre" is "tire" (RENAMED_PICKUPS). 12: the mode menu (Modes: each level features three modes, any of which opens the next; openDueLevels). 11: most tree roots start locked (keepOldStarters). 10: the gift box games joined the Casino tree (mergePrizeUnlocks). 6: the unlock system (Unlocks, meta.unlocks, meta.lifetime, car gem prices). 7: mode tiers (ModeTiers).
#8: the road atlas (30 levels in 6 regions, the Marathon road, meta.carClears). 9: the "audi" became the "supercar".
#Saves older than FIRST_KEPT_VERSION start over (the author's call when the unlocks went in, and again for the road
#atlas): the old file is copied beside the save as <name>.v<version>.tres, then a new save replaces it.
const FIRST_KEPT_VERSION := 8
var save_path = "user://saveData_0.1.tres"
var playerData: PlayerData
var saveTimer: Timer
var dirty := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	saveTimer = Timer.new()
	saveTimer.one_shot = true
	saveTimer.wait_time = 1.0
	saveTimer.timeout.connect(flush)
	add_child(saveTimer)
	#reset_save()   ###add this line here, start the game, then remove it
	playerData = load_data()
	if get_tree().has_signal("scene_changed"): get_tree().connect("scene_changed", flush)

func _exit_tree():
	flush()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST: flush()

func load_data():
	if ResourceLoader.exists(save_path):
		var data = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if data is PlayerData:
			Settings.import_legacy_volume(data.settings.get("volume", {}))
			if isObsolete(data):
				DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path.get_basename() + ".v%d.tres" % data.saveVersion))
				return reset_save()
			playerData = data
			if migrate(): save_character_data()
			return playerData
	return reset_save()

## A save from before FIRST_KEPT_VERSION, which load_data() replaces with a new one
static func isObsolete(data: PlayerData) -> bool:
	return data.saveVersion < FIRST_KEPT_VERSION

func reset_save():
	playerData = load("res://scene/player/save/playerData.tres").duplicate(true)
	migrate() #the template is a saved file too, and may lack fields added since it was written
	save_character_data()
	flush()
	return playerData

#Merge the saved file with the current defaults. New cars and levels are added, moved scene
#paths and new record keys are picked up, and price changes (coins and gems) reach cars that are still locked.
#Returns true when anything changed.
func migrate() -> bool:
	var defaults = PlayerData.new()
	var before = var_to_str([playerData.cars, playerData.levels, playerData.saveVersion, playerData.selectedCar, playerData.selectedLevel, playerData.gameMode, playerData.gameTier, playerData.meta])
	for section in defaults.meta:
		if not playerData.meta.get(section) is Dictionary: playerData.meta[section] = {}
	for old in RENAMED_CARS: renameCar(old, RENAMED_CARS[old])
	for old in RENAMED_PICKUPS: renamePickup(old, RENAMED_PICKUPS[old])
	if playerData.saveVersion >= FIRST_KEPT_VERSION && playerData.saveVersion < 10: mergePrizeUnlocks()
	if playerData.saveVersion >= FIRST_KEPT_VERSION && playerData.saveVersion < 11: keepOldStarters()
	for defaultCar in defaults.cars:
		var saved = playerData.cars.filter(func(c): return c.name == defaultCar.name)
		if saved.is_empty():
			playerData.cars.push_back(defaultCar.duplicate(true))
			continue
		var car = saved[0]
		car.scene = defaultCar.scene
		if car.cost != 0:
			car.cost = defaultCar.cost
			car.gems = defaultCar.get("gems", 0)
		for key in defaultCar:
			if not car.has(key): car[key] = defaultCar[key].duplicate(true) if defaultCar[key] is Dictionary else defaultCar[key]
		for key in defaultCar.records:
			if not car.records.has(key): car.records[key] = 0
	#levels were not saved before version 1, so older saves get the defaults here
	playerData.levels = mergeLevels(playerData.levels)
	if playerData.saveVersion < 14: keepOpenerWins() #before openDueLevels reads what is beaten
	if playerData.saveVersion < 12: openDueLevels()
	playerData.selectedCar = clampi(playerData.selectedCar, 0, playerData.cars.size() - 1)
	playerData.selectedLevel = clampi(playerData.selectedLevel, 0, playerData.levels.size() - 1)
	playerData.gameMode = clampi(playerData.gameMode, 0, Root.gameModes.size() - 1)
	playerData.gameTier = ModeTiers.clampTier(playerData.gameTier)
	playerData.saveVersion = SAVE_VERSION
	return before != var_to_str([playerData.cars, playerData.levels, playerData.saveVersion, playerData.selectedCar, playerData.selectedLevel, playerData.gameMode, playerData.gameTier, playerData.meta])

#version 12: the next level opens on any of a level's featured modes (it was the Marathon everywhere), so a save
#that had already won one of them gets the level it is now owed
func openDueLevels() -> void:
	for i in playerData.levels.size() - 1:
		if playerData.levels[i].unlocked && Root.opensNextLevel(playerData.levels[i]): playerData.levels[i + 1].unlocked = true

#version 11: only the Fuel Can, the Coin and the Claw Crane start open. These were open on every older save
#without being saved, so such a save keeps them
const OLD_STARTERS := ["health", "engine", "magnet", "horn", "nitro", "speedtrap", "ffwd"]

func keepOldStarters() -> void:
	for id in OLD_STARTERS: playerData.meta.unlocks["pickup:" + id] = true

#version 10: the gift box games (old unlock "prize:<game>") became Casino pickups, one unlock for the drop and
#the box game: old game id -> the pickup that now opens it (CrushPrizes.GAMES)
const PRIZE_PICKUPS := {"claw": "claw", "shuffle": "shuffle", "scratch": "scratch", "press": "press", "deal": "deal", "pachinko": "pachinko", "slot": "slotmachine", "pusher": "pusher"}

#a game bought on the old ladder opens its pickup, and the Slot Machine, which every save before version 10
#started with as the Casino tree's root, stays open
func mergePrizeUnlocks() -> void:
	var unlocks: Dictionary = playerData.meta.unlocks
	for game in PRIZE_PICKUPS:
		if unlocks.has("prize:" + game): unlocks["pickup:" + PRIZE_PICKUPS[game]] = true
		unlocks.erase("prize:" + game)
	unlocks["pickup:slotmachine"] = true

#version 14: a level's two openers are its own (LevelDef.openers), where every level opened on Sprint then
#Countdown. A win on an old opener carries to the mode now in its slot, on the same tier, so nothing a save
#had open is shut again.
func keepOpenerWins() -> void:
	for level in playerData.levels:
		if not level is Dictionary || not level.has("id"): continue
		var now := Root.openerModes(level)
		for slot in Modes.DEFAULT_OPENERS.size():
			var was: int = Modes.DEFAULT_OPENERS[slot]
			if now[slot] != was && level.get("gamemodeBeat", {}).get(was, false): passTier(level, now[slot], ModeTiers.best(level, was))

#pickups whose id changed: old id -> new id (version 13)
const RENAMED_PICKUPS := {"tyre": "tire"}

#moves a renamed pickup's unlock and its discovery to the new id
func renamePickup(old: String, new: String) -> void:
	for pair in [["unlocks", "pickup:"], ["pickups", ""]]:
		var section = playerData.meta.get(pair[0], {})
		if section is Dictionary && section.has(pair[1] + old):
			section[pair[1] + new] = section[pair[1] + old]
			section.erase(pair[1] + old)

#cars whose id changed: old name -> new name (version 9)
const RENAMED_CARS := {"audi": "supercar"}

#moves a renamed car's save data to its new name: its garage entry (kept in place, so selectedCar still
#points at it), its unlock and its clears on every level and mode
func renameCar(old: String, new: String) -> void:
	for car in playerData.cars:
		if car.name == old: car.name = new
	var unlocks = playerData.meta.get("unlocks", {})
	if unlocks is Dictionary && unlocks.has("car:" + old):
		unlocks["car:" + new] = unlocks["car:" + old]
		unlocks.erase("car:" + old)
	for byMode in playerData.meta.get("carClears", {}).values():
		for byCar in byMode.values():
			if byCar.has(old):
				byCar[new] = maxi(int(byCar[old]), int(byCar.get(new, 0)))
				byCar.erase(old)

#The save's levels rebuilt from the registry (Levels.ORDER). A saved entry keeps its unlock, beaten modes and
#best tiers (a mode beaten before the tiers, version 7, counts as Easy); entries for levels no longer in the
#registry are dropped.
static func mergeLevels(savedLevels: Array) -> Array:
	var byId := {}
	for saved in savedLevels:
		if saved is Dictionary && Levels.indexOf(StringName(str(saved.get("id", "")))) >= 0: byId[str(saved.id)] = saved
	var merged := []
	for i in Levels.count():
		var level := Levels.defaultEntry(i)
		var saved = byId.get(level.id)
		if saved != null:
			level.unlocked = bool(saved.get("unlocked", level.unlocked))
			#beaten modes are kept; modes the save has no key for (GOONPOCALYPSE before version 2) come from the defaults
			var savedBeat = saved.get("gamemodeBeat", {})
			if savedBeat is Dictionary:
				for mode in savedBeat: level.gamemodeBeat[mode] = bool(savedBeat[mode])
			var savedTiers = saved.get("tiers", {})
			for mode in level.tiers:
				var t := int(savedTiers.get(mode, 0)) if savedTiers is Dictionary else 0
				if level.gamemodeBeat.get(mode, false): t = maxi(t, ModeTiers.EASY)
				level.tiers[mode] = clampi(t, ModeTiers.NONE, ModeTiers.HARD)
				if t > ModeTiers.NONE: level.gamemodeBeat[mode] = true
		merged.push_back(level)
	return merged

#marks the save dirty; it is written one second after the last change, on scene change and on exit
func save_character_data():
	dirty = true
	if is_instance_valid(saveTimer) && saveTimer.is_inside_tree(): saveTimer.start()

func flush():
	if not dirty || playerData == null: return
	dirty = false
	ResourceSaver.save(playerData, save_path)


#credits the whole amount and saves first; the menu then counts the display up
func addCoins(num: int):
	if num == 0: return
	var start = playerData.coin
	playerData.coin += num
	save_character_data()
	flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.animateCoins(start, playerData.coin)

func addGems(num: int):
	if num == 0: return
	playerData.gem += num
	save_character_data()
	flush()
	if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()

## Buys the selected car (Unlocks.buy): entry cars cost coins, advanced ones coins and gems.
func unlockCar() -> bool:
	return Unlocks.buy("car:" + str(playerData.cars[playerData.selectedCar].name))

#upgrades each car can buy per stat. Saves from before the cap keep any levels above it (no refund).
const MAX_UPGRADE_LEVEL := 20

#how much the next upgrade will cost. `carIndex` -1 is the selected car (the garage's bench, DriverBench, names its own).
func requestStatCost(statString: Root.upgrade, carIndex := -1) -> int:
	return upgradePrice(getUpgradeLevel(statString, carIndex), str(playerData.cars[playerData.selectedCar if carIndex < 0 else carIndex].name))

## An upgrade from `level` to the next: (level + 1)^1.6 x 30, x the car's scale. An upgrade is +1 to the stat
## on any car, so it is worth most on the entry cars' low stats; the advanced cars' upgrades are the long
## coin sink instead.
const UPGRADE_COST_SCALE := {"sedan": 1.0, "van": 1.0, "taxi": 1.2, "pickup": 1.2, "semi": 1.6, "supercar": 1.8,
	"racer": 1.8, "police": 2.2, "ambulance": 2.5}
static func upgradePrice(level: int, carName: String) -> int:
	return int(pow(level + 1, 1.6) * 30 * UPGRADE_COST_SCALE.get(carName, 1.0))

func isUpgradeMaxed(statString: Root.upgrade, carIndex := -1) -> bool:
	return getUpgradeLevel(statString, carIndex) >= MAX_UPGRADE_LEVEL

func requestStatUpgrade(statString: Root.upgrade, carIndex := -1) -> bool:
	if carIndex < 0: carIndex = playerData.selectedCar
	if isUpgradeMaxed(statString, carIndex) || playerData.cars[carIndex].cost != 0: return false
	var requestCost = requestStatCost(statString, carIndex)
	if playerData.coin >= requestCost:
		playerData.coin -= requestCost
		var upgrades = playerData.cars[carIndex].upgrades
		upgrades[statString] = upgrades.get(statString, 0) + 1
		save_character_data()
		if is_instance_valid(Root.mainMenu): Root.mainMenu.statUpdatesUiUpdate()
		return true #true because upgrade went through
	else: return false #false if upgrade not allowed

#gets a car's upgrade value for a specific upgrade type (-1: the selected car)
func getUpgradeLevel(upgradeType:Root.upgrade, carIndex := -1) -> int:
	return playerData.cars[playerData.selectedCar if carIndex < 0 else carIndex].upgrades.get(upgradeType, 0)

#A won run: the mode is beaten on the RUN's level on the run's tier (and the tiers below it), and the run's car
#clears it there (meta.carClears). The run's level, mode and tier come from the level that ran (Level.runLevel,
#runMode, tier; the menu's selection may have moved since), else the menu's selection (tests, tools). Once the
#one of the level's featured modes is won (on Medium at a region's finale: Root.opensNextLevel) the next level opens and the menu moves
#to it; until then the menu offers this level's next unbeaten mode. Levels already open stay open.
#Returns the best tier before this run, for the first-clear bonus (ModeTiers.firstClear).
func currentLevelPassed(levelIndex := -1, mode := -1, tier := -1) -> int:
	var run = Root.levelRoot if is_instance_valid(Root.levelRoot) && Root.levelRoot is Level && Root.levelRoot.is_inside_tree() else null
	if levelIndex < 0: levelIndex = run.runLevel if run else playerData.selectedLevel
	if mode < 0: mode = run.runMode if run else playerData.gameMode
	if tier < 0: tier = run.tier if run else playerData.gameTier
	levelIndex = clampi(levelIndex, 0, playerData.levels.size() - 1)
	var level: Dictionary = playerData.levels[levelIndex]
	var before := passTier(level, mode, tier)
	var next = levelIndex + 1
	if Root.opensNextLevel(level) && next < playerData.levels.size() && not playerData.levels[next].unlocked:
		playerData.levels[next].unlocked = true
		#the demo unlocks the level for the full game but doesn't open the menu on a level it can't play
		if not (Root.IS_DEMO && next >= Root.DEMO_LEVEL_COUNT):
			playerData.selectedLevel = next
			playerData.gameMode = Root.firstMode(next)
	elif playerData.selectedLevel == levelIndex:
		var unbeaten = Root.modePath(level).filter(func(m): return not level.gamemodeBeat.get(m, false) && Root.isModePlayable(level, m))
		if not unbeaten.is_empty(): playerData.gameMode = unbeaten[0]
	save_character_data()
	return before

## Credits a tier beaten for a mode in a level entry; returns the best tier before it
static func passTier(level: Dictionary, mode: int, tier: int) -> int:
	var before := ModeTiers.best(level, mode)
	if not level.get("tiers") is Dictionary: level["tiers"] = {}
	level.tiers[mode] = maxi(before, ModeTiers.clampTier(tier))
	level.gamemodeBeat[mode] = true
	return before

func getGameTier() -> int:
	return ModeTiers.clampTier(playerData.gameTier)

func setGameTier(tier: int) -> void:
	tier = ModeTiers.clampTier(tier)
	if playerData.gameTier == tier: return
	playerData.gameTier = tier
	save_character_data()

## What is left on a level before the next one opens ("" when it is open or there is none): Root.openLeftText
func openLeft(index: int) -> String:
	if index + 1 >= playerData.levels.size() || playerData.levels[index + 1].unlocked: return ""
	return Root.openLeftText(playerData.levels[index])

#--- car clears (meta.carClears) ----------------------------------------------------------------
#Which cars have won each mode on each level, and on which tier: meta.carClears[level id][mode][car name] =
#the best tier (ModeTiers). A win credits the run's car on that tier and every tier below it, like medals.
#A car's first clear of a tier pays CAR_CLEAR_SHARE of that tier's first-clear coins x the level step, and
#the ninth car to clear a mode, level and tier (a Full Garage) pays FULL_GARAGE_GEMS by tier. Placeholders.
const CAR_CLEAR_SHARE := 0.1
const FULL_GARAGE_GEMS := [0, 1, 2, 4]

## The best tier `car` has won `mode` on at level `index` (ModeTiers.NONE when none)
func carClearTier(index: int, mode: int, car: String) -> int:
	if index < 0 || index >= playerData.levels.size(): return ModeTiers.NONE
	var byLevel: Dictionary = playerData.meta.get("carClears", {}).get(levelKey(playerData.levels[index]), {})
	return int(byLevel.get(mode, {}).get(car, ModeTiers.NONE))

## How many cars have won `mode` at level `index` on `tier` or harder
func carsCleared(index: int, mode: int, tier: int) -> int:
	if index < 0 || index >= playerData.levels.size(): return 0
	var byLevel: Dictionary = playerData.meta.get("carClears", {}).get(levelKey(playerData.levels[index]), {})
	var n := 0
	var byCar: Dictionary = byLevel.get(mode, {})
	for car in byCar:
		if int(byCar[car]) >= tier: n += 1
	return n

## Every car in the garage has won `mode` at level `index` on `tier` or harder
func isFullGarage(index: int, mode: int, tier: int) -> bool:
	return carsCleared(index, mode, tier) >= playerData.cars.size()

## Credits a won run to its car (tier and the tiers below). Returns what it earned: {"tiers": the newly
## cleared tiers, "coin": the new car clear bonus, "gem": the Full Garage gems, "fullGarage": the tiers that
## just became a Full Garage}. Nothing is paid here; the results ticket pays it.
func creditCarClear(index: int, mode: int, tier: int, car: String) -> Dictionary:
	var out := {"tiers": [], "coin": 0, "gem": 0, "fullGarage": []}
	if index < 0 || index >= playerData.levels.size() || car == "": return out
	tier = ModeTiers.clampTier(tier)
	var before := carClearTier(index, mode, car)
	if tier <= before: return out
	var garageBefore := []
	for t in ModeTiers.TIERS: garageBefore.push_back(isFullGarage(index, mode, t))
	var clears: Dictionary = playerData.meta.get_or_add("carClears", {})
	clears.get_or_add(levelKey(playerData.levels[index]), {}).get_or_add(mode, {})[car] = tier
	for t in range(before + 1, tier + 1):
		out.tiers.push_back(t)
		out.coin += carClearCoins(t, index)
		if not garageBefore[t - 1] && isFullGarage(index, mode, t):
			out.fullGarage.push_back(t)
			out.gem += FULL_GARAGE_GEMS[t]
	save_character_data()
	return out

## What a car's first clear of `tier` pays at level `index`: a share of the tier's first-clear coins
static func carClearCoins(tier: int, index: int) -> int:
	return roundi(ModeTiers.FIRST_CLEAR_COINS[ModeTiers.clampTier(tier)] * CAR_CLEAR_SHARE * ModeTiers.levelFactor(index))

## Car clears on every level and mode (the carclears:<n> condition) and Full Garages (garages:<n>), any tier
func carClearCount() -> int:
	var n := 0
	for byMode in playerData.meta.get("carClears", {}).values():
		for byCar in byMode.values(): n += byCar.size()
	return n

## What `car` has won, for its garage card: {"levels": levels it has won any mode on, "tiers": [0, mode wins
## on Easy or harder, on Medium or harder, on Hard]}, each level and mode counted once
func carProgress(car: String) -> Dictionary:
	var out := {"levels": 0, "tiers": [0, 0, 0, 0]}
	for byMode in playerData.meta.get("carClears", {}).values():
		var won := false
		for byCar in byMode.values():
			var best := int(byCar.get(car, ModeTiers.NONE))
			if best <= ModeTiers.NONE: continue
			won = true
			for t in ModeTiers.TIERS: if best >= t: out.tiers[t] += 1
		if won: out.levels += 1
	return out

func fullGarageCount() -> int:
	var n := 0
	for i in playerData.levels.size():
		for mode in Root.gameModes.values():
			if isFullGarage(i, mode, ModeTiers.EASY): n += 1
	return n

var carNameToFind
func getCarByName(carName):
	carNameToFind = carName
	return playerData.cars.filter(findCar)[0]


func findCar(car):
	return car.name == carNameToFind

func getGameMode():
	return playerData.gameMode

func setGameMode(mode: int):
	if playerData.gameMode == mode: return mode
	playerData.gameMode = wrap( mode, 0 , Root.gameModes.size() )
	save_character_data()
	return playerData.gameMode

#--- the record book of fixed courses (meta.records.course) ---------------------------------------
#records.course[level id][mode id][car] = {"time": seconds, "splits": [seconds at each checkpoint], "version":
#Course.VERSION}: the best won run of a fixed-map mode (Modes.isFixedMap), per car. Splits are only compared
#within one course version.

## The car's best run of a level's course in a mode; {} when it has none
func bestCourse(levelIndex: int, mode: int, carName: String) -> Dictionary:
	var byLevel: Dictionary = playerData.meta.get("records", {}).get("course", {})
	return byLevel.get(levelKey(playerData.levels[levelIndex]), {}).get(Modes.idOf(mode), {}).get(carName, {})

## Records a won run; {"time": true} when it is the car's best here (a record from an older course version is replaced)
func recordCourse(levelIndex: int, mode: int, carName: String, seconds: float, splits: Array) -> Dictionary:
	var best := bestCourse(levelIndex, mode, carName)
	var better: bool = best.is_empty() || int(best.get("version", -1)) != Course.VERSION || seconds < float(best.get("time", INF))
	if not better: return {"time": false}
	var byLevel: Dictionary = playerData.meta.records.get_or_add("course", {})
	byLevel.get_or_add(levelKey(playerData.levels[levelIndex]), {}).get_or_add(Modes.idOf(mode), {})[carName] = {"time": seconds, "splits": splits.duplicate(), "version": Course.VERSION}
	save_character_data()
	return {"time": true}

#--- run ranks (meta.records.rank) ---------------------------------------------------------------
#records.rank[level id][mode id] = {"score", "rank", "car", "tier"}: the best-scoring run of a mode on a level
#(RunRank), by any car. Each car's own best rank is in its records ("rank").

## The best-ranked run of a mode on a level; {} when there is none
func bestRank(levelIndex: int, mode: int) -> Dictionary:
	if levelIndex < 0 || levelIndex >= playerData.levels.size(): return {}
	var byLevel: Dictionary = playerData.meta.get("records", {}).get("rank", {})
	return byLevel.get(levelKey(playerData.levels[levelIndex]), {}).get(Modes.idOf(mode), {})

## Records a run's score and rank. Returns {"best": did it beat the level's best for the mode, "before": the
## score it had to beat (0 when there was none)}.
func recordRank(levelIndex: int, mode: int, carName: String, tier: int, score: int, rank: int) -> Dictionary:
	var before := int(bestRank(levelIndex, mode).get("score", 0))
	var records = getCarByName(carName).records
	records.rank = maxi(int(records.get("rank", 0)), rank)
	if score > before:
		var byLevel: Dictionary = playerData.meta.records.get_or_add("rank", {})
		byLevel.get_or_add(levelKey(playerData.levels[levelIndex]), {})[Modes.idOf(mode)] = {"score": score, "rank": rank, "car": carName, "tier": tier}
	save_character_data()
	return {"best": score > before, "before": before}

#--- per-level records (meta.records) -----------------------------------------------------------
#Keyed by the level's id (Levels.ORDER), so reordering levels keeps them, then by car.

## A level entry's stable key: its id; an entry from before the registry gives its scene's file name
static func levelKey(level: Dictionary) -> String:
	if str(level.get("id", "")) != "": return str(level.id)
	return str(level.get("scene", level.get("name", ""))).get_file().get_basename()

## The best Goonpocalypse run on this level with this car: {"time": seconds, "score": points}, zeros if none.
func bestGoonpocalypse(levelIndex: int, carName: String) -> Dictionary:
	var byLevel: Dictionary = playerData.meta.records.get("goonpocalypse", {})
	return byLevel.get(levelKey(playerData.levels[levelIndex]), {}).get(carName, {"time":0, "score":0})

## Keeps the better time and the better score (each on its own), here and in the car's records.
## Returns which of them are new bests: {"time": bool, "score": bool}.
func recordGoonpocalypse(levelIndex: int, carName: String, seconds: int, score: int) -> Dictionary:
	var best = bestGoonpocalypse(levelIndex, carName).duplicate()
	var newBest = {"time": seconds > best.time, "score": score > best.score}
	best.time = maxi(best.time, seconds)
	best.score = maxi(best.score, score)
	var byLevel: Dictionary = playerData.meta.records.get_or_add("goonpocalypse", {})
	byLevel.get_or_add(levelKey(playerData.levels[levelIndex]), {})[carName] = best
	var records = getCarByName(carName).records
	records.time = maxi(records.time, seconds)
	records.score = maxi(records.get("score", 0), score)
	save_character_data()
	return newBest
