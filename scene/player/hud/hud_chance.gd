class_name HudChance extends Control

#The HUD's moments (docs/HUD.md): rare-pickup toasts under the clock, the Scratch Card and Double or
#Nothing in the top-right corner under the payout, the Crush Combo under the crush pill, arrows at the
#screen edge for events and supply drops (PickupWorld.beacons), the station pointer, and the Goon Nuke's flash. It covers
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
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ui := GameUI.of(self)
	if ui != null && ui.guest: return #the second player's (Coop): pointers and warnings only; the moments are the player's
	current = self
	Audio.voice.spoke.connect(onSpoke)

func _exit_tree() -> void:
	if current == self: current = null

#a spoken line's subtitle (VoiceDirector), shown above the dashboard for as long as the line lasts
const SUBTITLE_MIN := 1.5     #s: a short line stays up long enough to read
const SUBTITLE_RISE := 190.0  #px above the screen's bottom edge
var subtitle := ""
var subtitleT := 0.0

func onSpoke(_kind: StringName, text: String, seconds: float) -> void:
	subtitle = text if Settings.get_value("access/subtitles") else ""
	subtitleT = maxf(seconds, SUBTITLE_MIN)
	queue_redraw()

func drawSubtitle() -> void:
	var tw := HudTheme.textWidth(subtitle, 22, HudTheme.BODY)
	var rect := Rect2(Vector2(size.x * 0.5 - tw * 0.5 - 18.0, size.y - SUBTITLE_RISE), Vector2(tw + 36.0, 38.0))
	draw_rect(rect, HudTheme.PANEL)
	HudTheme.text(self, rect.position + Vector2(18.0, 27.0), subtitle, 22, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 0, HudTheme.OUTLINE, HudTheme.BODY)

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

## `sources`: the chain's distinct kill sources (PickupEffects.CHAIN_NAMES). Mixed, it reads as a Critter Chain
## in gold: "CRITTER CHAIN x9: LOGS + BEES + SPLASH".
func showCombo(count: int, coins: int, sources: Array = []) -> void:
	combo = {"text": comboText(count, coins, sources), "t": 1.2, "count": count, "pop": COMBO_POP, "mixed": sources.size() > 1}

const CHAIN_SHOWN := 4 #source names shown at most; the rest are "+n"
static func comboText(count: int, coins: int, sources: Array) -> String:
	var pay := "   +%d" % coins if coins > 0 else ""
	if sources.size() < 2: return "COMBO %d%s" % [count, pay]
	var names := " + ".join(PackedStringArray(sources.slice(0, CHAIN_SHOWN)))
	if sources.size() > CHAIN_SHOWN: names += " +%d" % (sources.size() - CHAIN_SHOWN)
	return "CRITTER CHAIN x%d: %s%s" % [count, names, pay]

#the combo readout pops on every crush and heats from gold through orange to red as the chain grows (a
#Critter Chain stays gold)
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
	if is_instance_valid(GameUI.carOf(self)): shockAt = GameUI.carOf(self).get_global_transform_with_canvas().origin
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
	var car = GameUI.carOf(self)
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
	var car = GameUI.carOf(self)
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
	if subtitle != "":
		subtitleT -= delta
		if subtitleT <= 0.0:
			subtitle = ""
			busy = true #one more redraw clears it
	var car = GameUI.carOf(self)
	var deep: bool = is_instance_valid(car) && car.deepTicks > 0 && not car.isDestroyed
	if deep && deepShown == 0.0: deepLabel = deepWaterLabel()
	deepShown = move_toward(deepShown, 1.0 if deep else 0.0, DEEP_FADE * delta)
	if deepShown > 0.0: busy = true
	elif deepDrawn: busy = true #one more redraw clears it
	PickupWorld.beacons = PickupWorld.beacons.filter(func(b): return is_instance_valid(b[0]) && not b[0].is_queued_for_deletion())
	var stationOn: bool = is_instance_valid(Root.station) && is_instance_valid(GameUI.carOf(self)) && Root.station.active
	var hunting: bool = is_instance_valid(Root.levelRoot) && (Root.levelRoot.get("bounty") != null || Root.levelRoot.get("course") != null || Root.levelRoot.get("rivals") != null) #Bounty Hunt points at its mark, a course at its next gate
	if busy || not PickupWorld.beacons.is_empty() || stationOn || stationShown || hunting || markShown || Coop.guest != null: queue_redraw()
	stationShown = stationOn
	markShown = hunting

