class_name GiftBox extends CanvasLayer

#A gift box earned with crush XP (CrushPrizes, docs/PICKUPS.md "Gift boxes"): it drops in over the dimmed
#run, shakes, pops its lid on the prize game inside and opens that game. Only for show: nothing is
#credited here. The action key (E) or a click skips ahead; headless runs and the harnesses skip it at once
#(Transition.instant()); Reduce Motion drops the shake.

const GIFT_ICON := preload("res://texture/icon/gift.svg")
const SIZE := 180.0
const SHAKE_UNTIL := 0.4   #seconds: the box rattles harder until the lid pops
const HOLD_UNTIL := 1.0    #then the game inside shows until here
const SKIP_AFTER := 0.2

var gameId := ""
var tier := 0
var stage := Control.new()
var dim := ColorRect.new()
var t := 0.0
var popped := false
var done := false
var preview := -1.0 #screenshots (PickupWorld.screenshots): hold at this moment and never open the game

static func open(id: String, boxTier: int) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var box := GiftBox.new()
	box.gameId = id
	box.tier = boxTier
	Root.levelRoot.add_child.call_deferred(box) #the crush may come from a node leaving the level

func _init() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	if PickupMenu.runOver():
		queue_free()
		return
	get_tree().paused = true
	if preview >= 0.0:
		t = preview
		popped = t >= SHAKE_UNTIL
	elif Transition.instant():
		finish()
		return
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.5, 0.2)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.draw.connect(drawStage)
	add_child(stage)
	Juice.dropIn(stage, 90.0, 0.3)
	Transition.sound("thud", -6.0)

func _process(delta: float) -> void:
	if done: return
	if preview >= 0.0:
		stage.queue_redraw()
		return
	t += delta
	if not popped && t >= SHAKE_UNTIL:
		popped = true
		Transition.sound("pop", -2.0, 0.9)
		Settings.vibrate(0.3, 0.5, 0.12)
	if t >= HOLD_UNTIL || (t >= SKIP_AFTER && InputMap.has_action(PickupMenu.ACT) && Input.is_action_just_pressed(PickupMenu.ACT)):
		finish()
		return
	stage.queue_redraw()

func _input(event: InputEvent) -> void:
	if not done && preview < 0.0 && t >= SKIP_AFTER && event is InputEventMouseButton && event.pressed: finish()

## Opens the game inside. The pausing games keep the tree paused and resume it themselves; the Scratch
## Card runs in the HUD, so the run resumes through the 3-2-1 first.
func finish() -> void:
	if done: return
	done = true
	if CrushPrizes.pauses(gameId):
		CrushPrizes.openGame(gameId, tier)
	else:
		PickupMenu.resumeRun()
		CrushPrizes.openGame(gameId, tier)
	queue_free()

func drawStage() -> void:
	var c := stage.size * 0.5
	var col := CrushPrizes.tierColor(tier)
	var calm := Settings.reduce_motion()
	#a glow and, once open, slow rays in the box's color
	stage.draw_circle(c, SIZE * 0.72, Color(col, 0.18))
	if popped:
		var spin := 0.0 if calm else t * 0.6
		for i in 12:
			var a := spin + i * TAU / 12.0
			stage.draw_line(c + Vector2.from_angle(a) * SIZE * 0.45, c + Vector2.from_angle(a) * SIZE * 1.05, Color(col, 0.35), 6.0, true)
	HudTheme.text(stage, c + Vector2(0, -SIZE * 0.78), "%s BOX" % CrushPrizes.tierName(tier).to_upper(), 30, col, HORIZONTAL_ALIGNMENT_CENTER, 8)
	if not popped:
		var k := clampf(t / SHAKE_UNTIL, 0.0, 1.0)
		var wobble := 0.0 if calm else sin(t * 70.0) * 0.14 * k
		var hop := 0.0 if calm else -absf(sin(t * 24.0)) * 10.0 * k
		stage.draw_set_transform(c + Vector2(0, hop), wobble, Vector2.ONE)
		stage.draw_texture_rect(GIFT_ICON, Rect2(Vector2(-SIZE, -SIZE) * 0.5, Vector2(SIZE, SIZE)), false)
		stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	#popped: the box falls away and the game rises out of it
	var u := clampf((t - SHAKE_UNTIL) / 0.25, 0.0, 1.0)
	var rise := 1.0 - pow(1.0 - u, 3.0)
	stage.draw_set_transform(c + Vector2(0, SIZE * 0.35 * rise), 0.0, Vector2.ONE * (1.0 - 0.4 * rise))
	stage.draw_texture_rect(GIFT_ICON, Rect2(Vector2(-SIZE, -SIZE) * 0.5, Vector2(SIZE, SIZE)), false, Color(1, 1, 1, 1.0 - u))
	stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var icon := CrushPrizes.texture(gameId)
	var s := SIZE * (0.5 + 0.5 * rise)
	if icon: stage.draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5 - Vector2(0, 20.0 * rise), Vector2(s, s)), false)
	HudTheme.text(stage, c + Vector2(0, SIZE * 0.72), CrushPrizes.gameName(gameId).to_upper(), 40, Color(HudTheme.TEXT, rise), HORIZONTAL_ALIGNMENT_CENTER, 8)
	if tier > 0: HudTheme.text(stage, c + Vector2(0, SIZE * 0.72 + 30.0), "%s version" % CrushPrizes.tierName(tier), 18, Color(col, rise), HORIZONTAL_ALIGNMENT_CENTER, 5, HudTheme.OUTLINE, HudTheme.BODY)
