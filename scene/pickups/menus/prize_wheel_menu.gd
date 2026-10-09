class_name PrizeWheelMenu extends PickupMenu

#The Prize Wheel as a gift box game (CrushPrizes). Hold Accelerate (or the mouse) and a power gauge
#sweeps up and down; let go to spin with that much. Pegs between the wedges knock the flapper at the top
#and each costs the wheel a little speed, on top of its friction, so a spin always runs the same way for the
#same power: the weakest goes about one turn, the strongest nearly three, and a practised hand can aim.
#The wedge under the flapper pays the moment the wheel stops. Its wedges are the world wheel's
#(WorldProps.PrizeWheel); a higher box tier turns the busts into coins (Bronze), doubles the coin wedges
#(Silver), swaps the Wrench for a Gem (Gold) and the Nitro for a second Jackpot (Diamond).

const R := 172.0
const CENTRE := Vector2(300, 212)
const SPIN_MIN := 6.0      #rad/s at no power: about one turn
const SPIN_MAX := 14.0     #at full power: nearly three
const FRICTION := 0.8      #rad/s² always
const DRAG := 0.5          #per second, times the speed
const PEG_LOSS := 0.06     #rad/s per peg past the flapper
const SWEEP := 1.1         #seconds for the gauge to fill (and as long to empty)
const STOP_BELOW := 0.04
const SETTLE := 0.7        #seconds the lit wedge shows before the winnings

var tier := 0
var wedges: Array = []
var angle := 0.0
var spin := 0.0
var phase := "ready"       #ready, charging, spinning, done
var result := ""
var charge := 0.0          #seconds held
var power := 0.0
var flap := 0.0            #the flapper's kick, 0..1
var lastPeg := 0
var doneT := 0.0
var mouseHeld := false

