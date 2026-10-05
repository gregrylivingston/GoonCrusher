extends AnimatedSprite2D

#Exhaust smoke. A node with temporary = false is an emitter: while it is visible (the car is
#moving) it drops puffs into the level from its own pool. Density follows Settings gfx/smoke.
#A node with temporary = true is a single puff that grows, fades and frees itself.

@export var temporary: bool = true

const LEVELS = [
	{},                                                     #Off
	{"interval":0.18, "life":1.2, "scale":2.5},             #Low
	{"interval":0.06, "life":2.0, "scale":4.0},             #Full (as authored)
]
static var puffScene: PackedScene

var pooled := false        #set on puffs owned by an emitter
var pool = []
var nextPuff := 0
var emitTimer := 0.0
var puffTween: Tween

func _ready():
	play()
	rotation = randi()%360
	modulate.a = 0.5
	if pooled:
		z_index = 5
		visible = false
	elif temporary:
		z_index = 5
		var tween = create_tween().set_parallel()
		tween.tween_property(self, "scale", Vector2(4,4), 2)
		tween.tween_property(self, "modulate", Color(1.0,1.0,1.0,0.0), 2)
		tween.chain().tween_callback(queue_free)
	else:
		if puffScene == null: puffScene = load("res://texture/animation/smoke.tscn")
		Settings.changed.connect(onSettingChanged)
		onSettingChanged("gfx/smoke", Settings.get_value("gfx/smoke"))
		return
	set_process(false)

func onSettingChanged(key: String, value) -> void:
	if key != "gfx/smoke": return
	modulate.a = 0.5 if value > 0 else 0.0
	set_process(value > 0)

func _process(delta):
	emitTimer -= delta
	if emitTimer > 0.0 || not is_visible_in_tree() || not is_instance_valid(Root.levelRoot): return
	var level = LEVELS[Settings.get_value("gfx/smoke")]
	emitTimer = level.interval
	var puff = takePuff(ceili(level.life / level.interval) + 1)
	puff.global_position = global_position
	puff.rotation = randi()%360
	puff.scale = scale
	puff.modulate = Color(1.0, 1.0, 1.0, 0.5)
	puff.visible = true
	puff.frame = 0
	puff.play()
	if puff.puffTween: puff.puffTween.kill()
	puff.puffTween = puff.create_tween().set_parallel()
	puff.puffTween.tween_property(puff, "scale", Vector2(level.scale, level.scale), level.life)
	puff.puffTween.tween_property(puff, "modulate", Color(1.0,1.0,1.0,0.0), level.life)
	puff.puffTween.chain().tween_callback(puff.hide)

#ring buffer of puffs living in the level; grows to `size`, then reuses the oldest
func takePuff(size: int) -> AnimatedSprite2D:
	pool = pool.filter(func(p): return is_instance_valid(p))
	if pool.size() < size:
		var puff = puffScene.instantiate()
		puff.pooled = true
		Root.levelRoot.add_child(puff)
		pool.push_back(puff)
		return puff
	nextPuff = (nextPuff + 1) % pool.size()
	return pool[nextPuff]
