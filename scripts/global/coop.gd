class_name Coop

#Local two-player (docs/MODES.md, "Two players"). A second person on a controller joins in Level Options, picks
#one of the garage's cars, a gadget and a boost, and drives beside the player on a split screen (CoopRun).
#The mode picks their side: a rival in a Goon Cup mode, a friend everywhere else (isRival). The save, the rewards, the HUD and the run's goal all stay the first player's: the
#guest's car is a car with `isGuest` set and `isPlayer` off, so everything that asks for the player's car
#still finds only the first player's.
#
#The pads: every pad binding in the InputMap answers any controller, so while a guest is in, they are pointed
#at one device (the first player's) and the guest's controller is read by device (PadDriver, menuInput).

const NO_PAD := 30 #a device nothing is plugged into: where the pad bindings point while the first player is on the keyboard

static var active := false
static var device := -1   #the guest's controller
static var car := 0       #the guest's car: an index into the save's cars
static var gadget := ""   #the guest's loadout (Pickups.LOADOUT, BOOST_LOADOUT)
static var boost := ""
static var lastPad := -1  #the pad that last pressed a button in the menu, -1 after a key or a click: the first player's
static var guest: OverheadCarBody2D #the guest's car in a run (CoopRun), null otherwise

## A menu press, before it is read: who the first player is playing on
static func note(event: InputEvent) -> void:
	if event is InputEventKey || event is InputEventMouseButton: lastPad = -1
	elif event is InputEventJoypadButton && not (active && event.device == device) && event.button_index != JOY_BUTTON_START: lastPad = event.device

## Level Options: Start on a controller the first player isn't using joins; the guest's own buttons then pick
## its car (LB/RB or the D-pad), gadget (X) and boost (Y), and B leaves. True when the press was the guest's.
static func menuInput(event: InputEvent) -> bool:
	if not event is InputEventJoypadButton || not event.pressed: return false
	if not active:
		if event.button_index != JOY_BUTTON_START || event.device == lastPad: return false
		join(event.device)
		return true
	if event.device != device: return false
	match event.button_index:
		JOY_BUTTON_B: leave()
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT: stepCar(-1)
		JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT: stepCar(1)
		JOY_BUTTON_X: gadget = nextOf(RunLauncher.slotOptions("loadout"), gadget)
		JOY_BUTTON_Y: boost = nextOf(RunLauncher.slotOptions("boostLoadout"), boost)
	return true

static func join(pad: int) -> void:
	active = true
	device = pad
	if not isOwned(car): stepCar(1)
	claimPads()

static func leave() -> void:
	active = false
	device = -1
	setPadDevice(-1)

## The guest's controller was unplugged since it joined
static func padGone() -> bool:
	return active && not forced && device not in Input.get_connected_joypads()

## Points every pad binding at the first player's controller, so the guest's presses nothing of theirs. Run
## again whenever the bindings may have been rebuilt (a run's start).
static func claimPads() -> void:
	if not active: return
	var mine := lastPad
	if mine < 0 || mine == device:
		mine = NO_PAD
		for pad in Input.get_connected_joypads():
			if pad != device:
				mine = pad
				break
	setPadDevice(mine)

static func setPadDevice(pad: int) -> void:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton || event is InputEventJoypadMotion: event.device = pad

static func isOwned(index: int) -> bool:
	var cars: Array = SaveManager.playerData.cars
	return index >= 0 && index < cars.size() && int(cars[index].cost) == 0 && not (Root.IS_DEMO && index >= Root.DEMO_CAR_COUNT)

## The next car the garage owns
static func stepCar(direction: int) -> void:
	var count: int = SaveManager.playerData.cars.size()
	for i in count:
		car = wrapi(car + direction, 0, count)
		if isOwned(car): return

## The choice after `current` in a slot's options, with none after the last
static func nextOf(options: Array, current: String) -> String:
	var list := [""] + options
	return list[wrapi(list.find(current) + 1, 0, list.size())]

## The guest's side in `mode`: a rival where there are rivals (the Goon Cup), except in a Pursuit, where both
## chase the runner; a friend in every other mode
static func isRival(mode: int) -> bool:
	return active && Modes.hasRivals(mode) && mode != Root.gameModes.PURSUIT

static func runMode() -> int:
	return Root.levelRoot.runMode if is_instance_valid(Root.levelRoot) else Root.gameModes.GOONCRUSHER

## The car a crush, a pickup or a finish by `by` counts for: a friendly guest's go to the player
static func creditTo(by: OverheadCarBody2D) -> OverheadCarBody2D:
	if by.isGuest && not isRival(runMode()) && is_instance_valid(Root.playerCar): return Root.playerCar
	return by

## The car a goon at `from` goes for: the nearer of the two
static func prey(from: Vector2) -> OverheadCarBody2D:
	var player: OverheadCarBody2D = Root.playerCar
	if guest == null || guest.isDestroyed || not is_instance_valid(player): return player
	if player.isDestroyed: return guest
	return guest if from.distance_squared_to(guest.global_position) < from.distance_squared_to(player.global_position) else player

#--- hand testing: `-- --coop` puts a guest in every run without the menu (no second
#pad needed to see the split screen; the guest's car is read from the first pad, or sits still without one);
#`--coop-car=2` picks the guest's car
static var forced := false
static var argsRead := false
static func readArgs() -> void:
	if argsRead: return
	argsRead = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--coop-car="): car = int(arg.get_slice("=", 1)) #the guest's car, an index into the save's
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--coop") || arg.begins_with("--coop-car"): continue
		forced = true
		active = true
		var pads := Input.get_connected_joypads()
		device = pads[0] if not pads.is_empty() else 0
		if not isOwned(car): stepCar(1)
