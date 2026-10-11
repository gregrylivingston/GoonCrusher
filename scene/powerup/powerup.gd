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
		if not body.has_method("getIsPlayer"): return
		var own = get("id") #a GenericPickup's
		var taker = Coop.pickupFor(body, own if own is String && own != "" else Pickups.idForScene(scene_file_path), powerup) #a friendly guest (Coop) keeps what its car uses and hands the player the rest
		if taker.getIsPlayer() || taker.isGuest: #a rival car (Rivals) leaves it
			WorldMap.takeNode(self) #a chunk's own pickup stays gone when the chunk loads again
			var coins: int = taker.coin
			sendReward(taker)
			if taker != body: body.coin += taker.coin - coins #the guest's own count of what they brought in (their HUD)

@export var awardSound: Array[AudioStreamMP3]

#credits the reward at once; the fly-to-HUD icon that follows is only for show
func sendReward(body, forShowOnly: bool = false):
	if has_node("Area2D"): $Area2D.queue_free() #can't be collected twice
	Audio.queueRequest(awardSound)
	if not forShowOnly:
		Pickups.discover(Pickups.idForScene(scene_file_path)) #the Goonopedia shows it from now on
		Pickups.countCollected(body, Pickups.idForScene(scene_file_path))
	body.reward(powerup , quantity, forShowOnly)
	if not body.get("isGuest"): RewardFlyers.flyPowerup(self) #it flies to the player's HUD
	queue_free()
