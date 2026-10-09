class_name Personas extends RefCounted

#The three players a career playtest can be (docs/AI_DRIVER.md, "Career playtests"). A persona is how a
#player drives (an AIProfiles spec), how they spend coins and gems, which runs they pick, which input device
#they use in the menus and how much of the game around the runs they poke at. The career harness
#(scripts/debug/career.gd) carries the decisions out through the real menus; everything here is pure: it
#reads the save, the persona's own run history and a RandomNumberGenerator, so it can be unit tested.
#  rookie    a new player: drives sloppily, follows the obvious path, clicks with the mouse, buys whatever
#            is cheap the moment it can, never spends gems. Shows the first hours and where people stall.
#  grinder   an optimiser: the best AI driver, plays whatever pays most per minute once the path is
#            blocked, saves for cars, puts upgrades into the stats that win runs. Shows the fastest
#            progression and any run or purchase that pays far more than the rest.
#  explorer  a completionist: plays the least-played level, mode and car, buys every car to try it,
#            opens every menu, bets, rerolls, raises, pauses and sometimes abandons. Finds blocks and bugs.

const G := Root.gameModes
const U := Root.upgrade
const MODE_PATH := Root.MODE_PATH #the order a player meets them

const DATA := {
	"rookie": {
		"name": "Rookie", "profile": "rookie", "device": "mouse",
		"shop": "impulse",       #cheapest affordable things first, no saving
		"runs": "path",          #the newest level and its next unbeaten mode
		"car": "newest",         #drives the car bought last
		"overlays": 0.15,        #chance per menu visit to open the Goonopedia or records
		"pause": 0.1,            #chance per run to pause once and continue
		"abandon": 0.0,          #chance per run to abandon it from the pause menu
		"bet": "never", "gems": false, "deal": "rarest", "claw": "nearest", "pit": "first",
		"retreat": 3,            #losses in a row on one level and mode before it goes back to farm the previous level
		"tierCap": 2,            #the hardest tier (ModeTiers) it goes for: Medium
	},
	"grinder": {
		"name": "Grinder", "profile": "cautious", "device": "keys",
		"shop": "focused", "runs": "payout", "car": "strongest",
		"overlays": 0.0, "pause": 0.0, "abandon": 0.0,
		"bet": "rich", "gems": true, "deal": "worth", "claw": "rarest", "pit": "supplies",
		"retreat": 2, "tierCap": 3,
		"stats": [U.ENGINE, U.ARMOR, U.OIL, U.TRACTION, U.STEERING, U.CLOVER, U.LUCK, U.HEADLIGHTS],
	},
	"explorer": {
		"name": "Explorer", "profile": "crusher", "device": "mixed",
		"shop": "variety", "runs": "coverage", "car": "least",
		"overlays": 1.0, "pause": 0.5, "abandon": 0.06,
		"bet": "random", "gems": true, "deal": "new", "claw": "random", "pit": "all",
		"retreat": 2, "tierCap": 3,
	},
}

static func has(id: String) -> bool:
	return DATA.has(id)

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})

#---------- the garage ----------

