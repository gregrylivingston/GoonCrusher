class_name PickupWorld extends Node

#Where pickups come from besides goon drops (docs/PICKUPS.md): supply drops on a timer, events (the
#Golden Goon, the Loot Truck, Goon Bowling, a Ring Run) one at a time, chunk props (crates, the Speed
#Trap, Donut Zone, Bullseye, Prize Wheel, ring starts, bowling lanes) and the region-wave chest.
#The level adds one (Level._ready); its static helpers spawn things for PickupEffects.

const SUPPLY_FIRST := Vector2(60.0, 90.0)   #seconds before the first supply drop (min, max)
const SUPPLY_EVERY := Vector2(90.0, 120.0)
const EVENT_FIRST := Vector2(70.0, 100.0)
const EVENT_EVERY := Vector2(80.0, 120.0)
const SUPPLY_DISTANCE := 1500.0
const EVENT_DISTANCE := 1800.0
const EVENTS := ["goldgoon", "truck", "bowling", "rings"]

## Chunk props: [chance, kind]. Rolled in order from the chunk's own seed, so a reloaded chunk is the same.
const CHUNK_PROPS := [[0.10, "crates"], [0.03, "speedtrap"], [0.025, "donut"], [0.025, "bullseye"], [0.02, "wheel"], [0.02, "rings"], [0.01, "bowling"]]

static var current: PickupWorld
## Off-screen arrows on the HUD (HudChance): [node, color, icon].
static var beacons: Array = []

var supplyIn := 0.0
var eventIn := 0.0
var event: Node = null

func _ready() -> void:
	current = self
	beacons.clear()
	supplyIn = randf_range(SUPPLY_FIRST.x, SUPPLY_FIRST.y)
	eventIn = randf_range(EVENT_FIRST.x, EVENT_FIRST.y)
	giveFromCommandLine.call_deferred()

## Testing: `-- --pickups=nitro,plow,mine` collects these when the run starts; `-- --event=goldgoon`
## (goldgoon, truck, bowling, rings, supply) starts one right away.
func giveFromCommandLine() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pickups="):
			for id in arg.trim_prefix("--pickups=").split(","):
				if Pickups.has(id) && is_instance_valid(Root.playerCar): PickupEffects.collect(Root.playerCar, id, Root.playerCar.global_position)
		elif arg.begins_with("--pickup-shots="):
			screenshots(arg.trim_prefix("--pickup-shots=").split(","))
		elif arg.begins_with("--event=") && is_instance_valid(Root.playerCar):
			var kind := arg.trim_prefix("--event=")
			if kind == "supply": spawnSupplyDrop(Root.playerCar)
			else: startEvent(kind, Root.playerCar)

func _exit_tree() -> void:
	if current == self: current = null
	beacons.clear()

