class_name ClawCrane extends PickupMenu

#The Claw Crane (docs/PICKUPS.md, "Prize games"): a side view of an arcade crane over a heap of prizes. Steer
#moves the gantry and the claw swings on its cable as it starts and stops, so a good drop waits for the swing
#or times it. Accelerate drops the claw; it stops on the first prize under it and closes. The grip is set
#by how centred the claw is on the prize, and drains on the way up and over to the chute, faster for heavy
#(rarer, smaller) prizes and while the claw swings: a weak grip wobbles, then lets go. A prize dropped over
#the chute still counts. One grab is free; run coins buy more. In a gift box (CrushPrizes) a higher tier
#gives more free grabs (Silver 2, Diamond 3) and a firmer grip, and from Gold up fills the heap with Rare or
#better.

const W := 640.0
const H := 420.0
const RAIL_Y := 34.0
const FLOOR_Y := 404.0
const CHUTE_X := 96.0      #the chute is the strip left of this; its glass wall stands GLASS_H high
const GLASS_H := 120.0
const HOME_X := 48.0       #over the chute
const MIN_X := 70.0        #the gantry's travel while aiming
const MAX_X := W - 34.0
const GANTRY_ACCEL := 900.0
const GANTRY_MAX := 300.0
const GANTRY_FRICTION := 6.0
const CABLE_REST := 70.0
const GRAVITY := 900.0     #px/s², for the swing
const SWING_DAMP := 1.1
const DROP_SPEED := 420.0
const LIFT_SPEED := 300.0
const CARRY_SPEED := 340.0
const CLOSE_TIME := 0.28
const SPAN := 26.0         #half the open claw's reach
const EXTRA_GRAB := 150
const PRIZES := 14
## by rarity, Common to Legendary: rarer prizes are smaller and heavier
const RADIUS := [31.0, 29.0, 26.0, 23.0, 21.0, 21.0]
const WEIGHT := [1.0, 1.15, 1.35, 1.6, 1.85, 1.85]
const GRIP_DRAIN := 0.07   #per second per unit of weight, while held
const SWING_DRAIN := 0.05  #per second per radian/s of swing, while held
const LET_GO := 0.28       #the grip below which the prize slips

var prizes: Array = []     #{id, pos, r, w, vy} on the heap; pos is the centre
var falling: Array = []    #{id, pos, r, w, vy, chute} dropping back or into the chute
var clawX := W * 0.5       #the gantry
var vx := 0.0
var theta := 0.0           #the cable's swing, radians from straight down
var omega := 0.0
var cable := CABLE_REST
var phase := "aim"         #aim, drop, close, lift, carry, open, done
var t := 0.0
var held: Array = []       #prizes in the claw
var grip := 1.0
var grabs := 1
var won: Array = []
var boxTier := 0
var fromBox := false
var mouseX := -1.0         #the mouse steers the gantry towards here while it is over the stage

static func open(tier := 0, isGiftBox := false) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var claw := ClawCrane.new()
	claw.boxTier = tier
	claw.fromBox = isGiftBox
	claw.grabs = 1 + int(tier / 2.0)
	Root.levelRoot.add_child.call_deferred(claw)

## The grip a grab starts with: 1 when dead centre on the prize, falling off to the edge of its reach;
## Dice and the box tier firm it up.
static func gripFor(dx: float, radius: float, dice: float, tier: int) -> float:
	var centred := clampf(1.0 - absf(dx) / (radius + SPAN * 0.4), 0.0, 1.0)
	return clampf(0.3 + 0.7 * centred + dice * 0.001 + tier * 0.05, 0.0, 1.2)

func build() -> void:
	title("CLAW CRANE", ("Gift box: " if fromBox else "") + "Line up the claw, wait for the swing, drop it.")
	var heapTier := Pickups.R.RARE if boxTier >= 3 else Pickups.R.UNCOMMON
	var ids := []
	for i in PRIZES: #mostly Uncommon or better, padded with coin stacks
		var id := Pickups.rollOffer(heapTier, Pickups.NOT_IN_GAMES, []) if i < 10 else Pickups.openOr("coinstack")
		ids.push_back(id)
	ids.shuffle()
	for id in ids: drop(makePrize(id, randf_range(CHUTE_X + 40.0, W - 40.0)), true)
	updateHints()
	updateInfo()

func makePrize(id: String, x: float) -> Dictionary:
	var r := Pickups.rarity(id)
	return {"id": id, "pos": Vector2(x, RAIL_Y), "r": RADIUS[r], "w": WEIGHT[r], "vy": 0.0}

