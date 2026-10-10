extends AIDriver

#Lester's driver (the van: Cargo Bay, Top-Heavy). Hard cornering at speed lifts the van onto two wheels and,
#held there, rolls it (CarTraitRig.tickTip), which is a rule outside integrate() the plans can't see. So
#this driver counts how long a plan would keep it up and charges for the ones that end on its roof. It
#leaves the handbrake alone: a slide is the quickest way over.

const ROLL_SHARE := 0.6 #a plan is charged once it would use this share of the ticks a roll takes

func tuning() -> Dictionary:
	return {"handbrakeTurn": 0.0}

func personalities() -> Dictionary:
	return {
		#wide, slow corners: never near a roll
		"hauler": {},
		#rides two wheels and sometimes pays for it
		"tipsy": {"tipCost": 1.5, "hitCost": 8.0, "crushReward": 1.2},
	}

func planGuard(_candidate: Dictionary, rollout: Dictionary) -> float:
	if not car.tTopHeavy: return 0.0
	#ticks up on two wheels at the plan's end: what it already has, plus the plan's own hard cornering
	var up: int = rollout.hard - (0 if car.twoWheels else CarTraitRig.TIP_TICKS) + (car.traitRig.upTicks if car.twoWheels else 0)
	var share := float(up) / CarTraitRig.ROLL_TICKS
	return p.tipCost * share if share >= ROLL_SHARE else 0.0
