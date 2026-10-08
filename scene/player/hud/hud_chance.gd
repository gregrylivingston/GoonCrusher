class_name HudChance extends Control

#The HUD's moments (docs/HUD.md): rare-pickup toasts under the clock, the Scratch Card and Double or
#Nothing in the top-right corner under the payout, the Crush Combo under the crush pill, arrows at the
#screen edge for events and supply drops (PickupWorld.beacons), and the Goon Nuke's flash. It covers
#the screen, isn't scaled by HUD Scale, and only redraws while one of these is showing.

const TOAST_SECONDS := 2.2
const SCRATCH_STEP := 0.5
const SCRATCH_POOL := {"coinstack": 30, "gem": 14, "nitro": 14, "wrench": 12, "magnet": 10, "starfrag": 8, "purse": 8, "gemcluster": 4}
const EDGE := 70.0

static var current: HudChance

var toasts: Array = []        #[text, color, icon]
var toastT := 0.0
var scratch := {}             #{cells, shown, t}
var doubleActive := false
var doubleT := 0.0
var doubleStake := 0
var combo := {}               #{text, t, count, pop}
var flashT := 0.0

func _ready() -> void:
	current = self
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _exit_tree() -> void:
	if current == self: current = null

#--- the moments --------------------------------------------------------------------------------

func toast(text: String, color := HudTheme.GOLD, icon: Texture2D = null) -> void:
	if toasts.size() >= 4: toasts.pop_front()
	toasts.push_back([text, color, icon])
	if toasts.size() == 1: startToast()

#the head toast arrives: a soft tick, and a legendary pickup gets a small stamp beside its pill
func startToast() -> void:
	toastT = 0.0
	var t: Array = toasts[0]
	Transition.sound("pop", -18.0, 1.6)
	if t[1] == Pickups.rarityColor(Pickups.R.LEGENDARY):
		var tw := HudTheme.textWidth(t[0].to_upper(), 24)
		Stamp.slam(self, "LEGENDARY", Vector2(size.x * 0.5 + tw * 0.5 + 110.0, 166.0), HudTheme.GOLD, 20, TOAST_SECONDS - 0.7, -0.12)

func showCombo(count: int, coins: int) -> void:
	combo = {"text": "COMBO %d   +%d" % [count, coins], "t": 1.2, "count": count, "pop": COMBO_POP}

#the combo readout pops on every crush and heats from gold through orange to red as the chain grows
const COMBO_POP := 0.16
static func comboColor(count: int) -> Color:
	if count >= 20: return HudTheme.BAD
	if count >= 10: return HudTheme.GOLD.lerp(HudTheme.WARN, 0.5).lerp(HudTheme.BAD, (count - 10) / 10.0)
	return HudTheme.GOLD

#the Goon Nuke: an orange shockwave rings out from the car with a dust kick and a camera rumble (no
#white-out, so it is safe with Reduce Flashing; Reduce Motion drops the rumble and the dust)
const SHOCK_SECONDS := 0.5
var shockAt := Vector2.ZERO

func flash() -> void:
	flashT = SHOCK_SECONDS
	shockAt = size * 0.5
	if is_instance_valid(Root.playerCar): shockAt = Root.playerCar.get_global_transform_with_canvas().origin
	Transition.sound("thud")
	Transition.sound("hiss", -6.0, 0.7)
	if Settings.reduce_motion(): return
	var camera = get_viewport().get_camera_2d()
	if camera: Juice.rumble(camera, "offset", Transition.SHAKE, 0.25)
	var dust = TransitionFx.new()
	add_child(dust)
	for i in 10:
		var dir = Vector2.RIGHT.rotated(i * TAU / 10.0)
		dust.puff(shockAt + dir * 40.0, dir * 520.0, TransitionFx.DUST, 0.9, 20, 110, 0.5, 0.0, 2.6)

