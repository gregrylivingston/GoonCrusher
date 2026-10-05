extends SceneTree

#Bakes headlamp1-5 of scene/car/car.tscn into one texture for the Simple Headlight Cone.
#Run: Godot_console.exe --headless --path . -s res://scripts/debug/bake_headlight_cone.gd
#The five lamps are additive, so the cone texture is the sum of each lamp's texture times its
#energy, normalised to 0-1; the cone light's energy restores the peak. Prints the light values
#to put on the simpleCone node.

const SIZE = Vector2i(512, 384)
const OUT = "res://texture/fx/headlight_cone.png"

func _initialize():
	var car = load("res://scene/car/car.tscn").instantiate()
	var lamps = car.get_node("headlamps/headlights").get_children().filter(func(n): return n is PointLight2D)
	#bounds of every lamp's texture rectangle in `headlights` space
	var bounds: Rect2
	var first = true
	for lamp in lamps:
		for corner in lampCorners(lamp):
			if first:
				bounds = Rect2(corner, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(corner)
	#cone light sits at the front lamps; its texture covers `bounds`
	var origin = Vector2(120, 0)
	var scale = maxf(bounds.size.x / SIZE.x, bounds.size.y / SIZE.y)
	var images = {}
	var sums = PackedFloat32Array()
	sums.resize(SIZE.x * SIZE.y)
	var peak = 0.0
	for y in SIZE.y:
		for x in SIZE.x:
			var world = bounds.get_center() + (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(SIZE) / 2.0) * scale
			var total = 0.0
			for lamp in lamps:
				if not images.has(lamp.texture): images[lamp.texture] = lamp.texture.get_image()
				total += lamp.energy * sampleLamp(lamp, images[lamp.texture], world)
			sums[y * SIZE.x + x] = total
			peak = maxf(peak, total)
	var image = Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y in SIZE.y:
		for x in SIZE.x:
			var v = sums[y * SIZE.x + x] / peak
			image.set_pixel(x, y, Color(v, v, v, 1.0)) #value in rgb, opaque: right whether or not lights use alpha
	image.save_png(ProjectSettings.globalize_path(OUT))
	print("cone texture: ", OUT)
	print("position = ", origin)
	print("offset = ", bounds.get_center() - origin) #light offsets are not multiplied by texture_scale
	print("texture_scale = ", scale)
	print("energy = ", peak)
	print("color = ", lamps[0].color)
	car.free()
	quit()

#texture rectangle corners of a lamp, in its parent's space
func lampCorners(lamp: PointLight2D) -> Array:
	var size = Vector2(lamp.texture.get_size()) * lamp.texture_scale
	var rect = Rect2(lamp.offset * lamp.texture_scale - size / 2.0, size)
	var xf = lamp.transform
	return [xf * rect.position, xf * Vector2(rect.end.x, rect.position.y), xf * rect.end, xf * Vector2(rect.position.x, rect.end.y)]

#bilinear sample of the lamp's texture (red channel x alpha) at a point in the parent's space
func sampleLamp(lamp: PointLight2D, image: Image, point: Vector2) -> float:
	var local = lamp.transform.affine_inverse() * point
	var size = Vector2(image.get_size())
	var uv = (local / lamp.texture_scale - lamp.offset) + size / 2.0 - Vector2(0.5, 0.5)
	if uv.x < -0.5 || uv.y < -0.5 || uv.x > size.x - 0.5 || uv.y > size.y - 0.5: return 0.0
	var x0 = clampi(floori(uv.x), 0, int(size.x) - 1)
	var y0 = clampi(floori(uv.y), 0, int(size.y) - 1)
	var x1 = mini(x0 + 1, int(size.x) - 1)
	var y1 = mini(y0 + 1, int(size.y) - 1)
	var fx = clampf(uv.x - x0, 0.0, 1.0)
	var fy = clampf(uv.y - y0, 0.0, 1.0)
	var a = lerpf(texel(image, x0, y0), texel(image, x1, y0), fx)
	var b = lerpf(texel(image, x0, y1), texel(image, x1, y1), fx)
	return lerpf(a, b, fy)

func texel(image: Image, x: int, y: int) -> float:
	var c = image.get_pixel(x, y)
	return c.r * c.a
