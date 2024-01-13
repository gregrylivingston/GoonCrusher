class_name Powerup extends Sprite2D

@export var powerup: String
@export var quantity: float

func _on_area_2d_body_entered(body):
	if body.get_class() == "CharacterBody2D":
		if body.isPlayer: 
			$Area2D.queue_free()
			sendReward(body)

func sendReward(body, forShowOnly: bool = false):
	$AudioStreamReward.play()
	uiControlNode = get_tree().get_first_node_in_group(powerup+"ui")
	startPosition = global_position
	get_tree().create_tween().tween_method(flyToUi, 0.0, 1.0, 0.3)
	await get_tree().create_timer(0.05).timeout
	body.reward(powerup , quantity, forShowOnly)
	await get_tree().create_timer(0.25).timeout
	visible = false
	await get_tree().create_timer(2).timeout
	queue_free()

var uiControlNode
var startPosition
func flyToUi(lerpAmount):
	var screen_coords = uiControlNode.get_viewport_transform() * uiControlNode.global_position
	global_position = startPosition.lerp( get_viewport_transform().affine_inverse() * screen_coords , lerpAmount)

