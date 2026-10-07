# OverheadCarBody2D is the recipe described here adapted for Godot 4.
# http://kidscancode.org/godot_recipes/3.x/2d/car_steering/
# https://engineeringdotnet.blogspot.com/2010/04/simple-2d-car-physics-in-games.html
#
# Extend OverheadCarBody2D and override _get_input(input: CarInput) to control.
class_name OverheadCarBody2D extends CharacterBody2D


#voices 
#taxi - okole
#van - jessie
#sedan - patrick
#pickup - karen
#semi - tiffany



#the car's menu data and base stats; edit them in scene/car/<car>/<car>_info.tres
@export var info: CarInfo:
	set(value):
		info = value
		if value:
			for field in CarInfo.FIELDS: set(field, value.get(field))

#base stats come from `info`; upgrades and powerups add to them
var engine: int = 25  # Forward acceleration force.
var steering: int = 12  # Amount that front wheel turns, in degrees
var traction: int = 4   #grip, brakes and turn-rate-increase
var armor: int = 1
var luck: int = 1   #"Dice": more high-value drops (Root.luckAdjustedWeights)
var clover: int = 1 #"Clover": more goons drop a pickup (walker.gd)
var oil: int = 1
var headlights: int = 1

#stats that upgrades and powerups raise; powerups can't push them past STAT_CAP in a run
const UPGRADEABLE_STATS = ["engine", "steering", "traction", "armor", "oil", "headlights", "clover", "luck"]
const STAT_CAP := 150
const FUEL_BURN_BASE := 0.021 #fuel per physics tick at full throttle with 0 oil
const WALL_DAMAGE_PER_SPEED := 0.07 #wall-hit damage per px/s of speed; armor is applied in damage()
const TRACTION_GRIP_PER_POINT := 0.003 #grip each traction point adds to traction_fast/traction_slow
const GRIP_MIN := 0.05
const GRIP_FAST_MAX := 0.40
const GRIP_SLOW_MAX := 0.95

#System damage (docs/HUD.md, docs/CAR_ART.md). Each system has a condition from 0 to 100, and the
#stat it scales keeps CONDITION_FLOOR of its value at 0%. Wall hits wear the system on the side that
#hit (zoneForHit), physics reads the factor in integrate(), and the car art shows it (car_damage.gdshader).
const SYSTEM_STATS := {"lights":"headlights", "engine":"engine", "steering":"steering", "tires":"traction", "tank":"oil"}
const CONDITION_FLOOR := {"lights":0.35, "engine":0.6, "steering":0.7, "tires":0.5, "tank":0.4}
const ZONE_WEAR_PER_SPEED := 0.035 #condition a wall hit takes per px/s of speed, before armor (a 500 px/s hit takes 17.5)
const ZONE_WEAR_MIN_SPEED := 80.0 #slower bumps and scrapes against a wall don't wear a system
const ZONE_COOLDOWN_TICKS := 30   #a system takes wall wear at most every half second
const GOON_SCUFF := 2.0           #condition a goon bump that doesn't crush takes from the side it hit
const FUEL_LEAK_MAX := 0.006      #extra fuel per moving tick with the tank at 0%; starts below 50%
var condition := {"lights":100.0, "engine":100.0, "steering":100.0, "tires":100.0, "tank":100.0}
var runStartStats := {} #UPGRADEABLE_STATS when the run began (base + upgrades), before any pickup
var zoneCooldown := {}  #system -> physics ticks until it can take wall wear again
signal conditionChanged(system: String, value: float)

func setCondition(system: String, value: float) -> void:
	var v := clampf(value, 0.0, 100.0)
	if is_equal_approx(v, condition[system]): return
	condition[system] = v
	if system == "lights": setHeadlightStrength()
	updateDamageLook()
	conditionChanged.emit(system, v)

#how much of a system's stat still works: 1 when undamaged, CONDITION_FLOOR at 0%
func conditionFactor(system: String) -> float:
	return lerpf(CONDITION_FLOOR[system], 1.0, condition[system] / 100.0)

#Ground friction. integrate() reads the surface under each position from World (scripts/world/world.gd,
#with the off-road rule); this is only the fallback before a map is loaded, and is kept equal to the
#friction under the car each tick so the HUD and the AI's top-speed sums see the current ground.
@export var friction:float = 0.1
@export var drag:float = 0.0005   #.0015

@export var slip_speed:int = 100  # Speed where traction is reduced
@export var traction_fast:float = 0.1  # High-speed traction
@export var traction_slow:float = 0.7  # Low-speed traction
@export var grip_per_traction:float = TRACTION_GRIP_PER_POINT #grip each traction point adds (gripFor)
@export var grip_fast_max:float = GRIP_FAST_MAX
@export var grip_slow_max:float = GRIP_SLOW_MAX
@export var wheel_base:int = 70  # Distance from front to rear wheel

var health:float = 100.0
var fuel:float = 100.0
var coin:int = 0
var gem:int = 0
var star: int = 0
var currentGoonsCrushed:int = 0
var crushedById := {} #goon id -> crushes this run, credited to the save's goonsCrushed by gameSummary
var giantsCrushed: int = 0 #by the car itself; Goonpocalypse's score and the run log read it
var slotMachines:int = 0
var pickedById := {} #pickup id -> times collected this run (Pickups.countCollected); the run log counts them by kind

@export var isPlayer = true
var isDestroyed: bool = false #wrecked or out of fuel; the run is about to end
var isWrecked: bool = false #destroyed (health, water), not just out of fuel; a wrecked car can't win

