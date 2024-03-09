extends Node2D

var tilesPerChunk: Vector2 = Vector2(40,40)
var pixelsPerTile: Vector2 = Vector2(128,64)
var tilesize: Vector2



@export_range(0,3) var landscapeType: int = 0 # 0-grass 1-sand 2-dirt 3-snow
var landscapeMap = [
	preload("res://scene/level/terrain/landscapeMap.tscn"),
	preload("res://scene/level/terrain/landscapeMap2.tscn"),
	preload("res://scene/level/terrain/landscapeMap_mud.tscn"),
	preload("res://scene/level/terrain/landscapeMap_water.tscn"),
	preload("res://scene/level/terrain/landscapeMap_hill.tscn"),
	preload("res://scene/level/terrain/landscapeMap_shortGrass.tscn"),#moss
	preload("res://scene/level/terrain/landscapeMap_dirt.tscn"),
	preload("res://scene/level/terrain/landscapeMap_snow.tscn")
]

enum objectTypes { ROCKS , COINS , BONUS_ROCKS , EMPTY , SAND }
@export var requestedObjectTiles: Array[objectTypes] = [objectTypes.ROCKS]
var AllObjectTiles = {
	objectTypes.ROCKS:[
		preload("res://scene/level/levelObjects/level_rocks_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_2.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_3.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_4.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_5.tscn"),
	],
	objectTypes.COINS:[
		preload("res://scene/level/levelObjects/level_coins_1.tscn"),
		preload("res://scene/level/levelObjects/level_coins_2.tscn"),
		preload("res://scene/level/levelObjects/level_coins_3.tscn"),
		preload("res://scene/level/levelObjects/level_coins_4.tscn"),
		preload("res://scene/level/levelObjects/level_coins_5.tscn"),
	],
	objectTypes.BONUS_ROCKS:[
		preload("res://scene/level/levelObjects/level_rocks_fuel_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_2.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_3.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_fuel_4.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_purse_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_heart_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocks_slot_1.tscn")
		
	],
	objectTypes.EMPTY:[
		preload("res://scene/level/levelObjects/level_empty.tscn"),
		preload("res://scene/level/levelObjects/level_empty.tscn"),
		preload("res://scene/level/levelObjects/level_empty.tscn"),
	],
	objectTypes.SAND:[
		preload("res://scene/level/levelObjects/level_sandtrap_1.tscn"),
		preload("res://scene/level/levelObjects/level_sand_fuel_1.tscn"),
		preload("res://scene/level/levelObjects/level_rocksand_1.tscn")
	]
}

var objectTiles = []
var loadedLandscapes = {}
var loadedObjects = {}


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in requestedObjectTiles:
		objectTiles.append_array(AllObjectTiles[i])
	tilesize = tilesPerChunk * pixelsPerTile
	
	await $landscapeGenerator.createNewTerrain()
	
	setupByGamemode()

	await get_tree().process_frame

	getPlayerChunk()

	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT:
			var myStation = load("res://scene/level/station.tscn").instantiate()
			Root.station = myStation
			loadChunk(Vector2i( randi_range( Root.levelRoot.seconds * 0.12 , Root.levelRoot.seconds * 0.16),  randi_range(Root.levelRoot.seconds * 0.07, Root.levelRoot.seconds * - 0.07) ) , myStation)
		Root.gameModes.MARATHON:
			var myStation = load("res://scene/level/station.tscn").instantiate()
			Root.station = myStation
			loadChunk(Vector2i( randi_range( Root.levelRoot.seconds * 0.7 , Root.levelRoot.seconds * 0.72),  randi_range( Root.levelRoot.seconds * 0.2 , Root.levelRoot.seconds * -0.2 ) ), myStation)

	if loadedObjects.has(playerChunk):
		loadedObjects[playerChunk].queue_free()
		loadedObjects.erase(playerChunk)


func setupByGamemode() -> void:
	match SaveManager.playerData.gameMode:
		Root.gameModes.GOONCRUSHER:setupNoStations()
		Root.gameModes.GOONPOCALYPSE:setupNoStations()
		Root.gameModes.SPRINT:
			loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())
		Root.gameModes.MARATHON:
			loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())
		Root.gameModes.DEFENSE:
			var myStation = load("res://scene/level/station.tscn").instantiate()
			Root.station = myStation
			loadChunk(Vector2i( randi_range(0, 0), 0 ) , myStation)
	
func setupNoStations():
	Root.station = null
	loadChunk(Vector2i(0,0) , preload("res://scene/level/levelObjects/level_empty.tscn").instantiate())


