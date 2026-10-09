class_name GoonPress extends PickupMenu

#Goon Press (docs/PICKUPS.md, "Prize games"): a conveyor carries goons, prize crates and the odd bomb under a
#hydraulic press. The action key (E) slams it (a short wind-up, so you lead the target): a goon is crushed
#flat and fills the crush meter, a crate bursts and pays its prize at once, a bomb costs health (junk). A
#(held) slows the belt while its brake lasts; the belt speeds up as it runs. REJECT (Q) stops early. Crush
#CRUSH_GOAL goons and a bonus crate pays at the end. Better boxes put more crates and fewer bombs on the belt.

const BELT_Y := 318.0
const PRESS_X := 320.0
const RAM_W := 84.0
const HIT_REACH := 40.0
const START_SPEED := 120.0
const SPEEDUP := 0.05      #per item that leaves the belt
const BRAKE := 2.5         #seconds of slow belt
const WINDUP := 0.12
const SLAM := 0.08
const HOLD := 0.06
const RAISE := 0.25
const CRUSH_GOAL := 8
const ITEMS := 18
const GOONS := ["grunt", "goonling", "rat", "gremlin", "skink", "yipper", "bandit", "spiker"]
const ITEM_SIZE := 58.0

var tier := 0
var items: Array = []      #{kind: goon/crate/bomb, x, goon, id, hit}
var speed := START_SPEED
var brake := BRAKE
var ramT := -1.0           #seconds into a slam, -1 when idle
var crushed := 0
var cracked := 0
var ended := false
var textures := {}

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var game := GoonPress.new()
	game.tier = boxTier
	Root.levelRoot.add_child.call_deferred(game)

func build() -> void:
	title("GOON PRESS", "Crush the goons, crack the crates, miss the bombs.")
	var crates := 4 + int(tier / 2.0)
	var bombs := 2 - (1 if tier >= 3 else 0)
	var kinds := []
	for i in ITEMS: kinds.push_back("crate" if i < crates else ("bomb" if i < crates + bombs else "goon"))
	kinds.shuffle()
	var x := STAGE.x + 60.0
	for kind in kinds:
		var item := {"kind": kind, "x": x, "hit": false}
		if kind == "goon": item["goon"] = GOONS.pick_random()
		if kind == "crate": item["id"] = Pickups.rollOffer(Pickups.R.UNCOMMON if tier < 3 else Pickups.R.RARE, Pickups.NOT_IN_GAMES, [])
		items.push_back(item)
		x += randf_range(70.0, 135.0)
	hints([[[ACT], "Slam"], [["TurnLeft"], "Slow the belt"], [[REJECT], "Stop"]])
	updateInfo()

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

func goonTexture(goon: String, flat: bool) -> Texture2D:
	return texture("res://scene/enemy/goons/%s/art/%s_%s.png" % [goon, goon, "decal" if flat else "idle0"])

func updateInfo() -> void:
	say("Crushed %d / %d   -   Crates cracked %d" % [crushed, CRUSH_GOAL, cracked])

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept": slam()
		REJECT: finish()

func onStageMouse(event: InputEvent) -> void:
	if isClick(event): slam()

func slam() -> void:
	if ramT >= 0.0 || ended: return
	ramT = 0.0
	Transition.sound("hiss", -12.0, 1.3)

func tick(delta: float) -> void:
	if ended: return
	var slow := live() && Input.is_action_pressed("TurnLeft") && brake > 0.0
	if slow: brake = maxf(0.0, brake - delta)
	var v := speed * (0.5 if slow else 1.0)
	for item in items: item.x -= v * delta
	if ramT >= 0.0:
		var before := ramT
		ramT += delta
		if before < WINDUP + SLAM && ramT >= WINDUP + SLAM: hit()
		if ramT >= WINDUP + SLAM + HOLD + RAISE: ramT = -1.0
	for item in items.duplicate():
		if item.x < -60.0:
			items.erase(item)
			speed *= 1.0 + SPEEDUP
	if items.is_empty(): finish()

## The ram is down: everything under it is hit
func hit() -> void:
	Juice.shake(card, 4.0)
	Transition.sound("thud", -4.0, 0.9)
	for item in items:
		if item.hit || absf(item.x - PRESS_X) > HIT_REACH: continue
		item.hit = true
		match item.kind:
			"goon":
				crushed += 1
			"crate":
				cracked += 1
				award(item.id)
				Transition.sound("pop", -4.0)
			"bomb":
				awardJunk("junk:bomb")
	updateInfo()

func finish() -> void:
	if ended: return
	ended = true
	if crushed >= CRUSH_GOAL: award(Pickups.rollOffer(Pickups.R.RARE, Pickups.NOT_IN_GAMES, [])) #the bonus crate
	showWinnings("CRUSHED %d" % crushed if winnings.is_empty() else "")

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
				if tex: HudTheme.icon(m, tex, c + (Vector2(0, ITEM_SIZE * 0.35) if item.hit else Vector2.ZERO), ITEM_SIZE * (1.2 if item.hit else 1.0), Color.WHITE)
				else: m.draw_circle(c, 20.0, Color("7aa35a"))
			"crate":
				if item.hit: HudTheme.icon(m, Pickups.texture(item.id), c, 44.0)
				else: HudTheme.icon(m, Pickups.texture("crate"), c, ITEM_SIZE)
			"bomb":
				if not item.hit: HudTheme.icon(m, PickupMenu.junkTexture("junk:bomb"), c, ITEM_SIZE * 0.85, PickupMenu.JUNK_TINT)
	#the press
	var face := ramBottom()
	m.draw_rect(Rect2(PRESS_X - 10.0, 0, 20.0, face - 30.0), Color(0.45, 0.44, 0.46))
	m.draw_rect(Rect2(PRESS_X - RAM_W * 0.5, face - 30.0, RAM_W, 30.0), HudTheme.RIM)
	ShutterDoor.drawHazard(m, Rect2(PRESS_X - RAM_W * 0.5, face - 10.0, RAM_W, 8.0))
	m.draw_rect(Rect2(PRESS_X - RAM_W * 0.5 - 6.0, 6.0, RAM_W + 12.0, 24.0), Color(0.3, 0.29, 0.3))
	#the crush meter and the brake
	var bar := Rect2(16, 16, 180, 12)
	HudTheme.bar(m, bar, minf(1.0, float(crushed) / CRUSH_GOAL), HudTheme.OK if crushed >= CRUSH_GOAL else HudTheme.GOLD)
	HudTheme.text(m, bar.position + Vector2(0, 30), "CRUSH %d / %d" % [crushed, CRUSH_GOAL], 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var bb := Rect2(STAGE.x - 136, 16, 120, 12)
	HudTheme.bar(m, bb, brake / BRAKE, HudTheme.SKY)
	HudTheme.text(m, bb.position + Vector2(0, 30), "BRAKE", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 3)
