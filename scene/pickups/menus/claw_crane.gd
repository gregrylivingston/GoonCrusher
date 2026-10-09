class_name ClawCrane extends PickupMenu

#The Claw Crane (docs/PICKUPS.md, "Prize games"): a side view of an arcade crane over a heap of prizes.
#The gantry runs back and forth on its own; the action key (E, or a click) drops the claw where it is. Stopping
#swings the claw on its cable, so a good drop allows for the swing. The prizes are loose objects (a small
#physics sim, `stepPhysics`): the open prongs shove them aside on the way down, closing scoops up whatever
#is between them, one prize or several, and on the way up the claw goes weak to this grab's strength
#(`rollStrength`: luck of the draw, Dice and the box tier), so prizes can slip out between the prong tips or
#be shaken loose by the swing. Rarer prizes are smaller and slip through more easily. Whatever drops into the
#chute is won, held or not, and that includes the bit of junk mixed into the heap (JUNK: a dud bomb, an
#oil leak, a pickpocket), which costs something instead. One grab is free; run coins buy more. In a gift box (CrushPrizes) a higher tier
#gives more free grabs (Silver 2, Diamond 3) and a stronger claw, and from Gold up fills the heap with Rare
#or better.

const W := 640.0
const H := 420.0
const RAIL_Y := 34.0
const FLOOR_Y := 404.0
const CHUTE_X := 140.0     #the chute is the strip left of this; its glass wall stands GLASS_H high
const GLASS_H := 150.0    #tall enough that a prize bouncing off the heap rarely clears it
const HOME_X := 70.0       #over the chute
const MIN_X := 190.0       #the patrol
const MAX_X := W - 70.0
const PATROL_SPEED := 190.0
const PATROL_ACCEL := 700.0
const BRAKE := 900.0       #the gantry stops about 20 px after a drop
const CARRY_SPEED := 300.0
const CABLE_REST := 60.0
const CABLE_MAX := FLOOR_Y - RAIL_Y - 30.0
const GRAVITY := 2500.0    #px/s², for the swing: stiff, so it sways rather than flails
const SWING_DAMP := 3.0
const DROP_SPEED := 380.0
const LIFT_SPEED := 240.0
const CLOSE_TIME := 0.35
const RELAX_TIME := 0.5
const OPEN_TIME := 0.25
const EXTRA_GRAB := 150
const PRIZES := 24          #prizes in the heap, plus JUNK_COUNT junk
const GOOD := 15           #of them rolled Uncommon or better; the rest are coin stacks
## the prongs turn about their hinges from OPEN_ANGLE (out) to SHUT_ANGLE (tips crossed); after closing, a
## grab relaxes to between WEAK_ANGLE and SHUT_ANGLE by its strength
const OPEN_ANGLE := -0.55
const SHUT_ANGLE := 0.12
const WEAK_ANGLE := -0.32
const CLAW_SCALE := 1.3    #the claw's size: the head, hinges and prongs
const HINGE := Vector2(11, 8) * CLAW_SCALE
const PRONG := [Vector2(0, 0), Vector2(24, 30) * CLAW_SCALE, Vector2(6, 60) * CLAW_SCALE] #the right prong from its hinge, at angle 0
const PRONG_W := 3.5
const HEAD := Rect2(Vector2(-18, -8) * CLAW_SCALE, Vector2(36, 20) * CLAW_SCALE)
## by rarity, Common to Legendary: rarer prizes are smaller and heavier
const RADIUS := [22.0, 21.0, 19.0, 17.0, 16.0, 16.0]
const MASS := [1.0, 1.1, 1.3, 1.5, 1.7, 1.7]
## the physics
const STEP := 1.0 / 240.0
const FALL := 1500.0       #px/s²
const ITERATIONS := 5
const FRICTION := 0.35     #share of sliding taken off at a contact
const DAMP := 0.999
const MAX_MOVE := 8.0      #px per step at most, so a squeeze never launches a prize
const REST := 0.06         #px per step: a supported prize slower than this comes to rest (no jitter on the heap)
const JUNK_COUNT := 4      #junk in the heap (PickupMenu.JUNK)

