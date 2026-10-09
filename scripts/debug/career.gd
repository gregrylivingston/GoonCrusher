class_name CareerPilot extends Node

#Career playtests (docs/AI_DRIVER.md, "Career playtests"): one of the Personas plays the whole game as a
#player would, from a chosen point in its progress, through the real menus. It shops in the garage, picks a
#car, a level, a mode and a gadget in run setup, drives the run with the AI driver, answers every screen
#that pauses the run (slot machine, The Deal, Claw Crane, Pit Shop, pause), reads the results ticket and
#goes back to the garage, again and again. Menus get input actions (KeyHint.fire, as keys and pads send)
#or mouse clicks pushed into the viewport, never direct calls, so a menu a player can't work blocks the
#persona too. Started by the Playtest autoload with --career, which records every run (PLAYTEST_RESULT and
#the CSV) as it does for plain playtests.
#  Godot_console.exe --headless --fixed-fps 60 --path . -- --career --persona=rookie --start=fresh --sessions=40 --uncapped
#Options: --persona=rookie|grinder|explorer  --start=fresh|early|mid|late|maxed (CareerStart.TIERS)
#  --save=<path> (start from a copy of this save instead; the file is only read)  --coins=N --gems=N
#  --cars=N --upgrades=N --levels=N (override the tier)  --sessions=N (runs to play, default 30)
#  --minutes=N (stop after this much level time)  --seed=N  --tag=name  --sight=human|full  --max-seconds=N
#Output in user://playtest/: results<tag>.csv (one row per run), <tag>_events.log (every menu action and
#check), <tag>_summary.json (CAREER_SUMMARY: progress, milestones, economy, issues and script errors).
#Lines printed: CAREER_RUN, CAREER_SHOP, CAREER_ISSUE, CAREER_MILESTONE, CAREER_SUMMARY.
#Autopilot (the console's `autopilot`, beginAutopilot): the same persona play, on whatever save is in use,
#in the running game with its transitions, until stop(). Without the Playtest autoload it attaches the
#driver itself (its plan drawn) and records each run from the car when it ends.

const MENU_SCENE := "res://scene/player/menu/main/main2.tscn"
const GARAGE := 0 #main2.Screen
const SETUP := 1
const MODE_ORDER := Root.MODE_PATH #the medallions, left to right (main2.MODE_ORDER)
const SOFTLOCK_MS := 10000

var playtest: Node #the Playtest autoload, which records the runs (null under autopilot)
var standalone := false     #autopilot: no Playtest, the save in use, the game keeps running after stop()
var stopped := false        #stop() was called: every wait returns at once and the career ends
var injecting := false      #a click is being pushed in (the console tells it from a person's own click)
var finished := Callable()  #autopilot: told the summary line when the career ends
var options := {}
var personaId := ""
var persona := {}
var startName := ""
var tag := ""
var rng := RandomNumberGenerator.new()
var history: Array = []   #one entry per run: car, level_index, mode_id, won, payout, level_time, ...
var issues: Array = []    #{kind, session, text}
var milestones: Array = []
var shopping := {"cars": 0, "car_coins": 0, "upgrades": 0, "upgrade_coins": 0, "pickups": 0, "pickup_coins": 0, "gadgets": 0, "boosts": 0}
var session := 0
var sessions := 30
var maxMinutes := INF
var firstSeed := 1
var startProgress := {}
var logFile: FileAccess
var errors := ErrorCatcher.new()
var recovering := 0

#the run in progress
var runActive := false
var runRow := {}            #Playtest's row, once the run is recorded
var runPlan := {}           #what the persona chose: level, mode, car, loadout
var bankBefore := {}
var pauseAt := INF          #level time at which the persona pauses this run
var abandonThisRun := false
var handling := false       #a coroutine is answering a pausing screen
var pausedEmptySince := -1
var runTime := 0.0

#---------- setup (from Playtest._ready, before the menu scene loads) ----------

## Reads the options and writes the starting save. Returns "" or an error.
func setup(opts: Dictionary) -> String:
	options = opts
	process_mode = Node.PROCESS_MODE_ALWAYS
	personaId = str(options.get("persona", "rookie"))
	if not Personas.has(personaId): return "Unknown persona %s (have %s)" % [personaId, ", ".join(Personas.DATA.keys())]
	persona = Personas.get_def(personaId)
	startName = str(options.get("start", "fresh"))
	sessions = int(options.get("sessions", 30))
	maxMinutes = float(options.get("minutes", INF))
	firstSeed = int(options.get("seed", 1))
	rng.seed = firstSeed * 7919 + hash(personaId)
	tag = str(options.get("tag", "career_%s_%s" % [personaId, startName]))
	options["tag"] = tag #Playtest's CSV goes to results<tag>.csv
	var csv := "user://playtest/results%s.csv" % tag #a new career gets a file of its own; an older one is kept aside
	if FileAccess.file_exists(csv): DirAccess.rename_absolute(csv, csv.get_basename() + "_old_%d.csv" % Time.get_unix_time_from_system())
	var data: PlayerData
	if options.has("save"):
		var source := str(options.save)
		if not ResourceLoader.exists(source): return "No save at " + source
		data = ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not data is PlayerData: return source + " isn't a PlayerData save"
		data = data.duplicate(true)
		startName = "save"
	else:
		var overrides := {}
		for key in ["coins", "gems", "cars", "upgrades", "levels"]:
			if options.has(key): overrides[key] = int(options[key])
		data = CareerStart.build(startName, overrides)
		if data == null: return "Unknown start %s (have %s)" % [startName, ", ".join(CareerStart.TIERS.keys())]
	SaveManager.save_path = "user://playtest/%s_save.tres" % tag
	SaveManager.playerData = data
	SaveManager.migrate()
	SaveManager.save_character_data()
	SaveManager.flush()
	startProgress = CareerStart.progress(data)
	logFile = FileAccess.open("user://playtest/%s_events.log" % tag, FileAccess.WRITE)
	OS.add_logger(errors)
	note("CAREER_START persona=%s start=%s sessions=%d seed=%d progress=%s" % [personaId, startName, sessions, firstSeed, JSON.stringify(startProgress)])
	return ""

