class_name LevelRoster extends RefCounted

#Which three goons a district gets on a level: three of the level's line-up (LevelDef.lineup, 3-6 goons of
#its region's class, Goons.CLASSES). Slot 1 is the line-up's lowest rank (the spawner's commonest goon, the
#fodder), slots 2 and 3 a seeded shuffle of the rest. A line-up shorter than three repeats; an empty or
#invalid one falls back to the region's class. Unknown ids and rank-0 goons are dropped with a warning.

static var cache := {} #level id -> validated line-up

## The goons a level may field: its line-up, validated (real goons of rank 1+, each once, authored order).
## Falls back to its region's class when nothing in the line-up is valid.
static func lineupFor(def: LevelDef) -> Array:
	if def == null: return validIds(Goons.classMembers(&"tribe"))
	var key := String(def.id)
	if key != "" && cache.has(key): return cache[key].duplicate()
	var ids := validIds(def.lineup, "Level %s: " % def.id)
	if ids.is_empty(): ids = validIds(Goons.classMembers(Territories.classOf(def.region)))
	if key != "": cache[key] = ids
	return ids.duplicate()

## The ids that are real goons that regions may spawn (rank 1+), in authored order, each once
static func validIds(ids: Array, context: String = "") -> Array:
	var out := []
	for raw in ids:
		var id := StringName(raw)
		var d: Dictionary = Goons.DATA.get(id, {})
		if d.is_empty(): push_warning("%sunknown goon %s dropped from the line-up" % [context, id])
		elif d.rank < 1: push_warning("%s%s never spawns from districts (rank 0); dropped" % [context, id])
		elif not id in out: out.push_back(id)
	return out

## A district's three goons on this level, picked with `rng` so a seeded run picks the same goons
static func pickGoons(def: LevelDef, rng: RandomNumberGenerator) -> Array:
	return pickFrom(lineupFor(def), rng)

## Three goons from a list: slot 1 one of its lowest rank, slots 2 and 3 a seeded shuffle of the others
## (repeating when the list is short). [] for an empty list.
static func pickFrom(ids: Array, rng: RandomNumberGenerator) -> Array:
	if ids.is_empty(): return []
	var lowest := 99
	for id in ids: lowest = mini(lowest, int(Goons.DATA[id].rank))
	var low := ids.filter(func(id): return Goons.DATA[id].rank == lowest)
	var first = low[rng.randi() % low.size()]
	var rest := ids.filter(func(id): return id != first)
	for i in range(rest.size() - 1, 0, -1): #seeded shuffle
		var j := rng.randi() % (i + 1)
		var swap = rest[i]; rest[i] = rest[j]; rest[j] = swap
	if rest.is_empty(): rest = [first]
	return [first, rest[0], rest[1 % rest.size()]]
