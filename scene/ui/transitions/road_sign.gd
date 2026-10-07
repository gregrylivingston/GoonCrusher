class_name RoadSign extends Control

#A highway sign that swings in at the left edge when the car crosses into a new district (docs/UI.md,
#"Transitions"): the district's name and the faction that holds it. It swings in on its bracket over
#300 ms with a creak and settles with a clank, holds, then swings back out. Reduce Motion fades it.
#Lives on the run's banner layer (TapeBanner.layer).
#  RoadSign.post("Antler Bottoms", "Scrap Gang turf")

const SIGN := Color("1f6b3a")
const INK := Color("eff5ea")
const AT := Vector2(14, 172) #under the region chip
const SIGN_SIZE := Vector2(360, 108)
const HOLD := 2.2

static var showing: RoadSign

var title := ""
var line := ""

static func post(name: String, detail: String) -> void:
	if is_instance_valid(showing): showing.queue_free()
	var host = TapeBanner.layer()
	if host == null || name == "": return
	var s = RoadSign.new()
	s.title = name.to_upper()
	s.line = detail
	showing = s
	host.add_child(s)
	s.run()

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SIGN_SIZE
	position = AT
	pivot_offset = Vector2(0, SIGN_SIZE.y * 0.45) #the bracket on its left edge

func run() -> void:
	var t = create_tween()
	if Settings.reduce_motion():
		modulate.a = 0.0
		t.tween_property(self, "modulate:a", 1.0, Transition.FADE_SECONDS)
		t.tween_interval(HOLD)
		t.tween_property(self, "modulate:a", 0.0, Transition.FADE_SECONDS)
	else:
		rotation = -1.75
		Transition.sound("rattle", -14.0, 0.7)
		t.tween_property(self, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(Transition.sound.bind("clank", -8.0, 0.8))
		t.tween_method(func(k: float): rotation = 0.1 * exp(-k * 4.0) * sin(k * 18.0), 0.0, 1.0, 0.8) #it settles on the bracket
		t.tween_interval(HOLD - 0.8)
		t.tween_property(self, "rotation", -1.75, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(8, 10, size.x, size.y), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(-12, size.y * 0.4, 14, 12), Color("6b625b")) #the bracket
	draw_rect(r, SIGN)
	draw_rect(r.grow(-7), INK, false, 3.0)
	draw_rect(Rect2(18, 16, 104, 22), INK)
	HudTheme.text(self, Vector2(70, 33), "DISTRICT", 13, SIGN, HORIZONTAL_ALIGNMENT_CENTER, 0)
	HudTheme.text(self, Vector2(20, 72), title, 28, INK, HORIZONTAL_ALIGNMENT_LEFT, 0)
	HudTheme.text(self, Vector2(20, 95), line, 16, Color(INK, 0.8), HORIZONTAL_ALIGNMENT_LEFT, 0, HudTheme.OUTLINE, HudTheme.BODY)
