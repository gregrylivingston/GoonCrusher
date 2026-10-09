class_name PrizeVault extends PickupMenu

#The Vault, the strongest gift box game (CrushPrizes): crack a three-number combination. Steer turns the
#dial (tap for one number, hold to spin it); the listening gauge rises as the dial nears the next number
#and the lock clicks when it is on it. Accelerate tries the number: right, and that tumbler falls and opens a
#drawer, whose prize is credited at once; wrong, and the alarm takes a strike. Three strikes (four from a
#Silver box) and the vault locks with what you have, or a consolation prize if no drawer opened. The drawers
#hold Rare or better (the third Epic or better); Gold and Diamond boxes raise both and let the dial be one
#number off.

const DIAL := 40           #numbers on the dial
const NUMBERS := 3
const HEAR := 7.0          #the gauge starts to rise this many numbers away
const TURN_START := 6.0    #numbers per second once a held Steer starts to spin the dial
const TURN_MAX := 26.0
const HOLD_DELAY := 0.25
const DIAL_C := Vector2(205, 222)
const DIAL_R := 150.0

var tier := 0
var combo: Array = []      #the numbers, in order
var cracked := 0           #tumblers open
var contents: Array = []   #one prize per drawer
var strikes := 0
var maxStrikes := 3
var tolerance := 0
var dial := 0.0            #shown position; snaps to whole numbers at rest
var turnHeld := 0.0
var turnDir := 0
var lastNumber := 0
var phase := "crack"       #crack, done
var alarm := 0.0           #the red flash, 0..1
var click := 0.0           #the lock's click, 0..1
var dragFrom := -1.0
var dragMoved := 0.0

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var vault := PrizeVault.new()
	vault.tier = boxTier
	Root.levelRoot.add_child.call_deferred(vault)

static func minTierFor(boxTier: int) -> int:
	return mini(Pickups.R.RARE + boxTier / 3, Pickups.R.LEGENDARY)

## Numbers apart on the dial, either way round
static func gap(a: int, b: int) -> int:
	var d := posmod(a - b, DIAL)
	return mini(d, DIAL - d)

## The listening gauge, 0..1, for the dial at `number` with the tumbler's number `secret`
static func listen(at: int, secret: int) -> float:
	return clampf(1.0 - gap(at, secret) / HEAR, 0.0, 1.0)

func build() -> void:
	maxStrikes = 3 + (1 if tier >= 2 else 0)
	tolerance = 1 if tier >= 3 else 0
	var floorTier := minTierFor(tier)
	for i in NUMBERS:
		var n := randi() % DIAL
		while combo.any(func(c): return gap(c, n) < 6): n = randi() % DIAL
		combo.push_back(n)
		contents.push_back(Pickups.rollOffer(mini(floorTier + (1 if i == NUMBERS - 1 else 0), Pickups.R.LEGENDARY), Pickups.NOT_IN_GAMES, contents))
	dial = randi() % DIAL
	lastNumber = number()
	title("THE VAULT", "Gift box: crack the combination. Listen for the click.")
	hints([[["TurnLeft", "TurnRight"], "Turn the dial"], [["Accelerate"], "Try this number"]])
	updateInfo()

func number() -> int:
	return posmod(int(round(dial)), DIAL)

func updateInfo() -> void:
	if phase == "crack": say("Number %d of %d   -   Strikes %d of %d" % [cracked + 1, NUMBERS, strikes, maxStrikes])

func onAction(action: String) -> void:
	match action:
		"TurnLeft", "TurnRight":
			if phase == "crack": turn(-1 if action == "TurnLeft" else 1)
		"Accelerate", "ui_accept":
			if phase == "crack": tryNumber()

func onStageMouse(event: InputEvent) -> void:
	if phase != "crack": return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: turn(1)
			MOUSE_BUTTON_WHEEL_DOWN: turn(-1)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					dragFrom = event.position.x
					dragMoved = 0.0
				else:
					if dragFrom >= 0.0 && dragMoved < 6.0: tryNumber()
					dragFrom = -1.0
					dial = round(dial)
	elif event is InputEventMouseMotion && dragFrom >= 0.0:
		dragMoved += absf(event.relative.x)
		dial += event.relative.x / 9.0
		heard()

## One number round (a tap)
func turn(dir: int) -> void:
	dial = round(dial) + dir
	turnDir = dir
	turnHeld = 0.0
	heard()

func tick(delta: float) -> void:
	alarm = maxf(0.0, alarm - delta * 2.0)
	click = maxf(0.0, click - delta * 5.0)
	if phase != "crack": return
	var dir := 0
	if Input.is_action_pressed("TurnLeft") || Input.is_action_pressed("ui_left"): dir -= 1
	if Input.is_action_pressed("TurnRight") || Input.is_action_pressed("ui_right"): dir += 1
	if dir != 0 && dir == turnDir:
		turnHeld += delta
		if turnHeld > HOLD_DELAY:
			dial += dir * minf(TURN_MAX, TURN_START + (turnHeld - HOLD_DELAY) * 30.0) * delta
			heard()
	elif dir == 0 && turnDir != 0:
		turnDir = 0
		dial = round(dial)

## The dial moved onto a new number: the lock clicks when it is the tumbler's
func heard() -> void:
	var n := number()
	if n == lastNumber: return
	lastNumber = n
	if gap(n, combo[cracked]) == 0:
		click = 1.0
		Transition.sound("clank", -16.0, 2.2)
		Settings.vibrate(0.15, 0.0, 0.05)

