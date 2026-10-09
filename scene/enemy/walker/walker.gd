class_name Walker extends Enemy
## Every goon. Its baked scene (scripts/art/bake_goons.py) brings the art, collision, occluder and eye
## positions; Goons.DATA brings the faction, tuning and verb; the verb (goon_verbs.gd) drives it.
## The car calls tryCrush() on contact. docs/GOONS.md describes the whole system.
##
## The native base GoonBody (native/src/goon_body.cpp, docs/NATIVE.md) holds the per-tick fields (speed,
## turnRate, bodyRadius, state, stateTime, cooldown, resistTimer, stuckTime, carSpin, lockPos, lockDir,
## buffUntil, lastCarTouch, myMode) and the helpers the verbs call every tick (chase, advance, faceTo, play,
## walkAnim, setState, speedNow, distTo, lockOn, predict, touchedByCar). It calls back _onCarContact, and
## _worldLethalAt / _worldSlideStep when no native WorldGrid is current.

enum mode { MOVE, ATTACK, IDLE, DEAD, PREPAREATTACK } #read by the AI driver (myMode), so keep the names

@export var goonId: StringName
@export var decal: Texture2D
@export var eyes: PackedVector2Array #art space, game px (bake)
#relative drop weights. Before the luck fix the coin weight was effectively the luck stat (about 1), so fuel
#was about 28% of drops; COIN 30 keeps fuel near 20% and health near 10% while coins still drop often.
@export var powerupDropDict: Dictionary = {
	Root.upgrade.GEM:4,
	Root.upgrade.COIN:30,
	Root.upgrade.PURSE:4,
	Root.upgrade.SLOTMACHINE:1,
	Root.upgrade.HEALTH:10,
	Root.upgrade.FUEL:20,
	Root.upgrade.TRACTION:4,
	Root.upgrade.STEERING:4,
	Root.upgrade.ARMOR:4,
	Root.upgrade.ENGINE:4,
	Root.upgrade.OIL:4,
	Root.upgrade.CLOVER:4,
	Root.upgrade.HEADLIGHTS:4,
	Root.upgrade.LUCK:4
}

const RESIST_COOLDOWN := 0.4   #a resisted crush can't bounce the car again this soon
const GIANT_SPEED := 1.5       #giants were 4x in the demo, too much once goons have specials
const GIANT_SCALE := 1.6       #multiplies the scene's own scale
const DEATH_SOUND_RANGE := 1400.0 #px from the car: about a screen at the widest zoom

var isGiant: bool = false
var def: Dictionary
var killedFrom := Vector2.INF #a blast's centre, set just before it kills the goon, which is flung away from it
var verb #GoonVerbs.Verb

#tuning, from Goons.DATA (speed and turnRate live on GoonBody)
var windDist := 150.0
var windT := 0.55
var atkT := 0.38
var recT := 0.7
var lunge := 3.0
var attackDamage := 3.0
var sys := "hull"
var crushSpeed := 100.0
var frontArmor := 0.0
var frontArc := 1.05
var tele := "arrow"
var stunT := 1.4

