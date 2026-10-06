class_name HudObjective extends Control

#Top center, under the clock: the mode's own goal. Goonpocalypse: the score and the survival target for
#its star. Marathon: the leg. Defense: the barrier's health. Hidden in Countdown and Sprint, where the
#clock says it all.

const STAR_ICON := preload("res://texture/icon/star.svg")

var mode := -1
var shownKey := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	mode = SaveManager.playerData.gameMode
	visible = mode in [Root.gameModes.GOONPOCALYPSE, Root.gameModes.MARATHON, Root.gameModes.DEFENSE]
	set_process(visible)

func _process(_delta: float) -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level): return
	var key: Array
	match mode:
		Root.gameModes.GOONPOCALYPSE: key = [level.runScore(), level.targetReached, int(level.pocalypseTarget() - level.seconds)]
		Root.gameModes.MARATHON: key = [level.leg]
		Root.gameModes.DEFENSE: key = [int(Root.station.barrier) if is_instance_valid(Root.station) else -1]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var level = Root.levelRoot
	if not is_instance_valid(level): return
	HudTheme.panel(self, Rect2(Vector2.ZERO, size))
	var mid = size.x * 0.5
	match mode:
		Root.gameModes.GOONPOCALYPSE:
			HudTheme.text(self, Vector2(18, 29), "SCORE %d" % level.runScore(), 20)
			if level.targetReached:
				HudTheme.text(self, Vector2(size.x - 44, 29), "STAR EARNED", 15, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			else:
				var left = maxi(0, ceili(level.pocalypseTarget() - level.seconds))
				HudTheme.text(self, Vector2(size.x - 44, 29), "STAR IN %d:%02d" % [left / 60, left % 60], 15, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
			HudTheme.icon(self, STAR_ICON, Vector2(size.x - 24, size.y * 0.5), 26, Color.WHITE if level.targetReached else Color(1, 1, 1, 0.35))
		Root.gameModes.MARATHON:
			HudTheme.text(self, Vector2(mid, 29), "STATION %d OF %d" % [level.leg, Level.MARATHON_LEGS], 20, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		Root.gameModes.DEFENSE:
			var fraction = Root.station.barrier / Root.station.BARRIER_MAX if is_instance_valid(Root.station) else 1.0
			HudTheme.text(self, Vector2(18, 29), "BARRIER", 18)
			HudTheme.bar(self, Rect2(116, 15, size.x - 134, 12), fraction, HudTheme.conditionColor(fraction * 100.0))
