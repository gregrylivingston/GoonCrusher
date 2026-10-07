class_name AIDriver extends Node2D

#An AI that drives the player car, for automated playtesting (rules: docs/AI_DRIVER.md). It holds
#the same four digital keys a player has, through playerCarController.driver, and by default sees
#only what a player could: the screen by day, the headlight beam at night.
#Every physics tick the controller calls think(), then reads isPressed(). Layers:
#  goal      what to go for: the mode's objective, a pickup, a goon, or a region worth stars
#  route     A* over the world's coarse map (AIRoute), string-pulled to the farthest waypoint in sight;
#            near the station, a visibility graph that lines the car up with the lot's gap
#  control   candidate key plans are simulated 0.75 s ahead with the car's own physics, then swept on
#            straight out to lookaheadPx
#            (OverheadCarBody2D.integrate), swept against rocks, walls and water, and charged for
#            time spent slow or side-on among goons; the cheapest wins
#  recovery  a car that stops making progress reverses out and drops the goal it was stuck on;
#            trapped three times, it leaves along its own breadcrumb trail

const CONTROLLER = preload("res://scene/player/controller/playerCarController.gd")

const ACCEL = 1
const BRAKE = 2
const LEFT = 4
const RIGHT = 8
enum Throttle { ON, BRAKE, REVERSE }

const GOAL_TICKS = 15     #re-pick the goal 4 times a second
const SAMPLE_TICKS = 6    #the simulated path is swept for collisions in 0.1 s segments
const HOLD = 9999         #a steer key held for the whole plan

#forward plans: steer left or right for a tap (0.1 s), a turn (0.3 s), a swerve (0.6 s: the usual way
#round a rock) or the whole plan, then straighten; or go straight
const PLANS = [
	{"steer":0, "steerTicks":0, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":6, "throttle":Throttle.ON}, {"steer":1, "steerTicks":6, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":18, "throttle":Throttle.ON}, {"steer":1, "steerTicks":18, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":36, "throttle":Throttle.ON}, {"steer":1, "steerTicks":36, "throttle":Throttle.ON},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.ON}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.ON},
	{"steer":0, "steerTicks":0, "throttle":Throttle.BRAKE},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.BRAKE}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.BRAKE},
]
#offered when the car is nearly stopped, when every forward plan hits something soon, or while escaping
const REVERSE_PLANS = [
	{"steer":0, "steerTicks":0, "throttle":Throttle.REVERSE},
	{"steer":-1, "steerTicks":HOLD, "throttle":Throttle.REVERSE}, {"steer":1, "steerTicks":HOLD, "throttle":Throttle.REVERSE},
]
const REVERSE_BELOW_SPEED = 150.0
const STOPPED_SPEED = 60.0   #below this, reversing is always among the choices (three-point turns)

#costs are in seconds of estimated arrival time; the tunable ones are profile parameters (AIProfiles)
const LETHAL_COST = 1000.0    #driving into water
const SHALLOWS_COST = 0.3     #per second of a plan with a wheel in shallows: slow and slippery, never deadly
const WET_CORNER_SHARE = 0.3  #per second of a plan with a corner (not the centre) over deep water, this share of LETHAL_COST

const GOAL_RADIUS = {"pickup":70.0, "goon":80.0, "station":300.0, "roam":600.0, "patrol":600.0, "escape":300.0}
const PURSE_QUANTITY = 10.0   #purse.tscn is a "coin" powerup with this quantity
const FUEL_NEAR_PX = 3000.0   #a known fuel pickup this close lifts the fuel-saving cap
const CRUSH_SPEED = 140.0     #below this (with a margin over the game's 100) a touch costs health and crushes nothing
const CRUSH_MARGIN = 1.1      #a plan counts on a crush only this far above the goon's crush speed
const SLOW_GOON_PX = 350.0
const FLANK_PX = 260.0
const BUMPER_CONE = 0.8       #cosine: goons this close to straight ahead meet the bumper
const NIGHT_GLOW_PX = 350.0
const HEADLIGHT_REACH_PX = 2000.0
const HEADLIGHT_HALF_ANGLE = 0.45
const FULL_SIGHT_PX = 4000.0
const CAREFUL_ROCK_PX = 450.0  #a pickup with a rock this close is approached slowly...
const CAREFUL_FROM_PX = 1200.0 #...from this far out...
const STATION_INNER_PX = 1100.0 #the station graph: markers this far out in front of the gap...
const STATION_OUTER_PX = 2000.0
const STATION_SIDE_PX = 1400.0  #...corners this far to either side of the gap's line...
const STATION_BACK_PX = 1900.0  #...and this far behind the driveway
const STATION_GRAPH_PX = 6000.0 #the graph is used within this distance of the driveway
const STATION_CONE = 0.6        #radians either side of the gap's line from which the last legs start
const STATION_SLOW_PX = 2500.0  #within this of the driveway the car slows to stationSpeed
const STUCK_WINDOW = 5        #progress is sampled every 0.5 s over this many samples
const STUCK_PX = 150.0
const RECOVER_FORWARD_ROOM = 5.0 #segments (0.1 s each) a forward way out must have before reversing is skipped
const TRAIL_TICKS = 15        #the breadcrumb trail is sampled 4 times a second...
const TRAIL_SAMPLES = 60      #...over the last 15 s
const ESCAPE_BACK_SAMPLES = 24 #an escape heads for the trail at least 6 s back...
const ESCAPE_MIN_PX = 600.0   #...and at least this far away

var car: OverheadCarBody2D
var route: AIRoute
var sight := "human"          #"human" or "full"
var p: Dictionary = AIProfiles.resolve("") #tuning (AIProfiles); read as p.hitCost etc.
var debug := false            #draws the chosen plan, goal and route
var mode: int

