class_name GoonPress extends PickupMenu

#Goon Press (docs/PICKUPS.md, "Prize games"): a fast conveyor carries goons, prize crates and the odd bomb
#under a hydraulic press, bunched up or spread out at random. You get PRESSES slams and they are your prizes:
#the action key (E) slams (a short wind-up, so you lead the target) and everything under the ram is hit at
#once, so a slam can catch nothing, one thing or a few. A crate bursts and pays its prize, a goon is crushed
#flat and drops a coin, a bomb costs health (junk). A (held) slows the belt while its brake lasts, and the
#belt speeds up after each slam. REJECT (Q) stops early. Better boxes put more crates and fewer bombs on it.

const BELT_Y := 318.0
const PRESS_X := 320.0
const RAM_W := 84.0
const HIT_REACH := 44.0    #an item whose middle is this close to the press's is hit
const START_SPEED := 250.0
const SPEEDUP := 0.15      #per slam
const BRAKE := 1.5         #seconds of slow belt
const WINDUP := 0.12
const SLAM := 0.08
const HOLD := 0.06
const RAISE := 0.25
const PRESSES := 3
const GOONS := ["grunt", "goonling", "rat", "gremlin", "skink", "yipper", "bandit", "spiker"]
const ITEM_SIZE := 54.0

var tier := 0
var items: Array = []      #{kind: goon/crate/bomb, x, goon, id, hit}
var speed := START_SPEED
var brake := BRAKE
var ramT := -1.0           #seconds into a slam, -1 when idle
var presses := PRESSES
var crushed := 0
var nextX := 0.0           #where the next item joins the belt
var ended := false
var textures := {}

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var game := GoonPress.new()
	game.tier = boxTier
	Root.levelRoot.add_child.call_deferred(game)

func build() -> void:
	title("GOON PRESS", "Three slams. Whatever is under the press is yours.")
	nextX = STAGE.x + 30.0
	while nextX < STAGE.x * 2.0: nextX = addItem(nextX)
	hints([[[ACT], "Slam"], [["TurnLeft"], "Slow the belt"], [[REJECT], "Stop"]])
	updateInfo()

## Puts the next item on the belt at x and returns where the one after it goes: often bunched, often far apart
func addItem(x: float) -> float:
	var roll := randf()
	var crate := 0.28 + 0.03 * tier
	var bomb := 0.16 - (0.06 if tier >= 3 else 0.0)
	var kind := "crate" if roll < crate else ("bomb" if roll < crate + bomb else "goon")
	var item := {"kind": kind, "x": x, "hit": false}
	if kind == "goon": item["goon"] = GOONS.pick_random()
	if kind == "crate": item["id"] = Pickups.rollOffer(Pickups.R.UNCOMMON if tier < 3 else Pickups.R.RARE, Pickups.NOT_IN_GAMES, [])
	items.push_back(item)
	return x + (randf_range(30.0, 56.0) if randf() < 0.4 else randf_range(80.0, 300.0))

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

func goonTexture(goon: String, flat: bool) -> Texture2D:
	return texture("res://scene/enemy/goons/%s/art/%s_%s.png" % [goon, goon, "decal" if flat else "idle0"])

func updateInfo() -> void:
	say("Slams left %d" % presses)

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept": slam()
		REJECT: finish()

func onStageMouse(event: InputEvent) -> void:
	if isClick(event): slam()

func slam() -> void:
	if ramT >= 0.0 || ended || presses <= 0: return
	ramT = 0.0
	presses -= 1
	updateInfo()
	Transition.sound("hiss", -12.0, 1.3)

func tick(delta: float) -> void:
	if ended: return
	var slow := live() && Input.is_action_pressed("TurnLeft") && brake > 0.0
	if slow: brake = maxf(0.0, brake - delta)
	var v := speed * (0.5 if slow else 1.0)
	for item in items: item.x -= v * delta
	nextX -= v * delta
	while nextX < STAGE.x + 40.0: nextX = addItem(nextX)
	if ramT >= 0.0:
		var before := ramT
		ramT += delta
		if before < WINDUP + SLAM && ramT >= WINDUP + SLAM: hit()
		if ramT >= WINDUP + SLAM + HOLD + RAISE:
			ramT = -1.0
			if presses <= 0: finish()
	for item in items.duplicate():
		if item.x < -60.0: items.erase(item)

