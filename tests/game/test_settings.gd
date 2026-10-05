extends GameTest

#Settings never persists anything in these tests (persist = false), and every test puts the
#values it touched back.

var saved: Dictionary
var savedSession: Dictionary

func before_each():
	saved = Settings.values.duplicate(true)
	savedSession = Settings.sessionOnly.duplicate(true)

func after_each():
	for key in saved: Settings.values[key] = saved[key]
	Settings.sessionOnly = savedSession
	Settings.apply_all()

func test_validate_rejects_wrong_types_and_values():
	assert_null(Settings.validate("gfx/smoke", "full"))
	assert_null(Settings.validate("gfx/smoke", 7))
	assert_null(Settings.validate("no/such_key", 1))
	assert_eq(Settings.validate("audio/master", 2), 1.0, "ints are accepted for float keys and clamped")
	assert_eq(Settings.validate("controls/deadzone", 0.0), 0.2)

func test_apply_preset_sets_every_preset_key():
	for tier in 4:
		Settings.apply_preset(tier, false)
		assert_eq(Settings.get_value("meta/tier"), tier)
		for key in Settings.PRESET:
			assert_eq(Settings.get_value(key), Settings.PRESET[key][tier], key)

func test_changing_a_preset_key_shows_custom():
	Settings.apply_preset(Settings.Tier.LOW, false)
	Settings.set_value("gfx/smoke", 2, false)
	assert_eq(Settings.get_value("meta/tier"), Settings.Tier.CUSTOM)

func test_non_preset_key_keeps_the_preset():
	Settings.apply_preset(Settings.Tier.MEDIUM, false)
	Settings.set_value("audio/music", 0.25, false)
	assert_eq(Settings.get_value("meta/tier"), Settings.Tier.MEDIUM)

func test_legacy_volume_curve():
	assert_eq(Settings.legacy_volume(0.0), 1.0, "0 dB was the old default and stays full volume")
	assert_eq(Settings.legacy_volume(10.0), 1.0, "boosted volumes clamp to 100%")
	assert_eq(Settings.legacy_volume(-500.0), 0.0, "the old mute")
	assert_almost_eq(Settings.legacy_volume(-12.0), 0.5, 0.05)

func test_plain_text_and_reduce_motion_override_presets():
	Settings.apply_preset(Settings.Tier.HIGH, false)
	Settings.set_value("access/plain_text", true, false)
	assert_eq(Settings.text_quality(), 0)
	Settings.set_value("access/reduce_motion", true, false)
	assert_eq(Settings.celebration_level(), 1)
	Settings.set_value("access/reduce_flashing", true, false)
	assert_eq(Settings.celebration_level(), 0)

func test_adapter_id_matches_across_renderers():
	var vulkan = Settings.adapterId("Intel(R) HD Graphics 620", "Intel")
	var angle = Settings.adapterId("ANGLE (Intel, Intel(R) HD Graphics 620 (0x00005916) Direct3D11 vs_5_0 ps_5_0, D3D11-27.20.100.8681)", "Intel")
	assert_eq(vulkan, angle)

func test_binding_round_trip():
	var key = Settings.keyEvent(KEY_J)
	assert_true(Settings.sameInput(Settings.deserialize(Settings.serialize(key)), key))
	var pad = Settings.joyButton(JOY_BUTTON_X)
	assert_true(Settings.sameInput(Settings.deserialize(Settings.serialize(pad)), pad))
	assert_false(Settings.sameInput(key, pad))

func test_unsaved_changes_keep_the_file_value():
	var onDisk = Settings.get_value("gfx/smoke")
	var other = 0 if onDisk != 0 else 2
	Settings.set_value("gfx/smoke", other, false)
	assert_eq(Settings.sessionOnly.get("gfx/smoke"), onDisk, "save_now writes the remembered value, not the session one")
	Settings.set_value("gfx/smoke", other, true)
	assert_false(Settings.sessionOnly.has("gfx/smoke"), "a saved change is the player's")
