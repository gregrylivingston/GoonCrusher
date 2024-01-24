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



@export var engine = 25  # Forward acceleration force.
@export var steering = 12  # Amount that front wheel turns, in degrees
@export var traction = 4.0   #brakes and turn-rate-increase
@export var armor = 1

@export var friction = 0.9
@export var drag = 0.0015

@export var slip_speed = 400  # Speed where traction is reduced
@export var traction_fast = 0.1  # High-speed traction
@export var traction_slow = 0.7  # Low-speed traction
@export var wheel_base = 70  # Distance from front to rear wheel

var health = 100.0
var fuel = 100.0
var coin = 0
var gem = 0
var currentGoonsCrushed = 0
var slotMachines = 0

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


var _car_input := CarInput.new()
var _path_follow: OverheadCarPathFollow2D = null
@onready var myController = $CarController


func _init():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _ready():
	purseAudio.append_array(powerupAudio)
	_connect_car_areas(get_tree().root)
	updateAudioLevels()
	$"AudioStream-Engine".stream = engineNoise
	$"AudioStream-Engine".play()

	if isPlayer:
		add_to_group("playerCar")
		Root.playerCar = self
		engine += SaveManager.playerData.cars[carId].upgrades.engine
		steering += SaveManager.playerData.cars[carId].upgrades.steering
		traction += SaveManager.playerData.cars[carId].upgrades.traction
		armor += SaveManager.playerData.cars[carId].upgrades.armor	
		
		$headlamps/carhighlight.texture = $sprite.texture
		$headlamps/carhighlight.position = $sprite.position
	else: 
		$headlamps/carhighlight.queue_free()

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



func _physics_process(delta):
	if _path_follow:
		_path_follow.provide_input(self)
	else:
		_car_input = myController._provide_input(_car_input)
	_car_input.steering = clamp(_car_input.steering, -1.0, 1.0)
	_car_input.acceleration = clamp(_car_input.acceleration, -1.0, 1.0)
	if isDestroyed: _car_input.acceleration = 0.0
	if fuel <= 0: outOfFuel()		
	
	if fuel <= 35 && not gasWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeGasWarning()
	if health <= 50 && not healthWarningGiven && not $"AudioStream-Voice".playing && isPlayer:makeHealthWarning()

		

	
	# Base steering wheel angle and acceleration
	var steer_angle = _car_input.steering * deg_to_rad( 5 + ( steering / 4.0 ) )
	var acceleration = _car_input.acceleration * transform.x * engine * 70 

	# Apply friction
	if velocity.length() < 5:
		velocity = Vector2.ZERO
	var friction_force = velocity * -friction
	var drag_force = velocity * velocity.length() * -drag
	if velocity.length() < 100:
		friction_force *= 3
	acceleration += drag_force + friction_force
	if _car_input.braking:
		acceleration += velocity * - ( traction / 10.0 )
	
	# Calculate steering
	var rear_wheel = position - transform.x * wheel_base / 2.0 + velocity * delta
	var front_wheel = position + transform.x * wheel_base / 2.0 + velocity.rotated(steer_angle) * delta
	var new_heading = (front_wheel - rear_wheel).normalized()
	var traction = traction_slow
	if velocity.length() > slip_speed:
		traction = traction_fast
	var d = new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = velocity.lerp(new_heading * velocity.length(), traction)
	if d < 0:
		velocity = -new_heading * min(velocity.length(), engine * 10)
	
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
		if velocity.length() > 0.01 && collider.get_class() == "StaticBody2D":
			if not $"AudioStream-Crash".playing: $"AudioStream-Crash".play()
			damage( ( velocity.length() / 10 ) / armor )
			velocity *= 0.9
		elif collider.get_class() == "CharacterBody2D":
			damage(0.5)
			if velocity.length() > 500:crushGoon(collider)

	if velocity.length() == 0:
		stopCarFX()
	else:
		activeCarEffects(delta)
		
func stopCarFX():
	if $"AudioStream-Engine".playing:$"AudioStream-Engine".stop()
	if $"AudioStream-CarDamage".playing:$"AudioStream-CarDamage".stop()
	$sprite/exhaust.visible = false

