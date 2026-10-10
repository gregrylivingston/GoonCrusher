extends ModeBrief

#Sprint, Marathon, Rally Stage and Cannonball: the station (through the course's checkpoints, if it has
#any) against the clock. Detours come out of the spare time and goons are worth less than the road
#(AIDriver.detourBudget, raceGoonScale); the tank has to cover the route.

func objective() -> Dictionary:
	var station := d.stationObjective()
	return station if not station.is_empty() else d.gateObjective()

func isRace() -> bool:
	return true

func fuelPlan() -> StringName:
	return &"race"

func healthReserve() -> float:
	return d.p.reserveBase + 10.0
