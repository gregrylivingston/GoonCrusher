class_name Territories extends RefCounted
## The six regions of the road atlas (docs/WORLD.md, "Regions"). The code name is Territories because the Region
## autoload already means a run's districts. A region is who lives there: its goon class (Goons.CLASSES), the
## props it lays over each landscape, its landmark, the first words of its district names, its color and an
## elite strength step. Its five levels (LevelDef.region, LevelDef.stop) can sit in different landscapes.
##
##   name, color     the menus' name and color
##   class           its goon class (Goons.CLASSES); every level's line-up comes from it
##   landmark        the prop every district's landmark is (props.json, with a beacon; WorldSkin.LANDMARKS)
##   nameFirst       district names' first words; the landscape gives the second (Landscape.nameSecond)
##   dressing        the region's own props by zone ({prop id: weight}, zone 0 near the start, 2 far out), laid
##                   over the landscape's natural dressing so its share rises as you drive out
##   motifs          the same for set pieces (WorldSkin.MOTIFS)
##   heroes          the same for heroes ({prop or motif id: [weight, anchor]}, ChunkRecipe.placeHeroes), under
##                   the level's own (LevelDef.heroes)
##   step            the elite strength step, applied when a goon spawns (Walker): speed, damage and the crush
##                   speed needed, as multipliers. The factions' regions are x1.
##   demo            in the demo
## Every number is a placeholder for the pacing pass (docs/roadmap/).

const ORDER: Array[StringName] = [&"wilds", &"tribe", &"raiders", &"hunting", &"sprawl", &"works"]
const STOPS := 5 #levels per region; the 5th is its finale

const DATA := {
	&"wilds": {"name": "The Wilds", "color": Color("#8fbf55"), "class": &"wild", "demo": true,
		"landmark": &"landmark_wild",
		"nameFirst": ["Tusker", "Jackalope", "Thornback", "Wildroot", "Howling", "Bramble", "Snapjaw", "Feral", "Burrow", "Antler"],
		#crates everywhere (the Bandit's raids; one crate kind, the baked one) and crate stashes; hives as heroes from zone 1
		"dressing": [{&"carcass": 1, &"beehive": 1, &"crate": 1}, {&"carcass": 1, &"beehive": 1, &"bones": 2, &"crate": 1}, {&"carcass": 2, &"beehive": 2, &"bones": 3, &"crate": 1}],
		"motifs": [{&"cratestash": 0.3}, {&"cratestash": 0.4}, {&"boneyard": 1, &"cratestash": 0.4}],
		"heroes": [{&"cratestash": [1.0, "any"]}, {&"cratestash": [1.0, "any"], &"beehive": [0.5, "any"]}, {&"cratestash": [1.0, "any"], &"beehive": [1.0, "any"]}],
		"step": {"speed": 1.0, "damage": 1.0, "crush": 1.0},
		"blurb": "Critter country from farmland to swamp to red rock. The Wild Things teach crush speed."},
	&"tribe": {"name": "Tribe Country", "color": Color("#4fb39b"), "class": &"tribe", "demo": true,
		"landmark": &"landmark_tribe",
		"nameFirst": ["Totem", "Warpaint", "Grunt", "Bonefire", "Drumskull", "Spearhead", "Mudmask", "Hubcap", "Tusk", "Warband"],
		"dressing": [{&"totem": 1, &"tent": 1}, {&"tent": 2, &"totem": 1, &"firepit": 1, &"crate": 2}, {&"tent": 2, &"totem": 2, &"firepit": 2, &"crate": 2, &"fortwall": 1}],
		"motifs": [{}, {&"camp": 1}, {&"camp": 3}],
		"step": {"speed": 1.0, "damage": 1.0, "crush": 1.0},
		"blurb": "The Tribe's villages, camps and dig sites, from swamp villages to the Foreman's quarry."},
	&"raiders": {"name": "Raider Road", "color": Color("#e07a52"), "class": &"scrap", "demo": false,
		"landmark": &"landmark_scrap",
		"nameFirst": ["Rust", "Sprocket", "Gearhead", "Scrapper", "Chrome", "Piston", "Rivet", "Junker", "Sawtooth", "Busted"],
		"dressing": [{&"tires": 1, &"wreck": 1}, {&"tires": 2, &"wreck": 2, &"barrel": 1, &"barricade": 1}, {&"tires": 2, &"wreck": 3, &"barrel": 2, &"barricade": 2, &"scrapheap": 1}],
		"motifs": [{}, {&"wreckpile": 1}, {&"wreckpile": 2, &"roadblock": 1}],
		"step": {"speed": 1.0, "damage": 1.0, "crush": 1.0},
		"blurb": "The open road and the towns along it. The Scrap Gang rides everything with wheels."},
	&"hunting": {"name": "Hunting Grounds", "color": Color("#6aa9dc"), "class": &"biggame", "demo": false,
		"landmark": &"landmark_big",
		"nameFirst": ["Trophy", "Bigfoot", "Skull", "Mammoth", "Horn", "Stampede", "Hunter's", "Thunder", "Bone", "Grizzly"],
		"dressing": [{&"bones": 2, &"carcass": 1}, {&"bones": 3, &"carcass": 2, &"hunting_stand": 1}, {&"bones": 4, &"carcass": 3, &"hunting_stand": 2}],
		"motifs": [{}, {}, {&"boneyard": 1}],
		"step": {"speed": 1.0, "damage": 1.1, "crush": 1.1},
		"blurb": "Where the big ones live: snow, timber and tar. Build a run-up, then hit."},
	&"sprawl": {"name": "The Sprawl", "color": Color("#a688d3"), "class": &"swarm", "demo": false,
		"landmark": &"landmark_swarm",
		"nameFirst": ["Ratrun", "Alley", "Dumpster", "Gutter", "Sewer", "Graffiti", "Backlot", "Pack", "Scurry", "Stoop"],
		"dressing": [{&"dumpster": 1, &"trashbags": 1}, {&"dumpster": 2, &"trashbags": 2, &"crate": 1, &"manhole": 1}, {&"dumpster": 3, &"trashbags": 3, &"crate": 2, &"manhole": 2, &"paint": 2}],
		"motifs": [{}, {}, {}],
		"step": {"speed": 1.1, "damage": 1.1, "crush": 1.05},
		"blurb": "City, suburbs and the jammed roads between. Packs and thieves: combos pay, crowds kill."},
	&"works": {"name": "The Works", "color": Color("#d6ad3e"), "class": &"warmachine", "demo": false,
		"landmark": &"landmark_war",
		"nameFirst": ["Furnace", "Smoke", "Slag", "Boiler", "Forge", "Cinder", "Gauge", "Valve", "Ironclad", "Blast"],
		"dressing": [{&"barrel": 1}, {&"barrel": 2, &"tank": 1, &"oilstain": 2}, {&"barrel": 3, &"tank": 2, &"crane": 1, &"oilstain": 3, &"container": 1}],
		"motifs": [{}, {&"junkyard": 1}, {&"junkyard": 2}],
		"step": {"speed": 1.1, "damage": 1.2, "crush": 1.1},
		"blurb": "Pits, foundries and yards. Everything that shoots, burns or blows up. Close the gap fast."},
}

