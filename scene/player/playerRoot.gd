class_name GameUI
extends CanvasLayer

#The in-run HUD. The widgets in scene/player/hud each read Root.playerCar and redraw only when their
#numbers change (see docs/HUD.md); this script owns the gift boxes, pausing and HUD Scale.

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$VersionTracker.text = Root.versionText()
	%ModeLabel.text = Root.gameModeDescription[SaveManager.playerData.gameMode].name
	addPickupWidgets()
	addNowPlaying()
	setupHudScale()
	add_child(HudChance.new()) #toasts, the scratch card, beacons: over everything, not HUD-scaled
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
	if Input.is_action_just_pressed("ui_menu"): openPause()
	if not get_tree().paused: checkGiftBox() #a box earned under a paused tree opens once it unpauses

#the only way to pause a run: Esc / Start, the HUD button, or losing focus.
#never opens over the slot machine, countdown or summary, which pause the tree themselves
func openPause() -> void:
	if get_tree().paused || Settings.menu_open || get_tree().get_nodes_in_group("pauseMenu").size() > 0: return
	get_tree().paused = true
	add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )

#car.reward() calls this when a stat changes; the systems strip shows stats, so redraw it now
func updateStats(): $Systems.queue_redraw()

#the held gadget and the timed power-up rings, above the systems strip (hud_items.gd)
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
	items.offset_top = -124.0
	items.offset_bottom = -50.0
	add_child(items)

#the radio's now-playing card, above the tachometer; shows for a few seconds at each song (docs/RADIO.md)
func addNowPlaying() -> void:
	var card = NowPlaying.new()
	card.name = "NowPlaying"
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = 32.0
	card.offset_right = 32.0 + NowPlaying.SIZE.x
	card.offset_top = -334.0
	card.offset_bottom = -334.0 + NowPlaying.SIZE.y
	add_child(card)

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
	var screen = get_viewport().get_visible_rect().size
	for control in hudControls:
		var anchor = Vector2((control.anchor_left + control.anchor_right) * 0.5 * screen.x, (control.anchor_top + control.anchor_bottom) * 0.5 * screen.y)
		control.pivot_offset = (anchor - control.position).clamp(Vector2.ZERO, control.size)
		control.scale = control.get_meta("baseScale") * hudScale

#Gift boxes (CrushPrizes, docs/PICKUPS.md): crushes earn crush XP (car.crushXp) toward the next box, which
#holds one unlocked prize game. Box `boxLevel + 1` opens at CrushPrizes.boxAt(boxLevel + 1) total XP, and
#leftover XP carries on. HudCrush draws the bar.
var boxLevel := 0        #boxes opened this run
var boxStartXp := 0.0    #total XP where the current box's bar starts
var nextBoxXp: float = CrushPrizes.boxAt(1)

#called on every crush (car.reward); the box opens from _process, never over a paused tree
func updateGoonsCrushed():
	checkGiftBox()

func checkGiftBox() -> void:
	var car = Root.playerCar
	if not is_instance_valid(car) || car.isDestroyed || car.crushXp < nextBoxXp || get_tree().paused: return
	if not is_instance_valid(Root.levelRoot) || Root.levelRoot.get("hasEnded"): return
	boxLevel += 1
	boxStartXp = nextBoxXp
	nextBoxXp = CrushPrizes.boxAt(boxLevel + 1)
	var tier := CrushPrizes.tierFor(boxLevel)
	var id := CrushPrizes.pickGame(tier, randf(), CrushPrizes.openGames())
	flashWidget($TopLeft/CrushPill)
	GiftBox.open(id, tier)

func updatePlayerRegion(tile) ->void:
	%RegionChip.updatePlayerRegion(tile)

#a wave survived in this region: the chip flashes and the star it paid flies to the star counter
func waveSurvived() -> void:
	flashWidget(%RegionChip)
	Transition.sound("pop", -10.0)
	var flyers = RewardFlyers.instance()
	if flyers: flyers.launch(HudTheme.STAR_ICON, Transform2D(0.0, Vector2(0.5, 0.5), 0.0, %RegionChip.get_global_transform_with_canvas() * Vector2(30, 27)), "starui")

#a new district: a road sign swings in with its name and the faction that holds it
func districtEntered(region: Dictionary) -> void:
	flashWidget(%RegionChip)
	RoadSign.post(str(region.get("name", "")), Goons.factionName(region.get("faction", 0)) + " turf")

func flashWidget(widget: Control) -> void:
	if not is_instance_valid(widget): return
	widget.flash = 0.0 if Settings.get_value("access/reduce_flashing") else 0.55
	var t = widget.create_tween()
	t.tween_property(widget, "flash", 0.0, 0.6)
