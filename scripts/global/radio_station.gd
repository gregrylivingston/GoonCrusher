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
var segmentChance := 0.6
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
	segmentChance = clampf(float(config.get("segment_chance", 0.6 if talks else 0.3)), 0.0, 1.0)
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

#The segment to play between two songs, or {} for none, by the station's chance and weights.
#Segments are not contextual (docs/RADIO.md): any one may play at any time.
func pickSegment() -> Dictionary:
	if rng.randf() >= segmentChance: return {}
	var kinds := []
	var total := 0.0
	for kind in SEGMENT_KINDS:
		if weights[kind] > 0.0 && not files.get(kind, []).is_empty():
			kinds.push_back(kind)
			total += weights[kind]
	if kinds.is_empty(): return {}
	var roll = rng.randf() * total
	var kind = kinds.back()
	for k in kinds:
		roll -= weights[k]
		if roll < 0.0:
			kind = k
			break
	return {"kind":kind, "path":bag(kind, files[kind]).next()}

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
