class_name HudCrush extends Control

#Top-left objective: crush XP toward the next gift box (CrushPrizes), and that box's tier. GameUI
#(playerRoot.gd) owns the count and opens the box; this only draws it.

const GIFT_ICON := preload("res://texture/icon/gift.svg")

var shownKey := []
var flash := 0.0: #a gold wash over the panel, tweened down from 1 when its moment comes (GameUI)
	set(value):
		flash = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	HudTheme.marker(self, "currentGoonsCrushedui", Vector2(160, 24))
	HudTheme.marker(self, "slotmachineui", Vector2(33, 31)) #prize pickups (slot, Deal, Claw) fly to the box

func _process(_delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var key = [int(car.crushXp), owner.boxLevel]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var ui = owner
	var tier := CrushPrizes.tierFor(ui.boxLevel + 1)
	var col := CrushPrizes.tierColor(tier)
	HudTheme.panel(self, Rect2(Vector2.ZERO, size))
	draw_circle(Vector2(33, 31), 24, Color(col, 0.3))
	HudTheme.icon(self, GIFT_ICON, Vector2(33, 31), 42)
	HudTheme.text(self, Vector2(66, 33), "%s BOX" % CrushPrizes.tierName(tier).to_upper(), 21, col)
	var span: float = ui.nextBoxXp - ui.boxStartXp
	var progress := 1.0 if span <= 0.0 else clampf((car.crushXp - ui.boxStartXp) / span, 0.0, 1.0)
	HudTheme.bar(self, Rect2(66, 43, 234, 7), progress, col)
	var left := maxi(0, ceili(ui.nextBoxXp - car.crushXp))
	HudTheme.text(self, Vector2(size.x - 14, 22), "%d XP" % left, 14, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 4, HudTheme.OUTLINE, HudTheme.BODY)
	HudTheme.text(self, Vector2(size.x - 14, 40), "to go", 12, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 4, HudTheme.OUTLINE, HudTheme.BODY)
	if flash > 0.0: HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.GOLD, flash), 10)
