class_name Transition extends CanvasLayer

#Screen changes behind the garage shutter (docs/UI.md, "Transitions"). One door at a time lives on
#the tree root, above everything (including RunView), so it survives a scene change:
#  await Transition.play(swap)          slam, run `swap` (may await) behind the door, roll up
#  var door = Transition.close(...)     slam and stay down (loading); door.progress = 0.4; door.open()
#  Transition.carry(...)                a door that is already down (picks up where another one left off)
#The slam: 240 ms drop (gravity), thud + clank, 8 px shake, dust and chips, a 10 px bounce; the roll
#up is 450 ms with a rattle. Reduce Motion fades a still door in and out instead. Under the bench and
#playtest harnesses and headless, nothing is drawn and the swap runs at once.

signal shut                 #the door is down and settled: safe to change what's behind it
signal opened               #the door is gone

const LAYER := 90
const DROP_SECONDS := 0.24
const BOUNCE_SECONDS := 0.09
const OPEN_SECONDS := 0.45
const FADE_SECONDS := 0.15
const SHAKE := 8.0          #full slam; half doors and brakes use 4, small landings 2 (docs/UI.md)
const SOUNDS := {
	"thud": preload("res://sound/ui/transition/thud.wav"),
	"clank": preload("res://sound/ui/transition/clank.wav"),
	"rattle": preload("res://sound/ui/transition/rattle.wav"),
	"screech": preload("res://sound/ui/transition/screech.wav"),
	"skid": preload("res://sound/ui/transition/skid.wav"),
	"hiss": preload("res://sound/ui/transition/hiss.wav"),
	"whoosh": preload("res://sound/ui/transition/whoosh.wav"),
	"pop": preload("res://sound/ui/transition/pop.wav"),
	"rev": preload("res://sound/ui/transition/rev.wav"),
}

static var active: Transition

var door := ShutterDoor.new()
var fx := TransitionFx.new()
var isShut := false
var progress := -1.0:
	set(value):
		progress = value
		door.lamps = value
var opening := false
var minShutMsec := 0         #open() waits until the door has been down this long
var shutAtMsec := 0

#---------- the static API ----------

#no drawing and no waiting: headless runs and the bench / playtest harnesses
static func instant() -> bool:
	if DisplayServer.get_name() == "headless": return true
	var root = (Engine.get_main_loop() as SceneTree).root
	return root.has_node("Bench") || root.has_node("Playtest")

static func reducedMotion() -> bool:
	return Settings.reduce_motion()

#a run loading behind the menu's door waits for it: the level rolls it up and starts the countdown
static func holdsRunStart() -> bool:
	return busy() && not instant()

#true while a door is moving or down: menus ignore input then
static func busy() -> bool:
	return is_instance_valid(active)

#slam, run `swap` behind the door (it may be a coroutine), then roll up
static func play(swap: Callable, label := "GOONCRUSHER", sub := "") -> void:
	if busy(): #already behind a door: just make the change
		await swap.call()
		return
	var t = close(label, sub)
	if not t.isShut: await t.shut
	await swap.call()
	if is_instance_valid(t): t.open()

#slam down and stay down until open()
static func close(label := "GOONCRUSHER", sub := "", lamps := -1.0) -> Transition:
	if busy(): active.queue_free()
	var t = Transition.new()
	t.door.label = label
	t.door.sub = sub
	t.progress = lamps
	active = t
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	t.slam()
	return t

#a door that is already down, for a scene that ends behind another door (the results ticket)
static func carry(label := "GOONCRUSHER", sub := "") -> Transition:
	if busy(): active.queue_free()
	var t = Transition.new()
	t.door.label = label
	t.door.sub = sub
	active = t
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	t.isShut = true
	t.shutAtMsec = Time.get_ticks_msec()
	if instant(): t.door.visible = false
	return t

#plays a transition sound on the UI bus
static func sound(name: String, volume := 0.0, pitch := 1.0) -> void:
	if instant() || not SOUNDS.has(name): return
	var player = AudioStreamPlayer.new()
	player.stream = SOUNDS[name]
	player.bus = &"UI"
	player.volume_db = volume
	player.pitch_scale = pitch
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	(Engine.get_main_loop() as SceneTree).root.add_child(player)
	player.play()

#---------- the door ----------

func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "Transition"

func _ready() -> void:
	var screen = get_viewport().get_visible_rect().size
	door.size = screen
	door.labelSize = 150
	door.position = Vector2(0, 0 if isShut else -screen.y - 12)
	add_child(door)
	fx.autoFree = false
	add_child(fx)

func _exit_tree() -> void:
	if active == self: active = null

func slam() -> void:
	var height = door.size.y if door.size.y > 0 else get_viewport().get_visible_rect().size.y
	if instant():
		door.visible = false
		markShut.call_deferred()
		return
	if reducedMotion():
		door.position.y = 0
		door.modulate.a = 0.0
		var fade = create_tween()
		fade.tween_property(door, "modulate:a", 1.0, FADE_SECONDS)
		fade.tween_callback(markShut)
		return
	sound("whoosh", -6.0)
	var tween = create_tween()
	tween.tween_property(door, "position:y", 0.0, DROP_SECONDS).from(-height - 12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(impact)
	tween.tween_property(door, "position:y", -10.0, BOUNCE_SECONDS * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(door, "position:y", 0.0, BOUNCE_SECONDS * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(markShut)

func impact() -> void:
	sound("thud")
	sound("clank", -4.0)
	Juice.rumble(self, "offset", SHAKE, 0.18)
	fx.dustLine(0, door.size.x, door.size.y - 4, 28, 12)

func markShut() -> void:
	isShut = true
	shutAtMsec = Time.get_ticks_msec()
	shut.emit()

#rolls the door up and frees it. `smoke` pours tire smoke out from under the rising rail.
func open(smoke := false) -> void:
	if opening: return
	opening = true
	if not isShut: await shut
	var wait = minShutMsec - (Time.get_ticks_msec() - shutAtMsec)
	if wait > 0: await get_tree().create_timer(wait / 1000.0, true, false, true).timeout
	if not is_inside_tree(): return
	if instant():
		finish()
		return
	if reducedMotion():
		var fade = create_tween()
		fade.tween_property(door, "modulate:a", 0.0, FADE_SECONDS)
		fade.tween_callback(finish)
		return
	sound("rattle", -3.0)
	var tween = create_tween()
	tween.tween_property(door, "position:y", -door.size.y - 12, OPEN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if smoke:
		sound("hiss", -4.0)
		tween.parallel().tween_method(pourSmoke, 0.0, 1.0, OPEN_SECONDS)
	tween.tween_callback(finish)

#smoke rolling out from under the rail as it rises
var poured := 0
func pourSmoke(k: float) -> void:
	var wanted = int(k * 30)
	while poured < wanted:
		poured += 1
		if randf() > TransitionFx.smokeAmount(): continue
		var y = door.position.y + door.size.y + 6
		fx.puff(Vector2(randf() * door.size.x, y), Vector2(randf_range(-120, 120), -50 - randf() * 90), TransitionFx.DARK if randf() < 0.25 else TransitionFx.SMOKE, randf_range(0.9, 1.4), 30, 120 + randf() * 90, 0.5, 0, 1.4)

var finished := false
func finish() -> void:
	if finished: return
	finished = true
	door.visible = false
	if active == self: active = null
	opened.emit()
	#the smoke and dust drift on after the door is gone
	if fx.puffs.is_empty(): queue_free()
	else:
		fx.autoFree = true
		fx.tree_exited.connect(queue_free)
