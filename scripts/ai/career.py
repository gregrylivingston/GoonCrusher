"""Career playtests in parallel: every persona x start tier is one headless Godot process.

    python scripts/ai/career.py --personas rookie,grinder,explorer --starts fresh,mid,maxed --sessions 30
    python scripts/ai/career.py --report        (the summaries already in the playtest folder, again)

Each process plays one career (scripts/debug/career.gd, docs/AI_DRIVER.md "Career playtests") and writes
career_<persona>_<start>_summary.json, its events log and its CSV to %APPDATA%/GoonCrusher/playtest/.
This prints one table of the careers (runs, wins, minutes, progress, stalls, issues, script errors), then
every issue and script error grouped by text with the careers that met it.
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import time

DEFAULT_GODOT = r"C:/Users/Greg/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "GoonCrusher", "playtest")


def play(args):
    jobs = [(p, s) for p in args.personas.split(",") for s in args.starts.split(",")]
    running = []
    while jobs or running:
        while jobs and len(running) < args.parallel:
            persona, start = jobs.pop(0)
            tag = "career_%s_%s" % (persona, start)
            log = open(os.path.join(USER_DIR, tag + "_stdout.txt"), "w")
            cmd = [args.godot, "--headless", "--fixed-fps", "60", "--path", PROJECT, "--", "--career", "--uncapped",
                   "--persona=" + persona, "--start=" + start, "--sessions=%d" % args.sessions, "--seed=%d" % args.seed, "--tag=" + tag]
            if args.minutes:
                cmd.append("--minutes=%s" % args.minutes)
            print("start", tag, flush=True)
            running.append((tag, subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT), log, time.time()))
        time.sleep(2)
        for entry in running[:]:
            tag, proc, log, started = entry
            if proc.poll() is not None or time.time() - started > args.timeout:
                if proc.poll() is None:
                    proc.kill()
                    print("TIMEOUT", tag, flush=True)
                log.close()
                running.remove(entry)
                print("done %s in %.0f s (exit %s)" % (tag, time.time() - started, proc.returncode), flush=True)


def report(tags=None):
    rows = []
    for path in sorted(glob.glob(os.path.join(USER_DIR, "career_*_summary.json"))):
        tag = os.path.basename(path)[:-len("_summary.json")]
        if tags and tag not in tags:
            continue
        with open(path) as f:
            rows.append((tag, json.load(f)))
    if not rows:
        print("no career summaries in", USER_DIR)
        return
    head = "%-28s %5s %5s %7s %13s %9s %11s %6s %7s %6s" % ("career", "runs", "wins", "minutes", "modes beaten", "cars", "upgrades", "stall", "issues", "errors")
    print(head)
    print("-" * len(head))
    issues, errors = {}, {}
    for tag, s in rows:
        a, b = s["progress_start"], s["progress_end"]
        print("%-28s %5d %5d %7.1f %6d -> %-4d %3d -> %-3d %4d -> %-4d %6d %7d %6d" % (tag, s["runs"], s["wins"], s["minutes"],
              a["modes_beaten"], b["modes_beaten"], a["cars_owned"], b["cars_owned"], a["upgrades"], b["upgrades"],
              s["longest_runs_without_progress"], len(s["issues"]), sum(e["count"] for e in s["script_errors"])))
        for i in s["issues"]:
            issues.setdefault("[%s] %s" % (i["kind"], i["text"]), set()).add(tag)
        for e in s["script_errors"]:
            errors.setdefault(e["error"], {})[tag] = e["count"]
    print("\nCoins per minute by mode:")
    for tag, s in rows:
        print("  %-28s %s" % (tag, ", ".join("%s %d (%d/%d won)" % (m, v["coins_per_minute"], v["wins"], v["runs"]) for m, v in sorted(s["modes"].items()))))
    print("\nIssues (%d distinct):" % len(issues))
    for text, tags in sorted(issues.items()):
        print("  %s  <- %s" % (text, ", ".join(sorted(tags))))
    print("\nScript errors (%d distinct):" % len(errors))
    for text, counts in sorted(errors.items(), key=lambda kv: -sum(kv[1].values())):
        print("  %dx %s  <- %s" % (sum(counts.values()), text, ", ".join(sorted(counts))))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--personas", default="rookie,grinder,explorer")
    parser.add_argument("--starts", default="fresh")
    parser.add_argument("--sessions", type=int, default=30)
    parser.add_argument("--minutes", type=float, default=0)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--parallel", type=int, default=3)
    parser.add_argument("--timeout", type=float, default=4 * 3600, help="seconds before a career process is killed")
    parser.add_argument("--godot", default=DEFAULT_GODOT)
    parser.add_argument("--report", action="store_true", help="only print the summaries already written")
    args = parser.parse_args()
    os.makedirs(USER_DIR, exist_ok=True)
    if not args.report:
        play(args)
        report({"career_%s_%s" % (p, s) for p in args.personas.split(",") for s in args.starts.split(",")})
    else:
        report()


if __name__ == "__main__":
    sys.exit(main())
