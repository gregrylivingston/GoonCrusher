extends CanvasLayer

#Developer console (autoload `Console`). Debug builds only: in a release export it frees itself.
#  `  (backtick) opens and closes it; Esc closes; Up/Down walk the history; Tab completes a command.
#  `help` lists the commands for where you are (the menu or a run); `help menu`, `help run`, `help all`.
#  Several can be given on one line, separated by ';'.
#  `start <tier>` plays from further into the game (early, mid, late, maxed: CareerStart.TIERS) on a scratch
#  save, so the real save is untouched; `start real` goes back to it.
#  `autopilot [rookie | grinder | explorer]` hands the game to a persona (Personas; a random one if none is
#  named) from the menu or mid-run: menus, runs and results, on the save in use. Any key, pad button or
#  click takes control back.
#  At startup:  Godot_console.exe --path . -- --console="start late"   or   --console="unlock all;coins 50k"
#`unlock goons` (or `unlock all`) reveals every goon in the Goonopedia.
#Progress commands (unlock, lock, coins, gems, upgrades, save) change the real save, so back it up
#first. Run commands (heal, fuel, god, ai, give, win, lose, night, day) act on the current run.

const TOGGLE_KEY := KEY_QUOTELEFT
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const ECHO_COLOR := Color(0.6, 0.65, 0.7)

var panel: PanelContainer
var output: RichTextLabel
var input: LineEdit
var history: PackedStringArray = []
var historyIndex := 0
var previousFocus: Control
var godMode := false
var aiMode := false #the AI driver (scripts/ai/) drives every run's car until `ai off`
var commands := {} #name -> {"fn", "usage", "help", "group"}, in help order
var pilot: CareerPilot #the autopilot while a persona has the game
#which groups `help` shows where: the menu's (progress) and the run's; Console is always shown
const CONTEXT_GROUPS := {"menu": ["Start here", "Progress"], "run": ["Run"]}

func _ready():
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 129 #above the F3 overlay
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_physics_process(false)
	registerCommands()
	buildUi()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--console="): runStartup.call_deferred(arg.trim_prefix("--console=").trim_prefix("\"").trim_suffix("\""))

func runStartup(line: String) -> void:
	var result = execute(line)
	print("[console] > " + line + "\n" + result)
	say(result)

func _input(event):
	#a person's press takes the game back from the autopilot, except the console's own: opening it, typing in it
	#and clicking in it leave the persona playing (it waits for the console to close; autopilot off stops it)
	if is_instance_valid(pilot) && not pilot.stopped && not visible && isPersonPressing(event) \
			&& not (event is InputEventKey && event.physical_keycode == TOGGLE_KEY):
		stopAutopilot("You have control")
		return
	if not (event is InputEventKey) || not event.pressed || event.echo: return
	if event.physical_keycode == TOGGLE_KEY:
		toggle(not visible)
		get_viewport().set_input_as_handled()
	elif visible && event.keycode == KEY_ESCAPE:
		toggle(false)
		get_viewport().set_input_as_handled()

#god mode: health and fuel are topped up every tick (water and other instant wrecks still end the run).
#ai mode: a run's car without a driver gets one, so it carries on into the next run.
func _physics_process(_delta):
	if not is_instance_valid(Root.playerCar): return
	if aiMode && Root.playerCar.is_node_ready() && Root.playerCar.myController.driver == null:
		AIDriver.attach(Root.playerCar, {"debug":true})
	if not godMode: return
	Root.playerCar.health = 100.0
	Root.playerCar.fuel = 100.0

func toggle(open: bool) -> void:
	if open == visible: return
	visible = open
	if open:
		Settings.push_menu() #main2, the HUD, the pause menu and the car's controls ignore keys while it is open
		previousFocus = get_viewport().gui_get_focus_owner()
		input.grab_focus()
		input.edit()
	else:
		input.release_focus()
		Settings.pop_menu()
		if is_instance_valid(previousFocus) && previousFocus.is_visible_in_tree(): previousFocus.grab_focus()


#--- ui -------------------------------------------------------------------------------------

func buildUi() -> void:
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_bottom = 0.45
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	style.border_color = Color(0.3, 0.35, 0.4)
	style.border_width_bottom = 2
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box = VBoxContainer.new()
	panel.add_child(box)
	output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.scroll_following = true
	output.selection_enabled = true
	output.focus_mode = Control.FOCUS_NONE
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_override("normal_font", font)
	output.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(output)
	input = LineEdit.new()
	input.placeholder_text = "command (help, Tab completes, Esc closes)"
	input.keep_editing_on_text_submit = true
	input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", 18)
	input.text_submitted.connect(onSubmit)
	input.gui_input.connect(onInputKey)
	box.add_child(input)
	say("Dev console. help lists what works here (the menu or a run). start late plays from further in on a scratch save (start lists the tiers).", ECHO_COLOR)

