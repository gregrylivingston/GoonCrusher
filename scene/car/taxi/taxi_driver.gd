extends AIDriver

#Andrew's driver (the taxi: The Meter, City Tyres). The meter pays while the car stays above its speed
#with no wall hits (CarTraitRig.METER_SPEED), so fuel saving never takes it below that, and walls cost
#it more than they cost anyone else.

const METER_MARGIN := 30.0 #px/s kept over the meter's speed

func tuning() -> Dictionary:
	return {"hitCost": 12.0}

func personalities() -> Dictionary:
	return {
		#keeps the meter running: clean, quick, no detours into rough corners
		"fare": {"amongRocksMinValue": 30.0},
		#cuts corners and takes the knocks
		"shortcut": {"hitCost": 9.0, "probeCost": 3.0, "crushReward": 1.0},
	}

func cruiseFloor() -> float:
	return maxf(p.ecoMinSpeed, CarTraitRig.METER_SPEED + METER_MARGIN) if car.tMeter else p.ecoMinSpeed
