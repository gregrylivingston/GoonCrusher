class_name WorldProps extends RefCounted

#Pickup things that live in the world: skill challenges, events and supply drops (crates are the baked
#crate prop: BreakableProp, PickupWorld.decorateChunk)
#(docs/PICKUPS.md). Chunk props are children of their chunk's object node, so they unload with it;
#events are children of the level. Every class draws itself; none needs a scene file.

const MPH_PER_PX := 0.1 #the HUD's MPH: 100 px/s is 10 MPH

static func car():
	return Root.playerCar if is_instance_valid(Root.playerCar) else null

static func say(pos: Vector2, text: String) -> void:
	PickupEffects.label(pos, text)

static func carSpeed() -> float:
	var c = car()
	return c.velocity.length() if c else 0.0

#==================================================================================================
## Something the car rams instead of crushing. The car treats any CharacterBody2D as a goon (it calls
## isDying and tryCrush), so these sit on the goon layer and keep the car's crush rules.
class RamTarget extends CharacterBody2D:
	var dead := false
	var radius := 40.0
	var age := 0.0
	var life := 0.0 #0: forever
	func _init() -> void:
		collision_layer = 4 #layer 3, Goon: the car's mask hits it
		collision_mask = 1  #the world: rocks and walls stop it
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	func _ready() -> void:
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)
	func isDying() -> bool: return dead
	func tryCrush(_car: Node2D, _speed: float) -> bool: return false
	func destroy(_cause: StringName = &"crush") -> void:
		dead = true
		queue_free()
	func _physics_process(delta: float) -> void:
		age += delta
		if life > 0.0 && age > life:
			escape()
			return
		step(delta)
	func _process(_delta: float) -> void: queue_redraw()
	func step(_delta: float) -> void: pass
	func escape() -> void:
		dead = true
		queue_free()
	## Runs from the car, wandering a little. Water and hills are just more ground to it, like goons.
	func flee(speed: float, delta: float) -> void:
		var c = WorldProps.car()
		if c == null: return
		var away: Vector2 = (global_position - c.global_position).normalized()
		var wander := Vector2.from_angle(sin(age * 0.7) * 1.2 + away.angle())
		velocity = velocity.lerp(wander * speed, minf(1.0, delta * 3.0))
		rotation = lerp_angle(rotation, velocity.angle(), minf(1.0, delta * 6.0))
		move_and_slide()

