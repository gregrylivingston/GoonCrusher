# GoonCrusher: Performance and Settings

This is a reference for GoonCrusher's performance work and the settings system. It covers how settings work, what each option does, the measured results, the decisions behind them, and what is still open.

It replaces the original plan. The plan was carried out on branch `perf-settings` in October 2026, and its history is in git (`git log -- docs/PERFORMANCE_SETTINGS_PLAN.md`).

The reference machine is the dev box: an Intel HD 620 integrated GPU with 4 threads, running Godot 4.7.2. It counts as a "potato" PC.

---

## How settings work

**Where settings are stored**

| File | Contents | Steam Auto-Cloud |
|---|---|---|
| `user://settings.cfg` | Audio, controls, accessibility, gameplay options | Sync |
| `user://graphics.cfg` | Display and graphics settings, the detected tier and GPU, the boot counter | Don't sync: these are per machine |
| `user://override.cfg` | Only the renderer choice. It is read at engine start through `application/config/project_settings_override`. | Don't sync |
| `user://saveData_0.1.tres` | Progress only. Its `settings` field is legacy: `Settings.import_legacy_volume()` reads it once, and nothing writes it. | Sync |

`user://` is `%APPDATA%/GoonCrusher/`. Reset Progress never touches the settings files.

**The `Settings` autoload** (`scripts/global/settings.gd`, loaded first)
- **Loading:** reads both config files over `DEFAULTS` and clamps every value to `OPTIONS`/`RANGES`. Keys missing from the file come from the stored tier's `PRESET` column.
- **Saving:** debounced by 0.5 s, and also flushed when the overlay closes and on quit.
- **Runtime changes reach the game in three ways:**
  - **Shader globals** (`gc_*`, declared in `project.godot [shader_globals]`) for text quality, motion, pickup glow and the giant marker.
  - **A `node_added` hook** (connected in `_enter_tree`) that ANDs the Lighting level with each light's and occluder's authored state, stored in the `gc_shadow`, `gc_enabled` and `gc_vis` metadata.
  - **`Settings.get_value()` and the `changed` signal** where each effect is spawned.
- **Restart:** the renderer is the only setting that needs one. It writes `override.cfg` and offers a restart.
- **Safe mode:**
  - Two boots in a row that never reach the menu, or `-- --safe-mode`, apply Potato, windowed and Compatibility **for that session only**, then ask whether to keep them.
  - Headless runs and bench runs never count as crashed boots.
  - `-- --reset-graphics` deletes `graphics.cfg` and `override.cfg`.
- **First run:**
  - The tier comes from the adapter type and name and the thread count.
  - Then the menu measures its own GPU time over 120 frames, and steps down one tier if the GPU is clearly slower than the tier assumes. The limits are 2× the HD 620's time on Low, 0.8× on Medium and 0.5× on High, scaled to 1080p. Calibration runs only on the standard renderer.
  - A toast names the chosen preset.
- **Adapter identity is stored as vendor plus device ID.** A renderer switch is therefore not mistaken for a new GPU. Under ANGLE the vendor reads "Google Inc. (Intel)".
- **The F3 overlay** cycles Off, FPS and Detailed. Detailed shows frame time, process and physics ms, GPU ms (n/a on Compatibility), draw calls, nodes, goons, chunks, lights and the renderer.
- **The runtime advisor** shows once per install: if the 1% low stays under 45 fps in the first 90 s of a run, the summary suggests Potato.

**The overlay** (`scene/player/menu/settings/`)
- **How it's built:** `settings_menu.gd` builds the tabs from `buildSchema()`. Each row is an `OptionRow`: a choice, slider, button, header or key binding. `SettingsDialog` is the shared confirmation dialog.
- **Navigation:** fully usable with a controller (LB/RB switch tabs, B goes back). Display changes ask to confirm or revert within 15 s.
- **Info panel:** shows each option's effect, its performance cost, whether it affects gameplay, and whether it needs a restart.
- **Input underneath is blocked:** `Settings.menu_open` stops the menu, HUD and pause menu behind the overlay from reacting to input.
- **To add a setting:**
  1. Add the key to `DEFAULTS`, plus `OPTIONS`/`RANGES` and `PRESET` if presets drive it.
  2. Apply it in `Settings.applyKey`, or read it where it's used.
  3. Add a row to the schema.

---

## The options

### Graphics

The top row is **Quality Preset: Potato / Low / Medium / High**, shown as Custom once any value is changed, plus a **Detect Again** button. Presets set only the keys in the table below.