func getIsPlayer():return isPlayer

var profilePic: Texture2D  #from `info`
var backgroundPic: Texture2D
var charName: String = "Hi"
var carId:String

var introAudio: Array[AudioStreamMP3] = []
@export var purseAudio: Array[AudioStreamMP3] = []
@export var powerupAudio: Array[AudioStreamMP3] = []
@export var lowGasAudio: Array[AudioStreamMP3] = []
@export var lowHealthAudio: Array[AudioStreamMP3] = []
@export var engineNoise: AudioStreamMP3
@export var art: CarArtSet #the baked sheets, zone mask and shadow (scene/car/<car>/art/)

class CarInput:
	var steering := 0.0      # -1.0 (left) to 1.0 (right)
	var acceleration := 0.0  # -1.0 (reverse) to 1.0 (accelerate)
	var braking := false     # True if brakes are engaged

var gear: int = 0
var maxGears: int = 3
var _car_input := CarInput.new()
var _path_follow: OverheadCarPathFollow2D = null
@onready var myController = $CarController


func _init():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _ready():
	purseAudio.append_array(powerupAudio)
	$"AudioStream-Engine".stream = engineNoise
	$"AudioStream-Engine".play()

	if isPlayer:
		add_to_group("playerCar")
		Root.playerCar = self
		var thisCar = SaveManager.getCarByName(carId)
		engine += SaveManager.getUpgradeLevel(Root.upgrade.ENGINE)
		steering += SaveManager.getUpgradeLevel(Root.upgrade.STEERING)
		traction += SaveManager.getUpgradeLevel(Root.upgrade.TRACTION)
		armor += SaveManager.getUpgradeLevel(Root.upgrade.ARMOR)
		headlights += SaveManager.getUpgradeLevel(Root.upgrade.HEADLIGHTS)
		oil += SaveManager.getUpgradeLevel(Root.upgrade.OIL)
		clover += SaveManager.getUpgradeLevel(Root.upgrade.CLOVER)
		luck += SaveManager.getUpgradeLevel(Root.upgrade.LUCK)
	for stat in UPGRADEABLE_STATS: runStartStats[stat] = self[stat]
	if isPlayer:
		buffFx = CarBuffFx.new()
		add_child(buffFx)
		if Pickups.loadout != "": #a gadget bought with gems in run setup
			giveItem(Pickups.loadout)
			Pickups.loadout = ""

	halfWidth = $carBodyArea/CollisionShape2D.shape.size.y / 2.0
	applyArt()
	Settings.changed.connect(onSettingChanged)
	setHeadlightStrength()
	stopCarFX()

#the paint the player picked (cosmetic), the damage sheets and the night silhouette light
func applyArt() -> void:
	if art == null: return
	var sheets := art.sheets(Settings.get_value("gameplay/car_paint"))
	var body: Sprite2D = $sprite/body
	body.texture = sheets[0]
	body.material.set_shader_parameter("dented_tex", sheets[1])
	body.material.set_shader_parameter("wrecked_tex", sheets[2])
	body.material.set_shader_parameter("zone_mask", art.zoneMask)
	$sprite/shadow.texture = art.shadow
	$headlamps/carhighlight.texture = sheets[0]
	$headlamps/carhighlight.scale = $sprite.scale * body.scale
	$headlamps/carhighlight.position = $sprite.position
	lastDamageLook = PackedFloat32Array()
	updateDamageLook()

func onSettingChanged(key: String, _value) -> void:
	if key == "gameplay/car_paint": applyArt()

#hull, lights, engine, steering, tires, tank as 0 (like new) to 1 (wrecked), for car_damage.gdshader
var lastDamageLook := PackedFloat32Array()
func updateDamageLook() -> void:
	if not is_node_ready() || art == null: return
	var look := PackedFloat32Array([1.0 - clampf(health, 0.0, 100.0) / 100.0])
	for system in ["lights", "engine", "steering", "tires", "tank"]: look.push_back(1.0 - condition[system] / 100.0)
	if look == lastDamageLook: return
	lastDamageLook = look
	$sprite/body.material.set_shader_parameter("damage", look)

var gasWarningGiven = false
func resetGasWarning(): gasWarningGiven = false

func makeGasWarning():
	gasWarningGiven = true
	$"AudioStream-Voice".stream = lowGasAudio[ randi_range(0, lowGasAudio.size()-1)]
	$"AudioStream-Voice".play()
	await get_tree().create_timer(200).timeout
	resetGasWarning()
	
var healthWarningGiven = false
func resetHealthWarning(): healthWarningGiven = false

func makeHealthWarning():
	healthWarningGiven = true
	$"AudioStream-Voice".stream = lowHealthAudio[ randi_range(0, lowHealthAudio.size()-1)]
	$"AudioStream-Voice".play()
	$"AudioStream-CarDamage".play()
	await get_tree().create_timer(200).timeout
	resetHealthWarning()


#the region tile's terrain, for show only: handling reads World.surfaceAt in integrate()
var currentTerrain: Root.terrain
func setTerrain(terrain: int): # Root.terrain
	currentTerrain = terrain


