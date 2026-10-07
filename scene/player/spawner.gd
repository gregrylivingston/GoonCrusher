extends Node2D

#A goon spawn point (SpawnManager calls spawn() for each in turn). The spot is up to OFFSET px from it,
#rolled from the spawner's own RNG (seeded from the world seed and a counter, never the global RNG), and
#must be spawnable ground (World.spawnableAt: not water, a wall or shallows): up to TRIES spots are tried.

const OFFSET := 500
const TRIES := 3

var rng: RandomNumberGenerator

func spawn():
	if not Root.spawnManager.canSpawn(): return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = Root.worldMap.nextSpawnerSeed() if Root.worldMap != null else hash(get_path())
	for i in TRIES:
		var coordinates: Vector2i = global_position + Vector2(rng.randi_range(-OFFSET, OFFSET), rng.randi_range(-OFFSET, OFFSET))
		if World.spawnableAt(coordinates):
			Root.spawnManager.spawnAt(coordinates) #one goon, or a whole pack or herd
			return
