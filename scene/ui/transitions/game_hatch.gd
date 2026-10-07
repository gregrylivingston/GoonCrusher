class_name GameHatch extends Node

#How the in-run games come and go (slot machine, The Deal, Claw Crane, Pit Shop; docs/UI.md,
#"Transitions"): the panel skids in from the right and brakes, leaving rubber on the road, then a
#hatch shutter over it rolls up to reveal the game. Leaving, the hatch slams down and the panel
#peels out to the left in tire smoke. Reduce Motion fades instead; the harnesses skip it.
#  var hatch = GameHatch.attach(layer, stage, card, "BONUS")   stage: the full-screen Control that
#  hatch.enter(openAfter)                                        moves; card: the panel the hatch covers
#  await hatch.leave()

const SKID_SECONDS := 0.4
const OPEN_SECONDS := 0.32
const SLAM_SECONDS := 0.16
const PEEL_SECONDS := 0.32

var stage: Control
var card: Control
var label := ""
var hatch: Control
var door: ShutterDoor
var fx := TransitionFx.new()

static func attach(layer: Node, movingStage: Control, coveredCard: Control, text: String) -> GameHatch:
	var h = GameHatch.new()
	h.stage = movingStage
	h.card = coveredCard
	h.label = text
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(h)
	return h

func screen() -> Vector2:
	return stage.get_viewport().get_visible_rect().size

#skids the panel in; the hatch rolls up `openAfter` seconds after it lands
func enter(openAfter := 0.2) -> void:
	if Transition.instant(): return
	fx.autoFree = false
	get_parent().add_child(fx)
	hatch = Control.new()
	hatch.name = "hatch"
	hatch.clip_contents = true
	hatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(hatch)
	door = ShutterDoor.new()
	door.small = true
	door.label = label
	door.labelSize = 72
	door.labelAt = 0.5
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatch.add_child(door)
	hatch.resized.connect(func(): door.size = hatch.size)
	door.size = hatch.size
	if Settings.reduce_motion():
		door.visible = false
		stage.modulate.a = 0.0
		stage.create_tween().tween_property(stage, "modulate:a", 1.0, Transition.FADE_SECONDS)
		return
	var size = screen()
	stage.pivot_offset = size / 2.0
	stage.position.x = size.x
	stage.rotation = -0.06
	Transition.sound("screech", -6.0)
	var t = stage.create_tween()
	t.tween_property(stage, "position:x", 0.0, SKID_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(stage, "rotation", 0.0, SKID_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(landed)
	t.tween_interval(openAfter)
	t.tween_callback(Transition.sound.bind("rattle", -6.0))
	t.tween_property(door, "position:y", -door.size.y - 4, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

#the brake: a puff along the bottom edge and two rubber strips back to the screen edge
func landed() -> void:
	Transition.sound("pop", -8.0)
	Juice.rumble(stage, "position", 4.0, 0.12)
	var r = card.get_global_rect()
	for f in [0.1, 0.3, 0.5, 0.7, 0.9]: fx.burst(Vector2(r.position.x + r.size.x * f, r.end.y), 4, Vector2(140, -30), 160.0, 80.0, 0.9)
	for y in [r.position.y + 30, r.end.y - 14]: fx.mark(Vector2(r.end.x - 20, y), Vector2(screen().x + 10, y), 9.0, 0.5, 1.1)

#slams the hatch and peels the panel out; await it, then close the menu. `whileShut` runs (and is
#awaited) between the slam and the peel: the slot machine pours its prizes out of the chute then.
func leave(whileShut := Callable()) -> void:
	if Transition.instant() || not is_instance_valid(door): return
	if Settings.reduce_motion():
		var fade = stage.create_tween()
		fade.tween_property(stage, "modulate:a", 0.0, Transition.FADE_SECONDS)
		await fade.finished
		return
	var size = screen()
	var t = stage.create_tween()
	t.tween_property(door, "position:y", 0.0, SLAM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		Transition.sound("clank", -3.0)
		Transition.sound("thud", -6.0)
		Juice.rumble(stage, "position", 4.0, 0.12))
	t.tween_interval(0.12)
	await t.finished
	if whileShut.is_valid(): await whileShut.call()
	var peel = stage.create_tween()
	peel.tween_callback(peelSmoke)
	peel.tween_property(stage, "position:x", -size.x * 1.15, PEEL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	peel.parallel().tween_property(stage, "rotation", 0.05, PEEL_SECONDS)
	await peel.finished

func peelSmoke() -> void:
	Transition.sound("screech", -4.0)
	var r = card.get_global_rect()
	for i in 6: fx.burst(Vector2(r.end.x - 10, lerpf(r.position.y, r.end.y, (i + 0.5) / 6.0)), 3, Vector2(320, 0), 200.0, 130.0, 1.1, i * 0.02)
	fx.autoFree = true #fades out after the menu is gone