func _physics_process(delta):
	if _path_follow:
		_path_follow.provide_input(self)
		pass
	else:
		_car_input = myController._provide_input(_car_input)
	_car_input.steering = clamp(_car_input.steering, -1.0, 1.0)
	_car_input.acceleration = clamp(_car_input.acceleration, -1.0, 1.0)
	if isDestroyed: _car_input.acceleration = 0.0
	if not zoneCooldown.is_empty(): tickZoneCooldowns()
	if isPlayer: tickPickups()
	if fuel <= 0 && not isDestroyed: outOfFuel()
	checkGround(global_position)
	
	if fuel <= 35 && not gasWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeGasWarning()
	if health <= 50 && not healthWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeHealthWarning()

		

	
	var next = integrate(position, transform.x, velocity, _car_input, delta)
	rotation = next[0].angle()
	velocity = next[1]
	var hitVelocity = velocity #before the slide, for a wall hit's impact angle and a breakable's speed
	move_and_slide()
	_do_update_output(_car_input.acceleration)
	
	
	#finding colliders
	for i in get_slide_collision_count():
		var collision = get_slide_collision( i )
		var collider = collision.get_collider()
		##colide with an unmovable static object like a rock
		#a breakable (fence, hedge, crate...) hit fast enough is smashed, with no wall damage; an explosive
		#(barrel) goes off. Baked props carry smashSpeed as metadata (BreakableProp), scripted ones as a property.
		if (collider.has_method("smash") || BreakableProp.isBreakable(collider)) && hitVelocity.length() >= smashSpeedOf(collider):
			if collider.has_method("smash"): collider.smash(self)
			else: BreakableProp.smashNode(collider, self)
			velocity = hitVelocity * BreakableProp.SPEED_KEEP #the slide stopped the car; a smash barely slows it
		elif velocity.length() > 0.01 && World.isWall(collider):
			collideWithFixedObject( collision, hitVelocity )
		elif collider is CharacterBody2D:
			if goonBumpReady(collider): damage(5)
			#a crush never wears the car; a slow bump, or a goon that resists (shield, shell, heavy), scuffs it
			#a plow, spikes, monster tires or a golden ride crush at any speed (crushOverride)
			if not (velocity.length() > (0.0 if crushBuffActive() else 100.0) && crushGoon(collider)): wearSystem(hitZone(collision), GOON_SCUFF)
		#else: print(collider.get_class())

	if velocity.length() == 0:
		stopCarFX()
	else:
		activeCarEffects(delta)

#One physics tick of the bicycle model, without moving the body: returns [new heading (unit
#Vector2), new velocity]. `forward` is transform.x. The AI driver (scripts/ai/ai_driver.gd) runs it
#ahead from predicted states, so it must only read the car's stats, never change them.
func integrate(pos: Vector2, forward: Vector2, vel: Vector2, input: CarInput, delta: float) -> Array:
	# Base steering wheel angle and acceleration
	#damaged systems keep CONDITION_FLOOR of their stat (read only, so the AI's prediction matches)
	var steer_stat = steering * conditionFactor("steering")
	var engine_stat = engine * conditionFactor("engine")
	var traction_stat = traction * conditionFactor("tires")
	var steer_angle = input.steering * deg_to_rad( 8 + ( steer_stat / 4.0 ) )
	#Nitro (a timed pickup): more thrust, and less drag so the top speed rises by `top`
	var thrust := 1.0
	var dragScale := 1.0
	if buffs.has("nitro"):
		thrust = Pickups.DATA["nitro"]["thrust"]
		dragScale = thrust / pow(Pickups.DATA["nitro"]["top"], 2.0)

	var acceleration = input.acceleration * forward * ( engine_stat + 14 ) * 10 * ( 2.2 - abs(input.steering)) * thrust

	#the ground under this position (World's terrain table): friction with the off-road rule, grip and
	#brake multipliers, and a conveyor's push. UNKNOWN (no map loaded) keeps the car's own friction.
	var surface := World.surfaceAt(pos)
	var ground_friction := groundFriction(surface)

	# Apply friction
	if abs(vel.length()) < 5:
		vel = Vector2.ZERO
	var friction_force = vel * -ground_friction
	var drag_force = vel * vel.length() * -drag * dragScale
	if vel.length() < 100:
		friction_force *= 3
	acceleration += drag_force + friction_force
	if input.braking:
		acceleration += - ( (5 + traction_stat) * 50 / ( vel.length() + 1)  ) * vel * World.brake(surface)
	acceleration += conveyorPull(vel, World.pushAt(pos, surface))

	# Calculate steering
	var rear_wheel = pos - forward * wheel_base / 2.0 + vel * delta
	var front_wheel = pos + forward * wheel_base / 2.0 + vel.rotated(steer_angle) * delta
	var new_heading = (front_wheel - rear_wheel).normalized()
	var grip = gripFor(traction_slow, traction_stat, grip_slow_max, grip_per_traction)
	if vel.length() > slip_speed:
		grip = gripFor(traction_fast, traction_stat, grip_fast_max, grip_per_traction)
	grip *= World.grip(surface) #after the clamp, so ice and oil stay slippery whatever the traction
	var d = new_heading.dot(vel.normalized())
	if d >= 0:
		vel = vel.lerp(new_heading * vel.length(), grip)
	if d < 0:
		vel = -new_heading * min(vel.length(), ( engine_stat + 20 ) * 20)#10
	return [new_heading, vel + acceleration * delta]

#friction on a surface for this car: the table's value with the off-road rule (armor ploughs through
#soft ground); the car's own `friction` when no map is loaded. Read only, so integrate() stays pure.
func groundFriction(surface: int) -> float:
	if surface == World.UNKNOWN: return friction
	return World.effectiveFriction(World.friction(surface), armor)

