class_name AIDriver extends Node2D

#An AI that drives the player car, for automated playtesting (rules: docs/AI_DRIVER.md). It holds
#the same four digital keys a player has, through playerCarController.driver, and by default sees
#only what a player could: the screen by day, the headlight beam at night.
#Every physics tick the controller calls think(), then reads isPressed(). Layers:
#  goal      what to go for: the mode's objective, a pickup, a goon, or a region worth stars
#  route     A* over the terrain map (AIRoute), string-pulled to the farthest waypoint in sight
#  control   candidate key plans are simulated 1 s ahead with the car's own physics
#            (OverheadCarBody2D.integrate), swept against rocks, walls and water; cheapest wins
#  recovery  a car that stops making progress reverses out, and drops the goal it was stuck on

const CONTROLLER = preload("res://scene/player/controller/playerCarController.gd")

const ACCEL = 1
const BRAKE = 2
const LEFT = 4
const RIGHT = 8
enum Throttle { ON, BRAKE, REVERSE }

const SCAN_TICKS = 6      #re-plan 10 times a second
const GOAL_TICKS = 15     #re-pick the goal 4 times a second
const SAMPLE_TICKS = 6    #the simulated path is swept for collisions in 0.1 s segments
const HORIZON_TICKS = 60  #how far ahead plans are simulated (1 s)
const HOLD = 9999         #a steer key held for the whole plan

#forward plans: steer left or right for a tap (0.1 s), a turn (0.3 s) or the whole second, or go straight
const PLANS = [
	{"steer":0, "steerTicks":0, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":6, "throttle":Throttle.ON}, {"steer":1, "steerTicks":6, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":18, "throttle":Throttle.ON}, {"steer":1, "steerTicks":18, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.ON}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.ON},
	{"steer":0, "steerTicks":0, "throttle":Throttle.BRAKE},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.BRAKE}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.BRAKE},
]
#only offered when slow: backing out of a pocket of rocks
const REVERSE_PLANS = [
	{"steer":0, "steerTicks":0, "throttle":Throttle.REVERSE},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.REVERSE}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.REVERSE},
]
const REVERSE_BELOW_SPEED = 150.0

#costs are in seconds of estimated arrival time
const HIT_COST = 6.0          #hitting a rock or wall at 400 px/s; damage grows with speed
const LETHAL_COST = 1000.0    #driving into water
const TURN_COST = 0.6         #per radian the car still has to turn at the end of a plan
const SAME_PLAN_BONUS = 0.08  #keeps the choice from flickering between near-equal plans
const COMMIT_BONUS = 1.3      #the current goal's utility is multiplied by this

const GOAL_RADIUS = {"pickup":70.0, "goon":80.0, "station":300.0, "roam":600.0, "patrol":600.0}
const PURSE_QUANTITY = 10.0   #purse.tscn is a "coin" powerup with this quantity
const ECO_MIN_SPEED = 250.0   #fuel saving never slows the car below this (crushing needs 100)
const FUEL_HOPE = 1.15        #fuel saving assumes about this much more fuel will turn up on the way
const CRUSH_SPEED = 140.0     #below this goons can't be crushed, so they are obstacles, not targets
const GOON_TARGET_PX = 2500.0
const GOON_CLOSE_PX = 500.0
const GOON_AHEAD_ANGLE = 1.1  #radians either side of the nose
const SLOW_GOON_COST = 1.5    #per second spent below CRUSH_SPEED, per goon within SLOW_GOON_PX
const SLOW_GOON_PX = 350.0
const FLANK_COST = 4.0        #per second a goon spends beside the car within FLANK_PX (doubled mid-attack)
const FLANK_PX = 260.0
const BUMPER_CONE = 0.8       #cosine: goons this close to straight ahead meet the bumper
const REVERSE_IF_BLOCKED_SECONDS = 0.4 #reverse plans are tried only when every forward plan hits this soon
const NIGHT_GLOW_PX = 350.0
const HEADLIGHT_REACH_PX = 2000.0
const HEADLIGHT_HALF_ANGLE = 0.45
const FULL_SIGHT_PX = 4000.0
const ROAM_MIN_PX = 6000.0
const STATION_APPROACH_PX = [1100.0, 2000.0] #where the car lines up, out in front of the station's gap
const STUCK_WINDOW = 5        #progress is sampled every 0.5 s over this many samples
const STUCK_PX = 150.0

var car: OverheadCarBody2D
var route: AIRoute
var sight := "human"          #"human" or "full"
var debug := false            #draws the chosen plan, goal and route
var mode: int

var tick := 0
var keys := 0
var plan: Dictionary = PLANS[0]
var planTick := 0
var planPath := PackedVector2Array()
var planHit := false
var speedCap := INF

