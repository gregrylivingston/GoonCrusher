class_name Unlocks extends RefCounted
## What is open: levels, modes, cars and pickups, asked in one place (docs/PICKUPS.md, "Unlocks").
##
## Each owner keeps its own data. A pickup's place in its kind's tree is `parent` (and `start` for a root)
## in Pickups.DATA, with an optional play condition in `needs`. A level opens once the Marathon is won on the
## one before it, on Medium after a region's finale (Root.opensNextLevel, SaveManager.currentLevelPassed), and
## the mode chain is Root.isModeUnlocked. A car is open once bought (`cost` and `gems` in PlayerData.cars).
##
## Every unlock has one of four states. HIDDEN: its parent is still locked ("???"). SHOWN: its parent is
## open but its condition isn't met yet, or a pickup in its `after` is still locked. READY: it can be bought, or opens on its own at the next results
## ticket (refresh). OPEN: saved in meta.unlocks, and for a pickup, it can drop and be offered. An unlock
## never closes again, even when its rule is retuned.
##
## Ids: "pickup:<id>", "car:<name>", "level:<id>", "mode:<level>:<mode>". The gift box games (CrushPrizes) have no id of
## their own: each is open with its Casino pickup. Reserved for later: paint, station.

enum S { HIDDEN, SHOWN, READY, OPEN }
const STATE_NAMES := ["Hidden", "Shown", "Ready", "Open"]

## Price ranges by rarity: [fewest coins, most coins, fewest gems, most gems]. Inside a rarity no two
## pickups cost the same: they are spread over the range (evenly by ratio), shallowest in their trees first,
## so a tree's root is its rarity's cheapest and there is always something a little dearer to save for
## (buildPrices). Commons run from pocket change up; Legendaries cost gems only. A pickup with a play
## condition (`needs`) costs nothing: it opens when the condition is met. Placeholders until package 1.
const PRICE_RANGE := [[20, 1000, 0, 0], [1200, 4500, 0, 0], [5000, 12000, 0, 0], [15000, 30000, 3, 6], [0, 0, 12, 18]]
static var prices := {} #pickup id -> its price, built once (Pickups.DATA is constant)
## The demo opens Commons and Uncommons, every tree's root, and the Casino tree's first tier:
## the games straight under its root, whatever their rarity, so gift boxes have more than one game (inDemo).
const DEMO_MAX_RARITY := Pickups.R.UNCOMMON
## Condition words for modes, in Root.gameModes order.
const MODE_KEYS := ["countdown", "sprint", "marathon", "defense", "goonpocalypse"]
const FACTION_KEYS := ["wild", "tribe", "scrap"]
const TIER_KEYS := ["", "easy", "medium", "hard"] #ModeTiers, for "clears:<tier>:<n>"

## Harnesses and tests: every pickup is open whatever the save says (`--unlocks=all`, the default in
## playtests and benchmarks, so their numbers stay comparable with older runs).
static var allOpen := false

#--- pickups ------------------------------------------------------------------------------------

## Can this pickup drop, be offered or be sold? The hot path (Pickups.candidates): two lookups.
static func isPickupOpen(id: String) -> bool:
	var d: Dictionary = Pickups.DATA.get(id, {})
	if d.is_empty(): return false
	if allOpen || d.get("start", false) || d.rarity == Pickups.R.SYSTEM: return true
	if Root.IS_DEMO && not inDemo(id): return false
	return saved().has("pickup:" + id)

## Can the demo unlock this pickup? Commons and Uncommons, tree roots, and the Casino games straight under their root.
static func inDemo(id: String) -> bool:
	var d: Dictionary = Pickups.DATA.get(id, {})
	if d.is_empty(): return false
	if d.rarity <= DEMO_MAX_RARITY || d.get("parent", "") == "": return true
	return d.kind == Pickups.K.CASINO && Pickups.DATA.get(d.get("parent", ""), {}).get("start", false)

