class_name RadioStation extends RefCounted

#One radio station: a folder under sound/radio/ with station.json and folders of audio
#(docs/RADIO.md). Scanned once; adding a track needs no code.

const AUDIO_EXTENSIONS := ["ogg", "mp3", "wav"]
const SEGMENT_KINDS := ["ident", "talk", "ad"]
#kind -> folder
const FOLDERS := {"song":"songs", "ident":"idents", "talk":"talk", "ad":"ads"}

var id: StringName
var folder: String
var name: String
var short: String
var color := Color.WHITE
var order := 99
#relative odds of 0, 1 or 2 segments between two songs (station.json "segment_counts"); two are always
#of different kinds. Stations without it use "segment_chance": [1 - chance, chance, 0]. Two empty gaps
#never come in a row (lastEmpty), so with [1, 1, 1] a gap is empty a quarter of the time.
var segmentCounts: Array[float] = [0.4, 0.6, 0.0]
var lastEmpty := false
var weights := {"ident":1.0, "talk":1.0, "ad":1.0}
var crossfade := 2.5
var logo: String = ""
var files := {}       #kind -> Array of paths
var bags := {}        #kind -> RadioBag
var rng := RandomNumberGenerator.new()

static func fromFolder(dir: String) -> RadioStation:
	var station = RadioStation.new()
	station.folder = dir.trim_suffix("/")
	station.id = StringName(station.folder.get_file())
	for kind in FOLDERS: station.files[kind] = listAudio(station.folder + "/" + FOLDERS[kind])
	station.applyConfig(readJson(station.folder + "/station.json"))
	if ResourceLoader.exists(station.folder + "/logo.svg"): station.logo = station.folder + "/logo.svg"
	return station

func applyConfig(config: Dictionary) -> void:
	var talks = not files.get("talk", []).is_empty() || not files.get("ad", []).is_empty()
	name = str(config.get("name", String(id).capitalize()))
	short = str(config.get("short", initials(name)))
	color = Color.from_string(str(config.get("color", "#ffffff")), Color.WHITE)
	order = int(config.get("order", 99))
	var chance = clampf(float(config.get("segment_chance", 0.6 if talks else 0.3)), 0.0, 1.0)
	segmentCounts.assign([1.0 - chance, chance, 0.0])
	var counts = config.get("segment_counts")
	if counts is Array && counts.size() == 3:
		for i in 3: segmentCounts[i] = maxf(0.0, float(counts[i]))
	crossfade = clampf(float(config.get("crossfade", 2.5)), 0.0, 10.0)
	var w = config.get("weights", {})
	if w is Dictionary:
		for kind in SEGMENT_KINDS: weights[kind] = maxf(0.0, float(w.get(kind, weights[kind])))

func hasSongs() -> bool:
	return not files.get("song", []).is_empty()

func reseed(value: int) -> void:
	rng.seed = value
	bags.clear()

func bag(key: String, paths: Array) -> RadioBag:
	if not bags.has(key): bags[key] = RadioBag.new(paths, rng)
	return bags[key]

func nextSong() -> String:
	var path = bag("song", files.get("song", [])).next()
	return path if path else ""

#The segments to play between two songs: none, one, or two of different kinds, by the station's
#segment_counts, each kind picked by its weight. Segments are not contextual (docs/RADIO.md): any one
#may play at any time.
func pickSegments() -> Array:
	var odds: Array[float] = segmentCounts.duplicate()
	if lastEmpty && odds[1] + odds[2] > 0.0: odds[0] = 0.0
	var count = weightedIndex(odds)
	var out := []
	var used := []
	for n in count:
		var kind = pickKind(used)
		if kind == "": break
		used.push_back(kind)
		out.push_back({"kind":kind, "path":bag(kind, files[kind]).next()})
	lastEmpty = out.is_empty()
	return out

#a segment kind with files, by weight, skipping the kinds already used; "" when none is left
func pickKind(exclude: Array = []) -> String:
	var kinds := []
	var odds: Array[float] = []
	for kind in SEGMENT_KINDS:
		if weights[kind] > 0.0 && not files.get(kind, []).is_empty() && not exclude.has(kind):
			kinds.push_back(kind)
			odds.push_back(weights[kind])
	if kinds.is_empty(): return ""
	return kinds[weightedIndex(odds)]

func weightedIndex(odds: Array[float]) -> int:
	var total := 0.0
	for w in odds: total += w
	if total <= 0.0: return 0
	var roll = rng.randf() * total
	for i in odds.size():
		roll -= odds[i]
		if roll < 0.0: return i
	return odds.size() - 1

#every bag's place in its cycle (Radio saves it to user:// so the shuffle carries over launches)
func state() -> Dictionary:
	var out := {}
	for kind in FOLDERS:
		if bags.has(kind): out[kind] = bags[kind].state()
	return out

func restore(saved: Dictionary) -> void:
	for kind in FOLDERS:
		if saved.get(kind) is Dictionary && not files.get(kind, []).is_empty(): bag(kind, files[kind]).restore(saved[kind])

func nextIdent() -> String:
	var path = bag("ident", files.get("ident", [])).next()
	return path if path else ""

#"Crush Hour - DJ Grille.ogg" -> title "Crush Hour", artist "DJ Grille"; no " - " -> the station is the artist
func songInfo(path: String) -> Dictionary:
	var stem = path.get_file().get_basename()
	var cut = stem.find(" - ")
	if cut > 0: return {"title":stem.substr(0, cut).strip_edges(), "artist":stem.substr(cut + 3).strip_edges()}
	return {"title":stem.replace("_", " ").strip_edges(), "artist":name}

static func initials(text: String) -> String:
	var out = ""
	for word in text.split(" ", false): out += word.substr(0, 1).to_upper()
	return out.substr(0, 4)

#ResourceLoader.list_directory sees imported files in exported builds, where DirAccess lists .import/.remap
static func listEntries(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir): return PackedStringArray()
	if ResourceLoader.has_method("list_directory"): return ResourceLoader.call("list_directory", dir)
	var out := PackedStringArray()
	var access = DirAccess.open(dir)
	if access == null: return out
	for d in access.get_directories(): out.push_back(d + "/")
	for f in access.get_files(): out.push_back(f.trim_suffix(".remap").trim_suffix(".import"))
	return out

static func listAudio(dir: String) -> Array:
	var out := []
	for entry in listEntries(dir):
		if entry.ends_with("/"): continue
		if AUDIO_EXTENSIONS.has(entry.get_extension().to_lower()) && not out.has(dir + "/" + entry): out.push_back(dir + "/" + entry)
	out.sort()
	return out

static func listDirs(dir: String) -> Array:
	var out := []
	for entry in listEntries(dir):
		if entry.ends_with("/"): out.push_back(entry.trim_suffix("/"))
	return out

static func readJson(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary: return parsed
	push_warning("Radio: %s is not a JSON object" % path)
	return {}
