class_name ModeTiers extends RefCounted
## Easy, Medium and Hard: three completions for every mode on every level (docs/GAMEPLAY_SUGGESTIONS.md,
## package 1, B-1). The player picks the tier in run setup (PlayerData.gameTier). A harder tier sets a longer
## or stricter goal and a tougher world. Beating a tier credits the ones below it; Hard opens once Medium is
## beaten. The save keeps the best tier per mode per level in the level entry's `tiers` (SaveManager.passTier);
## `gamemodeBeat` stays the "beaten on any tier" flag the unlock chain reads.
##
## Every number here is a first guess, re-fitted with career playtests (package 1, B-4).

enum { NONE, EASY, MEDIUM, HARD }
const TIERS := [EASY, MEDIUM, HARD]
const NAMES := ["", "Easy", "Medium", "Hard"]
const MEDALS := ["", "Bronze", "Silver", "Gold"]
const MEDAL_COLORS := [Color(0.2, 0.15, 0.1, 0.55), Color(0.85, 0.52, 0.26), Color(0.82, 0.86, 0.92), Color(1.0, 0.8, 0.22)]

const M := Root.gameModes

## The goal, by tier (index 1-3). Countdown: the clock x the level's seconds. Goonpocalypse: survive this x
## the level's seconds. Defense: hold the station this many seconds (not scaled by the level: its goons
## already come faster, and the barrier's wear grows with the square of the hold). Sprint and Marathon: the
## clock's slack x the level's. Sprint: the station's distance x the region's (index 0 is a Marathon leg, a
## little shorter than an Easy Sprint). Marathon: legs, few enough that the longest relay is about as long as a
## Hard Countdown.
const CLOCK := [0.0, 1.0, 1.6, 2.2]
const POCALYPSE_TARGET := [0.0, 1.0, 1.75, 2.5]
const DEFENSE_HOLD := [0.0, 150.0, 210.0, 270.0]
## Defense spawns this much less often than the other modes: every lane spawns each round and the goons
## pile up at the walls, since one car can't crush them as fast as Countdown's spawners send them
const DEFENSE_SPAWN_SCALE := 2.5
const SLACK := [0.0, 1.15, 1.0, 0.85]
const SPRINT_DISTANCE := [2.5, 2.875, 3.25, 3.75]
const LEGS := [0, 2, 3, 4]
## Bounty Hunt: marks to crush, and the clock's seconds for each one (the drive out to it and the fight)
const BOUNTY_MARKS := [0, 3, 4, 5]
const BOUNTY_MARK_SECONDS := [0.0, 80.0, 70.0, 60.0]

## The world, by tier: escalation speed x, giant odds + (percent points), spawn interval x
const ESCALATION := [1.0, 1.0, 1.3, 1.6]
const GIANT_ODDS := [0, 0, 8, 16]
const SPAWN_TIMER := [1.0, 1.0, 0.9, 0.8]

## Win pay (B-2): coins a minute of the goal by mode (goalSeconds), x the tier's risk and x the level's step,
## added to the run's coins before the star multiplier (Root.computePayout). Racing and Defense earn few coins
## on the way, so they get more a minute. Paid by the goal's length, not per run: a flat bonus made a one-minute
## Hard Sprint pay 1,575 coins a minute (career playtests, 2026-10-08).
## A mode with no rate of its own pays its base mode's (Modes.plays); a mode that isn't built yet pays nothing.
const WIN_RATE := {M.GOONCRUSHER: 100.0, M.SPRINT: 150.0, M.MARATHON: 120.0, M.DEFENSE: 150.0, M.GOONPOCALYPSE: 60.0, M.BLACKOUT: 120.0, M.BOUNTY: 130.0}
const TIER_BONUS := [0.0, 1.0, 1.3, 1.6]
const LEVEL_STEP := 0.085 #each level after the first adds this share of the base: the 30th pays about 3.5x the first
## Paid once, the first time a tier is beaten on a mode and level (not multiplied by stars)
const FIRST_CLEAR_COINS := [0, 300, 800, 2000]
const FIRST_CLEAR_GEMS := [0, 0, 1, 3]

static func clampTier(tier: int) -> int:
	return clampi(tier, EASY, HARD)

static func levelFactor(levelIndex: int) -> float:
	return 1.0 + LEVEL_STEP * maxi(levelIndex, 0)

