class_name HudItems extends Control

#Along the bottom edge, between the dials (docs/HUD.md): the held gadget on the left with its charges and the Fire key,
#the held boost beside it with the Boost key, small counters left of them (star fragments, lottery
#tickets, a parcel, barricades), and on the right a ring per timed power-up that drains clockwise and
#blinks in its last 2 s. Gadgets fly to "itemui", boosts to "moveui", power-ups to "buffui" and clock
#pickups to "clockui" (on the run clock). Name tags (Pickups.shortName) sit above the held boxes, and
#above a ring for its first TAG_SECONDS. Redraws only on change.

const BOX := 58.0
const RING := 25.0
const RING_PITCH := 60.0
const TAG_SECONDS := 3.0 #a new power-up's ring shows its name this long

var box := Vector2.ZERO        #center of the held gadget's box
var moveBox := Vector2.ZERO    #center of the held boost's box
var rings := Vector2.ZERO      #center of the first ring
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
	var car = GameUI.carOf(self)
	if not is_instance_valid(car): return
	var key := [car.heldItem, car.heldCharges, car.moveItem, car.moveCharges, car.starFragments, car.lotteryTickets.size(), car.hasParcel, car.barricades, InputGlyphs.usingPad,
		car.spareItem, car.spareCharges, HudSkin.of(self).id]
	var rig: CarTraitRig = car.traitRig
	if rig: key.append_array([rig.meterMult if rig.meterTicks > 0 else 0, rig.bedCrates, int(rig.abilityReady() * 24.0)])
	for id in car.buffs: key.append_array([id, car.buffs[id] / 6, car.buffs[id] < 120 && HudTheme.blinkOn()])
	if key != shownKey:
		shownKey = key
		queue_redraw()

func _draw() -> void:
	var car = GameUI.carOf(self)
	if not is_instance_valid(car): return
	drawSlot(box, car.heldItem, car.heldCharges, "UseItem")
	drawSlot(moveBox, car.moveItem, car.moveCharges, "UseMove")
	#counters to the left of the box
	var x := box.x - BOX * 0.5 - 20.0
	if car.starFragments > 0: #three pips, lit for each fragment held
		for i in 3:
			HudTheme.icon(self, HudTheme.STAR_ICON, Vector2(x - (2 - i) * 22.0, box.y - 14.0), 22.0, Color.WHITE if i < car.starFragments else Color(0.3, 0.3, 0.3, 0.6))
	var counters := [] #[icon, count] in a row under the pips, right to left; count may be text
	var rig: CarTraitRig = car.traitRig
	var shown := HudSkin.of(self).instrument #the van's bays, the taximeter and the truck bed show these themselves
	if car.spareItem != "" && shown != &"tilt": counters.push_back([Pickups.texture(car.spareItem), car.spareCharges]) #Cargo Bay's second gadget
	if rig && car.tMeter && rig.meterTicks > 0 && shown != &"meter": counters.push_back([CarTraits.texture(&"meter"), "x%d" % rig.meterMult])
	if rig && car.tLoadedBed && rig.bedCrates > 0 && shown != &"bed": counters.push_back([CarTraits.texture(&"loaded_bed"), rig.bedCrates])
	if car.lotteryTickets.size() > 0: counters.push_back([Pickups.texture("lottery"), car.lotteryTickets.size()])
	if car.hasParcel: counters.push_back([Pickups.texture("delivery"), 1])
	if car.barricades > 0: counters.push_back([Pickups.texture("barricade"), car.barricades])
	for i in counters.size():
		var c := Vector2(x - i * 40.0, box.y + 14.0)
		HudTheme.icon(self, counters[i][0], c, 28.0)
		var n = counters[i][1]
		if n is String || n > 1: HudTheme.text(self, c + Vector2(12.0, 12.0), str(n), 14, HudTheme.GOLD if n is String else HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)
	if rig && car.tDropLoad: drawAbility(moveBox + Vector2(BOX + 52.0, 0), rig.abilityReady())
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
		if car.buffTicks.get(id, left) - left < TAG_SECONDS * Pickups.TICKS: #new: its name, staggered so neighbors don't touch
			tag(c + Vector2(0, -RING - 9.0 - (i % 2) * 14.0), id)
		HudTheme.text(self, c + Vector2(0, RING + 14.0), "%d" % ceili(left / float(Pickups.TICKS)), 13, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)
		i += 1

#a held item's box: rarity frame, icon, charges badge and the key that fires it
func drawSlot(at: Vector2, id: String, charges: int, action: String) -> void:
	if id == "": return
	var col := Pickups.rarityColor(Pickups.rarity(id))
	HudTheme.panel(self, Rect2(at - Vector2(BOX, BOX) * 0.5, Vector2(BOX, BOX)), col, 10)
	HudTheme.icon(self, Pickups.texture(id), at, 44.0)
	tag(at + Vector2(0, -BOX * 0.5 - 7.0), id)
	if charges > 1:
		draw_circle(at + Vector2(BOX * 0.5, -BOX * 0.5), 11.0, col)
		HudTheme.text(self, at + Vector2(BOX * 0.5, -BOX * 0.5 + 6.0), str(charges), 15, HudTheme.OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, 0)
	var keyName := InputGlyphs.label(action)
	if keyName != "": HudTheme.text(self, at + Vector2(BOX * 0.5 + 8.0, 8.0), keyName, 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 5)

#the car's own ability (CarTraits ABILITY: the semi's Drop the Load, on F / pad B): lit when ready, dim and filling while
#it recharges, with the Ability key
func drawAbility(at: Vector2, ready: float) -> void:
	var rect := Rect2(at - Vector2(BOX, BOX) * 0.5, Vector2(BOX, BOX))
	var lit := ready >= 1.0
	HudTheme.panel(self, rect, HudTheme.RIM if lit else HudTheme.TRACK, 10)
	if not lit: draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 4 - (rect.size.y - 8) * ready), Vector2(rect.size.x - 8, (rect.size.y - 8) * ready)), Color(HudTheme.RIM, 0.25))
	HudTheme.icon(self, CarTraits.texture(&"drop_load"), at, 44.0, Color.WHITE if lit else Color(1, 1, 1, 0.45))
	HudTheme.text(self, at + Vector2(0, -BOX * 0.5 - 7.0), "DROP LOAD", Pickups.TAG_SIZE, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
	var keyName := InputGlyphs.label("Ability")
	if keyName != "" && lit: HudTheme.text(self, at + Vector2(BOX * 0.5 + 8.0, 8.0), keyName, 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 5)

#a pickup's name tag, centered on `at` (the baseline)
func tag(at: Vector2, id: String) -> void:
	HudTheme.text(self, at, Pickups.shortName(id), Pickups.TAG_SIZE, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4, HudTheme.OUTLINE, HudTheme.BODY)
