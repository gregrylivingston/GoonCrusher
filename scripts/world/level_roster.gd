class_name LevelRoster extends RefCounted

#Who holds the land on a level (LevelDef.factionBand, LevelDef.roster) and which three goons a region
#or district gets. Rosters are validated against Goons.DATA: unknown ids, rank-0 goons and goons of
#another faction are dropped with a warning. A faction's roster needs MIN_LOW rank-1 goons and
#MIN_HIGH rank-2+ goons; a short one is padded from the faction's pool. A faction with no roster at
#all falls back to the Goon Tribe's (The Crusher has no Wild Things).

const MIN_LOW := 1
const MIN_HIGH := 2

static var cache := {} #"<level id>:<faction>" -> validated, padded Array of ids

## The faction score of a spot `distancePx` from the start, as Goons.factionFor scores it without the
## level index, clamped to the level's band
static func factionScore(distancePx: float, jitter: float, band: Vector2) -> float:
	var score := distancePx / Goons.CHUNK_PX * Goons.DISTANCE_WEIGHT + jitter
	return clampf(score, minf(band.x, band.y), maxf(band.x, band.y))

static func factionForScore(score: float) -> int:
	if score < Goons.WILD_BELOW: return Goons.faction.WILD
	if score < Goons.TRIBE_BELOW: return Goons.faction.TRIBE
	return Goons.faction.SCRAP

## The faction holding a spot on this level; without a def, the old index-weighted Goons.factionFor
static func factionAt(def: LevelDef, distancePx: float, jitter: float) -> int:
	if def == null: return Goons.factionFor(distancePx, 0, jitter)
	return factionForScore(factionScore(distancePx, jitter, def.factionBand))

## Every goon of a faction that regions may spawn (rank 1+), lowest rank first, in Goons.DATA order within a rank
static func factionPool(f: int) -> Array:
	var out := []
	for rank in [1, 2, 3]:
		for id in Goons.DATA:
			var d: Dictionary = Goons.DATA[id]
			if d.faction == f && d.rank == rank: out.push_back(id)
	return out

## The roster ids that are real goons of faction `f`, in authored order; the rest are dropped with a warning
static func validIds(ids: Array, f: int, context: String = "") -> Array:
	var out := []
	for raw in ids:
		var id := StringName(raw)
		var d: Dictionary = Goons.DATA.get(id, {})
		if d.is_empty(): push_warning("%sunknown goon %s dropped from the roster" % [context, id])
		elif d.faction != f: push_warning("%s%s is not %s; dropped from the roster" % [context, id, Goons.factionName(f)])
		elif d.rank < 1: push_warning("%s%s never spawns from regions (rank 0); dropped" % [context, id])
		elif not id in out: out.push_back(id)
	return out

## The faction the roster of `f` really comes from: `f`, or the Tribe when the level lists none of `f`
static func rosterFaction(def: LevelDef, f: int) -> int:
	if def == null: return f
	if f == Goons.faction.TRIBE: return f
	for id in rawRoster(def, f):
		var d: Dictionary = Goons.DATA.get(StringName(id), {})
		if not d.is_empty() && d.faction == f && d.rank >= 1: return f
	return Goons.faction.TRIBE

## A faction's roster on this level: validated, padded to MIN_LOW rank-1 and MIN_HIGH rank-2+ goons,
## lowest rank first. An empty faction gives the Tribe's roster.
static func rosterFor(def: LevelDef, f: int) -> Array:
	var key := "%s:%d" % [def.id if def else &"", f]
	if cache.has(key): return cache[key].duplicate()
	var source := rosterFaction(def, f)
	var context := "Level %s, %s: " % [def.id if def else &"?", Goons.factionName(source)]
	var ids := validIds(rawRoster(def, source), source, context) if def else []
	var pool := factionPool(source)
	var low := ids.filter(func(id): return Goons.DATA[id].rank == 1).size()
	var high := ids.filter(func(id): return Goons.DATA[id].rank >= 2).size()
	for id in pool:
		if id in ids: continue
		var rank: int = Goons.DATA[id].rank
		if rank == 1 && low < MIN_LOW:
			ids.push_back(id)
			low += 1
		elif rank >= 2 && high < MIN_HIGH:
			ids.push_back(id)
			high += 1
	var sorted := []
	for rank in [1, 2, 3]: sorted.append_array(ids.filter(func(id): return Goons.DATA[id].rank == rank))
	cache[key] = sorted
	return sorted.duplicate()

static func rawRoster(def: LevelDef, f: int) -> Array:
	if def == null: return []
	var ids = def.roster.get(f, def.roster.get(str(f), []))
	return ids if ids is Array else []

## A region's or district's three goons from the level's roster for faction `f`: slot 1 is the lowest
## rank present, slots 2 and 3 are higher ranks, picked with `rng` so a seeded run picks the same goons
static func pickGoons(def: LevelDef, f: int, rng: RandomNumberGenerator) -> Array:
	var ids := rosterFor(def, f)
	if ids.is_empty(): return []
	var lowest: int = Goons.DATA[ids[0]].rank
	var low := ids.filter(func(id): return Goons.DATA[id].rank == lowest)
	var high := ids.filter(func(id): return Goons.DATA[id].rank > lowest)
	var first = low[rng.randi() % low.size()]
	for i in range(high.size() - 1, 0, -1): #seeded shuffle
		var j := rng.randi() % (i + 1)
		var swap = high[i]; high[i] = high[j]; high[j] = swap
	var rest := high.duplicate()
	for id in low: if id != first && rest.size() < 2: rest.push_back(id)
	while rest.size() < 2: rest.push_back(ids[rng.randi() % ids.size()])
	return [first, rest[0], rest[1]]
