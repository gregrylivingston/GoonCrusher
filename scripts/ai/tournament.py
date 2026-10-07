"""AI driver tournament: plays several AI profiles on the same seeds and ranks them per mode.

    python scripts/ai/tournament.py --profiles default,v1,crusher --runs 6
    python scripts/ai/tournament.py --profiles "default,default+horizonTicks=120" --modes sprint --runs 10

Profiles are AIProfiles specs (scripts/ai/ai_profiles.gd): a name, optionally followed by
+key=value overrides. Every profile plays every mode on the same seeds (--seed, --seed+1, ...), so
they meet the same maps. Each profile x mode is one headless Godot process (--parallel at a time);
its log and CSV go to %APPDATA%/GoonCrusher/playtest/. The score is recomputed here from each
run's fields (run_score, the same formula as runScore in scripts/debug/playtest.gd), so an old
tournament can be ranked again under a new score:
    python scripts/ai/tournament.py --rerank %APPDATA%/GoonCrusher/playtest/tournament_round1.csv
docs/AI_DRIVER.md explains the rest.
"""

import argparse
import csv
import math
import os
import statistics
import subprocess
import sys
import time

DEFAULT_GODOT = r"C:/Users/Greg/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "GoonCrusher", "playtest")


def number(row, key):
    try:
        return float(row.get(key) or 0)
    except ValueError:
        return 0.0


def run_score(row):
    """Coins, since payout buys cars and upgrades, plus the mode's own result (runScore in playtest.gd)."""
    clock = max(number(row, "clock"), 1.0)
    coins = 30.0 * math.log10(1.0 + max(number(row, "payout"), 0.0))
    won = row.get("won") == "true"
    if row["mode"] == "gooncrusher":
        return coins + 50.0 * min(number(row, "level_time") / clock, 1.0)
    if row["mode"] in ("sprint", "marathon"):
        if won:
            return coins + 50.0 + 25.0 * number(row, "time_left") / clock
        return coins + 25.0 * min(max(1.0 - number(row, "station_left_px") / max(number(row, "station_px"), 1.0), 0.0), 1.0)
    return coins + 50.0 * min(number(row, "level_time") / 300.0, 1.0)


