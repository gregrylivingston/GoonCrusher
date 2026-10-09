extends GameTest

#The handbrake (OverheadCarBody2D.HANDBRAKE_*, the Handbrake action) inside integrate(): a powerslide
#at speed that turns tighter than steering alone, catches before it spins, and is shaped by the car's
#stats. Plus the v2 bindings migration that freed Space for it.

const DT := 1.0 / 60.0

func car(id := "sedan") -> OverheadCarBody2D:
	return add_child_autofree(load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate())

#drives `ticks` from `speed` px/s heading right, full lock right; returns [heading, velocity, widest slip (rad)]
func slide(c: OverheadCarBody2D, speed: float, handbrake: bool, ticks: int, gas := 1.0) -> Array:
	var input = OverheadCarBody2D.CarInput.new()
	input.steering = 1.0
	input.acceleration = gas
	input.handbrake = handbrake
	var fwd := Vector2.RIGHT
	var vel := Vector2(speed, 0)
	var pos := Vector2.ZERO
	var widest := 0.0
	for t in ticks:
		var next = c.integrate(pos, fwd, vel, input, DT)
		fwd = next[0]
		vel = next[1]
		pos += vel * DT
		widest = maxf(widest, absf(fwd.angle_to(vel)))
	return [fwd, vel, widest]

func test_integrate_stays_pure_with_the_handbrake():
	var c = car()
	var input = OverheadCarBody2D.CarInput.new()
	input.handbrake = true
	input.steering = 0.7
	var a = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(600, 40), input, DT)
	var b = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(600, 40), input, DT)
	assert_eq(a, b, "same state, same answer")
	assert_eq(c.velocity, Vector2.ZERO, "the body is untouched")

func test_the_handbrake_slides_and_turns_tighter():
	var c = car("audi")
	var plain = slide(c, 1200.0, false, 40)
	var slid = slide(c, 1200.0, true, 40)
	assert_gt(slid[2], plain[2] + 0.3, "the rear lets go")
	assert_gt(absf(Vector2.RIGHT.angle_to(slid[0])), absf(Vector2.RIGHT.angle_to(plain[0])), "the nose swings further")
	assert_gt(slid[1].length(), 1200.0 * 0.6, "a powerslide keeps most of its speed")

func test_a_held_slide_catches_before_it_spins():
	for id in ["police", "semi", "racer"]:
		var c = car(id)
		var held = slide(c, 1300.0, true, 150)
		assert_true(held[2] < deg_to_rad(80.0), "%s slip stays under the catch angle (%d deg)" % [id, rad_to_deg(held[2])])

func test_slow_it_only_brakes():
	var c = car()
	var input = OverheadCarBody2D.CarInput.new()
	input.steering = 1.0
	var plain = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 0), input, DT)
	input.handbrake = true
	var held = c.integrate(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 0), input, DT)
	assert_almost_eq(plain[0].angle(), held[0].angle(), 0.0001, "below HANDBRAKE_MIN_SPEED the steering is the same")
	assert_gt(plain[1].length(), held[1].length(), "and the car slows")

func test_heavy_cars_slide_longer():
	assert_gt(car("racer").handbrakeGrip(), car("semi").handbrakeGrip(), "weight loosens the slide")

func test_the_v2_bindings_migration_frees_space():
	var bindings := {"UseItem": [{"key": KEY_E}, {"key": KEY_SPACE}, {"button": JOY_BUTTON_X}], "Brake": [{"key": KEY_SHIFT}]}
	Settings.migrateDrivingKeys(bindings)
	assert_eq(bindings["UseItem"], [{"key": KEY_E}, {"button": JOY_BUTTON_X}], "Space leaves Fire Gadget")
	assert_false(bindings.has("Handbrake"), "Space is free, so the Handbrake keeps its defaults")
	assert_true(bindings.has("UseMove"), "Shift is the player's Brake...")
	assert_false(bindings["UseMove"].has({"key": KEY_SHIFT}), "...so Boost is saved without it")
	assert_true(bindings["UseMove"].has({"button": JOY_BUTTON_LEFT_SHOULDER}), "and keeps its pad button")

#Speed-sensitive steering (CarHandling.wheelAngle): a maxed fast car at top speed used to turn about
#7.5 rad/s, too twitchy to drive. Now the wheel turns the car at most at its yaw ceiling.
func test_a_maxed_fast_car_turns_no_faster_than_its_ceiling():
	var c = car("police")
	c.steering = 45
	var turned: Vector2 = slide(c, 1600.0, false, 10)[0]
	var rate := absf(turned.angle()) / (10 * DT)
	assert_gt(c.yawLimit(1600.0) * 1.1, rate, "at 1600 px/s, within the ceiling (%.2f rad/s)" % rate)
	assert_gt(rate, c.yawLimit(1600.0) * 0.6, "but still turning hard")

func test_slow_the_lock_limits_the_turn():
	var c = car("police")
	var h := CarHandling.tune
	assert_almost_eq(h.wheelAngle(100.0, 25, 0.5, 70.0), h.wheelMax(25), 0.0001, "at walking pace: full lock")
	assert_gt(h.wheelMax(25), h.wheelAngle(900.0, 25, 0.5, 70.0), "fast: less wheel")
	assert_almost_eq(h.wheelAngle(0.0, 25, 0.5, 70.0), h.wheelMax(25), 0.0001, "standing still")
	assert_gt(c.yawLimit(400.0), c.yawLimit(60.0) * 2.0, "the turn builds with speed from a crawl")

func test_the_handbrake_still_swings_past_the_cap():
	var c = car("police")
	c.steering = 45
	var plain: Vector2 = slide(c, 1200.0, false, 20)[0]
	var sliding: Vector2 = slide(c, 1200.0, true, 20)[0]
	assert_gt(absf(sliding.angle()), absf(plain.angle()), "a powerslide turns the nose further")
