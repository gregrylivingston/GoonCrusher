extends GameTest

#migrate() must bring demo-era saves up to date without losing progress. Nothing is written:
#SaveManager.playerData is swapped for a test copy and restored.

var original: PlayerData

func before_each():
	original = SaveManager.playerData

func after_each():
	SaveManager.playerData = original
	SaveManager.dirty = false

#a level entry as saves before the level registry (version 5) wrote them: no id, keyed by scene name
func legacyLevel(levelName: String, key: String, unlocked: bool) -> Dictionary:
	var beat := {}
	for mode in Root.gameModes.values(): beat[mode] = false
	return {"name": levelName, "image": "res://texture/background/old.png", "unlocked": unlocked,
		"scene": "res://scene/level/levels/%s.tscn" % key, "gamemodeBeat": beat}

func oldSave() -> PlayerData:
	var data = PlayerData.new()
	data.saveVersion = 4
	data.coin = 1234
	data.gem = 7
	data.cars = data.cars.slice(0, 3)          #a save from before the later cars existed
	data.cars[1].cost = 0                       #van bought
	data.cars[1].upgrades = {Root.upgrade.ENGINE: 3}
	data.cars[2].cost = 999                     #taxi price changed since
	data.cars[0].records.erase("powerups")      #a record key added later
	data.cars[0].scene = "res://old/path/sedan.tscn"
	data.levels = [legacyLevel("Easy", "level_grass_1", true), legacyLevel("Medium", "level_grass_2", true),
		legacyLevel("Hard", "level_grass_3", true), legacyLevel("Muddy Barrens", "level_mud_1", false)]
	data.levels[0].time = "1"                   #a stray field the old defaults had
	data.levels[3].unlocked = true
	data.levels[1].gamemodeBeat[Root.gameModes.GOONCRUSHER] = true
	for level in data.levels: level.gamemodeBeat.erase(Root.gameModes.GOONPOCALYPSE) #saves before version 2 had no key
	data.levels[2].gamemodeBeat.erase(Root.gameModes.DEFENSE) #and a key missing for any other reason
	data.meta.records = {"goonpocalypse": {"level_grass_2": {"van": {"time": 300, "score": 90}}}, "speedtrap": {"level_mud_1": 88}}
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
	assert_eq(data.cars[0].scene, defaults.cars[0].scene, "moved scenes are picked up")
	assert_true(data.cars[0].records.has("powerups"), "new record keys are added")
	assert_eq(data.coin, 1234, "coins are kept")
	assert_eq(data.gem, 7, "gems are kept")
	assert_eq(data.selectedLevel, data.levels.size() - 1, "out-of-range selection is clamped")
	assert_between(data.gameMode, 0, Root.gameModes.size() - 1, "out-of-range mode is clamped")
	assert_eq(data.saveVersion, SaveManager.SAVE_VERSION)

func test_old_levels_become_the_registry_levels():
	SaveManager.playerData = oldSave()
	SaveManager.migrate()
	var data = SaveManager.playerData
	assert_eq(data.levels.size(), Levels.count(), "one entry per registry level")
	for i in data.levels.size():
		var level: Dictionary = data.levels[i]
		var def := Levels.defAt(i)
		assert_eq(level.id, String(Levels.ORDER[i]), "entry %d has its id" % i)
		assert_eq(level.scene, Levels.scenePath(Levels.ORDER[i]), "%s plays its thin scene" % level.id)
		assert_eq(level.name, def.displayName, "%s takes its name from the def" % level.id)
		assert_eq(level.image, def.poster, "%s takes its poster from the def" % level.id)
		assert_false(level.has("time"), "stray fields are dropped")
		for mode in Root.gameModes.values():
			assert_true(level.gamemodeBeat.has(mode), "%s gets a %s key" % [level.id, Root.gameModes.find_key(mode)])
			assert_false(level.gamemodeBeat[mode], "%s: beaten modes reset, it is a new level" % level.id)
	for i in 4: assert_true(data.levels[i].unlocked, "unlocked index %d stays unlocked" % i)
	for i in range(4, data.levels.size()): assert_false(data.levels[i].unlocked, "index %d stays locked" % i)

func test_old_level_records_move_to_the_new_ids():
	SaveManager.playerData = oldSave()
	SaveManager.migrate()
	var records: Dictionary = SaveManager.playerData.meta.records
	assert_false(records.goonpocalypse.has("level_grass_2"), "the old key is gone")
	assert_eq(records.goonpocalypse.get(String(Levels.ORDER[1]), {}), {"van": {"time": 300, "score": 90}}, "moved to the level at the old index")
	assert_eq(SaveManager.bestGoonpocalypse(1, "van"), {"time": 300, "score": 90}, "and read back through levelKey")
	assert_eq(records.speedtrap.get(String(Levels.ORDER[3]), 0), 88)

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
		assert_eq(levels[i].unlocked, i < Root.DEMO_LEVEL_COUNT, "%s: the demo's levels start open" % levels[i].id)

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
