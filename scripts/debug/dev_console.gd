extends CanvasLayer

#Developer console (autoload `Console`). Debug builds only: in a release export it frees itself.
#  `  (backtick) opens and closes it; Esc closes; Up/Down walk the history; Tab completes a command.
#  `help` lists the commands; several can be given on one line, separated by ';'.
#  At startup:  Godot_console.exe --path . -- --console="unlock all;coins 50k"
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
	say("Dev console. Type help.", ECHO_COLOR)

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
	add("help", cmdHelp, "help [command]", "list the commands, or explain one", "Console")
	add("clear", cmdClear, "clear", "clear the console", "Console")
	add("unlock", cmdUnlock, "unlock cars [name...] | levels | modes | goons | all", "cars: free every driver (or the named ones). levels: open every level. modes: mark Countdown and Sprint beaten on every level, which opens every mode. goons: reveal every goon in the Goonopedia", "Progress")
	add("lock", cmdLock, "lock cars | levels | modes | goons | all", "undo unlock: cars back to their prices, levels, beaten modes and Goonopedia goons back to a new save's", "Progress")
	add("coins", cmdCoins, "coins [amount | set amount]", "add coins to the bank (negative takes them away; 50k and 2m work)", "Progress")
	add("gems", cmdGems, "gems [amount | set amount]", "add gems to the bank", "Progress")
	add("upgrades", cmdUpgrades, "upgrades max | reset [all]", "the selected car's (or every car's) upgrades to the cap or to 0", "Progress")
	add("unfinished", cmdUnfinished, "unfinished on | off", "let Coming Soon modes (any in Root.MODE_AVAILABLE set to false) be started; this session only", "Progress")
	add("save", cmdSave, "save [backup | open | reset]", "show the save; back it up; open its folder; reset it (backs up first)", "Progress")
	add("heal", cmdHeal, "heal", "full health", "Run")
	add("fuel", cmdFuel, "fuel", "full fuel", "Run")
	add("god", cmdGod, "god [on | off]", "keep health and fuel full (water still wrecks the car)", "Run")
	add("ai", cmdAi, "ai [on | off]", "the AI drives this run and every run after, drawing its plan (green, red when it expects a hit), goal (yellow) and route (blue); docs/AI_DRIVER.md", "Run")
	add("give", cmdGive, "give <what> [amount]", "credit a pickup to the car: %s" % ", ".join(giveable()), "Run")
	add("win", cmdWin, "win", "end the run as a success (beats the mode, as playing it would)", "Run")
	add("lose", cmdLose, "lose", "end the run as a wreck", "Run")
	add("night", cmdNight, "night", "turn night on now (the level's own cycle carries on)", "Run")
	add("day", cmdDay, "day", "turn day on now", "Run")

func cmdHelp(args: Array) -> String:
	if not args.is_empty():
		if not commands.has(args[0]): return "Error: unknown command '%s'" % args[0]
		return "%s\n  %s" % [commands[args[0]].usage, commands[args[0]].help]
	var lines = []
	var group = ""
	for cmd in commands:
		if commands[cmd].group != group:
			group = commands[cmd].group
			lines.push_back("-- %s --" % group)
		lines.push_back("  %-45s %s" % [commands[cmd].usage, commands[cmd].help])
	return "\n".join(lines)

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
		"level", "levels": return setLevels(unlock)
		"mode", "modes": return setModes(unlock)
		"goon", "goons", "goonopedia": return setGoons(unlock)
		"all": return "\n".join([setCars(unlock, []), setLevels(unlock), setModes(unlock), setGoons(unlock)])
	return "Error: unknown '%s' (cars, levels, modes, goons or all)" % what

#every car, or the named ones, bought for nothing; locking puts the default prices back
func setCars(unlock: bool, names: Array) -> String:
	var defaults = {}
	for car in PlayerData.new().cars: defaults[car.name] = car.cost
	for carName in names:
		if not defaults.has(carName): return "Error: no car '%s' (%s)" % [carName, ", ".join(defaults.keys())]
	var changed = []
	for car in SaveManager.playerData.cars:
		if not names.is_empty() && car.name not in names: continue
		var cost = 0 if unlock else defaults.get(car.name, car.cost)
		if car.cost != cost: changed.push_back(car.name)
		car.cost = cost
	return "Cars %s: %s" % ["unlocked" if unlock else "locked", ", ".join(changed) if changed else "none changed"]

func setLevels(unlock: bool) -> String:
	var defaults = PlayerData.new().levels
	var levels = SaveManager.playerData.levels
	for i in levels.size():
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

#Countdown and Sprint beaten opens every mode (Root.isModeUnlocked); locking clears every beaten mode
func setModes(unlock: bool) -> String:
	for level in SaveManager.playerData.levels:
		if unlock:
			level.gamemodeBeat[Root.gameModes.GOONCRUSHER] = true
			level.gamemodeBeat[Root.gameModes.SPRINT] = true
		else:
			for mode in level.gamemodeBeat: level.gamemodeBeat[mode] = false
	if not unlock: return "Modes: every beaten mode cleared"
	var comingSoon = Root.MODE_AVAILABLE.keys().filter(func(m): return not Root.MODE_AVAILABLE[m])
	var note = "" if Root.devAllModesAvailable || comingSoon.is_empty() else " (Coming Soon modes stay hidden; see unfinished)"
	return "Modes: Countdown and Sprint marked beaten on every level, so every mode is open on unlocked levels" + note

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
			if is_instance_valid(Root.mainMenu): Root.mainMenu.selectCar(SaveManager.playerData.cars[SaveManager.playerData.selectedCar])
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
	if not is_instance_valid(menu) || not menu.is_inside_tree(): return
	match menu.menuMode:
		menu.menuModes.RIDER: menu.disableLockedCars(Root.selectedCar)
		menu.menuModes.LEVEL: menu.setupLevel(SaveManager.playerData.levels[SaveManager.playerData.selectedLevel])
		menu.menuModes.GAMEMODE: menu.selectGameMode(SaveManager.getGameMode())
	menu.statUpdatesUiUpdate()


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
