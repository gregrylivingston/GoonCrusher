class_name PickupDeal extends PickupMenu

#The Deal, press your luck: a shuffled deck of twelve cards, any rarity from Common up (a box raises the
#floor), with a few plain coin cards in it. The top card is flipped over into your hand. Keep it (the action
#key), or redraw (REJECT): your card goes on the discard pile and the next one flips over. You get three
#redraws and can't go back. The cards' backs show what kind of pickup each is (Loot, Gadget, Supplies...),
#never its rarity, and the next few backs are in view, so you know what kind of card a redraw brings. It
#comes as a drop, or in a gift box (CrushPrizes): each box tier above Cardboard raises the floor by half a
#rarity tier (Uncommon from Bronze, Rare from Gold, Epic at Diamond).

const DECK := 12
const COIN_CARDS := 3      #of them plain coins: the Coin, a Coin Stack or a Purse
const COINS := ["coin", "coinstack", "purse"]
const REDRAWS := 3
const NEVER := Pickups.NOT_IN_GAMES
const CARD := Vector2(220, 300)
const SMALL := Vector2(150, 205)
const HAND_AT := Vector2(40, 36)
const DECK_AT := Vector2(420, 60)
const FLIP_TIME := 0.45
## a card back per kind of pickup (Pickups.K): its colour and emblem
const BACKS := {
	Pickups.K.SUPPLY: [Color("2f7d4f"), "res://texture/icon/toolbox.svg"],
	Pickups.K.TUNE: [Color("8a5a1c"), "res://texture/icon/upgrade.svg"],
	Pickups.K.BOOST: [Color("1f5f8f"), "res://texture/icon/nitro.svg"],
	Pickups.K.GADGET: [Color("8f2a2a"), "res://texture/icon/mine.svg"],
	Pickups.K.LOOT: [Color("9a7a12"), "res://texture/icon/coin.svg"],
	Pickups.K.CASINO: [Color("6a2a8f"), "res://texture/icon/deal.svg"],
	Pickups.K.SKILL: [Color("2a6f6f"), "res://texture/icon/bullseye.svg"],
	Pickups.K.MODE: [Color("4a4a5a"), "res://texture/icon/stopwatch.svg"],
	Pickups.K.MOVE: [Color("8f4a1f"), "res://texture/icon/jets.svg"],
}

var crushGoal := false     #from a gift box
var boxTier := 0
var minTier := Pickups.R.COMMON
var cards: Array = []      #the deck, top first (face down)
var hand := ""             #your card
var gone: Array = []       #redrawn away, oldest first
var redraws := REDRAWS
var flip := 1.0            #0..1: the top card on its way to your hand, turning over
var discard := 1.0         #0..1: your last card on its way to the discard pile
var leaving := ""          #that card

static func open(isCrushGoal: bool, tier := 0) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var deal = PickupDeal.new()
	deal.crushGoal = isCrushGoal
	deal.boxTier = tier
	deal.minTier = mini(Pickups.R.COMMON + int((tier + 1) / 2.0), Pickups.R.EPIC)
	Root.levelRoot.add_child.call_deferred(deal) #a crush can come from a node leaving the level (a Bait popping), while the level can't take children

## How many cards left in `deck` are rarer than `id`
static func beats(id: String, deck: Array) -> int:
	return deck.filter(func(c): return Pickups.rarity(c) > Pickups.rarity(id)).size()

## A shuffled deck: DECK cards of `floorTier` or better, COIN_CARDS of them plain coins
static func dealDeck(floorTier: int) -> Array:
	var deck := []
	for i in COIN_CARDS: deck.push_back(Pickups.openOr(COINS.pick_random()))
	while deck.size() < DECK: deck.push_back(Pickups.rollOffer(floorTier, NEVER, deck))
	deck.shuffle()
	return deck

static func backColor(id: String) -> Color:
	return BACKS.get(Pickups.def(id).get("kind", Pickups.K.LOOT), BACKS[Pickups.K.LOOT])[0]

static func kindName(id: String) -> String:
	return Pickups.KIND_NAMES[Pickups.def(id).get("kind", Pickups.K.LOOT)]

func build() -> void:
	title("THE DEAL", ("Gift box: " if crushGoal else "") + "Keep your card, or redraw. No going back.")
	cards = dealDeck(minTier)
	hand = cards.pop_front()
	flip = 0.0
	Transition.sound("whoosh", -12.0, 1.4)
	refresh()

func refresh() -> void:
	var list := [[[ACT], "Keep it"]]
	if canRedraw(): list.push_back([[REJECT], "Redraw  (%d left)" % redraws])
	hints(list)
	if not canRedraw(): say("No redraws left: this one is yours.")
	else: say("The next card is %s." % kindName(cards[0]))

func canRedraw() -> bool:
	return redraws > 0 && not cards.is_empty()

func onAction(action: String) -> void:
	if flip < 1.0: return #let the card land first
	match action:
		ACT, "ui_accept": keep()
		REJECT: redraw()

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event) || flip < 1.0: return
	if event.position.x > STAGE.x * 0.55: redraw()
	else: keep()

func redraw() -> void:
	if not canRedraw() || boardUp: return
	redraws -= 1
	leaving = hand
	gone.push_back(hand)
	hand = cards.pop_front()
	flip = 0.0
	discard = 0.0
	Transition.sound("whoosh", -12.0, 1.4)
	refresh()

