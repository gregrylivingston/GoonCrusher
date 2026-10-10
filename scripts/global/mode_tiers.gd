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
const SLACK := [0.0, 0.7, 0.66, 0.62] #was 1.15 / 1 / 0.85: with the longer drives that left minutes on the clock
const SPRINT_DISTANCE := [2.5, 2.875, 3.25, 3.75]
const LEGS := [0, 2, 3, 4]
## Rally Stage: its clock's slack x the level's, for bronze, silver and gold. No goons, so far tighter than a
## Sprint's. The stage is a Marathon leg long on every tier (SPRINT_DISTANCE[0]), so it is one course.
const RALLY_SLACK := [0.0, 0.7, 0.56, 0.46]
## The score Trials (TrialScore): Smash Run's quota of breakables and Drift Trial's score, and their clocks.
## Cone Course: the clock for its gates (ConeCourse); a knocked cone takes a second off it.
const SMASH_QUOTA := [0, 15, 25, 35]
const SMASH_SECONDS := [0.0, 150.0, 150.0, 150.0]
const DRIFT_TARGET := [0, 1500, 3000, 5000]
const DRIFT_SECONDS := [0.0, 120.0, 120.0, 120.0]
const CONES_SECONDS := [0.0, 90.0, 70.0, 55.0]
## The Goon Cup: the place a win needs, of the six cars (Rivals.COUNT rivals and the player)
const CUP_PLACE := [0, 3, 2, 1]
## Loops (Course.loopRoute): laps of Hot Lap (the best one counts) and Circuit Race; Knockout runs one fewer
## than its field. Flat Out's clock slack (it has nitro) and the speed over which crossing the line costs
## FLATOUT_PENALTY seconds. Demolition Derby: a rival's health, how hard cars hit, and the clock.
const HOTLAP_LAPS := 3
const HOTLAP_SLACK := [0.0, 0.36, 0.3, 0.26] #the lap the tier asks for, as a share of a Sprint clock round the loop
const CIRCUIT_LAPS := 3
const FLATOUT_SLACK := [0.0, 0.62, 0.5, 0.42]
const FLATOUT_STOP_SPEED := 420.0
const FLATOUT_PENALTY := 2.0
const DERBY_HEALTH := [0.0, 80.0, 100.0, 120.0]
const DERBY_BUMP := 1.5
const DERBY_SECONDS := [0.0, 240.0, 240.0, 240.0]
## Keep the Cup: seconds of holding that win it, and its clock. Pursuit: the runner's health, its head start (px)
## and its pace as a share of the player's car's top speed; how much harder cars hit each other there.
const CUP_HOLD := [0.0, 40.0, 55.0, 70.0]
const CUP_SECONDS := [0.0, 240.0, 240.0, 240.0]
const RUNNER_HEALTH := [0.0, 45.0, 60.0, 75.0]
const RUNNER_START := [0.0, 1600.0, 2200.0, 2800.0]
const RUNNER_PACE := [0.0, 0.78, 0.86, 0.94]
const PURSUIT_BUMP := 2.5
## its goons, where it has any ("light": Modes.lightGoons), come this much less often
const LIGHT_SPAWN_SCALE := 3.0
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
const WIN_RATE := {M.GOONCRUSHER: 100.0, M.SPRINT: 150.0, M.MARATHON: 120.0, M.DEFENSE: 150.0, M.GOONPOCALYPSE: 60.0, M.BLACKOUT: 120.0, M.BOUNTY: 130.0, M.RALLY: 170.0, M.SMASH: 170.0, M.DRIFT: 170.0, M.CONES: 170.0, M.CANNONBALL: 150.0, M.PURSUIT: 150.0, M.KEEPCUP: 130.0, M.FLATOUT: 170.0, M.HOTLAP: 170.0, M.CIRCUIT: 150.0, M.KNOCKOUT: 150.0, M.DERBY: 150.0}
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
	if mode == M.FLATOUT: return levelSeconds * Level.SPRINT_DRIVE_FRACTION * sprintSlack * FLATOUT_SLACK[tier] * SPRINT_DISTANCE[NONE]
	if mode in [M.HOTLAP, M.CIRCUIT, M.KNOCKOUT]: return 150.0 #about three laps of a loop; the real clock comes from the loop's length (Level.setupLoop)
	if mode == M.DERBY: return DERBY_SECONDS[tier]
	if mode == M.RALLY: return levelSeconds * Level.SPRINT_DRIVE_FRACTION * sprintSlack * RALLY_SLACK[tier] * SPRINT_DISTANCE[NONE]
	var sprint: float = levelSeconds * Level.SPRINT_DRIVE_FRACTION * sprintSlack * SLACK[tier]
	match Modes.plays(mode):
		M.GOONCRUSHER: return levelSeconds * CLOCK[tier]
		M.GOONPOCALYPSE: return levelSeconds * POCALYPSE_TARGET[tier]
		M.DEFENSE: return DEFENSE_HOLD[tier]
		M.BOUNTY: return bountySeconds(tier)
		M.SMASH: return SMASH_SECONDS[tier]
		M.KEEPCUP: return CUP_SECONDS[tier]
		M.DRIFT: return DRIFT_SECONDS[tier]
		M.CONES: return CONES_SECONDS[EASY] #paid by the course, which is the same on every tier, not by its shrinking clock
		M.SPRINT: return sprint * SPRINT_DISTANCE[tier]
		M.MARATHON: return sprint * SPRINT_DISTANCE[NONE] * LEGS[tier]
	return 0.0

