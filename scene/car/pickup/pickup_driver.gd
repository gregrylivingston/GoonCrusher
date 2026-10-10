extends AIDriver

#Karen's driver (the pickup: Off-Road Suspension, Loaded Bed). Every pickup it collects loads a crate worth
#5% of the run's payout, up to five (CarTraitRig.onRewarded), so cargo is worth more to it while the bed has
#room; a hard wall hit spills one, so walls cost more.

const CRATE_VALUE := 12.0 #what a crate in the bed adds to a pickup's worth (a goon crush is about 12)

func tuning() -> Dictionary:
	return {"hitCost": 11.0}

func personalities() -> Dictionary:
	return {
		#fills the bed: detours for pickups
		"hoarder": {"pickupScale": 1.4},
		#straight through the rough after goons
		"mudder": {"goonValue": 18.0, "crushReward": 1.2, "pickupScale": 0.9},
	}

func pickupWorth(pickup: Node, value: float) -> float:
	var rig = car.traitRig
	if not car.tLoadedBed || rig == null || rig.bedCrates >= CarTraitRig.BED_MAX || CarTraitRig.NOT_CARGO.has(pickup.powerup): return value
	return value + CRATE_VALUE * p.pickupScale
