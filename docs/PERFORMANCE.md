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
- **Low's S4 1% low is 37.9,** under the target of 45. The remaining cost is goon-against-goon physics when 250 goons crowd the car on screen; off-screen LOD can't help there. Running 2D physics on its own thread was slower. Goons now have their own physics layer and no longer collide with each other (`docs/GAMEPLAY_SUGGESTIONS.md`, shared prerequisites); S4 has not been re-measured since, and the goon overhaul changed the crowd too.
- **Compatibility (ANGLE) is slower** on this machine: 15–55% before the changes, and S3 21.0 / 7.5 before. It is a troubleshooting option, not a default.

---

## World revamp (branch `world-revamp`)

The world revamp (`docs/WORLD.md`) replaced the TileMap terrain with generated chunks. A coarse map is built on a worker at level start. Each chunk then gets a fine raster and a recipe, both built on workers, and the main thread applies the recipe a step at a time. These are the branch's final numbers, measured on 2026-10-06 at `99fe3b0` plus the final cleanups.

**Per-chunk budgets** (spec section 7, the `ChunkRecipe` constants; details in `docs/WORLD.md`, "Budgets and how they are enforced")

| Budget | Value | How it is enforced |
|---|---|---|
| World nodes | 100 (`MAX_NODES`; pickups not counted) | the fixed cost comes first (8 ground quads, the wall body, occluders, lines, one MultiMesh per decor id), then props in placement order; a prop that would go over the budget is dropped |
| Occluders | 16 (`MAX_OCCLUDERS`), each within 1,280 px (`SPAN`) | wall occluders are split at the span and the shortest are dropped; props past the remaining room are placed without their occluder |
| Static pieces | 48 (`MAX_PIECES`) | Douglas-Peucker simplification steps through 16, 32, 64 and 128 px until the convex pieces fit |
| Lines (shore foam, wall lips) | 24 (`MAX_LINES`) | split at the span, the shortest dropped |
| Area2D | none except pickups | |
| World lights | none | landmarks glow with an unlit additive sprite instead |
| Main-thread apply | 1.5 ms a frame (`APPLY_BUDGET_USEC`; a step may run past it, about 2 ms in all); 10 ms for the first 120 frames, behind the countdown | `ChunkView` applies one piece per step, and at most 2 new chunks open a frame. The only exception is the car's own chunk: its ground and collision go in at once |
| World textures per level | 48 MB | a level loads only its own materials and dressing, about 17 MB (`docs/WORLD_ART.md`) |

`test_world_recipe.gd` checks the recipe budgets for every level over 3 seeds, and it checks the node budget of an applied chunk.

**Measured chunk timings** (from the `WORLD_CHUNKS` line each run prints at exit). The workers share the dev box's 4 threads with the game.

| | Typical | Worst seen |
|---|---|---|
| Fine raster (worker) | 14–23 ms average | 39 ms |
| Recipe (worker) | 7–12 ms average | 21 ms |
| Apply (main thread), in a frame that applies anything | 1.2–2.3 ms average | 6–11 ms |
| Longest single apply step (prop, pickup, decor, extras) | 0.3–2.5 ms | 3.1 ms (an instanced breakable prop) |
| Frames with over 2 ms of apply in S6 (10 minutes, 161 chunks applied and released) | 52 of 709 apply frames | |

The `chunk_ms` column reaches 17–30 ms only in the first seconds of a run, while the start budget and the car's urgent chunk load run behind the countdown. In S6, only 4 of the 44 frames over 50 ms had more than 2 ms of chunk work.

**Benchmarks on the HD 620** (Vulkan Mobile, 1920x1080 borderless, uncapped, one run per cell unless noted). The first two columns are avg fps / 1% low fps. "Old" is the Low or Potato column of the table above, measured on the old world: S2 and S6 on `level_grass_1`, S3 and S4 on `level_mud_3`.

| Scenario | Old | World revamp | p99 frame | Under 17.5 ms | Frames > 50 ms | Max goons | Max visible occluders |
|---|---|---|---|---|---|---|---|
| S2 day drive, prairie, Low | 128.1 / 84.3 | 126.0 / 78.3 | 11.1 ms | 100% | 1 | 47 | 120 |
| S3 night, quarry, Low | 56.9 / 40.1 | 65.8 / 20.3 | 35.7 ms | 86.5% | 24 | 95 | 164 |
| S3 night, city, Low | | 78.3 / 49.5 | 18.1 ms | 98.7% | 2 | 85 | 96 |
| S3 night, prairie, Low | | 72.7 / 23.0 | 33.5 ms | 94.4% | 12 | 114 | 195 |
| S4 night crowd, quarry, Low (2 runs) | 55.0 / 37.9 | 45.5 / 18.2 and 49.2 / 17.5 | 50–52 ms | 59% | 42 and 111 | 208–237 | 276–305 |
| S4 night crowd, city, Low | | 62.3 / 30.7 | 28.1 ms | 73.7% | 3 | 209 | 219 |
| S4 night crowd, prairie, Low | | 49.4 / 13.6 | 66.9 ms | 68.7% | 303 | 250 | 350 |
| S4 night crowd, quarry, Potato | 111.9 / 61.2 | 76.1 / 15.1 | 58.3 ms | 80.1% | 236 | 250 | 69 |
| S6 10-minute drive, prairie, Low | 121.6 / 57.4; 16 frames > 50 ms | 93.9 / 30.6 | 25.0 ms | 94.3% | 44 | 159 | 248 |
| S2 day drive, prairie, Low, Compatibility | | 57.8 / 32.9 | 25.3 ms | 58.5% | 3 | 62 | 165 |

