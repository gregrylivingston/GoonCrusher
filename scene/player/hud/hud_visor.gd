class_name HudVisor extends Control

#The sun visors either side of the mirror (docs/HUD.md, "The visors"): two low slabs flush with the top edge, framed
#like the mirror in the dashboard's material.
#  Left (PRIZE): the next gift box (CrushPrizes) in a ring that fills with crush XP, in its tier's color, with the
#        XP still to go; then the radio: a little equaliser, and the song for a few seconds when one starts (the
#        visor grows for it and shrinks back).
#  Right (PAY): the star in a ring that fills as the run's wave runs down (Region.waveProgress: a star every wave,
#        one clock for the whole run), with the star multiplier and the time to the next star; then the coins and
#        what the run pays right now (Root.computePayout). Gems slide out under it for a few seconds when one is
#        picked up.
#Coin, star and gem pickups fly to their icons, prize pickups and crush XP to the box. Redraws only on change.

enum Kind { PRIZE, PAY }

@export var kind := Kind.PRIZE

const SIZE := Vector2(330, 58)
const SHUT := 164.0          #the left visor's width between songs
const RING := Vector2(34, 30)
const SONG_SECONDS := 5.0    #a new song's name stays this long
const SONG_IN := 0.25
const SONG_OUT := 0.6
const GEM_SECONDS := 3.0     #the gem tab stays out this long after a gem
const METER_FPS := 8.0
const GLASS := Color(0.055, 0.047, 0.043, 0.93)
const GIFT_ICON := preload("res://texture/icon/gift.svg")

var skin: HudSkin = HudSkin.named(&"house")
var set := false
var shownKey := []
var song := {}               #the radio's now-playing
var songHold := 0.0
var songShown := 0.0         #0 shut, 1 open
var gems := -1
var gemHold := 0.0
var markers := {}
var flash := 0.0: #a gold wash, tweened down from 1 when a box is earned or a wave survived (GameUI.flashWidget)
	set(value):
		flash = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if kind == Kind.PRIZE:
		for group in ["currentGoonsCrushedui", "slotmachineui"]: markers[group] = HudTheme.marker(self, group, RING)
		Audio.radio.trackStarted.connect(onTrackStarted)
		Audio.radio.stationChanged.connect(onStationChanged)
		song = Audio.radio.nowPlaying()
	else:
		markers.starui = HudTheme.marker(self, "starui", RING)
		markers.coinui = HudTheme.marker(self, "coinui", Vector2(132, 30))
		markers.gemui = HudTheme.marker(self, "gemui", gemTab().position + Vector2(18, 15))
	Settings.changed.connect(onSettingChanged)

func onSettingChanged(key: String, _value) -> void:
	if key == "access/classic_dash": set = false

func onTrackStarted(track: Dictionary) -> void:
	song = track
	songHold = SONG_SECONDS

func onStationChanged(_id: StringName) -> void:
	song = Audio.radio.nowPlaying()
	songHold = SONG_SECONDS

func radioOn() -> bool:
	return song.get("station", Radio.OFF) != Radio.OFF

#the tab under the right visor that the gems slide out on
func gemTab() -> Rect2:
	return Rect2(SIZE.x - 104.0, SIZE.y + 4.0, 96, 30)

func _process(delta: float) -> void:
	var car = GameUI.carOf(self)
	if not is_instance_valid(car): return
	if not set:
		set = true
		skin = HudSkin.of(self)
		shownKey = []
	var key: Array
	if kind == Kind.PRIZE:
		var to := 1.0 if songHold > 0.0 else 0.0
		songHold = maxf(0.0, songHold - delta)
		songShown = move_toward(songShown, to, delta / (SONG_IN if to > songShown else SONG_OUT))
		key = [int(car.crushXp), owner.boxLevel, snappedf(songShown, 0.02), radioOn(), int(Time.get_ticks_msec() / 1000.0 * METER_FPS) if radioOn() else 0]
	else:
		if gems >= 0 && car.gem != gems: gemHold = GEM_SECONDS + RewardFlyers.FLIGHT_SECONDS #a gem is on its way
		gems = car.gem
		gemHold = maxf(0.0, gemHold - delta)
		key = [car.coin, car.star, car.gem, Region.waveSecondsLeft(), snappedf(Region.waveProgress(), 0.01), snappedf(minf(gemHold, 0.3), 0.03)]
	if key != shownKey:
		shownKey = key
		queue_redraw()

#the slab: the dashboard's frame round a dark inset, hanging from above the top edge
func drawSlab(width: float) -> void:
	var x := 0.0 if kind == Kind.PRIZE else SIZE.x - width
	var turn := mini(skin.corner(), 14)
	HudTheme.panel(self, Rect2(x, -16, width, SIZE.y + 16.0), Color(skin.rim, 0.9), turn, skin.frameColor())
	HudTheme.panel(self, Rect2(x + 5, -16, width - 10, SIZE.y + 11.0), Color(skin.rim, 0.4), maxi(2, turn - 4), GLASS)
	if flash > 0.0: HudTheme.panel(self, Rect2(x, -16, width, SIZE.y + 16.0), Color(HudTheme.GOLD, flash), turn, Color(HudTheme.GOLD, flash * 0.25))

#a ring with something in it: the track, then `fraction` of it in `color`
func drawRing(fraction: float, color: Color) -> void:
	draw_circle(RING, 22, Color(color, 0.16))
	draw_arc(RING, 19, 0.0, TAU, 40, HudTheme.TRACK, 4.0, true)
	HudTheme.arc(self, RING, 19, 0.0, 360.0 * clampf(fraction, 0.0, 1.0), color, 4.0)

