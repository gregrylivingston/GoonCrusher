extends GameTest

#The cars' dashboards (HudSkin, HudDial, HudInstrument; docs/HUD.md "Dashboards"): every car has one, a skin
#only repaints, and the HUD with no car is the house look.

const CARS := ["sedan", "taxi", "police", "ambulance", "semi", "pickup", "van", "racer", "supercar"]
const HUD_SCENE := "res://scene/player/playerRoot.tscn"

func test_every_car_names_a_dashboard():
	for id in CARS:
		var info: CarInfo = load("res://scene/car/%s/%s_info.tres" % [id, id])
		assert_true(HudSkin.SKINS.has(info.hudSkin), "%s names '%s'" % [id, info.hudSkin])
		assert_true(info.hudSkin != &"house", "%s has its own dashboard" % id)
		var car = load("res://scene/car/%s/%s.tscn" % [id, id]).instantiate()
		assert_eq(car.hudSkin, info.hudSkin, "%s's car takes it from its info" % id)
		car.free()

func test_an_unknown_skin_is_the_house_look():
	assert_eq(HudSkin.named(&"no_such_dash").id, &"house")
	var house := HudSkin.named(&"house")
	assert_eq(house.rim, HudTheme.RIM)
	assert_eq(house.instrument, &"")
	assert_eq(HudSkin.current().id, &"house", "no car is being driven")

#a skin is paint: green still means go, red still means stop, and the numerals stand out from the face
func test_skins_keep_their_meaning_and_stay_legible():
	for id in HudSkin.SKINS:
		var skin := HudSkin.named(id)
		assert_true(skin.ok.g > skin.ok.r && skin.ok.g > skin.ok.b, "%s: ok is green" % id)
		assert_true(skin.bad.r > skin.bad.g && skin.bad.r > skin.bad.b, "%s: bad is red" % id)
		assert_true(absf(skin.text.get_luminance() - skin.face.get_luminance()) > 0.5, "%s: numerals against the face" % id)
		assert_true(absf(skin.needle.get_luminance() - skin.face.get_luminance()) > 0.15 || skin.needle.s > 0.5, "%s: the needle against the face" % id)
		assert_true(skin.sweep >= 70.0 && skin.sweep <= 90.0, "%s: the scale fits the part of the dial on screen" % id)
		assert_true(skin.lamp >= 0 && skin.lamp < HudSkin.Lamp.size(), "%s: lamp style" % id)
		assert_true(skin.instrument == &"" || HudInstrument.KINDS.has(skin.instrument), "%s: instrument '%s'" % [id, skin.instrument])
		for kind in skin.rects:
			assert_true(kind == HudDial.Kind.TACH || kind == HudDial.Kind.SPEEDO, "%s moves a real cluster" % id)
			var to: Array = skin.rects[kind]
			assert_eq(to.size(), 4, "%s: offsets" % id)
			assert_true(to[2] - to[0] >= 100.0 && to[3] - to[1] >= 36.0, "%s: cluster %d keeps a size" % [id, kind])
			assert_true(to[0] >= 0.0 if kind == HudDial.Kind.TACH else to[2] <= 0.0, "%s: cluster %d keeps its side" % [id, kind])

#every system has a lamp, on the same side on every dash: go on the left, handling and sight on the right
func test_every_system_has_a_lamp_on_one_side():
	var all := HudLamps.LEFT + HudLamps.RIGHT
	assert_eq(all.size(), HudLamps.SYSTEMS.size())
	for id in HudLamps.SYSTEMS: assert_eq(all.count(id), 1, id)
	for id in OverheadCarBody2D.SYSTEM_STATS: assert_true(HudLamps.SYSTEMS.has(id), "%s has a lamp" % id)

#a sunken dial's scale stays on screen: its ends are above the hub, or level with it
func test_the_scale_stays_above_the_screen_edge():
	for id in HudSkin.SKINS:
		var skin := HudSkin.named(id)
		assert_true(skin.sweep + HudDial.TILT <= 105.0, "%s: the scale's low end clears the bottom edge" % id)

func test_the_hud_with_no_car_is_the_house_dash():
	var hud = load(HUD_SCENE).instantiate()
	hud.get_node("TopCenter/Timer").free()
	add_child(hud)
	await get_tree().process_frame
	assert_eq(hud.get_node("Tach").skin.id, &"house")
	assert_false(hud.get_node("Instrument").visible, "no signature instrument")
	assert_true(hud.hudControls.has(hud.get_node("Instrument")), "HUD Scale covers the instrument")
	hud.free()

#the numbers on the tach match where its needle points: one a thousand rpm up to the dial's top
func test_tach_numbers_follow_the_dial():
	var dial := HudDial.new()
	dial.kind = HudDial.Kind.TACH
	dial.rpmMax = HudDial.rpmMaxFor(6.0)
	assert_eq(dial.tachMajors(), 7)
	assert_eq(dial.tachLabel(dial.tachMajors()), "7")
	dial.skin = HudSkin.named(&"rig") #the semi's reads in hundreds
	dial.rpmMax = HudDial.rpmMaxFor(2.4)
	assert_eq(dial.tachMajors(), 8)
	assert_eq(dial.tachLabel(dial.tachMajors()), "40")
	assert_eq(dial.tachCaption(), "RPM x100")
	dial.free()

func test_heart_monitor_beats():
	assert_eq(HudDial.heartbeat(0.0), 0.0)
	assert_eq(HudDial.heartbeat(0.8), 0.0)
	assert_true(HudDial.heartbeat(0.31) > 30.0, "the spike")

func test_classic_dashboard_is_a_setting():
	assert_eq(Settings.DEFAULTS["access/classic_dash"], false)