**What the numbers mean**
- **Streaming stays inside its budget.** S2 stresses terrain and streaming by day, and it matches the old world within noise: 126 fps against 128, with a p99 of 11 ms. A frame that applies anything spends about 1.3 ms on chunk work, and chunk work is almost never behind a long frame.
- **Night and crowds miss the targets.**
  - Low S3 keeps 86–99% of frames under 17.5 ms, against a target of 99%.
  - Low S4 is 45–49 / 18, against 55 / 45.
  - Potato S4 is 76 / 15, against 58 / 45.
- **The cost is the physics tick, not the GPU or the world.**
  - GPU time stays at 9–11 ms on Low (3–5 ms on Potato), whatever the number of goons.
  - `physics_ms` climbs with the crowd: about 2 ms with no goons, 10–14 ms with 120–200.
  - Once a frame passes 16.7 ms, the next one runs two physics ticks, so a crowd tips the game into a run of 30–40 ms frames.
  - S6 shows the same thing over time: its slow minutes (7 and 8) are the ones with 120–130 goons.
  - Potato is just as spiky, even though it drops goon occluders (69 visible, against 305 on Low), so shadows are not the cause either.
- **The old S3 and S4 numbers predate the goon overhaul** (43 goons with verbs, `docs/GOONS.md`) and the goon physics layer. This branch was never benchmarked against its base commit, so it is not yet known how the crowd cost splits between the goon overhaul and the world. The world's share would come from goons sliding on chunk collision on screen, and from `WorldHooks.slideStep` and the water check off screen.
- **Prairie's S4 is the worst:** 303 frames over 50 ms, with fewer goons on screen than quarry. The bench car now survives deep water, so it circles over prairie's lakes, and the goons following it keep drowning and being replaced. That much churn doesn't happen in normal play, because the car can't stay on the water.
- **Compatibility** ran at a steady 16.67 ms median despite `--uncapped`. That looks like V-Sync forced through ANGLE, so the cell shows the cap, not the renderer's speed. Compatibility remains a troubleshooting option.

**Noise and caveats**
- The author's Godot editor was open on the main tree throughout, which adds a little CPU load.
- All runs were one per cell, on AC power. The two S4 quarry runs differ by 8% in average fps.
- Two runs had to be redone:
  - A broken lock let the first S2 and S3 runs overlap a headless playtest.
  - S2's sine drive drowned the car at 49 s. The bench's god mode now resets `lethalTicks` as well as health, so a benchmark car never drowns.
- The phase-4 S6 runs in the branch history drowned after 30–46 s, so they mostly measured the results screen.
- The playtest harness now plays the `cautious` AI profile by default, because it was the best all-round profile in the tournaments (`docs/AI_DRIVER.md`). Playtest numbers from before this change used `default` and can't be compared with later ones.

**Next steps for performance**
- Benchmark S3 and S4 on the branch's base commit (a clean worktree of the parent of `40332c3`), so the crowd cost can be split between the goon overhaul and the world.
- Profile the goon physics tick at 150–250 goons: `move_and_slide` against chunk collision on screen, `slideStep` and `lethalAt` off screen, and the verbs. Cheaper off-screen goons, or a lower goon cap on Low and Potato, would bring the 1% lows back up.

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

- **Night crowds on the new world** miss the Low and Potato targets (see "World revamp"): split the cost between the goon overhaul and the world by benchmarking the branch's base commit, then profile the goon physics tick.
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
- **Repeatable:** it fixes the seed and drives the car with an autopilot. The car can't die: health, fuel and the deep-water counter are reset every tick.
- **Output:** a per-frame CSV and a `summary.csv` row in `user://bench/`.

```
Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90
Godot_console.exe --path . -- --bench=S2 --mode=sprint --level-seconds=8 --seconds=25
Godot_console.exe --path . -- --bench=S3 --level=city --uncapped --preset=low --tag=_city
Godot_console.exe --path . -- --bench=S2 --mode=sprint --at=station --pattern=none --shot=8 --seconds=10
```

- **World options:** `--level=<id>` plays another level, `--seed=N` another map, and `--at=water|wall|station|x,y` moves the car once the world is ready (`station` needs a mode with one). The CSV adds `chunk_ms` (main-thread chunk work that frame) and `occluders` (visible `LightOccluder2D`s); `WORLD_CHUNKS` at exit gives the worker and apply timings.
- **Compatibility spot check:** put Godot's own `--rendering-method gl_compatibility` before the `--`. It changes no saved setting, unlike `--safe-mode`.

| ID | Scenario | Stresses |
|---|---|---|
| S1 | Main menu idle | 3D text fill |
| S2 | Day drive, `prairie` (was `level_grass_1` before the world revamp), sedan | terrain, smoke, streaming |
| S3 | Night, `quarry` (was `level_mud_3`), police car, circling | lights, shadows, occluders |
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