func _draw() -> void:
	var w := size.x
	if not toasts.is_empty(): drawToast(toasts[0], w)
	if not scratch.is_empty(): drawScratch(Vector2(w - 360.0, 104.0))
	if doubleActive: drawDouble(Vector2(w - 360.0, 150.0 if scratch.is_empty() else 290.0))
	if not combo.is_empty():
		var a := clampf(combo.t / 0.3, 0.0, 1.0)
		var grow: float = 0.0 if Settings.reduce_motion() else combo.pop / COMBO_POP
		var fontSize := int(26.0 + mini(combo.count, 30) * 0.3 + 10.0 * grow * grow)
		var col: Color = HudTheme.GOLD if combo.get("mixed", false) else comboColor(combo.count)
		if combo.get("mixed", false): fontSize = int(24.0 + 8.0 * grow * grow) #a long line: it doesn't grow with the count
		HudTheme.text(self, Vector2(34.0, 190.0 + (fontSize - 26) * 0.5), combo.text, fontSize, Color(col, a), HORIZONTAL_ALIGNMENT_LEFT, 7, Color(HudTheme.DEEP, a))
	drawBeacons()
	if stationShown: drawStation()
	drawMark()
	drawGate()
	drawQuarry()
	drawPartner()
	if flashT > 0.0: drawShockwave(1.0 - flashT / SHOCK_SECONDS)
	if subtitle != "": drawSubtitle()
	deepDrawn = deepShown > 0.0
	if deepDrawn: drawDeepWater(deepShown)

#Deep water (docs/HUD.md): while the car's center is over it (car.deepTicks), a red edge round the screen
#and "DEEP WATER" under the toasts, pulsing (Reduce Flashing: steady), fading in and out over 1 / DEEP_FADE s.
#Lava landscapes say "LAVA". Silent: CarJuice's splash and hiss are the cue going in.
const DEEP_FADE := 4.0
const DEEP_EDGE := 0.1   #the red edge's depth, as a share of the screen's height
var deepShown := 0.0
var deepDrawn := false
var deepLabel := "DEEP WATER"

static func deepWaterLabel() -> String:
	var def := Levels.current()
	var land: Landscape = Landscapes.get_def(def.landscape) if def else null
	return "LAVA" if land != null && land.waterLook == &"lava" else "DEEP WATER"

func drawDeepWater(k: float) -> void:
	var pulse := 1.0 if Settings.get_value("access/reduce_flashing") else 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.009)
	var red := Color(HudTheme.BAD, 0.5 * k * pulse)
	var clear := Color(HudTheme.BAD, 0.0)
	var d := size.y * DEEP_EDGE
	var w := size.x
	var h := size.y
	var colors := PackedColorArray([red, red, clear, clear])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - d, d), Vector2(d, d)]), colors)
	draw_polygon(PackedVector2Array([Vector2(w, h), Vector2(0, h), Vector2(d, h - d), Vector2(w - d, h - d)]), colors)
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, 0), Vector2(d, d), Vector2(d, h - d)]), colors)
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - d, h - d), Vector2(w - d, d)]), colors)
	var grow := 0.0 if Settings.reduce_motion() else 2.0 * (pulse - 0.7) / 0.3
	HudTheme.text(self, Vector2(w * 0.5, 300.0), deepLabel, int(30.0 + grow), Color(HudTheme.BAD.lerp(Color.WHITE, 0.2), k), HORIZONTAL_ALIGNMENT_CENTER, 7, Color(HudTheme.OUTLINE, k))

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
	if PickupWorld.beacons.is_empty() || not is_instance_valid(GameUI.carOf(self)): return
	var canvas := GameUI.canvasOf(self)
	var screen := Rect2(Vector2.ZERO, size)
	var inner := Rect2(Vector2(EDGE, 165.0), size - Vector2(EDGE * 2.0, 165.0 + 175.0)) #clear of the mirror, the visors and the dials
	var center := inner.get_center()
	for b in PickupWorld.beacons:
		if not is_instance_valid(b[0]) || not b[0].is_inside_tree(): continue #freed since the last prune; spawns are deferred (it arrives next frame)
		var p: Vector2 = canvas * b[0].global_position
		if screen.grow(-10.0).has_point(p): continue
		var dir := (p - center).normalized()
		var t := INF
		if absf(dir.x) > 0.001: t = minf(t, (inner.size.x * 0.5) / absf(dir.x))
		if absf(dir.y) > 0.001: t = minf(t, (inner.size.y * 0.5) / absf(dir.y))
		var at := center + dir * t
		var col: Color = b[1]
		draw_circle(at, 30.0, Color(0.055, 0.047, 0.043, 0.85))
		draw_arc(at, 30.0, 0.0, TAU, 32, col, 3.0, true)
		if b[2]: HudTheme.icon(self, b[2], at, 38.0)
		var tip := at + dir * 44.0
		draw_colored_polygon(PackedVector2Array([tip, at + dir * 32.0 + dir.orthogonal() * 10.0, at + dir * 32.0 - dir.orthogonal() * 10.0]), col)
		var meters: float = GameUI.carOf(self).global_position.distance_to(b[0].global_position) / 100.0
		HudTheme.text(self, at + Vector2(0, 48.0), "%dm" % int(meters), 14, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)

