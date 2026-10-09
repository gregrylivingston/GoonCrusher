extends Node2D

var ui
@onready var car: OverheadCarBody2D = get_parent()
var driver = null #an AIDriver (scripts/ai/ai_driver.gd); when set, the AI presses the keys instead of the player (playtesting)

#is a key held: the player's, or the AI driver's when one is attached
func pressed(action: String) -> bool:
	return driver.isPressed(action) if driver else Input.is_action_pressed(action)

func _provide_input(_input):
	if driver: driver.think() #decides this tick's keys before they are read below
	elif Settings.menu_open: #the dev console is open over the running game: keys are typing, not driving
		_input.acceleration = 0.0
		_input.braking = false
		_input.handbrake = false
		_input.steering *= 0.9
		return _input
	_input.handbrake = pressed("Handbrake") #a powerslide (OverheadCarBody2D.HANDBRAKE_*)
	if car.gears > 0:
		gearbox(_input)
		var aim := Input.get_axis("TurnLeft", "TurnRight") if not driver else steerTarget(pressed("TurnLeft"), pressed("TurnRight"))
		_input.steering = steerToward(_input.steering, aim, car.steerRate())
		return _input
	if pressed("Accelerate"):
		if car.gear < 1:car.setForwardCollisionMode(true)
		_input.acceleration = 1.0
		car.gear = int(car.velocity.length())/300 + 1 #the HUD tachometer shows car.gear
		_input.braking = false
	else:
		_input.acceleration = 0.0

	#the AI holds keys; a player's stick steers part of the way (the keyboard gives -1, 0 or 1)
	var target := Input.get_axis("TurnLeft", "TurnRight") if not driver else steerTarget(pressed("TurnLeft"), pressed("TurnRight"))
	_input.steering = steerToward(_input.steering, target, car.steerRate())

	if pressed("Brake"):
		if car.velocity.length() < 10 || car.gear == -1:
			if car.gear > -1:car.setForwardCollisionMode(false)
			car.gear = -1
			_input.acceleration = -1.0
			_input.braking = false
		else: _input.braking = true
	else: _input.braking = false
	return _input

#A geared car (OverheadCarBody2D, "the gearbox"). By hand: ShiftUp / ShiftDown move the lever (down past N is
#R), Accelerate drives in the gear it is in (backward in R), and Brake only brakes. Otherwise (the AI, or the
#Automatic Gearbox setting) autoGear picks the gear and Brake at a standstill backs up, as in an automatic.
func gearbox(_input) -> void:
	_input.braking = false
	_input.acceleration = 0.0
	if car.isManual():
		if Input.is_action_just_pressed("ShiftUp"): car.shift(1)
		if Input.is_action_just_pressed("ShiftDown"): car.shift(-1)
		if pressed("Accelerate"): _input.acceleration = -1.0 if car.gear == -1 else 1.0
		_input.braking = pressed("Brake")
	else:
		if pressed("Accelerate"):
			car.setGear(car.autoGear(car.gear, car.velocity.length()))
			_input.acceleration = 1.0
		if pressed("Brake"):
			if car.velocity.length() < 10 || car.gear == -1:
				car.setGear(-1)
				_input.acceleration = -1.0
			else: _input.braking = true
	_input.gear = car.gear

#the wheel after one tick with these keys held. Shared with the AI driver's prediction.
static func nextSteering(steering: float, left: bool, right: bool, rate: float) -> float:
	return steerToward(steering, steerTarget(left, right), rate)

static func steerTarget(left: bool, right: bool) -> float:
	return -1.0 if left else (1.0 if right else 0.0)

#The wheel moves toward `target` (-1 to 1) by `rate` a tick (OverheadCarBody2D.steerRate: the steering
#stat and weight). Heading back toward the centre (letting go, easing off, or counter-steering) is
#CarHandling.steerReturn times quicker, and stops at the centre before turning the other way.
static func steerToward(steering: float, target: float, rate: float) -> float:
	if steering != 0.0 && signf(target - steering) != signf(steering):
		return move_toward(steering, target if target * steering > 0.0 else 0.0, rate * CarHandling.tune.steerReturn)
	return move_toward(steering, target, rate)
