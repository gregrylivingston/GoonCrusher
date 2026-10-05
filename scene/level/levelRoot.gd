class_name Level extends Node2D

var spawnerScene = preload("res://scene/player/spawner.tscn")
var explosionScene = preload("res://scene/fx/explosion.tscn") #loaded with the level, not with every car
var playerCar: OverheadCarBody2D
var playerController
@export var seconds = 600 #the run clock. Countdown, Sprint and Marathon count it down; Defense and Goonpocalypse count up from 0

var isDaytime: bool = true
var hasEnded := false #endLevel runs once per run, whichever ending gets there first
var endReason: int = -1 #Root.endCondition once the run has ended
var startPosition: Vector2 #where the car starts; objectives are placed relative to it
var clockReady := false #true once the clock holds its final starting value (Sprint sets it from the station distance)

#Sprint: the station is placed by distance and the clock is derived from the real distance.
const SPRINT_DRIVE_FRACTION = 0.25 #share of the level's authored seconds spent driving at REFERENCE_SPEED
#px/s; a fixed baseline, not the selected car, so fast cars feel fast. The stock sedan tops out at about
#744 on grass, 615 on snow and 499 on sand and mud, so 450 leaves room for rocks, goons and turns.
const REFERENCE_SPEED = 450.0
#the station is never further than this (px): about 0.75 of the stock sedan's tank (87 s at full throttle)
#at its sand and mud top speed, so a run is possible without fuel pickups
const SPRINT_MAX_DISTANCE = 32000.0
const SPRINT_Y_SPREAD = 0.25 #the station's y offset is up to this share of the distance, either way

func _ready():

	#add my car
	var newPosition = $Car.position
	startPosition = newPosition
	$Car.queue_free()
	if is_instance_valid(Root.playerCar): Root.playerCar.queue_free()
	if Root.selectedCar.is_empty(): #level launched directly (editor F6 or benchmark) - fall back to the saved car
		Root.selectedCar = SaveManager.playerData.cars[SaveManager.playerData.selectedCar]
	Root.playerCar = load(Root.selectedCar.scene).instantiate()
	Root.playerCar.position = newPosition
	add_child(Root.playerCar)

	Root.levelRoot = self
	var warmup = ShaderWarmup.new() #compiles gameplay shaders behind the countdown
	warmup.position = newPosition + Vector2(0, 150)
	add_child(warmup)
	Root.isRunActive = true
	Settings.on_run_started()
	
	Root.playerRoot = get_tree().get_nodes_in_group("playerGameUi")[0]
	Root.playerRoot.updateStats()
	
	match SaveManager.playerData.gameMode:
		Root.gameModes.GOONCRUSHER:createCountdownSpawners()
		Root.gameModes.GOONPOCALYPSE:createCountdownSpawners()
		Root.gameModes.MARATHON:createSprintSpawners()
		Root.gameModes.SPRINT:createSprintSpawners()
		#DEFENSE: its spawner goes under the station, which exists only once the world is ready

	match SaveManager.playerData.gameMode:
		Root.gameModes.DEFENSE:
			seconds = 0
		Root.gameModes.GOONPOCALYPSE:
			seconds = 0
		Root.gameModes.MARATHON:
			seconds = seconds * 5 #this is 5 times the length of sprint or countdown

	#the TileManager waits at least one frame before placing stations, so this is never too late
	var tileManager = $TileManager
	if tileManager.isWorldReady: onWorldReady()
	else: tileManager.world_ready.connect(onWorldReady)

#the map is built and every station is placed and in the tree
func onWorldReady() -> void:
	match SaveManager.playerData.gameMode:
		Root.gameModes.SPRINT:
			if is_instance_valid(Root.station):
				seconds = sprintSeconds(startPosition.distance_to(Root.station.global_position), seconds)
		Root.gameModes.DEFENSE:
			if is_instance_valid(Root.station):
				var spawner = newSpawner(Vector2i(4000,800), Root.station)
				#SpawnManager lists the "spawner" group once, a frame after it starts; this one may come later
				if is_instance_valid(Root.spawnManager) && Root.spawnManager.spawners is Array && not spawner in Root.spawnManager.spawners:
					Root.spawnManager.spawners.push_back(spawner)
	clockReady = true
	get_tree().call_group("runTimer", "onClockReady")

