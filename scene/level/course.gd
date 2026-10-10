class_name Course extends Node2D
## A course (docs/MODES.md): the checkpoints or gates of a fixed-map mode
## (Modes.isFixedMap), which the cars must pass in order. The world seed is fixed per level and mode (seedFor,
## TileManager.buildWorld), so the course is the same every run and its times compare. Three shapes use it:
##   a stage     checkpoints along the world's route from the start to the station (setup): Rally Stage, Flat Out.
##               The finish (station.gd) doesn't count until every checkpoint is passed.
##   gates       a layout's own points with a small radius, the last one the finish (ConeCourse)
##   a loop      checkpoints round a route that comes back to the start (loopRoute), driven `laps` times: Hot
##               Lap, Circuit Race, Knockout. Level.lapDone hears every lap, Level.courseDone the last.
## It tracks the player (next, lap, splits, lapTimes) and every rival (Rivals; progress), so a race has places
## (placeOf). Each checkpoint records a split against the driver's best (SaveManager.bestCourse). The HUD points
## at the next one (HudChance) and counts them (HudObjective); the AI driver steers for targetFor(its car).

## Bump when courses change (the seed rule, the checkpoint rule, the generator): records carry it, and a
## record from another version is shown as a time but never compared split by split.
const VERSION := 1
const GAP := 5000.0    #px of route between checkpoints
const RADIUS := 650.0  #the car passes a checkpoint inside this
const LOOP_RADIUS := 5200.0 #a loop's two far corners are this far from the start
const GATE_COLOR := Color(0.35, 0.78, 1.0)
const DONE_COLOR := Color(1, 1, 1, 0.22)

var radius := RADIUS     #Cone Course's gates are far tighter (ConeCourse.PASS_RADIUS)
var finishes := false    #the last checkpoint ends the course (gates and loops: there is no station)
var laps := 1
var gateWord := "CHECKPOINT"
var conesHit := 0        #Cone Course: cones knocked over (Level.coneKnocked)
var points := PackedVector2Array()
var next := 0            #the player's next checkpoint
var lap := 0             #laps the player has finished
var lapStart := 0.0
var lapTimes: Array = [] #seconds of each lap the player has finished
var splits: Array = []   #run-clock seconds at each checkpoint the player passed
var best := {}           #the driver's record here before this run ({} when none)
var progress := {}       #a rival's instance id -> [lap, next]
var lapLength := 0.0     #px round a loop (loopRoute)

## The world seed of a level's course in a mode: the same on every machine and every run
static func seedFor(levelId: StringName, mode: int) -> int:
	var h := 17
	for c in ("%s/%s/%d" % [levelId, Modes.idOf(mode), VERSION]).to_utf8_buffer(): h = (h * 31 + c) & 0x7fffffff
	return h

## Checkpoints every `gap` px along a route, none within half a gap of its end (the finish is the last gate)
static func checkpointsOn(route: PackedVector2Array, gap: float = GAP) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total := 0.0
	for i in range(1, route.size()): total += route[i - 1].distance_to(route[i])
	var along := 0.0
	var due := gap
	for i in range(1, route.size()):
		var step := route[i - 1].distance_to(route[i])
		while step > 0.0 && along + step >= due && due <= total - gap * 0.5:
			out.push_back(route[i - 1].lerp(route[i], (due - along) / step))
			due += gap
		along += step
	return out

## A loop from `start` out to two corners and back, along the world's routes (WorldMap.routeBetween): the first
## heading of a ring of tries whose three legs all connect. {} when none does.
static func loopRoute(map, start: Vector2, reach: float = LOOP_RADIUS) -> Dictionary:
	for i in 12:
		var a := start + Vector2.from_angle(i * TAU / 12.0) * reach
		var b := start + Vector2.from_angle(i * TAU / 12.0 + PI / 3.0) * reach
		var legs := [map.routeBetween(start, a), map.routeBetween(a, b), map.routeBetween(b, start)]
		if legs.any(func(leg): return not leg.reached): continue
		var route := PackedVector2Array()
		var length := 0.0
		for leg in legs:
			route.append_array(leg.points)
			length += leg.length
		return {"route": route, "length": length}
	return {}

func setup(route: PackedVector2Array) -> void:
	setPoints(checkpointsOn(route))

## A loop's checkpoints: the route's, then the start line itself as the last, driven `count` times
func setupLoop(loop: Dictionary, start: Vector2, count: int) -> void:
	var list := checkpointsOn(loop.route, GAP * 0.8)
	list.push_back(start)
	laps = count
	finishes = true
	lapLength = loop.length
	gateWord = "CHECKPOINT"
	setPoints(list)

