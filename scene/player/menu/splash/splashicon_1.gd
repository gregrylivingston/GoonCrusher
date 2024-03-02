extends Sprite2D

var velocity: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	var targetVelocity = Vector2( randf_range(-1,1),randf_range(-1,1)).normalized()
	targetVelocity.x = targetVelocity.x * randf_range(0,18)
	targetVelocity.y = ( targetVelocity.y -1.95 ) * randf_range(0,15)
	velocity =  targetVelocity
	material.set_shader_parameter("angle" ,randf_range(0,6))
	material.set_shader_parameter("front_tex" , texture)
	material.set_shader_parameter("back_tex" ,  texture )


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	velocity.y += 0.7
	position += velocity

