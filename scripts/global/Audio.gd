extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func queueRequest(requestOptions: Array[AudioStreamMP3]):
	for i in $enemy_sounds.get_children():
		if not i.playing:
			i.stream = requestOptions[randi_range(0, requestOptions.size() - 1)]
			i.play()
			return



func loadNextNightSong():
#	$AudioStream_Music.stream = load( nightSongs[ randi()%nightSongs.size()-1 ])
	$AudioStream_Music.play()


func _on_audio_stream_music_finished():
	loadNextNightSong()
