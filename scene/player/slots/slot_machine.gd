class_name SlotMachine extends PickupMenu

#The slot machine (docs/PICKUPS.md, "The slot machine"): three reels of pickups (SlotSymbols) spin at a
#speed you can read, and each press of the action key (E) stops the next one on the symbol coming up, so a
#good eye can time it. Before the first stop A / D set the bet (run coins that tilt the reels toward rarer
#prizes). Once all three stand, nudges (one, plus one per gift box tier) roll a reel on by one symbol: A / D
#pick the reel, W nudges it, and the line under the reels says what the pay line pays as it stands. The
#action key collects: a pair pays its symbol twice, a triple five times, stars are
#Star Fragments and three are the jackpot. What the pay line shows is exactly what pays.

const STRIP := 24          #symbols on a reel
const ROW := 90.0          #px per symbol on the reel
const REEL_W := 150.0
const REEL_GAP := 18.0
const REEL_TOP := 40.0
const SPIN_SPEED := 7.0    #symbols per second
const START_GAP := 0.12    #between the reels starting

var tier := 0
var fromBox := false
var strips: Array = []     #per reel: an Array of symbol ids
var pos: Array = [0.0, 0.0, 0.0]       #per reel, in symbols; the pay line shows strip[round(pos)]
var target: Array = [-1, -1, -1]       #per reel: the symbol index it is stopping on, -1 while spinning
var stopped: Array = [false, false, false]
var landed: Array = [0.0, 0.0, 0.0]    #seconds since the reel landed, for its settle
var spinT := 0.0
var nextStop := 0
var phase := "spin"        #spin, stopped
var nudges := 1
var cursor := 1
var betPaid := false

static func open(boxTier := 0, isGiftBox := false) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var machine := SlotMachine.new()
	machine.tier = boxTier
	machine.fromBox = isGiftBox
	Root.levelRoot.add_child.call_deferred(machine)

func build() -> void:
	SlotSymbols.bet = 0
	SlotSymbols.bonus = tier
	nudges = 1 + tier
	if is_instance_valid(Root.playerCar): Root.playerCar.slotMachines += 1
	var heading := "SLOT MACHINE"
	if fromBox: heading = "FREE SPIN" if tier <= 0 else "%s SPIN" % CrushPrizes.tierName(tier).to_upper()
	title(heading, "Stop each reel. Pairs pay twice, triples five times.")
	for r in 3:
		var strip := []
		for i in STRIP: strip.push_back(SlotSymbols.pick())
		strips.push_back(strip)
		pos[r] = randf() * STRIP
	updateHints()
	updateInfo()

## The symbol on the pay line of reel `r` (once stopped, exactly what pays)
func lineSymbol(r: int) -> String:
	var i: int = target[r] if target[r] >= 0 else int(round(pos[r]))
	return strips[r][posmod(i, STRIP)]

func line() -> Array:
	return [lineSymbol(0), lineSymbol(1), lineSymbol(2)]

func updateHints() -> void:
	if phase == "spin":
		var list := [[[ACT], "Stop reel %d" % (nextStop + 1)]]
		if not betPaid: list.push_back([["TurnLeft", "TurnRight"], "Bet"])
		hints(list)
		return
	var list := [[[ACT], "Collect"]]
	if nudges > 0: list.push_back([["TurnLeft", "TurnRight"], "Reel"])
	if nudges > 0: list.push_back([["Accelerate"], "Nudge (%d)" % nudges])
	hints(list)

func updateInfo() -> void:
	if phase == "spin": say("Bet %d run coins   -   Run coins %d" % [SlotSymbols.BETS[SlotSymbols.bet], runCoins()])
	else: say("Nudges left %d" % nudges)

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept":
			if phase == "spin": stopNext()
			else: collect()
		"TurnLeft", "TurnRight":
			var step := -1 if action == "TurnLeft" else 1
			if phase == "spin": changeBet(step)
			elif nudges > 0: cursor = wrapi(cursor + step, 0, 3)
		"Accelerate":
			if phase == "stopped": nudge(cursor)

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event): return
	var r := reelAt(event.position)
	if phase == "stopped" && r >= 0 && nudges > 0:
		cursor = r
		nudge(r)
	elif phase == "spin": stopNext()
	else: collect()

func reelAt(p: Vector2) -> int:
	for r in 3:
		if reelRect(r).has_point(p): return r
	return -1

func reelRect(r: int) -> Rect2:
	var x0 := (STAGE.x - (3.0 * REEL_W + 2.0 * REEL_GAP)) * 0.5
	return Rect2(x0 + r * (REEL_W + REEL_GAP), REEL_TOP, REEL_W, ROW * 3.0)

