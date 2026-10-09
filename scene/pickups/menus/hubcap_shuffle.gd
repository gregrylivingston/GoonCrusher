class_name HubcapShuffle extends PickupMenu

#Hubcap Shuffle (docs/PICKUPS.md, "Prize games"): a prize goes under one of three hubcaps and they shuffle.
#Follow it, then A / D pick a hubcap and the action key (E) lifts it. Found it: keep it (E), or go again
#(REJECT, Q) for the next prize up, with more and faster swaps. Missed: you leave with a coin. Now and then
#a swap is a feint: two caps start to cross and go back. Better boxes swap fewer times, slower, and start a
#rarity higher.

const SLOTS := [Vector2(160, 250), Vector2(320, 250), Vector2(480, 250)]
const CAP := Vector2(120, 70)
const ROUNDS := 4
const FEINT := 0.18        #chance a swap is a feint

var tier := 0
var level := 0          #the round, 0 first
var prize := ""
var capAt: Array = [0, 1, 2] #slot of each cap
var prizeCap := 1
var swaps: Array = []      #[slotA, slotB, feint] still to play
var swapT := 0.0
var swapTime := 0.42
var phase := "show"        #show, shuffle, pick, found, missed
var t := 0.0
var cursor := 1
var lifted := -1           #the cap lifted, -1 for none

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var game := HubcapShuffle.new()
	game.tier = boxTier
	Root.levelRoot.add_child.call_deferred(game)

## The rarity floor of round `r`'s prize in a box of `boxTier`
static func roundTier(r: int, boxTier: int) -> int:
	return mini(Pickups.R.COMMON + r + int(boxTier / 2.0), Pickups.R.LEGENDARY)

## Swaps in round `r`: more each round, fewer in better boxes
static func swapCount(r: int, boxTier: int) -> int:
	return maxi(3, 5 + r * 2 - int(boxTier / 2.0))

func build() -> void:
	title("HUBCAP SHUFFLE", "Keep your eye on the prize.")
	startRound()

func startRound() -> void:
	prize = Pickups.rollOffer(roundTier(level, tier), Pickups.NOT_IN_GAMES, [])
	swapTime = 0.42 * pow(0.82, level) * (1.0 + tier * 0.06)
	swaps.clear()
	for i in swapCount(level, tier):
		var a := randi() % 3
		var b := (a + 1 + randi() % 2) % 3
		swaps.push_back([a, b, randf() < FEINT])
	phase = "show"
	t = 0.0
	lifted = capOf(slotOf(prizeCap))
	hints([])
	say("Round %d of %d: %s" % [level + 1, ROUNDS, Pickups.displayName(prize)])

func slotOf(cap: int) -> int:
	return capAt[cap]

func capOf(slot: int) -> int:
	return capAt.find(slot)

func onAction(action: String) -> void:
	match action:
		"TurnLeft": if phase == "pick": cursor = maxi(0, cursor - 1)
		"TurnRight": if phase == "pick": cursor = mini(2, cursor + 1)
		ACT, "ui_accept":
			match phase:
				"pick": lift(cursor)
				"found": keep()
		REJECT:
			if phase == "found" && level < ROUNDS - 1: goAgain()

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event): return
	if phase == "pick":
		for s in 3:
			if Rect2(SLOTS[s] - CAP * 0.5, CAP).has_point(event.position): lift(s)
	elif phase == "found": keep()

func lift(slot: int) -> void:
	lifted = capOf(slot)
	if lifted == prizeCap:
		phase = "found"
		Transition.sound("pop", -4.0)
		var list := [[[ACT], "Keep it"]]
		if level < ROUNDS - 1: list.push_back([[REJECT], "Go again for better"])
		hints(list)
		say("Found it: %s." % Pickups.displayName(prize) + ("  Go again for a %s or better?" % Pickups.RARITY_NAMES[roundTier(level + 1, tier)] if level < ROUNDS - 1 else ""))
	else:
		phase = "missed"
		t = 0.0
		Transition.sound("thud", -8.0, 1.2)
		say("Not that one.")

func keep() -> void:
	if boardUp: return
	award(prize)
	showWinnings("FOUND IT")

func goAgain() -> void:
	level += 1
	startRound()

