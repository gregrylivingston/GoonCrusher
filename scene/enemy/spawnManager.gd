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

var giantTimer:float = 0
var spawners

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
		for i in spawners:i.spawn()
		timeCount = 0