var tick := 0
var keys := 0
var plan: Dictionary = PLANS[0]
var planTick := 0
var planPath := PackedVector2Array()
var planHit := false
var speedCap := INF           #fuel saving (updateSpeedCap)
var throttleCap := INF        #what the throttle actually holds to: speedCap, or slower near rocks
var rockyPickups := {}        #pickup instance id -> amongRocks
var wetPickups := {}          #pickup instance id -> too close to deep water to go for (nearWater)
var goalCareful := false      #the goal sits among rocks (fuel in a rock ring): go in slowly

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
var stationPoints: Array = []   #the station graph's points: driveway, inner and outer marker, corners
var stationEdges: Array = []    #distance matrix between them, INF where a wall is in the way
var stationGap := Vector2.RIGHT  #from the driveway out through the gap
var graphStation: Node = null    #the station the graph was built for (Marathon moves on to a new one)
var approachHop := -1           #the station point the car is heading for (for --trace)
var progress: Array[Vector2] = []
var recoverUntil := 0
var stuckTicks := []
var trail := PackedVector2Array() #where the car has been, every TRAIL_TICKS
var escapePoint := Vector2.INF
var escapeUntil := 0
var stuckOn := {}             #goal key -> times the car got stuck chasing it

var space: PhysicsDirectSpaceState2D
var query := PhysicsShapeQueryParameters2D.new()
var bodyShape := RectangleShape2D.new()   #the car's footprint with a margin, for sweeps
var exactShape := RectangleShape2D.new()  #the footprint itself, for overlap tests (tight gaps stay usable)
var startShape := RectangleShape2D.new()  #smaller, so a car touching a rock can still back away
var halfSize := Vector2(80, 40)
var excludes: Array[RID] = []
var lastCosts := PackedStringArray() #every plan's cost at the last choice, for --trace
var nearGoons := PackedVector2Array() #goons near the car, refreshed with every plan choice
var nearGoonsLunging := PackedByteArray() #1 where that goon is winding up or making an attack
var nearGoonsNeed := PackedFloat32Array() #the speed each one takes to crush (INF: can't be crushed now)

#what the run looked like to the driver; the playtest harness reports these
var stats := {"stuck":0, "escapes":0, "eco_seconds":0.0, "route_reached":true, "goals":{}, "think_usec":0}

#attaches a driver to a car whose _ready has run; options: sight ("human"/"full"), debug (bool),
#profile (an AIProfiles spec, such as "crusher" or "default+horizonTicks=120")
static func attach(target: OverheadCarBody2D, options: Dictionary = {}) -> AIDriver:
	var driver = AIDriver.new()
	driver.car = target
	driver.sight = options.get("sight", "human")
	driver.debug = options.get("debug", false)
	driver.p = AIProfiles.resolve(options.get("profile", ""))
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
	exactShape.size = halfSize * 2.0 + Vector2(4, 4)
	startShape.size = halfSize * 2.0 - Vector2(16, 16)
	query.collision_mask = 1 #rocks, walls and hills (goons have their own layer)

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
	var started = Time.get_ticks_usec()
	decide()
	stats.think_usec += Time.get_ticks_usec() - started

func decide() -> void:
	tick += 1
	space = car.get_world_2d().direct_space_state
	if route == null: buildRoute()
	var t0 = Time.get_ticks_usec()
	if goal.is_empty() || not goalValid() || tick % GOAL_TICKS == 1: updateGoal()
	var t1 = Time.get_ticks_usec()
	aim = aimPoint(goalPosition())
	var t2 = Time.get_ticks_usec()
	#a recovery plan runs blind for a second; deep water coming up ends it, so the planner takes over
	if tick < recoverUntil && car.velocity.length() > 50.0 && WorldHooks.lethalAhead(car.global_position, car.velocity.normalized(), car.velocity.length() * 0.8 + 200.0) < INF:
		recoverUntil = tick
	if tick % p.scanTicks == 1 && tick >= recoverUntil: choosePlan()
	var t3 = Time.get_ticks_usec()
	checkProgress()
	var t4 = Time.get_ticks_usec()
	stats.usec_goal = stats.get("usec_goal", 0) + t1 - t0
	stats.usec_aim = stats.get("usec_aim", 0) + t2 - t1
	stats.usec_plan = stats.get("usec_plan", 0) + t3 - t2
	stats.usec_recover = stats.get("usec_recover", 0) + t4 - t3
	if tick % TRAIL_TICKS == 0:
		trail.push_back(car.global_position)
		if trail.size() > TRAIL_SAMPLES: trail.remove_at(0)
	throttleCap = speedCap
	if goalCareful && car.global_position.distance_to(goalPosition()) < CAREFUL_FROM_PX: throttleCap = minf(throttleCap, p.carefulSpeed)
	if goal.get("kind") == "station" && not stationPoints.is_empty() && graphStation == Root.station && car.global_position.distance_to(stationPoints[0]) < STATION_SLOW_PX:
		throttleCap = minf(throttleCap, p.stationSpeed)
	#going for a goon: fast enough to crush it, whatever fuel saving says
	if goal.get("kind") == "goon" && goalValid(): throttleCap = maxf(throttleCap, crushNeed(goal.node) * CRUSH_MARGIN * 1.05)
	#deep water ahead: lift off early (the plans brake or turn; shallows give little grip to do it with)
	var speed := car.velocity.length()
	if speed > p.waterSpeed && WorldHooks.lethalAhead(car.global_position, car.velocity / speed, speed * p.waterLookSeconds * 1.5) < INF:
		throttleCap = minf(throttleCap, p.waterSpeed)
	keys = keysFor(plan, tick - planTick, forwardSpeed(), throttleCap)
	if speedCap < INF: stats.eco_seconds += 1.0 / Engine.physics_ticks_per_second
	if debug && tick % p.scanTicks == 1: queue_redraw()

func buildRoute() -> void:
	route = AIRoute.forWorld(Root.worldMap)

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

