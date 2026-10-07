class_name ShutterDoor extends Control

#The garage roller shutter (docs/UI.md, "Transitions"): corrugated ribs, grime, a stencilled label,
#optional loading lamps, and a bottom rail with a hazard stripe and handles. Everything is drawn in
#_draw and only redrawn when the label or lamps change, so moving the door costs nothing.
#The door's bottom edge is its rail: tween `position.y` (or `size.y` for a half door) to move it.

const STENCIL_FONT := preload("res://style/font/Tektur/Tektur-Black.ttf")
const RIB_BANDS := [[0, 2, Color("9a918a")], [2, 6, Color("716862")], [8, 6, Color("5e5650")], [14, 6, Color("4d4642")], [20, 5, Color("3a3431")], [25, 3, Color("181413")]]
const STENCIL := Color(0.941, 0.627, 0.188, 0.62)
const LAMP_COUNT := 12

static var ribTexture: ImageTexture
static var specks: PackedVector3Array #x, y in 0..1 and a size: grime, the same on every door

var label := "GOONCRUSHER":
	set(value):
		label = value
		queue_redraw()
var sub := "":
	set(value):
		sub = value
		queue_redraw()
var labelSize := 120
var labelAt := 0.44            #the label's height as a share of the door
var small := false             #a half door: a thinner rail and no handles
var lamps := -1.0:             #loading progress 0..1 on a row of lamps; below 0 hides them
	set(value):
		var lit = int(clampf(value, 0.0, 1.0) * LAMP_COUNT + 0.0001)
		var changed = (value < 0.0) != (lamps < 0.0) || lit != int(clampf(lamps, 0.0, 1.0) * LAMP_COUNT + 0.0001)
		lamps = value
		if changed: queue_redraw()

func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP #a closed door blocks clicks to the screen under it
	texture_repeat = TEXTURE_REPEAT_ENABLED
	clip_contents = false
	ensureArt()
	resized.connect(queue_redraw)

static func ensureArt() -> void:
	if ribTexture: return
	var image = Image.create(4, 28, false, Image.FORMAT_RGBA8)
	for band in RIB_BANDS: image.fill_rect(Rect2i(0, band[0], 4, band[1]), band[2])
	ribTexture = ImageTexture.create_from_image(image)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 900: specks.push_back(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 3.0)))

func railHeight() -> float:
	return 16.0 if small else 26.0

func _draw() -> void:
	var w = size.x
	var h = size.y
	draw_texture_rect(ribTexture, Rect2(0, 0, w, h), true)
	#grime: dark specks and rust streaks
	for i in specks.size():
		var s = specks[i]
		var p = Vector2(s.x * w, s.y * h)
		if i % 12 == 0: draw_rect(Rect2(p, Vector2(1.5 + s.z * 0.5, 20 + s.z * 25)), Color(0.45, 0.23, 0.08, 0.09))
		else: draw_rect(Rect2(p, Vector2(s.z, s.z)), Color(0.05, 0.035, 0.03, 0.18) if i % 3 else Color(0.5, 0.27, 0.11, 0.12))
	var centre = Vector2(w / 2.0, h * labelAt)
	if label != "": stencil(label, centre, labelSize)
	if sub != "":
		var subSize = maxi(14, labelSize / 6)
		drawCentred(sub, Vector2(centre.x, centre.y - labelSize * 0.62), subSize, Color(1, 0.95, 0.86, 0.55), HudTheme.BOLD)
	if lamps >= 0.0: drawLamps(Vector2(w / 2.0, h * labelAt + labelSize * 0.55))
	#the rail
	var rh = railHeight()
	draw_rect(Rect2(0, h - rh, w, rh), Color("231e1b"))
	hazard(Rect2(0, h - rh + 4, w, 7.0 if small else 11.0))
	draw_rect(Rect2(0, h - 3, w, 3), HudTheme.OUTLINE)
	if not small:
		for f in [0.3, 0.7]:
			draw_rect(Rect2(w * f - 32, h - rh - 10, 64, 7), Color("8a827a"))
			draw_rect(Rect2(w * f - 32, h - rh - 3, 64, 2), Color("2a2522"))
	draw_rect(Rect2(0, h, w, 10), Color(0, 0, 0, 0.4)) #its shadow on whatever is below

#spray-painted text: the letters, then flecks of overspray around them
func stencil(text: String, centre: Vector2, fontSize: int) -> void:
	drawStencil(self, text, centre, fontSize, STENCIL)

func drawCentred(text: String, centre: Vector2, fontSize: int, color: Color, font: Font) -> void:
	var textSize = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize)
	draw_string(font, centre + Vector2(-textSize.x / 2.0, fontSize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)

#shared with Stamp and TapeBanner: stencilled letters (optionally outlined) with overspray flecks
static func drawStencil(item: CanvasItem, text: String, centre: Vector2, fontSize: int, color: Color, outline := 0, outlineColor := HudTheme.OUTLINE) -> void:
	var span = STENCIL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize).x
	var at = centre + Vector2(-span / 2.0, fontSize * 0.36)
	if outline > 0: item.draw_string_outline(STENCIL_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, outline, outlineColor)
	item.draw_string(STENCIL_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fontSize, color)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(text)
	for i in int(60 + fontSize): item.draw_rect(Rect2(centre + Vector2(rng.randf_range(-0.5, 0.5) * span, rng.randf_range(-0.6, 0.6) * fontSize), Vector2(2, 2)), Color(color, color.a * rng.randf_range(0.4, 1.0)))

func drawLamps(centre: Vector2) -> void:
	var lampW = 46.0
	var gap = 11.0
	var total = LAMP_COUNT * lampW + (LAMP_COUNT - 1) * gap
	var lit = int(clampf(lamps, 0.0, 1.0) * LAMP_COUNT + 0.0001)
	for i in LAMP_COUNT:
		var x = centre.x - total / 2.0 + i * (lampW + gap)
		draw_rect(Rect2(x - 3, centre.y - 3, lampW + 6, 24), HudTheme.OUTLINE)
		draw_rect(Rect2(x, centre.y, lampW, 18), HudTheme.GOLD if i < lit else HudTheme.TRACK)
		if i < lit: draw_rect(Rect2(x + 4, centre.y + 3, lampW - 8, 4), Color(1, 0.95, 0.86, 0.5))

#black and orange diagonal stripes
func hazard(rect: Rect2) -> void:
	drawHazard(self, rect)

static func drawHazard(item: CanvasItem, rect: Rect2) -> void:
	item.draw_rect(rect, HudTheme.OUTLINE)
	var step = 34.0
	var x = rect.position.x - rect.size.y
	var bounds = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	while x < rect.end.x:
		var stripe = PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 13, rect.end.y), Vector2(x + 13 + rect.size.y, rect.position.y), Vector2(x + rect.size.y, rect.position.y)])
		for piece in Geometry2D.intersect_polygons(stripe, bounds):
			if piece.size() >= 3: item.draw_colored_polygon(piece, HudTheme.RIM)
		x += step
