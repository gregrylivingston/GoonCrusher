extends Sprite2D

var velocity: Vector2
var floatPosition: Vector2
# Called when the node enters the scene tree for the first time.
func _ready():
	floatPosition = Vector2( float(position.x) , float(position.y))
	material.set_shader_parameter("angle" ,randf_range(0,6))
	material.set_shader_parameter("front_tex" , texture)
	material.set_shader_parameter("back_tex" ,  texture )

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	floatPosition += velocity
	velocity.y += 0.7
	position = floatPosition

