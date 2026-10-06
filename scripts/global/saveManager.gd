extends Node

#Progress save. Settings live in user://settings.cfg (see Settings); only progress is kept here.
#The demo and the full game share this file, so demo progress carries over: load_data() merges
#each save with the current defaults (migrate()) before anything reads it.

const SAVE_VERSION := 5 #2: every level's gamemodeBeat has a GOONPOCALYPSE key. 3: goonsCrushed (older saves load it empty). 4: meta, and a score record per car
#5: levels come from the Levels registry (the world revamp) and carry an id; older level entries keep their unlocks by index, but their beaten modes reset and their records move to the new level's id
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
			playerData = data
			if migrate(): save_character_data()
			return playerData
	return reset_save()

func reset_save():
	playerData = load("res://scene/player/save/playerData.tres").duplicate(true)
	migrate() #the template is a saved file too, and may lack fields added since it was written
	save_character_data()
	flush()
	return playerData

#Merge the saved file with the current defaults. New cars and levels are added, moved scene
#paths and new record keys are picked up, and price changes reach cars that are still locked.
#Returns true when anything changed.
func migrate() -> bool:
	var defaults = PlayerData.new()
	var before = var_to_str([playerData.cars, playerData.levels, playerData.saveVersion, playerData.selectedCar, playerData.selectedLevel, playerData.gameMode, playerData.meta])
	for section in defaults.meta:
		if not playerData.meta.get(section) is Dictionary: playerData.meta[section] = {}
	for defaultCar in defaults.cars:
		var saved = playerData.cars.filter(func(c): return c.name == defaultCar.name)
		if saved.is_empty():
			playerData.cars.push_back(defaultCar.duplicate(true))
			continue
		var car = saved[0]
		car.scene = defaultCar.scene
		if car.cost != 0: car.cost = defaultCar.cost
		for key in defaultCar:
			if not car.has(key): car[key] = defaultCar[key].duplicate(true) if defaultCar[key] is Dictionary else defaultCar[key]
		for key in defaultCar.records:
			if not car.records.has(key): car.records[key] = 0
	#levels were not saved before version 1, so older saves get the defaults here
	playerData.levels = mergeLevels(playerData.levels)
	rekeyLevelRecords()
	playerData.selectedCar = clampi(playerData.selectedCar, 0, playerData.cars.size() - 1)
	playerData.selectedLevel = clampi(playerData.selectedLevel, 0, playerData.levels.size() - 1)
	playerData.gameMode = clampi(playerData.gameMode, 0, Root.gameModes.size() - 1)
	playerData.saveVersion = SAVE_VERSION
	return before != var_to_str([playerData.cars, playerData.levels, playerData.saveVersion, playerData.selectedCar, playerData.selectedLevel, playerData.gameMode, playerData.meta])

#The save's levels rebuilt from the registry (Levels.ORDER). A saved entry with a known id keeps its unlock
#and beaten modes. An entry from before the registry (no id, or an old scene name, Levels.LEGACY_KEYS) keeps
#only its unlock, carried to the level now at its old index: it was a different level, so its beaten modes
#reset. Entries for levels no longer in the registry are dropped.
static func mergeLevels(savedLevels: Array) -> Array:
	var byId := {}
	var legacy := {} #new index -> the old entry that sat there
	for j in savedLevels.size():
		var saved = savedLevels[j]
		if not saved is Dictionary: continue
		var id := str(saved.get("id", ""))
		if Levels.indexOf(StringName(id)) >= 0:
			byId[id] = saved
			continue
		var old := Levels.LEGACY_KEYS.find(levelKey(saved))
		legacy[old if old >= 0 else j] = saved
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
		elif legacy.has(i):
			level.unlocked = bool(legacy[i].get("unlocked", level.unlocked))
		merged.push_back(level)
	return merged