static func open(boxTier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var menu := PrizeWheelMenu.new()
	menu.tier = boxTier
	Root.levelRoot.add_child.call_deferred(menu)

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

## The gauge after `held` seconds: up over SWEEP, down over SWEEP, and again
static func powerAt(seconds: float) -> float:
	return pingpong(seconds / SWEEP, 1.0)

func build() -> void:
	wedges = wedgesFor(tier)
	angle = randf() * TAU
	title("PRIZE WHEEL", "Hold to charge, let go to spin." if tier <= 0 else "%s box: hold to charge, let go to spin." % CrushPrizes.tierName(tier))
	hints([[["Accelerate"], "Hold: charge, release: spin"]])
	say("More power, more turns. The flapper's pegs slow it down.")

func onAction(action: String) -> void:
	if (action == "Accelerate" || action == "ui_accept") && phase == "ready": startCharge()

func onStageMouse(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed && phase == "ready":
			mouseHeld = true
			startCharge()
		elif not event.pressed: mouseHeld = false

func startCharge() -> void:
	phase = "charging"
	charge = 0.0

func held() -> bool:
	return mouseHeld || Input.is_action_pressed("Accelerate") || Input.is_action_pressed("ui_accept")

func tick(delta: float) -> void:
	flap = maxf(0.0, flap - delta * 6.0)
	match phase:
		"ready":
			if live() && held(): startCharge()
		"charging":
			charge += delta
			power = powerAt(charge)
			if not held(): startSpin()
		"spinning":
			angle += spin * delta
			spin -= (FRICTION + DRAG * spin) * delta
			var peg := pegIndex()
			if peg != lastPeg:
				lastPeg = peg
				spin -= PEG_LOSS
				flap = 1.0
				Transition.sound("clank", -20.0, 1.8)
			if spin < STOP_BELOW: stopSpin()
		"done":
			doneT += delta
			if doneT >= SETTLE && not boardUp: showWinnings(result + "!" if result != "BUST" else "BUST")

func pegIndex() -> int:
	return int(floor(fposmod(-PI / 2 - angle, TAU * 100.0) / (TAU / wedges.size())))

func startSpin() -> void:
	phase = "spinning"
	hints([])
	say("")
	lastPeg = pegIndex()
	if Transition.instant(): #harnesses: no waiting for the wheel
		angle += randf() * TAU
		stopSpin()
		return
	spin = lerpf(SPIN_MIN, SPIN_MAX, power) * randf_range(0.98, 1.02)
	Transition.sound("rattle", -8.0)

func wedgeAtPointer() -> int:
	var n := wedges.size()
	var a := fposmod(-PI / 2 - angle, TAU) #the pointer is at the top
	return int(a / (TAU / n)) % n

func stopSpin() -> void:
	phase = "done"
	doneT = 0.0
	result = wedges[wedgeAtPointer()][0]
	pay(result)
	Transition.sound("pop", -6.0)

## Credits a wedge at once. A Mystery wedge pays an Uncommon-or-better pickup, a Jackpot a Legendary.
func pay(label: String) -> void:
	var c = Root.playerCar
	if not is_instance_valid(c): return
	Pickups.discover("wheel")
	match label:
		"JACKPOT": award(Pickups.rollOffer(Pickups.R.LEGENDARY, Pickups.NOT_IN_GAMES, []))
		"NITRO": award("nitro")
		"BUST":
			c.fuel = maxf(0.0, c.fuel - 10.0)
			note("bust", Pickups.texture("jerry"), "Bust", "-10 fuel", HudTheme.BAD)
		"WRENCH": award("wrench")
		"GEM": awardGems(1)
		"STAR": award("starfrag")
		"MYSTERY": award(Pickups.rollOffer(Pickups.R.UNCOMMON, Pickups.NOT_IN_GAMES, []))
		_:
			if label.is_valid_int(): awardCoins(int(label))

func drawStage() -> void:
	var w := stage
	var c := CENTRE
	var n := wedges.size()
	w.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.06, 0.045, 0.04))
	w.draw_circle(c, R + 14.0, Color(0.16, 0.11, 0.07, 0.95))
	var lit := wedgeAtPointer() if phase == "done" else -1
	for i in n:
		var a0 := angle + i * TAU / n
		var pts := PackedVector2Array([c])
		for k in 7: pts.push_back(c + Vector2.from_angle(a0 + TAU / n * k / 6.0) * R)
		var col: Color = wedges[i][1]
		w.draw_colored_polygon(pts, col if lit < 0 || i == lit else col.darkened(0.55))
		var mid := c + Vector2.from_angle(a0 + TAU / n * 0.5) * R * 0.64
		w.draw_set_transform(mid, a0 + TAU / n * 0.5 + PI / 2, Vector2.ONE)
		HudTheme.text(w, Vector2(0, 6), wedges[i][0], 16, Color(0.07, 0.05, 0.04), HORIZONTAL_ALIGNMENT_CENTER, 0)
		w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var peg := c + Vector2.from_angle(a0) * (R + 4.0)
		w.draw_circle(peg, 5.0, Color(0.9, 0.88, 0.84))
	w.draw_circle(c, 26.0, Color(0.15, 0.12, 0.1))
	w.draw_arc(c, 26.0, 0, TAU, 24, HudTheme.RIM, 3.0, true)
	#the flapper, hinged above the wheel; a peg knocks it aside
	var hinge := c + Vector2(0, -R - 34.0)
	var tipAt := hinge + Vector2.from_angle(PI / 2 + flap * 0.5) * 44.0
	w.draw_line(hinge, tipAt, Color(1.0, 0.95, 0.86), 8.0, true)
	w.draw_circle(hinge, 7.0, HudTheme.RIM)
	#the power gauge
	var g := Rect2(STAGE.x - 70.0, 60.0, 26.0, 300.0)
	w.draw_rect(g, HudTheme.TRACK)
	var shown := power if phase != "ready" else 0.0
	w.draw_rect(Rect2(g.position.x, g.end.y - g.size.y * shown, g.size.x, g.size.y * shown), HudTheme.OK.lerp(HudTheme.BAD, shown))
	w.draw_rect(g, HudTheme.RIM, false, 2.0)
	HudTheme.text(w, Vector2(g.get_center().x, g.position.y - 12.0), "POWER", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)
	for k in 3: HudTheme.text(w, Vector2(g.position.x - 8.0, g.end.y - g.size.y * k / 2.0 + 5.0), ["1", "2", "3"][k], 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 3)
	HudTheme.text(w, Vector2(g.get_center().x, g.end.y + 20.0), "TURNS", 11, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)
