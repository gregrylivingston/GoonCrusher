extends Node

enum gameModes {  GOONCRUSHER , SPRINT, MARATHON, DEFENSE, GOONPOCALYPSE }
enum endCondition { NOGAS , NOHEALTH , NOTIME , SUCCESS , ABANDONED , BASEDESTROYED } #append only: the values are ints
enum upgrade { HEALTH , FUEL , ARMOR , ENGINE , TRACTION , STEERING , CLOVER , LUCK , HEADLIGHTS , OIL , COIN , PURSE , GEM , SLOTMACHINE, CURRENTGOONSCRUSHED}
enum terrain { GRASS , SAND , MUD , WATER , HILLS , MOSS , DIRT , SNOW, ASPHALT, ICE, OIL, SHALLOWS, WASH, CONVEYOR, MUDPIT, DEEPSNOW, LOT, BUILDING, BRIDGE } #append only: World.TERRAIN and Goons.T mirror it

var playerCar: OverheadCarBody2D #the car in a run; null in the main menu
#the run's WorldMap (scripts/world/world_map.gd); null until it exists. World's queries use it. A real WorldMap's
#native grid becomes World.grid (and the goons' WorldGrid.current); a test's stand-in clears it
var worldMap = null:
	set(value):
		worldMap = value
		World.grid = value.grid if value is WorldMap else null
		WorldGrid.setCurrent(World.grid)
var station  #this is the gas-station / house thing
var selectedCar: Dictionary
var carInfo: CarInfo #the car shown in the main menu
var selectedCarScene: PackedScene #loaded with the level, so levelRoot's load() finds it cached


var mainMenu: CanvasLayer
var levelRoot: Node2D
var spawnManager: SpawnManager
var playerRoot: GameUI #this is basically the inlevel UI

var isRunActive: bool = false
var earnedCoins: int #the last run's payout, already credited and saved by gameSummary; main2 only animates it
var earnedGems: int

#--- demo build and progression ----------------------------------------------------------------
#Every demo gate reads IS_DEMO, so the Steam demo is built from the same code by flipping it.
const IS_DEMO := false
const GAME_VERSION := "0.1"
const DEMO_CAR_COUNT := 3 #the demo offers the first 3 cars and the first 3 levels
const DEMO_LEVEL_COUNT := 3
const DEMO_MODES = [gameModes.GOONCRUSHER, gameModes.SPRINT]

#modes that are finished enough to play. An unavailable mode shows "Coming soon" whatever its
#unlocks, can't be started, and doesn't count toward unlocking other modes.
const MODE_AVAILABLE = {
	gameModes.GOONCRUSHER: true,
	gameModes.SPRINT: true,
	gameModes.GOONPOCALYPSE: true,
	gameModes.MARATHON: true,
	gameModes.DEFENSE: true,
}

static func versionText() -> String:
	return ("Demo " + GAME_VERSION) if IS_DEMO else GAME_VERSION

#dev console `unfinished on`: Coming Soon modes can be started. Session only, never saved.
static var devAllModesAvailable := false

static func isModeAvailable(mode: int) -> bool:
	if devAllModesAvailable: return true
	if IS_DEMO && mode not in DEMO_MODES: return false
	return MODE_AVAILABLE.get(mode, false)

#the per-level unlock chain, ignoring availability. Countdown is open on any unlocked level,
#Sprint needs Countdown beaten, Marathon and Defense need Sprint, Goonpocalypse needs Countdown and Sprint.
static func isModeUnlocked(level: Dictionary, mode: int) -> bool:
	if not level.get("unlocked", false): return false
	var beat: Dictionary = level.get("gamemodeBeat", {})
	if beat.get(mode, false): return true #a mode already beaten stays open (older saves could beat Sprint first)
	match mode:
		gameModes.GOONCRUSHER: return true
		gameModes.SPRINT: return beat.get(gameModes.GOONCRUSHER, false)
		gameModes.MARATHON, gameModes.DEFENSE: return beat.get(gameModes.SPRINT, false)
		gameModes.GOONPOCALYPSE: return beat.get(gameModes.GOONCRUSHER, false) && beat.get(gameModes.SPRINT, false)
	return false

#Modes beaten on a level that open the next one: its LevelDef.unlockModes (3 on every level for now; the
#unlock chain makes them Countdown, Sprint and one of Goonpocalypse, Marathon and Defense). The demo offers
#only Countdown and Sprint, so it asks for those two. LEVEL_UNLOCK_MODES is the default for a level with no def.
const LEVEL_UNLOCK_MODES := 3
const MODE_PATH := [gameModes.GOONCRUSHER, gameModes.SPRINT, gameModes.GOONPOCALYPSE, gameModes.MARATHON, gameModes.DEFENSE] #the order a player meets them

static func modesToOpenNext(level: Dictionary = {}) -> int:
	if IS_DEMO: return DEMO_MODES.size()
	var def := Levels.get_def(StringName(str(level.get("id", "")))) if level.has("id") else null
	return def.unlockModes if def else LEVEL_UNLOCK_MODES

## Modes beaten on a level, counting only those that can be played (a demo save's extras don't count there)
static func modesBeaten(level: Dictionary) -> int:
	var beat: Dictionary = level.get("gamemodeBeat", {})
	return MODE_PATH.filter(func(m): return beat.get(m, false) && isModeAvailable(m)).size()

## Has this level done enough to open the one after it
static func opensNextLevel(level: Dictionary) -> bool:
	return modesBeaten(level) >= modesToOpenNext(level)

#can this mode be started on this level from the menu
static func isModePlayable(level: Dictionary, mode: int) -> bool:
	return isModeAvailable(mode) && isModeUnlocked(level, mode)

