extends VBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func updatePlayerRegion(tile):
	if tile.terrain != Root.terrain.WATER && tile.terrain != Root.terrain.HILLS:
		var myRegion = Region.getRegion(tile.region, tile.terrain)
		%regionName.text = str(myRegion.name)
		%giantism.text = "Giantism: " + str(myRegion.giantism)
		%goon1.text = Root.goon.keys()[myRegion.goon[0]]
		%goon2.text = Root.goon.keys()[myRegion.goon[1]]
		%goon3.text = Root.goon.keys()[myRegion.goon[2]]
		
		
	%terrain.text = str(Root.terrain.keys()[tile.terrain])
	%region.text = "ID " + str(tile.region)
