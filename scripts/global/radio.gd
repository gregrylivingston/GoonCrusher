class_name Radio extends Node

#The car radio (docs/RADIO.md): stations of in-house tracks scanned from sound/radio/, played in
#runs and menus on the Music bus. A child of the Audio autoload: Audio.radio.
#Two players crossfade songs; idents, talk and ads play between songs. Only the next item is loaded,
#on a worker (ResourceLoader.load_threaded_request), so a station switch never hitches the main
#thread. Headless runs (tests, playtests, benches) scan and schedule but never load or play audio.

signal trackStarted(info: Dictionary)
signal stationChanged(id: StringName)

const ROOT := "res://sound/radio"
const OFF := &"off"
const MUSIC_DB := 0.0
const SILENT_DB := -80.0
const SWITCH_FADE := 0.4      #s: the old station fades out before the new one starts
const SEGMENT_OVERLAP := 0.1  #s: segments butt-join with this much overlap
const MUFFLE_POLL := 0.25     #s between checks for the pause menu
const STATE_PATH := "user://radio.json"  #where each station's shuffle left off (not in the save: per machine)

var stations := {}                  #id -> RadioStation
var order: Array[StringName] = []   #stations with songs, in picker order
var station: StringName = OFF
var audible := true                 #false headless: schedule only
var persist := false                #saves and restores the shuffle (the game's radio, never headless or a test's)
var players: Array[AudioStreamPlayer] = []
var active := 0
var current := {}                   #the item on players[active]: {kind, path, stream}
var queue: Array = []               #upcoming items; the head is loaded before it is needed
var loadingPath := ""
var lastSong := {}                  #now-playing info of the latest song
var switchUntil := 0.0
var fadeTween: Tween
var muffleClock := 0.0
var musicBus := -1
var lowpass := -1


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS #keeps playing under the pause menu
	audible = DisplayServer.get_name() != "headless"
	for i in 2:
		var player = AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = MUSIC_DB
		add_child(player)
		players.push_back(player)
	musicBus = AudioServer.get_bus_index("Music")
	if musicBus >= 0:
		for i in AudioServer.get_bus_effect_count(musicBus):
			if AudioServer.get_bus_effect(musicBus, i) is AudioEffectLowPassFilter: lowpass = i
	scan()
	persist = audible
	loadState()
	Settings.changed.connect(onSettingChanged)
	tune(StringName(Settings.get_value("audio/station")))


func scan(root: String = ROOT) -> void:
	stations.clear()
	order.clear()
	for dir in RadioStation.listDirs(root):
		var found = RadioStation.fromFolder(root + "/" + dir)
		if found.hasSongs(): stations[found.id] = found
	order.assign(stations.keys())
	order.sort_custom(func(a, b):
		if stations[a].order != stations[b].order: return stations[a].order < stations[b].order
		return String(a) < String(b))

#---------- API ----------

#stations the picker offers, in order, then Radio Off
func stationIds() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in order:
		if isStationOpen(id): ids.push_back(id)
	ids.push_back(OFF)
	return ids

#[[id, name]] for an OptionRow; values are Strings because audio/station is a String setting
func stationOptions() -> Array:
	var out := []
	for id in stationIds(): out.push_back([String(id), stationName(id)])
	return out

func stationName(id: StringName) -> String:
	if stations.has(id): return stations[id].name
	return "Radio Off"

func stationColor(id: StringName) -> Color:
	if stations.has(id): return stations[id].color
	return Color(1, 1, 1, 0.5)

#package 12 hook: the unlock registry will answer this
func isStationOpen(_id: StringName) -> bool:
	return true

func setStation(id: StringName) -> void:
	Settings.set_value("audio/station", String(id))

#ends what is playing and goes straight to the next song, skipping any segments queued before it
func skip() -> void:
	if station == OFF: return
	var next = {}
	for item in queue:
		if item.kind == "song":
			next = item
			break
	if next.is_empty(): next = songItem(stations[station].nextSong())
	if loadingPath != "" && loadingPath != next.path: cancelLoad()
	queue = [next]
	fadeOutAll()
	current = {}
	lastSong = {}
	requestHead()

func isOn() -> bool:
	return station != OFF

#Radio Off and back (the now-playing card's right click)
func toggle() -> void:
	setStation(OFF if isOn() else (order[0] if not order.is_empty() else OFF))

#steps through stationIds(), wrapping
func cycleStation(direction: int = 1) -> void:
	var ids = stationIds()
	var index = maxi(0, ids.find(station))
	setStation(ids[posmod(index + direction, ids.size())])

func nowPlaying() -> Dictionary:
	var info = lastSong.duplicate()
	info["station"] = station
	info["stationName"] = stationName(station)
	info["color"] = stationColor(station)
	info["kind"] = current.get("kind", "")
	return info

#---------- scheduling ----------

func onSettingChanged(key: String, value) -> void:
	if key == "audio/station": tune(StringName(value))

#switch station: fade out what plays, then an ident (when the station has one) and a fresh song
func tune(id: StringName) -> void:
	if id != OFF && not stations.has(id): id = order[0] if not order.is_empty() else OFF #a removed station
	if id == station && (id == OFF || not current.is_empty() || not queue.is_empty()): return
	station = id
	queue.clear()
	cancelLoad()
	fadeOutAll()
	current = {}
	lastSong = {}
	stationChanged.emit(id)
	if id == OFF: return
	var picked = stations[id]
	var ident = picked.nextIdent()
	if ident != "": queue.push_back({"kind":"ident", "path":ident})
	queue.push_back(songItem(picked.nextSong()))
	requestHead()