var goal: Dictionary = {}
var goalTick := 0
var goalEta := 0.0
var blacklist := {}           #goal key -> tick it may be chosen again
var known := {}               #pickup instance id -> node, once seen
var aim := Vector2.INF        #where the car steers this tick: the goal or a route waypoint
var routePoints := PackedVector2Array()
var routeFor := Vector2.INF
var routeTick := -9999
var raceDistance := 0.0       #px left along the route to the station (races)
var roamPoint := Vector2.INF
var roamUntil := 0
var stationApproach: Array = [] #the driveway, then points out in front of the station's gap
var progress: Array[Vector2] = []
var recoverUntil := 0
var stuckTicks := []
var stuckOn := {}             #goal key -> times the car got stuck chasing it

var space: PhysicsDirectSpaceState2D
var query := PhysicsShapeQueryParameters2D.new()
var bodyShape := RectangleShape2D.new()   #the car's footprint with a margin
var startShape := RectangleShape2D.new()  #smaller, so a car touching a rock can still back away
var halfSize := Vector2(80, 40)
var excludes: Array[RID] = []
var lastCosts := PackedStringArray() #every plan's cost at the last choice, for --trace
var nearGoons := PackedVector2Array() #goons near the car, refreshed with every plan choice
var nearGoonsLunging := PackedByteArray() #1 where that goon is winding up or making an attack

#what the run looked like to the driver; the playtest harness reports these
var stats := {"stuck":0, "escapes":0, "eco_seconds":0.0, "route_reached":true, "goals":{}}

#attaches a driver to a car whose _ready has run; options: sight ("human"/"full"), debug (bool)
static func attach(target: OverheadCarBody2D, options: Dictionary = {}) -> AIDriver:
	var driver = AIDriver.new()
	driver.car = target
	driver.sight = options.get("sight", "human")
	driver.debug = options.get("debug", false)
	driver.name = "AIDriver"
	driver.top_level = true #draws in world coordinates
	driver.z_index = 100
	target.add_child(driver)
	target.myController.driver = driver
	return driver

func _ready():
	mode = SaveManager.playerData.gameMode
	var area = car.get_node_or_null("carBodyArea/CollisionShape2D")
	if area && area.shape is RectangleShape2D: halfSize = area.shape.size / 2.0
	bodyShape.size = halfSize * 2.0 + Vector2(20, 24)
	startShape.size = halfSize * 2.0 - Vector2(16, 16)
	query.collision_mask = 1 #rocks, walls and hills (goons are on it too, and are excluded)

func isPressed(action: String) -> bool:
	match action:
		"Accelerate": return (keys & ACCEL) != 0
		"Brake": return (keys & BRAKE) != 0
		"TurnLeft": return (keys & LEFT) != 0
		"TurnRight": return (keys & RIGHT) != 0
	return false

#called by the controller once per physics tick, before it reads the keys
func think() -> void:
	keys = 0
	if not is_instance_valid(Root.levelRoot) || car.isDestroyed || not Root.levelRoot.clockReady: return
	tick += 1
	space = car.get_world_2d().direct_space_state
	if route == null: buildRoute()
	if goal.is_empty() || not goalValid() || tick % GOAL_TICKS == 1: updateGoal()
	aim = aimPoint(goalPosition())
	if tick % SCAN_TICKS == 1 && tick >= recoverUntil: choosePlan()
	checkProgress()
	keys = keysFor(plan, tick - planTick, forwardSpeed(), speedCap)
	if speedCap < INF: stats.eco_seconds += 1.0 / Engine.physics_ticks_per_second
	if debug && tick % SCAN_TICKS == 1: queue_redraw()

func buildRoute() -> void:
	var generator = Root.levelRoot.get_node("TileManager/landscapeGenerator")
	var tileManager = Root.levelRoot.get_node("TileManager")
	route = AIRoute.new(generator.terrainMap, Vector2i(generator.inputSizeX, generator.inputSizeY), tileManager.tilesize)

func forwardSpeed() -> float:
	return car.velocity.dot(car.global_transform.x.normalized())

#--- goals ------------------------------------------------------------------------------------

func goalValid() -> bool:
	if goal.has("node"):
		var node = goal.node
		if not is_instance_valid(node) || node.is_queued_for_deletion(): return false
		if goal.kind == "goon" && node.isDying(): return false
		if goal.kind == "pickup" && not node.visible: return false
	return true

func goalPosition() -> Vector2:
	if goal.has("node") && is_instance_valid(goal.node): return goal.node.global_position
	return goal.get("pos", car.global_position)

