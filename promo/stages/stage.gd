extends Node

#The capture kit's stage (docs/PROMO.md, "Stages"): one thing on a plain backdrop, filmed with
#transparency so an editor can lay it over anything. The session (promo/capture/session.gd) makes one for a
#job whose kind is "stage"; job.stage picks what stands on it:
#  title       job.text in the game's extruded 3D lettering; "sub": a smaller line under it; "font_size" (170);
#              "spin": true lets the letters turn over now and then, as the menu's logo does
#  lineup      job.what: "cars", "goons" (walking), "pickups", "posters" (the 30 levels); "names": true labels
#              them; "only": [ids];
#              "columns": how many across (worked out from the frame's shape when left out)
#  transition  one of the game's own screen moves, by "which":
#                shutter (default)  the garage door down and up: "label", "sub" (its sign), "hold" seconds shut
#                stamp              stencil text slammed on: "label", "font_size" (96), "hold"
#                banner             the hazard-tape strip sliding across: "label", "hold"
#                sign               the highway sign swinging in: "label" (the place), "sub" (who holds it)
#  keyart      store art: job.plate (a still's path) filling the frame under the GOONCRUSHER logo;
#              "tagline", "logo_at" (0 top to 1 bottom, default 0.3), "dim" (0 to 1: how much the plate darkens)
#  safezone    a guide to lay over a tall or square edit: the area the platform's own buttons and captions
#              leave clear ("platform": shorts, reels, tiktok or all). A still; never part of a delivery.
#  endcard     the logo over "call" (default WISHLIST ON STEAM) with the Steam mark; "sub": a smaller line
#job.backdrop: "clear" (transparent), "magenta" (a key color nothing in the game uses), "gray", "black".

const TEXT_SHADER := preload("res://shader/3dtext.gdshader")
const TITLE_FONT := preload("res://style/font/Tektur/Tektur-Black.ttf")
const BACKDROPS := {"magenta": Color(1, 0, 1), "gray": Color(0.467, 0.467, 0.467), "black": Color.BLACK}
const CARS := ["sedan", "taxi", "pickup", "police", "ambulance", "van", "racer", "supercar", "semi"]

var job := {}
var ui := CanvasLayer.new()
var screen := Vector2(1600, 900)

func _ready() -> void:
	screen = get_viewport().get_visible_rect().size
	backdrop(self, str(job.get("backdrop", "clear")))
	add_child(ui)
	match str(job.get("stage", "")):
		"title": title()
		"lineup": lineup()
		"transition": transition()
		"keyart": keyart()
		"safezone": safezone()
		"endcard": endcard()
		_: push_error("CAPTURE unknown stage " + str(job.get("stage")))

func title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	ui.add_child(box)
	var main := lettering(str(job.get("text", "GOONCRUSHER")), int(job.get("font_size", 170)), bool(job.get("spin", false)))
	box.add_child(main)
	if job.has("sub"):
		var sub := lettering(str(job.sub), int(int(job.get("font_size", 170)) * 0.4))
		box.add_child(sub)
	if job.get("animate", true):
		#the title lands: a quick overshoot from small, as the game's own stamps do
		box.pivot_offset = screen / 2.0
		box.scale = Vector2(0.6, 0.6)
		box.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(box, "modulate:a", 1.0, 0.12)