## Autopilot: a persona plays the save in use from wherever the game is (the menu, or a run, which it takes
## over). Returns what the console shows. stop() hands control back.
func beginAutopilot(id: String) -> String:
	process_mode = Node.PROCESS_MODE_ALWAYS
	standalone = true
	personaId = id
	persona = Personas.get_def(id)
	startName = CareerStart.activeTier() if CareerStart.activeTier() != "" else "real"
	sessions = 1000000
	rng.randomize()
	tag = "autopilot"
	DirAccess.make_dir_recursive_absolute("user://playtest")
	startProgress = CareerStart.progress(SaveManager.playerData)
	logFile = FileAccess.open("user://playtest/autopilot_events.log", FileAccess.WRITE)
	OS.add_logger(errors)
	note("CAREER_START autopilot persona=%s save=%s progress=%s" % [personaId, startName, JSON.stringify(startProgress)])
	var device: String = {"mouse": "the mouse", "keys": "the keyboard", "mixed": "mouse and keys"}[persona.device]
	return "%s (%s driver, menus by %s) at the wheel" % [persona.name, persona.profile, device]

## Hands control back: the driver comes off the car, held keys are let go, and the career ends at its next step
func stop() -> void:
	if stopped: return
	stopped = true
	for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight"]: Input.action_release(action)
	if is_instance_valid(Root.playerCar) && Root.playerCar.myController.driver != null:
		var driver = Root.playerCar.myController.driver
		Root.playerCar.myController.driver = null
		if is_instance_valid(driver): driver.queue_free()

func _ready() -> void:
	if standalone: get_tree().node_added.connect(onNodeAdded)
	main.call_deferred()

#autopilot: every run's car gets the persona's driver, plan drawn (the Playtest autoload does this for careers)
func onNodeAdded(node: Node) -> void:
	if not stopped && node is OverheadCarBody2D && node.isPlayer: node.ready.connect(attachDriver.bind(node), CONNECT_ONE_SHOT)

func attachDriver(car: OverheadCarBody2D) -> void:
	if stopped || not is_instance_valid(car) || car.myController.driver != null: return
	AIDriver.attach(car, {"profile": persona.profile, "debug": true})

func _exit_tree() -> void:
	OS.remove_logger(errors)

#---------- the career ----------

func main() -> void:
	if standalone && Root.isRunActive && is_instance_valid(Root.playerCar): await takeOverRun()
	while not stopped && session < sessions && minutesPlayed() < maxMinutes:
		session += 1
		var before := snapshot()
		var ok := await menuVisit()
		if ok: ok = await playRun()
		if ok: ok = await readResults()
		milestonesSince(before)
		if not ok:
			recovering += 1
			if recovering >= 3:
				issue("abort", "three sessions in a row ended in a block; stopping")
				break
			if stopped: break
			await recover()
		else: recovering = 0
	finish()

#autopilot started mid-run: drive the rest of it, then carry on from the results as usual
func takeOverRun() -> void:
	session += 1
	attachDriver(Root.playerCar)
	var data := SaveManager.playerData
	runPlan = {"level": data.selectedLevel, "mode": data.gameMode, "tier": SaveManager.getGameTier(), "car": data.selectedCar, "gadget": "", "boost": ""}
	bankBefore = {"coin": data.coin, "gem": data.gem, "gadget_cost": 0}
	runRow = {}
	runActive = true
	pauseAt = INF
	abandonThisRun = false
	if await playRun(): await readResults()

func minutesPlayed() -> float:
	var total := 0.0
	for r in history: total += float(r.level_time)
	return total / 60.0

## Back to a clean garage after a block: unpause and change to the menu, as restarting the game would.
func recover() -> void:
	note("CAREER_RECOVER session=%d: back to the main menu" % session)
	runActive = false
	handling = false
	for action in ["Accelerate", "Brake", "TurnLeft", "TurnRight"]: Input.action_release(action)
	get_tree().paused = false
	Settings.menuDepth = 0 #an overlay left open counts as open until popped
	Root.isRunActive = false
	get_tree().change_scene_to_file(MENU_SCENE)
	await waitFor(menuReady, 30.0, "")

#---------- the garage and run setup ----------

func menu() -> Node:
	return Root.mainMenu if is_instance_valid(Root.mainMenu) && Root.mainMenu.is_inside_tree() else null

func menuReady() -> bool:
	var m := menu()
	return m != null && not m.loadingLevel && not Transition.busy() && not Settings.menu_open && not m.overlayOpen() \
		&& get_tree().current_scene == m

## One visit to the menus: side trips, shopping, the car, then run setup and Start. False on a block.
func menuVisit() -> bool:
	if not await waitFor(menuReady, 60.0, "the main menu to be ready"): return false
	await think(0.6)
	var m := menu()
	if m.screen != GARAGE:
		await press("ui_cancel")
		if not await waitFor(func(): return menu() != null && menu().screen == GARAGE, 5.0, "Back to leave run setup"): return false
	if rng.randf() < persona.overlays: await sideTrips()
	if not await shop(): return false
	var car := Personas.chooseCar(persona, SaveManager.playerData, history)
	if not await selectCar(car): return false
	var run := Personas.chooseRun(persona, SaveManager.playerData, history, rng)
	if run.is_empty():
		issue("no_run", "no level and mode can be started from this save")
		return false
	if not await openSetup(): return false
	if not await selectLevel(run.level): return false
	if not await selectMode(run.mode): return false
	if not await selectTier(run.get("tier", ModeTiers.EASY)): return false
	var gadget := Personas.chooseLoadout(persona, SaveManager.playerData.gem, rng)
	await chooseSlot("loadout", gadget, m.loadoutButton, "ui_upgrade")
	var boost := Personas.chooseBoost(persona, SaveManager.playerData.gem - Pickups.LOADOUT.get(m.slotPurchase("loadout"), 0), rng)
	await chooseSlot("boostLoadout", boost, m.boostButton, "ui_boost")
	return await start(run, car, gadget, boost)

func shop() -> bool:
	for i in 60: #a purchase at a time, re-planned with the new bank
		var want := Personas.nextPurchase(persona, SaveManager.playerData, history, rng)
		if want.is_empty(): break
		var ok: bool
		if want.has("unlock"): ok = await unlock(want.unlock)
		elif want.has("pickup"): ok = await unlockPickup(want.pickup)
		else: ok = await upgrade(want.car, want.upgrade)
		if not ok: return false
	var m := menu()
	if m != null && m.upgrading:
		await activate(m.cards[SaveManager.playerData.selectedCar].upgradeButton, "ui_cancel")
		if not await waitFor(func(): return not menu().upgrading, 3.0, "Done to close the upgrade sheet"): return false
	return true

