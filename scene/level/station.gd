extends Node2D

#The gas station: Sprint's finish, one of Marathon's relay stops, Defense's base, and in the other modes a
#free repair shop. The lot is walled, with its gap on the east side.

const LOT := Rect2(-770, -539, 1518, 1104) #the walled lot, walls included, from the station's origin
const BARRIER_MAX := 1000.0     #Defense: the walls' health; goons at the walls wear it down (Walker.siege)
const REFUEL_PER_SECOND := 4.0  #Defense: fuel a car parked in the driveway gains

var active := true #false once Marathon has moved on to the next station
var barrier := BARRIER_MAX
var hasBarrier := false #Defense only (startBarrier)
var parkedCar: Node2D = null
signal barrier_changed(barrier: float)

func _ready():
	set_physics_process(false)
	#lamps start off during the day
	setNighttime(is_instance_valid(Root.levelRoot) && not Root.levelRoot.isDaytime)

func setNighttime(isNighttime: bool):
	if isNighttime:	$Polygon2D/Lights.visible = true
	else: $Polygon2D/Lights.visible = false

#Marathon: a reached station stays where it is, but its driveway does nothing more
func retire() -> void:
	active = false
	parkedCar = null
	set_physics_process(false)

#--- Defense: the barrier -------------------------------------------------------------------------

func startBarrier() -> void:
	hasBarrier = true
	barrier = BARRIER_MAX
	tintWalls()

## The point on the lot's walls nearest `worldPoint` (the point itself when it is inside the lot).
func nearestWallPoint(worldPoint: Vector2) -> Vector2:
	return to_global(to_local(worldPoint).clamp(LOT.position, LOT.end))

## Goons hit the barrier through this; at 0 the run ends (BASEDESTROYED).
func damage(amount: float) -> void:
	if not hasBarrier || barrier <= 0.0 || (is_instance_valid(Root.levelRoot) && Root.levelRoot.hasEnded): return
	barrier = maxf(0.0, barrier - amount)
	barrier_changed.emit(barrier)
	tintWalls()
	if barrier <= 0.0 && is_instance_valid(Root.levelRoot): Root.levelRoot.endLevel(false, Root.endCondition.BASEDESTROYED)

## A Barricade Kit brought into the lot (PickupEffects.onStationReached); never past BARRIER_MAX.
func repairBarrier(amount: float) -> void:
	if not hasBarrier: return
	barrier = minf(BARRIER_MAX, barrier + amount)
	barrier_changed.emit(barrier)
	tintWalls()

#the walls redden as the barrier wears down
func tintWalls() -> void:
	var health = barrier / BARRIER_MAX
	for wall in $Polygon2D.get_children():
		if wall.name.begins_with("concreteWall"): wall.self_modulate = Color(1.0, lerpf(0.3, 1.0, health), lerpf(0.25, 1.0, health))

#--- the driveway ---------------------------------------------------------------------------------

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
