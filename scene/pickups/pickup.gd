class_name GenericPickup extends Powerup

#Every pickup that has no scene of its own (scripts/global/pickups.gd). Its icon, outline colour and
#effect come from Pickups.DATA by id; PickupEffects does what it does. Rarity shows as the outline
#colour, and Rare or better also glow at night.

const NIGHT_GLOW_FROM := Pickups.R.RARE
static var materials := {} #rarity -> a shared ShaderMaterial (the edge glow in that rarity's colour)

var id := ""

func setId(value: String) -> void:
	id = value
	powerup = value #the AI driver and the Bandit read this
	quantity = 1.0
	if is_node_ready(): applyLook()

func _ready():
	super()
	set_process(false)
	applyLook()

func applyLook() -> void:
	if id == "": return
	texture = Pickups.texture(id)
	var r := Pickups.rarity(id)
	if hasShinyShader: material = rarityMaterial(material, r)
	var light: PointLight2D = get_node_or_null("PointLight2D")
	if light && r >= NIGHT_GLOW_FROM && r <= Pickups.R.LEGENDARY:
		light.color = Pickups.rarityColor(r)
		light.energy = 0.9
		light.texture = preload("res://texture/fx/circle_05.png")
		light.texture_scale = 2.5
		glow = light
		set_process(true)

#Rare and better glow, but only at night: by day the light would wash out the ground around them
var glow: PointLight2D

func _process(_delta: float) -> void:
	if glow == null: return
	var night: bool = is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight
	if glow.visible != night: glow.visible = night

## The edge-glow material in a rarity's colour. Common keeps the authored one; the others are made once
## and shared, so every pickup of a rarity batches together.
static func rarityMaterial(base: Material, r: int) -> Material:
	if r == Pickups.R.COMMON || not base is ShaderMaterial: return base
	if not materials.has(r):
		var m: ShaderMaterial = base.duplicate()
		var c := Pickups.rarityColor(r)
		m.set_shader_parameter("color", Color(c.r * 6.0, c.g * 6.0, c.b * 6.0, 0.4))
		m.set_shader_parameter("shine_color", Color(c.r * 60.0, c.g * 60.0, c.b * 60.0, 1.0))
		materials[r] = m
	return materials[r]

#credits at once through PickupEffects; the icon that flies to the HUD is only for show
func sendReward(body, forShowOnly: bool = false):
	if has_node("Area2D"): $Area2D.queue_free() #can't be collected twice
	Audio.queueRequest(awardSound)
	if not forShowOnly: PickupEffects.collect(body, id, global_position)
	var flyers = RewardFlyers.instance()
	if flyers: flyers.launch(texture, get_global_transform_with_canvas(), Pickups.uiGroup(id))
	queue_free()
