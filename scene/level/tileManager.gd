extends Node2D

var tilesPerChunk: Vector2 = Vector2(40,40)
var pixelsPerTile: Vector2 = Vector2(128,64)

@export_range(0,3) var landscapeType: int = 0 # 0-grass 1-sand 2-dirt 3-snow
var landscapeMap = [
	preload("res://scene/level/terrain/landscapeMap.tscn"),
	preload("res://scene/level/terrain/landscapeMap2.tscn"),
	preload("res://scene/level/terrain/landscapeMap3.tscn"),
	preload("res://scene/level/terrain/landscapeMap4.tscn")
]

var loadedLandscapes = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	getPlayerChunk()


			
var lastPlayerChunk
func getPlayerChunk():
	var playerChunk = Vector2i( (Root.playerCar.global_position / ( tilesPerChunk * pixelsPerTile )) )
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
		var newLandscapeMap = landscapeMap[landscapeType].instantiate()
		newLandscapeMap.global_position = Vector2( tilesPerChunk.x * pixelsPerTile.x * chunk.x , tilesPerChunk.y * pixelsPerTile.y * chunk.y )
		loadedLandscapes[chunk] = newLandscapeMap
		add_child(newLandscapeMap)

			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	getPlayerChunk()


