class_name PayoutChute extends Node2D

#The slot machine's prizes pouring out (docs/UI.md, "Transitions"): after Collect the hatch slams, a slot
#opens under its rail and the won symbols drop out one by one, bounce once on the rail, then fly to the
#HUD. Purely visual: the reels are paid before it starts. The stream size follows Slot Celebration
#(Minimal 4, Reduced 8, Full 16); the harnesses skip it.
#  await PayoutChute.pour(layer, cardRect, textures)

const STREAM := [4, 8, 16]
const GAP := 0.055        #between icons
const FALL := 0.24
const BOUNCE := 0.2
const FLIGHT := 0.36
const DROP := 62.0         #from the chute to the rail it bounces on
const ICON := 46.0

signal done

var icons: Array = []      #{tex, x0, vx, t, target}
var chute := Vector2.ZERO
var age := 0.0
var length := 0.0

static func pour(layer: Node, card: Rect2, textures: Array) -> void:
	if Transition.instant() || textures.is_empty(): return
	var chuteFx = PayoutChute.new()
	chuteFx.process_mode = Node.PROCESS_MODE_ALWAYS
	chuteFx.chute = Vector2(card.get_center().x, card.end.y + 10)
	var count = mini(textures.size(), STREAM[Settings.celebration_level()]) if textures.size() > 1 else 1
	var screen = layer.get_viewport().get_visible_rect().size
	for i in count:
		var target = Vector2(screen.x - 160, 40)
		chuteFx.icons.push_back({"tex": textures[i % textures.size()], "vx": randf_range(-90, 90), "t": i * GAP, "target": target})
	chuteFx.length = (count - 1) * GAP + FALL + BOUNCE + FLIGHT
	layer.add_child(chuteFx)
	Transition.sound("clank", -10.0, 1.2) #the chute flap
	await chuteFx.done
	chuteFx.queue_free()

func _process(delta: float) -> void:
	var before = age
	age += delta
	for icon in icons: #a tick as each one hits the rail
		var hit = icon.t + FALL
		if before < hit && age >= hit && icons.find(icon) % 2 == 0: Transition.sound("pop", -16.0, 1.3)
	queue_redraw()
	if age >= length: done.emit()

func _draw() -> void:
	draw_rect(Rect2(chute + Vector2(-46, -4), Vector2(92, 8)), HudTheme.OUTLINE) #the open slot
	var rail = chute.y + DROP
	draw_rect(Rect2(chute.x - 160, rail + 22, 320, 5), Color(0, 0, 0, 0.35))
	for icon in icons:
		var a = age - icon.t
		if a < 0.0: continue
		var p: Vector2
		var s = 1.0
		if a < FALL:
			var k = a / FALL
			p = Vector2(chute.x + icon.vx * a, lerpf(chute.y, rail, k * k))
		elif a < FALL + BOUNCE:
			var k = (a - FALL) / BOUNCE
			p = Vector2(chute.x + icon.vx * a, rail - 26.0 * sin(PI * k))
		else:
			var k = clampf((a - FALL - BOUNCE) / FLIGHT, 0.0, 1.0)
			if k >= 1.0: continue
			var e = 1.0 - pow(1.0 - k, 3.0)
			var from = Vector2(chute.x + icon.vx * (FALL + BOUNCE), rail)
			p = from.lerp(icon.target, e) - Vector2(0, 50.0 * sin(PI * e))
			s = lerpf(1.0, 0.6, e)
		draw_circle(Vector2(p.x + 5, rail + 24 if a < FALL + BOUNCE else p.y + 9), ICON * 0.3 * s, Color(0, 0, 0, 0.3))
		draw_texture_rect(icon.tex, Rect2(p - Vector2(ICON, ICON) * s / 2.0, Vector2(ICON, ICON) * s), false)