## Pickup ids in tree order for one kind: each root (a pickup with no parent, open or not), then its children depth first.
static func treeOrder(kind: int) -> Array:
	var out := []
	for id in Pickups.ids(kind):
		if Pickups.DATA[id].get("parent", "") == "": addSubtree(id, out)
	return out

static func addSubtree(id: String, out: Array) -> void:
	out.push_back(id)
	for child in children(id): addSubtree(child, out)

static func children(id: String) -> Array:
	var out := []
	for other in Pickups.DATA:
		if Pickups.DATA[other].get("parent", "") == id: out.push_back(other)
	return out

## Every pickup that must be open before this one can be bought: its `parent`, then any in `after`
static func prerequisites(id: String) -> Array:
	var d: Dictionary = Pickups.DATA.get(id, {})
	var out := []
	if d.get("parent", "") != "": out.push_back(d.parent)
	out.append_array(d.get("after", []))
	return out

## The prerequisites still locked
static func missing(id: String) -> Array:
	return prerequisites(id).filter(func(p): return not isPickupOpen(p))

## The pickup's price ({} for one that starts open, a play unlock or Crush Combo): its own `price`, else its
## place in its rarity's range (buildPrices).
static func pickupPrice(id: String) -> Dictionary:
	var d: Dictionary = Pickups.DATA.get(id, {})
	if d.is_empty() || d.get("start", false) || d.rarity == Pickups.R.SYSTEM || d.has("needs"): return {}
	if d.has("price"): return d.price
	if prices.is_empty(): buildPrices()
	return prices.get(id, {})

## How many pickups are above this one in its tree
static func depthOf(id: String) -> int:
	var depth := 0
	var parent: String = Pickups.DATA[id].get("parent", "")
	while parent != "":
		depth += 1
		parent = Pickups.DATA[parent].get("parent", "")
	return depth

## Spreads each rarity's pickups over its PRICE_RANGE, shallowest first (then in registry order)
static func buildPrices() -> void:
	var order: Array = Pickups.DATA.keys()
	for r in PRICE_RANGE.size():
		var ids := []
		for id in order:
			var d: Dictionary = Pickups.DATA[id]
			if d.rarity == r && not (d.get("start", false) || d.has("needs") || d.has("price")): ids.push_back(id)
		ids.sort_custom(func(a, b): return depthOf(a) * 1000 + order.find(a) < depthOf(b) * 1000 + order.find(b))
		var span: Array = PRICE_RANGE[r]
		for i in ids.size():
			var t := float(i) / maxf(ids.size() - 1, 1.0)
			var cost := {}
			if span[1] > 0: cost.coin = roundPrice(span[0] * pow(float(span[1]) / span[0], t))
			if span[3] > 0: cost.gem = roundi(lerpf(span[2], span[3], t))
			prices[ids[i]] = cost

## A price a person would write: to the nearest 5 under 100, 10 under 1,000, 100 under 10,000, then 500
static func roundPrice(value: float) -> int:
	var step := 5.0 if value < 100.0 else (10.0 if value < 1000.0 else (100.0 if value < 10000.0 else 500.0))
	return int(roundf(value / step) * step)

#--- any unlock ---------------------------------------------------------------------------------

static func isOpen(uid: String) -> bool:
	return state(uid) == S.OPEN

static func state(uid: String) -> int:
	var parts := uid.split(":")
	match parts[0]:
		"pickup":
			var id := parts[1]
			if not Pickups.DATA.has(id): return S.HIDDEN
			if isPickupOpen(id): return S.OPEN
			var parent: String = Pickups.DATA[id].get("parent", "")
			if parent != "" && not isPickupOpen(parent): return S.HIDDEN
			if Root.IS_DEMO && not inDemo(id): return S.SHOWN
			if not missing(id).is_empty(): return S.SHOWN #its parent is open, but not everything in `after`
			return S.READY if needsMet(Pickups.DATA[id].get("needs", [])) else S.SHOWN
		"car":
			var car = carEntry(parts[1])
			if car == null: return S.HIDDEN
			return S.OPEN if car.cost == 0 else S.READY
		"level":
			var i := Levels.indexOf(StringName(parts[1]))
			if i < 0 || data() == null: return S.HIDDEN
			if data().levels[i].unlocked: return S.OPEN
			return S.SHOWN if i == 0 || data().levels[i - 1].unlocked else S.HIDDEN
		"mode":
			var i := Levels.indexOf(StringName(parts[1]))
			var mode := MODE_KEYS.find(parts[2]) if parts.size() > 2 else -1
			if i < 0 || mode < 0 || data() == null: return S.HIDDEN
			var level: Dictionary = data().levels[i]
			if Root.isModeUnlocked(level, mode): return S.OPEN
			return S.SHOWN if level.unlocked else S.HIDDEN
	return S.OPEN if saved().has(uid) else S.HIDDEN

