class_name CardArt extends RefCounted

#Card backs painted from the game's own art (The Deal; docs/PICKUPS.md, "Prize games"): a patch of world
#ground with props, cars and goons laid out on it, a little scene for each kind of pickup, so the back says
#what kind of card it is without saying how rare. The kind's colour frames it and its name and emblem sit on
#a banner. Everything is drawn through `base` (the caller's canvas transform, e.g. a card mid-flip).
#Layers are [art, centre (fraction of the card), width (fraction of the card's width), rotation]; art names
#are a prop (world/art/props), "car", a goon id ("goon:grunt"), an icon ("icon:coin") or "trail" (a
#nitro streak). `seed` picks the car and goons and nudges the layout, so a card always looks the same.

const GROUND := "res://world/art/ground/%s.png"
const PROP := "res://world/art/props/%s.png"
const STATION := "res://world/art/station/%s.png"
const CAR := "res://scene/car/%s/art/%s_c0.png"
const GOON := "res://scene/enemy/goons/%s/art/%s_idle0.png"
const ICON := "res://texture/icon/%s.svg"
const CARS := ["sedan", "taxi", "racer", "van", "police", "pickup", "supercar"]
const GOONS := ["grunt", "goonling", "rat", "gremlin", "yipper", "bandit", "skink", "spiker"]

## per kind (Pickups.K): ground, layers, emblem icon
const SCENES := {
	Pickups.K.SUPPLY: ["lot", [["station:station_pump", Vector2(0.27, 0.27), 0.34, 0.0], ["barrel", Vector2(0.78, 0.2), 0.2, 0.3], ["barrel", Vector2(0.86, 0.36), 0.17, 0.0], ["car", Vector2(0.58, 0.58), 0.34, 0.2]], "toolbox"],
	Pickups.K.TUNE: ["asphalt", [["container", Vector2(0.3, 0.24), 0.55, 0.0], ["tyres", Vector2(0.82, 0.2), 0.24, 0.0], ["car", Vector2(0.45, 0.62), 0.34, -0.15], ["icon:upgrade", Vector2(0.78, 0.5), 0.24, 0.0]], "upgrade"],
	Pickups.K.BOOST: ["asphalt", [["trail", Vector2(0.5, 0.78), 0.3, 0.0], ["car", Vector2(0.5, 0.42), 0.36, 0.0], ["cone", Vector2(0.15, 0.25), 0.14, 0.0], ["cone", Vector2(0.85, 0.6), 0.14, 0.0]], "nitro"],
	Pickups.K.GADGET: ["dirt", [["goon", Vector2(0.24, 0.24), 0.36, -0.4], ["goon", Vector2(0.78, 0.3), 0.36, 0.5], ["goon", Vector2(0.66, 0.68), 0.36, 2.2], ["icon:mine", Vector2(0.4, 0.55), 0.26, 0.0]], "mine"],
	Pickups.K.LOOT: ["grass", [["crate", Vector2(0.3, 0.3), 0.32, 0.2], ["icon:coin", Vector2(0.62, 0.22), 0.14, 0.0], ["icon:coin", Vector2(0.75, 0.4), 0.14, 0.0], ["icon:coinstack", Vector2(0.28, 0.66), 0.2, 0.0], ["icon:purse", Vector2(0.64, 0.6), 0.3, 0.0]], "coin"],
	Pickups.K.CASINO: ["lot", [["billboard", Vector2(0.5, 0.3), 0.6, 0.0], ["icon:deal", Vector2(0.5, 0.62), 0.32, 0.0]], "deal"],
	Pickups.K.SKILL: ["sand", [["cone", Vector2(0.25, 0.2), 0.15, 0.0], ["cone", Vector2(0.72, 0.36), 0.15, 0.0], ["cone", Vector2(0.28, 0.54), 0.15, 0.0], ["cone", Vector2(0.72, 0.7), 0.15, 0.0], ["car", Vector2(0.5, 0.45), 0.28, 0.5]], "bullseye"],
	Pickups.K.MODE: ["asphalt", [["busstop", Vector2(0.3, 0.28), 0.46, 0.0], ["sign", Vector2(0.8, 0.22), 0.18, 0.0], ["car", Vector2(0.62, 0.6), 0.34, -0.3], ["icon:stopwatch", Vector2(0.28, 0.66), 0.24, 0.0]], "stopwatch"],
	Pickups.K.MOVE: ["dirt", [["boulder", Vector2(0.5, 0.66), 0.4, 0.0], ["shadow", Vector2(0.56, 0.5), 0.34, 0.0], ["car", Vector2(0.48, 0.34), 0.36, 0.0]], "jets"],
}