func lineup() -> void:
	var what := str(job.get("what", "cars"))
	var only: Array = job.get("only", [])
	var items: Array = [] #[name, Node]
	match what:
		"cars":
			for id in CARS:
				if not only.is_empty() && not id in only: continue
				var info: CarInfo = load("res://scene/car/%s/%s_info.tres" % [id, id])
				var picture := TextureRect.new()
				picture.texture = info.get(str(job.get("picture", "sidePic"))) if info.get(str(job.get("picture", "sidePic"))) else info.profilePic
				items.push_back([info.charName if info.charName != "Hi" else id.capitalize(), picture])
		"goons":
			for id in Goons.DATA:
				if not only.is_empty() && not String(id) in only: continue
				var walker := walking(id)
				if walker: items.push_back([str(Goons.DATA[id].get("name", String(id).capitalize())), walker])
		"pickups":
			for id in Pickups.ids():
				if not only.is_empty() && not id in only: continue
				var picture := TextureRect.new()
				picture.texture = Pickups.texture(id)
				items.push_back([Pickups.displayName(id), picture])
		"posters":
			for id in Levels.ORDER:
				if not only.is_empty() && not String(id) in only: continue
				var def: LevelDef = load(Levels.DEF_DIR + String(id) + ".tres")
				if def == null || def.poster == "" || not ResourceLoader.exists(def.poster): continue
				var picture := TextureRect.new()
				picture.texture = load(def.poster)
				items.push_back([def.displayName if def.displayName != "" else String(id).capitalize(), picture])
		_:
			push_error("CAPTURE lineup of what? cars, goons, pickups or posters")
			return
	if items.is_empty(): return
	var margin := screen * 0.06
	var area := screen - margin * 2.0
	var columns := int(job.get("columns", ceili(sqrt(items.size() * area.x / area.y))))
	var rows := ceili(float(items.size()) / columns)
	var cell := Vector2(area.x / columns, area.y / rows)
	var names: bool = job.get("names", false)
	for i in items.size():
		var slot := Control.new()
		slot.position = margin + Vector2(i % columns, i / columns) * cell
		slot.size = cell
		ui.add_child(slot)
		var room := cell - Vector2(16, 44 if names else 16)
		var node: Node = items[i][1]
		if node is TextureRect:
			node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node.position = Vector2(8, 8)
			node.size = room
		else: #a walking goon: scaled to the cell, standing on its center
			var frame: Vector2 = node.get_meta(&"frameSize", Vector2(128, 128))
			var fit := minf(room.x / frame.x, room.y / frame.y) * 0.9
			node.scale = Vector2(fit, fit)
			node.position = Vector2(8, 8) + room / 2.0
		slot.add_child(node)
		if names:
			var caption := Label.new()
			caption.text = items[i][0]
			caption.add_theme_font_override("font", HudTheme.BODY)
			caption.add_theme_font_size_override("font_size", clampi(int(cell.x / 9.0), 12, 26))
			caption.add_theme_color_override("font_outline_color", Color.BLACK)
			caption.add_theme_constant_override("outline_size", 6)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.position = Vector2(0, cell.y - 36)
			caption.size = Vector2(cell.x, 30)
			slot.add_child(caption)

func transition() -> void:
	Transition.forceShown = true
	#banners and signs hang on the run's banner layer (TapeBanner.layer): a bare node stands in for the level
	var stand := Node2D.new()
	add_child(stand)
	Root.levelRoot = stand
	await get_tree().create_timer(0.3).timeout
	var hold := float(job.get("hold", 0.6))
	var text := str(job.get("label", "GOONCRUSHER"))
	match str(job.get("which", "shutter")):
		"stamp": Stamp.slam(ui, text, screen / 2.0, HudTheme.GOLD, int(job.get("font_size", 96)), maxf(hold, 1.2))
		"banner": TapeBanner.post(text, maxf(hold, 1.4))
		"sign": RoadSign.post(text, str(job.get("sub", "")))
		_: Transition.play(func(): await get_tree().create_timer(hold).timeout, text, str(job.get("sub", "")))

func keyart() -> void:
	var platePath := str(job.get("plate", ""))
	if platePath.begins_with("SET-ME"): push_error("CAPTURE store art needs a plate: set \"plate\" in promo/shots/store_art.json to a still's path")
	elif platePath != "":
		var image := Image.load_from_file(platePath)
		if image:
			var plate := TextureRect.new()
			plate.texture = ImageTexture.create_from_image(image)
			plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			plate.set_anchors_preset(Control.PRESET_FULL_RECT)
			ui.add_child(plate)
		else: push_error("CAPTURE can't read the plate " + platePath)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, float(job.get("dim", 0.35)))
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	#the logo fills most of the width whatever the capsule's shape
	var text := str(job.get("text", "GOONCRUSHER"))
	var fontSize := int(clampf(screen.x * 0.82 / (maxi(text.length(), 1) * 0.74), 40.0, 420.0))
	var logo := lettering(text, fontSize)
	logo.position = Vector2(0, screen.y * float(job.get("logo_at", 0.3)) - fontSize * 0.7)
	logo.size = Vector2(screen.x, fontSize * 1.4)
	ui.add_child(logo)
	if job.has("tagline"):
		var line := lettering(str(job.tagline), int(fontSize * 0.3))
		line.position = Vector2(0, logo.position.y + fontSize * 1.35)
		line.size = Vector2(screen.x, fontSize * 0.5)
		ui.add_child(line)

#Rough clear areas on a 9:16 video, as shares of the frame [left, top, right, bottom]. Platforms move their
#buttons about: check a real upload before trusting these to the pixel.
const SAFE := {"shorts": [0.05, 0.12, 0.82, 0.76], "reels": [0.05, 0.14, 0.84, 0.72], "tiktok": [0.05, 0.12, 0.83, 0.74]}
const SAFE_COLORS := {"shorts": Color(1, 0.25, 0.25), "reels": Color(0.9, 0.3, 0.9), "tiktok": Color(0.2, 0.9, 0.9)}

func safezone() -> void:
	var wanted := str(job.get("platform", "all"))
	var guide := Guide.new()
	guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide.font = HudTheme.BODY
	for platform in SAFE:
		if wanted != "all" && wanted != platform: continue
		var box: Array = SAFE[platform]
		guide.boxes.push_back([platform, Rect2(screen.x * box[0], screen.y * box[1], screen.x * (box[2] - box[0]), screen.y * (box[3] - box[1])), SAFE_COLORS[platform]])
	ui.add_child(guide)

