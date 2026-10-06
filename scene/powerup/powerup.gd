class_name Powerup extends Sprite2D

@export var powerup: String
@export var quantity: float

var hasShinyShader: bool = true

func _ready():
	add_to_group("pickup") #the AI driver looks for pickups here
	if not hasShinyShader:
		set_material(null)



func _on_area_2d_body_entered(body):
	if body is CharacterBody2D:
		if body.has_method("getIsPlayer"):
			sendReward(body)

@export var awardSound: Array[AudioStreamMP3]

#credits the reward at once; the fly-to-HUD icon that follows is only for show
func sendReward(body, forShowOnly: bool = false):
	if has_node("Area2D"): $Area2D.queue_free() #can't be collected twice
	Audio.queueRequest(awardSound)
	if not forShowOnly: Pickups.discover(Pickups.idForScene(scene_file_path)) #the Goonopedia shows it from now on
	body.reward(powerup , quantity, forShowOnly)
	RewardFlyers.flyPowerup(self)
	queue_free()