func selectCar(index: int) -> bool:
	var m := menu()
	var data := SaveManager.playerData
	if data.selectedCar == index: return true
	if m.upgrading:
		await press("ui_cancel")
		if not await waitFor(func(): return not menu().upgrading, 3.0, "Back to close the upgrade sheet"): return false
	for step in data.cars.size() + 2:
		if data.selectedCar == index: return true
		var count := data.cars.size()
		var offset := wrapi(index - data.selectedCar + count / 2, 0, count) - count / 2
		var before := data.selectedCar
		var side: DriverCard = m.cards[wrapi(data.selectedCar + signi(offset), 0, count)]
		if useMouse() && side.catcher.is_visible_in_tree(): await click(side.catcher)
		else: await press("ui_tab_next" if offset > 0 else "ui_tab_prev")
		if data.selectedCar == before:
			issue("block", "the garage didn't move to the next driver (from %s toward %s)" % [data.cars[before].name, data.cars[index].name])
			return false
	return data.selectedCar == index

func unlock(index: int) -> bool:
	var data := SaveManager.playerData
	if not await selectCar(index): return false
	var card: DriverCard = menu().cards[index]
	var price: int = data.cars[index].cost
	var gemPrice: int = data.cars[index].get("gems", 0)
	var coins := data.coin
	var gems := data.gem
	if not card.isLocked(): return true
	if card.mainButton.disabled:
		issue("ui", "the Unlock button for %s is disabled with %d coins against a price of %d" % [data.cars[index].name, coins, price])
		return false
	await activate(card.mainButton, "ui_accept")
	await think(0.3)
	if data.cars[index].cost != 0 || data.coin != coins - price || data.gem != gems - gemPrice:
		issue("economy", "unlocking %s: cost %d + %d gems, bank %d -> %d, gems %d -> %d" % [data.cars[index].name, price, gemPrice, coins, data.coin, gems, data.gem])
		return false
	shopping.cars += 1
	shopping.car_coins += price
	note("CAREER_SHOP session=%d unlock %s for %d (bank %d)" % [session, data.cars[index].name, price, data.coin])
	return true

## Unlocks a pickup or a prize game ("prize:<game>") in the Goonopedia's Pickups tab: G, a click on the tab,
## then two clicks on its tile (the first shows it, the second buys it), then Back.
func unlockPickup(id: String) -> bool:
	var uid := id if id.begins_with("prize:") else "pickup:" + id
	var data := SaveManager.playerData
	if menu().upgrading:
		await press("ui_cancel")
		if not await waitFor(func(): return not menu().upgrading, 3.0, "Back to close the upgrade sheet"): return false
	await press("ui_codex")
	if not await waitFor(func(): return goonopedia() != null, 3.0, "G to open the Goonopedia"): return false
	var page := goonopedia()
	await click(page.tabButtons[Goonopedia.Tab.PICKUPS])
	if page.tab != Goonopedia.Tab.PICKUPS:
		issue("ui", "a click on the PICKUPS tab left the Goonopedia on %s" % Goonopedia.TAB_NAMES[page.tab])
		return false
	var coins := data.coin
	var gems := data.gem
	var cost := Unlocks.price(uid)
	var tile := page.tileFor(id)
	if tile == null:
		issue("ui", "no Goonopedia tile for the ready pickup %s" % id)
		return false
	if not await wheelIntoView(page.listScroll, tile):
		issue("mouse", "the mouse wheel couldn't bring the %s tile into view in the Goonopedia" % id)
		return false
	await click(tile)
	if Unlocks.isOpen(uid): issue("ui", "the first click on %s bought it; a click should only show a tile" % id)
	else: await click(page.tileFor(id))
	var ok := Unlocks.isOpen(uid) && data.coin == coins - int(cost.get("coin", 0)) && data.gem == gems - int(cost.get("gem", 0))
	if not ok: issue("economy" if data.coin != coins else "block", "unlocking %s: open %s, bank %d -> %d coins, %d -> %d gems (price %s)" % [uid, Unlocks.isOpen(uid), coins, data.coin, gems, data.gem, cost])
	else:
		shopping.pickups = int(shopping.get("pickups", 0)) + 1
		shopping.pickup_coins = int(shopping.get("pickup_coins", 0)) + int(cost.get("coin", 0))
		note("CAREER_SHOP session=%d pickup %s for %s (bank %d)" % [session, id, Unlocks.priceText(cost), data.coin])
	await press("ui_cancel")
	await waitFor(func(): return goonopedia() == null, 3.0, "Back to close the Goonopedia")
	return ok

## Turns the mouse wheel over a scroll container until `control` is wholly inside it, as a player scrolls
## a list to find something. False when it never gets there.
func wheelIntoView(scroll: ScrollContainer, control: Control) -> bool:
	for step in 60:
		var view := scroll.get_global_rect()
		var rect := control.get_global_rect()
		if view.encloses(rect): return true
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if rect.end.y > view.end.y else MOUSE_BUTTON_WHEEL_UP
		wheel.position = view.get_center()
		wheel.global_position = wheel.position
		for down in [true, false]:
			wheel.pressed = down
			injecting = true
			scroll.get_viewport().push_input(wheel.duplicate(), true)
			injecting = false
		await get_tree().process_frame
	return false

func goonopedia() -> Goonopedia:
	for node in get_tree().get_nodes_in_group("menuOverlay"):
		if node is Goonopedia && not node.is_queued_for_deletion(): return node
	return null

