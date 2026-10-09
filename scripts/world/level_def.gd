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
## clock's old 60 s day, 60 s night), "events" ({world event id: weight}, PickupWorld.EVENTS and the
## level-owned WORLD_EVENTS; missing weighs every pickup event the same and starts no world event),
## "dazeHeavies" (bool: a Bullmoose lunging into a wall is dazed and easier to crush, Walker.daze) and
## "oakCoins" (int: an oak drops that many coins on its first hard hit, Spill.shakeOak)
@export var rules: Dictionary = {}

@export_group("Goons")
## 3-6 goon ids from its region's class (Goons.CLASSES). Each district fields 3 of them (LevelRoster).
@export var lineup: Array[StringName] = []

@export_group("World")
## Its landscape (Landscapes, world/landscapes/<id>.tres): the generator, ground materials, walls, water,
## natural props and district name words. grammar, features, baseTerrain and accents left empty here come
## from it (resolve()).
@export var landscape: StringName = &"meadow"
## &"meadow", &"bayou", &"canyon", &"quarry", &"mountain", &"highway", &"city" or &"yard"; empty: the landscape's
@export var grammar: StringName = &""
## Generator parameters for the grammar (WorldField.setup reads them, with defaults): frequencies (1/px),
## widths (px), thresholds as raw noise values, chances, and "barrierCap" (the most of any 3x3-chunk window
## hard barriers may cover: 0.2 by default, 0.35 on canyon, city and yard). features "props", "decor" and
## "motifs" set how many props, decor and set pieces a fully open chunk gets (16, 110 and 1 by default).
## Empty: the landscape's.
@export var features: Dictionary = {}
## Root.terrain ids by noise band, low to high. Empty: the landscape's.
@export var baseTerrain: Array = []
## Root.terrain ids sprinkled over the base as surface accents. Empty: the landscape's.
@export var accents: Array = []
## The level's own dressing over its landscape's and region's (WorldSkin.zoneTables): {prop id: weight}
## (props.json ids, DECOR ones as MultiMesh decor) on every zone, replacing the weight; 0 takes a prop out
@export var dressing: Dictionary = {}
## The same for set pieces: {motif id: weight} (WorldSkin.MOTIFS: camps, groves, wreck piles...)
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

## Fills grammar, features, baseTerrain and accents the def leaves empty from its landscape, once. A forced
## landscape (`-- --landscape=<id>`, Landscapes.forcedId) replaces the level's own world with the landscape's.
## Levels.get_def, Level.applyDef, snapshot() and WorldSkin call it; it is idempotent.
var resolvedLandscape := false
func resolve() -> LevelDef:
	if resolvedLandscape: return self
	resolvedLandscape = true
	var forced := Landscapes.forcedId()
	if forced != &"" && forced != landscape:
		landscape = forced
		grammar = &""
		features = {}
		baseTerrain = []
		accents = []
	var land := Landscapes.get_def(landscape)
	if land == null:
		if grammar == &"": grammar = &"meadow"
		return self
	if grammar == &"": grammar = land.grammar
	if features.is_empty(): features = land.features.duplicate(true)
	if baseTerrain.is_empty(): baseTerrain = land.baseTerrain.duplicate()
	if accents.is_empty(): accents = land.accents.duplicate()
	return self

## A plain, deep-copied Dictionary of every field, for worker threads (resources aren't thread-safe to share)
func snapshot() -> Dictionary:
	resolve()
	var out := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(p.name)
			out[p.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out
