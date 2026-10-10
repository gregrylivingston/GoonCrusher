extends SceneTree

#Runs every test_*.gd in tests/game and exits with the number of failed tests.
#  Godot_console.exe --headless --path . -s res://tests/game/run_tests.gd
#Autoloads (Settings, Root, SaveManager...) are loaded as usual. Tests must not write the save
#or the settings files; anything one does save goes to a scratch file (SaveManager.save_path). `-- --only=world_recipe` runs only the files whose names contain that text.
#Every test starts with every pickup unlocked (Unlocks.allOpen), whatever the save has opened; tests of
#the unlocks themselves turn it off.

const DIR = "res://tests/game/"

func _initialize():
	run.call_deferred()

func run() -> void:
	await process_frame #let the autoloads finish _ready
	root.get_node("SaveManager").save_path = "user://test_scratch_save.tres" #a test that buys through a menu flushes the save: never onto the player's
	var unlocks = load("res://scripts/global/unlocks.gd") #loaded, not named: naming it here compiles it before the autoloads exist
	var failed := 0
	var passed := 0
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	for file in DirAccess.get_files_at(DIR):
		if not file.begins_with("test_") || not file.ends_with(".gd"): continue
		if only != "" && not file.contains(only): continue
		var script = load(DIR + file)
		for method in script.get_script_method_list():
			if not method.name.begins_with("test_"): continue
			var test: GameTest = script.new()
			root.add_child(test)
			test.currentTest = file + " " + method.name
			unlocks.allOpen = true
			test.before_each()
			await test.call(method.name)
			test.after_each()
			test.freeAutofree()
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in test.failures: printerr("FAIL " + failure)
			test.queue_free()
			await process_frame
	print("GAME TESTS: %d passed, %d failed" % [passed, failed])
	quit(failed)
