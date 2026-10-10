extends GameTest

#The capture kit (docs/PROMO.md): it must stay out of a normal run and out of the exported game, and its
#small parts (the tape, the clean feed, the camera rigs, the shot files) must hold their shapes.

const SESSION := "res://promo/capture/session.gd"
const SCRATCH_TAPE := "user://test_capture.tape"

func after_each():
	DirAccess.remove_absolute(SCRATCH_TAPE)
	for action in ["Accelerate", "TurnLeft"]:
		if Input.is_action_pressed(action): Input.action_release(action)

func test_capture_is_inert_without_its_flag():
	var root = (Engine.get_main_loop() as SceneTree).root
	assert_false(root.has_node("Capture"), "the Capture autoload frees itself in a run without --capture")
	assert_false(TileManager.steady, "steady streaming is the capture kit's alone")
	assert_false(Transition.forceShown, "nothing forces the doors in a normal run")

func test_the_export_leaves_promo_out():
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("promo/*"), "export_presets.cfg excludes promo/")
	#the autoload ships, so it may not name a class that lives in promo/ (the build would not parse)
	var entry := FileAccess.get_file_as_string("res://scripts/debug/capture.gd")
	assert_false(entry.contains("Tape"), "capture.gd doesn't name promo's Tape class")
	for shipped in ["res://scripts/capture/clean_feed.gd", "res://scripts/capture/director_camera.gd"]:
		assert_false(FileAccess.get_file_as_string(shipped).contains("res://promo"), "%s doesn't reach into promo/" % shipped)

func test_tape_round_trip():
	var tape := Tape.new()
	assert_true(tape.actions.has("Accelerate"), "a tape listens to the driving actions")
	assert_false(tape.actions.has("ui_text_submit"), "and not to text editing")
	Input.action_press("Accelerate")
	tape.listen(1, null)
	Input.action_press("TurnLeft", 0.5)
	tape.listen(2, null)
	tape.listen(3, null) #nothing changed: nothing written
	Input.action_release("Accelerate")
	tape.listen(4, null)
	assert_eq(tape.lines.size(), 3, "only changes are taped")
	tape.bookmarks.push_back({"tick": 3, "label": "mark 1"})
	tape.write(ProjectSettings.globalize_path(SCRATCH_TAPE), {"level": "prairie", "seed": 7}, 4)
	var back := Tape.read(ProjectSettings.globalize_path(SCRATCH_TAPE))
	assert_true(back != null, "the tape reads back")
	assert_eq(back.ticks, 4)
	assert_eq(str(back.header.level), "prairie")
	assert_eq(back.bookmarks.size(), 1)
	assert_eq(back.changes[2][0][0], "TurnLeft")
	assert_almost_eq(back.changes[2][0][1], 0.5, 0.001)
	Input.action_release("TurnLeft")
	back.play(1, null)
	assert_true(Input.is_action_pressed("Accelerate"), "playing a tape holds its keys")
	back.play(4, null)
	assert_false(Input.is_action_pressed("Accelerate"), "and lets them go")

func test_clean_feed_modes():
	var ui := CanvasLayer.new()
	var version := Label.new()
	version.name = "VersionTracker"
	var tach := Control.new()
	tach.name = "Tach"
	var lamps := CanvasLayer.new()
	for node in [version, tach, lamps, AnimationPlayer.new()]: ui.add_child(node)
	CleanFeed.apply(ui, "minimal")
	assert_true(CleanFeed.isConcealed(version), "minimal takes out the version line")
	assert_false(CleanFeed.isConcealed(tach), "minimal keeps the instruments")
	CleanFeed.apply(ui, "off")
	assert_eq(tach.visibility_layer, 0, "off takes the instruments out of the picture")
	assert_false(lamps.visible, "and the start lamps")
	tach.visible = true #a widget showing itself mid-run doesn't bring it back
	assert_eq(tach.visibility_layer, 0)
	CleanFeed.apply(ui, "full")
	assert_eq(tach.visibility_layer, 1, "full puts the HUD back")
	assert_eq(version.visibility_layer, 1)
	assert_true(lamps.visible)
	ui.free()

func test_director_camera_rigs():
	assert_eq(DirectorCamera.pair([3, 4]), Vector2(3, 4))
	assert_eq(DirectorCamera.pair("nonsense"), Vector2.ZERO)
	var car := Node2D.new()
	car.global_position = Vector2(100, 50)
	var camera := DirectorCamera.new()
	camera.car = car
	camera.setRig({"rig": "tripod", "zoom": [0.9, 0.45], "seconds": 2.0, "ahead": 1000})
	assert_almost_eq(camera.zoom.x, 0.9, 0.001, "a push starts at its first zoom")
	assert_eq(camera.anchor, Vector2(1100, 50), "a tripod stands ahead of the car")
	camera._process(2.0)
	assert_almost_eq(camera.zoom.x, 0.45, 0.001, "and ends at its second")
	assert_eq(camera.global_position, Vector2(1100, 50), "a tripod doesn't follow")
	camera.setRig({"rig": "follow", "zoom": 0.5, "smooth": 1.0, "offset": [0, 100]})
	camera._process(0.016)
	assert_almost_eq(camera.global_position.y, 50.0 - 100.0 / 0.5, 0.01, "an offset sits the car off center by that many screen px")
	camera.free()
	car.free()

func test_frame_shapes():
	var session = load(SESSION)
	assert_eq(session.logicalFor(Vector2i(3840, 2160)), Vector2i(1600, 900), "16:9 is the game's own canvas")
	assert_eq(session.logicalFor(Vector2i(1080, 1920)), Vector2i(900, 1600), "a tall frame keeps 900 on its short side")
	assert_eq(session.logicalFor(Vector2i(1080, 1080)), Vector2i(900, 900))

func test_shot_files_are_well_formed():
	var dir := DirAccess.open("res://promo/shots")
	assert_true(dir != null, "promo/shots exists")
	var files := 0
	for file in dir.get_files():
		if not file.ends_with(".json"): continue
		files += 1
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://promo/shots/" + file))
		assert_true(data is Dictionary && data.has("shots"), "%s is a shot file" % file)
		if not data is Dictionary: continue
		var ids := {}
		for shot in data.shots:
			var merged: Dictionary = data.get("defaults", {}).duplicate()
			merged.merge(shot, true)
			assert_true(shot.has("id") && not ids.has(shot.id), "%s: every shot has its own id (%s)" % [file, shot.get("id", "?")])
			ids[shot.get("id", "")] = true
			if merged.get("kind", "shot") == "shot":
				assert_true(Levels.resolve(str(merged.get("level", ""))) != &"", "%s/%s: level %s exists" % [file, shot.get("id"), merged.get("level")])
				var carName := str(merged.get("car", ""))
				assert_true(SaveManager.playerData.cars.any(func(c): return c.name == carName), "%s/%s: car %s exists" % [file, shot.get("id"), carName])
	assert_gt(files, 3, "the starter shot files are there")
