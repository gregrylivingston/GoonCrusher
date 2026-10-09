class_name PickupMenu extends CanvasLayer

#The frame every pausing prize game is built on (docs/PICKUPS.md, "Prize games"): the Claw Crane, the Slot
#Machine, the Prize Wheel, The Deal, The Vault and the Pit Shop. One card in the menu theme (docs/UI.md) over
#a dimmed run, always the same size: a title and a subtitle, a STAGE-sized play area the game draws on (or
#fills with controls), one status line and a row of key hints. Every game ends on the same winnings board,
#which lists each prize and what it did (held on E, sold because a rarer one is held, +40 coins...).
#Prizes are credited the moment they are won (award), never from an animation; the board only shows them.
#
#Keys, the same in every game: the action key (ACT, E / X) does the game's main thing, WASD (Steer and
#Accelerate / Brake) moves or picks things, and REJECT (Q / Y) turns down, redraws or retries. The action
#key held when the game opens is ignored until it is released, so a gadget fired on the road can't play
#something by accident. Closing resumes the run through a
#quick 3-2-1 (resumeRun).

const STAGE := Vector2(640, 420)
const ARM_SECONDS := 0.2   #at least this long before a key counts, and the action key must be up
const ACT := "UseItem"     #E / X: the main action
const REJECT := "Horn"     #Q / Y: turn down, redraw, retry
const BOARD_ROWS := 6      #rows the winnings board shows; more are summed into the last
const ROW_STEP := 0.09     #seconds between rows appearing

## The prize lab (tests/prize_lab): the games open and close at once, with no hatch and no 3-2-1
static var lab := false

## Junk some games mix in with the prizes (the Claw's heap, the Coin Pusher's pile, the Goon Press's bombs):
## win it and it costs you. Never fatal. {name, icon, what it does}
const JUNK := {
	"junk:bomb": {"name": "Dud Bomb", "icon": "res://texture/icon/bomb.svg", "line": "-15 health"},
	"junk:leak": {"name": "Oil Leak", "icon": "res://texture/icon/oilslick.svg", "line": "-20 fuel"},
	"junk:pickpocket": {"name": "Pickpocket", "icon": "res://texture/icon/purse.svg", "line": "-50 run coins"},
}
const JUNK_TINT := Color(1.0, 0.55, 0.5)
static var junkTextures := {}

var root := Control.new()
var centre: CenterContainer
var card := PanelContainer.new()
var body := VBoxContainer.new()
var stage := Control.new()
var info := Label.new()
var hintRow: HBoxContainer
var armed := 0.0
var waitRelease := false
var closed := false
var shown := false         #past the queue (otherScreenUp) and on screen
var hatch: GameHatch #the skid in, the hatch and the peel out (docs/UI.md, "Transitions")
var hatchLabel := ""

var winnings: Array = []   #{key, icon, name, line, color, count}, in the order won
var board := Control.new()
var boardUp := false
var boardT := 0.0

func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	add_to_group("pickupMenu")
	#one game at a time: a pickup's game and a gift box landing together queue, and a game never opens
	#under the 3-2-1 (which would unpause the run beneath it)
	while not runOver() && otherScreenUp(): await get_tree().process_frame
	shown = true
	if runOver(): #opened (deferred) in the frame the run ended: never over the results ticket
		queue_free()
		return
	add_to_group("slotMachine") #the playtest and bench harnesses tap Accelerate through anything in it
	InputGlyphs.ensureMenuActions()
	waitRelease = InputMap.has_action(ACT) && Input.is_action_pressed(ACT)
	root.theme = MenuTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	centre = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	card.theme_type_variation = "CardPanel"
	centre.add_child(card)
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	stage.custom_minimum_size = STAGE
	stage.clip_contents = true
	stage.focus_mode = Control.FOCUS_NONE
	stage.draw.connect(drawStage)
	stage.gui_input.connect(stageInput)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.visible = false
	board.draw.connect(drawBoard)
	board.gui_input.connect(stageInput)
	info.theme_type_variation = "MutedLabel"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(STAGE.x, 26)
	info.clip_text = true
	hintRow = KeyHint.bar([], 15, 22)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	build()
	if stage.get_parent() == null: addStage()
	stage.add_child(board) #last, so it covers whatever the game put on the stage
	body.add_child(info)
	body.add_child(hintRow)
	if not lab:
		hatch = GameHatch.attach(self, centre, card, hatchLabel)
		hatch.enter(0.0)

