class_name SpawnManager extends Node

@export var spawnTimer: float = 6.0
@export var escalationSpeed = 0.15

const GOON_CAP = 250          #same for every player and preset
const DESPAWN_DISTANCE = 8000.0
const SWEEP_SECONDS = 0.5
const LOD_MARGIN = 400.0     #goons this far outside the view still collide normally
const NIGHT_BELOW := 0.4      #the CanvasModulate's value under which goons' eyes light up

## The current region's three goon ids (Region.gd). Setting it starts loading their scenes on a thread.
var basicGoons: Array = []:
	set(value):
		basicGoons = value
		for id in value: requestScene(id)

#world rect where goons run full physics; refreshed every physics tick
var physicsView := Rect2()

var giantTimer:float = 0
var spawners
var liveGoons: int = 0
var goons: Array[Node] = []
var pendingSpawns: Array = []
var sweepTimer: float = 0.0
var fx: GoonFx
var isNight := false
var scenes := {} #id -> PackedScene, loaded on first use
var packs := {} #packId -> Array of goons
var nextPack := 1

func registerGoon(newGoon: Node) -> void:
	liveGoons += 1
	goons.push_back(newGoon)
	newGoon.tree_exiting.connect(onGoonExiting.bind(newGoon))

func onGoonExiting(goon: Node) -> void:
	liveGoons -= 1
	goons.erase(goon)
	if goon.packId != 0 && packs.has(goon.packId):
		packs[goon.packId].erase(goon)
		if packs[goon.packId].is_empty(): packs.erase(goon.packId)

func _physics_process(_delta):
	physicsView = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).grow(LOD_MARGIN)

#off-screen LOD: goons outside the view skip collision queries while they walk
func needsFullPhysics(point: Vector2) -> bool:
	return physicsView.has_area() == false || physicsView.has_point(point)

func canSpawn() -> bool:
	return liveGoons < GOON_CAP

#frees goons left far behind. Before this ran only when a goon finished idling.
func despawnSweep() -> void:
	if not is_instance_valid(Root.playerCar): return
	var carPosition = Root.playerCar.global_position
	var view = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for goon in goons.duplicate():
		if is_instance_valid(goon) && not goon.is_queued_for_deletion() && goon.global_position.distance_to(carPosition) > DESPAWN_DISTANCE && not view.has_point(goon.global_position):
			goon.queue_free()

#night is the level's CanvasModulate going dark; goons light their eyes and night goons wake
func nightSweep() -> void:
	if not is_instance_valid(Root.levelRoot): return
	var modulate = Root.levelRoot.get_node_or_null("CanvasModulate")
	if modulate == null: return
	var night: bool = modulate.color.v < NIGHT_BELOW
	if night == isNight: return
	isNight = night
	for goon in goons:
		if is_instance_valid(goon) && not goon.dead: goon.setNight(night)

# Called when the node enters the scene tree for the first time.
func _ready():
	Root.spawnManager = self
	fx = GoonFx.new()
	fx.name = "GoonFx"
	add_child(fx)
	await get_tree().process_frame
	spawners = get_tree().get_nodes_in_group("spawner")

func increaseGiantOdds():
	giantOdds += 1
	gameTimeProgress += 1
	spawnTimer = clampf(spawnTimer - escalationSpeed , 1.0, 6.0)

#--- goon scenes --------------------------------------------------------------------------------

func requestScene(id: StringName) -> void:
	if scenes.has(id): return
	var path := Goons.scenePath(id)
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	var split: StringName = Goons.DATA.get(id, {}).get("split", &"")
	if split != &"": requestScene(split)

## The goon's scene; waits for its threaded load if one is running, else loads it now.
func sceneFor(id: StringName) -> PackedScene:
	if scenes.has(id): return scenes[id]
	var path := Goons.scenePath(id)
	var scene: PackedScene
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: scene = ResourceLoader.load_threaded_get(path)
	else: scene = load(path)
	scenes[id] = scene
	return scene

