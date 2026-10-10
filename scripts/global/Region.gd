extends Node

#The run's regions are the world's districts (WorldMap, docs/WORLD.md): areas about 40,000 px across, cut
#by the level's barriers, each with three goons from the level's line-up (its faction is its first goon's),
#a name, a tint and a giantism figure, all decided when the world is built. A district decides *who* spawns.
#(The road atlas's six regions are Territories, scripts/world/territories.gd.)
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
	if not Modes.hasGoons(SaveManager.playerData.gameMode): return #no goons: no waves, stars or wave chests
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

#Testing: `-- --class=wild|tribe|scrap|biggame|swarm|warmachine` picks every region's goons from that class
#(Goons.CLASSES) instead of the level's line-up, `-- --goons=spoke,karter,turret` forces its three goons
#(cycled if fewer are given). Also read by playtest and bench runs.
var forcedClass := &""
var forcedGoons: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			forcedClass = StringName(arg.get_slice("=", 1))
			if not Goons.CLASSES.has(forcedClass):
				push_warning("--class: unknown class %s (%s)" % [forcedClass, ", ".join(Goons.CLASS_ORDER)])
				forcedClass = &""
		elif arg.begins_with("--goons="):
			for id in arg.get_slice("=", 1).split(","):
				if Goons.DATA.has(StringName(id)): forcedGoons.push_back(StringName(id))
				else: push_warning("--goons: unknown goon " + id)

## The regions of a new world: one per district, with the goons, faction, name, tint and giantism the
## WorldMap gave it (and the --class / --goons overrides)
func setDistricts(map: WorldMap) -> void:
	resetRegions()
	rng.seed = WorldGen.ihash(map.worldSeed, WorldGen.TAG_DISTRICT, 7, 7)
	for d in map.districts:
		var faction: int = d.faction
		var goons: Array = d.goons.duplicate()
		if forcedClass != &"":
			var pick := RandomNumberGenerator.new()
			pick.seed = WorldGen.ihash(map.worldSeed, WorldGen.TAG_GOONS, d.id, 1)
			goons = LevelRoster.pickFrom(LevelRoster.validIds(Goons.classMembers(forcedClass)), pick)
			faction = Goons.DATA[goons[0]].faction
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

#A region made up without a world map (tests; a level launched before its map exists): three goons of the
#level's line-up (LevelRoster), or of the --class one.
func createRegion(terrain: int) -> Dictionary:#terrain is Enum Root.terrain
	var def := Levels.current()
	var goons := LevelRoster.pickFrom(LevelRoster.validIds(Goons.classMembers(forcedClass)), rng) if forcedClass != &"" else LevelRoster.pickGoons(def, rng)
	var faction: int = Goons.DATA[goons[0]].faction if not goons.is_empty() else Goons.faction.TRIBE
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
	var next := getRegion(id, tile.terrain)
	next.visited = true
	#the HUD says nothing about districts: what changes is who spawns
	if is_instance_valid(Root.spawnManager) && next.has("goon"): Root.spawnManager.basicGoons = next.goon

## How many districts the car has been in this run
func visitedCount() -> int:
	var count := 0
	for region in regions.values():
		if region.get("visited", false): count += 1
	return count
