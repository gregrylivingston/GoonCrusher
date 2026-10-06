"""Bakes the world art into world/art/ (docs/WORLD_ART.md): seamless ground materials and the macro noise, edge strips,
props (with variants, broken and debris states, hulls and a generated scene each), decor atlases, the station
textures and the eight level posters. It also writes world/art/props.json and every .import file (mipmaps on; BC7
for ground, posters and the station lot).

	python scripts/art/bake_world.py                     # everything
	python scripts/art/bake_world.py ground edge         # just these jobs (ground edge prop decor station poster)
	python scripts/art/bake_world.py prop --only oak,rock
	python scripts/art/bake_world.py poster --only city

Needs Microsoft Edge (or Chrome via --browser). Run Godot's --import afterwards so new PNGs get imported with the
settings written here. Re-bakes keep each .import file's uid and only rewrite the compression and mipmap lines.
"""
import base64, json, os, re, subprocess, sys, html, argparse, pathlib, tempfile, shutil
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "world" / "art"
RES_DIR = "res://world/art/"
BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Google\Chrome\Application\chrome.exe"]
JOBS = ["ground", "edge", "prop", "decor", "station", "poster"]
BATCH = {"ground": 5, "edge": 8, "prop": 5, "decor": 8, "station": 5, "poster": 1}
FACTIONS = ["wild", "tribe", "scrap"]
#VRAM-compressed (BC7 on desktop) files; everything else imports lossless. All get mipmaps.
BEACON_MATERIAL = "res://shader/world_beacon.tres"
VRAM = re.compile(r"^(ground/(?!macro_noise).*|posters/.*|station/station_(lot|roof)\.png)$")

def run_page(browser, job, ids, budget=120000):
	page = (ROOT / "scripts" / "art" / "bake_world.html").as_uri() + "#" + job + (":" + ",".join(ids) if ids else "")
	profile = tempfile.mkdtemp(prefix="gc_bake_")
	try:
		run = subprocess.run([browser, "--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--user-data-dir=" + profile,
			"--virtual-time-budget=%d" % budget, "--dump-dom", page], capture_output=True, text=True, timeout=900, encoding="utf-8")
	finally:
		shutil.rmtree(profile, ignore_errors=True)
	m = re.search(r'<pre id="out">(.*?)</pre>', run.stdout, re.S)
	if not m: raise RuntimeError("%s %s: no output from the bake page\n%s" % (job, ids, run.stderr[-2000:]))
	data = json.loads(html.unescape(m.group(1)))
	if data["error"]: raise RuntimeError("%s %s: %s" % (job, ids, data["error"]))
	return data

def import_text(rel, old=None):
	vram = bool(VRAM.match(rel))
	want = {"compress/mode": "2" if vram else "0", "compress/high_quality": "true" if vram else "false", "mipmaps/generate": "true"}
	if old:
		for k, v in want.items(): old = re.sub(r"(?m)^%s=.*$" % re.escape(k), "%s=%s" % (k, v), old)
		return old
	return """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode={mode}
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""".format(mode=want["compress/mode"], hq=want["compress/high_quality"])

def write_files(files):
	for rel, url in files.items():
		path = OUT / rel
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_bytes(base64.b64decode(url.split(",", 1)[1]))
		imp = path.with_name(path.name + ".import")
		old = imp.read_text(encoding="utf-8") if imp.exists() else None
		new = import_text(rel, old)
		if new != old: imp.write_text(new, encoding="utf-8")

def level_tags():
	"""prop id -> {"levels": [...], "faction": [...]}, read from the dressing tables in world/levels/*.tres"""
	tags = {}
	for tres in sorted((ROOT / "world" / "levels").glob("*.tres")):
		text = tres.read_text(encoding="utf-8")
		lid = re.search(r'^id = &"([a-z_]+)"', text, re.M)
		block = re.search(r"^dressing = \{(.*?)^\}$", text, re.M | re.S)
		if not lid or not block: continue
		for fac, body in re.findall(r"^(\d+): \{(.*?)^\}", block.group(1), re.M | re.S):
			for pid in re.findall(r'&"([a-z_]+)"', body):
				t = tags.setdefault(pid, {"levels": [], "faction": []})
				if lid.group(1) not in t["levels"]: t["levels"].append(lid.group(1))
				f = FACTIONS[int(fac)] if int(fac) < 3 else fac
				if f not in t["faction"]: t["faction"].append(f)
	return tags

def ccw_screen(pts):
	"""orient like scene/scenery/rocks1.tscn's occluder (positive shoelace sum in y-down space), for cull_mode 2"""
	s = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
	return pts if s >= 0 else list(reversed(pts))

def vec_array(pts):
	return "PackedVector2Array(%s)" % ", ".join("%g, %g" % (p[0], p[1]) for p in pts)