#Every option is scored as value / (time to get there + 1); the current goal gets COMMIT_BONUS so
#the car doesn't dither. Sprint only takes detours the clock can afford.
func updateGoal() -> void:
	updateSpeedCap()
	var carPos = car.global_position
	var options: Array = []
	var need = fuelNeed()
	for p in get_tree().get_nodes_in_group("pickup"):
		if not known.has(p.get_instance_id()) && canSee(p.global_position): known[p.get_instance_id()] = p
	for id in known.keys():
		var p = known[id]
		if not is_instance_valid(p) || p.is_queued_for_deletion() || not p.visible || not p.has_node("Area2D"):
			known.erase(id)
			continue
		if AIRoute.isBlocked(route.terrainAt(p.global_position)): continue
		var value = pickupValue(p.powerup, p.quantity, car.fuel, car.health, need)
		options.push_back({"kind":"pickup", "node":p, "value":value, "key":str(id), "type":p.powerup})
	#goons walk to the car anyway: only those ahead, or already close, are worth steering for
	if is_instance_valid(Root.spawnManager) && not protecting():
		var forward = car.global_transform.x.normalized()
		var near: Array = []
		for g in Root.spawnManager.goons:
			if is_instance_valid(g) && not g.isDying() && g.global_position.distance_squared_to(carPos) < GOON_TARGET_PX * GOON_TARGET_PX && canSee(g.global_position):
				near.push_back(g)
		for g in near:
			var offset = g.global_position - carPos
			if offset.length() > GOON_CLOSE_PX && absf(forward.angle_to(offset)) > GOON_AHEAD_ANGLE: continue
			var neighbours = 0
			for other in near:
				if other != g && other.global_position.distance_squared_to(g.global_position) < 350.0 * 350.0: neighbours += 1
			options.push_back({"kind":"goon", "node":g, "value":goonValue(neighbours), "key":str(g.get_instance_id())})

	var objective = objectiveGoal()
	var best = objective
	var bestUtility = objective.value / (etaTo(objective.pos) + 1.0) if not objective.is_empty() else -INF
	if goal.get("key") == objective.get("key"): bestUtility *= COMMIT_BONUS
	var isRace = mode == Root.gameModes.SPRINT || mode == Root.gameModes.MARATHON
	var allowedDetour = detourBudget() if isRace else INF
	for option in options:
		if blacklist.get(option.key, 0) > tick: continue
		var pos = option.node.global_position
		var eta = etaTo(pos)
		if isRace && not objective.is_empty():
			var detour = (carPos.distance_to(pos) + pos.distance_to(aim if aim != Vector2.INF else objective.pos) - carPos.distance_to(aim if aim != Vector2.INF else objective.pos)) / cruiseSpeed()
			if detour > (allowedDetour if option.get("type") != "fuel" || need < 0.3 else allowedDetour * 3.0 + 4.0): continue
		var utility = option.value / (eta + 1.0)
		if option.key == goal.get("key"): utility *= COMMIT_BONUS
		if utility > bestUtility:
			bestUtility = utility
			best = option
	if best.is_empty(): best = {"kind":"roam", "pos":car.global_position + car.global_transform.x * 2000.0, "value":1.0, "key":"roam"}
	if best.get("key") != goal.get("key"):
		goal = best
		goalTick = tick
		goalEta = etaTo(goalPosition())
		var label = goal.get("type", goal.kind)
		stats.goals[label] = stats.goals.get(label, 0) + 1
	elif goal.has("pos") && best.has("pos"):
		goal.pos = best.pos
	#a goal pursued far longer than it should take is probably out of reach
	if goal.kind in ["pickup", "goon"] && tick - goalTick > (maxf(3.0, goalEta * 2.5 + 1.0)) * Engine.physics_ticks_per_second:
		blacklist[goal.key] = tick + 10 * Engine.physics_ticks_per_second
		goal = {}

#the mode's own goal: the station in a race, a region worth stars in survival, the base in Defense
func objectiveGoal() -> Dictionary:
	match mode:
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			if is_instance_valid(Root.station):
				var target = stationTarget()
				raceDistance = car.global_position.distance_to(target)
				if not route.lineIsClear(car.global_position, target, 250.0):
					var result = route.plan(car.global_position, target)
					stats.route_reached = result.reached
					if result.reached: raceDistance = AIRoute.pathLength(result.points) + result.points[result.points.size() - 1].distance_to(target)
				var pressure = clampf(1.0 - raceSlack() / 60.0, 0.0, 1.0)
				return {"kind":"station", "pos":target, "value":40.0 + 160.0 * pressure, "key":"station"}
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station):
				if roamPoint == Vector2.INF || tick > roamUntil || car.global_position.distance_to(roamPoint) < GOAL_RADIUS.patrol:
					roamPoint = Root.station.global_position + Vector2.from_angle(randf() * TAU) * randf_range(600.0, 1800.0)
					roamUntil = tick + 15 * Engine.physics_ticks_per_second
				return {"kind":"patrol", "pos":roamPoint, "value":4.0, "key":"patrol"}
	if roamPoint == Vector2.INF || tick > roamUntil || car.global_position.distance_to(roamPoint) < GOAL_RADIUS.roam:
		roamPoint = pickRoamPoint()
		roamUntil = tick + 30 * Engine.physics_ticks_per_second
	return {"kind":"roam", "pos":roamPoint, "value":4.0, "key":"roam"}