#a conveyor pulls the velocity along the belt toward the belt speed (CONVEYOR_PULL per second of the
#shortfall); a car already going faster that way is left alone
const CONVEYOR_PULL := 2.0
static func conveyorPull(vel: Vector2, beltVelocity: Vector2) -> Vector2:
	if beltVelocity == Vector2.ZERO: return Vector2.ZERO
	var speed := beltVelocity.length()
	var dir := beltVelocity / speed
	var along := vel.dot(dir)
	return dir * (speed - along) * CONVEYOR_PULL if along < speed else Vector2.ZERO

#Once a tick, with the car's position: the car is wrecked once its centre has been over a lethal cell
#(deep water) for LETHAL_TICKS ticks in a row, through destroy() like the old water Area2D (which now
#drowns goons only). `friction` follows the ground under the car, for the HUD and the AI's sums.
const LETHAL_TICKS := 2
var lethalTicks := 0
func checkGround(at: Vector2) -> void:
	var surface := World.surfaceAt(at)
	if surface != World.UNKNOWN: friction = groundFriction(surface)
	if isWrecked:
		lethalTicks = 0
		return
	lethalTicks = lethalTicks + 1 if World.lethalAt(at) else 0
	if lethalTicks >= LETHAL_TICKS:
		lethalTicks = 0
		destroy()

#how square a wall hit is: |normal . direction of travel|, from WALL_IMPACT_MIN (a glancing scrape)
#to 1 (head-on). Wall damage and the speed lost scale with it.
const WALL_IMPACT_MIN := 0.15
const WALL_SPEED_KEEP := 0.85 #share of velocity kept after a head-on hit; a scrape keeps more
static func wallImpact(normal: Vector2, vel: Vector2) -> float:
	if vel.length_squared() < 0.0001: return WALL_IMPACT_MIN
	return clampf(absf(normal.dot(vel.normalized())), WALL_IMPACT_MIN, 1.0)

static func wallSpeedKeep(impact: float) -> float:
	return lerpf(1.0, WALL_SPEED_KEEP, impact)

#the speed a breakable needs to be smashed (its smashSpeed property, else BreakableProp's metadata; 0 when
#it has neither)
static func smashSpeedOf(breakable: Object) -> float:
	var need = breakable.get("smashSpeed")
	if need != null: return float(need)
	return BreakableProp.speedOf(breakable) if BreakableProp.isBreakable(breakable) else 0.0

var sparks = preload("res://scene/fx/spark/spark.tscn")
func collideWithFixedObject( collision, hitVelocity = null ):
	if not $"AudioStream-Crash".playing: 
		$"AudioStream-Crash".play()
		if isPlayer: Settings.vibrate(0.3, 0.6, 0.15)
		var spark = sparks.instantiate()
		spark.global_position = collision.get_position()
		Root.levelRoot.add_child(spark)
	var moving: Vector2 = hitVelocity if hitVelocity != null else velocity
	var hurt := wallTick(collision.get_normal(), moving, Engine.get_physics_frames())
	if hurt > 0.0:
		var before := health
		damage(hurt) #armor is applied once, in damage()
		wallHealthLost += before - health
		if moving.length() >= ZONE_WEAR_MIN_SPEED:
			wearSystem(hitZone(collision), ZONE_WEAR_PER_SPEED * hurt / WALL_DAMAGE_PER_SPEED * 100.0 / (maxf(armor, 0.0) + 100.0))
	velocity *= wallSpeedKeep(wallImpact(collision.get_normal(), moving))

#Wall damage is per contact, not per tick. Meeting a wall (none touched in the last WALL_CONTACT_GAP_TICKS)
#is a hit: WALL_DAMAGE_PER_SPEED x the speed going in x impact. Staying against it is a scrape, which costs
#at most every WALL_SCRAPE_TICKS a small amount capped at WALL_SCRAPE_MAX (about 1 health a second at
#most for a stock car), unless the car drives into the wall again at WALL_REHIT_SPEED or more (the speed
#component into it), which is a new hit. Speed is still lost every contact tick (wallSpeedKeep), and zone
#wear follows the damage, under its own 30-tick cooldown.
const WALL_CONTACT_GAP_TICKS := 10
const WALL_REHIT_SPEED := 150.0
const WALL_SCRAPE_TICKS := 15
const WALL_SCRAPE_MAX := 4.0
enum WallContact { HIT, SCRAPE, NONE }
var wallHealthLost := 0.0    #health this run's wall hits and scrapes took (the playtest's damage_rocks)
var lastWallTick := -1000    #physics frame of the last wall contact
var lastWallHitTick := -1000 #...and of the last full hit
var nextScrapeTick := 0      #a scrape costs nothing before this frame

## What one tick of wall contact counts as: `intoSpeed` is the speed into the wall (along its normal),
## `continuing` whether the car was already touching a wall, `scrapeDue` whether the scrape cooldown is over
static func wallContact(intoSpeed: float, continuing: bool, scrapeDue: bool) -> int:
	if not continuing || intoSpeed >= WALL_REHIT_SPEED: return WallContact.HIT
	return WallContact.SCRAPE if scrapeDue else WallContact.NONE

