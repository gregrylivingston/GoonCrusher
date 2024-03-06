extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Region.currentRegion.has("time"):
		%WaveProgressBar.value = int(Region.currentRegion.time) % 120
		%Label_wave.text = "Survive Wave " + str(Region.currentRegion.wave)

func updatePlayerRegion(tile):
	if tile.terrain != Root.terrain.WATER && tile.terrain != Root.terrain.HILLS:
		var myRegion = Region.getRegion(tile.region, tile.terrain)
		%Label_regionName.text = str(myRegion.name)
		%giantism.text = str(myRegion.giantism) + "%"
		
		%goon1.text = Root.goon.keys()[myRegion.goon[0]]
		%goon2.text = Root.goon.keys()[myRegion.goon[1]]
		%goon3.text = Root.goon.keys()[myRegion.goon[2]]
		
		match Region.currentRegion.wave:
			1:
				%goon2.visible = false	
				%goon3.visible = false
			2:
				%goon2.visible = true	
				%goon3.visible = false
			3:
				%goon2.visible = true
				%goon3.visible = true
		
		
	%terrain.text = str(Root.terrain.keys()[tile.terrain])
	%region.text = "ID " + str(tile.region)