def scene_tscn(pid, m):
	hull = ccw_screen(m["hull"])
	tex = RES_DIR + "props/" + m["variants"][0]
	meta = ['metadata/propId = &"%s"' % pid, 'metadata/propClass = &"%s"' % m["class"]]
	if m.get("breakable"):
		b = m["breakable"]
		meta += ["metadata/smashSpeed = %.1f" % b["smashSpeed"], 'metadata/broken = "%s"' % (RES_DIR + "props/" + b["broken"]),
			'metadata/debris = "%s"' % (RES_DIR + "props/" + b["debris"])]
	if m.get("explosive"): meta.append("metadata/explosive = true")
	occ = m["occluder"]
	sub_occ = "" if not occ else """
[sub_resource type="OccluderPolygon2D" id="occluder"]
cull_mode = 2
polygon = %s
""" % vec_array(hull)
	node_occ = "" if not occ else """
[node name="LightOccluder2D" type="LightOccluder2D" parent="."]
occluder = SubResource("occluder")
metadata/gc_world = true
"""
	disabled = "" if m.get("solid", True) else "disabled = true\n"
	#a landmark's beacon: a glow sprite at final brightness, added on top and unlit (shader/world_beacon.gdshader)
	ext_beacon = node_beacon = ""
	if m.get("beacon"):
		ext_beacon = """[ext_resource type="Texture2D" path="%s" id="beacon"]
[ext_resource type="Material" path="%s" id="beaconMat"]
""" % (RES_DIR + "props/" + m["beacon"], BEACON_MATERIAL)
		node_beacon = """
[node name="Beacon" type="Sprite2D" parent="."]
material = ExtResource("beaconMat")
scale = Vector2({sc:.4f}, {sc:.4f})
texture = ExtResource("beacon")
""".format(sc=1.0 / m["res"])
	return """[gd_scene format=3]

[ext_resource type="Texture2D" path="{tex}" id="tex"]
{ext_beacon}
[sub_resource type="ConvexPolygonShape2D" id="shape"]
points = {pts}
{sub_occ}
[node name="{pid}" type="StaticBody2D"]
collision_layer = 1
collision_mask = 0
{meta}

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2({sc:.4f}, {sc:.4f})
texture = ExtResource("tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("shape")
{disabled}{node_occ}{node_beacon}""".format(tex=tex, ext_beacon=ext_beacon, pts=vec_array(hull), sub_occ=sub_occ, pid=pid, meta="\n".join(meta), sc=1.0 / m["res"], disabled=disabled, node_occ=node_occ, node_beacon=node_beacon)

def manifest_entry(pid, m, tags):
	res = lambda name: RES_DIR + ("decor/" if m["class"] == "DECOR" else "props/") + name
	t = dict(m.get("tags") or {})
	lt = tags.get(pid, {})
	t["levels"] = sorted(set(t.get("levels", [])) | set(lt.get("levels", [])))
	t["faction"] = [f for f in FACTIONS if f in set(t.get("faction", [])) | set(lt.get("faction", []))]
	e = {"class": m["class"], "sizePx": m["sizePx"], "variants": [res(v) for v in m["variants"]], "hull": ccw_screen(m["hull"]) if m["hull"] else [],
		"occluder": m["occluder"], "breakable": None, "explosive": bool(m.get("explosive")), "tags": t}
	if m.get("breakable"):
		b = m["breakable"]
		e["breakable"] = {"smashSpeed": b["smashSpeed"], "broken": res(b["broken"]), "debris": res(b["debris"]), "debrisCells": b.get("debrisCells", 4)}
		if b.get("blastOnly"): e["breakable"]["blastOnly"] = True
	if "solid" in m: e["solid"] = m["solid"]
	if m.get("atlas"): e["atlas"] = m["atlas"]
	if m.get("beacon"): e["beacon"] = res(m["beacon"])
	if m["class"] != "DECOR": e["scene"] = RES_DIR + "props/" + pid + ".tscn"
	return e

def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("jobs", nargs="*", help="any of " + " ".join(JOBS))
	ap.add_argument("--only", default="", help="comma-separated ids within the chosen jobs")
	ap.add_argument("--workers", type=int, default=3)
	ap.add_argument("--browser", default=next((b for b in BROWSERS if os.path.exists(b)), None))
	args = ap.parse_args()
	if not args.browser: sys.exit("No Edge or Chrome found; pass --browser")
	jobs = args.jobs or JOBS
	only = set(filter(None, args.only.split(",")))
	lists = run_page(args.browser, "list", [])["meta"]["list"]
	ids_for = {"ground": lists["grounds"], "edge": lists["edges"], "prop": lists["props"], "decor": lists["decor"], "station": lists["station"], "poster": lists["posters"]}
	tasks = []
	for job in jobs:
		ids = [i for i in ids_for[job] if not only or i in only]
		if job == "ground" and not only: tasks.append(("macro", []))
		for k in range(0, len(ids), BATCH[job]): tasks.append((job, ids[k:k + BATCH[job]]))
	props = {}
	def one(task):
		data = run_page(args.browser, *task)
		write_files(data["files"])
		print(task[0], ",".join(task[1]) or "", "->", len(data["files"]), "files", flush=True)
		return data["meta"]["props"]
	with ThreadPoolExecutor(max_workers=args.workers) as pool:
		for meta in pool.map(one, tasks): props.update(meta)
	if props:
		tags = level_tags()
		mpath = OUT / "props.json"
		manifest = json.loads(mpath.read_text(encoding="utf-8")) if mpath.exists() else {}
		manifest.setdefault("props", {})
		manifest["version"] = 1
		manifest["texelsPerPx"] = 0.75
		manifest["classes"] = {"DECOR": "MultiMesh, no collision", "LOW": "pooled scene, collision, no occluder", "TALL": "pooled scene, collision and occluder",
			"STATEFUL": "instanced scene with state (breakable, explosive, spawn point)", "WALL": "wall segment, collision and occluder"}
		for pid, m in props.items():
			manifest["props"][pid] = manifest_entry(pid, m, tags)
			if m["class"] != "DECOR": (OUT / "props" / (pid + ".tscn")).write_text(scene_tscn(pid, m), encoding="utf-8")
		manifest["props"] = dict(sorted(manifest["props"].items()))
		mpath.write_text(json.dumps(manifest, indent=1), encoding="utf-8")
		print("props.json:", len(manifest["props"]), "props")

if __name__ == "__main__":
	main()
