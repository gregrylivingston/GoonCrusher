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
		%regionName.text = str(myRegion.name)
		%giantism.text = "Giantism: " + str(myRegion.giantism)
	%terrain.text = str(Root.terrain.keys()[tile.terrain])
	%region.text = "ID " + str(tile.region)
