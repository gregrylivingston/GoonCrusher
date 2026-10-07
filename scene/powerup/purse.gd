extends Powerup

const MIN_COINS = 15
const MAX_COINS = 100

#all coins are credited at once; the coins that fly to the HUD afterwards are only for show
func sendReward(body, forShowOnly: bool = false):
	if has_node("Area2D"): $Area2D.queue_free()
	visible = false
	if not forShowOnly:
		Pickups.discover("purse")
		Pickups.countCollected(body, "purse")
	var coinsToReward = randi_range( MIN_COINS , MAX_COINS )
	body.reward("coin", coinsToReward * RewardFlyers.infoFor(Root.upgrade.COIN).get("quantity", 1), forShowOnly)
	body.playPurseRewardAudio()
	for i in coinsToReward:
		#the show stops if the run ends or the chunk unloads under it (the coins are already credited)
		if not is_instance_valid(Root.playerCar) || not is_inside_tree(): break
		RewardFlyers.flyUpgrade(Root.upgrade.COIN, Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) ))
		await get_tree().physics_frame
		if not is_inside_tree(): break
		await get_tree().physics_frame
	queue_free()
