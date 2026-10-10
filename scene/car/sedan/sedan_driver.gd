extends AIDriver

#Anthony's driver (the sedan: Second Wind, Duct Tape). The all-rounder the base driver was tuned on, so it
#changes little: with the tank's one restart still unused it worries less about fuel.

func personalities() -> Dictionary:
	return {
		#clean and patient: the house style as it is
		"steady": {},
		#leans on Second Wind and gets stuck in: more crushing, a thinner health reserve, hopes for more fuel
		"scrappy": {"crushReward": 1.5, "goonValue": 18.0, "reserveBase": 15.0, "fuelHope": 1.3},
	}

func fuelCaution() -> float:
	return 0.75 if car.tSecondWind && not car.secondWindUsed else 1.0
