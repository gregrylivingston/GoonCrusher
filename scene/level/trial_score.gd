class_name TrialScore extends Node
## A Trial won by reaching a score before the clock runs out (docs/MODES.md), on a
## fixed map with no goons: Smash Run counts the breakables the car smashes (Level.propSmashed), Drift Trial
## scores slides. Reaching the target wins; the time it took goes in the record book (SaveManager.recordCourse).
## Level adds one in those modes; HudObjective shows the score.
##
## Drift scoring: every tick of a held slide (the handbrake's drift charge rising, OverheadCarBody2D.tickDriftCharge)
## adds speed / DRIFT_SPEED_PER_POINT points to a chain, doubled from the blue-spark tier and tripled from the
## orange; the chain banks when the slide ends, if it lasted DRIFT_MIN_TICKS. Every number is a first guess.

const DRIFT_SPEED_PER_POINT := 100.0
const DRIFT_MIN_TICKS := 20

var mode := -1
var score := 0
var target := 1
var chain := 0.0      #Drift Trial: the slide in progress, not banked yet
var chainTicks := 0
var lastCharge := 0

func _ready() -> void:
	var level = Root.levelRoot
	mode = level.runMode
	target = ModeTiers.trialTarget(mode, level.tier)
	set_physics_process(mode == Root.gameModes.DRIFT)

func add(points: int) -> void:
	var level = Root.levelRoot
	if points <= 0 || not is_instance_valid(level) || level.hasEnded: return
	score += points
	if score >= target: level.endLevel.call_deferred(true, Root.endCondition.SUCCESS)

## "SMASHED" or "DRIFT": the HUD's word for the score
func label() -> String:
	return "DRIFT" if mode == Root.gameModes.DRIFT else "SMASHED"

func _physics_process(_delta: float) -> void:
	var car = Root.playerCar
	var level = Root.levelRoot
	if not is_instance_valid(car) || not is_instance_valid(level) || level.hasEnded || not level.clockReady: return
	var charge: int = car.driftCharge
	if charge > lastCharge: #the slide is holding
		chain += car.velocity.length() / DRIFT_SPEED_PER_POINT * (2 + car.tierFor(charge))
		chainTicks += 1
	elif charge == 0 && chainTicks > 0: #let go, caught or stopped: bank it
		if chainTicks >= DRIFT_MIN_TICKS:
			var points := roundi(chain)
			var fx = Root.spawnManager.fx if is_instance_valid(Root.spawnManager) else null
			if fx: fx.label(car.global_position, "+%d" % points, 24)
			add(points)
		chain = 0.0
		chainTicks = 0
	lastCharge = charge