#The station lot is walled with one gap. Like a landing approach: the gap's direction is found once
#(probing outward from the driveway for the most room), and the car aims for the innermost of the
#driveway and two points out in front of the gap that it has a clear, car-wide run to, so it turns
#in lined up instead of sliding along the wall.
func stationTarget() -> Vector2:
	var driveway = Root.station.get_node("driveway/CollisionShape2D").global_position
	if stationApproach.is_empty():
		var best = Vector2.RIGHT
		var bestRoom = -1.0
		for i in 32:
			var direction = Vector2.from_angle(i * TAU / 32.0)
			var hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(driveway, driveway + direction * STATION_APPROACH_PX[0], 1, [car.get_rid()]))
			var room = driveway.distance_to(hit.position) if hit else STATION_APPROACH_PX[0]
			room += direction.dot((car.global_position - driveway).normalized()) * 20.0 #ties: the side facing the car
			if room > bestRoom:
				bestRoom = room
				best = direction
		stationApproach = [driveway]
		for distance in STATION_APPROACH_PX: stationApproach.push_back(driveway + best * distance)
	if car.global_position.distance_to(driveway) < STATION_APPROACH_PX[STATION_APPROACH_PX.size() - 1] * 1.5:
		for point in stationApproach:
			if pathIsClear(car.global_position, point): return point
	return stationApproach[stationApproach.size() - 1]

#can the car's footprint slide straight from a to b without touching a rock or wall
func pathIsClear(a: Vector2, b: Vector2) -> bool:
	if excludes.is_empty(): refreshExcludes()
	return sweep(a, b - a, b - a, false) >= 1.0

#Region stars: a region pays a star for each 60 s spent in it, up to 3 (Region.gd), so stay in a
#region until it has paid out, then head for one that hasn't. Land only, preferably ahead.
func pickRoamPoint() -> Vector2:
	var generator = Root.levelRoot.get_node("TileManager/landscapeGenerator")
	var tileManager = Root.levelRoot.get_node("TileManager")
	var carChunk: Vector2i = tileManager.chunkOf(car.global_position)
	var here = regionOf(generator, carChunk)
	var hereMaxed = isRegionMaxed(here)
	var forward = car.global_transform.x.normalized()
	var best = Vector2.INF
	var bestScore = -INF
	for dy in range(-4, 5):
		for dx in range(-3, 4):
			var chunk = carChunk + Vector2i(dx, dy)
			if chunk == carChunk && not hereMaxed: continue
			var cell = generator.cellAt(chunk.x + generator.inputSizeX / 2, chunk.y + generator.inputSizeY / 2)
			if AIRoute.isBlocked(cell.terrain): continue
			var centre = (Vector2(chunk) + Vector2(0.5, 0.5)) * tileManager.tilesize
			var score = randf()
			if cell.region == here: score += 0.0 if hereMaxed else 3.0
			elif not isRegionMaxed(cell.region): score += 4.0 if hereMaxed else 0.5
			#long straight runs: fresh goons spawn ahead and meet the bumper, the horde stays behind
			if centre.distance_to(car.global_position) < ROAM_MIN_PX: score -= 2.0
			score += 1.5 * forward.dot((centre - car.global_position).normalized())
			if score > bestScore:
				var spot = centre + Vector2(randf_range(-1500, 1500), randf_range(-700, 700))
				if not AIRoute.isBlocked(route.terrainAt(spot)) && route.plan(car.global_position, spot).reached:
					bestScore = score
					best = spot
	return best if best != Vector2.INF else car.global_position + forward * 2000.0

static func regionOf(generator, chunk: Vector2i) -> int:
	return generator.cellAt(chunk.x + generator.inputSizeX / 2, chunk.y + generator.inputSizeY / 2).region

static func isRegionMaxed(region: int) -> bool:
	if region == -2: return true #water and hills pay nothing
	return Region.regions.has(region) && Region.regions[region].get("wave", 1) >= 4

#--- values -----------------------------------------------------------------------------------

