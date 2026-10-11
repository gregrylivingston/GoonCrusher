class_name CoopRun extends Node

## A two-player run (Coop, docs/MODES.md): the guest's car, the right half of the screen for it, and the leash.
## Level adds one once the world is ready when a guest has joined.
##
## The screen: the level's own viewport still draws the whole window for the first player (the HUD, the
## menus and the results stay full width); its camera is shifted so the player's car sits in the middle of the
## left half, and the right half is covered by a second viewport on the same world with a camera on the guest.
## Each half has a HUD of its own (GameUI.setFrame): the player's is laid over the left half and a second one,
## for the guest's car, over the right.
##
## The leash: the world streams round the first player (TileManager keeps rasters for the 3x3 chunks round
## their car), so the two stay within LEASH of each other, less than a chunk each way: the guest is towed back
## to the player, or, in a race between the two, whoever is behind is towed up to the leader (leads).
## Wrecks: a guest that is a rival joins the mode's field (Rivals.cars), and once wrecked is out. With a friend,
## one car still going is enough: whichever is wrecked comes back beside the other after RESPAWN_TICKS, and
## the run is lost when both are down at once (revives). Goonpocalypse is about lasting, so nobody comes back there.

const LEASH := Vector2(4200, 2300)
const RESPAWN_TICKS := 4 * Pickups.TICKS
const VIEW_LAYER := 2    #over the world, under the HUD (GameUI)
const ENGINE_DB := -6.0  #the guest's engine under the player's own
const DIVIDER := 4.0
const HUD_FIT := 0.64    #a HUD's scale on half a screen: the mirror and a visor side by side just fit
const HUD_SCENE := "res://scene/player/playerRoot.tscn"
const NAME := "PLAYER 2"

