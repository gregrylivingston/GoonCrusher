#!/usr/bin/env python3
"""GoonCrusher capture kit: trailer and social footage, stills and interface elements.

    python promo/tools/capture.py doctor                 is this machine ready? (run this first)
    python promo/tools/capture.py shot trailer_launch    film every shot in promo/shots/trailer_launch.json
    python promo/tools/capture.py quick --level city --car taxi --time night --profile vertical
    python promo/tools/capture.py hand my_drive --level prairie --car sedan
    python promo/tools/capture.py replay my_drive --mark 1 --profile wide4k
    python promo/tools/capture.py stock                  the AI library: every level, day and night
    python promo/tools/capture.py gallery                build and open the review page

Each command has --help. How it all fits together: promo/README.md (for the people filming) and
docs/PROMO.md (for whoever maintains this). Output goes to a folder on this machine, outside the
repo, set by `doctor` and kept in promo/tools/local.json.
"""
import argparse
import datetime
import glob
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
import webbrowser
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PROMO = REPO / "promo"
LOCAL = PROMO / "tools" / "local.json"
GODOT_VERSION = "4.7.2"
NATIVE = REPO / "bin" / "windows" / "gooncrusher.windows.template_debug.x86_64.dll"
START_SECONDS = 90  # a game that hasn't begun its capture by now isn't going to

# name -> (width, height). Anything that isn't 16:9 is filmed with the HUD off unless the shot says
# otherwise: the HUD is laid out for a wide screen.
PROFILES = {
    "wide4k": (3840, 2160), "wide1440": (2560, 1440), "wide1080": (1920, 1080), "wide720": (1280, 720),
    "vertical": (1080, 1920), "square": (1080, 1080), "portrait45": (1080, 1350),
    # Steam store and library art (check Steamworks before a final export: these change)
    "steam_header": (920, 430), "steam_small": (462, 174), "steam_main": (1232, 706),
    "steam_vertical": (748, 896), "steam_library": (600, 900), "steam_hero": (3840, 1240),
    "steam_logo": (1280, 720), "steam_background": (1438, 810), "youtube_thumb": (1280, 720),
}
# job fields that are really the game's own command-line options (docs/WORLD.md, docs/GOONS.md, docs/PICKUPS.md)
PASS_THROUGH = ["landscape", "goons", "class", "prize"]
LEVELS = ["prairie", "orchard", "bayou", "canyon", "moosewoods", "mudlick", "stilttown", "lantern", "sawmill",
          "quarry", "highway", "ghosttown", "saltflats", "raiderpass", "thunderroad", "frostbite", "frozenlake",
          "timberline", "tarpits", "summit", "city", "manhole", "culdesac", "gridlock", "blockparty", "blastpits",
          "tankfarm", "slagfields", "theline", "crusher"]
CARS = ["sedan", "taxi", "pickup", "police", "ambulance", "van", "racer", "supercar", "semi"]


class Problem(Exception):
    """Something the person can fix; shown without a traceback."""


def say(text=""):
    print(text, flush=True)


# --- this machine ---------------------------------------------------------------------------------

def read_local():
    if LOCAL.exists():
        try:
            return json.loads(LOCAL.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            raise Problem(f"{LOCAL} is not valid JSON. Delete it and run: python promo/tools/capture.py doctor")
    return {}


def write_local(local):
    LOCAL.write_text(json.dumps(local, indent=2) + "\n", encoding="utf-8")


def find_godot(local):
    candidates = [local.get("godot"), os.environ.get("GODOT")]
    home = Path.home()
    for pattern in [f"Downloads/Godot_v{GODOT_VERSION}-stable_win64*/**/Godot_v{GODOT_VERSION}-stable_win64_console.exe",
                    f"Downloads/**/Godot_v{GODOT_VERSION}-stable_win64_console.exe",
                    f"Desktop/**/Godot_v{GODOT_VERSION}-stable_win64_console.exe"]:
        candidates += glob.glob(str(home / pattern), recursive=True)
    candidates += [shutil.which("godot_console"), shutil.which("godot")]
    for path in candidates:
        if path and Path(path).is_file():
            return str(Path(path))
    return None


def find_ffmpeg(local, tool="ffmpeg"):
    candidates = [local.get(tool), shutil.which(tool)]
    packages = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WinGet" / "Packages"
    candidates += glob.glob(str(packages / "Gyan.FFmpeg*" / "**" / f"{tool}.exe"), recursive=True)
    for path in candidates:
        if path and Path(path).is_file():
            return str(Path(path))
    return None


def default_out():
    return Path.home() / "Videos" / "GoonCrusher Capture"


def inside_repo(path):
    try:
        Path(path).resolve().relative_to(REPO)
        return True
    except ValueError:
        return False


class Machine:
    """Where things are on this machine. `need` raises a Problem with what to do about it."""

    def __init__(self):
        self.local = read_local()
        self.godot = find_godot(self.local)
        self.ffmpeg = find_ffmpeg(self.local)
        self.ffprobe = find_ffmpeg(self.local, "ffprobe")
        self.out = Path(self.local["out"]) if self.local.get("out") else None

    def need(self, godot=False, ffmpeg=False, out=True):
        hint = "Run: python promo/tools/capture.py doctor"
        if godot and not self.godot:
            raise Problem(f"Godot {GODOT_VERSION} was not found. {hint}")
        if godot and not NATIVE.exists():
            raise Problem(f"The game's native library is missing ({NATIVE.relative_to(REPO)}). {hint}")
        if ffmpeg and not self.ffmpeg:
            raise Problem(f"ffmpeg was not found. {hint}")
        if out:
            if not self.out:
                raise Problem(f"No output folder has been chosen yet. {hint}")
            if inside_repo(self.out):
                raise Problem(f"The output folder {self.out} is inside the repo. Footage must stay out of git. "
                              "Run: python promo/tools/capture.py doctor --out <a folder somewhere else>")
            self.out.mkdir(parents=True, exist_ok=True)
        return self

    def folder(self, name):
        path = self.out / name
        path.mkdir(parents=True, exist_ok=True)
        return path


def git(*args):
    try:
        return subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def cmd_doctor(args):
    local = read_local()
    if args.out:
        if inside_repo(args.out):
            raise Problem("That folder is inside the repo. Pick one outside it, for example " + str(default_out()))
        local["out"] = str(Path(args.out).resolve())
    if args.godot:
        local["godot"] = args.godot
    if not local.get("out"):
        local["out"] = str(default_out())
        say(f"No output folder chosen, so using {local['out']}  (change it with: doctor --out <folder>)")
    ok = True

    def line(good, name, detail, fix=""):
        nonlocal ok
        ok = ok and good
        say(f"  [{'ok' if good else 'MISSING'}] {name}: {detail}")
        if not good and fix:
            say(f"          -> {fix}")

    say("GoonCrusher capture kit: checking this machine")
    godot = find_godot(local)
    if godot:
        local["godot"] = godot
    line(bool(godot), f"Godot {GODOT_VERSION}", godot or "not found",
         f"Download Godot {GODOT_VERSION} (standard, Windows) from godotengine.org, unzip it in Downloads, and run doctor again. "
         "Or: doctor --godot <path to Godot_v4.7.2-stable_win64_console.exe>")
    ffmpeg = find_ffmpeg(local)
    if not ffmpeg and args.fix and shutil.which("winget"):
        say("  installing ffmpeg with winget (this can take a few minutes) ...")
        subprocess.run(["winget", "install", "--id", "Gyan.FFmpeg", "-e", "--accept-source-agreements",
                        "--accept-package-agreements", "--silent"], check=False)
        ffmpeg = find_ffmpeg(local)
    line(bool(ffmpeg), "ffmpeg", ffmpeg or "not found", "Run: python promo/tools/capture.py doctor --fix   (installs it with winget)")
    if args.native:
        source = Path(args.native)
        copied = 0
        for dll in (source.glob("*.dll") if source.is_dir() else [source]):
            NATIVE.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dll, NATIVE.parent / dll.name)
            copied += 1
        say(f"  copied {copied} file(s) into {NATIVE.parent.relative_to(REPO)}")
    line(NATIVE.exists(), "native library", str(NATIVE.relative_to(REPO)) if NATIVE.exists() else "not built",
         "The game needs this C++ library and it is not in git. Ask the author for the two .dll files for this commit "
         f"({git('rev-parse', '--short', 'HEAD') or 'unknown'}), then run: doctor --native <the folder they are in>. "
         "(With MSVC installed, scripts/windows/build_native.bat builds them.)")
    out = Path(local["out"])
    try:
        out.mkdir(parents=True, exist_ok=True)
        free = shutil.disk_usage(out).free / 1e9
        line(free > 20, "output folder", f"{out}  ({free:.0f} GB free)", "Under 20 GB free. A minute of 4K master is about 13 GB.")
    except OSError as error:
        line(False, "output folder", f"{out}: {error}", "Pick another: doctor --out <folder>")
    commit = git("rev-parse", "--short", "HEAD")
    dirty = bool(git("status", "--porcelain", "--untracked-files=no"))
    say(f"  [info] repo at commit {commit or 'unknown'}{' with local changes' if dirty else ''}")
    write_local(local)
    say()
    say("Ready to film." if ok else "Not ready yet: fix the MISSING lines above, then run doctor again.")
    return 0 if ok else 1