var prizes: Array = []     #{id, pos, prev, r, m, rot}
var clawX := (MIN_X + MAX_X) * 0.5
var vx := 0.0
var patrolDir := 1.0
var theta := 0.0           #the cable's swing, radians from straight down
var omega := 0.0
var cable := CABLE_REST
var prong := OPEN_ANGLE    #the prongs' angle now
var segs: Array = []       #the claw's colliders at the last step
var phase := "patrol"      #patrol, drop, close, lift, carry, open, done
var t := 0.0
var strength := 1.0        #this grab's claw, 0..1
var holdAngle := SHUT_ANGLE
var grabs := 1
var won: Array = []
var boxTier := 0
var fromBox := false
var leftover := 0.0        #frame time not yet stepped
var settling := false

static func open(tier := 0, isGiftBox := false) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var claw := ClawCrane.new()
	claw.boxTier = tier
	claw.fromBox = isGiftBox
	claw.grabs = 1 + int(tier / 2.0)
	Root.levelRoot.add_child.call_deferred(claw)

## A grab's strength: luck of the draw, plus Dice and the box tier
static func rollStrength(dice: float, tier: int) -> float:
	return clampf(0.45 + tier * 0.07 + dice * 0.001 + randf_range(-0.15, 0.15), 0.15, 1.0)

func build() -> void:
	title("CLAW CRANE", ("Gift box: " if fromBox else "") + "Drop the claw at the right moment.")
	var heapTier := Pickups.R.RARE if boxTier >= 3 else Pickups.R.UNCOMMON
	var ids := []
	for i in PRIZES: #mostly Uncommon or better, padded with coin stacks
		ids.push_back(Pickups.rollOffer(heapTier, Pickups.NOT_IN_GAMES, []) if i < GOOD else Pickups.openOr("coinstack"))
	for i in JUNK_COUNT: ids.push_back(JUNK.keys().pick_random())
	ids.shuffle()
	for id in ids: addPrize(id, freeSpot(radiusOf(id)))
	settle(1.5)
	hints([[[ACT], "Drop"]])
	updateInfo()

static func radiusOf(id: String) -> float:
	return 20.0 if isJunk(id) else RADIUS[Pickups.rarity(id)]

static func textureOf(id: String) -> Texture2D:
	return junkTexture(id) if isJunk(id) else Pickups.texture(id)

static func nameOf(id: String) -> String:
	return JUNK[id].name if isJunk(id) else Pickups.shortName(id)

static func colorOf(id: String) -> Color:
	return HudTheme.BAD if isJunk(id) else Pickups.rarityColor(Pickups.rarity(id))

func addPrize(id: String, at: Vector2) -> Dictionary:
	var p := {"id": id, "pos": at, "prev": at, "r": radiusOf(id), "m": 1.2 if isJunk(id) else MASS[Pickups.rarity(id)], "rot": randf_range(-0.4, 0.4)}
	prizes.push_back(p)
	return p

## A place to drop a new prize in from, clear of the others
func freeSpot(r: float) -> Vector2:
	var at := Vector2.ZERO
	for attempt in 40:
		at = Vector2(randf_range(CHUTE_X + 30.0, W - 30.0), randf_range(200.0, FLOOR_Y - r))
		if prizes.all(func(p): return p.pos.distance_to(at) >= p.r + r): break
	return at

## Runs the heap for `seconds` without the frame clock (the heap settling before the game shows)
func settle(seconds: float) -> void:
	settling = true
	for i in int(seconds / STEP): stepPhysics(STEP)
	settling = false

func tipX() -> float:
	return clawX + sin(theta) * cable

func tipY() -> float:
	return RAIL_Y + cos(theta) * cable

## The claw hangs along its cable
func clawXform() -> Transform2D:
	return Transform2D(-theta, Vector2(tipX(), tipY()))

func updateInfo() -> void:
	match phase:
		"patrol": say("Grabs left %d   -   Run coins %d" % [grabs, runCoins()])
		"done": say("Out of grabs." + ("   %s: one more for %d coins" % [InputGlyphs.label(REJECT), EXTRA_GRAB] if runCoins() >= EXTRA_GRAB else ""))

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept":
			if phase == "patrol": startDrop()
			elif phase == "done": showWinnings()
		REJECT: #retry: another grab for run coins
			if phase == "done" && runCoins() >= EXTRA_GRAB:
				Root.playerCar.coin -= EXTRA_GRAB
				grabs += 1
				phase = "patrol"
				hints([[[ACT], "Drop"]])
				updateInfo()
		"ui_cancel":
			if phase == "done": showWinnings()

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event): return
	if phase == "patrol": startDrop()
	elif phase == "done": showWinnings()

