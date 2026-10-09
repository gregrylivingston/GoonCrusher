extends Node2D

#The prize lab (docs/PICKUPS.md, "Prize games"): one prize game on a plain background, again and again. No
#level, HUD, music or transitions: a hidden, switched-off car holds the run coins and takes the prizes (the
#real crediting code), and the game opens again a moment after each play. Each scene in this folder sets
#`game`; open it and press F6, or run `Godot --path . res://tests/prize_lab/claw.tscn`. Progress goes to a
#scratch save (user://prize_lab/), with every pickup open. Keys (also in the corner panel):
#  R          play again now             1-5  box tier (Cardboard .. Diamond)
#  A          auto replay on / off       G    +1,000 run coins and +10 gems
#  C          clear the held gadget and boost
#  H          hold a Legendary gadget (to see a lesser prize sold)
#The panel lists what the car was actually credited by each play (the car's `rewarded` signal and the change
#in coins, gems, stars and held items), to check against the winnings board.
#`-- --lab-shots` plays by itself (tapping Accelerate, as the playtest harness does), saves a screenshot of
#each play when it opens and on its winnings board to user://prize_lab/, and quits after SHOT_PLAYS.

@export_enum("claw", "slot", "wheel", "deal", "vault", "pitshop") var game := "claw"
@export_range(0, 4) var tier := 0

const SCRATCH_SAVE := "user://prize_lab/lab_save.tres"
const REPLAY_AFTER := 0.4
const SHOT_PLAYS := 2

var car: OverheadCarBody2D
var seconds := 999.0 #the run's clock, for the Stopwatch and Fast Forward (Root.levelRoot stands in for a Level)
var auto := true
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://prize_lab")
	SaveManager.save_path = SCRATCH_SAVE #the real save is never touched
	Unlocks.allOpen = true
	PickupMenu.lab = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	Audio.radio.process_mode = Node.PROCESS_MODE_DISABLED
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var fill := ColorRect.new()
	fill.color = Color(0.11, 0.1, 0.1)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.add_child(fill)
	var data = SaveManager.playerData
	Root.selectedCar = data.cars[data.selectedCar]
	car = load(Root.selectedCar.scene).instantiate()
	car.process_mode = Node.PROCESS_MODE_DISABLED #no driving, physics, engine or effects: a wallet for the prizes
	car.visible = false
	add_child(car)
	Root.playerCar = car
	Root.levelRoot = self
	car.get_node("AudioStream-Engine").stop()
	car.coin = 5000
	car.gem = 50
	car.rewarded.connect(onRewarded)
	var front := CanvasLayer.new()
	front.layer = 30
	add_child(front)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0.6), Color(HudTheme.RIM, 0.6), 10, 2, Vector4(14, 10, 14, 10)))
	box.position = Vector2(16, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(box)
	panel.add_theme_font_override("font", HudTheme.BODY)
	panel.add_theme_font_size_override("font_size", 14)
	panel.add_theme_color_override("font_color", HudTheme.TEXT)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(panel)
	play.call_deferred()

## A Level's blast (the Nuke and others): nothing to blow up here
func explode(_pos: Vector2) -> void: pass

func _exit_tree() -> void:
	PickupMenu.lab = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)

func _process(delta: float) -> void:
	var open := gameOpen()
	if shots && playing: selfPlay(delta)
	if playing && not open:
		playing = false
		report()
		if shots && plays >= SHOT_PLAYS: get_tree().quit()
	if not open:
		idle += delta
		if auto && idle >= REPLAY_AFTER: play()
	else: idle = 0.0
	showPanel()

func gameOpen() -> bool:
	return not get_tree().get_nodes_in_group("pickupMenu").is_empty()

func play() -> void:
	if gameOpen(): return
	idle = 0.0
	plays += 1
	before = snapshot()
	credited.clear()
	playing = true
	openT = 0.0
	shot.clear()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if game == "pitshop": PitShop.open()
	else: CrushPrizes.openGame(game, tier)

func snapshot() -> Dictionary:
	return {"coin": car.coin, "gem": car.gem, "star": car.star, "held": "%s x%d" % [car.heldItem, car.heldCharges], "move": "%s x%d" % [car.moveItem, car.moveCharges], "buffs": car.buffs.keys()}

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
	history.resize(mini(history.size(), 16))
	car.buffs.clear() #nothing ticks them down here

func showPanel() -> void:
	var title := CrushPrizes.gameName(game) if game != "pitshop" else "Pit Shop"
	var text := "PRIZE LAB  -  %s  -  %s box\n" % [title, CrushPrizes.tierName(tier)]
	text += "R play  1-5 tier  A auto (%s)\nG +coins/gems  C clear held  H hold Legendary\n\n" % ("on" if auto else "off")
	text += "Coins %d   Gems %d   Stars %d\nE: %s x%d   Shift: %s x%d\n" % [car.coin, car.gem, car.star, car.heldItem if car.heldItem != "" else "-", car.heldCharges, car.moveItem if car.moveItem != "" else "-", car.moveCharges]
	text += "\n" + "\n".join(history)
	panel.text = text

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) || not event.pressed || event.echo: return
	match event.physical_keycode:
		KEY_R: play()
		KEY_A: auto = not auto
		KEY_G:
			car.coin += 1000
			car.gem += 10
		KEY_C:
			car.heldItem = ""
			car.heldCharges = 0
			car.moveItem = ""
			car.moveCharges = 0
		KEY_H:
			for id in Pickups.DATA:
				if Pickups.DATA[id].kind == Pickups.K.GADGET && Pickups.rarity(id) == Pickups.R.LEGENDARY:
					car.heldItem = id
					car.heldCharges = 1
					break
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: tier = event.physical_keycode - KEY_1
		_: return
	get_viewport().set_input_as_handled()

#--lab-shots: tap Accelerate through the game and screenshot it open and on its board
func selfPlay(delta: float) -> void:
	openT += delta
	var menus := get_tree().get_nodes_in_group("pickupMenu")
	var menu = menus[0] if not menus.is_empty() else null
	if openT > 1.0 && not shot.has("open"): capture("open")
	if menu != null && menu.boardUp && menu.boardT > 0.9 && not shot.has("board"): capture("board")
	if menu != null && menu.get("phase") == "carry" && menu.get("t") > 0.3 && not shot.has("carry"): capture("carry") #the claw on its way
	if openT < 1.1 || (menu != null && menu.boardUp && not shot.has("board")): return
	tapT -= delta
	if tapT <= 0.0:
		tapT = 0.45
		KeyHint.fire("Accelerate")

func capture(moment: String) -> void:
	shot[moment] = true
	var file := "user://prize_lab/%s_%d_%s.png" % [game, plays, moment]
	get_viewport().get_texture().get_image().save_png(file)
	print("PRIZE_LAB_SHOT " + ProjectSettings.globalize_path(file))