#what a pickup is worth now, in rough points (a goon crush is about 12). Fuel and health are
#worth what the car can still hold, more when it is running short.
static func pickupValue(kind: String, quantity: float, fuel: float, health: float, fuelShort: float) -> float:
	match kind:
		"fuel":
			var usable = clampf(100.0 - fuel, 0.0, quantity)
			return 4.0 + usable * (2.0 + 6.0 * fuelShort)
		"health":
			var usable = clampf(100.0 - health, 0.0, quantity)
			return 2.0 + usable * (1.5 + 4.0 * clampf((60.0 - health) / 40.0, 0.0, 1.0))
		"coin": return 60.0 if quantity >= PURSE_QUANTITY else 5.0
		"gem": return 25.0
		"slotmachine": return 50.0
		"engine": return 10.0
	return 7.0 #+1 to another stat

#crushing pays coins only through drops and milestone stars; a pack is worth more than one
static func goonValue(neighbours: int) -> float:
	return 12.0 + 4.0 * mini(neighbours, 6)

#Every crush costs health (the car's own damage(5) on contact), so crushing is paid for out of a
#budget: below the reserve the car stops hunting and steers around goons. Countdown keeps a reserve
#for the time still to survive; the others a flat one.
func protecting() -> bool:
	return car.health < healthReserve()

func healthReserve() -> float:
	match mode:
		Root.gameModes.GOONCRUSHER: return 15.0 + maxf(Root.levelRoot.seconds, 0.0) * 0.08
		Root.gameModes.SPRINT, Root.gameModes.MARATHON: return 20.0
	return 35.0

#0 when the tank will last the run, 1 when the car is about to run dry
func fuelNeed() -> float:
	var burn = fuelPerSecond()
	var low = clampf((50.0 - car.fuel) / 40.0, 0.0, 1.0)
	match mode:
		Root.gameModes.GOONCRUSHER:
			#throttle about 60% of the time on average
			return maxf(low, clampf((Root.levelRoot.seconds * burn * 0.6 - car.fuel) / 60.0, 0.0, 1.0))
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			return maxf(low, clampf((raceDistance / cruiseSpeed() * burn - car.fuel) / 30.0, 0.0, 1.0))
	return low

func fuelPerSecond() -> float:
	return OverheadCarBody2D.fuelBurn(1.0, car.oil) * Engine.physics_ticks_per_second

#Pulse and glide: throttle only below a cruise speed the tank can sustain. Holding speed v takes the
#throttle a share duty(v) = (drag v^2 + friction v) / force of the time, so a slower car burns far
#less per second (Countdown) and per px (races). No cap when a fuel pickup is known.
func updateSpeedCap() -> void:
	speedCap = INF
	if known.values().any(func(p): return is_instance_valid(p) && p.powerup == "fuel"): return
	var burn = fuelPerSecond()
	var cap = INF
	match mode:
		Root.gameModes.GOONCRUSHER:
			cap = sustainableSpeed(car.fuel / maxf(Root.levelRoot.seconds * burn, 0.001) * FUEL_HOPE)
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			if raceDistance > 0.0:
				#fuel per px at speed v is burn (drag v + friction) / force; the clock sets a floor
				var fuelLimited = (car.fuel * FUEL_HOPE * engineForce() / (raceDistance * burn) - car.friction) / car.drag
				var timeLimited = raceDistance / maxf(Root.levelRoot.seconds, 1.0) * 1.15
				cap = maxf(fuelLimited, timeLimited)
		_:
			if car.fuel < 40.0: cap = sustainableSpeed(car.fuel / (120.0 * burn))
	if cap < topSpeed() * 0.95: speedCap = maxf(cap, ECO_MIN_SPEED)

#the speed at which the throttle is needed `duty` of the time (1 = full throttle, top speed)
func sustainableSpeed(duty: float) -> float:
	duty = minf(duty, 1.0)
	return (-car.friction + sqrt(car.friction * car.friction + 4.0 * car.drag * duty * engineForce())) / (2.0 * car.drag)

func engineForce() -> float:
	return (car.engine + 14) * 10 * 2.2

#seconds of clock left over if the car drove the rest of the route now
func raceSlack() -> float:
	return Root.levelRoot.seconds - raceDistance / cruiseSpeed() * 1.1

#how many seconds a race can spend on a detour
func detourBudget() -> float:
	return clampf(raceSlack() * 0.15, 0.0, 8.0)

#the car's top speed on the current ground: engine force against drag and friction
func topSpeed() -> float:
	return sustainableSpeed(1.0)

func cruiseSpeed() -> float:
	return minf(topSpeed() * 0.8, speedCap)

func etaTo(point: Vector2) -> float:
	var offset = point - car.global_position
	var turn = absf(car.global_transform.x.angle_to(offset))
	var eta = offset.length() / maxf(cruiseSpeed(), 250.0) + turn * TURN_COST
	#inside the turning circle the car can't reach it without a loop; chasing it means orbiting
	#it side-on, which is where goons land their attacks
	var radius = turnRadius()
	var side = car.global_transform.x.normalized().orthogonal() * radius
	if point.distance_to(car.global_position + side) < radius * 0.9 || point.distance_to(car.global_position - side) < radius * 0.9:
		eta += TAU * radius / maxf(car.velocity.length(), 250.0)
	return eta