func say(text: String, color := Color.WHITE) -> void:
	if text == "": return
	if text.begins_with("Error"): color = ERROR_COLOR
	output.push_color(color)
	output.add_text(text + "\n")
	output.pop()

func onSubmit(text: String) -> void:
	input.clear()
	if text.strip_edges() == "": return
	if history.is_empty() || history[-1] != text: history.push_back(text)
	historyIndex = history.size()
	say("> " + text, ECHO_COLOR)
	say(execute(text))

func onInputKey(event: InputEvent) -> void:
	if not (event is InputEventKey) || not event.pressed: return
	match event.keycode:
		KEY_UP: showHistory(historyIndex - 1)
		KEY_DOWN: showHistory(historyIndex + 1)
		KEY_TAB: complete()
		_: return
	input.accept_event()

func showHistory(index: int) -> void:
	if history.is_empty(): return
	historyIndex = clampi(index, 0, history.size())
	input.text = history[historyIndex] if historyIndex < history.size() else ""
	input.caret_column = input.text.length()

func complete() -> void:
	var typed = input.text.strip_edges().to_lower()
	var matches = commands.keys().filter(func(c): return c.begins_with(typed))
	if matches.size() == 1: input.text = matches[0] + " "
	elif matches.size() > 1: say("  ".join(matches), ECHO_COLOR)
	input.caret_column = input.text.length()


#--- commands -------------------------------------------------------------------------------

#runs one line (commands separated by ';') and returns what they printed. Tests call this directly.
func execute(line: String) -> String:
	var results = []
	for part in line.split(";", false):
		var words = Array(part.strip_edges().split(" ", false))
		if words.is_empty(): continue
		var cmd = words[0].to_lower()
		if not commands.has(cmd):
			results.push_back("Error: unknown command '%s'. Type help." % cmd)
			continue
		results.push_back(commands[cmd]["fn"].call(words.slice(1).map(func(w): return w.to_lower())))
	return "\n".join(results)

func add(cmd: String, fn: Callable, usage: String, help: String, group: String) -> void:
	commands[cmd] = {"fn": fn, "usage": usage, "help": help, "group": group}

func registerCommands() -> void:
	add("help", cmdHelp, "help [menu | run | all | command]", "the commands for where you are (the menu or a run), another set, or one explained", "Console")
	add("clear", cmdClear, "clear", "clear the console", "Console")
	add("autopilot", cmdAutopilot, "autopilot [rookie | grinder | explorer | off]", "a persona plays for you from here (a random one if none is named): it shops, picks runs, drives with its plan drawn, answers every screen. Any key, pad button or click takes control back (the console's own keys don't; it waits while the console is open). ailines hides its drawing. On the real save it backs the save up first", "Start here")
	add("ailines", cmdAiLines, "ailines [on | off]", "show or hide what AI drivers draw (autopilot and ai): the goal (yellow), the plan (green, red when it expects a hit) and the route round water (blue)", "Run")
	add("start", cmdStart, "start [fresh | early | mid | late | maxed | real] [fresh]", "play from further into the game on a scratch save (the real save is untouched); real goes back to it. A tier's save carries on between sessions; add fresh to rebuild it. Bare start lists the tiers", "Start here")
	add("unlock", cmdUnlock, "unlock cars [name...] | levels [id...] | region <n> | modes | goons | pickups [id...] | all", "cars: free every driver (or the named ones). levels: open every level (or the named ones: ids or 0-based indices, Levels.ORDER). region: open every level of region 1-6 (or its id) and the road up to it. modes: mark Countdown, Sprint and Marathon beaten on every level, which opens every mode. goons: reveal every goon in the Goonopedia. pickups: unlock every pickup (or the named ones, with the pickups above them in their tree)", "Progress")
	add("lock", cmdLock, "lock cars | levels [id...] | modes | goons | pickups | all", "undo unlock: cars back to their prices, levels, beaten modes, Goonopedia goons and pickups back to a new save's", "Progress")
	add("unlocks", cmdUnlocks, "unlocks", "the pickups waiting to be unlocked: price or play condition and progress, nearest first (Unlocks)", "Progress")
	add("coins", cmdCoins, "coins [amount | set amount]", "add coins to the bank (negative takes them away; 50k and 2m work)", "Progress")
	add("gems", cmdGems, "gems [amount | set amount]", "add gems to the bank", "Progress")
	add("upgrades", cmdUpgrades, "upgrades max | reset [all]", "the selected car's (or every car's) upgrades to the cap or to 0", "Progress")
	add("unfinished", cmdUnfinished, "unfinished on | off", "let Coming Soon modes (any in Root.MODE_AVAILABLE set to false) be started; this session only", "Progress")
	add("level", cmdLevel, "level [id | index]", "list the levels by region (Levels.ORDER), or select one for the menu and direct launches", "Progress")
	add("cars", cmdCars, "cars all | <car> [tier]", "car clears (meta.carClears): every car (all) or one clears every beaten mode on the selected level (all: on every level), on its best tier or the one named (easy, medium, hard)", "Progress")
	add("save", cmdSave, "save [backup | open | reset]", "show the save; back it up; open its folder; reset it (backs up first)", "Progress")
	add("heal", cmdHeal, "heal", "full health", "Run")
	add("fuel", cmdFuel, "fuel", "full fuel", "Run")
	add("god", cmdGod, "god [on | off]", "keep health and fuel full (water still wrecks the car)", "Run")
	add("ai", cmdAi, "ai [on | off]", "the AI drives this run and every run after, drawing its plan (green, red when it expects a hit), goal (yellow) and route (blue); docs/AI_DRIVER.md", "Run")
	add("give", cmdGive, "give <what> [amount]", "credit a pickup to the car: %s" % ", ".join(giveable()), "Run")
	add("pickup", cmdPickup, "pickup <id> [count]", "collect any pickup from Pickups.DATA (docs/PICKUPS.md), e.g. nitro, deal, claw, goldgoon", "Run")
	add("win", cmdWin, "win", "end the run as a success (beats the mode, as playing it would)", "Run")
	add("lose", cmdLose, "lose", "end the run as a wreck", "Run")
	add("handling", cmdHandling, "handling [name value | car stat value | reset]", "the driving numbers (CarHandling, docs/CAR_ART.md \"Handling\"): bare lists them with this car's turn rate, wheel and brakes; name value changes one for every car (the AI follows); car stat value sets this car's engine, steering, traction or weight for the run; reset puts every number back. Nothing is saved", "Run")
	add("night", cmdNight, "night", "turn night on now (the level's own cycle carries on)", "Run")
	add("day", cmdDay, "day", "turn day on now", "Run")

