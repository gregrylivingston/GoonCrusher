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
	if pressed("Accelerate"):
		if car.gear < 1:car.setForwardCollisionMode(true)
		_input.acceleration = 1.0
		car.gear = int(car.velocity.length())/300 + 1 #the HUD tachometer shows car.gear
		_input.braking = false
	else:
		_input.acceleration = 0.0

	_input.steering = nextSteering(_input.steering, pressed("TurnLeft"), pressed("TurnRight"), car.traction)

	if pressed("Brake"):
		if car.velocity.length() < 10 || car.gear == -1:
			if car.gear > -1:car.setForwardCollisionMode(false)
			car.gear = -1
			_input.acceleration = -1.0
			_input.braking = false
		else: _input.braking = true
	else: _input.braking = false
	return _input

#the wheel after one tick: a held key turns it further each tick (faster with traction), and
#letting go recentres it. Shared with the AI driver's prediction.
static func nextSteering(steering: float, left: bool, right: bool, traction: int) -> float:
	if left: return steering - (0.01 + traction / 100.0)
	if right: return steering + (0.01 + traction / 100.0)
	return steering * 0.9
