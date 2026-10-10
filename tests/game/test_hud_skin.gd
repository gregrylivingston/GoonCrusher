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

#the clock and the goal sit on the mirror's glass, and the luck and clover pickups fly to its charms
func test_the_mirror_holds_the_clock_and_the_goal():
	var hud = load(HUD_SCENE).instantiate()
	hud.get_node("TopCenter/Timer").free()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var mirror: HudMirror = hud.get_node("Mirror")
	var glass := Rect2(mirror.position + mirror.glass().position, mirror.glass().size)
	for part in ["TopCenter", "Objective"]:
		var node: Control = hud.get_node(part)
		assert_true(glass.grow(4.0).encloses(Rect2(node.position, node.size)), "%s is on the glass" % part)
	assert_true(hud.get_node("TopCenter").position.x + hud.get_node("TopCenter").size.x <= hud.get_node("Objective").position.x, "the clock is left of the goal")
	for group in ["luckui", "cloverui"]: assert_true(mirror.is_ancestor_of(get_tree().get_first_node_in_group(group)), group)
	assert_true(hud.get_child(0) == mirror, "drawn under them")
	hud.free()

#each die and the clover hangs on its own string with its own period, and they rest apart
func test_charms_swing_apart():
	var periods := {}
	for charm in HudMirror.CHARMS: periods[charm[2]] = true
	assert_eq(periods.size(), HudMirror.CHARMS.size(), "no two charms share a period")
	assert_eq(HudMirror.CHARMS.size(), HudMirror.DICE_SHOWN + 1, "three dice and the clover")
	var mirror := HudMirror.new()
	add_child(mirror)
	for i in HudMirror.CHARMS.size():
		for j in i:
			assert_true(mirror.charmPoint(i, true).distance_to(mirror.charmPoint(j, true)) >= 12.0, "charms %d and %d rest apart" % [i, j])
	#tied to the top of the frame, their strings run down behind it and they hang clear under it
	assert_true(mirror.hook().y < mirror.body().get_center().y, "the strings are tied at the top")
	assert_true(mirror.charms.show_behind_parent, "the charms are behind the frame")
	for i in HudMirror.CHARMS.size(): assert_gt(mirror.charmPoint(i, true).y, mirror.body().end.y + 8.0, "charm %d hangs under the frame" % i)
	mirror.free()
	assert_eq(HudMirror.diceFor(1), 1)
	assert_eq(HudMirror.diceFor(6), 1)
	assert_eq(HudMirror.diceFor(7), 2)
	assert_eq(HudMirror.diceFor(18), 3)
	assert_eq(HudMirror.diceFor(50), 3)

#a jolt throws the charms up their strings; they bounce, land on them and come to rest hanging
func test_charms_bounce():
	var mirror := HudMirror.new()
	add_child(mirror)
	mirror.jolt(Vector2(-20.0, 0.0))
	mirror.stepCharms(0.0, 0.0, 1.0 / 60.0)
	for i in HudMirror.CHARMS.size(): assert_eq(mirror.drops[i], 0.0, "ordinary driving is no jolt (charm %d)" % i)
	mirror.jolt(Vector2(-500.0, 0.0))
	var highest := 0.0
	var landings := 0
	var wasUp := false
	for frame in 40:
		mirror.stepCharms(0.0, 0.0, 1.0 / 60.0)
		highest = minf(highest, mirror.drops[0])
		if wasUp && mirror.drops[0] == 0.0: landings += 1
		wasUp = mirror.drops[0] < 0.0
		for i in HudMirror.CHARMS.size(): assert_true(mirror.drops[i] <= 0.0 && mirror.drops[i] >= -HudMirror.LIFT_MAX, "a string never stretches (charm %d)" % i)
	assert_true(highest < -8.0, "a crash hops the die up its string")
	assert_true(landings > 0, "it lands on its string")
	for frame in 600: mirror.stepCharms(0.0, 0.0, 1.0 / 60.0)
	for i in HudMirror.CHARMS.size():
		assert_eq(mirror.drops[i], 0.0, "charm %d comes to rest" % i)
		assert_true(absf(mirror.angles[i] - HudMirror.CHARMS[i][0]) < 0.01, "charm %d hangs where it rests" % i)
	#braking or pulling away holds them up
	for frame in 120: mirror.stepCharms(0.0, -HudMirror.LIFT_ACCEL, 1.0 / 60.0)
	assert_true(mirror.drops[0] < -HudMirror.LIFT * 0.5, "a hard stop lifts them")
	mirror.free()

