class_name HudSkin extends RefCounted

#A car's dashboard: the look of its dials and which signature instrument sits beside them
#(docs/HUD.md, "Dashboards"). A car names its skin in CarInfo.hudSkin; a car with none, and every car with
#the Classic Dashboard setting on, gets "house", the HUD's own orange look. A skin is paint: the speed
#scale, the redline and the gear still come from the car, and green (crush speed), red (redline, danger)
#and amber (warning) mean the same on every dash.

enum Style { ROUND, RIBBON, BAR }               #needle dials; the pickup's sliding ribbons; the Track bar tach and digits
enum Bezel { RING, CHECKER, CHROME, SQUARE }    #a plain rim; the cab's checker band; chrome on a wood plate; a square housing
enum Lamp { RING, TILE, BLOCK, VITAL, GAUGE, PILL, LCD, LED } #how HudLamps draws a system lamp: a round tell-tale with a ring, a tile, an annunciator block...

const SAIRA := preload("res://style/font/SairaCondensed/SairaCondensed-Bold.ttf")
const SAIRA_BODY := preload("res://style/font/SairaCondensed/SairaCondensed-Medium.ttf")
const MICHROMA := preload("res://style/font/Michroma/Michroma-Regular.ttf")
const ROKKITT := preload("res://style/font/Rokkitt/Rokkitt-Variable.ttf")
const LED := preload("res://style/font/ShareTechMono/ShareTechMono-Regular.ttf")

var id: StringName = &"house"
var style := Style.ROUND
var bezel := Bezel.RING
var face := Color(0.047, 0.039, 0.035, 0.86)
var house := Color(0.055, 0.047, 0.043, 0.9)     #a square housing, a ribbon's panel
var hub := Color(0.106, 0.09, 0.078)
var rim := HudTheme.RIM
var text := HudTheme.TEXT
var muted := HudTheme.MUTED
var needle := HudTheme.NEEDLE
var tip := Color(0, 0, 0, 0)                     #the last fifth of the needle, when it has its own colour
var track := HudTheme.TRACK
var accent := HudTheme.GOLD                      #the gear number, the instrument's lit parts
var glow := Color(1.0, 0.62, 0.2)                #the night backlight
var ok := HudTheme.OK
var warn := HudTheme.WARN
var bad := HudTheme.BAD
var bold: Font = HudTheme.BOLD
var body: Font = HudTheme.BODY
var numScale := 1.0                              #dial numerals, for a narrow or a wide font
var light := false                               #a light face: dark numerals with no outline
var sweep := 90.0                                #the dials' scale: this many degrees either side of its middle (HudDial.TILT leans it)
var taper := false                               #a tapered needle
var rimWidth := 3.0
var minor := 2                                   #speedometer ticks per numbered tick
var tachUnits := 1                               #10: the tach reads in hundreds of rpm
var econ := Vector2.ZERO                         #a green band on the tach, in thousands of rpm
var weave := false                               #carbon hatching on the face
var hullMonitor := false                         #the hull is a heart monitor beside the speedometer
var lamp := Lamp.RING                             #how the system lamps are drawn
var radius := 12                                 #corner radius of the HUD's panels
var mirror: StringName = &""                     #HudMirror's dressing: crack, checker, lights, clinic, console, keys, convex, screen
var instrument: StringName = &""                 #HudInstrument's kind
var instrumentAt := []                           #its [left, top, right, bottom] offsets, where it can't sit in its usual bay
var rects := {}                                  #HudDial.Kind -> [left, top, right, bottom] offsets, where a cluster is not a sunken dial