func upgrade(index: int, stat: int) -> bool:
	var data := SaveManager.playerData
	if not await selectCar(index): return false
	var m := menu()
	var card: DriverCard = m.cards[index]
	if not m.upgrading:
		await activate(card.upgradeButton, "ui_upgrade")
		if not await waitFor(func(): return menu().upgrading, 3.0, "Upgrade to open the sheet"): return false
	var row := -1
	for i in DriverCard.STATS.size(): if DriverCard.STATS[i][1] == stat: row = i
	var button: Button = card.statButtons[row]
	var level := int(data.cars[index].upgrades.get(stat, 0))
	var coins := data.coin
	var cost := SaveManager.requestStatCost(stat)
	if useMouse(): await click(button)
	else:
		for step in DriverCard.STATS.size():
			var at := card.statButtons.find(button.get_viewport().gui_get_focus_owner())
			if at == row: break
			if at < 0:
				issue("ui", "no stat row has focus in the upgrade sheet; keys can't choose one (focus on %s, rows showing: %s, sheet at %.2f)" % [focusName(), button.is_visible_in_tree(), card.sheetAmount])
				return false
			await press("ui_down" if row > at else "ui_up")
			if card.statButtons.find(button.get_viewport().gui_get_focus_owner()) == at:
				issue("ui", "Up/Down didn't move between the upgrade rows (stuck on %s)" % DriverCard.STATS[at][0])
				return false
		await press("ui_accept")
	await think(0.2)
	if int(data.cars[index].upgrades.get(stat, 0)) != level + 1 || data.coin != coins - cost:
		issue("economy" if data.coin != coins else "block", "upgrading %s on %s: level %d -> %d, bank %d -> %d (cost %d)" % [
			DriverCard.STATS[row][0], data.cars[index].name, level, int(data.cars[index].upgrades.get(stat, 0)), coins, data.coin, cost])
		return false
	shopping.upgrades += 1
	shopping.upgrade_coins += cost
	note("CAREER_SHOP session=%d upgrade %s %s to %d for %d (bank %d)" % [session, data.cars[index].name, DriverCard.STATS[row][0], level + 1, cost, data.coin])
	return true

func openSetup() -> bool:
	var card: DriverCard = menu().cards[SaveManager.playerData.selectedCar]
	await activate(card.mainButton, "ui_accept")
	return await waitFor(func(): return menu() != null && menu().screen == SETUP && not Transition.busy(), 5.0, "Drive to open run setup")

func selectLevel(index: int) -> bool:
	var m := menu()
	var data := SaveManager.playerData
	for step in data.levels.size() + 2:
		if data.selectedLevel == index: return true
		var count := data.levels.size()
		var offset := wrapi(index - data.selectedLevel + count / 2, 0, count) - count / 2
		var before := data.selectedLevel
		var side: Control = m.posters[wrapi(before + signi(offset), 0, count)].get_node("catcher")
		if useMouse() && side.is_visible_in_tree(): await click(side)
		else: await press("ui_tab_next" if offset > 0 else "ui_tab_prev")
		if data.selectedLevel == before:
			issue("block", "run setup didn't move to the next level poster")
			return false
	return data.selectedLevel == index

func selectMode(mode: int) -> bool:
	var m := menu()
	for step in MODE_ORDER.size() + 1:
		if SaveManager.playerData.gameMode == mode: return true
		var before := SaveManager.playerData.gameMode
		if useMouse(): await click(m.medallions[MODE_ORDER.find(mode)].get_node("disc"))
		else:
			var at := MODE_ORDER.find(before)
			var target := MODE_ORDER.find(mode)
			await press("ui_right" if wrapi(target - at, 0, MODE_ORDER.size()) <= MODE_ORDER.size() / 2 else "ui_left")
		if SaveManager.playerData.gameMode == before:
			issue("block", "run setup didn't change the mode from %s" % Root.gameModeDescription[before].name)
			return false
	return SaveManager.playerData.gameMode == mode

## Run setup's tier chips (ModeTiers): a click on the chip, or Up / Down
func selectTier(tier: int) -> bool:
	var m := menu()
	for step in ModeTiers.TIERS.size() + 1:
		if SaveManager.getGameTier() == tier: return true
		var before := SaveManager.getGameTier()
		if useMouse(): await click(m.tierButtons[ModeTiers.TIERS.find(tier)])
		else: await press("ui_down" if tier > before else "ui_up")
		if SaveManager.getGameTier() == before:
			issue("block", "run setup didn't change the tier from %s" % ModeTiers.NAMES[before])
			return false
	return SaveManager.getGameTier() == tier

## Run setup's starting slots (main2.SLOTS): the gadget (Gadget, U / Y) and the boost (Boost, B / RS),
## each cycled until it shows `id`
func chooseSlot(slot: String, id: String, button: Button, action: String) -> void:
	var m := menu()
	for i in m.slotPrices(slot).size() + 1:
		if m.slotChoice(slot) == id: return
		await activate(button, action)
	if id != "": issue("ui", "the %s button never offered %s with %d gems" % [slot, id, SaveManager.playerData.gem])

func start(run: Dictionary, car: int, gadget: String, boost: String) -> bool:
	var m := menu()
	var data := SaveManager.playerData
	if m.startButton.disabled:
		issue("block", "START is disabled for %s %s (%s) though the mode rules say it is playable" % [
			Levels.ORDER[run.level], Root.gameModeDescription[run.mode].name, m.modeLock.text])
		return false
	var paid: int = Pickups.LOADOUT.get(m.slotPurchase("loadout"), 0) + Pickups.BOOST_LOADOUT.get(m.slotPurchase("boostLoadout"), 0)
	bankBefore = {"coin": data.coin, "gem": data.gem, "gadget_cost": paid} #what Start will take for the gadget and boost
	runPlan = {"level": run.level, "mode": run.mode, "tier": run.get("tier", ModeTiers.EASY), "car": car, "gadget": gadget, "boost": boost}
	runRow = {}
	runActive = true
	runTime = 0.0
	pauseAt = rng.randf_range(20.0, 120.0) if rng.randf() < persona.pause else INF
	abandonThisRun = rng.randf() < persona.abandon
	if abandonThisRun: pauseAt = minf(pauseAt, rng.randf_range(20.0, 90.0))
	note("CAREER_RUN session=%d %s %s %s %s gadget=%s boost=%s bank=%d gems=%d" % [session, Levels.ORDER[run.level], ModeTiers.NAMES[runPlan.tier], Root.gameModeDescription[run.mode].name,
		data.cars[car].name, gadget if gadget != "" else "-", boost if boost != "" else "-", data.coin, data.gem])
	await activate(m.startButton, "ui_accept")
	if not await waitFor(func(): return menu() == null || menu().loadingLevel, 5.0, "START to begin loading the run (focus on %s)" % focusName()):
		runActive = false
		return false
	if gadget != "": shopping.gadgets += 1
	if boost != "": shopping.boosts += 1
	if not await waitFor(func(): return is_instance_valid(Root.levelRoot) && Root.levelRoot.is_inside_tree() && Root.levelRoot.clockReady, 120.0, "the run to start after START"):
		runActive = false
		return false
	return true

