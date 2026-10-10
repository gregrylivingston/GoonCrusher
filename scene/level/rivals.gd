class_name Rivals extends Node
## The Goon Cup's other drivers (docs/MODES.md): the garage's other cars on the map,
## each a real car scene with `isPlayer` off and its own car's AIDriver holding its keys (SKILL by tier). A rival has no camera, HUD,
## rewards or spawners; it doesn't burn fuel or collect pickups, goons ignore it (they hunt Root.playerCar), and
## a wrecked one is simply gone. Cars bump each other (OverheadCarBody2D.bumpCar). Level adds one of these in
## a mode with rivals (Modes.hasRivals) and the mode's rules read it: Cannonball's places are finishOrder.
## Every number is a first guess. AI cost: about 40-140 ms of CPU per game second per driver on the machine that
## measured it (Playtest's ai_ms); not yet measured with five on the low-end target.

const COUNT := 5
#The start line: every car abreast across the way they face, the player in the middle, so nobody starts behind
#anybody. LINE_GAP is the px between cars side by side; a slot in water or a wall moves to a second line
#LINE_BACK px behind (room for the semi and its trailer).
const LINE_GAP := 210.0
const LINE_BACK := 520.0
const ENGINE_DB := -14.0            #a rival's engine under the player's own
## A rival's top pace as a share of the player's car's top speed, by tier: on Easy the field can be outrun,
## on Hard it is as quick as you are (and it has no goons after it and no tank to run dry)
const PACE := [0.0, 0.82, 0.92, 1.02]
## How well a rival works its keys, by tier (AIProfiles.SKILLS): on Easy they react late, misjudge close calls
## and fluff their shifts; on Hard they don't. Each drives its own car's driver and first personality.
const SKILL := ["ace", "rookie", "regular", "ace"]
const PLACE_WORDS := ["", "1ST", "2ND", "3RD", "4TH", "5TH", "6TH", "7TH", "8TH"]

var pace := INF             #the field's pace cap, px/s (the holder of the cup gets a share of it: KeepCup)
var cars: Array = []        #the rivals still driving
var names := {}             #instance id -> driver name, kept after the car is gone
var finishOrder: Array = [] #who has reached the finish, in order: a rival's name, or "" for the player

## The car ids of the rivals: the garage's cars after the player's, in order, so every car turns up as a rival
static func lineup(playerCar: String, count: int) -> Array:
	var ids: Array = SaveManager.playerData.cars.map(func(c): return str(c.name))
	var at := maxi(ids.find(playerCar), 0)
	var out := []
	for i in range(1, ids.size()):
		if out.size() < count: out.push_back(ids[(at + i) % ids.size()])
	return out

## Pursuit's runner: one rival ahead of the player on the way to the station, slower than the player's car and
## easier to wreck than a car of its own (ModeTiers.RUNNER_*)
func spawnRunner() -> void:
	var player = Root.playerCar
	var level = Root.levelRoot
	var tier := ModeTiers.clampTier(level.tier)
	spawn(1, ModeTiers.RUNNER_PACE[tier])
	if cars.is_empty(): return
	var runner: OverheadCarBody2D = cars[0]
	var toward: Vector2 = (Root.station.global_position - player.global_position).normalized() if is_instance_valid(Root.station) else Vector2.from_angle(player.rotation)
	for i in 7: #ahead, on ground a car can stand on
		var at: Vector2 = player.global_position + toward.rotated((i - 3) * 0.25) * ModeTiers.RUNNER_START[tier]
		if World.spawnableAt(at):
			runner.global_position = at
			break
	runner.rotation = toward.angle()
	runner.health = ModeTiers.RUNNER_HEALTH[tier]

## The runner (Pursuit), or null
func runner() -> OverheadCarBody2D:
	return cars[0] if not cars.is_empty() && is_instance_valid(cars[0]) else null