func startDrop() -> void:
	grabs -= 1
	phase = "drop"
	t = 0.0
	Transition.sound("whoosh", -14.0, 1.3)
	updateInfo()

func tick(delta: float) -> void:
	t += delta
	var accel := 0.0
	match phase:
		"patrol":
			if clawX >= MAX_X: patrolDir = -1.0
			elif clawX <= MIN_X: patrolDir = 1.0
			accel = gantry(patrolDir * PATROL_SPEED, PATROL_ACCEL, delta)
		"drop":
			accel = gantry(0.0, BRAKE, delta)
			cable = minf(cable + DROP_SPEED * delta, CABLE_MAX)
			if landed() || cable >= CABLE_MAX:
				phase = "close"
				t = 0.0
		"close":
			accel = gantry(0.0, BRAKE, delta)
			prong = lerpf(OPEN_ANGLE, SHUT_ANGLE, minf(t / CLOSE_TIME, 1.0))
			if t >= CLOSE_TIME:
				var dice: float = Root.playerCar.luck if is_instance_valid(Root.playerCar) else 0.0
				strength = rollStrength(dice, boxTier)
				holdAngle = lerpf(WEAK_ANGLE, SHUT_ANGLE, strength)
				phase = "lift"
				t = 0.0
				Transition.sound("clank", -8.0, 1.2)
		"lift":
			accel = gantry(0.0, BRAKE, delta)
			prong = lerpf(SHUT_ANGLE, holdAngle, minf(t / RELAX_TIME, 1.0))
			cable = maxf(CABLE_REST, cable - LIFT_SPEED * delta)
			if cable <= CABLE_REST && t >= RELAX_TIME:
				phase = "carry"
				t = 0.0
		"carry":
			accel = gantry(clampf((HOME_X - clawX) * 4.0, -CARRY_SPEED, CARRY_SPEED), PATROL_ACCEL, delta)
			if absf(clawX - HOME_X) < 3.0 && absf(vx) < 20.0:
				phase = "open"
				t = 0.0
		"open":
			accel = gantry(0.0, BRAKE, delta)
			prong = lerpf(holdAngle, OPEN_ANGLE, minf(t / OPEN_TIME, 1.0))
			if t >= OPEN_TIME + 0.7: afterGrab()
	swing(accel, delta)
	leftover = minf(leftover + delta, 0.1)
	while leftover >= STEP:
		leftover -= STEP
		stepPhysics(STEP)

func afterGrab() -> void:
	phase = "patrol" if grabs > 0 else "done"
	patrolDir = 1.0
	if phase == "done":
		if runCoins() >= EXTRA_GRAB: hints([[[ACT], "Collect"], [[REJECT], "Another grab  (%d coins)" % EXTRA_GRAB]])
		else: showWinnings()
	updateInfo()

## Drives the gantry toward `speed` at `rate`; returns its acceleration, for the swing.
func gantry(speed: float, rate: float, delta: float) -> float:
	var before := vx
	vx = move_toward(vx, speed, rate * delta)
	clawX = clampf(clawX + vx * delta, HOME_X, W - 40.0)
	return (vx - before) / maxf(delta, 0.0001)

## The cable as a pendulum hung from the moving gantry
func swing(accel: float, delta: float) -> void:
	var alpha := -(GRAVITY / cable) * sin(theta) - (accel / cable) * cos(theta) - SWING_DAMP * omega
	omega += alpha * delta
	theta = clampf(theta + omega * delta, -0.8, 0.8)

## The claw's head has come down onto the heap, or its prong tips onto the floor
func landed() -> bool:
	var x := clawXform()
	var head: Vector2 = x * Vector2(0, HEAD.end.y + 2.0)
	for p in prizes:
		if absf(p.pos.x - head.x) < HEAD.size.x * 0.45 + p.r * 0.6 && p.pos.y - p.r <= head.y + 2.0 && p.pos.y > head.y - p.r: return true
	for side in [-1.0, 1.0]:
		if (x * prongPoint(side, 2)).y >= FLOOR_Y - 4.0: return true
	return false

## A prong's point `i` (0 hinge, 1 knee, 2 tip) in the claw's frame; `side` -1 left, 1 right
func prongPoint(side: float, i: int) -> Vector2:
	var p: Vector2 = PRONG[i].rotated(prong)
	return Vector2(side * (HINGE.x + p.x), HINGE.y + p.y)