func _draw() -> void:
	var car = GameUI.carOf(self)
	if not is_instance_valid(car): return
	if kind == Kind.PRIZE: drawPrize(car)
	elif car.isGuest: drawGuestCoins(car)
	else: drawPay(car)

#the second player's (Coop): the coins they picked up. The stars and the payout are the player's.
func drawGuestCoins(car) -> void:
	drawSlab(SIZE.x)
	drawRing(0.0, HudTheme.GAIN)
	HudTheme.icon(self, HudTheme.COIN_ICON, RING, 28)
	HudTheme.text(self, Vector2(SIZE.x - 14, 16), "COINS", 9, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 3, HudTheme.OUTLINE, HudTheme.BODY)
	HudTheme.text(self, Vector2(SIZE.x - 14, 46), str(car.coin), 30, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 9, HudTheme.DEEP)

func drawPrize(car) -> void:
	var ui = owner
	var open := 1.0 - pow(1.0 - songShown, 3.0)
	drawSlab(lerpf(SHUT, SIZE.x, open))
	var tier := CrushPrizes.tierFor(ui.boxLevel + 1)
	var color := CrushPrizes.tierColor(tier)
	var span: float = ui.nextBoxXp - ui.boxStartXp
	drawRing(1.0 if span <= 0.0 else (car.crushXp - ui.boxStartXp) / span, color)
	HudTheme.icon(self, GIFT_ICON, RING, 28)
	HudTheme.text(self, Vector2(84, 34), str(maxi(0, ceili(ui.nextBoxXp - car.crushXp))), 20, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 5)
	HudTheme.text(self, Vector2(84, 48), "XP", 11, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
	draw_line(Vector2(114, 12), Vector2(114, 48), Color(1, 1, 1, 0.14), 1.0)
	#the radio: an equaliser that dances while a station plays, and the song while the visor is open
	var on := radioOn()
	var accent: Color = song.get("color", HudTheme.RIM) if on else Color(HudTheme.MUTED, 0.4)
	var tick := int(Time.get_ticks_msec() / 1000.0 * METER_FPS)
	for i in 4:
		var tall := 4.0 + float((tick * (i * 2 + 3) + i * 5) % 11) * 1.4 if on else 3.0
		draw_rect(Rect2(126 + i * 7.0, 40.0 - tall, 5, tall), accent)
	if open <= 0.02: return
	var title: String = song.get("title", "")
	var second: String = song.get("stationName", "")
	if not on:
		title = "Radio Off"
		second = ""
	elif title == "":
		title = second
		second = "Tuning in..."
	var room := SIZE.x - 172.0
	HudTheme.text(self, Vector2(160, 30 if second != "" else 36), NowPlaying.fit(title, 15, room, HudTheme.BOLD), 15, Color(HudTheme.TEXT, open), HORIZONTAL_ALIGNMENT_LEFT, 4, Color(HudTheme.OUTLINE, open))
	if second != "": HudTheme.text(self, Vector2(160, 46), NowPlaying.fit(second, 11, room, HudTheme.BODY), 11, Color(HudTheme.MUTED, open), HORIZONTAL_ALIGNMENT_LEFT, 3, Color(HudTheme.OUTLINE, open), HudTheme.BODY)

func drawPay(car) -> void:
	drawSlab(SIZE.x)
	#the star: its ring is the wave, and a full ring pays the next one
	var waves := Modes.hasGoons(Modes.running())
	drawRing(Region.waveProgress() if waves else 0.0, HudTheme.GAIN)
	HudTheme.icon(self, HudTheme.STAR_ICON, RING, 24)
	HudTheme.text(self, Vector2(80, 32 if waves else 38), "x" + Root.multiplierText(car.star), 18, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 5)
	if waves:
		var left := Region.waveSecondsLeft()
		HudTheme.text(self, Vector2(80, 47), "%d:%02d" % [left / 60, left % 60], 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
	draw_line(Vector2(110, 12), Vector2(110, 48), Color(1, 1, 1, 0.14), 1.0)
	#coins, then what they pay with the stars: the big number
	var payout := str(Root.computePayout(car.coin, car.star))
	var payoutLeft := SIZE.x - 14.0 - HudTheme.textWidth(payout, 30)
	HudTheme.icon(self, HudTheme.COIN_ICON, Vector2(132, 30), 26)
	if 150.0 + HudTheme.textWidth(str(car.coin), 17) + 12.0 <= payoutLeft: #room for the sum's first half
		HudTheme.text(self, Vector2(150, 36), str(car.coin), 17, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 4)
	HudTheme.text(self, Vector2(SIZE.x - 14, 16), "PAYOUT", 9, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 3, HudTheme.OUTLINE, HudTheme.BODY)
	HudTheme.text(self, Vector2(SIZE.x - 14, 46), payout, 30, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 9, HudTheme.DEEP)
	#gems: out for a moment when one is picked up
	var out := clampf(gemHold / 0.3, 0.0, 1.0)
	if out > 0.0:
		var tab := gemTab()
		HudTheme.panel(self, tab, Color(HudTheme.SKY, 0.55 * out), 8, Color(HudTheme.PANEL, HudTheme.PANEL.a * out))
		HudTheme.icon(self, HudTheme.GEM_ICON, tab.position + Vector2(18, 15), 22, Color(1, 1, 1, out))
		HudTheme.text(self, Vector2(tab.end.x - 12, tab.position.y + 22), str(car.gem), 19, Color(HudTheme.TEXT, out), HORIZONTAL_ALIGNMENT_RIGHT, 5, Color(HudTheme.OUTLINE, out))
