class_name Gadgets extends RefCounted

#Held gadgets (Pickups.K.GADGET, the Fire button) and boosts (Pickups.K.MOVE, the Boost button): what
#each does when fired, and when the AI driver fires one.
#Things a gadget leaves in the world (mines, slicks, flares, bait, the hubcap) are PickupNodes.

const AI_EVERY := 20 #ticks between the AI driver's checks

## Uses one charge of `id`. False when it can't be used right now (the charge is kept).
static func use(car, id: String) -> bool:
	var d := Pickups.def(id)
	if id == "nitro": #only the car's own burn, so it needs no level; a second charge while one burns adds its time
		car.addBuff("nitro")
		PickupEffects.label(car.global_position, "NITRO")
		return true
	var sm = Root.spawnManager
	if not is_instance_valid(sm) || not is_instance_valid(Root.levelRoot): return false
	var rear: Vector2 = car.to_global(Vector2(-130, 0))
	match id:
		"horn":
			for goon in sm.goonsNear(car.global_position, d.radius): stun(goon, d.stun, (goon.global_position - car.global_position).normalized() * 320.0)
			sm.fx.ring(car.global_position, d.radius)
			PickupEffects.label(car.global_position, "HONK")
		"oilslick": addNode(PickupNodes.OilSlick.new(), rear)
		"mine": addNode(PickupNodes.Mine.new(), rear)
		"flare": addNode(PickupNodes.Flare.new(), car.global_position)
		"bait": addNode(PickupNodes.Bait.new(), rear)
		"emp":
			for goon in sm.goonsNear(car.global_position, d.radius):
				if goon.def.get("faction", -1) == Goons.faction.SCRAP || goon.state == &"riding": stun(goon, 5.0, Vector2.ZERO)
			sm.fx.tethers.clear() #harpoons and tow magnets let go
			sm.fx.ring(car.global_position, 300.0)
			PickupEffects.label(car.global_position, "EMP")
		"jets", "hop":
			if car.airborneTicks > 0: return false
			car.airborneTicks = int(d.secs * Pickups.TICKS)
			car.landingBlast = id == "jets"
			car.set_collision_mask_value(3, false) #over goons; rocks and walls still stop the car
			var sprite: Node2D = car.get_node("sprite")
			var base: Vector2 = sprite.scale
			var tween = sprite.create_tween()
			tween.tween_property(sprite, "scale", base * d.get("lift", 1.3), d.secs * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", base, d.secs * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		"hubcap":
			var cap = PickupNodes.Hubcap.new()
			cap.bounces = d.bounces
			cap.heading = Vector2.from_angle(car.rotation)
			addNode(cap, car.to_global(Vector2(80, 0)))
		"airstrike":
			for i in 3: sm.fx.blastLater(car.to_global(Vector2(400 + i * 220, 0)), 0.35 + i * 0.3, d.radius, 0.0)
			PickupEffects.label(car.global_position, "INCOMING")
		"pocket":
			PickupEffects.supply(car, "service", {})
			PickupEffects.label(car.global_position, "PIT STOP")
		"nuke":
			var view: Rect2 = Root.levelRoot.get_viewport().get_canvas_transform().affine_inverse() * Root.levelRoot.get_viewport().get_visible_rect()
			for goon in sm.goons.duplicate():
				if is_instance_valid(goon) && view.has_point(goon.global_position): CarBuffFx.kill(goon)
			if is_instance_valid(HudChance.current): HudChance.current.flash()
		_: return false
	return true

static func addNode(node: Node2D, pos: Vector2) -> void:
	node.position = pos
	Root.levelRoot.add_child.call_deferred(node)

## Stuns a goon, first throwing off one riding the car.
static func stun(goon, seconds: float, push: Vector2) -> void:
	if not is_instance_valid(goon) || goon.dead || goon.verb == null: return
	if goon.state == &"riding":
		goon.z_index = 0
		goon.setSolid(true)
		goon.invulnerable = false
	elif goon.invulnerable: return #a flyer up high or a goon underground
	goon.verb.stunFor(seconds, push)

## Jump Jets and Hop come down; Jump Jets flatten everything around the car.
static func land(car) -> void:
	car.set_collision_mask_value(3, true)
	if is_instance_valid(car.juice): car.juice.land(car.landingBlast)
	if not car.landingBlast || not is_instance_valid(Root.spawnManager): return
	var r: float = Pickups.DATA["jets"]["radius"]
	for goon in Root.spawnManager.goonsNear(car.global_position, r): CarBuffFx.kill(goon)
	Root.spawnManager.fx.ring(car.global_position, r)

## The AI driver (playtests) uses a gadget when the moment is right. True on the tick it decides to.
static func aiWantsUse(car) -> bool:
	if Engine.get_physics_frames() % AI_EVERY != 0 || not is_instance_valid(Root.spawnManager): return false
	var sm = Root.spawnManager
	var pos: Vector2 = car.global_position
	match car.heldItem:
		"horn": return sm.goonsNear(pos, 350.0).size() >= 3
		"emp": return sm.goonsNear(pos, 700.0).any(func(g): return g.def.get("faction", -1) == Goons.faction.SCRAP)
		"mine", "oilslick": return sm.goonsNear(pos, 450.0).any(func(g): return car.to_local(g.global_position).x < 0.0)
		"flare": return sm.isNight
		"bait": return SaveManager.playerData.gameMode == Root.gameModes.DEFENSE || sm.goonsNear(pos, 600.0).size() >= 6
		"hubcap", "airstrike": return sm.goonsNear(pos, 800.0).size() >= 3
		"pocket": return car.fuel < 25.0 || car.health < 30.0
		"nuke": return sm.goonsNear(pos, 1100.0).size() >= 12
	return false

## The same for the Boost slot: Nitro on a straight with goons ahead, Hop and Jump Jets out of a crowd.
static func aiWantsMove(car) -> bool:
	if Engine.get_physics_frames() % AI_EVERY != 0 || not is_instance_valid(Root.spawnManager): return false
	var sm = Root.spawnManager
	var pos: Vector2 = car.global_position
	match car.moveItem:
		"nitro":
			if car.hasBuff("nitro") || car.velocity.length() < 300.0 || absf(car._car_input.steering) > 0.2: return false
			return sm.goonsNear(pos, 900.0).filter(func(g): return car.to_local(g.global_position).x > 0.0).size() >= 3
		"jets": return sm.goonsNear(pos, 250.0).size() >= 4
		"hop": return sm.goonsNear(pos, 200.0).size() >= 4 || (car.health < 40.0 && sm.goonsNear(pos, 200.0).size() >= 2)
	return false
