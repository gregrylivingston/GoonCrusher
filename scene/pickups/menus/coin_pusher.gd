class_name CoinPusher extends PickupMenu

#Coin Pusher (docs/PICKUPS.md, "Prize games"): the arcade classic, side on. A shelf slides in and out at the
#back, shoving a pile of coins and prizes along the floor toward the ledge at the front. The action key (E)
#drops a coin from a slot that sweeps back and forth over the pile; whatever falls off the ledge is won the
#moment it drops (coins pay run coins, prizes their pickup, the odd bit of junk costs you). Ten coins to
#drop, more in better boxes; REJECT (Q) gives up the rest. Either way the game plays on until the shelf has
#pushed at least once more after the last coin (SETTLE) and nothing has fallen for QUIET seconds, so the last
#coin's prizes always land. The pile runs on PrizePhysics.

const FLOOR_Y := 330.0
const BACK_X := 30.0
const LEDGE_X := 560.0
const SHELF_Y := 280.0     #the shelf's top; it pushes along the floor below
const SHELF_MIN := 40.0    #its front edge, in and out
const SHELF_MAX := 170.0
const SHELF_PERIOD := 2.6
const SLOT_Y := 40.0
const SLOT_MIN := 70.0
const SLOT_MAX := 470.0
const SLOT_SPEED := 170.0
const COIN_R := 11.0
const PRIZE_R := 17.0
const PILE_COINS := 22
const PILE_PRIZES := 6
const PILE_JUNK := 1
const COIN_VALUE := 5      #run coins for a coin off the ledge
const STEP := 1.0 / 240.0
const SETTLE := SHELF_PERIOD + 1.0 #s after the last coin at least
const QUIET := 1.5         #s with nothing falling
const MAX_WAIT := 12.0     #s after the last coin at most

var tier := 0
var physics := PrizePhysics.new()
var shelfX := SHELF_MIN
var shelfT := 0.0
var slotX := SLOT_MIN
var slotDir := 1.0
var coins := 10
var stopping := false
var quietT := 0.0          #seconds since anything last fell
var sinceDrop := 0.0       #seconds since the last coin went in
var leftover := 0.0
var prevShelf := SHELF_MIN

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var game := CoinPusher.new()
	game.tier = boxTier
	Root.levelRoot.add_child.call_deferred(game)

func build() -> void:
	title("COIN PUSHER", "Drop coins on the pile. Whatever goes over the ledge is yours.")
	coins = 10 + tier * 2
	physics.left = BACK_X
	physics.right = STAGE.x + 200.0 #nothing stops the front: over the ledge is the prize
	physics.friction = 0.45
	physics.maxR = PRIZE_R
	var kinds := []
	for i in PILE_COINS: kinds.push_back("coin")
	for i in PILE_PRIZES: kinds.push_back(Pickups.rollOffer(Pickups.R.UNCOMMON if tier < 3 else Pickups.R.RARE, Pickups.NOT_IN_GAMES, kinds))
	for i in PILE_JUNK: kinds.push_back(JUNK.keys().pick_random())
	kinds.shuffle()
	for id in kinds:
		var r := COIN_R if id == "coin" else PRIZE_R
		var b := physics.add(Vector2(randf_range(SHELF_MAX + 20.0, LEDGE_X - 60.0), randf_range(180.0, FLOOR_Y - r)), r, 0.8 if id == "coin" else 1.2)
		b["id"] = id
	for i in int(1.5 / STEP): physics.step(STEP, segments(Vector2.ZERO))
	hints([[[ACT], "Drop a coin"], [[REJECT], "Stop dropping"]])
	updateInfo()

func updateInfo() -> void:
	say("Coins to drop %d" % coins if coins > 0 else "Out of coins: the shelf pushes once more...")

## The floor (to the ledge), the back wall and the shelf; `shelfMove` is how far the shelf moved this step
func segments(shelfMove: Vector2) -> Array:
	return [
		[Vector2(BACK_X, FLOOR_Y), Vector2(LEDGE_X, FLOOR_Y), 2.0],
		[Vector2(shelfX, SHELF_Y), Vector2(shelfX, FLOOR_Y - 2.0), 3.0, shelfMove, shelfMove],
		[Vector2(BACK_X, SHELF_Y), Vector2(shelfX, SHELF_Y), 3.0, shelfMove, shelfMove],
	]

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept": dropCoin()
		REJECT: cashOut()