#Every option is scored as value / (time to get there + 1); the current goal gets commitBonus so
#the car doesn't dither. Sprint only takes detours the clock can afford.
func updateGoal() -> void:
	updateSpeedCap()
	if tick < escapeUntil:
		if car.global_position.distance_to(escapePoint) > GOAL_RADIUS.escape:
			goal = {"kind":"escape", "pos":escapePoint, "value":1000.0, "key":"escape"}
			return
		escapeUntil = 0
	var carPos = car.global_position
	var options: Array = []
	var need = fuelNeed()
	for pickup in get_tree().get_nodes_in_group("pickup"):
		if not known.has(pickup.get_instance_id()) && canSee(pickup.global_position): known[pickup.get_instance_id()] = pickup
	for id in known.keys():
		var pickup = known[id]
		if not is_instance_valid(pickup) || pickup.is_queued_for_deletion() || not pickup.visible || not pickup.has_node("Area2D"):
			known.erase(id)
			continue
		if AIRoute.isBlocked(route.terrainAt(pickup.global_position)) || wetPickup(pickup): continue
		var value = pickupValue(pickup.powerup, pickup.quantity, car.fuel, car.health, need) * p.pickupScale
		options.push_back({"kind":"pickup", "node":pickup, "value":value, "key":str(id), "type":pickup.powerup})
	#goons only die by being crushed, so crushing is also the defence: every goon left alive joins
	#the horde. Goons inside the turning circle are left to etaTo's loop penalty.
	if is_instance_valid(Root.spawnManager) && not protecting():
		var near: Array = []
		for g in Root.spawnManager.goons:
			if is_instance_valid(g) && not g.isDying() && g.global_position.distance_squared_to(carPos) < p.goonTargetPx * p.goonTargetPx && canSee(g.global_position):
				if p.waterGoonPx > 0.0 && WorldHooks.nearLethal(g.global_position, p.waterGoonPx): continue #lured to the bank: let it swim
				near.push_back(g)
		for g in near:
			var neighbours = 0
			if crushNeed(g) > topSpeed() * 0.95: continue #too tough for this car: leave it be
			for other in near:
				if other != g && other.global_position.distance_squared_to(g.global_position) < 350.0 * 350.0: neighbours += 1
			options.push_back({"kind":"goon", "node":g, "value":goonValue(neighbours, p.goonValue, p.goonPackBonus), "key":str(g.get_instance_id())})

	var objective = objectiveGoal()
	var best = objective
	var bestUtility = objective.value / (etaTo(objective.pos) + 1.0) if not objective.is_empty() else -INF
	if goal.get("key") == objective.get("key"): bestUtility *= p.commitBonus
	var isRace = mode == Root.gameModes.SPRINT || mode == Root.gameModes.MARATHON
	var allowedDetour = detourBudget() if isRace else INF
	for option in options:
		if blacklist.get(option.key, 0) > tick: continue
		var pos = option.node.global_position
		var eta = etaTo(pos)
		if isRace && not objective.is_empty():
			var detour = (carPos.distance_to(pos) + pos.distance_to(aim if aim != Vector2.INF else objective.pos) - carPos.distance_to(aim if aim != Vector2.INF else objective.pos)) / cruiseSpeed()
			if detour > (allowedDetour if option.get("type") != "fuel" || need < 0.3 else allowedDetour * 3.0 + 4.0): continue
		if option.kind == "pickup" && amongRocks(option.node):
			if option.value < p.amongRocksMinValue: continue #a coin is not worth a pocket of rocks
			eta += p.amongRocksSeconds
		var utility = option.value / (eta + 1.0)
		if option.key == goal.get("key"): utility *= p.commitBonus
		if utility > bestUtility:
			bestUtility = utility
			best = option
	if best.is_empty(): best = {"kind":"roam", "pos":car.global_position + car.global_transform.x * 2000.0, "value":1.0, "key":"roam"}
	if best.get("key") != goal.get("key"):
		goal = best
		goalTick = tick
		goalEta = etaTo(goalPosition())
		goalCareful = goal.kind == "pickup" && amongRocks(goal.node)
		var label = goal.get("type", goal.kind)
		stats.goals[label] = stats.goals.get(label, 0) + 1
	elif goal.has("pos") && best.has("pos"):
		goal.pos = best.pos
	#a goal pursued far longer than it should take is probably out of reach
	if goal.kind in ["pickup", "goon"] && tick - goalTick > (maxf(3.0, goalEta * 2.5 + 1.0)) * Engine.physics_ticks_per_second:
		blacklist[goal.key] = tick + 10 * Engine.physics_ticks_per_second
		goal = {}

#Marathon moves the station on (TileManager.placeNextStation): everything worked out for the old one
#(the approach graph, its gap, the hop) is dropped, so the next leg never steers to the old lot's points
func forgetStaleStation() -> void:
	if graphStation == Root.station || stationPoints.is_empty(): return
	stationPoints = []
	stationEdges = []
	stationGap = Vector2.RIGHT
	approachHop = -1
	graphStation = null

#the mode's own goal: the station in a race, a region worth stars in survival, the base in Defense
func objectiveGoal() -> Dictionary:
	forgetStaleStation()
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
					for attempt in 8: #a patrol point on dry land, clear of the water's edge
						roamPoint = Root.station.global_position + Vector2.from_angle(randf() * TAU) * randf_range(600.0, 1800.0)
						if not nearWater(roamPoint): break
					roamUntil = tick + 15 * Engine.physics_ticks_per_second
				return {"kind":"patrol", "pos":roamPoint, "value":4.0, "key":"patrol"}
	if roamPoint == Vector2.INF || tick > roamUntil || car.global_position.distance_to(roamPoint) < GOAL_RADIUS.roam:
		roamPoint = pickRoamPoint()
		roamUntil = tick + 30 * Engine.physics_ticks_per_second
	return {"kind":"roam", "pos":roamPoint, "value":4.0, "key":"roam"}