## What an unlock costs right now: {"coin": n, "gem": n}, either may be missing; {} when free.
static func price(uid: String) -> Dictionary:
	var parts := uid.split(":")
	match parts[0]:
		"pickup": return pickupPrice(parts[1])
		"car":
			var car = carEntry(parts[1])
			if car == null || car.cost == 0: return {}
			var out := {"coin": int(car.cost)}
			if int(car.get("gems", 0)) > 0: out.gem = int(car.gems)
			return out
	return {}

static func canAfford(uid: String) -> bool:
	var cost := price(uid)
	return data() != null && data().coin >= int(cost.get("coin", 0)) && data().gem >= int(cost.get("gem", 0))

## How many pickups the bank could buy right now, each on its own (the garage dock's badge)
static func buyableCount() -> int:
	var uids := []
	for id in Pickups.DATA: uids.push_back("pickup:" + str(id))
	var count := 0
	for uid in uids:
		if state(uid) == S.READY && not price(uid).is_empty() && canAfford(uid): count += 1
	return count

## Buys a READY unlock that has a price: spends the bank, opens it, and opens any child whose play
## condition is already met. False (nothing spent) when it can't be bought.
static func buy(uid: String) -> bool:
	if state(uid) != S.READY || price(uid).is_empty() || not canAfford(uid): return false
	var cost := price(uid)
	data().coin -= int(cost.get("coin", 0))
	data().gem -= int(cost.get("gem", 0))
	if uid.begins_with("car:"): carEntry(uid.trim_prefix("car:")).cost = 0
	else: saved()[uid] = true
	refresh()
	SaveManager.save_character_data()
	return true

## Opens without paying (migration of a starter, the dev console, career tiers).
static func grant(uid: String) -> void:
	if uid.begins_with("car:"):
		var car = carEntry(uid.trim_prefix("car:"))
		if car != null: car.cost = 0
	elif data() != null: saved()[uid] = true

## Opens every pickup whose parent is open, whose condition is met and that has no price. Runs on the
## results ticket and after a purchase, never in a run, so a run's drop pool doesn't change under it.
## Returns the newly opened pickup ids, for the ticket's note.
static func refresh() -> Array:
	var opened := []
	var changed := true
	while changed: #a pickup opened here may open a child with a met condition
		changed = false
		for id in Pickups.DATA:
			if not Pickups.DATA[id].has("needs") || isPickupOpen(id): continue
			if state("pickup:" + id) != S.READY: continue
			saved()["pickup:" + id] = true
			opened.push_back(id)
			changed = true
	return opened

#--- conditions ---------------------------------------------------------------------------------

## Conditions: "nights:<n>", "giants:<n>", "crushes:<n>", "crushed:<faction>:<n>", "wins:<mode>:<n>",
## "mode:<mode>" (open on any level), "open:<level>", "survive:<seconds>" (best Goonpocalypse anywhere),
## "clears:<tier>:<n>" (mode-and-level completions on that tier or harder, ModeTiers; tier easy, medium or hard),
## "boxes:<n>" (gift boxes opened over every run), "carclears:<n>" (mode-and-level wins by distinct cars, any tier:
## SaveManager.carClearCount), "garages:<n>" (Full Garages: every car has won a mode on a level).
## Lifetime counters (meta.lifetime) are added on the results ticket (countRun).
static func needsMet(needs: Array) -> bool:
	for need in needs:
		var p := progressOf(need)
		if p.have < p.need: return false
	return true

