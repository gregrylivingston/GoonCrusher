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

@export var friction:float = 0.1 #.9
#friction of 0.5 might be sand
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
var slotMachines:int = 0

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


var currentTerrain: Root.terrain
func setTerrain(terrain: int): # Root.terrain
	currentTerrain = terrain
	match terrain:
		Root.terrain.GRASS:friction = 0.13
		Root.terrain.SAND:friction = 0.5
		Root.terrain.MUD: friction = 0.5
		Root.terrain.DIRT: friction = 0.03
		Root.terrain.MOSS: friction = 0.08
		Root.terrain.SNOW: friction = 0.3


func pointIndicator():
	if is_instance_valid(Root.station):
		if global_position.distance_to(Root.station.global_position) > 4000:
			$indicator.visible = true
			$indicator.look_at(Root.station.global_position)
			%indicatorRoot.look_at(Vector2( $indicator.global_position.x + 10000, $indicator.global_position.y  ))
			var miles = global_position.distance_to(Root.station.global_position) / 10000.0
			if Settings.distance_unit() == "km": miles *= 1.609
			%indicatorDistance.text = str( int(miles) + 1) + " " + Settings.distance_unit()
		else: $indicator.visible = false
	else: $indicator.visible = false

func _physics_process(delta):
	pointIndicator()
	if _path_follow:
		_path_follow.provide_input(self)
		pass
	else:
		_car_input = myController._provide_input(_car_input)
	_car_input.steering = clamp(_car_input.steering, -1.0, 1.0)
	_car_input.acceleration = clamp(_car_input.acceleration, -1.0, 1.0)
	if isDestroyed: _car_input.acceleration = 0.0
	if not zoneCooldown.is_empty(): tickZoneCooldowns()
	if fuel <= 0 && not isDestroyed: outOfFuel()		
	
	if fuel <= 35 && not gasWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeGasWarning()
	if health <= 50 && not healthWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeHealthWarning()

		

	
	var next = integrate(position, transform.x, velocity, _car_input, delta)
	rotation = next[0].angle()
	velocity = next[1]
	move_and_slide()
	_do_update_output(_car_input.acceleration)
	
	
	#finding colliders
	for i in get_slide_collision_count():
		var collision = get_slide_collision( i )
		var collider = collision.get_collider()
		##colide with an unmovable static object like a rock
		#note: walls are TileMap nodes; moving them to TileMapLayer needs this check updated
		if velocity.length() > 0.01 && ( collider is StaticBody2D || collider is TileMap):
			collideWithFixedObject( collision )
		elif collider is CharacterBody2D:
			damage(5)
			#a crush never wears the car; a slow bump, or a goon that resists (shield, shell, heavy), scuffs it
			if not (velocity.length() > 100 && crushGoon(collider)): wearSystem(hitZone(collision), GOON_SCUFF)
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

	var acceleration = input.acceleration * forward * ( engine_stat + 14 ) * 10 * ( 2.2 - abs(input.steering))

	# Apply friction
	if abs(vel.length()) < 5:
		vel = Vector2.ZERO
	var friction_force = vel * -friction
	var drag_force = vel * vel.length() * -drag
	if vel.length() < 100:
		friction_force *= 3
	acceleration += drag_force + friction_force
	if input.braking:
		acceleration += - ( (5 + traction_stat) * 50 / ( vel.length() + 1)  ) * vel

	# Calculate steering
	var rear_wheel = pos - forward * wheel_base / 2.0 + vel * delta
	var front_wheel = pos + forward * wheel_base / 2.0 + vel.rotated(steer_angle) * delta
	var new_heading = (front_wheel - rear_wheel).normalized()
	var grip = gripFor(traction_slow, traction_stat, grip_slow_max, grip_per_traction)
	if vel.length() > slip_speed:
		grip = gripFor(traction_fast, traction_stat, grip_fast_max, grip_per_traction)
	var d = new_heading.dot(vel.normalized())
	if d >= 0:
		vel = vel.lerp(new_heading * vel.length(), grip)
	if d < 0:
		vel = -new_heading * min(vel.length(), ( engine_stat + 20 ) * 20)#10
	return [new_heading, vel + acceleration * delta]