#The station lot is walled with one gap. Around it the car keeps a small visibility graph: the
#driveway, two markers out in front of the gap (found once by probing outward from the driveway
#for the most room) and four corners clear of the lot, joined wherever a car-wide sweep is clear of
#walls. The inner marker and the driveway can only be entered from within STATION_CONE of the gap's
#line, so the last leg is always a straight run in. The car steers for the first point on the
#shortest way through that graph, so from any side it drives round the lot and turns in lined up,
#instead of pushing into a wall or reaching the gap side-on at full speed.
func stationTarget() -> Vector2:
	var driveway = Root.station.get_node("driveway/CollisionShape2D").global_position
	var carPos = car.global_position
	if carPos.distance_to(driveway) > STATION_GRAPH_PX: return driveway #far off: the route handles it
	forgetStaleStation()
	if stationPoints.is_empty():
		graphStation = Root.station
		buildStationGraph(driveway)
	var carEdges = PackedFloat32Array()
	for i in stationPoints.size():
		carEdges.push_back(carPos.distance_to(stationPoints[i]) if stationEdgeAllowed(carPos, i) && linedUpFor(i) && clearOfWalls(carPos, stationPoints[i]) else INF)
	var hop = firstHop(stationPoints, stationEdges, carEdges)
	approachHop = hop
	return stationPoints[hop] if hop >= 0 else stationPoints[2]

func buildStationGraph(driveway: Vector2) -> void:
	var gap = Vector2.RIGHT
	var bestRoom = -1.0
	for i in 32:
		var direction = Vector2.from_angle(i * TAU / 32.0)
		var hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(driveway, driveway + direction * STATION_INNER_PX, 1, [car.get_rid()]))
		var room = driveway.distance_to(hit.position) if hit else STATION_INNER_PX
		room += direction.dot((car.global_position - driveway).normalized()) * 20.0 #ties: the side facing the car
		if room > bestRoom:
			bestRoom = room
			gap = direction
	stationGap = gap
	var side = gap.orthogonal() * STATION_SIDE_PX
	stationPoints = [driveway, driveway + gap * STATION_INNER_PX, driveway + gap * STATION_OUTER_PX,
		driveway + gap * STATION_INNER_PX + side, driveway + gap * STATION_INNER_PX - side,
		driveway - gap * STATION_BACK_PX + side, driveway - gap * STATION_BACK_PX - side]
	stationEdges = []
	for i in stationPoints.size():
		var row = PackedFloat32Array()
		for j in stationPoints.size():
			var open = i != j && stationEdgeAllowed(stationPoints[i], j) && clearOfWalls(stationPoints[i], stationPoints[j])
			row.push_back(stationPoints[i].distance_to(stationPoints[j]) if open else INF)
		stationEdges.push_back(row)

#The last legs (to the inner marker and the driveway) also need the car heading in along the gap's line,
#or slow enough to turn in: a car crossing the line side-on at 450 px/s overshoots the gap by a turning
#circle and loops round the lot again (phase-3 sprints lost 30-40 s that way). Otherwise it goes on to the
#outer marker (or a corner), turns there and comes in lined up.
const STATION_ALIGN = 1.0        #radians between the heading and the way in (-stationGap) for a last leg at speed
const STATION_TURN_SPEED = 300.0 #below this any heading will do
func linedUpFor(point: int) -> bool:
	if point > 1 || car.velocity.length() < STATION_TURN_SPEED: return true
	return absf(car.global_transform.x.angle_to(-stationGap)) < STATION_ALIGN

#the driveway (0) and the inner marker (1) are entered only from the gap's line
func stationEdgeAllowed(from: Vector2, to: int) -> bool:
	if to > 1: return true
	var offset = from - stationPoints[0]
	return offset.length() < 1.0 || absf(stationGap.angle_to(offset)) < STATION_CONE

#Dijkstra from the car (carEdges: its distance to each point, INF where blocked) to point 0, over
#`edges` (a distance matrix, INF where blocked). Returns the first point on the way, -1 if none.
static func firstHop(points: Array, edges: Array, carEdges: PackedFloat32Array) -> int:
	var count = points.size()
	var best = PackedFloat32Array()
	var via = PackedInt32Array() #the first hop on the best way to each point
	var done = []
	for i in count:
		best.push_back(carEdges[i])
		via.push_back(i if carEdges[i] < INF else -1)
		done.push_back(false)
	for _step in count:
		var next = -1
		for i in count:
			if not done[i] && best[i] < INF && (next < 0 || best[i] < best[next]): next = i
		if next < 0: break
		if next == 0: return via[0]
		done[next] = true
		for j in count:
			if not done[j] && edges[next][j] < INF && best[next] + edges[next][j] < best[j]:
				best[j] = best[next] + edges[next][j]
				via[j] = via[next]
	return via[0]

#can a car-wide footprint slide from a to b without touching a rock or wall (goons are ignored:
#they move, and the planner deals with them)
func clearOfWalls(a: Vector2, b: Vector2) -> bool:
	var keep = excludes
	excludes = [car.get_rid()]
	if is_instance_valid(Root.spawnManager):
		for g in Root.spawnManager.goons:
			if is_instance_valid(g): excludes.push_back(g.get_rid())
	var clear = sweep(a, b - a, b - a, false) >= 1.0
	excludes = keep
	return clear

#a pickup with rocks around it (fuel in a rock ring) is slow and risky to collect; rocks don't
#move, so the answer is kept per pickup
func amongRocks(pickup: Node) -> bool:
	var id = pickup.get_instance_id()
	if not rockyPickups.has(id): rockyPickups[id] = rocksNear(pickup.global_position, CAREFUL_ROCK_PX)
	return rockyPickups[id]

#is there a rock or wall within `radius` of a point
func rocksNear(point: Vector2, radius: float) -> bool:
	var circle = CircleShape2D.new()
	circle.radius = radius
	var around = PhysicsShapeQueryParameters2D.new()
	around.shape = circle
	around.transform = Transform2D(0.0, point)
	around.collision_mask = 1
	around.exclude = [car.get_rid()]
	for hit in space.intersect_shape(around, 8):
		#a fence or hedge is smashed on the way in (carefulSpeed is too slow for some: then the planner treats it as a wall)
		if World.isWall(hit.collider) && not (BreakableProp.isBreakable(hit.collider) && not hit.collider.get_meta(&"explosive", false)): return true
	return false

