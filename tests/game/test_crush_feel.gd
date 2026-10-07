extends GameTest

#Package 2, crush feel (docs/GOONS.md, "Crush feel"): what a crush leaves (GoonFx.crushed), the crush
#bonuses CrushFeel pays, the contact chip, the giant scale and the best-combo record.

var savedManager
var savedCar
var savedCrushFx

func before_each():
	savedManager = Root.spawnManager
	savedCar = Root.playerCar
	savedCrushFx = Settings.get_value("gfx/crush_fx")

func after_each():
	Settings.set_value("gfx/crush_fx", savedCrushFx, false)
	Root.spawnManager = savedManager
	Root.playerCar = savedCar

func makeManager() -> SpawnManager:
	var manager: SpawnManager = add_child_autofree(load("res://scene/enemy/spawnManager.tscn").instantiate())
	Root.spawnManager = manager
	return manager

func makeCar():
	var car = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	Root.playerCar = car
	return car

func spawnGoon(id: StringName, at := Vector2.ZERO, giant := false) -> Walker:
	var goon: Walker = load(Goons.scenePath(id)).instantiate()
	goon.isGiant = giant
	goon.position = at
	add_child_autofree(goon)
	return goon

const NOSE := Vector2(110, 0)  #a goon met dead centre by the bumper, in car space
const CORNER := Vector2(110, 44)

func styles(speed: float, local: Vector2, giant := false) -> Dictionary:
	var seen := {}
	for i in 200:
		var s := GoonFx.deathStyle(speed, local, giant, i / 200.0)
		seen[s] = seen.get(s, 0) + 1
	return seen

func test_fast_crushes_die_every_way():
	var seen := styles(650.0, NOSE)
	for style in [&"splat", &"shove", &"hood", &"fling"]: assert_true(seen.has(style), "650 px/s on the nose: %s" % style)

func test_slow_crushes_never_fly_or_ride_the_hood():
	var seen := styles(200.0, NOSE)
	assert_false(seen.has(&"fling"), "no fling at 200 px/s")
	assert_false(seen.has(&"hood"), "no hood ride at 200 px/s")

func test_corner_hits_shove_more_and_rarely_ride():
	var corner := styles(500.0, CORNER)
	var nose := styles(500.0, NOSE)
	assert_true(corner.get(&"shove", 0) > nose.get(&"shove", 0), "a corner hit shoves more often than the nose")
	assert_true(corner.get(&"hood", 0) < nose.get(&"hood", 0) / 3, "and rarely lands on the hood")

func test_under_35_mph_is_nearly_always_a_splat():
	for speed in [150.0, 300.0, 340.0]:
		for at in [NOSE, CORNER]:
			assert_true(styles(speed, at).get(&"splat", 0) >= 160, "%d px/s: at least 80%% splat" % speed)

func test_a_shove_goes_the_way_of_the_hit():
	makeManager()
	var car = makeCar()
	car.rotation = 0.0
	car.velocity = Vector2(400, 0)
	for at in [NOSE, CORNER, Vector2(110, -44)]:
		assert_true(GoonFx.shoveDir(car, at).dot(Vector2.RIGHT) > 0.9, "forward, not to the side (%s)" % at)

func test_a_slow_shove_is_only_a_nudge():
	var manager := makeManager()
	makeCar()
	var src := manager.fx.bodyOf(spawnGoon(&"grunt", Vector2(0, 400)))
	manager.fx.shove(src, Vector2.RIGHT, 300.0)
	var c: Dictionary = manager.fx.corpses[0]
	var start: Vector2 = c.s.global_position
	for i in 120:
		if not manager.fx.corpses.is_empty(): manager.fx.stepCorpse(c, 0.016)
	assert_true(c.s.global_position.distance_to(start) < 70.0, "300 px/s pushes it under 70 px")

func test_giants_only_splat():
	assert_eq(styles(900.0, NOSE, true).keys(), [&"splat"])

func test_a_crush_leaves_a_body_and_minimal_does_not():
	var manager := makeManager()
	var car = makeCar()
	Settings.set_value("gfx/crush_fx", 2, false)
	car.velocity = Vector2(650, 0)
	spawnGoon(&"grunt", Vector2(100, 0)).destroy(&"crush")
	assert_eq(manager.fx.corpses.size(), 1, "one body: squashed, shoved, riding or flying")
	Settings.set_value("gfx/crush_fx", 0, false)
	spawnGoon(&"grunt", Vector2(100, 300)).destroy(&"crush")
	assert_eq(manager.fx.corpses.size(), 1, "Minimal adds no body")