## Sprint's station distance (px) by region, first to last (Level.sprintDistance): the drive grows with the road.
## A Sprint is this x its tier's ModeTiers.SPRINT_DISTANCE, a Marathon leg this x its index 0.
const SPRINT_DISTANCE := Vector2(20000.0, 28000.0)
const NO_STEP := {"speed": 1.0, "damage": 1.0, "crush": 1.0}

static func has(id: StringName) -> bool:
	return DATA.has(StringName(id))

static func get_def(id: StringName) -> Dictionary:
	return DATA.get(StringName(id), {})

static func indexOf(id: StringName) -> int:
	return ORDER.find(StringName(id))

static func displayName(id: StringName) -> String:
	return get_def(id).get("name", String(id).capitalize())

static func color(id: StringName) -> Color:
	return get_def(id).get("color", Color.WHITE)

static func classOf(id: StringName) -> StringName:
	return get_def(id).get("class", &"tribe")

static func isDemo(id: StringName) -> bool:
	return get_def(id).get("demo", false)

## The elite strength step of a region: {speed, damage, crush} multipliers
static func step(id: StringName) -> Dictionary:
	return get_def(id).get("step", NO_STEP)

## Sprint's station distance on a region's levels (px)
static func sprintDistance(id: StringName) -> float:
	var i := maxi(indexOf(id), 0)
	return lerpf(SPRINT_DISTANCE.x, SPRINT_DISTANCE.y, float(i) / maxf(ORDER.size() - 1, 1.0))

## The level ids of a region, in Levels.ORDER order
static func levelsOf(id: StringName) -> Array:
	var i := indexOf(id)
	if i < 0: return []
	return Levels.ORDER.slice(i * STOPS, (i + 1) * STOPS)

## The region of the level at an index in Levels.ORDER (five stops each)
static func regionAt(levelIndex: int) -> StringName:
	return ORDER[clampi(levelIndex / STOPS, 0, ORDER.size() - 1)]

## How far out a district is: zone 0 near the start, 1, then 2 far out, scored by distance (Goons.DISTANCE_WEIGHT,
## WILD_BELOW, TRIBE_BELOW)
static func zoneFor(distancePx: float, jitter: float) -> int:
	var score := distancePx / Goons.CHUNK_PX * Goons.DISTANCE_WEIGHT + jitter
	if score < Goons.WILD_BELOW: return 0
	if score < Goons.TRIBE_BELOW: return 1
	return 2

## The landmark a region's districts show
static func landmark(id: StringName) -> StringName:
	return get_def(id).get("landmark", &"landmark_tribe")
