extends GameTest

#The layers over the shared AI driver (docs/AI_DRIVER.md, "Who is driving"): each car's own driver
#(scene/car/<car>/<car>_driver.gd), its personalities and skills (AIProfiles), the mode briefs (ModeBrief) and
#the keys beyond the four driving ones (the handbrake, the lever, the buttons). Nothing here starts a run;
#every driver is made the way AIDriver.attach makes it, so it carries the tuning the game plays with.

const M := Root.gameModes

func car(id: String) -> OverheadCarBody2D:
	var c: OverheadCarBody2D = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
	c.isPlayer = false
	add_child_autofree(c)
	c.set_physics_process(false)
	return c

#the car's own driver, briefed for a mode, not in the tree (as attach() builds it, without taking the seat)
func driverFor(c: OverheadCarBody2D, mode: int = M.GOONCRUSHER, spec := "auto") -> AIDriver:
	var driver: AIDriver = AIProfiles.driverScript(c.carId).new()
	driver.car = c
	driver.spec = spec
	driver.setBrief(mode)
	autofree.push_back(driver)
	return driver

func test_every_car_has_its_own_driver_with_two_personalities():
	var seen := {}
	for id in AIProfiles.CARS:
		var script := AIProfiles.driverScript(id)
		assert_eq(script.resource_path, "res://scene/car/%s/%s_driver.gd" % [id, id], "%s has a driver of its own" % id)
		var driver = script.new()
		assert_true(driver is AIDriver, "%s's driver is an AIDriver" % id)
		var people: Dictionary = driver.personalities()
		assert_gt(people.size(), 1, "%s has at least two personalities" % id)
		for name in people:
			assert_false(seen.has(name), "%s is one car's personality only (%s and %s)" % [name, id, seen.get(name, "")])
			assert_false(AIProfiles.PROFILES.has(name) || AIProfiles.SKILLS.has(name) || name in ["auto", "alt"], "%s is no style, skill or keyword" % name)
			seen[name] = id
			for key in people[name]: assert_true(AIProfiles.DEFAULTS.has(key), "%s's %s sets a known key: %s" % [id, name, key])
		for key in driver.tuning(): assert_true(AIProfiles.DEFAULTS.has(key), "%s's tuning sets a known key: %s" % [id, key])
		driver.free()
	for entry in SaveManager.playerData.cars: assert_true(str(entry.name) in AIProfiles.CARS, "the garage's %s is in AIProfiles.CARS" % entry.name)
	assert_eq(AIProfiles.driverScript("nosuchcar").resource_path, "res://scripts/ai/ai_driver.gd", "a car with no driver gets the shared one")

