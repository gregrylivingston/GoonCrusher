extends Node2D

func spawn():
	if not Root.spawnManager.canSpawn(): return
	var coordinates: Vector2i = global_position + Vector2(randi_range(-500,500),randi_range(-500,500))
	var tile = Root.levelRoot.getTileByCoordinates(coordinates)
	if tile.has("region"):
		if tile.region != -2:
			var newWalker = Root.getGoon()
			newWalker.position = coordinates
			Root.spawnManager.registerGoon(newWalker)
			Root.levelRoot.add_child(newWalker)