func crushGoon(collider):
	var newPowerup = Root.getSpecificPowerup("currentGoonsCrushed")
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
	$sprite/exhaust.visible = true
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
	if ( _car_input.braking && velocity.length() > 200.0) || ( velocity.length() > 800.0 && abs(_car_input.steering) > 0.2):
		for i in tires: createTiremarks(i)
		if not $"AudioStream-Tires".playing: $"AudioStream-Tires".play()
	else: 
		$"AudioStream-Tires".stop()
		tiremark = {}

	#zoom out if going fast
	if velocity.length() > 450.0 && isPlayer && is_instance_valid($Camera2D):
		var myZoomFactor = 0.6 - velocity.length() / 4500.0
		$Camera2D.zoom = Vector2(myZoomFactor, myZoomFactor)
	else:
		$Camera2D.zoom = Vector2(0.5,0.5)
		



var tiremarkScene = preload("res://scene/fx/tiremark.tscn")
var tiremark = {}

@onready var tires = [$sprite/tireLocation, $sprite/tireLocation2, $sprite/tireLocation3, $sprite/tireLocation4]
func createTiremarks(i):
	if tiremark.has(i.get_instance_id()):
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


func _connect_car_areas(node: Node):
	for child in node.get_children(true):
		if child is OverheadCarArea2D:
			child.car_body_entered.connect(_on_overhead_car_area_2d_car_body_entered)
			child.car_body_exited.connect(_on_overhead_car_area_2d_car_body_exited)
		_connect_car_areas(child)


func _on_overhead_car_area_2d_car_body_entered(_body, area: OverheadCarArea2D):
	friction += area.friction
	drag += area.drag


func _on_overhead_car_area_2d_car_body_exited(_body, area: OverheadCarArea2D):
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
		if  powerupAudio.size() > 0 && $"AudioStream-Voice".playing == false:
			await get_tree().create_timer(.25).timeout
			$"AudioStream-Voice".stream = powerupAudio[ randi_range(0, powerupAudio.size()-1)]
			$"AudioStream-Voice".play()
	if Root.isRunActive:
		if not is_instance_valid(ui): ui = get_tree().get_nodes_in_group("playerGameUi")[0]
		ui.updateStats()
	if powerup == "currentGoonsCrushed": ui.updateGoonsCrushed()


func playPurseRewardAudio():
	if  purseAudio.size() > 0:# && $"AudioStream-Voice".playing == false:
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
	health -= damage / armor
	if health <= 0:
		destroy()


var explosion = load("res://scene/fx/explosion.tscn")
func destroy():
	if not isDestroyed:
		isDestroyed = true
		for i in randi_range(4,10):
			await get_tree().create_timer(randf_range(0.01 , 1.0)).timeout
			var newExplosion = explosion.instantiate()
			newExplosion.position = Vector2( randi_range( -50,50 ) , randi_range( -50,50 ))
			var modColor = 1.0 - (i/10.0)
			$sprite.modulate = Color(modColor,modColor,modColor,1.0)
			add_child(newExplosion)
		if isPlayer:
			$sprite.modulate = Color(0.5,0.5,0.5,1.0)
			await get_tree().create_timer(1).timeout
			Root.levelRoot.endLevel(false)
		else:
			queue_free()

func updateAudioLevels():
	$"AudioStream-Engine".volume_db =  SaveManager.getVolume("fx")
	$"AudioStream-Tires".volume_db = 	SaveManager.getVolume("fx")
	$"AudioStream-Crash".volume_db = 	SaveManager.getVolume("fx")
	$"AudioStream-Voice".volume_db = 2 + SaveManager.getVolume("voice")
	$"AudioStream-CarDamage".volume_db = -5 + SaveManager.getVolume("fx")
	
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
		
@onready var headlamps = $headlamps
func turnOnHeadlights(status: bool):
	headlamps.visible = status
	
func outOfFuel():
	_car_input.acceleration = 0.0
	await get_tree().create_timer(1).timeout
	Root.levelRoot.endLevel(false)
	
	
