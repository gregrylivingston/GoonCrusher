extends GameTest

#The semi's trailer (CarTrailer): it follows the kingpin, cuts inside a turn, folds when pushed backwards
#up to the jackknife stop, and snaps back behind the tractor after a teleport. The tractor is moved by
#hand here, tick by tick, so only the trailer's own rules are under test.

const DT := 1.0 / 60.0

func semi() -> OverheadCarBody2D:
	var c: OverheadCarBody2D = load("res://scene/car/semi/semi.tscn").instantiate()
	c.isPlayer = false
	add_child_autofree(c)
	c.set_physics_process(false) #moved by hand; a disabled body would leave the physics space, and the trailer with it
	return c

#moves the tractor `ticks` times along `vel` turning `yaw` rad/s, following with the trailer
func drive(c: OverheadCarBody2D, vel: float, yaw: float, ticks: int) -> void:
	for t in ticks:
		c.rotation += yaw * DT
		c.velocity = c.transform.x * vel
		c.global_position += c.velocity * DT
		c.trailer.follow(DT)

func fold(c: OverheadCarBody2D) -> float:
	return absf(c.global_transform.x.angle_to(c.trailer.global_transform.x))

func test_only_the_semi_has_a_trailer():
	assert_true(semi().trailer != null, "the semi pulls one")
	var sedan = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	assert_true(sedan.trailer == null, "a sedan doesn't")

func test_it_starts_straight_behind_the_tractor():
	var c := semi()
	c.global_position = Vector2(500, 300)
	c.trailer.follow(DT)
	var hitch := c.to_global(c.trailer.kingpin)
	assert_almost_eq(c.trailer.global_position.distance_to(hitch), c.trailer.length, 0.01, "the axles sit `length` behind the kingpin")
	assert_almost_eq(fold(c), 0.0, 0.0001, "in line")
	assert_gt(c.global_position.x, c.trailer.global_position.x, "behind it")

func test_it_cuts_inside_a_turn():
	var c := semi()
	c.trailer.follow(DT)
	drive(c, 500.0, 1.2, 150) #a steady circle, radius about 420 px
	var center := c.global_position + c.global_transform.y * (500.0 / 1.2) #turning right: the center is to the right
	assert_gt(c.global_position.distance_to(center), c.trailer.global_position.distance_to(center) + 20.0, "the trailer's axles run inside the tractor's path")
	assert_gt(fold(c), 0.2, "and it trails at an angle")
	assert_almost_eq(c.trailer.global_position.distance_to(c.to_global(c.trailer.kingpin)), c.trailer.length, 1.0, "still hitched")

func test_pushed_backwards_it_folds_to_the_stop():
	var c := semi()
	c.trailer.follow(DT)
	c.rotation = 0.05 #a little off line, as it always is
	drive(c, -200.0, 0.0, 240)
	assert_gt(fold(c), deg_to_rad(40.0), "reversing straight, it jackknifes")
	assert_true(fold(c) <= deg_to_rad(CarHandling.tune.trailerJackknife) + 0.01, "but no further than the stop (%.0f deg)" % rad_to_deg(fold(c)))

func test_a_teleport_snaps_it_back():
	var c := semi()
	c.trailer.follow(DT)
	c.global_position = Vector2(5000, -3000)
	c.trailer.follow(DT)
	assert_almost_eq(fold(c), 0.0, 0.0001, "straight behind again")
	assert_almost_eq(c.trailer.global_position.distance_to(c.to_global(c.trailer.kingpin)), c.trailer.length, 0.01)

