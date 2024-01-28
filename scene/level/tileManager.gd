extends Node2D

var tilesPerChunk: Vector2 = Vector2(40,40)
var pixelsPerTile: Vector2 = Vector2(128,64)
var tilesize: Vector2



@export_range(0,3) var landscapeType: int = 0 # 0-grass 1-sand 2-dirt 3-snow
var landscapeMap = [
	preload("res://scene/level/terrain/landscapeMap.tscn"),
	preload("res://scene/level/terrain/landscapeMap2.tscn"),
	preload("res://scene/level/terrain/landscapeMap3.tscn"),
	preload("res://scene/level/terrain/landscapeMap4.tscn")
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
	getPlayerChunk()


			
var lastPlayerChunk
func getPlayerChunk():
	var playerChunk = Vector2i( (Root.playerCar.global_position /  tilesize ) )
	if playerChunk != lastPlayerChunk:
		lastPlayerChunk = playerChunk
		loadChunk(playerChunk)

		loadChunk(playerChunk + Vector2i(1,0) )
		loadChunk(playerChunk + Vector2i(1,1) )
		loadChunk(playerChunk + Vector2i(1,-1) )

		loadChunk(playerChunk + Vector2i(0,1) )
		loadChunk(playerChunk + Vector2i(0,-1) )
		loadChunk(playerChunk + Vector2i(-1,1) )

		loadChunk(playerChunk + Vector2i(-1,-1) )
		loadChunk(playerChunk + Vector2i(-1,0) )
		loadChunk(playerChunk + Vector2i(-2,-2) )

		loadChunk(playerChunk + Vector2i(-2,-1) )
		loadChunk(playerChunk + Vector2i(-1,-2) )	
		loadChunk(playerChunk + Vector2i(0,-2) )	

		loadChunk(playerChunk + Vector2i(-2,1) )
		loadChunk(playerChunk + Vector2i(-2,0) )		
		loadChunk(playerChunk + Vector2i(1,-2) )		


func loadChunk(chunk):
	if not loadedLandscapes.has(chunk):
		var targetPosition = Vector2( tilesize.x * chunk.x , tilesize.y * chunk.y )
		var newLandscapeMap = landscapeMap[landscapeType].instantiate()
		newLandscapeMap.global_position = targetPosition
		loadedLandscapes[chunk] = newLandscapeMap
		add_child(newLandscapeMap)

		var newObjectTile = objectTiles[randi() % objectTiles.size()].instantiate()
		loadedObjects[chunk] = newObjectTile
		newObjectTile.global_position = targetPosition + (tilesize / 2) + Vector2(randi_range(tilesize.x/-3,tilesize.x/3),randi_range(-200,200))
		var myRotation = randi() % 180
		newObjectTile.rotation = myRotation
		for i in newObjectTile.get_children():i.rotation = -myRotation
		add_child(newObjectTile)
			


			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	getPlayerChunk()