#Sprint station offset from the car start, in px: straight ahead (+x), with a y offset of up
#to SPRINT_Y_SPREAD of the distance. yRoll is -1..1.
static func sprintOffsetPx(levelSeconds: float, yRoll: float) -> Vector2:
	var distance = levelSeconds * SPRINT_DRIVE_FRACTION * REFERENCE_SPEED
	return Vector2(distance, distance * SPRINT_Y_SPREAD * clampf(yRoll, -1.0, 1.0)).limit_length(SPRINT_MAX_DISTANCE)

#time allowed per second of reference driving: 1.5 on Easy (250 s) down to 1.1 on Northern Wastes (540 s)
static func sprintSlack(levelSeconds: float) -> float:
	return clampf(1.5 - (levelSeconds - 250.0) / 290.0 * 0.4, 1.1, 1.5)

#the Sprint clock: the real straight-line distance at REFERENCE_SPEED, plus the level's slack
static func sprintSeconds(distancePx: float, levelSeconds: float) -> float:
	return distancePx / REFERENCE_SPEED * sprintSlack(levelSeconds)

#how a run ends when a counting-down clock reaches 0 (Root.endCondition): Countdown is won, the races are lost.
#A wrecked car (exploding, its NOHEALTH ending still pending) has not survived Countdown. A car that only
#ran out of fuel has, matching the rolling finish in station.gd.
static func timeUpCondition(gameMode: int, wrecked: bool = false) -> int:
	if gameMode != Root.gameModes.GOONCRUSHER: return Root.endCondition.NOTIME
	return Root.endCondition.NOHEALTH if wrecked else Root.endCondition.SUCCESS

func timeRanOut() -> void:
	var car = Root.playerCar
	var wrecked = is_instance_valid(car) && (car.isWrecked || car.health <= 0)
	var condition = timeUpCondition(SaveManager.playerData.gameMode, wrecked)
	endLevel(condition == Root.endCondition.SUCCESS, condition)

func createCountdownSpawners():
	newSpawner( Vector2i(4000,2000)) 
	newSpawner( Vector2i(4000,-2000)) 
	
	newSpawner( Vector2i(4000,250) )
	newSpawner( Vector2i(4000,-250))
	newSpawner( Vector2i(-3500,0)) 

func createSprintSpawners():
	newSpawner( Vector2i(4000,800)) 
	newSpawner( Vector2i(4000,-800)) 

	newSpawner( Vector2i(4000,250) )
	newSpawner( Vector2i(4000,-250)) 
	newSpawner( Vector2i(-3500,0)) 
		

func setNighttime(isNighttime: bool):

	if isNighttime:
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(.0,.0,.0,1.0) , 5)
			#if canvasmodulate this is set to .05 powerups and giants glow at night.  If set to 0 they don't
		await get_tree().create_timer(2).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(1).timeout
		Root.playerCar.turnOnHeadlights(true)
	else: 
		get_tree().create_tween().tween_property($CanvasModulate , "color" , Color(1.0,1.0,1.0,1.0) , 5)
		await get_tree().create_timer(1).timeout
		if is_instance_valid(Root.station): Root.station.setNighttime(isNighttime)
		#$AudioStreamPlayer_wolf.play()
		await get_tree().create_timer(2).timeout
		Root.playerCar.turnOnHeadlights(false)
	
#spawners are children of the car by default, so their offsets rotate with it
func newSpawner( spawnerPosition: Vector2i, parent: Node = null ):
	var newSpawner = spawnerScene.instantiate()
	newSpawner.position = spawnerPosition
	(parent if parent != null else Root.playerCar).add_child(newSpawner)
	return newSpawner

	


	
#Every ending (car NOHEALTH/NOGAS, station SUCCESS, clock SUCCESS/NOTIME, abandon) comes here.
#Only the first counts: later calls, such as a car's pending NOGAS timer firing after the summary
#paused the tree (SceneTreeTimers run while paused), return at once.
func endLevel(levelCompleted: bool, reason):  #reason takes Root.endCondition
	if hasEnded: return
	hasEnded = true
	endReason = reason
	if is_instance_valid(Root.playerCar): Root.playerCar.isDestroyed = true
	var gameSummary = load("res://scene/player/menu/gameSummary.tscn").instantiate()
	gameSummary.reason = reason 
	if levelCompleted:
		$AudioStreamPlayer.stream = load("res://sound/fx/slotmachine/winner_3.mp3")
		$AudioStreamPlayer.play()
		gameSummary.levelCompleted = true
	add_child( gameSummary )
	get_tree().paused = true


func getTileByCoordinates(coord: Vector2i):
	return $TileManager.getTile(coord)
