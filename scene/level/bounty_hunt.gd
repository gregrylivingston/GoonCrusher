class_name BountyHunt extends Node
## Bounty Hunt (Modes, Root.gameModes.BOUNTY): marked goons, one at a time, each further off and tougher than
## the last, on Countdown's map and spawners. The HUD points at the mark (HudChance.drawMark); crushing every
## mark before the clock runs out wins (Level.timeUpCondition loses it). Level adds one of these in a Bounty run.
##
## A mark is a giant from the level's line-up, weakest first, with a red ring under it and an escort. It is never
## swept (the "bounty" meta, SpawnManager.despawnSweep). Only a death the car caused counts (Walker.deathCause):
## a mark that drowns or blows itself up is replaced by another.
## Every number is a first guess (docs/GAMEPLAY_SUGGESTIONS.md, package 18).

const FIRST_DISTANCE := 3200.0 #px from the car to the first mark
const STEP_DISTANCE := 500.0   #each later mark is this much further
const ESCORT := 2              #goons around the first mark; one more for each mark after
const RING_COLOR := Color(1.0, 0.22, 0.16, 0.85)
const NO_CREDIT := [&"", &"drown", &"self"] #deaths the car didn't cause
#a mark's strength over a plain giant, per mark already caught: faster and harder-hitting, a little harder to crush
const STEP := {"speed": 0.05, "damage": 0.15, "crush": 0.04}

var total := 3
var caught := 0
var mark: Walker

func _ready() -> void:
	total = ModeTiers.BOUNTY_MARKS[ModeTiers.clampTier(Root.levelRoot.tier)]

## The first mark; Level calls it once the world is ready
func begin() -> void:
	spawnMark()

## Where the HUD and the AI driver point: the mark, or Vector2.INF between marks
func markPosition() -> Vector2:
	return mark.global_position if is_instance_valid(mark) && not mark.dead else Vector2.INF

## The level's line-up, weakest first: the marks go up it as the hunt goes on
func markId() -> StringName:
	var lineup := LevelRoster.lineupFor(Root.levelRoot.def)
	if lineup.is_empty(): return &"grunt"
	lineup.sort_custom(func(a, b): return Goons.DATA[a].get("rank", 1) < Goons.DATA[b].get("rank", 1))
	return lineup[mini(caught * (lineup.size() - 1) / maxi(total - 1, 1), lineup.size() - 1)]

## Dry land about `distance` from `from`: the first of a ring of tries a goon can stand on
static func findSpot(from: Vector2, distance: float) -> Vector2:
	var start := randf() * TAU
	for ring in 3:
		for i in 12:
			var spot := from + Vector2.from_angle(start + i * TAU / 12.0) * distance * (1.0 + 0.2 * ring)
			if World.spawnableAt(spot): return spot
	return from + Vector2.from_angle(start) * distance

func spawnMark() -> void:
	var sm = Root.spawnManager
	var car = Root.playerCar
	if not is_instance_valid(sm) || not is_instance_valid(car) || Root.levelRoot.hasEnded: return
	var id := markId()
	var spot := findSpot(car.global_position, FIRST_DISTANCE + STEP_DISTANCE * caught)
	mark = sm.makeGoon(id)
	mark.isGiant = true
	mark.set_meta(&"bounty", true)
	mark.position = spot
	sm.registerGoon(mark)
	Root.levelRoot.add_child(mark)
	mark.applyStrength({"speed": 1.0 + STEP.speed * caught, "damage": 1.0 + STEP.damage * caught, "crush": 1.0 + STEP.crush * caught})
	var ring := Sprite2D.new()
	ring.texture = Walker.RING_TEXTURE
	ring.modulate = RING_COLOR
	ring.z_index = -1
	ring.scale = Vector2.ONE * 380.0 / Walker.RING_TEXTURE.get_width()
	mark.add_child(ring)
	mark.tree_exiting.connect(onMarkGone.bind(mark))
	var lineup := LevelRoster.lineupFor(Root.levelRoot.def)
	if not lineup.is_empty(): sm.spawnGroup(lineup[0], spot + Vector2(90.0, 0.0), ESCORT + caught)

func onMarkGone(goon: Walker) -> void:
	var level = Root.levelRoot
	if goon != mark || not is_instance_valid(level) || not level.is_inside_tree() || level.hasEnded: return
	mark = null
	if goon.deathCause in NO_CREDIT:
		spawnMark.call_deferred() #it drowned or wandered off: another takes its place
		return
	caught += 1
	if caught >= total:
		level.endLevel.call_deferred(true, Root.endCondition.SUCCESS)
		return
	TapeBanner.post("MARK %d OF %d DOWN" % [caught, total], 1.2)
	spawnMark.call_deferred()
