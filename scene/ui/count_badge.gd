class_name CountBadge extends PanelContainer

#A gold count on a button's corner: how many things behind the button can be bought right now (the garage
#dock's Upgrades and Pickups, docs/UI.md). Hidden at 0. It hops every couple of seconds and pops when the
#number changes; with Reduce Motion it sits still. Tween-driven, so frame caps don't change it.

const HOP_EVERY := 2.2
const REST := Vector2(6, -16) #how far its right and top edges sit outside the button's corner: inside the gap
#to the next button, which would draw over it (a z_index would lift it over overlays such as the Goonopedia)
const HEIGHT := 32.0

var count := 0
var phase := 0.0 #seconds before its first hop, so two badges side by side don't land together
var label := Label.new()
var tween: Tween

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	var style := MenuTheme.box(HudTheme.GOLD, HudTheme.DEEP, 16, 3, Vector4(9, 0, 9, 0))
	style.shadow_color = Color(HudTheme.GOLD, 0.45)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", HudTheme.DEEP)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	resized.connect(func(): pivot_offset = Vector2(size.x / 2.0, size.y))

## A badge on `button`'s top right corner
static func on(button: Control, delay := 0.0) -> CountBadge:
	var badge := CountBadge.new()
	badge.phase = delay
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = REST.x - HEIGHT
	badge.offset_right = REST.x
	badge.offset_top = REST.y
	badge.offset_bottom = REST.y + HEIGHT
	badge.grow_horizontal = GROW_DIRECTION_BEGIN #a wider number grows leftward, over the button
	button.add_child(badge)
	return badge

func setCount(value: int) -> void:
	var changed := value != count
	count = value
	label.text = str(value)
	visible = value > 0
	if value <= 0 || Settings.reduce_motion() || not is_inside_tree(): still()
	elif changed: pop()
	elif tween == null || not tween.is_valid(): hop(phase)

func _enter_tree() -> void:
	if count > 0 && not Settings.reduce_motion(): hop(phase)

func _exit_tree() -> void:
	still()

func still() -> void:
	if tween: tween.kill()
	tween = null
	scale = Vector2.ONE
	position.y = REST.y

#the number changed: it swells and settles, then goes back to hopping
func pop() -> void:
	still()
	scale = Vector2(1.7, 1.7)
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(hop.bind(0.0))

#squash, hop, land and settle, again and again
func hop(delay: float) -> void:
	still()
	if delay > 0.0:
		tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(hop.bind(0.0))
		return
	tween = create_tween().set_loops()
	tween.tween_interval(HOP_EVERY - 0.5)
	tween.tween_property(self, "scale", Vector2(1.18, 0.8), 0.08)
	tween.tween_property(self, "position:y", REST.y - 12.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.92, 1.14), 0.14)
	tween.tween_property(self, "position:y", REST.y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.12, 0.9), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
