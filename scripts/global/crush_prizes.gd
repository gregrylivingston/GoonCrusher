class_name CrushPrizes extends RefCounted
## Crush prizes (docs/PICKUPS.md, "Gift boxes"): every crush earns crush XP toward the next gift box. Each
## box holds one prize game, rolled among the games that are unlocked, and a higher box is a better tier
## that favours stronger games and plays a better version of each. GameUI (playerRoot.gd) keeps the count
## and opens the box (GiftBox); the games read the tier.
##
## The XP each box needs grows (XP_BASE * level^XP_EXP), so boxes come more slowly as a run goes on and
## only a strong run reaches the top tiers. Leftover XP carries into the next box.

## Prize games, weakest first. Measured with each game's own rolls, no bet and no Dice, every pickup open
## (rarity points per play: Common 1, Uncommon 2, Rare 4, Epic 8, Legendary 16): Claw Crane 1.05 for an
## average grab (2.67 aimed at the best prize), Scratch Card 2.12, Prize Wheel 2.78 (it can bust), The
## Deal 2.77 (one card, but your pick), Slot Machine 6.95 (three reels pay three things), the Vault more.
## A new save opens only the first. Prices are placeholders until the unlock shop sells them (Unlocks,
## "prize:<id>" in meta.unlocks).
const GAMES := [
	{"id": "claw", "name": "Claw Crane", "icon": "res://texture/icon/claw.svg", "start": true},
	{"id": "shuffle", "name": "Hubcap Shuffle", "icon": "res://texture/icon/hubcap.svg", "price": {"coin": 2000}},
	{"id": "scratch", "name": "Scratch Card", "icon": "res://texture/icon/scratch.svg", "price": {"coin": 3000}},
	{"id": "press", "name": "Goon Press", "icon": "res://texture/icon/wrecking.svg", "price": {"coin": 6000}},
	{"id": "deal", "name": "The Deal", "icon": "res://texture/icon/deal.svg", "price": {"coin": 18000}},
	{"id": "pachinko", "name": "Pachinko Drop", "icon": "res://texture/icon/bullseye.svg", "price": {"coin": 25000}},
	{"id": "slot", "name": "Slot Machine", "icon": "res://texture/icon/slotMachine.svg", "price": {"coin": 40000}},
	{"id": "pusher", "name": "Coin Pusher", "icon": "res://texture/icon/coinstack.svg", "price": {"coin": 60000, "gem": 5}},
]

## Box tiers by box level: box 1 is Cardboard, box 5 and later Diamond.
const TIERS := ["Cardboard", "Bronze", "Silver", "Gold", "Diamond"]
const TIER_COLORS := [Color(0.784, 0.635, 0.416), Color(0.851, 0.537, 0.29), Color(0.8, 0.835, 0.871), Color(1.0, 0.827, 0.42), Color(0.541, 0.91, 1.0)]
const TOP_TIER := 4

## The XP box `level` (1, 2, 3...) needs on its own: 50, 200, 450, 800, 1250... AI playtests (Countdown and
## Goonpocalypse, 3-4 min) make 150-1300 XP, 2-7.5 per crush as giants and combos pile up: 1-3 boxes a run,
## fewer than the old crush goals gave the same runs (2-4). A human's pace is for package 1 to check.
const XP_BASE := 50.0
const XP_EXP := 2.0

## Crush XP: by rank (Goons.DATA: 1 fodder, 2 special, 3 heavy), times 4 for a giant and 10 for a boss
const RANK_XP := [1.0, 1.0, 3.0, 8.0]
const GIANT_MULT := 4.0
const BOSS_MULT := 10.0
## on top: +5% per crush in the combo chain (up to +100%), +50% for a slam or drift crush, +50% at night
const COMBO_STEP := 0.05
const COMBO_MAX := 1.0
const STYLE_BONUS := 0.5
const NIGHT_BONUS := 0.5

static var textures := {}

#--- XP ------------------------------------------------------------------------------------------

## XP for one crush. `style`: a slam or drift crush. `bonus`: any other multiplier (car.crushXpMult).
static func crushXp(goonDef: Dictionary, giant: bool, combo: int, style: bool, night: bool, bonus := 1.0) -> float:
	var xp: float = RANK_XP[clampi(int(goonDef.get("rank", 1)), 0, RANK_XP.size() - 1)]
	if goonDef.get("verb", &"") == &"boss": xp *= BOSS_MULT
	elif giant: xp *= GIANT_MULT
	var mult := 1.0 + minf(maxi(combo - 1, 0) * COMBO_STEP, COMBO_MAX)
	if style: mult += STYLE_BONUS
	if night: mult += NIGHT_BONUS
	return xp * mult * bonus