func onStageMouse(event: InputEvent) -> void:
	if isClick(event): dropCoin()

func dropCoin() -> void:
	if coins <= 0 || stopping: return
	coins -= 1
	sinceDrop = 0.0
	quietT = 0.0
	var b := physics.add(Vector2(slotX, SLOT_Y + 14.0), COIN_R, 0.8)
	b["id"] = "coin"
	b["mine"] = true
	Transition.sound("clank", -16.0, 1.8)
	updateInfo()

## No more coins: the pile plays out and the game ends by itself
func cashOut() -> void:
	if coins <= 0: return
	coins = 0
	sinceDrop = 0.0
	updateInfo()

func finish() -> void:
	if boardUp: return
	stopping = true
	showWinnings()

func tick(delta: float) -> void:
	if stopping: return
	slotX += slotDir * SLOT_SPEED * delta
	if slotX >= SLOT_MAX: slotDir = -1.0
	elif slotX <= SLOT_MIN: slotDir = 1.0
	leftover = minf(leftover + delta, 0.1)
	while leftover >= STEP:
		leftover -= STEP
		shelfT += STEP
		prevShelf = shelfX
		shelfX = lerpf(SHELF_MIN, SHELF_MAX, 0.5 - 0.5 * cos(shelfT / SHELF_PERIOD * TAU))
		physics.step(STEP, segments(Vector2(shelfX - prevShelf, 0)))
	quietT += delta
	sinceDrop += delta
	for b in physics.bodies.duplicate():
		if b.pos.y > STAGE.y + 30.0: fell(b)
	if coins <= 0 && sinceDrop >= SETTLE && (quietT >= QUIET || sinceDrop >= MAX_WAIT): finish()

## Over the ledge: won now (the fall was the show)
func fell(b: Dictionary) -> void:
	physics.bodies.erase(b)
	quietT = 0.0
	if b.pos.x < LEDGE_X: return #down the back somehow: lost
	if b.id == "coin": awardCoins(COIN_VALUE)
	elif isJunk(b.id): awardJunk(b.id)
	else: award(b.id)
	Transition.sound("pop", -6.0, 1.2)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.07, 0.055, 0.05))
	m.draw_rect(Rect2(BACK_X, FLOOR_Y, LEDGE_X - BACK_X, 8.0), Color(0.35, 0.3, 0.26))
	m.draw_rect(Rect2(LEDGE_X, FLOOR_Y + 8.0, STAGE.x - LEDGE_X, STAGE.y), Color(0.02, 0.015, 0.012))
	HudTheme.text(m, Vector2((LEDGE_X + STAGE.x) * 0.5, FLOOR_Y + 40.0), "WIN", 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, Vector2((LEDGE_X + STAGE.x) * 0.5, FLOOR_Y + 62.0), "▼", 18, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 3)
	#the shelf
	m.draw_rect(Rect2(BACK_X - 30.0, SHELF_Y, shelfX - BACK_X + 30.0, FLOOR_Y - SHELF_Y - 2.0), Color(0.42, 0.36, 0.3))
	m.draw_rect(Rect2(shelfX - 6.0, SHELF_Y, 6.0, FLOOR_Y - SHELF_Y - 2.0), HudTheme.RIM)
	for b in physics.bodies:
		if b.id == "coin":
			m.draw_circle(b.pos, COIN_R, Color(0.95, 0.75, 0.25) if not b.get("mine", false) else Color(1.0, 0.85, 0.4))
			m.draw_arc(b.pos, COIN_R - 3.0, 0.0, TAU, 16, Color(0.7, 0.5, 0.1), 2.0)
		else:
			var s: float = b.r * 2.3
			m.draw_set_transform(b.pos, b.rot, Vector2.ONE)
			m.draw_texture_rect(ClawCrane.textureOf(b.id), Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), false, JUNK_TINT if isJunk(b.id) else Color.WHITE)
			m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	#the coin slot
	m.draw_rect(Rect2(0, SLOT_Y - 12.0, STAGE.x, 6.0), Color(0.35, 0.33, 0.32))
	m.draw_rect(Rect2(slotX - 20.0, SLOT_Y - 18.0, 40.0, 18.0), HudTheme.RIM)
	if coins > 0: m.draw_circle(Vector2(slotX, SLOT_Y + 8.0), COIN_R, Color(1.0, 0.85, 0.4, 0.6))
	HudTheme.text(m, Vector2(STAGE.x - 14.0, 26.0), "x%d" % coins, 18, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 4)
