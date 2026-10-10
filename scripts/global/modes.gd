class_name Modes extends RefCounted
## The game modes (Root.gameModes) as data: each mode's id, category, words and rules, and which three a level
## features. Every level plays Sprint, then Countdown, then one Crusher, one Trial and one Goon Cup mode picked
## for it (LevelDef.featured); winning any one of the three opens the next level (Root.modePath, roadModes,
## opensNextLevel). Root.MODE_AVAILABLE says which modes are built; the rest show "Coming Soon".
##
##   id           the word tools, unlock conditions and level defs use ("rally"); IDS is in Root.gameModes order
##   name         the menus' name, upper case
##   category     CRUSHER (goons are the point), TRIAL (no goons: the course and the clock) or CUP (other drivers)
##   plays        the mode whose run rules it uses when it is a variant (Blackout plays Countdown): what the
##                level, spawners, clock, HUD and AI driver branch on (plays())
##   description  one line for run setup; `rules` is how it is won, shown after it
##   map          RANDOM (a new world each run) or FIXED (one course per level, so results compare)
##   pickups      ALL, NONE or PLACED (only the kinds in `kinds`, at fixed spots on a fixed map, never rolled)
##   boxes        do crushes fill gift boxes here
##   record       what the record book keeps: "time", "lap", "score", "crushes", "wins" or "" (none yet)
##   goons        "full" (the level's line-up), "light" (a thin crowd on the road) or "none"

const M := Root.gameModes
enum Category { CRUSHER, TRIAL, CUP }
enum Map { RANDOM, FIXED }
enum Drops { ALL, PLACED, NONE }

const CATEGORY_ORDER := [Category.CRUSHER, Category.TRIAL, Category.CUP]
const CATEGORY_NAMES := ["Crusher", "Trial", "Goon Cup"]
const CATEGORY_COLORS := [Color("#f17d69"), Color("#6ab3f2"), Color("#e6b83c")]
const CATEGORY_BLURBS := ["Goons are the point.", "No goons. You against the course.", "You against the other drivers."]

## Mode ids in Root.gameModes order (Unlocks.MODE_KEYS, LevelDef.featured, `--mode=`)
const IDS := ["countdown", "sprint", "marathon", "defense", "goonpocalypse", "blackout", "bounty", "rally", "flatout",
	"hotlap", "drift", "cones", "smash", "cannonball", "circuit", "derby", "knockout", "keepcup", "pursuit"]