## Settles a prize onto the heap straight below it (at once when `instant`, else it falls).
func drop(p: Dictionary, instant := false) -> void:
	if instant:
		p.pos.y = restY(p)
		prizes.push_back(p)
	else:
		p["chute"] = p.pos.x < CHUTE_X
		falling.push_back(p)

## Where a prize at its x would come to rest on the floor or on top of the heap.
func restY(p: Dictionary) -> float:
	var y: float = FLOOR_Y - p.r
	for q in prizes:
		var dx: float = absf(q.pos.x - p.pos.x)
		var reach: float = q.r + p.r - 4.0
		if dx < reach: y = minf(y, q.pos.y - sqrt(reach * reach - dx * dx))
	return y

func tipX() -> float:
	return clawX + sin(theta) * cable

func tipY() -> float:
	return RAIL_Y + cos(theta) * cable

## Steady enough to drop where it points (the career harness waits for this)
func settled() -> bool:
	return absf(theta) < 0.04 && absf(omega) < 0.15 && absf(vx) < 10.0

func updateInfo() -> void:
	match phase:
		"aim": say("Grabs left %d   -   Run coins %d" % [grabs, runCoins()])
		"done": say("Out of grabs." + ("   Brake: one more for %d coins" % EXTRA_GRAB if runCoins() >= EXTRA_GRAB else ""))

func updateHints() -> void:
	if phase == "done":
		var list := [[["Accelerate"], "Collect"]]
		if runCoins() >= EXTRA_GRAB: list.push_back([["Brake"], "Another grab  (%d coins)" % EXTRA_GRAB])
		hints(list)
	else: hints([[["TurnLeft", "TurnRight"], "Move"], [["Accelerate"], "Drop"]])

func onAction(action: String) -> void:
	match action:
		"Accelerate", "ui_accept":
			if phase == "aim": startDrop()
			elif phase == "done": showWinnings()
		"Brake":
			if phase == "done" && runCoins() >= EXTRA_GRAB:
				Root.playerCar.coin -= EXTRA_GRAB
				grabs += 1
				phase = "aim"
				updateHints()
				updateInfo()
		"ui_cancel":
			if phase == "done": showWinnings()

func onStageMouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouseX = event.position.x
	elif isClick(event) && phase == "aim": startDrop()
	elif isClick(event) && phase == "done": showWinnings()

func startDrop() -> void:
	grabs -= 1
	phase = "drop"
	t = 0.0
	mouseX = -1.0
	Transition.sound("whoosh", -14.0, 1.3)
	updateInfo()

func tick(delta: float) -> void:
	t += delta
	var accel := 0.0
	match phase:
		"aim":
			var dir := 0.0
			if Input.is_action_pressed("TurnLeft") || Input.is_action_pressed("ui_left"): dir -= 1.0
			if Input.is_action_pressed("TurnRight") || Input.is_action_pressed("ui_right"): dir += 1.0
			if dir != 0.0: mouseX = -1.0
			elif mouseX >= 0.0 && absf(mouseX - clawX) > 6.0: dir = clampf((mouseX - clawX) / 60.0, -1.0, 1.0)
			accel = gantry(dir, delta)
		"drop":
			accel = gantry(0.0, delta)
			cable += DROP_SPEED * delta
			var floorAt := contactY()
			if tipY() + 40.0 >= floorAt:
				cable = maxf(CABLE_REST, (floorAt - 40.0 - RAIL_Y) / maxf(cos(theta), 0.3))
				phase = "close"
				t = 0.0
		"close":
			accel = gantry(0.0, delta)
			if t >= CLOSE_TIME:
				grab()
				phase = "lift"
				t = 0.0
		"lift":
			accel = gantry(0.0, delta)
			cable = maxf(CABLE_REST, cable - LIFT_SPEED * delta)
			drain(delta)
			if cable <= CABLE_REST:
				phase = "carry"
				t = 0.0
		"carry":
			accel = gantry(clampf((HOME_X - clawX) / 50.0, -1.0, 1.0), delta, CARRY_SPEED)
			drain(delta)
			if absf(clawX - HOME_X) < 4.0 && absf(vx) < 30.0:
				phase = "open"
				t = 0.0
				release(true)
		"open":
			accel = gantry(0.0, delta)
			if t >= 0.35 && falling.is_empty():
				phase = "aim" if grabs > 0 else "done"
				if phase == "done" && runCoins() < EXTRA_GRAB:
					showWinnings()
				updateHints()
				updateInfo()
	swing(accel, delta)
	for p in held:
		p.pos = Vector2(tipX(), tipY() + 30.0 + p.r * 0.5)
	fall(delta)