## The game's setup: call title(), then fill the stage (addStage() is called for it if build doesn't).
func build() -> void: pass

func _process(delta: float) -> void:
	if closed || not shown: return
	armed += delta
	if waitRelease && not Input.is_action_pressed(ACT): waitRelease = false
	if boardUp:
		boardT += delta
		board.queue_redraw()
	if armed < ARM_SECONDS || waitRelease:
		tick(delta)
		stage.queue_redraw()
		return
	for action in [ACT, REJECT, "Accelerate", "Brake", "TurnLeft", "TurnRight", "ui_accept", "ui_cancel"]:
		if InputMap.has_action(action) && Input.is_action_just_pressed(action):
			if boardUp:
				if action in [ACT, "ui_accept", "ui_cancel"] && boardT > 0.25: close()
			else: onAction(action)
	tick(delta)
	stage.queue_redraw()

## Keys count now: armed, and nothing held over from before the game opened
func live() -> bool:
	return armed >= ARM_SECONDS && not waitRelease

## A key went down (after arming): ACT, REJECT, Accelerate (W), Brake (S), TurnLeft (A), TurnRight (D),
## ui_accept or ui_cancel. Games treat ui_accept like ACT.
func onAction(_action: String) -> void: pass
## Every frame, armed or not (the tree is paused, so this is the game's clock).
func tick(_delta: float) -> void: pass
## Draws the game on the stage (STAGE-sized, clipped).
func drawStage() -> void: pass
## A mouse event on the stage (not on a button in it), in stage coordinates.
func onStageMouse(_event: InputEvent) -> void: pass

func stageInput(event: InputEvent) -> void:
	if closed || armed < ARM_SECONDS: return
	if boardUp:
		if event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT && boardT > 0.25: close()
		return
	onStageMouse(event)

## True for a left click (press) on the stage
static func isClick(event: InputEvent) -> bool:
	return event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT

#---------- the frame ----------

## The title strip: the game's name and one line under it (always there, so every card is the same size).
func title(text: String, sub := "") -> void:
	if hatchLabel == "": hatchLabel = text.to_upper()
	var t = Label.new()
	t.text = text
	t.theme_type_variation = "TitleLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(t)
	var s = Label.new()
	s.text = sub
	s.theme_type_variation = "MutedLabel"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size = Vector2(STAGE.x, 0)
	body.add_child(s)

## Puts the stage under the title (build() may call it before adding controls to the stage).
func addStage() -> void:
	if stage.get_parent() == null: body.add_child(stage)

## Replaces the key hints: [[actions], label] pairs, as KeyHint.bar.
func hints(list: Array) -> void:
	for child in hintRow.get_children():
		hintRow.remove_child(child)
		child.queue_free()
	for h in list: hintRow.add_child(KeyHint.make(PackedStringArray(h[0]), h[1], 15, true))
	if list.is_empty(): #keep the row's height, so the card never changes size
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 30)
		hintRow.add_child(gap)

func say(text: String) -> void:
	info.text = text

## The run has ended (the results ticket is up or about to be): no pausing screen opens any more.
static func runOver() -> bool:
	return is_instance_valid(Root.levelRoot) && Root.levelRoot.get("hasEnded") == true