static var textures := {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

static func artPath(name: String, seed: int, n: int) -> String:
	if name == "car" || name == "shadow":
		var car: String = CARS[posmod(seed, CARS.size())]
		return CAR % [car, car]
	if name == "goon":
		var goon: String = GOONS[posmod(seed + n * 3, GOONS.size())]
		return GOON % [goon, goon]
	if name.begins_with("goon:"): return GOON % [name.substr(5), name.substr(5)]
	if name.begins_with("icon:"): return ICON % name.substr(5)
	if name.begins_with("station:"): return STATION % name.substr(8)
	return PROP % name

## Paints the back of a card of pickup kind `kind` into Rect2(at, size), through `base`
static func drawBack(c: CanvasItem, base: Transform2D, kind: int, at: Vector2, size: Vector2, seed: int, color: Color, label: String) -> void:
	var sc: Array = SCENES.get(kind, SCENES[Pickups.K.LOOT])
	c.draw_set_transform_matrix(base)
	#the ground: a patch of the world texture, scaled so its detail reads at card size
	var ground := texture(GROUND % sc[0])
	if ground:
		var patch := Vector2(size.x, size.y) * 1.6
		var origin := Vector2(posmod(seed * 37, 200), posmod(seed * 53, 200))
		c.draw_texture_rect_region(ground, Rect2(at, size), Rect2(origin, patch))
	else: c.draw_rect(Rect2(at, size), color.darkened(0.5))
	c.draw_rect(Rect2(at, size), Color(color, 0.12))
	#the scene
	var n := 0
	for layer in sc[1]:
		n += 1
		var name: String = layer[0]
		var centre: Vector2 = at + size * (layer[1] as Vector2) + Vector2(sin(seed * 1.7 + n) * 4.0, cos(seed * 1.3 + n) * 4.0)
		var w: float = size.x * layer[2]
		if name == "trail":
			for i in 3:
				var x := centre.x + (i - 1) * w * 0.25
				c.draw_line(Vector2(x, centre.y - size.y * 0.2), Vector2(x, centre.y + size.y * 0.12), Color(1.0, 0.6 - i * 0.1, 0.15, 0.55), w * 0.16, true)
			continue
		var tex := texture(artPath(name, seed, n))
		if tex == null: continue
		var h := w * tex.get_height() / tex.get_width()
		c.draw_set_transform_matrix(base * Transform2D(layer[3] + sin(seed + n) * 0.08, centre))
		c.draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(0, 0, 0, 0.45) if name == "shadow" else Color.WHITE)
	c.draw_set_transform_matrix(base)
	#a darker foot for the banner, the banner, the emblem, the frame
	for i in 6: c.draw_rect(Rect2(at.x, at.y + size.y * (0.55 + i * 0.075), size.x, size.y * 0.075), Color(0, 0, 0, 0.06 * (i + 1)))
	var band := Rect2(at.x, at.y + size.y - 30.0, size.x, 30.0)
	c.draw_rect(band, Color(color, 0.92))
	HudTheme.text(c, Vector2(band.get_center().x, band.end.y - 9.0), label.to_upper(), int(clampf(size.x * 0.07, 11.0, 16.0)), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 3)
	var emblem := texture(ICON % sc[2])
	var e := at + Vector2(size.x * 0.13 + 4.0, size.x * 0.13 + 4.0)
	c.draw_circle(e, size.x * 0.13, Color(0, 0, 0, 0.55))
	c.draw_arc(e, size.x * 0.13, 0, TAU, 24, color.lightened(0.3), 2.0, true)
	if emblem: c.draw_texture_rect(emblem, Rect2(e - Vector2.ONE * size.x * 0.09, Vector2.ONE * size.x * 0.18), false)
	c.draw_rect(Rect2(at, size), color.lightened(0.2), false, 4.0)
	c.draw_rect(Rect2(at + Vector2(6, 6), size - Vector2(12, 12)), Color(1, 1, 1, 0.18), false, 1.0)