## XP box `level` needs on its own
static func boxXp(level: int) -> float:
	return XP_BASE * pow(maxf(level, 1), XP_EXP)

## Total XP at which box `level` opens (box 0 "opens" at 0)
static func boxAt(level: int) -> float:
	var total := 0.0
	for n in range(1, level + 1): total += boxXp(n)
	return total

static func tierFor(level: int) -> int:
	return clampi(level - 1, 0, TOP_TIER)

static func tierName(tier: int) -> String:
	return TIERS[clampi(tier, 0, TOP_TIER)]

static func tierColor(tier: int) -> Color:
	return TIER_COLORS[clampi(tier, 0, TOP_TIER)]

#--- games ---------------------------------------------------------------------------------------

static func game(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id: return g
	return {}

static func rank(id: String) -> int:
	for i in GAMES.size():
		if GAMES[i].id == id: return i
	return -1

static func gameName(id: String) -> String:
	return game(id).get("name", id.capitalize())

static func texture(id: String) -> Texture2D:
	var path: String = game(id).get("icon", "")
	if path == "": return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

## Is this game in the boxes? The first is always; harnesses and tests open every one (Unlocks.allOpen).
static func isOpen(id: String) -> bool:
	var g := game(id)
	if g.is_empty(): return false
	if Unlocks.allOpen || g.get("start", false): return true
	return Unlocks.saved().has(uid(id))

static func uid(id: String) -> String:
	return "prize:" + id

static func openGames() -> Array:
	var out := []
	for g in GAMES:
		if isOpen(g.id): out.push_back(g.id)
	return out

## Unlocks state for a prize game: OPEN, READY (the one after the best open game, or any whose
## predecessor is open) or SHOWN. The ladder opens in order.
static func state(id: String) -> int:
	if isOpen(id): return Unlocks.S.OPEN
	var r := rank(id)
	if r < 0: return Unlocks.S.HIDDEN
	return Unlocks.S.READY if r == 0 || isOpen(GAMES[r - 1].id) else Unlocks.S.SHOWN

static func price(id: String) -> Dictionary:
	return game(id).get("price", {})

## Opens a prize game without paying (the unlock shop's purchase, the dev console, career tiers)
static func grant(id: String) -> void:
	if not game(id).is_empty(): Unlocks.grant(uid(id))

## Testing: `-- --prize=<game id>` puts that game in every box (playtests, benchmarks, hand tests)
static var forcedGame = null
static func forced() -> String:
	if forcedGame == null:
		forcedGame = ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--prize="): forcedGame = arg.get_slice("=", 1)
		if forcedGame != "" && game(forcedGame).is_empty():
			push_warning("--prize: unknown game " + forcedGame)
			forcedGame = ""
	return forcedGame

## The game in a box of `tier`, among `open` game ids (weakest first). A Cardboard box favours the weakest
## open game and a Diamond box the strongest; the rest get less the further they are from that target.
static func pickGame(tier: int, roll: float, open: Array) -> String:
	if forced() != "": return forced()
	if open.is_empty(): return GAMES[0].id
	var ranks := open.map(func(id): return rank(id))
	var lo: int = ranks.min()
	var hi: int = ranks.max()
	var target := lerpf(lo, hi, clampf(float(tier) / TOP_TIER, 0.0, 1.0))
	var weights := {}
	for i in open.size():
		weights[open[i]] = 1.0 / pow(1.0 + absf(ranks[i] - target), 2.0)
	return Pickups.pickWeighted(weights, roll)

## Opens a prize game for a box of `tier`. Every game but the Scratch Card pauses the run itself; the gift
## box resumes the run before a scratch card starts.
static func openGame(id: String, tier: int) -> void:
	match id:
		"claw": ClawCrane.open(tier, true)
		"scratch":
			if is_instance_valid(HudChance.current): HudChance.current.startScratch(tier)
		"deal": PickupDeal.open(true, tier)
		"slot": SlotMachine.open(tier, true)
		"shuffle": HubcapShuffle.open(tier)
		"press": GoonPress.open(tier)
		"pachinko": PachinkoDrop.open(tier)
		"pusher": CoinPusher.open(tier)

static func pauses(id: String) -> bool:
	return id != "scratch"
