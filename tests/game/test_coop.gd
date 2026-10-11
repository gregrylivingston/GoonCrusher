extends GameTest

#Local two-player (Coop, CoopRun, PadDriver; docs/MODES.md "Two players"): joining in the menu, whose pad is
#whose, the leash, and whose car a guest's crushes and pickups count for.

var original: PlayerData
var carBefore
var levelBefore
var stubLevel: Level

#a run of `mode`, as far as Coop asks (Coop.runMode)
func runOf(mode: int) -> void:
	if not is_instance_valid(stubLevel): stubLevel = Level.new()
	stubLevel.runMode = mode
	Root.levelRoot = stubLevel

func before_each():
	original = SaveManager.playerData
	SaveManager.playerData = PlayerData.new()
	Coop.lastPad = -1
	carBefore = Root.playerCar
	levelBefore = Root.levelRoot

func after_each():
	Root.playerCar = carBefore if is_instance_valid(carBefore) else null #a test's car is freed with it
	Coop.leave()
	if is_instance_valid(stubLevel): stubLevel.free()
	Root.levelRoot = levelBefore
	Coop.gadget = ""
	Coop.boost = ""
	Coop.car = 0
	Coop.lastPad = -1
	SaveManager.playerData = original
	SaveManager.dirty = false

func press(button: int, pad: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = pad
	event.pressed = true
	return event

func padDevices() -> Array:
	var out := []
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if (event is InputEventJoypadButton || event is InputEventJoypadMotion) && event.device not in out: out.push_back(event.device)
	return out

func test_start_on_another_pad_joins():
	Coop.note(press(JOY_BUTTON_A, 0)) #the first player is on pad 0
	assert_false(Coop.menuInput(press(JOY_BUTTON_START, 0)), "their own Start is still Settings")
	assert_false(Coop.active)
	assert_true(Coop.menuInput(press(JOY_BUTTON_START, 1)), "Start on another pad joins")
	assert_true(Coop.active)
	assert_eq(Coop.device, 1)
	assert_eq(padDevices(), [0], "every pad binding now answers only the first player's pad")
	assert_true(Coop.menuInput(press(JOY_BUTTON_B, 1)), "B leaves")
	assert_false(Coop.active)
	assert_eq(padDevices(), [-1], "and the bindings answer any pad again")

func test_a_keyboard_player_leaves_every_pad_free():
	var key := InputEventKey.new()
	key.pressed = true
	Coop.note(press(JOY_BUTTON_A, 0))
	Coop.note(key)
	assert_true(Coop.menuInput(press(JOY_BUTTON_START, 0)), "after a key press, the only pad can join")
	assert_true(Coop.device not in padDevices(), "and nothing of the first player's answers it")

func test_the_mode_picks_the_side_and_the_guest_a_car_and_a_loadout():
	assert_false(Coop.isRival(Root.gameModes.DERBY), "nobody has joined")
	Coop.join(1)
	assert_true(Coop.isRival(Root.gameModes.DERBY), "a rival in the Goon Cup")
	assert_true(Coop.isRival(Root.gameModes.CANNONBALL))
	assert_false(Coop.isRival(Root.gameModes.PURSUIT), "both chase a Pursuit's runner")
	assert_false(Coop.isRival(Root.gameModes.GOONCRUSHER), "a friend everywhere else")
	assert_false(Coop.isRival(Root.gameModes.RALLY))
	for i in SaveManager.playerData.cars.size() + 1:
		Coop.menuInput(press(JOY_BUTTON_RIGHT_SHOULDER, 1))
		assert_true(Coop.isOwned(Coop.car), "only cars the garage owns")
	Coop.menuInput(press(JOY_BUTTON_X, 1))
	assert_eq(Coop.gadget, RunLauncher.slotOptions("loadout")[0], "X takes the first gadget")
	assert_false(Coop.menuInput(press(JOY_BUTTON_X, 0)), "the first player's pad is not the guest's")

func test_the_leash_is_inside_the_chunks_the_world_keeps():
	assert_true(CoopRun.LEASH.x < WorldGen.CHUNK_PX.x && CoopRun.LEASH.y < WorldGen.CHUNK_PX.y, "less than a chunk each way: the guest stays in the player's 3x3")
	assert_false(CoopRun.beyondLeash(CoopRun.LEASH * 0.9))
	assert_true(CoopRun.beyondLeash(Vector2(CoopRun.LEASH.x + 1.0, 0)))
	assert_true(CoopRun.beyondLeash(Vector2(0, -CoopRun.LEASH.y - 1.0)))

func test_a_friends_crushes_are_the_players():
	var player = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	var guest = load("res://scene/car/sedan/sedan.tscn").instantiate()
	guest.isPlayer = false
	guest.isGuest = true
	add_child_autofree(guest)
	assert_eq(Root.playerCar, player, "the guest's car is never the player's car")
	Coop.join(1)
	assert_eq(Coop.creditTo(guest), player, "a friend's count for the player")
	assert_eq(Coop.creditTo(player), player)
	runOf(Root.gameModes.DERBY)
	assert_eq(Coop.creditTo(guest), guest, "a rival's are its own")

func test_no_prize_games_with_two_players():
	assert_true(Pickups.allowedIn("claw", Root.gameModes.GOONCRUSHER))
	Coop.join(1)
	assert_false(Pickups.allowedIn("claw", Root.gameModes.GOONCRUSHER), "a prize game stops the run for both")
	assert_true(Pickups.allowedIn("fuel", Root.gameModes.GOONCRUSHER))

func test_a_driver_with_keys_steers_all_the_way():
	var driver := CarDriver.new()
	assert_eq(driver.steerAim(), 0.0)
	driver.free()
	var pad := PadDriver.new()
	pad.held = {"TurnLeft": 0.25, "TurnRight": 0.0}
	assert_almost_eq(pad.steerAim(), -0.25, 0.001, "a stick steers part of the way")
	assert_true(pad.isPressed("TurnLeft"))
	assert_true(pad.justPressed("TurnLeft"), "new this tick")
	pad.free()

func test_the_guests_hud_shows_the_guests_car_and_takes_no_pickups():
	var player = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	var guest = load("res://scene/car/taxi/taxi.tscn").instantiate()
	guest.isPlayer = false
	guest.isGuest = true
	add_child_autofree(guest)
	Coop.guest = guest
	var hud: GameUI = load("res://scene/player/playerRoot.tscn").instantiate()
	hud.guest = true
	hud.remove_from_group("playerGameUi")
	hud.get_node("TopCenter/Timer").free() #the run clock needs a level
	add_child(hud)
	await get_tree().process_frame
	var tach = hud.widget("Tach")
	assert_eq(GameUI.carOf(tach), guest, "its widgets read the guest's car")
	assert_eq(HudSkin.of(tach).id, HudSkin.forCar(guest).id, "and wear its dashboard")
	assert_eq(GameUI.carOf(self), player, "anything outside a HUD means the player's")
	assert_true(hud.widget("RightVisor").visible, "the guest has a coin counter of their own")
	assert_false(hud.widget("LeftVisor").visible, "and no gift boxes")
	for group in ["fuelui", "healthui", "coinui", "itemui"]:
		for node in get_tree().get_nodes_in_group(group): assert_false(hud.is_ancestor_of(node), "no pickup flies to the guest's %s" % group)
	hud.setFrame(Rect2(800, 0, 800, 900), 0.5)
	assert_eq(hud.widget("Tach"), tach, "a framed HUD still finds its widgets")
	assert_eq(tach.get_parent(), hud.host)
	assert_eq(hud.host.size, Vector2(1600, 1800), "the frame is laid out at the widgets' own size and scaled down")
	Coop.guest = null
	hud.free()

func test_a_friends_coins_show_on_their_own_counter():
	var player = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	var guest = load("res://scene/car/sedan/sedan.tscn").instantiate()
	guest.isPlayer = false
	guest.isGuest = true
	add_child_autofree(guest)
	Coop.join(1)
	var coin = add_child_autofree(Pickups.make("coin"))
	coin._on_area_2d_body_entered(guest)
	assert_true(player.coin > 0, "a friend's coin is banked by the player")
	assert_eq(guest.coin, player.coin, "and counted on the guest's own visor")
	runOf(Root.gameModes.CANNONBALL)
	var before: int = player.coin
	coin = add_child_autofree(Pickups.make("coin"))
	coin._on_area_2d_body_entered(guest)
	assert_eq(player.coin, before, "a rival keeps what it picks up")
	assert_true(guest.coin > before)

func test_a_tow_carries_the_course_along():
	var player = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	var guest = load("res://scene/car/sedan/sedan.tscn").instantiate()
	guest.isPlayer = false
	add_child_autofree(guest)
	var course: Course = add_child_autofree(Course.new())
	course.progress[guest.get_instance_id()] = [1, 2]
	course.matchProgress(player, guest)
	assert_eq([course.lap, course.next], [1, 2], "a towed player is as far round as the car it was towed to")
	assert_true(course.towed, "and its time is no record")
	course.lap = 2
	course.next = 0
	course.matchProgress(guest, player)
	assert_eq(course.progress[guest.get_instance_id()], [2, 0])

func test_a_wrecked_car_comes_back_to_the_road():
	var car = add_child_autofree(load("res://scene/car/sedan/sedan.tscn").instantiate())
	car.isWrecked = true
	car.isDestroyed = true
	car.health = 0.0
	for system in car.condition: car.setCondition(system, 0.0)
	car.revive()
	assert_false(car.isWrecked || car.isDestroyed, "driving again")
	assert_eq(car.health, car.REVIVE_HEALTH)
	for system in car.condition: assert_eq(car.condition[system], 100.0, "%s patched up" % system)

func test_the_leash_warns_before_it_pulls():
	assert_almost_eq(CoopRun.leashShare(Vector2(CoopRun.LEASH.x * 0.5, 0)), 0.5, 0.001)
	assert_almost_eq(CoopRun.leashShare(Vector2(10, -CoopRun.LEASH.y)), 1.0, 0.001, "the nearer limit counts")
	assert_true(HudChance.LEASH_WARN < 1.0)
