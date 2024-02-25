extends Node2D

@onready var devil = preload("res://scene/enemy/walker/devil/devil.tscn")

func spawn():
	var newWalker = Root.getGoon()
	newWalker.position = global_position + Vector2(randi_range(-500,500),randi_range(-500,500))
	Root.levelRoot.add_child(newWalker)

