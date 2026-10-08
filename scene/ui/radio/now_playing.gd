class_name NowPlaying extends Control

#The radio's now-playing card (docs/RADIO.md). In a run (the HUD, bottom left above the tachometer)
#it slides in when a song starts or the station changes, holds a few seconds and fades. In the main
#menu it is pinned (always shown) and a click changes station (right click goes back).
#Drawn with _draw like the HUD widgets; redraws only while it moves or its little meter ticks.

const ICON := preload("res://texture/icon/radio.svg")
const SIZE := Vector2(360, 58)
const HOLD_SECONDS := 5.0
const IN_SECONDS := 0.25
const OUT_SECONDS := 0.6
const METER_FPS := 8.0

var pinned := false
var info := {}
var shown := 0.0    #0 hidden, 1 fully in
var hold := 0.0
var meterTick := -1
var hovered := false


func _ready():
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP if pinned else Control.MOUSE_FILTER_IGNORE
	if pinned:
		tooltip_text = "Radio: click to change station"
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(setHovered.bind(true))
		mouse_exited.connect(setHovered.bind(false))
		shown = 1.0
	Audio.radio.trackStarted.connect(onTrackStarted)
	Audio.radio.stationChanged.connect(onStationChanged)
	info = Audio.radio.nowPlaying()
	visible = shown > 0.0

func onTrackStarted(track: Dictionary) -> void:
	info = track
	popIn()

func onStationChanged(_id: StringName) -> void:
	info = Audio.radio.nowPlaying()
	popIn()

func popIn() -> void:
	hold = HOLD_SECONDS
	visible = true
	queue_redraw()

func setHovered(value: bool) -> void:
	hovered = value
	queue_redraw()

func _gui_input(event):
	if not pinned || not event is InputEventMouseButton || not event.pressed: return
	if event.button_index == MOUSE_BUTTON_LEFT: Audio.radio.cycleStation(1)
	elif event.button_index == MOUSE_BUTTON_RIGHT: Audio.radio.cycleStation(-1)
	else: return
	accept_event()

func _process(delta):
	if not pinned:
		var target = 1.0 if hold > 0.0 else 0.0
		hold = maxf(0.0, hold - delta)
		var before = shown
		shown = move_toward(shown, target, delta / (IN_SECONDS if target > shown else OUT_SECONDS))
		if shown != before:
			#Reduce Motion fades instead of sliding
			modulate.a = eased() if Settings.reduce_motion() else 1.0
			queue_redraw()
		visible = shown > 0.0
	if visible && isPlaying():
		var tick = int(Time.get_ticks_msec() / 1000.0 * METER_FPS)
		if tick != meterTick:
			meterTick = tick
			queue_redraw()

func eased() -> float:
	return 1.0 - pow(1.0 - shown, 3.0)

func isPlaying() -> bool:
	return info.get("station", Radio.OFF) != Radio.OFF

func _draw():
	var offset = Vector2.ZERO
	if not pinned && not Settings.reduce_motion(): offset.x = -(1.0 - eased()) * (SIZE.x + 40.0)
	var accent: Color = info.get("color", Color(1, 1, 1, 0.5))
	var rect = Rect2(offset, SIZE)
	HudTheme.panel(self, rect, Color(accent, 0.9 if hovered else 0.6))
	draw_texture_rect(ICON, Rect2(offset + Vector2(10, 11), Vector2(36, 36)), false, Color(1, 1, 1, 1.0 if isPlaying() else 0.4))
	var textLeft = offset.x + 56.0
	var textWidth = SIZE.x - 56.0 - (44.0 if isPlaying() else 12.0)
	var title: String = info.get("title", "")
	var second: String
	if not isPlaying():
		title = "Radio Off"
		second = "Click to tune in" if pinned else ""
	elif title == "":
		title = info.get("stationName", "")
		second = "Tuning in..."
	else:
		var artist: String = info.get("artist", "")
		var station: String = info.get("stationName", "")
		second = station if artist == "" || artist == station else "%s  -  %s" % [artist, station]
	var titleY = 27.0 if second != "" else 36.0
	HudTheme.text(self, Vector2(textLeft, offset.y + titleY), fit(title, 21, textWidth, HudTheme.BOLD), 21, HudTheme.TEXT)
	if second != "":
		HudTheme.text(self, Vector2(textLeft, offset.y + 47.0), fit(second, 15, textWidth, HudTheme.BODY), 15, HudTheme.MUTED,
			HORIZONTAL_ALIGNMENT_LEFT, 4, HudTheme.OUTLINE, HudTheme.BODY)
	if isPlaying(): drawMeter(Vector2(offset.x + SIZE.x - 36.0, offset.y + 42.0), accent)

#three bouncing level bars, stepped at METER_FPS (looks alive, costs a few redraws a second)
func drawMeter(base: Vector2, color: Color) -> void:
	var t = meterTick
	for i in 3:
		var h = 6.0 + 18.0 * absf(sin(t * (0.9 + i * 0.37) + i * 1.7))
		draw_rect(Rect2(base + Vector2(i * 8.0, -h), Vector2(5, h)), color)

#cuts text to a width with an ellipsis
static func fit(text: String, fontSize: int, width: float, font: Font) -> String:
	if HudTheme.textWidth(text, fontSize, font) <= width: return text
	var cut = text.length()
	while cut > 1 && HudTheme.textWidth(text.substr(0, cut) + "...", fontSize, font) > width: cut -= 1
	return text.substr(0, cut).strip_edges() + "..."