func test_a_spec_picks_the_personality_the_skill_and_overrides():
	var people := {"first": {"hitCost": 1.0}, "second": {"hitCost": 2.0}}
	assert_eq(AIProfiles.parse("showoff@rookie+hitCost=4"), {"name": "showoff", "skill": "rookie", "overrides": ["hitCost=4"]})
	assert_eq(AIProfiles.parse("racer:showoff").name, "showoff", "a car prefix is dropped")
	assert_eq(AIProfiles.parse("").skill, "ace", "an ace unless it says otherwise")
	assert_eq(AIProfiles.build("auto", people).hitCost, 1.0, "auto is the first personality")
	assert_eq(AIProfiles.build("", people).hitCost, 1.0, "and so is nothing")
	assert_eq(AIProfiles.build("alt", people).hitCost, 2.0, "alt is the second")
	assert_eq(AIProfiles.build("second", people).hitCost, 2.0, "or one by name")
	assert_eq(AIProfiles.build("showoff", people).hitCost, 1.0, "another car's personality falls back to the first")
	assert_eq(AIProfiles.personalityName("showoff", people), "first")
	assert_eq(AIProfiles.personalityName("crusher", people), "", "a house style has no personality on top")
	var house := AIProfiles.build("auto")
	assert_eq(house.flankCost, AIProfiles.PROFILES[AIProfiles.HOUSE].flankCost, "every driver is built on the house style")
	assert_eq(AIProfiles.build("crusher", people).crushReward, AIProfiles.PROFILES.crusher.crushReward, "unless a style is named")
	assert_eq(AIProfiles.build("crusher", people).hitCost, AIProfiles.DEFAULTS.hitCost, "and then no personality")
	#the layers, lowest first: style, car, personality, brief, skill, override
	assert_eq(AIProfiles.build("auto", {}, {"flankCost": 7.0}).flankCost, 7.0, "the car over the style")
	assert_eq(AIProfiles.build("auto", {"x": {"flankCost": 8.0}}, {"flankCost": 7.0}).flankCost, 8.0, "the personality over the car")
	assert_eq(AIProfiles.build("auto", {"x": {"flankCost": 8.0}}, {}, {"flankCost": 9.0}).flankCost, 9.0, "the mode's brief over the personality")
	assert_eq(AIProfiles.build("auto@rookie", {}, {}, {"lookaheadPx": 5.0}).lookaheadPx, AIProfiles.SKILLS.rookie.lookaheadPx, "the skill over the brief")
	assert_eq(AIProfiles.build("auto@rookie+lookaheadPx=3").lookaheadPx, 3, "an override over everything")
	var rookie := AIProfiles.build("auto@rookie")
	assert_true(rookie.reactionTicks > 0 && rookie.planSlop > 0.0 && rookie.shiftSlop > 0.0, "a rookie reacts late, misjudges and fluffs shifts")
	assert_true(house.reactionTicks == 0 && house.planSlop == 0.0 && house.shiftSlop == 0.0, "an ace doesn't")
	for skill in AIProfiles.SKILLS:
		for key in AIProfiles.SKILLS[skill]: assert_true(AIProfiles.DEFAULTS.has(key), "%s sets a known key: %s" % [skill, key])

func test_bad_specs_are_caught_before_a_run():
	for good in ["", "auto", "alt", "auto@rookie", "@regular", "showoff", "bulldozer@regular", "cautious", "crusher+hitCost=4", "racer:showoff@ace"]:
		assert_eq(AIProfiles.problemWith(good), "", "%s is sound" % good)
	for bad in ["nosuch", "auto@genius", "auto+nokey=1", "auto+hitCost"]:
		assert_ne(AIProfiles.problemWith(bad), "", "%s is caught" % bad)

func test_every_mode_has_a_brief():
	var probe := AIDriver.new()
	for mode in Modes.DATA:
		var brief := ModeBriefs.forMode(mode, probe)
		assert_eq(brief.mode, mode)
		assert_eq(brief.d, probe)
		for key in brief.tuning(): assert_true(AIProfiles.DEFAULTS.has(key), "%s's brief sets a known key: %s" % [Modes.idOf(mode), key])
		assert_eq(brief.isRace(), brief.fuelPlan() == &"race", "%s: a race rations the tank for the route" % Modes.idOf(mode))
	for mode in [M.SPRINT, M.MARATHON, M.RALLY, M.FLATOUT, M.CANNONBALL, M.PURSUIT]: assert_true(ModeBriefs.forMode(mode, probe).isRace(), "%s is a race" % Modes.idOf(mode))
	for mode in [M.GOONCRUSHER, M.BLACKOUT]: assert_eq(ModeBriefs.forMode(mode, probe).fuelPlan(), &"clock", "%s: the tank lasts the clock" % Modes.idOf(mode))
	for mode in [M.HOTLAP, M.DRIFT, M.CONES, M.DERBY, M.KEEPCUP, M.DEFENSE, M.GOONPOCALYPSE]: assert_false(ModeBriefs.forMode(mode, probe).isRace(), "%s is no race to a station" % Modes.idOf(mode))
	assert_true(ModeBriefs.forMode(M.DERBY, probe).ramsCars(), "the derby's drivers steer into cars")
	assert_false(ModeBriefs.forMode(M.CIRCUIT, probe).ramsCars(), "a circuit's don't")
	assert_true(ModeBriefs.forMode(M.DRIFT, probe).drifts())
	assert_gt(ModeBriefs.forMode(M.DRIFT, probe).tuning().driftReward, 0.0, "Drift Trial pays for sliding")
	probe.free()