#Region stars: a region (a district of the world map) pays a star for each 60 s spent in it, up to 3
#(Region.gd), so stay in a district until it has paid out, then head for one that hasn't. Passable,
#reachable coarse cells only, preferably ahead.
const ROAM_CELLS := Vector2i(16, 12) #how far the candidates reach, in coarse cells (20,480 x 15,360 px)
const ROAM_STEP := 3
func pickRoamPoint() -> Vector2:
	var map: WorldMap = Root.worldMap
	var carCell: Vector2i = map.coarseCell(car.global_position)
	var here := map.districtOfCell(carCell)
	var hereMaxed = isRegionMaxed(here)
	var forward = car.global_transform.x.normalized()
	var best = Vector2.INF
	var bestScore = -INF
	for dy in range(-ROAM_CELLS.y, ROAM_CELLS.y + 1, ROAM_STEP):
		for dx in range(-ROAM_CELLS.x, ROAM_CELLS.x + 1, ROAM_STEP):
			var cell = carCell + Vector2i(dx, dy)
			if (dx == 0 && dy == 0) || not map.cellReachable(cell): continue
			var district := map.districtOfCell(cell)
			if district == here && not hereMaxed && absi(dx) + absi(dy) <= ROAM_STEP: continue
			var centre = WorldGen.cellCentre(cell)
			var score = randf()
			if district == here: score += 0.0 if hereMaxed else 3.0
			elif not isRegionMaxed(district): score += 4.0 if hereMaxed else 0.5
			#long straight runs: fresh goons spawn ahead and meet the bumper, the horde stays behind
			if centre.distance_to(car.global_position) < p.roamMinPx: score -= 2.0
			score += 1.5 * forward.dot((centre - car.global_position).normalized())
			if score > bestScore:
				var spot = centre + Vector2(randf_range(-400, 400), randf_range(-400, 400))
				if not AIRoute.isBlocked(route.terrainAt(spot)) && not nearWater(spot) && route.plan(car.global_position, spot).reached:
					bestScore = score
					best = spot
	return best if best != Vector2.INF else car.global_position + forward * 2000.0

#too close to deep water to drive to at speed: within waterTargetPx of a lethal cell, unless on a bridge deck
func nearWater(point: Vector2) -> bool:
	return route.terrainAt(point) != Root.terrain.BRIDGE && WorldHooks.nearLethal(point, p.waterTargetPx)

#pickups don't move, so the answer is kept per pickup
func wetPickup(pickup: Node) -> bool:
	var id = pickup.get_instance_id()
	if not wetPickups.has(id): wetPickups[id] = nearWater(pickup.global_position)
	return wetPickups[id]

static func isRegionMaxed(region: int) -> bool:
	if region < 0: return true #barriers pay nothing
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
	if Pickups.DATA.has(kind) && Pickups.DATA[kind].has("ai"): return Pickups.DATA[kind]["ai"] #docs/PICKUPS.md
	return 7.0 #+1 to another stat

#crushing pays coins only through drops and milestone stars; a pack is worth more than one
static func goonValue(neighbours: int, base := 12.0, pack := 4.0) -> float:
	return base + pack * mini(neighbours, 6)

#Every crush costs health (the car's own damage(5) on contact), so crushing is paid for out of a
#budget: below the reserve the car stops hunting and steers around goons. Countdown keeps a reserve
#for the time still to survive; the others a flat one.
func protecting() -> bool:
	return car.health < healthReserve()

func healthReserve() -> float:
	match mode:
		Root.gameModes.GOONCRUSHER: return p.reserveBase + maxf(Root.levelRoot.seconds, 0.0) * p.reservePerSecond
		Root.gameModes.SPRINT, Root.gameModes.MARATHON: return p.reserveBase + 10.0
	return p.reserveBase + 15.0

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
#less per second (Countdown) and per px (races). No cap while a fuel pickup is close by and not
#given up on; one seen far away doesn't count, or the car would burn its tank getting there.
func updateSpeedCap() -> void:
	speedCap = INF
	if known.values().any(func(pickup): return is_instance_valid(pickup) && pickup.powerup == "fuel" && blacklist.get(str(pickup.get_instance_id()), 0) <= tick && pickup.global_position.distance_to(car.global_position) < FUEL_NEAR_PX): return
	var burn = fuelPerSecond()
	var cap = INF
	match mode:
		Root.gameModes.GOONCRUSHER:
			cap = sustainableSpeed(car.fuel / maxf(Root.levelRoot.seconds * burn, 0.001) * p.fuelHope)
		Root.gameModes.SPRINT, Root.gameModes.MARATHON:
			if raceDistance > 0.0:
				#fuel per px at speed v is burn (drag v + friction) / force; the clock sets a floor
				var fuelLimited = (car.fuel * p.fuelHope * engineForce() / (raceDistance * burn) - car.friction) / car.drag
				var timeLimited = raceDistance / maxf(Root.levelRoot.seconds, 1.0) * 1.15
				cap = maxf(fuelLimited, timeLimited)
		_:
			if car.fuel < 40.0: cap = sustainableSpeed(car.fuel / (120.0 * burn))
	if cap < topSpeed() * 0.95: speedCap = maxf(cap, p.ecoMinSpeed)

#the speed at which the throttle is needed `duty` of the time (1 = full throttle, top speed)
func sustainableSpeed(duty: float) -> float:
	duty = minf(duty, 1.0)
	return (-car.friction + sqrt(car.friction * car.friction + 4.0 * car.drag * duty * engineForce())) / (2.0 * car.drag)

func engineForce() -> float:
	return (car.engine + 14) * 10 * 2.2

