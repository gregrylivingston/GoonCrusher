class_name CarTraitRig extends Node

#The car traits that are rules rather than handling (CarTraits, docs/CAR_ART.md "Traits"): the car makes
#one when it has any trait and ticks it after its own move (tick). Handling traits live in the car's
#integrate(), read from the flags it caches; this holds the state those flags read (twoWheels,
#loadDropped) and everything else: the meter, duct tape, the van's tip and roll, the lightbar, the bed's
#crates, low clearance's scraping and Drop the Load.
#Rewards here credit at once (car.reward), never from an animation.

var car: OverheadCarBody2D

#--- Top-Heavy (the van) ---
const TIP_SHARE := 0.85        #share of the car's turn limit that starts lifting it...
const TIP_SPEED := 450.0       #...above this speed...
const TIP_TICKS := 12          #...held this long
const LAND_SHARE := 0.5        #it drops back below this share or TIP_SPEED * 0.7
const ROLL_TICKS := 75         #up this long and it rolls
const ROLL_KEEP := 0.35        #speed kept through a roll
const ROLL_HEALTH := 6.0       #health a roll costs
const ROLL_LOCK := 45          #ticks the driver has no control while it rights itself
var tipHeld := 0
var upTicks := 0
var controlLock := 0

#--- The Meter (the taxi) ---
const METER_SPEED := 300.0     #px/s it must keep above
const METER_STOP := 120.0      #below this the meter resets
const METER_PX := 450.0        #a fare's worth of driving...
const METER_STEP := 600        #...paying one more coin each fare per this many ticks of clean running, up to
const METER_MAX := 3
var meterPx := 0.0
var meterTicks := 0
var meterMult := 1
var meterFare := 0             #coins this fare has paid so far, for the taximeter (HudInstrument)

#--- Duct Tape (the sedan) ---
const TAPE_WAIT := 180         #ticks clean before it starts patching
const TAPE_CAP := 60.0         #condition it patches back up to
const TAPE_STEP := 1.0         #condition per patch, every 30 ticks
var lastPatch := 0

#--- Loaded Bed (the pickup) ---
const BED_MAX := 5
const BED_BONUS := 0.05        #payout per crate
const BED_SPILL_SPEED := 300.0 #px/s into a wall that spills a crate
const BED_SLOTS := [Vector2(-17, 30), Vector2(17, 30), Vector2(-17, 62), Vector2(17, 62), Vector2(0, 92)] #sheet units (the bed)
const NOT_CARGO := ["coin", "gem", "star", "health", "fuel", "currentGoonsCrushed"]
var bedCrates := 0
var bedSprites: Array[Sprite2D] = []

#--- Low Clearance (the supercar) ---
const SCRAPE_WEAR := 1.5       #engine condition per scrape, every 30 ticks on rough ground at speed
const SCRAPE_SPEED := 250.0

#--- Lightbar (the police) ---
const LIGHTBAR_RADIUS := 900.0
var lightbar: Array[PointLight2D] = []

#--- Drop the Load (the semi) ---
const DROP_CRATES := 7
const DROP_RESTOCK := 40.0     #seconds until the trailer is loaded again
const DROP_CRUSH_RADIUS := 70.0
const DROP_LIFETIME := 25.0    #seconds the crates stand before they're cleared away
const CRATE_SCENE := "res://world/art/props/crate.tscn"
var restockTicks := 0
var abilityWasDown := false

func _ready() -> void:
	if car.tLightbar: buildLightbar()
	if car.tLoadedBed: buildBed()
	car.rewarded.connect(onRewarded)

## One physics tick, after the car has moved
func tick(delta: float) -> void:
	var now := Engine.get_physics_frames()
	var speed := car.velocity.length()
	if controlLock > 0: controlLock -= 1
	if car.tTopHeavy: tickTip(speed)
	if car.tMeter: tickMeter(speed, delta)
	if car.tDuctTape && now % 30 == 0: tickTape(now, speed)
	if car.tLowClearance && now % 30 == 0: tickScrape(speed)
	if car.tLightbar: tickLightbar(now)
	if car.tDropLoad: tickDrop()

#--- Top-Heavy ---