# --- running the game ---------------------------------------------------------------------------

def next_version(folder, stem):
    """<stem>_v01, _v02 ...: a new take never overwrites the last."""
    taken = [int(m.group(1)) for p in folder.glob(f"{stem}_v*") if (m := re.search(r"_v(\d+)", p.name[len(stem):]))]
    return f"{stem}_v{max(taken, default=0) + 1:02d}"


def run_godot(machine, job, log, sound=None, headless=False, fixed=True):
    """Starts the game on a job file and waits. Returns the CAPTURE_* lines it printed."""
    job_path = Path(str(log) + ".job.json")
    job_path.write_text(json.dumps(job, indent=1), encoding="utf-8")
    width, height = job.get("size", [1600, 900])
    command = [machine.godot, "--path", str(REPO), "--windowed", "--resolution", f"{width}x{height}"]
    if fixed:
        command += ["--fixed-fps", str(job.get("fps", 60))]
    if sound:
        command += ["--write-movie", str(sound)]
    if headless:
        command += ["--headless"]
    command += ["--", "--capture", f"--job={job_path}", f"--window={width}x{height}"]
    command += [f"--{key}={job[key]}" for key in PASS_THROUGH if job.get(key)]
    with open(log, "w", encoding="utf-8", errors="replace") as handle:
        result = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT)
        # A game that doesn't compile never reaches the capture and never quits, so watch that it starts.
        started = time.monotonic()
        while result.poll() is None:
            time.sleep(2)
            if time.monotonic() - started < START_SECONDS or job.get("kind") == "hand":
                continue
            text = Path(log).read_text(encoding="utf-8", errors="replace")
            if "CAPTURE_RUN" not in text and "CAPTURE_STAGE" not in text:
                result.kill()
                result.wait()
                broken = [l for l in text.splitlines() if "Parse Error" in l][:3]
                raise Problem("The game didn't start the capture. " + ("Its code doesn't compile right now (a change in progress?):\n  " + "\n  ".join(broken) if broken
                              else f"The log is {log}"))
    lines = Path(log).read_text(encoding="utf-8", errors="replace").splitlines()
    marks = [l for l in lines if l.startswith("CAPTURE_")]
    failed = [l for l in marks if l.startswith("CAPTURE_FAILED")]
    errors = [l for l in lines if "SCRIPT ERROR" in l]
    if failed:
        raise Problem(failed[0].removeprefix("CAPTURE_FAILED "))
    if result.returncode != 0 or not any(l.startswith("CAPTURE_DONE") or l.startswith("CAPTURE_TAPE") for l in marks):
        tail = "\n".join(lines[-12:])
        raise Problem(f"The game stopped before the capture finished (exit code {result.returncode}). The log is {log}\n{tail}")
    if errors:
        say(f"  note: {len(errors)} script error(s) during the run, see {log}")
    job_path.unlink(missing_ok=True)
    return marks


def ffmpeg_run(machine, arguments, what):
    result = subprocess.run([machine.ffmpeg, "-hide_banner", "-loglevel", "error", "-y", *arguments], capture_output=True, text=True)
    if result.returncode != 0:
        raise Problem(f"ffmpeg failed while {what}:\n{result.stderr.strip()[-1500:]}")


def master_args(alpha, light):
    """Resolve-ready video. ProRes 422 HQ, 4444 when the picture has transparency; --light is H.264 for small disks."""
    colour = ["-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709"]
    if alpha:
        return ["-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le", "-vendor", "apl0", *colour], ".mov"
    if light:
        return ["-vf", "scale=out_color_matrix=bt709:out_range=tv", "-c:v", "libx264", "-crf", "14", "-preset", "medium",
                "-pix_fmt", "yuv420p", *colour, "-color_range", "tv"], ".mp4"
    return ["-vf", "scale=out_color_matrix=bt709:out_range=tv", "-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le",
            "-vendor", "apl0", *colour, "-color_range", "tv"], ".mov"


def timecode(frame, fps, hours=1):
    seconds, frames = divmod(frame, fps)
    minutes, seconds = divmod(seconds, 60)
    extra_hours, minutes = divmod(minutes, 60)
    return f"{hours + extra_hours:02d}:{minutes:02d}:{seconds:02d}:{frames:02d}"


def write_markers(sidecar, path):
    """A marker list DaVinci Resolve imports (right-click the timeline in the media pool > Timelines > Import >
    Timeline Markers from EDL). Crushes close together become one marker."""
    fps = int(sidecar.get("fps", 60))
    colours = {"crush": "ResolveColorRed", "pickup": "ResolveColorYellow", "bookmark": "ResolveColorGreen",
               "event": "ResolveColorBlue", "mark": "ResolveColorCyan"}
    merged = []
    for event in sidecar.get("events", []):
        last = merged[-1] if merged else None
        if last and event["kind"] == "crush" and last["kind"] == "crush" and event["frame"] - last["last"] < fps // 2:
            last["count"] += 1
            last["last"] = event["frame"]
        else:
            merged.append({**event, "count": 1, "last": event["frame"]})
    lines = [f"TITLE: {Path(path).stem}", "FCM: NON-DROP FRAME", ""]
    for index, event in enumerate(merged, 1):
        name = event["kind"] + (f" x{event['count']}" if event["count"] > 1 else "") + (f" {event['label']}" if event["kind"] != "crush" and event.get("label") else "")
        start, end = timecode(event["frame"], fps), timecode(event["frame"] + 1, fps)
        lines += [f"{index:03d}  001      V     C        {start} {end} {start} {end}  ",
                  f" |C:{colours.get(event['kind'], 'ResolveColorBlue')} |M:{name} |D:1", ""]
    Path(path).write_text("\n".join(lines), encoding="utf-8")
    return len(merged)