#Bet: run coins that tilt the reels toward rarer prizes (SlotSymbols.weights), set before the first stop
#and paid when it comes. The symbols out of sight are rolled again at the new odds.
func changeBet(step: int) -> void:
	if betPaid: return
	var level := wrapi(SlotSymbols.bet + step, 0, SlotSymbols.BETS.size())
	while level > 0 && runCoins() < SlotSymbols.BETS[level]: level -= 1
	if level == SlotSymbols.bet: return
	SlotSymbols.bet = level
	for r in 3:
		for i in STRIP:
			if absf(wrapf(i - pos[r], -STRIP * 0.5, STRIP * 0.5)) > 2.0: strips[r][i] = SlotSymbols.pick()
	MenuTheme.click()
	updateInfo()

func stopNext() -> void:
	if nextStop >= 3 || spinT < START_GAP * 3.0: return
	if not betPaid:
		betPaid = true
		if is_instance_valid(Root.playerCar): Root.playerCar.coin -= SlotSymbols.BETS[SlotSymbols.bet]
	var r := nextStop
	target[r] = int(ceil(pos[r])) + 1 #the symbol coming up next
	#Dice: a luck / 500 chance that the last reel lands on the middle reel's symbol
	if r == 2 && is_instance_valid(Root.playerCar) && randf() < Root.playerCar.luck / 500.0:
		strips[2][posmod(target[2], STRIP)] = strips[1][posmod(target[1], STRIP)]
	nextStop += 1
	updateHints()

func tick(delta: float) -> void:
	spinT += delta
	for r in 3:
		if stopped[r]:
			landed[r] += delta
			continue
		if spinT < r * START_GAP: continue
		if target[r] < 0:
			pos[r] += SPIN_SPEED * delta
			continue
		var left: float = target[r] - pos[r]
		pos[r] += minf(left, maxf(SPIN_SPEED * minf(1.0, left * 1.6), 2.5) * delta)
		if target[r] - pos[r] < 0.002:
			pos[r] = float(target[r])
			stopped[r] = true
			landed[r] = 0.0
			Transition.sound("clank", -10.0, randf_range(0.9, 1.1))
			if stopped.count(true) == 3: allStopped()

func allStopped() -> void:
	phase = "stopped"
	SlotSymbols.bet = 0 #the bet bought these reels; nudges and a second spin keep their odds
	if Transition.instant(): #harnesses tap straight through
		nudges = 0
	updateHints()
	updateInfo()

func nudge(r: int) -> void:
	if nudges <= 0 || phase != "stopped": return
	nudges -= 1
	target[r] += 1
	stopped[r] = false
	phase = "spin"
	nextStop = 3
	Transition.sound("clank", -14.0, 1.4)
	updateHints()

#Paylines (SlotSymbols.payouts): a pair pays its symbol twice, a triple five times; one or two stars are
#Star Fragments, three are the jackpot (+1 star and a purse rain). Credited now; the board shows it.
func collect() -> void:
	if phase != "stopped" || boardUp: return
	var reels := line()
	var pays := SlotSymbols.payouts(reels)
	SlotSymbols.bet = 0
	SlotSymbols.bonus = 0
	var car = Root.playerCar
	var heading := "NO MATCH"
	var stars: int = pays.get(SlotSymbols.STAR, 0)
	pays.erase(SlotSymbols.STAR)
	if is_instance_valid(car):
		if stars == 3:
			car.star += 1
			for i in 5: PickupEffects.dropAndCollect(car, "purse", car.global_position)
			note("star", HudTheme.STAR_ICON, "Jackpot", "+1 star and a purse rain", HudTheme.GOLD)
		elif stars > 0:
			for i in stars: PickupEffects.addStarFragment(car)
			note("star", HudTheme.STAR_ICON, "Star Fragment", "+%d toward your next star" % stars, HudTheme.GOLD, stars)
	awardAll(pays)
	for id in pays:
		if reels.count(id) == 3: heading = "TRIPLE!"
		elif reels.count(id) == 2 && heading != "TRIPLE!": heading = "PAIR!"
	if stars == 3: heading = "JACKPOT!"
	elif heading == "NO MATCH" && not winnings.is_empty(): heading = "YOU WON"
	showWinnings(heading)