## One tick of wall contact on physics frame `now`, moving at `moving` against a wall with this normal: the
## damage it costs before armor (0 for a scrape still cooling down), and the contact state kept up to date
func wallTick(normal: Vector2, moving: Vector2, now: int) -> float:
	var kind := wallContact(absf(normal.dot(moving)), now - lastWallTick <= WALL_CONTACT_GAP_TICKS, now >= nextScrapeTick)
	if kind == WallContact.HIT && now == lastWallHitTick: kind = WallContact.NONE #two pieces of one wall in one tick: one hit
	lastWallTick = now
	if kind == WallContact.NONE: return 0.0
	if kind == WallContact.HIT: lastWallHitTick = now
	nextScrapeTick = now + WALL_SCRAPE_TICKS
	return wallDamage(kind, moving.length(), wallImpact(normal, moving))

## Damage before armor for a contact of that kind at `speed` (px/s) and `impact` (wallImpact)
static func wallDamage(kind: int, speed: float, impact: float) -> float:
	match kind:
		WallContact.HIT: return WALL_DAMAGE_PER_SPEED * speed * impact
		WallContact.SCRAPE: return minf(WALL_DAMAGE_PER_SPEED * speed * WALL_IMPACT_MIN, WALL_SCRAPE_MAX)
	return 0.0

#which system a hit wears, from the hit's normal and point in car space. The car faces +x and the
#normal points from the obstacle to the car. Front centre: engine; front corners: lights; sides ahead
#of the middle: steering; sides behind it: tires; the rear: the tank.
static func zoneForHit(localNormal: Vector2, localPoint: Vector2, carHalfWidth: float) -> String:
	if localNormal.x < -0.6: return "lights" if absf(localPoint.y) > carHalfWidth * 0.45 else "engine"
	if localNormal.x > 0.6: return "tank"
	return "steering" if localPoint.x > 0.0 else "tires"

var halfWidth := 40.0 #half the car's footprint (carBodyArea), set in _ready
func hitZone(collision: KinematicCollision2D) -> String:
	return zoneForHit(collision.get_normal().rotated(-rotation), to_local(collision.get_position()), halfWidth)

#wears a system, at most once per ZONE_COOLDOWN_TICKS so scraping along a wall can't empty it at once
func wearSystem(system: String, amount: float) -> void:
	if amount <= 0.0 || zoneCooldown.get(system, 0) > 0: return
	if buffs.has("shield") || buffs.has("golden") || (system == "tires" && buffs.has("spikes")): return
	zoneCooldown[system] = ZONE_COOLDOWN_TICKS
	setCondition(system, condition[system] - amount)

func tickZoneCooldowns() -> void:
	for system in zoneCooldown.keys():
		zoneCooldown[system] -= 1
		if zoneCooldown[system] <= 0: zoneCooldown.erase(system)

#every system back to new (the station driveway, in the modes where it doesn't end the run)
func repairAll() -> void:
	for system in condition: setCondition(system, 100.0)

#extra fuel lost per moving tick: none above 50% tank condition, FUEL_LEAK_MAX at 0%
static func fuelLeak(tankCondition: float) -> float:
	return FUEL_LEAK_MAX * clampf(1.0 - tankCondition / 50.0, 0.0, 1.0)

func stopCarFX():
	if engineAudio.playing:engineAudio.stop()
	if carDamageAudio.playing:carDamageAudio.stop()
	smoke.visible = false

#contact damage counts once per goon per GOON_BUMP_TICKS, not every tick the two touch, so a big goon
#(a Scrap Gang van, a Thunderhoof) pressed against the car doesn't drain health per frame
const GOON_BUMP_TICKS := 30
var goonBumps := {}
func goonBumpReady(goon: Object) -> bool:
	var now := Engine.get_physics_frames()
	var id := goon.get_instance_id()
	if now - goonBumps.get(id, -GOON_BUMP_TICKS) < GOON_BUMP_TICKS: return false
	if goonBumps.size() > 64: goonBumps.clear()
	goonBumps[id] = now
	return true

#false when the goon resisted: some need more speed, a hit from the side, or can't be hit right now
#(Walker.tryCrush, docs/GOONS.md). The goon handles the bounce and any damage itself.
func crushGoon(collider) -> bool:
	if not is_instance_valid(collider) || collider.isDying(): return true
	if collider.has_method("tryCrush"):
		if not collider.tryCrush(self, velocity.length()): return false
	else: collider.destroy()
	if isPlayer: Settings.vibrate(0.4, 0.0, 0.08)
	creditGoon(collider)
	if collider.get("isGiant"): giantsCrushed += 1
	reward("currentGoonsCrushed", 1) #credited now; the flying icon is only for show
	RewardFlyers.flyUpgrade(Root.upgrade.CURRENTGOONSCRUSHED, collider.global_position)
	if isPlayer: PickupEffects.onCrush(self, collider.global_position)
	return true

#a goon this car killed, by its bumper or anything it set off (SpawnManager.creditCrush: blasts, shells,
#drownings): the Goonopedia's per-goon count (gameSummary)
func creditGoon(goon: Object) -> void:
	if goon == null || not is_instance_valid(goon): return
	var id = goon.get("goonId")
	if id: crushedById[id] = crushedById.get(id, 0) + 1

var isVibratingLeft = 4
var vibrationSteps = 0
var vibrationFrequency = 5
@onready var sprite = $sprite
@onready var spriteStartingPosition = $sprite.position
@onready var shakeFrom: Vector2 = spriteStartingPosition
@onready var shakeTo: Vector2 = spriteStartingPosition
@onready var engineAudio = $"AudioStream-Engine"
@onready var tiresAudio = $"AudioStream-Tires"
@onready var carDamageAudio = $"AudioStream-CarDamage"
@onready var smoke = %Smoke
@onready var tailLamps = [$headlamps/taillamps/tailLamp3, $headlamps/taillamps/tailLamp4]
@onready var camera = $Camera2D
var tailLampsBright = null

