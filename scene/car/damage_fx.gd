extends Node2D

#Damage effects on the car (docs/CAR_ART.md): engine smoke and fire, a fuel drip trail, sparks off a
#wrecked front wheel and flickering headlights. The dents themselves are in car_damage.gdshader.
#Idle (no _process) while every system is healthy. Settings "gfx/damage_fx": Low = smoke only,
#Full = everything. Visual only, and every timer is delta-based.

const SMOKE_BELOW := 60.0   #engine condition where smoke starts; it turns black below 30
const FIRE_BELOW := 15.0    #engine or tank condition where small flames start
const DRIP_BELOW := 50.0    #tank condition where fuel drips (the fuel dial says LEAK there too)
const SPARK_BELOW := 40.0   #steering condition where a front wheel scrapes
const FLICKER_BELOW := 50.0 #lights condition where the headlights cut out now and then
const FIRE_RADIUS := 20.0    #the fire on a failing engine or tank (Fx.burn)...
const WRECK_FIRE := 2.2      #...and how much bigger it burns on a wreck
const PUFF_POOL := 16
const DRIP_POOL := 24

var car
var puffScene := preload("res://texture/animation/smoke.tscn")
var dripTexture := preload("res://texture/fx/circle_05.png")
var fireMaterial: CanvasItemMaterial #flames glow through the night
var puffs := []
var drips := []
var nextPuff := 0
var nextDrip := 0
var timers := {"smoke":0.0, "fire":0.0, "drip":0.0, "spark":0.0, "flicker":0.0}
var flickerLeft := 0.0

func _ready():
	car = get_parent()
	fireMaterial = CanvasItemMaterial.new()
	fireMaterial.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fireMaterial.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	car.conditionChanged.connect(onConditionChanged)
	set_process(false)

func onConditionChanged(_system: String, _value: float) -> void:
	var active = isActive(car.condition)
	if not active: endFlicker()
	set_process(active)

static func isActive(c: Dictionary) -> bool:
	return c.engine < SMOKE_BELOW || c.tank < DRIP_BELOW || c.steering < SPARK_BELOW || c.lights < FLICKER_BELOW

func _process(delta):
	if not is_instance_valid(Root.levelRoot) || car.art == null: return
	var c = car.condition
	var full = Settings.get_value("gfx/damage_fx") >= 2
	for k in timers: timers[k] -= delta
	if c.engine < SMOKE_BELOW && timers.smoke <= 0.0:
		timers.smoke = lerpf(0.08, 0.35, c.engine / SMOKE_BELOW)
		puff(car.art.hood, Color(0.12, 0.11, 0.1, 0.6) if c.engine < 30.0 else Color(0.75, 0.74, 0.72, 0.45), 3.0, 1.6, false)
	if full && (c.engine < FIRE_BELOW || c.tank < FIRE_BELOW):
		var spot: Vector2 = car.art.hood if c.engine < FIRE_BELOW else car.art.tank
		var fx := Fx.current()
		var burning: bool = fx != null && fx.burn(car.to_global(spot), FIRE_RADIUS * (WRECK_FIRE if car.isDestroyed else 1.0), delta)
		if not burning && timers.fire <= 0.0: #Blast Effects Minimal: the plain flame
			timers.fire = 0.05
			puff(spot, Color(1.8, 0.95, 0.3, 1.0), 1.1, 0.45, true)
	if full && c.tank < DRIP_BELOW && timers.drip <= 0.0:
		timers.drip = lerpf(0.12, 0.6, c.tank / DRIP_BELOW)
		drip()
	if full && c.steering < SPARK_BELOW && car.velocity.length() > 150.0 && timers.spark <= 0.0:
		timers.spark = randf_range(0.3, 1.2) * (0.4 + c.steering / SPARK_BELOW)
		var w: Vector2 = car.art.frontWheel
		car.sparkAt(car.to_global(Vector2(w.x, w.y if randf() < 0.5 else -w.y)), 10)
	flicker(delta, c.lights)

#a pooled puff of the exhaust's smoke flipbook, tinted, growing and fading in the level
func puff(at: Vector2, color: Color, grow: float, life: float, fire: bool) -> void:
	var p
	if puffs.size() < PUFF_POOL:
		p = puffScene.instantiate()
		p.pooled = true
		Root.levelRoot.add_child(p)
		puffs.push_back(p)
	else:
		nextPuff = (nextPuff + 1) % puffs.size()
		p = puffs[nextPuff]
		if not is_instance_valid(p):
			puffs.remove_at(nextPuff)
			return
	p.global_position = car.to_global(at + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
	p.rotation = randf() * TAU
	p.scale = Vector2(0.35, 0.35) if fire else Vector2(0.6, 0.6)
	p.modulate = color
	p.material = fireMaterial if fire else null
	p.visible = true
	p.frame = 0
	p.play()
	if p.puffTween: p.puffTween.kill()
	p.puffTween = p.create_tween().set_parallel()
	p.puffTween.tween_property(p, "scale", Vector2(grow, grow), life)
	p.puffTween.tween_property(p, "modulate:a", 0.0, life)
	p.puffTween.chain().tween_callback(p.hide)

#a pooled drop of fuel left on the ground under the filler
func drip() -> void:
	var d: Sprite2D
	if drips.size() < DRIP_POOL:
		d = Sprite2D.new()
		d.texture = dripTexture
		d.z_index = -1
		Root.levelRoot.add_child(d)
		drips.push_back(d)
	else:
		nextDrip = (nextDrip + 1) % drips.size()
		d = drips[nextDrip]
		if not is_instance_valid(d):
			drips.remove_at(nextDrip)
			return
	d.global_position = car.to_global(car.art.tank)
	var s = randf_range(0.018, 0.03)
	d.scale = Vector2(s, s * 1.3)
	d.rotation = car.rotation
	d.modulate = Color(0.14, 0.1, 0.16, 0.85)
	d.visible = true
	var t = d.create_tween()
	t.tween_interval(1.5)
	t.tween_property(d, "modulate:a", 0.0, 4.0)
	t.tween_callback(d.hide)

#the headlights cut out for a moment now and then, more often the worse the lights are
func flicker(delta: float, lights: float) -> void:
	if flickerLeft > 0.0:
		flickerLeft -= delta
		if flickerLeft <= 0.0: endFlicker()
		return
	if lights < FLICKER_BELOW && timers.flicker <= 0.0:
		timers.flicker = randf_range(0.4, 3.0) * (0.3 + lights / FLICKER_BELOW)
		car.get_node("headlamps/headlights").visible = false
		flickerLeft = randf_range(0.04, 0.12) * (2.0 if lights < 15.0 else 1.0)

func endFlicker() -> void:
	flickerLeft = 0.0
	car.get_node("headlamps/headlights").visible = true

func _exit_tree():
	for n in puffs + drips:
		if is_instance_valid(n): n.queue_free()
