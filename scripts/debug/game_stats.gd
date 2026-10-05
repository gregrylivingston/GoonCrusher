class_name GameStats extends RefCounted

#cheap counters shared by the benchmark harness, the F3 overlay and the editor Monitors tab

static func goons() -> int:
	if is_instance_valid(Root.spawnManager): return Root.spawnManager.liveGoons
	return 0

static func chunks() -> int:
	if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_node("TileManager"):
		return Root.levelRoot.get_node("TileManager").loadedLandscapes.size()
	return 0

#walks the tree, so only call this a few times per second
static func lights(tree: SceneTree) -> int:
	var count = 0
	for light in tree.root.find_children("*", "PointLight2D", true, false):
		if light.is_visible_in_tree(): count += 1
	return count

static func registerMonitors(tree: SceneTree) -> void:
	if Performance.has_custom_monitor("game/goons"): return
	Performance.add_custom_monitor("game/goons", goons)
	Performance.add_custom_monitor("game/chunks", chunks)
	Performance.add_custom_monitor("game/lights", lights.bind(tree))
