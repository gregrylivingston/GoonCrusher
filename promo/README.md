# The capture kit

Footage, stills and interface pieces for trailers and social posts, made from the game itself. This page is for the people filming. You don't need to know the code. If you use Claude in this repo, ask it in plain words ("film a taxi at night in the city, vertical, 15 seconds") and it will run the right command; `promo/CLAUDE.md` tells it how.

Everything runs through one command, from the repo's folder:

```
python promo/tools/capture.py <what> ...
```

or double-click `scripts/windows/capture.bat` for a menu of the common ones.

## First time on a machine

```
python promo/tools/capture.py doctor --fix
```

It checks for Godot 4.7.2, ffmpeg and the game's native library, picks an output folder and says in plain words what is missing and how to fix it. `--fix` installs ffmpeg for you.

- **Output folder.** Footage is big and never goes in git. It is written to a folder on your own machine, `Videos/GoonCrusher Capture` unless you choose another with `doctor --out <folder>`.
- **Native library.** The game needs two `.dll` files that are not in git. If doctor says they are missing, ask the author for the pair that matches your commit, then run `doctor --native <the folder they are in>`.
- **Same commit, same picture.** Two people's shots only cut together if both filmed the same version of the game. Pull before a filming session, and check the commit in the gallery.

## The two ways to get gameplay

### 1. Ask the AI driver (quick)

```
python promo/tools/capture.py quick --level city --car taxi --time night --profile vertical --seconds 12
```