func tryNumber() -> void:
	dial = round(dial)
	if gap(number(), combo[cracked]) <= tolerance:
		Transition.sound("thud", -4.0, 1.2)
		award(contents[cracked])
		cracked += 1
		if cracked >= NUMBERS: finish("VAULT CRACKED!")
		else: updateInfo()
		return
	strikes += 1
	alarm = 1.0
	Juice.shake(card, 5.0)
	Transition.sound("screech", -12.0, 1.6)
	if strikes >= maxStrikes: finish()
	else: updateInfo()

func finish(heading := "") -> void:
	phase = "done"
	if cracked == 0: #the alarm went before any drawer: a consolation prize
		award(Pickups.rollOffer(Pickups.R.UNCOMMON, Pickups.NOT_IN_GAMES, []))
		heading = "ALARM! A CONSOLATION"
	elif heading == "": heading = "ALARM! YOU GOT OUT WITH"
	showWinnings(heading)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.07, 0.07, 0.075))
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(1, 0.15, 0.1, 0.25 * alarm))
	#the dial: a steel ring that turns under a fixed index mark
	var c := DIAL_C
	m.draw_circle(c, DIAL_R + 16.0, Color(0.2, 0.2, 0.22))
	m.draw_circle(c, DIAL_R, Color(0.3, 0.31, 0.33))
	m.draw_arc(c, DIAL_R, 0, TAU, 64, Color(0.55, 0.56, 0.6), 3.0, true)
	for i in DIAL:
		var a := -PI / 2 + (i - dial) * TAU / DIAL
		var major := i % 5 == 0
		m.draw_line(c + Vector2.from_angle(a) * (DIAL_R - (18.0 if major else 9.0)), c + Vector2.from_angle(a) * (DIAL_R - 2.0), Color(0.92, 0.9, 0.86), 3.0 if major else 1.5)
		if major: HudTheme.text(m, c + Vector2.from_angle(a) * (DIAL_R - 34.0) + Vector2(0, 6), str(i), 16, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 3)
	m.draw_circle(c, 46.0, Color(0.16, 0.16, 0.18))
	m.draw_arc(c, 46.0, 0, TAU, 32, HudTheme.RIM, 3.0, true)
	HudTheme.text(m, c + Vector2(0, 11), "%02d" % number(), 30, HudTheme.GOLD if click <= 0.0 else HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 5)
	m.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -DIAL_R - 22), c + Vector2(12, -DIAL_R - 22), c + Vector2(0, -DIAL_R - 4)]), HudTheme.GOLD.lerp(Color.WHITE, click))
	#the listening gauge
	var g := Vector2(510, 128)
	HudTheme.text(m, g + Vector2(0, -96), "LISTEN", 14, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)
	m.draw_arc(g, 76.0, PI, TAU, 32, HudTheme.TRACK, 12.0, true)
	var level := listen(number(), combo[mini(cracked, NUMBERS - 1)]) if phase == "crack" else 0.0
	if level > 0.0: m.draw_arc(g, 76.0, PI, PI + PI * level, 32, HudTheme.OK.lerp(HudTheme.GOLD, level), 12.0, true)
	m.draw_line(g, g + Vector2.from_angle(PI + PI * level) * 66.0, HudTheme.TEXT.lerp(Color.WHITE, click), 4.0, true)
	m.draw_circle(g, 7.0, HudTheme.RIM)
	#the alarm's strike lamps
	for i in maxStrikes:
		var p := Vector2(g.x - (maxStrikes - 1) * 18.0 + i * 36.0, g.y + 30.0)
		m.draw_circle(p, 11.0, HudTheme.OUTLINE)
		m.draw_circle(p, 8.0, HudTheme.BAD if i < strikes else Color(0.3, 0.1, 0.08))
	#the drawers, one per tumbler
	for i in NUMBERS:
		var r := Rect2(410, 200 + i * 66.0, 200, 56)
		var isOpen := i < cracked
		var id: String = contents[i]
		var col := Pickups.rarityColor(Pickups.rarity(id)) if isOpen else Color(0.45, 0.46, 0.5)
		m.draw_rect(r, Color(0.16, 0.16, 0.18))
		m.draw_rect(r, col, false, 3.0)
		if isOpen:
			HudTheme.icon(m, Pickups.texture(id), r.position + Vector2(30, 28), 40.0)
			HudTheme.text(m, r.position + Vector2(58, 34), Pickups.shortName(id).to_upper(), 16, col, HORIZONTAL_ALIGNMENT_LEFT, 4)
		else:
			var floorTier := minTierFor(tier) + (1 if i == NUMBERS - 1 else 0)
			HudTheme.icon(m, HudTheme.LOCK_ICON, r.position + Vector2(30, 28), 28.0)
			HudTheme.text(m, r.position + Vector2(58, 26), "DRAWER %d" % (i + 1), 15, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 4)
			HudTheme.text(m, r.position + Vector2(58, 45), "%s or better" % Pickups.RARITY_NAMES[mini(floorTier, Pickups.R.LEGENDARY)], 12, Pickups.rarityColor(mini(floorTier, Pickups.R.LEGENDARY)), HORIZONTAL_ALIGNMENT_LEFT, 3, HudTheme.OUTLINE, HudTheme.BODY)
