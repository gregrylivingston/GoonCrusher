extends Node

var perfOverlay: PerfOverlay

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameStats.registerMonitors(get_tree())
	perfOverlay = PerfOverlay.new()
	add_child(perfOverlay)

func _unhandled_input(event):
	if event is InputEventKey && event.pressed && not event.echo && event.keycode == KEY_F3:
		perfOverlay.setMode((perfOverlay.mode + 1) % 3)
