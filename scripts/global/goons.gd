class_name Goons extends RefCounted
## Every goon: faction, regions, rank, behaviour (verb) and tuning. The art and shapes are baked into
## scene/enemy/goons/<id>/ by scripts/art/bake_goons.py; everything you tune lives here. See docs/GOONS.md.

enum faction { WILD, TRIBE, SCRAP }
const FACTION_NAMES := ["Wild Things", "Goon Tribe", "Scrap Gang"]

## Distance scoring: score = distance from the start in chunks × DISTANCE_WEIGHT (+ level index × LEVEL_WEIGHT
## in factionFor, the fallback without a level) ± FACTION_JITTER. A level's districts use the same score for
## their zone (Territories.zoneFor: below WILD_BELOW zone 0, below TRIBE_BELOW zone 1, else zone 2).
const DISTANCE_WEIGHT := 0.35
const LEVEL_WEIGHT := 0.3
const FACTION_JITTER := 0.4
const WILD_BELOW := 1.0
const TRIBE_BELOW := 2.2
const CHUNK_PX := 5120.0
## The bake's resolution (RES in scripts/art/bake_goons.html): frames hold ART_RES texture px per game px,
## and each goon's sprite is scaled 1 / ART_RES. test_goons.gd checks the baked scenes agree.
const ART_RES := 2.0

## Wave mix: chance (in %) that a spawn uses the region's goon 1, 2 or 3, by the region's wave (1-4).
## Matches the HUD, which reveals goons 2 and 3 as the waves come.
const WAVE_MIX := [[95, 5, 0], [70, 30, 0], [50, 30, 20], [40, 30, 30]]

## Mirrors Root.terrain (same order; test_goons.gd checks it), because an autoload's enum can't be used in a const.
enum T { GRASS, SAND, MUD, WATER, HILLS, MOSS, DIRT, SNOW, ASPHALT, ICE, OIL, SHALLOWS, WASH, CONVEYOR, MUDPIT, DEEPSNOW, LOT, BUILDING, BRIDGE, WADE }
## Tuning keys (all optional, defaults in walker.gd): speed (px/s), windDist (px), windT, atkT, recT (s),
## lunge (speed multiplier while attacking), dmg (health its attack takes from a car with no armor; docs/CAR_ART.md), sys (car system the attack wears),
## crush (crush speed px/s), front (head-on crush speed; 0 = none), arc (half-width of the front in radians, default 1.05), turn (rad/s), pack (spawn group size),
## tele (telegraph: arrow, ring, land, aim, crack, none). rank: 1 fodder, 2 special, 3 heavy.
## Wild instincts (docs/GOONS.md, "Wild instincts"): seeks (props it goes for, SEEK_* below), smashes (its attack
## breaks breakables it is fast enough for), tramples (its attack flattens rank-1 goons in its way), daze (a lunge
## into a wall dazes it, on levels whose LevelDef rules has dazeHeavies).
## Tiers: Scrap Gang hits hardest per hit (they hit less often, since they peel off), then Tribe, then Wild.
## A stock sedan tops out near 433 px/s, so crush thresholds stay at or under 400: heavies need near-top speed, not upgrades.
## seeks rows: [group, action, carRange, goonRange]. Every SEEK_EVERY seconds the goon looks for the nearest prop
## of the group (BreakableProp.GROUPS) within goonRange of it, rows in order. carRange > 0: the car must be within
## carRange of the goon and of the prop (it acts where the player sees it); < 0: the car must be farther than
## -carRange from the goon (it acts while the car keeps away); 0: anywhere. Actions (GoonVerbs.Verb.seekProp):
##   release  run to a log pile and cut it loose at the car (Spill.goonRelease)
##   knock    break a hive near the car; its swarm hunts the nearest goons, often the goon's own pack
##   raid     break it open (a crate, a hive) and steal what spills (the Thief takes pickups first)
##   perch    land on it and feed until the car comes at it (a carcass, like a crush decal)
##   roost    sit in its crown out of reach until rammed down (Spill.ROOSTS: dead trees; scarecrows later)
## Extension points: a den's "stash" (R-6) and a burrow's "hide" (R-7) come in as new actions here.
const SEEKS_RELEASE := [[&"prop_logpile", &"release", 900.0, 650.0]]
const SEEK_EVERY := 0.5