#---------- the side trips ----------

## The screens around the runs: the Goonopedia (every tab), the records ticket, Settings (every tab,
## changing nothing). Each must open, take input and close, leaving the garage working.
func sideTrips() -> void:
	var m := menu()
	var trips := ["goonopedia", "records", "settings"]
	trips.shuffle()
	if persona.overlays < 1.0: trips = [trips[0]] if trips[0] != "settings" else ["goonopedia"]
	for trip in trips:
		match trip:
			"goonopedia":
				await press("ui_codex")
				if not await waitFor(func(): return menu().overlayOpen(), 3.0, "G to open the Goonopedia"): continue
				for tab in 6:
					for i in rng.randi_range(1, 4): await press("ui_down", 0.12)
					await press("ui_tab_next", 0.2)
				await press("ui_cancel")
				await waitFor(func(): return not menu().overlayOpen(), 3.0, "Back to close the Goonopedia")
			"records":
				await press("ui_records")
				if not await waitFor(func(): return menu().overlayOpen(), 3.0, "R to open the records"): continue
				await think(0.8)
				await press("ui_accept")
				await waitFor(func(): return not menu().overlayOpen(), 4.0, "a press to close the records ticket")
			"settings":
				await press("ui_menu")
				if not await waitFor(func(): return Settings.menu_open, 3.0, "Esc to open Settings"): continue
				for tab in 6:
					for i in rng.randi_range(0, 3): await press("ui_down", 0.12)
					await press("ui_tab_next", 0.2)
				await press("ui_cancel")
				await waitFor(func(): return not Settings.menu_open, 3.0, "Back to close Settings")
		await think(0.3)
		note("CAREER_TRIP session=%d %s" % [session, trip])
		if menu() != null && menu().get_viewport().gui_get_focus_owner() == null:
			issue("ui", "nothing has focus in the %s after closing %s; keys and pads lose their place" % ["garage" if menu().screen == GARAGE else "run setup", trip])

#---------- the run ----------

func playRun() -> bool:
	var lastFrame := Engine.get_process_frames()
	while runActive:
		await get_tree().process_frame
		if not is_instance_valid(Root.levelRoot):
			issue("block", "the level went away during the run")
			return false
		if Root.levelRoot.hasEnded:
			if standalone: runRow = standaloneRow()
			break
		if stopped: return false
		if not get_tree().paused: runTime += get_process_delta_time()
		if handling: continue
		if get_tree().paused:
			var screen := pausingScreen()
			if screen != null:
				pausedEmptySince = -1
				handling = true
				await answer(screen)
				handling = false
			elif not get_tree().get_nodes_in_group("pauseMenu").is_empty():
				#a pause the persona didn't ask for (the window lost focus): carry on
				handling = true
				await think(1.0)
				await press("ui_menu")
				handling = false
			else:
				if pausedEmptySince < 0: pausedEmptySince = Time.get_ticks_msec()
				elif Time.get_ticks_msec() - pausedEmptySince > SOFTLOCK_MS && not countdownShowing():
					issue("softlock", "the run was paused with no menu open for %d s; unpausing" % (SOFTLOCK_MS / 1000))
					pausedEmptySince = -1
					get_tree().paused = false
			continue
		pausedEmptySince = -1
		if runTime >= pauseAt && Root.levelRoot.clockReady:
			pauseAt = INF
			handling = true
			await pauseRun()
			handling = false
	return await waitFor(func(): return summary() != null, 15.0, "the results ticket after the run ended")

func countdownShowing() -> bool:
	if not is_instance_valid(Root.playerCar): return false
	for child in Root.playerCar.get_children():
		if child.scene_file_path == "res://scene/player/countdown.tscn": return true
	return false

func pausingScreen() -> Node:
	for node in get_tree().get_nodes_in_group("slotMachine"):
		if is_instance_valid(node) && not node.is_queued_for_deletion(): return node
	return null

func answer(screen: Node) -> void:
	var name := "an unknown screen"
	if screen is SlotMachine: name = "Slot Machine"
	elif screen is PickupDeal: name = "The Deal"
	elif screen is ClawCrane: name = "Claw Crane"
	elif screen is PitShop: name = "Pit Shop"
	elif screen is HubcapShuffle: name = "Hubcap Shuffle"
	elif screen is GoonPress: name = "Goon Press"
	elif screen is PachinkoDrop: name = "Pachinko Drop"
	elif screen is CoinPusher: name = "Coin Pusher"
	note("CAREER_SCREEN session=%d t=%.0f %s" % [session, runTime, name])
	if screen is SlotMachine: await answerSlots(screen)
	elif screen is PickupDeal: await answerDeal(screen)
	elif screen is ClawCrane: await answerClaw(screen)
	elif screen is PitShop: await answerPit(screen)
	elif screen is PickupMenu: await answerTapping(screen, name)
	else: issue("ui", "an unknown screen in group slotMachine: %s" % screen.name)
	if not await waitFor(func(): return screen.is_queued_for_deletion(), 12.0, "the %s to close" % name, screen):
		if is_instance_valid(screen): screen.queue_free() #the harness takes it away so the run can go on
		get_tree().paused = false

## Every prize game ends on its winnings board: the action key (or a click on it) leaves.
func leaveBoard(game: PickupMenu, name: String) -> void:
	if not await waitFor(func(): return game.boardUp, 6.0, "%s's winnings board" % name, game): return
	if not is_instance_valid(game): return
	await think(0.5)
	if useMouse(): await click(game.board)
	else: await press(PickupMenu.ACT)

func answerSlots(machine: SlotMachine) -> void:
	var car := Root.playerCar
	await think(PickupMenu.ARM_SECONDS + 0.4)
	var bet := Personas.slotBet(persona, car.coin, rng)
	for i in SlotSymbols.BETS.size():
		if SlotSymbols.bet >= bet || machine.betPaid: break
		await press("TurnRight", 0.3)
	for reel in 3:
		if not is_instance_valid(machine) || machine.phase != "spin": break
		await press(PickupMenu.ACT, 0.4)
	if not await waitFor(func(): return machine.phase == "stopped", 6.0, "the slot machine's reels to stop", machine): return
	if not is_instance_valid(machine): return
	await press(PickupMenu.ACT) #collect
	await leaveBoard(machine, "the slot machine")