## Strongbox: ram it three times above 300 px/s.
class Strongbox extends RamTarget:
	const RAM_SPEED := 300.0
	var rams := 0
	var cooldown := 0.0
	func _init() -> void:
		super()
		radius = 46.0
	func step(delta: float) -> void: cooldown = maxf(0.0, cooldown - delta)
	func tryCrush(c: Node2D, speed: float) -> bool:
		if speed < RAM_SPEED:
			if cooldown <= 0.0: WorldProps.say(global_position, "FASTER")
			cooldown = 0.6
			return false
		if cooldown > 0.0: return false
		cooldown = 0.5
		rams += 1
		if is_instance_valid(Root.levelRoot): Root.levelRoot.explode(global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
		if rams < 3:
			WorldProps.say(global_position, "%d / 3" % rams)
			return false
		var coins := randi_range(150, 400)
		c.reward("coin", coins)
		c.reward("gem", 1)
		RewardFlyers.flyUpgrade(Root.upgrade.PURSE, global_position)
		WorldProps.say(global_position, "+%d COINS" % coins)
		destroy()
		return false
	func _draw() -> void:
		var tex := Pickups.texture("strongbox")
		draw_texture_rect(tex, Rect2(-56, -56, 112, 112), false)
		for i in rams: draw_circle(Vector2(-16 + i * 16, -66), 6.0, HudTheme.GOLD)

## Whether the run is in The Wilds (Region 1): the level's region (LevelDef.region, Territories), or, for a
## level without one, whether the district the car is in belongs to the Wild Things
static func inWilds() -> bool:
	var def := Levels.current()
	if def && def.region != &"": return def.region == &"wilds"
	return Region.currentRegion.get("faction", -1) == Goons.faction.WILD

## The Golden Goon: runs from the car; crush it for coins and a Star Fragment. In The Wilds it is a Golden
## Jackalope (R-14): the Jackalope's art in gold, bounding along in hops (drawn only: the rules are the same).
class GoldenGoon extends RamTarget:
	const HOP := 0.55       #s a bound takes
	const LIFT := 30.0      #px the art rises at the top of a bound
	const GOLD := Color(1.0, 0.84, 0.32)
	var light: PointLight2D
	var jackalope: SpriteFrames #set in The Wilds
	func _init() -> void:
		super()
		radius = 30.0
		life = Pickups.DATA["goldgoon"]["secs"]
	func _ready() -> void:
		super()
		if WorldProps.inWilds(): jackalope = load("res://scene/enemy/goons/jackalope/jackalope_frames.tres")
		light = PointLight2D.new()
		light.texture = preload("res://texture/fx/circle_05.png")
		light.texture_scale = 4.0
		light.color = Color(1.0, 0.8, 0.3)
		add_child(light)
		PickupWorld.beacon(self, Pickups.rarityColor(Pickups.R.EPIC), Pickups.texture("goldgoon"))
		Pickups.discover("goldgoon")
	func step(delta: float) -> void: flee(330.0, delta)
	func tryCrush(c: Node2D, speed: float) -> bool:
		if speed < 100.0: return false
		c.reward("coin", Pickups.DATA["goldgoon"]["coins"])
		PickupEffects.addStarFragment(c)
		RewardFlyers.flyUpgrade(Root.upgrade.PURSE, global_position)
		WorldProps.say(global_position, "+%d COINS" % Pickups.DATA["goldgoon"]["coins"])
		dead = true
		queue_free()
		return true
	func escape() -> void:
		WorldProps.say(global_position, "GOT AWAY")
		super()
	func _draw() -> void:
		if jackalope:
			drawJackalope()
			return
		draw_set_transform(Vector2.ZERO, -rotation + sin(age * 14.0) * 0.12, Vector2.ONE)
		draw_texture_rect(Pickups.texture("goldgoon"), Rect2(-48, -48, 96, 96), false)
	## Bounding along like a Jackalope's hop (GoonVerbs.Hopper.drawHop): up and down on a sine, bigger at the top,
	## its shadow left on the ground. The art faces +x, the way it runs.
	func drawJackalope() -> void:
		var u := fmod(age, HOP) / HOP
		var h := sin(PI * u)
		var anim := &"special" if jackalope.has_animation(&"special") else &"walk"
		var tex := jackalope.get_frame_texture(anim, int(u * jackalope.get_frame_count(anim)) % maxi(jackalope.get_frame_count(anim), 1))
		if tex == null: return
		var size := tex.get_size() / Goons.ART_RES * 1.5 * (1.0 + 0.3 * h)
		draw_set_transform(Vector2(3, 4), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, size.y * 0.32 * (1.0 - 0.3 * h), Color(0, 0, 0, 0.4 - 0.15 * h))
		draw_set_transform(Vector2(0, -LIFT * h).rotated(-rotation), 0.0, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false, GOLD)

## The Loot Truck: every ram spills coins; five burst it for a Rare pickup. `skin` re-skins it as a level's own
## event (PickupWorld.TRUCK_SKINS): the Hay Wagon (Orchard Lanes), the Bandit Barge (Snapper Bayou).
class LootTruck extends RamTarget:
	const SKINS := {"": [Color(0.1, 0.7, 0.6), Color(0.02, 0.26, 0.22), Color(0.08, 0.55, 0.47)],
		"haywagon": [Color(0.62, 0.36, 0.16), Color(0.3, 0.16, 0.06), Color(0.93, 0.78, 0.34)],
		"barge": [Color(0.24, 0.32, 0.18), Color(0.1, 0.13, 0.07), Color(0.55, 0.42, 0.24)]}
	var rams := 0
	var cooldown := 0.0
	var skin := ""
	func _init() -> void:
		super()
		radius = 60.0
		life = Pickups.DATA["truck"]["secs"]
	func _ready() -> void:
		super()
		PickupWorld.beacon(self, Pickups.rarityColor(Pickups.R.EPIC), Pickups.texture("truck"))
		Pickups.discover("truck")
	func step(delta: float) -> void:
		cooldown = maxf(0.0, cooldown - delta)
		flee(430.0, delta)
	func tryCrush(_c: Node2D, speed: float) -> bool:
		if speed < 200.0 || cooldown > 0.0: return false
		cooldown = 0.6
		rams += 1
		var behind := global_position - Vector2.from_angle(rotation) * 90.0
		for i in 3: PickupEffects.spawnPickup("coinstack", behind + Vector2.from_angle(randf() * TAU) * randf_range(30, 120))
		if rams < Pickups.DATA["truck"]["rams"]:
			WorldProps.say(global_position, "RAM %d / %d" % [rams, Pickups.DATA["truck"]["rams"]])
			return false
		if is_instance_valid(Root.levelRoot): Root.levelRoot.explode(global_position)
		PickupEffects.spawnPickup(Pickups.rollAtLeast(Pickups.R.RARE), global_position)
		WorldProps.say(global_position, "BUSTED OPEN")
		destroy()
		return false
	func escape() -> void:
		WorldProps.say(global_position, "GOT AWAY")
		super()
	func _draw() -> void:
		var cols: Array = SKINS.get(skin, SKINS[""])
		draw_rect(Rect2(-80, -36, 110, 72), cols[0])
		draw_rect(Rect2(-80, -36, 110, 72), cols[1], false, 4.0)
		if skin == "haywagon": #bales on the bed
			for i in 3: draw_rect(Rect2(-74 + i * 34, -28, 30, 56), cols[2])
		draw_rect(Rect2(30, -30, 46, 60), cols[2] if skin != "haywagon" else cols[0].darkened(0.2))
		draw_rect(Rect2(52, -24, 18, 48), Color(0.8, 0.94, 1.0))
		HudTheme.text(self, Vector2(-25, 12), "$", 40, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		for i in rams: draw_circle(Vector2(-60 + i * 22, -48), 6.0, HudTheme.GOLD)

## A world event's rumble: a camera shake, a pad buzz and a low thud
static func rumble(amount: float) -> void:
	var c = car()
	if c == null: return
	var feel = c.get("crushFeel")
	if is_instance_valid(feel): feel.addTrauma(amount)
	if c.get("isPlayer") && Settings.has_method("vibrate"): Settings.vibrate(0.3, 0.5, 0.25)
	Audio.play(Transition.SOUNDS["thud"], -8.0, 0.5)

## Unshaded, so night never hides a world event's tell
static func unshaded(node: CanvasItem) -> void:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	node.material = m

#==================================================================================================
## Stampede (a level's world event, PickupWorld.WORLD_EVENTS): dust on the horizon, an edge arrow and a rumble
## for WARN s, then a herd of HERD Thunderhoof (SpawnManager.spawnGroup) bursts out and is driven along `dir`,
## across the car's path AHEAD px in front of it (GoonVerbs.Herd.spook: trampling and bursting fences). After the
## drive they are an ordinary herd. A driver who ignores it is never wrecked by it: it is a herd crossing.
class Stampede extends Node2D:
	const WARN := 2.5
	const HERD := 5
	const AHEAD := 1000.0
	const SIDE := 1100.0
	const DUST := Color(0.74, 0.63, 0.47, 0.6)
	var dir := Vector2.RIGHT
	var age := 0.0
	var rumbleT := 0.0
	var herd: Array = []
	func _ready() -> void:
		z_index = 2
		WorldProps.unshaded(self)
		PickupWorld.beacon(self, HudTheme.GOLD, PickupWorld.worldEventIcon("stampede"))
		if is_instance_valid(Root.spawnManager): Root.spawnManager.requestScene(&"thunderhoof") #outside a line-up it loads now
	func _physics_process(delta: float) -> void:
		age += delta
		if not herd.is_empty() || age >= WARN:
			if herd.is_empty(): release()
			if age > WARN + GoonVerbs.Herd.DRIVE_SECONDS + 1.0: queue_free()
			return
		rumbleT -= delta
		if rumbleT <= 0.0:
			rumbleT = 0.6
			WorldProps.rumble(0.1)
	func _process(_delta: float) -> void:
		if age < WARN + 1.0: queue_redraw()
	func release() -> void:
		if not is_instance_valid(Root.spawnManager):
			queue_free()
			return
		herd = Root.spawnManager.spawnGroup(&"thunderhoof", global_position, HERD, &"graze")
		if herd.is_empty():
			queue_free()
			return
		for h in herd:
			if h.verb is GoonVerbs.Herd: h.verb.calm = &"move" #an ordinary herd once the drive is over
		if herd[0].verb is GoonVerbs.Herd: herd[0].verb.spook(global_position - dir * 300.0)
	func _draw() -> void:
		var k := clampf(age / WARN, 0.0, 1.0)
		var fade := 1.0 - clampf(age - WARN, 0.0, 1.0)
		for i in 9:
			var off := dir.orthogonal() * (i - 4) * 70.0 - dir * (40.0 + 30.0 * sin(age * 3.0 + i)) + dir * k * 120.0
			draw_circle(off, (50.0 + 40.0 * k) * (0.7 + 0.3 * sin(age * 2.0 + i * 1.7)), Color(DUST, DUST.a * fade))

#==================================================================================================
## Flash flood (a level's world event; Red Canyon): a rumble and an edge arrow upstream for WARN s, then a water
## sheet runs down the wash nearest ahead of the car at SPEED for SECONDS, following the wash's bends. It sweeps
## away goons on WASH cells in its front (SPLASH, credited near the car like any kill the player set up) and, outside
## integrate() like the oil hazard, nudges the car along the wash while the car is on it near the front. It never
## damages the car. Its node sits at the front, so the edge arrow points at the water.
class FlashFlood extends Node2D:
	const SPEED := 520.0
	const SECONDS := 8.0
	const WARN := 2.0
	const HALF := 420.0       #px either side of the wash's line it covers
	const BAND := 260.0       #px deep, the front that sweeps goons
	const CAR_BAND := 700.0   #the car is nudged while it is on the wash within this far behind the front
	const PUSH := 14.0        #px/s added to the car's velocity a tick, along the flow
	const SWEEP_EVERY := 3    #ticks between sweeps
	const STEER_EVERY := 0.25 #s between looks for the wash's bend
	const TRAIL := 16
	const WATER := Color(0.5, 0.72, 0.9, 0.55)
	const FOAM := Color(0.95, 0.98, 1.0, 0.85)
	var dir := Vector2.RIGHT
	var age := 0.0
	var steerT := 0.0
	var rumbleT := 0.0
	var swept := 0
	var trail := PackedVector2Array() #where the front has been, world px
	func _ready() -> void:
		z_index = 1
		WorldProps.unshaded(self)
		PickupWorld.beacon(self, Color(0.45, 0.75, 1.0), PickupWorld.worldEventIcon("flood"))
	## Where the flood starts and which way it runs: [start, dir] for the nearest wash ahead of the car (its
	## upstream end, up to 1,800 px back along it), [] for none
	static func locate(c) -> Array:
		var heading: float = c.velocity.angle() if c.velocity.length() > 80.0 else c.rotation
		var found := Vector2.INF
		for dist in [500.0, 900.0, 1300.0, 1700.0, 2100.0]:
			for a in [0.0, 0.4, -0.4, 0.8, -0.8]:
				var p: Vector2 = c.global_position + Vector2.from_angle(heading + a) * dist
				if World.terrainAt(p) == Root.terrain.WASH:
					found = p
					break
			if found != Vector2.INF: break
		if found == Vector2.INF: return []
		var axis := Vector2.ZERO
		var bestN := 0
		for k in 8:
			var d := Vector2.from_angle(k * PI / 8.0)
			var n := 0
			for j in range(1, 6):
				for s in [-1.0, 1.0]:
					if World.terrainAt(found + d * s * j * 150.0) == Root.terrain.WASH: n += 1
			if n > bestN:
				bestN = n
				axis = d
		if axis == Vector2.ZERO: return []
		if axis.dot(Vector2.from_angle(heading)) < 0.0: axis = -axis #it runs the way the car is going
		var start := found
		for i in 12:
			if World.terrainAt(start - axis * 150.0) != Root.terrain.WASH: break
			start -= axis * 150.0
		return [start, axis]
	## The wash's bend ahead: the heading within 0.5 rad of `d` with the most wash along it
	static func followWash(at: Vector2, d: Vector2) -> Vector2:
		var best := d
		var bestN := 0
		for k in [0, 1, -1, 2, -2]:
			var t := d.rotated(k * 0.25)
			var n := 0
			for j in range(1, 4):
				if World.terrainAt(at + t * j * 150.0) == Root.terrain.WASH: n += 1
			if n > bestN:
				bestN = n
				best = t
		return best
	func _physics_process(delta: float) -> void:
		age += delta
		if age < WARN:
			rumbleT -= delta
			if rumbleT <= 0.0:
				rumbleT = 0.5
				WorldProps.rumble(0.12)
			return
		if age > WARN + SECONDS:
			modulate.a -= delta * 2.0
			if modulate.a <= 0.0: queue_free()
			return
		global_position += dir * SPEED * delta
		steerT -= delta
		if steerT <= 0.0:
			steerT = STEER_EVERY
			dir = followWash(global_position, dir)
			trail.push_back(global_position)
			if trail.size() > TRAIL: trail.remove_at(0)
		if (Engine.get_physics_frames() + get_instance_id()) % SWEEP_EVERY == 0: sweep()
		pushCar()
	## Goons on the wash in the front are swept away
	func sweep() -> int:
		var n := 0
		var side := dir.orthogonal()
		for goon in Spill.goonsNear(global_position, HALF + BAND):
			if goon.dead: continue
			var off: Vector2 = goon.global_position - global_position
			var along := off.dot(dir)
			if along > 60.0 || along < -BAND || absf(off.dot(side)) > HALF: continue
			if World.terrainAt(goon.global_position) != Root.terrain.WASH: continue
			Spill.flatten(goon, global_position - dir * 80.0, &"boom", &"splash")
			n += 1
		swept += n
		return n
	## The car on the wash near the front is carried along it, never wrecked
	func pushCar() -> bool:
		var c = WorldProps.car()
		if c == null: return false
		var off: Vector2 = c.global_position - global_position
		var along := off.dot(dir)
		if along > 80.0 || along < -CAR_BAND || absf(off.dot(dir.orthogonal())) > HALF: return false
		if World.terrainAt(c.global_position) != Root.terrain.WASH: return false
		c.velocity += dir * PUSH
		return true
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var side := dir.orthogonal()
		if age < WARN: #the roar upstream: a churning patch
			for i in 6: draw_circle(side * (i - 2.5) * 120.0 + dir * sin(age * 6.0 + i) * 30.0, 70.0 + 20.0 * sin(age * 4.0 + i), Color(WATER, 0.25 + 0.2 * age / WARN))
			return
		for i in trail.size():
			var p := to_local(trail[i])
			draw_circle(p, HALF * 0.9, Color(WATER, WATER.a * (0.3 + 0.7 * float(i) / TRAIL)))
		draw_colored_polygon(PackedVector2Array([side * HALF, side * HALF - dir * BAND, -side * HALF - dir * BAND, -side * HALF]), WATER)
		draw_line(side * HALF, -side * HALF, FOAM, 22.0)

## A bowling pin: a fodder goon standing still. Crushing one counts as a crush.
class Pin extends RamTarget:
	var lane
	var texture: Texture2D
	func _init() -> void:
		super()
		radius = 34.0
	func tryCrush(_c: Node2D, speed: float) -> bool:
		if speed < 100.0: return false
		dead = true
		if is_instance_valid(lane): lane.knocked(global_position)
		if is_instance_valid(Root.spawnManager): Root.spawnManager.fx.bits(global_position, 1)
		queue_free()
		return true
	func _draw() -> void:
		if texture: draw_texture_rect(texture, Rect2(-60, -60, 120, 120), false)
		else: draw_texture_rect(Pickups.texture("bowling"), Rect2(-48, -48, 96, 96), false)

#==================================================================================================
## Goon Bowling: ten pins in a triangle. One pass: a strike pays a Star Fragment and 100 coins.
class BowlingLane extends Node2D:
	var pins := 0
	var down := 0
	var clock := -1.0
	var done := false
	func _ready() -> void:
		var tex: Texture2D = null
		if is_instance_valid(Root.spawnManager) && not Root.spawnManager.basicGoons.is_empty():
			var path := Goonopedia.goonArt(Root.spawnManager.basicGoons[0])
			if ResourceLoader.exists(path): tex = load(path)
		for r in 4:
			for i in r + 1:
				var pin = WorldProps.Pin.new()
				pin.lane = self
				pin.texture = tex
				pin.position = Vector2(r * 110.0, (i - r * 0.5) * 110.0)
				add_child(pin)
				pins += 1
		PickupWorld.beacon(self, Pickups.rarityColor(Pickups.R.RARE), Pickups.texture("bowling"))
	func knocked(_pos: Vector2) -> void:
		down += 1
		if clock < 0.0: clock = 2.5
	func _physics_process(delta: float) -> void:
		if clock < 0.0 || done: return
		clock -= delta
		if clock <= 0.0 || down >= pins: finish()
	func finish() -> void:
		done = true
		Pickups.discover("bowling")
		var c = WorldProps.car()
		if c:
			if down >= pins:
				c.reward("coin", 100)
				PickupEffects.addStarFragment(c)
				PickupEffects.toast("STRIKE!", HudTheme.GOLD, Pickups.texture("bowling"))
			elif down >= 7:
				c.reward("coin", 50)
				PickupEffects.toast("SPARE  -  %d PINS" % down, HudTheme.GOLD, Pickups.texture("bowling"))
			else:
				c.reward("coin", down * 5)
				PickupEffects.toast("%d PINS" % down, HudTheme.TEXT, Pickups.texture("bowling"))
		await get_tree().create_timer(2.0, false).timeout
		queue_free()
	func _draw() -> void:
		if done: return
		draw_colored_polygon(PackedVector2Array([Vector2(-520, -50), Vector2(-80, -210), Vector2(440, -210), Vector2(440, 210), Vector2(-80, 210), Vector2(-520, 50)]), Color(0.86, 0.68, 0.4, 0.22))
		HudTheme.text(self, Vector2(-330, 18), "BOWL", 54, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 10)

## Ring Run: the first ring starts a chain of 8, each placed ahead of the car.
class RingRun extends Node2D:
	const RINGS := 8
	const PER_RING := 3.5
	const REACH := 110.0
	var index := 0
	var clock := -1.0
	var ring := Vector2.ZERO #world position of the ring to drive through
	var done := false
	func _ready() -> void:
		ring = global_position
		top_level = true
		global_position = Vector2.ZERO
	func _physics_process(delta: float) -> void:
		var c = WorldProps.car()
		if c == null || done: return
		if clock >= 0.0:
			clock -= delta
			if clock <= 0.0:
				WorldProps.say(c.global_position, "RING RUN OVER")
				done = true
				queue_free()
				return
		if c.global_position.distance_to(ring) < REACH:
			if index == 0: Pickups.discover("rings")
			index += 1
			c.reward("coin", 5)
			if index >= RINGS:
				var prize := Pickups.rollAtLeast(Pickups.R.RARE)
				PickupEffects.toast("RING RUN  -  %s" % Pickups.displayName(prize).to_upper(), Pickups.rarityColor(Pickups.rarity(prize)), Pickups.texture(prize))
				PickupEffects.collect(c, prize, c.global_position)
				done = true
				queue_free()
				return
			WorldProps.say(ring, "%d / %d" % [index, RINGS])
			var heading: float = c.velocity.angle() if c.velocity.length() > 50.0 else c.rotation
			ring = c.global_position + Vector2.from_angle(heading + randf_range(-0.8, 0.8)) * randf_range(650.0, 900.0)
			clock = PER_RING
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		if done: return
		var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.01)
		draw_arc(ring, 90.0 * pulse, 0.0, TAU, 40, Color(0.48, 0.25, 0.0), 22.0, true)
		draw_arc(ring, 90.0 * pulse, 0.0, TAU, 40, Color(1.0, 0.78, 0.25), 14.0, true)
		if clock >= 0.0: draw_arc(ring, 120.0, -PI / 2, -PI / 2 + TAU * clock / PER_RING, 40, Color(1, 1, 1, 0.8), 6.0, true)
		if index == 0: HudTheme.text(self, ring + Vector2(0, -120), "RING RUN", 30, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)

## Speed Trap: a camera that pays your speed. A record per level.
class SpeedTrap extends Node2D:
	const ZONE := 260.0
	var cooldown := 0.0
	var flash := 0.0
	var shown := ""
	func _physics_process(delta: float) -> void:
		cooldown = maxf(0.0, cooldown - delta)
		flash = maxf(0.0, flash - delta)
		var c = WorldProps.car()
		if c == null || cooldown > 0.0 || c.global_position.distance_to(global_position) > ZONE || c.velocity.length() < 200.0: return
		cooldown = 20.0
		flash = 0.4
		Pickups.discover("speedtrap")
		var mph := int(c.velocity.length() * WorldProps.MPH_PER_PX)
		var coins := mph / 2
		c.reward("coin", coins)
		shown = "%d MPH" % mph
		var record := PickupWorld.recordSpeedTrap(mph)
		WorldProps.say(global_position, ("NEW RECORD  %d MPH" % mph) if record else ("%d MPH  +%d" % [mph, coins]))
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		draw_texture_rect(Pickups.texture("speedtrap"), Rect2(-48, -48, 96, 96), false)
		if flash > 0.0: draw_circle(Vector2(-10, -12), 60.0 * flash / 0.4 + 10.0, Color(1, 1, 1, flash))
		draw_arc(Vector2.ZERO, ZONE, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 3.0)
		if shown != "": HudTheme.text(self, Vector2(0, -60), shown, 22, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)

## Donut Zone: circle the cone inside its ring for 5 s.
class DonutZone extends Node2D:
	const INNER := 90.0
	const OUTER := 300.0
	const NEED := 5.0
	var held := 0.0
	var lastAngle := 0.0
	var done := false
	func _physics_process(delta: float) -> void:
		var c = WorldProps.car()
		if c == null || done: return
		var off: Vector2 = c.global_position - global_position
		var d := off.length()
		var a := off.angle()
		var spin := absf(angle_difference(lastAngle, a)) / delta
		lastAngle = a
		if d > INNER && d < OUTER && c.velocity.length() > 150.0 && spin > 0.5: held += delta
		else: held = maxf(0.0, held - delta * 2.0)
		if held >= NEED:
			done = true
			Pickups.discover("donut")
			WorldProps.say(global_position, "DONUT!")
			PickupEffects.collect(c, "crate", c.global_position)
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		draw_arc(Vector2.ZERO, OUTER, 0.0, TAU, 56, Color(1.0, 0.55, 0.1, 0.25 if not done else 0.08), 6.0)
		draw_arc(Vector2.ZERO, INNER, 0.0, TAU, 32, Color(1.0, 0.55, 0.1, 0.25 if not done else 0.08), 4.0)
		if held > 0.0 && not done: draw_arc(Vector2.ZERO, OUTER + 14.0, -PI / 2, -PI / 2 + TAU * held / NEED, 56, HudTheme.GOLD, 10.0)
		draw_texture_rect(Pickups.texture("cone"), Rect2(-40, -40, 80, 80), false)

## Bullseye: come in fast and stop on the target.
class Bullseye extends Node2D:
	const RINGS := [55.0, 110.0, 170.0]
	var armed := -1.0
	var done := false
	func _physics_process(delta: float) -> void:
		var c = WorldProps.car()
		if c == null || done: return
		var d: float = c.global_position.distance_to(global_position)
		var v: float = c.velocity.length()
		if armed < 0.0:
			if d < 650.0 && v > 400.0: armed = 4.0
			return
		armed -= delta
		if v < 20.0 && d < 260.0:
			done = true
			Pickups.discover("bullseye")
			if d < RINGS[0]:
				c.reward("gem", 1)
				WorldProps.say(global_position, "BULLSEYE  +1 GEM")
			elif d < RINGS[1]:
				c.reward("coin", 30)
				WorldProps.say(global_position, "+30")
			elif d < RINGS[2]:
				c.reward("coin", 10)
				WorldProps.say(global_position, "+10")
			else: WorldProps.say(global_position, "MISSED")
		elif armed <= 0.0: armed = -1.0
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var a := 0.1 if done else 0.45
		var cols := [Color(0.82, 0.09, 0.29, a), Color(1, 0.95, 0.86, a), Color(0.82, 0.09, 0.29, a)]
		for i in [2, 1, 0]: draw_circle(Vector2.ZERO, RINGS[i], cols[i])
		if armed > 0.0: draw_arc(Vector2.ZERO, 200.0, 0.0, TAU, 48, HudTheme.GOLD, 6.0)

## Prize Wheel: drive across it and your speed spins it.
class PrizeWheel extends Node2D:
	const R := 170.0
	const WEDGES := [["JACKPOT", Color("ffc23d")], ["NITRO", Color("3fa8f0")], ["50", Color("f0a020")], ["BUST", Color("ff4a3d")], ["WRENCH", Color("a8b0b8")],
		["GEM", Color("e83aa8")], ["100", Color("f0a020")], ["BUST", Color("ff4a3d")], ["STAR", Color("ffe68a")], ["MYSTERY", Color("9a4ae8")]]
	var angle := 0.0
	var spin := 0.0
	var used := false
	var spinning := false
	func _physics_process(_delta: float) -> void:
		var c = WorldProps.car()
		if c == null: return
		if not used && not spinning && c.global_position.distance_to(global_position) < R && c.velocity.length() > 150.0:
			spinning = true
			spin = clampf(c.velocity.length() / 2500.0, 0.12, 0.45) * randf_range(0.85, 1.15)
		if spinning:
			angle += spin
			spin *= 0.988
			if spin < 0.003:
				spinning = false
				used = true
				pay(c)
	func wedgeAtPointer() -> int:
		var n := WEDGES.size()
		var a := fposmod(-PI / 2 - angle - global_rotation, TAU) #the pointer is at the top of the screen
		return int(a / (TAU / n)) % n
	func pay(c) -> void:
		Pickups.discover("wheel")
		var w: String = WEDGES[wedgeAtPointer()][0]
		WorldProps.say(global_position, w)
		match w:
			"JACKPOT": PickupEffects.collect(c, Pickups.rollAtLeast(Pickups.R.LEGENDARY), c.global_position)
			"NITRO": PickupEffects.collect(c, "nitro", c.global_position)
			"50": c.reward("coin", 50)
			"100": c.reward("coin", 100)
			"BUST": c.fuel = maxf(0.0, c.fuel - 10.0)
			"WRENCH": PickupEffects.collect(c, "wrench", c.global_position)
			"GEM": c.reward("gem", 1)
			"STAR": PickupEffects.collect(c, "starfrag", c.global_position)
			"MYSTERY": PickupEffects.collect(c, "mystery", c.global_position)
	func _process(_delta: float) -> void:
		if spinning: queue_redraw()
	func _draw() -> void:
		var n := WEDGES.size()
		draw_circle(Vector2.ZERO, R + 10.0, Color(0.16, 0.11, 0.07, 0.9))
		for i in n:
			var a0 := angle + i * TAU / n
			var pts := PackedVector2Array([Vector2.ZERO])
			for k in 7: pts.push_back(Vector2.from_angle(a0 + TAU / n * k / 6.0) * R)
			var col: Color = WEDGES[i][1]
			draw_colored_polygon(pts, col if not used else col.darkened(0.6))
			var mid := Vector2.from_angle(a0 + TAU / n * 0.5) * R * 0.62
			draw_set_transform(mid, a0 + TAU / n * 0.5 + PI / 2, Vector2.ONE)
			HudTheme.text(self, Vector2(0, 6), WEDGES[i][0], 15, Color(0.07, 0.05, 0.04), HORIZONTAL_ALIGNMENT_CENTER, 0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 22.0, Color(0.15, 0.12, 0.1))
		draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE) #the pointer stays at the top
		draw_colored_polygon(PackedVector2Array([Vector2(0, -R + 18), Vector2(-14, -R - 16), Vector2(14, -R - 16)]), Color(1.0, 0.95, 0.86))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A Supply Drop: a crate on a parachute that becomes a Rare-or-better pickup when it lands.
