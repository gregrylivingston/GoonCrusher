class_name SpawnManager extends Node

@export var spawnTimer: float = 6.0
@export var escalationSpeed = 0.07

enum goon { DEVIL , SPARTAN , SAMURAI , FIREKIN, PIKEMAN }

var basicGoons

@onready var goonScene = {
	goon.DEVIL:preload("res://scene/enemy/walker/devil/devil.tscn"),
	goon.SPARTAN:preload("res://scene/enemy/walker/spartan/spartan.tscn"),
	goon.FIREKIN:preload("res://scene/enemy/walker/firekin/firekin.tscn"),
	goon.PIKEMAN:preload("res://scene/enemy/walker/pikeman/pikeman.tscn"),
	goon.SAMURAI:preload("res://scene/enemy/walker/samurai/samurai.tscn"),
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
		increaseGiantOdds
		giantTimer = 0
	timeCount += delta
	if timeCount > spawnTimer:
		for i in spawners:i.spawn()
		timeCount = 0