#sound and graphics for running car
func activeCarEffects(delta):
	smoke.visible = true
	if not engineAudio.playing: engineAudio.play()
	if not carDamageAudio.playing && healthWarningGiven: carDamageAudio.play()
	engineAudio.pitch_scale = 1  +  ( velocity.length() / 400 ) 
	if not buffs.has("freetank"): fuel -= fuelBurn(_car_input.acceleration, oil * conditionFactor("tank")) + fuelLeak(condition.tank)

	#body shake: the sprite slides between two offsets, one tick at a time (no tween per shake)
	vibrationSteps += 1
	if vibrationSteps % vibrationFrequency == 0:
		vibrationFrequency = clampi( 10 -  int(velocity.length() / 500) , 2 , 10 )
		vibrationSteps = 0
		isVibratingLeft = -isVibratingLeft
		shakeFrom = sprite.position
		shakeTo = spriteStartingPosition
		if Settings.get_value("access/car_shake") && not Settings.reduce_motion():
			shakeTo += Vector2(0 , isVibratingLeft * velocity.length() / 2000)
	sprite.position = shakeFrom.lerp(shakeTo, minf(float(vibrationSteps + 1) / vibrationFrequency, 1.0))


	##FX and Audio
	if ( _car_input.braking && velocity.length() > 200.0) || ( velocity.length() > 500.0 && abs(_car_input.steering) > 0.2):
		match Settings.get_value("gfx/tire_marks"):
			1: for i in [tires[0], tires[1]]: createTiremarks(i, 6.0) #Short: rear tyres only
			2: for i in tires: createTiremarks(i, 20.0)
		if not tiresAudio.playing: tiresAudio.play()
	else:
		tiresAudio.stop()
		tiremark = {}

	var bright = _car_input.braking || gear == -1
	if bright != tailLampsBright:
		tailLampsBright = bright
		for i in tailLamps: i.energy = 0.3 if bright else 0.1

	updateCameraZoom()

		
var defaultZoomLevel:float = 0.45
var cameraAdjustmentSpeed: float = 0.0008
func updateCameraZoom():
	var targetZoomFactor: float
	if velocity.length() > 450.0 && isPlayer && is_instance_valid(camera):
		targetZoomFactor = defaultZoomLevel + 0.10 - velocity.length() / 4500.0
	else:
		targetZoomFactor = defaultZoomLevel
	if camera.zoom.x > targetZoomFactor:
		camera.zoom -= Vector2(cameraAdjustmentSpeed,cameraAdjustmentSpeed)
	elif camera.zoom.x < targetZoomFactor:
		camera.zoom += Vector2(cameraAdjustmentSpeed,cameraAdjustmentSpeed)
	#$Camera2D.zoom = Vector2(targetZoomFactor, targetZoomFactor)

var tiremarkScene = preload("res://scene/fx/tiremark.tscn")
var tiremark = {}

@onready var tires = [$sprite/tireLocation, $sprite/tireLocation2, $sprite/tireLocation3, $sprite/tireLocation4]
func createTiremarks(i, lifetime: float):
	var id = i.get_instance_id()
	var start = i.global_position
	if tiremark.has(id) && is_instance_valid(tiremark[id]):
		if tiremark[id].update(i.global_position): return
		start = tiremark[id].lastGlobalPoint() #segment full: the next one continues from its end
	var mark = tiremarkScene.instantiate()
	mark.lifetime = lifetime
	mark.position = start
	get_parent().add_child(mark)
	tiremark[id] = mark


func _update_output(_speed_factor: float, _acceleration_factor: float):
	pass


var _highest_measured_speed = 0
func _do_update_output(acceleration):
	var speed = velocity.length()
	if speed > _highest_measured_speed:
		_highest_measured_speed = speed
	var speed_factor = speed / _highest_measured_speed if _highest_measured_speed > 0 else 0
	_update_output(speed_factor, abs(acceleration))

func connectCarArea(carArea):
	carArea.car_body_entered.connect(_on_overhead_car_area_2d_car_body_entered)
	carArea.car_body_exited.connect(_on_overhead_car_area_2d_car_body_exited)


#OverheadCarArea2D (the old sand-trap patches) no longer changes handling: ground friction comes from
#World.surfaceAt in integrate(), and adding and subtracting here drifted whenever an enter and an exit
#didn't pair up. Kept inert so the old scenes still load.
func _on_overhead_car_area_2d_car_body_entered(_area: OverheadCarArea2D):
	pass


func _on_overhead_car_area_2d_car_body_exited(_area: OverheadCarArea2D):
	pass


func follow_path(path_follow: OverheadCarPathFollow2D):
	_path_follow = path_follow


