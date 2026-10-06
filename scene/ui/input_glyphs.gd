class_name InputGlyphs

#Which input the player is using right now, and what to call an action's key or button on it.
#KeyHint nodes feed input events here, so on-screen prompts switch between keyboard and controller
#the moment the player switches. Bindings are read from InputMap, so rebinding shows up too.

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View",
	JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right", JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
}
const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_LEFT_X: "L-Stick", JOY_AXIS_LEFT_Y: "L-Stick"}
const KEY_SHORT := {"Escape": "Esc", "Enter": "Enter", "Space": "Space", "BackSpace": "Back", "PageUp": "PgUp", "PageDown": "PgDn"}

static var usingPad := Input.get_connected_joypads().size() > 0

#notes which device an event came from; small stick drift and tiny mouse moves don't count
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton && event.pressed: usingPad = true
	elif event is InputEventJoypadMotion && absf(event.axis_value) > 0.5: usingPad = true
	elif (event is InputEventKey || event is InputEventMouseButton) && event.pressed: usingPad = false
	elif event is InputEventMouseMotion && event.relative.length() > 6.0: usingPad = false

#the label for the first binding of `action` on the current device, or "" if it has none there
static func label(action: String, pad := usingPad) -> String:
	if not InputMap.has_action(action): return ""
	for event in InputMap.action_get_events(action):
		if pad:
			if event is InputEventJoypadButton: return PAD_NAMES.get(event.button_index, "Btn %d" % event.button_index)
			if event is InputEventJoypadMotion: return AXIS_NAMES.get(event.axis, "Stick")
		else:
			if event is InputEventKey && event.keycode != KEY_MENU: return keyName(event) #Esc reads better than the Menu key
			if event is InputEventMouseButton: return "Click"
	return ""

static func keyName(event: InputEventKey) -> String:
	var code = event.keycode
	if code == KEY_NONE && event.physical_keycode != KEY_NONE:
		code = event.physical_keycode
		if DisplayServer.get_name() != "headless": code = DisplayServer.keyboard_get_keycode_from_physical(code) #the player's layout
	var text = OS.get_keycode_string(code)
	return KEY_SHORT.get(text, text)

#menu actions beyond Godot's ui_* and the ones Settings adds (ui_tab_prev/next, ui_reset_tab),
#and the controller's A and B for accept and back, which the project's ui_* don't bind
static func ensureMenuActions() -> void:
	addEvent("ui_accept", pad(JOY_BUTTON_A))
	addEvent("ui_cancel", pad(JOY_BUTTON_B))
	addIfMissing("ui_upgrade", key(KEY_U), pad(JOY_BUTTON_Y))
	addIfMissing("ui_records", key(KEY_R), pad(JOY_BUTTON_X))

static func addIfMissing(action: String, keyEvent: InputEvent, padEvent: InputEvent) -> void:
	if InputMap.has_action(action): return
	InputMap.add_action(action)
	InputMap.action_add_event(action, keyEvent)
	InputMap.action_add_event(action, padEvent)

static func addEvent(action: String, event: InputEvent) -> void:
	if InputMap.has_action(action) && not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

static func key(code: int) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = code
	return event

static func pad(button: int) -> InputEventJoypadButton:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	return event
