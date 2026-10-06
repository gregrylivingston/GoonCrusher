class_name Walker extends Enemy
## Every goon. Its baked scene (scripts/art/bake_goons.py) brings the art, collision, occluder and eye
## positions; Goons.DATA brings the faction, tuning and verb; the verb (goon_verbs.gd) drives it.
## The car calls tryCrush() on contact. docs/GOONS.md describes the whole system.

enum mode { MOVE, ATTACK, IDLE, DEAD, PREPAREATTACK } #read by the AI driver, so keep the names
var myMode: mode = mode.MOVE

@export var goonId: StringName
@export var decal: Texture2D
@export var eyes: PackedVector2Array #art space, game px (bake)
@export var bodyRadius: float = 18.0
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

const WALK_CYCLE_PER_R := 3.4  #ground covered by one 8-frame walk cycle, in body radii
const RESIST_COOLDOWN := 0.4   #a resisted crush can't bounce the car again this soon
const GIANT_SPEED := 1.5       #giants were 4x in the demo, too much once goons have specials

var isGiant: bool = false
var def: Dictionary
var verb #GoonVerbs.Verb

#tuning, from Goons.DATA
var speed := 110.0
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
var turnRate := 9.0
var tele := "arrow"
var stunT := 1.4

#state
var state: StringName = &"move"
var stateTime := 0.0
var cooldown := 0.0
var lockPos := Vector2.ZERO
var lockDir := Vector2.RIGHT
var hitDone := false
var invulnerable := false
var buffUntil := 0.0
var packId := 0
var drift := Vector2.ZERO
var resistTimer := 0.0
var dead := false
var lastCarRotation := 0.0
var carSpin := 0.0 #the car's turn rate (rad/s), for goons that can be shaken off
var savedLayers := Vector2i(3, 3)

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
	savedLayers = Vector2i(collision_layer, collision_mask)
	if isGiant:
		scale = Vector2(1.6, 1.6)
		speed *= GIANT_SPEED
		attackDamage *= 2
		if Settings.get_value("access/giant_style") == 2: addGroundRing()
	else:
		sprite.material = null
	cooldown = randf() * 1.5
	sprite.play(&"walk")
	sprite.frame = randi() % 8
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
	stateTime += delta
	cooldown = maxf(0.0, cooldown - delta)
	resistTimer = maxf(0.0, resistTimer - delta)
	carSpin = angle_difference(lastCarRotation, car.rotation) / delta
	lastCarRotation = car.rotation
	verb.tick(delta, car)

#--- helpers the verbs use ----------------------------------------------------------------------

func fx() -> GoonFx:
	return Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null

func speedNow() -> float:
	return speed * (Goons.DATA[&"foreman"]["buff"] if buffUntil > Time.get_ticks_msec() / 1000.0 else 1.0)

func isBuffed() -> bool:
	return buffUntil > Time.get_ticks_msec() / 1000.0

func distTo(car: Node2D) -> float:
	return global_position.distance_to(car.global_position)

## State changes keep myMode in step for the AI driver.
func setState(s: StringName) -> void:
	state = s
	stateTime = 0.0
	match s:
		&"windup": myMode = mode.PREPAREATTACK
		&"attack", &"charge", &"roll", &"slam", &"dive": myMode = mode.ATTACK
		&"move", &"flee", &"dodge": myMode = mode.MOVE
		_: myMode = mode.IDLE

## Plays an animation; a duration stretches it so its frames span that time.
func play(anim: StringName, duration := 0.0) -> void:
	if sprite.animation != anim || not sprite.is_playing(): sprite.play(anim)
	if duration > 0.0:
		var frames := sprite.sprite_frames
		sprite.speed_scale = frames.get_frame_count(anim) / frames.get_animation_speed(anim) / duration
	else: sprite.speed_scale = 1.0

## The walk plays at the rate the goon covers ground, so feet never skate.
func walkAnim(moveSpeed: float) -> void:
	if sprite.animation != &"walk": sprite.play(&"walk")
	sprite.speed_scale = clampf(moveSpeed / (bodyRadius * WALK_CYCLE_PER_R * 10.0 / 8.0 * scale.x), 0.2, 3.0)

func faceTo(angle: float, delta: float, rate := -1.0) -> void:
	var r := (turnRate if rate < 0.0 else rate) * delta
	rotation += clampf(angle_difference(rotation, angle), -r, r)

## Walks toward a point. Off screen it skips collision queries (the spawn manager's LOD).
func chase(target: Vector2, moveSpeed: float, delta: float, rate := -1.0) -> void:
	faceTo((target - global_position).angle(), delta, rate)
	advance(Vector2.from_angle(rotation) * moveSpeed, delta)
	walkAnim(moveSpeed)

func advance(v: Vector2, delta: float) -> void:
	velocity = v
	if Root.spawnManager.needsFullPhysics(global_position):
		move_and_slide()
		#the car takes contact damage every tick it touches a goon, so goons that bump it back off
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() == Root.playerCar:
				verb.onTouch(Root.playerCar)
				return
	else: global_position += v * delta

## Where the car will be in `lead` seconds.
func predict(car: Node2D, lead: float) -> Vector2:
	return car.global_position + car.velocity * lead

func lockOn(car: Node2D, lead: float) -> void:
	lockPos = predict(car, lead)
	lockDir = (lockPos - global_position).normalized()

## Moves along lockDir at attack speed and hits the car once if it touches it.
func lungeStep(car: Node2D, moveSpeed: float, delta: float) -> void:
	faceTo(lockDir.angle(), delta, 14.0)
	velocity = lockDir * moveSpeed
	move_and_slide()
	if hitDone: return
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == car:
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

#--- crushing -----------------------------------------------------------------------------------

## The car calls this when it touches the goon above 100 px/s. False means the goon resisted.
func tryCrush(car: Node2D, carSpeed: float) -> bool:
	if dead: return true
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

## Every death: crushed (decal, bits, maybe a pickup), blown up, or drowned (no decal).
func destroy(cause: StringName = &"crush"):
	if dead: return
	dead = true
	myMode = mode.DEAD
	verb.onDeath(cause)
	var f = fx()
	if f && cause != &"drown":
		var heading: float = Root.playerCar.rotation if is_instance_valid(Root.playerCar) else rotation
		f.addDecal(decal, global_position, sprite.global_rotation, sprite.global_scale.x, heading, cause == &"crush")
		f.bits(global_position, def.get("faction", 1))
	#death sounds go through the shared, limited pool (Max Sound Effects); their own players
	#are only used as data. Authored level is +10 dB over the pool's +3 dB.
	Audio.play($AudioStreamPlayer2D2.stream, 7.0 + randf_range(0.0,5.0), randf_range(0.95,1.05))
	Audio.play($AudioStreamPlayer2D.stream, 7.0 + randf_range(0.0,8.0), randf_range(0.95,1.05))
	if f && cause != &"drown" && is_instance_valid(Root.playerCar) && randi_range(0,200) + Root.playerCar.clover > 190:
		f.dropLater(global_position, powerupDropDict)
	queue_free()

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