const DATA := {
	M.GOONCRUSHER: {"name": "COUNTDOWN", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "crushes", "goons": "full",
		"description": "Survive the countdown while crushing increasing powerful waves of goon.",
		"rules": "The clock counts down from the level's time. Still driving when it hits zero? You win."},
	M.SPRINT: {"name": "SPRINT", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "time", "goons": "full",
		"description": "Race against the goons, rocks, and clocks to reach the finish line.",
		"rules": "Reach the gas station before the clock runs out. The further away the station, the more time you get."},
	M.MARATHON: {"name": "MARATHON", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "time", "goons": "full",
		"description": "A relay of stations. Each one refuels you, patches you up and adds time. Reach the last.",
		"rules": "A relay of stations against the clock. Each one refuels and repairs you, and its pit shop sells pickups for run coins."},
	M.DEFENSE: {"name": "DEFENSE", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "score", "goons": "full",
		"description": "Hold the station until the clock runs out. Goons march on its pumps and blow up when they reach them: crush them before they get there.",
		"rules": "Barricade Kits patch the station's walls and Sentry Turrets help guard them."},
	M.GOONPOCALYPSE: {"name": "GOONPOCALYPSE", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "score", "goons": "full",
		"description": "Endless, and it only gets worse. Survive the target for the star, then chase your best score.",
		"rules": "No finish line. The clock counts up, and the run lasts as long as you do."},
	M.BLACKOUT: {"name": "BLACKOUT", "category": Category.CRUSHER, "plays": M.GOONCRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "crushes", "goons": "full",
		"description": "The sun never comes up. Survive the countdown with nothing but your headlights to show the goons.",
		"rules": "Night falls at the start and stays. Still driving when the clock hits zero? You win."},
	M.BOUNTY: {"name": "BOUNTY HUNT", "category": Category.CRUSHER, "map": Map.RANDOM, "pickups": Drops.ALL, "boxes": true, "record": "time", "goons": "full",
		"description": "Marked goons, one per district, each tougher than the last. The pointer shows the next mark.",
		"rules": "Crush every mark before the clock runs out."},
	M.RALLY: {"name": "RALLY STAGE", "category": Category.TRIAL, "plays": M.SPRINT, "map": Map.FIXED, "pickups": Drops.NONE, "boxes": false, "record": "time", "goons": "none",
		"description": "A marked stage over the level's worst ground, with a split time at every checkpoint.",
		"rules": "Pass every checkpoint and beat the medal time. The stage is the same every run."},
	M.FLATOUT: {"name": "FLAT OUT", "category": Category.TRIAL, "plays": M.SPRINT, "map": Map.FIXED, "pickups": Drops.PLACED, "kinds": ["boost"], "boxes": false, "record": "time", "goons": "none",
		"description": "Flat out due east to the station, with nitro at every checkpoint. Arrive too fast to stop and it costs you.",
		"rules": "Beat the medal time. Nitro sits at the same spots every run; crossing the line over the stop speed adds two seconds."},
	M.HOTLAP: {"name": "HOT LAP", "category": Category.TRIAL, "map": Map.FIXED, "pickups": Drops.NONE, "boxes": false, "record": "lap", "goons": "none",
		"description": "A closed loop and three laps. Your best run drives ahead of you as a ghost.",
		"rules": "The best of three laps counts. Beat the medal lap."},
	M.DRIFT: {"name": "DRIFT TRIAL", "category": Category.TRIAL, "map": Map.FIXED, "pickups": Drops.NONE, "boxes": false, "record": "score", "goons": "none",
		"description": "Marked corners score by how long and how hard you hold the slide.",
		"rules": "Reach the medal score in one pass."},
	M.CONES: {"name": "CONE COURSE", "category": Category.TRIAL, "map": Map.FIXED, "pickups": Drops.NONE, "boxes": false, "record": "time", "goons": "none",
		"description": "Gates, a slalom and a handbrake box. Tight, technical and over fast.",
		"rules": "Beat the medal time. Every cone you knock over adds a second."},
	M.SMASH: {"name": "SMASH RUN", "category": Category.TRIAL, "map": Map.FIXED, "pickups": Drops.PLACED, "kinds": ["boost"], "boxes": false, "record": "score", "goons": "none",
		"description": "The stage is lined with things that break. Rocks and walls still hurt.",
		"rules": "Smash the quota before the clock runs out."},
	M.CANNONBALL: {"name": "CANNONBALL", "category": Category.CUP, "plays": M.SPRINT, "rivals": true, "map": Map.RANDOM, "pickups": Drops.PLACED, "kinds": ["supply", "boost", "gadget", "move", "loot"], "boxes": true, "record": "wins", "goons": "light",
		"description": "Five rivals, one station, no set route. Shortcuts through water and fences are fair.",
		"rules": "Reach the pumps in a paying place."},
	M.CIRCUIT: {"name": "CIRCUIT RACE", "category": Category.CUP, "rivals": true, "map": Map.FIXED, "pickups": Drops.PLACED, "kinds": ["boost", "gadget"], "boxes": false, "record": "time", "goons": "none",
		"description": "Three laps of a track cut through the level, against five rivals.",
		"rules": "Finish in a paying place."},
	M.DERBY: {"name": "DEMOLITION DERBY", "category": Category.CUP, "rivals": true, "map": Map.FIXED, "pickups": Drops.PLACED, "kinds": ["repair", "armor", "gadget"], "boxes": true, "record": "score", "goons": "none",
		"description": "Six cars on a lot and no rules. Hits hurt far more here, and leaving the painted line costs health.",
		"rules": "Be the last car running."},
	M.KNOCKOUT: {"name": "KNOCKOUT", "category": Category.CUP, "rivals": true, "map": Map.FIXED, "pickups": Drops.PLACED, "kinds": ["boost", "gadget"], "boxes": false, "record": "wins", "goons": "none",
		"description": "Last place is cut at the end of every lap until one car is left.",
		"rules": "Be the one left."},
	M.KEEPCUP: {"name": "KEEP THE CUP", "category": Category.CUP, "rivals": true, "map": Map.RANDOM, "pickups": Drops.PLACED, "kinds": ["boost", "gadget", "move"], "boxes": false, "record": "time", "goons": "none",
		"description": "One trophy on the map and six cars after it. Whoever holds it banks time.",
		"rules": "The first car to hold the cup for the tier's time wins. Get close to whoever has it to take it."},
	M.PURSUIT: {"name": "PURSUIT", "category": Category.CUP, "plays": M.SPRINT, "rivals": true, "map": Map.RANDOM, "pickups": Drops.PLACED, "kinds": ["supply", "boost", "gadget", "move", "loot"], "boxes": true, "record": "time", "goons": "light",
		"description": "One of the other drivers runs for the station with a head start.",
		"rules": "Ram them until they wreck. If they reach the station, they got away."},
}

