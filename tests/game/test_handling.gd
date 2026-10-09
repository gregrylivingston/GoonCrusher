extends GameTest

#The handling targets (CarHandling, docs/CAR_ART.md "Handling"): every car, stock and maxed, stays in a
#band that drives well, and the cars still differ. scripts/debug/handling_lab.gd prints the full table.

const DT := 1.0 / 60.0
const CARS := ["sedan", "taxi", "van", "pickup", "semi", "ambulance", "supercar", "police", "racer"]
var CTRL = load("res://scene/player/controller/playerCarController.gd")

func car(id: String, up := 0) -> OverheadCarBody2D:
	var c: OverheadCarBody2D = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
	c.isPlayer = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	for stat in ["engine", "steering", "traction", "armor"]: c.set(stat, c.get(stat) + up)
	return add_child_autofree(c)

#full lock right from straight at `speed`, throttle on: the turn rate over the last 15 of `ticks`
func turnRate(c: OverheadCarBody2D, speed: float, ticks := 30) -> float:
	var input = OverheadCarBody2D.CarInput.new()
	input.acceleration = 1.0
	var fwd := Vector2.RIGHT
	var vel := Vector2(speed, 0)
	var before := 0.0
	for t in ticks:
		if t == ticks - 15: before = fwd.angle()
		input.steering = CTRL.nextSteering(input.steering, false, true, c.steerRate())
		var next = c.integrate(Vector2.ZERO, fwd, vel, input, DT)
		fwd = next[0]
		vel = next[1]
	return absf(angle_difference(before, fwd.angle())) / (15 * DT)

func test_every_car_turns_within_the_band():
	var stock := []
	for id in CARS:
		for up in [0, 20]:
			var rate := turnRate(car(id, up), 500.0)
			assert_true(rate > 1.3 && rate < 2.6, "%s +%d turns at %.2f rad/s at 500 px/s" % [id, up, rate])
			if up == 0: stock.push_back(rate)
	assert_gt(stock.max() / stock.min(), 1.25, "the cars still turn differently")

func test_the_wheel_takes_a_moment_but_not_long():
	for id in CARS:
		for up in [0, 20]:
			var seconds := 1.0 / (car(id, up).steerRate() * 60.0)
			assert_true(seconds > 0.09 && seconds < 0.26, "%s +%d reaches full lock in %.2f s" % [id, up, seconds])
	assert_gt(car("racer").steerRate(), car("semi").steerRate(), "a light car turns in quicker than a heavy one")

func test_brakes_stop_every_car():
	for id in ["sedan", "semi", "police"]:
		for up in [0, 20]:
			var c := car(id, up)
			var input = OverheadCarBody2D.CarInput.new()
			input.braking = true
			var vel := Vector2(1000, 0)
			var ticks := 0
			while vel != Vector2.ZERO && ticks < 240:
				vel = c.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, DT)[1]
				ticks += 1
			assert_eq(vel, Vector2.ZERO, "%s +%d stops from 1000 px/s (it used to hover at 20 px/s with strong brakes)" % [id, up])
			assert_true(ticks < 150, "%s +%d within 2.5 s (%d ticks)" % [id, up, ticks])

func test_reverse_is_slow():
	for id in ["sedan", "racer"]:
		var c := car(id, 20)
		var input = OverheadCarBody2D.CarInput.new()
		input.acceleration = -1.0
		var vel := Vector2.ZERO
		for t in 600: vel = c.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, DT)[1]
		assert_true(vel.length() < 500.0, "%s +20 reverses at %.0f px/s" % [id, vel.length()])

func test_a_corner_keeps_most_of_the_speed():
	for id in ["sedan", "semi", "racer"]:
		var c := car(id)
		var input = OverheadCarBody2D.CarInput.new()
		input.acceleration = 1.0
		var fwd := Vector2.RIGHT
		var vel := Vector2(900, 0)
		var ticks := 0
		while absf(vel.angle()) < PI / 2 && ticks < 300:
			input.steering = CTRL.nextSteering(input.steering, false, true, c.steerRate())
			var next = c.integrate(Vector2.ZERO, fwd, vel, input, DT)
			fwd = next[0]
			vel = next[1]
			ticks += 1
		assert_gt(vel.length(), 900.0 * 0.8, "%s keeps %.0f%% through a 90 degree turn" % [id, 100.0 * vel.length() / 900.0])

func test_weight_shapes_the_car():
	var light := car("sedan")
	var heavy := car("sedan")
	heavy.weight = 100
	light.weight = 0
	assert_gt(turnRate(light, 500.0), turnRate(heavy, 500.0), "heavy turns slower")
	assert_gt(light.steerRate(), heavy.steerRate(), "and turns in slower")
	var h := CarHandling.tune
	assert_gt(h.brakeDecel(4, 0.0), h.brakeDecel(4, 1.0), "and brakes longer")
	assert_gt(h.bounce(0.0), h.bounce(1.0), "and bounces less off walls")

func test_a_glancing_wall_turns_the_nose_along_it():
	var wall := Vector2(0, -1) #a wall below the car, its normal pointing up at it
	var nose := Vector2(1, 0.4).normalized() #heading right and down into it
	var turn := OverheadCarBody2D.wallDeflect(wall, nose, nose * 600.0)
	assert_gt(0.0, turn, "the nose swings up, along the wall")
	assert_gt(absf(turn), 0.0, "by part of the angle")
	assert_eq(OverheadCarBody2D.wallDeflect(wall, Vector2(0, 1), Vector2(0, 600)), 0.0, "head-on: no swing, it bounces")
	assert_eq(OverheadCarBody2D.wallDeflect(wall, Vector2(1, -0.4).normalized(), Vector2(600, 0)), 0.0, "already pointing away")
	var tail := OverheadCarBody2D.wallDeflect(wall, -nose, nose * 200.0)
	assert_gt(0.0, tail, "reversing into it, the tail leads")

func test_a_hard_hit_bounces_light_cars_more():
	var light := car("racer")
	var heavy := car("semi")
	var wall := Vector2(-1, 0)
	for c in [light, heavy]:
		c.velocity = Vector2.ZERO #what the slide leaves of a square hit
		c.wallResponse(wall, Vector2(800, 0), true)
	assert_gt(0.0, light.velocity.x, "a square hit bounces back")
	assert_gt(heavy.velocity.x, light.velocity.x, "a light car further than a heavy one")
	var slow := car("racer")
	slow.wallResponse(wall, Vector2(100, 0), true)
	assert_eq(slow.velocity, Vector2.ZERO, "a nudge doesn't bounce")

func test_the_console_tunes_every_car_live():
	var before := car("sedan").yawLimit(500.0)
	assert_true(Console.execute("handling yawlow 2.5").begins_with("yawLow"), "names match whatever the case")
	assert_gt(car("sedan").yawLimit(500.0), before, "every car turns faster at once")
	assert_true(Console.execute("handling nosuch 1").begins_with("Error"), "an unknown name is an error")
	Console.execute("handling reset")
	assert_almost_eq(car("sedan").yawLimit(500.0), before, 0.0001, "reset puts it back")
