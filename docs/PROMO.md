# The capture kit (trailers, stills, social content)

How the kit works, for whoever maintains it. The people filming read `promo/README.md`; Claude helping them reads `promo/CLAUDE.md`.

## What is where

| Path | What | Ships with the game |
|---|---|---|
| `scripts/debug/capture.gd` | autoload `Capture`: inert without `--capture`, else loads the session | yes (inert) |
| `scripts/capture/clean_feed.gd` | `CleanFeed`: HUD full / minimal / off. Minimal hides the HUD children named in `MINIMAL_HIDES` (the version, the mirror with its clock and goal, the objective), the chance widgets and every `KeyHint`: a renamed HUD node must be renamed there too | yes (photo mode will use it) |
| `scripts/capture/director_camera.gd` | `DirectorCamera`: follow, tripod, pan, free rigs | yes (photo mode will use it) |
| `promo/capture/session.gd` | one capture job: starts the run or stage, drives, films, writes the sidecar | no |
| `promo/capture/tape.gd` | `Tape`: a hand drive's inputs per tick | no |
| `promo/stages/stage.gd` | title, lineup (cars, goons, pickups, posters), transition (shutter, stamp, banner, sign), keyart, safezone, endcard on a plain backdrop | no |
| `promo/tools/capture.py` | the command line: doctor, shot, quick, hand, replay, stock, seeds, stage, panorama, encode, reframe, slowmo, song, gallery | no |
| `promo/shots/*.json` | shot files | no |
| `promo/tapes/*.tape` | taped drives | no |
| `promo/seeds/hero_seeds.json` | each level's liveliest maps (`capture.py seeds`) | no |
| `promo/tools/local.json` | this machine's paths (gitignored) | no |

`promo/` is in the export preset's `exclude_filter`. The autoload must not name a class from `promo/` (it loads the session by path), or an exported build would fail to parse it. `Tape` is a global class that exists only in the editor build; nothing outside `promo/` may use it.

## How a take is made

1. `capture.py` builds a **job** (a JSON object: one shot at one size), writes it to the output folder's `work/`, and starts Godot:
   `Godot_console.exe --path . --windowed --resolution WxH --fixed-fps 60 [--write-movie <take>_sound.avi] -- --capture --job=<file> --window=WxH`
2. `Capture` hands over to the session, which points the save at `user://capture/capture_save.tres`, opens every unlock, forces native render resolution, sets the window to the frame's pixels (borderless, so it can be larger than the screen) and starts the level as the playtest does.
3. The session counts **ticks from GO** (the first unpaused physics tick after the world is ready). `lead` seconds later it films `seconds` of frames: on `RenderingServer.frame_post_draw` it reads the window's texture and saves a PNG on a worker thread.
4. It writes the **sidecar** (`<take>.json`: the job, the first filmed frame, the car's screen position per frame, events) and quits.
5. `capture.py` turns the PNGs into a master with ffmpeg, cuts the sound to the filmed frames, adds the commit and tags to the sidecar, writes the `.edl` markers and deletes the frames.

### Why frames are saved by the session, not by Movie Maker

Godot's Movie Maker (`--write-movie`) fixes its picture at the project's 1600×900 whatever the window's size, so it can't make a 4K or a vertical master. It is still what makes the **sound** right: in movie mode the audio is mixed offline, in step with the frames, however slowly they render. So a take runs in movie mode writing a small `.avi` whose picture is thrown away, and the session saves the real frames itself. `first_frame` in the sidecar (`Engine.get_frames_drawn()` at the first filmed frame) is where the sound is cut.

`--fixed-fps 60` gives one physics tick per frame and a constant delta, so a take is the same on any machine and never drops a frame. It is also why nothing here may depend on the wall clock.

### Sizes

The window is the picture. The logical canvas keeps 900 px on the frame's short side (`Session.logicalFor`): 16:9 is the game's own 1600×900; 9:16 is 900×1600, so the world is drawn at the same scale and the HUD (laid out for a wide screen) is switched off unless the shot asks for it. `content_scale_aspect` is set to expand.

## Hand drives and replays

`Tape` records every input action's strength on each tick from GO (changes only) and the car's position once a second. Playback presses the same actions through `Input.action_press` before the car's tick, so the game reads a tape exactly as it reads a person. Mouse clicks are not taped.

A replay matches its tape to a fraction of a pixel (measured: 0.1 px over 30 s with goons and a wreck) because of three things:
- **`--fixed-fps 60`** in the hand session and the replay. The hand session also caps the frame rate at 60 so it runs in real time.
- **Ticks counted from GO.** The start lamps begin before the world is built, so their length in ticks depends on how long the build took.
- **`TileManager.steady`** (set by the session): each frame waits for the chunk tasks it queued and applies every chunk in full, so walls enter the world on the same tick on any machine. It costs a small hitch at chunk borders, so it is never on in a player's run.

What breaks a tape: any change to the game's simulation between taping and replaying (handling numbers, goon behaviour, the world generator, the RNG's order of use). The replay reports `drift_px`, and `capture.py` warns above 150. What the goons do also depends on how much world is on screen (`SpawnManager.physicsView`, off-screen spawns), so a replay must have the tape's 16:9 view: tall and square replays are filmed wide at their own height and cut out around the car (`reframe_file`).

