class_name PickupEffects extends RefCounted

#What each pickup does when it is collected (scripts/global/pickups.gd holds the numbers). Everything
#is credited here at once; flyers, toasts and labels that follow are only for show.

## Collects `id` for the car. `pos` is where it was picked up (labels and spawned things go there).
static func collect(car, id: String, pos: Vector2) -> void:
	if not is_instance_valid(car) || not Pickups.has(id): return
	var d := Pickups.def(id)
	if d.has("scene"): #an original pickup won from a slot, a card, the claw or a Mystery Box: its own scene pays it
		dropAndCollect(car, id, car.global_position)
		return
	Pickups.discover(id)
	Pickups.countCollected(car, id)
	car.powerupsCollected += 1
	car.rewarded.emit(id, 1)
	announce(id)
	match d.kind:
		Pickups.K.SUPPLY: supply(car, id, d)
		Pickups.K.TUNE: tune(car, id, d)
		Pickups.K.BOOST: car.addBuff(id)
		Pickups.K.GADGET:
			if not car.giveItem(id):
				var price := 10 * (Pickups.rarity(id) + 1)
				car.reward("coin", price)
				label(pos, "SOLD +%d" % price)
		Pickups.K.LOOT: loot(car, id, d, pos)
		Pickups.K.CASINO: casino(car, id)
		Pickups.K.SKILL:
			match id:
				"potato": car.addBuff("potato")
				"truck": PickupWorld.spawnLootTruck(car)
				"delivery":
					car.hasParcel = true
					label(pos, "DELIVER IT")
		Pickups.K.MODE: mode(car, id, d)
	if is_instance_valid(car.ui): car.ui.updateStats()
	if is_instance_valid(car.buffFx): car.buffFx.updateProcessing()

## An original pickup's scene, added and collected at once (its own sendReward credits it).
## Deferred, because it is often reached from a physics callback where areas can't be added.
static func dropAndCollect(car, id: String, pos: Vector2) -> void:
	if not is_instance_valid(Root.levelRoot): return
	var node = Pickups.make(id)
	node.position = pos
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	var collectNow := func():
		if not is_instance_valid(Root.levelRoot) || not is_instance_valid(car): return
		Root.levelRoot.add_child(node)
		node.sendReward(car, false)
	collectNow.call_deferred()

## A pickup node of `id` lying at `pos`, to be driven over.
static func spawnPickup(id: String, pos: Vector2) -> Node2D:
	if not is_instance_valid(Root.levelRoot): return null
	var node = Pickups.make(id)
	node.position = pos
	Root.levelRoot.add_child.call_deferred(node)
	return node

static func announce(id: String) -> void:
	var r := Pickups.rarity(id)
	if r >= Pickups.R.RARE && r <= Pickups.R.LEGENDARY && is_instance_valid(HudChance.current):
		HudChance.current.toast("%s  -  %s" % [Pickups.RARITY_NAMES[r], Pickups.displayName(id)], Pickups.rarityColor(r), Pickups.texture(id))

static func label(pos: Vector2, text: String) -> void:
	if is_instance_valid(Root.spawnManager) && Root.spawnManager.fx: Root.spawnManager.fx.label(pos, text)

static func toast(text: String, color := HudTheme.GOLD, icon: Texture2D = null) -> void:
	if is_instance_valid(HudChance.current): HudChance.current.toast(text, color, icon)

#--- kinds --------------------------------------------------------------------------------------

static func supply(car, id: String, d: Dictionary) -> void:
	match id:
		"jerry":
			car.reward("fuel", d.fuel)
			car.resetGasWarning()
		"wrench":
			var worst := "engine"
			for s in car.condition:
				if car.condition[s] < car.condition[worst]: worst = s
			car.setCondition(worst, car.condition[worst] + d.repair)
		"toolbox":
			for s in car.condition: car.setCondition(s, car.condition[s] + d.repair)
		"service":
			car.fuel = 100.0
			car.health = 100.0
			car.repairAll()
			car.updateDamageLook()
			car.resetGasWarning()
			car.resetHealthWarning()
		_:
			if d.has("system"): car.setCondition(d.system, 100.0)