| Option | Values | Potato | Low | Medium | High | Effect |
|---|---|---|---|---|---|---|
| Text Effects | Flat / Still 3D / Animated / Animated HD | Flat | Still 3D | Animated | Animated HD | Drives the single `shader/3dtext.gdshader` through `gc_text_quality` and `gc_text_max_slices` (1/4/8/16). The slice count adapts: at rest, text uses only as many slices as its extrusion needs. |
| Lighting | Low / Medium / High | Low | Medium | Medium | High | **High** is as authored. **Medium** keeps every shadow and occluder, but uses a smaller shadow atlas and no glow on collected pickups; night plays the same. **Low** turns off shadows and the small lights, and lights the station yard with one large lamp. **Low affects gameplay:** shadows no longer hide goons behind rocks. The headlight cone always scales with the Headlights stat. |
| Simple Headlight Cone | On / Off | On | On | Off | Off | One baked shadowed cone (`texture/fx/headlight_cone.png`) instead of 5 headlamps, with the same reach and brightness. Re-bake it with `scripts/debug/bake_headlight_cone.gd` if the lamps change. |
| Exhaust Smoke | Off / Low / Full | Off | Low | Full | Full | Pooled puffs. Off stops the emitter loop. |
| Tire Marks | Off / Short / Full | Off | Short | Full | Full | Short: rear tyres only, 6 s. Full: all tyres, 20 s. Points are spaced and segments pooled. |
| Pickup Glow | Simple / Full | Simple | Simple | Full | Full | Simple keeps the full-width outline but drops the moving shine. |
| Slot Celebration | Minimal / Reduced / Full | Minimal | Reduced | Full | Full | The icon wall and icon burst; node counts are cut on lower levels. Reels and results are the same at every level. |
| Reward Pop-ups | Minimal / Reduced / Full | Minimal | Reduced | Full | Full | Caps flying reward icons at 3, 10 or 20. Rewards are credited when collected, never by the animation. |
| Max Sound Effects | 8 / 12 / 24 | 8 | 12 | 24 | 24 | Size of the `Audio` FX pool. Engine, crash and voice sounds are separate. |

### Display

| Option | Values | Notes |
|---|---|---|
| Window Mode | Borderless / Exclusive / Windowed | Default Borderless |
| Window Size | 1280x720 … 2560x1440 | Windowed only. The logical canvas is always 1600x900. |
| Monitor | 1..N | |
| Render Resolution | Native / Auto / Cap 900p / 720p / 540p | Presets: Potato Cap 900p; Low and Medium Auto; High Native. Cap 900p uses viewport content scale, but only when the window is larger than 1600x900. Auto caps only above 1080p. **720p and 540p** draw the whole run (level, HUD, in-run menus) into a SubViewport of that height with the 1600x900 logical canvas, through `scene/level/run_view.gd`, and scale it up; menus behave as Auto. The world view is identical at every setting. |
| V-Sync | On / Adaptive / Off | |
| Frame Rate Limit | Match display / 30 / 60 / 120 / 144 / Unlimited | Potato and Low default to 60. "Match display" with V-Sync on leaves pacing to V-Sync. |
| Menu Frame Rate | 30 / Same as game | Potato and Low use 30. Applied only in the main menu and pause menu, never during the slot machine, countdown or summary. |
| Pause When Unfocused | On / Off | Opens the pause menu, never over the slot machine or countdown |
| Performance Overlay | Off / FPS / Detailed | Same as F3 |
| Renderer (Troubleshooting) | Standard / Compatibility | Needs a restart. Standard is Vulkan Mobile, or D3D12 by engine fallback. Compatibility is OpenGL, which runs through ANGLE/D3D11 on Intel because Godot blocklists the Intel GL driver. Works in exported builds; no ANGLE DLLs are needed. |

### Audio, Controls, Accessibility, Gameplay

- **Audio:**
  - Master, Music, Voice, Effects and Menu Sounds sliders, 0–100% on a perceptual curve with 0 dB at the top, each with its own mute.
  - Mute When Unfocused.
  - Goon and slot sounds play on the FX bus.
- **Controls:**
  - Rebind Accelerate, Brake, Steer Left, Steer Right and Pause: two keyboard keys plus one controller input each.
  - Stick deadzone and vibration Off / Low / High.
  - Start pauses.
- **Accessibility** (these override presets without turning them into Custom):
  - Reduce Motion and Reduce Flashing.
  - Giant marker style (Pulse / Steady / Tint + ring) and colour (Red / Yellow / Cyan / Magenta / White).
  - Plain Text, Car Shake, and HUD Scale (80–130%).