def film(machine, job, name, dest, args, tags=None):
    """One job, start to finish: run the game, make the master (or keep the stills), write the sidecar.
    Returns the files made."""
    work = machine.folder("work")
    stem = next_version(dest, name)
    base = work / stem
    job = {**job, "out": base.as_posix()}
    still_only = float(job.get("seconds", 10)) <= 0
    if still_only:
        job.update(record="none", seconds=0.2, stills=job.get("stills") or [0.0])
    else:
        job.setdefault("record", "frames")
    alpha = bool(job.get("alpha"))
    want_sound = not still_only and not alpha and job.get("sound", True) and not getattr(args, "silent", False)
    sound = Path(str(base) + "_sound.avi") if want_sound else None
    log = Path(str(base) + ".log")
    width, height = job["size"]
    say(f"  filming {stem}  {width}x{height}  {job.get('seconds', 0):g}s" + ("  (still)" if still_only else ""))
    started = datetime.datetime.now()
    marks = run_godot(machine, job, log, sound=sound)
    sidecar_path = Path(str(base) + ".json")
    sidecar = json.loads(sidecar_path.read_text(encoding="utf-8")) if sidecar_path.exists() else {}
    sidecar.update(name=stem, shot=name, commit=git("rev-parse", "--short", "HEAD"), commit_time=int(git("log", "-1", "--format=%ct") or 0),
                   dirty=bool(git("status", "--porcelain", "--untracked-files=no")), filmed=started.isoformat(timespec="seconds"),
                   tags=sorted(set((tags or []) + [str(job.get(k)) for k in ("level", "car", "mode", "time", "profile") if job.get(k)])))
    made = []
    for still in sorted(work.glob(f"{stem}_t*.png")):
        target = dest / (f"{stem}.png" if still_only and len(job["stills"]) == 1 else still.name)
        shutil.move(still, target)
        made.append(target)
    if not still_only:
        frames = Path(str(base) + "_frames")
        count = len(list(frames.glob("f*.png")))
        if count == 0:
            raise Problem(f"No frames were filmed. The log is {log}")
        fps = int(sidecar.get("fps", 60))
        video, extension = master_args(alpha, machine.local.get("master") == "light" or getattr(args, "light", False))
        target = dest / (stem + extension)
        inputs = ["-framerate", str(fps), "-i", str(frames / "f%06d.png")]
        audio = []
        if sound and sound.exists() and sidecar.get("first_frame", -1) >= 0:
            inputs += ["-ss", f"{sidecar['first_frame'] / fps:.4f}", "-t", f"{count / fps:.4f}", "-i", str(sound)]
            audio = ["-map", "0:v", "-map", "1:a", "-c:a", "pcm_s16le"]
        ffmpeg_run(machine, [*inputs, *video, *audio, str(target)], "making the master")
        made.append(target)
        if not getattr(args, "keep", False):
            shutil.rmtree(frames, ignore_errors=True)
            if sound:
                sound.unlink(missing_ok=True)
        if sidecar.get("events"):
            markers = dest / (stem + ".edl")
            write_markers(sidecar, markers)
            made.append(markers)
    sidecar["files"] = [p.name for p in made]
    sidecar["seconds_to_film"] = int((datetime.datetime.now() - started).total_seconds())
    (dest / (stem + ".json")).write_text(json.dumps(sidecar), encoding="utf-8")
    sidecar_path.unlink(missing_ok=True)
    if "SCRIPT ERROR" not in log.read_text(encoding="utf-8", errors="replace"):
        log.unlink(missing_ok=True)
    drift = float(sidecar.get("drift_px", 0))
    if drift > 150:
        say(f"  WARNING: the replay drifted {drift:.0f} px from the taped drive, so it may not show what the driver saw")
    for path in made:
        say(f"    {path}")
    return made


def profile_job(job, profile):
    if profile not in PROFILES:
        raise Problem(f"Unknown size '{profile}'. Sizes: {', '.join(PROFILES)}")
    width, height = PROFILES[profile]
    merged = {**job, **job.get("per", {}).get(profile, {})}
    merged.pop("per", None)
    merged.pop("profiles", None)
    merged["size"] = [width, height]
    merged["profile"] = profile
    if width * 9 != height * 16 and "hud" not in merged:
        merged["hud"] = "off"
    merged.setdefault("audio", {"music": False})  # masters carry the game's effects; the song goes on in the edit
    if merged.get("kind") == "stage":
        merged.setdefault("alpha", merged.get("backdrop", "clear") == "clear")
        merged["hud"] = "full"
    if merged.get("layer") == "hud":  # the HUD alone, over nothing
        merged["alpha"] = True
        merged["hud"] = merged.get("hud") if merged.get("hud") in ("full", "minimal") else "full"
    return merged


