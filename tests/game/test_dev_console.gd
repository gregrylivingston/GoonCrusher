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
		for mode in Root.modePath(level):
			assert_true(Root.isModeUnlocked(level, mode), "%s open on %s" % [M.find_key(mode), level.name])
	assert_true(Root.isModePlayable(SaveManager.playerData.levels[0], M.MARATHON), "Marathon opens with Countdown beaten")
	assert_false(SaveManager.playerData.levels[0].gamemodeBeat[M.MARATHON], "unlock modes credits only Sprint and Countdown")
	Console.execute("unfinished on")
	assert_true(Root.isModePlayable(SaveManager.playerData.levels[1], M.CIRCUIT), "unfinished on lets any of the level's modes start")
	Console.execute("unfinished off")
	Console.execute("lock all")
	var defaults = PlayerData.new().levels
	for i in defaults.size():
		assert_eq(SaveManager.playerData.levels[i].unlocked, defaults[i].unlocked, "level %d back to the default" % i)
		assert_false(Root.isModeUnlocked(SaveManager.playerData.levels[i], M.GOONCRUSHER), "level %d: Countdown locked again" % i)

func test_levels_by_id():
	var levels = SaveManager.playerData.levels
	Console.execute("unlock levels city 3")
	assert_true(levels[Levels.indexOf(&"city")].unlocked, "a named level unlocks")
	assert_true(levels[3].unlocked, "an index works too")
	assert_false(levels[Levels.indexOf(&"crusher")].unlocked, "the others stay locked")
	assert_true(Console.execute("unlock levels nowhere").begins_with("Error"), "an unknown level is an error")
	assert_true(Console.execute("level").contains("frostbite"), "level lists the registry")
	Console.execute("level highway")
	assert_eq(SaveManager.playerData.selectedLevel, Levels.indexOf(&"highway"), "level selects by id")
	Console.execute("lock levels city")
	assert_false(levels[Levels.indexOf(&"city")].unlocked, "a named level locks")
	assert_true(levels[3].unlocked, "only the named one")
	var list := Console.execute("level")
	assert_true(list.contains("The Works") && list.contains("2-5"), "level lists by region and stop")

func test_unlock_region_opens_it_and_the_road_up_to_it():
	var levels = SaveManager.playerData.levels
	Console.execute("unlock region 3")
	for i in levels.size(): assert_eq(levels[i].unlocked, i < 15, "%s: open up to Raider Road's last stop" % levels[i].id)
	Console.execute("unlock region works")
	assert_true(levels[Levels.indexOf(&"crusher")].unlocked, "an id works too")
	Console.execute("lock region works")
	assert_false(levels[Levels.indexOf(&"crusher")].unlocked, "and locks it again")
	assert_true(levels[Levels.indexOf(&"city")].unlocked, "only that region")
	assert_true(Console.execute("unlock region 9").begins_with("Error"), "an unknown region is an error")

func test_cars_fills_car_clears():
	var data := SaveManager.playerData
	data.levels = Levels.defaultEntries()
	SaveManager.passTier(data.levels[0], M.GOONCRUSHER, ModeTiers.MEDIUM)
	SaveManager.passTier(data.levels[1], M.GOONCRUSHER, ModeTiers.EASY)
	data.selectedLevel = 0
	Console.execute("cars van")
	assert_eq(SaveManager.carClearTier(0, M.GOONCRUSHER, "van"), ModeTiers.MEDIUM, "the van clears the selected level on its best tier")
	assert_eq(SaveManager.carClearTier(1, M.GOONCRUSHER, "van"), ModeTiers.NONE, "only the selected level")
	Console.execute("cars all")
	assert_true(SaveManager.isFullGarage(1, M.GOONCRUSHER, ModeTiers.EASY), "all: every car on every level")
	assert_false(SaveManager.isFullGarage(1, M.SPRINT, ModeTiers.EASY), "only modes beaten there")
	assert_true(Console.execute("cars nosuchcar").begins_with("Error"))

func test_unlock_and_lock_goons():
	SaveManager.playerData.goonsCrushed = {"grunt": 5}
	Console.execute("unlock goons")
	for id in Goons.DATA: assert_true(Goonopedia.isDiscovered(id), "%s revealed" % id)
	assert_eq(SaveManager.playerData.goonsCrushed["grunt"], 5, "real crush counts are kept")
	Console.execute("lock goons")
	if not Goonopedia.REVEAL_ALL:
		for id in Goons.DATA: assert_false(Goonopedia.isDiscovered(id), "%s hidden again" % id)
	Console.execute("unlock all")
	assert_true(Goonopedia.isDiscovered(&"plowboss"), "unlock all includes the goons")

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
	for cmd in ["start", "unlock", "coins", "help"]: assert_true(help.contains(cmd), "help in the menu lists " + cmd)
	assert_false(help.contains("give <what>"), "but not the run's commands")
	var run = Console.execute("help run")
	for cmd in ["give", "win", "heal"]: assert_true(run.contains(cmd), "help run lists " + cmd)
	assert_false(run.contains("coins ["), "and not the menu's")
	var all = Console.execute("help all")
	for cmd in ["start", "coins", "give", "win"]: assert_true(all.contains(cmd), "help all lists " + cmd)
	assert_true(Console.execute("help start").contains("scratch save"), "one command explained")

func test_autopilot_checks_its_persona():
	assert_true(Console.execute("autopilot nobody").begins_with("Error"), "an unknown persona is an error")
	assert_eq(Console.execute("autopilot off"), "Autopilot isn't on")
	assert_true(Console.execute("help").contains("autopilot"), "help in the menu lists it")

func test_ailines_toggles_every_drivers_drawing():
	assert_eq(Console.execute("ailines off"), "AI lines off")
	assert_false(AIDriver.drawPlans)
	assert_eq(Console.execute("ailines"), "AI lines on", "bare ailines flips it")
	assert_true(AIDriver.drawPlans)

func test_start_lists_tiers_and_checks_them():
	var list = Console.execute("start")
	for tier in CareerStart.TIERS: assert_true(list.contains(tier), "start lists " + tier)
	assert_true(list.contains("the real save"), "and says which save is in use")
	assert_true(Console.execute("start nowhere").begins_with("Error"), "an unknown tier is an error")
	assert_eq(Console.execute("start real"), "Already playing the real save")

func test_play_lists_every_mode_and_refuses_what_it_cant_start():
	var listing: String = Console.execute("play")
	for id in Modes.IDS: assert_true(listing.contains(id), "play lists %s" % id)
	assert_true(listing.contains("e.g. "), "with a level that features each")
	assert_true(Console.execute("play nonsense").begins_with("Error"), "an unknown mode is an error")
	assert_eq(Console.firstLevelWith(Root.gameModes.FLATOUT), Levels.indexOf(&"stilttown"), "Flat Out's first level is Stilt Town, which opens on it")
	assert_eq(Console.firstLevelWith(Root.gameModes.MARATHON), 0)
