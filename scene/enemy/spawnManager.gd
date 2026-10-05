class_name SpawnManager extends Node

@export var spawnTimer: float = 6.0
@export var escalationSpeed = 0.15

enum goon { DEVIL , SPARTAN , SAMURAI , FIREKIN, PIKEMAN , GOONBEAR , DOOMCART , GREMLIN , 
SHELLBACK , IMMORTAL , LIZARD , RAT , ROCKMAN , SKELETON , SMASHER ,
SOLDIER , VIKING , ZULU }
var basicGoons
@onready var goonScene = {
	goon.DEVIL:preload("res://scene/enemy/walker/devil/devil.tscn"),
	goon.SPARTAN:preload("res://scene/enemy/walker/spartan/spartan.tscn"),
	goon.FIREKIN:preload("res://scene/enemy/walker/firekin/firekin.tscn"),
	goon.PIKEMAN:preload("res://scene/enemy/walker/pikeman/pikeman.tscn"),
	goon.SAMURAI:preload("res://scene/enemy/walker/samurai/samurai.tscn"),
	goon.GOONBEAR:preload("res://scene/enemy/walker/goonbear/goonbear.tscn"),
	goon.DOOMCART:preload("res://scene/enemy/walker/doomcart/doomcart.tscn"),
	goon.GREMLIN:preload("res://scene/enemy/walker/gremlin/gremlin.tscn"),
	goon.SHELLBACK:preload("res://scene/enemy/walker/shellback/shellback.tscn"),
	goon.IMMORTAL:preload("res://scene/enemy/walker/immortal/immortal.tscn"),
	goon.LIZARD:preload("res://scene/enemy/walker/lizard/lizard.tscn"),
	goon.RAT:preload("res://scene/enemy/walker/rat/rat.tscn"),
	goon.ROCKMAN:preload("res://scene/enemy/walker/rockman/rockman.tscn"),
	goon.SKELETON:preload("res://scene/enemy/walker/skeleton/skeleton.tscn"),
	goon.SMASHER:preload("res://scene/enemy/walker/smasher/smasher.tscn"),
	goon.SOLDIER:preload("res://scene/enemy/walker/soldier/soldier.tscn"),
	goon.VIKING:preload("res://scene/enemy/walker/viking/viking.tscn"),
	goon.ZULU:preload("res://scene/enemy/walker/zulu/zulu.tscn")
}

const GOON_CAP = 250          #same for every player and preset
const DESPAWN_DISTANCE = 8000.0
const SWEEP_SECONDS = 0.5
const LOD_MARGIN = 400.0     #goons this far outside the view still collide normally

#world rect where goons run full physics; refreshed every physics tick
var physicsView := Rect2()

var giantTimer:float = 0
var spawners
var liveGoons: int = 0
var goons: Array[Node] = []
var pendingSpawns: Array = []
var sweepTimer: float = 0.0

func registerGoon(newGoon: Node) -> void:
	liveGoons += 1
	goons.push_back(newGoon)
	newGoon.tree_exiting.connect(onGoonExiting.bind(newGoon))

func onGoonExiting(goon: Node) -> void:
	liveGoons -= 1
	goons.erase(goon)

func _physics_process(_delta):
	physicsView = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).grow(LOD_MARGIN)

#off-screen LOD: goons outside the view skip collision queries while they walk
func needsFullPhysics(point: Vector2) -> bool:
	return physicsView.has_area() == false || physicsView.has_point(point)

func canSpawn() -> bool:
	return liveGoons < GOON_CAP

#frees goons left far behind. Before this ran only when a goon finished idling.
func despawnSweep() -> void:
	if not is_instance_valid(Root.playerCar): return
	var carPosition = Root.playerCar.global_position
	var view = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for goon in goons.duplicate():
		if is_instance_valid(goon) && not goon.is_queued_for_deletion() && goon.global_position.distance_to(carPosition) > DESPAWN_DISTANCE && not view.has_point(goon.global_position):
			goon.queue_free()

# Called when the node enters the scene tree for the first time.
func _ready():
	Root.spawnManager = self
	await get_tree().process_frame
	spawners = get_tree().get_nodes_in_group("spawner")


func increaseGiantOdds():
	giantOdds += 1
	gameTimeProgress += 1
	spawnTimer = clampf(spawnTimer - escalationSpeed , 1.0, 6.0)
	
func createGoonScene():
	var randomizer = randf_range(0,100) - gameTimeProgress
	if randomizer > 5:return goonScene[basicGoons[0]].instantiate()
	elif randomizer > -15: return goonScene[basicGoons[1]].instantiate()
	else: return goonScene[basicGoons[2]].instantiate()
	
var gameTimeProgress = 0 
@export var giantOdds = -10
func getGoon():
	var goon = createGoonScene()
	if randi_range(0 , 100) < giantOdds:
		goon.isGiant = true
	return goon


var timeCount: float = 0
var mySpawners

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	giantTimer += delta
	if giantTimer > 10:
		increaseGiantOdds()
		giantTimer = 0
	timeCount += delta
	if timeCount > spawnTimer:
		pendingSpawns.append_array(spawners)
		timeCount = 0
	#one spawner per frame, so a wave is spread over five frames instead of one
	if not pendingSpawns.is_empty():
		var spawner = pendingSpawns.pop_front()
		if is_instance_valid(spawner): spawner.spawn()
	sweepTimer -= delta
	if sweepTimer <= 0.0:
		sweepTimer = SWEEP_SECONDS
		despawnSweep()