#what follows a song: none, one or two segments (of different kinds), then the next song
func planAfterSong() -> Array:
	var picked: RadioStation = stations[station]
	var song = picked.nextSong()
	var out := []
	for segment in picked.pickSegments():
		if segment.get("path"): out.push_back(segment)
	out.push_back(songItem(song))
	return out

func songItem(path: String) -> Dictionary:
	return {"kind":"song", "path":path}

func overlapFor(from: Dictionary, to: Dictionary) -> float:
	if from.get("kind") == "song" && to.get("kind") == "song": return stations[station].crossfade
	return SEGMENT_OVERLAP

#---------- playback ----------

func _process(delta):
	if not audible: return
	updateMuffle(delta)
	if station == OFF: return
	if queue.is_empty(): queue.append_array(planAfterSong())
	var head: Dictionary = queue[0]
	if not head.has("stream"):
		pollLoad(head)
		return
	if nowSeconds() < switchUntil: return
	var player = players[active]
	if current.is_empty() || not player.playing:
		startHead()
		return
	var remaining = current.stream.get_length() - player.get_playback_position()
	if remaining <= overlapFor(current, head): startHead()

func requestHead() -> void:
	if not audible || queue.is_empty() || queue[0].has("stream"): return
	var path: String = queue[0].path
	if loadingPath == path: return
	if ResourceLoader.load_threaded_request(path, "AudioStream") != OK:
		push_warning("Radio: can't load " + path)
		queue.pop_front()
		return
	loadingPath = path

func pollLoad(head: Dictionary) -> void:
	if loadingPath != head.path:
		requestHead()
		return
	match ResourceLoader.load_threaded_get_status(head.path):
		ResourceLoader.THREAD_LOAD_LOADED:
			loadingPath = ""
			var stream = ResourceLoader.load_threaded_get(head.path)
			if stream is AudioStream: head["stream"] = stream
			else:
				push_warning("Radio: %s is not audio" % head.path)
				queue.pop_front()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Radio: failed to load " + head.path)
			loadingPath = ""
			queue.pop_front()

#a finished request must still be collected, or the loader keeps it; the result is dropped
func cancelLoad() -> void:
	if loadingPath != "" && ResourceLoader.load_threaded_get_status(loadingPath) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(loadingPath)
	loadingPath = ""

func startHead() -> void:
	var item: Dictionary = queue.pop_front()
	var old = players[active]
	var crossfading = not current.is_empty() && old.playing && overlapFor(current, item) > SEGMENT_OVERLAP
	if fadeTween: fadeTween.kill()
	if current.is_empty(): #just tuned in: nothing from the old station may linger
		for each in players: each.stop()
	else: active = 1 - active
	var player = players[active]
	player.stream = item.stream
	player.volume_db = SILENT_DB if crossfading else MUSIC_DB
	player.play()
	if crossfading: crossfade(old, player, overlapFor(current, item))
	current = item
	if item.kind == "song":
		lastSong = stations[station].songInfo(item.path)
		trackStarted.emit(nowPlaying())
		saveState()
	if queue.is_empty(): queue.append_array(planAfterSong())
	requestHead()

#---------- the shuffle across launches ----------

func _exit_tree():
	saveState()

func saveState() -> void:
	if not persist: return
	var out := {}
	for id in stations: out[String(id)] = stations[id].state()
	var file = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(out))

func loadState() -> void:
	if not persist || not FileAccess.file_exists(STATE_PATH): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if not saved is Dictionary: return
	for id in stations:
		if saved.get(String(id)) is Dictionary: stations[id].restore(saved[String(id)])

#equal-power crossfade: the sum stays level through the middle
func crossfade(from: AudioStreamPlayer, to: AudioStreamPlayer, seconds: float) -> void:
	fadeTween = create_tween()
	fadeTween.tween_method(func(k: float):
		from.volume_db = MUSIC_DB + linear_to_db(maxf(cos(k * PI / 2.0), 0.0001))
		to.volume_db = MUSIC_DB + linear_to_db(maxf(sin(k * PI / 2.0), 0.0001)), 0.0, 1.0, seconds)
	fadeTween.tween_callback(from.stop)

func fadeOutAll() -> void:
	if fadeTween: fadeTween.kill()
	switchUntil = nowSeconds() + SWITCH_FADE
	if not audible: return
	fadeTween = create_tween().set_parallel()
	for player in players:
		if player.playing: fadeTween.tween_property(player, "volume_db", SILENT_DB, SWITCH_FADE)
	fadeTween.chain().tween_callback(func():
		for player in players: player.stop())

#a gentle low-pass on the Music bus while the pause menu is open (not under slot machines)
func updateMuffle(delta: float) -> void:
	if lowpass < 0: return
	muffleClock -= delta
	if muffleClock > 0.0: return
	muffleClock = MUFFLE_POLL
	var muffled = get_tree().paused && get_tree().get_first_node_in_group("pauseMenu") != null
	if AudioServer.is_bus_effect_enabled(musicBus, lowpass) != muffled:
		AudioServer.set_bus_effect_enabled(musicBus, lowpass, muffled)

static func nowSeconds() -> float:
	return Time.get_ticks_msec() / 1000.0