func drawShockwave(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 3.0)
	var radius := lerpf(30.0, size.length() * 0.6, e)
	draw_arc(shockAt, radius, 0.0, TAU, 96, Color(HudTheme.RIM, 0.9 * (1.0 - k)), lerpf(26.0, 3.0, k), true)
	draw_arc(shockAt, radius * 0.82, 0.0, TAU, 96, Color(HudTheme.GOLD, 0.5 * (1.0 - k)), lerpf(10.0, 1.0, k), true)

#The station (Sprint, Marathon, Defense), in its own blue (HudTheme.STATION) with the mode's icon. Off screen:
#a pill on the screen edge pointing at it, with the distance. On screen: a tag over the driveway, which fades
#as the car arrives. With HURRY_SECONDS left on a race clock the pill pulses; in Defense the pointer turns
#red and shakes for a moment when a goon blows up at a pump (HudTheme.stationHit).
const HURRY_SECONDS := 15.0
const STATION_PILL := Vector2(200.0, 56.0)
var stationShown := false
var markShown := false

func drawStation() -> void:
	if not is_instance_valid(Root.station) || not is_instance_valid(GameUI.carOf(self)): return
	var mode: int = SaveManager.playerData.gameMode
	var defense := mode == Root.gameModes.DEFENSE
	var hit := HudTheme.stationHit()
	var col: Color = HudTheme.STATION.lerp(HudTheme.BAD, hit)
	var label := "BASE" if defense else "STATION"
	var icon: Texture2D = HudTheme.MODE_ICONS.get(mode)
	var calm := Settings.reduce_motion()
	var shake := Vector2.ZERO
	if hit > 0.0 && not calm: shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 6.0 * hit
	#a race's last seconds: the rim pulses (and the pill swells, unless Reduce Motion)
	var pulse := 0.0
	var level = Root.levelRoot
	if not defense && is_instance_valid(level) && level.seconds > 0.0 && level.seconds <= HURRY_SECONDS:
		pulse = 1.0 if Settings.get_value("access/reduce_flashing") else 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	#a course's next checkpoint comes before its finish
	var gate: Vector2 = level.course.target() if is_instance_valid(level) && level.get("course") != null else Vector2.INF
	if gate != Vector2.INF: drawPointer(gate, "CHECKPOINT", col, icon, pulse, shake, hit)
	else: drawPointer(Root.station.drivewayPoint(), "FINISH" if is_instance_valid(level) && level.get("course") != null else label, col, icon, pulse, shake, hit)

#Two players (Coop): the pointer at the other car once it is off this half of the screen. It turns red and
#pulses as the leash runs out (CoopRun.LEASH), before the tow.
const LEASH_WARN := 0.75
func drawPartner() -> void:
	var mine = GameUI.carOf(self)
	var other = Root.playerCar if mine == Coop.guest else Coop.guest
	if Coop.guest == null || not is_instance_valid(mine) || not is_instance_valid(other) || other.isDestroyed: return
	if Rect2(Vector2.ZERO, size).grow(-40.0).has_point(GameUI.canvasOf(self) * other.global_position): return
	var tight := CoopRun.leashShare(other.global_position - mine.global_position) >= LEASH_WARN
	var pulse := 0.0
	if tight: pulse = 1.0 if Settings.get_value("access/reduce_flashing") else 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	drawPointer(other.global_position, "TOO FAR" if tight else ("PLAYER 1" if other == Root.playerCar else CoopRun.NAME), HudTheme.BAD if tight else HudTheme.TEXT, null, pulse, Vector2.ZERO, 0.0)

#Bounty Hunt: the same pointer at the mark, in red
func drawMark() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.get("bounty") == null || not is_instance_valid(GameUI.carOf(self)): return
	var at: Vector2 = level.bounty.markPosition()
	if at != Vector2.INF: drawPointer(at, "MARK", HudTheme.BAD, HudTheme.MODE_ICONS.get(Root.gameModes.BOUNTY), 0.0, Vector2.ZERO, 0.0)

