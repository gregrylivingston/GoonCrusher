extends GameTest

#The radio (docs/RADIO.md): shuffle bags, station scanning, segment scheduling and switching.
#Behaviour is tested on a private Radio over tests/game/radio_fixture (tiny tones), so the tests
#don't depend on which songs ship; a few tests check the shipped stations in sound/radio/.
#Headless: the radio schedules but never loads or plays. Nothing writes audio/station.

const FIXTURE := "res://tests/game/radio_fixture"

var radio: Radio

func before_each():
	radio = Radio.new()
	add_child_autofree(radio)
	radio.scan(FIXTURE)
	radio.tune(&"alpha")

func test_bag_plays_everything_once_per_cycle():
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var bag = RadioBag.new(["a", "b", "c", "d", "e"], rng)
	for cycle in 20:
		var seen := {}
		for i in 5: seen[bag.next()] = true
		assert_eq(seen.size(), 5, "cycle %d repeats an item" % cycle)

func test_bag_never_repeats_across_cycles():
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	var bag = RadioBag.new(["a", "b", "c"], rng)
	var last = bag.next()
	for i in 300:
		var item = bag.next()
		assert_true(item != last, "the same item played twice in a row")
		last = item

func test_bag_edge_cases():
	assert_null(RadioBag.new([]).next(), "an empty bag gives nothing")
	var one = RadioBag.new(["solo"])
	assert_eq(one.next(), "solo")
	assert_eq(one.next(), "solo", "a one-song station repeats its song")

func test_stations_are_scanned_in_order():
	assert_eq(radio.order, [&"alpha", &"beta"], "a station without songs is left out")
	assert_eq(radio.stationIds(), [&"alpha", &"beta", Radio.OFF], "Radio Off is the last choice")
	assert_eq(radio.stationName(&"alpha"), "Alpha FM")
	assert_eq(radio.stationName(Radio.OFF), "Radio Off")
	for option in radio.stationOptions(): assert_eq(typeof(option[0]), TYPE_STRING, "options match the String setting")

func test_folders_are_read():
	var alpha: RadioStation = radio.stations[&"alpha"]
	assert_eq(alpha.files["song"].size(), 3)
	for kind in ["ident", "talk", "ad"]: assert_eq(alpha.files[kind].size(), 1, kind)
	assert_eq(radio.stations[&"beta"].short, "B", "short defaults to the name's initials")

func test_song_names_come_from_the_file():
	var station = RadioStation.new()
	station.name = "Lofi"
	assert_eq(station.songInfo("res://x/songs/Crush Hour - DJ Grille.ogg"), {"title":"Crush Hour", "artist":"DJ Grille"})
	assert_eq(station.songInfo("res://x/songs/rainy_drive.ogg"), {"title":"rainy drive", "artist":"Lofi"})

func test_segments_follow_chance_and_weights():
	var station = RadioStation.new()
	station.files = {"song":["s1", "s2"], "ident":["i1"], "talk":["t1", "t2"], "ad":[]}
	station.reseed(11)
	station.segmentChance = 0.0
	for i in 50: assert_eq(station.pickSegment(), {}, "chance 0 never plays a segment")
	station.segmentChance = 1.0
	var counts := {}
	for i in 400:
		var segment = station.pickSegment()
		counts[segment.kind] = counts.get(segment.kind, 0) + 1
	assert_false(counts.has("ad"), "a kind with no files never plays")
	assert_between(counts.get("ident", 0), 150, 250, "equal weights split evenly")
	station.weights["talk"] = 0.0
	for i in 50: assert_eq(station.pickSegment().kind, "ident", "weight 0 turns a kind off")

func test_a_song_always_follows_a_segment():
	for i in 100:
		var plan = radio.planAfterSong()
		assert_between(plan.size(), 1, 2)
		assert_eq(plan.back().kind, "song")
		if plan.size() == 2: assert_true(plan[0].kind in ["ident", "talk", "ad"], "unknown segment " + str(plan[0].kind))

func test_tuning_queues_an_ident_then_a_song():
	radio.tune(Radio.OFF)
	assert_true(radio.queue.is_empty(), "Radio Off queues nothing")
	radio.tune(&"beta")
	assert_eq(radio.station, &"beta")
	assert_eq(radio.queue.size(), 2)
	assert_eq(radio.queue[0].kind, "ident")
	assert_eq(radio.queue[1].kind, "song")
	assert_true(radio.queue[1].path.begins_with(FIXTURE + "/beta/songs/"))

func test_an_unknown_station_falls_back_to_the_first():
	radio.tune(&"no_such_station")
	assert_eq(radio.station, &"alpha")

func test_cycle_wraps_through_off():
	var ids = radio.stationIds()
	var index = ids.find(Radio.OFF)
	assert_eq(ids[posmod(index + 1, ids.size())], &"alpha", "after Radio Off comes the first station")

#---------- the shipped stations ----------

func test_shipped_stations_are_valid():
	var shipped: Radio = Audio.radio
	assert_true(shipped.stations.has(StringName(Settings.DEFAULTS["audio/station"])), "the default station has songs")
	for id in shipped.order:
		var station: RadioStation = shipped.stations[id]
		assert_between(station.segmentChance, 0.0, 1.0)
		for kind in station.files:
			for path in station.files[kind]: assert_true(ResourceLoader.exists(path), path + " is not imported")

func test_music_bus_ducks_under_voice():
	var bus = AudioServer.get_bus_index("Music")
	var ducks := false
	for i in AudioServer.get_bus_effect_count(bus):
		var effect = AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectCompressor && effect.sidechain == &"Voice": ducks = true
	assert_true(ducks, "the Music bus has a compressor keyed from Voice")
	assert_true(Audio.radio.lowpass >= 0, "the pause muffle is on the Music bus")
	assert_false(AudioServer.is_bus_effect_enabled(bus, Audio.radio.lowpass), "the muffle starts off")