#state (the rest is on GoonBody; carSpin is the car's turn rate in rad/s, for goons that can be shaken off)
var hitDone := false
var invulnerable := false
var packId := 0
var drift := Vector2.ZERO
var dead := false
var savedLayers := Vector2i(4, 3) #layer 3 (Goon) only, so goons never collide with each other; mask: world and car
#the world (WorldHooks): water drowns a solid goon (checked every 4 ticks, staggered: GoonBody.beginTick), a
#drowning within DROWN_CREDIT_SECONDS of the car's touch (lastCarTouch, GoonVerbs.now seconds) counts as a
#crush; a goon pressing a barrier on screen for STUCK_SECONDS (stuckTime) may be swept away

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready():
	def = Goons.DATA.get(goonId, {})
	speed = def.get("speed", speed)
	windDist = def.get("windDist", windDist)
	windT = def.get("windT", windT)
	atkT = def.get("atkT", atkT)
	recT = def.get("recT", recT)
	lunge = def.get("lunge", lunge)
	attackDamage = def.get("dmg", attackDamage)
	sys = def.get("sys", sys)
	crushSpeed = def.get("crush", crushSpeed)
	frontArmor = def.get("front", frontArmor)
	frontArc = def.get("arc", frontArc)
	turnRate = def.get("turn", turnRate)
	tele = def.get("tele", tele)
	buffScale = Goons.DATA[&"foreman"]["buff"]
	savedLayers = Vector2i(collision_layer, collision_mask)
	motion_mode = MOTION_MODE_FLOATING #top-down, like the car: no floor, wall or ceiling sorting in move_and_slide
	bindSprite(sprite)
	if isGiant:
		scale *= GIANT_SCALE
		speed *= GIANT_SPEED
		attackDamage *= 2
		if Settings.get_value("access/giant_style") == 2: addGroundRing()
	else:
		sprite.material = null
	cooldown = randf() * 1.5
	sprite.play(&"walk")
	sprite.frame = randi() % 8
	if SaveManager.playerData.gameMode == Root.gameModes.DEFENSE && is_instance_valid(Root.station) && def.get("verb", &"lunge") not in SIEGE_SKIP:
		siegeTarget = Root.station
	verb = GoonVerbs.make(def.get("verb", &"lunge"), self)
	verb.setup()
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight: setNight(true)

const RING_TEXTURE = preload("res://texture/fx/circle_05.png")

#Giant Marker Style "Tint + ground ring": a ring in the marker colour under the giant
func addGroundRing() -> void:
	var ring = Sprite2D.new()
	ring.texture = RING_TEXTURE
	var tint: Color = Settings.GIANT_COLORS[Settings.get_value("access/giant_color")]
	var peak = maxf(tint.r, maxf(tint.g, tint.b))
	ring.modulate = Color(tint.r / peak, tint.g / peak, tint.b / peak, 0.7)
	ring.z_index = -1
	ring.scale = Vector2.ONE * 300.0 / RING_TEXTURE.get_width()
	add_child(ring)

func _physics_process(delta):
	if dead: return
	var car = Root.playerCar
	if not is_instance_valid(car): return
	if Pickups.goonTickSkipped(): return #Time Warp
	if beginTick(delta, car): #the state clock; true when it stands in deep water
		drown()
		return
	if (state == &"move" || state == &"lured") && not Pickups.lures.is_empty():
		var lure := Pickups.lureFor(global_position, def.get("verb", &"lunge")) #Goon Bait, Flare
		if lure != Vector2.INF:
			if state != &"lured": setState(&"lured")
			if def.get("verb", &"") == &"flyer": chase(lure + Vector2.from_angle(stateTime * 0.8) * 220.0, speedNow(), delta, 3.0) #circles it
			elif global_position.distance_to(lure) > 40.0: chase(lure, speedNow(), delta)
			else: play(&"idle")
			return
		if state == &"lured": setState(&"move")
	elif state == &"lured": setState(&"move")
	tickTimers(delta, car) #cooldown, resistTimer, carSpin
	if sieging(car):
		siege(delta)
		return
	verb.tick(delta, car)

#--- Defense: the siege -------------------------------------------------------------------------
#In Defense a goon marches on the nearer of the station's pumps (round the house if it is in the way:
#station.siegeStep) and blows up when it reaches it, damaging the barrier,
#unless the car comes within SIEGE_AGGRO, when its verb hunts the car as usual. Verbs with their own
#movement (burrowers, flyers, vehicles) always hunt the car. Verbs never see the station.

const SIEGE_AGGRO := 650.0
const SIEGE_SKIP := [&"burrow", &"flyer", &"rider"]
var siegeTarget: Node2D = null #Defense's station; null in every other mode

func sieging(car: Node2D) -> bool:
	if not is_instance_valid(siegeTarget): return false
	return state == &"move" && distTo(car) > SIEGE_AGGRO

