class_name PadDriver extends CarDriver

#The second player's hands (Coop): one controller, read by device once a tick. It uses the pad bindings
#the first player has (Settings' controller slot), so a rebound button moves for both. The stick steers part
#of the way, as the first player's does.

const ACTIONS := ["Accelerate", "Brake", "TurnLeft", "TurnRight", "Handbrake", "UseItem", "UseMove", "Horn", "Ability", "ShiftUp", "ShiftDown"]

var device := 0
var held := {}    #action -> how far it is pressed this tick, 0 to 1
var heldLast := {}

func think() -> void:
	heldLast = held
	held = {}
	for action in ACTIONS: held[action] = strength(action)

#how far `action` is pressed on this driver's controller: a button is all the way, a stick or trigger its
#travel past the action's deadzone
func strength(action: String) -> float:
	if Settings.menu_open || not InputMap.has_action(action): return 0.0
	var dead := InputMap.action_get_deadzone(action)
	var most := 0.0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			if Input.is_joy_button_pressed(device, event.button_index): return 1.0
		elif event is InputEventJoypadMotion:
			var travel := Input.get_joy_axis(device, event.axis) * signf(event.axis_value)
			if travel > dead: most = maxf(most, inverse_lerp(dead, 1.0, travel))
	return most

func isPressed(action: String) -> bool:
	return held.get(action, 0.0) > 0.0

func justPressed(action: String) -> bool:
	return isPressed(action) && heldLast.get(action, 0.0) <= 0.0

func steerAim() -> float:
	return held.get("TurnRight", 0.0) - held.get("TurnLeft", 0.0)

func shiftsByHand() -> bool:
	return not Settings.get_value("gameplay/auto_gearbox")
