class_name SpawnManager extends Node

@export var spawnTimer: float = 6.0
@export var escalationSpeed = 0.07

enum goon { DEVIL , SPARTAN , SAMURAI , FIREKIN, PIKEMAN }

@export var basicGoons: Array[goon] = [
	goon.DEVIL, goon.SPARTAN , goon.SAMURAI
]

@onready var goonScene = {
	goon.DEVIL:preload("res://scene/enemy/walker/devil/devil.tscn"),
	goon.SPARTAN:preload("res://scene/enemy/walker/spartan/spartan.tscn"),
	goon.FIREKIN:preload("res://scene/enemy/walker/firekin/firekin.tscn"),
	goon.PIKEMAN:preload("res://scene/enemy/walker/pikeman/pikeman.tscn"),
	goon.SAMURAI:preload("res://scene/enemy/walker/samurai/samurai.tscn"),
}


# Called when the node enters the scene tree for the first time.
func _ready():
	Root.spawnManager = self
	increaseGiantOdds()

func increaseGiantOdds():
	giantOdds += 1
	gameTimeProgress += 1
	spawnTimer = clampf(spawnTimer - escalationSpeed , 1.0, 6.0)
	await get_tree().create_timer(10).timeout
	increaseGiantOdds()
	
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
