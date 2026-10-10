# The capture kit

Footage, stills and interface pieces for trailers and social posts, made from the game itself. This page is for the people filming; you don't need to know the code. If you use Claude in this repo, ask in plain words ("film a taxi at night in the city, vertical, 15 seconds") and it will run the right command.

Everything runs through one command, from the repo's folder (or double-click `scripts/windows/capture.bat` for a menu):

```
python promo/tools/capture.py <what> ...
```

Add `--help` after any command to see all its options.

## First time on a machine

```
python promo/tools/capture.py doctor --fix
```

It checks for Godot, ffmpeg and the game's native library, picks an output folder and says what is missing and how to fix it.

- **Output folder.** Footage is big and never goes in git. It goes to `Videos/GoonCrusher Capture` unless you choose another with `doctor --out <folder>`.
- **Native library.** The game needs two `.dll` files that are not in git. If doctor says they are missing, ask the author for the pair that matches your commit, then run `doctor --native <their folder>`.
- **Same commit, same picture.** Two people's shots only cut together if both filmed the same version of the game. Pull before a session.
- The kit never touches your real save.

## Getting gameplay

### Ask the AI driver (quick)

```
python promo/tools/capture.py quick --level city --car taxi --time night --profile vertical --seconds 12
```

The AI drives, the kit films, and a master lands in `masters/`. Good for b-roll and social clips. Useful options: `--hud full|minimal|off`, `--zoom 0.6` (closer; the game's own is 0.45), `--seed 7` (another map), `--lead 10` (seconds of driving before filming), `--seconds 0` (a still).

`python promo/tools/capture.py stock` films every level by day and by night into `stock/`. Leave it running overnight (`--redo` replaces clips).

### Drive it yourself (for anything that has to look played)

```
python promo/tools/capture.py hand my_drive --level prairie --car sedan --time day
```

The game opens and you play normally. **F9** (or clicking the right stick) bookmarks a good moment; **F10** finishes. Nothing is filmed while you play: the kit tapes what you pressed. Then film the bookmarks, at any size, as often as you like:

```
python promo/tools/capture.py replay my_drive --profile wide4k
python promo/tools/capture.py replay my_drive --mark 2 --before 8 --after 4 --hud off --profile wide4k,vertical
```

The replay is the same drive, tick for tick, rendered offline, so a slow laptop makes the same clean 60 fps 4K as a fast desktop. The tape is a small file in `promo/tapes/`: commit it and the other editor can film your drive too.

- A tape only matches the version of the game it was made on. If a replay warns that it drifted, drive it again.
- Mouse clicks are not taped, so answer prize games with the keys (E, Q, WASD).
- A vertical or square replay is cut out of a wide one, so its HUD is off.

## Shot files

A shot file is a list of shots you can film again whenever the game changes. They live in `promo/shots/`: `trailer_launch`, `steam_screens`, `social_loops`, `elements` (interface pieces) and `store_art`.

```
python promo/tools/capture.py shot trailer_launch                       # all of it
python promo/tools/capture.py shot trailer_launch crowd_plow          # one shot
python promo/tools/capture.py shot trailer_launch --profile wide1080    # a quick look before the 4K take
```

A shot is a few plain fields. Copy one and change it:

```json
{"id": "crowd_plow", "level": "orchard", "car": "pickup", "time": "day",
 "lead": 8, "seconds": 8, "hud": "off",
 "camera": {"rig": "follow", "zoom": 0.55, "lead": 0.25},
 "events": [{"t": 1, "do": "crowd", "count": 20, "ahead": 1500}]}
```

- **What is played:** `level`, `car`, `mode`, `tier`, `seed`, `time` (day, night, cycle), `upgrades`, `god` (the car can't be hurt).
- **Who drives:** `driver`: `ai`, `pattern:sine`, `pattern:circle`, `pattern:straight`, `none` (parked).
- **When:** `lead` is seconds of driving before filming starts; `seconds` is how long is filmed (0 = a still).
- **What shows:** `hud`: `full`, `minimal` (no clock, goal or key hints), `off`.
- **Camera:** `rig`: `follow`, `tripod` (stands still while the car drives through), `pan`. `zoom` is a number, or `[from, to]` for a push in or pull back. `offset: [0, 220]` sits the car low in a tall frame.
- **Events** happen `t` seconds into the shot (negative: before filming starts): `crowd` (goons ahead of the car), `explode`, `console` (any dev console line: `night`, `heal`, `pickup <id>`), `camera`, `hud`, `press` / `click` (for menu tours), `isolate` (one interface piece over nothing), `mark` (a marker for the edit).
- **Sizes:** `profiles`: `wide4k`, `wide1440`, `wide1080`, `wide720`, `vertical`, `square`, `portrait45`, and the Steam art sizes.

## What you get

In the output folder: `masters/` (gameplay, ProRes 422 HQ, 60 fps, sound effects but no music), `stock/`, `elements/` (pieces with transparency, ProRes 4444), `stills/`, `deliverables/`, `audio/` and `gallery.html`.

Beside each clip:
- a `.json` sidecar: exactly how it was filmed (level, seed, commit ...), so anyone can film it again
- a `.edl` marker list: crushes, pickups, events and your bookmarks. In DaVinci Resolve: right-click the timeline in the media pool, **Timelines > Import > Timeline Markers from EDL**.

A new take never overwrites an old one (`_v01`, `_v02` ...). ProRes is large, about 13 GB a minute at 4K; add `--light` to any filming command for H.264 instead.

**Music.** Masters have no music so you can lay your own. The studio owns the radio songs, so any can go in a trailer: `capture.py song` lists them, `capture.py song <name>` copies one to `audio/` as WAV. `--music` keeps the radio in a clip's sound.

## Pieces for the edit

```
python promo/tools/capture.py shot elements
python promo/tools/capture.py stage title --set text="43 GOONS" --set sub="ONE CAR"
python promo/tools/capture.py stage lineup --set what=goons --seconds 4
python promo/tools/capture.py stage transition --set which=stamp --set label=CRUSHED
```

`elements.json` holds titles and the end card, the game's own screen moves (the garage door, the stamp, the hazard tape, the highway sign), line-ups (cars, goons, pickups, level posters), single interface pieces (`piece_...`, `hud_alone`), whole pages, prize games and a safe-zone guide for tall video.

A single piece is the real menu with everything else taken out of the picture. To isolate something else, copy a `piece_` shot: its events press the keys that open the screen, then `isolate` names the piece. Ask Claude to find the right name.

Pieces come out transparent, so they drop straight over footage. For a key color instead, add `--backdrop magenta` (nothing in the game is magenta; green would eat the grass and coins).

**A wide picture of the world:** `capture.py panorama --level city --tiles 4x3` joins tiles into one large still of the area round a level's start, with no car, HUD or goons.

## Finishing

```
python promo/tools/capture.py reframe <take> --to vertical     # cut a tall clip out of a wide one, following the car
python promo/tools/capture.py slowmo <take> --factor 4 --start 3 --seconds 2
python promo/tools/capture.py encode <your finished cut.mov> --preset steam,youtube4k,vertical
python promo/tools/capture.py gallery                          # a page of everything filmed
```

`<take>` is a file path or a take's name from the gallery. The gallery filters as you type, shows each clip's commit and flags clips filmed before the latest art change as **stale art**.

## Working as two

- Write what you need in `promo/brief/shot_requests.md` and put your name on what you are filming. The trailer's beats are in `promo/brief/beat_sheet.md`.
- Commit shot files and tapes. Footage stays on your machine.

## When something goes wrong

Every error says what to do next.
- **Something "was not found" or "is missing":** run `doctor`.
- **"The game stopped before the capture finished":** the message names a log file. Give it to Claude or the author.
- **Key hints or a pointer in the picture:** use `--hud off` or `--hud minimal`.