## The featured modes of a level whose def names none (a def from before the mode menu, a test's stand-in)
const DEFAULT_FEATURED := [M.MARATHON, M.RALLY, M.CANNONBALL]

static func get_def(mode: int) -> Dictionary:
	return DATA.get(mode, {})

## The mode for an id ("rally"), or -1
static func byId(id) -> int:
	return IDS.find(str(id))

static func idOf(mode: int) -> String:
	return IDS[mode] if mode >= 0 && mode < IDS.size() else ""

static func category(mode: int) -> int:
	return get_def(mode).get("category", Category.CRUSHER)

static func categoryName(mode: int) -> String:
	return CATEGORY_NAMES[category(mode)]

static func categoryColor(mode: int) -> Color:
	return CATEGORY_COLORS[category(mode)]

## The mode whose run rules this one uses: itself, or the mode a variant is built on (Blackout: Countdown)
static func plays(mode: int) -> int:
	return get_def(mode).get("plays", mode)

## The run rules of the run being set up or played: plays() of the save's mode. Run code branches on this.
static func running() -> int:
	return plays(SaveManager.playerData.gameMode)

## "Rally Stage": the name inside a sentence
static func title(mode: int) -> String:
	return str(get_def(mode).get("name", "")).capitalize()

static func isFixedMap(mode: int) -> bool:
	return get_def(mode).get("map", Map.RANDOM) == Map.FIXED

## Does the mode have goons at all (its spawners, the wave clock and its stars)
static func hasGoons(mode: int) -> bool:
	return get_def(mode).get("goons", "full") != "none"

## What the world hands out: Drops.ALL (rolled drops, supply drops and events, the level's chunk pickups),
## PLACED (fixed spots only) or NONE
static func drops(mode: int) -> int:
	return get_def(mode).get("pickups", Drops.ALL)

## Does the mode put the other drivers on the map (Rivals)
static func hasRivals(mode: int) -> bool:
	return get_def(mode).get("rivals", false)

## A thin crowd: goons on the road for something to crush, far fewer than a Crusher mode's
static func lightGoons(mode: int) -> bool:
	return get_def(mode).get("goons", "full") == "light"

## Can a pickup of this kind (Pickups.KIND_KEYS) turn up in the mode: any in a mode that rolls everything, only
## its own `kinds` where they are limited to what is useful there, none in a mode with no pickups
static func allowsKind(mode: int, kind: String) -> bool:
	match drops(mode):
		Drops.ALL: return true
		Drops.PLACED: return kind in get_def(mode).get("kinds", [])
	return false

## A Trial is the car against the course: no goons, no night, and the tank doesn't run down
static func isTrial(mode: int) -> bool:
	return category(mode) == Category.TRIAL

static func fillsBoxes(mode: int) -> bool:
	return get_def(mode).get("boxes", true)

## Every mode of a category, in Root.gameModes order
static func inCategory(cat: int) -> Array:
	return DATA.keys().filter(func(m): return DATA[m].category == cat)

## A level's three featured modes, Crusher then Trial then Goon Cup (LevelDef.featured, as ids)
static func featured(def: LevelDef) -> Array:
	var out := []
	for id in (def.featured if def else []):
		var mode := byId(id)
		if mode >= 0 && mode not in Root.STAPLE_MODES && mode not in out: out.push_back(mode)
	return out if not out.is_empty() else DEFAULT_FEATURED.duplicate()

## Root.gameModeDescription: mode -> {name, description}
static func descriptions() -> Dictionary:
	var out := {}
	for mode in DATA: out[mode] = {"name": DATA[mode].name, "description": DATA[mode].description}
	return out

## Root.MODE_RULES: mode -> how it is won
static func rulesTexts() -> Dictionary:
	var out := {}
	for mode in DATA: out[mode] = DATA[mode].rules
	return out