var ui
var powerupsCollected = 0
signal rewarded(powerup: String, quantity) #a credited reward (not a show-only one); the playtest harness counts these
func reward(powerup: String , quantity, forShowOnly: bool = false):
	if powerup == "coin" && not forShowOnly:
		if buffs.has("frenzy"): quantity *= 2 #Coin Frenzy
		coinsSinceBet += int(quantity)
	if not forShowOnly:
		if UPGRADEABLE_STATS.has(powerup): self[powerup] = addCapped(self[powerup], quantity)
		else: self[powerup] += quantity
		rewarded.emit(powerup, quantity)
	health = clamp(health, -10.0, 100.0)
	fuel = clamp(fuel, -10.0, 100.0)
	if powerup == "health": updateDamageLook()
	if powerup != "coin" && powerup != "health" && powerup != "fuel" && powerup != "currentGoonsCrushed": 
		if powerup != "gem": powerupsCollected += 1
		if  powerupAudio.size() > 0 && not $"AudioStream-Voice".playing:
			await get_tree().create_timer(.25).timeout
			$"AudioStream-Voice".stream = powerupAudio[ randi_range(0, powerupAudio.size()-1)]
			$"AudioStream-Voice".play()
	if Root.isRunActive:
		if not is_instance_valid(ui): ui = get_tree().get_nodes_in_group("playerGameUi")[0]
		ui.updateStats()
	match powerup:
		"currentGoonsCrushed": ui.updateGoonsCrushed()
		"headlights":setHeadlightStrength()

#a stat after a powerup adds `quantity`: never past STAT_CAP, but a stat already above it
#(an old save with more upgrades than MAX_UPGRADE_LEVEL) is kept, not lowered
static func addCapped(current: int, quantity: float) -> int:
	var total := current + int(quantity)
	if total <= STAT_CAP: return total
	return maxi(current, STAT_CAP)

#fuel burned per physics tick: more oil always burns less, and the burn never reaches zero
static func fuelBurn(acceleration: float, oilStat: float) -> float:
	return absf(acceleration) * FUEL_BURN_BASE * 100.0 / (100.0 + 2.0 * maxf(oilStat, 0.0))

#how strongly velocity turns toward the heading each tick: the car's base grip plus the traction stat
static func gripFor(baseGrip: float, tractionStat: float, maxGrip: float, perPoint: float = TRACTION_GRIP_PER_POINT) -> float:
	return clampf(baseGrip + tractionStat * perPoint, GRIP_MIN, maxGrip)


func setHeadlightStrength():
	var reach = 1.0 + headlights * conditionFactor("lights") / 100.0
	if buffs.has("flood"): reach *= Pickups.DATA["flood"]["reach"]
	$headlamps/headlights.scale = Vector2(reach, reach)

func playPurseRewardAudio():
	if  purseAudio.size() > 0 && not $"AudioStream-Voice".playing:
		$"AudioStream-Voice".stream = purseAudio[ randi_range(0, purseAudio.size()-1)]
		await get_tree().create_timer(.25).timeout
		$"AudioStream-Voice".play()

func spendGems(numOfGems: int):
	if gem >= numOfGems:
		gem -= numOfGems
		return true
	else:
		return false

func damage(damage: float):
	if blockedByPickup(damage): return
	health -= (damage * 7) / ( armor + 100)
	updateDamageLook()
	if health <= 0:
		destroy()


func destroy():
	isWrecked = true #even after running out of fuel: it can no longer win
	if not isDestroyed:
		stopCarFX()
		$"AudioStream-Explosion".play()
		if isPlayer:
			Settings.vibrate(1.0, 1.0, 0.6)
			wreckSmoke()
		isDestroyed = true
		for system in condition: setCondition(system, 0.0) #the art goes fully wrecked
		for i in randi_range(1,2):
			Root.levelRoot.explode(to_global(Vector2( randi_range( 50,90 ) , randi_range( -50,20 ))))
			var modColor = 1.0 - (i/10.0)
			$sprite.modulate = Color(modColor,modColor,modColor,1.0)
			await get_tree().create_timer(randf_range(0.01 , 1.0)).timeout
		if isPlayer:
			$sprite.modulate = Color(0.8,0.8,0.8,1.0)
			await get_tree().create_timer(1).timeout
			Root.levelRoot.endLevel( false ,  Root.endCondition.NOHEALTH )
		else:
			queue_free()

	
#the player's wreck (docs/UI.md, "Transitions"): tire smoke rolls off the car and the camera shakes, so
#the explosions lead straight into the results' smoke wall as one beat
func wreckSmoke() -> void:
	Transition.sound("screech", -6.0, 0.8)
	if Settings.reduce_motion() || not is_instance_valid(Root.levelRoot): return
	var camera = get_viewport().get_camera_2d()
	if camera: Juice.rumble(camera, "offset", Transition.SHAKE, 0.3)
	var fx = TransitionFx.new()
	fx.position = global_position
	fx.z_index = 5
	Root.levelRoot.add_child(fx)
	for i in 4: fx.burst(Vector2.ZERO, 7, Vector2.RIGHT.rotated(randf() * TAU) * 160.0, 320.0, 280.0, 1.8, i * 0.12)

func playRandomFxSound():
	var randomizer = randi_range(0,1)
	if randomizer == 0: 
		$"AudioStream-Crash".play()
		await get_tree().create_timer(0.5).timeout
		$"AudioStream-Crash".stop()
	elif randomizer == 1: 
		$"AudioStream-Tires".play()
		await get_tree().create_timer(0.5).timeout
		$"AudioStream-Tires".stop()
	else: 
		$"AudioStream-Engine".play()
		await get_tree().create_timer(0.5).timeout
		$"AudioStream-Engine".stop()
		
@onready var myLights = $headlamps
func turnOnHeadlights(status: bool):
	myLights.visible = status
	
func outOfFuel():
	isDestroyed = true
	_car_input.acceleration = 0.0
	await get_tree().create_timer(2.5).timeout
	if fuel > 0.0 && not isWrecked: #coasted into a Marathon station, which filled the tank
		isDestroyed = false
		return
	Root.levelRoot.endLevel(false, Root.endCondition.NOGAS)
	