## The next thing to buy, or {} when done shopping: {"unlock": car index}, {"upgrade": stat, "car": car index}
## or {"pickup": id} (unlocked in the Goonopedia). Called again after each purchase, with the bank updated.
static func nextPurchase(persona: Dictionary, data: PlayerData, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	var cheapestLocked := -1
	for i in data.cars.size():
		if data.cars[i].cost > 0 && (cheapestLocked < 0 || data.cars[i].cost < data.cars[cheapestLocked].cost): cheapestLocked = i
	var drive := chooseCar(persona, data, history)
	var canCar := cheapestLocked >= 0 && canBuyCar(data, cheapestLocked)
	match persona.shop:
		"impulse": #a new car the moment it is affordable, any pickup under half the bank, then the cheapest upgrade
			if canCar: return {"unlock": cheapestLocked}
			var pick := pickupToBuy(data, "cheapest", data.coin / 2, rng)
			if pick != "": return {"pickup": pick}
			return cheapestUpgrade(data, drive, CareerStart.STATS, data.coin)
		"focused": #save for the next car once it is within three good runs; useful pickups and the winning stats meanwhile
			var income := averagePayout(history, 5)
			if cheapestLocked >= 0:
				var price: int = data.cars[cheapestLocked].cost
				if canCar: return {"unlock": cheapestLocked}
				if income > 0.0 && price - data.coin <= income * 3.0: return {} #nearly there: keep saving
			var pick := pickupToBuy(data, "useful", data.coin / 3, rng)
			if pick != "": return {"pickup": pick}
			return priorityUpgrade(data, drive, persona.stats, data.coin)
		"variety": #every car to try it, a new pickup to try, then the stat it has least of
			if canCar: return {"unlock": cheapestLocked}
			var pick := pickupToBuy(data, "random", data.coin, rng)
			if pick != "" && rng.randf() < 0.6: return {"pickup": pick}
			var stats := CareerStart.STATS.duplicate()
			stats.sort_custom(func(a, b): return int(data.cars[drive].upgrades.get(a, 0)) < int(data.cars[drive].upgrades.get(b, 0)))
			if rng.randf() < 0.3: stats.shuffle() #sometimes just whatever looks fun
			return priorityUpgrade(data, drive, stats, data.coin)
	return {}

## Coins and gems cover the car (advanced cars cost gems too)
static func canBuyCar(data: PlayerData, index: int) -> bool:
	return data.coin >= int(data.cars[index].cost) && data.gem >= int(data.cars[index].get("gems", 0))

## A ready unlock the bank covers within `budget` coins, sold in the Goonopedia: a pickup id, or a prize game
## as "prize:<game>" (CrushPrizes). The cheapest, the most useful per coin, or any. "" when there is none.
static func pickupToBuy(data: PlayerData, how: String, budget: int, rng: RandomNumberGenerator) -> String:
	var options := []
	var keys: Array = Pickups.DATA.keys()
	for g in CrushPrizes.GAMES: keys.push_back(CrushPrizes.uid(g.id))
	for key in keys:
		var uid: String = key if str(key).begins_with("prize:") else "pickup:" + key
		var cost := Unlocks.price(uid)
		if cost.is_empty() || Unlocks.state(uid) != Unlocks.S.READY || not Unlocks.canAfford(uid): continue
		if int(cost.get("coin", 0)) > budget: continue
		options.push_back(key)
	if options.is_empty(): return ""
	match how:
		"cheapest": options.sort_custom(func(a, b): return priceOf(a).get("coin", 0) < priceOf(b).get("coin", 0))
		"useful": options.sort_custom(func(a, b): return worth(a) > worth(b))
		_: return options[rng.randi() % options.size()]
	return options[0]

static func priceOf(key: String) -> Dictionary:
	return Unlocks.price(key if key.begins_with("prize:") else "pickup:" + key)

## Worth per coin: a pickup's `ai` value; a prize game counts by its place on the ladder (each one up is
## worth about another two pickups' rarity points a box)
static func worth(key: String) -> float:
	var cost := priceOf(key)
	var value: float = 30.0 * (CrushPrizes.rank(key.trim_prefix("prize:")) + 1) if key.begins_with("prize:") else float(Pickups.DATA[key].get("ai", 10))
	return value / (1.0 + float(cost.get("coin", 0)) + 500.0 * float(cost.get("gem", 0)))

static func cheapestUpgrade(data: PlayerData, car: int, stats: Array, coins: int) -> Dictionary:
	var best := {}
	var bestCost := 0
	for stat in stats:
		var level := int(data.cars[car].upgrades.get(stat, 0))
		if level >= SaveManager.MAX_UPGRADE_LEVEL: continue
		var cost := SaveManager.upgradePrice(level, str(data.cars[car].name))
		if cost <= coins && (best.is_empty() || cost < bestCost):
			best = {"upgrade": stat, "car": car}
			bestCost = cost
	return best

## The first stat in `stats` that is affordable and not yet ahead of the ones before it by more than
## two levels, so the top stats lead and the rest follow.
static func priorityUpgrade(data: PlayerData, car: int, stats: Array, coins: int) -> Dictionary:
	var upgrades: Dictionary = data.cars[car].upgrades
	var floorLevel := SaveManager.MAX_UPGRADE_LEVEL
	for stat in stats: floorLevel = mini(floorLevel, int(upgrades.get(stat, 0)))
	for lead in [2, SaveManager.MAX_UPGRADE_LEVEL]:
		for stat in stats:
			var level := int(upgrades.get(stat, 0))
			if level >= SaveManager.MAX_UPGRADE_LEVEL || level > floorLevel + lead: continue
			if SaveManager.upgradePrice(level, str(data.cars[car].name)) <= coins: return {"upgrade": stat, "car": car}
	return {}

## The owned car to drive next.
static func chooseCar(persona: Dictionary, data: PlayerData, history: Array) -> int:
	var owned := []
	for i in data.cars.size(): if data.cars[i].cost == 0: owned.push_back(i)
	if owned.is_empty(): return data.selectedCar
	match persona.car:
		"newest": #the dearest owned car is the one bought last
			owned.sort_custom(func(a, b): return carPrice(data, a) > carPrice(data, b))
		"strongest": #the dearest, unless another owned car pays clearly better in this persona's runs
			owned.sort_custom(func(a, b): return carScore(data, a, history) > carScore(data, b, history))
		"least": #the owned car with the fewest runs
			owned.sort_custom(func(a, b): return runsWith(history, "car", data.cars[a].name) < runsWith(history, "car", data.cars[b].name))
	return owned[0]

#a car's list price (owned cars have cost 0 in the save, so the defaults say what it cost)
static func carPrice(data: PlayerData, index: int) -> int:
	for car in PlayerData.new().cars:
		if car.name == data.cars[index].name: return int(car.cost)
	return 0

static func carScore(data: PlayerData, index: int, history: Array) -> float:
	var runs := history.filter(func(r): return r.car == data.cars[index].name)
	var perMinute := 0.0
	for r in runs: perMinute += float(r.payout) / maxf(float(r.level_time) / 60.0, 0.5)
	if runs.size() >= 3: return perMinute / runs.size()
	return 1000.0 + carPrice(data, index) / 100.0 #untried: trust the price tag

#---------- run setup ----------

## The level index, mode and tier to play next, among those the menu lets this save start.
static func chooseRun(persona: Dictionary, data: PlayerData, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	var run := chooseLevelAndMode(persona, data, history, rng)
	if not run.is_empty(): run.tier = chooseTier(persona, data, history, run, rng)
	return run

## The tier (ModeTiers) for a run: the next one above the best beaten there, up to the persona's cap; after a
## losing streak, the one below. The Explorer picks any open tier.
static func chooseTier(persona: Dictionary, data: PlayerData, history: Array, run: Dictionary, rng: RandomNumberGenerator) -> int:
	var level: Dictionary = data.levels[run.level]
	var open: Array = ModeTiers.TIERS.filter(func(t): return ModeTiers.isOpen(level, run.mode, t))
	if persona.runs == "coverage": return open[rng.randi() % open.size()]
	var tier := mini(ModeTiers.best(level, run.mode) + 1, int(persona.get("tierCap", ModeTiers.HARD)))
	if losingStreak(history, run, persona.retreat): tier -= 1
	tier = ModeTiers.clampTier(tier)
	while tier > ModeTiers.EASY && not ModeTiers.isOpen(level, run.mode, tier): tier -= 1
	return tier

static func chooseLevelAndMode(persona: Dictionary, data: PlayerData, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	var playable := playableRuns(data)
	if playable.is_empty(): return {}
	match persona.runs:
		"coverage":
			var car: String = data.cars[chooseCar(persona, data, history)].name
			playable.sort_custom(func(a, b): return coverage(history, a, car) < coverage(history, b, car))
			var fewest := coverage(history, playable[0], car)
			var tied := playable.filter(func(r): return coverage(history, r, car) == fewest)
			return tied[rng.randi() % tied.size()]
		"payout":
			var next := pathRun(data, history, persona)
			if not next.is_empty() && not losingStreak(history, next, persona.retreat): return next
			return bestPaying(playable, history, rng)
	var next := pathRun(data, history, persona)
	if next.is_empty(): return playable[0]
	if losingStreak(history, next, persona.retreat):
		#stuck: farm Countdown on the level before for a run (a player grinding coins to upgrade)
		return {"level": maxi(next.level - 1, 0), "mode": G.GOONCRUSHER}
	return next

## Every {level, mode} the menu would start: the level is open and the mode unlocked and available.
static func playableRuns(data: PlayerData) -> Array:
	var out := []
	for i in data.levels.size():
		if not data.levels[i].unlocked || (Root.IS_DEMO && i >= Root.DEMO_LEVEL_COUNT): continue
		for mode in MODE_PATH:
			if Root.isModePlayable(data.levels[i], mode): out.push_back({"level": i, "mode": mode})
	return out

## The obvious next run, heading for the Marathon on the furthest open level (Root.MODE_PATH puts the road,
## Countdown, Sprint and Marathon, first): that level's first unbeaten mode; at a finale whose Marathon was won
## below Medium, the Marathon again (chooseTier picks Medium); then Goonpocalypse and Defense where they are
## open, furthest first; then a mode with a tier left to win (up to the persona's cap); else the furthest
## level's Countdown. Modes this persona keeps losing there are skipped while another is left.
static func pathRun(data: PlayerData, history: Array, persona: Dictionary) -> Dictionary:
	var playable := playableRuns(data)
	if playable.is_empty(): return {}
	var furthest: int = playable.map(func(r): return r.level).max()
	var road := {"level": furthest, "mode": Root.ROAD_MODE}
	var top: Dictionary = data.levels[furthest]
	if furthest + 1 < data.levels.size() && top.gamemodeBeat.get(Root.ROAD_MODE, false) && not Root.opensNextLevel(top) \
			&& Root.isModePlayable(top, Root.ROAD_MODE) && not losingStreak(history, road, persona.retreat):
		return road #a finale won on Easy: the next region waits for Medium
	for level in range(furthest, -1, -1):
		var fallback := {}
		for run in playable:
			if run.level != level || data.levels[level].gamemodeBeat.get(run.mode, false): continue
			if not losingStreak(history, run, persona.retreat): return run
			if fallback.is_empty(): fallback = run
		if not fallback.is_empty(): return fallback
	var cap := int(persona.get("tierCap", ModeTiers.HARD))
	for level in range(furthest, -1, -1): #everything beaten on Easy: go for medals
		for run in playable:
			if run.level == level && ModeTiers.best(data.levels[level], run.mode) < cap && not losingStreak(history, run, persona.retreat): return run
	return {"level": furthest, "mode": G.GOONCRUSHER}

## The last `count` runs of this level and mode were all lost.
static func losingStreak(history: Array, run: Dictionary, count: int) -> bool:
	var same := history.filter(func(r): return r.level_index == run.level && r.mode_id == run.mode)
	if same.size() < count: return false
	for r in same.slice(same.size() - count): if r.won: return false
	return true

static func bestPaying(playable: Array, history: Array, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < 0.2: return playable[rng.randi() % playable.size()] #keep sampling the others
	var best: Dictionary = playable[0]
	var bestRate := -1.0
	for run in playable:
		var same := history.filter(func(r): return r.level_index == run.level && r.mode_id == run.mode)
		var rate := 1e9 if same.is_empty() else 0.0 #untried runs first
		for r in same: rate += float(r.payout) / maxf(float(r.level_time) / 60.0, 0.5) / same.size()
		if rate > bestRate:
			bestRate = rate
			best = run
	return best

static func coverage(history: Array, run: Dictionary, car: String) -> int:
	var count := 0
	for r in history:
		if r.level_index == run.level && r.mode_id == run.mode: count += 2 if r.car == car else 1
	return count

static func runsWith(history: Array, key: String, value) -> int:
	return history.filter(func(r): return r[key] == value).size()

static func averagePayout(history: Array, last: int) -> float:
	if history.is_empty(): return 0.0
	var recent := history.slice(maxi(0, history.size() - last))
	var total := 0.0
	for r in recent: total += float(r.payout)
	return total / recent.size()

## The starting gadget to buy with gems (Pickups.LOADOUT), or "".
static func chooseLoadout(persona: Dictionary, gems: int, rng: RandomNumberGenerator) -> String:
	if not persona.gems: return ""
	var options := Pickups.LOADOUT.keys().filter(func(id): return Pickups.LOADOUT[id] <= gems && Unlocks.isPickupOpen(id))
	if options.is_empty(): return ""
	if persona.runs == "coverage": return options[rng.randi() % options.size()] if rng.randf() < 0.5 else ""
	return options[0] if gems >= 6 else "" #the grinder keeps a reserve for slot rerolls

## The boost to buy with the gems left after the gadget (Pickups.BOOST_LOADOUT), or "".
static func chooseBoost(persona: Dictionary, gems: int, rng: RandomNumberGenerator) -> String:
	if not persona.gems: return ""
	var options := Pickups.BOOST_LOADOUT.keys().filter(func(id): return Pickups.BOOST_LOADOUT[id] <= gems && Unlocks.isPickupOpen(id))
	if options.is_empty(): return ""
	if persona.runs == "coverage": return options[rng.randi() % options.size()] if rng.randf() < 0.5 else ""
	return "nitro" if "nitro" in options && gems >= 8 else "" #the grinder keeps a reserve for slot rerolls

#---------- in a run ----------

## Bet level (an index into SlotSymbols.BETS) for a slot machine with these run coins.
static func slotBet(persona: Dictionary, runCoins: int, rng: RandomNumberGenerator) -> int:
	match persona.bet:
		"rich": return 1 if runCoins >= 400 else 0
		"random": return rng.randi() % SlotSymbols.BETS.size()
	return 0

## Spend a gem to spin the reels again: only on a result with nothing paid.
static func slotReroll(persona: Dictionary, gems: int, paid: Dictionary, rng: RandomNumberGenerator) -> bool:
	if not persona.gems || gems <= 0: return false
	if persona.runs == "coverage": return rng.randf() < 0.5
	return paid.is_empty() && gems >= 3

## The Deal: keep the card in hand (true) or swap it for the next one. "rarest" keeps once fewer than half
## of the deck beat it, "worth" once it is worth enough to the AI, "new" keeps a card it hasn't seen yet.
static func dealKeep(persona: Dictionary, hand: String, deck: Array, rng: RandomNumberGenerator) -> bool:
	if deck.is_empty(): return true
	match persona.deal:
		"rarest": return PickupDeal.beats(hand, deck) * 2 < deck.size()
		"worth": return float(Pickups.def(hand).get("ai", 7)) >= 20.0
		"new": return not Pickups.isDiscovered(hand) || rng.randf() < 0.4
	return true

## The claw's target: an index into the crane's prizes.
static func clawTarget(persona: Dictionary, prizes: Array, clawX: float, rng: RandomNumberGenerator) -> int:
	if prizes.is_empty(): return -1
	var best := 0
	for i in prizes.size():
		match persona.claw:
			"nearest": if absf(prizes[i].pos.x - clawX) < absf(prizes[best].pos.x - clawX): best = i
			"rarest": if Pickups.rarity(prizes[i].id) > Pickups.rarity(prizes[best].id): best = i
	return rng.randi() % prizes.size() if persona.claw == "random" else best

## Pit Shop offers to buy, as indices, in order.
static func pitBuys(persona: Dictionary, offers: Array, prices: Array, runCoins: int) -> Array:
	var out := []
	var left := runCoins
	for i in offers.size():
		if offers[i] == "" || prices[i] > left: continue
		match persona.pit:
			"supplies": if Pickups.def(offers[i]).get("kind", -1) != Pickups.K.SUPPLY: continue
			"first": if not out.is_empty(): continue
		out.push_back(i)
		left -= prices[i]
	return out