#the dice show luck in pips: a die for every six, three at most
func test_mirror_names():
	var known := [&"", &"checker", &"lights", &"clinic", &"console", &"keys", &"convex", &"screen"]
	for id in HudSkin.SKINS: assert_true(known.has(HudSkin.named(id).mirror), "%s: mirror '%s'" % [id, HudSkin.named(id).mirror])
	#a dashboard's own hangs are ones the mirror can draw, each with a string of its own that swings out of step
	var periods := {}
	for charm in HudMirror.CHARMS + HudMirror.HANGS: periods[charm[2]] = true
	assert_eq(periods.size(), HudMirror.CHARMS.size() + HudMirror.HANGS.size(), "no hang shares a period")
	for id in HudSkin.SKINS:
		var skin := HudSkin.named(id)
		assert_true(skin.hangs.size() <= HudMirror.HANGS.size(), "%s: a string for every hang" % id)
		assert_true(skin.mirror != &"console" || skin.hangs.is_empty(), "%s: nothing hangs from a console" % id)
		for hang in skin.hangs: assert_true(HudMirror.HANG_KINDS.has(hang), "%s: hang '%s'" % [id, hang])
	var full := HudMirror.new()
	add_child(full)
	full.strings = HudMirror.CHARMS + HudMirror.HANGS
	for i in full.strings.size():
		assert_gt(full.charmPoint(i, true).y, full.body().end.y + 8.0, "string %d hangs under the frame" % i)
		for j in i: assert_true(full.charmPoint(i, true).distance_to(full.charmPoint(j, true)) >= 12.0, "strings %d and %d rest apart" % [i, j])
	full.free()
	assert_eq(HudMirror.PIPS.size(), 7)
	for face in range(1, 7): assert_eq(HudMirror.PIPS[face].size(), face, "a %d has %d pips" % [face, face])

#a star every wave on one clock for the whole run: crossing into another district must not restart it
func test_the_wave_clock_ignores_districts():
	Region.resetRegions()
	Region.runTime = 95.0
	Region.wave = 2
	var left := Region.waveSecondsLeft()
	Region.updatePlayerRegion({"region": 911, "terrain": Root.terrain.GRASS})
	Region.updatePlayerRegion({"region": 912, "terrain": Root.terrain.SAND})
	assert_eq(Region.wave, 2)
	assert_eq(Region.waveSecondsLeft(), left)
	assert_almost_eq(Region.waveProgress(), 35.0 / 60.0, 0.001)
	Region.resetRegions()

#the visors hold what the corners did, and nothing is left in them that the player can't use
func test_the_visors_replace_the_corner_panels():
	var hud = load(HUD_SCENE).instantiate()
	hud.get_node("TopCenter/Timer").free()
	add_child(hud)
	await get_tree().process_frame
	for group in ["currentGoonsCrushedui", "slotmachineui"]: assert_true(hud.get_node("LeftVisor").is_ancestor_of(get_tree().get_first_node_in_group(group)), group)
	for group in ["coinui", "starui", "gemui"]: assert_true(hud.get_node("RightVisor").is_ancestor_of(get_tree().get_first_node_in_group(group)), group)
	for gone in ["TopLeft", "TopRight", "NowPlaying", "Systems"]: assert_true(hud.get_node_or_null(gone) == null, "%s is gone" % gone)
	assert_eq(hud.find_children("*", "Button", true, false).size(), 0, "no pause button: Esc, Start and losing focus pause")
	hud.free()

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

#every dash starts a run pristine: the glass cracks with the hull, the speedometer's first, and mends with it
func test_the_glass_cracks_as_the_hull_drops():
	var car = load("res://scene/car/sedan/sedan.tscn").instantiate()
	var speedo := HudDial.new()
	var tach := HudDial.new()
	tach.kind = HudDial.Kind.TACH
	for dial in [speedo, tach]: dial.skin = HudSkin.named(car.hudSkin)
	car.health = 100.0
	assert_eq(HudDial.glassStage(car), 0, "a whole car has whole glass")
	assert_eq(speedo.cracks(car), 0, "the sedan's too")
	assert_false(tach.tapeOn, "and no tape until Duct Tape patches")
	var last := 0
	for hull in [HudDial.SCUFFED - 1.0, HudDial.WORN - 1.0, HudDial.LOW - 1.0]:
		car.health = hull
		assert_eq(HudDial.glassStage(car), last + 1, "one more stage under %d hull" % int(hull + 1.0))
		assert_eq(tach.cracks(car), last, "the tachometer is a stage behind")
		last += 1
	for crack in HudDial.CRACKS: assert_true(crack[0] >= 1 && crack[0] <= last, "a crack shows at a stage the hull reaches")
	car.health = 100.0
	assert_eq(speedo.cracks(car), 0, "repaired")
	speedo.free()
	tach.free()
	car.free()

func test_heart_monitor_beats():
	assert_eq(HudDial.heartbeat(0.0), 0.0)
	assert_eq(HudDial.heartbeat(0.8), 0.0)
	assert_true(HudDial.heartbeat(0.31) > 30.0, "the spike")

func test_classic_dashboard_is_a_setting():
	assert_eq(Settings.DEFAULTS["access/classic_dash"], false)
