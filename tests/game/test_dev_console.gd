extends GameTest

#Dev console progress commands. SaveManager.playerData is swapped for a new save and the save path
#for a scratch file, so the player's save is never written.

const M = Root.gameModes
const SCRATCH = "user://test_console_save.tres"

var original: PlayerData
var originalPath: String

func before_each():
	original = SaveManager.playerData
	originalPath = SaveManager.save_path
	SaveManager.save_path = SCRATCH
	SaveManager.playerData = load("res://scene/player/save/playerData.tres").duplicate(true)

func after_each():
	SaveManager.playerData = original
	SaveManager.save_path = originalPath
	SaveManager.dirty = false
	Root.devAllModesAvailable = false
	DirAccess.remove_absolute(SCRATCH)

func test_console_is_loaded_in_debug_builds():
	assert_true(is_instance_valid(Console), "the Console autoload stays in a debug build")

func test_unlock_and_lock_cars():
	var cars = SaveManager.playerData.cars
	Console.execute("unlock cars")
	for car in cars: assert_eq(car.cost, 0, "%s unlocked" % car.name)
	Console.execute("lock cars")
	var defaults = PlayerData.new().cars
	for i in cars.size(): assert_eq(cars[i].cost, defaults[i].cost, "%s back to its price" % cars[i].name)
	Console.execute("unlock drivers van")
	assert_eq(SaveManager.getCarByName("van").cost, 0, "a named car unlocks")
	assert_gt(SaveManager.getCarByName("taxi").cost, 0, "the others stay locked")
	assert_true(Console.execute("unlock cars nosuchcar").begins_with("Error"), "an unknown car is an error")

func test_unlock_levels_and_modes():
	Console.execute("unlock levels;unlock modes")
	for level in SaveManager.playerData.levels:
		assert_true(level.unlocked, "%s unlocked" % level.name)
		for mode in [M.GOONCRUSHER, M.SPRINT, M.GOONPOCALYPSE, M.MARATHON, M.DEFENSE]:
			assert_true(Root.isModeUnlocked(level, mode), "%s open on %s" % [M.find_key(mode), level.name])
	assert_false(Root.isModePlayable(SaveManager.playerData.levels[0], M.MARATHON), "Marathon is still Coming Soon")
	Console.execute("unfinished on")
	assert_true(Root.isModePlayable(SaveManager.playerData.levels[0], M.MARATHON), "unfinished on lets it start")
	Console.execute("lock all")
	var defaults = PlayerData.new().levels
	for i in defaults.size():
		assert_eq(SaveManager.playerData.levels[i].unlocked, defaults[i].unlocked, "level %d back to the default" % i)
		assert_false(Root.isModeUnlocked(SaveManager.playerData.levels[i], M.SPRINT), "level %d: Sprint locked again" % i)

func test_coins_and_gems():
	Console.execute("coins 500")
	assert_eq(SaveManager.playerData.coin, 500)
	Console.execute("coins 50k")
	assert_eq(SaveManager.playerData.coin, 50500)
	Console.execute("coins -999999")
	assert_eq(SaveManager.playerData.coin, 0, "never below zero")
	Console.execute("coins set 1234")
	assert_eq(SaveManager.playerData.coin, 1234)
	Console.execute("gems 7")
	assert_eq(SaveManager.playerData.gem, 7)
	assert_true(Console.execute("coins lots").begins_with("Error"), "not a number")

func test_upgrades_max_and_reset():
	Console.execute("upgrades max")
	assert_eq(SaveManager.getUpgradeLevel(Root.upgrade.ENGINE), SaveManager.MAX_UPGRADE_LEVEL)
	assert_true(SaveManager.isUpgradeMaxed(Root.upgrade.LUCK))
	Console.execute("upgrades reset")
	assert_eq(SaveManager.getUpgradeLevel(Root.upgrade.ENGINE), 0)

func test_run_commands_need_a_run():
	for line in ["heal", "fuel", "give coin 5", "win", "lose", "night"]:
		assert_true(Console.execute(line).begins_with("Error"), "%s outside a run is an error" % line)

func test_unknown_command_and_help():
	assert_true(Console.execute("frobnicate").begins_with("Error"))
	var help = Console.execute("help")
	for cmd in ["unlock", "coins", "give", "win"]: assert_true(help.contains(cmd), "help lists " + cmd)
