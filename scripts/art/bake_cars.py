"""Bakes the car art: for each car, three weathered sheets (a0-a2), three showroom sheets (c0-c2),
the zone mask and the shadow, plus geometry.json for collision shapes (the `sheets` job), and the
weathered side view <car>_side.png for the menu (the `side` job).

    python scripts/art/bake_cars.py                   # every job, every car
    python scripts/art/bake_cars.py sedan taxi        # just these
    python scripts/art/bake_cars.py --job side        # only the side views (leaves the sheets alone)

Needs Microsoft Edge (or Chrome via --browser). Run Godot's --import afterwards so the new PNGs get
their .import files; the sheets need mipmaps on (see docs/CAR_ART.md). The side job writes its own
.import file (lossless, mipmaps on) and keeps an existing one's uid.
"""
import base64, json, os, re, subprocess, sys, html, argparse, pathlib, tempfile, shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
CARS = ["sedan", "van", "taxi", "pickup", "semi", "audi", "racer", "police", "ambulance"]
#art that bakes with a car into its folder under another name: the semi's trailer (CarTrailer)
EXTRA = {"semi": [("semiTrailer", "semi_trailer")]}
JOBS = ["sheets", "side"]
BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Google\Chrome\Application\chrome.exe"]

#The side job's page: car_gen.js's renderSide, written out like bake.html's #out.
SIDE_PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>car side bake</title></head>
<body><pre id="out"></pre>
<script src="%s"></script>
<script>
(function(){
	const key = location.hash.slice(1), out = {files:{}, error:null};
	try { out.files[key + "_side.png"] = window.CarArt.renderSide(key).toDataURL("image/png"); }
	catch(e) { out.error = String(e && e.stack || e); }
	document.getElementById("out").textContent = JSON.stringify(out);
})();
</script></body></html>
"""

def art_tres(car, geo, prefix=None):
	"""The CarArtSet the car scene points at: sheets, mask, shadow and the damage FX anchors."""
	prefix = prefix or car
	path = lambda name: "res://scene/car/%s/art/%s_%s.png" % (car, prefix, name)
	names = ["a0", "a1", "a2", "c0", "c1", "c2", "mask", "shadow"]
	ext = "\n".join('[ext_resource type="Texture2D" path="%s" id="%s"]' % (path(n), n) for n in names)
	vec = lambda v: "Vector2(%g, %g)" % (round(v[0], 1), round(v[1], 1))
	arr = lambda ids: "Array[Texture2D]([%s])" % ", ".join('ExtResource("%s")' % i for i in ids)
	return """[gd_resource type="Resource" script_class="CarArtSet" format=3]

[ext_resource type="Script" path="res://scene/car/car_art_set.gd" id="script"]
%s

[resource]
script = ExtResource("script")
weathered = %s
showroom = %s
zoneMask = ExtResource("mask")
shadow = ExtResource("shadow")
hood = %s
tank = %s
frontWheel = %s
""" % (ext, arr(["a0", "a1", "a2"]), arr(["c0", "c1", "c2"]), vec(geo["hood"]), vec(geo["tank"]), vec(geo["frontWheel"]))

def side_import(old=None):
	"""The side view imports lossless with mipmaps (the menu shrinks it a lot); Godot adds the uid and paths."""
	if old: return re.sub(r"(?m)^mipmaps/generate=.*$", "mipmaps/generate=true", old)
	return """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=false
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
detect_3d/compress_to=1
"""

def run_page(browser, page, what):
	run = subprocess.run([browser, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
		"--virtual-time-budget=20000", "--dump-dom", page], capture_output=True, text=True, timeout=180, encoding="utf-8")
	m = re.search(r'<pre id="out">(.*?)</pre>', run.stdout, re.S)
	if not m: raise RuntimeError(what + ": no output from the bake page\n" + run.stderr[-2000:])
	data = json.loads(html.unescape(m.group(1)))
	if data["error"]: raise RuntimeError(what + ": " + data["error"])
	return data

def write_png(out, name, url):
	(out / name).write_bytes(base64.b64decode(url.split(",", 1)[1]))

def bake(car, browser, key=None, prefix=None):
	"""Bakes generator entry `key` (the car's own by default) into the car's folder as `prefix`_*"""
	key = key or car
	prefix = prefix or car
	data = run_page(browser, (ROOT / "scripts" / "art" / "bake.html").as_uri() + "#" + key, key)
	out = ROOT / "scene" / "car" / car / "art"
	out.mkdir(exist_ok=True)
	for name, url in data["files"].items(): write_png(out, prefix + name[len(key):], url)
	geo = data["geometry"]
	#LF like the rest of the tree (.gitattributes), so a re-bake on Windows leaves unchanged files clean
	(out / ("geometry.json" if prefix == car else prefix + "_geometry.json")).write_text(json.dumps(geo, indent=1), encoding="utf-8", newline="\n")
	(out / (prefix + "_art.tres")).write_text(art_tres(car, geo, prefix), encoding="utf-8", newline="\n")
	print(prefix, "->", len(data["files"]), "files")
	for extraKey, extraPrefix in EXTRA.get(car, []) if key == car else []: bake(car, browser, extraKey, extraPrefix)

def bake_side(car, browser, page):
	data = run_page(browser, page.as_uri() + "#" + car, car + " side")
	out = ROOT / "scene" / "car" / car / "art"
	out.mkdir(exist_ok=True)
	for name, url in data["files"].items():
		write_png(out, name, url)
		imp = out / (name + ".import")
		old = imp.read_text(encoding="utf-8") if imp.exists() else None
		new = side_import(old)
		if new != old: imp.write_text(new, encoding="utf-8", newline="\n")
	print(car, "-> side")

if __name__ == "__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("cars", nargs="*")
	ap.add_argument("--job", choices=JOBS + ["all"], default="all")
	ap.add_argument("--browser", default=next((b for b in BROWSERS if os.path.exists(b)), None))
	args = ap.parse_args()
	if not args.browser: sys.exit("No Edge or Chrome found; pass --browser")
	cars = args.cars or CARS
	if args.job in ("all", "sheets"):
		for car in cars: bake(car, args.browser)
	if args.job in ("all", "side"):
		tmp = pathlib.Path(tempfile.mkdtemp(prefix="gc_side_"))
		try:
			page = tmp / "side.html"
			page.write_text(SIDE_PAGE % (ROOT / "scripts" / "art" / "car_gen.js").as_uri(), encoding="utf-8")
			for car in cars: bake_side(car, args.browser, page)
		finally:
			shutil.rmtree(tmp, ignore_errors=True)
