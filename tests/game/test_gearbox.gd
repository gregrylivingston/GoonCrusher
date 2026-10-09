extends GameTest

#The gearbox (OverheadCarBody2D, "the gearbox"; CarInfo.gears): the racer, supercar and semi are manual,
#the gears' push follows the rules (limiter, bog, low-gear pull, clutch cut, shift kick), the lever goes
#down past N into R, and a car shifted well is no slower than the same car as an automatic.

const MANUAL := {"racer": 5, "supercar": 6, "semi": 7}
const AUTOMATIC := ["sedan", "van", "taxi", "pickup", "police", "ambulance"]

func car(id: String) -> OverheadCarBody2D:
	var c: OverheadCarBody2D = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
	c.isPlayer = false
	add_child_autofree(c)
	c.set_physics_process(false)
	return c

func test_the_manual_cars_and_the_rest():
	for id in MANUAL: assert_eq(car(id).gears, MANUAL[id], "%s has %d gears" % [id, MANUAL[id]])
	for id in AUTOMATIC: assert_eq(car(id).gears, 0, "%s is an automatic" % id)

func test_a_geared_car_starts_in_first_with_its_gears_spread_over_its_top_speed():
	var c := car("supercar")
	assert_eq(c.gear, 1)
	var top := c.cruiseTop(c.engine)
	assert_gt(top, c.gearSpan * (c.gears - 1), "the second-to-last gear tops out below top speed")
	assert_gt(c.gearSpan * c.gears, top, "the last gear runs past it")

func test_neutral_has_no_push_and_reverse_keeps_its_own():
	var c := car("racer")
	assert_eq(c.gearThrust(0, 0.0), 0.0)
	assert_eq(c.gearThrust(-1, 50.0), 1.0)

func test_the_limiter_cuts_every_gear_but_the_last():
	var c := car("racer")
	assert_eq(c.gearThrust(1, c.gearSpan * 1.01), 0.0, "first gear at its limit")
	assert_eq(c.gearThrust(3, c.gearSpan * 3.0), 0.0, "third gear at its limit")
	assert_gt(c.gearThrust(c.gears, c.gearSpan * c.gears * 1.2), 0.0, "the last gear keeps pulling")

func test_low_gears_pull_harder_and_a_high_gear_bogs_at_low_speed():
	var c := car("semi")
	var slow := c.gearSpan * 0.5
	assert_gt(c.gearThrust(1, slow), c.gearThrust(c.gears, c.gearSpan * c.gears * 0.8), "first pulls harder than top")
	assert_gt(c.gearThrust(1, slow), c.gearThrust(4, slow), "fourth at a crawl bogs")
	assert_almost_eq(c.gearThrust(4, 0.0), OverheadCarBody2D.bogFloor(4) * (1.0 + OverheadCarBody2D.LOW_GEAR_PULL * 3.0 / 6.0), 0.001, "down to its bog floor at a standstill")
	assert_gt(c.gearThrust(1, 0.0), c.gearThrust(2, 0.0) * 3.0, "first is by far the best start")
	assert_gt(0.05, c.gearThrust(5, 0.0), "fifth from a standstill barely moves")

func test_the_lever_stops_at_r_and_the_top_gear():
	var c := car("racer")
	assert_true(c.shift(-1), "1 to N")
	assert_eq(c.gear, 0)
	assert_true(c.shift(-1), "N to R at a standstill")
	assert_eq(c.gear, -1)
	assert_false(c.shift(-1), "nothing below R")
	c.setGear(c.gears)
	assert_false(c.shift(1), "nothing above the top gear")

func test_r_wont_go_in_rolling_forward():
	var c := car("racer")
	c.setGear(0)
	c.velocity = c.transform.x * 200.0
	assert_false(c.shift(-1), "the lever stops at N")
	assert_eq(c.gear, 0)