#Pursuit: at the runner, in red, over the station's own pointer. Keep the Cup: at the cup, in gold.
func drawQuarry() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || not is_instance_valid(GameUI.carOf(self)): return
	if level.get("cup") != null && not level.cup.playerHolds():
		drawPointer(level.cup.cupPosition(), "CUP", HudTheme.GOLD, HudTheme.MODE_ICONS.get(Root.gameModes.KEEPCUP), 0.0, Vector2.ZERO, 0.0)
	elif level.runMode == Root.gameModes.PURSUIT && level.get("rivals") != null && level.rivals.runner() != null:
		drawPointer(level.rivals.runner().global_position, "RUNNER", HudTheme.BAD, HudTheme.MODE_ICONS.get(Root.gameModes.PURSUIT), 0.0, Vector2.ZERO, 0.0)

#a course with no station (Cone Course): the pointer at its next gate, when that is off screen
func drawGate() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level) || level.get("course") == null || is_instance_valid(Root.station) || not is_instance_valid(GameUI.carOf(self)): return
	var at: Vector2 = level.course.target()
	if at != Vector2.INF && not Rect2(Vector2.ZERO, size).grow(-40.0).has_point(GameUI.canvasOf(self) * at):
		drawPointer(at, level.course.gateWord, HudTheme.STATION, HudTheme.MODE_ICONS.get(level.runMode), 0.0, Vector2.ZERO, 0.0)

#a world point as the HUD shows it: on screen a tag over it that fades as the car arrives (`hit` keeps it lit);
#off screen a pill on the screen edge with an arrow, the label and the distance
func drawPointer(point: Vector2, label: String, col: Color, icon: Texture2D, pulse: float, shake: Vector2, hit: float) -> void:
	var calm := Settings.reduce_motion()
	var target: Vector2 = GameUI.canvasOf(self) * point
	if Rect2(Vector2.ZERO, size).grow(-40.0).has_point(target):
		var fade := clampf((GameUI.carOf(self).global_position.distance_to(point) - 400.0) / 600.0, 0.0, 1.0)
		if fade > 0.0 || hit > 0.0: drawStationTag(target + shake, label, Color(col, maxf(fade, hit)), icon)
		return
	var inner := Rect2(Vector2(EDGE + 60.0, 190.0), size - Vector2((EDGE + 60.0) * 2.0, 190.0 + 300.0)) #clear of the mirror, the visors and the dials
	var center := inner.get_center()
	var dir: Vector2 = (target - center).normalized()
	var t := INF
	if absf(dir.x) > 0.001: t = minf(t, (inner.size.x * 0.5) / absf(dir.x))
	if absf(dir.y) > 0.001: t = minf(t, (inner.size.y * 0.5) / absf(dir.y))
	var at := center + dir * t + shake
	var rect := Rect2(at - STATION_PILL * 0.5, STATION_PILL)
	if not calm: rect = rect.grow(4.0 * pulse)
	#the arrow starts where `dir` leaves the pill
	var half := rect.size * 0.5
	var edge := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	draw_colored_polygon(PackedVector2Array([at + dir * (edge + 24.0), at + dir * (edge - 4.0) + dir.orthogonal() * 16.0, at + dir * (edge - 4.0) - dir.orthogonal() * 16.0]), col)
	HudTheme.panel(self, rect, col.lerp(Color.WHITE, pulse * 0.8), 26)
	if icon: HudTheme.icon(self, icon, rect.position + Vector2(32.0, rect.size.y * 0.5), 36.0)
	HudTheme.text(self, rect.position + Vector2(60.0, 23.0), label, 16, HudTheme.TEXT)
	HudTheme.text(self, rect.position + Vector2(60.0, 46.0), HudTheme.distanceFrom(GameUI.carOf(self), point), 20, col, HORIZONTAL_ALIGNMENT_LEFT, 5)

#on screen: a small pill over the driveway with a notch pointing down at it
func drawStationTag(at: Vector2, label: String, col: Color, icon: Texture2D) -> void:
	col.a = snappedf(col.a, 0.1) #HudTheme.panel caches a box per color
	var w := HudTheme.textWidth(label, 16) + 58.0
	var rect := Rect2(at + Vector2(-w * 0.5, -96.0), Vector2(w, 38.0))
	var notch := at + Vector2(0.0, -40.0)
	draw_colored_polygon(PackedVector2Array([notch, notch + Vector2(-12.0, -18.0), notch + Vector2(12.0, -18.0)]), col)
	HudTheme.panel(self, rect, col, 19, Color(HudTheme.PANEL, HudTheme.PANEL.a * col.a))
	if icon: HudTheme.icon(self, icon, rect.position + Vector2(22.0, 19.0), 26.0, Color(1, 1, 1, col.a))
	HudTheme.text(self, rect.position + Vector2(42.0, 26.0), label, 16, Color(HudTheme.TEXT, col.a), HORIZONTAL_ALIGNMENT_LEFT, 5, Color(HudTheme.OUTLINE, col.a))
