class_name HudCrush extends Control

#Top-left objective: how many more goons to crush for the next star and free slot machine.
#GameUI (playerRoot.gd) owns the goal; this only draws it.

const SLOT_ICON := preload("res://texture/icon/slotMachine.svg")
const STAR_ICON := preload("res://texture/icon/star.svg")

var shownKey := []
var flash := 0.0: #a gold wash over the panel, tweened down from 1 when its moment comes (GameUI)
	set(value):
		flash = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	HudTheme.marker(self, "currentGoonsCrushedui", Vector2(160, 24))
	HudTheme.marker(self, "slotmachineui", Vector2(33, 31))

func _process(_delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var key = [car.currentGoonsCrushed, owner.nextCrushingAward, owner.crushGoalStart]
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var ui = owner
	HudTheme.panel(self, Rect2(Vector2.ZERO, size))
	HudTheme.icon(self, SLOT_ICON, Vector2(33, 31), 42)
	var left = maxi(0, int(ui.nextCrushingAward) - car.currentGoonsCrushed)
	HudTheme.text(self, Vector2(66, 33), "CRUSH %d MORE" % left, 23)
	var span = ui.nextCrushingAward - ui.crushGoalStart
	var progress = 1.0 if span <= 0.0 else (car.currentGoonsCrushed - ui.crushGoalStart) / span
	HudTheme.bar(self, Rect2(66, 43, 234, 7), progress, HudTheme.RIM)
	HudTheme.icon(self, STAR_ICON, Vector2(331, 31), 38)
	if flash > 0.0: HudTheme.panel(self, Rect2(Vector2.ZERO, size), Color(HudTheme.GOLD, flash), 10)
