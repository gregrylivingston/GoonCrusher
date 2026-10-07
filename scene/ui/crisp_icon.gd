class_name CrispIcon extends TextureRect
## A menu icon drawn 1:1 on screen. Icons are imported large (96 px) with mipmaps, which keeps them sharp on
## big screens but blurs them when a menu shows them small: the GPU blends two shrunken mips. This resamples
## the icon once (Lanczos) to the exact screen pixels it covers and draws that instead. It rebuilds when the
## window or its own size changes; results are shared through `cache`. Upscales are left to the source texture.

static var cache := {} #"<source id>|<w>x<h>" -> ImageTexture

var source: Texture2D
var built := Vector2i.ZERO

func _init(icon: Texture2D = null, side := 0.0) -> void:
	source = icon
	texture = icon
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	get_viewport().size_changed.connect(rebuild)
	rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED && is_inside_tree(): rebuild()

func rebuild() -> void:
	if source == null || not is_inside_tree(): return
	var box := size if size.x > 0.0 && size.y > 0.0 else custom_minimum_size
	var full := Vector2(source.get_size())
	if box.x <= 0.0 || box.y <= 0.0 || full.x <= 0.0 || full.y <= 0.0: return
	#window stretch only, not this control's own scale, so pop-in animations don't trigger rebuilds
	var pixels := get_viewport().get_screen_transform().get_scale().x * get_viewport().get_canvas_transform().get_scale().x
	var target := Vector2i((full * minf(box.x / full.x, box.y / full.y) * pixels).round())
	if target == built: return
	built = target
	if target.x < 1 || target.y < 1 || target.x >= full.x || target.y >= full.y:
		texture = source
		return
	var key := "%d|%dx%d" % [source.get_instance_id(), target.x, target.y]
	if not cache.has(key):
		var image := source.get_image()
		if image == null:
			texture = source
			return
		if image.is_compressed(): image.decompress()
		image.clear_mipmaps()
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		cache[key] = ImageTexture.create_from_image(image)
	texture = cache[key]
