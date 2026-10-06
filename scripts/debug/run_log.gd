class_name RunLog extends RefCounted

#Developer run log (debug builds only): gameSummary appends one row per run to user://runlog.csv, so prices
#and payouts can be tuned from real numbers. A file written with other columns is moved aside, not appended to.
#`driver` is "ai" when the AI drove (playtests, the console's `ai`), so those rows can be filtered out.

const PATH := "user://runlog.csv"
const COLUMNS := ["date", "version", "driver", "car", "upgrades", "level", "mode", "seconds", "coins", "stars", "payout",
	"crushes", "giants", "regions", "reason", "gems", "slot_machines", "top_speed_px", "end_fuel", "end_health",
	"score", "leg", "barrier"]

static func append(car: OverheadCarBody2D, level: Level, reason: int, payout: int, path := PATH) -> void:
	write(row(car, level, reason, payout), path)

static func row(car: OverheadCarBody2D, level: Level, reason: int, payout: int) -> Dictionary:
	var data := SaveManager.playerData
	var upgrades := 0
	for value in SaveManager.getCarByName(car.carId).upgrades.values(): upgrades += int(value)
	var regions: int = Region.regions.keys().filter(func(id): return id >= 0).size() #-2 is the wasteland outside the map
	var mode: int = data.gameMode
	return {
		"date": Time.get_datetime_string_from_system(),
		"version": Root.versionText(),
		"driver": "ai" if car.myController.get("driver") != null else "player",
		"car": car.carId,
		"upgrades": upgrades,
		"level": SaveManager.levelKey(data.levels[data.selectedLevel]),
		"mode": str(Root.gameModes.find_key(mode)).to_lower(),
		"seconds": snappedf(level.elapsed, 0.1),
		"coins": car.coin,
		"stars": car.star,
		"payout": payout,
		"crushes": car.currentGoonsCrushed,
		"giants": car.giantsCrushed,
		"regions": regions,
		"reason": str(Root.endCondition.find_key(reason)),
		"gems": car.gem,
		"slot_machines": car.slotMachines,
		"top_speed_px": int(car._highest_measured_speed),
		"end_fuel": snappedf(car.fuel, 0.1),
		"end_health": snappedf(car.health, 0.1),
		"score": level.runScore() if mode == Root.gameModes.GOONPOCALYPSE else "",
		"leg": level.leg if mode == Root.gameModes.MARATHON else "",
		"barrier": int(Root.station.barrier) if mode == Root.gameModes.DEFENSE && is_instance_valid(Root.station) else "",
	}

static func write(values: Dictionary, path := PATH) -> void:
	var header := ",".join(COLUMNS)
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		var firstLine := existing.get_line() if existing else ""
		existing = null
		if firstLine != header: DirAccess.rename_absolute(path, path.get_basename() + "_old_%d.csv" % Time.get_unix_time_from_system())
	var isNew := not FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE if isNew else FileAccess.READ_WRITE)
	if file == null:
		push_warning("RunLog: can't write " + path)
		return
	file.seek_end()
	if isNew: file.store_line(header)
	file.store_line(",".join(COLUMNS.map(func(column): return str(values.get(column, "")).replace(",", ";"))))
