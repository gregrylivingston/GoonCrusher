extends GameTest

#System damage (docs/CAR_ART.md): which system a hit wears, the wear cooldown, the factor in physics,
#the station repair, and the baked art every car scene points at.

const CARS := ["sedan", "van", "taxi", "pickup", "semi", "audi", "racer", "police", "ambulance"]
const Car = preload("res://lib/overhead_car_2d/overhead_car_body_2d.gd")

var saved: Dictionary
var savedCar

func before_each():
	saved = Settings.values.duplicate(true)
	savedCar = Root.playerCar

func after_each():
	for key in saved: Settings.values[key] = saved[key]
	Root.playerCar = savedCar

func makeCar(car := "sedan"):
	return add_child_autofree(load("res://scene/car/%s/%s.tscn" % [car, car]).instantiate())

func test_hits_wear_the_system_on_the_side_that_hit():
	var half := 44.0
	assert_eq(Car.zoneForHit(Vector2(-1, 0), Vector2(100, 0), half), "engine", "dead ahead")
	assert_eq(Car.zoneForHit(Vector2(-0.9, 0.3), Vector2(100, -35), half), "lights", "front corner")
	assert_eq(Car.zoneForHit(Vector2(1, 0), Vector2(-100, 5), half), "tank", "rear")
	assert_eq(Car.zoneForHit(Vector2(0, -1), Vector2(40, 44), half), "steering", "side, ahead of the middle")
	assert_eq(Car.zoneForHit(Vector2(0, 1), Vector2(-40, -44), half), "tires", "side, behind the middle")

#health damage (docs/CAR_ART.md, "Health damage"): a bare car takes the full amount, a little armor helps
#a lot, and no armor makes the car immune
func test_armor_helps_early_but_never_makes_the_car_immune():
	assert_almost_eq(Car.armorFactor(0), 1.0, 0.001, "no armor: the full hit")
	assert_gt(0.85, Car.armorFactor(10), "a few points already take a good share off")
	assert_gt(0.75, Car.armorFactor(20), "a fully upgraded bare car")
	var gainEarly: float = Car.armorFactor(0) - Car.armorFactor(20)
	var gainLate: float = Car.armorFactor(70) - Car.armorFactor(90)
	assert_gt(gainEarly, gainLate * 4.0, "the first 20 points matter far more than 70 to 90")
	assert_gt(Car.armorFactor(Car.STAT_CAP), 0.45, "the in-run cap still takes nearly half")
	assert_gt(Car.armorFactor(100000), Car.ARMOR_FLOOR - 0.001, "never under the floor")
	var last := 2.0
	for a in range(0, 200, 5):
		assert_gt(last, Car.armorFactor(a), "more armor always helps a little")
		last = Car.armorFactor(a)

func test_goon_hits_hurt_a_bare_car():
	var car = makeCar("sedan")
	car.armor = 0
	car.damage(3.0) #a typical goon attack (Goons.DATA dmg)
	assert_almost_eq(car.health, 97.0, 0.001, "a bare car loses the hit's full damage")
	car.armor = Car.STAT_CAP
	car.health = 100.0
	car.damage(3.0)
	assert_between(car.health, 98.0, 99.0, "the most armor still loses more than a point")

func test_wall_wear_has_a_cooldown_per_system():
	var car = makeCar()
	car.wearSystem("engine", 20.0)
	car.wearSystem("engine", 20.0)
	assert_almost_eq(car.condition.engine, 80.0, 0.01, "a second hit inside the cooldown is ignored")
	car.wearSystem("tank", 10.0)
	assert_almost_eq(car.condition.tank, 90.0, 0.01, "other systems have their own cooldown")
	for i in Car.ZONE_COOLDOWN_TICKS: car.tickZoneCooldowns()
	car.wearSystem("engine", 20.0)
	assert_almost_eq(car.condition.engine, 60.0, 0.01, "wear lands again once the cooldown has run out")

