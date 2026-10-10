extends GameTest

#The radio (docs/RADIO.md): shuffle bags, station scanning, segment scheduling and switching.
#Behavior is tested on a private Radio over tests/game/radio_fixture (tiny tones), so the tests
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

func test_segment_counts_and_weights():
	var station = RadioStation.new()
	station.files = {"song":["s1", "s2"], "ident":["i1"], "talk":["t1", "t2"], "ad":[]}
	station.reseed(11)
	station.segmentCounts.assign([1.0, 0.0, 0.0])
	for i in 50: assert_eq(station.pickSegments(), [], "count 0 never plays a segment")
	station.segmentCounts.assign([0.0, 1.0, 0.0])
	var counts := {}
	for i in 400:
		var picked = station.pickSegments()
		assert_eq(picked.size(), 1)
		counts[picked[0].kind] = counts.get(picked[0].kind, 0) + 1
	assert_false(counts.has("ad"), "a kind with no files never plays")
	assert_between(counts.get("ident", 0), 150, 250, "equal weights split evenly")
	station.weights["talk"] = 0.0
	for i in 50: assert_eq(station.pickSegments()[0].kind, "ident", "weight 0 turns a kind off")

func test_two_segments_are_different_kinds():
	var station = RadioStation.new()
	station.files = {"song":["s1"], "ident":["i1", "i2"], "talk":["t1"], "ad":["a1"]}
	station.reseed(5)
	station.segmentCounts.assign([0.0, 0.0, 1.0])
	for i in 200:
		var picked = station.pickSegments()
		assert_eq(picked.size(), 2)
		assert_true(picked[0].kind != picked[1].kind, "two segments in a row are never the same kind")
	station.files = {"song":["s1"], "ident":["i1"], "talk":[], "ad":[]}
	assert_eq(station.pickSegments().size(), 1, "with one kind available, two becomes one")

func test_even_counts_and_no_two_empty_gaps():
	var station = RadioStation.new()
	station.files = {"song":["s1"], "ident":["i1"], "talk":["t1"], "ad":["a1"]}
	station.reseed(9)
	station.segmentCounts.assign([1.0, 1.0, 1.0])
	var sizes := [0, 0, 0]
	var lastSize = -1
	for i in 1600:
		var size = station.pickSegments().size()
		assert_false(size == 0 && lastSize == 0, "two empty gaps in a row")
		lastSize = size
		sizes[size] += 1
	assert_between(sizes[0], 330, 470, "a gap is empty about a quarter of the time")
	for n in [1, 2]: assert_between(sizes[n], 520, 680, "%d segments about 3/8 of the time" % n)

func test_only_empty_gaps_when_nothing_else_can_play():
	var station = RadioStation.new()
	station.files = {"song":["s1"], "ident":[], "talk":[], "ad":[]}
	station.segmentCounts.assign([1.0, 1.0, 1.0])
	for i in 20: assert_eq(station.pickSegments(), [], "no segments to play is still fine")
	station.segmentCounts.assign([1.0, 0.0, 0.0])
	station.files = {"song":["s1"], "ident":["i1"], "talk":[], "ad":[]}
	for i in 20: assert_eq(station.pickSegments(), [], "segment_counts [1, 0, 0] stays all songs")

func test_legacy_segment_chance():
	var station = RadioStation.new()
	station.applyConfig({"segment_chance": 0.25})
	assert_eq(station.segmentCounts, [0.75, 0.25, 0.0] as Array[float])
	station.applyConfig({"segment_counts": [1, 2, 3]})
	assert_eq(station.segmentCounts, [1.0, 2.0, 3.0] as Array[float])

func test_a_song_always_follows_the_segments():
	for i in 100:
		var plan = radio.planAfterSong()
		assert_between(plan.size(), 1, 3)
		assert_eq(plan.back().kind, "song")
		for item in plan.slice(0, plan.size() - 1): assert_true(item.kind in ["ident", "talk", "ad"], "unknown segment " + str(item.kind))
		if plan.size() == 3: assert_true(plan[0].kind != plan[1].kind, "two segments differ in kind")

func test_skip_goes_straight_to_a_song():
	for i in 30:
		radio.queue = radio.planAfterSong()
		var queuedSong = radio.queue.back().path
		radio.queue.push_front({"kind":"talk", "path":"talk"})
		radio.skip()
		assert_eq(radio.queue.size(), 1)
		assert_eq(radio.queue[0].kind, "song", "skip drops the segments")
		assert_eq(radio.queue[0].path, queuedSong, "and plays the song that was coming")
	radio.queue.clear()
	radio.skip()
	assert_eq(radio.queue[0].kind, "song", "with nothing queued, skip draws a song")
	radio.tune(Radio.OFF)
	radio.skip()
	assert_true(radio.queue.is_empty(), "skip does nothing with the radio off")

func test_bag_resumes_its_cycle():
	var rng = RandomNumberGenerator.new()
	rng.seed = 4
	var bag = RadioBag.new(["a", "b", "c", "d", "e"], rng)
	var played := [bag.next(), bag.next()]
	var saved = JSON.parse_string(JSON.stringify(bag.state()))
	var resumed = RadioBag.new(["a", "b", "c", "d", "e", "f"], rng)
	resumed.restore(saved)
	var rest := []
	for i in 4: rest.push_back(resumed.next())
	for item in played: assert_false(rest.has(item), "a song played before the restart waits for the next cycle")
	assert_true(rest.has("f"), "a song added since still comes up this cycle")
	var gone = RadioBag.new(["a"], rng)
	gone.restore(saved)
	assert_eq(gone.next(), "a", "a save naming removed songs still plays what is there")
	var junk = RadioBag.new(["a", "b"], rng)
	junk.restore({"pending":"nonsense"})
	assert_eq(junk.pending, [], "a broken save is ignored")

func test_station_state_round_trips():
	var station = RadioStation.new()
	station.files = {"song":["s1", "s2", "s3"], "ident":["i1"], "talk":["t1", "t2"], "ad":[]}
	var first = station.nextSong()
	station.pickSegments()
	var copy = RadioStation.new()
	copy.files = station.files
	copy.restore(JSON.parse_string(JSON.stringify(station.state())))
	assert_true(copy.bags.has("song"))
	assert_eq(copy.bags["song"].pending, station.bags["song"].pending, "the song bag carries over")
	assert_false(copy.bags["song"].pending.has(first))
	assert_false(radio.persist, "the tests never write user://radio.json")

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
		for w in station.segmentCounts: assert_true(w >= 0.0, "segment_counts are not negative")
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
