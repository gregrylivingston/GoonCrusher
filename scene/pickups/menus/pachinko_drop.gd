class_name PachinkoDrop extends PickupMenu

#Pachinko Drop (docs/PICKUPS.md, "Prize games"): A / D slide the dropper along the top, the action key (E)
#drops a ball into a field of pegs, and it rattles down into one of seven cups, each showing its prize. The
#outer cups hold the rarest prizes and the pegs make them hardest to reach. REJECT (Q) nudges the cabinet
#once per ball, toward the side you last steered. A cup pays the moment a ball lands in it, then refills.
#Three balls, one more per two box tiers; better boxes fill the cups with better prizes. The balls run on
#PrizePhysics, with bounce and a little scatter off every peg (the luck).

const BALL_R := 9.0
const DROP_Y := 34.0
const DROPPER_SPEED := 260.0
const PEG_TOP := 86.0
const PEG_ROWS := 8
const PEG_GAP := 52.0
const ROW_GAP := 30.0
const CUP_TOP := 346.0
const CUPS := 7
const CUP_W := 640.0 / CUPS
## each cup's prize floor, outer to centre and back: rarer at the edges
const CUP_TIERS := [Pickups.R.RARE, Pickups.R.UNCOMMON, Pickups.R.COMMON, Pickups.R.COMMON, Pickups.R.COMMON, Pickups.R.UNCOMMON, Pickups.R.RARE]
const NUDGE := 160.0       #px/s sideways
const STEP := 1.0 / 240.0

var tier := 0
var physics := PrizePhysics.new()
var pegs: Array = []       #peg centres
var walls: Array = []      #static segments: cup dividers, the floor, the sides
var cups: Array = []       #prize id per cup
var dropX := 320.0
var lastDir := 1.0
var balls := 3
var nudged := false        #this ball's nudge is spent
var leftover := 0.0
var flash := {}            #cup index -> seconds left of its win flash

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var game := PachinkoDrop.new()
	game.tier = boxTier
	Root.levelRoot.add_child.call_deferred(game)

func build() -> void:
	title("PACHINKO DROP", "Aim, drop, and nudge it once. The outer cups pay best.")
	balls = 3 + int(tier / 2.0)
	physics.bounce = 0.45
	physics.scatter = 60.0
	physics.friction = 0.05
	physics.maxR = BALL_R
	for row in PEG_ROWS:
		var offset := PEG_GAP * 0.5 if row % 2 else 0.0
		var x := 30.0 + offset
		while x < STAGE.x - 20.0:
			pegs.push_back(Vector2(x, PEG_TOP + row * ROW_GAP))
			x += PEG_GAP
	for i in range(1, CUPS): walls.push_back([Vector2(i * CUP_W, CUP_TOP), Vector2(i * CUP_W, STAGE.y), 3.0])
	walls.push_back([Vector2(0, STAGE.y - 8.0), Vector2(STAGE.x, STAGE.y - 8.0), 2.0])
	for i in CUPS: cups.push_back(rollCup(i))
	hints([[["TurnLeft", "TurnRight"], "Aim"], [[ACT], "Drop"], [[REJECT], "Nudge"]])
	updateInfo()

func rollCup(i: int) -> String:
	var floorTier := mini(CUP_TIERS[i] + int(tier / 2.0), Pickups.R.LEGENDARY)
	if floorTier == Pickups.R.COMMON && i == CUPS / 2: return Pickups.openOr("coinstack")
	return Pickups.rollOffer(floorTier, Pickups.NOT_IN_GAMES, cups)

func updateInfo() -> void:
	say("Balls left %d" % balls + ("   -   nudge ready" if not nudged && not physics.bodies.is_empty() else ""))

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept": drop()
		REJECT: nudge()
		"TurnLeft": lastDir = -1.0
		"TurnRight": lastDir = 1.0

func onStageMouse(event: InputEvent) -> void:
	if event is InputEventMouseMotion: dropX = clampf(event.position.x, 20.0, STAGE.x - 20.0)
	elif isClick(event): drop()

