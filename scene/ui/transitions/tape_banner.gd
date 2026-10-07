class_name TapeBanner extends Control

#A hazard-tape strip that slides across the run with stencil text (docs/UI.md, "Transitions"): in from
#the left over 300 ms with an overshoot, a hold, out to the right over 250 ms. Banners queue so two
#never overlap; toasts stay separate. Used for the crush goal, Marathon legs, new goons and nightfall.
#  TapeBanner.post("NIGHT FALLS")

const BAND_Y := 210.0
const BAND_HEIGHT := 58.0
const IN_SECONDS := 0.3
const OUT_SECONDS := 0.25
const LAYER := 25 #over the HUD and the in-run menus

static var queue: Array = []
static var showing: TapeBanner

var text := ""
var hold := 1.4

static func post(label: String, holdSeconds := 1.4) -> void:
	queue.push_back([label, holdSeconds])
	if not is_instance_valid(showing): next()

static func next() -> void:
	showing = null
	if queue.is_empty(): return
	var host = layer()
	if host == null:
		queue.clear()
		return
	var entry = queue.pop_front()
	var b = TapeBanner.new()
	b.text = entry[0]
	b.hold = entry[1]
	showing = b
	host.add_child(b)
	b.run()

#one CanvasLayer per run, under the level, so banners show over the HUD and menus and go with the run
static func layer() -> CanvasLayer:
	if not is_instance_valid(Root.levelRoot) || not Root.levelRoot.is_inside_tree(): return null
	var existing = Root.levelRoot.get_node_or_null("Banners")
	if existing: return existing
	var host = CanvasLayer.new()
	host.name = "Banners"
	host.layer = LAYER
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	Root.levelRoot.add_child(host)
	return host

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	if showing == self: showing = null

func run() -> void:
	var screen = get_viewport().get_visible_rect().size
	size = Vector2(screen.x + 80, BAND_HEIGHT + 12)
	position = Vector2(-40, BAND_Y)
	pivot_offset = size / 2.0
	rotation = -0.012
	var t = create_tween()
	if Settings.reduce_motion():
		modulate.a = 0.0
		t.tween_property(self, "modulate:a", 1.0, Transition.FADE_SECONDS)
		t.tween_interval(hold)
		t.tween_property(self, "modulate:a", 0.0, Transition.FADE_SECONDS)
	else:
		position.x = -screen.x * 1.1
		Transition.sound("rattle", -8.0)
		t.tween_property(self, "position:x", -40.0, IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(Transition.sound.bind("clank", -6.0))
		t.tween_interval(hold)
		t.tween_property(self, "position:x", screen.x * 1.1, OUT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		queue_free()
		TapeBanner.next())

func _draw() -> void:
	draw_rect(Rect2(0, BAND_HEIGHT, size.x, 8), Color(0, 0, 0, 0.4))
	ShutterDoor.drawHazard(self, Rect2(0, 0, size.x, BAND_HEIGHT))
	var fontSize = 30
	var span = ShutterDoor.STENCIL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x
	var plate = Rect2(size.x / 2.0 - span / 2.0 - 22, 7, span + 44, BAND_HEIGHT - 14)
	draw_rect(plate, HudTheme.OUTLINE)
	ShutterDoor.drawStencil(self, text, plate.get_center(), fontSize, HudTheme.RIM)