#seconds of clock left over if the car drove the rest of the route now. The route (coarse A*) is shorter
#than the drive, so it is stretched the way the clock was (Level.driveLengthFor: the grammar's factor, plus
#the lot approach while the car is still out of the station graph's reach)
func raceSlack() -> float:
	var level = Root.levelRoot
	var drive = raceDistance
	if level.has_method("driveLength"):
		drive = level.driveLength(raceDistance) if raceDistance > STATION_GRAPH_PX else raceDistance * Level.ROUTE_FACTOR_DEFAULT
	return level.seconds - drive / cruiseSpeed() * 1.1

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
	var eta = offset.length() / maxf(cruiseSpeed(), 250.0) + turn * p.turnCost
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

#Goons are on the obstacle layer too. The sweeps ignore them (they are targets: a slow car should
#floor it through, crush speed takes a third of a second, and scoreRollout charges for time spent
#slow among them), except in protect mode, when the car steers around them like rocks.
func refreshExcludes() -> void:
	excludes = [car.get_rid()]
	nearGoons.clear()
	nearGoonsLunging.clear()
	nearGoonsNeed.clear()
	if not is_instance_valid(Root.spawnManager): return
	var carPos = car.global_position
	var crushing = not protecting()
	var reachable = topSpeed() * 0.95
	for g in Root.spawnManager.goons:
		if is_instance_valid(g) && not g.isDying() && g.global_position.distance_squared_to(carPos) < 1800.0 * 1800.0:
			var need = crushNeed(g)
			#one the car can't get fast enough to crush is a wall that hits back (it bounces the car)
			if crushing && need <= reachable: excludes.push_back(g.get_rid())
			nearGoons.push_back(g.global_position)
			nearGoonsLunging.push_back(1 if g.myMode == Walker.mode.PREPAREATTACK || g.myMode == Walker.mode.ATTACK else 0)
			nearGoonsNeed.push_back(need)

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
	var ticks = horizonTicks()
	for candidate in PLANS: best = cheaper(best, candidate, ticks)
	#backing up is fine, just not the first choice (reverseCost): it is weighed whenever the car is
	#nearly stopped, or slow with everything ahead blocked soon
	var speed = car.velocity.length()
	var blocked = best.rollout.get("hitSeconds", INF) < p.reverseIfBlocked && speed < REVERSE_BELOW_SPEED
	if blocked || (p.reverseWhenStopped && speed < STOPPED_SPEED) || tick < escapeUntil:
		for candidate in REVERSE_PLANS: best = cheaper(best, candidate, ticks)
	if best.plan != plan: planTick = tick
	plan = best.plan
	planPath = best.rollout.path
	planHit = best.rollout.get("hit", false)

#how far ahead plans are simulated: at least p.horizonTicks, and long enough to cover lookaheadPx at
#the current speed (a fast car needs the room to brake or swerve), up to maxHorizonTicks
func horizonTicks() -> int:
	var ticks = p.lookaheadPx / maxf(car.velocity.length(), 1.0) * Engine.physics_ticks_per_second
	return int(clampf(ticks, p.horizonTicks, maxf(p.maxHorizonTicks, p.horizonTicks)))

func cheaper(best: Dictionary, candidate: Dictionary, ticks: int) -> Dictionary:
	var t0 = Time.get_ticks_usec()
	var rollout = simulate(candidate, ticks)
	var t1 = Time.get_ticks_usec()
	var cost = scoreRollout(rollout, aim)
	stats.usec_sim = stats.get("usec_sim", 0) + t1 - t0
	stats.usec_score = stats.get("usec_score", 0) + Time.get_ticks_usec() - t1
	if candidate == plan: cost -= p.samePlanBonus
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
	var forwards = PackedFloat32Array([vel.dot(forward.normalized())]) #signed: negative when rolling backwards
	for t in ticks:
		var held = keysFor(candidate, t, vel.dot(forward.normalized()), throttleCap)
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
			forwards.push_back(vel.dot(forward.normalized()))
	return {"path":path, "headings":headings, "speeds":speeds, "forwards":forwards}

