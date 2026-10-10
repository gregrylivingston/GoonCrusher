extends SceneTree

#Bakes the par a run's rank is graded against (RunRank, docs/MODES.md "Run rank") from playtest runs: what the
#AI drivers do on each level, mode and tier. Play the runs with a tag that starts with "par", then bake:
#  Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --tag=par_prairie --level=prairie --mode=sprint,countdown,marathon,rally,cannonball --tier=easy,medium,hard --runs=3
#  Godot_console.exe --headless --path . -s res://scripts/debug/bake_run_par.gd
#Every user://playtest/results<tag>.csv whose tag starts with "par" is read. For each level, mode and tier
#(the par_key column) the par is the median of its won runs, or of all of them where none was won: crushes
#(a giant counts GIANT_WEIGHT), best combo, top speed, payout, and the time of a won run (0 when none was won).
#Entries already in the file are kept unless the runs replace them; `-- --fresh` starts from an empty file.

const DIR := "user://playtest/"

func _initialize() -> void:
	var rank = load("res://scripts/global/run_rank.gd")
	var samples := {} #par key -> its runs
	for file in DirAccess.get_files_at(DIR):
		if not file.begins_with("results") || not file.ends_with(".csv") || not file.trim_prefix("results").trim_prefix("_").begins_with("par"): continue
		var csv := FileAccess.open(DIR + file, FileAccess.READ)
		var header := csv.get_csv_line()
		if not header.has("par_key"):
			print("BAKE_PAR skipped %s: written before the par columns" % file)
			continue
		while not csv.eof_reached():
			var cells := csv.get_csv_line()
			if cells.size() < header.size(): continue
			var run := {}
			for i in header.size(): run[header[i]] = cells[i]
			if str(run.par_key) != "" && str(run.reason) != "TIMEOUT": samples.get_or_add(run.par_key, []).push_back(run)
	var table := {}
	if not OS.get_cmdline_user_args().has("--fresh") && FileAccess.file_exists(rank.PAR_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(rank.PAR_PATH))
		if parsed is Dictionary: table = parsed
	for key in samples:
		var runs: Array = samples[key]
		var won := runs.filter(func(r): return str(r.won) == "true")
		var from: Array = won if not won.is_empty() else runs
		table[key] = {
			"crushed": median(from.map(func(r): return float(r.crushed) + rank.GIANT_WEIGHT * float(r.giants))),
			"combo": median(from.map(func(r): return float(r.combo))),
			"speed": median(from.map(func(r): return float(r.top_speed))),
			"paid": median(from.map(func(r): return float(r.payout))),
			"time": median(won.map(func(r): return float(r.level_time))) if not won.is_empty() else 0.0,
			"runs": runs.size(), "won": won.size(),
		}
	var ordered := {}
	var keys := table.keys()
	keys.sort()
	for key in keys: ordered[key] = table[key]
	var out := FileAccess.open(rank.PAR_PATH, FileAccess.WRITE)
	out.store_string(JSON.stringify(ordered, "\t") + "\n")
	out.close()
	print("BAKE_PAR %d entries (%d from these runs) written to %s" % [ordered.size(), samples.size(), rank.PAR_PATH])
	quit(0)

func median(values: Array) -> float:
	if values.is_empty(): return 0.0
	values.sort()
	var mid := values.size() / 2
	return snappedf(values[mid] if values.size() % 2 == 1 else (values[mid - 1] + values[mid]) * 0.5, 0.1)
