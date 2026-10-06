class_name ClawCrane extends PickupMenu

#The Claw Crane: steer the claw over a heap of prizes and drop it with Accelerate. A prize can slip on
#the way up (less often with Dice). One grab is free; run coins buy more.

const W := 640.0
const H := 420.0
const CLAW_SPEED := 320.0
const DROP_TIME := 0.8
const LIFT_TIME := 1.0
const EXTRA_GRAB := 150

var machine := Control.new()
var info := Label.new()
var prizes: Array = []    #{id, pos}
var clawX := W * 0.5
var phase := "aim"        #aim, drop, lift, deliver, done
var t := 0.0
var held = null           #the prize in the claw
var slipAt := -1.0        #lift progress where the prize slips, or -1
var grabs := 1
var won: Array = []

static func open() -> void:
	if not is_instance_valid(Root.levelRoot): return
	Root.levelRoot.add_child(ClawCrane.new())

func build() -> void:
	title("CLAW CRANE", "Line up the claw and drop it.")
	machine.custom_minimum_size = Vector2(W, H)
	machine.draw.connect(drawMachine)
	body.add_child(machine)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(info)
	hints([[["TurnLeft", "TurnRight"], "Move"], [["Accelerate"], "Drop / Leave"], [["Brake"], "Another grab  (%d coins)" % EXTRA_GRAB]])
	for i in 14: #mostly Uncommon or better, padded with coin stacks
		var id := Pickups.rollAtLeast(Pickups.R.UNCOMMON) if i < 10 else "coinstack"
		if id in PickupDeal.NEVER: id = "coinstack"
		prizes.push_back({"id": id, "pos": Vector2(randf_range(60.0, W - 60.0), randf_range(H - 120.0, H - 40.0))})
	prizes.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	updateInfo()

func updateInfo() -> void:
	info.text = "Grabs left %d   -   Coins %d" % [grabs, runCoins()] if phase != "done" else "Won: %s" % (", ".join(won.map(func(id): return Pickups.displayName(id))) if not won.is_empty() else "nothing")

func onAction(action: String) -> void:
	match action:
		"Accelerate", "ui_accept":
			if phase == "aim" && grabs > 0: startDrop()
			elif phase == "done" || (phase == "aim" && grabs <= 0): finish()
		"Brake":
			if (phase == "aim" || phase == "done") && grabs <= 0 && runCoins() >= EXTRA_GRAB:
				Root.playerCar.coin -= EXTRA_GRAB
				grabs += 1
				phase = "aim"
				updateInfo()
		"ui_cancel":
			if phase == "aim" || phase == "done": finish()

func startDrop() -> void:
	grabs -= 1
	phase = "drop"
	t = 0.0
	updateInfo()

func tick(delta: float) -> void:
	t += delta
	match phase:
		"aim":
			var dir := 0.0
			if Input.is_action_pressed("TurnLeft") || Input.is_action_pressed("ui_left"): dir -= 1.0
			if Input.is_action_pressed("TurnRight") || Input.is_action_pressed("ui_right"): dir += 1.0
			clawX = clampf(clawX + dir * CLAW_SPEED * delta, 50.0, W - 50.0)
		"drop":
			if t >= DROP_TIME:
				grab()
				phase = "lift"
				t = 0.0
		"lift":
			if held != null && slipAt >= 0.0 && t / LIFT_TIME >= slipAt:
				held.pos = Vector2(clawX, H - 50.0)
				prizes.push_back(held)
				held = null
				info.text = "Slipped!"
			if t >= LIFT_TIME:
				phase = "deliver"
				t = 0.0
		"deliver":
			clawX = move_toward(clawX, 50.0, 700.0 * delta)
			if clawX <= 50.0:
				if held != null:
					won.push_back(held.id)
					PickupEffects.collect(Root.playerCar, held.id, Root.playerCar.global_position)
					held = null
				phase = "aim" if grabs > 0 else "done"
				updateInfo()
	machine.queue_redraw()

## The claw takes the prize nearest under it, if any is close enough.
func grab() -> void:
	var best = null
	var bestD := 55.0
	for p in prizes:
		var d := absf(p.pos.x - clawX)
		if d < bestD:
			bestD = d
			best = p
	if best == null: return
	prizes.erase(best)
	held = best
	var dice: float = Root.playerCar.luck if is_instance_valid(Root.playerCar) else 0.0
	var slip := clampf(0.3 - dice * 0.002 + bestD / 55.0 * 0.25, 0.08, 0.55) #off-centre grabs slip more
	slipAt = randf_range(0.3, 0.9) if randf() < slip else -1.0

func finish() -> void:
	close()

func clawY() -> float:
	match phase:
		"drop": return lerpf(40.0, H - 70.0, minf(1.0, t / DROP_TIME))
		"lift": return lerpf(H - 70.0, 40.0, minf(1.0, t / LIFT_TIME))
	return 40.0

func drawMachine() -> void:
	var m := machine
	m.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.08, 0.06, 0.05))
	m.draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), HudTheme.RIM, false, 4.0)
	m.draw_rect(Rect2(Vector2(0, 0), Vector2(100, 24)), Color(0.2, 0.16, 0.12))
	HudTheme.text(m, Vector2(50, 18), "PRIZE", 14, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0)
	for p in prizes:
		m.draw_circle(p.pos, 34.0, Color(Pickups.rarityColor(Pickups.rarity(p.id)), 0.25))
		m.draw_texture_rect(Pickups.texture(p.id), Rect2(p.pos - Vector2(30, 30), Vector2(60, 60)), false)
	var y := clawY()
	m.draw_line(Vector2(clawX, 0), Vector2(clawX, y), Color(0.7, 0.72, 0.76), 4.0)
	m.draw_rect(Rect2(Vector2(clawX - 20, y - 12), Vector2(40, 18)), Color(0.66, 0.69, 0.74))
	var open := 22.0 if held == null && phase != "lift" else 10.0
	for side in [-1.0, 1.0]:
		m.draw_polyline(PackedVector2Array([Vector2(clawX + side * 14, y + 4), Vector2(clawX + side * open * 1.4, y + 24), Vector2(clawX + side * open * 0.6, y + 44)]), Color(0.75, 0.78, 0.82), 6.0)
	if held != null: m.draw_texture_rect(Pickups.texture(held.id), Rect2(Vector2(clawX - 28, y + 18), Vector2(56, 56)), false)
