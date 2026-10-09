extends GameTest

#Package 14 (docs/WORLD.md "Prop reactions", docs/WORLD_ART.md "Layered props"): tree crowns and the crane's jib
#draw over the car and fade while the car is under them (never for goons), props answer hits by kind and settle
#back at rest, cones knock over and stop being walls, blasts shake nearby crowns, and pooled props come back clean.

#the HUD a car reports to, outside a run
class UiStub extends RefCounted:
	func updateStats() -> void: pass
	func updateGoonsCrushed() -> void: pass

const LAYERED := ["oak", "pine", "cypress", "deadtree", "crane", "pine_snow", "palm"]

var savedCar
var reactions: PropReactions

func before_each():
	savedCar = Root.playerCar
	reactions = PropReactions.new(&"meadow", {})
	add_child_autofree(reactions)
	reactions.particleScale = 1.0
	reactions.calm = false

func after_each():
	Root.playerCar = savedCar if is_instance_valid(savedCar) else null

func prop(id: String, at := Vector2.ZERO) -> StaticBody2D:
	var node: StaticBody2D = load("res://world/art/props/%s.tscn" % id).instantiate()
	node.position = at
	add_child_autofree(node)
	return node

func makeCar(at: Vector2) -> OverheadCarBody2D:
	var car: OverheadCarBody2D = load("res://scene/car/sedan/sedan.tscn").instantiate()
	car.position = at
	add_child_autofree(car)
	car.ui = UiStub.new()
	Root.playerCar = car
	return car

func manifest() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://world/art/props.json"))
	return data.get("props", {}) if data is Dictionary else {}

func step(seconds: float, frames := 10) -> void:
	for i in frames: reactions._process(seconds / frames)

func test_layered_props_draw_their_canopy_over_the_car():
	var props := manifest()
	for id in LAYERED:
		var entry: Dictionary = props.get(id, {})
		assert_true(entry.get("canopy") is Array && entry.canopy.size() == entry.variants.size(), "%s: a canopy per variant" % id)
		var node := prop(id)
		var canopy: Sprite2D = node.get_node_or_null("Canopy")
		assert_true(canopy != null && canopy.texture != null, "%s: a Canopy sprite" % id)
		if canopy:
			assert_false(canopy.z_as_relative, "%s: absolute z" % id)
			assert_eq(canopy.z_index, PropReactions.CANOPY_Z, "%s: over goons and the car" % id)
	assert_true(PropReactions.CANOPY_Z > 6, "above the highest goon layer (GoonFx top, 6)")
	assert_false(props.saguaro.has("canopy"), "the saguaro stays one piece")
	for id in ["oak", "pine", "cypress", "deadtree", "pine_snow", "palm"]: assert_true(ResourceLoader.exists(props[id].get("leaves", "")), "%s drops leaves" % id)

func test_a_canopy_fades_while_the_car_is_under_it_only():
	var oak := prop("oak", Vector2(0, 0))
	var canopy: Sprite2D = oak.get_node("Canopy")
	reactions.addCanopy(oak, canopy)
	var car := makeCar(Vector2(2000, 0))
	step(1.0)
	assert_almost_eq(canopy.modulate.a, 1.0, 0.001, "car far away: solid")
	car.global_position = Vector2(60, 40)
	step(1.0)
	assert_almost_eq(canopy.modulate.a, PropReactions.FADE_ALPHA, 0.001, "car under the crown: see-through")
	car.global_position = Vector2(2000, 0)
	step(1.0)
	assert_almost_eq(canopy.modulate.a, 1.0, 0.001, "and back")
	Root.playerCar = null
	step(1.0)
	assert_almost_eq(canopy.modulate.a, 1.0, 0.001, "no car (goons never fade it)")

func test_the_cranes_jib_counts_as_its_box():
	var crane := prop("crane", Vector2.ZERO)
	var canopy: Sprite2D = crane.get_node("Canopy")
	reactions.addCanopy(crane, canopy)
	var entry: Array = reactions.canopies[0]
	assert_true(entry[3], "tested as a box")
	var tip: Vector2 = canopy.to_global(entry[2].get_center())
	assert_true(PropReactions.isUnder(canopy, entry[2], true, tip), "under the middle of the jib")
	assert_false(PropReactions.isUnder(canopy, entry[2], true, tip + Vector2(0, 400)), "well off to the side")

func test_a_hit_tree_shakes_drops_leaves_and_settles():
	var oak := prop("oak")
	reactions.leafTextures = {&"oak": load(manifest().oak.leaves)}
	var canopy: Sprite2D = oak.get_node("Canopy")
	reactions.addCanopy(oak, canopy)
	PropReactions.hit(oak, Vector2(500, 0))
	step(0.08, 2)
	assert_true(canopy.position.length() > 0.5, "the crown moves")
	assert_true(reactions.bits.alive >= PropReactions.LEAVES.x, "leaves fall")
	step(3.0, 60)
	assert_eq(canopy.position, Vector2.ZERO, "settled back")
	assert_eq(reactions.springs.size(), 0, "nothing left running")

func test_no_bits_at_minimal_driving_effects():
	var oak := prop("oak")
	reactions.leafTextures = {&"oak": load(manifest().oak.leaves)}
	reactions.addCanopy(oak, oak.get_node("Canopy"))
	reactions.particleScale = 0.0
	PropReactions.hit(oak, Vector2(500, 0))
	assert_eq(reactions.bits.alive, 0, "no leaves")
	assert_eq(reactions.dust.alive, 0, "no dust")
	assert_eq(reactions.springs.size(), 1, "the crown still shakes")