func _physics_process(delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || not Root.isRunActive || not is_instance_valid(Root.levelRoot) || Root.levelRoot.hasEnded: return
	supplyIn -= delta
	if supplyIn <= 0.0:
		supplyIn = randf_range(SUPPLY_EVERY.x, SUPPLY_EVERY.y)
		spawnSupplyDrop(car)
	if is_instance_valid(event): return
	eventIn -= delta
	if eventIn <= 0.0:
		eventIn = randf_range(EVENT_EVERY.x, EVENT_EVERY.y)
		startEvent(EVENTS.pick_random(), car)

func startEvent(kind: String, car) -> void:
	var at := aheadOf(car, EVENT_DISTANCE)
	match kind:
		"goldgoon": event = spawnGoldenGoon(car)
		"truck": event = spawnLootTruck(car)
		"bowling":
			var lane = WorldProps.BowlingLane.new()
			lane.rotation = (at - car.global_position).angle()
			event = addToLevel(lane, at)
		"rings":
			var rings = WorldProps.RingRun.new()
			event = addToLevel(rings, at)
			PickupWorld.beacon(rings, HudTheme.GOLD, Pickups.texture("ring"))
	PickupEffects.toast(Pickups.displayName(kind).to_upper() + " NEARBY", Pickups.rarityColor(Pickups.rarity(kind)), Pickups.texture(kind))

## Testing: `-- --pickup-shots=deal,claw,pitshop,scratch,double` (with a bench run, e.g. --bench=SL)
## opens each in turn after the countdown and saves user://bench/pickup_<id>.png.
func screenshots(ids: PackedStringArray) -> void:
	await get_tree().create_timer(4.5, true).timeout
	var placed := 0
	for id in ids:
		var car = Root.playerCar
		if not is_instance_valid(car): return
		var beside: Vector2 = car.global_position + Vector2(-1100 + (placed % 3) * 1100, -600 + (placed / 3 % 2) * 1100)
		placed += 1
		match id:
			"pitshop": PitShop.open()
			"wheel": addToLevel(WorldProps.PrizeWheel.new(), beside)
			"speedtrap": addToLevel(WorldProps.SpeedTrap.new(), beside)
			"donut": addToLevel(WorldProps.DonutZone.new(), beside)
			"bullseye": addToLevel(WorldProps.Bullseye.new(), beside)
			"rings": addToLevel(WorldProps.RingRun.new(), beside)
			"bowling": addToLevel(WorldProps.BowlingLane.new(), beside)
			"strongbox": addToLevel(WorldProps.Strongbox.new(), beside)
			"crate":
				for i in 3: addToLevel(WorldProps.Crate.new(), beside + Vector2(i * 95.0, 0))
			"truck", "goldgoon": startEvent(id, car)
			"supply": spawnSupplyDrop(car)
			"double":
				car.coinsSinceBet = 140
				PickupEffects.collect(car, id, car.global_position)
			_: PickupEffects.collect(car, id, car.global_position)
		await get_tree().process_frame
		for menu in get_tree().get_nodes_in_group("slotMachine"):
			if menu is PickupMenu: menu.remove_from_group("slotMachine") #the bench would tap through it
		await get_tree().create_timer(1.0, true).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://bench")
		get_viewport().get_texture().get_image().save_png("user://bench/pickup_%s.png" % id)
		print("PICKUP_SHOT " + ProjectSettings.globalize_path("user://bench/pickup_%s.png" % id))
		for menu in get_tree().get_nodes_in_group("pickupMenu"): menu.close(false)
		await get_tree().create_timer(0.6, true).timeout

#--- helpers ------------------------------------------------------------------------------------

## A point `distance` ahead of the car, a little to either side, on land when one can be found.
static func aheadOf(car, distance: float) -> Vector2:
	var heading: float = car.velocity.angle() if car.velocity.length() > 80.0 else car.rotation
	var best: Vector2 = car.global_position + Vector2.from_angle(heading) * distance
	for i in 8:
		var p: Vector2 = car.global_position + Vector2.from_angle(heading + randf_range(-0.9, 0.9)) * distance
		if onLand(p): return p
	return best

static func onLand(p: Vector2) -> bool:
	if not is_instance_valid(Root.levelRoot) || Root.worldMap == null: return true
	return not World.blockedAt(p)

static func beacon(node: Node2D, color: Color, icon: Texture2D) -> void:
	beacons.push_back([node, color, icon])

## Deferred: most spawns happen inside a physics callback (a pickup's body_entered), where bodies
## and areas can't be added.
static func addToLevel(node: Node2D, pos: Vector2) -> Node2D:
	if not is_instance_valid(Root.levelRoot): return node
	node.position = pos
	Root.levelRoot.add_child.call_deferred(node)
	return node

static func spawnSupplyDrop(car) -> Node2D:
	var drop = addToLevel(WorldProps.SupplyDrop.new(), aheadOf(car, SUPPLY_DISTANCE))
	PickupEffects.toast("SUPPLY DROP INBOUND", Pickups.rarityColor(Pickups.R.RARE), Pickups.texture("chute"))
	return drop

static func spawnGoldenGoon(car) -> Node2D:
	return addToLevel(WorldProps.GoldenGoon.new(), aheadOf(car, 1100.0))

static func spawnLootTruck(car) -> Node2D:
	var truck = addToLevel(WorldProps.LootTruck.new(), aheadOf(car, 1300.0))
	truck.rotation = car.rotation
	return truck

static func spawnStrongbox(pos: Vector2) -> Node2D:
	return addToLevel(WorldProps.Strongbox.new(), pos)

## Defense: the Sentry Turret sets up on the station wall nearest the car.
static func spawnTurret() -> Node2D:
	if not is_instance_valid(Root.station) || not is_instance_valid(Root.playerCar): return null
	var wall: Vector2 = Root.station.nearestWallPoint(Root.playerCar.global_position)
	return addToLevel(WorldProps.Turret.new(), wall)

## A region wave was survived (Region.gd): an Uncommon-or-better pickup lands ahead of the car.
static func waveChest() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || not is_instance_valid(Root.levelRoot): return
	PickupEffects.spawnPickup(Pickups.rollAtLeast(Pickups.R.UNCOMMON), car.global_position + Vector2.from_angle(car.rotation) * 450.0)

## Speed Trap records per level (meta.records.speedtrap). True for a new record.
static func recordSpeedTrap(mph: int) -> bool:
	if SaveManager.playerData == null: return false
	var level: Dictionary = SaveManager.playerData.levels[SaveManager.playerData.selectedLevel]
	var byLevel: Dictionary = SaveManager.playerData.meta.records.get_or_add("speedtrap", {})
	var key := SaveManager.levelKey(level)
	if mph <= byLevel.get(key, 0): return false
	byLevel[key] = mph #saved with the run at the results ticket
	return true

## Props for a freshly loaded chunk, as children of its object node (TileManager.loadChunk).
static func decorateChunk(objects: Node2D, rng: RandomNumberGenerator) -> void:
	for prop in CHUNK_PROPS:
		if rng.randf() >= prop[0]: continue
		var offset := Vector2(rng.randf_range(-1400.0, 1400.0), rng.randf_range(-600.0, 600.0))
		match prop[1]:
			"crates":
				for i in rng.randi_range(2, 4):
					var crate = WorldProps.Crate.new()
					crate.position = offset + Vector2(i * 95.0, rng.randf_range(-30.0, 30.0))
					objects.add_child(crate)
			"speedtrap": addProp(objects, WorldProps.SpeedTrap.new(), offset)
			"donut": addProp(objects, WorldProps.DonutZone.new(), offset)
			"bullseye": addProp(objects, WorldProps.Bullseye.new(), offset)
			"wheel": addProp(objects, WorldProps.PrizeWheel.new(), offset)
			"rings": addProp(objects, WorldProps.RingRun.new(), offset)
			"bowling": addProp(objects, WorldProps.BowlingLane.new(), offset)

static func addProp(objects: Node2D, prop: Node2D, offset: Vector2) -> void:
	prop.position = offset
	objects.add_child(prop)