func tickTip(speed: float) -> void:
	var limit := car.yawLimit(speed)
	var share := absf(car.spinRate) / limit if limit > 0.01 else 0.0
	if car.twoWheels:
		upTicks += 1
		if upTicks >= ROLL_TICKS: roll()
		elif share < LAND_SHARE || speed < TIP_SPEED * 0.7:
			car.twoWheels = false
			upTicks = 0
			if is_instance_valid(car.juice): car.juice.landTwoWheels()
		return
	tipHeld = tipHeld + 1 if share >= TIP_SHARE && speed >= TIP_SPEED else 0
	if tipHeld >= TIP_TICKS:
		car.twoWheels = true
		tipHeld = 0
		upTicks = 0

## Over it goes: most of the speed lost, a knock to the hull and the steering, and a moment with no control
func roll() -> void:
	car.twoWheels = false
	upTicks = 0
	tipHeld = 0
	controlLock = ROLL_LOCK
	car.velocity *= ROLL_KEEP
	car.rotation += signf(car.spinRate) * 0.7 if car.spinRate != 0.0 else 0.7
	car.loseHealth(ROLL_HEALTH)
	car.wearSystem("steering", 10.0)
	if is_instance_valid(car.juice): car.juice.bump(1.0)
	if car.isPlayer: Settings.vibrate(0.6, 0.9, 0.35)
	label("ROLLED!", Color(1.0, 0.45, 0.3))

#--- The Meter ---

func tickMeter(speed: float, delta: float) -> void:
	if speed < METER_STOP:
		resetMeter()
		return
	if speed < METER_SPEED: return #between the two: the meter waits
	meterTicks += 1
	meterMult = mini(1 + meterTicks / METER_STEP, METER_MAX)
	meterPx += speed * delta
	while meterPx >= METER_PX:
		meterPx -= METER_PX
		car.reward("coin", meterMult)
		meterFare += meterMult

func resetMeter() -> void:
	meterPx = 0.0
	meterTicks = 0
	meterMult = 1
	meterFare = 0

#--- Duct Tape ---

func tickTape(now: int, speed: float) -> void:
	if now - car.lastHurtTick < TAPE_WAIT || speed < 50.0 || car.isDestroyed: return
	for system in car.condition:
		var c: float = car.condition[system]
		if c < TAPE_CAP: car.setCondition(system, minf(TAPE_CAP, c + TAPE_STEP))

## Duct Tape is patching right now: clean for long enough, moving, and something still under the cap (the HUD's tape strip)
func taping() -> bool:
	if not car.tDuctTape || car.isDestroyed || car.velocity.length() < 50.0 || Engine.get_physics_frames() - car.lastHurtTick < TAPE_WAIT: return false
	for system in car.condition:
		if car.condition[system] < TAPE_CAP: return true
	return false

#--- Low Clearance ---

func tickScrape(speed: float) -> void:
	if speed < SCRAPE_SPEED || not car.isRough(World.surfaceAt(car.global_position)): return
	car.setCondition("engine", car.condition.engine - SCRAPE_WEAR) #straight to the condition: wearSystem's cooldown would skip most
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.fx && randf() < 0.5: Root.spawnManager.fx.dust(car.global_position)

#--- walls (the car's collideWithFixedObject) ---

## A wall contact this tick: `into` the speed into it, `fresh` a new hit rather than a scrape
func onWall(into: float, fresh: bool) -> void:
	if car.tMeter && fresh: resetMeter()
	if car.tTopHeavy && car.twoWheels && fresh: roll()
	if car.tLoadedBed && fresh && into >= BED_SPILL_SPEED && bedCrates > 0: spillCrate()

#--- Loaded Bed ---

func buildBed() -> void:
	var sprite: Node2D = car.get_node("sprite")
	var tex: Texture2D = load("res://world/art/props/crate.png")
	for slot in BED_SLOTS:
		var s := Sprite2D.new()
		s.texture = tex
		s.position = slot
		s.scale = Vector2.ONE * (26.0 / maxf(tex.get_width(), 1.0))
		s.visible = false
		sprite.add_child(s)
		bedSprites.push_back(s)

func onRewarded(powerup: String, _quantity) -> void:
	if not car.tLoadedBed || NOT_CARGO.has(powerup) || not Pickups.has(powerup) || bedCrates >= BED_MAX: return
	bedCrates += 1
	showBed()

