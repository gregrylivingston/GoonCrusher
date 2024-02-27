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



@export var engine: int = 25  # Forward acceleration force.
@export var steering: int = 12  # Amount that front wheel turns, in degrees
@export var traction: int = 4   #brakes and turn-rate-increase
@export var armor: int = 1
var luck: int = 1
var clover: int = 1
var oil: int = 1
var headlights: int = 1

@export var friction:float = 0.1 #.9
#friction of 0.5 might be sand
@export var drag:float = 0.0005   #.0015

@export var slip_speed:int = 100  # Speed where traction is reduced
@export var traction_fast:float = 0.1  # High-speed traction
@export var traction_slow:float = 0.7  # Low-speed traction
@export var wheel_base:int = 70  # Distance from front to rear wheel

var health:float = 100.0
var fuel:float = 100.0
var coin:int = 0
var gem:int = 0
var currentGoonsCrushed:int = 0
var slotMachines:int = 0

@onready var rewardAudioPlayer = $"AudioStream-Reward"

@export var isPlayer = true
var isDestroyed: bool = false

func getIsPlayer():return isPlayer

@export var profilePic: Texture2D
@export var backgroundPic: Texture2D
@export var charName: String = "Hi"
@export var carId:String

@export var introAudio: Array[AudioStreamMP3] = []
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
		$headlamps/carhighlight.position = $sprite.position
	else: 
		$headlamps/carhighlight.queue_free()

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
			var distance = int ( global_position.distance_to(Root.station.global_position) / 10000 ) 			
			%indicatorDistance.text = str( distance + 1) + " mi"
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
	var traction = traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast
	var d = new_heading.dot(velocity.normalized())
	if d >= 0:
		velocity = velocity.lerp(new_heading * velocity.length(), traction)
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
		#print(collider.get_class())
		##colide with an unmovable static object like a rock
		if velocity.length() > 0.01 && ( collider.get_class() == "StaticBody2D" || collider.get_class() == "TileMap"):
			collideWithFixedObject( get_slide_collision(i) )
		elif collider.get_class() == "CharacterBody2D":
			damage(0.5)
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
		var spark = sparks.instantiate()
		spark.global_position = collision.get_position()
		Root.levelRoot.add_child(spark)
	damage(  velocity.length()  / ( armor + 5 )  )
	velocity *= 0.85

func stopCarFX():
	if $"AudioStream-Engine".playing:$"AudioStream-Engine".stop()
	if $"AudioStream-CarDamage".playing:$"AudioStream-CarDamage".stop()
	%Smoke.visible = false

func crushGoon(collider):
	if is_instance_valid(collider):
		var newPowerup = Root.getSpecificPowerup(Root.upgrade.CURRENTGOONSCRUSHED)
		newPowerup.global_position = collider.global_position
		Root.levelRoot.add_child(newPowerup)
		newPowerup._on_area_2d_body_entered(self)
		collider.destroy()
	#currentGoonsCrushed += 1

var isVibratingLeft = 4
var vibrationSteps = 0
var vibrationFrequency = 5
@onready var spriteStartingPosition = $sprite.position

#sound and graphics for running car
func activeCarEffects(delta):
	%Smoke.visible = true
	if not $"AudioStream-Engine".playing: $"AudioStream-Engine".play()
	if not $"AudioStream-CarDamage".playing && healthWarningGiven: $"AudioStream-CarDamage".play()
	$"AudioStream-Engine".pitch_scale = 1  +  ( velocity.length() / 400 ) 
	fuel -= velocity.length() / 50000

	vibrationSteps += 1
	if vibrationSteps % vibrationFrequency == 0:
		vibrationFrequency = clampi( 10 -  int(velocity.length() / 500) , 2 , 10 )
		vibrationSteps = 0
		isVibratingLeft = -isVibratingLeft
		var vibrationTarget = spriteStartingPosition + Vector2(0 , isVibratingLeft * velocity.length() / 2000)
		get_tree().create_tween().tween_property( $sprite , "position" , vibrationTarget ,  vibrationFrequency * delta)


	##FX and Audio
	if ( _car_input.braking && velocity.length() > 200.0) || ( velocity.length() > 500.0 && abs(_car_input.steering) > 0.2):
		for i in tires: createTiremarks(i)
		if not $"AudioStream-Tires".playing: $"AudioStream-Tires".play()
	else: 
		$"AudioStream-Tires".stop()
		tiremark = {}
		
	if _car_input.braking || gear == -1:
		for i in [$headlamps/taillamps/tailLamp3, $headlamps/taillamps/tailLamp4]:i.energy = 0.3
	else: 		
		for i in [$headlamps/taillamps/tailLamp3, $headlamps/taillamps/tailLamp4]:i.energy = 0.1

	#zoom out if going fast
	if velocity.length() > 450.0 && isPlayer && is_instance_valid($Camera2D):
		var myZoomFactor = 0.55 - velocity.length() / 9000.0
		$Camera2D.zoom = Vector2(myZoomFactor, myZoomFactor)
	else:
		$Camera2D.zoom = Vector2(0.5,0.5)
		



var tiremarkScene = preload("res://scene/fx/tiremark.tscn")
var tiremark = {}

@onready var tires = [$sprite/tireLocation, $sprite/tireLocation2, $sprite/tireLocation3, $sprite/tireLocation4]
func createTiremarks(i):
	if tiremark.has(i.get_instance_id()) && is_instance_valid(tiremark[i.get_instance_id()]):
		tiremark[i.get_instance_id()].update(i.global_position)
	else:
		tiremark[i.get_instance_id()] = tiremarkScene.instantiate()
		tiremark[i.get_instance_id()].position = i.global_position
		get_parent().add_child(tiremark[i.get_instance_id()])


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
	if not forShowOnly: self[powerup] += quantity
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
	if powerup == "currentGoonsCrushed": ui.updateGoonsCrushed()


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
	health -= damage / ( armor + 5)
	if health <= 0:
		destroy()


var explosion = load("res://scene/fx/explosion.tscn")
func destroy():
	if not isDestroyed:
		stopCarFX()
		$"AudioStream-Explosion".play()
		isDestroyed = true
		for i in randi_range(1,2):
			var newExplosion = explosion.instantiate()
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