func test_damaged_systems_weaken_handling_inside_integrate():
	var car = makeCar()
	var input = Car.CarInput.new()
	input.acceleration = 1.0
	input.steering = 1.0
	var vel := Vector2(300, 0)
	var healthy = car.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, 1.0 / 60.0)
	car.setCondition("steering", 0.0)
	car.setCondition("engine", 0.0)
	var damaged = car.integrate(Vector2.ZERO, Vector2.RIGHT, vel, input, 1.0 / 60.0)
	assert_gt(absf(healthy[0].angle()), absf(damaged[0].angle()), "a wrecked steering system turns less")
	assert_gt(healthy[1].length(), damaged[1].length(), "a wrecked engine accelerates less")
	assert_almost_eq(car.conditionFactor("engine"), Car.CONDITION_FLOOR.engine, 0.001, "a wrecked system keeps its floor")

func test_headlight_reach_follows_the_lights_condition():
	var car = makeCar()
	car.headlights = 40
	car.setHeadlightStrength()
	assert_almost_eq(car.get_node("headlamps/headlights").scale.x, 1.4, 0.001)
	car.setCondition("lights", 0.0)
	assert_almost_eq(car.get_node("headlamps/headlights").scale.x, 1.0 + 40 * Car.CONDITION_FLOOR.lights / 100.0, 0.001)

func test_a_holed_tank_leaks_below_half():
	assert_eq(Car.fuelLeak(100.0), 0.0)
	assert_eq(Car.fuelLeak(50.0), 0.0)
	assert_almost_eq(Car.fuelLeak(0.0), Car.FUEL_LEAK_MAX, 0.000001)

func test_the_station_repairs_every_system():
	var car = makeCar()
	for system in car.condition: car.setCondition(system, 10.0)
	car.repairAll()
	for system in car.condition: assert_eq(car.condition[system], 100.0, system)

func test_the_damage_shader_gets_hull_and_all_five_systems():
	var car = makeCar()
	car.setCondition("tank", 25.0)
	var look = car.get_node("sprite/body").material.get_shader_parameter("damage")
	assert_eq(look.size(), 6)
	assert_almost_eq(look[5], 0.75, 0.001, "tank")
	assert_almost_eq(look[0], 0.0, 0.001, "hull is like new at full health")

func test_damage_fx_sleep_while_the_car_is_healthy():
	var fx = preload("res://scene/car/damage_fx.gd")
	var healthy = {"lights":100.0, "engine":100.0, "steering":100.0, "tires":100.0, "tank":100.0}
	assert_false(fx.isActive(healthy))
	var smoking = healthy.duplicate()
	smoking.engine = 40.0
	assert_true(fx.isActive(smoking))

func test_every_car_has_matching_baked_art():
	for car in CARS:
		var scene = makeCar(car)
		var art: CarArtSet = scene.art
		assert_true(art != null, car + " has art")
		if art == null: continue
		assert_eq(art.weathered.size(), 3, car + " weathered sheets")
		assert_eq(art.showroom.size(), 3, car + " showroom sheets")
		var size = art.weathered[0].get_size()
		for sheet in art.weathered + art.showroom + [art.zoneMask, art.shadow]:
			assert_eq(sheet.get_size(), size, car + " sheets line up")
		assert_eq(scene.get_node("sprite/body").texture, art.weathered[0], car + " shows its weathered paint")
		var area = scene.get_node("carBodyArea/CollisionShape2D").shape.size
		var trailer: CarTrailer = scene.trailer
		assert_between(area.x, 120.0 if trailer else 180.0, 290.0, car + " footprint length (a semi's is its tractor)")
		if trailer: #the trailer's own art (car_gen.js semiTrailer)
			var tsize = trailer.art.weathered[0].get_size()
			for sheet in trailer.art.weathered + trailer.art.showroom + [trailer.art.zoneMask, trailer.art.shadow]:
				assert_eq(sheet.get_size(), tsize, car + " trailer sheets line up")
			assert_eq(trailer.body.texture, trailer.art.weathered[0], car + " trailer shows its weathered paint")
			assert_between(trailer.bodyRect.size.x, 250.0, 360.0, car + " trailer length")

func test_car_paint_switches_live():
	var car = makeCar("taxi")
	Settings.set_value("gameplay/car_paint", "showroom", false)
	assert_eq(car.get_node("sprite/body").texture, car.art.showroom[0])
	Settings.set_value("gameplay/car_paint", "weathered", false)
	assert_eq(car.get_node("sprite/body").texture, car.art.weathered[0])