func test_a_blast_flings_its_goons():
	var manager := makeManager()
	makeCar()
	Settings.set_value("gfx/crush_fx", 2, false)
	var goon := spawnGoon(&"grunt", Vector2(0, 300))
	goon.killedFrom = Vector2(0, 250)
	goon.destroy(&"boom")
	assert_eq(manager.fx.corpses[0].kind, "fling")
	assert_true(manager.fx.corpses[0].dir.y > 0.0, "away from the blast")

func test_a_hood_rider_is_thrown_off_when_the_car_brakes():
	var manager := makeManager()
	var car = makeCar()
	var src := manager.fx.bodyOf(spawnGoon(&"grunt", Vector2(100, 0)))
	manager.fx.hood(src, car, Vector2(100, 0))
	car.velocity = Vector2(500, 0)
	manager.fx.stepCorpse(manager.fx.corpses[0], 0.016)
	assert_eq(manager.fx.corpses[0].kind, "hood", "still riding at 500 px/s")
	car.velocity = Vector2(50, 0)
	manager.fx.stepCorpse(manager.fx.corpses[0], 0.016)
	assert_eq(manager.fx.corpses.size(), 1, "the same body...")
	assert_eq(manager.fx.corpses[0].kind, "fling", "...goes over the nose")
	assert_true(manager.fx.corpses[0].s.visible, "and its sprite is still shown")

func test_a_shoved_body_slides_to_a_stop_and_lies_down():
	var manager := makeManager()
	makeCar()
	var src := manager.fx.bodyOf(spawnGoon(&"grunt", Vector2(0, 400)))
	manager.fx.shove(src, Vector2.RIGHT, 500.0)
	var c: Dictionary = manager.fx.corpses[0]
	var start: Vector2 = c.s.global_position
	var decals := manager.fx.decalPool.size()
	for i in 120:
		if not manager.fx.corpses.is_empty(): manager.fx.stepCorpse(c, 0.016)
	assert_true(manager.fx.corpses.is_empty(), "it stopped")
	assert_true(c.s.global_position.x > start.x + 50.0, "after sliding")
	assert_eq(manager.fx.decalPool.size(), decals + 1, "and lies where it stopped")
	assert_false(c.smear.drops.is_empty(), "leaving a smear")

func test_a_flung_goon_lands_as_a_decal():
	var manager := makeManager()
	makeCar()
	manager.fx.fling(manager.fx.bodyOf(spawnGoon(&"grunt")), Vector2.RIGHT, 600.0)
	var c: Dictionary = manager.fx.corpses[0]
	var decals := manager.fx.decalPool.size()
	manager.fx.stepCorpse(c, c.T + 0.01)
	assert_true(manager.fx.corpses.is_empty(), "landed")
	assert_eq(manager.fx.decalPool.size(), decals + 1, "its decal is laid where it landed")

func test_giant_scale_multiplies_the_scene_scale():
	makeManager()
	makeCar()
	var giant := spawnGoon(&"grunt", Vector2.ZERO, true)
	assert_almost_eq(giant.scale.x, Walker.GIANT_SCALE, 0.001)

func test_multi_crush_pays_per_extra_goon():
	makeManager()
	var car = makeCar()
	var feel: CrushFeel = car.crushFeel
	assert_true(feel != null, "the player's car owns a CrushFeel")
	var before: int = car.coin
	for i in 3: feel.countMulti(Vector2.ZERO)
	feel.payMulti()
	assert_eq(car.coin - before, 2 * CrushFeel.MULTI_COINS, "a triple pays for two extra goons")
	before = car.coin
	feel.countMulti(Vector2.ZERO)
	feel.payMulti()
	assert_eq(car.coin, before, "a single crush is no multi")

func test_giant_slayer_pays_and_slows_the_car():
	makeManager()
	var car = makeCar()
	car.velocity = Vector2(500, 0)
	var before: int = car.coin
	car.crushFeel.onCrush(spawnGoon(&"grunt", Vector2.ZERO, true), 500.0)
	assert_eq(car.coin - before, CrushFeel.GIANT_COINS)
	assert_almost_eq(car.velocity.length(), 500.0 * CrushFeel.GIANT_SPEED_KEEP, 0.01)

