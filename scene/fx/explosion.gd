extends AnimatedSprite2D

#An explosion keeps replaying while it swells, then ends. Pooled ones (ExplosionPool) hide and wait
#to be fired again; any other instance frees itself.

const FRAMES = [
	preload("res://scene/fx/explosion/spriteframes_explosion2.tres"),
	preload("res://scene/fx/explosion/spriteframes_explosion3.tres"),
	preload("res://scene/fx/explosion/spriteframes_explosion4.tres"),
]

var pooled := false
signal finished_burning(explosion: AnimatedSprite2D)

func _ready():
	if not pooled: fire()

func fire() -> void:
	sprite_frames = FRAMES[randi() % FRAMES.size()]
	var myScale = randf_range(0.2,0.5)
	scale = Vector2( myScale , myScale )
	rotation = 0.0
	visible = true
	play(&"default")

func _on_animation_finished():
	if scale.x < 1.2:
		create_tween().tween_property(self , "scale" , scale * randf_range(1.02,1.08) , 0.1)
		play()
	elif pooled:
		stop()
		visible = false
		finished_burning.emit(self)
	else: queue_free()