func answerDeal(deal: PickupDeal) -> void:
	var car := Root.playerCar
	await think(PickupMenu.ARM_SECONDS + 0.6)
	while deal.canRedraw() && not Personas.dealKeep(persona, deal.hand, deal.cards, rng):
		var hand := deal.hand
		await press(PickupMenu.REJECT, 0.7) #the next card flips over
		if not is_instance_valid(deal): return
		if deal.hand == hand:
			issue("ui", "Redraw in The Deal did nothing")
			break
	var id: String = deal.hand
	var before := int(car.pickedById.get(id, 0))
	await press(PickupMenu.ACT)
	await think(0.3)
	if is_instance_valid(car) && int(car.pickedById.get(id, 0)) <= before && Pickups.has(id):
		issue("economy", "The Deal's %s was kept but not collected" % id)
	await leaveBoard(deal, "The Deal")

func answerClaw(crane: ClawCrane) -> void:
	await think(PickupMenu.ARM_SECONDS + 0.3)
	var extra: bool = persona.runs == "coverage" && Root.playerCar.coin >= ClawCrane.EXTRA_GRAB + 200
	for grab in 4: #a gift box's claw can have up to 3 free grabs
		#the claw runs back and forth by itself: drop as it passes over the prize the persona wants
		var target := Personas.clawTarget(persona, crane.prizes, crane.tipX(), rng)
		if target >= 0:
			var prize: Dictionary = crane.prizes[target]
			await waitFor(func(): return crane.phase == "patrol" && absf(crane.tipX() - prize.pos.x) < 12.0, 10.0, "the claw to pass over its prize", crane)
			if not is_instance_valid(crane): return
		await press(PickupMenu.ACT, 0.1)
		if not await waitFor(func(): return crane.boardUp || crane.phase == "done" || (crane.phase == "patrol" && crane.grabs > 0), 10.0, "the claw to come back", crane): return
		if not is_instance_valid(crane) || crane.boardUp: break
		if crane.grabs > 0: continue #free grabs left
		if grab >= 1 || not extra: break
		await press(PickupMenu.REJECT, 0.3) #another grab for run coins
		if crane.grabs == 0: break
	if is_instance_valid(crane) && not crane.boardUp: await press(PickupMenu.ACT) #collect
	if is_instance_valid(crane): await leaveBoard(crane, "the Claw Crane")

## A game with no plan of its own yet (the drafts): tap the action key every 0.4 s until its board is up
func answerTapping(game: PickupMenu, name: String) -> void:
	await think(PickupMenu.ARM_SECONDS + 0.4)
	var started := Time.get_ticks_msec()
	while is_instance_valid(game) && not game.boardUp && Time.get_ticks_msec() - started < 40000:
		await press(PickupMenu.ACT, 0.4)
	if is_instance_valid(game) && not game.boardUp: issue("ui", "%s never reached its winnings board" % name)
	await leaveBoard(game, name)

func answerPit(shop: PitShop) -> void:
	await think(PickupMenu.ARM_SECONDS + 0.3)
	var prices := shop.offers.map(func(id): return shop.price(id) if id != "" else 0)
	var wanted := Personas.pitBuys(persona, shop.offers, prices, PickupMenu.runCoins())
	while shop.next in wanted && shop.canBuy(): #the shop sells in order: stop at the first one not wanted
		var at := shop.next
		if useMouse(): await clickStage(shop, shop.rowRect(at).get_center())
		else: await press(PickupMenu.ACT, 0.3)
		if shop.next == at:
			issue("ui", "the Pit Shop didn't sell %s" % shop.offers[at])
			break
	if useMouse(): await clickStage(shop, PitShop.LEAVE.get_center())
	else: await press(PickupMenu.REJECT)