const DATA := {
	#---------------------------------------------------------------- Wild Things (tier 1)
	&"jackalope": {"name":"Jackalope", "faction":faction.WILD, "rank":1, "biomes":[T.GRASS, T.MOSS, T.SNOW], "verb":&"hopper",
		"speed":170, "windDist":120, "windT":0.35, "atkT":0.3, "lunge":2.6, "dmg":2, "sys":"tires"},
	&"tusker": {"name":"Tusker", "faction":faction.WILD, "rank":2, "biomes":[T.GRASS, T.MUD], "verb":&"charger",
		"speed":110, "windDist":380, "windT":0.7, "atkT":1.1, "lunge":3.6, "dmg":6, "sys":"engine", "front":280, "smashes":true, "tramples":true},
	&"bandit": {"name":"Bandit", "faction":faction.WILD, "rank":1, "biomes":[T.GRASS, T.DIRT], "verb":&"thief", "speed":150,
		"seeks":[[&"prop_crate", &"raid", 0.0, 600.0], [&"prop_hive", &"raid", 0.0, 600.0]]},
	&"stinger": {"name":"Stinger", "faction":faction.WILD, "rank":2, "biomes":[T.SAND], "verb":&"striker",
		"speed":100, "windDist":130, "windT":0.6, "atkT":0.35, "dmg":4, "sys":"steering", "tele":"ring"},
	&"buzzard": {"name":"Buzzard", "faction":faction.WILD, "rank":1, "biomes":[T.SAND, T.DIRT], "verb":&"flyer",
		"speed":240, "windDist":380, "windT":0.7, "atkT":0.6, "lunge":2.4, "dmg":2, "sys":"lights",
		"seeks":[[&"prop_carcass", &"perch", -260.0, 500.0], [&"prop_roost", &"roost", -260.0, 900.0]]},
	&"rattler": {"name":"Rattler", "faction":faction.WILD, "rank":1, "biomes":[T.SAND, T.DIRT], "verb":&"striker",
		"speed":90, "windDist":115, "windT":0.5, "atkT":0.3, "dmg":3, "sys":"tires", "tele":"ring"},
	&"quill": {"name":"Quill", "faction":faction.WILD, "rank":2, "biomes":[T.SAND, T.DIRT], "verb":&"spiky",
		"speed":80, "windDist":200, "windT":0.6, "dmg":2, "sys":"tires", "tele":"ring"},
	&"spitter": {"name":"Spitter", "faction":faction.WILD, "rank":2, "biomes":[T.MOSS, T.MUD], "verb":&"lobber",
		"speed":80, "range":[260, 340], "windT":0.7, "cd":2.6, "hazard":"slime", "sys":"tires", "tele":"land"},
	&"snapper": {"name":"Snapper", "faction":faction.WILD, "rank":3, "biomes":[T.MUD, T.MOSS], "verb":&"burrow",
		"speed":60, "atkT":0.35, "lunge":4.5, "dmg":6, "sys":"tires", "log":true, "tramples":true},
	&"yipper": {"name":"Yipper", "faction":faction.WILD, "rank":1, "biomes":[T.DIRT, T.SNOW], "verb":&"pack",
		"speed":175, "windDist":70, "windT":0.25, "atkT":0.25, "lunge":2.5, "recT":0.5, "dmg":2, "sys":"tank", "pack":4, "flank":true,
		"seeks":[[&"prop_logpile", &"release", 900.0, 650.0], [&"prop_hive", &"knock", 900.0, 650.0]]},
	&"bullmoose": {"name":"Bullmoose", "faction":faction.WILD, "rank":3, "biomes":[T.SNOW], "verb":&"lunge",
		"speed":70, "windDist":220, "windT":0.9, "atkT":0.7, "lunge":3.4, "dmg":8, "sys":"engine", "crush":400, "tele":"ring", "wander":true,
		"smashes":true, "tramples":true, "daze":true},
	&"thunderhoof": {"name":"Thunderhoof", "faction":faction.WILD, "rank":3, "biomes":[T.GRASS, T.DIRT], "verb":&"herd",
		"speed":150, "dmg":5, "sys":"engine", "crush":300, "pack":5, "tramples":true},

	#---------------------------------------------------------------- Goon Tribe (tier 2)
	&"grunt": {"name":"Grunt", "faction":faction.TRIBE, "rank":1, "biomes":[T.GRASS], "verb":&"lunge",
		"speed":110, "windDist":150, "windT":0.55, "atkT":0.38, "lunge":3.4, "recT":0.7, "dmg":3, "seeks":SEEKS_RELEASE},
	&"goonling": {"name":"Goonling", "faction":faction.TRIBE, "rank":0, "biomes":[], "verb":&"lunge",
		"speed":150, "windDist":110, "windT":0.4, "atkT":0.3, "lunge":3.0, "recT":0.5, "dmg":1},
	&"hubcap": {"name":"Hubcap", "faction":faction.TRIBE, "rank":2, "biomes":[T.GRASS, T.MUD], "verb":&"lunge",
		"speed":95, "turn":1.8, "windDist":150, "windT":0.6, "atkT":0.38, "lunge":3.0, "dmg":3, "sys":"lights", "front":380, "shield":true},
	&"dasher": {"name":"Dasher", "faction":faction.TRIBE, "rank":2, "biomes":[T.GRASS], "verb":&"dodger",
		"speed":185, "windDist":170, "windT":0.35, "atkT":0.3, "lunge":2.8, "recT":0.5, "dmg":2, "sys":"steering"},
	&"torch": {"name":"Torch", "faction":faction.TRIBE, "rank":2, "biomes":[T.SAND], "verb":&"lobber",
		"speed":120, "range":[300, 380], "windT":0.8, "cd":2.4, "hazard":"fire", "sys":"tires", "tele":"land", "deathFire":true},
	&"spiker": {"name":"Spiker", "faction":faction.TRIBE, "rank":2, "biomes":[T.GRASS], "verb":&"trapper", "speed":150, "hazard":"spikes", "sys":"tires"},
	&"yeti": {"name":"Yeti", "faction":faction.TRIBE, "rank":3, "biomes":[T.SNOW], "verb":&"lunge",
		"speed":120, "windDist":260, "windT":0.8, "atkT":0.6, "lunge":3.6, "recT":0.9, "dmg":6, "sys":"engine", "crush":360, "tele":"ring"},
	&"doomcart": {"name":"Doomcart", "faction":faction.TRIBE, "rank":3, "biomes":[T.DIRT], "verb":&"bomber", "speed":150, "fuseDist":260, "fuseT":2.2, "blast":130, "dmg":10},
	&"gremlin": {"name":"Gremlin", "faction":faction.TRIBE, "rank":2, "biomes":[T.MOSS, T.DIRT], "verb":&"hitcher",
		"speed":210, "windDist":170, "windT":0.35, "sys":"engine"},
	&"shellback": {"name":"Shellback", "faction":faction.TRIBE, "rank":2, "biomes":[T.SAND, T.MOSS], "verb":&"turtle",
		"speed":95, "windDist":110, "windT":0.5, "atkT":0.3, "lunge":2.6, "dmg":3},
	&"foreman": {"name":"Foreman", "faction":faction.TRIBE, "rank":3, "biomes":[T.MUD], "verb":&"boss", "speed":85, "range":[300, 380], "aura":260, "buff":1.35},
	&"skink": {"name":"Skink", "faction":faction.TRIBE, "rank":2, "biomes":[T.MOSS, T.SNOW], "verb":&"burrow",
		"speed":85, "atkT":0.3, "lunge":4.5, "dmg":3, "sys":"tires"},
	&"rat": {"name":"Rat Pack", "faction":faction.TRIBE, "rank":1, "biomes":[T.MOSS], "verb":&"pack",
		"speed":150, "windDist":60, "windT":0.2, "atkT":0.25, "lunge":2.5, "recT":0.4, "dmg":1, "sys":"tires", "pack":6},
	&"boulder": {"name":"Boulder", "faction":faction.TRIBE, "rank":3, "biomes":[T.DIRT, T.SNOW], "verb":&"roller", "speed":85, "windDist":420, "windT":0.7, "dmg":8},
	&"nightcrawler": {"name":"Nightcrawler", "faction":faction.TRIBE, "rank":1, "biomes":[T.SAND, T.DIRT, T.SNOW], "verb":&"lunge",
		"speed":125, "windDist":120, "windT":0.4, "atkT":0.35, "lunge":3.2, "recT":0.6, "dmg":3, "sys":"lights", "night":true},
	&"wrecker": {"name":"Wrecker", "faction":faction.TRIBE, "rank":3, "biomes":[T.MUD], "verb":&"slammer", "speed":75, "windDist":150, "windT":0.9, "dmg":12, "sys":"engine"},
	&"slinger": {"name":"Slinger", "faction":faction.TRIBE, "rank":2, "biomes":[T.GRASS, T.MUD], "verb":&"shooter",
		"speed":100, "range":[320, 420], "windT":0.6, "cd":1.8, "dmg":2, "sys":"lights", "tele":"aim"},
	&"rammer": {"name":"Rammer", "faction":faction.TRIBE, "rank":3, "biomes":[T.MUD], "verb":&"charger",
		"speed":90, "windDist":440, "windT":0.7, "atkT":1.4, "lunge":4.2, "recT":1.2, "dmg":8, "sys":"engine", "front":320, "smashes":true},
	&"splitter": {"name":"Splitter", "faction":faction.TRIBE, "rank":1, "biomes":[T.MUD], "verb":&"lunge",
		"speed":80, "windDist":140, "windT":0.6, "atkT":0.4, "lunge":3.0, "recT":0.8, "dmg":3, "split":&"goonling", "seeks":SEEKS_RELEASE},

	#---------------------------------------------------------------- Scrap Gang (tier 3): anything with an engine or wheels
	&"spoke": {"name":"Spoke", "faction":faction.SCRAP, "rank":1, "biomes":[T.GRASS, T.SAND, T.DIRT, T.MUD], "verb":&"rider",
		"speed":300, "act":"ram", "dmg":8, "sys":"engine", "front":240},
	&"chainer": {"name":"Chainer", "faction":faction.SCRAP, "rank":2, "biomes":[T.GRASS, T.SAND, T.DIRT], "verb":&"rider",
		"speed":270, "act":"swipe", "dmg":6, "sys":"steering", "front":240},
	&"torcher": {"name":"Torcher", "faction":faction.SCRAP, "rank":2, "biomes":[T.SAND, T.DIRT], "verb":&"rider",
		"speed":320, "act":"burn", "sys":"tires", "front":240},
	&"harpooner": {"name":"Harpooner", "faction":faction.SCRAP, "rank":3, "biomes":[T.MUD, T.SNOW, T.DIRT], "verb":&"rider",
		"speed":260, "act":"harpoon", "sys":"steering", "front":240},
	&"sidecar": {"name":"Sidecar", "faction":faction.SCRAP, "rank":2, "biomes":[T.GRASS, T.MUD, T.SAND], "verb":&"rider",
		"speed":280, "act":"bomb", "dmg":9, "sys":"hull", "front":240},
	&"plowboss": {"name":"Plowboss", "faction":faction.SCRAP, "rank":3, "biomes":[T.MUD, T.SNOW, T.DIRT], "verb":&"rider",
		"speed":200, "act":"ram", "dmg":12, "sys":"engine", "front":99999, "arc":0.75, "crush":200},
	&"karter": {"name":"Karter", "faction":faction.SCRAP, "rank":1, "biomes":[T.GRASS, T.MOSS, T.MUD], "verb":&"rider",
		"speed":280, "act":"tailgate", "dmg":5, "sys":"tank", "front":200},
	&"slick": {"name":"Slick", "faction":faction.SCRAP, "rank":2, "biomes":[T.GRASS, T.SAND, T.MOSS], "verb":&"rider",
		"speed":260, "act":"oil", "sys":"tires", "front":240, "crush":220},
	&"boostjack": {"name":"Boostjack", "faction":faction.SCRAP, "rank":2, "biomes":[T.DIRT, T.SNOW, T.MOSS], "verb":&"rider",
		"speed":200, "act":"boost", "dmg":12, "blast":110},
	&"shredder": {"name":"Shredder", "faction":faction.SCRAP, "rank":2, "biomes":[T.MUD, T.SNOW, T.MOSS], "verb":&"rider",
		"speed":270, "act":"swipe", "dmg":5, "sys":"tires", "front":240},
	&"sawbot": {"name":"Sawbot", "faction":faction.SCRAP, "rank":1, "biomes":[T.SNOW, T.MOSS, T.GRASS], "verb":&"rider",
		"speed":240, "act":"saw", "dmg":5, "sys":"tires"},
	&"turret": {"name":"Turret", "faction":faction.SCRAP, "rank":2, "biomes":[T.SAND, T.SNOW, T.GRASS, T.MOSS], "verb":&"rider",
		"speed":140, "act":"shoot", "range":[360, 480], "windT":0.6, "cd":1.6, "dmg":3, "sys":"lights", "tele":"aim"},
	&"magnet": {"name":"Magnet", "faction":faction.SCRAP, "rank":3, "biomes":[T.DIRT, T.SNOW, T.MUD, T.MOSS], "verb":&"rider",
		"speed":220, "act":"magnet", "sys":"steering", "crush":200},
}

