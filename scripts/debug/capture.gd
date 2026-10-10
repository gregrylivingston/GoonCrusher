extends Node

#The capture kit's entry (docs/PROMO.md): trailer and social footage, stills and interface elements.
#Inert unless the user args include --capture; then it hands over to promo/capture/session.gd, which the
#exported game does not ship (promo/ is excluded), so nothing here may name a class from that folder.
#Runs are started by promo/tools/capture.py, which writes the job file:
#  Godot_console.exe --path . --fixed-fps 60 [--write-movie <dir>/f.png] -- --capture --job=<job.json> --window=320x180
#A job is one shot at one size (see promo/README.md for the fields). The save is a scratch copy, as with
#the benchmark, so a capture never changes player progress.

const SESSION := "res://promo/capture/session.gd"

func _ready():
	var args := parseArgs()
	if not args.has("capture"):
		queue_free()
		return
	if not ResourceLoader.exists(SESSION):
		push_error("CAPTURE the kit is not in this build (promo/ is missing)")
		get_tree().quit(1)
		return
	var session: Node = load(SESSION).new()
	session.name = "Session"
	session.args = args
	add_child(session)

static func parseArgs() -> Dictionary:
	var result = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") && arg.contains("="):
			var parts = arg.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
		elif arg.begins_with("--"):
			result[arg.substr(2)] = true
	return result
