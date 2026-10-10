extends AIDriver

#Snake's driver (the supercar: Downforce, Low Clearance, seven gears). Fast and fragile: walls cost it more
#and it keeps more health in hand. Downforce and the splitter's dislike of rough ground are handling
#(integrate()), so its plans already feel them.

func tuning() -> Dictionary:
	return {"hitCost": 12.0, "reserveBase": 30.0}

func personalities() -> Dictionary:
	return {
		#top speed first: saves less fuel, crushes what is in the way
		"flatout": {"ecoMinSpeed": 350.0, "crushReward": 1.0},
		#not a scratch on it
		"precious": {"hitCost": 14.0, "flankCost": 4.0, "amongRocksMinValue": 40.0},
	}
