class_name HudObjective extends Control

#Top center, under the clock: what the mode wants, in every mode. Countdown: survive the clock. Sprint: the
#station and its distance. Marathon: the leg and its distance. Defense: the base's barrier, its rim flashing
#red when a goon blows up at a pump. Goonpocalypse: the score and the survival target for its star. The
#station's words and distance are in its own blue (HudTheme.STATION), like its pointer.

const STAR_ICON := preload("res://texture/icon/star.svg")

var mode := -1
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
		Root.gameModes.SPRINT: key = [HudTheme.stationDistance()]
		Root.gameModes.MARATHON: key = [level.leg, HudTheme.stationDistance()]
		Root.gameModes.DEFENSE: key = [int(Root.station.barrier) if is_instance_valid(Root.station) else -1, snappedf(HudTheme.stationHit(), 0.1)]
		_: key = [mode]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level): return
	var hit := HudTheme.stationHit() if mode == Root.gameModes.DEFENSE else 0.0
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.BAD, 0.4 + 0.6 * hit) if hit > 0.0 else Color(HudTheme.RIM, 0.55))
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
		Root.gameModes.SPRINT:
			HudTheme.text(self, Vector2(42, 28), "REACH THE STATION", 17)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.MARATHON:
			HudTheme.text(self, Vector2(42, 28), "STATION %d OF %d" % [level.leg, level.legs()], 18)
			HudTheme.text(self, Vector2(size.x - 14, 28), HudTheme.stationDistance(), 17, HudTheme.STATION, HORIZONTAL_ALIGNMENT_RIGHT)
		Root.gameModes.DEFENSE:
			var fraction = Root.station.barrier / Root.station.BARRIER_MAX if is_instance_valid(Root.station) else 1.0
			HudTheme.text(self, Vector2(42, 28), "BASE", 17, HudTheme.TEXT.lerp(HudTheme.BAD, hit))
			HudTheme.bar(self, Rect2(96, 15, size.x - 164, 12), fraction, HudTheme.conditionColor(fraction * 100.0))
			HudTheme.text(self, Vector2(size.x - 14, 28), "%d%%" % ceili(fraction * 100.0), 17, HudTheme.conditionColor(fraction * 100.0), HORIZONTAL_ALIGNMENT_RIGHT)
		_:
			HudTheme.text(self, Vector2(mid + 12, 28), "SURVIVE THE CLOCK", 17, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