## A score Trial's target on a tier (TrialScore): Smash Run's quota, Drift Trial's score
static func trialTarget(mode: int, tier: int) -> int:
	tier = clampTier(tier)
	return DRIFT_TARGET[tier] if mode == M.DRIFT else SMASH_QUOTA[tier]

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

## One line for run setup: what the tier asks on this level. The races' clocks come from the route once the
## world is built, so theirs is the planned drive's (goalSeconds), to the nearest 5 s, as "about".
static func goalText(mode: int, tier: int, levelSeconds: float, sprintSlack := 1.3) -> String:
	tier = clampTier(tier)
	match mode:
		M.FLATOUT: return "Beat the %s time, flat out to the station" % MEDALS[tier].to_lower()
		M.HOTLAP: return "Beat the %s lap: the best of %d counts" % [MEDALS[tier].to_lower(), HOTLAP_LAPS]
		M.CIRCUIT: return "%d laps: finish %s" % [CIRCUIT_LAPS, ["", "in the top 3", "in the top 2", "first"][tier]]
		M.KNOCKOUT: return "Last place is out every lap. Be the one left (%s field)" % ["", "a slow", "a quicker", "a quick"][tier]
		M.DERBY: return "Wreck all five rivals (%s)" % ["", "they break easily", "tougher", "as tough as you"][tier]
		M.KEEPCUP: return "Hold the cup for %d seconds before a rival does" % CUP_HOLD[tier]
		M.PURSUIT: return "Wreck the runner before the station (%s)" % ["", "slow, a short lead", "quicker, a longer lead", "as quick as you"][tier]
		M.CANNONBALL: return "Reach the station %s" % (["", "in the top 3", "in the top 2", "first"][tier])
		M.SMASH: return "Smash %d things in %s" % [SMASH_QUOTA[tier], clock(SMASH_SECONDS[tier])]
		M.DRIFT: return "Score %d drifting in %s" % [DRIFT_TARGET[tier], clock(DRIFT_SECONDS[tier])]
		M.CONES: return "Clear the gates in %s" % clock(CONES_SECONDS[tier])
		M.RALLY: return "Beat the %s time over the stage" % MEDALS[tier].to_lower()
		M.BOUNTY: return "Crush %d marks in %s" % [BOUNTY_MARKS[tier], clock(bountySeconds(tier))]
		M.BLACKOUT: return "Survive %s of night" % clock(levelSeconds * CLOCK[tier])
		M.GOONCRUSHER: return "Survive %s" % clock(levelSeconds * CLOCK[tier])
		M.GOONPOCALYPSE: return "Survive %s" % clock(levelSeconds * POCALYPSE_TARGET[tier])
		M.DEFENSE: return "Hold the station for %s" % clock(DEFENSE_HOLD[tier])
		M.SPRINT: return "Reach the station in about %s" % clock(snappedf(goalSeconds(mode, tier, levelSeconds, sprintSlack), 5.0))
		M.MARATHON: return "Reach %d stations in about %s" % [LEGS[tier], clock(snappedf(goalSeconds(mode, tier, levelSeconds, sprintSlack), 5.0))]
	return ""

static func clock(seconds: float) -> String:
	var s := roundi(seconds)
	return "%d:%02d" % [s / 60, s % 60]
