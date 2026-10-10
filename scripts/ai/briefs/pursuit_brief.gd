extends "res://scripts/ai/briefs/race_brief.gd"

#Pursuit: one of the other drivers runs for the station with a head start. The runner's driver races there
#(RaceBrief). The hunter's rams it until it wrecks: it leaves cars out of its sweeps and aims where the
#runner will be when it gets there, so the hit lands on the runner's tail or flank, not behind it.

func hunting() -> bool:
	return d.car.isPlayer

func ramsCars() -> bool:
	return hunting()

func objective() -> Dictionary:
	if hunting():
		var prey = Root.levelRoot.rivals.runner() if Root.levelRoot.get("rivals") != null else null
		if prey != null: return {"kind":"gate", "pos":d.leadPoint(prey), "value":200.0, "key":"runner"}
	return super()
