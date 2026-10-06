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
var combo := {}               #{text, t}
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
	if toasts.size() == 1: toastT = 0.0

func showCombo(count: int, coins: int) -> void:
	combo = {"text": "COMBO %d   +%d" % [count, coins], "t": 1.2}

func flash() -> void:
	flashT = 0.6

## A Scratch Card: three cells revealed one by one, then paid.
func startScratch() -> void:
	if not scratch.is_empty(): payScratch() #a second card settles the first
	var first := Pickups.pickWeighted(SCRATCH_POOL, randf())
	var second := first if randf() < 0.45 else Pickups.pickWeighted(SCRATCH_POOL, randf())
	var third := first if randf() < 0.3 else (second if randf() < 0.2 else Pickups.pickWeighted(SCRATCH_POOL, randf()))
	scratch = {"cells": [first, second, third], "shown": 0, "t": 0.0}

func payScratch() -> void:
	var car = Root.playerCar
	var cells: Array = scratch.cells
	scratch = {}
	if not is_instance_valid(car): return
	var counts := {}
	for c in cells: counts[c] = counts.get(c, 0) + 1
	for id in counts:
		if counts[id] < 2: continue
		var times := 3 if counts[id] == 3 else 1
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
			toastT = 0.0
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
		if combo.t <= 0.0: combo = {}
	if flashT > 0.0:
		busy = true
		flashT -= delta
	PickupWorld.beacons = PickupWorld.beacons.filter(func(b): return is_instance_valid(b[0]) && not b[0].is_queued_for_deletion())
	if busy || not PickupWorld.beacons.is_empty(): queue_redraw()

func _draw() -> void:
	var w := size.x
	if not toasts.is_empty(): drawToast(toasts[0], w)
	if not scratch.is_empty(): drawScratch(Vector2(w - 360.0, 150.0))
	if doubleActive: drawDouble(Vector2(w - 360.0, 150.0 if scratch.is_empty() else 275.0))
	if not combo.is_empty():
		var a := clampf(combo.t / 0.3, 0.0, 1.0)
		HudTheme.text(self, Vector2(34.0, 190.0), combo.text, 26, Color(HudTheme.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, 7, Color(HudTheme.DEEP, a))
	drawBeacons()
	if flashT > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flashT / 0.6 * 0.85))

func drawToast(t: Array, w: float) -> void:
	var fade := clampf(minf(toastT / 0.15, (TOAST_SECONDS - toastT) / 0.3), 0.0, 1.0)
	var text: String = t[0].to_upper()
	var tw := HudTheme.textWidth(text, 24)
	var rect := Rect2(Vector2(w * 0.5 - tw * 0.5 - 50.0, 142.0), Vector2(tw + 100.0, 46.0))
	var col: Color = t[1]
	HudTheme.panel(self, rect, Color(col, 0.9 * fade), 10)
	if t[2]: HudTheme.icon(self, t[2], rect.position + Vector2(26.0, 23.0), 34.0, Color(1, 1, 1, fade))
	HudTheme.text(self, rect.position + Vector2(52.0, 32.0), text, 24, Color(col, fade), HORIZONTAL_ALIGNMENT_LEFT, 6, Color(HudTheme.OUTLINE, fade))

func drawScratch(at: Vector2) -> void:
	HudTheme.panel(self, Rect2(at, Vector2(320.0, 112.0)), HudTheme.GOLD, 10)
	HudTheme.text(self, at + Vector2(14.0, 26.0), "SCRATCH CARD", 18, HudTheme.GOLD)
	for i in 3:
		var cell := Rect2(at + Vector2(14.0 + i * 100.0, 36.0), Vector2(92.0, 66.0))
		if i < scratch.shown:
			draw_rect(cell, Color(1.0, 0.97, 0.9))
			HudTheme.icon(self, Pickups.texture(scratch.cells[i]), cell.get_center(), 52.0)
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
