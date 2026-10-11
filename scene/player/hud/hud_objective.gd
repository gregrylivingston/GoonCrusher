class_name HudObjective extends Control

#Top center, on the mirror beside the clock (HudMirror): what the mode wants, in every mode. Countdown: survive the clock. Sprint: the
#station and its distance. Marathon: the leg and its distance. Defense: the base's barrier, its rim flashing
#red when a goon blows up at a pump. Goonpocalypse: the score and the survival target for its star. The
#station's words and distance are in its own blue (HudTheme.STATION), like its pointer.

const STAR_ICON := preload("res://texture/icon/star.svg")

var mode := -1
var framed := true #its own panel; off on the mirror, whose glass is the panel (HudMirror)
var shownKey := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	mode = SaveManager.playerData.gameMode
	set_process(true)

func _process(_delta: float) -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level): return
	var key: Array
	match mode:
		Root.gameModes.GOONPOCALYPSE: key = [level.runScore(), level.targetReached, int(level.pocalypseTarget() - level.seconds)]
		Root.gameModes.SMASH, Root.gameModes.DRIFT: key = [level.trial.score, int(level.trial.chain)] if level.trial else [0]
		Root.gameModes.CONES: key = [level.course.next, level.course.conesHit] if level.course else [0]
		Root.gameModes.RALLY: key = [level.course.next, HudTheme.distanceFrom(GameUI.carOf(self), level.course.target()), HudTheme.stationDistance(GameUI.carOf(self))] if level.course else [0]
		Root.gameModes.CANNONBALL: key = [racePlace(level, GameUI.carOf(self)), HudTheme.stationDistance(GameUI.carOf(self))]
		Root.gameModes.HOTLAP, Root.gameModes.CIRCUIT, Root.gameModes.KNOCKOUT: key = [level.course.lap, level.course.next, loopPlace(level, GameUI.carOf(self)), level.rivals.cars.size() if level.rivals else 0] if level.course else [0]
		Root.gameModes.DERBY: key = [level.rivals.cars.size() if level.rivals else 0]
		Root.gameModes.FLATOUT: key = [level.course.next, HudTheme.stationDistance(GameUI.carOf(self))] if level.course else [0]
		Root.gameModes.KEEPCUP: key = [int(level.cup.playerSeconds()), int(level.cup.rivalBest()), level.cup.playerHolds()] if level.cup else [0]
		Root.gameModes.PURSUIT:
			var prey = level.rivals.runner() if level.rivals else null
			key = [int(prey.health) if prey else -1]
		Root.gameModes.SPRINT: key = [HudTheme.stationDistance(GameUI.carOf(self))]
		Root.gameModes.MARATHON: key = [level.leg, HudTheme.stationDistance(GameUI.carOf(self))]
		Root.gameModes.BOUNTY: key = [level.bounty.caught, HudTheme.distanceFrom(GameUI.carOf(self), level.bounty.markPosition())] if level.bounty else [0]
		Root.gameModes.DEFENSE: key = [int(Root.station.barrier) if is_instance_valid(Root.station) else -1, snappedf(HudTheme.stationHit(), 0.1)]
		_: key = [mode]
	if key != shownKey:
		shownKey = key
		queue_redraw()

#the player's place on a loop, among the cars still running
static func loopPlace(level, car = Root.playerCar) -> int:
	if level.course == null || level.rivals == null || not is_instance_valid(car): return 1
	return level.course.placeOf(car, level.rivals.cars + ([] if car == Root.playerCar else [Root.playerCar]))

#the player's place in a race against rivals, by distance to the station
static func racePlace(level, car = Root.playerCar) -> int:
	if level.rivals == null || not is_instance_valid(Root.station): return 1
	return level.rivals.placeBy(Root.station.drivewayPoint(), car)

