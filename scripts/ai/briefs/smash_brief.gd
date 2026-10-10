extends ModeBrief

#Smash Run: a quota of breakables before the clock runs out. The goal is the nearest thing this car can
#smash (AIDriver.nearestBreakable: it knows what each car's weight breaks); rocks and walls still hurt.

func objective() -> Dictionary:
	var prop := d.nearestBreakable()
	if prop != null: return {"kind":"gate", "pos":prop.global_position, "value":80.0, "key":"smash%d" % prop.get_instance_id()}
	return super()

func wantsBoost() -> bool:
	return d.openRoadAhead()