#Estimated seconds to the target if the car follows this plan: the plan's own time, plus the rest
#of the way from where it ends, plus the turn still needed; rocks, walls and water add their cost.
func scoreRollout(rollout: Dictionary, target: Vector2) -> float:
	var path: PackedVector2Array = rollout.path
	var headings: PackedVector2Array = rollout.headings
	var speeds: PackedFloat32Array = rollout.speeds
	var forwards: PackedFloat32Array = rollout.forwards
	var crushing = p.crushReward > 0.0 && not nearGoons.is_empty() && not protecting()
	var met = {} #goons this plan meets with the bumper, counted once
	var segment = float(SAMPLE_TICKS) / Engine.physics_ticks_per_second
	var radius = GOAL_RADIUS.get(goal.get("kind", "roam"), 300.0) if target == goalPosition() else 400.0
	var cost = 0.0
	var last = path.size() - 1
	var endSpeed = speeds[last]
	for i in range(1, path.size()):
		#forwards is how the game is played: rolling backwards costs, whatever it gains
		if forwards[i] < -20.0: cost += p.reverseCost * segment
		if crushing && speeds[i] >= CRUSH_SPEED: bumperGoons(path[i], headings[i], speeds[i], met)
		#goons beside the path lunge at the body; a car below crush speed among them is chewed up
		if not nearGoons.is_empty():
			cost += p.flankCost * segment * flankExposure(path[i], headings[i])
			if speeds[i] < CRUSH_SPEED: cost += p.slowGoonCost * segment * goonsNear(path[i])
		var ground = footprintTerrain(path[i], headings[i])
		if World.isLethal(ground):
			#the car dies once its centre is over deep water: that ends the plan. A corner over it (the
			#footprint has a margin) is a near miss: very dear, but a plan that keeps the centre out still
			#beats one that doesn't when every choice is wet (a car already on the edge)
			if World.lethalAt(path[i]) || World.lethalAt(path[i].lerp(path[i - 1], 0.5)):
				rollout.hitSeconds = i * segment
				return LETHAL_COST * (2.0 - float(i) / last)
			cost += LETHAL_COST * WET_CORNER_SHARE * segment
		if ground == Root.terrain.SHALLOWS: cost += SHALLOWS_COST * segment
		cost += waterAheadCost(path[i - 1], path[i], speeds[i]) * segment
		sweepSmashes = 0
		var fraction = 0.0 if World.isWallTerrain(ground) else sweep(path[i - 1], headings[i - 1], path[i] - path[i - 1], i == 1, minf(speeds[i - 1], speeds[i]))
		cost += p.smashCost * sweepSmashes #through a fence or hedge at speed: a little slower, never a wall hit
		if fraction < 1.0:
			rollout.hit = true
			rollout.hitSeconds = (i - 1 + fraction) * segment
			cost += p.hitCost * (0.4 + speeds[i - 1] / 400.0) * (2.0 - float(i) / last)
			path[i] = path[i - 1].lerp(path[i], fraction) #where it stops
			last = i
			endSpeed = 0.0
			break
		if path[i].distance_to(target) < radius: return cost + i * segment + metCost(met) #gets there within the plan
	var end = path[last]
	var toTarget = target - end
	cost += last * segment
	#the rest of the way at cruise speed, plus the time lost getting back up to it: accelerating
	#from v to c at a loses (c - v)^2 / (2 a c) against having been at c all along
	var cruise = maxf(cruiseSpeed(), 150.0)
	cost += toTarget.length() / cruise
	if endSpeed < cruise: cost += (cruise - endSpeed) * (cruise - endSpeed) / (2.0 * engineForce() * cruise)
	cost += absf(headings[last].angle_to(toTarget)) * p.turnCost
	if not rollout.get("hit", false) && endSpeed > 200.0:
		#Looking further than the plan, cheaply: a car-wide straight sweep from where it ends, along
		#where it ends up pointing, out to lookaheadPx from the start (or probeSeconds of travel at the
		#end speed, if that is further). A wall there means the next plans must swerve or brake hard,
		#so plans already steering clear of it win, well before the car gets close.
		var travelled = path[0].distance_to(end)
		var reach = maxf(400.0, maxf(p.lookaheadPx - travelled, endSpeed * p.probeSeconds))
		var heading = headings[last].normalized()
		var clear = sweep(end, heading, heading * reach, false, endSpeed)
		if clear < 1.0: cost += p.probeCost * (1.0 - clear)
		var wet = WorldHooks.lethalAhead(end, heading, reach) #deep water counts like a wall there, only more so
		if wet < INF: cost += p.probeCost * 2.0 * (1.0 - wet / (reach + WorldHooks.FINE))
	return cost + metCost(met)

#Deep water along the direction of travel within waterLookSeconds of a point of a plan: the closer and the
#faster, the more it costs per second of the plan, so plans that turn away or brake early win long before
#the footprint would touch it (by then, at 700 px/s on shallows, it is too late to stop)
func waterAheadCost(from: Vector2, to: Vector2, speed: float) -> float:
	if speed < 100.0 || p.waterNearCost <= 0.0: return 0.0
	var motion = to - from
	if motion.length_squared() < 1.0: return 0.0
	var reach = speed * p.waterLookSeconds
	var wet = WorldHooks.lethalAhead(to, motion.normalized(), reach)
	if wet == INF: return 0.0
	return p.waterNearCost * (1.0 - wet / (reach + WorldHooks.FINE)) * speed / 400.0

#a crush takes crushReward off a plan; bouncing off a goon too tough to crush costs like a light wall hit
func metCost(met: Dictionary) -> float:
	if met.is_empty(): return 0.0
	var counts = countMet(met)
	return -p.crushReward * counts.x + p.hitCost * 0.5 * counts.y

#Goons in front of the bumper at a point of a plan, added to `met` (by index into nearGoons): true
#if the car is fast enough to crush that one (Walker.tryCrush), false if it would bounce off.
func bumperGoons(point: Vector2, heading: Vector2, speed: float, met: Dictionary) -> void:
	var forward = heading.normalized()
	for i in nearGoons.size():
		if met.has(i): continue
		var offset = nearGoons[i] - point
		var along = offset.dot(forward)
		if along > halfSize.x * 0.3 && along < halfSize.x + 60.0 && absf(offset.cross(forward)) < halfSize.y + 10.0:
			met[i] = speed >= nearGoonsNeed[i] * CRUSH_MARGIN

#the speed a goon takes to crush now: its crush speed, or its front armor while that is up (the
#car meets it head-on, so assume it faces the car); INF while invulnerable
static func crushNeed(goon: Node) -> float:
	if goon.get("invulnerable"): return INF
	var need = float(goon.get("crushSpeed")) if goon.get("crushSpeed") != null else 100.0
	var armor = goon.get("frontArmor")
	if armor != null && armor > 0.0 && goon.get("verb") != null && goon.verb.frontArmorActive(): need = maxf(need, armor)
	return need

#crushes and bounces in a plan's `met`
static func countMet(met: Dictionary) -> Vector2i:
	var crushed = 0
	for i in met:
		if met[i]: crushed += 1
	return Vector2i(crushed, met.size() - crushed)

#how far along `motion` the car's footprint gets before touching a rock or wall (1 = clear)
#The first segment uses a smaller shape and skips the overlap test, so a car already touching a
#rock can still choose to back or steer away from it.
#`speed` is the car's predicted speed there: a breakable prop (fence, hedge, hay bale, crate,
#barricade) it would meet at smashMargin x its smash speed or more is driven through, as the car
#does (it smashes it with no wall damage); sweepSmashes counts them for smashCost. Slower, or an
#explosive (barrel, tank: never free), it is a wall. Speed 0 (the default) treats every prop as a wall.
var sweepSmashes := 0
const SWEEP_PASSES = 4 #at most this many breakables are driven through in one sweep
func sweep(from: Vector2, heading: Vector2, motion: Vector2, first: bool, speed := 0.0) -> float:
	sweepSmashes = 0
	var pose = Transform2D(heading.angle(), from)
	query.transform = pose
	query.exclude = excludes
	var passed: Array[RID] = []
	for attempt in SWEEP_PASSES:
		#cast_motion ignores anything the shape already overlaps, so test that first, with the real
		#footprint: the margin would make every plan in a tight pocket look like a crash
		query.motion = Vector2.ZERO
		if not first:
			query.shape = exactShape
			var overlaps = space.intersect_shape(query, 4)
			if not overlaps.is_empty():
				if not passThrough(overlaps, speed, passed): return 0.0
				continue
		query.shape = startShape if first else bodyShape
		query.motion = motion
		var result = space.cast_motion(query)
		if result.size() == 0 || result[0] >= 1.0: return 1.0
		if speed <= 0.0: return result[0]
		#what it would touch: through it if it is a breakable this speed smashes
		query.transform = Transform2D(pose.get_rotation(), from + motion * result[1])
		query.motion = Vector2.ZERO
		var touched = space.get_rest_info(query)
		query.transform = pose
		if touched.is_empty() || not passThrough([touched], speed, passed): return result[0]
	return 0.0