const SKINS := {
	&"house": {},
	&"beater": {"mirror":&"crack", "instrument":&"beater"},
	&"hack": {"bezel":Bezel.CHECKER, "face":Color(0.05, 0.05, 0.05, 0.9), "hub":Color(0.08, 0.08, 0.08), "rim":Color(0.965, 0.761, 0.102),
		"text":Color.WHITE, "muted":Color(0.79, 0.76, 0.66), "needle":Color(0.965, 0.761, 0.102), "track":Color(0.165, 0.165, 0.165),
		"accent":Color(0.965, 0.761, 0.102), "glow":Color(0.965, 0.761, 0.102), "bold":SAIRA, "body":SAIRA_BODY, "numScale":1.25, "taper":true,
		"radius":4, "lamp":Lamp.TILE, "mirror":&"checker", "instrument":&"meter"},
	&"interceptor": {"face":Color(0.02, 0.027, 0.051, 0.9), "hub":Color(0.067, 0.082, 0.102), "rim":Color(0.184, 0.482, 1.0),
		"text":Color.WHITE, "muted":Color(0.56, 0.706, 1.0), "needle":Color.WHITE, "tip":HudTheme.BAD, "track":Color(0.075, 0.11, 0.2),
		"accent":Color.WHITE, "glow":Color(0.184, 0.482, 1.0), "bold":SAIRA, "body":SAIRA_BODY, "numScale":1.25, "minor":10,
		"radius":6, "lamp":Lamp.BLOCK, "mirror":&"lights", "instrument":&"radar"},
	&"medic": {"face":Color(0.933, 0.945, 0.918, 0.96), "hub":Color.WHITE, "rim":Color(0.847, 0.149, 0.173), "text":Color(0.078, 0.094, 0.102),
		"muted":Color(0.365, 0.4, 0.392), "needle":Color(0.847, 0.149, 0.173), "track":Color(0.81, 0.83, 0.8), "accent":Color(0.078, 0.094, 0.102),
		"glow":Color(1.0, 0.45, 0.45), "ok":Color(0.122, 0.616, 0.302), "warn":Color(0.85, 0.54, 0.0), "bad":Color(0.847, 0.149, 0.173),
		"bold":SAIRA, "body":SAIRA_BODY, "numScale":1.25, "light":true, "hullMonitor":true, "radius":14, "lamp":Lamp.VITAL,
		"mirror":&"clinic", "instrument":&"defib"},
	&"rig": {"bezel":Bezel.CHROME, "face":Color(0.039, 0.035, 0.031, 0.95), "hub":Color(0.1, 0.082, 0.07), "rim":Color(0.79, 0.8, 0.815),
		"text":Color(0.953, 0.918, 0.824), "muted":Color(0.725, 0.68, 0.573), "needle":Color(1.0, 0.353, 0.122), "track":Color(0.15, 0.13, 0.106),
		"accent":Color(1.0, 0.827, 0.42), "glow":Color(1.0, 0.7, 0.3), "bold":SAIRA, "body":SAIRA_BODY, "numScale":1.25, "taper":true,
		"sweep":84.0, "tachUnits":10, "econ":Vector2(1.2, 1.8), "radius":10, "lamp":Lamp.GAUGE, "mirror":&"console", "instrument":&"load"},
	&"truck": {"style":Style.RIBBON, "face":Color(0.09, 0.094, 0.055, 0.95), "house":Color(0.204, 0.216, 0.122, 0.94), "rim":Color(0.4, 0.416, 0.255),
		"text":Color(0.945, 0.902, 0.784), "muted":Color(0.72, 0.68, 0.533), "needle":Color(1.0, 0.353, 0.122), "track":Color(0.165, 0.173, 0.106),
		"accent":Color(1.0, 0.827, 0.42), "glow":Color(0.8, 0.9, 0.4), "bold":ROKKITT, "weight":800, "numScale":1.15, "radius":8, "lamp":Lamp.PILL, "mirror":&"keys", "instrument":&"bed",
		"instrumentAt":[16.0, -220.0, 216.0, -124.0], "rects":{0:[16.0, -116.0, 388.0, -8.0], 1:[-388.0, -116.0, -16.0, -8.0]}},
	&"delivery": {"bezel":Bezel.SQUARE, "face":Color(0.055, 0.07, 0.078, 0.95), "house":Color(0.169, 0.188, 0.2, 0.94), "hub":Color(0.09, 0.11, 0.122),
		"rim":Color(0.36, 0.404, 0.43), "text":Color(0.85, 0.94, 0.89), "muted":Color(0.56, 0.64, 0.604), "needle":Color(1.0, 0.54, 0.122),
		"track":Color(0.122, 0.15, 0.16), "accent":Color(0.85, 0.94, 0.89), "glow":Color(0.3, 1.0, 0.6), "bold":SAIRA, "body":SAIRA_BODY,
		"numScale":1.25, "sweep":78.0, "radius":2, "lamp":Lamp.LCD, "mirror":&"convex", "instrument":&"tilt"},
	&"track_racer": {"style":Style.BAR, "face":Color(0.043, 0.039, 0.078, 0.92), "hub":Color(0.086, 0.075, 0.165), "rim":Color(1.0, 0.17, 0.84),
		"text":Color(0.957, 0.95, 1.0), "muted":Color(0.616, 0.592, 0.77), "track":Color(0.133, 0.122, 0.22), "accent":Color(1.0, 0.17, 0.84),
		"glow":Color(1.0, 0.17, 0.84), "bold":MICHROMA, "body":MICHROMA, "numScale":0.8, "rimWidth":1.5, "radius":20, "lamp":Lamp.LED, "mirror":&"screen", "instrument":&"shift"},
	&"track_super": {"style":Style.BAR, "face":Color(0.04, 0.04, 0.04, 0.94), "hub":Color(0.086, 0.086, 0.086), "rim":Color(1.0, 0.83, 0.0),
		"text":Color.WHITE, "muted":Color(0.64, 0.64, 0.64), "track":Color(0.15, 0.15, 0.15), "accent":Color(1.0, 0.83, 0.0),
		"glow":Color(1.0, 0.83, 0.0), "bold":MICHROMA, "body":MICHROMA, "numScale":0.8, "rimWidth":1.5, "weave":true, "radius":20, "lamp":Lamp.LED, "mirror":&"screen", "instrument":&"shift"},
}