func cmdHelp(args: Array) -> String:
	var context := "run" if Root.isRunActive else "menu"
	var heading := "In %s. help %s, help all or help <command> for more." % ["a run" if context == "run" else "the menu", "menu" if context == "run" else "run"]
	if not args.is_empty():
		match args[0]:
			"menu", "run":
				context = args[0]
				heading = "Commands for the %s:" % args[0]
			"all":
				context = "all"
				heading = "Every command:"
			_:
				if not commands.has(args[0]): return "Error: unknown command '%s'" % args[0]
				return "%s\n  %s" % [commands[args[0]].usage, commands[args[0]].help]
	var groups: Array = ["Console"]
	if context == "all":
		for c in CONTEXT_GROUPS: groups.append_array(CONTEXT_GROUPS[c])
	else: groups.append_array(CONTEXT_GROUPS[context])
	var lines = [heading]
	for group in groups:
		lines.push_back("-- %s --" % group)
		for cmd in commands:
			if commands[cmd].group == group: lines.push_back("  %-45s %s" % [commands[cmd].usage, commands[cmd].help])
	return "\n".join(lines)

#--- start here: autopilot ------------------------------------------------------------------

func cmdAutopilot(args: Array) -> String:
	var running := is_instance_valid(pilot) && not pilot.stopped
	if not args.is_empty() && args[0] in ["off", "stop"]:
		if not running: return "Autopilot isn't on"
		stopAutopilot("Autopilot off")
		return "Autopilot off: you have control"
	if running: return "Error: %s is already at the wheel (autopilot off, or any key, stops it)" % pilot.persona.name
	var id: String = args[0] if not args.is_empty() else Personas.DATA.keys().pick_random()
	if not Personas.has(id): return "Error: unknown persona '%s' (have %s)" % [id, ", ".join(Personas.DATA.keys())]
	var note := ""
	if CareerStart.activeTier() == "": #it will spend the real save's coins: keep a copy
		note = backupSave()
		if note.begins_with("Error"): return note
		note = "\nOn your real save. " + note
	pilot = CareerPilot.new()
	var line := pilot.beginAutopilot(id)
	pilot.finished = func(text): say(text, ECHO_COLOR)
	add_child(pilot)
	toggle.call_deferred(false) #out of the way: the menus ignore input while the console is open
	return "Autopilot: %s. Any key, pad button or click takes control back; the console (backtick) doesn't. ailines off hides its lines.%s" % [line, note]