#why a mode can't be started, for the menu; "" when it can
static func modeLockReason(level: Dictionary, mode: int) -> String:
	if not isModeAvailable(mode): return "Not Available In Demo" if IS_DEMO && MODE_AVAILABLE.get(mode, false) else "Coming Soon"
	if isModeUnlocked(level, mode): return ""
	if not level.get("unlocked", false): return "Level Locked"
	match mode:
		gameModes.SPRINT: return "Beat Countdown To Unlock"
		gameModes.MARATHON, gameModes.DEFENSE: return "Beat Sprint To Unlock"
		gameModes.GOONPOCALYPSE: return "Beat Countdown And Sprint To Unlock"
	return "Locked"

#coins a run pays: its coins times the star multiplier, x1 plus STAR_BONUS a star (50 stars pay x6).
#Was coins x stars, which paid six-figure runs by the sixth level (career playtests, docs/GAMEPLAY_SUGGESTIONS.md).
const STAR_BONUS := 0.1
static func payoutMultiplier(star: int) -> float:
	return 1.0 + STAR_BONUS * maxi(0, star)

## The multiplier as the HUD and the results ticket show it: "3.6"
static func multiplierText(star: int) -> String:
	return "%.1f" % payoutMultiplier(star)

static func computePayout(coin: int, star: int) -> int:
	return roundi(coin * payoutMultiplier(star))


@onready var powerup = {
	upgrade.HEALTH:preload("res://scene/powerup/health.tscn"),
	upgrade.FUEL:preload("res://scene/powerup/fuel.tscn"),
	upgrade.STEERING:preload("res://scene/powerup/steering.tscn"),
	upgrade.ENGINE:preload("res://scene/powerup/engine.tscn"),
	upgrade.ARMOR:preload("res://scene/powerup/armor.tscn"),
	upgrade.TRACTION:preload("res://scene/powerup/traction.tscn"),
	upgrade.HEADLIGHTS:preload("res://scene/powerup/headlights.tscn"),
	upgrade.OIL:preload("res://scene/powerup/oil.tscn"),
	upgrade.LUCK:preload("res://scene/powerup/luck.tscn"),
	upgrade.CLOVER:preload("res://scene/powerup/clover.tscn"),
	
	upgrade.COIN:preload("res://scene/powerup/coin.tscn"),
	upgrade.PURSE:preload("res://scene/powerup/purse.tscn"),
	upgrade.GEM:preload("res://scene/powerup/gem.tscn"),
	upgrade.SLOTMACHINE:preload("res://scene/powerup/slotMachine.tscn"),
	upgrade.CURRENTGOONSCRUSHED:preload("res://scene/powerup/currentGoonsCrushed.tscn"),
}
	
#extra drop weight per point of the luck ("Dice") stat; only prizes already in a goon's table are raised
const LUCK_WEIGHT_BONUS = { upgrade.PURSE: 0.3, upgrade.GEM: 0.1, upgrade.SLOTMACHINE: 0.02 }

#picks a drop from a goon's weight table, with the player's luck raising the high-value prizes.
#The caller's table is never changed.
func getPowerupFromWeights( powerupWeightDict:Dictionary ) -> Powerup:
	if powerupWeightDict.has(Pickups.ROLL): #a goon's drop: rarity tier, then item (scripts/global/pickups.gd)
		var info: Dictionary = powerupWeightDict[Pickups.ROLL]
		return Pickups.make(Pickups.rollForCar(info.get("faction", -1), info.get("bump", 0)))
	var carLuck = Root.playerCar.luck if is_instance_valid(Root.playerCar) else 0
	var weights = luckAdjustedWeights(powerupWeightDict, carLuck)
	var weightTotal := 0.0
	for i in weights: weightTotal += weights[i]
	var picked = pickWeighted(weights, randf() * weightTotal)
	if picked == null: picked = upgrade.COIN
	return powerup[picked].instantiate()

#a copy of `weights` with luck added to the high-value prizes; COIN and the rest keep their weight
static func luckAdjustedWeights(weights: Dictionary, luckStat: float) -> Dictionary:
	var adjusted = weights.duplicate()
	for key in LUCK_WEIGHT_BONUS:
		if adjusted.has(key): adjusted[key] += LUCK_WEIGHT_BONUS[key] * maxf(luckStat, 0.0)
	return adjusted

#the key whose cumulative weight range holds `roll` (0 <= roll < total); null for an empty table
static func pickWeighted(weights: Dictionary, roll: float):
	for key in weights:
		roll -= weights[key]
		if roll < 0.0: return key
	return weights.keys().back() if not weights.is_empty() else null

func getSpecificPowerup(pName: upgrade) -> Powerup:
	return powerup[pName].instantiate()


func getGoon():return spawnManager.getGoon()


var gameModeDescription: Dictionary = {
	Root.gameModes.GOONCRUSHER:{
		"name":"COUNTDOWN",
		"description":"Survive the countdown while crushing increasing powerful waves of goon.",
	},
	Root.gameModes.SPRINT:{
		"name":"SPRINT",
		"description":"Race against the goons, rocks, and clocks to reach the finish line.",
	},
	Root.gameModes.DEFENSE:{
		"name":"DEFENSE",
		"description":"Hold the station until the clock runs out. Goons march on its walls: crush them before they break through.",
	},
	Root.gameModes.MARATHON:{
		"name":"MARATHON",
		"description":"A relay of five stations. Each one refuels you, patches you up and adds time. Reach the last.",
	},
	Root.gameModes.GOONPOCALYPSE:{
		"name":"GOONPOCALYPSE",
		"description":"Endless, and it only gets worse. Survive twice the level's clock for the star, then chase your best score.",
	},
}
	
	
