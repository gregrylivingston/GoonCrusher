extends Node

#append only: saves key beaten modes, tiers and car clears by these numbers. Modes (scripts/global/modes.gd) holds
#each mode's id, category and rules; a level plays Sprint, Countdown and its three featured modes (modePath)
enum gameModes {  GOONCRUSHER , SPRINT, MARATHON, DEFENSE, GOONPOCALYPSE, BLACKOUT, BOUNTY, RALLY, FLATOUT, HOTLAP, DRIFT, CONES, SMASH, CANNONBALL, CIRCUIT, DERBY, KNOCKOUT, KEEPCUP, PURSUIT }
enum endCondition { NOGAS , NOHEALTH , NOTIME , SUCCESS , ABANDONED , BASEDESTROYED , OUTRUN } #append only: the values are ints
enum upgrade { HEALTH , FUEL , ARMOR , ENGINE , TRACTION , STEERING , CLOVER , LUCK , HEADLIGHTS , OIL , COIN , PURSE , GEM , SLOTMACHINE, CURRENTGOONSCRUSHED}
enum terrain { GRASS , SAND , MUD , WATER , HILLS , MOSS , DIRT , SNOW, ASPHALT, ICE, OIL, SHALLOWS, WASH, CONVEYOR, MUDPIT, DEEPSNOW, LOT, BUILDING, BRIDGE, WADE } #append only: World.TERRAIN and Goons.T mirror it

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
const DEMO_CAR_COUNT := 3 #the demo offers the first 3 cars and the first 2 regions (10 levels)
const DEMO_LEVEL_COUNT := 10
#modes that are finished enough to play. An unavailable mode shows "Coming soon" whatever its
#unlocks, can't be started, and doesn't count toward unlocking other modes or the next level.
const MODE_AVAILABLE = {
	gameModes.GOONCRUSHER: true,
	gameModes.SPRINT: true,
	gameModes.GOONPOCALYPSE: true,
	gameModes.MARATHON: true,
	gameModes.DEFENSE: true,
	gameModes.BLACKOUT: true,
	gameModes.BOUNTY: true,
	gameModes.RALLY: true,
	gameModes.FLATOUT: true,
	gameModes.HOTLAP: true,
	gameModes.DRIFT: true,
	gameModes.CONES: true,
	gameModes.SMASH: true,
	gameModes.CANNONBALL: true,
	gameModes.CIRCUIT: true,
	gameModes.DERBY: true,
	gameModes.KNOCKOUT: true,
	gameModes.KEEPCUP: true,
	gameModes.PURSUIT: true,
}

static func versionText() -> String:
	return ("Demo " + GAME_VERSION) if IS_DEMO else GAME_VERSION

#dev console `unfinished on`: Coming Soon modes can be started. Session only, never saved.
static var devAllModesAvailable := false

#the demo plays every mode its levels feature
static func isModeAvailable(mode: int) -> bool:
	if devAllModesAvailable: return true
	return MODE_AVAILABLE.get(mode, false)

#how many of a level's modes are openers: the first is open with the level, the second behind it
const OPENER_SLOTS := 2

## The modes a level plays, in the order a player meets them and the menus show them: its two openers
## (LevelDef.openers; Sprint then Countdown unless it names others), then its featured Crusher, Trial and Goon
## Cup mode (LevelDef.featured). The one list every menu, harness and test reads. `level` is a save entry (its
## "id") or a level index; an entry with no id has only the default openers.
static func modePath(level) -> Array:
	var def: LevelDef = null
	if level is int: def = Levels.defAt(level)
	elif level is Dictionary && level.has("id"): def = Levels.get_def(StringName(str(level.id)))
	return Modes.openers(def) + (Modes.featured(def) if def else [])

## The mode open on an unlocked level from the start: where a new level begins
static func firstMode(level) -> int:
	return modePath(level)[0]

## A level's two openers
static func openerModes(level) -> Array:
	return modePath(level).slice(0, OPENER_SLOTS)

## A level's featured modes: the ones behind its second opener, any of which opens the next level
static func featuredModes(level) -> Array:
	return modePath(level).slice(OPENER_SLOTS)

## The modes whose win opens the next level: the featured ones that can be played. A level none of whose
## featured modes is finished yet opens the road on its second opener, so unfinished modes never block it.
static func roadModes(level) -> Array:
	var road := featuredModes(level).filter(func(m): return isModeAvailable(m))
	return road if not road.is_empty() else [modePath(level)[OPENER_SLOTS - 1]]

#the per-level unlock chain, ignoring availability. The first opener is open on any unlocked level, the second
#needs the first beaten, and the level's three featured modes need the second. A mode the level doesn't play
#is shut here (Free Play opens those: freePlayOpen).
static func isModeUnlocked(level: Dictionary, mode: int) -> bool:
	if not level.get("unlocked", false): return false
	var path := modePath(level)
	var slot := path.find(mode)
	if slot < 0: return false
	var beat: Dictionary = level.get("gamemodeBeat", {})
	if beat.get(mode, false): return true #a mode already beaten stays open
	if slot == 0: return true
	return beat.get(path[mini(slot, OPENER_SLOTS) - 1], false)