## The six goon classes (docs/GOONS.md, "Classes"): the goons a region may field (Territories). A goon keeps
## its faction (colours, goo, drops, the EMP's target, the crushed:<faction> counters); a class is only a list.
## The first three are the factions' own (every rank-1+ member; the Goonling is spawn-only); the three elite
## classes are themed squads drawn from every faction. A level's line-up (LevelDef.lineup) is 3-6 of its
## region's class.
const CLASSES := {
	&"wild": {"name": "Wild Things", "faction": faction.WILD, "members": [&"jackalope", &"tusker", &"bandit", &"stinger", &"buzzard",
		&"rattler", &"quill", &"spitter", &"snapper", &"yipper", &"bullmoose", &"thunderhoof"]},
	&"tribe": {"name": "Goon Tribe", "faction": faction.TRIBE, "members": [&"grunt", &"hubcap", &"dasher", &"torch", &"spiker", &"yeti",
		&"doomcart", &"gremlin", &"shellback", &"foreman", &"skink", &"rat", &"boulder", &"nightcrawler", &"wrecker", &"slinger", &"rammer", &"splitter"]},
	&"scrap": {"name": "Scrap Gang", "faction": faction.SCRAP, "members": [&"spoke", &"chainer", &"torcher", &"harpooner", &"sidecar",
		&"plowboss", &"karter", &"slick", &"boostjack", &"shredder", &"sawbot", &"turret", &"magnet"]},
	&"biggame": {"name": "Big Game", "faction": -1, "members": [&"tusker", &"thunderhoof", &"bullmoose", &"snapper", &"yeti", &"boulder",
		&"wrecker", &"rammer", &"plowboss", &"harpooner"]},
	&"swarm": {"name": "Street Swarm", "faction": -1, "members": [&"rat", &"yipper", &"jackalope", &"bandit", &"splitter", &"dasher",
		&"gremlin", &"karter", &"spoke", &"sawbot"]},
	&"warmachine": {"name": "War Machine", "faction": -1, "members": [&"doomcart", &"torch", &"torcher", &"spitter", &"slinger", &"turret",
		&"sidecar", &"boostjack", &"magnet", &"foreman"]},
}
const CLASS_ORDER: Array[StringName] = [&"wild", &"tribe", &"scrap", &"biggame", &"swarm", &"warmachine"]

