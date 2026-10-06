extends GameTest

#Lighting levels must never change what the Headlights upgrade does, and Reward Pop-up levels
#must never change what is credited.

var saved: Dictionary
var savedCar

func before_each():
	saved = Settings.values.duplicate(true)
	savedCar = Root.playerCar

func after_each():
	for key in saved: Settings.values[key] = saved[key]
	Settings.apply_all()
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null

func test_headlight_cone_scales_with_the_upgrade_at_every_lighting_level():
	var car = load("res://scene/car/sedan/sedan.tscn").instantiate()
	add_child_autofree(car)
	car.headlights = 40
	car.setHeadlightStrength()
	var lamps = car.get_node("headlamps/headlights").get_children().filter(func(n): return n is PointLight2D)
	for level in 3:
		Settings.set_value("gfx/lighting", level, false)
		assert_eq(car.get_node("headlamps/headlights").scale, Vector2(1.4, 1.4), "headlight reach at level %d" % level)
		var lit = lamps.filter(func(l): return l.enabled)
		assert_gt(lit.size(), 0, "some headlight is on at level %d" % level)
		for lamp in lit:
			assert_eq(lamp.shadow_enabled, level >= 1, "headlamp shadows at level %d" % level)
	Settings.set_value("gfx/lighting", 0, false)
	assert_true(car.get_node("headlamps/carhighlight").enabled, "the car stays visible at night on Low")

class FakeCar extends CharacterBody2D:
	var coin := 0
	var currentGoonsCrushed := 0
	var calls := 0
	func getIsPlayer(): return true
	func playPurseRewardAudio(): pass
	func reward(powerup: String, quantity, _forShowOnly := false):
		self[powerup] += int(quantity)
		calls += 1

func test_coins_are_credited_the_same_at_every_reward_popup_level():
	for level in 3:
		Settings.set_value("gfx/reward_fx", level, false)
		var car = FakeCar.new()
		add_child_autofree(car)
		for i in 25:
			var coin = Root.getSpecificPowerup(Root.upgrade.COIN)
			add_child(coin)
			coin.sendReward(car)
		assert_eq(car.coin, 25, "coins at reward level %d" % level)

func test_purse_credits_all_coins_at_once():
	var car = FakeCar.new()
	add_child_autofree(car)
	var purse = Root.getSpecificPowerup(Root.upgrade.PURSE)
	add_child(purse)
	purse.sendReward(car)
	assert_eq(car.calls, 1, "one credit for the whole purse")
	assert_between(car.coin, 15, 100)
