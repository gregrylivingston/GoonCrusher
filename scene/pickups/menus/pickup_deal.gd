class_name PickupDeal extends PickupMenu

#The Deal, press your luck: you are dealt one card face up from a short deck of Uncommon-or-better pickups,
#and you see what is left in the deck by rarity (never which card is next). Keep your card, or swap it for
#the next one, which you must then keep or swap again; a swapped card is gone. The number of swaps is the
#game. It comes as a drop, or in a gift box (CrushPrizes): a Silver or Gold box deals Rare or better, a
#Diamond box Epic or better, and every tier above Cardboard adds a swap.

const BASE_TIER := Pickups.R.UNCOMMON
const DECK := 6            #cards in the deck, the first of them dealt to you
const NEVER := Pickups.NOT_IN_GAMES
const CARD := Vector2(230, 320)

var crushGoal := false     #from a gift box
var boxTier := 0
var minTier := BASE_TIER
var cards: Array = []      #the deck, top first (face down)
var hand := ""             #your card
var gone: Array = []       #swapped away, oldest first
var swaps := 2
var flip := 1.0            #0..1: the newest card turning over

static func open(isCrushGoal: bool, tier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var deal = PickupDeal.new()
	deal.crushGoal = isCrushGoal
	deal.boxTier = tier
	deal.minTier = mini(BASE_TIER + tier / 2, Pickups.R.LEGENDARY)
	deal.swaps = 2 + mini(tier, 2)
	Root.levelRoot.add_child.call_deferred(deal) #a crush can come from a node leaving the level (a Bait popping), while the level can't take children

## How many cards left in `deck` are rarer than `id`
static func beats(id: String, deck: Array) -> int:
	return deck.filter(func(c): return Pickups.rarity(c) > Pickups.rarity(id)).size()

func build() -> void:
	title("THE DEAL", ("Gift box: " if crushGoal else "") + "Keep your card, or swap it for the next. No going back.")
	for i in DECK: cards.push_back(Pickups.rollOffer(minTier, NEVER, cards))
	hand = cards.pop_front()
	flip = 0.0
	refresh()

func refresh() -> void:
	var list := [[["Accelerate"], "Keep it"]]
	if canSwap(): list.push_back([["Brake"], "Swap  (%d left)" % swaps])
	hints(list)
	if not canSwap(): say("No swaps left: this one is yours.")
	else:
		var n := beats(hand, cards)
		say("%d of the %d cards in the deck %s rarer than yours." % [n, cards.size(), "is" if n == 1 else "are"])

func canSwap() -> bool:
	return swaps > 0 && not cards.is_empty()

func onAction(action: String) -> void:
	match action:
		"Accelerate", "ui_accept": keep()
		"Brake": swap()

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event): return
	if event.position.x > STAGE.x * 0.55: swap()
	else: keep()

func swap() -> void:
	if not canSwap() || boardUp: return
	swaps -= 1
	gone.push_back(hand)
	hand = cards.pop_front()
	flip = 0.0
	Transition.sound("whoosh", -12.0, 1.4)
	refresh()

func keep() -> void:
	if boardUp: return
	award(hand)
	showWinnings("YOU KEPT")

func tick(delta: float) -> void:
	flip = minf(1.0, flip + delta * 4.0)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.05, 0.08, 0.06))
	m.draw_rect(Rect2(10, 10, STAGE.x - 20, STAGE.y - 20), Color(0.08, 0.2, 0.12), false, 3.0)
	#your card, turning over
	var at := Vector2(46, 40)
	var sx := absf(cos((1.0 - flip) * PI)) if flip < 1.0 else 1.0
	var faceUp := flip >= 0.5
	m.draw_set_transform(at + CARD * 0.5, 0.0, Vector2(maxf(sx, 0.02), 1.0))
	if faceUp: drawFace(m, hand, -CARD * 0.5)
	else: drawBack(m, -CARD * 0.5)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	HudTheme.text(m, Vector2(at.x + CARD.x * 0.5, at.y + CARD.y + 34), "YOUR CARD", 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	#the deck, and what is in it by rarity
	var deckAt := Vector2(330, 46)
	var small := CARD * 0.62
	for i in mini(cards.size(), 4):
		drawBack(m, deckAt + Vector2(i * 6.0, -i * 4.0), small)
	if cards.is_empty(): HudTheme.text(m, deckAt + Vector2(small.x * 0.5, small.y * 0.5), "EMPTY", 18, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, Vector2(deckAt.x + small.x + 24, deckAt.y + 20), "IN THE DECK", 14, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 4)
	var y := deckAt.y + 46.0
	for r in range(Pickups.R.LEGENDARY, -1, -1):
		var n := cards.filter(func(c): return Pickups.rarity(c) == r).size()
		if n == 0: continue
		var col := Pickups.rarityColor(r)
		m.draw_circle(Vector2(deckAt.x + small.x + 32, y - 5), 7.0, col)
		HudTheme.text(m, Vector2(deckAt.x + small.x + 46, y), "%s x%d" % [Pickups.RARITY_NAMES[r], n], 14, col, HORIZONTAL_ALIGNMENT_LEFT, 4)
		y += 24.0
	#swapped away
	if not gone.is_empty():
		HudTheme.text(m, Vector2(330, 314), "SWAPPED AWAY", 13, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 3)
		for i in gone.size():
			var c := Vector2(352 + i * 52.0, 350)
			m.draw_circle(c, 22.0, Color(Pickups.rarityColor(Pickups.rarity(gone[i])), 0.18))
			HudTheme.icon(m, Pickups.texture(gone[i]), c, 34.0, Color(1, 1, 1, 0.45))
	HudTheme.text(m, Vector2(deckAt.x + small.x * 0.5, deckAt.y + small.y + 30), "SWAPS %d" % swaps, 18, HudTheme.SKY if swaps > 0 else HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)

func drawFace(m: Control, id: String, at: Vector2) -> void:
	var r := Pickups.rarity(id)
	var col := Pickups.rarityColor(r)
	m.draw_rect(Rect2(at, CARD), Color(0.1, 0.08, 0.07))
	m.draw_rect(Rect2(at, CARD), col, false, 4.0)
	HudTheme.icon(m, Pickups.texture(id), at + Vector2(CARD.x * 0.5, 84), 110.0)
	HudTheme.text(m, at + Vector2(CARD.x * 0.5, 168), Pickups.RARITY_NAMES[r].to_upper(), 15, col, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, at + Vector2(CARD.x * 0.5, 196), Pickups.shortName(id).to_upper(), 22, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 5)
	m.draw_multiline_string(HudTheme.BODY, at + Vector2(14, 224), Pickups.def(id).get("text", ""), HORIZONTAL_ALIGNMENT_CENTER, CARD.x - 28, 13, 5, HudTheme.MUTED)

func drawBack(m: Control, at: Vector2, size := CARD) -> void:
	m.draw_rect(Rect2(at, size), Color(0.42, 0.1, 0.07))
	m.draw_rect(Rect2(at + Vector2(8, 8), size - Vector2(16, 16)), HudTheme.GOLD, false, 2.0)
	HudTheme.text(m, at + size * 0.5 + Vector2(0, 10), "?", int(size.y * 0.18), HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	m.draw_rect(Rect2(at, size), HudTheme.OUTLINE, false, 2.0)