#records keyed by an old level scene name (meta.records.<section>.level_grass_1) move to the id of the level
#now at that index; a record already under the new id wins
func rekeyLevelRecords() -> void:
	for section in playerData.meta.records:
		var byLevel = playerData.meta.records[section]
		if not byLevel is Dictionary: continue
		for old in Levels.LEGACY_KEYS.size():
			var oldKey: String = Levels.LEGACY_KEYS[old]
			if not byLevel.has(oldKey) || old >= Levels.count(): continue
			var newKey := String(Levels.ORDER[old])
			if not byLevel.has(newKey): byLevel[newKey] = byLevel[oldKey]
			byLevel.erase(oldKey)

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

func unlockCar():
	var thisCar = playerData.cars[playerData.selectedCar]
	if playerData.coin >= thisCar.cost:
		playerData.coin -= thisCar.cost
		thisCar.cost = 0
		save_character_data()
		return true
	else: return false

#upgrades each car can buy per stat. Saves from before the cap keep any levels above it (no refund).
const MAX_UPGRADE_LEVEL := 20

#how much the next upgrade will cost
func requestStatCost(statString: Root.upgrade) -> int:
	return int(pow( getUpgradeLevel(statString) + 1 , 1.6 ) * 15)

func isUpgradeMaxed(statString: Root.upgrade) -> bool:
	return getUpgradeLevel(statString) >= MAX_UPGRADE_LEVEL

func requestStatUpgrade(statString: Root.upgrade) -> bool:
	if isUpgradeMaxed(statString): return false
	var requestCost = requestStatCost(statString)
	if playerData.coin >= requestCost:
		playerData.coin -= requestCost
		var upgrades = playerData.cars[playerData.selectedCar].upgrades
		upgrades[statString] = upgrades.get(statString, 0) + 1
		save_character_data()
		Root.mainMenu.statUpdatesUiUpdate()
		return true #true because upgrade went through
	else: return false #false if upgrade not allowed

#gets the current cars upgrade value for a specific upgrade type
func getUpgradeLevel(upgradeType:Root.upgrade) -> int:
	return playerData.cars[playerData.selectedCar].upgrades.get(upgradeType, 0)

func selectNextLevel():
	if playerData.selectedLevel < playerData.levels.size() - 1:
		playerData.selectedLevel += 1
	else: playerData.selectedLevel = 0
	save_character_data()
	return playerData.levels[playerData.selectedLevel]

func selectPreviousLevel():
	if playerData.selectedLevel > 0:playerData.selectedLevel -= 1
	else: playerData.selectedLevel = playerData.levels.size() - 1
	save_character_data()
	return playerData.levels[playerData.selectedLevel]


func selectNextCar():
	if playerData.selectedCar < playerData.cars.size() - 1:
		playerData.selectedCar += 1
	else: playerData.selectedCar = 0
	save_character_data()
	return playerData.cars[playerData.selectedCar]

func selectPreviousCar():
	if playerData.selectedCar > 0: playerData.selectedCar -= 1
	else: playerData.selectedCar = playerData.cars.size() - 1
	save_character_data()
	return playerData.cars[playerData.selectedCar]


func currentLevelPassed():
	playerData.levels[playerData.selectedLevel].gamemodeBeat[playerData.gameMode] = true
	var next = playerData.selectedLevel + 1
	if next < playerData.levels.size() && not playerData.levels[next].unlocked:
		playerData.levels[next].unlocked = true
		#the demo unlocks the level for the full game but doesn't open the menu on a level it can't play
		if not (Root.IS_DEMO && next >= Root.DEMO_LEVEL_COUNT):
			playerData.selectedLevel = next
			playerData.gameMode = Root.gameModes.GOONCRUSHER
	save_character_data()

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

func selectNextGameMode():
	playerData.gameMode = wrap( playerData.gameMode + 1, 0 , Root.gameModes.size() )
	save_character_data()
	return playerData.gameMode

func selectPreviousGameMode():
	playerData.gameMode = wrap( playerData.gameMode  -1, 0 , Root.gameModes.size() )
	save_character_data()
	return playerData.gameMode

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
