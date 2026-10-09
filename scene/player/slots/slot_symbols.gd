class_name SlotSymbols extends RefCounted

#What the slot reels show (docs/PICKUPS.md). Each icon is a pickup id, rolled by rarity tier like a
#goon drop but with the reels' own odds, or STAR, the jackpot symbol. Dice tilts the tiers up, and so
#does the machine's bet (run coins, BETS). Paylines are in slot_machine.gd.

const STAR := "star"
const TIER_WEIGHTS := [50.0, 30.0, 14.0, 5.0, 1.0]
const BETS := [0, 25, 100, 250]     #coins per bet level
const STAR_CHANCE := 0.06           #per icon, plus STAR_PER_BET per bet level
const STAR_PER_BET := 0.02
## Reels never show another game (Pickups.NOT_IN_GAMES).
const NEVER := Pickups.NOT_IN_GAMES
## The most times a pair or triple pays one item, by rarity (a triple of Blueprints pays one).
const MAX_REPEAT := [5, 5, 3, 2, 1, 1]

static var bet := 0 #the open machine's bet level
static var bonus := 0 #free bet levels from a gift box's tier (CrushPrizes), on top of the bet

static func weights(dice: float, betLevel: int) -> Array:
	var out := []
	for t in TIER_WEIGHTS.size():
		out.push_back(TIER_WEIGHTS[t] * (1.0 + t * 0.6 * betLevel) * (1.0 + maxf(dice, 0.0) / 80.0 * t))
	return out

static func pick() -> String:
	if randf() < STAR_CHANCE + STAR_PER_BET * (bet + bonus): return STAR
	var car = Root.playerCar
	var dice: float = car.luck if is_instance_valid(car) else 0.0
	var mode: int = SaveManager.playerData.gameMode if SaveManager.playerData else 0
	var tier := Pickups.pickTier(weights(dice, bet + bonus), randf())
	while tier >= 0:
		var options := Pickups.candidates(tier, mode, true)
		for id in NEVER: options.erase(id)
		var id := Pickups.pickWeighted(options, randf())
		if id != "": return id
		tier -= 1
	return "coin"

static func texture(id: String) -> Texture2D:
	return HudTheme.STAR_ICON if id == STAR else Pickups.texture(id)

## How many times each symbol pays for three reels: a pair pays 2, a triple 5 (capped by rarity).
## STAR is counted, not paid: one or two give Star Fragments, three are the jackpot.
static func payouts(reels: Array) -> Dictionary:
	var counts := {}
	for r in reels: counts[r] = counts.get(r, 0) + 1
	var out := {}
	for id in counts:
		var n: int = counts[id]
		if id == STAR:
			out[id] = n
			continue
		var times := 1 if n == 1 else (2 if n == 2 else 5)
		out[id] = mini(times, MAX_REPEAT[Pickups.rarity(id)])
	return out
