extends VBoxContainer


var isPrepared: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/masterVolume.value = SaveManager.getVolume("master")
	$HBoxContainer2/musicVolume.value = SaveManager.getVolume("music")
	$HBoxContainer3/voiceVolume.value = SaveManager.getVolume("voice")
	$HBoxContainer4/fxVolume.value = SaveManager.getVolume("fx")
	isPrepared = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_master_volume_value_changed(value):
	if isPrepared:
		if value < -39: value = -500
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)
		SaveManager.setVolume( "master" , value )
	
func _on_music_volume_value_changed(value):
	if isPrepared:
		if value < -39: value = -500
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), value)
		SaveManager.setVolume( "music" , value )

func _on_voice_volume_value_changed(value):
	if isPrepared:
		if value < -39: value = -500
		SaveManager.setVolume( "voice" , value )
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), value)
		#if is_instance_valid(Root.playerCar):
		#	Root.playerCar.playPurseRewardAudio()

func _on_fx_volume_value_changed(value):
	if isPrepared:
		if value < -39: value = -500
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("FX"), value)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), value)
		SaveManager.setVolume( "fx" , value )
		#if is_instance_valid(Root.playerCar):
		#	Root.playerCar.playRandomFxSound()
		


	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), SaveManager.getVolume("fx"))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("FX"), SaveManager.getVolume("fx"))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), SaveManager.getVolume("master"))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), SaveManager.getVolume("voice"))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), SaveManager.getVolume("music"))
	
