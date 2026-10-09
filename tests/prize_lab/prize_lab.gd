extends Node

#The prize lab (docs/PICKUPS.md, "Prize games"): play one prize game again and again without earning a box.
#Each scene in this folder sets `game`; open it and press F6 (Run Current Scene), or run
#`Godot --path . res://tests/prize_lab/claw.tscn`. It loads the level on a scratch save with every pickup
#open, keeps the car topped up and the clock away, and opens the game as soon as the run is under way.
#Keys (also listed in the lab panel):
#  R          play again now             1-5  box tier (Cardboard .. Diamond)
#  B          next play comes in a gift box (the whole reveal)
#  A          auto replay on / off       G    +1,000 run coins and +10 gems
#  C          clear the held gadget and boost
#  H          hold a Legendary gadget (to see a lesser prize sold)
#The panel lists what the car was actually credited by each play (from the car's `rewarded` signal and the
#change in coins, gems, stars and held items), so it can be checked against the winnings board.
#
#`-- --lab-shots` plays by itself (tapping Accelerate, as the playtest harness does), saves screenshots of
#each play just after it opens and on its winnings board to user://prize_lab/, and quits after SHOT_PLAYS.

@export_enum("claw", "slot", "wheel", "deal", "vault", "scratch", "pitshop") var game := "claw"
@export var level := "prairie"
@export_range(0, 4) var tier := 0

const SCRATCH_SAVE := "user://prize_lab/lab_save.tres"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://prize_lab")
	SaveManager.save_path = SCRATCH_SAVE #the real save is never touched
	Unlocks.allOpen = true
	var id := Levels.resolve(level)
	var data = SaveManager.playerData
	data.gameMode = Root.gameModes.GOONCRUSHER
	data.selectedLevel = maxi(Levels.indexOf(id), 0)
	Root.selectedCar = data.cars[data.selectedCar]
	Region.resetRegions()
	var driver := Driver.new()
	driver.game = game
	driver.tier = tier
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_node.call_deferred(RunView.wrap(load(Levels.scenePath(id)).instantiate()))

