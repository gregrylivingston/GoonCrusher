extends Node2D

var ui
# Called when the node enters the scene tree for the first time.
func _ready():
	get_parent().myController = self




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _provide_input(_input):
	if Input.is_action_pressed("ui_up"):_input.acceleration = 1.0
	else: _input.acceleration = 0.0
	
	if Input.is_action_pressed("ui_left"):		_input.steering -= 0.01 +  ( get_parent().traction / 100.0 )
	elif Input.is_action_pressed("ui_right"):		_input.steering += 0.01 + ( get_parent().traction / 100.0 )
	else: _input.steering *= 0.9
	
	if Input.is_action_pressed("ui_down"):_input.braking = true
	else: _input.braking = false
	return _input