class Guide extends Control:
	var boxes: Array = [] #[name, Rect2, Color]
	var font: Font
	func _draw() -> void:
		for i in boxes.size():
			draw_rect(boxes[i][1], boxes[i][2], false, 3.0)
			draw_string_outline(font, boxes[i][1].position + Vector2(10, 28 + i * 26), boxes[i][0] + " clear area", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color.BLACK)
			draw_string(font, boxes[i][1].position + Vector2(10, 28 + i * 26), boxes[i][0] + " clear area", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, boxes[i][2])
		draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), Color(1, 1, 1, 0.35), 1.0)
		draw_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), Color(1, 1, 1, 0.35), 1.0)

func endcard() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(screen.y * 0.04))
	ui.add_child(box)
	var fontSize := int(clampf(screen.x * 0.8 / (11 * 0.74), 40.0, 230.0))
	box.add_child(lettering(str(job.get("text", "GOONCRUSHER")), fontSize))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(fontSize * 0.2))
	box.add_child(row)
	var steam := "res://texture/icon/steam.png" #the official mark (CLAUDE.md, "Icons")
	if job.get("steam", true) && ResourceLoader.exists(steam):
		var mark := TextureRect.new()
		mark.texture = load(steam)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(fontSize * 0.55, fontSize * 0.55)
		row.add_child(mark)
	var call := Label.new()
	call.text = str(job.get("call", "WISHLIST ON STEAM"))
	call.add_theme_font_override("font", TITLE_FONT)
	call.add_theme_font_size_override("font_size", int(fontSize * 0.36))
	call.add_theme_color_override("font_color", Color.WHITE)
	call.add_theme_color_override("font_outline_color", Color.BLACK)
	call.add_theme_constant_override("outline_size", 8)
	row.add_child(call)
	if job.has("sub"):
		var sub := Label.new()
		sub.text = str(job.sub)
		sub.add_theme_font_override("font", HudTheme.BODY)
		sub.add_theme_font_size_override("font_size", int(fontSize * 0.2))
		sub.add_theme_color_override("font_outline_color", Color.BLACK)
		sub.add_theme_constant_override("outline_size", 6)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.4)

#"clear" makes the picture transparent wherever nothing is drawn
static func backdrop(host: Node, kind: String) -> void:
	host.get_tree().root.transparent_bg = kind == "clear"
	if not BACKDROPS.has(kind): return
	var back := CanvasLayer.new()
	back.layer = -100
	var fill := ColorRect.new()
	fill.color = BACKDROPS[kind]
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(fill)
	host.add_child(back)

#the menu logo's lettering (main2.gd, buildLogo) at any size; it holds still unless `spin`
static func lettering(text: String, fontSize: int, spin := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", fontSize)
	label.add_theme_color_override("font_color", HudTheme.RIM)
	label.add_theme_color_override("font_outline_color", Color(0.353, 0.071, 0.047))
	label.add_theme_constant_override("outline_size", maxi(int(fontSize * 0.18), 4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.478, 0.122, 0.039), Color(0.306, 0.067, 0.043)])
	var side := GradientTexture1D.new()
	side.gradient = gradient
	var material := ShaderMaterial.new()
	material.shader = TEXT_SHADER
	material.set_shader_parameter("time_mode", 1 if spin else 3) #1: the letters turn over now and then, as the menu's logo does
	material.set_shader_parameter("angle", 6.8)
	material.set_shader_parameter("thickness", fontSize * 0.09)
	material.set_shader_parameter("shear", Vector2(0, -0.35))
	material.set_shader_parameter("slices", 64)
	material.set_shader_parameter("outline", true)
	material.set_shader_parameter("outline_width", 2.0)
	material.set_shader_parameter("side_tex", side)
	label.material = material
	return label

#a goon's own sprite, walking on the spot: its frames are read from its scene, which is never added to the
#tree (a Walker outside a level has no world to live in)
static func walking(id: StringName) -> AnimatedSprite2D:
	var path := Goons.scenePath(id)
	if not ResourceLoader.exists(path): return null
	var goon: Node = load(path).instantiate()
	var found: Array = goon.find_children("*", "AnimatedSprite2D", true, false)
	var sprite: AnimatedSprite2D = null
	if not found.is_empty() && found[0].sprite_frames:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = found[0].sprite_frames
		var animations := sprite.sprite_frames.get_animation_names()
		var animation: StringName = &"walk" if animations.has("walk") else (animations[0] if not animations.is_empty() else &"default")
		sprite.play(animation)
		var first := sprite.sprite_frames.get_frame_texture(animation, 0)
		if first: sprite.set_meta(&"frameSize", first.get_size())
	goon.free()
	return sprite