static func tune(car, id: String, d: Dictionary) -> void:
	match id:
		"crate":
			var stats: Array = OverheadCarBody2D.UPGRADEABLE_STATS.duplicate()
			stats.sort_custom(func(a, b): return car.get(a) < car.get(b))
			var stat: String = stats[randi() % 3]
			car.reward(stat, d.amount)
			label(car.global_position, "+%d %s" % [d.amount, Pickups.displayName(stat).to_upper()])
		"overhaul":
			for stat in OverheadCarBody2D.UPGRADEABLE_STATS: car.reward(stat, d.amount)
		"turbo":
			car.reward("engine", d.amount)
			car.turboKit = true
		"blueprint":
			car.blueprints += 1

static func loot(car, id: String, d: Dictionary, pos: Vector2) -> void:
	match id:
		"coinstack": car.reward("coin", d.coins)
		"gemcluster": car.reward("gem", d.gems)
		"starfrag": addStarFragment(car)
		"strongbox": PickupWorld.spawnStrongbox(pos)
		"goldgoon": PickupWorld.spawnGoldenGoon(car)

static func addStarFragment(car) -> void:
	car.starFragments += 1
	if car.starFragments >= 3:
		car.starFragments -= 3
		car.star += 1
		toast("THREE FRAGMENTS  -  +1 STAR", HudTheme.GOLD, HudTheme.STAR_ICON)
	else: toast("STAR FRAGMENT  %d / 3" % car.starFragments, HudTheme.GOLD, Pickups.texture("starfrag"))

static func casino(car, id: String) -> void:
	match id:
		"scratch":
			if is_instance_valid(HudChance.current): HudChance.current.startScratch()
		"double":
			if is_instance_valid(HudChance.current): HudChance.current.startDouble(car)
		"lottery":
			car.lotteryTickets.push_back([randi() % 10, randi() % 10, randi() % 10])
			toast("LOTTERY TICKET  %s" % "-".join(car.lotteryTickets.back().map(func(n): return str(n))), Pickups.rarityColor(Pickups.R.UNCOMMON), Pickups.texture("lottery"))
		"mystery":
			var other := mysteryRoll()
			toast("MYSTERY BOX  -  %s" % Pickups.displayName(other).to_upper(), Pickups.rarityColor(Pickups.rarity(other)), Pickups.texture(other))
			collect(car, other, car.global_position)
		"deal": PickupDeal.open(false)
		"claw": ClawCrane.open()

## Any pickup but another box: the tier is rolled again (with Dice), from every kind.
static func mysteryRoll() -> String:
	for i in 6:
		var id := Pickups.rollForCar()
		if id != "mystery": return id
	return "coinstack"

static func mode(car, id: String, d: Dictionary) -> void:
	match id:
		"stopwatch":
			Root.levelRoot.seconds += d.seconds
			label(car.global_position, "+%d S" % d.seconds)
		"ffwd":
			Root.levelRoot.seconds = maxf(1.0, Root.levelRoot.seconds - d.seconds)
			label(car.global_position, "-%d S" % d.seconds)
		"barricade":
			car.barricades += 1
			label(car.global_position, "TAKE IT TO THE LOT")
		"turret": PickupWorld.spawnTurret()
		"compass", "panic": car.addBuff(id)

#--- hooks --------------------------------------------------------------------------------------