#true when every hit (intersect_shape or get_rest_info results) is a breakable the car smashes at
#`speed`; they are then left out of the query (`passed`) and counted in sweepSmashes
func passThrough(hits: Array, speed: float, passed: Array[RID]) -> bool:
	if speed <= 0.0: return false
	for hit in hits:
		var collider = hit.get("collider") if hit.has("collider") else instance_from_id(hit.get("collider_id", 0))
		if not smashableAt(collider, speed, p.smashMargin): return false
	for hit in hits:
		passed.push_back(hit.rid)
		sweepSmashes += 1
	var skip: Array[RID] = excludes.duplicate()
	skip.append_array(passed)
	query.exclude = skip
	return true

#would the car smash this prop at `speed` (with a margin over its smash speed)? Explosives never count:
#driving into a barrel is a blast, not a shortcut.
static func smashableAt(collider: Object, speed: float, margin := 1.15) -> bool:
	if collider == null || not is_instance_valid(collider): return false
	if not (collider.has_method("smash") || BreakableProp.isBreakable(collider)): return false
	if collider.get_meta(&"explosive", false) || collider.get_meta(&"smashed", false): return false
	return speed >= OverheadCarBody2D.smashSpeedOf(collider) * margin

#the worst ground under the car's corners (plus a margin): a lethal terrain (water) if any corner is
#over one, else a wall terrain (hills, buildings), else shallows, else GRASS. Read from World (the
#fine map once there is one), falling back to the route's chunk map.
func footprintTerrain(pos: Vector2, heading: Vector2) -> int:
	var forward = heading.normalized() * (halfSize.x + 40.0)
	var side = heading.normalized().orthogonal() * (halfSize.y + 40.0)
	var worst = Root.terrain.GRASS
	for corner in [pos, pos + forward + side, pos + forward - side, pos - forward + side, pos - forward - side]:
		var type = World.terrainAt(corner)
		if type == World.UNKNOWN: type = route.terrainAt(corner)
		if World.isLethal(type): return type
		if World.isWallTerrain(type): worst = type
		elif type == Root.terrain.SHALLOWS && not World.isWallTerrain(worst): worst = type
	return worst

#--- recovery ---------------------------------------------------------------------------------

#Twice a second: a car that has moved less than STUCK_PX in 2.5 s turns out forwards if it can (or
#reverses out) on the plan with the most room, and drops its goal for 10 s (for good after twice).
#Three times in 20 s and it escapes back along its breadcrumb trail.
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
		#trapped (a pocket of rocks, a crowd): leave the way the car came in. Its trail from a few
		#seconds back is known to be drivable; reversing is allowed until it gets there.
		stuckTicks.clear()
		stats.escapes += 1
		escapePoint = car.global_position - car.global_transform.x * 1500.0
		for i in range(trail.size() - 1 - ESCAPE_BACK_SAMPLES, -1, -1):
			if trail[i].distance_to(car.global_position) > ESCAPE_MIN_PX && not World.lethalAt(trail[i]):
				escapePoint = trail[i]
				break
		escapeUntil = tick + 8 * Engine.physics_ticks_per_second
		goal = {}
	refreshExcludes()
	#turn out forwards if some forward plan has half a second of room; otherwise back out
	var choice = roomiest(PLANS) if p.recoverForward else {"room":-INF}
	if choice.room < RECOVER_FORWARD_ROOM: choice = roomiest(REVERSE_PLANS)
	plan = choice.plan
	planPath = choice.path
	planTick = tick
	recoverUntil = tick + Engine.physics_ticks_per_second

#the plan that gets furthest before touching anything (room counts clear 0.1 s segments)
func roomiest(candidates: Array) -> Dictionary:
	var best = {"room":-INF}
	for candidate in candidates:
		var rollout = simulate(candidate, maxi(horizonTicks(), Engine.physics_ticks_per_second + 30)) #at least the blind second and then some
		var room = 0.0
		for i in range(1, rollout.path.size()):
			if World.isLethal(footprintTerrain(rollout.path[i], rollout.headings[i])): break #no room in the water
			var fraction = sweep(rollout.path[i - 1], rollout.headings[i - 1], rollout.path[i] - rollout.path[i - 1], i == 1, minf(rollout.speeds[i - 1], rollout.speeds[i]))
			room += fraction
			if fraction < 1.0: break
		if room > best.room: best = {"room":room, "plan":candidate, "path":rollout.path}
	return best

#--- debug ------------------------------------------------------------------------------------

func _draw():
	if not debug: return
	if planPath.size() > 1: draw_polyline(planPath, Color.RED if planHit else Color.LIME, 6.0)
	if routePoints.size() > 1: draw_polyline(routePoints, Color(0.3, 0.6, 1.0, 0.6), 10.0)
	if aim != Vector2.INF: draw_circle(aim, 40.0, Color.CYAN)
	if not goal.is_empty():
		draw_line(car.global_position, goalPosition(), Color.YELLOW, 3.0)
		draw_arc(goalPosition(), GOAL_RADIUS.get(goal.kind, 100.0), 0.0, TAU, 24, Color.YELLOW, 4.0)