func siege(delta: float) -> void:
	var pump: Vector2 = siegeTarget.nearestPump(global_position)
	if global_position.distance_to(pump) > bodyRadius * scale.x + 40.0:
		chase(siegeTarget.siegeStep(global_position), speedNow(), delta)
		return
	siegeTarget.damage(attackDamage)
	if is_instance_valid(Root.levelRoot): Root.levelRoot.explode(global_position)
	destroy(&"self") #no crush credit: the car didn't stop it

#--- helpers the verbs use ----------------------------------------------------------------------

func fx() -> GoonFx:
	return Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null

## GoonBody.advance: the car bumped into on screen. touchedByCar and stuckTime are already done.
func _onCarContact(car: Node2D) -> void:
	verb.onTouch(car)

## GoonBody's world queries when no native WorldGrid is current (a test's stand-in map, or none)
func _worldLethalAt(pos: Vector2) -> bool:
	return World.lethalAt(pos)

func _worldSlideStep(pos: Vector2, step: Vector2) -> Vector2:
	return WorldHooks.slideStep(pos, step)

## Moves along lockDir at attack speed and hits the car once if it touches it.
func lungeStep(car: Node2D, moveSpeed: float, delta: float) -> void:
	faceTo(lockDir.angle(), delta, 14.0)
	velocity = lockDir * moveSpeed
	move_and_slide()
	if hitDone: return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == car:
			touchedByCar()
			hitCar(car, attackDamage, sys)
			hitDone = true
			return

## Damage to the car: health always, plus wear on one system when the goon targets one.
func hitCar(car: Node2D, dmg: float, system: String) -> void:
	if car.has_method("damage"): car.damage(dmg)
	if system != "hull" && car.has_method("wearSystem"): car.wearSystem(system, dmg * 3.0)
	if audio_hit.size() > 0: Audio.queueRequest(audio_hit)

func telegraph(kind: String, duration: float, radius := 0.0) -> void:
	var f = fx()
	if f && kind != "none": f.telegraph(self, kind, duration, radius)

## Turns collisions off (buried, flying, riding the car) or back on.
func setSolid(solid: bool) -> void:
	collision_layer = savedLayers.x if solid else 0
	collision_mask = savedLayers.y if solid else 0

#--- water -------------------------------------------------------------------------------------

## A solid goon over deep water drowns (buried, hopping, flying and riding goons aren't solid, so they're
## immune until they land); a car alongside counts as a touch (GoonBody.overDeepWater). True when it drowned.
## The tick runs the same check every 4 ticks through beginTick.
func checkWater(car: Node2D) -> bool:
	if not overDeepWater(car): return false
	drown()
	return true

## Into the water: a splash, and a crush ("SPLASH") when the car put it there
func drown() -> void:
	if dead: return
	var credited := WorldHooks.drownCredited(GoonVerbs.now(), lastCarTouch)
	var f = fx()
	if f:
		f.ring(global_position, bodyRadius * scale.x * 1.6)
		if credited: f.label(global_position, "SPLASH")
	destroy(&"drown")
	if credited && is_instance_valid(Root.spawnManager): Root.spawnManager.creditCrush(global_position, self)

## Pressed against a wall long enough that it will never get through (SpawnManager.despawnSweep)
func isStuck() -> bool:
	return stuckTime >= WorldHooks.STUCK_SECONDS

#--- crushing -----------------------------------------------------------------------------------

## The car calls this when it touches the goon above 100 px/s. False means the goon resisted.
func tryCrush(car: Node2D, carSpeed: float) -> bool:
	if dead: return true
	touchedByCar()
	if not is_node_ready(): #hit the tick it spawned, before _ready made its verb and sprite: it just goes
		dead = true
		queue_free()
		return true
	if car.has_method("crushOverride") && car.crushOverride(self): #a plow, spikes, monster tires, a golden ride
		verb.beforeCrush(car, carSpeed)
		destroy(&"crush")
		return true
	var resisted: bool = invulnerable || carSpeed < crushSpeed
	if not resisted && frontArmor > 0.0 && carSpeed < frontArmor && verb.frontArmorActive() && facing(car): resisted = true
	if not resisted && not verb.allowCrush(car, carSpeed): resisted = true
	if resisted:
		if resistTimer <= 0.0:
			resistTimer = RESIST_COOLDOWN
			verb.onResist(car, carSpeed)
		return false
	verb.beforeCrush(car, carSpeed)
	destroy(&"crush")
	return true

