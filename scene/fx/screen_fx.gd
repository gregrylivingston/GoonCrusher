class_name ScreenFx extends CanvasLayer
## The run's screen layer (docs/roadmap/ROADMAP_JUICE.md), over the world and under the HUD. Fx owns one
## (Fx.screen). Everything is drawn shapes and one gradient: no screen-texture pass, so it costs little fill.
##   - a flash on a near blast or a giant (flash(); never with Reduce Flashing)
##   - a red edge that pulses when the player's car is hurt and beats while its health is low
##   - streaks at the edges at speed: on nitro, on a drift boost and near the car's top speed (never with
##     Reduce Motion)
##   - a darker edge while a hit-stop holds the game
##   - a warm edge as the heat rises
## It also keeps the heat (Fx.heat): 0 to 1 from the player's Crush Combo, which the other effects scale by.
## Screen Effects (gfx/screen_fx) turns the drawing off; the heat is kept either way. It reads the car and
## never writes it. Off in a two-player run: the screen is two views there.

const FLASH_SECONDS := 0.14
const HURT_PER_HEALTH := 1.0 / 30.0 #edge strength per point of health lost at once
const HURT_MIN := 1.0             #a loss smaller than this (the chip of a crush) shows nothing
const HURT_DECAY := 1.6           #per second
const LOW_HEALTH := 25.0
const HEAT_COMBO := 20.0          #the Crush Combo that is full heat
const HEAT_EASE := 2.0            #per second
const STREAKS := 30
const STREAK_EASE := 5.0
const NEAR_TOP := 0.85            #share of the car's top speed where the streaks begin
const RED := Color(0.85, 0.05, 0.03)
const WARM := Color(1.0, 0.5, 0.1)

static var EDGE := edgeTexture() #clear in the middle, white at the corners

var canvas := Control.new()
var fx: Fx
var on := true
var flashLeft := 0.0
var flashPeak := 0.0
var hurt := 0.0
var low := 0.0
var streaks := 0.0
var dim := 0.0
var lastHealth := -1.0
var clock := 0.0
var drawn := false

static func edgeTexture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(0.72, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.1, 0.5)
	t.width = 128
	t.height = 128
	return t

func _init(owner: Fx) -> void:
	fx = owner
	name = "ScreenFx"
	layer = 0 #over the world, under the HUD (PlayerRoot, layer 1)
	process_mode = Node.PROCESS_MODE_ALWAYS #to clear itself when the run pauses
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(draw)
	add_child(canvas)

func _ready() -> void:
	readSettings()
	Settings.changed.connect(onSettingChanged)

func onSettingChanged(key: String, _value) -> void:
	if key == "gfx/screen_fx": readSettings()

func readSettings() -> void:
	on = Settings.get_value("gfx/screen_fx") > 0

## A white flash of `amount` (0 to 1) over the whole screen
func flash(amount: float) -> void:
	if not on || Settings.get_value("access/reduce_flashing") || amount <= 0.02: return
	flashPeak = maxf(flashPeak if flashLeft > 0.0 else 0.0, minf(amount, 1.0))
	flashLeft = FLASH_SECONDS

func _process(delta: float) -> void:
	clock += delta
	var car = Root.playerCar
	var live: bool = is_instance_valid(car) && not get_tree().paused
	fx.heat = move_toward(fx.heat, heatFor(car.comboCount) if live else 0.0, HEAT_EASE * delta)
	flashLeft = maxf(0.0, flashLeft - delta)
	hurt = maxf(0.0, hurt - HURT_DECAY * delta)
	var wantStreaks := 0.0
	var wantLow := 0.0
	if live:
		var health: float = car.health
		if lastHealth >= 0.0: hurt = minf(1.0, hurt + hurtFor(lastHealth - health))
		lastHealth = health
		if health <= LOW_HEALTH && not car.isDestroyed: wantLow = 1.0
		if not Settings.reduce_motion(): wantStreaks = streaksFor(car) * (1.0 + 0.5 * fx.heat)
	else:
		hurt = 0.0
		lastHealth = -1.0
	low = move_toward(low, wantLow, 2.0 * delta)
	streaks = lerpf(streaks, wantStreaks, 1.0 - exp(-STREAK_EASE * delta))
	dim = move_toward(dim, 1.0 if live && Engine.time_scale < 0.99 else 0.0, 12.0 * delta)
	var show: bool = on && not Coop.active && (flashLeft > 0.0 || hurt > 0.01 || low > 0.01 || streaks > 0.02 || dim > 0.01 || fx.heat > 0.05)
	if show || drawn: canvas.queue_redraw()
	drawn = show

static func heatFor(combo: int) -> float:
	return clampf(combo / HEAT_COMBO, 0.0, 1.0)

static func hurtFor(lost: float) -> float:
	return lost * HURT_PER_HEALTH if lost >= HURT_MIN else 0.0

## How hard the edges streak, 0 to 1: full on nitro, strong while a drift boost burns, rising near top speed
func streaksFor(car) -> float:
	if car.isDestroyed: return 0.0
	if car.buffs.has("nitro"): return 1.0
	var juice = car.juice
	if not is_instance_valid(juice): return 0.0
	if juice.flameLeft > 0.0: return 0.8
	return 0.4 * clampf((car.velocity.length() / maxf(juice.top, 1.0) - NEAR_TOP) / (1.0 - NEAR_TOP), 0.0, 1.0)

func draw() -> void:
	if not drawn: return
	var c := canvas
	var rect := Rect2(Vector2.ZERO, c.size)
	if dim > 0.01: c.draw_texture_rect(EDGE, rect, false, Color(0, 0, 0, 0.45 * dim))
	if fx.heat > 0.05: c.draw_texture_rect(EDGE, rect, false, Color(WARM, 0.14 * fx.heat * fx.heat))
	var beat := 0.3 if Settings.get_value("access/reduce_flashing") else 0.3 + 0.2 * sin(clock * 6.0)
	var red := maxf(hurt * 0.75, low * beat)
	if red > 0.01: c.draw_texture_rect(EDGE, rect, false, Color(RED, red))
	if streaks > 0.02:
		var mid := c.size * 0.5
		var reach := mid.length()
		for i in STREAKS:
			var dir := Vector2.from_angle(i * TAU / STREAKS + sin(i * 12.9898) * 0.09)
			var u := fmod(clock * (1.3 + 0.5 * sin(i * 4.1)) + i * 0.37, 1.0) #each streak runs out to the edge, again and again
			var from := 0.58 + 0.4 * u
			c.draw_line(mid + dir * reach * from, mid + dir * reach * (from + 0.1 + 0.08 * streaks), Color(1, 1, 1, 0.45 * streaks * u), 2.0 + 2.0 * u)
	if flashLeft > 0.0: c.draw_rect(rect, Color(1.0, 0.97, 0.9, 0.55 * flashPeak * flashLeft / FLASH_SECONDS))
