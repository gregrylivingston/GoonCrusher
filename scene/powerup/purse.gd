extends Powerup

var coinScene = preload("res://scene/powerup/coin.tscn")

func sendReward(body, forShowOnly: bool = false):
	var coinsToReward = randi_range( 50 , 250 )
	visible = false
	for i in coinsToReward:
		var newCoin = coinScene.instantiate()
		newCoin.global_position = Root.playerCar.global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
		Root.levelRoot.add_child(newCoin)
		newCoin.process_mode = Node.PROCESS_MODE_ALWAYS
		newCoin.sendReward(body, forShowOnly)
		await get_tree().process_frame
	body.playPurseRewardAudio()	
	queue_free()
