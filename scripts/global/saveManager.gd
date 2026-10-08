extends Node

#Progress save. Settings live in user://settings.cfg (see Settings); only progress is kept here.
#The demo and the full game share this file: load_data() merges each save with the current defaults
#(migrate()) before anything reads it.

const SAVE_VERSION := 6 #6: the unlock system (Unlocks, meta.unlocks, meta.lifetime, car gem prices)
#Saves older than FIRST_KEPT_VERSION start over (the author's call when the unlocks went in): the old file is
#copied beside the save as <name>.v<version>.tres, then a new save replaces it.
const FIRST_KEPT_VERSION := 6
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
		if car.cost != 0:
			car.cost = defaultCar.cost
			car.gems = defaultCar.get("gems", 0)
		for key in defaultCar:
			if not car.has(key): car[key] = defaultCar[key].duplicate(true) if defaultCar[key] is Dictionary else defaultCar[key]
		for key in defaultCar.records:
			if not car.records.has(key): car.records[key] = 0
	#levels were not saved before version 1, so older saves get the defaults here
	playerData.levels = mergeLevels(playerData.levels)
	playerData.selectedCar = clampi(playerData.selectedCar, 0, playerData.cars.size() - 1)
	playerData.selectedLevel = clampi(playerData.selectedLevel, 0, playerData.levels.size() - 1)
	playerData.gameMode = clampi(playerData.gameMode, 0, Root.gameModes.size() - 1)
	playerData.saveVersion = SAVE_VERSION
	return before != var_to_str([playerData.cars, playerData.levels, playerData.saveVersion, playerData.selectedCar, playerData.selectedLevel, playerData.gameMode, playerData.meta])

#The save's levels rebuilt from the registry (Levels.ORDER). A saved entry keeps its unlock and beaten
#modes; entries for levels no longer in the registry are dropped.
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

#how much the next upgrade will cost. `carIndex` -1 is the selected car (the Goonopedia's Cars tab names its own).
func requestStatCost(statString: Root.upgrade, carIndex := -1) -> int:
	return int(pow( getUpgradeLevel(statString, carIndex) + 1 , 1.6 ) * 15)

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


#A won run: the mode is beaten here. Once Root.modesToOpenNext(level) modes are beaten (Countdown, Sprint and one
#more), the next level opens and the menu moves to it; until then the menu offers this level's next unbeaten
#mode. Levels already open stay open (saves from before the rule keep theirs).
func currentLevelPassed():
	var level: Dictionary = playerData.levels[playerData.selectedLevel]
	level.gamemodeBeat[playerData.gameMode] = true
	var next = playerData.selectedLevel + 1
	if Root.opensNextLevel(level) && next < playerData.levels.size() && not playerData.levels[next].unlocked:
		playerData.levels[next].unlocked = true
		#the demo unlocks the level for the full game but doesn't open the menu on a level it can't play
		if not (Root.IS_DEMO && next >= Root.DEMO_LEVEL_COUNT):
			playerData.selectedLevel = next
			playerData.gameMode = Root.gameModes.GOONCRUSHER
	else:
		var unbeaten = Root.MODE_PATH.filter(func(m): return not level.gamemodeBeat.get(m, false) && Root.isModePlayable(level, m))
		if not unbeaten.is_empty(): playerData.gameMode = unbeaten[0]
	save_character_data()

## Modes still to beat on a level before the next one opens (0 when it is open or there is none)
func modesToGo(index: int) -> int:
	if index + 1 >= playerData.levels.size() || playerData.levels[index + 1].unlocked: return 0
	return maxi(Root.modesToOpenNext(playerData.levels[index]) - Root.modesBeaten(playerData.levels[index]), 0)

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