static var built := {}

## The skin called `skinId`; "house" for a name that isn't one
static func named(skinId: StringName) -> HudSkin:
	if not SKINS.has(skinId): skinId = &"house"
	if not built.has(skinId):
		var skin := HudSkin.new()
		skin.id = skinId
		var data: Dictionary = SKINS[skinId]
		for key in data:
			if key != "weight": skin.set(key, data[key])
		if data.has("weight"): #a variable font, at one weight
			var font := FontVariation.new()
			font.base_font = data.bold
			font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): data.weight}
			skin.bold = font
			skin.body = font
		built[skinId] = skin
	return built[skinId]

## The skin of the car being driven: the house look with no car, or with Classic Dashboard on
static func current() -> HudSkin:
	var car = Root.playerCar
	if not is_instance_valid(car) || Settings.get_value("access/classic_dash"): return named(&"house")
	var skinId = car.get("hudSkin")
	return named(skinId if skinId is StringName else &"house")

## The frame of the things along the top (the mirror, the visors): the dashboard's material
func frameColor() -> Color:
	if light: return Color(face, 0.97)
	if bezel == Bezel.CHROME: return Color(0.227, 0.145, 0.086, 0.97) #wood
	if style == Style.RIBBON || bezel == Bezel.SQUARE: return Color(house, 0.97)
	return Color(0.09, 0.078, 0.07, 0.97)

func corner() -> int:
	return 6 if style == Style.BAR else clampi(radius * 2, 4, 26)

#green, amber or red for a 0-100 amount, in this face's shades
func condition(value: float) -> Color:
	if value >= 70.0: return ok
	if value >= 40.0: return warn
	return bad

#text on this skin: its font, and no outline on a light face
func write(item: CanvasItem, pos: Vector2, value: String, fontSize: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 4, font: Font = null) -> void:
	HudTheme.text(item, pos, value, fontSize, color, align, 0 if light else outline, HudTheme.OUTLINE, font if font else bold)