## Moves the gantry towards `dir` (-1..1); returns its acceleration for the swing.
func gantry(dir: float, delta: float, topSpeed := GANTRY_MAX) -> float:
	var before := vx
	if dir != 0.0: vx = clampf(vx + dir * GANTRY_ACCEL * delta, -topSpeed * absf(dir), topSpeed * absf(dir))
	else: vx = move_toward(vx, 0.0, absf(vx) * GANTRY_FRICTION * delta + GANTRY_ACCEL * 0.5 * delta)
	var lo := HOME_X if phase in ["carry", "open"] else MIN_X
	var x := clampf(clawX + vx * delta, lo, MAX_X)
	if x != clawX + vx * delta: vx = 0.0
	clawX = x
	return (vx - before) / maxf(delta, 0.0001)

## The cable as a pendulum hung from the moving gantry
func swing(accel: float, delta: float) -> void:
	var damp := SWING_DAMP * (2.0 if phase == "drop" else 1.0)
	var alpha := -(GRAVITY / cable) * sin(theta) - (accel / cable) * cos(theta) - damp * omega
	omega += alpha * delta
	theta = clampf(theta + omega * delta, -0.9, 0.9)

## The highest point under the claw it would come down on: a prize within its reach, or the floor.
func contactY() -> float:
	var y := FLOOR_Y
	var x := tipX()
	for p in prizes:
		if absf(p.pos.x - x) < p.r + SPAN * 0.5: y = minf(y, p.pos.y - p.r * 0.6)
	return y

## The claw closes on the prize under it, most centred first. A second one right beside it can come too.
func grab() -> void:
	var x := tipX()
	var near := prizes.filter(func(p): return absf(p.pos.x - x) < p.r + SPAN * 0.4 && p.pos.y - p.r <= tipY() + 60.0)
	if near.is_empty():
		grip = 0.0
		Transition.sound("clank", -12.0, 1.4)
		return
	near.sort_custom(func(a, b): return absf(a.pos.x - x) < absf(b.pos.x - x))
	var first: Dictionary = near[0]
	var dice: float = Root.playerCar.luck if is_instance_valid(Root.playerCar) else 0.0
	grip = gripFor(first.pos.x - x, first.r, dice, boxTier)
	held = [first]
	prizes.erase(first)
	if near.size() > 1 && grip > 0.85 && randf() < 0.3: #a lucky double: a small prize wedged in beside
		held.push_back(near[1])
		prizes.erase(near[1])
	Transition.sound("clank", -8.0, 1.2)
	settleHeap()

func drain(delta: float) -> void:
	if held.is_empty(): return
	var weight := 0.0
	for p in held: weight += p.w
	grip -= (GRIP_DRAIN * weight + SWING_DRAIN * absf(omega)) * delta
	if grip < LET_GO:
		say("It slipped!" if clawX >= CHUTE_X else "It slipped... into the chute!")
		release(false)

## Lets go of what the claw holds: over the chute it is won now (credited at once; the fall is the look).
func release(intended: bool) -> void:
	for p in held:
		p.vy = 0.0
		drop(p)
		if p.pos.x < CHUTE_X:
			won.push_back(p.id)
			award(p.id)
			Transition.sound("pop", -4.0)
	held.clear()
	if not intended: Transition.sound("thud", -10.0, 1.3)

func fall(delta: float) -> void:
	for p in falling.duplicate():
		p.vy += 1600.0 * delta
		p.pos.y += p.vy * delta
		var stop: float = (FLOOR_Y + 60.0) if p.chute else float(restY(p))
		if p.pos.y >= stop:
			falling.erase(p)
			if not p.chute:
				p.pos.y = stop
				prizes.push_back(p)