Anything new that should be replayable must not read the wall clock or frame-dependent randomness in gameplay code.

## Stages

A job of kind `stage` puts one thing on a backdrop: `clear` sets `root.transparent_bg`, so the saved PNGs carry alpha and the master is ProRes 4444. `stage.gd` holds the built-in ones; a `res://` path films any scene (the prize lab scenes, with `tap` to play them); `menu` opens the real main menu on a `CareerStart` tier's save, copied to `user://capture/menu_save.tres`. `"doors": true` (and the transition stage) set `Transition.forceShown`, which makes `Transition.instant()` false although a harness is running.

`"layer": "hud"` on a normal shot hides the `Level` node and makes the root transparent, leaving the HUD's `CanvasLayer`.

The `transition` stage plays the game's own pieces by `which`: `Transition.play` (the shutter), `Stamp.slam`, `TapeBanner.post`, `RoadSign.post`. The last two hang on the run's banner layer, so the stage sets `Root.levelRoot` to a bare `Node2D`. `"hatch": true` on a prize lab scene turns `PickupMenu.lab` off so the `GameHatch` plays.

**Isolating a piece** (`Session.isolate`, the `isolate` event): the piece is found in the current scene by class, name or a variable of `Root.mainMenu`; walking up from it, every sibling is concealed with `CleanFeed.conceal` and every ancestor's own drawing is switched off with `self_modulate`, then the root is made transparent. It works on the real menu and in a run (the results ticket), so a piece always looks exactly as it does in the game. Events with a negative `t` fire during the lead-in, which is how a shot opens the screen it wants before filming.

A clean picture (`hud: off`, a survey) also hides the run's `Banners` layer each frame: the tape banners and district signs are not part of the HUD.

To add a stage: a function in `stage.gd`, a line in its `match`, its fields in the header comment, and an example in `promo/shots/elements.json`.

## Panoramas

A job of kind `survey` parks a hidden car at each cell of a grid round the start, waits `SURVEY_SETTLE` frames for the chunks, and saves a tile; `capture.py panorama` joins them with ffmpeg's `tile` filter. The car's own camera is held at the survey's zoom because `TileManager.queueNeededChunks` streams for that camera. `TileManager.KEEP_RADIUS` (2 chunks) bounds how much world one tile can hold: below about zoom 0.12 the edges of a tile would be unloaded.

## Events and the camera

`Session.fire` runs a shot's events. `console` passes a line to the dev console's `execute`, so every console command is an event. `crowd` uses `SpawnManager.spawnGroup`; `explode` uses `Level.explode`.

`DirectorCamera` is a second `Camera2D` made current; it never touches the car's own camera, and `release()` hands the picture back. The world streams round the **car** (`TileManager.queueNeededChunks`), not the camera, so a rig far from the car, or zoomed out past about 0.2, shows unloaded ground.

## Game code the kit touches

- `project.godot`: the `Capture` autoload.
- `scene/ui/transitions/transition.gd`: `instant()` is true while `Capture` runs; `forceShown` overrides it.
- `scene/level/tileManager.gd`: `steady`.
- `export_presets.cfg`: `promo/*` excluded.

`tests/game/test_capture.gd` checks that the autoload is inert, that the export excludes `promo/`, the tape round trip, the clean feed, the camera rigs, the frame shapes and that the shot files are well formed.

## Photo mode (planned)

`CleanFeed` and `DirectorCamera` live in `scripts/capture/` so a player-facing photo mode can use them: pause, a `free` rig moved with the stick or keys, zoom, HUD off, save a PNG to `user://photos/`. It needs a menu with `MenuTheme`, `KeyHint`s, full pad and mouse control, a rebindable key in `Settings`, and a line in the pause menu. Not built yet.

## Known limits

- Speed: about 0.1 to 0.2 s a frame at 1080p and 0.5 s at 4K, most of it PNG encoding and Movie Maker's own (unused) picture. The lead-in frames cost render time too.
- The `.avi` that carries the sound has a 4 GB limit: about 5 minutes of run, lead included. Replay long drives in stretches.
- Slow motion is ffmpeg's motion interpolation after the fact. Real slow motion needs physics interpolation, which the project doesn't use.
- `"layer": "hud"` and an isolated results ticket leave the odd world-space marker that draws on its own layer.
- The hatch reel and the full pages (Pickups, Goonopedia) come on the game's own dark background, not transparent: their backdrops are part of the piece.
- The Steam sizes in `PROFILES` and the safe zones in `stage.gd` are from memory: check them before a final export.
- A non-technical filmer can't build the native library (docs/NATIVE.md). `doctor --native <folder>` copies in a prebuilt pair; publishing one per commit (a GitHub release) is the author's job and isn't automated.
