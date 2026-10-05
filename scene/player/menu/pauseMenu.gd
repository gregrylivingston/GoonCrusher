extends CanvasLayer

var confirmTimers = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Settings.set_menu_context(true)
	$Panel/VBoxContainer/continue.grab_focus()

func _process(_delta):
	if Input.is_action_just_pressed("ui_menu") && not Settings.menu_open:
		_on_continue_pressed()


func _on_continue_pressed():
	for i in get_tree().get_nodes_in_group("visibleWhenPaused"):i.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Settings.set_menu_context(false)
	queue_free()	
	get_tree().paused = false

func _on_quit_pressed():
	if confirmed($Panel/VBoxContainer/quit, "Quit"):
		get_tree().quit()

#abandoning ends the run like a death: the summary shows it and pays coins x stars (at least x1)
func _on_abandon_pressed():
	if is_queued_for_deletion(): return
	if confirmed($Panel/VBoxContainer/abandon, "Abandon"):
		Settings.set_menu_context(false)
		if is_instance_valid(Root.levelRoot) && Root.levelRoot.has_method("endLevel") && not Root.levelRoot.hasEnded:
			for i in get_tree().get_nodes_in_group("visibleWhenPaused"):i.visible = false
			queue_free()
			Root.levelRoot.endLevel(false, Root.endCondition.ABANDONED)
		else: #no run to end (the level is gone, or it already ended and paid): just leave
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scene/player/menu/main/main2.tscn")

#with Confirm Abandon / Quit on, the first press only arms the button for 3 seconds
func confirmed(button, label: String) -> bool:
	if not Settings.get_value("gameplay/confirm_quit") || confirmTimers.get(button, false): return true
	armConfirm(button, label)
	return false

func armConfirm(button, label: String) -> void:
	confirmTimers[button] = true
	button.updateText("Press again")
	await get_tree().create_timer(3.0, true).timeout
	if is_instance_valid(button):
		confirmTimers[button] = false
		button.updateText(label)

func _on_settings_pressed():
	add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())