func cmdAiLines(args: Array) -> String:
	AIDriver.drawPlans = (args[0] in ["on", "1", "true"]) if not args.is_empty() else not AIDriver.drawPlans
	if is_instance_valid(Root.playerCar):
		var driver = Root.playerCar.get_node_or_null("AIDriver")
		if driver: driver.queue_redraw() #clears the lines at once when turned off
	return "AI lines " + ("on" if AIDriver.drawPlans else "off")

func stopAutopilot(message: String) -> void:
	if not is_instance_valid(pilot): return
	pilot.stop()
	say(message, ECHO_COLOR)
	print("[console] " + message)

#a person's own press (not the autopilot's input actions or the clicks it pushes in): key, pad button or click
func isPersonPressing(event: InputEvent) -> bool:
	if not event.is_pressed() || event.is_echo(): return false
	if event is InputEventKey || event is InputEventJoypadButton: return true
	return event is InputEventMouseButton && not pilot.injecting

#--- start here: play from a tier -----------------------------------------------------------

func cmdStart(args: Array) -> String:
	if args.is_empty():
		var lines = ["Playing %s. start <tier> [fresh] plays from there on a scratch save; start real goes back:" % ("the real save" if CareerStart.activeTier() == "" else "the %s save" % CareerStart.activeTier())]
		for tier in CareerStart.TIERS: lines.push_back("  %-7s %s" % [tier, CareerStart.TIER_TEXT[tier]])
		return "\n".join(lines)
	if Root.isRunActive: return "Error: leave the run first"
	var result: String
	if args[0] in ["real", "off", "back"]: result = CareerStart.useRealSave()
	else: result = CareerStart.useScratchSave(args[0], args.size() > 1 && args[1] == "fresh")
	if not result.begins_with("Error") && is_instance_valid(Root.mainMenu) && Root.mainMenu.is_inside_tree():
		get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn") #the garage rebuilt from the save now in use
	return result

func cmdClear(_args: Array) -> String:
	output.clear()
	return ""


#--- progress -------------------------------------------------------------------------------

func cmdUnlock(args: Array) -> String:
	if args.is_empty(): return "Error: " + commands.unlock.usage
	var result = setUnlocks(args[0], true, args.slice(1))
	if not result.begins_with("Error"): progressChanged()
	return result

func cmdLock(args: Array) -> String:
	if args.is_empty(): return "Error: " + commands.lock.usage
	var result = setUnlocks(args[0], false, args.slice(1))
	if not result.begins_with("Error"): progressChanged()
	return result

func setUnlocks(what: String, unlock: bool, names: Array) -> String:
	match what:
		"car", "cars", "driver", "drivers": return setCars(unlock, names)
		"level", "levels": return setLevels(unlock, names)
		"region", "regions": return setRegion(unlock, names)
		"mode", "modes": return setModes(unlock)
		"goon", "goons", "goonopedia": return setGoons(unlock)
		"pickup", "pickups": return setPickups(unlock, names)
		"all": return "\n".join([setCars(unlock, []), setLevels(unlock), setModes(unlock), setGoons(unlock), setPickups(unlock, [])])
	return "Error: unknown '%s' (cars, levels, modes, goons, pickups or all)" % what

#every pickup, or the named ones and the pickups above them in their tree (Unlocks); locking leaves the roots
func setPickups(unlock: bool, names: Array) -> String:
	for id in names:
		if not Pickups.has(id): return "Error: no pickup '%s'" % id
	var saved := Unlocks.saved()
	if not unlock:
		var count := saved.keys().filter(func(k): return str(k).begins_with("pickup:")).size()
		for key in saved.keys(): if str(key).begins_with("pickup:"): saved.erase(key)
		return "Pickups locked: %d back to a new save's (the tree roots)" % count
	var opened := 0
	for id in (names if not names.is_empty() else Pickups.DATA.keys()):
		var at: String = id
		while at != "":
			if not Unlocks.isPickupOpen(at):
				Unlocks.grant("pickup:" + at)
				opened += 1
			at = Pickups.def(at).get("parent", "")
	return "Pickups unlocked: %d" % opened

