"""Bakes the goon art: for each goon, 35 frames (walk 8, idle 4, windup 4, attack 6, special 8, stun 4) plus the
crush decal, its SpriteFrames, and a scene that inherits scene/enemy/walker/walker.tscn with the collision capsule, the
light occluder and the eye positions taken from the art.

	python scripts/art/bake_goons.py               # every goon
	python scripts/art/bake_goons.py grunt hubcap  # just these

Needs Microsoft Edge (or Chrome via --browser). Run Godot's --import afterwards so the new PNGs get their
.import files (see docs/GOONS.md). Behavior and tuning live in scripts/global/goons.gd, not here.
"""
import base64, json, math, os, re, subprocess, sys, html, argparse, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
BROWSERS = [r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
	r"C:\Program Files\Google\Chrome\Application\chrome.exe"]
ANIMS = [("walk", True, 10.0), ("idle", True, 6.0), ("windup", False, 8.0), ("attack", False, 12.0), ("special", True, 10.0), ("stun", True, 8.0)]
BATCH = 6

def all_goons():
	"""Every design id in goon_gen.js, in file order."""
	src = (ROOT / "scripts" / "art" / "goon_gen.js").read_text(encoding="utf-8")
	ids = []
	for block in re.findall(r"(?:const D=\{|Object\.assign\(D,\{)(.*?)\n\}\);?", src, re.S):
		ids += re.findall(r"^([a-z_]+):\{", block, re.M)
	return [i for i in ids if not i.startswith(("a_", "b_"))] #a_/b_ were concept-page samples

def frames_tres(gid, frames):
	path = lambda name: "res://scene/enemy/goons/%s/art/%s_%s.png" % (gid, gid, name)
	ext, anims, n = [], [], 0
	for anim, loop, fps in ANIMS:
		ids = []
		for i in range(frames[anim]):
			n += 1
			ext.append('[ext_resource type="Texture2D" path="%s" id="%d"]' % (path(anim + str(i)), n))
			ids.append('{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % n)
		anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(ids), "true" if loop else "false", anim, fps))
	return '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n' % (n + 1, "\n".join(ext), ", ".join(anims))

def vec_array(pts):
	return "PackedVector2Array(%s)" % ", ".join("%g, %g" % (p[0], p[1]) for p in pts)

def scene_tscn(gid, data, res):
	"""The goon's scene: the shared base with this goon's frames, decal, shapes and eyes."""
	shape = data["shape"]
	xs = [p[0] for p in shape] or [0]; ys = [p[1] for p in shape] or [0]
	w, l = max(xs) - min(xs), max(ys) - min(ys)
	cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
	#the body, not the props: bipeds and round rigs get a circle of about R; long rigs a capsule along the art
	R, kind = data["R"], data["kind"]
	if kind in ("biped", "shell", "blob", "boulder"): radius, height, cx, cy = R * 0.95, R * 1.9, 0.0, 0.0
	elif kind == "bird": radius, height, cx, cy = R * 0.6, R * 1.2, 0.0, 0.0
	elif kind == "vehicle": radius, height = w / 2 * 0.8, l * 0.85
	else: radius, height, cx = min(w, l) / 2 * 0.75, l * 0.75, 0.0
	radius = max(radius, R * 0.6)
	height = max(height, radius * 2)
	#art space (facing up) to body space (facing +x): the sprite, shape and occluder nodes are turned a quarter turn
	pos = (-cy, cx)
	sprite_scale = 1.0 / res
	return """[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://scene/enemy/walker/walker.tscn" id="base"]
[ext_resource type="SpriteFrames" path="res://scene/enemy/goons/{gid}/{gid}_frames.tres" id="frames"]
[ext_resource type="Texture2D" path="res://scene/enemy/goons/{gid}/art/{gid}_decal.png" id="decal"]

[sub_resource type="CapsuleShape2D" id="shape"]
radius = {radius:.1f}
height = {height:.1f}

[sub_resource type="OccluderPolygon2D" id="occluder"]
cull_mode = 1
polygon = {occ}

[node name="{gid}" instance=ExtResource("base")]
goonId = &"{gid}"
decal = ExtResource("decal")
eyes = {eyes}
bodyRadius = {radius:.1f}

[node name="CollisionShape2D" parent="." index="0"]
position = Vector2({px:.1f}, {py:.1f})
shape = SubResource("shape")

[node name="Sprite" parent="." index="1"]
scale = Vector2({sc:.4f}, {sc:.4f})
sprite_frames = ExtResource("frames")

[node name="LightOccluder2D" parent="." index="2"]
occluder = SubResource("occluder")
""".format(gid=gid, radius=radius, height=height, occ=vec_array(shape), eyes=vec_array(data["eyes"]), px=pos[0], py=pos[1], sc=sprite_scale)

def bake(ids, browser):
	page = (ROOT / "scripts" / "art" / "bake_goons.html").as_uri() + "#" + ",".join(ids)
	run = subprocess.run([browser, "--headless=new", "--disable-gpu", "--allow-file-access-from-files",
		"--virtual-time-budget=60000", "--dump-dom", page], capture_output=True, text=True, timeout=600, encoding="utf-8")
	m = re.search(r'<pre id="out">(.*?)</pre>', run.stdout, re.S)
	if not m: raise RuntimeError(",".join(ids) + ": no output from the bake page\n" + run.stderr[-2000:])
	data = json.loads(html.unescape(m.group(1)))
	if data["error"]: raise RuntimeError(data["error"])
	for gid, g in data["goons"].items():
		folder = ROOT / "scene" / "enemy" / "goons" / gid
		(folder / "art").mkdir(parents=True, exist_ok=True)
		for name, url in g["files"].items():
			(folder / "art" / name).write_bytes(base64.b64decode(url.split(",", 1)[1]))
		(folder / (gid + "_frames.tres")).write_text(frames_tres(gid, g["frames"]), encoding="utf-8")
		(folder / (gid + ".tscn")).write_text(scene_tscn(gid, g, data["res"]), encoding="utf-8")
		print(gid, "->", len(g["files"]), "frames")

if __name__ == "__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("goons", nargs="*")
	ap.add_argument("--browser", default=next((b for b in BROWSERS if os.path.exists(b)), None))
	args = ap.parse_args()
	if not args.browser: sys.exit("No Edge or Chrome found; pass --browser")
	ids = args.goons or all_goons()
	for i in range(0, len(ids), BATCH): bake(ids[i:i + BATCH], args.browser)
