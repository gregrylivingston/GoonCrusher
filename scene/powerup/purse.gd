extends Powerup

var coinScene = preload("res://scene/powerup/coin.tscn")

func sendReward(body):
	var coinsToReward = randi_range( 5 , 100 )
	for i in coinsToReward:
		var newCoin = coinScene.instantiate()
		newCoin.global_position = global_position + Vector2( randi_range(-100,100) ,randi_range(-100,100) )
		get_parent().add_child(newCoin)
		newCoin.sendReward(body)
		await get_tree().process_frame
	queue_free()