class SupplyDrop extends Node2D:
	const FALL := 2.5
	var t := 0.0
	var landed := false
	func _ready() -> void:
		z_index = 3
		PickupWorld.beacon(self, Pickups.rarityColor(Pickups.R.RARE), Pickups.texture("chute"))
	func _physics_process(delta: float) -> void:
		if landed: return
		t += delta
		if t >= FALL:
			landed = true
			var pickup := PickupEffects.spawnPickup(Pickups.rollAtLeast(Pickups.R.RARE), global_position)
			if pickup: PickupWorld.beacon(pickup, Pickups.rarityColor(Pickups.R.RARE), Pickups.texture("chute"))
			queue_free()
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var u := t / FALL
		draw_circle(Vector2.ZERO, 30.0 + 30.0 * u, Color(0, 0, 0, 0.25 * u))
		var lift := (1.0 - u) * 420.0
		draw_texture_rect(Pickups.texture("chute"), Rect2(-60, -60 - lift, 120, 120), false)

## Sentry Turret (Defense): shoots the nearest goon near the station.
class Turret extends Node2D:
	const RANGE := 900.0
	const EVERY := 0.4
	var life := 30.0
	var t := 0.0
	var shot := Vector2.INF
	var shotT := 0.0
	func _ready() -> void: z_index = 2
	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		shotT = maxf(0.0, shotT - delta)
		t += delta
		if t < EVERY || not is_instance_valid(Root.spawnManager): return
		t = 0.0
		var best = null
		var bestD := RANGE
		for goon in Root.spawnManager.goonsNear(global_position, RANGE):
			if goon.dead || goon.invulnerable: continue
			var d := global_position.distance_to(goon.global_position)
			if d < bestD:
				bestD = d
				best = goon
		if best:
			shot = best.global_position
			shotT = 0.1
			CarBuffFx.kill(best)
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		draw_texture_rect(Pickups.texture("turret"), Rect2(-48, -48, 96, 96), false)
		if shotT > 0.0 && shot != Vector2.INF: draw_line(Vector2(0, -20), to_local(shot), Color(1.0, 0.9, 0.5), 4.0)
		draw_arc(Vector2.ZERO, 60.0, -PI / 2, -PI / 2 + TAU * life / 30.0, 32, HudTheme.GOLD, 5.0)
