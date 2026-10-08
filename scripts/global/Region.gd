extends Node

#The run's regions are the world's districts (WorldMap, docs/WORLD.md): areas about 40,000 px across, cut
#by the level's barriers, each held by one faction with three goons, a name, a tint and a giantism figure,
#all decided when the world is built. A district decides *who* spawns.
#
#Waves are one clock for the whole run (roadmap W-1), whatever district the car is in: the longer the
#run, the harder it gets. Every waveLength seconds of run clock is a new wave, which pays a star and a
#wave chest, with no limit. The spawner's mix and pressure read waveIntensity().

var waveLength: int = 60
const WASTELAND := -2 #barriers and anything off the map

var runTime := 0.0 #seconds of run clock so far (paused menus and the world build don't count)
var wave := 1      #the wave the run is in: 1 + whole waves survived

func resetWaves() -> void:
	runTime = 0.0
	wave = 1

## How far into its current wave the run is, 0..1 (the HUD's ring)
func waveProgress() -> float:
	return clampf((runTime - (wave - 1) * waveLength) / waveLength, 0.0, 1.0)

## Seconds left in the current wave
func waveSecondsLeft() -> int:
	return maxi(0, ceili(wave * waveLength - runTime))

## The run's escalation as one number: the wave, plus a little for time inside it. The spawner's goon-slot
## mix (Goons.pickSlot) and the giant odds read it.
func waveIntensity() -> float:
	return wave + waveProgress() * 0.5

func _process(delta):
	if not Root.isRunActive || not is_instance_valid(Root.levelRoot) || not Root.levelRoot.get("clockReady"): return
	runTime += delta
	if wave * waveLength < runTime:
		wave += 1
		if is_instance_valid(Root.playerCar): Root.playerCar.star += 1
		if is_instance_valid(Root.playerRoot): Root.playerRoot.waveSurvived()
		PickupWorld.waveChest() #an Uncommon-or-better pickup for surviving the wave


#names for a region made up outside the world map (tests, a level without one): by terrain
var names: Dictionary = {
	Root.terrain.GRASS: ["Goon Fields", "Goonvale", "Peaceful Meadow", "Goon Park", "Emerald Expanse", "Verdant Valley"],
	Root.terrain.MUD: ["Mudtown", "Goon Pits", "Muddy Barrens", "Bogland Basin", "Sludge Hollow", "Grimy Gulch"],
	Root.terrain.SAND: ["Goon Beach", "Sand Alley", "The Dunes", "Doonvale", "Desert Mirage", "Sunset Dunes"],
	Root.terrain.MOSS: ["Mossy Barrens", "Mossblanket Vale", "Lichen Ledge", "Velvet Verdure"],
	Root.terrain.DIRT: ["Dusty Lane", "Barren Bluffs", "Gravel Grounds", "Clodhopper Row"],
	Root.terrain.SNOW: ["The Tundra", "Frostbite Fields", "Snowdrift Valley", "Chillwind Wastes"],
}

func wasteland() -> Dictionary:
	return {"name":"Wasteland", "giantism":0, "terrain_modulate":1.0}

func resetRegions():
	regions = {WASTELAND: wasteland()}
	currentRegion = {}
	currentRegionNumber = -99
	resetWaves()

var regions: Dictionary = {WASTELAND: {"name":"Wasteland", "giantism":0, "terrain_modulate":1.0}}
var currentRegion: Dictionary = {}
var currentRegionNumber: int = -99

## The region with this id: a district from setDistricts, or (for an id the map doesn't know) a region made
## up on the spot. Makes it the current region.
func getRegion(regionNumber: int , terrainType: int) -> Dictionary:
	if not regions.has(regionNumber): regions[regionNumber] = createRegion(terrainType)
	currentRegion = regions[regionNumber]
	currentRegionNumber = regionNumber
	return currentRegion

#seeded from the world seed by setDistricts, so made-up regions repeat with the map
var rng := RandomNumberGenerator.new()

#Testing: `-- --faction=wild|tribe|scrap` forces every region's faction, `-- --goons=spoke,karter,turret`
#forces its three goons (cycled if fewer are given). Also read by playtest and bench runs.
var forcedFaction := -1
var forcedGoons: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--faction="): forcedFaction = ["wild", "tribe", "scrap"].find(arg.get_slice("=", 1))
		elif arg.begins_with("--goons="):
			for id in arg.get_slice("=", 1).split(","):
				if Goons.DATA.has(StringName(id)): forcedGoons.push_back(StringName(id))
				else: push_warning("--goons: unknown goon " + id)

