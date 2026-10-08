class_name Juice

#Small feedback tweens shared by the menus (docs/UI.md, "Juice"): a row that says no, a gold flash
#for something bought, a pop for a number that changed. Each one is short, transform or modulate
#only, and safe to call again before the last one ends.

const DENY_SOUND := preload("res://sound/ui/answerIncorrect.wav")

static var denyPlayer: AudioStreamPlayer

#a quick side-to-side shake and a dull buzz: the action isn't available
static func shake(item: Control, distance := 7.0) -> void:
	var home: float = item.get_meta("juiceHome", item.position.x)
	item.set_meta("juiceHome", home)
	var old: Tween = item.get_meta("juiceShake") if item.has_meta("juiceShake") else null #a null default still errors
	if old && old.is_valid(): old.kill()
	var tween = item.create_tween()
	for offset in [distance, -distance, distance * 0.6, -distance * 0.4, 0.0]:
		tween.tween_property(item, "position:x", home + offset, 0.045)
	tween.finished.connect(func(): item.remove_meta("juiceHome"))
	item.set_meta("juiceShake", tween)
	if not is_instance_valid(denyPlayer):
		denyPlayer = AudioStreamPlayer.new()
		denyPlayer.bus = &"UI"
		denyPlayer.stream = DENY_SOUND
		denyPlayer.volume_db = -8.0
		denyPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child(denyPlayer)
	denyPlayer.play()

#a wash of `color` over the item that fades out (modulate can't brighten past white in 2D)
static func flash(item: Control, color := HudTheme.GOLD, seconds := 0.45, radius := 7) -> void:
	var wash = Panel.new()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.add_theme_stylebox_override("panel", MenuTheme.box(Color(color, 0.55), color, radius, 2))
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(wash)
	var tween = wash.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wash, "modulate:a", 0.0, seconds)
	tween.tween_callback(wash.queue_free)

#scales up from its centre and settles with a small overshoot
static func pop(item: Control, peak := 1.3, seconds := 0.3) -> void:
	item.pivot_offset = item.size / 2.0
	item.scale = Vector2(peak, peak)
	item.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(item, "scale", Vector2.ONE, seconds)

#a decaying shake of `property` (a Control's position, a CanvasLayer's offset) around where it is;
#off with Reduce Motion. The shared sizes: 8 px for a full slam, 4 for a half door or a brake, 2 for a landing.
static func rumble(target: Object, property: StringName, amplitude: float, seconds := 0.18) -> void:
	if Settings.reduce_motion() || not is_instance_valid(target): return
	var home: Vector2 = target.get_meta("juiceRumbleHome", target.get(property))
	target.set_meta("juiceRumbleHome", home)
	var node: Node = target if target is Node else null
	if node == null: return
	var tween = node.create_tween()
	var seed = randf() * 10.0
	tween.tween_method(func(k: float):
		var decay = pow(1.0 - k, 2.0) * amplitude
		var t = k * seconds * 1000.0
		target.set(property, home + Vector2(sin(t * 0.11 + seed), cos(t * 0.093 + seed * 0.7)) * decay), 0.0, 1.0, seconds)
	tween.tween_callback(func():
		target.set(property, home)
		target.remove_meta("juiceRumbleHome"))

#an overlay arriving: drops a little from above and settles with a clank (Goonopedia, Settings,
#the records ticket). Reduce Motion fades it in instead.
static func dropIn(item: CanvasItem, distance := 50.0, seconds := 0.22) -> void:
	item.modulate.a = 0.0
	var tween = item.create_tween().set_parallel()
	tween.tween_property(item, "modulate:a", 1.0, seconds * 0.6)
	if Settings.reduce_motion() || not item is Control: return
	var control = item as Control
	var home = control.position.y
	control.position.y = home - distance
	tween.tween_property(control, "position:y", home, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Transition.sound("clank", -12.0)

