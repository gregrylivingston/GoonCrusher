extends GameTest

#The gearbox (OverheadCarBody2D, "the gearbox"; CarInfo.gears): the racer, supercar and semi are manual,
#the gears' push follows the rules (limiter, bog, low-gear pull, clutch cut, shift kick), the lever goes
#down past N into R, and a car shifted well is no slower than the same car as an automatic.

const MANUAL := {"racer": 6, "supercar": 7, "semi": 10}
const ALL := ["sedan", "van", "taxi", "pickup", "police", "ambulance", "racer", "supercar", "semi"]
const MAX_TO_TOP_GEAR := 30.0 #seconds of full throttle on grass to reach the last gear, at most
const MIN_GEAR_SECONDS := 0.3 #...and every gear of a manual lasts at least this long at full throttle, time enough to shift by hand
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
	assert_almost_eq(c.gearTop(c.gears - 1), top * OverheadCarBody2D.LAST_SHIFT, 0.5, "the second-to-last gear tops out at LAST_SHIFT of top speed")
	assert_almost_eq(c.gearTop(c.gears), top, 0.5, "the last gear runs to it")
	assert_gt(c.gearTop(1) + 0.01, c.gearTop(2) - c.gearTop(1), "first is the longest gear")
	for g in range(3, c.gears): assert_gt(c.gearTop(g - 1) - c.gearTop(g - 2) + 0.01, c.gearTop(g) - c.gearTop(g - 1), "gear %d is no longer than the one below" % g)
	var auto := car("sedan")
	assert_almost_eq(auto.gearTop(auto.shownGears() - 1), auto.cruiseTop(auto.engine) * OverheadCarBody2D.LAST_SHIFT, 0.5, "an automatic's shown gears spread the same way")

func test_neutral_has_no_push_and_reverse_keeps_its_own():
	var c := car("racer")
	assert_eq(c.gearThrust(0, 0.0), 0.0)
	assert_eq(c.gearThrust(-1, 50.0), 1.0)

func test_the_limiter_cuts_every_gear_but_the_last():
	var c := car("racer")
	assert_eq(c.gearThrust(1, c.gearTop(1) * 1.01), 0.0, "first gear at its limit")
	assert_eq(c.gearThrust(3, c.gearTop(3)), 0.0, "third gear at its limit")
	assert_gt(c.gearThrust(c.gears, c.gearTop(c.gears) * 1.2), 0.0, "the last gear keeps pulling")

func test_low_gears_pull_harder_and_a_high_gear_bogs_at_low_speed():
	var c := car("semi")
	var slow := c.gearTop(1) * 0.5
	assert_gt(c.gearThrust(1, slow), c.gearThrust(c.gears, c.gearTop(c.gears) * 0.8), "first pulls harder than top")
	assert_gt(c.gearThrust(1, slow), c.gearThrust(4, slow), "fourth at a crawl bogs")
	assert_almost_eq(c.gearThrust(4, 0.0), OverheadCarBody2D.POWER_BAND.x * OverheadCarBody2D.bogFloor(4) * (1.0 + OverheadCarBody2D.LOW_GEAR_PULL * (c.gears - 4.0) / (c.gears - 1.0)), 0.001, "down to its bog floor at a standstill")
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
	c.velocity = c.transform.x * c.gearTop(1) * 0.95 #near the redline of first
	assert_true(c.shift(1))
	assert_eq(c.shiftKick, OverheadCarBody2D.SHIFT_KICK_TICKS, "a well-timed shift pushes")
	assert_eq(c.shiftCut, 0, "with no clutch cut")
	assert_gt(c.gearThrust(2, c.gearTop(2) * 0.9), 1.0 + OverheadCarBody2D.LOW_GEAR_PULL * (c.gears - 2.0) / (c.gears - 1.0), "the kick is in the push")
	c.shiftKick = 0
	c.velocity = c.transform.x * lerpf(c.gearTop(1), c.gearTop(2), 0.4) #partway through second
	assert_true(c.shift(1))
	assert_eq(c.shiftKick, 0, "an early shift earns nothing...")
	assert_eq(c.shiftCut, OverheadCarBody2D.SHIFT_CUT_TICKS, "...and the clutch cuts the push")
	assert_eq(c.gearThrust(3, c.gearTop(2)), 0.0, "nothing while it is in")
	assert_eq(kicks, [true, false])

func test_auto_gear_shifts_up_at_the_limit_and_down_when_bogging():
	var c := car("racer")
	assert_eq(c.autoGear(0, 0.0), 1, "out of N or R into first")
	assert_eq(c.autoGear(1, c.gearTop(1) * 0.5), 1)
	assert_eq(c.autoGear(1, c.gearTop(1) * 0.99), 2, "up near the limit")
	assert_eq(c.autoGear(4, c.gearTop(1)), 3, "down when far too slow")
	assert_eq(c.autoGear(c.gears, c.gearTop(c.gears) * 9.0), c.gears, "never past the top")

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

class FlatGrass extends RefCounted:
	func terrainAt(_pos: Vector2) -> int: return Root.terrain.GRASS
	func surfaceAt(_pos: Vector2) -> int: return Root.terrain.GRASS
	func lethalAt(_pos: Vector2) -> bool: return false
	func blockedAt(_pos: Vector2) -> bool: return false
	func spawnableAt(_pos: Vector2) -> bool: return true

