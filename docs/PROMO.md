# The capture kit (trailers, stills, social content)

How the kit hooks into the game, for whoever maintains it. Using it: `promo/README.md` (the people filming) and `python promo/tools/capture.py <command> --help`.

## What is where

| Path | What | Ships |
|---|---|---|
| `scripts/debug/capture.gd` | autoload `Capture`: inert without `--capture`, else loads the session by path | yes (inert) |
| `scripts/capture/clean_feed.gd` | `CleanFeed`: HUD full / minimal / off. It hides HUD nodes by name (`MINIMAL_HIDES`), so a renamed HUD node must be renamed there | yes |
| `scripts/capture/director_camera.gd` | `DirectorCamera`: a second `Camera2D` (follow, tripod, pan, free); never touches the car's own | yes |
| `promo/capture/session.gd` | one capture job: starts the run or stage, drives, fires events, films, writes the sidecar. Its header lists every job field and event | no |
| `promo/capture/tape.gd` | `Tape`: a hand drive's inputs per tick | no |
| `promo/stages/stage.gd` | titles, line-ups, the game's own transitions, key art, the end card, on a plain backdrop | no |
| `promo/tools/capture.py` | the command line: builds jobs, starts Godot, runs ffmpeg. Footage goes outside the repo (`promo/tools/local.json`, gitignored) | no |
| `promo/shots/*.json`, `promo/tapes/*.tape` | shot files and taped drives (committed) | no |

**Nothing shipped may name a class from `promo/`.** It is in the export preset's `exclude_filter`, so the autoload loads the session by path, and `Tape` exists only in the editor build. `CleanFeed` and `DirectorCamera` live in `scripts/capture/` so a player-facing photo mode can use them (planned, not built).

Game code the kit touches: the `Capture` autoload in `project.godot`; `Transition.instant()` (true while `Capture` runs, unless `Transition.forceShown`); `TileManager.steady`; `PickupMenu.lab`. `tests/game/test_capture.gd` covers the inert autoload, the export filter, the tape round trip, the clean feed, the rigs and the shot files.

## How a take is made

`capture.py` writes a **job** (JSON: one shot at one size) and starts Godot with `--fixed-fps 60 --write-movie <take>_sound.avi -- --capture --job=<file>`. The session uses a scratch save (`user://capture/`), opens every unlock, sizes the window to the frame, starts the level as the playtest does, counts **ticks from GO** (the first unpaused physics tick after the world is ready), saves the frames itself and writes the sidecar (`<take>.json`). `capture.py` then makes the master with ffmpeg.

- **Frames are saved by the session, not by Movie Maker,** because `--write-movie` fixes its picture at the project's 1600×900. Movie mode is still used for the **sound**: it mixes audio offline, in step with the frames, however slowly they render.
- **The window is the picture.** The logical canvas keeps 900 px on the frame's short side (`Session.logicalFor`), so the world is drawn at the same scale in every shape.
- **The world streams round the car, not the camera** (`TileManager.queueNeededChunks`, `KEEP_RADIUS`): a rig far from the car, or zoomed far out, shows unloaded ground. Panoramas (`survey` jobs) therefore park a hidden car at each tile.

## Hand drives and replays

`Tape` records every input action's strength on each tick from GO and the car's position once a second. Playback presses the same actions before the car's tick. Mouse clicks are not taped.

A replay matches its tape to a fraction of a pixel only because:
- **`--fixed-fps 60`** in the hand session and the replay: one physics tick per frame, a constant delta.
- **Ticks are counted from GO,** since the world build's length varies.
- **`TileManager.steady`** (set by the session): each frame waits for its chunk tasks and applies every chunk in full, so walls enter the world on the same tick on any machine. It hitches at chunk borders, so it is never on in a player's run.
- **The replay has the tape's 16:9 view.** Goon behavior depends on what is on screen (`SpawnManager.physicsView`), so tall and square replays are filmed wide and cut out round the car.

**So gameplay code must not read the wall clock or use frame-dependent randomness.** Anything that changes the simulation (handling numbers, goon behavior, the world generator, the RNG's order of use) breaks existing tapes: the replay reports `drift_px` and `capture.py` warns when it is large. Tapes are cheap to drive again; don't hold a gameplay change back for one.

## Stages

A job of kind `stage` puts one thing on a backdrop; `clear` makes the root transparent, so the frames carry alpha. `job.stage` is a name in `stage.gd`'s `match`, a `res://` scene (the prize lab scenes), or `menu` (the real main menu on a `CareerStart` tier's scratch save).

- **Pieces are the real thing.** The `transition` stage calls the game's own `Transition.play`, `Stamp.slam`, `TapeBanner.post` and `RoadSign.post`. `Session.isolate` leaves one piece of the real menu or HUD in the picture by concealing its siblings (`CleanFeed.conceal`) and switching off its ancestors' own drawing.
- **`"layer": "hud"`** on a normal shot hides the `Level` node and leaves the HUD's `CanvasLayer` over nothing.
- **Add a stage:** a function in `stage.gd`, a line in its `match`, its fields in the header comment, an example in `promo/shots/elements.json`.

## Known limits

- The `.avi` that carries the sound has a 4 GB limit, about 5 minutes of run. Replay long drives in stretches.
- A filmer can't build the native library; the author publishes a prebuilt pair for `doctor --native`.

Open work on the kit: `docs/roadmap/ROADMAP_TECH.md`.