func setForwardCollisionMode(setting: bool):#activate or deactive bumper collision based on gear
	$CollisionShape2D.disabled = not setting
	$CollisionShape2D_rear.disabled = setting

#--- pickups (scripts/global/pickups.gd, docs/PICKUPS.md) ---------------------------------------
#Timed power-ups count down in physics ticks. integrate() only reads `buffs`, so the AI driver's
#prediction of boosted handling stays pure. Gadgets wait in one slot for the Use button.
const MAX_BUFFS := 4      #a fifth timed power-up replaces the one with the least time left
var buffs := {}           #pickup id -> physics ticks left
var buffTicks := {}       #pickup id -> ticks it started with (the HUD ring drains from this)
var heldItem := ""        #a gadget waiting for Use
var heldCharges := 0
var shieldHits := 0
var starFragments := 0    #three make a star
var blueprints := 0       #free garage upgrades, credited by gameSummary however the run ends
var lotteryTickets: Array = [] #each [crushes, speed, coins] digit guesses, checked by gameSummary
var hasParcel := false    #Delivery
var barricades := 0       #Defense: Barricade Kits being carried to the lot
var airborneTicks := 0    #Jump Jets
var comboCount := 0       #Crush Combo: crushes in the current chain
var comboTick := -100000  #physics frame of the chain's last crush
var bestCombo := 0
var coinsSinceBet := 0    #Double or Nothing's stake
var turboKit := false     #Turbo Kit: exhaust flames at full throttle
var buffFx: CarBuffFx
var useWasDown := false

func hasBuff(id: String) -> bool:
	return buffs.has(id)

func addBuff(id: String) -> void:
	var t := Pickups.ticks(id)
	if t <= 0: return
	if not buffs.has(id) && buffs.size() >= MAX_BUFFS:
		var shortest = buffs.keys()[0]
		for k in buffs:
			if buffs[k] < buffs[shortest]: shortest = k
		endBuff(shortest)
	buffs[id] = buffs.get(id, 0) + t
	buffTicks[id] = buffs[id]
	match id:
		"shield": shieldHits = Pickups.DATA["shield"]["hits"]
		"flood": setHeadlightStrength()
		"timewarp": Pickups.timeWarp = true
	if is_instance_valid(buffFx): buffFx.onBuff(id, true)

## `expired`: the clock ran out, rather than the effect being used up or replaced.
func endBuff(id: String, expired := false) -> void:
	if not buffs.has(id): return
	buffs.erase(id)
	buffTicks.erase(id)
	match id:
		"flood": setHeadlightStrength()
		"timewarp": Pickups.timeWarp = false
		"potato":
			if expired: PickupEffects.potatoFailed(self)
	if is_instance_valid(buffFx): buffFx.onBuff(id, false)

func tickPickups() -> void:
	if not buffs.is_empty():
		for id in buffs.keys():
			buffs[id] -= 1
			if buffs[id] <= 0: endBuff(id, true)
	if airborneTicks > 0:
		airborneTicks -= 1
		if airborneTicks == 0: Gadgets.land(self)
	if heldItem == "" || isDestroyed:
		useWasDown = false
		return
	var down: bool
	if myController.driver: down = Gadgets.aiWantsUse(self)
	else: down = not Settings.menu_open && InputMap.has_action("UseItem") && Input.is_action_pressed("UseItem")
	if down && not useWasDown && not PickupEffects.useTakenByPrompt(): useItem()
	useWasDown = down

## Takes a gadget into the slot. The same gadget adds its charges; a different one replaces the held
## one only when it is at least as rare, else it is sold for coins. Returns false when it was sold.
func giveItem(id: String) -> bool:
	var charges: int = Pickups.DATA[id].get("charges", 1)
	if heldItem == id:
		heldCharges += charges
		return true
	if heldItem == "" || Pickups.rarity(id) >= Pickups.rarity(heldItem):
		heldItem = id
		heldCharges = charges
		return true
	return false

func useItem() -> void:
	var id := heldItem
	if not Gadgets.use(self, id): return
	heldCharges -= 1
	if heldCharges <= 0:
		heldItem = ""
		heldCharges = 0

func crushBuffActive() -> bool:
	return buffs.has("golden") || buffs.has("monster") || buffs.has("plow") || buffs.has("spikes")

## True when a buff crushes this goon whatever its speed, armour or shell (Walker.tryCrush asks).
func crushOverride(goon: Node2D) -> bool:
	if buffs.has("golden") || buffs.has("monster"): return true
	var local := to_local(goon.global_position)
	if buffs.has("plow") && local.x > 0.0 && absf(local.angle()) < 0.9: return true
	if buffs.has("spikes") && absf(local.y) > halfWidth * 0.5: return true
	return false

## Golden Ride and Jump Jets ignore damage; a Bubble Shield soaks it, and real hits (more than a
## crush's contact bump) use up its charges.
func blockedByPickup(amount: float) -> bool:
	if buffs.has("golden") || airborneTicks > 0: return true
	if buffs.has("shield"):
		if amount > 5.0:
			shieldHits -= 1
			if is_instance_valid(buffFx): buffFx.shieldFlash()
			if shieldHits <= 0: endBuff("shield")
		return true
	return false

## Damage that ignores armour and shields (a Hot Potato going off on the roof).
func loseHealth(amount: float) -> void:
	health -= amount
	updateDamageLook()
	if health <= 0: destroy()
