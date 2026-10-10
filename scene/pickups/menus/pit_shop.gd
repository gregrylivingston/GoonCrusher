class_name PitShop extends PickupMenu

#Marathon's pit shop: each station but the last sells three pickups for run coins, bought in order, top to
#bottom: the action key (E) buys the next one (and leaves once nothing more can be bought), REJECT (Q) leaves. Each offer says what it does, in small
#type under its name, before you buy it. Coins spent here don't reach the payout, which is the trade.
#Leaving resumes the run.

const PRICES := [30, 60, 150, 400, 900] #by rarity tier
const ROW_H := 104.0
const ROW_GAP := 10.0
const TOP := 20.0
const LEAVE := Rect2(170, 368, 300, 44)

var offers: Array = []     #pickup ids, "" once sold
var sold: Array = []       #what each bought offer did (PickupMenu.outcome), "" until bought
var next := 0              #the offer for sale now; the ones after wait their turn

static func open() -> void:
	if not is_instance_valid(Root.levelRoot): return
	Root.levelRoot.add_child(PitShop.new())

func build() -> void:
	title("PIT SHOP", "Buy them in order. What you spend here isn't paid out.")
	for i in 3:
		offers.push_back(Pickups.rollOffer(Pickups.R.UNCOMMON, Pickups.NOT_IN_GAMES, offers))
		sold.push_back("")
	refresh()

func price(id: String) -> int:
	return PRICES[clampi(Pickups.rarity(id), 0, PRICES.size() - 1)]

func canBuy() -> bool:
	return next < offers.size() && runCoins() >= price(offers[next])

func refresh() -> void:
	var list := []
	if canBuy(): list.push_back([[ACT], "Buy #%d  (%d coins)" % [next + 1, price(offers[next])]])
	list.push_back([[REJECT] if canBuy() else [ACT, REJECT], "Back to the road"])
	hints(list)
	if next >= offers.size(): say("Sold out.   Run coins: %d" % runCoins())
	elif not canBuy(): say("Not enough run coins for #%d.   Run coins: %d" % [next + 1, runCoins()])
	else: say("Run coins: %d" % runCoins())

func onAction(action: String) -> void:
	match action:
		ACT, "ui_accept":
			if canBuy(): buyNext()
			else: leaveShop()
		REJECT, "ui_cancel": leaveShop()

func onStageMouse(event: InputEvent) -> void:
	if not isClick(event): return
	if LEAVE.has_point(event.position): leaveShop()
	elif next < offers.size() && rowRect(next).has_point(event.position): buyNext()

func buyNext() -> void:
	if not canBuy(): return
	buy(next)

func buy(index: int) -> void:
	if index != next: return #in order only
	var id: String = offers[index]
	if id == "" || runCoins() < price(id): return
	Root.playerCar.coin -= price(id)
	award(id)
	sold[index] = winnings.back().line
	next += 1
	Transition.sound("pop", -6.0, 1.2)
	refresh()

func leaveShop() -> void:
	close()

func rowRect(i: int) -> Rect2:
	return Rect2(30, TOP + i * (ROW_H + ROW_GAP), STAGE.x - 60, ROW_H)

func drawStage() -> void:
	var m := stage
	m.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.06, 0.05, 0.045))
	for i in offers.size():
		var r := rowRect(i)
		var id: String = offers[i]
		var col := Pickups.rarityColor(Pickups.rarity(id))
		var bought := i < next
		var current := i == next
		var fade := 1.0 if current else (0.55 if bought else 0.4)
		HudTheme.panel(m, r, Color(col if current else HudTheme.RIM, 0.9 if current else 0.3), 10)
		if current: m.draw_rect(r.grow(3.0), Color(col, 0.6 + 0.3 * sin(Time.get_ticks_msec() / 200.0)), false, 2.0)
		HudTheme.text(m, r.position + Vector2(-2, 22), "%d" % (i + 1), 18, Color(HudTheme.GOLD, fade), HORIZONTAL_ALIGNMENT_RIGHT, 4)
		HudTheme.icon(m, Pickups.texture(id), r.position + Vector2(44, ROW_H * 0.5), 56.0, Color(1, 1, 1, fade))
		var x := r.position.x + 84.0
		HudTheme.text(m, Vector2(x, r.position.y + 28), Pickups.displayName(id).to_upper(), 20, Color(col, fade), HORIZONTAL_ALIGNMENT_LEFT, 5)
		var tag := "SOLD" if bought else ("%d coins" % price(id) if current else "after #%d" % i)
		var tagCol := HudTheme.OK if bought else (HudTheme.GOLD if current && canBuy() else HudTheme.MUTED)
		HudTheme.text(m, Vector2(r.end.x - 14, r.position.y + 28), tag, 17, tagCol, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		var text: String = sold[i] if bought else Pickups.def(id).get("text", "")
		m.draw_multiline_string(HudTheme.BODY, Vector2(x, r.position.y + 52), text, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 14, 13, 3, Color(HudTheme.TEXT if bought else HudTheme.MUTED, fade))
	HudTheme.panel(m, LEAVE, Color(HudTheme.RIM, 0.8), 10)
	HudTheme.text(m, LEAVE.get_center() + Vector2(0, 7), "BACK TO THE ROAD", 18, HudTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 4)
