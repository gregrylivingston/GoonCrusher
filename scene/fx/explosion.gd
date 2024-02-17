extends AnimatedSprite2D

var explosionOptions = [
	"res://scene/fx/explosion/spriteframes_explosion2.tres",
	"res://scene/fx/explosion/spriteframes_explosion3.tres",
	"res://scene/fx/explosion/spriteframes_explosion4.tres"
]


# Called when the node enters the scene tree for the first time.
func _ready():
	sprite_frames = load(explosionOptions[ randi() % explosionOptions.size() ])
	var myScale = randf_range(0.2,0.5)
	scale = Vector2( myScale , myScale )


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rotation = -get_parent().rotation
#	$PointLight2D.texture = sprite_frames.get_frame_texture("default", frame)
	pass

func _on_animation_finished():
	if scale.x < 1.2:
		get_tree().create_tween().tween_property(self , "scale" , scale * randf_range(1.02,1.08) , 0.1)
		play()
