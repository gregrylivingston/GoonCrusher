extends GameTest

#The run's effects (docs/roadmap/ROADMAP_JUICE.md): the shared particle kit (FxParticles) and what a blast
#throws out (Fx). All of it is show only.

var savedCar
var savedSettings := {}
const KEYS := ["gfx/blast_fx", "access/reduce_flashing"]

func before_each():
	savedCar = Root.playerCar
	for k in KEYS: savedSettings[k] = Settings.get_value(k)

func after_each():
	for k in KEYS: Settings.set_value(k, savedSettings[k], false)
	Root.playerCar = savedCar

func makeFx() -> Fx:
	Root.playerCar = null
	return add_child_autofree(Fx.new())

#--- the particle kit -----------------------------------------------------------------------------

func test_a_full_ring_overwrites_its_oldest():
	var p: FxParticles = add_child_autofree(FxParticles.new(false, 0))
	p.resize(4)
	for i in 6: p.spawn(Vector2(i, 0), Vector2.ZERO, 1.0, 2.0, Color.WHITE)
	assert_eq(p.alive, 4, "never more alive than the ring holds")
	assert_eq(p.pos[0], Vector2(4, 0), "the fifth took the first's place")

func test_particles_die_and_the_node_goes_idle():
	var p: FxParticles = add_child_autofree(FxParticles.new(false, 0))
	p.resize(8)
	for k in FxParticles.Kind.values(): p.spawn(Vector2.ZERO, Vector2(100, 0), 0.5, 4.0, Color.WHITE, k)
	assert_true(p.is_processing(), "awake while something is alive")
	p._process(0.25)
	assert_gt(p.pos[0].x, 0.0, "they move")
	assert_eq(p.alive, FxParticles.Kind.size())
	p._process(0.3)
	assert_eq(p.alive, 0)
	assert_false(p.is_processing(), "idle once the last one is gone")

func test_an_empty_ring_takes_no_particles():
	var p: FxParticles = add_child_autofree(FxParticles.new(true, 0))
	p.spawn(Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, Color.WHITE)
	assert_eq(p.alive, 0)

func test_every_kind_has_its_drag():
	assert_eq(FxParticles.DRAG.size(), FxParticles.Kind.size())

func test_the_cloud_is_clear_at_its_rim():
	var img := FxParticles.cloud().get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "the corner is clear")
	assert_gt(img.get_pixel(32, 32).a, 0.9, "the middle is solid")

#--- blasts ---------------------------------------------------------------------------------------

func test_a_blast_throws_more_the_bigger_it_is():
	Settings.set_value("gfx/blast_fx", 2, false)
	var alive := []
	for size in Fx.Size.values():
		var fx := makeFx()
		fx.blast(Vector2.ZERO, size)
		alive.push_back(fx.smoke.alive + fx.glow.alive)
		assert_eq(fx.rings.size(), 1, "one shockwave")
		assert_eq(fx.scorches.size(), 1, "one burn mark")
	assert_gt(alive[1], alive[0])
	assert_gt(alive[2], alive[1])

func test_minimal_keeps_only_the_scorch():
	Settings.set_value("gfx/blast_fx", 0, false)
	var fx := makeFx()
	fx.blast(Vector2.ZERO, Fx.Size.BIG)
	assert_eq(fx.smoke.alive + fx.glow.alive, 0)
	assert_true(fx.rings.is_empty() && fx.flashes.is_empty())
	assert_eq(fx.scorches.size(), 1)

func test_reduce_flashing_drops_the_flash():
	Settings.set_value("gfx/blast_fx", 2, false)
	Settings.set_value("access/reduce_flashing", true, false)
	var fx := makeFx()
	fx.blast(Vector2.ZERO)
	assert_true(fx.flashes.is_empty())
	Settings.set_value("access/reduce_flashing", false, false)
	fx.blast(Vector2.ZERO)
	assert_eq(fx.flashes.size(), 1)

