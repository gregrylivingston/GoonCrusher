class_name HudPayout extends Control

#Top right: the pause button, the payout sum (coins x stars = what the run pays, Root.computePayout)
#and gems. Coin, star and gem pickups fly to their icons; luck and clover, which change what goons
#drop, fly to the payout.

const COIN_ICON := preload("res://texture/icon/coin.svg")
const STAR_ICON := preload("res://texture/icon/star.svg")
const GEM_ICON := preload("res://texture/icon/gem.svg")
const PILL := Rect2(56, 0, 410, 62)
const GEMS := Rect2(366, 72, 100, 40)
const RIGHT := 452.0

var markers := {}
var layout := {}             #x of each part of the sum, rebuilt when the numbers change
var shownKey := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for group in ["coinui", "starui", "gemui", "luckui", "cloverui"]: markers[group] = HudTheme.marker(self, group, Vector2.ZERO)
	markers.gemui.position = Vector2(GEMS.position.x + 20, GEMS.position.y + 20)
	markers.luckui.position = Vector2(RIGHT - 30, 38)
	markers.cloverui.position = markers.luckui.position
	var pause = Button.new()
	pause.flat = true
	pause.focus_mode = Control.FOCUS_NONE
	pause.position = Vector2.ZERO
	pause.size = Vector2(46, 62)
	pause.tooltip_text = "Pause"
	pause.pressed.connect(onPausePressed)
	add_child(pause)

func onPausePressed() -> void:
	owner.openPause()

func _process(_delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var key = [car.coin, car.star, car.gem]
	if key != shownKey:
		shownKey = key
		layOut(car)
		queue_redraw()

func layOut(car) -> void:
	var x = PILL.position.x + 16
	layout.coin = x + 18
	x += 42
	layout.coins = x
	x += HudTheme.textWidth(str(car.coin), 26) + 12
	layout.times = x
	x += HudTheme.textWidth("x", 22) + 12
	layout.star = x + 18
	x += 42
	layout.stars = x
	x += HudTheme.textWidth(str(car.star), 26) + 12
	layout.equals = x
	markers.coinui.position = Vector2(layout.coin, 31)
	markers.starui.position = Vector2(layout.star, 31)

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || layout.is_empty(): return
	HudTheme.panel(self, Rect2(0, 0, 46, 62), Color(1, 1, 1, 0.25))
	draw_rect(Rect2(14, 18, 6, 26), HudTheme.TEXT)
	draw_rect(Rect2(26, 18, 6, 26), HudTheme.TEXT)
	HudTheme.panel(self, PILL)
	HudTheme.icon(self, COIN_ICON, Vector2(layout.coin, 31), 36)
	HudTheme.text(self, Vector2(layout.coins, 42), str(car.coin), 26)
	HudTheme.text(self, Vector2(layout.times, 41), "x", 22, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 4)
	HudTheme.icon(self, STAR_ICON, Vector2(layout.star, 30), 36)
	HudTheme.text(self, Vector2(layout.stars, 42), str(car.star), 26)
	HudTheme.text(self, Vector2(layout.equals, 41), "=", 22, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 4)
	HudTheme.text(self, Vector2(RIGHT, 19), "PAYOUT", 11, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	HudTheme.text(self, Vector2(RIGHT, 51), str(Root.computePayout(car.coin, car.star)), 30, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 10, HudTheme.DEEP)
	HudTheme.panel(self, GEMS, Color(HudTheme.SKY, 0.45), 10)
	HudTheme.icon(self, GEM_ICON, Vector2(GEMS.position.x + 20, GEMS.position.y + 20), 26)
	HudTheme.text(self, Vector2(RIGHT, GEMS.position.y + 29), str(car.gem), 22, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