var level: Level
var car: OverheadCarBody2D  #the guest's; null while it is wrecked
var layer: CanvasLayer
var box: SubViewportContainer
var view: SubViewport
var camera: Camera2D
var divider: ColorRect
var hud: GameUI             #the guest's
var shift := 0.0            #what this has added to the player's camera offset (x), to take back
var respawnIn := 0
var out := false            #the guest is out for the rest of the run
var closed := false         #the split is gone: the run ended, or the guest is out
var loadoutGiven := false
var playerDown := false     #the player's car is wrecked and waiting to come back
var reviveIn := 0
var coins := 0              #the guest's count so far, kept over a wreck (tally)
var crushes := 0
var lastChunk := Vector2i(1 << 20, 0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS #the cameras follow behind the countdown's pause, as the player's does
	level = get_parent()
	Coop.claimPads()
	Input.joy_connection_changed.connect(onPadChanged)
	Audio.radio.trackStarted.connect(onTrackStarted)
	buildView()
	spawn(true)
	buildHud()
	layout()
	followCameras()

func _exit_tree() -> void:
	Coop.guest = null

#--- the guest's car ----------------------------------------------------------------------------

func spawn(atStart := false) -> void:
	var player: OverheadCarBody2D = Root.playerCar
	if not is_instance_valid(player): return
	var entry: Dictionary = SaveManager.playerData.cars[Coop.car if Coop.isOwned(Coop.car) else SaveManager.playerData.selectedCar]
	car = load(entry.scene).instantiate()
	car.isPlayer = false
	car.isGuest = true
	car.fuelFree = true #the pumps are the player's
	car.coin = coins
	car.currentGoonsCrushed = crushes
	var own = car.get_node_or_null("Camera2D") #it still works out the zoom and look-ahead; the view's camera copies it
	if own: own.enabled = false
	#at the start, at the end of the line the rivals are on; later, behind the player
	car.position = spotBeside(player, (level.rivals.cars.size() if level.rivals else 0) + 1 if atStart else 1, 0 if atStart else 1)
	car.rotation = player.rotation
	level.add_child(car)
	var engine = car.get_node_or_null("AudioStream-Engine")
	if engine: engine.volume_db += ENGINE_DB
	var driver := PadDriver.new()
	driver.device = Coop.device
	driver.seat(car)
	if not loadoutGiven:
		loadoutGiven = true
		for id in [Coop.gadget, Coop.boost]:
			if id != "" && Unlocks.isPickupOpen(id): car.giveItem(id)
	car.turnOnHeadlights(player.myLights.visible)
	car.tree_exiting.connect(onCarGone.bind(car))
	Coop.guest = car
	if atStart && Coop.isRival(level.runMode) && level.rivals: #one of the field: the mode's rules place, lap and eliminate it
		level.rivals.cars.push_back(car)
		level.rivals.names[car.get_instance_id()] = NAME
		car.tree_exiting.connect(level.rivals.onRivalGone.bind(car))
	if camera && own:
		camera.position_smoothing_enabled = own.position_smoothing_enabled
		camera.position_smoothing_speed = own.position_smoothing_speed
		camera.global_position = car.global_position
		camera.reset_smoothing()

## Ground a car can stand on beside the player: the `slot`th place of the start line (Rivals.gridSlot), from
## the line `row` back
static func spotBeside(player: OverheadCarBody2D, slot: int, row: int) -> Vector2:
	var forward := Vector2.from_angle(player.rotation)
	for back in range(row, row + 4):
		for n in [slot, slot + 1]:
			var spot := Rivals.gridSlot(n, back, player.global_position, forward)
			if World.spawnableAt(spot): return spot
	return player.global_position - forward * Rivals.LINE_BACK

#the guest's car left the level: wrecked (a non-player's wreck frees it), or the level is going
func onCarGone(gone: Node) -> void:
	if Coop.guest == gone: Coop.guest = null
	if car == gone: car = null
	coins = gone.coin
	crushes = gone.currentGoonsCrushed
	if not is_inside_tree() || level.hasEnded || not gone.get("isWrecked"): return
	if not revives():
		out = true
		close.call_deferred()
	elif playerDown: level.endLevel.call_deferred(false, Root.endCondition.NOHEALTH) #both down at once
	else:
		respawnIn = RESPAWN_TICKS
		TapeBanner.post("%s WRECKED" % NAME, 1.0)

## Does a wrecked car come back while the other is still going: with a friend, except in Goonpocalypse
func revives() -> bool:
	return not Coop.isRival(level.runMode) && Modes.running() != Root.gameModes.GOONPOCALYPSE

## The player's car was wrecked (OverheadCarBody2D.destroy asks before it ends the run): true when the guest
## is still going, and the player comes back beside them
func holdsWreck() -> bool:
	if out || closed || level.hasEnded || not revives() || not is_instance_valid(car) || car.isDestroyed: return false
	playerDown = true
	reviveIn = RESPAWN_TICKS
	TapeBanner.post("PLAYER 1 WRECKED", 1.0)
	return true

func revivePlayer(player: OverheadCarBody2D) -> void:
	playerDown = false
	player.revive()
	tow(player, car, false)
	TapeBanner.post("PLAYER 1 IS BACK", 1.0)

## What the guest has done this run, for the results: {coins, crushes}
func tally() -> Dictionary:
	return {"coins": car.coin, "crushes": car.currentGoonsCrushed} if is_instance_valid(car) else {"coins": coins, "crushes": crushes}

#the guest's controller came unplugged mid-run: the run pauses until it is back
func onPadChanged(device: int, connected: bool) -> void:
	if connected || device != Coop.device || level.hasEnded || Coop.forced: return
	TapeBanner.post("%s: CONTROLLER UNPLUGGED" % NAME, 2.0)
	if is_instance_valid(Root.playerRoot): Root.playerRoot.openPause()

#the radio's song, which the player's left visor (hidden with two players) would have shown
func onTrackStarted(track: Dictionary) -> void:
	var title: String = track.get("title", "")
	if title != "" && not closed: PickupEffects.toast(title, HudTheme.TEXT)

## How much of the leash is used, 0 to 1 and over: the HUD warns as it runs out (HudChance.drawPartner)
static func leashShare(apart: Vector2) -> float:
	return maxf(absf(apart.x) / LEASH.x, absf(apart.y) / LEASH.y)

func _physics_process(_delta: float) -> void:
	if get_tree().paused || level.hasEnded || out: return
	var player: OverheadCarBody2D = Root.playerCar
	if not is_instance_valid(player): return
	if playerDown && is_instance_valid(car):
		reviveIn -= 1
		if reviveIn <= 0: revivePlayer(player)
	if car == null:
		if respawnIn > 0:
			respawnIn -= 1
			if respawnIn == 0:
				spawn()
				TapeBanner.post("%s IS BACK" % NAME, 1.0)
		return
	if car.myLights.visible != player.myLights.visible: car.turnOnHeadlights(player.myLights.visible)
	if beyondLeash(car.global_position - player.global_position):
		if leads(car, player): tow(player, car)
		else: tow(car, player)
		return
	var tiles = level.get_node("TileManager")
	var chunk: Vector2i = tiles.chunkOf(car.global_position)
	if chunk != lastChunk: #the ground and walls under the guest go in now, as they do under the player
		lastChunk = chunk
		tiles.loadChunk(chunk, true)

static func beyondLeash(apart: Vector2) -> bool:
	return absf(apart.x) > LEASH.x || absf(apart.y) > LEASH.y

## In a race between the two (a rival guest), is `a` ahead of `b`: further round the course, or nearer the finish
func leads(a: OverheadCarBody2D, b: OverheadCarBody2D) -> bool:
	if not Coop.isRival(level.runMode): return false
	if level.course && not level.course.points.is_empty(): return level.course.standing(a) > level.course.standing(b)
	if level.runMode == Root.gameModes.CANNONBALL && is_instance_valid(Root.station):
		var finish: Vector2 = Root.station.global_position
		return a.global_position.distance_squared_to(finish) < b.global_position.distance_squared_to(finish)
	return false

## Moves `moved` to just behind `anchor`, at its speed and as far round the course
func tow(moved: OverheadCarBody2D, anchor: OverheadCarBody2D, announce := true) -> void:
	moved.global_position = spotBeside(anchor, 1, 1)
	moved.rotation = anchor.rotation
	moved.velocity = anchor.velocity
	if moved.trailer: moved.trailer.placeBehind()
	if level.course: level.course.matchProgress(moved, anchor)
	if moved == car:
		camera.global_position = car.global_position
		camera.reset_smoothing()
	elif is_instance_valid(moved.camera): moved.camera.reset_smoothing()
	if announce: TapeBanner.post("%s TOWED UP" % (NAME if moved == car else "PLAYER 1"), 1.0)

#the guest's Start pauses the run too (the pause menu itself is the first player's)
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton && event.pressed && event.device == Coop.device && event.button_index == JOY_BUTTON_START:
		if is_instance_valid(Root.playerRoot) && not level.hasEnded: Root.playerRoot.openPause()

#--- the split screen ---------------------------------------------------------------------------

func buildView() -> void:
	layer = CanvasLayer.new()
	layer.layer = VIEW_LAYER
	add_child(layer)
	box = SubViewportContainer.new()
	box.stretch = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view = SubViewport.new()
	view.world_2d = level.get_viewport().find_world_2d()
	view.disable_3d = true
	view.size_2d_override_stretch = true
	view.canvas_item_default_texture_filter = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")
	camera = Camera2D.new()
	view.add_child(camera)
	box.add_child(view)
	layer.add_child(box)
	divider = ColorRect.new()
	divider.color = HudTheme.OUTLINE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(divider)

#the guest's HUD: the same scene as the player's, told whose it is before it enters the tree
func buildHud() -> void:
	hud = load(HUD_SCENE).instantiate()
	hud.guest = true
	hud.view = view
	hud.remove_from_group("playerGameUi")
	hud.get_node("TopCenter/Timer").drives = false
	level.add_child(hud)
	if is_instance_valid(Root.playerRoot): Root.playerRoot.widget("LeftVisor").visible = false #no gift boxes with two players

#the right half of the level's viewport, drawn at that viewport's own pixel density (RunView may have lowered it)
func layout() -> void:
	var host = level.get_viewport()
	var logical: Vector2 = host.get_visible_rect().size
	var half := Vector2(logical.x / 2.0, logical.y)
	var pixels := Vector2i((half * Vector2(host.size) / logical).round()).max(Vector2i.ONE)
	if view.size == pixels && view.size_2d_override == Vector2i(half.round()): return
	view.size = pixels
	view.size_2d_override = Vector2i(half.round())
	box.position = Vector2(half.x, 0)
	box.size = Vector2(pixels)
	box.scale = half / Vector2(pixels)
	divider.position = Vector2(half.x - DIVIDER / 2.0, 0)
	divider.size = Vector2(DIVIDER, half.y)
	if is_instance_valid(Root.playerRoot): Root.playerRoot.setFrame(Rect2(Vector2.ZERO, half), HUD_FIT)
	hud.setFrame(Rect2(Vector2(half.x, 0), half), HUD_FIT)

func _process(_delta: float) -> void:
	if closed: return
	layout()
	followCameras()

#the guest's view copies the zoom and look-ahead its car works out; the player's camera is moved over so
#their car sits in the middle of the left half. Camera2D.offset is shared (the car's look-ahead, CrushFeel,
#Juice.rumble), so this adds only its own change.
func followCameras() -> void:
	if is_instance_valid(car) && is_instance_valid(car.camera):
		camera.global_position = car.global_position
		camera.zoom = car.camera.zoom
		camera.offset = car.camera.offset
	var player: OverheadCarBody2D = Root.playerCar
	if not is_instance_valid(player) || not is_instance_valid(player.camera): return
	var want: float = level.get_viewport().get_visible_rect().size.x / 4.0 / maxf(player.camera.zoom.x, 0.01)
	player.camera.offset.x += want - shift
	shift = want

## Back to one screen: the run ended (the results use the whole window), or the guest is out
func close() -> void:
	if closed: return
	closed = true
	if is_instance_valid(car): car.isDestroyed = true #keys off
	if is_instance_valid(Root.playerCar) && is_instance_valid(Root.playerCar.camera): Root.playerCar.camera.offset.x -= shift
	shift = 0.0
	layer.queue_free()
	hud.queue_free()
	if is_instance_valid(Root.playerRoot):
		Root.playerRoot.setFrame(Rect2())
		Root.playerRoot.widget("LeftVisor").visible = true
