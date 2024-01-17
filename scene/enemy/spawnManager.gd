extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	Root.spawnManager = self
	increaseGiantOdds()

@onready var goon = {
	"devil":preload("res://scene/enemy/walker/devil/devil.tscn"),
	"spartan":preload("res://scene/enemy/walker/spartan/spartan.tscn"),
	"samurai":preload("res://scene/enemy/walker/samurai/samurai.tscn"),
}

func increaseGiantOdds():
	giantOdds += 1
	await get_tree().create_timer(10).timeout
	increaseGiantOdds()
	
func createGoonScene():
	var randomizer = randf_range(0,100) - giantOdds
	if randomizer > 5:return goon.devil.instantiate()
	elif randomizer > -15: return goon.spartan.instantiate()
	else: return goon.samurai.instantiate()
	
var giantOdds = -1
func getGoon():
	var goon = createGoonScene()
	if randi_range(0 , 100) < giantOdds:
		goon.isGiant = true
	return goon

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