## What a won run pays on top of its coins, from the level's def (its seconds and Sprint slack)
static func winBonus(mode: int, tier: int, levelIndex: int) -> int:
	var def := Levels.defAt(levelIndex)
	var seconds := goalSeconds(mode, tier, def.seconds if def else 300.0, def.sprintSlack if def else 1.3)
	return roundi(WIN_RATE.get(mode, WIN_RATE.get(Modes.plays(mode), 0.0)) * seconds / 60.0 * TIER_BONUS[clampTier(tier)] * levelFactor(levelIndex))

## How long the tier's goal runs, for its pay: the clock or target, or for the races the clock the planned
## drive gets (Level.SPRINT_DRIVE_FRACTION of the level's seconds at REFERENCE_SPEED, x the slack; x Sprint's
## distance or the legs)
static func goalSeconds(mode: int, tier: int, levelSeconds: float, sprintSlack: float) -> float:
	tier = clampTier(tier)
	var sprint: float = levelSeconds * Level.SPRINT_DRIVE_FRACTION * sprintSlack * SLACK[tier]
	match Modes.plays(mode):
		M.GOONCRUSHER: return levelSeconds * CLOCK[tier]
		M.GOONPOCALYPSE: return levelSeconds * POCALYPSE_TARGET[tier]
		M.DEFENSE: return DEFENSE_HOLD[tier]
		M.BOUNTY: return bountySeconds(tier)
		M.SPRINT: return sprint * SPRINT_DISTANCE[tier]
		M.MARATHON: return sprint * SPRINT_DISTANCE[NONE] * LEGS[tier]
	return 0.0

## Bounty Hunt's clock: its marks x the seconds each gets
static func bountySeconds(tier: int) -> float:
	tier = clampTier(tier)
	return BOUNTY_MARKS[tier] * BOUNTY_MARK_SECONDS[tier]

## {coin, gem} for beating `tier` when `before` was the best so far: every tier newly credited pays once
static func firstClear(before: int, tier: int, levelIndex: int) -> Dictionary:
	var out := {"coin": 0, "gem": 0}
	for t in range(maxi(before, NONE) + 1, clampTier(tier) + 1):
		out.coin += roundi(FIRST_CLEAR_COINS[t] * levelFactor(levelIndex))
		out.gem += FIRST_CLEAR_GEMS[t]
	return out

## The best tier beaten for a mode in a level entry (0 when none). A save from before the tiers has only
## gamemodeBeat, which counts as Easy.
static func best(level: Dictionary, mode: int) -> int:
	var tiers: Dictionary = level.get("tiers", {})
	var t := int(tiers.get(mode, 0))
	if t == NONE && level.get("gamemodeBeat", {}).get(mode, false): return EASY
	return clampi(t, NONE, HARD)

## Can this tier be started (the mode itself must be playable too: Root.isModePlayable)? Easy and Medium
## are open with the mode; Hard once Medium is beaten.
static func isOpen(level: Dictionary, mode: int, tier: int) -> bool:
	return tier <= MEDIUM || best(level, mode) >= MEDIUM

static func lockReason(level: Dictionary, mode: int, tier: int) -> String:
	return "" if isOpen(level, mode, tier) else "Beat Medium To Unlock Hard"

## How many mode-and-level completions reach this tier, over every level
static func clears(levels: Array, tier: int) -> int:
	var n := 0
	for level in levels:
		for mode in M.values():
			if best(level, mode) >= tier: n += 1
	return n

## One line for run setup: what the tier asks on this level
static func goalText(mode: int, tier: int, levelSeconds: float) -> String:
	tier = clampTier(tier)
	match mode:
		M.BOUNTY: return "Crush %d marks in %s" % [BOUNTY_MARKS[tier], clock(bountySeconds(tier))]
		M.BLACKOUT: return "Survive %s of night" % clock(levelSeconds * CLOCK[tier])
		M.GOONCRUSHER: return "Survive %s" % clock(levelSeconds * CLOCK[tier])
		M.GOONPOCALYPSE: return "Survive %s" % clock(levelSeconds * POCALYPSE_TARGET[tier])
		M.DEFENSE: return "Hold the station for %s" % clock(DEFENSE_HOLD[tier])
		M.SPRINT: return "Beat a %s clock to the station" % ["", "loose", "fair", "tight"][tier] + ["", "", ", further off", ", furthest off"][tier]
		M.MARATHON: return "Reach %d stations" % LEGS[tier]
	return ""

static func clock(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]
