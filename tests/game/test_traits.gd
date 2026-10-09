extends GameTest

#Car traits (CarTraits, CarTraitRig; docs/CAR_ART.md "Traits"): every car has its signature features, the
#handling ones change integrate()'s numbers the right way, and the rules do what their cards say.

const CARS := {"sedan": 2, "van": 2, "taxi": 2, "pickup": 2, "audi": 2, "racer": 2, "police": 2, "ambulance": 2, "semi": 2}
const T = Root.terrain

func car(id: String) -> OverheadCarBody2D:
	var c: OverheadCarBody2D = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
	c.isPlayer = false
	add_child_autofree(c)
	c.set_physics_process(false)
	return c

func input(steer := 0.0, accel := 0.0, braking := false) -> OverheadCarBody2D.CarInput:
	var i = OverheadCarBody2D.CarInput.new()
	i.steering = steer
	i.acceleration = accel
	i.braking = braking
	return i

func test_every_car_has_its_features():
	var seen := {}
	for id in CARS:
		var c := car(id)
		assert_eq(c.traits.size(), CARS[id], "%s has %d features" % [id, CARS[id]])
		for t in c.traits:
			assert_true(CarTraits.has(t), "%s: %s is a known trait" % [id, t])
			assert_true(CarTraits.texture(t) != null, "%s has an icon" % t)
			assert_false(seen.has(t), "%s belongs to one car only" % t)
			seen[t] = true
		assert_true(c.traitRig != null, "%s has its trait rig" % id)
	assert_eq(seen.size(), CarTraits.DATA.size(), "every trait in CarTraits is on a car")

func test_flags_follow_the_traits():
	assert_true(car("audi").tDownforce, "the supercar has Downforce")
	assert_false(car("racer").tDownforce, "the racer doesn't")
	assert_true(car("semi").tDropLoad && car("semi").tUnstoppable, "the semi's two")

#--- handling ---

func test_downforce_grips_harder_with_speed():
	var c := car("audi")
	var slow := c.traitGrip(200.0, input())
	var fast := c.traitGrip(1200.0, input())
	assert_gt(fast, 1.4, "glued at speed")
	assert_gt(1.0, slow, "loose at a crawl")

func test_city_tyres_love_pavement():
	var c := car("taxi")
	assert_gt(c.surfaceGrip(T.ASPHALT), World.grip(T.ASPHALT), "more grip on asphalt")
	assert_gt(World.grip(T.DIRT), c.surfaceGrip(T.DIRT), "less on dirt")

func test_offroad_and_low_clearance_on_rough_ground():
	var pickup := car("pickup")
	var audi := car("audi")
	var plain := car("taxi")
	assert_gt(plain.groundFriction(T.SAND), pickup.groundFriction(T.SAND), "sand drags the pickup less")
	assert_gt(audi.groundFriction(T.SAND), plain.groundFriction(T.SAND), "and the supercar more")
	assert_gt(pickup.surfaceGrip(T.MUD), World.grip(T.MUD), "the pickup keeps its grip in mud")
	assert_almost_eq(pickup.groundFriction(T.ASPHALT), plain.groundFriction(T.ASPHALT), 0.0001, "paved ground is the same for everyone")

func test_drift_king_slides_looser():
	var racer := car("racer")
	var king := racer.handbrakeGrip()
	racer.tDriftKing = false
	assert_gt(racer.handbrakeGrip(), king, "the handbrake lets the rear go further")
	racer.tDriftKing = true
	assert_eq(racer.tierFor(170), OverheadCarBody2D.DRIFT_TIERS.size(), "a long slide reaches the third tier")
	assert_eq(car("audi").tierFor(170), OverheadCarBody2D.DRIFT_TIERS.size() - 1, "others top out at two")

func test_top_heavy_grips_less_on_two_wheels():
	var van := car("van")
	var down := van.traitGrip(600.0, input(1.0, 1.0))
	van.twoWheels = true
	assert_gt(down, van.traitGrip(600.0, input(1.0, 1.0)), "up on two wheels it grips less")

func test_box_sway_bites_on_the_brakes():
	var amb := car("ambulance")
	assert_gt(amb.traitSteer(600.0, input(1.0, 0.0, true)), amb.traitSteer(600.0, input(1.0, 0.0)), "braking turns it in harder")
	assert_gt(1.0, amb.traitGrip(600.0, input(1.0, 1.0)), "power through a hard corner and the tail steps out")

func test_an_empty_trailer_is_lighter():
	var semi := car("semi")
	var full := semi.effectiveWeight()
	semi.loadDropped = true
	assert_gt(full, semi.effectiveWeight(), "running empty sheds weight")

func test_unstoppable_smashes_at_any_speed():
	var crate := StaticBody2D.new()
	crate.set_meta(&"smashSpeed", 300.0)
	var barrel := StaticBody2D.new()
	barrel.set_meta(&"smashSpeed", 300.0)
	barrel.set_meta(&"explosive", true)
	assert_eq(car("semi").smashThreshold(crate), 0.0, "a crate at walking pace")
	assert_eq(car("semi").smashThreshold(barrel), 300.0, "but explosives still need a hit")
	assert_eq(car("sedan").smashThreshold(crate), 300.0, "other cars need the run-up")
	crate.free()
	barrel.free()

#--- rules ---

func test_second_wind_once():
	var c := car("sedan")
	c.fuel = 0.0
	c.outOfFuel()
	assert_almost_eq(c.fuel, OverheadCarBody2D.SECOND_WIND_FUEL, 0.001, "it starts again with a splash of fuel")
	assert_false(c.isDestroyed, "and keeps going")
	assert_true(c.secondWindUsed, "once")

