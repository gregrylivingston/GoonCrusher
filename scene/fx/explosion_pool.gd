class_name ExplosionPool extends Node2D

#Explosions in world space, reused instead of instantiated per blast. A wrecked car, a Doomcart or
#a chain of blasts can want many at once; past MAX_LIVE the oldest one still burning is restarted.
#Levels own one (Level.explode).

const MAX_LIVE := 16

var scene: PackedScene
var idle: Array[AnimatedSprite2D] = []
var live: Array[AnimatedSprite2D] = []

func _init(explosionScene: PackedScene) -> void:
	scene = explosionScene
	name = "Explosions"
	z_index = 2 #over goons and the car, as when they were the car's children

func explode(worldPosition: Vector2) -> AnimatedSprite2D:
	var e: AnimatedSprite2D
	if not idle.is_empty(): e = idle.pop_back()
	elif live.size() >= MAX_LIVE: e = live.pop_front()
	else:
		e = scene.instantiate()
		e.pooled = true
		e.finished_burning.connect(onFinished)
		add_child(e)
	live.push_back(e)
	e.global_position = worldPosition
	e.fire()
	return e

func onFinished(e: AnimatedSprite2D) -> void:
	live.erase(e)
	idle.push_back(e)
