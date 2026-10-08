extends GameTest

#migrate() must bring saves up to date without losing progress; saves from before the unlocks (version 6)
#start over (SaveManager.isObsolete). Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

#a save of the current version, with progress, a missing car, a stale price and an old record key
func oldSave() -> PlayerData:
	var data = PlayerData.new()
	data.saveVersion = SaveManager.SAVE_VERSION
	data.coin = 1234
	data.gem = 7
	data.cars = data.cars.slice(0, 5)          #a save from before the later cars existed
	data.cars[1].cost = 0                       #van bought
	data.cars[1].upgrades = {Root.upgrade.ENGINE: 3}
	data.cars[2].cost = 999                     #taxi price changed since
	data.cars[4].gems = 1                       #and the semi's gem price
	data.cars[0].records.erase("powerups")      #a record key added later
	data.cars[0].scene = "res://old/path/sedan.tscn"
	data.levels[1].unlocked = true
	data.levels[1].gamemodeBeat.erase(Root.gameModes.DEFENSE) #a key missing for any reason
	data.meta.erase("unlocks")
	data.selectedLevel = 40
	data.gameMode = 99
	return data

func test_migrate_adds_and_updates_without_losing_progress():
	SaveManager.playerData = oldSave()
	assert_true(SaveManager.migrate())
	var data = SaveManager.playerData
	var defaults = PlayerData.new()
	assert_eq(data.cars.size(), defaults.cars.size(), "new cars are added")
	assert_eq(data.cars[1].cost, 0, "bought cars stay bought")
	assert_eq(data.cars[1].upgrades, {Root.upgrade.ENGINE: 3}, "upgrades are kept")
	assert_eq(data.cars[2].cost, defaults.cars[2].cost, "locked cars get the new price")
	assert_eq(data.cars[4].gems, defaults.cars[4].gems, "and the new gem price")
	assert_eq(data.cars[0].scene, defaults.cars[0].scene, "moved scenes are picked up")
	assert_true(data.cars[0].records.has("powerups"), "new record keys are added")
	assert_true(data.meta.get("unlocks") is Dictionary, "the unlocks section is added")
	assert_true(data.levels[1].unlocked, "opened levels stay open")
	assert_true(data.levels[1].gamemodeBeat.has(Root.gameModes.DEFENSE), "missing mode keys come back")
	assert_eq(data.coin, 1234, "coins are kept")
	assert_eq(data.gem, 7, "gems are kept")
	assert_eq(data.selectedLevel, data.levels.size() - 1, "out-of-range selection is clamped")
	assert_between(data.gameMode, 0, Root.gameModes.size() - 1, "out-of-range mode is clamped")
	assert_eq(data.saveVersion, SaveManager.SAVE_VERSION)

func test_saves_from_before_the_unlocks_start_over():
	for version in [0, 4, 5]:
		var data = PlayerData.new()
		data.saveVersion = version
		assert_true(SaveManager.isObsolete(data), "a version %d save is replaced by a new one" % version)
	var current = PlayerData.new()
	current.saveVersion = SaveManager.SAVE_VERSION
	assert_false(SaveManager.isObsolete(current), "a current save is kept")

func test_registry_saves_keep_progress_by_id():
	var data = PlayerData.new()
	data.levels[2].gamemodeBeat[Root.gameModes.SPRINT] = true
	data.levels[5].unlocked = true
	data.levels.reverse() #order no longer matters once entries carry ids
	data.levels.push_back({"id": "removed_level", "unlocked": true, "gamemodeBeat": {}})
	SaveManager.playerData = data
	SaveManager.migrate()
	assert_eq(data.levels.size(), Levels.count(), "unknown ids are dropped")
	assert_eq(data.levels[2].id, String(Levels.ORDER[2]), "back in registry order")
	assert_true(data.levels[2].gamemodeBeat[Root.gameModes.SPRINT], "beaten modes are kept")
	assert_true(data.levels[5].unlocked, "unlocks are kept")
	assert_false(data.levels[6].unlocked)

func test_new_save_levels_come_from_the_registry():
	var levels = PlayerData.new().levels
	assert_eq(levels.size(), Levels.count())
	for i in levels.size():
		assert_eq(levels[i].id, String(Levels.ORDER[i]))
		assert_eq(levels[i].unlocked, i == 0, "%s: only the first level starts open" % levels[i].id)

func test_a_clamped_mode_alone_counts_as_a_change():
	var data = PlayerData.new()
	data.saveVersion = SaveManager.SAVE_VERSION
	SaveManager.playerData = data
	SaveManager.migrate()
	data.gameMode = 99
	assert_true(SaveManager.migrate(), "the clamped mode is saved")

func test_migrate_is_idempotent():
	SaveManager.playerData = oldSave()
	SaveManager.migrate()
	assert_false(SaveManager.migrate(), "a second pass changes nothing")

func test_last_level_pass_does_not_read_past_the_end():
	var data = PlayerData.new()
	data.selectedLevel = data.levels.size() - 1
	SaveManager.playerData = data
	SaveManager.currentLevelPassed()
	assert_true(data.levels[data.selectedLevel].gamemodeBeat[data.gameMode])