def load_shots(name):
    path = Path(name)
    if not path.exists():
        path = PROMO / "shots" / (name if name.endswith(".json") else name + ".json")
    if not path.exists():
        have = ", ".join(sorted(p.stem for p in (PROMO / "shots").glob("*.json")))
        raise Problem(f"No shot file called '{name}'. In promo/shots: {have or 'none yet'}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise Problem(f"{path} is not valid JSON: {error}")
    return path.stem, data


def cmd_shot(args):
    machine = Machine().need(godot=True, ffmpeg=True)
    set_name, data = load_shots(args.file)
    defaults = data.get("defaults", {})
    shots = data.get("shots", [])
    wanted = [s for s in shots if not args.ids or s.get("id") in args.ids]
    missing = set(args.ids or []) - {s.get("id") for s in shots}
    if missing:
        raise Problem(f"No shot called {', '.join(sorted(missing))} in {set_name}. It has: {', '.join(s.get('id', '?') for s in shots)}")
    made = 0
    for shot in wanted:
        job = {**defaults, **shot}
        profiles = args.profile.split(",") if args.profile else job.get("profiles", ["wide1080"])
        still = float(job.get("seconds", 10)) <= 0
        element = job.get("kind") == "stage" or job.get("layer") == "hud" or job.get("alpha")
        dest = machine.folder(job.get("dest", "stills" if still else ("elements" if element else "masters")))
        for profile in profiles:
            film(machine, profile_job(job, profile), f"{set_name}_{shot['id']}_{profile}", dest, args, tags=[set_name] + job.get("tags", []))
            made += 1
    say(f"Done: {made} take(s). Review them with: python promo/tools/capture.py gallery")


def cmd_quick(args):
    """One shot straight from the command line, for a quick grab."""
    machine = Machine().need(godot=True, ffmpeg=True)
    job = {"level": args.level, "car": args.car, "mode": args.mode, "tier": args.tier, "seed": args.seed, "time": args.time,
           "driver": args.driver, "lead": args.lead, "seconds": args.seconds, "god": not args.mortal, "upgrades": args.upgrades}
    if args.hud:
        job["hud"] = args.hud
    if args.zoom:
        job["camera"] = {"rig": "follow", "zoom": args.zoom}
    if args.music:
        job["audio"] = {"music": True}
    for key in PASS_THROUGH:
        if getattr(args, key, None):
            job[key] = getattr(args, key)
    still = args.seconds <= 0
    dest = machine.folder("stills" if still else "masters")
    for profile in args.profile.split(","):
        film(machine, profile_job(job, profile), f"quick_{args.level}_{args.car}_{args.time}_{profile}", dest, args, tags=["quick"])


# --- hand drives -----------------------------------------------------------------------------------

def tape_path(name):
    path = Path(name)
    if path.suffix != ".tape":
        path = PROMO / "tapes" / f"{name}.tape"
    return path


def read_tape_header(path):
    if not path.exists():
        have = ", ".join(sorted(p.stem for p in (PROMO / "tapes").glob("*.tape")))
        raise Problem(f"No taped drive at {path}. In promo/tapes: {have or 'none yet'}")
    with open(path, encoding="utf-8") as handle:
        return json.loads(handle.readline())


def cmd_hand(args):
    machine = Machine().need(godot=True, out=False)
    path = tape_path(args.name)
    if path.exists() and not args.overwrite:
        raise Problem(f"{path.relative_to(REPO)} already exists. Pick another name, or add --overwrite to tape over it.")
    job = {"kind": "hand", "tape": path.as_posix(), "level": args.level, "car": args.car, "mode": args.mode, "tier": args.tier,
           "seed": args.seed, "time": args.time, "upgrades": args.upgrades, "god": args.god, "size": [int(v) for v in args.window.split("x")],
           "hud": "full"}
    for key in PASS_THROUGH:
        if getattr(args, key, None):
            job[key] = getattr(args, key)
    say(f"Taping a drive to {path.relative_to(REPO)}")
    say("  Drive as you normally would. F9 (or click the right stick) bookmarks a good moment. F10 finishes.")
    work = REPO / ".godot"  # the log only; nothing is filmed in a hand session
    marks = run_godot(machine, job, work / "capture_hand.log")
    header = read_tape_header(path)
    say(f"Taped {header['ticks'] / 60:.0f} s with {len(header.get('bookmarks', []))} bookmark(s).")
    for index, mark in enumerate(header.get("bookmarks", []), 1):
        say(f"  mark {index}: {mark['tick'] / 60:.1f} s")
    say(f"Film it with: python promo/tools/capture.py replay {path.stem} --mark 1 --profile wide4k")


def cmd_replay(args):
    machine = Machine().need(godot=True, ffmpeg=True)
    path = tape_path(args.name)
    header = read_tape_header(path)
    marks = header.get("bookmarks", [])
    length = header["ticks"] / 60.0
    windows = []
    if args.whole:
        windows.append(("whole", 0.0, length))
    elif args.start is not None:
        windows.append((f"at{int(args.start)}", args.start, min(args.start + (args.seconds or 10.0), length)))
    else:
        chosen = range(1, len(marks) + 1) if not args.mark else args.mark
        if not marks:
            raise Problem("This drive has no bookmarks. Film a stretch with --start <seconds> --seconds <length>, or all of it with --whole.")
        for number in chosen:
            if number < 1 or number > len(marks):
                raise Problem(f"This drive has {len(marks)} bookmark(s); there is no mark {number}.")
            at = marks[number - 1]["tick"] / 60.0
            windows.append((f"mark{number}", max(at - args.before, 0.0), min(at + args.after, length)))
    base = {k: v for k, v in header.items() if k not in ("ticks", "bookmarks")}
    base.update(kind="shot", driver="tape", tape=path.as_posix(), god=header.get("god", False))
    if args.hud:
        base["hud"] = args.hud
    if args.camera:
        base["camera"] = json.loads(args.camera)
    if args.music:
        base["audio"] = {"music": True}
    dest = machine.folder("masters")
    for label, start, end in windows:
        job = {**base, "lead": start, "seconds": round(end - start, 3)}
        for profile in args.profile.split(","):
            if profile not in PROFILES:
                raise Problem(f"Unknown size '{profile}'. Sizes: {', '.join(PROFILES)}")
            width, height = PROFILES[profile]
            if width * 9 == height * 16:
                film(machine, profile_job(job, profile), f"hand_{path.stem}_{label}_{profile}", dest, args, tags=["hand", path.stem])
                continue
            # What the goons do depends on how much of the world is on screen, so a tall frame would not replay
            # the drive that was taped. A tall take is filmed wide at its own height, then cut out round the car.
            wide = profile_job({**job, "hud": "off"}, "wide1080")
            wide["size"] = [-(-height * 16 // 9 // 2) * 2, height]
            made = film(machine, wide, f"hand_{path.stem}_{label}_widefor", dest, args, tags=["hand", path.stem])
            source = next(p for p in made if p.suffix in (".mov", ".mp4"))
            target = reframe_file(machine, source, profile, light=getattr(args, "light", False))
            say(f"    {target}")
            if not args.keep:
                for leftover in source.parent.glob(source.stem + ".*"):
                    leftover.unlink()


# --- the AI stock library ----------------------------------------------------------------------

def cmd_stock(args):
    machine = Machine().need(godot=True, ffmpeg=True)
    levels = LEVELS if args.levels == "all" else args.levels.split(",")
    cars = CARS if args.cars == "all" else args.cars.split(",")
    times = args.times.split(",")
    dest = machine.folder("stock")
    seeds = {}
    seed_file = PROMO / "seeds" / "hero_seeds.json"
    if seed_file.exists():
        seeds = json.loads(seed_file.read_text(encoding="utf-8"))
    made = skipped = 0
    for index, level in enumerate(levels):
        if level not in LEVELS:
            raise Problem(f"Unknown level '{level}'. Levels: {', '.join(LEVELS)}")
        for time_index, time_of_day in enumerate(times):
            car = cars[(index * len(times) + time_index) % len(cars)]  # every car gets its turn across the library
            for profile in args.profile.split(","):
                name = f"stock_{level}_{car}_{time_of_day}_{profile}"
                if list(dest.glob(name + "_v*.json")) and not args.redo:
                    skipped += 1
                    continue
                seed = (seeds.get(level) or [{"seed": args.seed}])[0]["seed"]
                job = {"level": level, "car": car, "mode": "countdown", "time": time_of_day, "driver": "ai", "seed": seed,
                       "lead": args.lead, "seconds": args.seconds, "god": True, "upgrades": 8, "hud": args.hud}
                try:
                    film(machine, profile_job(job, profile), name, dest, args, tags=["stock"])
                    made += 1
                except Problem as problem:
                    say(f"  skipped {name}: {problem}")
    say(f"Stock library: {made} new clip(s), {skipped} already there (add --redo to film them again).")


def cmd_seeds(args):
    """Hero seeds: play each level on several maps with the AI and keep the liveliest."""
    machine = Machine().need(godot=True, out=False)
    levels = LEVELS if args.levels == "all" else args.levels.split(",")
    seed_file = PROMO / "seeds" / "hero_seeds.json"
    seed_file.parent.mkdir(exist_ok=True)
    best = json.loads(seed_file.read_text(encoding="utf-8")) if seed_file.exists() else {}
    log = REPO / ".godot" / "capture_seeds.log"
    for level in levels:
        say(f"  trying {args.runs} maps of {level} ...")
        command = [machine.godot, "--headless", "--fixed-fps", "60", "--path", str(REPO), "--", "--playtest", "--uncapped",
                   "--mode=countdown", f"--level={level}", "--car=sedan", f"--runs={args.runs}", f"--seed={args.seed}",
                   f"--max-seconds={args.seconds}", "--upgrades=8", "--profiles=cautious", "--tag=heroseeds"]
        with open(log, "w", encoding="utf-8", errors="replace") as handle:
            subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT)
        rows = []
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("PLAYTEST_RESULT"):
                try:
                    rows.append(json.loads(line.split(" ", 1)[1]))
                except (json.JSONDecodeError, IndexError):
                    pass
        if not rows:
            say(f"    no results for {level} (see {log})")
            continue
        # lively and readable: plenty of crushes, pickups and distance, and a car that survives to show it
        def score(row):
            return float(row.get("crushed", 0)) + 0.002 * float(row.get("distance_px", 0)) + 3 * float(row.get("slot_machines", 0)) - 40 * float(row.get("stuck", 0)) - (60 if float(row.get("end_health", 1)) <= 0 else 0)
        rows.sort(key=score, reverse=True)
        best[level] = [{"seed": int(r["seed"]), "score": round(score(r), 1), "crushed": int(float(r.get("crushed", 0)))} for r in rows[:3]]
        say(f"    best seed {best[level][0]['seed']} ({best[level][0]['crushed']} crushed)")
        seed_file.write_text(json.dumps(best, indent=1) + "\n", encoding="utf-8")
    say(f"Saved to {seed_file.relative_to(REPO)}. The stock library films these maps first.")


def cmd_panorama(args):
    """A wide picture of the world round a level's start: the game films it in tiles and ffmpeg joins them."""
    machine = Machine().need(godot=True, ffmpeg=True)
    across, down = (int(v) for v in args.tiles.lower().split("x"))
    width, height = PROFILES[args.profile]
    dest = machine.folder("stills")
    stem = next_version(dest, f"panorama_{args.level}_{across}x{down}")
    base = machine.folder("work") / stem
    job = {"kind": "survey", "out": base.as_posix(), "size": [width, height], "profile": args.profile, "level": args.level, "car": "sedan",
           "seed": args.seed, "time": args.time, "tiles": [across, down], "zoom": args.zoom, "lead": 1.0, "hud": "off", "god": True,
           "record": "none", "crowd": {"floor": False, "spawnTimer": 9999.0, "escalation": 0.0}, "audio": {"music": False}}
    if args.landscape:
        job["landscape"] = args.landscape
    say(f"  surveying {args.level}: {across}x{down} tiles of {width}x{height}")
    log = Path(str(base) + ".log")
    run_godot(machine, job, log)
    tiles = sorted(base.parent.glob(stem + "_tile*.png"))
    if len(tiles) != across * down:
        raise Problem(f"Only {len(tiles)} of {across * down} tiles were filmed. The log is {log}")
    target = dest / (stem + ".png")
    ffmpeg_run(machine, ["-framerate", "1", "-i", str(base) + "_tile%03d.png", "-vf", f"tile={across}x{down}", "-frames:v", "1", str(target)], "joining the tiles")
    for tile in tiles:
        tile.unlink()
    Path(str(base) + ".json").unlink(missing_ok=True)
    log.unlink(missing_ok=True)
    meta = {"name": stem, "job": job, "size": [width * across, height * down], "files": [target.name], "tags": ["panorama", args.level, args.time],
            "commit": git("rev-parse", "--short", "HEAD"), "commit_time": int(git("log", "-1", "--format=%ct") or 0),
            "filmed": datetime.datetime.now().isoformat(timespec="seconds")}
    (dest / (stem + ".json")).write_text(json.dumps(meta), encoding="utf-8")
    say(f"    {target}  ({width * across}x{height * down})")


# --- interface pieces, titles and line-ups --------------------------------------------------------

def cmd_stage(args):
    machine = Machine().need(godot=True, ffmpeg=True)
    job = {"kind": "stage", "stage": args.stage, "seconds": args.seconds, "lead": args.lead, "backdrop": args.backdrop,
           "alpha": args.backdrop == "clear", "sound": False}
    for pair in args.set or []:
        key, _, value = pair.partition("=")
        try:
            job[key] = json.loads(value)
        except json.JSONDecodeError:
            job[key] = value
    name = args.name or "_".join([args.stage] + [re.sub(r"[^a-z0-9]+", "", str(job[k]).lower())[:24] for k in ("piece", "text", "what") if job.get(k)])
    dest = machine.folder("elements" if args.seconds > 0 else "stills")
    for profile in args.profile.split(","):
        merged = profile_job(job, profile)
        merged["hud"] = "full"
        film(machine, merged, f"{name}_{profile}", dest, args, tags=["element", args.stage])


# --- finishing ---------------------------------------------------------------------------------------

# name -> (what it is for, ffmpeg video filter or None, video arguments, extension)
DELIVERIES = {
    "steam": ("Steam store trailer, 1080p", "scale=1920:1080:flags=lanczos", ["-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "youtube4k": ("YouTube, 4K", "scale=3840:2160:flags=lanczos", ["-c:v", "libx264", "-crf", "15", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "youtube": ("YouTube, 1080p", "scale=1920:1080:flags=lanczos", ["-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "vertical": ("Shorts, Reels, TikTok: 1080x1920", "scale=1080:1920:force_original_aspect_ratio=decrease:flags=lanczos,pad=1080:1920:(ow-iw)/2:(oh-ih)/2", ["-c:v", "libx264", "-crf", "18", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "square": ("feed posts, 1080x1080", "scale=1080:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1080:1080:(ow-iw)/2:(oh-ih)/2", ["-c:v", "libx264", "-crf", "18", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "x": ("X / Twitter, 720p", "scale=1280:720:force_original_aspect_ratio=decrease:flags=lanczos,pad=1280:720:(ow-iw)/2:(oh-ih)/2", ["-c:v", "libx264", "-crf", "20", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "discord": ("Discord, small file", "scale=1280:-2:flags=lanczos", ["-c:v", "libx264", "-crf", "26", "-preset", "slow", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
    "preview": ("a small copy for the review page", "scale=-2:360", ["-c:v", "libx264", "-crf", "27", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], ".mp4"),
}


def find_media(machine, name):
    path = Path(name)
    if path.exists():
        return path
    for folder in ("masters", "stock", "elements", "deliverables", "stills"):
        hits = sorted((machine.out / folder).glob(f"**/{name}*"))
        hits = [h for h in hits if h.suffix in (".mov", ".mp4", ".png")]
        if hits:
            return hits[-1]
    raise Problem(f"Can't find '{name}'. Give a file path, or the name of a take in the output folder (see the gallery).")


def cmd_encode(args):
    machine = Machine().need(ffmpeg=True)
    source = find_media(machine, args.source)
    for preset in args.preset.split(","):
        dest = machine.folder("deliverables") / preset
        dest.mkdir(exist_ok=True)
        if preset in ("gif", "webp"):
            target = dest / (source.stem + "." + preset)
            width = args.width or 480
            chain = f"fps={args.fps or 20},scale={width}:-1:flags=lanczos"
            if preset == "gif":
                ffmpeg_run(machine, ["-i", str(source), "-vf", f"{chain},split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4", "-loop", "0", str(target)], "making the GIF")
            else:
                ffmpeg_run(machine, ["-i", str(source), "-vf", chain, "-c:v", "libwebp", "-lossless", "0", "-q:v", "70", "-loop", "0", "-an", str(target)], "making the WebP")
        elif preset in DELIVERIES:
            _, vf, video, extension = DELIVERIES[preset]
            target = dest / (source.stem + extension)
            ffmpeg_run(machine, ["-i", str(source), "-vf", vf + ",format=yuv420p", *video, "-c:a", "aac", "-b:a", "256k", str(target)], f"encoding for {preset}")
        else:
            raise Problem(f"Unknown preset '{preset}'. Presets: {', '.join(list(DELIVERIES) + ['gif', 'webp'])}")
        say(f"  {target}  ({target.stat().st_size / 1e6:.1f} MB)")


def sidecar_for(media):
    path = media.with_suffix(".json")
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def reframe_file(machine, source, to, smooth=1.0, light=False):
    """Cuts a tall or square clip out of a wide one, keeping the car in frame (it follows the sidecar's track)."""
    sidecar = sidecar_for(source)
    if not sidecar or not sidecar.get("track"):
        raise Problem(f"{source.name} has no sidecar track beside it, so there is nothing to follow.")
    if to not in ("vertical", "square", "portrait45"):
        raise Problem("Reframe to: vertical, square or portrait45")
    width, height = sidecar["size"]
    fps = int(sidecar.get("fps", 60))
    out_w, out_h = PROFILES[to]
    crop_w = min(int(height * out_w / out_h) // 2 * 2, width)
    xs = [sidecar["track"][i] * width for i in range(0, len(sidecar["track"]), 2)]
    window = max(int(fps * smooth), 1)
    glide, total = [], 0.0
    for i, x in enumerate(xs):  # a moving average, so the crop glides instead of twitching with the car
        total += x
        if i >= window:
            total -= xs[i - window]
        glide.append(total / min(i + 1, window))
    commands = machine.folder("work") / (source.stem + "_crop.txt")
    with open(commands, "w", encoding="utf-8") as handle:
        for i, x in enumerate(glide):
            left = min(max(int(x - crop_w / 2), 0), width - crop_w)
            handle.write(f"{i / fps:.4f} crop x {left};\n")
    video, extension = master_args(False, machine.local.get("master") == "light" or light)
    escaped = commands.as_posix().replace(":", "\\:")  # the drive letter's colon, inside a filter argument
    chain = f"sendcmd=f='{escaped}',crop={crop_w}:{height}:0:0,scale={out_w}:{out_h}:flags=lanczos:out_color_matrix=bt709:out_range=tv"
    video = [chain if a.startswith("scale=out_color") else a for a in video]
    stem = re.sub(r"_v\d+$", "", source.stem)
    stem = re.sub(r"_widefor$", "", stem) + (f"_{to}" if stem.endswith("_widefor") else f"_to{to}")
    target = source.with_name(next_version(source.parent, stem) + extension)
    ffmpeg_run(machine, ["-i", str(source), *video, "-c:a", "copy", str(target)], "reframing")
    commands.unlink(missing_ok=True)
    meta = {**sidecar, "name": target.stem, "size": [out_w, out_h], "files": [target.name],
            "tags": sorted(set([t for t in sidecar.get("tags", []) if not t.startswith("wide")] + ["reframed", to]))}
    meta.pop("track", None)
    target.with_suffix(".json").write_text(json.dumps(meta), encoding="utf-8")
    if sidecar.get("events"):
        write_markers(sidecar, target.with_suffix(".edl"))
    return target


def cmd_reframe(args):
    machine = Machine().need(ffmpeg=True)
    target = reframe_file(machine, find_media(machine, args.source), args.to, args.smooth, args.light)
    say(f"  {target}")


def cmd_slowmo(args):
    """Slow a clip down with in-between frames (the game's physics can't run slower, so this is done after filming)."""
    machine = Machine().need(ffmpeg=True)
    source = find_media(machine, args.source)
    sidecar = sidecar_for(source) or {}
    fps = int(sidecar.get("fps", 60))
    video, extension = master_args(False, machine.local.get("master") == "light" or args.light)
    cut = (["-ss", str(args.start)] if args.start else []) + (["-t", str(args.seconds)] if args.seconds else [])
    chain = f"minterpolate=fps={fps * args.factor}:mi_mode=mci:mc_mode=aobmc:vsbmc=1,setpts={args.factor}*PTS,fps={fps}"
    video = [a if not a.startswith("scale=out_color") else chain + "," + a for a in video]
    target = source.with_name(next_version(source.parent, re.sub(r"_v\d+$", "", source.stem) + f"_slow{args.factor}") + extension)
    say("  working out the in-between frames (slow: about a second a frame at 4K) ...")
    ffmpeg_run(machine, [*cut, "-i", str(source), *video, "-an", str(target)], "making slow motion")
    meta = {**sidecar, "name": target.stem, "files": [target.name], "tags": sorted(set(sidecar.get("tags", []) + ["slowmo"]))}
    meta.pop("track", None)
    meta.pop("events", None)
    target.with_suffix(".json").write_text(json.dumps(meta), encoding="utf-8")
    say(f"  {target}")


def cmd_song(args):
    """A radio song as a WAV for the edit (the game's own music; the studio owns it)."""
    machine = Machine().need(ffmpeg=True)
    songs = sorted((REPO / "sound" / "radio").glob("*/songs/*.ogg")) + sorted((REPO / "sound" / "radio").glob("*/songs/*.mp3"))
    if not args.name:
        for song in songs:
            say(f"  {song.parent.parent.name}/{song.stem}")
        say("Copy one out with: python promo/tools/capture.py song <name>")
        return
    hits = [s for s in songs if args.name.lower() in s.stem.lower()]
    if not hits:
        raise Problem(f"No song matching '{args.name}'. Run `song` with no name to list them.")
    dest = machine.folder("audio")
    for song in hits:
        target = dest / (song.stem + ".wav")
        ffmpeg_run(machine, ["-i", str(song), "-c:a", "pcm_s16le", "-ar", "48000", str(target)], "converting the song")
        say(f"  {target}")


# --- the review page -------------------------------------------------------------------------------

ART_PATHS = ["scene/car", "scene/enemy", "texture", "world", "scene/pickups", "scene/player/hud"]


def cmd_gallery(args):
    machine = Machine().need(ffmpeg=True)
    thumbs = machine.folder("work") / "gallery"
    thumbs.mkdir(exist_ok=True)
    art_time = int(git("log", "-1", "--format=%ct", "--", *ART_PATHS) or 0)
    head = git("rev-parse", "--short", "HEAD")
    cards = []
    for folder in ("masters", "stock", "elements", "stills", "deliverables"):
        for meta_path in sorted((machine.out / folder).glob("**/*.json")):
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            media = [meta_path.parent / f for f in meta.get("files", []) if Path(f).suffix in (".mov", ".mp4", ".png")]
            media = [m for m in media if m.exists()]
            if not media:
                continue
            main = media[0]
            preview = None
            if main.suffix == ".png":
                preview = main
            else:
                preview = thumbs / (main.stem + ".mp4")
                if not preview.exists() or preview.stat().st_mtime < main.stat().st_mtime:
                    say(f"  preview for {main.name}")
                    # transparent pieces are shown over grey, as an editor would see them on a neutral plate
                    vf = "scale=-2:360,format=yuv420p" if not meta.get("job", {}).get("alpha") else "split[a][b];[a]drawbox=c=0x777777:t=fill[bg];[bg][b]overlay,scale=-2:360,format=yuv420p"
                    try:
                        ffmpeg_run(machine, ["-i", str(main), "-filter_complex" if "split" in vf else "-vf", vf, "-c:v", "libx264", "-crf", "27", "-preset", "veryfast", "-an", "-movflags", "+faststart", str(preview)], "making a preview")
                    except Problem as problem:
                        say(f"    {problem}")
                        continue
            job = meta.get("job", {})
            stale = art_time and meta.get("commit_time", 0) and meta["commit_time"] < art_time
            cards.append({"folder": folder, "name": meta.get("name", main.stem), "preview": preview.as_uri(), "still": main.suffix == ".png",
                          "path": str(main), "tags": meta.get("tags", []), "size": "x".join(str(v) for v in meta.get("size", job.get("size", []))),
                          "seconds": round(meta.get("frames", 0) / max(int(meta.get("fps", 60)), 1), 1), "commit": meta.get("commit", ""),
                          "filmed": meta.get("filmed", ""), "stale": bool(stale), "dirty": bool(meta.get("dirty")),
                          "crushed": meta.get("crushed", 0), "events": len(meta.get("events", [])),
                          "detail": {k: job[k] for k in ("level", "car", "mode", "tier", "seed", "time", "driver", "hud", "landscape") if k in job}})
    page = machine.out / "gallery.html"
    page.write_text(GALLERY.replace("/*CARDS*/", json.dumps(cards)).replace("{HEAD}", html.escape(head)).replace("{WHEN}", datetime.datetime.now().strftime("%d %b %Y %H:%M")), encoding="utf-8")
    say(f"Gallery: {page}  ({len(cards)} item(s))")
    if not args.no_open:
        webbrowser.open(page.as_uri())


GALLERY = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GoonCrusher capture gallery</title><style>
:root{--bg:#12171d;--panel:#1b222b;--ink:#e6ebf0;--muted:#9aa7b5;--line:#323c48;--accent:#7db6f2;--warn:#f0c661}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 "Segoe UI",system-ui,sans-serif}
header{position:sticky;top:0;background:var(--bg);border-bottom:1px solid var(--line);padding:14px 20px;display:flex;flex-wrap:wrap;gap:12px;align-items:center;z-index:2}
h1{font-size:18px;margin:0 12px 0 0}input,select{background:var(--panel);color:var(--ink);border:1px solid var(--line);border-radius:4px;padding:7px 9px;font:inherit}
input{min-width:240px}.sub{color:var(--muted);font-size:12.5px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:16px;padding:20px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:6px;overflow:hidden;display:flex;flex-direction:column}
.card video,.card img{width:100%;aspect-ratio:16/9;object-fit:contain;background:#000;display:block}
.body{padding:10px 12px;display:flex;flex-direction:column;gap:6px}.name{font-weight:600;word-break:break-all}
.tags{display:flex;flex-wrap:wrap;gap:5px}.tag{font-size:11.5px;padding:2px 6px;border-radius:3px;background:#263447;color:var(--accent);cursor:pointer}
.stale{background:#3b3012;color:var(--warn)}.path{font:11.5px Consolas,monospace;color:var(--muted);word-break:break-all;cursor:pointer}
.path:hover{color:var(--ink)}.empty{padding:40px 20px;color:var(--muted)}
</style></head><body><header><h1>Capture gallery</h1><input id="q" placeholder="Search: level, car, night, vertical, hand ..." autofocus>
<select id="folder"><option value="">Everything</option><option>masters</option><option>stock</option><option>elements</option><option>stills</option><option>deliverables</option></select>
<span class="sub" id="count"></span><span class="sub">built {WHEN} at commit {HEAD}. Click a path to copy it.</span></header><main id="grid"></main>
<script>
const cards=/*CARDS*/;const grid=document.getElementById('grid'),q=document.getElementById('q'),folder=document.getElementById('folder');
function esc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function draw(){const words=q.value.toLowerCase().split(/\\s+/).filter(Boolean);
const shown=cards.filter(c=>(!folder.value||c.folder===folder.value)&&words.every(w=>(c.name+' '+c.tags.join(' ')+' '+c.size+' '+JSON.stringify(c.detail)).toLowerCase().includes(w)));
document.getElementById('count').textContent=shown.length+' of '+cards.length;
grid.innerHTML=shown.length?shown.map(c=>`<div class="card">${c.still?`<img loading="lazy" src="${c.preview}">`:`<video src="${c.preview}" preload="metadata" controls muted loop></video>`}
<div class="body"><div class="name">${esc(c.name)}</div><div class="tags">${c.tags.map(t=>`<span class="tag" data-t="${esc(t)}">${esc(t)}</span>`).join('')}${c.stale?'<span class="tag stale" title="Filmed before the latest art change">stale art</span>':''}${c.dirty?'<span class="tag stale" title="Filmed with uncommitted changes">uncommitted</span>':''}</div>
<div class="sub">${c.size}${c.seconds?' · '+c.seconds+' s':''}${c.crushed?' · '+c.crushed+' crushed':''}${c.events?' · '+c.events+' markers':''} · ${esc(c.commit)} · ${esc(c.filmed.replace('T',' '))}</div>
<div class="sub">${esc(Object.entries(c.detail).map(([k,v])=>k+' '+v).join(' · '))}</div><div class="path" data-p="${esc(c.path)}">${esc(c.path)}</div></div></div>`).join(''):'<div class="empty">Nothing matches. Film something with capture.py, then build the gallery again.</div>'}
grid.addEventListener('click',e=>{const t=e.target;if(t.dataset.t){q.value=t.dataset.t;draw()}if(t.dataset.p){navigator.clipboard&&navigator.clipboard.writeText(t.dataset.p);t.textContent='copied: '+t.dataset.p}});
q.addEventListener('input',draw);folder.addEventListener('change',draw);draw();
</script></body></html>"""


# --- the command line ------------------------------------------------------------------------------

def run_options(parser, driver="ai"):
    parser.add_argument("--level", default="prairie", help="a level id: " + ", ".join(LEVELS[:6]) + " ...")
    parser.add_argument("--car", default="sedan", choices=CARS)
    parser.add_argument("--mode", default="countdown", help="countdown, sprint, marathon, defense, goonpocalypse ...")
    parser.add_argument("--tier", default="easy", choices=["easy", "medium", "hard"])
    parser.add_argument("--seed", type=int, default=1, help="which map (same seed, same map)")
    parser.add_argument("--time", default="day", choices=["day", "night", "cycle"])
    parser.add_argument("--upgrades", type=int, default=8, help="every stat at this level (0 to 20)")
    for key in PASS_THROUGH:
        parser.add_argument(f"--{key}", help=f"the game's own --{key}= option")
    if driver:
        parser.add_argument("--driver", default=driver, help="ai, pattern:sine, pattern:circle, pattern:straight or none")


def film_options(parser):
    parser.add_argument("--profile", default=None, help="sizes, comma separated: " + ", ".join(list(PROFILES)[:7]) + " ...")
    parser.add_argument("--keep", action="store_true", help="keep the raw frames in the work folder")
    parser.add_argument("--light", action="store_true", help="H.264 masters instead of ProRes (much smaller files)")
    parser.add_argument("--silent", action="store_true", help="no sound in the master")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)

    p = commands.add_parser("doctor", help="check this machine and choose the output folder")
    p.add_argument("--out", help="the output folder (outside the repo)")
    p.add_argument("--godot", help="path to Godot_v4.7.2-stable_win64_console.exe")
    p.add_argument("--native", help="a folder holding the game's two native .dll files, to copy into bin/windows")
    p.add_argument("--fix", action="store_true", help="install what can be installed (ffmpeg)")
    p.set_defaults(run=cmd_doctor)

    p = commands.add_parser("shot", help="film the shots in a shot file (promo/shots/<name>.json)")
    p.add_argument("file")
    p.add_argument("ids", nargs="*", help="only these shots")
    film_options(p)
    p.set_defaults(run=cmd_shot)

    p = commands.add_parser("quick", help="film one shot described on the command line")
    run_options(p)
    film_options(p)
    p.set_defaults(profile="wide1080")
    p.add_argument("--seconds", type=float, default=10.0, help="how long to film (0 = one still)")
    p.add_argument("--lead", type=float, default=4.0, help="seconds of driving before filming starts")
    p.add_argument("--hud", choices=["full", "minimal", "off"])
    p.add_argument("--zoom", type=float, help="hold the camera at this zoom (the game's own is 0.45; smaller is further out)")
    p.add_argument("--mortal", action="store_true", help="the car can be hurt and run dry (it can't by default)")
    p.add_argument("--music", action="store_true", help="keep the radio in the sound")
    p.set_defaults(run=cmd_quick)

    p = commands.add_parser("hand", help="drive by hand and tape it (promo/tapes/<name>.tape)")
    p.add_argument("name")
    run_options(p, driver=None)
    p.add_argument("--window", default="1600x900")
    p.add_argument("--god", action="store_true", help="the car can't be hurt or run dry")
    p.add_argument("--overwrite", action="store_true")
    p.set_defaults(run=cmd_hand)

    p = commands.add_parser("replay", help="film a taped drive: its bookmarks, a stretch, or all of it")
    p.add_argument("name")
    p.add_argument("--mark", type=int, nargs="*", help="bookmark numbers (default: all of them)")
    p.add_argument("--before", type=float, default=5.0, help="seconds before a bookmark")
    p.add_argument("--after", type=float, default=5.0, help="seconds after a bookmark")
    p.add_argument("--start", type=float, help="film from this second of the drive")
    p.add_argument("--seconds", type=float, help="with --start: how long")
    p.add_argument("--whole", action="store_true", help="film the whole drive")
    p.add_argument("--hud", choices=["full", "minimal", "off"])
    p.add_argument("--camera", help='a camera rig as JSON, e.g. {"rig":"follow","zoom":0.6}')
    p.add_argument("--music", action="store_true")
    film_options(p)
    p.set_defaults(profile="wide1080", run=cmd_replay)

    p = commands.add_parser("stock", help="the AI stock library: every level by day and by night")
    p.add_argument("--levels", default="all")
    p.add_argument("--cars", default="all")
    p.add_argument("--times", default="day,night")
    p.add_argument("--seconds", type=float, default=20.0)
    p.add_argument("--lead", type=float, default=12.0)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--hud", default="off", choices=["full", "minimal", "off"])
    p.add_argument("--redo", action="store_true", help="film clips that are already in the library again")
    film_options(p)
    p.set_defaults(profile="wide1080", run=cmd_stock)

    p = commands.add_parser("seeds", help="find each level's liveliest maps with the AI (promo/seeds/hero_seeds.json)")
    p.add_argument("--levels", default="all")
    p.add_argument("--runs", type=int, default=6)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--seconds", type=int, default=90)
    p.set_defaults(run=cmd_seeds)

    p = commands.add_parser("stage", help="an interface piece, a title or a line-up on a plain backdrop (promo/stages/)")
    p.add_argument("stage", help="title, lineup, transition, keyart, safezone, endcard, menu or a res:// scene")
    p.add_argument("--set", action="append", metavar="key=value", help="what the stage shows, e.g. --set piece=results --set text=\"43 GOONS\"")
    p.add_argument("--backdrop", default="clear", choices=["clear", "magenta", "grey", "black"])
    p.add_argument("--seconds", type=float, default=4.0, help="0 = one still")
    p.add_argument("--lead", type=float, default=0.0)
    p.add_argument("--name")
    film_options(p)
    p.set_defaults(profile="wide1080", run=cmd_stage)

    p = commands.add_parser("panorama", help="a wide still of the world round a level's start, joined from tiles")
    p.add_argument("--level", default="prairie")
    p.add_argument("--tiles", default="4x3", help="across x down")
    p.add_argument("--zoom", type=float, default=0.25, help="smaller shows more world per tile (the game's own is 0.45)")
    p.add_argument("--profile", default="wide1080", help="each tile's size")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--time", default="day", choices=["day", "night"])
    p.add_argument("--landscape")
    p.set_defaults(run=cmd_panorama)

    p = commands.add_parser("encode", help="a finished cut (or any take) in a platform's upload format")
    p.add_argument("source", help="a file, or a take's name")
    p.add_argument("--preset", default="steam", help=", ".join(list(DELIVERIES) + ["gif", "webp"]))
    p.add_argument("--width", type=int, help="gif/webp: pixels wide (default 480)")
    p.add_argument("--fps", type=int, help="gif/webp: frames a second (default 20)")
    p.set_defaults(run=cmd_encode)

    p = commands.add_parser("reframe", help="cut a vertical or square clip out of a wide master, following the car")
    p.add_argument("source")
    p.add_argument("--to", default="vertical", choices=["vertical", "square", "portrait45"])
    p.add_argument("--smooth", type=float, default=1.0, help="seconds the crop takes to catch the car")
    p.add_argument("--light", action="store_true")
    p.set_defaults(run=cmd_reframe)

    p = commands.add_parser("slowmo", help="slow a clip down with in-between frames")
    p.add_argument("source")
    p.add_argument("--factor", type=int, default=4)
    p.add_argument("--start", type=float, help="from this second of the clip")
    p.add_argument("--seconds", type=float, help="this much of the clip")
    p.add_argument("--light", action="store_true")
    p.set_defaults(run=cmd_slowmo)

    p = commands.add_parser("song", help="list the radio songs, or copy one out as a WAV")
    p.add_argument("name", nargs="?")
    p.set_defaults(run=cmd_song)

    p = commands.add_parser("gallery", help="build the review page of everything filmed, and open it")
    p.add_argument("--no-open", action="store_true")
    p.set_defaults(run=cmd_gallery)

    args = parser.parse_args()
    try:
        return args.run(args) or 0
    except Problem as problem:
        say(f"\nCan't do that: {problem}")
        return 1
    except KeyboardInterrupt:
        say("\nStopped.")
        return 130


if __name__ == "__main__":
    sys.exit(main())