func cmdUnlocks(_args: Array) -> String:
	var waiting := []
	for id in Pickups.DATA:
		var s := Unlocks.state("pickup:" + id)
		if s != Unlocks.S.SHOWN && s != Unlocks.S.READY: continue
		var cost := Unlocks.pickupPrice(id)
		var p := Unlocks.progress("pickup:" + id)
		var line: String
		var done: float
		if not cost.is_empty():
			line = "%-18s %s%s" % [Pickups.displayName(id), Unlocks.priceText(cost), "  (affordable)" if Unlocks.canAfford("pickup:" + id) else ""]
			done = 2.0 if Unlocks.canAfford("pickup:" + id) else 1.0
		else:
			line = "%-18s %s  %d / %d" % [Pickups.displayName(id), p.get("text", "opens after the next run"), p.get("have", 1), p.get("need", 1)]
			done = float(p.get("have", 1)) / maxf(float(p.get("need", 1)), 1.0)
		waiting.push_back([done, line])
	waiting.sort_custom(func(a, b): return a[0] > b[0])
	var open := Pickups.DATA.keys().filter(Unlocks.isPickupOpen).size()
	var lines := ["Pickups open %d / %d%s. Waiting:" % [open, Pickups.DATA.size(), "  (all open: Unlocks.allOpen)" if Unlocks.allOpen else ""]]
	for w in waiting.slice(0, 12): lines.push_back("  " + w[1])
	return "\n".join(lines)

#every car, or the named ones, bought for nothing; locking puts the default prices back
func setCars(unlock: bool, names: Array) -> String:
	var defaults = {}
	for car in PlayerData.new().cars: defaults[car.name] = car.cost #gem prices stay on the save's entry
	for carName in names:
		if not defaults.has(carName): return "Error: no car '%s' (%s)" % [carName, ", ".join(defaults.keys())]
	var changed = []
	for car in SaveManager.playerData.cars:
		if not names.is_empty() && car.name not in names: continue
		var cost = 0 if unlock else defaults.get(car.name, car.cost)
		if car.cost != cost: changed.push_back(car.name)
		car.cost = cost
	return "Cars %s: %s" % ["unlocked" if unlock else "locked", ", ".join(changed) if changed else "none changed"]

#every level, or the named ones (ids or indices, Levels.resolve); locking puts a new save's unlocks back
func setLevels(unlock: bool, names: Array = []) -> String:
	var defaults = PlayerData.new().levels
	var levels = SaveManager.playerData.levels
	var only := []
	for levelName in names:
		var id := Levels.resolve(levelName)
		if id == &"": return "Error: unknown level '%s' (%s)" % [levelName, Levels.idsText()]
		only.push_back(Levels.indexOf(id))
	for i in levels.size():
		if not only.is_empty() && i not in only: continue
		levels[i].unlocked = unlock || (i < defaults.size() && defaults[i].unlocked)
	var open = levels.filter(func(l): return l.unlocked).size()
	return "Levels: %d of %d unlocked" % [open, levels.size()]

#the Goonopedia reveals a goon once it has been crushed (Goonopedia.isDiscovered), so unlocking counts
#every goon in Goons.DATA as crushed once, keeping real counts; locking empties the list like a new save
func setGoons(unlock: bool) -> String:
	var crushed: Dictionary = SaveManager.playerData.goonsCrushed
	if not unlock:
		crushed.clear()
		return "Goons: Goonopedia back to a new save's (none discovered)"
	for id in Goons.DATA: crushed[String(id)] = maxi(crushed.get(String(id), 0), 1)
	return "Goons: all %d revealed in the Goonopedia" % Goons.DATA.size()

#Sprint and Countdown beaten opens every mode a level plays (Root.isModeUnlocked); locking clears every beaten mode
func setModes(unlock: bool) -> String:
	for level in SaveManager.playerData.levels:
		if unlock:
			for mode in Root.STAPLE_MODES: SaveManager.passTier(level, mode, ModeTiers.EASY)
		else:
			for mode in level.gamemodeBeat: level.gamemodeBeat[mode] = false
			if level.get("tiers") is Dictionary:
				for mode in level.tiers: level.tiers[mode] = ModeTiers.NONE
	if not unlock: return "Modes: every beaten mode cleared"
	var comingSoon = Root.MODE_AVAILABLE.keys().filter(func(m): return not Root.MODE_AVAILABLE[m])
	var note = "" if Root.devAllModesAvailable || comingSoon.is_empty() else " (Coming Soon modes stay hidden; see unfinished)"
	return "Modes: Sprint and Countdown marked beaten on every level, so every mode is open on unlocked levels" + note

#every level of a region (1-6 or its Territories id) and every level before it; locking closes the region's
#levels (the first level of the game stays open)
func setRegion(unlock: bool, names: Array) -> String:
	if names.is_empty(): return "Error: unlock region <1-6 | %s>" % " | ".join(Territories.ORDER)
	var region := regionArg(names[0])
	if region == &"": return "Error: unknown region '%s' (1-6 or %s)" % [names[0], ", ".join(Territories.ORDER)]
	var levels = SaveManager.playerData.levels
	var ids := Territories.levelsOf(region)
	for i in levels.size():
		var inRegion: bool = Levels.ORDER[i] in ids
		if unlock && (inRegion || i < Levels.indexOf(ids[0])): levels[i].unlocked = true
		elif not unlock && inRegion && i > 0: levels[i].unlocked = false
	return "Region %s: %s (%s)" % [Territories.displayName(region), "open, with the road up to it" if unlock else "locked", ", ".join(ids)]

