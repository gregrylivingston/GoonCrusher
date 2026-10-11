class_name KeepCup extends Node2D
## Keep the Cup (Modes, Root.gameModes.KEEPCUP): one trophy and six cars (Rivals) on an open map with no goons.
## The cup lies ahead of the start; the first car to reach it takes it. Whoever holds it banks time, and any
## other car that gets within STEAL_PX of the holder takes it (after TAKE_IMMUNITY seconds, so it can't bounce
## straight back). The holder drives a little slower than the pack (HOLDER_PACE), so it can always be caught.
## The first car to bank the tier's hold time wins: the player (a win) or a rival (OUTRUN). Level adds one in
## this mode; AIDriver.objectiveGoal sends every driver after the cup, and the holder off to roam.
## Every number is a first guess.

const AHEAD := 1600.0        #px from the start to where the cup lies
const PICK_PX := 130.0       #a car this close to the loose cup takes it
const STEAL_PX := 230.0      #a car this close to the holder takes it
const TAKE_IMMUNITY := 2.0   #seconds a new holder keeps it whatever happens
const HOLDER_PACE := 0.88    #the holder's pace as a share of the pack's
const ICON := preload("res://texture/icon/mode_keepcup.svg")

var holder: Node2D = null
var spot := Vector2.ZERO     #where the cup is while nobody holds it
var held := {}               #car instance id -> seconds banked
var immune := 0.0
var need := 60.0
var sprite := Sprite2D.new()

func _ready() -> void:
	var level = Root.levelRoot
	need = ModeTiers.CUP_HOLD[ModeTiers.clampTier(level.tier)]
	var car = Root.playerCar
	spot = car.global_position + Vector2.from_angle(car.rotation) * AHEAD
	for i in 12: #onto ground a car can reach
		var tryAt: Vector2 = car.global_position + Vector2.from_angle(car.rotation + i * TAU / 12.0) * AHEAD
		if World.spawnableAt(tryAt):
			spot = tryAt
			break
	sprite.texture = ICON
	sprite.z_index = 20
	add_child(sprite)
	global_position = spot

## Where the cup is: on its holder or on the ground
func cupPosition() -> Vector2:
	return holder.global_position if is_instance_valid(holder) else spot

func playerSeconds() -> float:
	return held.get(Root.playerCar.get_instance_id(), 0.0) if is_instance_valid(Root.playerCar) else 0.0

## The most any rival has banked
func rivalBest() -> float:
	var best := 0.0
	var mine := Root.playerCar.get_instance_id() if is_instance_valid(Root.playerCar) else 0
	for id in held:
		if id != mine: best = maxf(best, held[id])
	return best

func playerHolds() -> bool:
	return is_instance_valid(holder) && holder == Root.playerCar

func contenders() -> Array:
	var level = Root.levelRoot
	var out := []
	if is_instance_valid(Root.playerCar) && not Root.playerCar.isDestroyed: out.push_back(Root.playerCar)
	if level.rivals:
		for car in level.rivals.cars:
			if is_instance_valid(car) && not car.isDestroyed: out.push_back(car)
	return out

func _physics_process(delta: float) -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.hasEnded || not level.clockReady: return
	immune = maxf(immune - delta, 0.0)
	if holder != null && (not is_instance_valid(holder) || holder.isDestroyed): #wrecked with it: the cup drops there
		if is_instance_valid(holder): spot = holder.global_position
		setHolder(null)
	if holder == null:
		global_position = spot
		for car in contenders():
			if car.global_position.distance_to(spot) < PICK_PX:
				setHolder(car)
				break
		return
	spot = holder.global_position
	global_position = spot + Vector2(0.0, -70.0)
	var id := holder.get_instance_id()
	held[id] = held.get(id, 0.0) + delta
	if held[id] >= need:
		var won: bool = holder == Root.playerCar
		level.endLevel.call_deferred(won, Root.endCondition.SUCCESS if won else Root.endCondition.OUTRUN)
		return
	if immune > 0.0: return
	for car in contenders():
		if car != holder && car.global_position.distance_to(spot) < STEAL_PX:
			setHolder(car)
			return

func setHolder(car: Node2D) -> void:
	var level = Root.levelRoot
	if is_instance_valid(holder): setPace(holder, 1.0)
	holder = car
	immune = TAKE_IMMUNITY
	if car == null: return
	setPace(car, HOLDER_PACE)
	var who: String = "YOU HAVE" if car == Root.playerCar else "%s HAS" % (level.rivals.names.get(car.get_instance_id(), "A RIVAL") if level.rivals else "A RIVAL")
	TapeBanner.post("%s THE CUP" % who, 0.9)

#a rival's driver holds its pace cap (Rivals.pace); the holder's is cut. The player's own car is not slowed.
func setPace(car: Node2D, share: float) -> void:
	var level = Root.levelRoot
	if car == Root.playerCar || level.rivals == null: return
	var driver = car.myController.driver if car.get("myController") else null
	if driver is AIDriver: driver.paceCap = level.rivals.pace * share #a guest (Coop) is a rival with no cap