func test_reverse_swaps_the_bumpers():
	var c := car("supercar")
	c.setGear(-1)
	assert_true(c.get_node("CollisionShape2D").disabled, "the front bumper stops colliding in R")
	assert_false(c.get_node("CollisionShape2D_rear").disabled)
	c.setGear(1)
	assert_false(c.get_node("CollisionShape2D").disabled, "and comes back in gear")

func test_a_late_shift_kicks_and_an_early_one_cuts():
	var c := car("supercar")
	var kicks := []
	c.shifted.connect(func(_g, kicked): kicks.push_back(kicked))
	c.velocity = c.transform.x * c.gearSpan * 0.95 #near the redline of first
	assert_true(c.shift(1))
	assert_eq(c.shiftKick, OverheadCarBody2D.SHIFT_KICK_TICKS, "a well-timed shift pushes")
	assert_eq(c.shiftCut, 0, "with no clutch cut")
	assert_gt(c.gearThrust(2, c.gearSpan * 1.2), 1.0 + OverheadCarBody2D.LOW_GEAR_PULL * 4.0 / 5.0, "the kick is in the push")
	c.shiftKick = 0
	c.velocity = c.transform.x * c.gearSpan * 2.0 * 0.5 #halfway through second
	assert_true(c.shift(1))
	assert_eq(c.shiftKick, 0, "an early shift earns nothing...")
	assert_eq(c.shiftCut, OverheadCarBody2D.SHIFT_CUT_TICKS, "...and the clutch cuts the push")
	assert_eq(c.gearThrust(3, c.gearSpan), 0.0, "nothing while it is in")
	assert_eq(kicks, [true, false])

func test_auto_gear_shifts_up_at_the_limit_and_down_when_bogging():
	var c := car("racer")
	assert_eq(c.autoGear(0, 0.0), 1, "out of N or R into first")
	assert_eq(c.autoGear(1, c.gearSpan * 0.5), 1)
	assert_eq(c.autoGear(1, c.gearSpan * 0.99), 2, "up near the limit")
	assert_eq(c.autoGear(4, c.gearSpan * 1.0), 3, "down when far too slow")
	assert_eq(c.autoGear(c.gears, c.gearSpan * 99.0), c.gears, "never past the top")

func test_the_ai_and_the_setting_shift_for_you():
	var c := car("racer")
	var saved = Settings.values.get("gameplay/auto_gearbox", false)
	Settings.values["gameplay/auto_gearbox"] = true
	assert_false(c.isManual(), "the Automatic Gearbox setting")
	Settings.values["gameplay/auto_gearbox"] = false
	assert_true(c.isManual(), "otherwise the player shifts")
	Settings.values["gameplay/auto_gearbox"] = saved
	assert_false(car("sedan").isManual(), "an automatic is never manual")

#full throttle on flat ground (no map), shifting at the limit as autoGear does: the geared car gets to speed
#no slower than the same car as an automatic, and reaches the same top speed
func test_a_car_shifted_well_is_no_slower():
	var c := car("supercar")
	var timeTo := func(geared: bool) -> Array:
		var saved := c.gears
		if not geared: c.gears = 0
		var input := OverheadCarBody2D.CarInput.new()
		input.acceleration = 1.0
		var vel := Vector2.ZERO
		var fwd := Vector2.RIGHT
		var g := 1
		var target := c.cruiseTop(c.engine) * 0.85
		var reached := -1
		for t in 60 * 40:
			if geared: g = c.autoGear(g, vel.length())
			input.gear = g
			var next = c.integrate(Vector2.ZERO, fwd, vel, input, 1.0 / 60.0)
			vel = next[1]
			if reached < 0 && vel.length() >= target: reached = t
		c.gears = saved
		return [reached, vel.length()]
	var auto: Array = timeTo.call(false)
	var geared: Array = timeTo.call(true)
	assert_gt(auto[0], 0, "the automatic gets there")
	assert_gt(geared[0], 0, "so does the manual")
	assert_true(geared[0] <= auto[0], "no slower to 85%% of top speed (%d vs %d ticks)" % [geared[0], auto[0]])
	assert_almost_eq(geared[1], auto[1], auto[1] * 0.03, "the same top speed")