func drop() -> void:
	if balls <= 0 || not physics.bodies.is_empty(): return #one ball at a time
	balls -= 1
	nudged = false
	var b := physics.add(Vector2(dropX + randf_range(-1.5, 1.5), DROP_Y), BALL_R)
	PrizePhysics.setVelocity(b, Vector2(0, 40), STEP)
	Transition.sound("clank", -16.0, 1.6)
	updateInfo()

func nudge() -> void:
	if nudged || physics.bodies.is_empty(): return
	nudged = true
	for b in physics.bodies: PrizePhysics.setVelocity(b, PrizePhysics.velocity(b, STEP) + Vector2(lastDir * NUDGE, -40.0), STEP)
	Juice.shake(card, 4.0)
	Transition.sound("thud", -10.0, 1.3)
	updateInfo()

func tick(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("TurnLeft"): dir -= 1.0
	if Input.is_action_pressed("TurnRight"): dir += 1.0
	if live(): dropX = clampf(dropX + dir * DROPPER_SPEED * delta, 20.0, STAGE.x - 20.0)
	for k in flash.keys():
		flash[k] -= delta
		if flash[k] <= 0.0: flash.erase(k)
	leftover = minf(leftover + delta, 0.1)
	var segs := walls.duplicate()
	for p in pegs: segs.push_back([p, p, 4.0])
	while leftover >= STEP:
		leftover -= STEP
		physics.step(STEP, segs)
	for b in physics.bodies.duplicate():
		if b.pos.y > CUP_TOP + 20.0 && PrizePhysics.velocity(b, STEP).length() < 120.0: landed(b)
	if balls <= 0 && physics.bodies.is_empty() && not boardUp: showWinnings()

## A ball came to rest in a cup: it pays that cup's prize now, and the cup refills
func landed(b: Dictionary) -> void:
	physics.bodies.erase(b)
	var i := clampi(int(b.pos.x / CUP_W), 0, CUPS - 1)
	award(cups[i])
	flash[i] = 0.8
	Transition.sound("pop", -4.0)
	cups[i] = rollCup(i)
	updateInfo()

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.05, 0.05, 0.08))
	for p in pegs:
		m.draw_circle(p, 4.0, Color(0.85, 0.82, 0.76))
		m.draw_circle(p - Vector2(1, 1), 1.5, Color(1, 1, 1, 0.8))
	for i in CUPS:
		var r := Rect2(i * CUP_W + 3.0, CUP_TOP, CUP_W - 6.0, STAGE.y - CUP_TOP - 8.0)
		var col := Pickups.rarityColor(Pickups.rarity(cups[i]))
		m.draw_rect(r, Color(col, 0.18 + (0.5 if flash.has(i) else 0.0)))
		HudTheme.icon(m, Pickups.texture(cups[i]), r.get_center() + Vector2(0, -6), 36.0)
		HudTheme.text(m, Vector2(r.get_center().x, r.end.y - 4.0), Pickups.shortName(cups[i]), 11, col, HORIZONTAL_ALIGNMENT_CENTER, 3, HudTheme.OUTLINE, HudTheme.BODY)
	for w in walls: m.draw_line(w[0], w[1], Color(0.6, 0.6, 0.66), w[2] * 2.0)
	#the dropper
	m.draw_rect(Rect2(dropX - 18.0, 10.0, 36.0, 14.0), HudTheme.RIM)
	if physics.bodies.is_empty() && balls > 0:
		m.draw_circle(Vector2(dropX, DROP_Y), BALL_R, Color(0.9, 0.92, 0.96))
		m.draw_dashed_line(Vector2(dropX, DROP_Y + 12.0), Vector2(dropX, PEG_TOP - 8.0), Color(1, 1, 1, 0.25), 2.0, 6.0)
	for b in physics.bodies:
		m.draw_circle(b.pos, BALL_R, Color(0.9, 0.92, 0.96))
		m.draw_circle(b.pos - Vector2(3, 3), 3.0, Color.WHITE)
	for i in balls - (0 if physics.bodies.is_empty() else 0): m.draw_circle(Vector2(STAGE.x - 16.0 - i * 20.0, 17.0), 6.0, Color(0.9, 0.92, 0.96, 0.8))