func facing(car: Node2D) -> bool:
	return absf(angle_difference(rotation, (car.global_position - global_position).angle())) < frontArc

## The default resist: the car loses speed and bounces back, the goon staggers. Verbs add damage.
func bounceCar(car: Node2D, dmg: float, system: String, label := "BLOCKED") -> void:
	car.velocity *= 0.35
	car.global_position -= Vector2.from_angle(car.rotation) * 6.0
	hitCar(car, dmg, system)
	var f = fx()
	if f: f.label(global_position, label)
	if Settings.has_method("vibrate") && car.get("isPlayer"): Settings.vibrate(0.5, 0.3, 0.12)

func isDying() -> bool:
	return dead

## Every death: crushed or blown up (squashed or flung, decal, bits, spatter: GoonFx.crushed; maybe a
## pickup), or drowned (no decal).
func destroy(cause: StringName = &"crush"):
	if dead: return
	dead = true
	myMode = mode.DEAD
	verb.onDeath(cause)
	var f = fx()
	if f && cause != &"drown":
		f.crushed(self, cause, killedFrom)
	#death sounds go through the shared, limited pool (Max Sound Effects); their own players are only
	#used as data. The pool isn't positional, so only crushes and blasts near the car sound: goons drowning,
	#blowing themselves up or dying anywhere else in the world stay quiet. A giant's are an octave-ish lower.
	if cause != &"drown" && cause != &"self" && is_instance_valid(Root.playerCar) && global_position.distance_to(Root.playerCar.global_position) < DEATH_SOUND_RANGE:
		var pitch := 0.72 if isGiant else 1.0
		Audio.play($AudioStreamPlayer2D2.stream, randf_range(-6.0, -2.0), pitch * randf_range(0.95,1.05))
		Audio.play($AudioStreamPlayer2D.stream, randf_range(-8.0, -2.0), pitch * randf_range(0.95,1.05))
	if f && cause != &"drown" && is_instance_valid(Root.playerCar) && randi_range(0,200) + Root.playerCar.clover > 190:
		f.dropLater(global_position, dropTable())
	queue_free()

## What GoonFx drops later: Pickups rolls it then (Root.getPowerupFromWeights), by this goon's faction.
## Giants and bosses drop one rarity tier up. powerupDropDict is the pre-rarity table, kept for reference.
func dropTable() -> Dictionary:
	var bump := 1 if isGiant || def.get("verb", &"") == &"boss" else 0
	return {Pickups.ROLL: {"faction": def.get("faction", -1), "bump": bump}}

#--- night --------------------------------------------------------------------------------------

const EYE_MATERIAL = preload("res://scene/enemy/goon_eyes.tres") #additive and unshaded
const EYE_TEXTURE = preload("res://scene/enemy/goon_eye.tres")
var eyeSprites: Array[Sprite2D] = []

## Eyes glow unshaded at night, so a goon in the dark is two points of light. Made on the first night.
func setNight(on: bool) -> void:
	if on && eyeSprites.is_empty() && not eyes.is_empty():
		for e in eyes:
			var s := Sprite2D.new()
			s.texture = EYE_TEXTURE
			s.material = EYE_MATERIAL
			s.modulate = Color(1.0, 0.92, 0.55)
			s.position = e / sprite.scale.x
			s.scale = Vector2.ONE * 7.0 / EYE_TEXTURE.get_width() / sprite.scale.x
			sprite.add_child(s)
			eyeSprites.push_back(s)
	for s in eyeSprites: s.visible = on
	verb.onNight(on)
