extends Node2D

@onready var devil = preload("res://scene/enemy/walker/devil/devil.tscn")

func spawn():
	var coordinates: Vector2i = global_position + Vector2(randi_range(-500,500),randi_range(-500,500))
	var tile = Root.levelRoot.getTileByCoordinates(coordinates)
	if tile.has("region"):
		if tile.region != -2:
			var newWalker = Root.getGoon()
			newWalker.position = coordinates
			Root.levelRoot.add_child(newWalker)