- **Gameplay:**
  - Speed units (MPH / km/h).
  - Show Run Timer, flagged as gameplay information in Sprint and Marathon.
  - Confirm Abandon / Quit (needs a second press).
  - Reset Progress, which keeps settings.

There are deliberately no MSAA, FXAA, HDR-2D or glow options. **The physics tick rate is never exposed** because handling, fuel and goon timers are computed per tick.

---

## Always-on changes (no setting)

These went in for every player. File-level detail is in the `perf-settings` commit history.

- **World streaming:**
  - Chunks unload by distance (Chebyshev > 2), and the station chunk is pinned.
  - At most one chunk loads per frame, with a prefetch ring.
  - Landscape TileMaps are pooled, 8 per terrain.
  - Each chunk's objects come from its own seed, so going back regenerates the same rocks and coins.
- **Terrain generation:**
  - The 256×256 map is stored in packed arrays (`terrainMap`, `regionMap`) and built, with its regions, on a `WorkerThreadPool` task.
  - Regions are labelled by an iterative flood fill.
- **Goons:**
  - Capped at 250 for everyone (`SpawnManager.GOON_CAP`).
  - Swept every 0.5 s when more than 8000 px away and off screen.
  - Goons outside the view skip collision queries (off-screen LOD).
  - Spawns are staggered across frames.
- **Rewards are credited at once,** and fly-to-HUD icons are pooled visuals on their own CanvasLayer. This also fixed a purse double-collect.
- **One text shader.** All ~24 inline copies now reference `shader/3dtext.gdshader`. Never paste it inline again.
- **Batching and textures:**
  - Pickup materials are shared.
  - World textures have mipmaps with the Linear Mipmap default filter.
  - Large backgrounds, portraits and the explosion flipbooks use BC7.
- **Lights:**
  - The 2D shadow atlas is 1024.
  - Tail-lamp energy is set only when the brake state changes.
  - The station's micro-lights were removed, and its lights are off during the day.
- **Frame-rate independence:**
  - Slot reels advance in `_physics_process` and recycle their icons, at most 12 per reel.
  - Other per-frame animations are delta-based, so frame caps are safe.
- **Loading:**
  - Levels and the car scene load on worker threads behind a "Loading..." label.
  - The menu shows `CarInfo` resources (`scene/car/<car>/<car>_info.tres`), not car scenes.
  - Shaders are warmed up during the countdown.
- **Saves** are debounced by 1 s and flushed on scene change and quit.
- **Physics overload:** `max_physics_steps_per_frame = 4`, so overload causes brief slow-motion instead of a stall.
- **Cleanup:**
  - 22 empty `_process` stubs were removed.
  - The HUD rebuilds strings only when a value changes.
  - Car shake is a sprite offset, not a new tween every few ticks.
- **Repo and exports:**
  - `.godot/` is untracked.
  - `export_presets.cfg` is tracked, with filters that keep tests and editor addons out of the `.pck`.
  - The menu fonts moved out of `addons/gut`.

---

## Results on the HD 620

Vulkan Mobile, 1920x1080 borderless, uncapped, one run per cell. Cells are avg fps / 1% low fps.

| Scenario | Before (`7f49e14`) | Low | Potato | High |
|---|---|---|---|---|
| S1 main menu | 96.1 / 81.0 | 123.0 / 106.1 | | |
| S2 day drive | 106.6 / 43.7 | 128.1 / 84.3 | | |
| S3 night, 150+ goons | 23.1 / 8.3 | 56.9 / 40.1 | 116.0 / 47.0 | 24.2 / 14.1 |
| S4 late-game night crowd | 20.7 / 6.9 (337 goons) | 55.0 / 37.9 (250 goons) | 111.9 / 61.2 | |
| S5 5 slot claims | 89.8 / 15.4, 35 frames > 50 ms | 118.2 / 55.4 | | |
| S6 10-minute drive | 67.9 / 7.1; 111 chunks, 1,235 frames > 50 ms | 121.6 / 57.4; 12 chunks, 16 frames > 50 ms | | |
| S7 10 purses at night | 40.3 / 34.4 | 64.7 / 59.3 | | |

Render Resolution on Low:

| | Native | 720p | 540p |
|---|---|---|---|
| S3 night | 56.9 / 40.1 | 78.0 / 40.6 | 101.4 / 57.7 |
| S4 night crowd | 55.0 / 37.9 | 76.1 / 34.7 | |