## The regions of a new world: one per district, with the faction, goons, name, tint and giantism the
## WorldMap gave it (and the --faction / --goons overrides)
func setDistricts(map: WorldMap) -> void:
	resetRegions()
	rng.seed = WorldGen.ihash(map.worldSeed, WorldGen.TAG_DISTRICT, 7, 7)
	for d in map.districts:
		var faction: int = d.faction
		var goons: Array = d.goons.duplicate()
		if forcedFaction >= 0 && faction != forcedFaction:
			faction = forcedFaction
			var pick := RandomNumberGenerator.new()
			pick.seed = WorldGen.ihash(map.worldSeed, WorldGen.TAG_GOONS, d.id, 1)
			goons = LevelRoster.pickGoons(map.def, faction, pick) if map.def else Goons.regionGoons(faction, Root.terrain.GRASS, pick)
			if not goons.is_empty(): faction = Goons.DATA[goons[0]].faction
		if not forcedGoons.is_empty():
			goons = [forcedGoons[0], forcedGoons[1 % forcedGoons.size()], forcedGoons[2 % forcedGoons.size()]]
			faction = Goons.DATA[goons[0]].faction
		regions[d.id] = {
			"name": d.name,
			"terrain": map.terrain[d.firstCell] if d.firstCell >= 0 else Root.terrain.GRASS,
			"giantism": d.giantism,
			"faction": faction,
			"goon": goons,
			"terrain_modulate": d.tint,
			"visited": false,
		}

#A region made up without a world map (tests; a level launched before its map exists). Its faction comes
#from the car's distance from the start, scored as Goons.factionFor does and clamped to the level's
#LevelDef.factionBand (LevelRoster); its goons from the level's roster for that faction.
func createRegion(terrain: int) -> Dictionary:#terrain is Enum Root.terrain
	var distance: float = Root.playerCar.global_position.length() if is_instance_valid(Root.playerCar) else 0.0
	var def := Levels.current()
	var faction := LevelRoster.factionAt(def, distance, rng.randf_range(-Goons.FACTION_JITTER, Goons.FACTION_JITTER))
	if forcedFaction >= 0: faction = forcedFaction
	var goons := LevelRoster.pickGoons(def, faction, rng) if def else Goons.regionGoons(faction, terrain, rng)
	if not goons.is_empty(): faction = Goons.DATA[goons[0]].faction
	if not forcedGoons.is_empty():
		goons = [forcedGoons[0], forcedGoons[1 % forcedGoons.size()], forcedGoons[2 % forcedGoons.size()]]
		faction = Goons.DATA[goons[0]].faction
	var pool: Array = names.get(terrain, names[Root.terrain.GRASS])
	return {
		"name": pool[rng.randi() % pool.size()],
		"terrain":terrain,
		"giantism":rng.randi() % 100,
		"faction":faction,
		"goon":goons,
		"terrain_modulate":rng.randf_range(0.9, 1.08),
		"visited": false,
	}

func factionName(faction: int = -1) -> String:
	return Goons.factionName(currentRegion.get("faction", Goons.faction.TRIBE) if faction < 0 else faction)

## The car entered another district (TileManager checks whenever its coarse cell changes; a barrier cell
## keeps the last district). `tile` is {"terrain", "region"}. Pushes the district's goons to the spawner;
## the run's wave is untouched.
func updatePlayerRegion(tile):
	var id: int = tile.region
	if id < 0 || id == currentRegionNumber: return
	var previous := currentRegion
	var next := getRegion(id, tile.terrain)
	var firstVisit: bool = not next.get("visited", false)
	next.visited = true
	#a sign for each district met after the first (the run starts in one)
	if is_instance_valid(Root.playerRoot) && previous.has("faction") && firstVisit: Root.playerRoot.districtEntered(next)
	if is_instance_valid(Root.spawnManager) && next.has("goon"): Root.spawnManager.basicGoons = next.goon
	await get_tree().process_frame
	if is_instance_valid(Root.playerRoot) && currentRegionNumber == id: Root.playerRoot.updatePlayerRegion(tile)

## How many districts the car has been in this run
func visitedCount() -> int:
	var count := 0
	for region in regions.values():
		if region.get("visited", false): count += 1
	return count
