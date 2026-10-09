class_name WorldProps extends RefCounted

#Pickup things that live in the world: skill challenges, events, crates and supply drops
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

## Whether the run is in The Wilds (Region 1): the level's region (a LevelDef `region`, else rules "region"), or,
## for a level without one, whether the district the car is in belongs to the Wild Things
static func inWilds() -> bool:
	var def := Levels.current()
	if def:
		var region = def.get("region")
		if (region is String || region is StringName) && String(region) != "": return StringName(region) == &"wilds"
		var rules = def.get("rules")
		if rules is Dictionary && rules.has("region"): return StringName(rules["region"]) == &"wilds"
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

## The Loot Truck: every ram spills coins; five burst it for a Rare pickup.
class LootTruck extends RamTarget:
	var rams := 0
	var cooldown := 0.0
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
		var teal := Color(0.1, 0.7, 0.6)
		draw_rect(Rect2(-80, -36, 110, 72), teal)
		draw_rect(Rect2(-80, -36, 110, 72), Color(0.02, 0.26, 0.22), false, 4.0)
		draw_rect(Rect2(30, -30, 46, 60), Color(0.08, 0.55, 0.47))
		draw_rect(Rect2(52, -24, 18, 48), Color(0.8, 0.94, 1.0))
		HudTheme.text(self, Vector2(-25, 12), "$", 40, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		for i in rams: draw_circle(Vector2(-60 + i * 22, -48), 6.0, HudTheme.GOLD)

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

## A breakable crate: smash it above 200 px/s for a Common or Uncommon pickup.
class Crate extends Area2D:
	const SMASH := 200.0
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var shape = CollisionShape2D.new()
		var box = RectangleShape2D.new()
		box.size = Vector2(70, 70)
		shape.shape = box
		add_child(shape)
		body_entered.connect(onBody)
	func onBody(body) -> void:
		if not body.has_method("getIsPlayer") || body.velocity.length() < SMASH: return
		set_deferred("monitoring", false)
		if is_instance_valid(Root.spawnManager): Root.spawnManager.fx.bits(global_position, 0)
		var id := Pickups.rollAtLeast(Pickups.R.COMMON)
		if Pickups.rarity(id) > Pickups.R.UNCOMMON: id = Pickups.openOr("coinstack")
		PickupEffects.collect(body, id, global_position)
		var flyers = RewardFlyers.instance()
		if flyers: flyers.launch(Pickups.texture(id), get_global_transform_with_canvas(), Pickups.uiGroup(id))
		queue_free()
	func _draw() -> void:
		draw_texture_rect(Pickups.texture("crate"), Rect2(-40, -40, 80, 80), false)

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