#the tightest circle the car drives at full lock; tyre slip at speed widens it by about a third
func turnRadius() -> float:
	return car.wheel_base / tan(deg_to_rad(8 + car.steering / 4.0)) * 1.3

#--- perception -------------------------------------------------------------------------------

#could a player see this point: on screen by day; in the headlight beam or the car's glow at night
func canSee(point: Vector2) -> bool:
	var offset = point - car.global_position
	if sight == "full": return offset.length() < FULL_SIGHT_PX
	if Root.levelRoot.isDaytime:
		var zoom = car.camera.zoom if is_instance_valid(car.camera) else Vector2.ONE
		var half = car.get_viewport().get_visible_rect().size / zoom / 2.0
		return absf(offset.x) < half.x && absf(offset.y) < half.y
	if offset.length() < NIGHT_GLOW_PX: return true
	var reach = HEADLIGHT_REACH_PX * car.get_node("headlamps/headlights").scale.x
	return offset.length() < reach && absf(car.global_transform.x.angle_to(offset)) < HEADLIGHT_HALF_ANGLE

#goons are on the obstacle layer too. A car fast enough to crush them ignores them in its sweeps;
#a slow one steers around them, since every touch costs health without crushing
func refreshExcludes() -> void:
	excludes = [car.get_rid()]
	nearGoons.clear()
	nearGoonsLunging.clear()
	if not is_instance_valid(Root.spawnManager): return
	var carPos = car.global_position
	var fast = car.velocity.length() >= CRUSH_SPEED && not protecting()
	for g in Root.spawnManager.goons:
		if is_instance_valid(g) && not g.isDying() && g.global_position.distance_squared_to(carPos) < 1800.0 * 1800.0:
			if fast: excludes.push_back(g.get_rid())
			nearGoons.push_back(g.global_position)
			nearGoonsLunging.push_back(1 if g.myMode == Walker.mode.PREPAREATTACK || g.myMode == Walker.mode.ATTACK else 0)

#Goons beside the car's path: close enough to lunge (most goon damage lands this way, on the
#body, even at speed), but not in front of the bumper where they would be crushed.
func flankExposure(point: Vector2, heading: Vector2) -> float:
	var exposure = 0.0
	var forward = heading.normalized()
	for i in nearGoons.size():
		var offset = nearGoons[i] - point
		var distance = offset.length()
		if distance > FLANK_PX || distance < 1.0: continue
		if offset.dot(forward) > BUMPER_CONE * distance: continue #dead ahead: crushed, not lunging
		exposure += 2.0 if nearGoonsLunging[i] else 1.0
	return exposure

#goons within SLOW_GOON_PX of a point
func goonsNear(point: Vector2) -> int:
	var count = 0
	for g in nearGoons:
		if g.distance_squared_to(point) < SLOW_GOON_PX * SLOW_GOON_PX: count += 1
	return count

#--- route ------------------------------------------------------------------------------------

#the goal itself when the straight line to it is on land, otherwise the farthest waypoint of the
#A* route that is
func aimPoint(target: Vector2) -> Vector2:
	var carPos = car.global_position
	if route.lineIsClear(carPos, target, 250.0): return target
	if routeFor.distance_to(target) > 1500.0 || tick - routeTick > 2 * Engine.physics_ticks_per_second || routePoints.is_empty():
		var result = route.plan(carPos, target)
		routePoints = result.points
		if result.reached: routePoints.push_back(target)
		routeFor = target
		routeTick = tick
	if routePoints.size() < 2: return target
	var waypoint = routePoints[1]
	for i in range(2, mini(routePoints.size(), 14)):
		if not route.lineIsClear(carPos, routePoints[i], 250.0): break
		waypoint = routePoints[i]
	return waypoint

#--- control ----------------------------------------------------------------------------------

#the keys a plan holds `t` ticks after it was chosen
static func keysFor(candidate: Dictionary, t: int, speedForward: float, cap: float) -> int:
	var held = 0
	if t < candidate.steerTicks && candidate.steer != 0: held |= LEFT if candidate.steer < 0 else RIGHT
	match candidate.throttle:
		Throttle.ON: if speedForward < cap: held |= ACCEL
		Throttle.BRAKE: if speedForward > 60.0: held |= BRAKE #never so long that it starts reversing
		Throttle.REVERSE: held |= BRAKE
	return held