func makeGoon(id: StringName) -> Walker:
	return sceneFor(id).instantiate()

#--- spawning -----------------------------------------------------------------------------------

## Which of the region's goons to spawn: by the region's wave, so goons 2 and 3 come as the HUD reveals them.
func pickGoonId() -> StringName:
	if basicGoons.is_empty(): return &"grunt"
	var wave: int = Region.currentRegion.get("wave", 1) if Region.currentRegion else 1
	return basicGoons[Goons.pickSlot(wave + int(gameTimeProgress / 12.0), randf())]

var gameTimeProgress = 0
@export var giantOdds = -10
func getGoon() -> Walker:
	var goon = makeGoon(pickGoonId())
	if randi_range(0 , 100) < giantOdds:
		goon.isGiant = true
	return goon

## Spawns one goon, or a whole pack or herd, around `coordinates`. Every goon counts against the cap.
func spawnAt(coordinates: Vector2) -> void:
	var id := pickGoonId()
	var count: int = Goons.DATA.get(id, {}).get("pack", 1)
	var pack := 0
	if count > 1:
		pack = nextPack
		nextPack += 1
	var giant := randi_range(0, 100) < giantOdds && count == 1
	for i in count:
		if not canSpawn(): return
		var goon := makeGoon(id)
		goon.isGiant = giant
		goon.packId = pack
		goon.position = coordinates + (Vector2.from_angle(i * 2.4) * 40.0 * sqrt(i) if count > 1 else Vector2.ZERO)
		registerGoon(goon)
		Root.levelRoot.add_child(goon)

## Goons that burst out of another (Splitter): thrown outward, briefly dazed.
func spawnBurst(id: StringName, pos: Vector2, count: int) -> void:
	for i in count:
		if not canSpawn() || not is_instance_valid(Root.levelRoot): return
		var goon := makeGoon(id)
		goon.position = pos
		registerGoon(goon)
		Root.levelRoot.call_deferred("add_child", goon)
		var dir := Vector2.from_angle(randf() * TAU + i * TAU / count)
		goon.ready.connect(func():
			if goon.verb: goon.verb.stunFor(0.35, dir * 260.0)
		, CONNECT_ONE_SHOT)

func joinPack(goon: Walker) -> int:
	if goon.packId == 0: return 0
	if not packs.has(goon.packId): packs[goon.packId] = []
	packs[goon.packId].push_back(goon)
	return packs[goon.packId].size() - 1

func packMates(goon: Walker) -> Array:
	return packs.get(goon.packId, [goon])

func goonsNear(pos: Vector2, radius: float) -> Array:
	var out := []
	var r2 := radius * radius
	for goon in goons:
		if is_instance_valid(goon) && goon.global_position.distance_squared_to(pos) < r2: out.push_back(goon)
	return out

## A goon killed by something the player set off (a blast, a kicked shell) counts as a crush.
func creditCrush(pos: Vector2) -> void:
	if not is_instance_valid(Root.playerCar): return
	Root.playerCar.reward("currentGoonsCrushed", 1)
	RewardFlyers.flyUpgrade(Root.upgrade.CURRENTGOONSCRUSHED, pos)

## The first goon of the current region, for the level's shader warmup.
func warmupScene() -> PackedScene:
	return sceneFor(basicGoons[0] if not basicGoons.is_empty() else &"grunt")

var timeCount: float = 0
var mySpawners

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	giantTimer += delta
	if giantTimer > 10:
		increaseGiantOdds()
		giantTimer = 0
	timeCount += delta
	if timeCount > spawnTimer:
		pendingSpawns.append_array(spawners)
		timeCount = 0
	#one spawner per frame, so a wave is spread over five frames instead of one
	if not pendingSpawns.is_empty():
		var spawner = pendingSpawns.pop_front()
		if is_instance_valid(spawner): spawner.spawn()
	sweepTimer -= delta
	if sweepTimer <= 0.0:
		sweepTimer = SWEEP_SECONDS
		despawnSweep()
		nightSweep()
