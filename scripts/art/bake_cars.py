"""Bakes the car art: for each car, three weathered sheets (a0-a2), three showroom sheets (c0-c2),
the zone mask and the shadow, plus geometry.json for collision shapes.

    python scripts/art/bake_cars.py            # every car
    python scripts/art/bake_cars.py sedan taxi # just these

Needs Microsoft Edge (or Chrome via --browser). Run Godot's --import afterwards so the new PNGs get
their .import files; the sheets need mipmaps on (see docs/CAR_ART.md).
"""
import base64, json, os, re, subprocess, sys, html, argparse, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
CARS = ["sedan", "van", "taxi", "pickup", "semi", "audi", "racer", "police", "ambulance"]
#art that bakes with a car into its folder under another name: the semi's trailer (CarTrailer)
EXTRA = {"semi": [("semiTrailer", "semi_trailer")]}
BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Google\Chrome\Application\chrome.exe"]

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

def bake(car, browser, key=None, prefix=None):
	"""Bakes generator entry `key` (the car's own by default) into the car's folder as `prefix`_*"""
	key = key or car
	prefix = prefix or car
	page = (ROOT / "scripts" / "art" / "bake.html").as_uri() + "#" + key
	run = subprocess.run([browser, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
		"--virtual-time-budget=20000", "--dump-dom", page], capture_output=True, text=True, timeout=180, encoding="utf-8")
	m = re.search(r'<pre id="out">(.*?)</pre>', run.stdout, re.S)
	if not m: raise RuntimeError(car + ": no output from the bake page\n" + run.stderr[-2000:])
	data = json.loads(html.unescape(m.group(1)))
	if data["error"]: raise RuntimeError(car + ": " + data["error"])
	out = ROOT / "scene" / "car" / car / "art"
	out.mkdir(exist_ok=True)
	for name, url in data["files"].items():
		(out / (prefix + name[len(key):])).write_bytes(base64.b64decode(url.split(",", 1)[1]))
	geo = data["geometry"]
	(out / ("geometry.json" if prefix == car else prefix + "_geometry.json")).write_text(json.dumps(geo, indent=1), encoding="utf-8")
	(out / (prefix + "_art.tres")).write_text(art_tres(car, geo, prefix), encoding="utf-8")
	print(prefix, "->", len(data["files"]), "files")
	for extraKey, extraPrefix in EXTRA.get(car, []) if key == car else []: bake(car, browser, extraKey, extraPrefix)

if __name__ == "__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("cars", nargs="*")
	ap.add_argument("--browser", default=next((b for b in BROWSERS if os.path.exists(b)), None))
	args = ap.parse_args()
	if not args.browser: sys.exit("No Edge or Chrome found; pass --browser")
	for car in args.cars or CARS: bake(car, args.browser)
