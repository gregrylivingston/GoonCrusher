class_name ModeBriefs extends RefCounted

#Which brief (ModeBrief, scripts/ai/briefs/) an AI driver gets for each mode. A mode with no entry gets the
#base brief: roam, crush, collect (Goonpocalypse plays that way).

const M := Root.gameModes
const SURVIVAL := preload("res://scripts/ai/briefs/survival_brief.gd")
const RACE := preload("res://scripts/ai/briefs/race_brief.gd")
const LAP := preload("res://scripts/ai/briefs/lap_brief.gd")

const BRIEFS := {
	M.GOONCRUSHER: SURVIVAL, M.BLACKOUT: SURVIVAL,
	M.SPRINT: RACE, M.MARATHON: RACE, M.RALLY: RACE, M.CANNONBALL: RACE,
	M.FLATOUT: preload("res://scripts/ai/briefs/flatout_brief.gd"),
	M.PURSUIT: preload("res://scripts/ai/briefs/pursuit_brief.gd"),
	M.HOTLAP: LAP, M.CIRCUIT: LAP, M.KNOCKOUT: LAP,
	M.CONES: preload("res://scripts/ai/briefs/cones_brief.gd"),
	M.DRIFT: preload("res://scripts/ai/briefs/drift_brief.gd"),
	M.SMASH: preload("res://scripts/ai/briefs/smash_brief.gd"),
	M.DEFENSE: preload("res://scripts/ai/briefs/defense_brief.gd"),
	M.BOUNTY: preload("res://scripts/ai/briefs/bounty_brief.gd"),
	M.DERBY: preload("res://scripts/ai/briefs/derby_brief.gd"),
	M.KEEPCUP: preload("res://scripts/ai/briefs/keepcup_brief.gd"),
}

static func forMode(mode: int, driver: AIDriver) -> ModeBrief:
	var brief: ModeBrief = BRIEFS[mode].new() if BRIEFS.has(mode) else ModeBrief.new()
	brief.mode = mode
	brief.d = driver
	return brief