## A Scratch Card: three cells revealed one by one, then paid. From a gift box (CrushPrizes) a higher
## `tier` matches more often and pays more: a pair 1 + tier / 2 times, a triple 3 + tier.
func startScratch(tier := 0) -> void:
	if not scratch.is_empty(): payScratch() #a second card settles the first
	var pool := {} #only unlocked prizes (Unlocks); a new save's card still has Nitro and the Magnet
	for id in SCRATCH_POOL:
		if Unlocks.isPickupOpen(id): pool[id] = SCRATCH_POOL[id]
	if pool.is_empty(): pool = {"coin": 1}
	var first := Pickups.pickWeighted(pool, randf())
	var second := first if randf() < 0.45 + 0.07 * tier else Pickups.pickWeighted(pool, randf())
	var third := first if randf() < 0.3 + 0.07 * tier else (second if randf() < 0.2 else Pickups.pickWeighted(pool, randf()))
	scratch = {"cells": [first, second, third], "shown": 0, "t": 0.0, "tier": tier}

func payScratch() -> void:
	var car = Root.playerCar
	var cells: Array = scratch.cells
	var tier: int = scratch.get("tier", 0)
	scratch = {}
	if not is_instance_valid(car): return
	var counts := {}
	for c in cells: counts[c] = counts.get(c, 0) + 1
	for id in counts:
		if counts[id] < 2: continue
		var times: int = 3 + tier if counts[id] == 3 else 1 + tier / 2
		toast("SCRATCH  -  %s x%d" % [Pickups.displayName(id).to_upper(), times], Pickups.rarityColor(Pickups.rarity(id)), Pickups.texture(id))
		for i in times: PickupEffects.collect(car, id, car.global_position)
		return
	toast("SCRATCH  -  NO MATCH", HudTheme.MUTED, Pickups.texture("scratch"))

## Double or Nothing: the coins earned since the last bet, at about even odds. Use rolls.
func startDouble(car) -> void:
	if car.coinsSinceBet < 10:
		toast("DOUBLE OR NOTHING  -  NOTHING TO BET YET", HudTheme.MUTED, Pickups.texture("double"))
		return
	doubleStake = car.coinsSinceBet
	doubleActive = true
	doubleT = Pickups.DATA["double"]["secs"]

func resolveDouble(bet: bool) -> void:
	doubleActive = false
	var car = Root.playerCar
	if not is_instance_valid(car): return
	car.coinsSinceBet = 0
	if not bet:
		toast("WALKED AWAY", HudTheme.MUTED, Pickups.texture("double"))
		return
	var odds: float = Pickups.DATA["double"]["odds"] + minf(car.luck, 50.0) * 0.001
	if randf() < odds:
		car.reward("coin", doubleStake)
		car.coinsSinceBet = 0
		toast("DOUBLED  +%d" % doubleStake, HudTheme.OK, Pickups.texture("double"))
	else:
		car.coin = maxi(0, car.coin - doubleStake)
		toast("LOST %d" % doubleStake, HudTheme.BAD, Pickups.texture("double"))

#--- updates and drawing ------------------------------------------------------------------------

func _process(delta: float) -> void:
	var busy := false
	if not toasts.is_empty():
		busy = true
		toastT += delta
		if toastT >= TOAST_SECONDS:
			toasts.pop_front()
			if not toasts.is_empty(): startToast()
	if not scratch.is_empty():
		busy = true
		scratch.t += delta
		scratch.shown = mini(3, int(scratch.t / SCRATCH_STEP))
		if scratch.t >= SCRATCH_STEP * 4.0: payScratch()
	if doubleActive:
		busy = true
		doubleT -= delta
		if InputMap.has_action("UseItem") && Input.is_action_just_pressed("UseItem") && not Settings.menu_open: resolveDouble(true)
		elif doubleT <= 0.0: resolveDouble(false)
	if not combo.is_empty():
		busy = true
		combo.t -= delta
		combo.pop = maxf(0.0, combo.pop - delta)
		if combo.t <= 0.0: combo = {}
	if flashT > 0.0:
		busy = true
		flashT -= delta
	PickupWorld.beacons = PickupWorld.beacons.filter(func(b): return is_instance_valid(b[0]) && not b[0].is_queued_for_deletion())
	var stationFar := is_instance_valid(Root.station) && is_instance_valid(Root.playerCar) && Root.playerCar.global_position.distance_to(Root.station.global_position) > STATION_FAR
	if busy || not PickupWorld.beacons.is_empty() || stationFar || stationShown: queue_redraw()
	stationShown = stationFar