func test_props_answer_by_kind():
	var rock := prop("rock")
	PropReactions.hit(rock, Vector2(500, 0))
	assert_eq(reactions.springs.size(), 0, "a rock only thuds")
	assert_true(reactions.dust.alive > 0, "and dusts")
	var hedge := prop("hedge", Vector2(600, 0))
	var sprite: Sprite2D = hedge.get_node("Sprite2D")
	var rest := sprite.scale
	PropReactions.hit(hedge, Vector2(0, 400))
	step(0.06, 2)
	assert_false(sprite.scale == rest, "a hedge squashes")
	step(3.0, 60)
	assert_eq(sprite.scale, rest, "and springs back")
	var sign := prop("sign", Vector2(-600, 0))
	PropReactions.hit(sign, Vector2(300, 0))
	step(0.06, 2)
	assert_false(sign.get_node("Sprite2D").rotation == 0.0, "a sign wobbles")
	var slow := prop("shack", Vector2(0, 900))
	PropReactions.hit(slow, Vector2(PropReactions.MIN_SPEED * 0.5, 0))
	assert_false(reactions.springs.any(func(e): return e[8] == slow), "too slow to react")

func test_a_hydrant_sprays_for_a_while():
	var hydrant := prop("hydrant")
	PropReactions.hit(hydrant, Vector2(400, 0))
	assert_eq(reactions.sprays.size(), 1, "spraying")
	step(0.5, 10)
	assert_true(reactions.dust.alive > 0, "droplets")
	step(PropReactions.SPRAY_SECONDS + 0.5, 30)
	assert_eq(reactions.sprays.size(), 0, "and it stops")

func test_cones_knock_over_and_stop_being_walls():
	var cone := prop("cone")
	assert_false(PropReactions.knocks(cone, Vector2(PropReactions.KNOCK_SPEED * 0.5, 0)), "too slow: still a wall")
	assert_false(PropReactions.knocks(prop("rock"), Vector2(900, 0)), "only cones")
	assert_true(PropReactions.knocks(cone, Vector2(400, 0)), "fast enough: it flies")
	assert_false(PropReactions.knocks(cone, Vector2(400, 0)), "once")
	await get_tree().physics_frame
	assert_true(cone.get_node("CollisionShape2D").disabled, "the car drives through")
	step(1.0, 20)
	assert_true(cone.get_node("Sprite2D").position.length() > PropReactions.KNOCK_DISTANCE.x * 0.5, "it landed away from its spot")
	PropReactions.reset(cone)
	assert_false(cone.get_node("CollisionShape2D").disabled, "a reused cone stands again")
	assert_eq(cone.get_node("Sprite2D").position, Vector2.ZERO, "where it belongs")

func test_blasts_shake_nearby_crowns_only():
	var near := prop("pine", Vector2(200, 0))
	var far := prop("pine", Vector2(3000, 0))
	reactions.addCanopy(near, near.get_node("Canopy"))
	reactions.addCanopy(far, far.get_node("Canopy"))
	PropReactions.blast(Vector2.ZERO, 170.0)
	assert_true(reactions.springs.any(func(e): return e[8] == near), "the near crown shakes")
	assert_false(reactions.springs.any(func(e): return e[8] == far), "the far one doesn't")

func test_forget_puts_a_prop_at_rest():
	var oak := prop("oak")
	var canopy: Sprite2D = oak.get_node("Canopy")
	reactions.addCanopy(oak, canopy)
	PropReactions.hit(oak, Vector2(500, 0))
	step(0.05, 1)
	reactions.forget(oak)
	assert_eq(canopy.position, Vector2.ZERO, "at rest")
	assert_eq(reactions.springs.size() + reactions.canopies.size(), 0, "nothing kept")

func test_the_ai_plans_through_standing_cones():
	var cone := prop("cone")
	assert_true(AIDriver.smashableAt(cone, PropReactions.KNOCK_SPEED * 1.2), "fast enough: a cone is no wall")
	assert_false(AIDriver.smashableAt(cone, PropReactions.KNOCK_SPEED * 0.5), "too slow: it is")
	PropReactions.knocks(cone, Vector2(400, 0))
	assert_false(PropReactions.isKnockable(cone), "a knocked cone is out of the plan")
	assert_false(PropReactions.isKnockable(prop("rock", Vector2(900, 0))), "rocks stay walls")

func test_a_near_miss_on_a_breakable_cracks():
	var fence := prop("fence")
	var smash := BreakableProp.speedOf(fence)
	PropReactions.hit(fence, Vector2(smash * 0.4, 0))
	assert_eq(reactions.bits.alive, 0, "well short: just a wobble")
	PropReactions.hit(fence, Vector2(smash * 0.95, 0))
	assert_true(reactions.bits.alive >= 2, "nearly smashed: chips fly")
	assert_true(reactions.springs[0][3] > PropReactions.SPRING[PropReactions.WOBBLE][0] * 0.9, "and it wobbles near full")

func test_tufts_and_reeds_bend_away_from_the_car():
	var skin := WorldSkin.new(Levels.get_def(&"prairie"))
	assert_true(skin.decorMaterials.has(&"tufts"), "Prairie has tufts")
	assert_eq(skin.decorMaterials[&"tufts"].get_shader_parameter("bend"), WorldSkin.BEND_DECOR[&"tufts"], "they bend")
	makeCar(Vector2(123, 456))
	reactions.updateCarPos()
	assert_eq(reactions.carShown, Vector2(123, 456), "the shader is told where the car is")
