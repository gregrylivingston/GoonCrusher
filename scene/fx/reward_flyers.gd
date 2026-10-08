class_name RewardFlyers extends CanvasLayer

#Fly-to-HUD icons for collected rewards. Purely visual: the reward is already credited when
#a flyer starts, so capping them (Settings gfx/reward_fx) never changes coins or crush counts.
#Flyers live on their own CanvasLayer, so they stay visible at night without a light.

const CAPS = [3, 10, 20]       #Minimal, Reduced, Full
const FLIGHT_SECONDS = 0.3
const LAYER = 2

static var infoCache = {}      #upgrade -> {texture, scale, sounds, ui}

var pool: Array[Sprite2D] = []
var active := 0

static func instance() -> RewardFlyers:
	if not is_instance_valid(Root.levelRoot): return null
	var existing = Root.levelRoot.get_node_or_null("RewardFlyers")
	if existing: return existing
	var flyers = RewardFlyers.new()
	flyers.name = "RewardFlyers"
	flyers.layer = LAYER
	flyers.process_mode = Node.PROCESS_MODE_ALWAYS
	Root.levelRoot.add_child(flyers)
	return flyers

#icon, size and sounds of a powerup type, read once from its scene
static func infoFor(upgrade: Root.upgrade) -> Dictionary:
	if not infoCache.has(upgrade):
		var sample = Root.getSpecificPowerup(upgrade)
		infoCache[upgrade] = {"texture":sample.texture, "scale":sample.scale, "sounds":sample.awardSound, "ui":sample.powerup + "ui", "quantity":sample.quantity}
		sample.free()
	return infoCache[upgrade]

#flies a collected powerup node's icon to its HUD counter
static func flyPowerup(powerup: Powerup) -> void:
	var flyers = instance()
	if flyers: flyers.launch(powerup.texture, powerup.get_global_transform_with_canvas(), powerup.powerup + "ui")

#flies an icon for a reward that has no node of its own (crushes, purse coins)
static func flyUpgrade(upgrade: Root.upgrade, worldPosition: Vector2, playSound := true) -> void:
	var info = infoFor(upgrade)
	if playSound: Audio.queueRequest(info.sounds)
	var flyers = instance()
	if not flyers || not is_instance_valid(Root.levelRoot) || not Root.levelRoot.is_inside_tree(): return #a run that is ending
	var canvas = Root.levelRoot.get_viewport().get_canvas_transform()
	flyers.launch(info.texture, canvas * Transform2D(0.0, info.scale, 0.0, worldPosition), info.ui)

func launch(texture: Texture2D, screenTransform: Transform2D, uiGroup: String) -> void:
	if active >= CAPS[Settings.get_value("gfx/reward_fx")] || not is_inside_tree(): return #the layer left with the run
	var target = get_tree().get_first_node_in_group(uiGroup)
	if not is_instance_valid(target): return
	var flyer = takeFlyer()
	flyer.texture = texture
	flyer.position = screenTransform.origin
	flyer.scale = screenTransform.get_scale()
	flyer.visible = true
	active += 1
	var end = target.get_global_transform_with_canvas().origin
	var tween = flyer.create_tween()
	tween.tween_property(flyer, "position", end, FLIGHT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) #fast off the mark, settling onto the counter
	tween.tween_callback(func():
		flyer.visible = false
		active -= 1
	)

func takeFlyer() -> Sprite2D:
	for flyer in pool:
		if not flyer.visible: return flyer
	var flyer = Sprite2D.new()
	flyer.visible = false
	add_child(flyer)
	pool.push_back(flyer)
	return flyer
