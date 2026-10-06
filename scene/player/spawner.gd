extends Node2D

func spawn():
	if not Root.spawnManager.canSpawn(): return
	var coordinates: Vector2i = global_position + Vector2(randi_range(-500,500),randi_range(-500,500))
	var tile = Root.levelRoot.getTileByCoordinates(coordinates)
	if tile.has("terrain") && World.isSpawnable(tile.terrain): Root.spawnManager.spawnAt(coordinates) #one goon, or a whole pack or herd
