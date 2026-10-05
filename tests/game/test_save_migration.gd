extends GameTest

#migrate() must bring demo-era saves up to date without losing progress. Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

func oldSave() -> PlayerData:
	var data = PlayerData.new()
	data.saveVersion = 0
	data.cars = data.cars.slice(0, 3)          #a save from before the later cars existed
	data.cars[1].cost = 0                       #van bought
	data.cars[2].cost = 999                     #taxi price changed since
	data.cars[0].records.erase("powerups")      #a record key added later
	data.cars[0].scene = "res://old/path/sedan.tscn"
	data.levels = data.levels.slice(0, 4)
	data.levels[3].unlocked = true
	data.levels[1].gamemodeBeat[Root.gameModes.GOONCRUSHER] = true
	data.selectedLevel = 40
	return data

func test_migrate_adds_and_updates_without_losing_progress():
	SaveManager.playerData = oldSave()
	assert_true(SaveManager.migrate())
	var data = SaveManager.playerData
	var defaults = PlayerData.new()
	assert_eq(data.cars.size(), defaults.cars.size(), "new cars are added")
	assert_eq(data.cars[1].cost, 0, "bought cars stay bought")
	assert_eq(data.cars[2].cost, defaults.cars[2].cost, "locked cars get the new price")
	assert_eq(data.cars[0].scene, defaults.cars[0].scene, "moved scenes are picked up")
	assert_true(data.cars[0].records.has("powerups"), "new record keys are added")
	assert_eq(data.levels.size(), defaults.levels.size())
	assert_true(data.levels[3].unlocked, "unlocks are kept")
	assert_true(data.levels[1].gamemodeBeat[Root.gameModes.GOONCRUSHER], "beaten modes are kept")
	assert_eq(data.selectedLevel, data.levels.size() - 1, "out-of-range selection is clamped")
	assert_eq(data.saveVersion, SaveManager.SAVE_VERSION)

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