## Clicks a point on a prize game's stage
func clickStage(game: PickupMenu, at: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	game.stageInput(press)
	await think(0.3)

func pauseRun() -> void:
	await press("ui_menu", 0.5)
	if not await waitFor(func(): return not get_tree().get_nodes_in_group("pauseMenu").is_empty() || get_tree().paused, 3.0, "Esc to pause the run"): return
	var pause := get_tree().get_nodes_in_group("pauseMenu")
	if pause.is_empty():
		issue("ui", "Esc paused the run but no pause menu is showing")
		return
	var card: Node = pause[0]
	note("CAREER_PAUSE session=%d t=%.0f abandon=%s" % [session, runTime, abandonThisRun])
	await think(0.6)
	if abandonThisRun:
		for i in 3: #with Confirm Abandon on, the first press arms it
			if Root.levelRoot.hasEnded: break
			if useMouse(): await click(card.abandonButton)
			else:
				for step in 4:
					if card.abandonButton.has_focus(): break
					await press("ui_down", 0.15)
				await press("ui_accept", 0.4)
		if not Root.levelRoot.hasEnded: issue("ui", "Abandon run didn't end the run")
		return
	if persona.overlays >= 1.0 && rng.randf() < 0.5: #Settings from the pause menu: the row under Continue
		await press("ui_down", 0.2)
		await press("ui_accept", 0.4)
		if await waitFor(func(): return Settings.menu_open, 3.0, "Settings to open from the pause menu"):
			await press("ui_tab_next", 0.3)
			await press("ui_cancel", 0.4)
			await waitFor(func(): return not Settings.menu_open, 3.0, "Back to close Settings over the pause menu")
	await press("ui_menu")
	await waitFor(func(): return not get_tree().paused || not get_tree().get_nodes_in_group("slotMachine").is_empty(), 4.0, "Esc to continue the run")

#---------- the results ----------

func summary() -> Node:
	if not is_instance_valid(Root.levelRoot): return null
	for child in Root.levelRoot.get_children():
		if "isGameSummary" in child && child.isGameSummary: return child
	return null

func readResults() -> bool:
	var ticket := summary()
	if not await waitFor(func(): return not runRow.is_empty(), 10.0, "the playtest to record the run"): return false
	await think(0.7)
	await press("ui_accept") #speeds the count up
	if not await waitFor(func(): return ticket.summaryComplete, 20.0, "the results ticket to finish counting", ticket): return false
	await think(0.4)
	if is_instance_valid(ticket):
		if useMouse() && is_instance_valid(ticket.continueButton) && ticket.continueButton.is_visible_in_tree(): await click(ticket.continueButton)
		else: await press("ui_accept")
	if not await waitFor(menuReady, 30.0, "Continue on the results to reach the garage"): return false
	runActive = false
	checkRun()
	return true

## The checks after each run: the bank grew by the payout, gems by the run's gems less the gadget, a win
## marked the mode beaten (and with enough beaten, opened the next level), and the save on disk matches.
func checkRun() -> void:
	var data := SaveManager.playerData
	var row := runRow
	var level: int = runPlan.level
	var paid := int(row.get("payout", 0)) + int(row.get("first_clear", 0))
	if data.coin - bankBefore.coin != paid:
		issue("economy", "the bank went %d -> %d after a run that paid %d" % [bankBefore.coin, data.coin, paid])
	var gems := int(row.get("gem", 0)) + int(row.get("first_clear_gem", 0))
	if data.gem - bankBefore.gem != gems - bankBefore.gadget_cost:
		issue("economy", "gems went %d -> %d after a run that ended with %d gems (gadget %d)" % [bankBefore.gem, data.gem, gems, bankBefore.gadget_cost])
	if row.get("won", false):
		if not data.levels[level].gamemodeBeat.get(runPlan.mode, false): issue("progress", "a won %s on %s isn't marked beaten" % [row.mode, Levels.ORDER[level]])
		if level + 1 < data.levels.size() && not data.levels[level + 1].unlocked && Root.opensNextLevel(data.levels[level]):
			issue("progress", "%d modes beaten on %s didn't open the next level" % [Root.modesBeaten(data.levels[level]), Levels.ORDER[level]])
	if data.coin < 0 || data.gem < 0: issue("economy", "the bank is negative: %d coins, %d gems" % [data.coin, data.gem])
	SaveManager.flush()
	var disk = ResourceLoader.load(SaveManager.save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not disk is PlayerData: issue("save", "the save file doesn't load back")
	elif var_to_str([disk.coin, disk.gem, disk.cars, disk.levels]) != var_to_str([data.coin, data.gem, data.cars, data.levels]):
		issue("save", "the save on disk differs from the one in memory after the results")
	history.push_back({"session": session, "car": row.car, "level_index": level, "level": row.level, "mode_id": runPlan.mode, "mode": row.mode, "tier": runPlan.get("tier", ModeTiers.EASY),
		"won": row.won, "reason": row.reason, "payout": paid, "level_time": float(row.level_time), "crushed": row.crushed, "gem": gems})

## Autopilot: the run's record from the car, as Playtest would write it (the fields the checks and history use)
func standaloneRow() -> Dictionary:
	var car := Root.playerCar
	var level = Root.levelRoot
	var data := SaveManager.playerData
	return {"car": data.cars[data.selectedCar].name, "level": String(Levels.ORDER[data.selectedLevel]), "mode": str(Root.gameModes.find_key(data.gameMode)).to_lower(),
		"reason": str(Root.endCondition.find_key(level.endReason)), "won": level.isWon(),
		"payout": level.runPayout(level.isWon()), "gem": car.gem, "crushed": car.currentGoonsCrushed,
		"first_clear": level.firstClear.coin, "first_clear_gem": level.firstClear.gem, "tier": ModeTiers.NAMES[level.tier].to_lower(),
		"level_time": snappedf(float(level.elapsed), 0.1), "persona": personaId, "session": session}

## Playtest calls this once a run is recorded (its row, as in results<tag>.csv).
func onRunRecorded(row: Dictionary) -> void:
	runRow = row
	row["persona"] = personaId
	row["session"] = session

#---------- milestones and the summary ----------

func snapshot() -> Dictionary:
	var data := SaveManager.playerData
	var beaten := {}
	for i in data.levels.size():
		for mode in data.levels[i].gamemodeBeat:
			if data.levels[i].gamemodeBeat[mode]: beaten["%s %s" % [data.levels[i].id, Root.gameModeDescription[mode].name]] = true
	return {"cars": data.cars.filter(func(c): return c.cost == 0).map(func(c): return c.name),
		"levels": data.levels.filter(func(l): return l.unlocked).map(func(l): return l.id), "beaten": beaten,
		"pickups": Pickups.DATA.keys().filter(Unlocks.isPickupOpen)}

func milestonesSince(before: Dictionary) -> void:
	var now := snapshot()
	var found := []
	for car in now.cars: if car not in before.cars: found.push_back("car " + car)
	for level in now.levels: if level not in before.levels: found.push_back("level " + level)
	for key in now.beaten: if not before.beaten.has(key): found.push_back("beat " + key)
	for id in now.pickups: if id not in before.pickups: found.push_back("pickup " + id)
	for what in found:
		milestones.push_back({"session": session, "minutes": snappedf(minutesPlayed(), 0.1), "what": what})
		note("CAREER_MILESTONE session=%d minutes=%.1f %s" % [session, minutesPlayed(), what])

func finish() -> void:
	var byMode := {}
	for r in history:
		var m: Dictionary = byMode.get_or_add(r.mode, {"runs": 0, "wins": 0, "payout": 0, "minutes": 0.0})
		m.runs += 1
		m.wins += 1 if r.won else 0
		m.payout += r.payout
		m.minutes += r.level_time / 60.0
	for mode in byMode: byMode[mode]["coins_per_minute"] = snappedf(byMode[mode].payout / maxf(byMode[mode].minutes, 0.01), 1.0)
	var longestDry := 0 #runs in a row with no milestone: where this player stalls
	var dry := 0
	var milestoneSessions := milestones.map(func(m): return m.session)
	for r in history:
		dry = 0 if r.session in milestoneSessions else dry + 1
		longestDry = maxi(longestDry, dry)
	var kinds := {}
	for i in issues: kinds[i.kind] = kinds.get(i.kind, 0) + 1
	var pace := {} #unlock pace: per kind of milestone (car, level, beat, pickup), how many and when
	for m in milestones:
		var p: Dictionary = pace.get_or_add(str(m.what).split(" ")[0], {"count": 0, "first_minute": m.minutes, "last_minute": m.minutes})
		p.count += 1
		p.last_minute = m.minutes
	var result := {"persona": personaId, "start": startName, "seed": firstSeed, "sessions": session, "runs": history.size(),
		"wins": history.filter(func(r): return r.won).size(), "minutes": snappedf(minutesPlayed(), 0.1),
		"progress_start": startProgress, "progress_end": CareerStart.progress(SaveManager.playerData),
		"milestones": milestones, "unlock_pace": pace, "longest_runs_without_progress": longestDry, "modes": byMode, "shopping": shopping,
		"issue_counts": kinds, "issues": issues, "script_errors": errors.summary()}
	var file := FileAccess.open("user://playtest/%s_summary.json" % tag, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	note("CAREER_SUMMARY " + JSON.stringify(result))
	var done := "%d runs, %d issues, %d script errors; files in %s" % [history.size(), issues.size(), errors.count(), ProjectSettings.globalize_path("user://playtest/")]
	print("CAREER_DONE " + done)
	logFile.close()
	if standalone:
		if finished.is_valid(): finished.call("Autopilot off after " + done)
		queue_free()
		return
	get_tree().quit(0)

#---------- input, as a player gives it ----------

## Presses and releases an action (KeyHint.fire: _input handlers, the GUI and polling all see it), then
## waits as a player would before the next press.
func press(action: String, after := 0.25) -> void:
	await holdForConsole()
	if stopped: return
	log_line("press %s" % action)
	KeyHint.fire(action)
	await think(after)

## Clicks a control with the mouse: a move over it, then the button down and up, pushed into its
## viewport. A click that lands on another control (something covering it) is an issue.
func click(control: Control, after := 0.25) -> void:
	await holdForConsole()
	if stopped: return
	if not is_instance_valid(control) || not control.is_visible_in_tree():
		issue("ui", "tried to click %s, which isn't showing" % (control.name if is_instance_valid(control) else "a freed control"))
		return
	var viewport := control.get_viewport()
	var at := control.get_global_transform_with_canvas() * (control.size / 2.0)
	log_line("click %s at %s" % [control.name if control.name != "" else control.get_class(), at])
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	injecting = true
	viewport.push_input(move, true)
	injecting = false
	await get_tree().process_frame
	var hovered := viewport.gui_get_hovered_control()
	if hovered != control && not control.is_ancestor_of(hovered):
		issue("mouse", "a click on %s (%s) lands on %s instead" % [control.name, control.get_path(), hovered.get_path() if hovered else "nothing"])
	for down in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = down
		button.position = at
		button.global_position = at
		injecting = true
		viewport.push_input(button, true)
		injecting = false
		await get_tree().process_frame
	await think(after)

## A button, pressed the persona's way: clicked, or with `action` when keys are in use (an empty action
## clicks it whatever the device).
func activate(button: Control, action: String) -> void:
	if not is_instance_valid(button): return
	if action == "" || useMouse(): await click(button)
	else: await press(action)

func focusName() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	return "nothing" if focused == null else (focused.text if focused is Button && focused.text != "" else str(focused.name))

func useMouse() -> bool:
	match persona.device:
		"mouse": return true
		"mixed": return rng.randf() < 0.4
	return false

## Autopilot: the console is open over the game (the persona's parent is the Console). The menus ignore input
## under it, so the persona waits for it to close rather than press keys into it.
func consoleOpen() -> bool:
	return standalone && get_parent() is CanvasLayer && get_parent().visible

func holdForConsole() -> void:
	while consoleOpen() && not stopped: await get_tree().process_frame

## A player's pause between actions, in game time (paused or not).
func think(seconds: float) -> void:
	if stopped: return
	await get_tree().create_timer(seconds * rng.randf_range(0.8, 1.3), true).timeout

## Waits until `condition` holds. After `seconds` of game time and as long in real time (a world can take
## a while to build on a busy machine) it gives up: an issue saying what never happened, unless `what` is "".
## A `watch` node that is freed meanwhile ends the wait as met, without calling the condition (whose
## captured node would be gone).
func waitFor(condition: Callable, seconds: float, what: String, watch = null) -> bool:
	var frames := 0
	var started := Time.get_ticks_msec()
	var watching := typeof(watch) == TYPE_OBJECT #a freed node compares equal to null, but is still an object
	while not (watching && not is_instance_valid(watch)) && not condition.call():
		if stopped: return false
		await get_tree().process_frame
		if consoleOpen(): #time with the console open doesn't count toward giving up
			frames = 0
			started = Time.get_ticks_msec()
			continue
		frames += 1
		if frames > seconds * 60.0 && Time.get_ticks_msec() - started > seconds * 1000.0:
			if what != "": issue("block", "waited %d s for %s" % [int(seconds), what])
			return false
	return true

#---------- the log ----------

func issue(kind: String, text: String) -> void:
	issues.push_back({"kind": kind, "session": session, "text": text, "where": where()})
	note("CAREER_ISSUE session=%d kind=%s %s [%s]" % [session, kind, text, where()])

## Where the persona is: the screen, for issue reports.
func where() -> String:
	if runActive && is_instance_valid(Root.levelRoot):
		return "run %s %s t=%.0f%s" % [Levels.ORDER[runPlan.level], Root.gameModeDescription[runPlan.mode].name, runTime, " paused" if get_tree().paused else ""]
	var m := menu()
	if m == null: return "scene %s" % (get_tree().current_scene.name if get_tree().current_scene else "-")
	return "garage%s" % (" upgrades" if m.upgrading else "") if m.screen == GARAGE else "run setup"

func note(text: String) -> void:
	print(text)
	log_line(text)
	if logFile: logFile.flush() #a killed career keeps its log

func log_line(text: String) -> void:
	if logFile: logFile.store_line("%8d %s" % [Engine.get_process_frames(), text])

## Script and engine errors while the career plays, counted by message, with where the persona was.
class ErrorCatcher extends Logger:
	var mutex := Mutex.new()
	var seen := {}
	var total := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		var text := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		mutex.lock()
		total += 1
		seen[text] = seen.get(text, 0) + 1
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void: pass

	func count() -> int:
		return total

	func summary() -> Array:
		mutex.lock()
		var out := []
		for text in seen: out.push_back({"error": text, "count": seen[text]})
		mutex.unlock()
		out.sort_custom(func(a, b): return a.count > b.count)
		return out