## Seconds of full throttle on grass from a standstill until each gear first comes in, shifting as autoGear
## does (an automatic's shown gear: bestGear), up to 40 s. [times per gear (index 0 = gear 1), speed at the end]
func gearTimes(c: OverheadCarBody2D) -> Array:
	var input := OverheadCarBody2D.CarInput.new()
	input.acceleration = 1.0
	var vel := Vector2.ZERO
	var g := 1
	var times := [0.0]
	for t in 60 * 40:
		g = c.autoGear(g, vel.length()) if c.gears > 0 else c.bestGear(vel.length())
		while times.size() < g: times.push_back(t / 60.0)
		if g == c.shownGears(): break
		input.gear = g
		vel = c.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, 1.0 / 60.0)[1]
	return [times, vel.length()]

#the gear ratios make sense for every car: each gear comes in, in order, the last within MAX_TO_TOP_GEAR
#seconds, and every gear of a manual lasts at least MIN_GEAR_SECONDS (time to shift by hand). Prints the table.
func test_every_car_climbs_through_its_gears():
	var saved = Root.worldMap
	Root.worldMap = FlatGrass.new()
	for id in ALL:
		var c := car(id)
		var result := gearTimes(c)
		var times: Array = result[0]
		var line := "  GEARS %-9s %2d gears, top %4.0f px/s:" % [id, c.shownGears(), c.cruiseTop(c.engine)]
		for i in times.size(): line += "  %d@%.1fs" % [i + 1, times[i]]
		print(line)
		assert_eq(times.size(), c.shownGears(), "%s reaches every gear" % id)
		var last: float = times.back()
		assert_gt(MAX_TO_TOP_GEAR, last, "%s reaches its last gear within %.0f s (%.1f)" % [id, MAX_TO_TOP_GEAR, last])
		if c.gears > 0:
			for i in range(1, times.size()):
				assert_gt(times[i] - times[i - 1], MIN_GEAR_SECONDS, "%s: gear %d lasts long enough to shift (%.2f s)" % [id, i, times[i] - times[i - 1]])
	Root.worldMap = saved

#the tach reads well in every gear of every car: a shift up at the limit lands near 2 and the revs climb to
#about 6 before the next, never sitting in the red through a gear
func test_the_tach_drops_on_a_shift_and_climbs_through_the_gear():
	for id in ALL:
		var c := car(id)
		var red := c.redline
		c._car_input.acceleration = 1.0
		for g in range(1, c.shownGears() + 1):
			c.gear = g
			c.velocity = Vector2.RIGHT * lerpf(c.gearTop(g - 1) if g > 1 else 0.0, c.gearTop(g), 0.99)
			var high := HudDial.gearedRpm(c)
			assert_true(high > red * 0.95 && high <= red, "%s gear %d reads %.1f at the top of the gear (redline %.1f)" % [id, g, high, red])
			if g == 1: continue
			c.velocity = Vector2.RIGHT * c.gearTop(g - 1)
			var low := HudDial.gearedRpm(c)
			assert_almost_eq(low, red * HudDial.RPM_AFTER_SHIFT, 0.05, "%s gear %d reads %.1f just after the shift up" % [id, g, low])
			c.velocity = Vector2.RIGHT * lerpf(c.gearTop(g - 1), c.gearTop(g), 0.5)
			assert_true(HudDial.gearedRpm(c) < red * 0.75, "%s gear %d is well under the red halfway through" % [id, g])
		c.gear = c.shownGears()
		c.velocity = Vector2.RIGHT * c.gearTop(c.gear) * 1.3 #Nitro past the last gear
		assert_true(HudDial.gearedRpm(c) <= HudDial.rpmMaxFor(red), "%s never reads past its dial" % id)

#each car's tach is its own: trucks rev low, sports cars high
func test_every_car_has_its_own_redline():
	var red := {}
	for id in ALL: red[id] = car(id).redline
	assert_gt(red.supercar, red.racer - 0.01, "the supercar revs highest")
	assert_gt(red.racer, red.police, "sports cars above the saloons")
	assert_gt(red.sedan, red.pickup, "trucks below the saloons")
	assert_gt(red.ambulance, red.semi, "and the semi lowest of all")
	for id in ALL: assert_gt(HudDial.rpmMaxFor(red[id]), red[id] + 0.5, "%s's dial has room past its redline" % id)

func test_the_kick_needs_the_top_of_the_band():
	var c := car("supercar")
	c.setGear(5)
	c.velocity = c.transform.x * lerpf(c.gearTop(4), c.gearTop(5), 0.5) #halfway through fifth: most of fifth's limit in speed, half its revs
	c.shift(1)
	assert_eq(c.shiftKick, 0, "half the band earns nothing")
	c.setGear(5)
	c.shiftCut = 0
	c.velocity = c.transform.x * lerpf(c.gearTop(4), c.gearTop(5), 0.9)
	c.shift(1)
	assert_eq(c.shiftKick, OverheadCarBody2D.SHIFT_KICK_TICKS, "the top fifth does")