## Free Play: every mode the level plays (and that can be played) is won, so any other mode can be driven
## here. A Free Play run pays its coins and nothing else: no medal, clear, record or unlock (Level.freePlay).
static func freePlayOpen(level: Dictionary) -> bool:
	if not level.get("unlocked", false): return false
	var path := modePath(level).filter(func(m): return isModeAvailable(m))
	return not path.is_empty() && modesBeaten(level) >= path.size()

## The modes Free Play offers on a level: every built mode it doesn't play, in Root.gameModes order
static func freePlayModes(level) -> Array:
	var path := modePath(level)
	return gameModes.values().filter(func(m): return m not in path && isModeAvailable(m))

## Is this mode on this level a Free Play run (one the level doesn't play). An entry with no id names no
## level, so nothing is Free Play there.
static func isFreePlay(level, mode: int) -> bool:
	if level is Dictionary && not level.has("id"): return false
	return mode not in modePath(level)

## Modes beaten on a level, counting only those it plays that can be played
static func modesBeaten(level: Dictionary) -> int:
	var beat: Dictionary = level.get("gamemodeBeat", {})
	return modePath(level).filter(func(m): return beat.get(m, false) && isModeAvailable(m)).size()

## Is the level a region's finale (its 5th stop), which opens the next region only on Medium
static func isFinale(level: Dictionary) -> bool:
	var def := Levels.get_def(StringName(str(level.get("id", "")))) if level.has("id") else null
	return def != null && def.isFinale()

## The tier a road mode must be won on here to open the next level: Medium at a finale, else any
static func tierToOpenNext(level: Dictionary) -> int:
	return ModeTiers.MEDIUM if isFinale(level) else ModeTiers.EASY

## The best tier won here on any road mode
static func roadTier(level: Dictionary) -> int:
	var best := ModeTiers.NONE
	for mode in roadModes(level): best = maxi(best, ModeTiers.best(level, mode))
	return best

## Has this level done enough to open the one after it: one of its road modes won, on Medium at a finale
static func opensNextLevel(level: Dictionary) -> bool:
	return roadTier(level) >= tierToOpenNext(level)

## "Marathon, Rally Stage or Cannonball": the level's road modes by name
static func roadText(level: Dictionary) -> String:
	var names := roadModes(level).map(func(m): return modeName(m))
	if names.size() < 2: return "".join(names)
	return ", ".join(names.slice(0, -1)) + " or " + names[-1]

## A mode's name as a sentence writes it: "Rally Stage"
static func modeName(mode: int) -> String:
	return Modes.title(mode)

## The rule that opens the next level, for a locked poster: "Win Marathon, Rally Stage or Cannonball on the
## level before it to unlock", "... on Medium ..." after a finale
static func openRuleText(level: Dictionary) -> String:
	return "Win %s on the level before it%s to unlock" % [roadText(level), " on Medium" if isFinale(level) else ""]

## What is left here before the next level opens, or "" when nothing is: "Win Marathon, Rally Stage or
## Cannonball here", "... on Medium here"
static func openLeftText(level: Dictionary) -> String:
	if opensNextLevel(level): return ""
	return "Win %s%s here" % [roadText(level), " on Medium" if isFinale(level) else ""]

#can this mode be started on this level from the menu
static func isModePlayable(level: Dictionary, mode: int) -> bool:
	if not isModeAvailable(mode): return false
	return isModeUnlocked(level, mode) || (isFreePlay(level, mode) && freePlayOpen(level))

#why a mode can't be started, for the menu; "" when it can
static func modeLockReason(level: Dictionary, mode: int) -> String:
	if not isModeAvailable(mode): return "Coming Soon"
	if isModePlayable(level, mode): return ""
	if not level.get("unlocked", false): return "Level Locked"
	var path := modePath(level)
	var slot := path.find(mode)
	if slot < 0: return "Win All Five Modes Here"
	return "Beat %s To Unlock" % modeName(path[mini(slot, OPENER_SLOTS) - 1])

#coins a run pays: its coins times the star multiplier, x1 plus STAR_BONUS a star, up to STAR_MULT_MAX (20 stars).
#Was coins x stars, which paid six-figure runs by the sixth level (career playtests);
#uncapped, a 15-minute Goonpocalypse (a star a minute and ever more coins) still paid 33,000-50,000.
const STAR_BONUS := 0.1
const STAR_MULT_MAX := 3.0
static func payoutMultiplier(star: int) -> float:
	return minf(1.0 + STAR_BONUS * maxi(0, star), STAR_MULT_MAX)

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


#how a run in each mode is won and lost (Level Options shows it after the mode's description), and each mode's
#name and description: all from Modes.DATA
var MODE_RULES: Dictionary = Modes.rulesTexts()
var gameModeDescription: Dictionary = Modes.descriptions()
