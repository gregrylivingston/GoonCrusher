extends SceneTree

func _initialize():
	run.call_deferred()

func run() -> void:
	await process_frame
	var infoScript = load("res://scene/car/car_info.gd")
	for car in root.get_node("SaveManager").playerData.cars:
		var path: String = car.scene
		var inst = load(path).instantiate()
		var info = infoScript.new()
		for field in infoScript.FIELDS:
			if field == "introAudio":
				var arr: Array[AudioStreamMP3] = []
				for a in inst.introAudio: arr.push_back(a)
				info.introAudio = arr
			else:
				info.set(field, inst.get(field))
		var out = path.get_base_dir() + "/" + path.get_file().get_basename() + "_info.tres"
		var err = ResourceSaver.save(info, out)
		print("CARINFO %s -> %s err=%d carId=%s engine=%d profile=%s" % [path, out, err, info.carId, info.engine, info.profilePic.resource_path if info.profilePic else "none"])
		inst.free()
	quit(0)