func test_defibrillator_once():
	var c := car("ambulance")
	c.loseHealth(150.0)
	assert_almost_eq(c.health, OverheadCarBody2D.DEFIB_HEALTH, 0.001, "shocked back")
	assert_false(c.isDestroyed, "still running")
	assert_true(c.defibUsed, "and the paddles are spent")

func test_cargo_bay_holds_two_gadgets():
	var van := car("van")
	assert_true(van.giveItem("mine"), "the first")
	assert_true(van.giveItem("flare"), "and a second, stowed")
	assert_eq(van.heldItem, "mine")
	assert_eq(van.spareItem, "flare")
	var sedan := car("sedan")
	sedan.giveItem("mine")
	sedan.giveItem("flare")
	assert_eq(sedan.spareItem, "", "other cars have one slot")

func test_the_meter_pays_and_resets():
	var taxi := car("taxi")
	var rig := taxi.traitRig
	taxi.velocity = Vector2(900, 0)
	var before := taxi.coin
	for t in 120: rig.tickMeter(900.0, 1.0 / 60.0)
	assert_gt(taxi.coin, before, "two seconds at speed earns fares")
	rig.onWall(400.0, true)
	assert_eq(rig.meterTicks, 0, "a wall hit resets the meter")

func test_the_bed_loads_and_spills():
	var pickup := car("pickup")
	var rig := pickup.traitRig
	for i in 7: rig.onRewarded("magnet", 1)
	assert_eq(rig.bedCrates, CarTraitRig.BED_MAX, "loads up to five crates")
	assert_almost_eq(rig.payoutBonus(), 1.25, 0.001, "worth 25% more pay")
	rig.onRewarded("coin", 5)
	assert_eq(rig.bedCrates, CarTraitRig.BED_MAX, "loose coins aren't cargo")
	rig.onWall(500.0, true)
	assert_eq(rig.bedCrates, CarTraitRig.BED_MAX - 1, "a hard hit spills one")
	rig.onWall(100.0, true)
	assert_eq(rig.bedCrates, CarTraitRig.BED_MAX - 1, "a nudge doesn't")

func test_duct_tape_patches_after_a_clean_spell():
	var c := car("sedan")
	c.setCondition("engine", 20.0)
	c.velocity = Vector2(300, 0)
	c.lastHurtTick = Engine.get_physics_frames() - CarTraitRig.TAPE_WAIT - 1
	c.traitRig.tickTape(Engine.get_physics_frames(), 300.0)
	assert_gt(c.condition.engine, 20.0, "the engine gets patched")
	c.setCondition("lights", 70.0)
	c.traitRig.tickTape(Engine.get_physics_frames(), 300.0)
	assert_almost_eq(c.condition.lights, 70.0, 0.001, "but never above the tape's 60%")

func test_the_van_tips_and_rolls():
	var van := car("van")
	var rig := van.traitRig
	van.twoWheels = true
	van.velocity = Vector2(700, 0)
	rig.onWall(400.0, true)
	assert_false(van.twoWheels, "a hit while up rolls it")
	assert_gt(rig.controlLock, 0, "and it takes a moment to right itself")
	assert_gt(700.0 * 0.5, van.velocity.length(), "losing most of its speed")

func test_the_lightbar_is_built():
	var police := car("police")
	assert_eq(police.traitRig.lightbar.size(), 2, "a red and a blue")
	for l in police.traitRig.lightbar: assert_eq(l.get_parent(), police.get_node("headlamps"), "on with the headlights, at night")

func test_drop_the_load():
	var level := Node2D.new()
	add_child_autofree(level)
	var before = Root.levelRoot
	Root.levelRoot = level
	var semi := car("semi")
	semi.global_position = Vector2(4000, 4000)
	semi.trailer.placeBehind()
	var rig := semi.traitRig
	assert_eq(rig.abilityReady(), 1.0, "loaded and ready")
	rig.dropLoad()
	Root.levelRoot = before
	var crates := level.get_children().filter(func(n): return n is StaticBody2D)
	assert_eq(crates.size(), CarTraitRig.DROP_CRATES, "the cargo lands as crates")
	assert_true(crates.all(func(c): return c.get_meta(&"dropped", false) && BreakableProp.isBreakable(c)), "breakable, and worth no coins")
	assert_true(crates.all(func(c): return c.global_position.distance_to(semi.trailer.global_position) < 500.0), "behind the trailer")
	assert_true(semi.loadDropped, "the trailer runs empty")
	assert_gt(1.0, rig.abilityReady(), "and restocks before it can drop again")
	for t in int(CarTraitRig.DROP_RESTOCK * Engine.physics_ticks_per_second): rig.tickDrop()
	assert_false(semi.loadDropped, "restocked")

#--- across the garage ---

func test_weight_changes_the_crush_speed():
	assert_almost_eq(car("police").crushWeight(), 1.0, 0.001, "weight 50 crushes as before")
	assert_almost_eq(1.0 / car("semi").crushWeight(), 0.7, 0.01, "the semi at 70% of the speed")
	assert_gt(1.0 / car("racer").crushWeight(), 1.15, "the racer needs more")
	var semi := car("semi")
	var full := semi.crushWeight()
	semi.loadDropped = true
	assert_gt(full, semi.crushWeight(), "an empty trailer crushes a little less")

func test_every_car_has_a_horn():
	for id in CARS:
		var c := car(id)
		assert_true(c.hornSound != null, "%s has its own horn (sound/horn/%s.wav)" % [id, id])
	assert_true(InputMap.has_action("Horn") && InputMap.has_action("Ability"), "both actions exist")
	assert_true(Settings.REBINDABLE.has("Horn") && Settings.REBINDABLE.has("Ability"), "and can be rebound")
