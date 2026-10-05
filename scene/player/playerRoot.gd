class_name GameUI
extends CanvasLayer



# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$VersionTracker.text = Root.versionText()
	setupHudScale()
	if is_instance_valid(Root.playerCar):
		updateStats()
	else: await get_tree().create_timer(1).timeout
	updateGoonsCrushed()
	updateStats()
	Root.playerRoot = self
	%ProgressBar.value = 0
	%ProgressBar.max_value = awardBase
	add_child(load("res://scene/player/countdown.tscn").instantiate())
	


	
# Called every frame. 'delta' is the elapsed time since the previous frame.
var shownCounts = []

func _process(delta):
	if Input.is_action_just_pressed("ui_menu"): openPause()
	if crushAwardPending && not get_tree().paused: #a goal reached while paused is granted on unpause
		crushAwardPending = false
		updateGoonsCrushed()
	var counts = [Root.playerCar.coin, Root.playerCar.gem, Root.playerCar.star]
	if counts != shownCounts: #strings are rebuilt only when a count changes
		shownCounts = counts
		%coins.text = str( Root.playerCar.coin )
		%gem.text = str( Root.playerCar.gem )
		%star.text = str(Root.playerCar.star)
		%coinProjection.text = str(Root.computePayout(Root.playerCar.coin, Root.playerCar.star))

#the only way to pause a run: Esc / Start, the HUD button, or losing focus.
#never opens over the slot machine, countdown or summary, which pause the tree themselves
func openPause() -> void:
	if get_tree().paused || Settings.menu_open || get_tree().get_nodes_in_group("pauseMenu").size() > 0: return
	get_tree().paused = true
	for i in get_tree().get_nodes_in_group("visibleWhenPaused"):i.visible = true
	add_child( load("res://scene/player/menu/pauseMenu.tscn").instantiate() )

func updateStats():$carPanel.updateStats()

#HUD Scale (Accessibility). Each authored HUD control is scaled about its point nearest its anchor,
#so corner widgets stay in their corners and the car's bars stay by the car. Menus added at
#runtime (pause, slots, countdown, summary) are not scaled.
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

var awardBase = 12
var crushingAwardLevel = 0
var nextCrushingAward = awardBase
var crushAwardPending := false #a crush goal was reached while the tree was paused (e.g. a slot machine reward)
@onready var crushProgressBar = %ProgressBar

func updateGoonsCrushed():
	%crushedGoons.text = str( clampi( int(nextCrushingAward) - Root.playerCar.currentGoonsCrushed , 0 , 9999999999999 ) )
	crushProgressBar.value = Root.playerCar.currentGoonsCrushed
	if Root.playerCar.currentGoonsCrushed >= nextCrushingAward && not Root.playerCar.isDestroyed && get_tree().paused:
		crushAwardPending = true #the slot machine can't open over a paused tree; _process grants it on unpause
	elif Root.playerCar.currentGoonsCrushed >= nextCrushingAward && not Root.playerCar.isDestroyed:
		crushProgressBar.min_value = nextCrushingAward
		crushingAwardLevel += 1
		Root.playerCar.star += 1


		get_tree().paused = true
		
		#create award
		var slotMachineScene = preload("res://scene/player/slots/slotMachine.tscn")
		var newMachine = slotMachineScene.instantiate()
		newMachine.isGoonCrushBonus = true
		Root.levelRoot.add_child(newMachine)





func updatePlayerRegion(tile) ->void:
	%regionUi.updatePlayerRegion(tile)


func animateNewGoonCrushGoal(animatebackwards: bool = true) -> void:
	if animatebackwards:
		$AnimationPlayer.play_backwards("NewGoonCrushBonus")
		nextCrushingAward = pow(( crushingAwardLevel + 1 ), 1.7) * awardBase
		crushProgressBar.max_value = nextCrushingAward
		%crushedGoons.text = str( int(nextCrushingAward) - Root.playerCar.currentGoonsCrushed  )		
	else:
		$AnimationPlayer.play("NewGoonCrushBonus")
		
func animateNewRegion(animatebackwards: bool = true) -> void:
	
	if animatebackwards:
		$AnimationPlayer2.play_backwards("NewWave")
	else:
		$AnimationPlayer2.play("NewWave")
