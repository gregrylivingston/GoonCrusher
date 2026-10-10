class_name Stamp extends Control

#Stencil text slammed onto the screen (docs/UI.md, "Transitions"): it drops from 140% to 100% in 110 ms,
#lands with a clank and a small rumble, holds, then fades. Used for crush and milestone moments
#("TARGET SMASHED"), the legendary toast and the results. Reduce Motion fades it in at full size.
#  Stamp.slam(parent, "GOAL!", center, HudTheme.GOLD, 64)

const SLAM_SECONDS := 0.11
const FADE_SECONDS := 0.2

var text := ""
var color := HudTheme.GOLD
var fontSize := 64

#`hold` below 0 keeps it until freed
static func slam(parent: Node, label: String, center: Vector2, tint := HudTheme.GOLD, size := 64, hold := 1.2, angle := -0.06) -> Stamp:
	var s = Stamp.new()
	s.text = label
	s.color = tint
	s.fontSize = size
	s.mouse_filter = MOUSE_FILTER_IGNORE
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	var span = ShutterDoor.STENCIL_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	s.size = Vector2(span + size, size * 1.6)
	s.position = center - s.size / 2.0
	s.pivot_offset = s.size / 2.0
	s.rotation = angle
	parent.add_child(s)
	s.play(hold)
	return s

func play(hold: float) -> void:
	var t = create_tween()
	if Settings.reduce_motion():
		modulate.a = 0.0
		t.tween_property(self, "modulate:a", 1.0, Transition.FADE_SECONDS)
	else:
		scale = Vector2(1.4, 1.4)
		modulate.a = 0.0
		t.tween_property(self, "scale", Vector2.ONE, SLAM_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "modulate:a", 1.0, SLAM_SECONDS * 0.6)
		t.tween_callback(func():
			Transition.sound("clank", -6.0)
			Juice.rumble(self, "position", 3.0, 0.12))
	if hold < 0.0: return
	t.tween_interval(hold)
	t.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	t.tween_callback(queue_free)

func _draw() -> void:
	ShutterDoor.drawStencil(self, text, size / 2.0, fontSize, color, maxi(4, fontSize / 9), Color(HudTheme.OUTLINE, 0.9))