func tick(delta: float) -> void:
	t += delta
	match phase:
		"show":
			if t >= 1.1:
				lifted = -1
				phase = "shuffle"
				swapT = 0.0
				Transition.sound("rattle", -14.0, 1.4)
		"shuffle":
			if swaps.is_empty():
				phase = "pick"
				hints([[["TurnLeft", "TurnRight"], "Pick"], [[ACT], "Lift"]])
				say("Which hubcap?")
				return
			swapT += delta / swapTime
			if swapT >= 1.0:
				var s: Array = swaps.pop_front()
				if not s[2]: #a real swap: the caps trade places
					var ca := capOf(s[0])
					var cb := capOf(s[1])
					capAt[ca] = s[1]
					capAt[cb] = s[0]
				swapT = 0.0
				Transition.sound("clank", -22.0, randf_range(1.6, 2.0))
		"missed":
			if t >= 0.9 && not boardUp:
				lifted = prizeCap #show where it was
				award(Pickups.openOr("coin"))
				showWinnings("MISSED: A COIN FOR TRYING")

## Where cap `cap` is drawn now: on its slot, or partway through the current swap (one passes in front,
## low, the other behind, high)
func capPos(cap: int) -> Vector2:
	var slot := slotOf(cap)
	var at: Vector2 = SLOTS[slot]
	if phase != "shuffle" || swaps.is_empty(): return at
	var s: Array = swaps[0]
	if slot != s[0] && slot != s[1]: return at
	var other: int = s[1] if slot == s[0] else s[0]
	var u := swapT if not s[2] else (swapT * 2.0 if swapT < 0.5 else 2.0 - swapT * 2.0) * 0.45
	var e := 0.5 - 0.5 * cos(u * PI)
	var lift := sin(u * PI) * 46.0 * (1.0 if slot == s[0] else -1.0)
	return at.lerp(SLOTS[other], e) + Vector2(0, lift)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.08, 0.07, 0.065))
	m.draw_rect(Rect2(40, 275, STAGE.x - 80, 16), Color(0.2, 0.17, 0.15))
	#the prize under its cap (seen when that cap is up)
	var showPrize := lifted == prizeCap
	if showPrize: HudTheme.icon(m, Pickups.texture(prize), SLOTS[slotOf(prizeCap)] + Vector2(0, 2), 56.0)
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return capPos(a).y < capPos(b).y)
	for cap in order:
		var c := capPos(cap)
		if cap == lifted: c.y -= 70.0
		drawCap(m, c, phase == "pick" && slotOf(cap) == cursor)
	if phase == "pick":
		HudTheme.text(m, SLOTS[cursor] + Vector2(0, 70), "▲", 22, HudTheme.SKY, HORIZONTAL_ALIGNMENT_CENTER, 4)
	#the round ladder
	for r in ROUNDS:
		var col := Pickups.rarityColor(roundTier(r, tier))
		var box := Rect2(20 + r * 150, 24, 136, 30)
		m.draw_rect(box, Color(col, 0.35 if r == level else 0.1))
		m.draw_rect(box, Color(col, 0.9 if r == level else 0.3), false, 2.0)
		HudTheme.text(m, box.get_center() + Vector2(0, 6), "%d  %s" % [r + 1, Pickups.RARITY_NAMES[roundTier(r, tier)]], 14, Color(HudTheme.TEXT, 1.0 if r <= level else 0.5), HORIZONTAL_ALIGNMENT_CENTER, 3)
	if phase == "show": HudTheme.text(m, Vector2(STAGE.x * 0.5, 120), Pickups.displayName(prize).to_upper(), 22, Pickups.rarityColor(Pickups.rarity(prize)), HORIZONTAL_ALIGNMENT_CENTER, 5)

func drawCap(m: Control, c: Vector2, lit: bool) -> void:
	var w := CAP.x * 0.5
	var pts := PackedVector2Array()
	for i in 17: pts.push_back(c + Vector2(-w + w * 2.0 * i / 16.0, -sin(PI * i / 16.0) * CAP.y * 0.8 + 20.0))
	m.draw_colored_polygon(pts, Color(0.62, 0.66, 0.7) if not lit else Color(0.78, 0.84, 0.9))
	m.draw_polyline(pts, HudTheme.OUTLINE, 3.0, true)
	m.draw_rect(Rect2(c + Vector2(-w - 6, 16), Vector2(CAP.x + 12, 9)), Color(0.4, 0.42, 0.46))
	m.draw_circle(c + Vector2(0, -14), 13.0, Color(0.85, 0.87, 0.9))
	m.draw_circle(c + Vector2(-4, -18), 4.0, Color(1, 1, 1, 0.8))
	if lit: m.draw_rect(Rect2(c + Vector2(-w - 6, 16), Vector2(CAP.x + 12, 9)), HudTheme.SKY, false, 2.0)