static func classMembers(id: StringName) -> Array:
	return CLASSES.get(StringName(id), {}).get("members", [])

static func className(id: StringName) -> String:
	return CLASSES.get(StringName(id), {}).get("name", String(id).capitalize())

## An elite class draws from every faction (Big Game, Street Swarm, War Machine)
static func isElite(id: StringName) -> bool:
	return int(CLASSES.get(StringName(id), {}).get("faction", -1)) < 0

## The classes a goon plays in
static func classesOf(goon: StringName) -> Array:
	return CLASS_ORDER.filter(func(c): return goon in classMembers(c))

static func scenePath(id: StringName) -> String:
	return "res://scene/enemy/goons/%s/%s.tscn" % [id, id]

static func factionName(f: int) -> String:
	return FACTION_NAMES[clampi(f, 0, FACTION_NAMES.size() - 1)]

## Ids of a faction's goons that live in a terrain, sorted by rank (fodder first). Rank 0 never spawns from regions.
static func pool(f: int, terrain: int) -> Array:
	var out := []
	for id in DATA:
		var d: Dictionary = DATA[id]
		if d.faction == f && d.rank > 0 && terrain in d.biomes: out.push_back(id)
	out.sort_custom(func(a, b): return DATA[a].rank < DATA[b].rank)
	return out

