extends ModeBrief

#Hot Lap, Circuit Race and Knockout: laps of a loop through its gates. No station, no goons and a free
#tank, so the whole job is the next gate (ModeBrief.objective: AIDriver.gateObjective) and the road to it;
#Nitro goes on the straights.

func healthReserve() -> float:
	return d.p.reserveBase

func wantsBoost() -> bool:
	return d.openRoadAhead()