#"3" or "raiders" -> &"raiders"; &"" when it names no region
static func regionArg(text: String) -> StringName:
	if text.is_valid_int() && int(text) >= 1 && int(text) <= Territories.ORDER.size(): return Territories.ORDER[int(text) - 1]
	return StringName(text) if Territories.has(StringName(text)) else &""

func cmdCoins(args: Array) -> String: return changeBank("coin", args)
func cmdGems(args: Array) -> String: return changeBank("gem", args)

func changeBank(field: String, args: Array) -> String:
	var label = "Coins" if field == "coin" else "Gems"
	var current: int = SaveManager.playerData[field]
	if args.is_empty(): return "%s: %d" % [label, current]
	var setTo = args[0] == "set"
	var amount = parseAmount(args[1] if setTo && args.size() > 1 else args[0])
	if amount == null: return "Error: " + commands[label.to_lower()].usage
	var delta = maxi(amount - current if setTo else amount, -current) #never below 0
	if field == "coin": SaveManager.addCoins(delta)
	else: SaveManager.addGems(delta)
	refreshMenu()
	return "%s: %d (%+d)" % [label, SaveManager.playerData[field], delta]

#"500", "-200", "50k", "2m"; null when it isn't a number
static func parseAmount(text: String):
	var multiplier = 1
	if text.ends_with("k"): multiplier = 1000
	elif text.ends_with("m"): multiplier = 1000000
	var number = text.trim_suffix("k") if multiplier == 1000 else text.trim_suffix("m") if multiplier == 1000000 else text
	if number.is_valid_int(): return int(number) * multiplier
	if number.is_valid_float(): return int(float(number) * multiplier)
	return null

func cmdUpgrades(args: Array) -> String:
	if args.is_empty() || args[0] not in ["max", "reset"]: return "Error: " + commands.upgrades.usage
	var level = SaveManager.MAX_UPGRADE_LEVEL if args[0] == "max" else 0
	var everyCar = args.size() > 1 && args[1] == "all"
	var cars = SaveManager.playerData.cars if everyCar else [SaveManager.playerData.cars[SaveManager.playerData.selectedCar]]
	var stats = [Root.upgrade.ENGINE, Root.upgrade.STEERING, Root.upgrade.TRACTION, Root.upgrade.ARMOR,
		Root.upgrade.HEADLIGHTS, Root.upgrade.OIL, Root.upgrade.CLOVER, Root.upgrade.LUCK]
	for car in cars:
		for stat in stats:
			if level > 0: car.upgrades[stat] = level
			else: car.upgrades.erase(stat)
	progressChanged()
	var who = "every car" if everyCar else cars[0].name
	var note = " (takes effect next run)" if Root.isRunActive else ""
	return "Upgrades for %s set to %d%s" % [who, level, note]

func cmdUnfinished(args: Array) -> String:
	if not args.is_empty(): Root.devAllModesAvailable = args[0] in ["on", "1", "true"]
	refreshMenu()
	return "Coming Soon modes are %s" % ("playable" if Root.devAllModesAvailable else "hidden")

func cmdLevel(args: Array) -> String:
	var data = SaveManager.playerData
	if args.is_empty():
		var lines = []
		for i in Levels.count():
			var def := Levels.defAt(i)
			if def && def.stop == 1: lines.push_back("-- %d %s (%s) --" % [Territories.indexOf(def.region) + 1, Territories.displayName(def.region), Goons.className(Territories.classOf(def.region))])
			lines.push_back("%s %2d %-4s %-12s %-16s %-11s %s%s" % [">" if i == data.selectedLevel else " ", i, Levels.stopText(i), Levels.ORDER[i], def.displayName if def else "?",
				def.landscape if def else "", "open" if data.levels[i].unlocked else "locked", "  finale" if def && def.isFinale() else ""])
		return "\n".join(lines)
	var id := Levels.resolve(args[0])
	if id == &"": return "Error: unknown level '%s' (%s)" % [args[0], Levels.idsText()]
	data.selectedLevel = Levels.indexOf(id)
	progressChanged()
	return "Level %d selected: %s" % [data.selectedLevel, id]