## The faction holding a region `distancePx` from the start on level `levelIndex` (0 = first level).
static func factionFor(distancePx: float, levelIndex: int, jitter: float) -> int:
	var score := distancePx / CHUNK_PX * DISTANCE_WEIGHT + levelIndex * LEVEL_WEIGHT + jitter
	if score < WILD_BELOW: return faction.WILD
	if score < TRIBE_BELOW: return faction.TRIBE
	return faction.SCRAP

## A region's three goons: a fodder goon first, then two specials or heavies, all from one faction.
## Falls back to the faction's lowest ranks when a terrain has few goons of a rank.
static func regionGoons(f: int, terrain: int, rng: RandomNumberGenerator) -> Array:
	var ids := pool(f, terrain)
	if ids.is_empty(): ids = pool(faction.TRIBE, T.GRASS)
	var low := ids.filter(func(id): return DATA[id].rank == 1)
	var high := ids.filter(func(id): return DATA[id].rank >= 2)
	if low.is_empty(): low = [ids[0]]
	if high.is_empty(): high = ids
	var first = low[rng.randi() % low.size()]
	for i in range(high.size() - 1, 0, -1): #seeded shuffle, so a seeded run picks the same goons
		var j := rng.randi() % (i + 1)
		var swap = high[i]; high[i] = high[j]; high[j] = swap
	var rest := high.filter(func(id): return id != first)
	while rest.size() < 2: rest.push_back(ids[rng.randi() % ids.size()])
	return [first, rest[0], rest[1]]

## Which of a region's three goons to spawn, by its wave (WAVE_MIX).
static func pickSlot(wave: int, roll: float) -> int:
	var mix: Array = WAVE_MIX[clampi(wave, 1, WAVE_MIX.size()) - 1]
	var r := roll * 100.0
	for i in 3:
		r -= mix[i]
		if r < 0.0: return i
	return 0