func _draw() -> void:
	var w := size.x
	if not toasts.is_empty(): drawToast(toasts[0], w)
	if not scratch.is_empty(): drawScratch(Vector2(w - 360.0, 150.0))
	if doubleActive: drawDouble(Vector2(w - 360.0, 150.0 if scratch.is_empty() else 290.0))
	if not combo.is_empty():
		var a := clampf(combo.t / 0.3, 0.0, 1.0)
		var grow: float = 0.0 if Settings.reduce_motion() else combo.pop / COMBO_POP
		var fontSize := int(26.0 + mini(combo.count, 30) * 0.3 + 10.0 * grow * grow)
		HudTheme.text(self, Vector2(34.0, 190.0 + (fontSize - 26) * 0.5), combo.text, fontSize, Color(comboColor(combo.count), a), HORIZONTAL_ALIGNMENT_LEFT, 7, Color(HudTheme.DEEP, a))
	drawBeacons()
	if stationShown: drawStation()
	if flashT > 0.0: drawShockwave(1.0 - flashT / SHOCK_SECONDS)

#the pill drops 12 px with an overshoot as it arrives and its rim flashes white (Reduce Motion: fades only)
func drawToast(t: Array, w: float) -> void:
	var fade := clampf(minf(toastT / 0.15, (TOAST_SECONDS - toastT) / 0.3), 0.0, 1.0)
	var text: String = t[0].to_upper()
	var tw := HudTheme.textWidth(text, 24)
	var drop := 0.0
	var rimFlash := 0.0
	if not Settings.reduce_motion():
		var k := clampf(toastT / 0.22, 0.0, 1.0)
		drop = -12.0 * (1.0 - (1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)))
		if not Settings.get_value("access/reduce_flashing"): rimFlash = snappedf(clampf(1.0 - toastT / 0.36, 0.0, 1.0), 0.1)
	var rect := Rect2(Vector2(w * 0.5 - tw * 0.5 - 50.0, 142.0 + drop), Vector2(tw + 100.0, 46.0))
	var col: Color = t[1]
	HudTheme.panel(self, rect, Color(col, 0.9 * fade), 10)
	if rimFlash > 0.0: HudTheme.panel(self, rect, Color(1, 1, 1, rimFlash), 10)
	if t[2]: HudTheme.icon(self, t[2], rect.position + Vector2(26.0, 23.0), 34.0, Color(1, 1, 1, fade))
	HudTheme.text(self, rect.position + Vector2(52.0, 32.0), text, 24, Color(col, fade), HORIZONTAL_ALIGNMENT_LEFT, 6, Color(HudTheme.OUTLINE, fade))