func choosePlan() -> void:
	refreshExcludes()
	var best = {"cost":INF}
	lastCosts.clear()
	for candidate in PLANS: best = cheaper(best, candidate)
	#reversing is for getting out of a pocket, not for driving: only when everything ahead is blocked
	if best.rollout.get("hitSeconds", INF) < REVERSE_IF_BLOCKED_SECONDS && car.velocity.length() < REVERSE_BELOW_SPEED:
		for candidate in REVERSE_PLANS: best = cheaper(best, candidate)
	if best.plan != plan: planTick = tick
	plan = best.plan
	planPath = best.rollout.path
	planHit = best.rollout.get("hit", false)

func cheaper(best: Dictionary, candidate: Dictionary) -> Dictionary:
	var rollout = simulate(candidate, HORIZON_TICKS)
	var cost = scoreRollout(rollout, aim)
	if candidate == plan: cost -= SAME_PLAN_BONUS
	lastCosts.push_back("%d/%d/%d=%.1f%s" % [candidate.steer, mini(candidate.steerTicks, 99), candidate.throttle, cost, "!" if rollout.get("hit", false) else ""])
	return {"cost":cost, "plan":candidate, "rollout":rollout} if cost < best.cost else best

#Runs a plan through the car's own physics from its current state (collisions ignored; the sweep
#in scoreRollout finds them). Mirrors playerCarController._provide_input for the keys.
func simulate(candidate: Dictionary, ticks: int) -> Dictionary:
	var delta = 1.0 / Engine.physics_ticks_per_second
	var pos = car.global_position
	var forward = car.global_transform.x
	var vel = car.velocity
	var steering = car._car_input.steering
	var gear = car.gear
	var input = OverheadCarBody2D.CarInput.new()
	var path = PackedVector2Array([pos])
	var headings = PackedVector2Array([forward])
	var speeds = PackedFloat32Array([vel.length()])
	for t in ticks:
		var held = keysFor(candidate, t, vel.dot(forward.normalized()), speedCap)
		input.acceleration = 0.0
		input.braking = false
		if held & ACCEL:
			input.acceleration = 1.0
			gear = int(vel.length()) / 300 + 1
		steering = clampf(CONTROLLER.nextSteering(steering, (held & LEFT) != 0, (held & RIGHT) != 0, car.traction), -1.0, 1.0)
		if held & BRAKE:
			if vel.length() < 10 || gear == -1:
				gear = -1
				input.acceleration = -1.0
			else: input.braking = true
		input.steering = steering
		var next = car.integrate(pos, forward, vel, input, delta)
		forward = next[0]
		vel = next[1]
		pos += vel * delta
		if (t + 1) % SAMPLE_TICKS == 0:
			path.push_back(pos)
			headings.push_back(forward)
			speeds.push_back(vel.length())
	return {"path":path, "headings":headings, "speeds":speeds}

#Estimated seconds to the target if the car follows this plan: the plan's own time, plus the rest
#of the way from where it ends, plus the turn still needed; rocks, walls and water add their cost.
func scoreRollout(rollout: Dictionary, target: Vector2) -> float:
	var path: PackedVector2Array = rollout.path
	var headings: PackedVector2Array = rollout.headings
	var speeds: PackedFloat32Array = rollout.speeds
	var segment = float(SAMPLE_TICKS) / Engine.physics_ticks_per_second
	var radius = GOAL_RADIUS.get(goal.get("kind", "roam"), 300.0) if target == goalPosition() else 400.0
	var cost = 0.0
	var last = path.size() - 1
	var endSpeed = speeds[last]
	for i in range(1, path.size()):
		#a car below crush speed among goons is chewed up: each touch costs health and crushes nothing
		if not nearGoons.is_empty():
			cost += FLANK_COST * segment * flankExposure(path[i], headings[i])
			if speeds[i] < CRUSH_SPEED: cost += SLOW_GOON_COST * segment * goonsNear(path[i])
		var ground = footprintTerrain(path[i], headings[i])
		if ground == Root.terrain.WATER:
			rollout.hitSeconds = i * segment
			return LETHAL_COST * (2.0 - float(i) / last)
		var fraction = 0.0 if ground == Root.terrain.HILLS else sweep(path[i - 1], headings[i - 1], path[i] - path[i - 1], i == 1)
		if fraction < 1.0:
			rollout.hit = true
			rollout.hitSeconds = (i - 1 + fraction) * segment
			cost += HIT_COST * (0.4 + speeds[i - 1] / 400.0) * (2.0 - float(i) / last)
			path[i] = path[i - 1].lerp(path[i], fraction) #where it stops
			last = i
			endSpeed = 0.0
			break
		if path[i].distance_to(target) < radius: return cost + i * segment #gets there within the plan
	var end = path[last]
	var toTarget = target - end
	cost += last * segment
	#the rest of the way at cruise speed, plus the time lost getting back up to it: accelerating
	#from v to c at a loses (c - v)^2 / (2 a c) against having been at c all along
	var cruise = maxf(cruiseSpeed(), 150.0)
	cost += toTarget.length() / cruise
	if endSpeed < cruise: cost += (cruise - endSpeed) * (cruise - endSpeed) / (2.0 * engineForce() * cruise)
	cost += absf(headings[last].angle_to(toTarget)) * TURN_COST
	if not rollout.get("hit", false) && endSpeed > 200.0:
		#heading into a wall just past the horizon: the next plan would have to swerve hard
		var hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(end, end + headings[last].normalized() * 400.0, 1, excludes))
		if hit: cost += 0.6 * (1.0 - end.distance_to(hit.position) / 400.0)
	return cost