## {have, need, text} for one condition
static func progressOf(need: String) -> Dictionary:
	var parts := need.split(":")
	var n := int(parts[-1]) if parts[-1].is_valid_int() else 1
	match parts[0]:
		"nights": return {"have": lifetime("nights"), "need": n, "text": "Drive through %d night%s" % [n, "" if n == 1 else "s"]}
		"giants": return {"have": lifetime("giants"), "need": n, "text": "Crush %d giants" % n}
		"crushes": return {"have": totalCrushed(-1), "need": n, "text": "Crush %d goons" % n}
		"crushed":
			var f := FACTION_KEYS.find(parts[1])
			return {"have": totalCrushed(f), "need": n, "text": "Crush %d %s goons" % [n, parts[1].capitalize()]}
		"wins":
			var mode := MODE_KEYS.find(parts[1])
			var name: String = Root.gameModeDescription[mode].name.capitalize() if mode >= 0 else parts[1]
			return {"have": lifetime("wins_" + parts[1]), "need": n, "text": "Win %s" % (("a " + name) if n == 1 else "%d %s runs" % [n, name])}
		"mode":
			var mode := MODE_KEYS.find(parts[1])
			var open := 0
			if data() != null && mode >= 0:
				for level in data().levels:
					if Root.isModeUnlocked(level, mode): open = 1
			return {"have": open, "need": 1, "text": "Open %s" % Root.gameModeDescription[mode].name.capitalize() if mode >= 0 else parts[1]}
		"open":
			var i := Levels.indexOf(StringName(parts[1]))
			var open := 1 if i >= 0 && data() != null && data().levels[i].unlocked else 0
			return {"have": open, "need": 1, "text": "Open %s" % (Levels.defAt(i).displayName if i >= 0 else parts[1])}
		"survive":
			return {"have": bestSurvival(), "need": n, "text": "Survive %d:%02d in Goonpocalypse" % [n / 60, n % 60]}
		"boxes": return {"have": lifetime("boxes"), "need": n, "text": "Open %d gift box%s" % [n, "" if n == 1 else "es"]}
		"carclears": return {"have": SaveManager.carClearCount() if data() != null else 0, "need": n, "text": "Earn %d car clear%s" % [n, "" if n == 1 else "s"]}
		"garages": return {"have": SaveManager.fullGarageCount() if data() != null else 0, "need": n, "text": "Win %d Full Garage%s" % [n, "" if n == 1 else "s"]}
		"clears":
			var tier := TIER_KEYS.find(parts[1])
			var have := ModeTiers.clears(data().levels, tier) if data() != null && tier > 0 else 0
			return {"have": have, "need": n, "text": "Win %d %s medal%s" % [n, ModeTiers.MEDALS[maxi(tier, 0)].to_lower(), "" if n == 1 else "s"]}
	return {"have": 0, "need": 1, "text": need}

## A pickup's progress toward its condition (the first unmet one), or {} when it has none.
static func progress(uid: String) -> Dictionary:
	if not uid.begins_with("pickup:"): return {}
	for need in Pickups.DATA.get(uid.trim_prefix("pickup:"), {}).get("needs", []):
		var p := progressOf(need)
		if p.have < p.need: return p
	return {}

## Is this a condition the parser knows (tests check every pickup's)?
static func isValidNeed(need: String) -> bool:
	var parts := need.split(":")
	match parts[0]:
		"nights", "giants", "crushes", "survive", "boxes", "carclears", "garages": return parts.size() == 2 && parts[1].is_valid_int()
		"crushed": return parts.size() == 3 && parts[1] in FACTION_KEYS && parts[2].is_valid_int()
		"wins": return parts.size() == 3 && parts[1] in MODE_KEYS && parts[2].is_valid_int()
		"mode": return parts.size() == 2 && parts[1] in MODE_KEYS
		"open": return parts.size() == 2 && Levels.indexOf(StringName(parts[1])) >= 0
		"clears": return parts.size() == 3 && TIER_KEYS.find(parts[1]) > 0 && parts[2].is_valid_int()
	return false

