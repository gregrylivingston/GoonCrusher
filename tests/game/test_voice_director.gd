extends GameTest

#The VoiceDirector (scripts/global/voice_director.gd): which line gets to speak. Tested on a private
#director with its own clock and one-second tones, so nothing depends on the cars' recorded lines.

var voice: VoiceDirector
var heard: Array = [] #[kind, text] of every line that started

func before_each():
	voice = VoiceDirector.new()
	add_child_autofree(voice)
	voice.rng.seed = 5
	voice.clock = 0
	heard = []
	voice.spoke.connect(onSpoke)

func onSpoke(kind: StringName, text: String, _seconds: float) -> void:
	heard.push_back([kind, text])

func tone(seconds := 1.0) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(8000 * seconds))
	wav.data = data
	return wav

func wait(seconds: float) -> void:
	voice.clock += int(seconds * Engine.physics_ticks_per_second)

func test_a_line_is_spoken():
	assert_true(voice.say(&"pickup", [tone()], 0.0, "Nice."))
	assert_eq(heard, [[&"pickup", "Nice."]])

func test_unknown_kinds_and_empty_sets_say_nothing():
	assert_false(voice.say(&"gossip", [tone()]))
	assert_false(voice.say(&"pickup", []))
	assert_eq(heard.size(), 0)

func test_a_line_of_the_same_or_a_lesser_kind_waits():
	voice.say(&"award", [tone()])
	assert_false(voice.say(&"award", [tone()]), "the same kind while the line plays")
	assert_false(voice.say(&"pickup", [tone()]), "a lesser kind while the line plays")
	wait(1.0 + VoiceDirector.COOLDOWN - 0.5)
	assert_false(voice.say(&"pickup", [tone()]), "still inside the cooldown")
	wait(1.0)
	assert_true(voice.say(&"pickup", [tone()]), "the cooldown is over")

func test_a_more_important_line_cuts_in():
	voice.say(&"pickup", [tone()])
	assert_true(voice.say(&"giant", [tone()]))
	assert_true(voice.say(&"warning", [tone()]))
	assert_false(voice.say(&"win", [tone()]), "nothing cuts in on a warning")
	assert_eq(heard.size(), 2 + 1)

func test_kinds_are_ranked_as_agreed():
	assert_eq(VoiceDirector.KINDS.slice(0, 7), [&"warning", &"win", &"record", &"jackpot", &"giant", &"award", &"region"])

func test_no_line_repeats_within_the_memory():
	var lines := []
	for i in VoiceDirector.MEMORY + 2: lines.push_back(tone())
	var spoken := []
	for i in 60:
		voice.say(&"pickup", lines)
		spoken.push_back(voice.recent[-1])
		wait(10.0)
	for i in spoken.size():
		for back in range(1, VoiceDirector.MEMORY + 1):
			if i - back >= 0: assert_true(spoken[i] != spoken[i - back], "line %d repeats one of the last %d" % [i, VoiceDirector.MEMORY])

func test_a_small_set_takes_turns():
	var lines := [tone(), tone()]
	var spoken := []
	for i in 6:
		voice.say(&"pickup", lines)
		spoken.push_back(voice.recent[-1])
		wait(10.0)
	for i in range(1, spoken.size()): assert_true(spoken[i] != spoken[i - 1], "two lines alternate")

func test_a_delayed_line_cut_off_never_starts():
	voice.say(&"pickup", [tone()], 0.05, "late")
	voice.say(&"warning", [tone()], 0.0, "now")
	await get_tree().create_timer(0.2).timeout
	assert_eq(heard, [[&"warning", "now"]])
