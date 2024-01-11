extends Node2D

@onready var devil = preload("res://scene/enemy/walker/devil/devil.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	await get_tree().create_timer(2).timeout
	spawn()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func spawn():
	var newWalker = Root.getGoon()
	newWalker.position = global_position + Vector2(randi_range(-500,500),randi_range(-500,500))
	Root.levelRoot.add_child(newWalker)

	await get_tree().create_timer(2).timeout
	spawn()
