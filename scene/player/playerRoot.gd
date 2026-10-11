class_name GameUI
extends CanvasLayer

#The in-run HUD. The widgets in scene/player/hud each read Root.playerCar and redraw only when their
#numbers change (see docs/HUD.md); this script owns the gift boxes, pausing and HUD Scale.

## The second player's HUD in a two-player run (CoopRun adds it): the guest's car on the dials, the same clock
## and goal, the coins they picked up on the right visor, and nothing of the save's (no payout, gift boxes or pause). It joins no group, so everything that
## looks for the HUD finds the player's.
var guest := false
var view: Viewport #the viewport this HUD's half of the world is drawn in, when that isn't its own (the guest's)
var host: Control  #with a frame (setFrame): the widgets' parent, laid over the frame and scaled to fit it
var plain: Control #...and HudChance's, over the same frame at full size

## The HUD a widget belongs to, or null (a widget built alone in a test)
static func of(node: Node) -> GameUI:
	while node != null && not node is GameUI: node = node.get_parent()
	return node as GameUI

## The car a widget shows: its HUD's (the guest's on the second player's HUD)
static func carOf(node: Node) -> OverheadCarBody2D:
	var ui := of(node)
	return Coop.guest if ui != null && ui.guest else Root.playerCar

## World to this widget's HUD: its HUD's own camera
static func canvasOf(node: CanvasItem) -> Transform2D:
	var ui := of(node)
	return ui.view.get_canvas_transform() if ui != null && is_instance_valid(ui.view) else node.get_viewport().get_canvas_transform()

## A widget by its name, wherever a frame has put it
func widget(widgetName: String) -> Node:
	return (host if host else self).get_node_or_null(widgetName)

## Lays the HUD over `rect` of the screen (a half, with two players) with every widget scaled by `fit`; an empty
## rect is the whole screen again. Anchors then mean the frame's corners and center.
func setFrame(rect: Rect2, fit := 1.0) -> void:
	if host == null:
		host = Control.new()
		host.name = "Frame"
		plain = Control.new()
		plain.name = "PlainFrame"
		for frame in [host, plain]:
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.clip_contents = true #a dial hangs off its corner: past the frame's edge is the other player's half
			add_child(frame)
		for control in hudControls: control.reparent(host, false)
		var chance = get_node_or_null("HudChance")
		if chance: chance.reparent(plain, false)
	if not rect.has_area(): rect = get_viewport().get_visible_rect()
	host.position = rect.position
	host.size = rect.size / fit
	host.scale = Vector2(fit, fit)
	plain.position = rect.position
	plain.size = rect.size
	applyHudScale()

func _ready():
	if not guest: Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$VersionTracker.text = Root.versionText()
	%ModeLabel.text = CoopRun.NAME if guest else Root.gameModeDescription[SaveManager.playerData.gameMode].name
	addMirror()
	addPickupWidgets()
	addInstrument()
	setupHudScale()
	var chance := HudChance.new() #toasts, the scratch card, beacons: over everything, not HUD-scaled
	chance.name = "HudChance"
	add_child(chance)
	if guest:
		for hidden in ["LeftVisor", "VersionTracker"]: get_node(hidden).visible = false
		return
	if is_instance_valid(Root.playerCar):
		updateStats()
	else: await get_tree().create_timer(1).timeout
	updateGoonsCrushed()
	updateStats()
	Root.playerRoot = self
	#behind the menu's loading shutter the level adds it once the door is up (Level.revealRun)
	if not Transition.holdsRunStart(): addCountdown()

#the run-start lamps: the rack drops in on its rail (resumes use a plain countdown.tscn, already down)
func addCountdown() -> void:
	var lamps = load("res://scene/player/countdown.tscn").instantiate()
	lamps.dropIn = true
	add_child(lamps)

func _process(_delta):
	if guest: return
	if Input.is_action_just_pressed("ui_menu"): openPause()
	if not get_tree().paused: checkGiftBox() #a box earned under a paused tree opens once it unpauses

#the only way to pause a run: Esc / Start, or losing focus.
#never opens over the slot machine, countdown or summary, which pause the tree themselves
func openPause() -> void:
	if get_tree().paused || Settings.menu_open || get_tree().get_nodes_in_group("pauseMenu").size() > 0: return
	get_tree().paused = true
	add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )

#car.reward() calls this when a stat changes; the dials' lamps show stats, so redraw them now
func updateStats():
	for dial in [widget("Tach"), widget("Speedo")]: dial.needle.queue_redraw()

