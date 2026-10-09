extends GameTest

#The weathered side views (docs/CAR_ART.md, "Side views"): every car's CarInfo points at its baked
#<car>_side.png, which is the bake's size, has a clean alpha edge and stands on the bottom pad.

const SIZE := Vector2i(256, 96)
const PAD := 2

func carInfos() -> Array:
	var infos := []
	for dir in DirAccess.get_directories_at("res://scene/car/"):
		var path := "res://scene/car/%s/%s_info.tres" % [dir, dir]
		if ResourceLoader.exists(path): infos.append(load(path))
	return infos

func test_every_car_has_a_side_view_of_the_baked_size_with_alpha():
	var infos := carInfos()
	assert_eq(infos.size(), 9, "nine cars have a CarInfo")
	for info in infos:
		var pic: Texture2D = info.sidePic
		assert_true(pic != null, "%s has a sidePic" % info.carId)
		if pic == null: continue
		assert_eq(pic.resource_path, "res://scene/car/%s/art/%s_side.png" % [info.carId, info.carId], "%s points at its own side view" % info.carId)
		assert_eq(Vector2i(pic.get_size()), SIZE, "%s side view size" % info.carId)
		var img := pic.get_image()
		if img.is_compressed(): img.decompress()
		assert_true(img.detect_alpha() != Image.ALPHA_NONE, "%s side view has alpha" % info.carId)
		for corner in [Vector2i(0, 0), Vector2i(SIZE.x - 1, 0), Vector2i(0, SIZE.y - 1), Vector2i(SIZE.x - 1, SIZE.y - 1)]:
			assert_almost_eq(img.get_pixelv(corner).a, 0.0, 0.01, "%s side view corner %s is clear" % [info.carId, corner])
		var used := img.get_used_rect()
		assert_gt(used.size.x, SIZE.x / 2, "%s fills the frame across" % info.carId)
		assert_eq(used.end.y, SIZE.y - PAD, "%s stands on the bottom pad" % info.carId)
		assert_true(used.position.x >= PAD - 1 && used.end.x <= SIZE.x - PAD + 1 && used.position.y >= PAD - 1, "%s stays inside the pad" % info.carId)
