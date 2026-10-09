extends Node2D

#The gas station: Sprint's finish, one of Marathon's relay stops, Defense's base, and in the other modes a
#free repair shop. The lot is open on every side: only the house blocks.
#Art (world/art/station, docs/WORLD_ART.md): `lot` tiles the concrete slabs, the house has a two-slope
#shingle roof, two pump islands mark the driveway and lamp posts sit over the
#Lights (lightRole: Lights/PointLight2D is "station", Lights/<post>/PointLight2D a "post").

const LOT := Rect2(-770, -539, 1518, 1104) #the lot, from the station's origin
const BARRIER_MAX := 1000.0     #Defense: the station's health; goons that reach a pump blow up on it (Walker.siege)
const BLAST_DAMAGE := 8.0       #Defense: a goon blowing up at a pump does this many times its attack damage
const PUMPS := ["pump", "pump2"] #Defense: what the goons march on
const HOUSE_CLEARANCE := 70.0   #Defense: goons round the house this far out from its walls
#Defense: where Sentry Turrets set up, in order: between the pump islands, then either side of them and
#beyond the south one (from the station's origin; the pumps are at (0, 175) and (0, 405))
const TURRET_SPOTS := [Vector2(0, 290), Vector2(-240, 290), Vector2(240, 290), Vector2(0, 560)]
const TURRET_SPACING := 120.0
const REFUEL_PER_SECOND := 4.0  #Defense: fuel a car parked in the driveway gains

var active := true #false once Marathon has moved on to the next station
var barrier := BARRIER_MAX
var hasBarrier := false #Defense only (startBarrier)
var blasts := 0 #Defense: goons that have blown up at the pumps (the playtest's trace)
var lastHitMsec := -100000 #Defense: when a goon last blew up at a pump (the HUD flashes red)
var parkedCar: Node2D = null
signal barrier_changed(barrier: float)

func _ready():
	set_physics_process(false)
	#lamps start off during the day
	setNighttime(is_instance_valid(Root.levelRoot) && not Root.levelRoot.isDaytime)

func setNighttime(isNighttime: bool):
	$Lights.visible = isNighttime

#Marathon: a reached station stays where it is, but its driveway does nothing more
func retire() -> void:
	active = false
	parkedCar = null
	set_physics_process(false)

#--- Defense: the barrier -------------------------------------------------------------------------

func startBarrier() -> void:
	hasBarrier = true
	barrier = BARRIER_MAX
	tintBarrier()

## The point on the lot nearest `worldPoint` (the point itself when it is inside the lot).
func nearestLotPoint(worldPoint: Vector2) -> Vector2:
	return to_global(to_local(worldPoint).clamp(LOT.position, LOT.end))

## Defense: the pump island nearer `worldPoint`, which a goon from there marches on
func nearestPump(worldPoint: Vector2) -> Vector2:
	var best := Vector2.INF
	for pump in PUMPS:
		var at: Vector2 = get_node(pump).global_position
		if best == Vector2.INF || worldPoint.distance_squared_to(at) < worldPoint.distance_squared_to(best): best = at
	return best

## Defense: where a goon at `worldPoint` walks next on its way to its pump: straight at the pump, or, when the
## house is in the way, to the corner of the house (HOUSE_CLEARANCE out) on the shorter way round
func siegeStep(worldPoint: Vector2) -> Vector2:
	var pump := to_local(nearestPump(worldPoint))
	var from := to_local(worldPoint)
	var house := houseRect()
	if not segmentCrosses(house, from, pump): return to_global(pump)
	var wide := house.grow(HOUSE_CLEARANCE)
	var best := Vector2.INF
	var bestLength := INF
	for corner in [wide.position, Vector2(wide.end.x, wide.position.y), wide.end, Vector2(wide.position.x, wide.end.y)]:
		if from.distance_to(corner) < 1.0: continue
		var length: float = from.distance_to(corner) + corner.distance_to(pump)
		if segmentCrosses(house, from, corner): length += 100000.0 #only through the house: a last resort
		if length < bestLength:
			bestLength = length
			best = corner
	return to_global(best)

## Defense: where the next Sentry Turret sets up: the first TURRET_SPOTS not already taken by one
## (`turrets`: the live ones' positions), or the first again when every spot is taken
func turretSpot(turrets: Array) -> Vector2:
	for spot in TURRET_SPOTS:
		var at := to_global(spot)
		if turrets.all(func(t: Vector2): return t.distance_to(at) > TURRET_SPACING): return at
	return to_global(TURRET_SPOTS[0])

## The house's collision box, in the station's space
func houseRect() -> Rect2:
	var shape: CollisionShape2D = $house/CollisionShape2D
	var size: Vector2 = shape.shape.size
	return Rect2($house.position + shape.position - size * 0.5, size)

static func segmentCrosses(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	if rect.has_point(a) || rect.has_point(b): return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null: return true
	return false

## A goon blowing up at a pump hits the barrier through this (`amount` is its attack damage); at 0 the run
## ends (BASEDESTROYED).
func damage(amount: float) -> void:
	if not hasBarrier || barrier <= 0.0 || (is_instance_valid(Root.levelRoot) && Root.levelRoot.hasEnded): return
	blasts += 1
	lastHitMsec = Time.get_ticks_msec()
	barrier = maxf(0.0, barrier - amount * BLAST_DAMAGE)
	barrier_changed.emit(barrier)
	tintBarrier()
	if barrier <= 0.0 && is_instance_valid(Root.levelRoot): Root.levelRoot.endLevel(false, Root.endCondition.BASEDESTROYED)

## A Barricade Kit brought into the lot (PickupEffects.onStationReached); never past BARRIER_MAX.
func repairBarrier(amount: float) -> void:
	if not hasBarrier: return
	barrier = minf(BARRIER_MAX, barrier + amount)
	barrier_changed.emit(barrier)
	tintBarrier()

#the house reddens as the barrier wears down
func tintBarrier() -> void:
	var health = barrier / BARRIER_MAX
	$house.modulate = Color(1.0, lerpf(0.3, 1.0, health), lerpf(0.25, 1.0, health))

#--- the driveway ---------------------------------------------------------------------------------

## Where the car has to go: the driveway's centre (the HUD points here, the AI aims here)
func drivewayPoint() -> Vector2:
	return $driveway/CollisionShape2D.global_position

#Reaching the station wins Sprint and moves Marathon to its next leg. A car that ran out of fuel but is
#still rolling may coast in (its NOGAS ending is still pending); a wrecked car (health <= 0, or water) may not.
func _on_driveway_body_entered(body):
	if not body.has_method("getIsPlayer"): return
	if not active || not is_instance_valid(Root.levelRoot) || Root.levelRoot.hasEnded || body.health <= 0 || body.isWrecked: return
	PickupEffects.onStationReached(body, self) #a Delivery's star and Barricade Kits, before the run can end
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT: Root.levelRoot.endLevel(true, Root.endCondition.SUCCESS)
		Root.gameModes.MARATHON: Root.levelRoot.stationReached.call_deferred(self) #it places the next station: not inside a physics callback
		_:
			if body.has_method("repairAll"): body.repairAll() #a free repair shop
			if hasBarrier:
				parkedCar = body
				set_physics_process(true)

func _on_driveway_body_exited(body):
	if body == parkedCar:
		parkedCar = null
		set_physics_process(false)

#Defense: parked in the driveway, the car slowly refuels
func _physics_process(delta):
	if is_instance_valid(parkedCar) && not parkedCar.isWrecked:
		parkedCar.fuel = minf(100.0, parkedCar.fuel + REFUEL_PER_SECOND * delta)
