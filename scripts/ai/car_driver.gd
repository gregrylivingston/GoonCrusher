class_name CarDriver extends Node2D

#Whatever holds a car's keys in place of a person (docs/AI_DRIVER.md). The car's controller
#(playerCarController.driver) calls think() once per physics tick and then reads every key from here:
#the four driving keys and the handbrake through isPressed(), the shift lever through justPressed(), and
#the car reads its horn, gadget, boost and ability buttons through OverheadCarBody2D.actionDown, which asks
#the driver too. So a driver has exactly the buttons a player has, and nothing reaches the car another way.
#AIDriver (scripts/ai/ai_driver.gd) is the one that plans; each car's own driver extends that.

var car: OverheadCarBody2D

#decides this tick's keys; called before they are read
func think() -> void:
	pass

#is a key held this tick: Accelerate, Brake, TurnLeft, TurnRight, Handbrake, UseItem, UseMove, Horn, Ability
func isPressed(_action: String) -> bool:
	return false

#was a key pressed this tick: ShiftUp, ShiftDown (a manual gearbox's lever)
func justPressed(_action: String) -> bool:
	return false

#where the wheel is held, -1 (left) to 1: the keys' by default; a driver with a stick says how far
func steerAim() -> float:
	return -1.0 if isPressed("TurnLeft") else (1.0 if isPressed("TurnRight") else 0.0)

#does this driver work a geared car's lever itself (OverheadCarBody2D.isManual); otherwise the box is automatic
func shiftsByHand() -> bool:
	return false

#puts this driver in the car's seat (a car whose _ready has run)
func seat(target: OverheadCarBody2D) -> void:
	car = target
	target.add_child(self)
	target.myController.driver = self

#gives the keys back to the player
func leave() -> void:
	if is_instance_valid(car) && car.myController.driver == self: car.myController.driver = null
	queue_free()