#car clears (SaveManager.creditCarClear): every car, or one, has won every beaten mode on the selected level
#(or everywhere with all), on its best tier there or the one named
func cmdCars(args: Array) -> String:
	if args.is_empty(): return "Error: " + commands.cars.usage
	var data = SaveManager.playerData
	var names := []
	for car in data.cars: names.push_back(str(car.name))
	var who: Array = names if args[0] == "all" else [args[0]]
	if args[0] != "all" && not args[0] in names: return "Error: no car '%s' (%s)" % [args[0], ", ".join(names)]
	var tier := ModeTiers.NAMES.map(func(n): return n.to_lower()).find(args[1]) if args.size() > 1 else -1
	if args.size() > 1 && tier < ModeTiers.EASY: return "Error: tier easy, medium or hard"
	var levels: Array = range(data.levels.size()) if args[0] == "all" else [data.selectedLevel]
	var count := 0
	for i in levels:
		for mode in Root.modePath(i):
			var best := ModeTiers.best(data.levels[i], mode)
			if best == ModeTiers.NONE: continue
			for car in who:
				if not SaveManager.creditCarClear(i, mode, tier if tier > 0 else best, car).tiers.is_empty(): count += 1
	progressChanged()
	return "Car clears: %d added for %s on %s" % [count, "every car" if args[0] == "all" else args[0], "every level" if args[0] == "all" else Levels.ORDER[data.selectedLevel]]

func cmdSave(args: Array) -> String:
	var data = SaveManager.playerData
	match args[0] if not args.is_empty() else "":
		"":
			var cars = data.cars.filter(func(c): return c.cost == 0).size()
			var levels = data.levels.filter(func(l): return l.unlocked).size()
			return "%s\n  coins %d, gems %d, cars %d/%d, levels %d/%d, version %d" % [
				ProjectSettings.globalize_path(SaveManager.save_path), data.coin, data.gem,
				cars, data.cars.size(), levels, data.levels.size(), data.saveVersion]
		"backup": return backupSave()
		"open":
			OS.shell_open(ProjectSettings.globalize_path("user://"))
			return "Opened " + ProjectSettings.globalize_path("user://")
		"reset":
			if Root.isRunActive: return "Error: leave the run first"
			var backup = backupSave()
			if backup.begins_with("Error"): return backup
			SaveManager.reset_save()
			if is_instance_valid(Root.mainMenu) && Root.mainMenu.is_node_ready(): Root.mainMenu.selectCar(SaveManager.playerData.selectedCar, false) #the card menu takes an index
			refreshMenu()
			return backup + "\nSave reset to a new game"
	return "Error: " + commands.save.usage

#copies the save next to itself with a timestamp; returns the message to show
func backupSave() -> String:
	SaveManager.dirty = true #write what is in memory first
	SaveManager.flush()
	var stamp = Time.get_datetime_string_from_system().replace(":", "-")
	var target = SaveManager.save_path.get_basename() + ".backup-" + stamp + ".tres"
	var err = DirAccess.copy_absolute(SaveManager.save_path, target)
	if err != OK: return "Error: backup failed (%s)" % error_string(err)
	return "Backed up to " + ProjectSettings.globalize_path(target)

#saves and redraws the menu after progress changed
func progressChanged() -> void:
	SaveManager.save_character_data()
	refreshMenu()

#redraws whichever main menu page is showing; nothing in a run
func refreshMenu() -> void:
	var menu = Root.mainMenu
	if not is_instance_valid(menu) || not menu.is_inside_tree() || not menu.is_node_ready(): return
	#the card menu (main2.gd, docs/UI.md): driver cards and the bank, and the level posters and mode
	#medallions when run setup is showing. Duck-typed, so a menu rewrite can't break progress commands.
	if menu.has_method("statUpdatesUiUpdate"): menu.statUpdatesUiUpdate()
	if "screen" in menu && "Screen" in menu && menu.screen == menu.Screen.SETUP && menu.has_method("refreshSetup"): menu.refreshSetup(false)


#--- run ------------------------------------------------------------------------------------

#the car of a run that is still going, or null
func runCar() -> OverheadCarBody2D:
	if not Root.isRunActive || not is_instance_valid(Root.playerCar) || not is_instance_valid(Root.levelRoot): return null
	return Root.playerCar

const NO_RUN := "Error: only in a run"

func cmdHeal(_args: Array) -> String:
	var car = runCar()
	if car == null: return NO_RUN
	car.reward("health", 100.0 - car.health)
	car.resetHealthWarning()
	return "Health full"

func cmdFuel(_args: Array) -> String:
	var car = runCar()
	if car == null: return NO_RUN
	car.reward("fuel", 100.0 - car.fuel)
	car.resetGasWarning()
	return "Fuel full"