func keep() -> void:
	if boardUp: return
	award(hand)
	showWinnings("YOU KEPT")

func tick(delta: float) -> void:
	var was := flip
	flip = minf(1.0, flip + delta / FLIP_TIME)
	discard = minf(1.0, discard + delta / 0.3)
	if was < 0.5 && flip >= 0.5: Transition.sound("pop", -14.0, 1.6) #the card turns face up

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.05, 0.08, 0.06))
	m.draw_rect(Rect2(10, 10, STAGE.x - 20, STAGE.y - 20), Color(0.08, 0.2, 0.12), false, 3.0)
	#your card's place
	m.draw_rect(Rect2(HAND_AT, CARD), Color(1, 1, 1, 0.04))
	HudTheme.text(m, Vector2(HAND_AT.x + CARD.x * 0.5, HAND_AT.y + CARD.y + 30), "YOUR CARD", 16, HudTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 4)
	#the deck: its top three backs fanned, so the next kinds are in view
	for i in range(mini(cards.size(), 3) - 1, -1, -1):
		drawBack(m, cards[i], DECK_AT + Vector2(i * 22.0, i * 30.0), SMALL)
	if cards.is_empty(): HudTheme.text(m, DECK_AT + SMALL * 0.5, "EMPTY", 18, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, DECK_AT + Vector2(SMALL.x * 0.5 + 22.0, -16.0), "DECK  %d" % cards.size(), 14, HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 3)
	HudTheme.text(m, DECK_AT + Vector2(SMALL.x * 0.5 + 22.0, SMALL.y + 92.0), "REDRAWS %d" % redraws, 18, HudTheme.SKY if redraws > 0 else HudTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 4)
	#redrawn away
	for i in gone.size():
		var c := Vector2(286 + i * 42.0, 372)
		if i == gone.size() - 1 && discard < 1.0: c = (HAND_AT + CARD * 0.5).lerp(c, ease(discard, 0.5))
		HudTheme.icon(m, Pickups.texture(gone[i]), c, 32.0, Color(1, 1, 1, 0.5))
	#your card: from the deck to your hand, turning over on the way
	var u := ease(flip, -1.8)
	var at := DECK_AT.lerp(HAND_AT, u)
	var size := SMALL.lerp(CARD, u)
	var sx := absf(cos(flip * PI))
	m.draw_set_transform(at + size * 0.5, 0.0, Vector2(maxf(sx, 0.02), 1.0))
	if flip >= 0.5: drawFace(m, hand, -size * 0.5, size)
	else: drawBack(m, hand, -size * 0.5, size)
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func drawFace(m: Control, id: String, at: Vector2, size := CARD) -> void:
	var r := Pickups.rarity(id)
	var col := Pickups.rarityColor(r)
	var k := size.x / CARD.x
	m.draw_rect(Rect2(at, size), Color(0.1, 0.08, 0.07))
	m.draw_rect(Rect2(at, size), col, false, 4.0)
	m.draw_rect(Rect2(at, Vector2(size.x, 26.0 * k)), backColor(id))
	HudTheme.text(m, at + Vector2(size.x * 0.5, 18.0 * k), kindName(id).to_upper(), int(12 * k), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 3)
	HudTheme.icon(m, Pickups.texture(id), at + Vector2(size.x * 0.5, 100.0 * k), 100.0 * k)
	HudTheme.text(m, at + Vector2(size.x * 0.5, 176.0 * k), Pickups.RARITY_NAMES[r].to_upper(), int(14 * k), col, HORIZONTAL_ALIGNMENT_CENTER, 4)
	HudTheme.text(m, at + Vector2(size.x * 0.5, 202.0 * k), Pickups.shortName(id).to_upper(), int(20 * k), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 5)
	m.draw_multiline_string(HudTheme.BODY, at + Vector2(12, 226.0 * k), Pickups.def(id).get("text", ""), HORIZONTAL_ALIGNMENT_CENTER, size.x - 24, int(12 * k), 5, HudTheme.MUTED)

## A card back shows the kind of pickup, never the rarity
func drawBack(m: Control, id: String, at: Vector2, size := CARD) -> void:
	var kind: int = Pickups.def(id).get("kind", Pickups.K.LOOT)
	var back: Array = BACKS.get(kind, BACKS[Pickups.K.LOOT])
	var col: Color = back[0]
	m.draw_rect(Rect2(at, size), col)
	m.draw_rect(Rect2(at + Vector2(7, 7), size - Vector2(14, 14)), col.lightened(0.35), false, 2.0)
	for i in 5: m.draw_line(at + Vector2(10, 10 + i * size.y * 0.22), at + Vector2(size.x - 10, 10 + i * size.y * 0.22 + 18), Color(1, 1, 1, 0.05), 6.0)
	HudTheme.icon(m, load(back[1]), at + size * Vector2(0.5, 0.45), size.x * 0.42, Color(1, 1, 1, 0.9))
	HudTheme.text(m, at + Vector2(size.x * 0.5, size.y - 18.0), Pickups.KIND_NAMES[kind].to_upper(), int(maxf(11.0, size.x * 0.085)), HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 3)
	m.draw_rect(Rect2(at, size), HudTheme.OUTLINE, false, 2.0)
