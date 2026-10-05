extends GameTest

#A reel recycles icons that scroll off the top, so a long spin keeps a fixed node count and
#still stops with the active icon in the same place.

func test_long_spin_recycles_icons_and_stops_aligned():
	var scene = load("res://scene/player/slots/slot_row.tscn")
	var short = add_child_autofree(scene.instantiate())
	var long = add_child_autofree(scene.instantiate())
	while not short.isSpinning: await get_tree().physics_frame
	for i in 30: await get_tree().physics_frame
	short.stopSpinning()
	for i in 270: await get_tree().physics_frame
	long.stopSpinning()
	for row in [short, long]:
		while row.spinFrameTracker != 6: await get_tree().physics_frame
	await get_tree().process_frame
	var box = long.get_node("VBoxContainer")
	assert_true(box.get_child_count() <= long.MAX_ROW_CHILDREN, "row has %d children" % box.get_child_count())
	assert_eq(long.spins, box.get_child_count() - 2, "active icon is second from the bottom")
	var shortActive = short.get_node("VBoxContainer").get_child(short.spins)
	var longActive = box.get_child(long.spins)
	assert_eq(longActive.texture, long.getActiveTexture())
	assert_eq(short.get_node("VBoxContainer").position.y + shortActive.position.y, box.position.y + longActive.position.y, "active icon stops at the same height")