## The claw's colliders in stage space: the head's underside and each prong's two segments
func clawSegments() -> Array:
	var x := clawXform()
	var out := [[x * Vector2(HEAD.position.x, HEAD.end.y), x * HEAD.end, 0.0]]
	for side in [-1.0, 1.0]:
		for i in 2: out.push_back([x * prongPoint(side, i), x * prongPoint(side, i + 1), side])
	return out

#---------- the physics: position-based circles against the cabinet and the claw ----------

func stepPhysics(dt: float) -> void:
	var now := clawSegments()
	var claw := []
	for i in now.size():
		var was: Array = now[i]
		if segs.size() == now.size(): was = segs[i]
		claw.push_back([now[i][0], now[i][1], now[i][0] - was[0], now[i][1] - was[1], now[i][2]])
	segs = now
	var near := Rect2(now[0][0], Vector2.ZERO) #the claw's bounds: prizes outside it skip the claw's segments
	for seg in now: near = near.expand(seg[0]).expand(seg[1])
	near = near.grow(PRONG_W + 24.0)
	for p in prizes:
		p["held"] = false #set when the floor, another prize or the claw holds it up this step
		var v: Vector2 = ((p.pos - p.prev) * DAMP).limit_length(MAX_MOVE)
		p.prev = p.pos
		p.pos += v + Vector2(0, FALL * dt * dt)
	prizes.sort_custom(func(a, b): return a.pos.x < b.pos.x) #sweep: only neighbours along x can touch
	for k in ITERATIONS:
		for i in prizes.size():
			var reach: float = prizes[i].pos.x + prizes[i].r + 26.0
			for j in range(i + 1, prizes.size()):
				if prizes[j].pos.x > reach: break
				pair(prizes[i], prizes[j])
		for p in prizes:
			if near.has_point(p.pos):
				for s in claw: pushOut(p, s[0], s[1], s[2], s[3], s[4])
			cabinet(p)
	for p in prizes.duplicate():
		var moved: Vector2 = p.pos - p.prev
		if p.held && moved.length() < REST: p.prev = p.pos #resting on something: no creeping or buzzing in the heap
		elif absf(moved.x) > REST * 4.0: p.rot = clampf(p.rot + moved.x / p.r * 0.25, -0.6, 0.6) #tips a little as it rolls
		if p.pos.x < CHUTE_X && p.pos.y > FLOOR_Y + p.r + 8.0: inChute(p)

func pair(a: Dictionary, b: Dictionary) -> void:
	var d: Vector2 = b.pos - a.pos
	var reach: float = a.r + b.r
	var dist := d.length()
	if dist >= reach || dist < 0.0001: return
	var n := d / dist
	var total: float = a.m + b.m
	if n.y > 0.4: a.held = true #b is under a
	elif n.y < -0.4: b.held = true
	a.pos -= n * (reach - dist) * b.m / total
	b.pos += n * (reach - dist) * a.m / total