## After a grab the prizes that lost their support drop onto what is under them.
func settleHeap() -> void:
	prizes.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	var placed := []
	for p in prizes:
		var y: float = FLOOR_Y - p.r
		for q in placed:
			var dx: float = absf(q.pos.x - p.pos.x)
			var reach: float = q.r + p.r - 4.0
			if dx < reach: y = minf(y, q.pos.y - sqrt(reach * reach - dx * dx))
		p.pos.y = y
		placed.push_back(p)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.07, 0.055, 0.05))
	for i in 6: m.draw_rect(Rect2(0, RAIL_Y + i * 64.0, W, 32.0), Color(1, 0.9, 0.7, 0.015))
	m.draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.13, 0.1, 0.08))
	#the chute: a dark hole behind a glass wall
	m.draw_rect(Rect2(0, FLOOR_Y - GLASS_H, CHUTE_X, GLASS_H + 20.0), Color(0.02, 0.015, 0.012))
	m.draw_rect(Rect2(CHUTE_X - 5.0, FLOOR_Y - GLASS_H, 5.0, GLASS_H), Color(0.6, 0.8, 1.0, 0.35))
	HudTheme.text(m, Vector2(CHUTE_X * 0.5, FLOOR_Y - GLASS_H - 10.0), "PRIZE", 15, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, Vector2(CHUTE_X * 0.5, FLOOR_Y - GLASS_H + 28.0), "▼", 22, Color(HudTheme.GOLD, 0.6 + 0.4 * sin(t * 6.0)), HORIZONTAL_ALIGNMENT_CENTER, 3)
	for p in prizes + falling: drawPrize(m, p)
	#the gantry rail and carriage
	m.draw_rect(Rect2(0, RAIL_Y - 14.0, W, 8.0), Color(0.35, 0.33, 0.32))
	m.draw_rect(Rect2(clawX - 26.0, RAIL_Y - 20.0, 52.0, 18.0), HudTheme.RIM)
	var tip := Vector2(tipX(), tipY())
	m.draw_line(Vector2(clawX, RAIL_Y - 4.0), tip, Color(0.7, 0.72, 0.76), 3.0)
	if phase == "aim": #where it would come down, and the name of the prize there
		var x := tipX()
		m.draw_dashed_line(tip + Vector2(0, 40), Vector2(x, contactY()), Color(1, 1, 1, 0.18), 2.0, 8.0)
		var under = null
		for p in prizes:
			if absf(p.pos.x - x) < p.r + SPAN * 0.4 && (under == null || p.pos.y < under.pos.y): under = p
		if under != null: HudTheme.text(m, Vector2(clampf(under.pos.x, 60.0, W - 60.0), under.pos.y - under.r - 10.0), Pickups.shortName(under.id), Pickups.TAG_SIZE + 3, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
	for p in held: drawPrize(m, p, (0.5 - grip) * 10.0 * sin(t * 40.0) if grip < 0.5 else 0.0)
	drawClaw(m, tip)
	if not held.is_empty(): #the grip gauge
		var r := Rect2(W - 30.0, RAIL_Y + 20.0, 14.0, 150.0)
		m.draw_rect(r, HudTheme.TRACK)
		var f := clampf(grip, 0.0, 1.0)
		var col := HudTheme.OK if grip > 0.6 else (HudTheme.WARN if grip > 0.4 else HudTheme.BAD)
		m.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * f, r.size.x, r.size.y * f), col)
		m.draw_line(Vector2(r.position.x - 4, r.end.y - r.size.y * LET_GO), Vector2(r.end.x + 4, r.end.y - r.size.y * LET_GO), HudTheme.BAD, 2.0)
		HudTheme.text(m, Vector2(r.get_center().x, r.end.y + 18.0), "GRIP", 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)

func drawPrize(m: Control, p: Dictionary, jitter := 0.0) -> void:
	var c: Vector2 = p.pos + Vector2(jitter, 0)
	var col := Pickups.rarityColor(Pickups.rarity(p.id))
	m.draw_circle(c, p.r, Color(col, 0.22))
	m.draw_arc(c, p.r, 0.0, TAU, 24, Color(col, 0.7), 2.0, true)
	var s: float = p.r * 1.6
	m.draw_texture_rect(Pickups.texture(p.id), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)

func drawClaw(m: Control, tip: Vector2) -> void:
	var closing := 0.0
	match phase:
		"close": closing = clampf(t / CLOSE_TIME, 0.0, 1.0)
		"lift", "carry": closing = 1.0
		"open": closing = 1.0 - clampf(t / 0.2, 0.0, 1.0)
	var spread := lerpf(SPAN, 8.0 if held.is_empty() else 16.0, closing)
	m.draw_set_transform(tip, -theta, Vector2.ONE)
	m.draw_rect(Rect2(-18, -10, 36, 18), Color(0.66, 0.69, 0.74))
	m.draw_rect(Rect2(-18, -10, 36, 18), HudTheme.OUTLINE, false, 2.0)
	for side in [-1.0, 1.0]:
		m.draw_polyline(PackedVector2Array([Vector2(side * 12, 6), Vector2(side * (spread + 8.0), 24), Vector2(side * spread * 0.55, 44)]), Color(0.78, 0.8, 0.84), 6.0, true)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
