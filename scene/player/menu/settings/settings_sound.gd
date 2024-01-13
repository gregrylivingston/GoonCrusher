extends VBoxContainer




# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_master_volume_value_changed(value):
	if value < -39: value = -500
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)
	SaveManager.setVolume( "master" , value )
	forceAudioUpdate()
	
func _on_music_volume_value_changed(value):
	if value < -39: value = -500
	SaveManager.setVolume( "music" , value )
	forceAudioUpdate()

func _on_voice_volume_value_changed(value):
	if value < -39: value = -500
	SaveManager.setVolume( "voice" , value )
	forceAudioUpdate()
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playPurseRewardAudio()

func _on_fx_volume_value_changed(value):
	if value < -39: value = -500
	SaveManager.setVolume( "fx" , value )
	forceAudioUpdate()
	if is_instance_valid(Root.playerCar):
		Root.playerCar.playRandomFxSound()
		

func forceAudioUpdate():
	if is_instance_valid(Root.mainMenu):
		Root.mainMenu.updateAudioLevels()
	if is_instance_valid(Root.playerCar):
		Root.playerCar.updateAudioLevels()