func cmdHandling(args: Array) -> String:
	var h := CarHandling.tune
	if not args.is_empty() && args[0] == "reset":
		CarHandling.reset()
		return "Handling numbers back to their defaults"
	if not args.is_empty() && args[0] == "car":
		if args.size() < 3 || not args[1] in ["engine", "steering", "traction", "weight"]: return "Error: handling car engine | steering | traction | weight <value>"
		if not is_instance_valid(Root.playerCar): return "Error: no car (start a run)"
		Root.playerCar.set(args[1], int(args[2]))
		return "%s: %s %d for this run" % [Root.playerCar.carId, args[1], int(args[2])]
	if args.size() >= 2:
		for name in h.names():
			if name.to_lower() == args[0]:
				h.set(name, float(args[1]))
				return "%s = %s" % [name, h.get(name)]
		return "Error: no handling number '%s' (bare handling lists them)" % args[0]
	var lines := []
	for name in h.names(): lines.push_back("  %-16s %s" % [name, h.get(name)])
	var car = Root.playerCar
	if is_instance_valid(car):
		var w := CarHandling.weightShare(car.weight)
		var t: float = car.traction * car.conditionFactor("tires")
		lines.push_back("%s (engine %d, steering %d, traction %d, weight %d):" % [car.carId, car.engine, car.steering, car.traction, car.weight])
		lines.push_back("  turn rate %.2f / %.2f / %.2f / %.2f rad/s at 200 / 500 / 900 / 1400 px/s" % [car.yawLimit(200.0), car.yawLimit(500.0), car.yawLimit(900.0), car.yawLimit(1400.0)])
		lines.push_back("  full lock in %.2f s, brakes %.0f px/s², reverse %.0f px/s" % [1.0 / (car.steerRate() * Engine.physics_ticks_per_second), h.brakeDecel(t, w), h.reverseTop(car.engine * car.conditionFactor("engine"))])
	return "
".join(lines)

func cmdGod(args: Array) -> String:
	godMode = (args[0] in ["on", "1", "true"]) if not args.is_empty() else not godMode
	set_physics_process(godMode || aiMode)
	return "God mode " + ("on" if godMode else "off")

func cmdAi(args: Array) -> String:
	aiMode = (args[0] in ["on", "1", "true"]) if not args.is_empty() else not aiMode
	set_physics_process(godMode || aiMode)
	if not aiMode && is_instance_valid(Root.playerCar) && Root.playerCar.myController.driver != null:
		Root.playerCar.myController.driver.queue_free()
		Root.playerCar.myController.driver = null #the keys are the player's again
	return "AI driver " + ("on: it takes the wheel now and in every run until `ai off`" if aiMode else "off")

static func giveable() -> Array:
	return OverheadCarBody2D.UPGRADEABLE_STATS + ["coin", "gem", "star", "crushed", "health", "fuel"]

func cmdGive(args: Array) -> String:
	var car = runCar()
	if car == null: return NO_RUN
	if args.is_empty() || args[0] not in giveable(): return "Error: give <%s> [amount]" % " | ".join(giveable())
	var amount = parseAmount(args[1]) if args.size() > 1 else 1
	if amount == null: return "Error: '%s' is not a number" % args[1]
	var field = "currentGoonsCrushed" if args[0] == "crushed" else args[0]
	car.reward(field, amount) #crushed past a goal opens the free slot machine, as crushing would
	return "%s is now %s" % [args[0], str(car[field])]

func cmdPickup(args: Array) -> String:
	var car = runCar()
	if car == null: return NO_RUN
	if args.is_empty() || not Pickups.has(args[0]): return "Error: pickup <id> [count]; ids: %s" % ", ".join(Pickups.DATA.keys())
	var count = parseAmount(args[1]) if args.size() > 1 else 1
	if count == null: return "Error: '%s' is not a number" % args[1]
	for i in count: PickupEffects.collect(car, args[0], car.global_position, true) #locked ones too
	return "Collected %s x%d" % [Pickups.displayName(args[0]), count]

func cmdWin(_args: Array) -> String:
	if runCar() == null: return NO_RUN
	Root.levelRoot.endLevel(true, Root.endCondition.SUCCESS)
	toggle(false) #the summary takes the keys
	return "Run won"

func cmdLose(_args: Array) -> String:
	if runCar() == null: return NO_RUN
	Root.levelRoot.endLevel(false, Root.endCondition.NOHEALTH)
	toggle(false)
	return "Run lost"

func cmdNight(_args: Array) -> String: return setNight(true)
func cmdDay(_args: Array) -> String: return setNight(false)

func setNight(night: bool) -> String:
	if runCar() == null: return NO_RUN
	Root.levelRoot.isDaytime = not night
	Root.levelRoot.setNighttime(night)
	return "Night" if night else "Day"