func drawScratch(at: Vector2) -> void:
	HudTheme.panel(self, Rect2(at, Vector2(320.0, 128.0)), HudTheme.GOLD, 10)
	HudTheme.text(self, at + Vector2(14.0, 26.0), "SCRATCH CARD", 18, HudTheme.GOLD)
	for i in 3:
		var cell := Rect2(at + Vector2(14.0 + i * 100.0, 36.0), Vector2(92.0, 66.0))
		if i < scratch.shown:
			draw_rect(cell, Color(1.0, 0.97, 0.9))
			HudTheme.icon(self, Pickups.texture(scratch.cells[i]), cell.get_center(), 52.0)
			HudTheme.text(self, Vector2(cell.get_center().x, cell.end.y + 15.0), Pickups.shortName(scratch.cells[i]), Pickups.TAG_SIZE, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
		else:
			draw_rect(cell, Color(0.66, 0.68, 0.72))
			HudTheme.text(self, cell.get_center() + Vector2(0, 9), "?", 28, Color(0.4, 0.42, 0.46), HORIZONTAL_ALIGNMENT_CENTER, 0)

func drawDouble(at: Vector2) -> void:
	HudTheme.panel(self, Rect2(at, Vector2(320.0, 96.0)), Pickups.rarityColor(Pickups.R.UNCOMMON), 10)
	HudTheme.icon(self, Pickups.texture("double"), at + Vector2(38.0, 48.0), 50.0)
	HudTheme.text(self, at + Vector2(72.0, 34.0), "BET %d COINS?" % doubleStake, 22, HudTheme.TEXT)
	var keyName := InputGlyphs.label("UseItem")
	HudTheme.text(self, at + Vector2(72.0, 62.0), "%s  ROLL      WAIT  WALK AWAY" % keyName, 15, HudTheme.GOLD)
	HudTheme.bar(self, Rect2(at + Vector2(72.0, 74.0), Vector2(230.0, 8.0)), doubleT / Pickups.DATA["double"]["secs"], HudTheme.GOLD)

func drawBeacons() -> void:
	if PickupWorld.beacons.is_empty() || not is_instance_valid(Root.playerCar): return
	var canvas := get_viewport().get_canvas_transform()
	var screen := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2(EDGE, 165.0), size - Vector2(EDGE * 2.0, 165.0 + 175.0)) #clear of the top panels and the dials
	var centre := inner.get_center()
	for b in PickupWorld.beacons:
		if not b[0].is_inside_tree(): continue #spawns are deferred; it arrives next frame
		var p: Vector2 = canvas * b[0].global_position
		if screen.grow(-10.0).has_point(p): continue
		var dir := (p - centre).normalized()
		var t := INF
		if absf(dir.x) > 0.001: t = minf(t, (inner.size.x * 0.5) / absf(dir.x))
		if absf(dir.y) > 0.001: t = minf(t, (inner.size.y * 0.5) / absf(dir.y))
		var at := centre + dir * t
		var col: Color = b[1]
		draw_circle(at, 30.0, Color(0.055, 0.047, 0.043, 0.85))
		draw_arc(at, 30.0, 0.0, TAU, 32, col, 3.0, true)
		if b[2]: HudTheme.icon(self, b[2], at, 38.0)
		var tip := at + dir * 44.0
		draw_colored_polygon(PackedVector2Array([tip, at + dir * 32.0 + dir.orthogonal() * 10.0, at + dir * 32.0 - dir.orthogonal() * 10.0]), col)
		var metres: float = Root.playerCar.global_position.distance_to(b[0].global_position) / 100.0
		HudTheme.text(self, at + Vector2(0, 48.0), "%dm" % int(metres), 14, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)

func drawShockwave(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 3.0)
	var radius := lerpf(30.0, size.length() * 0.6, e)
	draw_arc(shockAt, radius, 0.0, TAU, 96, Color(HudTheme.RIM, 0.9 * (1.0 - k)), lerpf(26.0, 3.0, k), true)
	draw_arc(shockAt, radius * 0.82, 0.0, TAU, 96, Color(HudTheme.GOLD, 0.5 * (1.0 - k)), lerpf(10.0, 1.0, k), true)

#the station (Sprint, Marathon, Defense): a pill on the screen edge pointing at it, with its distance,
#once it is more than STATION_FAR away. It replaced the car's old 3D-text arrow.
const STATION_FAR := 4000.0
var stationShown := false

func drawStation() -> void:
	if not is_instance_valid(Root.station) || not is_instance_valid(Root.playerCar): return
	var canvas := get_viewport().get_canvas_transform()
	var inner := Rect2(Vector2(EDGE + 40.0, 175.0), size - Vector2((EDGE + 40.0) * 2.0, 175.0 + 185.0))
	var centre := inner.get_center()
	var dir: Vector2 = ((canvas * Root.station.global_position) - centre).normalized()
	var t := INF
	if absf(dir.x) > 0.001: t = minf(t, (inner.size.x * 0.5) / absf(dir.x))
	if absf(dir.y) > 0.001: t = minf(t, (inner.size.y * 0.5) / absf(dir.y))
	var at := centre + dir * t
	var miles: float = Root.playerCar.global_position.distance_to(Root.station.global_position) / 10000.0
	if Settings.distance_unit() == "km": miles *= 1.609
	var rect := Rect2(at - Vector2(70.0, 24.0), Vector2(140.0, 48.0))
	var tip := at + dir * 46.0
	draw_colored_polygon(PackedVector2Array([tip, at + dir * 26.0 + dir.orthogonal() * 16.0, at + dir * 26.0 - dir.orthogonal() * 16.0]), HudTheme.GOLD)
	HudTheme.panel(self, rect, Color(HudTheme.GOLD, 0.9), 24)
	HudTheme.text(self, rect.position + Vector2(70.0, 18.0), "STATION", 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, HudTheme.BODY)
	HudTheme.text(self, rect.position + Vector2(70.0, 40.0), "%d %s" % [int(miles) + 1, Settings.distance_unit()], 20, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
