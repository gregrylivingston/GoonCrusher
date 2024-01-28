extends Node2D

var ui
@onready var car: OverheadCarBody2D = get_parent()
@onready var gearui: Control = get_tree().get_first_node_in_group("gearui")


func _provide_input(_input):
	if Input.is_action_pressed("Accelerate"):
		if car.gear < 1:car.setForwardCollisionMode(true)
		_input.acceleration = 1.0
		car.gear = int(car.velocity.length())/300 + 1
		gearui.text = str(car.gear)
		_input.braking = false
	else: 
		_input.acceleration = 0.0
	
	if Input.is_action_pressed("TurnLeft"):		_input.steering -= 0.01 +  ( car.traction / 100.0 )
	elif Input.is_action_pressed("TurnRight"):		_input.steering += 0.01 + ( car.traction / 100.0 )
	else: _input.steering *= 0.9
	
	if Input.is_action_pressed("Brake"):
		if car.velocity.length() == 0 || car.gear == -1:
			if car.gear > -1:car.setForwardCollisionMode(false)
			car.gear = -1
			gearui.text = "R"
			_input.acceleration = -1.0
			_input.braking = false
		else: _input.braking = true
	else: _input.braking = false
	return _input
