extends HBoxContainer


var shownWave = -1
var shownSecond = -1

func _process(_delta):
	if Region.currentRegion.has("time"):
		var second = int(Region.currentRegion.time)
		if second != shownSecond:
			shownSecond = second
			%WaveProgressBar.value = second % Region.waveLength
		if Region.currentRegion.wave != shownWave:
			shownWave = Region.currentRegion.wave
			%Label_wave.text = "Survive Wave " + str(shownWave)
			%WaveProgressBar.max_value = int(shownWave * Region.waveLength)

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
