class_name LevelDef extends Resource

#One level: what the menu shows, the run's clock and spawn tuning, who holds the land, and the
#parameters the world generator reads (docs/WORLD.md). Each level is res://world/levels/<id>.tres,
#listed in order by Levels.ORDER, and its thin scene res://scene/level/levels/level_<id>.tscn only
#sets `def`. Edit a level's numbers here, not on its scene: levelRoot copies them in when the run starts.

@export var id: StringName
@export var displayName: String
## The menu and Goonopedia art. One path, so the art phase can swap the placeholder posters.
@export_file("*.png") var poster: String
@export_range(1, 3) var act: int = 1
@export var order: int = 0
## One line for the Goonopedia: the level's signature barrier and surfaces.
@export_multiline var blurb: String

@export_group("Run")
@export var startPosition := Vector2(2129, 1227)
@export var seconds: int = 420
@export var spawnTimer: float = 6.0
@export var giantOdds: int = -10
@export var escalationSpeed: float = 0.15
## Sprint and Marathon: time allowed per second of reference driving (Level.sprintSeconds)
@export var sprintSlack: float = 1.3
## Modes this level offers; empty means every mode
@export var modes: Array = []

@export_group("Goons")
## Districts score their faction as Goons.factionFor does (distance from the start), clamped to this band
## (x = min, y = max). Below Goons.WILD_BELOW is wild, below Goons.TRIBE_BELOW tribal, else scrap.
@export var factionBand := Vector2(0.0, 3.6)
## Goons.faction -> Array of goon ids. LevelRoster validates and pads it; an empty faction falls back to the Tribe's.
@export var roster: Dictionary = {}

@export_group("World")
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
## Goons.faction -> {prop id: weight}: props.json ids, DECOR ones as MultiMesh decor (ChunkRecipe). features
## "props" and "decor" set how many of each a fully open chunk gets (16 and 110 by default).
@export var dressing: Dictionary = {}
## pickup kind -> weight
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

## Whether the level offers a mode (the `modes` whitelist; empty offers all)
func offersMode(mode: int) -> bool:
	return modes.is_empty() || mode in modes

## A plain, deep-copied Dictionary of every field, for worker threads (resources aren't thread-safe to share)
func snapshot() -> Dictionary:
	var out := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = get(p.name)
			out[p.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out
