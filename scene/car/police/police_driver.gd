extends AIDriver

#Nikita's driver (the police car: PIT Maneuver, Lightbar). Goons swatted with its flanks or tail cost it no
#health, so a goon beside the car matters far less than to any other; and at night the lightbar shows it
#everything round the car, not only what the beams reach.

const FLANK_SHARE := 0.25 #a lunging goon can still land a hit; a swatted one can't

func personalities() -> Dictionary:
	return {
		#in among them, swatting with the flanks
		"interceptor": {"crushReward": 1.5, "goonValue": 20.0, "slowGoonCost": 2.0},
		#keeps its distance and its health
		"bythebook": {},
	}

func flankScale() -> float:
	return FLANK_SHARE if car.tPit else 1.0

func nightGlow() -> float:
	return CarTraitRig.LIGHTBAR_RADIUS if car.tLightbar else NIGHT_GLOW_PX