var playerChunk: Vector2i = Vector2i(-999,-999)
var startingPlayerChunk
#var terrainRegion: int = -5
#var terrainType: int = Root.terrain.GRASS

func getTile(coordinates) -> Dictionary:
	var tileVector = Vector2i( (coordinates.x /  tilesize.x ), coordinates.y / tilesize.y )
	if tileVector.y < 0: tileVector.y -= 1
	if tileVector.x < 0: tileVector.x -= 1
	return $landscapeGenerator.mapDict[tileVector.y + 128][tileVector.x + 128]
	


func getPlayerChunk():
		
	if playerChunk != Vector2i( (Root.playerCar.global_position /  tilesize ) ):
		playerChunk = Vector2i( (Root.playerCar.global_position /  tilesize ) )
	
		var tileToTest = playerChunk
		if playerChunk.y < 0: tileToTest.y -= 1
		if playerChunk.x < 0: tileToTest.x -= 1
		var myTile = loadChunk(tileToTest)
		if is_instance_valid(Root.playerRoot):Region.updatePlayerRegion(myTile)
		
		for i in chunksToLoad:
			loadChunk(playerChunk + i)

		for i in chunksToUnload:
			unloadChunk(playerChunk + i)
			unloadChunk(playerChunk - i)


var chunksToLoad: Array[Vector2i] = [
	Vector2i(-2,1),Vector2i(-2,0),Vector2i(1,-2),Vector2i(0,-2),Vector2i(-1,-2),Vector2i(-2,-1) ,Vector2i(-2,-2),
	Vector2i(-1,0), Vector2i(-1,-1), Vector2i(-1,1) ,Vector2i(0,-1), Vector2i(0,1) ,Vector2i(1,-1),Vector2i(1,1),Vector2i(1,0)
]

var chunksToUnload: Array[Vector2i] = [ 
	Vector2i(-4,-4), Vector2i(-4,-3), Vector2i(-4,-2), Vector2i(-4,-1), Vector2i(-4,0),
	Vector2i(-3,-4), Vector2i(-2,-4), Vector2i(-1,-4), Vector2i(0,-4), 
]

func unloadChunk(chunk: Vector2i):
	if loadedLandscapes.has(chunk):
		loadedLandscapes[chunk].queue_free()
		loadedLandscapes.erase(chunk)
		if loadedObjects.has(chunk):
			loadedObjects[chunk].queue_free()
			loadedObjects.erase(chunk)
	

func getRandomTileObject():
	return objectTiles[randi() % objectTiles.size()].instantiate()
	

func loadChunk(chunk:Vector2i , myScene = null): #if an instantiated scene isn't passed get a random one from the level dictionary.
	if not loadedLandscapes.has(chunk):
		var targetPosition = Vector2( tilesize.x * chunk.x , tilesize.y * chunk.y )
		var tile = $landscapeGenerator.mapDict[chunk.y + 128][chunk.x + 128]
		var newLandscapeMap = landscapeMap[tile.terrain].instantiate()
		
		if Region.regions.has(tile.region):
			newLandscapeMap.self_modulate = newLandscapeMap.self_modulate * Region.regions[tile.region].terrain_modulate
			newLandscapeMap.self_modulate.a = 1.0
		
		newLandscapeMap.global_position = targetPosition
		loadedLandscapes[chunk] = newLandscapeMap
		add_child(newLandscapeMap)
		
		if tile.terrain != Root.terrain.WATER && tile.terrain != Root.terrain.HILLS:
			var newObjectTile = createNewTileObject(targetPosition  , myScene)
			loadedObjects[chunk] = newObjectTile
			add_child(newObjectTile)
		return tile
	else: return $landscapeGenerator.mapDict[chunk.y + 128][chunk.x + 128]
			

#create objects like rocks and powerups that go over the landscapes
func createNewTileObject(targetPosition , myScene = null):
		var newObjectTile 
		if myScene == null: 
			newObjectTile = getRandomTileObject()
			var myRotation = randi() % 180
			newObjectTile.global_position = targetPosition + (tilesize / 2) + Vector2(randi_range(tilesize.x/-4,tilesize.x/4),randi_range(-200,200))		
			newObjectTile.rotation = myRotation
			for i in newObjectTile.get_children():
				if not i.has_method("isFixed"):i.rotation = -myRotation
		else: 
			newObjectTile = myScene
			newObjectTile.global_position = targetPosition + (tilesize / 2) 
		return newObjectTile

func _process(delta):
	getPlayerChunk()