## The car crushed a goon at `pos`: Crush Combo, Coin Frenzy and Golden Ride pay here.
static func onCrush(car, pos: Vector2) -> void:
	var now := Engine.get_physics_frames()
	var gap := int(Pickups.DATA["combo"]["gap"] * Pickups.TICKS)
	car.comboCount = car.comboCount + 1 if now - car.comboTick <= gap else 1
	car.comboTick = now
	car.bestCombo = maxi(car.bestCombo, car.comboCount)
	var mult := comboCoins(car.comboCount)
	if mult > 0:
		Pickups.discover("combo")
		car.reward("coin", mult)
		if is_instance_valid(HudChance.current): HudChance.current.showCombo(car.comboCount, mult)
	if car.hasBuff("golden"): car.reward("coin", Pickups.DATA["golden"]["coins"])
	if car.hasBuff("frenzy") && is_instance_valid(Root.spawnManager) && Root.spawnManager.fx:
		Root.spawnManager.fx.dropAt(pos, "res://scene/powerup/coin.tscn")

## Coins each crush in a chain of `count` pays: none below 3, then 2, rising by 1 every 3 crushes to 5.
static func comboCoins(count: int) -> int:
	if count < 3: return 0
	return mini(2 + (count - 3) / 3, 5)

## The Hot Potato ran out before it found a crowd.
static func potatoFailed(car) -> void:
	if not is_instance_valid(car): return
	if is_instance_valid(Root.levelRoot): Root.levelRoot.explode(car.global_position)
	label(car.global_position, "TOO SLOW")
	car.loseHealth(25.0)

## The car pulled into an active station's driveway (station.gd): Delivery and Barricade Kits pay here.
static func onStationReached(car, station) -> void:
	if car.hasParcel:
		car.hasParcel = false
		if car.health >= Pickups.DATA["delivery"]["minHealth"]:
			car.star += 1
			toast("DELIVERED  -  +1 STAR", HudTheme.GOLD, Pickups.texture("delivery"))
		else: toast("PARCEL DAMAGED", HudTheme.BAD, Pickups.texture("delivery"))
	if car.barricades > 0 && station.get("hasBarrier"):
		var add: float = car.barricades * Pickups.DATA["barricade"]["barrier"]
		car.barricades = 0
		station.repairBarrier(add)
		toast("BARRIER +%d" % add, HudTheme.OK, Pickups.texture("barricade"))

## A prompt on screen (Double or Nothing) takes the Use button instead of the gadget.
static func useTakenByPrompt() -> bool:
	return is_instance_valid(HudChance.current) && HudChance.current.doubleActive

#--- the results ticket (gameSummary) -----------------------------------------------------------

## Lottery Tickets: each number matching the last digit of crushes, top speed (MPH) and coins pays 50;
## all three pay 500. Added to the run's coins before the payout. Returns [winnings, matches].
static func payLottery(car, topSpeedMph: int) -> Array:
	if car.lotteryTickets.is_empty(): return [0, 0]
	var digits := [car.currentGoonsCrushed % 10, topSpeedMph % 10, car.coin % 10]
	var winnings := 0
	var matches := 0
	for ticket in car.lotteryTickets:
		var hit := 0
		for i in 3:
			if ticket[i] == digits[i]: hit += 1
		matches += hit
		winnings += 500 if hit == 3 else hit * 50
	car.coin += winnings
	return [winnings, matches]

## Blueprints: a free garage upgrade each, for this car's lowest stat that isn't maxed. Returns the
## stats upgraded (display names). Saved by gameSummary with the rest of the run.
static func creditBlueprints(car) -> Array:
	var upgraded := []
	var saved = SaveManager.getCarByName(car.carId)
	if saved == null: return upgraded
	for i in car.blueprints:
		var best := ""
		for stat in OverheadCarBody2D.UPGRADEABLE_STATS:
			var level: int = saved.upgrades.get(Root.upgrade[stat.to_upper()], 0)
			if level >= SaveManager.MAX_UPGRADE_LEVEL: continue
			if best == "" || level < saved.upgrades.get(Root.upgrade[best.to_upper()], 0): best = stat
		if best == "": break
		var key = Root.upgrade[best.to_upper()]
		saved.upgrades[key] = saved.upgrades.get(key, 0) + 1
		upgraded.push_back(Pickups.displayName(best))
	car.blueprints = 0
	return upgraded
