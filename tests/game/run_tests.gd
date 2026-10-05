extends SceneTree

#Runs every test_*.gd in tests/game and exits with the number of failed tests.
#  Godot_console.exe --headless --path . -s res://tests/game/run_tests.gd
#Autoloads (Settings, Root, SaveManager...) are loaded as usual. Tests must not write the save
#or the settings files.

const DIR = "res://tests/game/"

func _initialize():
	run.call_deferred()

func run() -> void:
	await process_frame #let the autoloads finish _ready
	var failed := 0
	var passed := 0
	for file in DirAccess.get_files_at(DIR):
		if not file.begins_with("test_") || not file.ends_with(".gd"): continue
		var script = load(DIR + file)
		for method in script.get_script_method_list():
			if not method.name.begins_with("test_"): continue
			var test: GameTest = script.new()
			root.add_child(test)
			test.currentTest = file + " " + method.name
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
