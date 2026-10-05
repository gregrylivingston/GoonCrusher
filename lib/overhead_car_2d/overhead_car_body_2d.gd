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
@export var carDamagedTexture: Texture2D

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
		
		
	$headlamps/carhighlight.texture = $sprite.texture
	$headlamps/carhighlight.scale = $sprite.scale
	$headlamps/carhighlight.position = $sprite.position
	setHeadlightStrength()
	stopCarFX()

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
	$sprite.texture = carDamagedTexture
	$headlamps/carhighlight.texture = carDamagedTexture
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
	if fuel <= 0 && not isDestroyed: outOfFuel()		
	
	if fuel <= 35 && not gasWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeGasWarning()
	if health <= 50 && not healthWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeHealthWarning()

		

	
	# Base steering wheel angle and acceleration
	var steer_angle = _car_input.steering * deg_to_rad( 8 + ( steering / 4.0 ) )
	
	var acceleration = _car_input.acceleration * transform.x * ( engine + 14 ) * 10 * ( 2.2 - abs(_car_input.steering))

	# Apply friction
	if abs(velocity.length()) < 5:
		velocity = Vector2.ZERO
	var friction_force = velocity * -friction
	var drag_force = velocity * velocity.length() * -drag
	if velocity.length() < 100:
		friction_force *= 3
	acceleration += drag_force + friction_force
	if _car_input.braking:
		acceleration += - ( (5 + traction) * 50 / ( velocity.length() + 1)  ) * velocity
	
	# Calculate steering
	var rear_wheel = position - transform.x * wheel_base / 2.0 + velocity * delta
	var front_wheel = position + transform.x * wheel_base / 2.0 + velocity.rotated(steer_angle) * delta
	var new_heading = (front_wheel - rear_wheel).normalized()
	var grip = gripFor(traction_slow, traction, grip_slow_max, grip_per_traction)
	if velocity.length() > slip_speed:
		grip = gripFor(traction_fast, traction, grip_fast_max, grip_per_traction)
	var d = new_heading.dot(velocity.normalized())
	if d >= 0:
		velocity = velocity.lerp(new_heading * velocity.length(), grip)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), ( engine + 20 ) * 20)#10
	
	# Update the physics engine
	rotation = new_heading.angle()
	velocity += acceleration * delta
	move_and_slide()
	_do_update_output(_car_input.acceleration)
	
	
	#finding colliders
	for i in get_slide_collision_count():
		var collider = get_slide_collision( i ).get_collider()
		##colide with an unmovable static object like a rock
		#note: walls are TileMap nodes; moving them to TileMapLayer needs this check updated
		if velocity.length() > 0.01 && ( collider is StaticBody2D || collider is TileMap):
			collideWithFixedObject( get_slide_collision(i) )
		elif collider is CharacterBody2D:
			damage(5)
			if velocity.length() > 100:crushGoon(collider)
		#else: print(collider.get_class())

	if velocity.length() == 0:
		stopCarFX()
	else:
		activeCarEffects(delta)

var sparks = preload("res://scene/fx/spark/spark.tscn")
func collideWithFixedObject( collision ):
	if not $"AudioStream-Crash".playing: 
		$"AudioStream-Crash".play()
		if isPlayer: Settings.vibrate(0.3, 0.6, 0.15)
		var spark = sparks.instantiate()
		spark.global_position = collision.get_position()
		Root.levelRoot.add_child(spark)
	damage( WALL_DAMAGE_PER_SPEED * velocity.length() ) #armor is applied once, in damage()
	velocity *= 0.85

func stopCarFX():
	if engineAudio.playing:engineAudio.stop()
	if carDamageAudio.playing:carDamageAudio.stop()
	smoke.visible = false

func crushGoon(collider):
	if is_instance_valid(collider):
		if not collider.isDying():
			if isPlayer: Settings.vibrate(0.4, 0.0, 0.08)
			collider.destroy()
			reward("currentGoonsCrushed", 1) #credited now; the flying icon is only for show
			RewardFlyers.flyUpgrade(Root.upgrade.CURRENTGOONSCRUSHED, collider.global_position)

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
	fuel -= fuelBurn(_car_input.acceleration, oil)

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
func reward(powerup: String , quantity, forShowOnly: bool = false):
	if not forShowOnly:
		if UPGRADEABLE_STATS.has(powerup): self[powerup] = addCapped(self[powerup], quantity)
		else: self[powerup] += quantity
	health = clamp(health, -10.0, 100.0)
	fuel = clamp(fuel, -10.0, 100.0)
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
	$headlamps/headlights.scale = Vector2( 1.0 + float(headlights)/100 , 1.0 + float(headlights)/100)

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
	if health <= 0:
		destroy()


func destroy():
	isWrecked = true #even after running out of fuel: it can no longer win
	if not isDestroyed:
		stopCarFX()
		$"AudioStream-Explosion".play()
		if isPlayer: Settings.vibrate(1.0, 1.0, 0.6)
		isDestroyed = true
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