## Pushes a prize out of a segment of the claw that moved by `ma` and `mb` this step, and drags it along
## with the segment a little (friction). A prong's outside (`side`: -1 left prong, 1 right, 0 the head) is
## smooth, so prizes slide off the arms instead of riding up on them.
func pushOut(p: Dictionary, a: Vector2, b: Vector2, ma: Vector2, mb: Vector2, side := 0.0) -> void:
	var ab := b - a
	var u := clampf((p.pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var d: Vector2 = p.pos - (a + ab * u)
	var dist := d.length()
	var reach: float = p.r + PRONG_W
	if dist >= reach: return
	var n := d / dist if dist > 0.0001 else Vector2(-ab.y, ab.x).normalized()
	p.pos += n * (reach - dist)
	if n.y < -0.4: p.held = true
	if side != 0.0 && clawXform().basis_xform_inv(n).x * side > 0.2: return #the outside of a prong
	var slide: Vector2 = (p.pos - p.prev) - ma.lerp(mb, u)
	slide -= n * slide.dot(n)
	p.pos -= slide * FRICTION

## The floor (open over the chute), the cabinet's sides and the chute's glass
func cabinet(p: Dictionary) -> void:
	var r: float = p.r
	if p.pos.x >= CHUTE_X && p.pos.y > FLOOR_Y - r - 0.5:
		p.held = true
		p.pos.y = minf(p.pos.y, FLOOR_Y - r)
		p.pos.x = lerpf(p.pos.x, p.prev.x, FRICTION)
	p.pos.x = clampf(p.pos.x, r, W - r)
	#the glass: a wall at CHUTE_X from its top to the floor, with a rounded top
	var top := Vector2(CHUTE_X, FLOOR_Y - GLASS_H)
	if p.pos.y >= top.y && absf(p.pos.x - CHUTE_X) < r:
		p.pos.x = CHUTE_X + (r if p.prev.x >= CHUTE_X else -r)
	elif p.pos.y < top.y && p.pos.distance_to(top) < r:
		p.pos = top + (p.pos - top).normalized() * r

## A prize fell down the chute: won, credited now (the fall was the show)
func inChute(p: Dictionary) -> void:
	if settling: #not played for: back onto the heap
		p.pos = Vector2(W * 0.6, 200.0)
		p.prev = p.pos
		return
	prizes.erase(p)
	if isJunk(p.id):
		awardJunk(p.id)
		say("Junk! %s: %s" % [JUNK[p.id].name, JUNK[p.id].line])
		return
	won.push_back(p.id)
	award(p.id)
	Transition.sound("pop", -4.0)

#---------- drawing ----------

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.07, 0.055, 0.05))
	for i in 6: m.draw_rect(Rect2(0, RAIL_Y + i * 64.0, W, 32.0), Color(1, 0.9, 0.7, 0.015))
	m.draw_rect(Rect2(CHUTE_X, FLOOR_Y, W - CHUTE_X, H - FLOOR_Y), Color(0.13, 0.1, 0.08))
	#the chute: a dark hole behind a glass wall
	m.draw_rect(Rect2(0, FLOOR_Y - GLASS_H, CHUTE_X, GLASS_H + 20.0), Color(0.02, 0.015, 0.012))
	m.draw_rect(Rect2(CHUTE_X - 4.0, FLOOR_Y - GLASS_H, 4.0, GLASS_H), Color(0.6, 0.8, 1.0, 0.4))
	HudTheme.text(m, Vector2(CHUTE_X * 0.5, FLOOR_Y - GLASS_H - 10.0), "PRIZE", 15, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, Vector2(CHUTE_X * 0.5, FLOOR_Y - GLASS_H + 28.0), "▼", 22, Color(HudTheme.GOLD, 0.6 + 0.4 * sin(t * 6.0)), HORIZONTAL_ALIGNMENT_CENTER, 3)
	for p in prizes:
		var s: float = p.r * 2.3
		m.draw_set_transform(p.pos, p.rot, Vector2.ONE)
		m.draw_texture_rect(textureOf(p.id), Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), false, JUNK_TINT if isJunk(p.id) else Color.WHITE)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase == "patrol": #the name of the prize the claw is over
		var x := tipX()
		var under = null
		for p in prizes:
			if absf(p.pos.x - x) < p.r + 6.0 && (under == null || p.pos.y < under.pos.y): under = p
		if under != null: HudTheme.text(m, Vector2(clampf(under.pos.x, 60.0, W - 60.0), under.pos.y - under.r - 8.0), nameOf(under.id), Pickups.TAG_SIZE + 3, colorOf(under.id), HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
	#the gantry rail, carriage and cable, then the claw along it
	m.draw_rect(Rect2(0, RAIL_Y - 14.0, W, 8.0), Color(0.35, 0.33, 0.32))
	m.draw_rect(Rect2(clawX - 26.0, RAIL_Y - 20.0, 52.0, 18.0), HudTheme.RIM)
	m.draw_line(Vector2(clawX, RAIL_Y - 4.0), Vector2(tipX(), tipY()), Color(0.7, 0.72, 0.76), 3.0)
	m.draw_set_transform_matrix(clawXform())
	m.draw_rect(HEAD, Color(0.66, 0.69, 0.74))
	m.draw_rect(HEAD, HudTheme.OUTLINE, false, 2.0)
	for side in [-1.0, 1.0]:
		m.draw_polyline(PackedVector2Array([prongPoint(side, 0), prongPoint(side, 1), prongPoint(side, 2)]), Color(0.78, 0.8, 0.84), PRONG_W * 2.0, true)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase in ["lift", "carry", "open"]: #this grab's strength
		var r := Rect2(W - 30.0, RAIL_Y + 20.0, 14.0, 150.0)
		m.draw_rect(r, HudTheme.TRACK)
		var col := HudTheme.OK if strength > 0.6 else (HudTheme.WARN if strength > 0.35 else HudTheme.BAD)
		m.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * strength, r.size.x, r.size.y * strength), col)
		HudTheme.text(m, Vector2(r.get_center().x, r.end.y + 18.0), "GRIP", 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)
