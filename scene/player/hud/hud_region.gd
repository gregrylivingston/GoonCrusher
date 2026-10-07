class_name HudRegion extends Control

#Top-left chip under the crush goal: the region you're in, its goon size, and the wave timer.
#Each region pays a star for every wave you survive in it, up to 3 (Region.gd); no limit in Goonpocalypse.

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
	var key = [Region.currentRegion.get("wave", 0), int(Region.currentRegion.get("time", 0.0)), regionName]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.SKY, 0.45))
	var ring = Vector2(30, 27)
	draw_arc(ring, 15, 0.0, TAU, 32, Color(0.184, 0.227, 0.251), 5, true)
	var wave: int = Region.currentRegion.get("wave", 0)
	var time: float = Region.currentRegion.get("time", 0.0)
	var length = Region.waveLength
	var detail := ""
	if wave >= Region.waveCap():
		HudTheme.arc(self, ring, 15, 0.0, 360.0, HudTheme.SKY, 5)
		detail = "All waves survived"
	elif wave > 0:
		HudTheme.arc(self, ring, 15, 0.0, 360.0 * clampf((time - (wave - 1) * length) / length, 0.0, 1.0), HudTheme.SKY, 5)
		var left = maxi(0, ceili(wave * length - time))
		detail = "Wave %d: survive %d:%02d for a star" % [wave, left / 60, left % 60]
	HudTheme.text(self, Vector2(58, 24), regionName, 19)
	HudTheme.text(self, Vector2(58, 45), detail, 14, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 5, HudTheme.OUTLINE, HudTheme.BODY)
	if regionName != "":
		HudTheme.icon(self, MUTATION_ICON, Vector2(307, 18), 18)
		HudTheme.text(self, Vector2(348, 24), "%d%%" % giantism, 15, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 5)
	if flash > 0.0: HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.GOLD, flash), 10)