func spillCrate() -> void:
	bedCrates -= 1
	showBed()
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.fx: Root.spawnManager.fx.dust(car.to_global(Vector2(-90, 0)))
	label("CRATE LOST", Color(1.0, 0.6, 0.3))

func showBed() -> void:
	for i in bedSprites.size(): bedSprites[i].visible = i < bedCrates

## The payout multiplier the bed's crates add (Level.runPayout)
func payoutBonus() -> float:
	return 1.0 + BED_BONUS * bedCrates if car.tLoadedBed else 1.0

#--- Lightbar ---

func buildLightbar() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var lamps: Node2D = car.get_node("headlamps") #on only at night
	for col in [Color(1.0, 0.18, 0.15), Color(0.2, 0.45, 1.0)]:
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = LIGHTBAR_RADIUS * 2.0 / 256.0
		l.color = col
		l.energy = 0.0
		l.shadow_enabled = true
		lamps.add_child(l)
		lightbar.push_back(l)

## Red and blue in turn, four flashes a second
func tickLightbar(now: int) -> void:
	var red := (now / 8) % 2 == 0
	lightbar[0].energy = 0.9 if red else 0.25
	lightbar[1].energy = 0.25 if red else 0.9

#--- Drop the Load ---

func tickDrop() -> void:
	if restockTicks > 0:
		restockTicks -= 1
		if restockTicks == 0:
			car.loadDropped = false
			label("RESTOCKED", HudTheme.GOLD)
	var down := car.isPlayer && not car.isDestroyed && car.actionDown("Ability")
	if down && not abilityWasDown && not car.loadDropped: dropLoad()
	abilityWasDown = down

## 0 to 1: how far the trailer is through restocking (1 when loaded), for the HUD
func abilityReady() -> float:
	if not car.tDropLoad: return 0.0
	return 1.0 - float(restockTicks) / (DROP_RESTOCK * Engine.physics_ticks_per_second) if car.loadDropped else 1.0

## The cargo out the back of the trailer: a fan of crates that flattens goons under them and then stands
## as a barrier; the trailer runs empty (lighter) until it restocks
func dropLoad() -> void:
	if not is_instance_valid(Root.levelRoot) || car.trailer == null: return
	car.loadDropped = true
	restockTicks = int(DROP_RESTOCK * Engine.physics_ticks_per_second)
	var trailer := car.trailer
	var back := -trailer.global_transform.x
	var side := trailer.global_transform.y
	var tail := trailer.to_global(Vector2(trailer.bodyRect.position.x, 0.0)) + back * 40.0
	var scene: PackedScene = load(CRATE_SCENE)
	var script: Script = load("res://scripts/world/breakable.gd")
	for i in DROP_CRATES:
		var row := i / 4
		var col := (i % 4) - 1.5 if row == 0 else (i % 4) - 1.0
		var pos := tail + back * (row * 60.0 + randf_range(-8.0, 8.0)) + side * (col * 58.0 + randf_range(-6.0, 6.0))
		for goon in Root.spawnManager.goonsNear(pos, DROP_CRUSH_RADIUS) if is_instance_valid(Root.spawnManager) else []:
			if not goon.dead: car.crushGoon(goon, 600.0)
		var crate: Node2D = scene.instantiate()
		crate.set_script(script)
		crate.set_meta(&"dropped", true) #smashing it spills no coins (BreakableProp.smashNode)
		crate.global_position = pos
		crate.rotation = randf_range(-0.4, 0.4)
		Root.levelRoot.add_child(crate)
		Root.levelRoot.get_tree().create_timer(DROP_LIFETIME + i * 0.1, false).timeout.connect(clearCrate.bind(crate))
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.fx: Root.spawnManager.fx.dust(tail)
	if car.isPlayer: Settings.vibrate(0.5, 0.7, 0.25)
	label("LOAD DROPPED", HudTheme.RIM)

static func clearCrate(crate: Node) -> void:
	if is_instance_valid(crate): crate.queue_free()

#--- helpers ---

func label(text: String, col: Color) -> void:
	if not car.isPlayer || not is_instance_valid(Root.spawnManager) || not Root.spawnManager.fx: return
	Root.spawnManager.fx.label(car.global_position + Vector2(0, -90), text, 22, col)
