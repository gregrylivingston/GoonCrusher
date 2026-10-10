extends AIDriver

#Tiffany's driver (the semi: Unstoppable, Drop the Load, ten gears, a trailer). It smashes breakables at
#any speed (the base driver asks the car what it can smash) and the base charges plans that drag the
#trailer through a rock (trailerCost). This adds the ability: with a pack on its tail and the trailer
#loaded it drops the cargo on them. It leaves the handbrake alone: a slide folds the trailer.

const DROP_GOONS := 4     #this many goons close behind...
const DROP_PX := 520.0    #...within this of the car

func tuning() -> Dictionary:
	return {"handbrakeTurn": 0.0, "smashCost": 0.1}

func personalities() -> Dictionary:
	return {
		#through everything that breaks, and most goons
		"bulldozer": {"crushReward": 1.5, "goonValue": 18.0, "smashCost": 0.0, "flankCost": 2.0},
		#plans wide for the trailer and keeps the paint
		"trucker": {"trailerCost": 5.0, "hitCost": 11.0},
	}

func wantsAbility() -> bool:
	if not car.tDropLoad || car.loadDropped || tick % 10 != 0: return false
	var behind := 0
	for g in nearGoons:
		var local: Vector2 = car.to_local(g)
		if local.x < 0.0 && local.length() < DROP_PX: behind += 1
	return behind >= DROP_GOONS
