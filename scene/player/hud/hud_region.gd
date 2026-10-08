class_name HudRegion extends Control

#Top-left chip under the crush goal: the district you're in, its goon size, and the run's wave timer.
#Waves are one clock for the whole run (Region.gd): every wave survived pays a star, with no limit.

const MUTATION_ICON := preload("res://texture/icon/mutation.svg")

var regionName := ""
var giantism := 0
var shownKey := []
var flash := 0.0: #a gold wash over the panel, tweened down from 1 when its moment comes (GameUI)
	set(value):
		flash = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

#called through GameUI when the car enters a tile; impassable ones (water, hills) keep the last region's name
func updatePlayerRegion(tile) -> void:
	if not World.isPassable(tile.terrain): return
	var region = Region.getRegion(tile.region, tile.terrain)
	regionName = str(region.name)
	giantism = region.giantism
	queue_redraw()

func _process(_delta: float) -> void:
	var key = [Region.wave, int(Region.runTime), regionName]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.SKY, 0.45))
	var ring = Vector2(30, 27)
	draw_arc(ring, 15, 0.0, TAU, 32, Color(0.184, 0.227, 0.251), 5, true)
	HudTheme.arc(self, ring, 15, 0.0, 360.0 * Region.waveProgress(), HudTheme.SKY, 5)
	var left := Region.waveSecondsLeft()
	var detail := "Wave %d: survive %d:%02d for a star" % [Region.wave, left / 60, left % 60]
	HudTheme.text(self, Vector2(58, 24), regionName, 19)
	HudTheme.text(self, Vector2(58, 45), detail, 14, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 5, HudTheme.OUTLINE, HudTheme.BODY)
	if regionName != "":
		HudTheme.icon(self, MUTATION_ICON, Vector2(307, 18), 18)
		HudTheme.text(self, Vector2(348, 24), "%d%%" % giantism, 15, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 5)
	if flash > 0.0: HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.GOLD, flash), 10)
