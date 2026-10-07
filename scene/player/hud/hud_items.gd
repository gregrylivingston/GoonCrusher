class_name HudItems extends Control

#Above the systems strip (docs/HUD.md): the held gadget on the left with its charges and the Fire key,
#the held boost beside it with the Boost key, small counters left of them (star fragments, lottery
#tickets, a parcel, barricades), and on the right a ring per timed power-up that drains clockwise and
#blinks in its last 2 s. Gadgets fly to "itemui", boosts to "moveui", power-ups to "buffui" and clock
#pickups to "clockui" (on the run clock). Redraws only on change.

const BOX := 58.0
const RING := 25.0
const RING_PITCH := 60.0

var box := Vector2.ZERO        #centre of the held gadget's box
var moveBox := Vector2.ZERO    #centre of the held boost's box
var rings := Vector2.ZERO      #centre of the first ring
var shownKey := []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	box = Vector2(size.x * 0.5 - 235.0, size.y - BOX * 0.5 - 4.0)
	rings = Vector2(size.x * 0.5 + 130.0, size.y - RING - 6.0)
	moveBox = box + Vector2(BOX + 52.0, 0)
	HudTheme.marker(self, "itemui", box)
	HudTheme.marker(self, "moveui", moveBox)
	HudTheme.marker(self, "buffui", rings)
	var top = get_parent().get_node_or_null("TopCenter")
	if top: HudTheme.marker(top, "clockui", Vector2(top.size.x * 0.5, 40.0))

func _process(_delta: float) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	var key := [car.heldItem, car.heldCharges, car.moveItem, car.moveCharges, car.starFragments, car.lotteryTickets.size(), car.hasParcel, car.barricades, InputGlyphs.usingPad]
	for id in car.buffs: key.append_array([id, car.buffs[id] / 6, car.buffs[id] < 120 && HudTheme.blinkOn()])
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car): return
	drawSlot(box, car.heldItem, car.heldCharges, "UseItem")
	drawSlot(moveBox, car.moveItem, car.moveCharges, "UseMove")
	#counters to the left of the box
	var x := box.x - BOX * 0.5 - 20.0
	if car.starFragments > 0: #three pips, lit for each fragment held
		for i in 3:
			HudTheme.icon(self, HudTheme.STAR_ICON, Vector2(x - (2 - i) * 22.0, box.y - 14.0), 22.0, Color.WHITE if i < car.starFragments else Color(0.3, 0.3, 0.3, 0.6))
	var counters := [] #[icon, count] in a row under the pips, right to left
	if car.lotteryTickets.size() > 0: counters.push_back([Pickups.texture("lottery"), car.lotteryTickets.size()])
	if car.hasParcel: counters.push_back([Pickups.texture("delivery"), 1])
	if car.barricades > 0: counters.push_back([Pickups.texture("barricade"), car.barricades])
	for i in counters.size():
		var c := Vector2(x - i * 40.0, box.y + 14.0)
		HudTheme.icon(self, counters[i][0], c, 28.0)
		if counters[i][1] > 1: HudTheme.text(self, c + Vector2(12.0, 12.0), str(counters[i][1]), 14, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)
	#timed power-ups
	var i := 0
	for id in car.buffs:
		var c := rings + Vector2(i * RING_PITCH, 0)
		var left: int = car.buffs[id]
		var fraction := float(left) / maxf(1.0, car.buffTicks.get(id, left))
		var col := Pickups.rarityColor(Pickups.rarity(id))
		draw_circle(c, RING + 2.0, Color(0.055, 0.047, 0.043, 0.88))
		draw_arc(c, RING - 2.0, 0.0, TAU, 32, HudTheme.TRACK, 5.0, true)
		if left >= 120 || HudTheme.blinkOn(): HudTheme.arc(self, c, RING - 2.0, 0.0, 360.0 * fraction, col, 5.0)
		HudTheme.icon(self, Pickups.texture(id), c, 30.0)
		HudTheme.text(self, c + Vector2(0, RING + 14.0), "%d" % ceili(left / float(Pickups.TICKS)), 13, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)
		i += 1

#a held item's box: rarity frame, icon, charges badge and the key that fires it
func drawSlot(at: Vector2, id: String, charges: int, action: String) -> void:
	if id == "": return
	var col := Pickups.rarityColor(Pickups.rarity(id))
	HudTheme.panel(self, Rect2(at - Vector2(BOX, BOX) * 0.5, Vector2(BOX, BOX)), col, 10)
	HudTheme.icon(self, Pickups.texture(id), at, 44.0)
	if charges > 1:
		draw_circle(at + Vector2(BOX * 0.5, -BOX * 0.5), 11.0, col)
		HudTheme.text(self, at + Vector2(BOX * 0.5, -BOX * 0.5 + 6.0), str(charges), 15, HudTheme.OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, 0)
	var keyName := InputGlyphs.label(action)
	if keyName != "": HudTheme.text(self, at + Vector2(BOX * 0.5 + 8.0, 8.0), keyName, 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 5)