def leaderboard(rows, profiles):
    for mode in sorted({r["mode"] for r in rows}):
        table = []
        for profile in profiles:
            runs = [r for r in rows if r["mode"] == mode and r["profile"] == profile]
            if not runs:
                continue
            mean = lambda key: statistics.mean(number(r, key) for r in runs)
            scores = [run_score(r) for r in runs]
            table.append({
                "profile": profile, "runs": len(runs), "wins": sum(r["won"] == "true" for r in runs),
                "score": statistics.mean(scores), "spread": statistics.pstdev(scores) if len(scores) > 1 else 0.0,
                "time": mean("level_time"), "crushed": mean("crushed"), "payout": mean("payout"),
                "rocks": mean("damage_rocks"), "contact": mean("damage_goon_contact"), "attacks": mean("damage_goon_attacks"),
                "stuck": mean("stuck"),
            })
        table.sort(key=lambda t: -t["score"])
        print("\n%s  (score = coins + mode result, higher is better; damage is health lost per run)" % mode.upper())
        print("  %-3s %-36s %4s %4s %7s %6s %7s %7s %7s %6s %7s %7s %5s" % (
            "#", "profile", "runs", "wins", "score", "+/-", "time s", "crushed", "payout", "rocks", "contact", "attacks", "stuck"))
        for i, t in enumerate(table):
            print("  %-3d %-36s %4d %4d %7.1f %6.1f %7.1f %7.1f %7.0f %6.1f %7.1f %7.1f %5.1f" % (
                i + 1, t["profile"][:36], t["runs"], t["wins"], t["score"], t["spread"], t["time"], t["crushed"],
                t["payout"], t["rocks"], t["contact"], t["attacks"], t["stuck"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--profiles", default="cautious,default", help="comma-separated AIProfiles specs")
    parser.add_argument("--modes", default="countdown,sprint,goonpocalypse")
    parser.add_argument("--level", default="prairie", help="comma-separated level ids (Levels.ORDER) or 0-based indices")
    parser.add_argument("--car", default="sedan", help="comma-separated cars")
    parser.add_argument("--runs", type=int, default=6, help="seeds per profile and mode")
    parser.add_argument("--seed", type=int, default=101)
    parser.add_argument("--parallel", type=int, default=3, help="Godot processes at once (the dev box has 4 threads)")
    parser.add_argument("--max-seconds", type=int, default=600, help="level time before a run is cut short")
    parser.add_argument("--name", default=time.strftime("%Y%m%d_%H%M%S"), help="names the logs and CSVs")
    parser.add_argument("--rerank", default=None, help="print the leaderboard of an existing tournament CSV and exit")
    parser.add_argument("--godot", default=None, help="the console build of Godot (default: $GODOT if it exists, else the 4.7.2 path)")
    args = parser.parse_args()
    if args.rerank:
        with open(args.rerank, newline="") as f:
            rows = list(csv.DictReader(f))
        leaderboard(rows, list(dict.fromkeys(r["profile"] for r in rows)))
        return
    if args.godot is None:
        args.godot = os.environ.get("GODOT", "")
        if not os.path.exists(args.godot): args.godot = DEFAULT_GODOT
    if not os.path.exists(args.godot):
        sys.exit("Godot not found at %s; pass --godot" % args.godot)
    print("Godot: %s" % args.godot)

    profiles = [p.strip() for p in args.profiles.split(",") if p.strip()]
    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    os.makedirs(USER_DIR, exist_ok=True)
    jobs = []
    for profile in profiles:
        for mode in modes:
            tag = "_t_%s_%d" % (args.name, len(jobs))
            jobs.append({"profile": profile, "mode": mode, "tag": tag,
                         "log": os.path.join(USER_DIR, "tournament_%s_%d.log" % (args.name, len(jobs)))})

    started = time.time()
    print("Tournament %s: %d profiles x %d modes x %d runs = %d runs in %d processes, %d at a time"
          % (args.name, len(profiles), len(modes), args.runs, len(profiles) * len(modes) * args.runs, len(jobs), args.parallel))
    pending = list(jobs)
    running = []
    while pending or running:
        while pending and len(running) < args.parallel:
            job = pending.pop(0)
            command = [args.godot, "--headless", "--fixed-fps", "60", "--path", PROJECT, "--", "--playtest", "--uncapped",
                       "--profiles=" + job["profile"], "--mode=" + job["mode"], "--level=" + args.level, "--car=" + args.car,
                       "--runs=%d" % args.runs, "--seed=%d" % args.seed, "--max-seconds=%d" % args.max_seconds, "--tag=" + job["tag"]]
            job["file"] = open(job["log"], "w")
            job["process"] = subprocess.Popen(command, stdout=job["file"], stderr=subprocess.STDOUT)
            running.append(job)
        time.sleep(2)
        for job in list(running):
            if job["process"].poll() is not None:
                job["file"].close()
                running.remove(job)
                print("  done %-40s %-14s exit %d  (%.0f s)" % (job["profile"], job["mode"], job["process"].returncode, time.time() - started))

    rows = []
    for job in jobs:
        path = os.path.join(USER_DIR, "results%s.csv" % job["tag"])
        if not os.path.exists(path):
            print("  no results for %s %s, see %s" % (job["profile"], job["mode"], job["log"]))
            continue
        with open(path, newline="") as f:
            rows.extend(csv.DictReader(f))
    if not rows:
        sys.exit("No results.")

    combined = os.path.join(USER_DIR, "tournament_%s.csv" % args.name)
    with open(combined, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    leaderboard(rows, profiles)
    print("\nAll runs: %s  (%.0f min)" % (combined, (time.time() - started) / 60))


if __name__ == "__main__":
    main()
