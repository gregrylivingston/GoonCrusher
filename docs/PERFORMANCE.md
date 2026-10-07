# Performance and settings

The reference machine is the dev box: Intel HD 620 iGPU, 4 threads, Godot 4.7.2. It is the "potato" target.

## How settings work

| File | Contents | Steam Auto-Cloud |
|---|---|---|
| `user://settings.cfg` | Audio, controls, accessibility, gameplay | Sync |
| `user://graphics.cfg` | Display and graphics, detected tier and GPU, boot counter | Don't sync (per machine) |
| `user://override.cfg` | Only the renderer, read at engine start (`application/config/project_settings_override`) | Don't sync |
| `user://saveData_0.1.tres` | Progress (its `settings` field is legacy, read once) | Sync |

Reset Progress never touches the settings files.

**The `Settings` autoload** (`scripts/global/settings.gd`, loaded first):
- **Load/save:** both files are read over `DEFAULTS` and clamped to `OPTIONS`/`RANGES`; missing keys come from the stored tier's `PRESET` column. Saves are debounced 0.5 s and flushed when the overlay closes and on quit.
- **Applying:** shader globals (`gc_*` in `project.godot [shader_globals]`) for text quality, motion, pickup glow, the giant marker and ground detail; a `node_added` hook that ANDs the Lighting level with each light's and occluder's authored state (`gc_shadow`, `gc_enabled`, `gc_vis`, `gc_world` metadata); and `Settings.get_value()` plus the `changed` signal where effects spawn.
- **Restart:** only the renderer needs one (it writes `override.cfg`).
- **Safe mode:** two boots in a row that never reach the menu, or `-- --safe-mode`, apply Potato, windowed and Compatibility for that session, then ask whether to keep them. Headless and bench runs never count as crashed boots.
- **First run:** the tier comes from the adapter and thread count; the menu then measures its GPU time over 120 frames and steps down a tier if the GPU is clearly slower (2×/0.8×/0.5× the HD 620's time on Low/Medium/High, scaled to 1080p; standard renderer only). A toast names the preset. The adapter is stored as vendor plus device ID, so a renderer switch isn't a new GPU.
- **F3 overlay:** Off, FPS, Detailed (frame, process, physics and GPU ms, draw calls, nodes, goons, chunks, lights, renderer).
- **Runtime advisor:** once per install, if the 1% low stays under 45 fps in a run's first 90 s, the summary suggests Potato.

**The overlay** (`scene/player/menu/settings/`): `settings_menu.gd` builds tabs from `buildSchema()`; each row is an `OptionRow`; `SettingsDialog` is the shared modal. Fully usable with a controller; display changes revert after 15 s unless confirmed. The info panel shows each option's effect, cost, gameplay impact and restart need. `Settings.menu_open` blocks input underneath. To add a setting, see CLAUDE.md.

## The options

### Graphics

**Quality Preset:** Potato / Low / Medium / High (Custom once a value changes), plus **Detect Again**. Presets set only these keys:

| Option | Values | Potato | Low | Medium | High | Effect |
|---|---|---|---|---|---|---|
| Text Effects | Flat / Still 3D / Animated / Animated HD | Flat | Still 3D | Animated | Animated HD | `shader/3dtext.gdshader` via `gc_text_quality` and `gc_text_max_slices` (1/4/8/16); at rest text uses only the slices its extrusion needs |
| Lighting | Low / Medium / High | Low | Medium | Medium | High | High as authored. Medium keeps every shadow and occluder with a smaller atlas and no pickup glow. **Low affects gameplay:** no shadows or small lights (world occluders stay), one big station lamp |
| Simple Headlight Cone | On / Off | On | On | Off | Off | One baked shadowed cone (`texture/fx/headlight_cone.png`) instead of 5 headlamps, same reach |
| Exhaust Smoke | Off / Low / Full | Off | Low | Full | Full | Pooled puffs |
| Tire Marks | Off / Short / Full | Off | Short | Full | Full | Short: rear tyres, 6 s. Full: all tyres, 20 s |
| Damage Effects | Low / Full | Low | Full | Full | Full | Low: engine smoke only (docs/CAR_ART.md) |
| Pickup Glow | Simple / Full | Simple | Simple | Full | Full | Simple drops the moving shine |
| Slot Celebration | Minimal / Reduced / Full | Minimal | Reduced | Full | Full | Splash burst node counts; reels and results unchanged (the slot icon wall is gone: transitions follow Exhaust Smoke, docs/UI.md) |
| Reward Pop-ups | Minimal / Reduced / Full | Minimal | Reduced | Full | Full | Caps flying reward icons at 3/10/20; rewards are credited on collection |
| Ground Detail | Simple / Full | Simple | Full | Full | Full | `gc_ground_quality`: Simple draws the nearest cell's material with no macro noise or water/belt animation (docs/WORLD.md, "The ground shader") |
| Max Sound Effects | 8 / 12 / 24 | 8 | 12 | 24 | 24 | `Audio` FX pool size |

### Display

| Option | Values | Notes |
|---|---|---|
| Window Mode | Borderless / Exclusive / Windowed | Default Borderless |
| Window Size | 1280x720 … 2560x1440 | Windowed only; the logical canvas is always 1600x900 |
| Monitor | 1..N | |
| Render Resolution | Native / Auto / Cap 900p / 720p / 540p | Potato Cap 900p, Low and Medium Auto, High Native. Auto caps only above 1080p. 720p/540p render the whole run in a SubViewport (`scene/level/run_view.gd`) and scale it up; menus behave as Auto |
| V-Sync | On / Adaptive / Off | |
| Frame Rate Limit | Match display / 30 / 60 / 120 / 144 / Unlimited | Potato and Low: 60 |
| Menu Frame Rate | 30 / Same as game | Potato and Low: 30; main and pause menus only |
| Pause When Unfocused | On / Off | Never over the slot machine or countdown |
| Performance Overlay | Off / FPS / Detailed | Same as F3 |
| Renderer (Troubleshooting) | Standard / Compatibility | Restart. Standard is Vulkan Mobile; Compatibility is OpenGL via Godot's built-in ANGLE/D3D11 on Intel. Works in exports |

### Audio, Controls, Accessibility, Gameplay

- **Audio:** Master, Music, Voice, Effects and Menu Sounds (0–100% perceptual, 0 dB max, each with a mute); Mute When Unfocused.
- **Controls:** rebind Accelerate, Brake, Steer Left/Right, Pause and Use Gadget (two keys plus one pad input each); stick deadzone; vibration Off/Low/High.
- **Accessibility** (overrides presets without making them Custom): Reduce Motion, Reduce Flashing, giant marker style and colour, Plain Text, Car Shake, HUD Scale (80–130%).
- **Gameplay:** speed units, Show Run Timer, Confirm Abandon / Quit, Car Paint, Reset Progress (keeps settings).

There are deliberately no MSAA, FXAA, HDR-2D or glow options, and **the physics tick rate is never exposed**.

## Always on

- **World streaming** (docs/WORLD.md): map built on a worker; rasters and recipes built on workers; the main thread applies chunks within `APPLY_BUDGET_USEC`; nodes are pooled; chunks more than 2 away unload. Per-chunk budgets: docs/WORLD.md, "Budgets".
- **Goons:** capped at 250 for everyone; off-screen goons skip collision; spawns are staggered; the despawn sweep runs every 0.5 s. They move in floating mode (top-down), not CharacterBody2D's grounded default.
- **Native code** (docs/NATIVE.md): the goon tick's fields and movement helpers (`GoonBody`), the terrain queries and WorldHooks' grid walks (`WorldGrid`), and the map build's crossings pass (`WorldGenNative`) are C++. Goon script went from 62 to 30 µs per goon per tick; the map build from 1.36–2.02 s to 0.82–1.29 s.
- **Rewards** are credited at once; flyers are pooled visuals.
- **Batching and textures:** one text shader, shared pickup materials, mipmaps on world textures, BC7 for large backgrounds, portraits, ground materials and posters. A level loads only its own world art (about 17 MB of 48 MB budget).
- **Lights:** 2D shadow atlas 1024; no world lights (landmarks use unlit beacon sprites).
- **Loading:** levels and the car load on worker threads; the menu loads `CarInfo`, not car scenes; shaders warm up behind the countdown.
- **Physics overload:** `max_physics_steps_per_frame = 4` (brief slow motion instead of a stall).

## Latest results on the HD 620

Measured 2026-10-07 with the native goon tick, grid and crossings. Vulkan Mobile, 1920x1080 borderless, uncapped, 90 s, one run per cell. Avg / 1% low fps; in brackets the 2026-10-06 GDScript numbers from the same box.

| Scenario | fps | p99 frame | Under 17.5 ms | Frames > 50 ms | Max goons |
|---|---|---|---|---|---|
| S2 day drive, prairie, Low | 125.8 / 81.4 (126.0 / 78.3) | 10.8 ms | 100% | 0 | 36 |
| S3 night, quarry, Low | 74.1 / 41.9 (65.8 / 20.3) | 19.3 ms | 97.5% (86.5%) | 2 (24) | 99 |
| S4 night crowd, quarry, Low (2 runs) | 54.4 / 21.1, 56.3 / 25.4 (45.5 / 18.2, 49.2 / 17.5) | 35–44 ms | 65–68% (59%) | 7, 2 (42, 111) | 190–201 |
| S4 night crowd, prairie, Low | 54.4 / 19.1 (49.4 / 13.6) | 44.6 ms | 62.7% (68.7%) | 21 (303) | 250 |
| S4 night crowd, quarry, Potato | 94.7 / 28.0 (76.1 / 15.1) | 29.2 ms | 84.4% (80.1%) | 12 (236) | 202 |

The S3 night, city and S6 rows of 2026-10-06 weren't re-run. Chunk work (`WORLD_CHUNKS`): fine raster about 16–25 ms and recipe 7–8 ms average on workers; main-thread apply 1.6–1.9 ms average, longest step under 5 ms.

- **The goon tick halved; crowds still miss the S4 targets.** In a profile of S4 (counters in `Walker`), goon script cost 62 µs per goon per tick before and 30 after (docs/NATIVE.md has the breakdown). Physics by crowd size on Low: 80–120 goons 13 → 4.5–5 ms per frame, 120–160 goons 16.6 → 8–10 ms; above 160 goons it is still 10–12 ms, now mostly the physics server and other nodes (goon script is under a quarter of it). Long frames are rare now (2–21 per run instead of 42–303), but the 1% low stays at 19–28 fps.
- GPU time stays at 9–12 ms on Low (4 on Potato) whatever the crowd, so Potato's S4 average clears its 58 fps target; its 1% low doesn't.
- Prairie's S4 is inflated by churn: the bench car can't drown and circles over lakes, where following goons keep drowning and respawning.
- Compatibility ran pinned at 16.67 ms despite `--uncapped` (V-Sync forced through ANGLE). It stays a troubleshooting option.

## Decisions

- Lighting Medium (Low preset) keeps all shadows so night stealth plays the same; only Lighting Low (Potato) drops them.
- No Night Visibility Assist; smoke stays drawn over goons; volume sliders top out at 0 dB.
- The 250-goon cap and despawn sweep apply to everyone.
- Measured and dropped: a goon texture atlas (fewer draw calls, no real time saved); physics interpolation (no measurable effect at 60 Hz; would need a check on 120/144 Hz displays and an audit of teleporting nodes).

## Still open

- Night crowds above 160 goons: physics is still 10–12 ms per frame on Low, now mostly outside goon script. Next steps: no collision for off-screen goons (they never use it, but they still sit in the broadphase and move every tick), then a lower cap on Low and Potato, then native verbs (docs/NATIVE.md, "What to port next").
- Load time: the map build is 0.8–1.3 s; `WorldField.sample` is the next native port.
- Should Low or Potato default to 720p?
- Unmeasured: 4K (stepped text slices on the titles, ground seams), vsync-on runs, medians of 3 runs.
- Per-canvas-item 2D light limits are unconfirmed; watch for lights popping near a station at night.

## Benchmarking

`scripts/debug/bench.gd` (autoload `Bench`): inert without `--bench`; boots through the menu, saves to a scratch copy, fixes the seed (default 1337), drives with an autopilot, and resets health, fuel and the deep-water counter every tick. Output: a per-frame CSV (with `chunk_ms` and `occluders`) and a `summary.csv` row in `user://bench/`; `WORLD_CHUNKS` prints at exit.

```
Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90
Godot_console.exe --path . -- --bench=S3 --level=city --uncapped --preset=low --tag=_city
Godot_console.exe --path . -- --bench=S2 --mode=sprint --at=station --pattern=none --shot=8 --seconds=10
```

Options (the header lists all): `--preset`, `--set=gfx/lighting:0;...` (values go through `str_to_var`, so strings need quotes, e.g. `display/render_res:"720"`; PowerShell strips them unless the command line is built with `Start-Process -ArgumentList`), `--shot=5;30`, `--tag`, `--headlights=N`, `--open-settings`, `--notext`, `--car`, `--damage=engine:35;...`, `--level=<id>`, `--seed=N`, `--pattern=none|sine|circle|route`, `--at=water|wall|station|x,y`, `--zoom=0.4`. For a Compatibility spot check put `--rendering-method gl_compatibility` before the `--`.

| ID | Scenario | Stresses |
|---|---|---|
| S1 | Main menu idle | 3D text fill |
| S2 | Day drive, prairie, sedan | terrain, smoke, streaming |
| S3 | Night, quarry, police car, circling | lights, shadows, occluders |
| S4 | S3 plus maximum spawn pressure | goon physics, draw calls |
| S5 | 5 slot claims | celebrations, reels |
| S6 | 10-minute drive | streaming, hitches |
| S7 | 10 purses at night | reward flyers, HUD |
| SL | Parked at night, no goons | lighting parity screenshots |

**Run conditions:** from a clean `git worktree` of HEAD, on AC power, with a cool-down between runs (thermals add about ±20%), with nothing else running. Never pipe Godot output into `head`.

**Targets** (1080p, Vulkan): Low holds 99% of frames under 17.5 ms in S1–S3, and S4 averages at least 55 fps with a 1% low of at least 45. Potato S4: at least 58 / 45. A change should not regress Low's S1–S4.