**What the numbers mean**
- **Startup:** 2.5 s to the menu (was 3.7–5.4 s). The longest frame during a level load is 75–85 ms (was a 1.7 s freeze).
- **Night is fill-bound on the HD 620:** a 1280x720 window ran S3 at 121 fps, against 57 at 1080p. That is why 720p and 540p exist.
- **The menu's 3D text costs 2.9 ms per frame,** confirmed by measuring with it off.
- **Low's S4 1% low is 37.9,** under the target of 45. The remaining cost is goon-against-goon physics when 250 goons crowd the car on screen; off-screen LOD can't help there. Running 2D physics on its own thread was slower.
- **Compatibility (ANGLE) is slower** on this machine: 15–55% before the changes, and S3 21.0 / 7.5 before. It is a troubleshooting option, not a default.

---

## Decisions

- **Lighting Medium** (the Low preset) keeps all shadows and occluders, so night stealth plays the same. Only Lighting Low (Potato) drops shadows. 2D shadows block light fully whatever `shadow_color` alpha is set to, so without them goons behind rocks become visible.
- **Rejected options:** no Night Visibility Assist. Smoke stays drawn over goons.
- **The title text follows the preset.** Volume sliders top out at 0 dB.
- **The demo and the full game share the save,** which is migrated in place.
- **The despawn sweep, the iterative region fill and the 250-goon cap** apply to everyone.
- **Presets default Render Resolution to Auto.** Whether Low or Potato should default to 720p is still open.

**Measured and dropped**
- **Goon texture atlas:** it cut S4 draw calls from 178 to 116 but saved only 0.1 ms of render CPU and no GPU time.
- **Physics interpolation** (`physics/common/physics_interpolation`): no measurable cost and no measurable benefit at 60 Hz. Shipping it needs a check by eye on a 120/144 Hz display, and an audit of nodes that teleport: pooled goons and landscapes, smoke, the car on restart.

---

## Still open

- **Unmeasured:** 4K (scenario S8; no 4K panel available), vsync-on runs, and 3 runs per cell with the median reported.
- **Should Low or Potato default to 720p?**
- **Check at 4K:**
  - Adaptive text slices on the GOON/CRUSHER titles: if they look stepped, scale the slice count by the canvas scale.
  - Terrain seams from mipmaps or compression: keep the terrain atlases lossless if seams appear.
- **2D lights per canvas item:** a per-item light limit couldn't be confirmed. Watch for lights popping near a station at night.
- **Shipping needs the 4.7.2 export templates.** Only 4.7.0 templates are installed on the dev box.

---

## Benchmarking

**The harness** is `scripts/debug/bench.gd`, the `Bench` autoload.
- **Inert unless launched with `--bench`.** Its header lists every option.
- **Real settings and progress are safe:** it boots through the menu and saves to a scratch copy.
- **Repeatable:** it fixes the seed and drives the car with an autopilot.
- **Output:** a per-frame CSV and a `summary.csv` row in `user://bench/`.

```
Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90
Godot_console.exe --path . -- --bench=S2 --mode=sprint --level-seconds=8 --seconds=25
```

| ID | Scenario | Stresses |
|---|---|---|
| S1 | Main menu idle | 3D text fill |
| S2 | Day drive, `level_grass_1`, sedan | terrain, smoke, streaming |
| S3 | Night, `level_mud_3`, police car, circling | lights, shadows, occluders |
| S4 | Late-game night crowd (S3 plus maximum spawn pressure) | goon physics, draw calls |
| S5 | 5 slot claims | celebrations, reels |
| S6 | 10-minute drive | streaming, hitches |
| S7 | 10 purses at night | reward flyers, HUD |
| SL | Parked at night, no goons (`--headlights=N --shot=…`) | lighting parity screenshots |

**Run conditions**
- **Run from a clean `git worktree` of HEAD,** so uncommitted edits don't skew numbers.
- **On AC power,** with a cool-down between runs; laptop thermals add about ±20%.
- **Don't pipe Godot output into `head`:** it leaves the process running. Capture the output, then filter it.
- **Quoting:** `--set` string values need quotes, for example `display/render_res:"720"`. PowerShell strips them unless the command line is built with `Start-Process -ArgumentList`.

**Targets** (1080p, Vulkan): Low holds 99% of frames under 17.5 ms in S1–S3, and S4 averages at least 55 fps with a 1% low of at least 45. Potato S4 averages at least 58 with a 1% low of at least 45. A change should not regress Low's S1–S4.
