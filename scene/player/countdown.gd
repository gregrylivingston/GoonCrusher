extends CanvasLayer

#The start lamps (docs/UI.md, "Transitions"): a drag-strip lamp rack on the shutter's rail hardware.
#Three amber lamps light one second apart with a relay clunk, then green on GO with a tire chirp and a
#puff off the car. At run start the rack drops in on its rail (playerRoot sets `dropIn`); on a resume
#after a slot machine or pickup menu it is simply there. The run stays paused for the three steps, as
#the old 3-2-1 did, and unpauses on GO. Reduce Motion fades the rack in and out with no drop or smoke.

const STEP := 1.0
const DROP_SECONDS := 0.26
const LIFT_SECONDS := 0.3
const RACK_Y := 196.0
const RACK_SIZE := Vector2(460, 150)

var dropIn := false
var rack := StartLamps.new()
var fx := TransitionFx.new()

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var screen = get_viewport().get_visible_rect().size
	rack.size = RACK_SIZE
	rack.position = Vector2((screen.x - RACK_SIZE.x) / 2.0, RACK_Y)
	add_child(rack)
	fx.autoFree = false
	add_child(fx)
	run()

func run() -> void:
	var calm = Settings.reduce_motion()
	if dropIn && not calm:
		rack.position.y = -RACK_SIZE.y - 20
		Transition.sound("whoosh", -8.0)
		var drop = create_tween()
		drop.tween_property(rack, "position:y", RACK_Y, DROP_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop.tween_callback(func():
			Transition.sound("clank", -4.0)
			Juice.rumble(rack, "position", 4.0, 0.14))
		await drop.finished
	else:
		rack.modulate.a = 0.0
		create_tween().tween_property(rack, "modulate:a", 1.0, 0.12)
	for lamp in 3:
		light(lamp + 1)
		await get_tree().create_timer(STEP, true).timeout
	get_tree().paused = false #the run starts now; the green lamp shows over it without holding anything up
	go(calm)
	await get_tree().create_timer(LIFT_SECONDS, true).timeout
	var lift = create_tween()
	if calm: lift.tween_property(rack, "modulate:a", 0.0, Transition.FADE_SECONDS)
	else:
		Transition.sound("rattle", -10.0)
		lift.tween_property(rack, "position:y", -RACK_SIZE.y - 20, LIFT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await lift.finished
	queue_free()

#a relay clunks an amber lamp on
func light(count: int) -> void:
	rack.lit = count
	rack.flash = 1.0
	create_tween().tween_property(rack, "flash", 0.0, 0.14)
	Transition.sound("clank", -7.0, 0.8 + count * 0.05)
	Transition.sound("thud", -16.0)

#green: a tire chirp and a puff off the car's rear wheels
func go(calm: bool) -> void:
	rack.green = true
	rack.flash = 1.0
	create_tween().tween_property(rack, "flash", 0.0, 0.14)
	Transition.sound("skid", -4.0)
	if calm || not is_instance_valid(Root.playerCar): return
	var canvas = Root.playerCar.get_global_transform_with_canvas()
	var tail = canvas.origin - canvas.x * 26.0 #forward is the car's +x
	for i in 3: fx.burst(tail, 4, -canvas.x.normalized() * 140.0, 160.0, 80.0, 0.9, i * 0.05)

#the rack: a steel plate hung on two posts from the top of the screen, four lamps and a hazard rail
class StartLamps extends Control:
	const AMBER := Color(1.0, 0.69, 0.18)
	const GREEN := Color(0.49, 0.94, 0.54)
	var lit := 0:
		set(value):
			lit = value
			queue_redraw()
	var green := false:
		set(value):
			green = value
			queue_redraw()
	var flash := 0.0:
		set(value):
			flash = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w = size.x
		var h = size.y
		for x in [w * 0.5 - 170.0, w * 0.5 + 170.0]: draw_rect(Rect2(x - 4, -position.y - 20, 8, position.y + 24), Color("6b625b"))
		draw_rect(Rect2(8, 10, w, h), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(0, 0, w, h), Color("4a4440"))
		for i in 18: draw_rect(Rect2(fposmod(i * 97.0, w - 60), 6 + fposmod(i * 37.0, h - 30), 30 + fposmod(i * 53.0, 90), 1), Color(1, 0.95, 0.86, 0.05))
		draw_rect(Rect2(0, 0, w, h), HudTheme.OUTLINE, false, 3.0)
		ShutterDoor.drawHazard(self, Rect2(3, h - 16, w - 6, 11))
		for p in [Vector2(14, 14), Vector2(w - 14, 14)]:
			draw_circle(p, 6, Color("211c19"))
			draw_circle(p - Vector2(1.5, 1.5), 2.2, Color("7b726b"))
		for i in 4:
			var centre = Vector2(w * 0.5 + (i - 1.5) * 100.0, 58.0)
			var isGreen = i == 3
			var on = green if isGreen else (i < lit && not green)
			var colour: Color = GREEN if isGreen else AMBER
			draw_circle(centre, 36, HudTheme.OUTLINE)
			draw_circle(centre, 29, colour if on else colour.darkened(0.78))
			if on:
				var latest = green if isGreen else i == lit - 1
				var boost = flash if latest else 0.0
				for ring in 4: draw_circle(centre, 34 + ring * 12, Color(colour, (0.22 + 0.2 * boost) / (ring + 1)))
				draw_circle(centre + Vector2(-9, -10), 7, Color(1, 1, 0.94, 0.75))
			else: draw_circle(centre + Vector2(-9, -10), 6, Color(1, 0.95, 0.86, 0.08))
			HudTheme.text(self, centre + Vector2(0, 58), ["3", "2", "1", "GO"][i], 15, HudTheme.TEXT if on else HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
