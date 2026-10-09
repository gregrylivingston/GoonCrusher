class_name LevelDef extends Resource

#One level: what the menu shows, the run's clock and spawn tuning, its region and line-up, and the
#parameters the world generator reads (docs/WORLD.md). Each level is res://world/levels/<id>.tres,
#listed in order by Levels.ORDER, and its thin scene res://scene/level/levels/level_<id>.tscn only
#sets `def`. Edit a level's numbers here, not on its scene: levelRoot copies them in when the run starts.
#A level is three choices: where (its landscape), who (its region: class, props, landmark) and what (its
#twist: line-up, rules, overrides).

@export var id: StringName
@export var displayName: String
## The menu and Goonopedia art. One path, so the art phase can swap the placeholder posters.
@export_file("*.png") var poster: String
## Its region (Territories.ORDER) and its stop on the region's road (1-5; 5 is the finale)
@export var region: StringName = &"wilds"
@export_range(1, 5) var stop: int = 1
@export var order: int = 0
## One line for the Goonopedia: the level's signature barrier and surfaces.
@export_multiline var blurb: String
## The Goonopedia's BARRIER line: what walls the level in and how to get through
@export var barrier: String
## The Goonopedia's SURFACES line: the ground and its hazards
@export var surfaces: String

@export_group("Run")
@export var startPosition := Vector2(2129, 1227)
@export var seconds: int = 420
@export var spawnTimer: float = 6.0
@export var giantOdds: int = -10
@export var escalationSpeed: float = 0.15
## Sprint and Marathon: time allowed per second of reference driving (Level.sprintSeconds)
@export var sprintSlack: float = 1.3
## The level's rules: "nightShare" (0..1, the share of each day cycle that is night; missing keeps the
## clock's old 60 s day, 60 s night) and "events" ({world event id: weight}, PickupWorld.EVENTS; missing
## weighs every event the same)
@export var rules: Dictionary = {}

@export_group("Goons")
## 3-6 goon ids from its region's class (Goons.CLASSES). Each district fields 3 of them (LevelRoster).
@export var lineup: Array[StringName] = []

@export_group("World")
## Its landscape (road_atlas_ids: meadow, bayou, canyon, quarry, mountain, highway, city, scrapyard, forest,
## forest_snow, coast, ghosttown, saltflats, volcano, suburbs)
@export var landscape: StringName = &"meadow"
## &"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city" or &"yard"
@export var grammar: StringName = &"meadow"
## Generator parameters for the grammar (WorldField.setup reads them, with defaults): frequencies (1/px),
## widths (px), thresholds as raw noise values, chances, and "barrierCap" (the most of any 3x3-chunk window
## hard barriers may cover: 0.2 by default, 0.35 on canyon, city and yard)
@export var features: Dictionary = {}
## Root.terrain ids by noise band, low to high
@export var baseTerrain: Array = []
## Root.terrain ids sprinkled over the base as surface accents
@export var accents: Array = []
## Zone (0 near the start, 1, 2 far out) -> {prop id: weight}: props.json ids, DECOR ones as MultiMesh decor
## (ChunkRecipe). features "props" and "decor" set how many of each a fully open chunk gets (16 and 110 by default).
@export var dressing: Dictionary = {}
## Zone -> {motif id: weight}: set pieces from WorldSkin.MOTIFS (camps, groves, wreck piles...) placed
## before the scattered dressing. features "motifs" sets how many a fully open chunk gets (1 by default).
@export var motifs: Dictionary = {}
## pickup kind -> weight, rolled pickupsPerChunk times per chunk: coinline (a line of 7 coins), fuel, health,
## purse, slot, or none (nothing, so later levels can lean out the coins)
@export var pickupTable: Dictionary = {}
@export var pickupsPerChunk: int = 3

@export_group("Look")
## ground colours for the shader fallback: name -> Color
@export var palette: Dictionary = {}
@export var nightTint := Color.BLACK
@export var ambience: StringName = &""

## The thin level scene that sets this def
func scenePath() -> String:
	return Levels.scenePath(id)

## A finale (its region's 5th stop) opens the next level only on Medium (Root.opensNextLevel)
func isFinale() -> bool:
	return stop >= Territories.STOPS

## A plain, deep-copied Dictionary of every field, for worker threads (resources aren't thread-safe to share)
func snapshot() -> Dictionary:
	var out := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(p.name)
			out[p.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out
