class_name PrizeWheelMenu extends PickupMenu

#The Prize Wheel as a gift box game (CrushPrizes): Accelerate spins it and the wedge under the pointer
#pays, credited the moment the wheel stops. Its wedges are the world wheel's (WorldProps.PrizeWheel); a
#higher box tier turns the busts into coins (Bronze), doubles the coin wedges (Silver), swaps the Wrench
#for a Gem (Gold) and the Nitro for a second Jackpot (Diamond). Accelerate again leaves.

const R := 190.0
const SPIN_MIN := 16.0  #rad/s at the start of a spin
const SPIN_MAX := 22.0
const SPIN_DECAY := 1.5 #per second, exponential: a spin lasts about 4 s
const STOP_BELOW := 0.05

var tier := 0
var wheel := Control.new()
var info := Label.new()
var wedges: Array = []
var angle := 0.0
var spin := 0.0
var phase := "ready" #ready, spinning, done
var result := ""

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var menu := PrizeWheelMenu.new()
	menu.tier = boxTier
	Root.levelRoot.add_child(menu)

## The wedges, [label, colour], for a box of `boxTier`
static func wedgesFor(boxTier: int) -> Array:
	var out := []
	for w in WorldProps.PrizeWheel.WEDGES:
		var label: String = w[0]
		var col: Color = w[1]
		if label == "BUST" && boxTier >= 1:
			label = "50"
			col = Color("f0a020")
		if label.is_valid_int() && boxTier >= 2: label = str(int(label) * 2)
		if label == "WRENCH" && boxTier >= 3:
			label = "GEM"
			col = Color("e83aa8")
		if label == "NITRO" && boxTier >= 4:
			label = "JACKPOT"
			col = Color("ffc23d")
		out.push_back([label, col])
	return out

func build() -> void:
	wedges = wedgesFor(tier)
	angle = randf() * TAU
	title("PRIZE WHEEL", "Gift box: spin the wheel." if tier <= 0 else "%s box: spin the wheel." % CrushPrizes.tierName(tier))
	wheel.custom_minimum_size = Vector2(R * 2.0 + 60.0, R * 2.0 + 60.0)
	wheel.draw.connect(drawWheel)
	body.add_child(wheel)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "Accelerate to spin."
	body.add_child(info)
	hints([[["Accelerate"], "Spin / Leave"]])

func onAction(action: String) -> void:
	if action != "Accelerate" && action != "ui_accept": return
	match phase:
		"ready": startSpin()
		"done": close()

func startSpin() -> void:
	phase = "spinning"
	info.text = ""
	if Transition.instant(): #harnesses: no waiting for the wheel
		angle += randf() * TAU
		stopSpin()
		return
	spin = randf_range(SPIN_MIN, SPIN_MAX)
	Transition.sound("rattle", -8.0)

func tick(delta: float) -> void:
	if phase != "spinning": return
	angle += spin * delta
	spin *= exp(-SPIN_DECAY * delta)
	if spin < STOP_BELOW: stopSpin()
	wheel.queue_redraw()

func wedgeAtPointer() -> int:
	var n := wedges.size()
	var a := fposmod(-PI / 2 - angle, TAU) #the pointer is at the top
	return int(a / (TAU / n)) % n

func stopSpin() -> void:
	phase = "done"
	result = wedges[wedgeAtPointer()][0]
	pay(result)
	info.text = ("%s!" % result if result != "BUST" else "BUST: -10 fuel") + "   Accelerate to leave."
	Transition.sound("pop", -6.0)
	wheel.queue_redraw()

## Credits a wedge at once. A Mystery wedge pays an Uncommon-or-better pickup (no menu opens another).
func pay(label: String) -> void:
	var c = Root.playerCar
	if not is_instance_valid(c): return
	Pickups.discover("wheel")
	match label:
		"JACKPOT": PickupEffects.collect(c, Pickups.rollOffer(Pickups.R.LEGENDARY, PickupDeal.NEVER, []), c.global_position)
		"NITRO": PickupEffects.collect(c, "nitro", c.global_position)
		"BUST": c.fuel = maxf(0.0, c.fuel - 10.0)
		"WRENCH": PickupEffects.collect(c, "wrench", c.global_position)
		"GEM": c.reward("gem", 1)
		"STAR": PickupEffects.collect(c, "starfrag", c.global_position)
		"MYSTERY": PickupEffects.collect(c, Pickups.rollOffer(Pickups.R.UNCOMMON, PickupDeal.NEVER, []), c.global_position)
		_:
			if label.is_valid_int(): c.reward("coin", int(label))

func drawWheel() -> void:
	var w := wheel
	var c := w.size * 0.5
	var n := wedges.size()
	w.draw_circle(c, R + 12.0, Color(0.16, 0.11, 0.07, 0.95))
	var lit := wedgeAtPointer() if phase == "done" else -1
	for i in n:
		var a0 := angle + i * TAU / n
		var pts := PackedVector2Array([c])
		for k in 7: pts.push_back(c + Vector2.from_angle(a0 + TAU / n * k / 6.0) * R)
		var col: Color = wedges[i][1]
		w.draw_colored_polygon(pts, col if lit < 0 || i == lit else col.darkened(0.55))
		var mid := c + Vector2.from_angle(a0 + TAU / n * 0.5) * R * 0.64
		w.draw_set_transform(mid, a0 + TAU / n * 0.5 + PI / 2, Vector2.ONE)
		HudTheme.text(w, Vector2(0, 6), wedges[i][0], 17, Color(0.07, 0.05, 0.04), HORIZONTAL_ALIGNMENT_CENTER, 0)
		w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	w.draw_circle(c, 26.0, Color(0.15, 0.12, 0.1))
	w.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -R + 20), c + Vector2(-16, -R - 18), c + Vector2(16, -R - 18)]), Color(1.0, 0.95, 0.86))