#how far along `motion` the car's footprint gets before touching a rock or wall (1 = clear)
#The first segment uses a smaller shape and skips the overlap test, so a car already touching a
#rock can still choose to back or steer away from it.
func sweep(from: Vector2, heading: Vector2, motion: Vector2, first: bool) -> float:
	query.shape = startShape if first else bodyShape
	query.transform = Transform2D(heading.angle(), from)
	query.exclude = excludes
	#cast_motion ignores anything the shape already overlaps, so test that first
	query.motion = Vector2.ZERO
	if not first && not space.intersect_shape(query, 1).is_empty(): return 0.0
	query.motion = motion
	var result = space.cast_motion(query)
	return result[0] if result.size() > 0 else 1.0

#water if any corner of the car (plus a margin) is over water, hills if over hills
func footprintTerrain(pos: Vector2, heading: Vector2) -> int:
	var forward = heading.normalized() * (halfSize.x + 40.0)
	var side = heading.normalized().orthogonal() * (halfSize.y + 40.0)
	var worst = Root.terrain.GRASS
	for corner in [pos, pos + forward + side, pos + forward - side, pos - forward + side, pos - forward - side]:
		var type = route.terrainAt(corner)
		if type == Root.terrain.WATER: return type
		if type == Root.terrain.HILLS: worst = type
	return worst

#--- recovery ---------------------------------------------------------------------------------

#Twice a second: a car that has moved less than STUCK_PX in 2.5 s reverses out on the plan with
#the most room, and drops its goal for 10 s. Three times in 20 s and it heads somewhere else.
func checkProgress() -> void:
	if tick % 30 != 0: return
	progress.push_back(car.global_position)
	if progress.size() > STUCK_WINDOW: progress.pop_front()
	if progress.size() < STUCK_WINDOW || progress[0].distance_to(car.global_position) > STUCK_PX: return
	progress.clear()
	stats.stuck += 1
	if goal.has("key") && goal.kind in ["pickup", "goon"]:
		#stuck twice on the same pickup (fuel in a ring of rocks): leave it for good
		stuckOn[goal.key] = stuckOn.get(goal.key, 0) + 1
		blacklist[goal.key] = INF if stuckOn[goal.key] >= 2 else tick + 10 * Engine.physics_ticks_per_second
		goal = {}
	stuckTicks.push_back(tick)
	stuckTicks = stuckTicks.filter(func(t): return tick - t < 20 * Engine.physics_ticks_per_second)
	if stuckTicks.size() >= 3:
		stuckTicks.clear()
		stats.escapes += 1
		roamPoint = car.global_position - car.global_transform.x * 2500.0
		roamUntil = tick + 8 * Engine.physics_ticks_per_second
	refreshExcludes()
	var bestRoom = -INF
	for candidate in REVERSE_PLANS:
		var rollout = simulate(candidate, HORIZON_TICKS)
		var room = 0.0
		for i in range(1, rollout.path.size()):
			var fraction = sweep(rollout.path[i - 1], rollout.headings[i - 1], rollout.path[i] - rollout.path[i - 1], i == 1)
			room += fraction
			if fraction < 1.0: break
		if room > bestRoom:
			bestRoom = room
			plan = candidate
			planPath = rollout.path
	planTick = tick
	recoverUntil = tick + Engine.physics_ticks_per_second

#--- debug ------------------------------------------------------------------------------------

func _draw():
	if not debug: return
	if planPath.size() > 1: draw_polyline(planPath, Color.RED if planHit else Color.LIME, 6.0)
	if routePoints.size() > 1: draw_polyline(routePoints, Color(0.3, 0.6, 1.0, 0.6), 10.0)
	if aim != Vector2.INF: draw_circle(aim, 40.0, Color.CYAN)
	if not goal.is_empty():
		draw_line(car.global_position, goalPosition(), Color.YELLOW, 3.0)
		draw_arc(goalPosition(), GOAL_RADIUS.get(goal.kind, 100.0), 0.0, TAU, 24, Color.YELLOW, 4.0)
