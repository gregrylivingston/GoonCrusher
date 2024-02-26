extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func updatePlayerRegion(tile):
	if tile.region != Region.currentRegionNumber:
		var myRegion = Region.getRegion(tile.region, tile.terrain)
		%regionName.text = "Region: " + str(myRegion.name)
	%terrain.text = "Terrain: " + str(Root.terrain.keys()[tile.terrain])
	%region.text = "Region#: " + str(tile.region)
