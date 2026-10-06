extends Node

var waveLength: int = 60
const LAST_WAVE := 4 #a region stops paying stars at this wave, except in Goonpocalypse

func waveCap() -> int:
	return 1 << 30 if SaveManager.playerData && SaveManager.playerData.gameMode == Root.gameModes.GOONPOCALYPSE else LAST_WAVE


func _process(delta):
	if currentRegion.has("time") && Root.isRunActive:
		currentRegion.time += delta
		if currentRegion.wave * waveLength < currentRegion.time && currentRegion.wave < waveCap():
			currentRegion.wave += 1
			Root.playerCar.star += 1
			Root.playerRoot.animateNewRegion(true)


var names: Dictionary = {
	Root.terrain.GRASS: [
		"Goon Fields", "Goonvale", "Peaceful Meadow", "Goon Park",
		"Emerald Expanse", "Whisperwind Plains", "Verdant Valley", "Greenhaven Glade",
		"Sunlit Savanna", "Bloomridge Field", "Meadowbrook Glade", "Serenity Fields"
	],
	Root.terrain.MUD: [
		"Mudtown", "Dust Valley", "Goon Pits", "Muddy Barrens",
		"Slick Quarry", "Claymore Canyon", "Mudslide Domain", "Bogland Basin",
		"Sludge Hollow", "Grimy Gulch", "Swampland Shallows", "Marshland Maze"
	],
	Root.terrain.SAND: [
		"Goon Beach", "Sand Alley", "The Dunes", "Doonvale",
		"Golden Sands Shore", "Desert Mirage", "Sandy Oasis", "Sunset Dunes",
		"Quicksand Quarters", "Dune Labyrinth", "Silica Valley", "Scorching Plains"
	],
	Root.terrain.MOSS: [
		"Mossy Barrens",
		"Verdigris Forest", "Mossblanket Vale", "Lichen Ledge",
		"Ferngully Thicket", "Sporing Grounds", "Emerald Moss Marsh", "Velvet Verdure"
	],
	Root.terrain.DIRT: [
		"Dusty Lane",
		"Barren Bluffs", "Gravel Grounds", "Loam Lands",
		"Earthenway Path", "Clodhopper Row", "Tilled Fields", "Soilrich Hollow"
	],
	Root.terrain.SNOW: [
		"The Tundra",
		"Frostbite Fields", "Snowdrift Valley", "Icicle Isle",
		"Glacial Basin", "Winter's Edge", "Permafrost Plains", "Chillwind Wastes"
	]
}

func resetRegions():
	for i in regions.keys():
		regions.erase(i)
	
	regions = {
	-2:{
		"name":"Wasteland",
		"giantism":0,
		"terrain_modulate":1.0,
	},
	0:getRegion(0,Root.terrain.GRASS)
	}
	currentRegion = regions[0]
	currentRegionNumber = -99

@onready var regions: Dictionary = {
	-2:{
		"name":"Wasteland","giantism":0,"terrain_modulate":1.0,
	},
	0:getRegion(0,Root.terrain.GRASS)
}
var currentRegion: Dictionary
var currentRegionNumber: int = -99

func getRegion(regionNumber: int , terrainType: int) -> Dictionary:
	if regions.has(regionNumber) || regionNumber == -2:
		currentRegion = regions[regionNumber]
		currentRegionNumber = regionNumber
		return regions[regionNumber]
	else:
		var newRegion = createRegion(terrainType)
		regions.merge({regionNumber:newRegion})
		currentRegion = newRegion
		currentRegionNumber = regionNumber
		return newRegion
		
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

#A region belongs to one faction (Goons.gd): Wild Things near the start and on early levels, the Goon
#Tribe further out, the Scrap Gang furthest out and on late levels. Its three goons come from that faction.
func createRegion(terrain: int) -> Dictionary:#terrain is Enum Root.terrain
	var distance: float = Root.playerCar.global_position.length() if is_instance_valid(Root.playerCar) else 0.0
	var faction := Goons.factionFor(distance, SaveManager.playerData.selectedLevel if SaveManager.playerData else 0, rng.randf_range(-Goons.FACTION_JITTER, Goons.FACTION_JITTER))
	if forcedFaction >= 0: faction = forcedFaction
	var goons := Goons.regionGoons(faction, terrain, rng)
	if not forcedGoons.is_empty():
		goons = [forcedGoons[0], forcedGoons[1 % forcedGoons.size()], forcedGoons[2 % forcedGoons.size()]]
		faction = Goons.DATA[goons[0]].faction
	var thisRegion = {
		"name": names[ terrain ][ randi()%names[terrain].size() - 1 ],
		"terrain":terrain,
		"giantism":randi()%100,
		"time":0.0,
		"wave":1,
		"faction":faction,
		"goon":goons,
		"terrain_modulate":randf_range(0.8,1.12),
	}
	return thisRegion

func factionName(faction: int = -1) -> String:
	return Goons.factionName(currentRegion.get("faction", Goons.faction.TRIBE) if faction < 0 else faction)

func updatePlayerRegion(tile):
	if currentRegionNumber != tile.region:
		Root.playerRoot.animateNewRegion(true)
	currentRegionNumber = tile.region
	currentRegion = getRegion(tile.region , tile.terrain)
	
	await get_tree().process_frame
	Root.playerRoot.updatePlayerRegion(tile)
	Root.playerCar.setTerrain(tile.terrain)
	
	if currentRegion.has("goon"):Root.spawnManager.basicGoons = currentRegion.goon
	
	
	#still needs at least....
	#terrain objects
	#objectives
	#goons
	