func test_a_knocked_cone_costs_cone_course_its_second():
	var c := car("sedan")
	var cones := driverFor(c, M.CONES)
	var sprint := driverFor(c, M.SPRINT)
	assert_gt(cones.brief.knockCost(), 1.0, "a second off the clock, and a little more")
	assert_eq(sprint.brief.knockCost(), sprint.p.smashCost, "anywhere else a cone is a passing touch")

func test_plans_hold_the_handbrake_and_brake_above_a_cap():
	var slide := AIDriver.HAND_PLANS[0]
	assert_true((AIDriver.keysFor(slide, 0, 500.0, INF) & AIDriver.HAND) != 0, "a handbrake plan holds the handbrake")
	var flick := AIDriver.HAND_PLANS[2]
	assert_true((AIDriver.keysFor(flick, 10, 500.0, INF) & AIDriver.HAND) != 0, "a flick holds it")
	assert_eq(AIDriver.keysFor(flick, 40, 500.0, INF) & AIDriver.HAND, 0, "then lets go")
	for plan in AIDriver.PLANS: assert_eq(AIDriver.keysFor(plan, 0, 500.0, INF) & AIDriver.HAND, 0, "no other plan touches it")
	var straight := AIDriver.PLANS[0]
	assert_eq(AIDriver.keysFor(straight, 0, 500.0, INF, 380.0), AIDriver.BRAKE, "over the brake cap a forward plan brakes")
	assert_eq(AIDriver.keysFor(straight, 0, 300.0, 380.0, 380.0), AIDriver.ACCEL, "under it, it drives")
	assert_eq(AIDriver.PLANS[9].throttle, AIDriver.Throttle.BRAKE, "brakeDistance simulates the straight braking plan")

func test_a_handbrake_plan_is_predicted_as_a_slide():
	var c := car("racer")
	c.velocity = Vector2(600, 0)
	var driver := driverFor(c)
	var slide := driver.simulate(AIDriver.HAND_PLANS[0], 60)
	var steer := driver.simulate(AIDriver.PLANS[7], 60)
	assert_gt(slide.slide, 10, "holding the handbrake through a turn at speed slides")
	assert_eq(steer.slide, 0, "steering alone doesn't count as one")
	assert_eq(c.velocity, Vector2(600, 0), "the prediction never touches the car")
	assert_gt(absf(slide.headings[slide.headings.size() - 1].angle()), absf(steer.headings[steer.headings.size() - 1].angle()), "and the slide turns the nose further")

func test_who_pulls_the_handbrake():
	var kim := driverFor(car("racer"))
	assert_gt(kim.p.driftReward, 0.0, "the racer's showoff slides for the boost")
	assert_eq(driverFor(car("racer"), M.GOONCRUSHER, "alt").p.driftReward, 0.0, "its lineholder doesn't")
	assert_eq(driverFor(car("van")).p.handbrakeTurn, 0.0, "the van never pulls it")
	assert_eq(driverFor(car("semi")).p.handbrakeTurn, 0.0, "nor the semi")
	assert_gt(driverFor(car("sedan"), M.DRIFT).p.driftReward, 0.0, "in Drift Trial every driver slides")
	var slow := driverFor(car("sedan"), M.DRIFT)
	assert_false(slow.handbrakeWeighed(), "not from a standstill")
	slow.car.velocity = Vector2(500, 0)
	assert_true(slow.handbrakeWeighed(), "at speed in Drift Trial the handbrake is always among the plans")

