class_name GameUI
extends CanvasLayer

#The in-run HUD. The widgets in scene/player/hud each read Root.playerCar and redraw only when their
#numbers change (see docs/HUD.md); this script owns the crush goals, pausing and HUD Scale.

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$VersionTracker.text = Root.versionText()
	%ModeLabel.text = Root.gameModeDescription[SaveManager.playerData.gameMode].name
	addPickupWidgets()
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

func addCountdown() -> void:
	add_child(load("res://scene/player/countdown.tscn").instantiate())

func _process(_delta):
	if Input.is_action_just_pressed("ui_menu"): openPause()
	if crushAwardPending && not get_tree().paused: #a goal reached while paused is granted on unpause
		crushAwardPending = false
		updateGoonsCrushed()

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

#crush goals: every goal reached pays a star and a free slot machine. HudCrush draws the goal.
var awardBase = 12
var crushingAwardLevel = 0
var nextCrushingAward: float = awardBase
var crushGoalStart: float = 0.0  #crushes when the current goal began; the goal's bar fills from here
var crushAwardPending := false   #a crush goal was reached while the tree was paused (e.g. a slot machine reward)

func updateGoonsCrushed():
	var crushed = Root.playerCar.currentGoonsCrushed
	if crushed >= nextCrushingAward && not Root.playerCar.isDestroyed && get_tree().paused:
		crushAwardPending = true #the slot machine can't open over a paused tree; _process grants it on unpause
	elif crushed >= nextCrushingAward && not Root.playerCar.isDestroyed:
		crushGoalStart = nextCrushingAward
		crushingAwardLevel += 1
		Root.playerCar.star += 1
		get_tree().paused = true
		if crushingAwardLevel % 2 == 0: #every other goal deals The Deal instead of the slot machine
			PickupDeal.open(true)
			return
		var newMachine = preload("res://scene/player/slots/slotMachine.tscn").instantiate()
		newMachine.isGoonCrushBonus = true
		Root.levelRoot.add_child.call_deferred(newMachine) #deferred: the crush may come from a node leaving the level

func updatePlayerRegion(tile) ->void:
	%RegionChip.updatePlayerRegion(tile)

#the crush goal flies to mid-screen while its slot machine opens, then back with the next goal
func animateNewGoonCrushGoal(animatebackwards: bool = true) -> void:
	if animatebackwards:
		$AnimationPlayer.play_backwards("NewGoonCrushBonus")
		nextCrushingAward = pow(( crushingAwardLevel + 1 ), 1.7) * awardBase
	else:
		$AnimationPlayer.play("NewGoonCrushBonus")

func animateNewRegion(animatebackwards: bool = true) -> void:
	if animatebackwards:
		$AnimationPlayer2.play_backwards("NewWave")
	else:
		$AnimationPlayer2.play("NewWave")
