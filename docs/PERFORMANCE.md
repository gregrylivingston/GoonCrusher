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
| Slot Celebration | Minimal / Reduced / Full | Minimal | Reduced | Full | Full | Icon wall and burst node counts; reels and results unchanged |
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
- **Goons:** capped at 250 for everyone; off-screen goons skip collision; spawns are staggered; the despawn sweep runs every 0.5 s.
- **Rewards** are credited at once; flyers are pooled visuals.
- **Batching and textures:** one text shader, shared pickup materials, mipmaps on world textures, BC7 for large backgrounds, portraits, ground materials and posters. A level loads only its own world art (about 17 MB of 48 MB budget).
- **Lights:** 2D shadow atlas 1024; no world lights (landmarks use unlit beacon sprites).
- **Loading:** levels and the car load on worker threads; the menu loads `CarInfo`, not car scenes; shaders warm up behind the countdown.
- **Physics overload:** `max_physics_steps_per_frame = 4` (brief slow motion instead of a stall).

## Latest results on the HD 620

Measured 2026-10-06 on the current world. Vulkan Mobile, 1920x1080 borderless, uncapped, one run per cell. Avg / 1% low fps.

| Scenario | fps | p99 frame | Under 17.5 ms | Frames > 50 ms | Max goons |
|---|---|---|---|---|---|
| S2 day drive, prairie, Low | 126.0 / 78.3 | 11.1 ms | 100% | 1 | 47 |
| S3 night, quarry, Low | 65.8 / 20.3 | 35.7 ms | 86.5% | 24 | 95 |
| S3 night, city, Low | 78.3 / 49.5 | 18.1 ms | 98.7% | 2 | 85 |
| S3 night, prairie, Low | 72.7 / 23.0 | 33.5 ms | 94.4% | 12 | 114 |
| S4 night crowd, quarry, Low (2 runs) | 45.5 / 18.2, 49.2 / 17.5 | 50–52 ms | 59% | 42, 111 | 208–237 |
| S4 night crowd, city, Low | 62.3 / 30.7 | 28.1 ms | 73.7% | 3 | 209 |
| S4 night crowd, prairie, Low | 49.4 / 13.6 | 66.9 ms | 68.7% | 303 | 250 |
| S4 night crowd, quarry, Potato | 76.1 / 15.1 | 58.3 ms | 80.1% | 236 | 250 |
| S6 10-minute drive, prairie, Low | 93.9 / 30.6 | 25.0 ms | 94.3% | 44 | 159 |

Chunk work (`WORLD_CHUNKS`): fine raster 14–23 ms and recipe 7–12 ms average on workers; main-thread apply 1.2–2.3 ms average in frames that apply anything, longest single step about 3 ms.

- **Streaming stays inside its budget;** chunk work is almost never behind a long frame.
- **Night crowds miss the targets, and the cost is the physics tick:** GPU time stays at 9–11 ms on Low (3–5 on Potato) whatever the crowd, while `physics_ms` climbs from about 2 ms with no goons to 10–14 ms with 120–200; past 16.7 ms a frame runs two ticks and the game tips into 30–40 ms frames. Potato is just as spiky with far fewer occluders, so shadows aren't the cause.
- The older S3/S4 baselines (Low S4 55.0 / 37.9 on the previous world) predate the goon overhaul, so the crowd cost hasn't been split between the goons and the world; both builds miss the S4 target because of physics with crowds.
- Prairie's S4 is inflated by churn: the bench car can't drown and circles over lakes, where following goons keep drowning and respawning.
- Compatibility ran pinned at 16.67 ms despite `--uncapped` (V-Sync forced through ANGLE). It stays a troubleshooting option.

## Decisions

- Lighting Medium (Low preset) keeps all shadows so night stealth plays the same; only Lighting Low (Potato) drops them.
- No Night Visibility Assist; smoke stays drawn over goons; volume sliders top out at 0 dB.
- The 250-goon cap and despawn sweep apply to everyone.
- Measured and dropped: a goon texture atlas (fewer draw calls, no real time saved); physics interpolation (no measurable effect at 60 Hz; would need a check on 120/144 Hz displays and an audit of teleporting nodes).

## Still open

- Night crowds: profile the goon physics tick at 150–250 goons (`move_and_slide` on screen, `slideStep`/`lethalAt` off screen, the verbs); consider cheaper off-screen goons or a lower cap on Low and Potato.
- Native code is available for hot paths the profile finds: a C++ GDExtension in `native/` (docs/NATIVE.md, which lists the candidates: world workers, a batched goon step, the `World` queries).
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