func test_a_driver_works_the_lever_of_a_geared_car():
	var c := car("racer")
	var driver := driverFor(c)
	assert_true(driver.shiftsByHand(), "the racer's driver shifts by hand")
	assert_false(driverFor(car("sedan")).shiftsByHand(), "an automatic has no lever")
	assert_false(driverFor(c, M.GOONCRUSHER, "auto+shiftByHand=false").shiftsByHand(), "and a driver can leave it to the box")
	var top := c.gearTop(1)
	assert_eq(driver.leverGear(1, top * 0.5, 0.9), 1, "mid-band: stay in gear")
	assert_eq(driver.leverGear(1, top * 0.95, 0.9), 2, "near the redline: up")
	assert_eq(driver.leverGear(1, top * 0.6, 0.5), 1, "an early shift still waits until the next gear can pull")
	assert_eq(driver.leverGear(3, c.gearTop(2) * 0.5, 0.9), 2, "bogging: down")
	assert_eq(driver.leverGear(c.gears, c.gearTop(c.gears), 0.9), c.gears, "top gear stays")
	#the keys: a manual's, made from the plan's automatic ones
	c.myController.driver = driver
	assert_true(c.isManual(), "with that driver the car is a manual")
	c.gear = 1
	c.velocity = Vector2(top * 0.95, 0)
	driver.keys = AIDriver.ACCEL
	driver.shiftWant = 0
	driver.workLever()
	assert_true(driver.justPressed("ShiftUp"), "it pulls the lever up at the redline")
	c.gear = 2
	c.velocity = Vector2.ZERO
	driver.keys = AIDriver.BRAKE
	driver.shiftWant = 0
	driver.workLever()
	assert_true(driver.justPressed("ShiftDown"), "backing up: down toward R")
	c.gear = -1
	driver.keys = AIDriver.BRAKE
	driver.shiftWant = 0
	driver.workLever()
	assert_eq(driver.keys, AIDriver.ACCEL, "in R the throttle backs it up")
	driver.keys = AIDriver.ACCEL
	driver.shiftWant = 0
	driver.workLever()
	assert_true(driver.justPressed("ShiftUp"), "forward again: up out of R")
	c.myController.driver = null
	c.gear = 1

func test_the_cars_buttons_are_the_drivers():
	var c := car("sedan")
	var driver := driverFor(c)
	c.myController.driver = driver
	assert_false(c.actionDown("Horn"), "nothing pressed")
	driver.buttons = AIDriver.HORN | AIDriver.MOVE
	assert_true(c.actionDown("Horn"), "the horn is the driver's button")
	assert_true(c.actionDown("UseMove"))
	assert_false(c.actionDown("UseItem"))
	driver.keys = AIDriver.HAND
	assert_true(c.myController.pressed("Handbrake"), "and the handbrake its key")
	c.myController.driver = null

func test_the_semi_smashes_what_others_must_hit_at_speed():
	var fence = StaticBody2D.new()
	fence.set_meta(&"smashSpeed", 180.0)
	var barrel = StaticBody2D.new()
	barrel.set_meta(&"smashSpeed", 120.0)
	barrel.set_meta(&"explosive", true)
	var rock = StaticBody2D.new()
	var semi := driverFor(car("semi"))
	var sedan := driverFor(car("sedan"))
	assert_true(semi.smashable(fence, 60.0), "Unstoppable: through a fence at a crawl")
	assert_false(sedan.smashable(fence, 60.0), "the sedan needs a run-up")
	assert_true(sedan.smashable(fence, 260.0))
	assert_false(semi.smashable(barrel, 900.0), "explosives are never free, even for the semi")
	assert_false(semi.smashable(rock, 900.0), "and a rock is a rock")
	for node in [fence, barrel, rock]: node.free()

func test_the_trailer_follows_the_tractor_and_cuts_the_corner():
	var c := car("semi")
	var driver := driverFor(c)
	assert_true(c.trailer != null, "the semi tows a trailer")
	var length: float = c.trailer.length
	var axles := Vector2(-length + c.trailer.kingpin.x, 0)
	axles = driver.towTrailer(axles, Vector2(100, 0), Vector2.RIGHT)
	assert_almost_eq(axles.y, 0.0, 0.01, "straight on, it follows straight")
	assert_almost_eq(axles.x, 100.0 + c.trailer.kingpin.x - length, 0.5, "its length behind the kingpin")
	for i in 40: axles = driver.towTrailer(axles, Vector2(100, (i + 1) * 30.0), Vector2.DOWN)
	assert_almost_eq(axles.x, 100.0, 12.0, "after the turn it comes round behind the tractor")
	assert_almost_eq(axles.distance_to(Vector2(100, 1200.0 + c.trailer.kingpin.x)), length, 0.5, "always its length from the kingpin")