## Another prize game, a gift box or the countdown is showing
func otherScreenUp() -> bool:
	for menu in get_tree().get_nodes_in_group("pickupMenu"):
		if menu != self && menu.shown && not menu.closed: return true
	if not get_tree().root.find_children("*", "GiftBox", true, false).is_empty(): return true
	if is_instance_valid(Root.playerCar):
		for child in Root.playerCar.get_children():
			if child.scene_file_path == "res://scene/player/countdown.tscn": return true
	return false

static func runCoins() -> int:
	return Root.playerCar.coin if is_instance_valid(Root.playerCar) else 0

static func runGems() -> int:
	return Root.playerCar.gem if is_instance_valid(Root.playerCar) else 0

## Resumes a paused run through a quick 3-2-1 (or at once when there is no car).
static func resumeRun() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if lab || not is_instance_valid(Root.playerCar):
		tree.paused = false
		return
	var countdown = load("res://scene/player/countdown.tscn").instantiate()
	countdown.step = countdown.QUICK_STEP
	Root.playerCar.add_child(countdown)

## Leaves the game. `countdown`: resume through 3-2-1 (false when another pausing screen follows).
func close(countdown := true) -> void:
	if closed: return
	closed = true
	#another pausing screen follows at once (countdown false) only when this closes synchronously
	if countdown && is_instance_valid(hatch): await hatch.leave()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if countdown: resumeRun()
	else: get_tree().paused = false
	queue_free()

#---------- prizes ----------

## Credits pickup `id` (`times` over) now and lists it on the winnings board.
func award(id: String, times := 1) -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || times <= 0: return
	id = Pickups.openOr(id)
	var line := outcome(car, id, times)
	for i in times: PickupEffects.collect(car, id, car.global_position, true)
	note(id, Pickups.texture(id), Pickups.displayName(id), line, Pickups.rarityColor(Pickups.rarity(id)), times)

## Several pickups at once (the slot's reels): the rarest first, so a gadget only loses to a rarer one.
func awardAll(pays: Dictionary) -> void:
	var ids := pays.keys()
	ids.sort_custom(func(a, b): return Pickups.rarity(a) > Pickups.rarity(b))
	for id in ids: award(id, pays[id])

func awardCoins(amount: int) -> void:
	if not is_instance_valid(Root.playerCar) || amount <= 0: return
	Root.playerCar.reward("coin", amount)
	note("coin", HudTheme.COIN_ICON, "Coins", "+%d run coins" % amount, HudTheme.GOLD, amount)

func awardGems(amount: int) -> void:
	if not is_instance_valid(Root.playerCar) || amount <= 0: return
	Root.playerCar.reward("gem", amount)
	note("gem", HudTheme.GEM_ICON, "Gems", "+%d" % amount, Color("e83aa8"), amount)

static func isJunk(id: String) -> bool:
	return JUNK.has(id)

static func junkTexture(id: String) -> Texture2D:
	if not junkTextures.has(id): junkTextures[id] = load(JUNK[id].icon)
	return junkTextures[id]

## Junk was won: it costs now, and the board lists it
func awardJunk(id: String) -> void:
	var car = Root.playerCar
	if is_instance_valid(car):
		match id:
			"junk:bomb": car.health = maxf(1.0, car.health - 15.0)
			"junk:leak": car.fuel = maxf(0.0, car.fuel - 20.0)
			"junk:pickpocket": car.coin = maxi(0, car.coin - 50)
	note(id, junkTexture(id), JUNK[id].name, JUNK[id].line, HudTheme.BAD)
	Transition.sound("thud", -6.0, 0.8)

## Lists a prize (or a loss) that the game credited itself.
func note(key: String, icon: Texture2D, label: String, line: String, color: Color, count := 1) -> void:
	for w in winnings:
		if w.key == key && key != "":
			w.count += count
			w.line = line if key != "coin" && key != "gem" else "+%d" % w.count + (" run coins" if key == "coin" else "")
			return
	winnings.push_back({"key": key, "icon": icon, "name": label, "line": line, "color": color, "count": count})