#the held gadget and the timed power-up rings, along the bottom edge between the dials (hud_items.gd)
func addPickupWidgets() -> void:
	var items = HudItems.new()
	items.name = "Items"
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.anchor_left = 0.5
	items.anchor_right = 0.5
	items.anchor_top = 1.0
	items.anchor_bottom = 1.0
	items.offset_left = -300.0
	items.offset_right = 300.0
	items.offset_top = -80.0
	items.offset_bottom = -6.0
	add_child(items)

#the rear-view mirror behind the clock and the goal, which it lays out on its glass (hud_mirror.gd)
func addMirror() -> void:
	var mirror = HudMirror.new()
	mirror.name = "Mirror"
	mirror.anchor_left = 0.5
	mirror.anchor_right = 0.5
	mirror.offset_left = -HudMirror.SIZE.x * 0.5
	mirror.offset_right = HudMirror.SIZE.x * 0.5
	mirror.offset_bottom = HudMirror.STALK + HudMirror.SIZE.y
	add_child(mirror)
	move_child(mirror, 0) #under the clock and the goal

#the car's signature instrument, on the bottom edge just inside the tachometer's fuel arc (hud_instrument.gd); hidden on the house dash
func addInstrument() -> void:
	var instrument = HudInstrument.new()
	instrument.name = "Instrument"
	instrument.anchor_top = 1.0
	instrument.anchor_bottom = 1.0
	instrument.offset_left = HudInstrument.OFFSETS[0]
	instrument.offset_top = HudInstrument.OFFSETS[1]
	instrument.offset_right = HudInstrument.OFFSETS[2]
	instrument.offset_bottom = HudInstrument.OFFSETS[3]
	add_child(instrument)

#HUD Scale (Accessibility). Each authored HUD control is scaled about its point nearest its anchor,
#so corner widgets stay in their corners. Menus added at runtime (pause, slots, countdown, summary)
#are not scaled.
var hudControls: Array[Control] = []

func setupHudScale() -> void:
	for child in get_children():
		if child is Control:
			hudControls.push_back(child)
			child.set_meta("baseScale", child.scale)
			child.resized.connect(applyHudScale)
	Settings.changed.connect(onSettingChanged)
	applyHudScale()

func onSettingChanged(key: String, _value) -> void:
	if key == "access/hud_scale": applyHudScale()

func applyHudScale() -> void:
	var hudScale: float = Settings.get_value("access/hud_scale")
	var screen = host.size if host else get_viewport().get_visible_rect().size
	for control in hudControls:
		var anchor = Vector2((control.anchor_left + control.anchor_right) * 0.5 * screen.x, (control.anchor_top + control.anchor_bottom) * 0.5 * screen.y)
		control.pivot_offset = (anchor - control.position).clamp(Vector2.ZERO, control.size)
		control.scale = control.get_meta("baseScale") * hudScale

#Gift boxes (CrushPrizes, docs/PICKUPS.md): crushes earn crush XP (car.crushXp) toward the next box, which
#holds one unlocked prize game. Box `boxLevel + 1` opens at CrushPrizes.boxAt(boxLevel + 1) total XP, and
#leftover XP carries on. The left visor draws the ring (HudVisor).
var boxLevel := 0        #boxes opened this run
var boxStartXp := 0.0    #total XP where the current box's bar starts
var nextBoxXp: float = CrushPrizes.boxAt(1)

#called on every crush (car.reward); the box opens from _process, never over a paused tree
func updateGoonsCrushed():
	checkGiftBox()

func checkGiftBox() -> void:
	if Coop.active: return #a prize game stops the run for both players: none with two
	var car = Root.playerCar
	if not is_instance_valid(car) || car.isDestroyed || car.crushXp < nextBoxXp || get_tree().paused: return
	if not is_instance_valid(Root.levelRoot) || Root.levelRoot.get("hasEnded"): return
	boxLevel += 1
	boxStartXp = nextBoxXp
	nextBoxXp = CrushPrizes.boxAt(boxLevel + 1)
	var tier := CrushPrizes.tierFor(boxLevel)
	var id := CrushPrizes.pickGame(tier, randf(), CrushPrizes.openGames())
	flashWidget(widget("LeftVisor"))
	GiftBox.open(id, tier)

#a wave survived: the star it paid lands in its ring on the right visor, which flashes
func waveSurvived() -> void:
	flashWidget(widget("RightVisor"))
	Transition.sound("pop", -10.0)

func flashWidget(widget: Control) -> void:
	if not is_instance_valid(widget): return
	widget.flash = 0.0 if Settings.get_value("access/reduce_flashing") else 0.55
	var t = widget.create_tween()
	t.tween_property(widget, "flash", 0.0, 0.6)