## What the pay line would pay as it stands, for the readout under the reels
func payText() -> String:
	if stopped.count(true) < 3: return ""
	var reels := line()
	var parts := []
	var pays := SlotSymbols.payouts(reels)
	for id in pays:
		if id == SlotSymbols.STAR: parts.push_back("JACKPOT" if pays[id] == 3 else "%d STAR FRAGMENT%s" % [pays[id], "S" if pays[id] > 1 else ""])
		elif pays[id] > 1 || reels.count(id) > 1: parts.push_back("%s x%d" % [Pickups.shortName(id).to_upper(), pays[id]])
		else: parts.push_back(Pickups.shortName(id).to_upper())
	return "PAYS:  " + ",  ".join(parts)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.06, 0.045, 0.04))
	for r in 3: drawReel(m, r)
	#the bet and the nudges, along the top
	HudTheme.text(m, Vector2(18, 26), "BET %d" % SlotSymbols.BETS[SlotSymbols.bet] if not betPaid else "", 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 4)
	var pips := ""
	for i in nudges: pips += "● "
	HudTheme.text(m, Vector2(STAGE.x - 18, 26), ("NUDGES  " + pips) if nudges > 0 else "", 15, HudTheme.SKY, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	#the pay line
	var y := REEL_TOP + ROW * 1.5
	var x0 := reelRect(0).position.x - 14.0
	var x1 := reelRect(2).end.x + 14.0
	for side in [-1.0, 1.0]: m.draw_line(Vector2(x0, y + side * ROW * 0.5), Vector2(x1, y + side * ROW * 0.5), Color(HudTheme.GOLD, 0.7), 2.0)
	m.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 12, y - 10), Vector2(x0, y), Vector2(x0 - 12, y + 10)]), HudTheme.GOLD)
	m.draw_colored_polygon(PackedVector2Array([Vector2(x1 + 12, y - 10), Vector2(x1, y), Vector2(x1 + 12, y + 10)]), HudTheme.GOLD)
	var pay := payText()
	HudTheme.text(m, Vector2(STAGE.x * 0.5, REEL_TOP + ROW * 3.0 + 38.0), pay if pay != "" else "", 20, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 6)
	HudTheme.text(m, Vector2(STAGE.x * 0.5, STAGE.y - 16.0), "PAIR x2   -   TRIPLE x5   -   STAR: FRAGMENT   -   3 STARS: JACKPOT", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3, HudTheme.OUTLINE, HudTheme.BODY)

func drawReel(m: Control, r: int) -> void:
	var rect := reelRect(r)
	var lit := phase == "stopped" && nudges > 0 && r == cursor
	m.draw_rect(rect, Color(0.95, 0.92, 0.86))
	var bounce := 0.0
	if stopped[r] && not Settings.reduce_motion(): bounce = sin(minf(landed[r], 0.25) / 0.25 * PI) * 7.0 * (1.0 - minf(landed[r] / 0.25, 1.0))
	var p: float = pos[r]
	var first := int(floor(p)) - 2
	for k in 5:
		var i := first + k
		var cy: float = rect.position.y + ROW * 1.5 - (i - p) * ROW + bounce #higher symbols sit above and come down
		if cy < rect.position.y - ROW || cy > rect.end.y + ROW: continue
		var id: String = strips[r][posmod(i, STRIP)]
		var blur: bool = not stopped[r] && target[r] < 0
		var tint := Color(1, 1, 1, 0.55 if blur else 1.0)
		HudTheme.icon(m, SlotSymbols.texture(id), Vector2(rect.get_center().x, cy - 8.0), 58.0, tint)
		if not blur:
			var tag := "STAR" if id == SlotSymbols.STAR else Pickups.shortName(id)
			HudTheme.text(m, Vector2(rect.get_center().x, cy + 36.0), tag, Pickups.TAG_SIZE, Color(0.1, 0.07, 0.05), HORIZONTAL_ALIGNMENT_CENTER, 0, HudTheme.OUTLINE, HudTheme.BODY)
	#shade the rows off the pay line
	m.draw_rect(Rect2(rect.position, Vector2(rect.size.x, ROW)), Color(0, 0, 0, 0.35))
	m.draw_rect(Rect2(rect.position + Vector2(0, ROW * 2.0), Vector2(rect.size.x, ROW)), Color(0, 0, 0, 0.35))
	#cover what scrolls past the window
	m.draw_rect(Rect2(rect.position.x, 0, rect.size.x, rect.position.y), Color(0.06, 0.045, 0.04))
	m.draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, ROW), Color(0.06, 0.045, 0.04))
	m.draw_rect(rect, HudTheme.SKY if lit else HudTheme.GOLD, false, 4.0 if lit else 3.0)
	if lit: HudTheme.text(m, Vector2(rect.get_center().x, rect.end.y + 2.0 + 12.0), "▲", 14, HudTheme.SKY, HORIZONTAL_ALIGNMENT_CENTER, 3)
