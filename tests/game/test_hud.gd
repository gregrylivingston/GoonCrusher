extends GameTest

#The in-run HUD (scene/player/hud): every pickup has somewhere to fly, and the speedometer scale
#follows the car's top speed.

const HUD_SCENE := "res://scene/player/playerRoot.tscn"

#the HUD without a level: the run clock needs Root.levelRoot, so it goes. Free it before its 1 s wait
#for a car runs out.
func addHud() -> Node:
	var hud = load(HUD_SCENE).instantiate()
	hud.get_node("TopCenter/Timer").free()
	add_child(hud)
	await get_tree().process_frame
	return hud

#RewardFlyers aims a pickup at the first node in "<powerup>ui"; it must be a visible HUD widget,
#not the stat list that only shows while paused
func test_every_pickup_flies_to_a_hud_widget():
	var hud = await addHud()
	var carPanel = hud.get_node("carPanel")
	for path in DirAccess.get_files_at("res://scene/powerup/"):
		if not path.ends_with(".tscn") || path == "powerup.tscn": continue
		var sample = load("res://scene/powerup/" + path).instantiate()
		var group = sample.powerup + "ui"
		sample.free()
		var target = get_tree().get_first_node_in_group(group)
		assert_true(is_instance_valid(target), "nothing in %s (%s)" % [group, path])
		if is_instance_valid(target):
			assert_true(hud.is_ancestor_of(target), "%s is outside the HUD" % group)
			assert_false(carPanel.is_ancestor_of(target), "%s lands on the paused stat list" % group)
	hud.free()

func test_stat_pickups_land_on_their_lamp():
	var hud = await addHud()
	var systems = hud.get_node("Systems")
	for stat in ["headlights", "engine", "steering", "traction", "oil"]:
		assert_true(systems.is_ancestor_of(get_tree().get_first_node_in_group(stat + "ui")), stat)
	hud.free()

#a slow car gets a short scale and a fast one a long scale, always a multiple of 40
func test_speedometer_scale_follows_top_speed():
	var sedan = {"engine": 3, "friction": 0.1, "drag": 0.0005}
	var racer = {"engine": 50, "friction": 0.1, "drag": 0.0005}
	assert_almost_eq(HudDial.topSpeed(sedan), 770.0, 5.0, "sedan flat-out speed in px/s")
	assert_eq(HudDial.speedScaleFor(sedan), 120)
	assert_eq(HudDial.speedScaleFor(racer), 200)
	assert_eq(HudDial.speedScaleFor(racer) % 40, 0)

func test_condition_factor_floors():
	var car = load("res://scene/car/sedan/sedan.tscn").instantiate()
	assert_almost_eq(car.conditionFactor("tires"), 1.0, 0.001, "undamaged")
	car.setCondition("tires", 0.0)
	assert_almost_eq(car.conditionFactor("tires"), car.CONDITION_FLOOR.tires, 0.001, "wrecked keeps its floor")
	car.setCondition("tires", 150.0)
	assert_eq(car.condition.tires, 100.0, "clamped")
	car.free()