func test_low_grip_lets_it_swing_wide():
	var swing := []
	for grip in [1.0, 0.05]:
		CarHandling.tune.trailerGrip = grip
		var c := semi()
		c.global_position = Vector2(0.0, 3000.0 * swing.size()) #apart, or the second truck would hit the first
		c.trailer.follow(DT)
		drive(c, 700.0, 0.0, 30)
		drive(c, 700.0, 3.0, 20) #a sharp flick
		drive(c, 700.0, 0.0, 20)
		swing.push_back(fold(c))
	CarHandling.reset()
	assert_gt(swing[1], swing[0] + 0.05, "on ice the trailer keeps sliding after the flick (%.2f vs %.2f rad)" % [swing[1], swing[0]])

#A trailer swung into a rock used to feed its own correction back into its swing: pushes of 8,000 px/s,
#a fresh hard hit every tick, and a semi wrecked in seconds. Blocked, it stops swinging and is judged by its
#real speed.
func test_a_snagged_trailer_stays_calm():
	var c := semi()
	c.global_position = Vector2(0, 0)
	c.trailer.follow(DT)
	var rock := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(80, 80)
	rock.add_child(shape)
	rock.position = Vector2(0, -167) #the middle of the tractor's turn: the tractor goes round it, the trailer cuts in
	add_child_autofree(rock)
	await get_tree().physics_frame
	var fastest := 0.0
	var apart := 0.0
	for t in 120:
		c.rotation -= 1.5 * DT #a tight left turn (radius 167 px); the trailer, longer than that, cuts across the inside
		c.velocity = c.transform.x * 250.0
		c.global_position += c.velocity * DT
		c.trailer.follow(DT)
		fastest = maxf(fastest, c.trailer.axleVel.length())
		apart = maxf(apart, absf(c.trailer.global_position.distance_to(c.to_global(c.trailer.kingpin)) - c.trailer.length))
	assert_gt(1.0, apart, "the hitch never gives: the trailer stays on the kingpin every tick (at most %.1f px off)" % apart)
	assert_gt(c.wallHealthLost, 0.0, "the trailer did meet the rock")
	assert_gt(c.health, 60.0, "the truck survives scraping a rock (health %.0f)" % c.health)
	assert_gt(1500.0, fastest, "the trailer never flies (fastest %.0f px/s)" % fastest)
	assert_true(absf(c.trailer.spin) <= CarTrailer.MAX_SPIN, "its swing stays capped")

func test_the_trailer_draws_over_its_mount():
	var c := semi()
	var cab: CanvasItem = c.get_node("sprite/body")
	var absolute := func(item: CanvasItem) -> int: #z with every relative parent added up
		var z := 0
		var n: Node = item
		while n is CanvasItem:
			z += n.z_index
			if not n.z_as_relative: break
			n = n.get_parent()
		return z
	assert_gt(absolute.call(c.trailer.body), absolute.call(cab), "the box covers the tractor's frame and fifth wheel")
	assert_gt(absolute.call(cab), absolute.call(c.trailer.shadow), "and its shadow falls under the tractor")

#the trailer's front corners sweep a circle round the kingpin as it folds; at every fold up to the jackknife
#stop they must stay behind the cab's back (the baked tractor's rear, scene/car/semi/art/geometry.json)
func test_a_folded_trailer_clears_the_cab():
	var c := semi()
	var geo = JSON.parse_string(FileAccess.get_file_as_string("res://scene/car/semi/art/geometry.json"))
	var cabBack: float = geo.rear + 3.0 #sceneGeometry pads the outline by 3
	var nose: float = c.trailer.bodyRect.end.x - c.trailer.length #box ahead of the kingpin
	var half: float = c.trailer.bodyRect.size.y / 2.0
	var stop := deg_to_rad(CarHandling.tune.trailerJackknife)
	for i in 41:
		var fold := lerpf(-stop, stop, i / 40.0)
		for side in [-1.0, 1.0]:
			var corner: Vector2 = c.trailer.kingpin + Vector2(nose, side * half).rotated(fold)
			assert_gt(cabBack, corner.x, "folded %d deg, a front corner stays behind the cab (%.1f vs %.1f)" % [rad_to_deg(fold), corner.x, cabBack])
