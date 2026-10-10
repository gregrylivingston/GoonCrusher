class_name RunRank

#A run's score and its rank on a 25-step ladder (docs/MODES.md, "Run rank"). Modes differ too much for raw
#points to share one ladder, so each part of the score is measured against a par for the run's level, mode
#and tier: what the AI drivers do there, baked from playtest runs (scripts/debug/bake_run_par.gd writes
#PAR_PATH). A run at par scores about two thirds of what its tier allows; the top ranks need a run well past
#par. Pure: grade() reads only what it is handed, so the playtest harness logs the same score the ticket shows.

const TITLES: Array[String] = ["Goon", "Speed Bump", "Roadkill", "Sunday Driver", "Learner's Permit",
	"Fender Bender", "Lane Hog", "Tailgater", "Road Hazard", "Lead Foot",
	"Bumper Thumper", "Goon Bruiser", "Hit and Runner", "Road Rager", "Wrecking Crew",
	"Goon Flattener", "Highway Menace", "Derby King", "Asphalt Outlaw", "Goon Reaper",
	"Road Warlord", "Steamroller", "Apex Menace", "Goonslayer", "GoonCrusher"]
const RANKS := 25
const MAX_SCORE := 1000
const POINTS_PER_RANK := 40
#the share of the score each part can earn
const SHARES := {"goal": 0.4, "carnage": 0.25, "style": 0.15, "haul": 0.2}
const OVER := 1.5 #a part counts up to this many times its par
const TIER_SCALE := [1.0, 0.85, 0.93, 1.0] #by ModeTiers tier: the top rank is out of reach below Hard
const LOSS_CAP := 13 * POINTS_PER_RANK - 1 #a lost run tops out at rank 13: the top half of the ladder means a win
const GIANT_WEIGHT := 5 #a giant counts as this many crushes, as in Goonpocalypse's score (Level.pocalypseScore)
const HIGHLIGHT_OVER := 1.15 #a part this far past par earns the run its highlight
const PAR_PATH := "res://world/run_par.json"
#par where nothing is baked for the mode at all. Placeholders.
const FALLBACK := {"crushed": 60.0, "combo": 6.0, "speed": 600.0, "paid": 300.0, "time": 0.0}

## The score and rank of a run.
## stats: won, progress (the share of the mode's goal reached; past 1 where a mode goes on after its goal),
## timed (a quicker win is a better one), time (s), crushed, giants, combo, speed (px/s), paid (coins), fuel.
## par: crushed, combo, speed, paid, time (0 where a part has no par: it then counts as met).
## Returns score, rank (1..RANKS), title, parts (each part's points) and highlight ("" when nothing stood out).
static func grade(stats: Dictionary, par: Dictionary, tier: int) -> Dictionary:
	var won: bool = stats.get("won", false)
	var combo := ratio(stats.get("combo", 0), par.get("combo", 0.0))
	var speed := ratio(stats.get("speed", 0.0), par.get("speed", 0.0))
	var ratios := {
		"carnage": ratio(float(stats.get("crushed", 0)) + GIANT_WEIGHT * float(stats.get("giants", 0)), par.get("crushed", 0.0)),
		"style": (combo + speed) * 0.5,
		"haul": ratio(stats.get("paid", 0), par.get("paid", 0.0)),
	}
	var progress: float = stats.get("progress", 0.0)
	if not won: ratios.goal = clampf(progress, 0.0, 1.0)
	elif stats.get("timed", false) && float(par.get("time", 0.0)) > 0.0 && float(stats.get("time", 0.0)) > 0.0:
		ratios.goal = clampf(float(par.time) / float(stats.time), 1.0, OVER) #a quicker win than par
	elif progress > 1.0: ratios.goal = minf(progress, OVER) #the mode went on past its goal
	else: ratios.goal = clampf((ratios.carnage + ratios.style + ratios.haul) / 3.0, 1.0, OVER) #no pace to measure: as far past par as the rest of the run
	var parts := {}
	var total := 0.0
	var scale: float = TIER_SCALE[clampi(tier, 0, TIER_SCALE.size() - 1)]
	for part in SHARES:
		parts[part] = roundi(SHARES[part] * ratios[part] / OVER * MAX_SCORE * scale)
		total += parts[part]
	var score := int(total)
	if not won: score = mini(score, LOSS_CAP)
	var rank := rankOf(score)
	return {"score": score, "rank": rank, "title": TITLES[rank - 1], "parts": parts, "highlight": highlight(stats, ratios, combo, speed)}

static func ratio(value: float, par: float) -> float:
	if par <= 0.0: return 1.0
	return clampf(value / par, 0.0, OVER)

static func rankOf(score: int) -> int:
	return clampi(1 + score / POINTS_PER_RANK, 1, RANKS)

static func title(rank: int) -> String:
	return TITLES[clampi(rank, 1, RANKS) - 1]

#the one thing the run did best, when it was well past par
static func highlight(stats: Dictionary, ratios: Dictionary, combo: float, speed: float) -> String:
	var marks := {"Crowd Control": ratios.carnage, "Combo Fiend": combo, "Speed Demon": speed, "Coin Magnet": ratios.haul}
	var best := ""
	for mark in marks:
		if marks[mark] >= HIGHLIGHT_OVER && (best == "" || marks[mark] > marks[best]): best = mark
	if best == "Crowd Control" && int(stats.get("giants", 0)) >= 3: return "Giant Killer"
	if best == "" && stats.get("won", false) && float(stats.get("fuel", 100.0)) < 5.0: return "Running on Fumes"
	return best

#--- par ----------------------------------------------------------------------------------------
#PAR_PATH holds {"<level id>/<mode id>/<tier>": {crushed, combo, speed, paid, time}}. A level, mode and tier
#nothing was baked for takes the mean of the mode on that tier over the levels that have one, then the mode
#on any tier, then FALLBACK.

static var table := {}
static var tableRead := false

static func parTable() -> Dictionary:
	if tableRead: return table
	tableRead = true
	if FileAccess.file_exists(PAR_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PAR_PATH))
		if parsed is Dictionary: table = parsed
	return table

static func parKey(levelId: String, modeId: String, tier: int) -> String:
	return "%s/%s/%d" % [levelId, modeId, tier]

static func parFor(levelId: String, modeId: String, tier: int) -> Dictionary:
	var all := parTable()
	var own = all.get(parKey(levelId, modeId, tier))
	if own is Dictionary: return own
	var sameTier := meanOf(all, "/%s/%d" % [modeId, tier])
	if not sameTier.is_empty(): return sameTier
	var anyTier := meanOf(all, "/%s/" % modeId)
	return anyTier if not anyTier.is_empty() else FALLBACK

#the mean of every entry whose key holds `fragment`; {} when there is none
static func meanOf(all: Dictionary, fragment: String) -> Dictionary:
	var sum := {}
	var count := 0
	for key in all:
		if not str(key).contains(fragment) || not all[key] is Dictionary: continue
		count += 1
		for field in FALLBACK: sum[field] = float(sum.get(field, 0.0)) + float(all[key].get(field, 0.0))
	if count == 0: return {}
	for field in sum: sum[field] /= count
	return sum