The AI drives, the kit films, and a master lands in `masters/`. Good for b-roll, backgrounds and social clips. Useful options: `--hud full|minimal|off`, `--zoom 0.6` (closer; the game's own zoom is 0.45), `--seed 7` (another map), `--lead 10` (seconds of driving before filming starts), `--seconds 0` (one still instead of a clip).

For the whole game at once, leave this running overnight:

```
python promo/tools/capture.py stock
```

It films every level by day and by night, 20 seconds each, with the cars taking turns, into `stock/`. Run it again after the art changes; add `--redo` to replace clips that are already there.

### 2. Drive it yourself (for anything that has to look played)

```
python promo/tools/capture.py hand my_drive --level prairie --car sedan --time day
```

The game opens and you play normally. **F9** (or clicking the right stick) bookmarks a good moment. **F10** finishes. Nothing is filmed while you play: the kit tapes what you pressed. Then film the bookmarks, at any size, as many times as you like:

```
python promo/tools/capture.py replay my_drive --profile wide4k
python promo/tools/capture.py replay my_drive --mark 2 --before 8 --after 4 --hud off --profile wide4k,vertical
python promo/tools/capture.py replay my_drive --start 30 --seconds 20
```

The replay is the same drive, tick for tick: same goons, same crushes. Because it is rendered offline, a slow laptop produces the same clean 60 fps 4K as a fast desktop; it just takes longer. The tape is a small text file in `promo/tapes/`, so commit it and the other editor can film your drive too.

Things to know about hand drives:
- A tape only matches the version of the game it was made on. After the game's code or levels change, old tapes can drift. The kit measures this and warns you; if it does, drive it again.
- Mouse clicks are not taped, so answer prize games with the keys (E, Q, WASD).
- A vertical or square replay is filmed wide and then cut out around the car, so the HUD is off in those.

## Shot files

A shot file is a list of shots you can film again whenever the game changes. They live in `promo/shots/`:

| File | What it holds |
|---|---|
| `trailer_launch.json` | the launch trailer's gameplay beats |
| `steam_screens.json` | the Steam page's screenshots |
| `social_loops.json` | vertical and square clips |
| `elements.json` | titles, the shutter wipe, line-ups, the HUD alone, prize games, a menu tour, the end card |
| `store_art.json` | Steam capsules made from a still |

```
python promo/tools/capture.py shot trailer_launch                 # all of it
python promo/tools/capture.py shot trailer_launch crowd_plough    # one shot
python promo/tools/capture.py shot trailer_launch --profile wide1080   # a quick look before the 4K take
```

A shot is a few plain fields. Copy one and change it:

```json
{"id": "crowd_plough", "level": "orchard", "car": "pickup", "time": "day",
 "lead": 8, "seconds": 8, "hud": "off",
 "camera": {"rig": "follow", "zoom": 0.55, "lead": 0.25},
 "events": [{"t": 1, "do": "crowd", "count": 20, "ahead": 1500}]}
```

- **What is played:** `level`, `car`, `mode`, `tier`, `seed`, `time` (day, night, cycle), `upgrades` (0 to 20), `god` (the car can't be hurt). Also the game's own `landscape`, `goons`, `class` and `prize` options.
- **Who drives:** `driver`: `ai`, `pattern:sine`, `pattern:circle`, `pattern:straight`, `none` (parked).
- **When:** `lead` is seconds of driving after GO before filming starts; `seconds` is how long is filmed (0 = one still).
- **What shows:** `hud`: `full`, `minimal` (instruments only), `off`. `"layer": "hud"` films the HUD alone with transparency.
- **Camera:** `rig`: `follow`, `tripod` (stands still while the car drives through), `pan`. `zoom` is a number, or `[from, to]` for a push in or pull back over `seconds`. `lead` looks ahead of the car. `offset: [0, 220]` sits the car low in a tall frame.
- **Events** happen at `t` seconds into the shot:
  - `crowd`: `count` goons `ahead` px in front of the car (`goon`: an id, else the level's own)
  - `explode`: a blast `ahead` / `side` px from the car
  - `console`: any dev console line (`night`, `day`, `heal`, `pickup <id>`, `give ...`)
  - `camera`: change the rig mid-shot
  - `hud`: switch `mode`
  - `press` / `click`: an input action or a mouse click (for menu tours)
  - `mark`: a named marker for the edit
- **Sizes:** `profiles`: `wide4k`, `wide1440`, `wide1080`, `vertical` (1080×1920), `square`, `portrait45` (1080×1350), and the Steam art sizes. `per` holds changes for one size.

## What you get

In the output folder:

| Folder | Holds |
|---|---|
| `masters/` | gameplay clips: ProRes 422 HQ `.mov`, 60 fps, with the game's sound effects and no music |
| `stock/` | the AI library |
| `elements/` | pieces with transparency: ProRes 4444 `.mov` |
| `stills/` | PNGs |
| `deliverables/` | finished exports per platform |
| `audio/` | radio songs as WAV |
| `gallery.html` | the review page |

Beside each clip:
- a `.json` sidecar: exactly how it was filmed (level, seed, commit ...), so anyone can film it again
- a `.edl` marker list: crushes, pickups, events and your bookmarks. In DaVinci Resolve: put the clip on a timeline, right-click the timeline in the media pool, **Timelines > Import > Timeline Markers from EDL**.

A new take never overwrites an old one: names end `_v01`, `_v02` ...

ProRes masters are large: about 13 GB a minute at 4K, 3 GB at 1080p. If disk is short, add `--light` to any filming command for H.264 masters instead.

**Music.** Masters have no music so you can lay your own. The studio owns the radio songs, so any of them can go in a trailer:

```
python promo/tools/capture.py song            # list them
python promo/tools/capture.py song crush      # copy matching songs to audio/ as WAV
```

Add `--music` to `quick` or `replay` (or `"audio": {"music": true}` in a shot) to keep the radio in a clip's sound.

## Pieces for the edit

```
python promo/tools/capture.py shot elements
python promo/tools/capture.py stage title --set text="43 GOONS" --set sub="ONE CAR"
python promo/tools/capture.py stage lineup --set what=goons --seconds 4
python promo/tools/capture.py stage transition --set label="LEVEL 2"
python promo/tools/capture.py stage endcard --profile wide1080,vertical
```

They come out transparent, so they drop straight over footage in Resolve. If you need a key colour instead, add `--backdrop magenta` (nothing in the game is magenta; green would eat the grass and coins) or `--backdrop grey`.

## Finishing

```
python promo/tools/capture.py reframe <take> --to vertical     # cut a tall clip out of a wide one, following the car
python promo/tools/capture.py slowmo <take> --factor 4 --start 3 --seconds 2
python promo/tools/capture.py encode <your finished cut.mov> --preset steam,youtube4k,vertical
python promo/tools/capture.py encode <take> --preset gif --width 480
```

Presets: `steam`, `youtube`, `youtube4k`, `vertical`, `square`, `x`, `discord`, `gif`, `webp`. `<take>` is a file path, or just a take's name from the gallery.

Slow motion is made after filming (the game's physics can't run slower), so it works best on a couple of seconds around a hit. Resolve's own retime with Optical Flow does the same job inside the edit.

## The gallery

```
python promo/tools/capture.py gallery
```

Builds and opens a page of everything you have filmed. Type to filter ("night vertical taxi"). Each card shows the commit it was filmed on and flags clips filmed before the latest art change as **stale art**. Click a path to copy it.

## Working as two

- Write what you need in `promo/brief/shot_requests.md` and put your name on what you are filming.
- Commit shot files and tapes. Footage stays on your machine; pass masters to each other however you like, or film the same shot yourself from the same commit.
- The trailer's beats are in `promo/brief/beat_sheet.md`.

## When something goes wrong

Every error says what to do next. The usual ones:
- **"Godot was not found" / "ffmpeg was not found" / "native library is missing"**: run `doctor`.
- **"The game stopped before the capture finished"**: the message names a log file. Give it to Claude or the author.
- **A replay warns that it drifted**: the game changed since the drive was taped. Drive it again.
- **The picture has key hints or a mouse pointer you don't want**: use `--hud off` or `--hud minimal`.

The kit never touches your real save: every run uses a scratch save.