var sparks = preload("res://scene/fx/spark/spark.tscn")
func collideWithFixedObject( collision ):
	if not $"AudioStream-Crash".playing: 
		$"AudioStream-Crash".play()
		if isPlayer: Settings.vibrate(0.3, 0.6, 0.15)
		var spark = sparks.instantiate()
		spark.global_position = collision.get_position()
		Root.levelRoot.add_child(spark)
	damage( WALL_DAMAGE_PER_SPEED * velocity.length() ) #armor is applied once, in damage()
	if velocity.length() >= ZONE_WEAR_MIN_SPEED:
		wearSystem(hitZone(collision), ZONE_WEAR_PER_SPEED * velocity.length() * 100.0 / (maxf(armor, 0.0) + 100.0))
	velocity *= 0.85

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

#false when the goon resisted: some need more speed, a hit from the side, or can't be hit right now
#(Walker.tryCrush, docs/GOONS.md). The goon handles the bounce and any damage itself.
func crushGoon(collider) -> bool:
	if not is_instance_valid(collider) || collider.isDying(): return true
	if collider.has_method("tryCrush"):
		if not collider.tryCrush(self, velocity.length()): return false
	else: collider.destroy()
	if isPlayer: Settings.vibrate(0.4, 0.0, 0.08)
	reward("currentGoonsCrushed", 1) #credited now; the flying icon is only for show
	RewardFlyers.flyUpgrade(Root.upgrade.CURRENTGOONSCRUSHED, collider.global_position)
	return true

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
	fuel -= fuelBurn(_car_input.acceleration, oil * conditionFactor("tank")) + fuelLeak(condition.tank)

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


func _on_overhead_car_area_2d_car_body_entered(area: OverheadCarArea2D):
	friction += area.friction
	drag += area.drag


func _on_overhead_car_area_2d_car_body_exited(area: OverheadCarArea2D):
	friction -= area.friction
	drag -= area.drag


func follow_path(path_follow: OverheadCarPathFollow2D):
	_path_follow = path_follow


var ui
var powerupsCollected = 0
signal rewarded(powerup: String, quantity) #a credited reward (not a show-only one); the playtest harness counts these
func reward(powerup: String , quantity, forShowOnly: bool = false):
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
	health -= (damage * 7) / ( armor + 100)
	updateDamageLook()
	if health <= 0:
		destroy()


func destroy():
	isWrecked = true #even after running out of fuel: it can no longer win
	if not isDestroyed:
		stopCarFX()
		$"AudioStream-Explosion".play()
		if isPlayer: Settings.vibrate(1.0, 1.0, 0.6)
		isDestroyed = true
		for system in condition: setCondition(system, 0.0) #the art goes fully wrecked
		for i in randi_range(1,2):
			var newExplosion = Root.levelRoot.explosionScene.instantiate()
			newExplosion.position = Vector2( randi_range( 50,90 ) , randi_range( -50,20 ))
			var modColor = 1.0 - (i/10.0)
			$sprite.modulate = Color(modColor,modColor,modColor,1.0)
			add_child(newExplosion)
			await get_tree().create_timer(randf_range(0.01 , 1.0)).timeout
		if isPlayer:
			$sprite.modulate = Color(0.8,0.8,0.8,1.0)
			await get_tree().create_timer(1).timeout
			Root.levelRoot.endLevel( false ,  Root.endCondition.NOHEALTH )
		else:
			queue_free()

	
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
	%indicatorLight.visible = status
	
func outOfFuel():
	isDestroyed = true
	_car_input.acceleration = 0.0
	await get_tree().create_timer(2.5).timeout
	Root.levelRoot.endLevel(false, Root.endCondition.NOGAS)
	
func setForwardCollisionMode(setting: bool):#activate or deactive bumper collision based on gear
	$CollisionShape2D.disabled = not setting
	$CollisionShape2D_rear.disabled = setting