func test_the_van_is_charged_for_plans_that_roll_it():
	var c := car("van")
	var driver := driverFor(c)
	var plan := AIDriver.PLANS[7]
	assert_eq(driver.planGuard(plan, {"hard": 0}), 0.0, "an easy plan is free")
	assert_eq(driver.planGuard(plan, {"hard": CarTraitRig.TIP_TICKS + 10}), 0.0, "a moment on two wheels is fine")
	assert_gt(driver.planGuard(plan, {"hard": CarTraitRig.TIP_TICKS + CarTraitRig.ROLL_TICKS}), 0.0, "held until it rolls: charged")
	c.twoWheels = true
	c.traitRig.upTicks = 50
	assert_gt(driver.planGuard(plan, {"hard": 20}), 0.0, "already up: more hard cornering takes it over")
	c.twoWheels = false
	c.traitRig.upTicks = 0
	assert_eq(driverFor(car("sedan")).planGuard(plan, {"hard": 200}), 0.0, "no other car is")

func test_each_cars_traits_change_what_its_driver_weighs():
	var police := driverFor(car("police"))
	assert_true(police.flankScale() < 1.0, "PIT: a goon beside the police car matters less")
	assert_eq(police.nightGlow(), CarTraitRig.LIGHTBAR_RADIUS, "the lightbar shows it all round at night")
	var sedan := driverFor(car("sedan"))
	assert_eq(sedan.flankScale(), 1.0)
	assert_eq(sedan.nightGlow(), AIDriver.NIGHT_GLOW_PX)
	assert_true(sedan.fuelCaution() < 1.0, "Second Wind unused: the sedan worries less about the tank")
	sedan.car.secondWindUsed = true
	assert_eq(sedan.fuelCaution(), 1.0, "once it is spent, as much as anyone")
	var taxi := driverFor(car("taxi"))
	assert_gt(taxi.cruiseFloor(), CarTraitRig.METER_SPEED, "fuel saving never stops the taxi's meter")
	assert_eq(sedan.cruiseFloor(), sedan.p.ecoMinSpeed)
	var medic := driverFor(car("ambulance"))
	assert_gt(medic.spareHealth(), 0.0, "the defibrillator is health in hand")
	medic.car.defibUsed = true
	assert_eq(medic.spareHealth(), 0.0, "until it is used")
	var truck := driverFor(car("pickup"))
	var crate := PickupStub.new()
	crate.powerup = "engine"
	assert_gt(truck.pickupWorth(crate, 10.0), 10.0, "a pickup is a crate in the bed too")
	crate.powerup = "fuel"
	assert_eq(truck.pickupWorth(crate, 10.0), 10.0, "fuel isn't cargo")
	crate.powerup = "engine"
	truck.car.traitRig.bedCrates = CarTraitRig.BED_MAX
	assert_eq(truck.pickupWorth(crate, 10.0), 10.0, "a full bed takes no more")
	assert_eq(sedan.pickupWorth(crate, 10.0), 10.0, "to any other car a pickup is a pickup")
	crate.free()

class PickupStub extends Node2D:
	var powerup := ""

func test_rivals_drive_their_own_cars_by_tier():
	assert_eq(Rivals.SKILL.size(), ModeTiers.NAMES.size(), "a skill per tier")
	for skill in Rivals.SKILL: assert_true(AIProfiles.SKILLS.has(skill), "%s is a skill" % skill)
	assert_eq(Rivals.SKILL[ModeTiers.EASY], "rookie", "on Easy the field makes mistakes")
	assert_eq(Rivals.SKILL[ModeTiers.HARD], "ace", "on Hard it doesn't")
