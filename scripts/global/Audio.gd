extends Node

#Pool of one-shot sound players for goons, pickups and crushes. Settings audio_perf/max_sfx
#sets how many of the pool's players may sound at once; starts per frame scale with it.
#Music is the radio (Radio, docs/RADIO.md), a child made here: Audio.radio.
const POOL_VOLUME_DB = 0.0

var soundsStartedThisFrame: int = 0
@onready var players = $enemy_sounds.get_children()
var radio: Radio


func _ready():
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)


func _process(_delta):
	soundsStartedThisFrame = 0


func queueRequest(requestOptions: Array[AudioStreamMP3]):
	if requestOptions.size() > 0:
		play(requestOptions[randi_range(0, requestOptions.size() - 1)])

#returns false when the sound was dropped by the limiter
func play(stream: AudioStream, volumeOffsetDb: float = 0.0, pitch: float = 1.0) -> bool:
	var maxSounds = Settings.get_value("audio_perf/max_sfx")
	if soundsStartedThisFrame >= maxi(2, maxSounds / 6): return false
	for i in mini(maxSounds, players.size()):
		var player = players[i]
		if not player.playing:
			player.stream = stream
			player.volume_db = POOL_VOLUME_DB + volumeOffsetDb
			player.pitch_scale = pitch
			player.play()
			soundsStartedThisFrame += 1
			return true
	return false