## What collecting `id` will do for `car`, said before it is collected (PickupEffects.collect).
static func outcome(car, id: String, times := 1) -> String:
	var d := Pickups.def(id)
	var kind: int = d.get("kind", -1)
	if kind == Pickups.K.GADGET || kind == Pickups.K.MOVE:
		var slot := "moveItem" if kind == Pickups.K.MOVE else "heldItem"
		var key := InputGlyphs.label("UseMove" if kind == Pickups.K.MOVE else "UseItem")
		var held: String = car.get(slot) if car.get(slot) != null else ""
		var charges: int = d.get("charges", 1) * times
		if held == id: return "+%d %s  -  fire with %s" % [charges, "charge" if charges == 1 else "charges", key]
		if held == "" || Pickups.rarity(id) >= Pickups.rarity(held):
			return "Ready  -  fire with %s" % key + ("  (replaces %s)" % Pickups.shortName(held) if held != "" else "")
		return "Sold for %d coins: your %s is rarer" % [10 * (Pickups.rarity(id) + 1) * times, Pickups.shortName(held)]
	if kind == Pickups.K.BOOST && d.has("secs"): return "On now for %d s" % int(d.secs)
	var text: String = d.get("text", "")
	var stop := text.find(". ")
	return text.substr(0, stop + 1) if stop > 0 else text

## Turns the stage into the winnings board; the action key (or a click) then leaves.
func showWinnings(heading := "") -> void:
	if boardUp: return
	boardUp = true
	boardT = 0.0
	board.set_meta("heading", heading)
	board.visible = true
	board.mouse_filter = Control.MOUSE_FILTER_STOP #over any buttons the game put on the stage
	hints([[[ACT], "Back to the road"]])
	say("")
	Transition.sound("pop", -6.0, 1.1)

func drawBoard() -> void:
	var b := board
	var fade := clampf(boardT / 0.15, 0.0, 1.0)
	b.draw_rect(Rect2(Vector2.ZERO, STAGE), Color(0.035, 0.03, 0.027, 0.93 * fade))
	var heading: String = b.get_meta("heading", "")
	if heading == "": heading = "YOU WON" if not winnings.is_empty() else "NO PRIZE THIS TIME"
	HudTheme.text(b, Vector2(STAGE.x * 0.5, 50), heading, 34, Color(HudTheme.GOLD, fade), HORIZONTAL_ALIGNMENT_CENTER, 8)
	var rows := winnings.slice(0, BOARD_ROWS)
	var rowH := 56.0
	var top := 80.0 + (BOARD_ROWS - rows.size()) * rowH * 0.5
	for i in rows.size():
		var a := clampf((boardT - 0.12 - i * ROW_STEP) / 0.12, 0.0, 1.0)
		if a <= 0.0: break
		var w: Dictionary = rows[i]
		var y := top + i * rowH
		var x := 36.0 + (1.0 - a) * 30.0
		HudTheme.panel(b, Rect2(x, y, STAGE.x - 72.0, rowH - 8.0), Color(w.color, 0.55 * a), 10)
		if w.icon: HudTheme.icon(b, w.icon, Vector2(x + 30, y + 24), 40, Color(1, 1, 1, a))
		var label: String = w.name.to_upper() + ("  x%d" % w.count if w.count > 1 && w.key != "coin" && w.key != "gem" else "")
		if i == BOARD_ROWS - 1 && winnings.size() > BOARD_ROWS: label += "  +%d MORE" % (winnings.size() - BOARD_ROWS)
		HudTheme.text(b, Vector2(x + 62, y + 21), label, 19, Color(w.color, a), HORIZONTAL_ALIGNMENT_LEFT, 5)
		HudTheme.text(b, Vector2(x + 62, y + 41), w.line, 14, Color(HudTheme.TEXT, a), HORIZONTAL_ALIGNMENT_LEFT, 4, HudTheme.OUTLINE, HudTheme.BODY)