## Where the nth rival starts (1 is the first): beside the player, alternating sides and working outward, on the
## start line (`row` 0) or a line behind it
static func gridSlot(n: int, row: int, origin: Vector2, forward: Vector2) -> Vector2:
	var out := ((n + 1) / 2) * (1.0 if n % 2 == 1 else -1.0)
	return origin + forward.orthogonal() * LINE_GAP * out - forward * LINE_BACK * row

## Lines the rivals up abreast of the player, facing the same way. `share` is their pace as a share of
## the player's car's top speed (PACE by tier when not given).
func spawn(count: int = COUNT, share: float = -1.0) -> void:
	var player = Root.playerCar
	var level = Root.levelRoot
	if not is_instance_valid(player) || not is_instance_valid(level): return
	var forward := Vector2.from_angle(player.rotation)
	var slot := 0
	var probe := AIDriver.new() #the player's car's top speed, the way a driver works it out
	probe.car = player
	pace = probe.topSpeed() * (share if share > 0.0 else PACE[ModeTiers.clampTier(level.tier)])
	probe.free()
	for id in lineup(player.carId, count):
		var entry = SaveManager.playerData.cars.filter(func(c): return str(c.name) == id)
		if entry.is_empty(): continue
		var car: OverheadCarBody2D = load(entry[0].scene).instantiate()
		car.isPlayer = false
		car.fuelFree = true
		var camera = car.get_node_or_null("Camera2D")
		if camera: camera.enabled = false
		slot += 1
		var spot := gridSlot(slot, 0, player.global_position, forward)
		for row in 3: #back a line at a time until it is ground a car can stand on
			spot = gridSlot(slot, row, player.global_position, forward)
			if World.spawnableAt(spot): break
		car.position = spot
		car.rotation = player.rotation
		level.add_child(car)
		var engine = car.get_node_or_null("AudioStream-Engine")
		if engine: engine.volume_db += ENGINE_DB
		AIDriver.attach(car, {"profile": "auto@" + SKILL[ModeTiers.clampTier(level.tier)]}).paceCap = pace
		cars.push_back(car)
		names[car.get_instance_id()] = driverName(car, id)
		car.tree_exiting.connect(onRivalGone.bind(car))

static func driverName(car: Node, id: String) -> String:
	var info = car.get("info")
	return str(info.charName).to_upper() if info && str(info.charName) != "" else id.to_upper()

func onRivalGone(car: Node) -> void:
	cars.erase(car)
	var level = Root.levelRoot
	if car.get("isWrecked") && is_instance_valid(level) && level.is_inside_tree() && not level.hasEnded: level.rivalWrecked.call_deferred(names.get(car.get_instance_id(), ""))

## A rival reached the finish (station.gd): it takes the next place and parks
func rivalFinished(car: Node) -> void:
	var who: String = names.get(car.get_instance_id(), "RIVAL")
	if who in finishOrder: return
	finishOrder.push_back(who)
	car.isDestroyed = true #keys off: it rolls to a stop on the lot
	var level = Root.levelRoot
	if is_instance_valid(level) && not level.hasEnded: TapeBanner.post("%s FINISHES %s" % [who, placeWord(finishOrder.size())], 1.2)

## Knockout: a rival is out. It parks where it is and leaves the field.
func eliminate(car: Node) -> void:
	cars.erase(car)
	car.isDestroyed = true
	TapeBanner.post("%s IS OUT" % names.get(car.get_instance_id(), "RIVAL"), 1.2)

## The place the player would take by finishing now
func nextPlace() -> int:
	return finishOrder.size() + 1

## The player's place in the running: the finished cars, then everyone nearer `target` than the player
func placeBy(target: Vector2) -> int:
	var player = Root.playerCar
	if not is_instance_valid(player): return nextPlace()
	var mine: float = player.global_position.distance_squared_to(target)
	var place := nextPlace()
	for car in cars:
		if is_instance_valid(car) && not car.isDestroyed && car.global_position.distance_squared_to(target) < mine: place += 1
	return place

## Cars in the event, the player included
func field() -> int:
	return names.size() + 1

static func placeWord(place: int) -> String:
	return PLACE_WORDS[place] if place > 0 && place < PLACE_WORDS.size() else "%dTH" % place
