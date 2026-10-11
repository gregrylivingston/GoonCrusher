class_name Achievements extends RefCounted
## Achievements: goals with tiers, each paying a reward the player claims in the Goonopedia (docs/UI.md).
## Every goon has one ("goon:<id>", from Goons.DATA): crush it GOON_GOALS times. What is earned is read from
## the save's counters (PlayerData.goonsCrushed), never stored; the save keeps only how many tiers were claimed
## (meta.achievements[id]). A new kind adds its ids to all() and its cases to goals(), progress() and title().
## Steam will mirror these by steamId().

const TIER_NAMES := ["I", "II", "III"]
## Crushes for a goon's tiers, by its rank (Goons.DATA; the spawn-only rank 0 counts as fodder). Placeholders.
const GOON_GOALS := {0: [1, 250, 10000], 1: [1, 250, 10000], 2: [1, 100, 2500], 3: [1, 50, 1000]}
## What each tier pays when claimed. Placeholders.
const GOON_REWARDS := [{"coin": 100}, {"coin": 1500}, {"gem": 1}]

static func forGoon(goon: StringName) -> String:
	return "goon:" + String(goon)

static func goonOf(id: String) -> StringName:
	return StringName(id.trim_prefix("goon:"))

static func all() -> Array:
	return Goons.DATA.keys().map(forGoon)

## "GOON_GRUNT_2" for tier index 1: the name Steam's achievement goes by
static func steamId(id: String, tier: int) -> String:
	return "%s_%d" % [id.replace(":", "_").to_upper(), tier + 1]

static func title(id: String, tier: int) -> String:
	return "%s %s" % [Goons.DATA.get(goonOf(id), {}).get("name", id), TIER_NAMES[tier]]

static func goals(id: String) -> Array:
	return GOON_GOALS.get(int(Goons.DATA.get(goonOf(id), {}).get("rank", 1)), GOON_GOALS[1])

static func reward(_id: String, tier: int) -> Dictionary:
	return GOON_REWARDS[tier]

## The count the goals are measured against
static func progress(id: String) -> int:
	return int(SaveManager.playerData.goonsCrushed.get(String(goonOf(id)), 0))

## How many tiers `count` reaches
static func tiersAt(id: String, count: int) -> int:
	return goals(id).filter(func(goal): return count >= goal).size()

static func earned(id: String) -> int:
	return tiersAt(id, progress(id))

static func claimed(id: String) -> int:
	return int(SaveManager.playerData.meta.get("achievements", {}).get(id, 0))

## Tiers earned and not yet claimed
static func claimable(id: String) -> int:
	return maxi(earned(id) - claimed(id), 0)

static func claimableCount(ids: Array = all()) -> int:
	var n := 0
	for id in ids: n += claimable(id)
	return n

static func earnedCount(ids: Array = all()) -> int:
	var n := 0
	for id in ids: n += earned(id)
	return n

## What claiming `id` would pay now: {"coin": n, "gem": n}, {} when nothing waits
static func pending(id: String) -> Dictionary:
	var out := {}
	for tier in range(claimed(id), earned(id)):
		var pay := reward(id, tier)
		for key in pay: out[key] = int(out.get(key, 0)) + int(pay[key])
	return out

## Pays every earned tier of `id` and marks them claimed; returns what it paid ({} when nothing waited)
static func claim(id: String) -> Dictionary:
	var pay := pending(id)
	if pay.is_empty(): return pay
	SaveManager.playerData.meta.get_or_add("achievements", {})[id] = earned(id)
	SaveManager.addCoins(int(pay.get("coin", 0)))
	SaveManager.addGems(int(pay.get("gem", 0)))
	SaveManager.save_character_data()
	return pay

static func claimAll(ids: Array = all()) -> Dictionary:
	var out := {}
	for id in ids:
		var pay := claim(id)
		for key in pay: out[key] = int(out.get(key, 0)) + int(pay[key])
	return out

## A crush of `goon` by `car` in a run: a tape banner when it reaches a tier. The save's count is only added to
## on the results ticket, so the total is the save's plus this run's, from both cars of a two-player run.
static func onCrush(car: Object, goon: StringName) -> void:
	if not Goons.DATA.has(goon) || (car != Root.playerCar && car != Coop.guest): return
	var id := forGoon(goon)
	var total := progress(id)
	for c in [Root.playerCar, Coop.guest]:
		if is_instance_valid(c): total += int(c.crushedById.get(goon, 0))
	var tier := goals(id).find(total)
	if tier < 0: return
	var name := str(Goons.DATA[goon].name).to_upper()
	if tier == 0: TapeBanner.post("NEW GOON  -  " + name, 1.0)
	else: TapeBanner.post("%s %s  -  %s CRUSHED" % [name, TIER_NAMES[tier], DriverCard.formatCoins(total)], 1.0)