## The ram is down: everything under it is hit
func hit() -> void:
	Juice.shake(card, 4.0)
	Transition.sound("thud", -4.0, 0.9)
	speed *= 1.0 + SPEEDUP
	var any := false
	for item in items:
		if item.hit || absf(item.x - PRESS_X) > HIT_REACH: continue
		item.hit = true
		any = true
		match item.kind:
			"goon":
				crushed += 1
				award(Pickups.openOr("coin"))
			"crate":
				award(item.id)
				Transition.sound("pop", -4.0)
			"bomb":
				awardJunk("junk:bomb")
	if not any: say("Missed!   Slams left %d" % presses)
	else: updateInfo()

func finish() -> void:
	if ended: return
	ended = true
	showWinnings("" if not winnings.is_empty() else "NOTHING THIS TIME")

## Where the ram's face is: up at rest, a little higher in the wind-up, down on the belt in the slam
func ramBottom() -> float:
	var rest := 150.0
	var down := BELT_Y - 4.0
	if ramT < 0.0: return rest
	if ramT < WINDUP: return rest - 14.0 * ramT / WINDUP
	if ramT < WINDUP + SLAM: return lerpf(rest - 14.0, down, (ramT - WINDUP) / SLAM)
	if ramT < WINDUP + SLAM + HOLD: return down
	return lerpf(down, rest, (ramT - WINDUP - SLAM - HOLD) / RAISE)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.07, 0.06, 0.055))
	#the belt
	m.draw_rect(Rect2(0, BELT_Y, STAGE.x, 22.0), Color(0.16, 0.14, 0.13))
	var shift := fposmod(-Time.get_ticks_msec() / 1000.0 * speed, 40.0)
	for i in 18: m.draw_rect(Rect2(shift + i * 40.0 - 40.0, BELT_Y + 6.0, 20.0, 8.0), Color(0.24, 0.21, 0.19))
	for item in items:
		var c := Vector2(item.x, BELT_Y - ITEM_SIZE * 0.5)
		match item.kind:
			"goon":
				var tex := goonTexture(item.goon, item.hit)
				if tex: HudTheme.icon(m, tex, c + (Vector2(0, ITEM_SIZE * 0.3) if item.hit else Vector2(0, ITEM_SIZE * 0.1)), ITEM_SIZE * (2.2 if item.hit else 1.9), Color.WHITE) #the art has wide margins
				else: m.draw_circle(c, ITEM_SIZE * 0.25, Color("7aa35a"))
			"crate":
				if item.hit: HudTheme.icon(m, Pickups.texture(item.id), c, ITEM_SIZE * 0.7)
				else: HudTheme.icon(m, Pickups.texture("crate"), c, ITEM_SIZE)
			"bomb":
				if not item.hit: HudTheme.icon(m, PickupMenu.junkTexture("junk:bomb"), c, ITEM_SIZE * 0.85, PickupMenu.JUNK_TINT)
	#the press
	var face := ramBottom()
	m.draw_rect(Rect2(PRESS_X - 10.0, 0, 20.0, face - 30.0), Color(0.45, 0.44, 0.46))
	m.draw_rect(Rect2(PRESS_X - RAM_W * 0.5, face - 30.0, RAM_W, 30.0), HudTheme.RIM)
	ShutterDoor.drawHazard(m, Rect2(PRESS_X - RAM_W * 0.5, face - 10.0, RAM_W, 8.0))
	m.draw_rect(Rect2(PRESS_X - RAM_W * 0.5 - 6.0, 6.0, RAM_W + 12.0, 24.0), Color(0.3, 0.29, 0.3))
	#the slams left and the brake
	for i in PRESSES:
		var pip := Vector2(24.0 + i * 30.0, 22.0)
		m.draw_circle(pip, 10.0, HudTheme.GOLD if i < presses else Color(1, 1, 1, 0.12))
	HudTheme.text(m, Vector2(16, 52), "SLAMS", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var bb := Rect2(STAGE.x - 136, 16, 120, 12)
	HudTheme.bar(m, bb, brake / BRAKE, HudTheme.SKY)
	HudTheme.text(m, bb.position + Vector2(0, 30), "BRAKE", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 3)