## Outlives the scene change: opens the game, keeps the run going and shows the lab panel.
class Driver extends CanvasLayer:
	const REPLAY_AFTER := 1.2 #seconds of driving between plays
	const SHOT_PLAYS := 2
	var game := "claw"
	var tier := 0
	var auto := true
	var viaBox := false
	var started := false
	var playing := false
	var idle := 0.0
	var plays := 0
	var before := {}
	var credited: Array = []
	var history: Array[String] = []
	var panel := Label.new()
	var shots := OS.get_cmdline_user_args().has("--lab-shots")
	var openT := 0.0
	var tapT := 0.0
	var shot := {}

	func _init() -> void:
		layer = 30
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _ready() -> void:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0.72), HudTheme.RIM, 10, 2, Vector4(14, 10, 14, 10)))
		box.position = Vector2(16, 120)
		box.custom_minimum_size = Vector2(330, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		panel.add_theme_font_override("font", HudTheme.BODY)
		panel.add_theme_font_size_override("font_size", 14)
		panel.add_theme_color_override("font_color", HudTheme.TEXT)
		panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.custom_minimum_size = Vector2(300, 0)
		box.add_child(panel)

	func car():
		return Root.playerCar if is_instance_valid(Root.playerCar) else null

	func _process(delta: float) -> void:
		var c = car()
		if c == null || not is_instance_valid(Root.levelRoot) || not c.is_node_ready():
			panel.text = "PRIZE LAB\nloading %s..." % game
			return
		if not started:
			if get_tree().paused: return #the start countdown
			started = true
			idle = -3.5 #let the run's opening banner pass
			c.rewarded.connect(onRewarded)
			c.coin += 2000
			c.gem += 20
		Root.levelRoot.seconds = 9999.0
		if not get_tree().paused:
			c.health = 100.0
			c.fuel = 100.0
		var open := gameOpen()
		if shots && playing: selfPlay(delta)
		if playing && not open && not get_tree().paused:
			playing = false
			report()
			if shots && plays >= SHOT_PLAYS: get_tree().quit()
		if not open && not get_tree().paused:
			idle += delta
			if auto && idle >= REPLAY_AFTER: play()
		else: idle = 0.0
		showPanel()

	#--lab-shots: tap Accelerate through the game and screenshot it open and on its board
	func selfPlay(delta: float) -> void:
		openT += delta
		var menus := get_tree().get_nodes_in_group("pickupMenu")
		var menu = menus[0] if not menus.is_empty() else null
		if openT > 1.4 && not shot.has("open"): capture("open")
		if menu != null && menu.boardUp && menu.boardT > 0.9 && not shot.has("board"): capture("board")
		if openT < 1.5 || (menu != null && menu.boardUp && not shot.has("board")): return
		tapT -= delta
		if tapT <= 0.0:
			tapT = 0.45
			KeyHint.fire("Accelerate")

	func capture(moment: String) -> void:
		shot[moment] = true
		var file := "user://prize_lab/%s_%d_%s.png" % [game, plays, moment]
		get_viewport().get_texture().get_image().save_png(file)
		print("PRIZE_LAB_SHOT " + ProjectSettings.globalize_path(file))

	func gameOpen() -> bool:
		if not get_tree().get_nodes_in_group("pickupMenu").is_empty(): return true
		if not get_tree().root.find_children("*", "GiftBox", true, false).is_empty(): return true
		return game == "scratch" && is_instance_valid(HudChance.current) && not HudChance.current.scratch.is_empty()

	func play() -> void:
		if gameOpen() || PickupMenu.runOver(): return
		idle = 0.0
		plays += 1
		before = snapshot()
		credited.clear()
		playing = true
		openT = 0.0
		shot.clear()
		if viaBox && game != "pitshop": GiftBox.open(game, tier)
		elif game == "pitshop": PitShop.open()
		else: CrushPrizes.openGame(game, tier)
		viaBox = false

	func snapshot() -> Dictionary:
		var c = car()
		return {"coin": c.coin, "gem": c.gem, "star": c.star, "held": "%s x%d" % [c.heldItem, c.heldCharges], "move": "%s x%d" % [c.moveItem, c.moveCharges], "buffs": c.buffs.keys()}

	func onRewarded(id: String, quantity) -> void:
		if playing: credited.push_back("%s x%s" % [id, str(quantity)])

	func report() -> void:
		var now := snapshot()
		var lines: Array[String] = ["#%d %s (%s)" % [plays, game.to_upper(), CrushPrizes.tierName(tier)]]
		for key in ["coin", "gem", "star"]:
			if now[key] != before[key]: lines.push_back("  %s %+d" % [key, now[key] - before[key]])
		for key in ["held", "move"]:
			if now[key] != before[key]: lines.push_back("  %s: %s -> %s" % [key, before[key], now[key]])
		for b in now.buffs:
			if b not in before.buffs: lines.push_back("  buff on: %s" % b)
		if not credited.is_empty(): lines.push_back("  credited: " + ", ".join(credited))
		if lines.size() == 1: lines.push_back("  nothing credited")
		for line in lines: print("PRIZE_LAB " + line)
		history = lines + history
		history.resize(mini(history.size(), 18))

	func showPanel() -> void:
		var c = car()
		var text := "PRIZE LAB  -  %s  -  %s box%s\n" % [CrushPrizes.gameName(game) if game != "pitshop" else "Pit Shop", CrushPrizes.tierName(tier), "  (next via gift box)" if viaBox else ""]
		text += "R play  1-5 tier  B gift box  A auto (%s)\nG +coins/gems  C clear held  H hold Legendary\n\n" % ("on" if auto else "off")
		text += "Coins %d   Gems %d   Stars %d\nE: %s x%d   Shift: %s x%d\n" % [c.coin, c.gem, c.star, c.heldItem if c.heldItem != "" else "-", c.heldCharges, c.moveItem if c.moveItem != "" else "-", c.moveCharges]
		if not c.buffs.is_empty(): text += "Buffs: %s\n" % ", ".join(c.buffs.keys())
		text += "\n" + "\n".join(history)
		panel.text = text

	func _input(event: InputEvent) -> void:
		if not started || not (event is InputEventKey) || not event.pressed || event.echo: return
		var c = car()
		match event.physical_keycode:
			KEY_R: play()
			KEY_A: auto = not auto
			KEY_B: viaBox = true
			KEY_G:
				c.coin += 1000
				c.gem += 10
			KEY_C:
				c.heldItem = ""
				c.heldCharges = 0
				c.moveItem = ""
				c.moveCharges = 0
			KEY_H:
				for id in Pickups.DATA:
					if Pickups.DATA[id].kind == Pickups.K.GADGET && Pickups.rarity(id) == Pickups.R.LEGENDARY:
						c.heldItem = id
						c.heldCharges = 1
						break
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: tier = event.physical_keycode - KEY_1
			_: return
		get_viewport().set_input_as_handled()