#--- what's next --------------------------------------------------------------------------------

## The shown or ready pickup closest to done, for run setup's "Next unlock" line: {uid, name, text, have,
## need}, or {} when nothing is waiting. A ready one the bank covers comes first, then the cheapest ready
## one, then the condition nearest its goal.
static func nextUnlock() -> Dictionary:
	var best := {}
	var bestScore := -INF
	for id in Pickups.DATA:
		var uid: String = "pickup:" + id
		var s := state(uid)
		if s != S.READY && s != S.SHOWN: continue
		if Root.IS_DEMO && not inDemo(id): continue
		var entry := {"uid": uid, "name": Pickups.displayName(id)}
		var score: float
		var cost := pickupPrice(id)
		if s == S.READY && not cost.is_empty():
			var coins := int(cost.get("coin", 0))
			var gems := int(cost.get("gem", 0))
			entry.text = priceText(cost)
			entry.have = mini(data().coin, coins) if coins > 0 else mini(data().gem, gems)
			entry.need = coins if coins > 0 else gems
			score = (2.0 if canAfford(uid) else 1.0) + 1.0 / (1.0 + coins + gems * 500)
		else:
			var p := progress(uid)
			if p.is_empty(): continue
			entry.merge(p)
			score = float(p.have) / maxf(float(p.need), 1.0)
		if score > bestScore:
			bestScore = score
			best = entry
	return best

static func priceText(cost: Dictionary) -> String:
	var parts := []
	if cost.get("coin", 0) > 0: parts.push_back("%s coins" % DriverCard.formatCoins(cost.coin))
	if cost.get("gem", 0) > 0: parts.push_back("%d gem%s" % [cost.gem, "" if cost.gem == 1 else "s"])
	return " + ".join(parts)

#--- the results ticket -------------------------------------------------------------------------

## Adds a finished run to the lifetime counters the conditions read. Called once by the results ticket.
static func countRun(won: bool, mode: int, nights: int, giants: int, boxes := 0) -> void:
	if data() == null: return
	var life: Dictionary = data().meta.get_or_add("lifetime", {})
	life.runs = int(life.get("runs", 0)) + 1
	life.nights = int(life.get("nights", 0)) + nights
	life.giants = int(life.get("giants", 0)) + giants
	life.boxes = int(life.get("boxes", 0)) + boxes #gift boxes opened (CrushPrizes)
	life.bestBox = maxi(int(life.get("bestBox", 0)), boxes) #the most in one run
	if won && mode >= 0 && mode < MODE_KEYS.size():
		var key: String = "wins_" + MODE_KEYS[mode]
		life[key] = int(life.get(key, 0)) + 1

#--- save access --------------------------------------------------------------------------------

static func data() -> PlayerData:
	return SaveManager.playerData

## meta.unlocks: uid -> true for everything opened (pickups today; cosmetics and stations later)
static func saved() -> Dictionary:
	if data() == null: return {}
	return data().meta.get_or_add("unlocks", {})

static func lifetime(key: String) -> int:
	if data() == null: return 0
	return int(data().meta.get("lifetime", {}).get(key, 0))

## Goons crushed over every run, of one faction (Goons.faction) or all (-1)
static func totalCrushed(faction: int) -> int:
	if data() == null: return 0
	var total := 0
	for id in data().goonsCrushed:
		if faction >= 0 && int(Goons.DATA.get(StringName(id), {}).get("faction", -1)) != faction: continue
		total += int(data().goonsCrushed[id])
	return total

static func bestSurvival() -> int:
	var best := 0
	if data() == null: return best
	for byCar in data().meta.get("records", {}).get("goonpocalypse", {}).values():
		if not byCar is Dictionary: continue
		for rec in byCar.values():
			if rec is Dictionary: best = maxi(best, int(rec.get("time", 0)))
	return best

static func carEntry(carName: String):
	if data() == null: return null
	for car in data().cars:
		if car.name == carName: return car
	return null