func test_drift_crush_pays_only_when_sliding():
	makeManager()
	var car = makeCar()
	car.rotation = 0.0
	car.velocity = Vector2(400, 0)
	var before: int = car.coin
	car.crushFeel.onCrush(spawnGoon(&"grunt"), 400.0)
	assert_eq(car.coin, before, "straight on: no drift bonus")
	car.velocity = Vector2.from_angle(0.7) * 400.0
	car.crushFeel.onCrush(spawnGoon(&"grunt", Vector2(0, 300)), 400.0)
	assert_eq(car.coin - before, CrushFeel.DRIFT_COINS, "sliding 0.7 rad: a drift crush")

func test_crush_chip_never_spends_a_shield():
	assert_true(OverheadCarBody2D.GOON_CONTACT_DAMAGE <= 5.0, "blockedByPickup spends a charge above 5")
	var car = makeCar()
	car.addBuff("shield")
	var hits: int = car.shieldHits
	car.damage(OverheadCarBody2D.GOON_CONTACT_DAMAGE)
	assert_eq(car.shieldHits, hits)

func test_hit_stop_is_off_under_the_harnesses():
	makeManager()
	var car = makeCar()
	car.crushFeel.hitStop(CrushFeel.HIT_STOP_GIANT, false)
	assert_eq(Engine.time_scale, 1.0, "headless runs never change the time scale")

func test_a_drifting_car_slams_goons_with_its_side():
	var manager := makeManager()
	var car = makeCar()
	car.velocity = Vector2(0, 400) #sliding sideways, toward +y
	var goon := spawnGoon(&"grunt", Vector2(0, 48))
	manager.goons.push_back(goon)
	car.slamGoons()
	assert_true(goon.dead, "the flank crushes it")
	assert_eq(car.crushHitVel, Vector2.ZERO, "the slam's velocity is cleared after")

func test_the_tail_swings_into_goons():
	var manager := makeManager()
	var car = makeCar()
	car.velocity = Vector2.ZERO
	car.spinRate = -6.0 #the tail swinging toward +y
	var goon := spawnGoon(&"grunt", Vector2(-60, 50))
	manager.goons.push_back(goon)
	car.slamGoons()
	assert_true(goon.dead, "the swinging tail crushes it")

func test_the_bumper_still_owns_the_front_and_slow_sides_do_nothing():
	var manager := makeManager()
	var car = makeCar()
	car.velocity = Vector2(400, 0)
	var ahead := spawnGoon(&"grunt", Vector2(95, 0))
	var beside := spawnGoon(&"grunt", Vector2(0, 48))
	manager.goons.append_array([ahead, beside])
	car.slamGoons()
	assert_false(ahead.dead, "the front is the bumper's collision, not a slam")
	assert_false(beside.dead, "driving past a goon isn't slamming it")

func test_drift_charge_tiers_and_release():
	assert_eq(OverheadCarBody2D.driftTier(20), -1, "too short a slide")
	assert_eq(OverheadCarBody2D.driftTier(OverheadCarBody2D.DRIFT_TIERS[0][0]), 0)
	assert_eq(OverheadCarBody2D.driftTier(500), OverheadCarBody2D.DRIFT_TIERS.size() - 1)
	makeManager()
	var car = makeCar()
	car.rotation = 0.0
	car.velocity = Vector2(300, 0)
	car.driftCharge = OverheadCarBody2D.DRIFT_TIERS[1][0]
	car._car_input.handbrake = false
	car.tickDriftCharge()
	assert_almost_eq(car.velocity.x, 300.0 + OverheadCarBody2D.DRIFT_TIERS[1][1], 0.01, "letting go fires the boost along the nose")
	assert_eq(car.driftCharge, 0)

func test_holding_a_slide_charges():
	makeManager()
	var car = makeCar()
	car.rotation = 0.0
	car.velocity = Vector2.from_angle(0.6) * 500.0
	car._car_input.handbrake = true
	for i in 10: car.tickDriftCharge()
	assert_eq(car.driftCharge, 10)
	car.velocity = Vector2(500, 0) #straight again: no charge, but none lost
	car.tickDriftCharge()
	assert_eq(car.driftCharge, 10)

func test_combo_heat():
	assert_eq(HudChance.comboColor(3), HudTheme.GOLD)
	assert_eq(HudChance.comboColor(25), HudTheme.BAD)

func test_best_combo_record_is_added_to_old_saves():
	var original = SaveManager.playerData
	var data = PlayerData.new()
	data.cars[0].records.erase("combo")
	SaveManager.playerData = data
	SaveManager.migrate()
	assert_eq(SaveManager.playerData.cars[0].records.get("combo", -1), 0)
	SaveManager.playerData = original
	SaveManager.dirty = false