func test_the_pools_hold_the_biggest_blast():
	Settings.set_value("gfx/blast_fx", 2, false)
	var fx := makeFx()
	var big: Dictionary = Fx.BLAST[Fx.Size.BIG]
	fx.blast(Vector2.ZERO, Fx.Size.BIG)
	assert_eq(fx.smoke.alive, big.smoke + big.debris, "nothing of one big blast is overwritten")
	assert_eq(fx.glow.alive, big.flames + big.embers)

func test_scorch_marks_are_capped_and_fade_away():
	var fx := makeFx()
	for i in Fx.MAX_SCORCH + 5: fx.scorch(Vector2(i, 0), 40.0)
	assert_eq(fx.scorches.size(), Fx.MAX_SCORCH)
	assert_eq(fx.scorches[0].pos, Vector2(5, 0), "the oldest went first")
	fx._process(Fx.SCORCH_LIFE + 1.0)
	assert_true(fx.scorches.is_empty())
	assert_false(fx.is_processing(), "idle with nothing left")

func test_the_shake_falls_off_with_distance():
	assert_eq(Fx.nearness(0.0, 1000.0), 1.0)
	assert_eq(Fx.nearness(1000.0, 1000.0), 0.0)
	assert_eq(Fx.nearness(5000.0, 1000.0), 0.0)
	assert_gt(Fx.nearness(200.0, 1000.0), Fx.nearness(700.0, 1000.0))

func test_a_near_blast_shakes_the_players_camera():
	var car = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	var fx: Fx = add_child_autofree(Fx.new())
	Root.playerCar = car
	if not is_instance_valid(car.crushFeel): return
	car.crushFeel.trauma = 0.0
	fx.blast(car.global_position + Vector2(100000, 0), Fx.Size.BIG)
	assert_eq(car.crushFeel.trauma, 0.0, "a blast far away is not felt")
	fx.blast(car.global_position, Fx.Size.BLAST)
	assert_gt(car.crushFeel.trauma, 0.0)

func test_the_fireball_takes_the_blasts_size():
	var pool: ExplosionPool = add_child_autofree(ExplosionPool.new(load("res://scene/fx/explosion.tscn")))
	var e = pool.explode(Vector2.ZERO, Fx.BLAST[Fx.Size.BIG].core)
	assert_eq(e.size, Fx.BLAST[Fx.Size.BIG].core)
	assert_gt(e.scale.x, 0.2 * e.size - 0.001)

#--- tire marks -----------------------------------------------------------------------------------

func surface(name: String) -> int:
	for i in World.count():
		if World.def(i).name == name: return i
	return -1

func test_every_look_names_a_real_surface():
	for name in Tiremark.LOOK: assert_true(surface(name) >= 0, name + " is a surface")

func test_water_never_takes_a_mark():
	for name in ["WATER", "WADE", "SHALLOWS"]:
		assert_false(Tiremark.marks(surface(name), true, 900.0), name)

func test_hard_ground_marks_only_in_a_skid():
	assert_true(Tiremark.marks(surface("ASPHALT"), true, 300.0))
	assert_false(Tiremark.marks(surface("ASPHALT"), false, 900.0))
	assert_false(Tiremark.marks(surface("GRASS"), false, 900.0))

func test_soft_ground_takes_ruts_at_speed():
	for name in ["SAND", "MUD", "SNOW", "DEEPSNOW"]:
		assert_true(Tiremark.marks(surface(name), false, Tiremark.RUT_SPEED + 1.0), name)
		assert_false(Tiremark.marks(surface(name), false, Tiremark.RUT_SPEED - 1.0), name + ", crawling")

func test_a_mark_takes_its_surfaces_look_and_no_map_marks_too():
	var mark: Tiremark = load("res://scene/fx/tiremark.tscn").instantiate()
	mark.surface = surface("SNOW")
	add_child_autofree(mark)
	assert_eq(mark.default_color, Tiremark.LOOK["SNOW"][0])
	assert_eq(mark.width, Tiremark.LOOK["SNOW"][1])
	assert_true(Tiremark.marks(World.UNKNOWN, true, 300.0), "before a map is loaded a skid still marks")
