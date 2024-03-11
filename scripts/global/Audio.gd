extends Node

var soundsStartedThisFrame: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	soundsStartedThisFrame = 0


func queueRequest(requestOptions: Array[AudioStreamMP3]):
	if requestOptions.size() > 0:
		for i in $enemy_sounds.get_children():
			if not i.playing && soundsStartedThisFrame < 4:
				i.stream = requestOptions[randi_range(0, requestOptions.size() - 1)]
				i.play()
				soundsStartedThisFrame += 1
				return



func loadNextNightSong():
#	$AudioStream_Music.stream = load( nightSongs[ randi()%nightSongs.size()-1 ])
	$AudioStream_Music.play()


func _on_audio_stream_music_finished():
	loadNextNightSong()