## The course's points, in order: a route's checkpoints (setup, setupLoop) or a layout's gates (ConeCourse)
func setPoints(list: PackedVector2Array) -> void:
	points = list
	z_index = 1
	var level = Root.levelRoot
	var car = Root.playerCar
	if is_instance_valid(car): best = SaveManager.bestCourse(level.runLevel, level.runMode, car.carId)
	queue_redraw()

func total() -> int:
	return points.size()

## Has the player passed everything (every lap of a loop)
func complete() -> bool:
	return lap >= laps if laps > 1 else next >= points.size()

## The player's next checkpoint, or Vector2.INF once every one is passed (then the station is the goal)
func target() -> Vector2:
	return points[next] if next < points.size() && not complete() else Vector2.INF

## The next checkpoint of any car in the event: the player's, or a rival's own
func targetFor(car: Node) -> Vector2:
	if car == Root.playerCar: return target()
	var at: Array = progress.get(car.get_instance_id(), [0, 0])
	return points[at[1]] if at[0] < laps && at[1] < points.size() else Vector2.INF

## How far round a car is: laps, then checkpoints, then how close it is to its next one
func standing(car: Node) -> float:
	var at: Array = [lap, next] if car == Root.playerCar else progress.get(car.get_instance_id(), [0, 0])
	var toNext: float = car.global_position.distance_to(points[mini(at[1], points.size() - 1)]) if not points.is_empty() else 0.0
	return at[0] * 1000.0 + at[1] - clampf(toNext / 100000.0, 0.0, 0.99)

## A car's place among `cars` (1 is the leader)
func placeOf(car: Node, cars: Array) -> int:
	var mine := standing(car)
	var place := 1
	for other in cars:
		if other != car && is_instance_valid(other) && standing(other) > mine: place += 1
	return place

func bestLap() -> float:
	return lapTimes.min() if not lapTimes.is_empty() else INF

func _physics_process(_delta: float) -> void:
	var car = Root.playerCar
	var level = Root.levelRoot
	if points.is_empty() || not is_instance_valid(level) || level.hasEnded || not level.clockReady: return
	if level.rivals:
		for rival in level.rivals.cars:
			if is_instance_valid(rival) && not rival.isDestroyed: stepRival(rival, level)
	if complete() || not is_instance_valid(car): return
	if car.global_position.distance_squared_to(points[next]) > radius * radius: return
	splits.push_back(level.elapsed)
	next += 1
	if next >= points.size() && laps > 1: #a lap of a loop
		lapTimes.push_back(level.elapsed - lapStart)
		lapStart = level.elapsed
		lap += 1
		if lap < laps: next = 0
		level.lapDone(car, lap)
	if finishes && complete(): level.courseDone(car)
	elif radius >= RADIUS && next > 0: TapeBanner.post("%s %d OF %d%s" % [gateWord, next, points.size(), splitText(splits.size() - 1)], 1.0) #gates come too fast for a banner each
	queue_redraw()

func stepRival(rival: Node, level) -> void:
	var at: Array = progress.get_or_add(rival.get_instance_id(), [0, 0])
	if at[0] >= laps || at[1] >= points.size(): return
	if rival.global_position.distance_squared_to(points[at[1]]) > radius * radius: return
	at[1] += 1
	if at[1] < points.size(): return
	at[0] += 1
	if at[0] < laps: at[1] = 0
	if laps > 1: level.lapDone(rival, at[0])
	if finishes && at[0] >= laps: level.courseDone(rival)

## "  -1.3" or "  +0.8" against the best run's split at checkpoint `i`; "" with no comparable record
func splitText(i: int) -> String:
	var old: Array = best.get("splits", [])
	if int(best.get("version", -1)) != VERSION || i < 0 || i >= old.size() || i >= splits.size(): return ""
	return "  %+.1f" % (splits[i] - float(old[i]))

## "1:23.4"
static func clock(seconds: float) -> String:
	if seconds == INF: return "-"
	var tenths := roundi(maxf(seconds, 0.0) * 10.0)
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]

#a ring on the ground at each checkpoint, with its number of pips; passed ones fade
func _draw() -> void:
	for i in points.size():
		var col := DONE_COLOR if i < next else GATE_COLOR
		if radius < RADIUS: #a gate: a spot between its cones, the next one brighter
			draw_circle(points[i], 16.0 if i == next else 9.0, Color(col, col.a * (1.0 if i == next else 0.5)))
			continue
		draw_arc(points[i], RADIUS, 0.0, TAU, 96, Color(col, col.a * 0.55), 14.0)
		draw_arc(points[i], RADIUS * 0.12, 0.0, TAU, 32, col, 10.0)
		for pip in mini(i + 1, 12):
			draw_circle(points[i] + Vector2((pip - mini(i, 11) * 0.5) * 46.0, -RADIUS * 0.12 - 60.0), 14.0, col)
