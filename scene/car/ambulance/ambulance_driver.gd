extends AIDriver

#Xavier's driver (the ambulance: Defibrillator, Box Sway). The defibrillator brings it back once from 0
#health, so until that is spent it can hunt goons on less health than another car would risk.

const DEFIB_HEALTH := 12.0 #health the unused shock is worth against the reserve

func personalities() -> Dictionary:
	return {
		#protects its health and keeps the shock for an accident
		"careful": {"reserveBase": 30.0},
		#lights and sirens: spends the shock early
		"codethree": {"reserveBase": 15.0, "crushReward": 1.2, "goonValue": 18.0},
	}

func spareHealth() -> float:
	return DEFIB_HEALTH if car.tDefib && not car.defibUsed else 0.0
