class_name Tape extends RefCounted

#A taped drive (docs/PROMO.md, "Hand drives"): what a person held on each physics tick of a run, so the same
#run can be played again and filmed offline at any size. Input in this game is actions held or not (a stick
#is a strength), so a tape is the list of changes:
#  line 1          a JSON object: what was played (level, car, mode, tier, seed ...), "ticks", "bookmarks"
#  <tick> <action> <strength>     the action's strength from that tick on (0 = let go)
#  <tick> @ <x> <y>               where the car was, every Session.CHECK_TICKS: a replay reports its drift
#Ticks count from GO (the start lamps going green). A tape plays back through Input.action_press, so the
#game reads it exactly as it reads a person; mouse clicks are not taped.

const SKIP := ["ui_text_", "ui_graph_", "ui_filedialog_", "ui_colorpicker_", "ui_swap_", "ui_undo", "ui_redo", "ui_copy", "ui_cut", "ui_paste"]
const CHECK := "@"

var header := {}
var bookmarks: Array = []
var ticks := 0
var actions: PackedStringArray = []
var held := {} #action -> the strength last written or played
var lines: PackedStringArray = []
var changes := {} #tick -> [[action, strength], ...]
var checks := {} #tick -> Vector2

func _init():
	for action in InputMap.get_actions():
		var name := String(action)
		if SKIP.any(func(prefix): return name.begins_with(prefix)): continue
		actions.push_back(name)

#taping: note what changed this tick
func listen(tick: int, car: Node2D) -> void:
	for action in actions:
		var strength := snappedf(Input.get_action_strength(action), 0.01)
		if strength != held.get(action, 0.0):
			held[action] = strength
			lines.push_back("%d\t%s\t%s" % [tick, action, str(strength)])
	if tick % 60 == 0 && is_instance_valid(car):
		lines.push_back("%d\t%s\t%.1f\t%.1f" % [tick, CHECK, car.global_position.x, car.global_position.y])

#playing: hold what the tape held on this tick. Returns how far the car is from where it was when taped
#(0 on a tick with no note of it)
func play(tick: int, car: Node2D) -> float:
	for change in changes.get(tick, []):
		if change[1] > 0.0: Input.action_press(change[0], change[1])
		else: Input.action_release(change[0])
	if checks.has(tick) && is_instance_valid(car): return car.global_position.distance_to(checks[tick])
	return 0.0

func write(path: String, what: Dictionary, lastTick: int) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	what["ticks"] = lastTick
	what["bookmarks"] = bookmarks
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line(JSON.stringify(what))
	for line in lines: file.store_line(line)
	file.close()

static func read(path: String) -> Tape:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	var first = JSON.parse_string(file.get_line())
	if not first is Dictionary: return null
	var tape := Tape.new()
	tape.header = first
	tape.ticks = int(first.get("ticks", 0))
	tape.bookmarks = first.get("bookmarks", [])
	while not file.eof_reached():
		var parts := file.get_line().split("\t")
		if parts.size() < 3: continue
		var tick := int(parts[0])
		if parts[1] == CHECK:
			if parts.size() >= 4: tape.checks[tick] = Vector2(float(parts[2]), float(parts[3]))
		else:
			if not tape.changes.has(tick): tape.changes[tick] = []
			tape.changes[tick].push_back([parts[1], float(parts[2])])
	return tape