func _draw() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level): return
	var hit := HudTheme.stationHit() if mode == Root.gameModes.DEFENSE else 0.0
	if hit > 0.0: HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.BAD, 0.4 + 0.6 * hit), 8, HudTheme.PANEL if framed else Color(HudTheme.BAD, 0.12 * hit))
	elif framed: HudTheme.panel(self, Rect2(Vector2.ZERO, size))
	var mid = size.x * 0.5
	var icon: Texture2D = HudTheme.MODE_ICONS.get(mode)
	if icon && mode != Root.gameModes.GOONPOCALYPSE: HudTheme.icon(self, icon, Vector2(22, size.y * 0.5), 26)
	match mode:
		Root.gameModes.GOONPOCALYPSE:
			HudTheme.text(self, Vector2(18, 29), "SCORE %d" % level.runScore(), 20)
			if level.targetReached:
				HudTheme.text(self, Vector2(size.x - 44, 29), "STAR EARNED", 15, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			else:
				var left = maxi(0, ceili(level.pocalypseTarget() - level.seconds))
				HudTheme.text(self, Vector2(size.x - 44, 29), "STAR IN %d:%02d" % [left / 60, left % 60], 15, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			HudTheme.icon(self, STAR_ICON, Vector2(size.x - 24, size.y * 0.5), 26, Color.WHITE if level.targetReached else Color(1, 1, 1, 0.35))
		Root.gameModes.SMASH, Root.gameModes.DRIFT:
			var t: TrialScore = level.trial
			if t:
				HudTheme.text(self, Vector2(42, 28), "%s %d / %d" % [t.label(), t.score, t.target], 18)
				if t.chain >= 1.0: HudTheme.text(self, Vector2(size.x - 14, 28), "+%d" % int(t.chain), 17, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.CONES:
			var gates: Course = level.course
			if gates:
				HudTheme.text(self, Vector2(42, 28), "GATE %d OF %d" % [mini(gates.next + 1, gates.total()), gates.total()], 18)
				if gates.conesHit > 0: HudTheme.text(self, Vector2(size.x - 14, 28), "%d CONES" % gates.conesHit, 16, HudTheme.BAD, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.RALLY:
			var stage: Course = level.course
			var gates := stage != null && not stage.complete()
			HudTheme.text(self, Vector2(42, 28), "CHECKPOINT %d OF %d" % [stage.next + 1, stage.total()] if gates else "TO THE FINISH", 17)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.distanceFrom(GameUI.carOf(self), stage.target()) if gates else HudTheme.stationDistance(GameUI.carOf(self)), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.HOTLAP:
			var ring: Course = level.course
			if ring:
				HudTheme.text(self, Vector2(42, 28), "LAP %d OF %d" % [mini(ring.lap + 1, ring.laps), ring.laps], 18)
				HudTheme.text(self, Vector2(size.x - 14, 28), "%s / %s" % [Course.clock(ring.bestLap()), Course.clock(level.lapTarget)], 15, HudTheme.GOLD if ring.bestLap() <= level.lapTarget else HudTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.CIRCUIT, Root.gameModes.KNOCKOUT:
			var track: Course = level.course
			if track && level.rivals:
				var at := loopPlace(level, GameUI.carOf(self))
				var cars: int = level.rivals.cars.size() + 1
				HudTheme.text(self, Vector2(42, 28), "%s OF %d" % [Rivals.placeWord(at), cars], 18, HudTheme.BAD if mode == Root.gameModes.KNOCKOUT && at >= cars else HudTheme.TEXT)
				HudTheme.text(self, Vector2(size.x - 14, 28), "LAP %d/%d" % [mini(track.lap + 1, track.laps), track.laps], 16, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.DERBY:
			HudTheme.text(self, Vector2(mid + 12, 28), "%d RIVALS LEFT" % (level.rivals.cars.size() if level.rivals else 0), 18, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Root.gameModes.FLATOUT:
			var strip: Course = level.course
			var more := strip != null && not strip.complete()
			HudTheme.text(self, Vector2(42, 28), "NITRO %d OF %d" % [strip.next + 1, strip.total()] if more else "STOP AT THE LINE", 17)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(GameUI.carOf(self)), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.KEEPCUP:
			var c: KeepCup = level.cup
			if c:
				HudTheme.text(self, Vector2(42, 28), "CUP %d / %d" % [int(c.playerSeconds()), int(c.need)], 18, HudTheme.GOLD if c.playerHolds() else HudTheme.TEXT)
				HudTheme.text(self, Vector2(size.x - 14, 28), "RIVAL %d" % int(c.rivalBest()), 16, HudTheme.BAD if c.rivalBest() > c.playerSeconds() else HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.PURSUIT:
			var prey = level.rivals.runner() if level.rivals else null
			var left: float = clampf(prey.health / ModeTiers.RUNNER_HEALTH[level.tier], 0.0, 1.0) if prey else 0.0
			HudTheme.text(self, Vector2(42, 28), "RUNNER", 17)
			HudTheme.bar(self, Rect2(124, 15, size.x - 144, 12), left, HudTheme.BAD)
		Root.gameModes.CANNONBALL:
			var place := racePlace(level, GameUI.carOf(self))
			HudTheme.text(self, Vector2(42, 28), "%s OF %d" % [Rivals.placeWord(place), level.rivals.field()] if level.rivals else "REACH THE STATION", 18, HudTheme.GOLD if place <= ModeTiers.CUP_PLACE[level.tier] else HudTheme.TEXT)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(GameUI.carOf(self)), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.SPRINT:
			HudTheme.text(self, Vector2(42, 28), "REACH THE STATION", 17)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(GameUI.carOf(self)), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.MARATHON:
			HudTheme.text(self, Vector2(42, 28), "STATION %d OF %d" % [level.leg, level.legs()], 18)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(GameUI.carOf(self)), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.BOUNTY:
			var hunt: BountyHunt = level.bounty
			HudTheme.text(self, Vector2(42, 28), "MARK %d OF %d" % [mini(hunt.caught + 1, hunt.total), hunt.total] if hunt else "FIND THE MARK", 18)
			if hunt: HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.distanceFrom(GameUI.carOf(self), hunt.markPosition()), 17, HudTheme.BAD, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.DEFENSE:
			var fraction = Root.station.barrier / Root.station.BARRIER_MAX if is_instance_valid(Root.station) else 1.0
			HudTheme.text(self, Vector2(42, 28), "BASE", 17, HudTheme.TEXT.lerp(HudTheme.BAD, hit))
			HudTheme.bar(self, Rect2(96, 15, size.x - 164, 12), fraction, HudTheme.conditionColor(fraction * 100.0))
			HudTheme.text(self, Vector2(size.x - 14, 28), "%d%%" % ceili(fraction * 100.0), 17, HudTheme.conditionColor(fraction * 100.0), HORIZONTAL_ALIGNMENT_RIGHT)
		_:
			HudTheme.text(self, Vector2(mid + 12, 28), "SURVIVE THE NIGHT" if mode == Root.gameModes.BLACKOUT else "SURVIVE THE CLOCK", 17, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
