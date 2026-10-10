class_name VoiceDirector extends Node

#Who gets to speak. Every spoken line in a run goes through say(), which plays one line at a time on the
#Voice bus (the Music bus ducks under it, docs/RADIO.md). A child of the Audio autoload: Audio.voice.
#A line of a more important kind cuts in; any other waits out the line and COOLDOWN after it, and is
#dropped, not queued (a late line is worse than none). No line comes back while it is among the last
#MEMORY spoken. Timing is counted in physics ticks from the stream's length, so who speaks doesn't
#depend on the frame rate or the audio driver. Headless runs decide but never play.

signal spoke(kind: StringName, text: String, seconds: float) #text is "" for a line without a subtitle

const KINDS: Array[StringName] = [&"warning", &"win", &"record", &"jackpot", &"giant", &"award", &"region", &"pickup"] #most important first
const COOLDOWN := 5.0   #s of quiet after a line, for lines of its kind or a lesser one
const MEMORY := 3       #lines remembered, so none repeats that soon
const SUBTITLES := {}   #a line's file name without its extension -> what is said

var rng := RandomNumberGenerator.new()
var player: AudioStreamPlayer
var audible := true
var recent: Array = []        #the last MEMORY streams spoken, oldest first
var lastRank := -1            #the kind (index in KINDS) holding the floor until quietUntil
var quietUntil := 0           #physics tick when the line and its cooldown are over
var serial := 0               #counts accepted lines, so a delayed start knows it was cut off
var clock := -1               #tests set the tick; -1 reads the engine's


func _ready():
	audible = DisplayServer.get_name() != "headless"
	player = AudioStreamPlayer.new()
	player.bus = &"Voice"
	add_child(player)


## Speaks one of `lines` (AudioStreams) as a line of `kind`, after `delay` seconds. `text` is its subtitle;
## without one the line's entry in SUBTITLES is shown. False when the line was dropped.
func say(kind: StringName, lines: Array, delay := 0.0, text := "") -> bool:
	var rank := KINDS.find(kind)
	if rank < 0 || lines.is_empty(): return false
	var now := tick()
	if now < quietUntil && rank >= lastRank: return false
	var stream: AudioStream = pick(lines)
	recent.erase(stream)
	recent.push_back(stream)
	if recent.size() > MEMORY: recent.pop_front()
	var seconds := stream.get_length()
	lastRank = rank
	quietUntil = now + int((delay + seconds + COOLDOWN) * Engine.physics_ticks_per_second)
	serial += 1
	if text == "": text = SUBTITLES.get(stream.resource_path.get_file().get_basename(), "")
	player.stop() #a lesser line still playing
	if delay > 0.0 && is_inside_tree(): get_tree().create_timer(delay).timeout.connect(start.bind(serial, kind, stream, text, seconds))
	else: start(serial, kind, stream, text, seconds)
	return true


func start(id: int, kind: StringName, stream: AudioStream, text: String, seconds: float) -> void:
	if id != serial: return #a more important line cut in during the delay
	if audible:
		player.stream = stream
		player.play()
	spoke.emit(kind, text, seconds)


#a line not spoken lately; when all of them were, the one spoken longest ago
func pick(lines: Array) -> AudioStream:
	var fresh := lines.filter(func(line): return not recent.has(line))
	if fresh.is_empty():
		for line in recent:
			if lines.has(line): return line
	return fresh[rng.randi_range(0, fresh.size() - 1)]


func tick() -> int:
	return clock if clock >= 0 else Engine.get_physics_frames()
