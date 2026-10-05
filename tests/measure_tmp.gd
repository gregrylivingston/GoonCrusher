extends SceneTree

#cold-load split for menu cars: the menu-only assets (portrait, background, intro voice) vs the whole car scene
#run once per car index in a fresh process: -- --car=N

func _initialize():
	run.call_deferred()

func run() -> void:
	await process_frame
	var cars = root.get_node("SaveManager").playerData.cars
	var index = int(OS.get_cmdline_user_args()[0].get_slice("=", 1))
	var path = cars[index].scene
	#find the menu assets' paths from the scene state without loading the scene's dependencies
	var deps = ResourceLoader.get_dependencies(path)
	var menuAssets = []
	for d in deps:
		var p = d.get_slice("::", 2) if d.contains("::") else d
		if p.contains("char_") || p.contains("background") || p.contains("backgrond") || p.ends_with(".mp3") || p.ends_with(".wav") || p.ends_with(".ogg"):
			menuAssets.push_back(p)
	var t = Time.get_ticks_usec()
	for p in menuAssets: load(p)
	var tm = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	load(path)
	var ts = Time.get_ticks_usec() - t
	print("CARLOAD %s menu_assets=%d files %dus, rest_of_scene=%dus" % [path.get_file(), menuAssets.size(), tm, ts])
	quit(0)
