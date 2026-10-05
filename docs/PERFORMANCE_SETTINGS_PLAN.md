# GoonCrusher: Settings, Performance and Potato-Mode Plan

This document has three goals:
- Overhaul the settings menu.
- Fix the performance problems that every player hits.
- Add performance settings so low-end PCs (no discrete GPU) can turn off expensive cosmetic effects while gameplay-essential visuals stay readable.

**How this plan was made.**
- Five subsystem reviews.
- Three performance audits (GPU, CPU, project/assets), each checked by a skeptical reviewer.
- Real FPS measurements on the dev box: Intel HD 620, 4 threads, Godot 4.7.2.
- Three independent plan drafts merged into this one.
- Two final checks:
  - every engine API named here was checked against the 4.7.2 class reference generated with `--doctool`, and the shader and renderer behaviour was tested in a throwaway project on the HD 620;
  - a coverage and readability review.
- Corrections from those checks are already folded in. Where a check overturned an earlier assumption, the text says so.

File:line citations are from commit `83abe66`.

---

## Status (2026-10-05): implemented on branch `perf-settings`

Phases 0 to 8 are in, one commit per phase (Phases 1, 6 and 7 share a commit because they live in the same Settings files). A second pass did the leftovers, including the parts of Phase 9 that measured as a win (see "Second pass" below). `CLAUDE.md` describes the new architecture.

### Results on the HD 620 (1920x1080 borderless, Vulkan Mobile, uncapped, 1 run per cell)

Baseline is commit `7f49e14` (Phase 0). "Low" is the preset the game now detects on this machine. Cells are avg fps / 1% low fps.

| Scenario | Baseline | Low | Potato | High |
|---|---|---|---|---|
| S1 main menu | 96.1 / 81.0 | 123.0 / 106.1 | | |
| S2 day drive | 106.6 / 43.7 | 135.3 / 73.3 | | |
| S3 night, 150+ goons | 23.1 / 8.3 | 56.3 / 39.0 | 116.0 / 47.0 | 24.2 / 14.1 |
| S4 late-game night crowd | 20.7 / 6.9 (337 goons, 675 frames > 50 ms) | 55.2 / 39.9 (250 goons, 1 frame > 50 ms) | 111.9 / 61.2 | |
| S5 5 slot claims | 89.8 / 15.4, 35 frames > 50 ms | 116.1 / 52.0, 4 frames > 50 ms | | |
| S6 10-minute drive | 67.9 / 7.1; 111 chunks, 844 goons, 7,118 nodes, 1,235 frames > 50 ms | 109.4 / 14.1; 12 chunks, 250 goons, 2,087 nodes, 1,119 frames > 50 ms | | |
| S7 10 purses at night | 40.3 / 34.4 | 64.7 / 59.3 | | |
| S3 on ANGLE (Compatibility) | 21.0 / 7.5 | | | |

- **Startup and loading:** 2.5 s from launch to the menu (was 3.7-5.4 s). A level loads on a worker thread behind a "Loading..." label; the longest frame during a load is 75-85 ms (was a 1.7 s freeze).
- **S6 spikes are no longer chunk loads** (none of the 1,119 frames over 50 ms is near a chunk change). All of them come in minutes 8-10, when 250 goons crowd the car on screen: goon-against-goon physics, about 24 ms per frame. The off-screen LOD cannot help there. Running 2D physics on its own thread was tried and was slower (S4 53.6 / 38.3), so it is off.
- **Against the section 9.4 targets (uncapped numbers):** Potato meets its S4 target (avg >= 58, 1% low >= 45). Low meets the S4 average (>= 55) but not the 1% low (39.9 against 45). S1 and S2 on Low are well under 17.5 ms.
- **Where the night cost went:** GPU time at night fell from about 35 ms to 14 ms on Low (Lighting Medium plus the Simple Headlight Cone). On Low, the rest of a slow S4 frame was goon physics; the off-screen goon LOD (7.3) addresses it.
- **Menu:** the 3D text cost 2.9 ms per frame in the menu (10.4 ms with it, 7.6 ms without), which confirmed it as the menu's main cost.
- **Not measured:** 4K (S8, no 4K panel), 3 runs per cell, vsync-on runs, ANGLE after the changes.

### Decisions taken (the author answered section 11)

- Q1: Lighting **Medium**, which the Low preset uses, keeps every shadow and occluder, so night stealth plays the same. Its saving comes from the smaller shadow atlas and the Simple Headlight Cone (one shadowed light instead of five). Only Lighting Low (Potato) drops shadows. This replaces the earlier "Medium hides goon occluders".
- Q2: no Night Visibility Assist. Q3: the title follows the preset. Q5: sliders top out at 0 dB. Q6: smoke stays over goons. Q7: the demo and the full game share the save, migrated in place.
- Q4 (section 7.3): all three items are in: the despawn sweep, the region flood fill rewritten as an iterative fill, and a 250-goon cap for everyone plus off-screen LOD (goons outside the view walk without collision queries).

### Where the implementation differs from the plan

- **Text shader:** every inline copy was rewritten to reference `shader/3dtext.gdshader` (A-24 done up front), so no `node_added` material swap is needed. The hook only handles lights and occluders.
- **Celebrations:** Full keeps the authored icon wall and sprite burst (both now sized from the logical rect). Reduced and Minimal cut node counts instead of moving to CPUParticles2D or a tiling shader.
- **Reward flyers** are drawn on their own CanvasLayer, so they stay visible at night without a light.
- **CLI flags:** Godot hides its own flags from scripts, so the game reads `-- --window=WxH` and `-- --uncapped` instead.
- **Safe mode** triggered by the boot counter applies Potato for that session only, then asks; nothing is saved unless the player accepts.
- **Hold to Confirm** is covered by Confirm Abandon / Quit (second press); there is no separate toggle.
- **Tests:** GUT 9.0.0 doesn't parse on Godot 4.7, so `tests/game` has its own small runner with GUT-style asserts.

### Second pass (2026-10-05): the items left over from the first pass

Measured from a clean worktree of the branch, on Low, 1920x1080 borderless, uncapped. Avg / 1% low fps.

| Scenario | Native (Low) | Render Resolution 720p | 540p |
|---|---|---|---|
| S3 night, 90 s | 56.9 / 40.1 | 78.0 / 40.6 | 101.4 / 57.7 |
| S4 night crowd | 55.0 / 37.9 | 76.1 / 34.7 | |
| S2 day drive | 128.1 / 84.3 | | |
| S5 slot claims | 118.2 / 55.4 | | |
| S6 10-minute drive | 121.6 / 57.4; 12 chunks, 16 frames > 50 ms (first pass: 109.4 / 14.1, 1,119 frames > 50 ms) | | |

**Done**
- **Phase 9, sub-900p rendering.** Render Resolution gains 720p and 540p. A run (level, HUD and in-run menus) is drawn into a SubViewport of that height, with the 1600x900 logical canvas (`size_2d_override`), and scaled up. The world view and every layout are unchanged; menus behave as Auto. `scene/level/run_view.gd`. Night lighting turned out to be fill-bound on the HD 620, which the first pass had missed: a 1280x720 window ran S3 at 121 fps against 57 at 1080p. Presets still default to Auto; whether Low or Potato should default to 720p is the author's call.
- **Phase 9, chunk pooling.** Unloaded landscape TileMaps are reused, up to 8 per terrain, saving about 0.5 ms per chunk load. Chunk objects are not pooled because they hold per-chunk state.
- **HUD Scale** (Accessibility, 80-130%). Each authored HUD control is scaled about its point nearest its anchor.
- **First-run GPU calibration.** When a new GPU is detected, the menu's GPU time is measured over 120 frames before the toast, and the tier steps down once if the GPU is clearly slower than the tier assumes.
  - On the HD 620 the menu costs the same at every preset (median 3.8 ms at 1080p), so it works as a GPU-speed probe.
  - Limits: 2x the HD 620's time on Low, 0.8x on Medium and 0.5x on High, scaled to 1080p.
  - It uses the median because the HD 620's p90 is 8.4 ms; the "p90 > 8 ms" rule in section 6 would have demoted the reference machine.
  - It runs only on the standard renderer: ANGLE does report GPU time, and Compatibility is slower by design.
- **A-9.** Slot reels recycle the icon that scrolled off, holding at most 12 instead of growing by 6 a second.
- **A-21, CarInfo.**
  - Each car's base stats and menu data (portrait, background, intro lines) live in `scene/car/<car>/<car>_info.tres`. The car copies them through `info`, so there's one place to edit.
  - The menu loads only CarInfos: a cold car switch skipped 100-160 ms of car scene. `Root.playerCar` is null in the menu.
  - The car scene loads on the worker thread with the level.
  - `car.tscn`'s placeholder portrait is gone.
- **A-20, BC7.** The three 1024x1024 explosion flipbooks use BC7, 5.6 to 1.4 MB each.
- **A-22.** The terrain map is packed arrays, built with its regions on a worker thread. The grid alone had cost 230-380 ms in one frame. The same seed gives the same cells and region ids, checked against the old code on three seeds.
- **A-23.**
  - `export_presets.cfg` (Windows Desktop) is tracked with the exclude filters, and an export confirmed they keep tests and editor addons out of the `.pck`.
  - GodotSteam loads on 4.7; its singleton registers and `steamInitEx` runs.
  - Shipping needs the 4.7.2 export templates; only 4.7.0 templates are installed here.
- **Exported-build test of the `override.cfg` switch.** It passes: Vulkan Mobile without the file, Compatibility through ANGLE/D3D11 with it, and no ANGLE DLLs needed.
  - The test found a bug, now fixed. Under ANGLE the adapter vendor reads "Google Inc. (Intel)", so switching renderer looked like a new GPU and reset the player to Potato.
- **Harness fixes.**
  - Headless runs (tests, `--import`) no longer re-detect the tier or count as crashed boots.
  - Bench runs no longer trip the crashed-boot counter. Before the fix, every third run started in safe mode (windowed, Potato).
  - The S6 autopilot escapes rock rings: a run had sat in one for 10 minutes.

**Measured and not kept**
- **A-20, goon atlas.** Drawing every goon from one shared texture (the best case for an atlas) cut S4 draw calls from 178 to 116. It saved 0.1 ms of render CPU and no GPU time, and fps didn't change (54.1 against 54.7). Godot's TextureAtlas importer also only wrote its failure placeholder when run from the command line.
- **Physics interpolation.** It costs nothing measurable (S4 54.1 / 38.2 with it, 55.0 / 37.9 without), and Godot moves Camera2D to physics processing when it is on.
  - Its benefit, smooth motion when the frame rate is above 60 Hz, can't be measured by the harness: in 2D the interpolated transforms exist only in the renderer.
  - Shipping it needs a look on a 120/144 Hz display and an audit of nodes that teleport (pooled goons and landscapes, smoke, the car on a restart).
  - It is a one-line project setting (`physics/common/physics_interpolation`) when someone can check it by eye.

**Still open**
- 4K (S8), vsync-on runs, 3 runs per cell.
- S6's first-pass spikes came from 250 goons crowding a stalled car. With the autopilot kept moving, the crowd peaks at 141, so S4 remains the crowd test.

---

## 1. Measured baseline (HD 620, 1600x900 window)

Each cell is min / avg / max FPS, leaving out the first 5 s of warm-up.

| Scenario | Vulkan Mobile, vsync on | ANGLE (Compatibility), vsync on | Vulkan, uncapped | ANGLE, uncapped |
|---|---|---|---|---|
| Main menu, idle | 59 / 60 / 61 | 58 / 59 / 60 | 87 / **93** / 97 | 57 / 82 / 89 |
| `level_grass_1`, sedan, day, wave 1 | 49 / 60 / 61 | **8** / 56 / 60 | 120 / **145** / 160 | 58 / 94 / 101 |
| `level_sand_1` | – | – | 83 / 134 / 157 | 61 / 80 / 98 |

**Takeaways**
- **Keep Vulkan Mobile as the default.** It was 15–55% faster than Compatibility on this iGPU. On Compatibility, Godot blocklists the Intel GL driver and runs ANGLE on D3D11. Compatibility belongs in a troubleshooting option and in the engine's automatic fallback.
- **The static main menu costs more to draw than early gameplay** (10.7 ms vs 6.9 ms uncapped). The prime suspect is the ray-marched "3D text" shader, which runs up to 64 slices on the titles. Phase 0 must confirm this by measuring the menu with those materials turned off, because 9 menu lights and the background art also contribute.
- **There was a one-off hitch about 38 s into the run** (8 fps on ANGLE, 49 on Vulkan). It looks like a shader compiling the first time it is used.
- **These numbers are the best case.** Night, late-game crowds, slot celebrations and 4K were **not** measured. The audits show these are the expensive paths: night lighting with shadows, uncapped goon counts, thousands of celebration nodes, and fill that scales with native resolution.
- **Startup:** 3.7–5.4 s to the first menu frame on Vulkan. A level load freezes for about 1.7 s.

---

## 2. Where the cost is

Ranked by expected impact on low-end hardware. Every item was confirmed by a reviewer unless marked otherwise.

| # | Cost centre | Bound | Gameplay role | Evidence |
|---|---|---|---|---|
| 1 | **Render resolution.** `canvas_items` stretch draws at native window resolution, so a 4K laptop draws 5.8× the pixels of 1600x900 for every shader. | GPU | essential | `project.godot:38-41` |
| 2 | **Night lighting.** `CanvasModulate` tweens to pure black, and each car has 8 `PointLight2D`s. 5 headlamps cast shadows, and `headlamp5`'s light rect is 10240x5760 px. Every goon, rock and wall has a `LightOccluder2D`. There are 11 station lights, and they are on during the day. | GPU | essential (headlight cone; its size is an upgrade stat) | `car.tscn:213-312`, `levelRoot.gd:63-79`, `station.tscn:229-271` |
| 3 | **3D text shader.** About 24 inline copies. Each draws `slices` (1–64) plus 16 taps per pixel, animated by `TIME`, on titles, buttons, HUD labels and the world-space station indicator. | GPU | cosmetic (the text itself is informative) | `shader/3dtext.gdshader:34,55,68,98-147`, `main2.tscn:45-57` |
| 4 | **Uncapped goons.** 5 spawners fire every 1 s at the timer's floor. A goon only despawns when it leaves idle more than 8000 px away. Goons collide with each other, and each runs `move_and_slide` every tick. | CPU | essential | `spawnManager.gd:41-73`, `walker.gd:39-40,72,107-125` |
| 5 | **Chunk unload leak.** The unload ring is asymmetric, so 38–287 chunks stay loaded after a long drive (about 16 expected). Crossing a chunk boundary instantiates 4–7 TileMaps in one frame. | CPU, memory, hitches | essential | `tileManager.gd:125-205` |
| 6 | **Exhaust smoke.** A 256 px puff every 0.06 s grows to 1024 px over 2 s, so about 33 puffs are alive per exhaust. Each re-parses a duplicated PackedScene, and the emitter loop never stops. | GPU overdraw, CPU | cosmetic | `smoke.gd:6-34` |
| 7 | **Slot celebrations.** The lotto wall builds `(w/40+5)·(h/40+5)` TextureRects from physical pixels: about 1,200 at 900p and about 6,000 at 4K. The icon burst adds 600 sprites with 600 unique 3D-icon materials. | CPU, GPU, hitch | cosmetic | `lottoTransition.gd:5-42`, `splashscreen_1.gd:10-33` |
| 8 | **Pickup shine.** Up to 61 neighbour taps per transparent texel, and `resource_local_to_scene` materials that never batch. | GPU (low) | informative (the outline is essential) | `shine.gdshader:16-46`, `coin.tscn:7-12` |
| 9 | **Batching breakers.** 244 separate goon frame PNGs and per-instance materials. | GPU (draw calls) | – | goon `SpriteFrames .tres` files |
| 10 | **Textures.** All 374 imports are Lossless with no mipmaps, while the camera sits at 0.45 zoom. About 68 MB of RGBA8 in a level. | GPU bandwidth, load time | – | `*.png.import` |
| 11 | **Tire marks.** A `Line2D` point every tick per tyre while skidding, with no cap. | CPU | cosmetic | `tiremark.gd:14-15` |
| 12 | **Synchronous saves.** Every slider tick and menu arrow press does a full `ResourceSaver.save`. | hitch | – | `saveManager.gd:102-104,109-165` |
| 13 | **Region labelling.** A recursive flood fill awaits one frame per tile, so about 65k coroutines keep running into gameplay. | CPU | essential | `landscapeGenerator.gd:55-104` |
| 14 | **Small items.** 22 empty `_process` stubs; new car-shake tweens every 2–10 ticks; the HUD rebuilds strings every frame; goon death sounds bypass the voice limiter. | CPU (low) | – | see §6 |

---

## 3. Design principles

1. **Lowering a setting must not change the game's difficulty.**
   - Goon caps, crowd physics and night brightness are never preset-driven. Anything that unavoidably changes what the player can see is labelled **"Affects gameplay"** in the menu.
   - The reviewers checked whether Low makes the game easier. Where it does, it is listed in §4.7.
2. **Potato is one click.** It is the first row of the first tab. It is also reachable without the menu, through a safe-mode launch option (§3.4).
3. **Every option explains itself.** An info panel shows: what the option does, its performance impact, whether it affects gameplay, and whether it needs a restart.
4. **Every menu works with a controller.** Rows are `< value >` selectors or sliders, with no dropdowns. LB/RB switch tabs, B goes back, Y resets the tab, and Start closes the menu.
5. **These visuals are protected at every preset:**
   - terrain;
   - goons, plus the giant marking;
   - the car;
   - pickups and their outline;
   - HUD numbers and bars;
   - the night headlight cone, which is scaled by `setHeadlightStrength` (`overhead_car_body_2d.gd:364-365`);
   - the station indicator.
6. **Physics stays at 60 Hz and is never exposed as a setting.** Handling, fuel burn, the steering ramp, camera zoom and goon idle are computed per tick (`overhead_car_body_2d.gd:195,259,294-297`; `playerCarController.gd:18-20`; `walker.gd:114`).

---

## 4. Settings architecture

### 4.1 Where settings live

| File | Contents | Steam Auto-Cloud | Written |
|---|---|---|---|
| `user://settings.cfg` (ConfigFile) | `[meta] version`; `[audio]`; `[gameplay]`; `[controls]`; `[access]` | **Synced** (personal preferences) | 0.5 s after the last change, when the overlay closes, and on `NOTIFICATION_WM_CLOSE_REQUEST` |
| `user://graphics.cfg` | `[meta] version, tier, adapter_id, boot_pending_count, safe_mode_handled`; `[display]`; `[gfx]`; `[audio_perf]` | **Excluded** (per machine) | same as above |
| `user://override.cfg` | only `rendering/renderer/rendering_method` | Excluded | only when the player changes Renderer |
| `user://saveData_0.1.tres` | progress only | Synced | unchanged |

Settings use two files so that a desktop's High preset doesn't follow the player through Steam Cloud onto their HD 620 laptop.

**`project.godot` changes**
- Add `application/config/project_settings_override="user://override.cfg"`. The doctool check confirmed this switches the renderer when the game is launched with `--path`. It **must be re-tested in an exported build**.
- Leave the new-in-4.7 `application/config/disable_project_settings_override` at false.
- Delete the 3D-only keys at `:13` and `:128`.

**Why ConfigFile and not the `.tres` save**
- Reset Save (`saveManager.gd:29-32`) will no longer wipe settings.
- New keys can't crash old saves. Today `getVolume` indexes the dictionary directly (`:106-107`).
- Slider ticks no longer rewrite the save (`:102-104`).
- A ConfigFile can be read before the first frame.

**Caveat:** ConfigFile uses Godot's Variant text parser, which can construct `Object(...)` values. It is lower risk than loading a `.tres`, but not zero. Validate types on load (§4.2).

### 4.2 `Settings` autoload (`scripts/global/settings.gd`)

**Setup**
- Register it **first** in `[autoload]` (`project.godot:29-34`), so the order is `Settings, Root, SaveManager, Audio, Region`.
- Give it `process_mode = PROCESS_MODE_ALWAYS` so its timers keep running while the tree is paused.

```gdscript
extends Node
signal changed(key: String, value)
const VERSION := 1
enum Tier { POTATO, LOW, MEDIUM, HIGH }

# Preset-driven keys; index = Tier. All other keys have one default.
const PRESET := {
  "display/render_res":  ["cap900", "auto", "auto", "native"],
  "display/max_fps":     [60, 60, 0, 0],             # 0 = unlimited / match display (see 5.2)
  "display/menu_fps":    [30, 30, 0, 0],
  "gfx/text_fx":         [0, 1, 2, 3],               # flat, still, animated(8), animated(16)
  "gfx/lighting":        [0, 1, 1, 2],               # see 5.1 and open question Q1
  "gfx/smoke":           [0, 1, 2, 2],
  "gfx/tire_marks":      [0, 1, 2, 2],
  "gfx/pickup_fx":       [0, 0, 1, 1],
  "gfx/celebration":     [0, 1, 2, 2],
  "gfx/reward_fx":       [0, 1, 2, 2],
  "audio_perf/max_sfx":  [8, 12, 24, 24],
}
var menu_open := false   # set by the overlay; guards main2.gd:23-25 and pauseMenu.gd:13
func get_value(k: String) -> Variant
func set_value(k: String, v, persist := true) -> void  # applies, emits changed, flips preset to "custom"
func apply_preset(t: int) -> void                      # touches only PRESET keys
func apply_all() -> void
```

**Load and merge**
1. Start from the defaults defined in code.
2. Overlay each saved key that has the right type, then clamp it to its validator.
3. Fill keys missing from the file from `PRESET[key][stored tier]`, so options added in later versions get sensible values on old installs.
4. Keep unknown keys. They are not loaded, but stay in the file, so a downgrade cannot lose data.
5. Run migrations as `if version < N:` blocks.

### 4.3 Migrating from `PlayerData.settings`

1. `Settings` finds no `settings.cfg` and sets `needs_volume_import`.
2. After `SaveManager._ready` (`saveManager.gd:7-10`) loads the save, it calls `Settings.import_legacy_volume(playerData.settings.get("volume", {}))`. Use `.get(k, 0)` for every key. Convert each value as follows:
   - `p = sqrt(clamp(db_to_linear(db), 0, 1))`. This inverts the new perceptual slider curve, `db = linear_to_db(p*p)`.
   - A value of -39 dB or lower (the old -500 "mute", `settings_sound.gd:22`) becomes 0 with mute on.
   - Values above 0 dB clamp to 100%.
   - `ui = fx`, because FX drove the UI bus before (`settings_sound.gd:44`).
3. Delete `SaveManager.load_settings` (`:13-18`) and `setVolume`/`getVolume` (`:102-107`). Repoint their callers in the same change:
   - `walker.gd:141,144`: set `bus = "FX"` on both `AudioStreamPlayer2D` in `walker.tscn:53-59` (they play on Master today, so the FX slider doesn't affect them) and drop the `+ getVolume()`.
   - `slotMachine.gd:38-40`: use the FX bus plus constant offsets.
4. Keep the `@export var settings` field in `playerData.gd:67-71` for one release so old saves still load. Stop writing to it.

**Gate before Phase 1:** decide whether the demo and the full game share `%APPDATA%/GoonCrusher` and whether progress carries over. Settle the save versioning at the same time (`levels` is not `@export`, `playerData.gd:74`; see `GAMEPLAY_SUGGESTIONS.md` T0-1). This work touches the same folder and files.

### 4.4 Boot sequence and safe mode (`Settings._enter_tree` / `_ready`)

1. **Connect the scene hook in `_enter_tree()`.** The doctool test showed that an autoload's `_ready` runs only after every autoload and the main scene are already in the tree, so a `node_added` connected in `_ready` misses everything. Connect `get_tree().node_added` in `_enter_tree()`, and also walk `get_tree().root` once in `_ready` as a safety net.

2. **Safe mode.** All of the following apply:
   - **When it triggers:**
     - `boot_pending_count >= 2`, meaning **two** boots in a row never reached the menu. A single closed-during-load does not count.
     - Or an explicit safe-mode argument. Check both `OS.get_cmdline_user_args()` and `OS.get_cmdline_args()`, because a bare `--safe-mode` shows up only in the second. Document the Steam launch option as `-- --safe-mode`.
   - **Ask, don't act silently.** Show a prompt: "The game didn't start properly last time. Start in safe mode? (Potato preset, windowed, Compatibility renderer)".
   - **Handle the request once.** Record `safe_mode_handled` so a launch option left in Steam does not re-apply Potato on every boot.
   - **Don't carry the flag into restarts.** When restarting, call `OS.set_restart_on_exit(true, args)` with the safe-mode argument filtered out of `args`.
   - **Clear the counter** in `main2._ready` once the menu is drawn.
   - **Reset option:** `--reset-graphics` deletes `graphics.cfg` and `override.cfg`.

3. **Detect the tier** (§6) on the first run only. Store a normalized `adapter_id` (vendor plus device ID, not the name string). Vulkan reports "Intel(R) HD Graphics 620" but ANGLE reports "ANGLE (Intel, …)", so comparing names would re-detect on every renderer switch. **Never overwrite Custom.**

4. **Display:**
   - `get_window().mode`: `MODE_WINDOWED`=0, `MODE_FULLSCREEN`=3 (today's borderless default), `MODE_EXCLUSIVE_FULLSCREEN`=4.
   - `get_window().current_screen`.
   - `DisplayServer.window_set_vsync_mode`.
   - `Engine.max_fps`.
   - Root content scale (§5.2).

5. **Graphics:**
   - `RenderingServer.global_shader_parameter_set(...)` for the `gc_*` globals (§4.5).
   - `RenderingServer.canvas_set_shadow_texture_size(...)`.
   - Patch the cached 3D-text `.tres` resources (§4.5).

6. **Audio:** bus volumes and mutes (`AudioServer.set_bus_volume_db` / `set_bus_mute`).

7. **Input:** `InputMap.action_erase_events` / `action_add_event` from `[controls]`, then `action_set_deadzone`.

### 4.5 How runtime changes reach scenes

| Mechanism | Used for | Repo edits |
|---|---|---|
| **Global shader uniforms**, declared in `project.godot [shader_globals]` | `gc_text_quality` (int), `gc_text_max_slices` (int), `gc_motion` (float), `gc_pickup_fx` (int), `gc_giant_style` (int), `gc_giant_color` (vec4) | `3dtext.gdshader`, `shine.gdshader`, `flashiness.gdshader`, `rainbowfill.gdshader`, `rainbow_shader.tres` |
| **`node_added` hook** in `settings.gd` | Points every 3D-text-family material at the canonical shader and sets its `time_mode`. Sets light shadows and occluder visibility per Lighting level. Adds nodes to private groups so a mid-run change can re-apply. | none in scenes |
| **`Settings.get_value()` at the use site, plus the `changed` signal** | smoke, tire marks, celebrations, reward flyers, car shake, max SFX, speed units | one-line guards in about 12 scripts |
| **Window / DisplayServer / Engine** | window mode, vsync, fps caps, content scale | none |
| **Confirm-or-revert dialog** | window mode, size, monitor, render resolution | in-overlay "Keep these settings? Reverting in 15 s [Keep] [Revert]" |
| **Restart** | renderer only | write `override.cfg`, show "Restart now / Later" |

**Global uniforms.** The test confirmed `global uniform` and `instance uniform` work in canvas_item shaders on **both** renderers. Every `gc_*` global must be declared in `[shader_globals]`. An undeclared one prints an error and falls back to default values.

**The hook.** Its behaviour is set by the following rules.

- **Swap materials whatever shader they currently use.** Ten scenes, the default sedan's station indicator among them, already reference `shader/3dtext.gdshader` directly. Those still need `time_mode` set. So:
  1. Detect the family by checking whether the shader code contains `VERTEX_ID>>1`.
  2. Save the material's parameters: `angle, thickness, scale, shear, slices, outline, outline_width, show_bound, front_tex, back_tex, side_tex, outline_tex`.
  3. Set the canonical shader.
  4. Restore the parameters.
  5. Set `time_mode` from the old code's line-55 variant: `sin(TIME *2.0 )` gives oscillate, `sin(TIME) , 0` gives one-sided, `TIME * 2.0;` gives spin, and anything else gives none.
- **Materials assigned at runtime never pass through `node_added`.** An example is `main2.gd:174-196` setting the `Mat_Star_*.tres` materials. Patch the cached `.tres` resources once in `Settings._ready`: `3dText_Common`, `3dShader_Star`, `Mat_Star_Grey/White/yellow`, `3d_Text_HighlightRight` and `flatTextNoTime`.
- **Lights:**
  - Store each light's authored `shadow_enabled` in meta `gc_shadow`.
  - Store each occluder's authored `visible` in meta `gc_vis`.
  - Only ever AND the setting with those values. For example, `powerup.tscn:30-31` hides its occluder by default, and turning lighting back to High must not make pickups cast shadows.
- **Cost:** about two `is` checks per added node. Confirm it stays under 0.1 ms per frame in the crowd benchmark.

**Canonical shader edit** (`shader/3dtext.gdshader`). The defaults reproduce today's look exactly.

```glsl
global uniform int   gc_text_quality;     // 0 flat, 1 still, 2 animated
global uniform int   gc_text_max_slices;  // 8 Medium, 16 High
global uniform float gc_motion;           // 0 = reduce motion
uniform int time_mode = 0;                // 0 osc, 1 one-sided, 2 spin, 3 none

// replaces line 55
if (gc_text_quality < 2 || gc_motion < 0.5) { if (time_mode <= 1) _angle = 0.0; }
else if (time_mode == 0) { _angle *= sin(TIME * 2.0); }
else if (time_mode == 1) { _angle = max(_angle * sin(TIME), 0.0); }
else if (time_mode == 2) { _angle += TIME * 2.0; }

// after line 98 (rd is in UV units here; dividing by TEXTURE_PIXEL_SIZE.x gives texels)
int n_max = (gc_text_quality == 0) ? 1 : min(slices, (gc_text_quality == 1) ? 4 : gc_text_max_slices);
int n = clamp(int(ceil(length(rd.xy) / TEXTURE_PIXEL_SIZE.x)) + 1, 1, max(n_max, 1));
if (n == 1) { rd = vec3(0.0); } else { p -= rd * 0.5; rd /= float(n - 1); }  // also fixes /0 when slices==1
// use textureLod(..., 0.0) inside the variable-length loop (undefined derivatives otherwise);
// back outline only if gc_text_quality > 0; final slice uses front_tex if rd.z < 0 else back_tex
```

What this changes:
- **Adaptive slices are always on and visually lossless.** At rest, text extrudes only a few texels, so 3–5 slices replace 16–64. The 64-slice titles are capped at 16 on High, and no scene file needs editing.
- **Flat mode costs about 9 taps per pixel**, against up to 144 today.

**Correction.** Earlier drafts expected the `VERTEX_ID` corner trick to break under Compatibility and planned a separate `text_plain` shader. A test on both renderers produced identical corners, so **no separate shader is needed**.

---

## 5. The settings menu

**Shell.** Rewrite `scene/player/menu/settings/settings.tscn`:
- The root becomes a `Control` with `mouse_filter = STOP`, not a full-screen `Button`.
- Delete the five stray 3D materials on the root Button (`settings.tscn:12-70,120-177`). They run over blank space, cost GPU time and show nothing.
- Delete `set3B0E.tmp`.
- Build the rows from a schema array through a new `option_row.tscn/.gd`. Row labels use plain theme fonts.
- Tab order: **Graphics · Display · Audio · Controls · Accessibility · Gameplay**.
- Changes apply live. "Revert changes" restores the values from when the overlay opened, and "Reset tab" restores the defaults.

Preset columns below: **P** Potato · **L** Low · **M** Medium · **H** High.

### 5.1 Graphics

The top row is **Quality preset: Potato / Low / Medium / High**, shown as "Custom" once any key is changed. It also shows "★ Recommended: Low (Intel HD Graphics 620)" and a "Detect again" button.

| Option | Values | P | L | M | H | What it does | Gameplay |
|---|---|---|---|---|---|---|---|
| **Text Effects** | Flat / Still 3D / Animated / Animated HD | Flat | Still | Anim | Anim HD | `gc_text_quality` 0/1/2/2 and `gc_text_max_slices` 1/4/8/16 (§4.5). In Still mode, button focus feedback comes from the existing scale tween (`roadButton.gd:70`). | None. All text stays drawn and outlined. |
| **Lighting** | Low / Medium / High | Low | Med* | Med | High | **High:** as authored, shadow atlas 2048. **Medium:** headlamp shadows on, goon occluders hidden, rocks keep theirs, atlas 1024. **Low:** shadows off and all occluders hidden; tail lamps, pickup-flyer lights and explosion lights off; station lamp posts off, with the **central station light enlarged to cover the yard** (`station.tscn:267`); atlas 256. **At every level:** all 5 headlamps (or the baked cone, below) still scale with `setHeadlightStrength`, plus `carhighlight` (`car.tscn:216`), `indicatorLight` (`:346`) and the night CanvasModulate. | **Low and Medium affect gameplay.** The test showed 2D shadows fully block light, whatever `shadow_color` alpha is set to. With shadows off, goons behind rocks become visible, and Medium shows goons behind other goons. The menu must label both. *See Q1 for whether Low should keep one shadowed cone. |
| ▸ Simple Headlight Cone | On / Off | On | On | Off | Off | One `PointLight2D` with a baked `texture/fx/headlight_cone.png` replaces headlamp1-5 under `headlamps/headlights`. **Hidden until it passes a parity check** at Headlights stat 1/20/40/100 (Phase 4b). | None once parity passes |
| **Exhaust Smoke** | Off / Low / Full | Off | Low | Full | Full | `smoke.gd:27-34`. Off must break the re-arm loop, not just hide the node. Low: a puff every 0.18 s, 1.2 s life, end scale 2.5. | Minor. Puffs draw over goons at z=5 (`smoke.gd:13`), so less smoke means better visibility. See Q6: move smoke below goons for everyone. |
| **Tire Marks** | Off / Short / Full | Off | Short | Full | Full | Guard in `overhead_car_body_2d.gd:271-276,300-310`. Short: 6 s, rear tyres only. Full: 20 s. | None |
| **Pickup Glow** | Simple / Full | Simple | Simple | Full | Full | `gc_pickup_fx`. Simple keeps an outline about **5 texels wide** using a fixed ring of 8–16 samples (or a pre-baked outline) and drops the TIME shine. Clamping the width to 2 was rejected, because that is about 0.9 screen px at zoom 0.45. | None. The outline stays readable. |
| **Slot Celebration** | Minimal / Reduced / Full | Min | Red | Full | Full | Lotto backdrop: a dim fade, about 150 large cells, or the full wall sized from the logical rect and capped. Icon burst: 3×8 / 3×40 / 3×200, using `CPUParticles2D` in Phase 5. | None. Reels, results and the claim flow are unchanged. |
| **Reward Pop-ups** | Minimal / Reduced / Full | Min | Red | Full | Full | Crush and purse fly-to-HUD icons become pooled visual flyers, capped at 3 / 10 / 20. **Prerequisite:** every reward must be credited directly and synchronously (see G-13). Today the flying icon's `sendReward → body.reward()` *is* the crediting (`powerup.gd:32`), so capping flyers as-is would lose crushes and coins. | None, after G-13. A test asserts identical totals at all three levels. |
| Max Sound Effects | 8 / 12 / 24 | 8 | 12 | 24 | 24 | Size of the `Audio.gd` pool and its starts-per-frame cap. Goon deaths go through it (§7). Engine, crash and voice players are separate and always on. | Minor. Routing deaths through the pool loses positional panning. |

### 5.2 Display

| Option | Values | Default | What it does | Gameplay |
|---|---|---|---|---|
| Window Mode | Borderless / Exclusive / Windowed | Borderless (today's `mode=3`) | `get_window().mode`, with confirm-or-revert. Replaces the buggy `graphics.gd`. | None |
| Window Size | 1280x720 … 2560x1440, clamped to `screen_get_usable_rect()` | 1600x900 | Windowed only | None. The logical canvas stays 1600x900. |
| Monitor | 1..N | current | `get_window().current_screen` | None |
| **Render Resolution** | Native / Auto / Cap 900p | P: Cap900, L/M: Auto, H: Native | **Cap 900p:** `CONTENT_SCALE_MODE_VIEWPORT` with `content_scale_size = 1600x900`, but **only when the window is larger than 1600x900**. Otherwise stay on `canvas_items`, because viewport mode always renders at `content_scale_size`, so an 800x450 window rendered 1600x900. **Auto:** cap above 1920x1080, native otherwise. Saves up to 5.76× fill on 4K. | None. `get_visible_rect().size` stays 1600x900, so the camera shows the same world. Text is slightly softer when upscaled. |
| V-Sync | On / Adaptive / Off | On | `DisplayServer.window_set_vsync_mode`. Fixes the wrong-checkbox bug (`graphics.gd:23`). | None |
| Frame Rate Limit | Match display / 30 / 60 / 120 / 144 / Unlimited | P/L: 60, M/H: Match | `Engine.max_fps`. "Match" with V-Sync on sets 0, letting vsync pace frames, because a cap at the refresh rate can judder. With V-Sync off it uses `round(screen_get_refresh_rate())`, which returns −1.0 when unknown. **Requires G-1.** | None, after G-1 |
| Menu Frame Rate | 30 / Same as game | P/L: 30 | Applied **only from explicit signals**: main2 entered or left, pause menu opened or closed. **Never** while paused for the slot machine, countdown, summary or a celebration (see G-1 and H1). | None. Laptops run cooler. |
| Pause When Unfocused | On / Off | On | Focus out during a run calls a new `playerRoot.openPause()`, keeping the existing `not paused` guard (`playerRoot.gd:24`) so it never opens over the slot machine or countdown. Menus do not get an fps cap on focus loss. | None |
| Renderer ↻ *(Troubleshooting)* | Standard / Compatibility | Standard | `override.cfg` plus a restart prompt. Tooltip: "Only change this if the game crashes or shows a black screen. Standard is faster on most PCs." | None |
| Performance Overlay | Off / FPS / Detailed (F3) | Off | §8.2 | None |

### 5.3 Audio

| Option | Values | Default | What it does |
|---|---|---|---|
| Master / Music / Voice / Effects / Menu Sounds | 0–100% in 5% steps, each with a mute | migrated, else 80/70/90/80/70 | `set_bus_volume_db(idx, linear_to_db(p*p))`; 0 mutes the bus. The maximum is 0 dB, removing today's +10 dB range, which clips (see Q5). A preview sound plays on release. Also delete the mis-indented block at `settings_sound.gd:51-55`. |
| Mute When Unfocused | On / Off | Off | Master mute on focus out |

### 5.4 Controls

| Option | Values | Default | What it does |
|---|---|---|---|
| Rebind Accelerate / Brake / Steer L / Steer R / Pause | keyboard ×2 + pad ×1 each; capture with a timeout; conflict warning | `project.godot:47-118` | Stored in `[controls]`. `main2.gd:24-25` reads `TurnLeft/Right`, and the slot machine uses Accelerate and Brake (`slotMachine.gd:56,63`). |
| Stick Deadzone | 0.2–0.8 | 0.5 | `InputMap.action_set_deadzone`. Input stays digital. |
| Controller Vibration | Off / Low / High | High | `Input.start_joy_vibration` on crush, damage and explosion |
| *(always-on)* | | | Bind **Start** (joypad button 6) to `ui_menu`; today a controller cannot pause. Add `ui_tab_prev/next` actions for LB/RB. |

Analog steering changes handling, so it is left out of this pass. It is a gameplay decision.

### 5.5 Accessibility (overrides presets without relabelling them)

| Option | Values | Default | What it does |
|---|---|---|---|
| Reduce Motion | On / Off | Off | `gc_motion = 0`: no 3D-text wobble, rainbow fills freeze, giant pulse becomes steady, car shake off, celebrations capped at Reduced. Camera zoom at speed is unchanged. |
| Reduce Flashing | On / Off | Off | Celebrations at Minimal; explosion modulate ≤ 1; slow giant pulse. **The giant tint is HDR `Color(128.498,1,1,1)`** (`walker.tscn:22-26`). Clamping it would make giants white, so convert it to a hue-preserving 0–1 red instead. |
| Giant Marker Style | Pulse / Steady / Tint + ground ring | Pulse | `gc_giant_style`. The 1.6×1.9 giant scale always applies. |
| Giant Marker Colour | Red / Yellow / Cyan / Magenta / White | Red | `gc_giant_color`. Tooltip: Yellow or Cyan for red-green colour blindness. |
| Plain Text | On / Off | Off | Forces Flat text |
| Car Shake | On / Off | On | Zeroes the always-on sprite offset (A-12) |
| Hold to Confirm | On / Off | On | Reset, Abandon and Quit need a hold or a second press |
| Night Visibility Assist *(only if approved, Q2)* | 0 / 10 / 20% | 0% | `levelRoot.gd:66` tweens to `Color(a,a,a)` instead of black. **Affects gameplay:** night gets easier and the Headlights upgrade is worth less. Because of the HDR giant tint, giants glow from far away (see the note at `levelRoot.gd:67`), so scale the tint down while Assist is on. |
| HUD Scale *(optional)* | 80–130% | 100% | A Control wrapper under the HUD CanvasLayer. Not `content_scale_factor`, which would change the world view. |

### 5.6 Gameplay

| Option | Values | Default | Notes |
|---|---|---|---|
| Speed Units | MPH / km/h | MPH | `car_panel.gd:12`; the indicator distance "mi" (`overhead_car_body_2d.gd:147-148`) also switches |
| Show Run Timer | On / Off | On | **Affects gameplay in Sprint and Marathon**, where the timer is information. Label it as such. |
| Confirm Abandon / Quit | On / Off | On | `pauseMenu.gd:23-28` |
| Reset Progress… | button | – | Two-step confirmation. Unpause before reloading (`gameplay.gd:14-16`). "Your settings will be kept." |

There are deliberately no MSAA, FXAA, HDR-2D or glow options. Keep `hdr_2d=false` and `msaa_2d` disabled.

### 5.7 Where Low/Potato differs in what the player sees

Players on different presets do **not** see exactly the same game. The menu text must not claim they do.

- Lighting Low/Medium: shadows stop hiding goons (labelled).
- Smoke Off/Low: goons are easier to see (or fix Q6 for everyone).
- Lighting Low: tail lamps off, so the area behind the car is darker when reversing at night.
- Show Run Timer off: Sprint and Marathon lose information (labelled).
- Night Assist: easier nights (labelled, off by default, not driven by presets).

---

## 6. Presets and first-run detection

| Preset | Target |
|---|---|
| Potato | CPU or software rasterizers, engine fell back to GL, ≤ 2 threads, safe mode |
| Low | Intel HD/UHD-class iGPUs (default on the dev box) |
| Medium | Iris Xe, Radeon 680M/780M, entry-level discrete GPUs with ≤ 4 threads |
| High | Discrete GPU with ≥ 6 threads |

```gdscript
func detect_tier() -> int:
    var t := RenderingServer.get_video_adapter_type()   # returns DEVICE_TYPE_OTHER (0) on Compatibility
    var name := RenderingServer.get_video_adapter_name().to_lower()
    var cores := OS.get_processor_count()
    var fell_back := RenderingServer.get_current_rendering_method() != \
        ProjectSettings.get_setting("rendering/renderer/rendering_method")
    if t == RenderingDevice.DEVICE_TYPE_CPU or fell_back or cores <= 2 \
       or name.contains("llvmpipe") or name.contains("basic render") or name.contains("swiftshader"):
        return Tier.POTATO
    if t == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
        return Tier.HIGH if cores >= 6 else Tier.MEDIUM
    if RegEx.create_from_string("intel.*\\bu?hd graphics").search(name) or cores <= 4:
        return Tier.LOW      # matches both "Intel(R) HD Graphics 620" and the ANGLE name
    return Tier.MEDIUM
```

Notes:
- **Command-line renderer flags count as a fallback.** `--rendering-method` on the command line leaves the ProjectSettings value at `mobile`, so a deliberate CLI Compatibility launch looks like a fallback and gets Potato. That is acceptable. An `override.cfg` choice updates ProjectSettings, so it doesn't count.
- **4K is handled by Render Resolution = Auto**, not by dropping a tier.
- **Optional calibration** on the first menu display: sample `viewport_get_measured_render_time_gpu` over 120 frames, and step down one tier if p90 is above 8 ms. **It returns 0 on Compatibility**, so fall back to CPU frame time there.
- **One-time toast:** "Graphics set to Low for Intel HD Graphics 620. [OK] [Open Graphics]".
- **Runtime advisor**, at most once per install: if the 1% low stays under 45 fps for the first 90 s, the summary shows "Running slow? Try Potato in Settings → Graphics." It never changes settings by itself.

---

## 7. Always-on fixes (no setting)

### 7.1 Bugs that block or interact with settings work

| # | Bug | Where | Fix |
|---|---|---|---|
| G-1 | **Frame-count logic breaks under any fps cap**, and today on 144 Hz screens | `slot_row.gd:72-75` (100 `await process_frame` wind-up); `slot_row.gd:82-97` (18 px per frame, `spinFrameTracker`); `splashicon_1.gd:17-19`; `lottoTransition.gd:19,25,31` (one row per frame); `purse.gd:14-15` (2 frames per coin); `saveManager.gd:49,64`; `statUpgradeButton.gd:23-24` | Move the reel motion and wind-up to `_physics_process` (they run in ALWAYS mode, so they keep exact 60 Hz behaviour and reel alignment), or make them time-based. Make the rest time-based. **`smoke.gd:22` sets a random rotation every frame** and is not a rotation rate, so multiplying by delta does nothing: set the rotation once at spawn. **Must land before Frame Rate Limit or Menu Frame Rate.** Without it, a 30 fps cap breaks the slot machine. The 1.8 s unlock at `slotMachine.gd:41-45` fires before a 3.3 s wind-up finishes, so the reel never stops and the reward doesn't match the reel. |
| G-2 | V-Sync reads the Fullscreen checkbox; toggles don't reflect the real state; nothing is saved | `graphics.gd:5,14-26` | Replaced by the Display tab, which reads `get_window().mode` and `window_get_vsync_mode()` |
| G-3 | Settings live inside the save | `playerData.gd:67-71`, `saveManager.gd:13-18,29-31,102-107` | §4.1–4.3. Also use `duplicate(true)` in `reset_save`. |
| G-4 | Input leaks behind the overlay: arrows and A/D cycle cars (and save); Esc in pause → settings unpauses the game | `main2.gd:23-25`, `pauseMenu.gd:13` | Return early while `Settings.menu_open`. The overlay consumes `ui_menu` and `ui_cancel` itself. |
| G-5 | Reset Save from the pause menu leaves the tree paused; no confirmation | `gameplay.gd:14-16` | Unpause and confirm |
| G-6 | The HUD pause path skips the `visibleWhenPaused` group, and its button node is missing | `car_panel.gd:26-28` vs `playerRoot.gd:24-27` | Route both through `playerRoot.openPause()` |
| G-7 | `get_viewport().size` is in physical pixels: about 6,000 lotto nodes at 4K | `lottoTransition.gd:6-7`, `main2.gd:79-82`, `slotMachine.gd:20` | Use `get_viewport().get_visible_rect().size` |
| G-8 | Goon and slot sounds bypass the FX bus | `walker.tscn:53-59`, `walker.gd:141-146`, `slotMachine.gd:38-40` | `bus="FX"`; delete `getVolume` |
| G-9 | `updateIcon` touches the material with no null check | `roadButton.gd:49-50` | Add `if material:` |
| G-10 | Levels can't be launched directly; log spam | `root.gd:13`, `levelRoot.gd:16`; `overhead_car_body_2d.gd:44` (`AudioStream-Reward` missing); tile 15:3 in `landscapeMap_snow.tscn` | Fall back to the saved car and fix both errors. **Phase 0, because the benchmark needs it.** |
| G-11 | Station lights are on through the first day | `station.tscn:229`, `station.gd:13-15` | Set from the day state in `_ready` |
| G-12 | Main menu fonts come from the test addon | `main2.tscn:6,10`, `scene/splash_text.tscn:4` | Move them to `style/font/` |
| G-13 | **Rewards are credited by the flying icon** | `powerup.gd:22-42`, `overhead_car_body_2d.gd:238-245,356-360`, `purse.gd:5-17` | Credit crush counts, coins, gems and powerups directly. Flyers become visual only. Required before Reward Pop-ups. It also fixes a probable purse double-collect: purse coins keep a live `Area2D` (`purse.gd:9-13`). |
| G-14 | Test runners point at a folder that doesn't exist | `scripts/windows/run_tests.bat`, `scripts/linux/run_tests.sh` (`-gdir=res://gut`) | Point them at `res://tests` and add `tests/game/` |

### 7.2 Always-on performance fixes, ranked

| # | Fix | Where | Phase |
|---|---|---|---|
| A-1 | Canonical text shader plus adaptive slices (§4.5) | `shader/3dtext.gdshader`, hook | 2 |
| A-2 | **Chunk unload by distance.** Free any chunk with Chebyshev distance > 2 from `floor(pos/tilesize)`, used everywhere. **Pin the station chunk.** Note: freed chunks re-roll rocks and coins when reloaded (`tileManager.gd:190-198`). That already happens today, but it becomes more frequent, so store a per-chunk seed so reloads regenerate the same objects. | `tileManager.gd:117-160` | 3 |
| A-3 | Chunk load queue: at most 1 per frame, plus a prefetch ring in the travel direction. Pool TileMaps per terrain type later. | `tileManager.gd:167-205` | 3 |
| A-4 | Live goon counter (`tree_exiting`); stagger the 5 spawns across 5 frames | `spawnManager.gd:65-73` | 3 |
| A-6 | Light hygiene: set tail-lamp energy only when the brake state changes; remove the `Color(100,100,100)` light modulates; delete the 5 station pavement micro-lights; `rendering/2d/shadow_atlas/size=1024` (the 2D key, not the 3D key at `:128`) | `overhead_car_body_2d.gd:278-281`, `car.tscn`, `light.tscn:26-40` | 4 |
| A-7 | Smoke: preloaded const instead of `load().duplicate()`; pool 8–12 sprites; make the emitter loop really stop | `smoke.gd:6-34` | 3 |
| A-8 | Tire marks: add a point only after ≥ 12 px; new segment every 64 points; pooled ring | `tiremark.gd`, `overhead_car_body_2d.gd:300-310` | 3 |
| A-9 | Delete the 22 empty `_process` / `_physics_process` stubs and `Event.gd`; slot rows free icons that scroll off | rocks, tiremark, spark, `slot_award_icon`, `roadButton`, settings scripts… | 3 |
| A-10 | HUD dirty flags; speed label at 10 Hz | `playerRoot.gd:28-31`, `car_panel.gd`, `Timer.gd:27-29`, `regionUi.gd:11-14` | 3 |
| A-11 | Saves: dirty flag plus 1 s debounce; save on scene change and close; `addCoins` adds the total and saves first, then animates; `getUpgradeLevel` stops writing on read. **Land after G-3**, because both touch `saveManager.gd`. | `saveManager.gd` | 3 |
| A-12 | Car shake as a direct sprite offset, not a new tween every 2–10 ticks; `@onready` caches; `is` checks instead of `get_class()` strings | `overhead_car_body_2d.gd:211,261-267` | 3 |
| A-13 | Explosion: preload once per level, not per car (the menu loads it too); free it after the last loop | `overhead_car_body_2d.gd:386`, `explosion.gd:23-26` | 3 |
| A-14 | `physics/common/max_physics_steps_per_frame=4`, so overload causes brief slow-motion instead of a stall | `project.godot` `[physics]` | 3 |
| A-15 | Celebrations: lotto becomes one TextureRect with a tiling shader; the icon burst becomes 3 `CPUParticles2D` with a shared material; remove the per-sprite `process_thread_group=2` | `lottoTransition.gd`, `splashscreen_1.gd`, `splashicon_1.tscn:29` | 5 |
| A-16 | Pooled reward flyers (no Area2D, light or occluder; shared material). Needs G-13. | `powerup.gd`, `purse.gd` | 5 |
| A-17 | Goon death SFX through `Audio.queueRequest`; short SFX as QOA WAV (the 4.7 import default) | `walker.gd:141-146` | 5 / 8 |
| A-18 | Shader warm-up behind the level load: draw one of each goon, giant, explosion, smoke puff, pickup, slot UI and shadowed light for about 3 frames. Targets the measured 38 s hitch. | new `scene/level/shader_warmup.tscn` | 5 |
| A-19 | Shared pickup materials (drop `resource_local_to_scene`) | `shader_edgeglow.tres:6`, `coin.tscn:7-12`, `level_coins_1.tscn` | 5 |
| A-20 | Textures: mipmaps plus the Linear Mipmap default filter for world sprites; BC7 for backgrounds, portraits and FX sheets (test terrain atlases for seams); pack goon frames into atlases | `*.png.import`, 18 SpriteFrames | 8 |
| A-21 | Threaded level load with a loading screen. Show menu cars from a light `CarInfo` resource instead of the orphan car instance (`main2.gd:28-31`). Prefetch neighbouring cars. Clear placeholder art (`car.tscn:4-5`). | `main2.gd` | 8 |
| A-22 | Packed-array terrain map (`PackedByteArray` terrain / `PackedInt32Array` region) read with `get_data()` instead of 65k dictionaries and `get_pixel`; bake rock collision hulls (`rocks.gd:6`); fix `inputFractalType=4` (valid range 0–3) | `landscapeGenerator.gd:19-54` | 8 |
| A-23 | Export and repo hygiene: exclude `addons/gut`, `addons/rmsmartshape`, `tests/`, `*.psd` and the unreferenced `texture/backgroundTexture.png` (3600x3600); `git rm -r --cached .godot` (874 tracked files); delete the 12 committed `*.tmp` files; delete `default_env.tres` and `world_environment.tscn`; check the GodotSteam binaries (built for `compatibility_minimum 4.1`) against 4.7 or exclude them | `.gitignore`, export preset | 8 |
| A-24 | Optional: bake the shader consolidation with an EditorScript, rewriting the inline sub-resources to reference `3dtext.gdshader`. That removes extra shader compiles and makes the hook's swap step a no-op. | scenes | 8 |

*(An earlier draft had an "A-5": move the car to its own physics layer. It was **dropped**. The water `Area2D` (`landscapeMap_water.tscn:26`), the station driveway (`station.tscn:275`) and pickups all rely on mask 1, so moving the car silently breaks water deaths and Sprint wins. The cost it addressed was low.)*

### 7.3 Gameplay-adjacent work (needs author sign-off and a playtest)

| Item | Gameplay effect |
|---|---|
| Despawn sweep: run the existing 8000 px rule every 0.5 s (plus an off-screen check) instead of only when a goon leaves idle | Smaller chasing crowds and fewer coins |
| Region labelling as an iterative BFS during the countdown (`landscapeGenerator.gd:55-104`) | Fixes fragmented regions and the bogus region −1, so per-region waves and stars reset less often. **Changes pacing.** |
| Global goon safety cap (e.g. 250, the same for everyone) plus off-screen LOD | Late-game crowd and coins. Only if the crowd benchmark (S4) shows physics p95 above 8 ms. |

---

## 8. Phased implementation

Effort: S ≤ 1 day, M = 1–3 days, L > 3 days.

| Phase | Work | Effort | Depends on | Acceptance |
|---|---|---|---|---|
| **0. Measure** | G-10, G-14. Benchmark harness and overlay (§9). Baseline S1–S7 on both renderers. **Measure the menu with the text materials turned off**, to confirm what is driving its cost. Re-rank Phases 2–5 from the data. | S–M | — | A CSV per scenario; night and crowd numbers exist |
| **Gate** | Decide save-folder sharing, demo carry-over and save versioning (`GAMEPLAY_SUGGESTIONS.md` T0-1) | — | — | Decision recorded |
| **1. Foundation** | `Settings` autoload, two cfg files, migration, boot apply, safe mode, tier stored; new overlay with `option_row`, info panel, controller navigation, confirm-or-revert; Display (except Render Resolution and Renderer), Audio, Gameplay, basic Controls (Start = pause); G-1 to G-9 | M–L | 0, Gate | An old demo save boots with volumes migrated. Reset keeps settings. Sliders don't touch the save file's modification time. V-Sync and window mode persist. **Reels stop on the right symbol at 30 fps and at unlimited.** |
| **2. Text Effects** | A-1, `[shader_globals]`, the hook (including cached `.tres` patching), the Text Effects row | S–M | 1 | Animated HD matches today side by side (titles, buttons, stars, HUD, indicator, slot, summary), on Vulkan and Compatibility. Menu-fps targets set from the Phase 0 data. |
| **3. CPU always-on** | A-2 to A-4, A-7 to A-14 | M–L | 0. Can run alongside 1–2, but A-11 must land after G-3. | S6: ≤ 25 chunks after 10 min, node count flat ±10%, no frame > 50 ms on chunk crossings. S4: CPU p95 ≤ 8 ms at 150 goons. |
| **4. Lighting** | Light and occluder branches of the hook, G-11, A-6, station-light enlargement, GUT invariant test (headlight scale, lamp count and night CanvasModulate unchanged per level) | S–M | 1 | S3 at Low within 10% of S2 uncapped. Defense-night and goon-behind-rock screenshot pairs reviewed. |
| **4b. Simple Cone** | Bake the union of headlamp1-5 into `headlight_cone.png` (512x256); one node in `car.tscn` | M (art) | 4 | Parity at Headlights stat 1/20/40/100; then unhide the row |
| **5. Cosmetic FX** | G-13 (credit-first rewards, purse fix), Smoke, Tire Marks, Pickup Glow, Celebration (A-15), Reward Pop-ups (A-16), Max SFX (A-17), Reduce Motion and flashing hooks, A-18, A-19 | M | 1, G-13 | S5 at Reduced: worst frame < 50 ms, < 500 extra nodes. Crush and coin totals identical across all Reward Pop-up levels. |
| **6. Presets, resolution, renderer** | Preset row and Custom, detection toast, optional calibration, Render Resolution, Renderer and restart, launch options, advisor | M | 2, 4, 5 | Auto on a screen > 1080p is within 10% of the 900p numbers. `get_visible_rect().size == 1600x900` in both modes. |
| **7. Accessibility and controls** | Rebinding, deadzone, vibration, giant style and colour, Plain Text, Reduce Flashing, Hold to Confirm, Night Assist if approved | M | 1, 2 | Controller-only pass through every menu |
| **8. Assets and export** | A-20 to A-24, G-12 | L | — | First menu frame ≤ 3 s on Vulkan (measured 3.7–5.4 s). Level-load freeze ≤ 1 s (measured 1.7 s). |
| **9. Optional** | 720p/540p via a world `SubViewport` with `size_2d_override = 1600x900` (§10); chunk pooling; HUD Scale; physics interpolation experiment; §7.3 items once signed off | M–L each | 6 | Kept only if the benchmark shows a win |

---

## 9. Measuring success on the HD 620

### 9.1 Harness: `scripts/debug/bench.gd`
- **Inert by default.** It runs only when the user args include `--bench=<id>`, passed after `--`.
- **Boots through main2** so the car comes from the save.
- **Repeatable runs:** fixed seed (`landscapeGenerator.inputSeed = 1337`, `seed(1337)`), autopilot through `Input.action_press` (straight, circle or sine), and god mode.
- **Output:** discards the first 5 s, then writes a per-frame CSV to `user://bench/<id>_<preset>_<renderer>_<res>.csv` with these columns: `t, frame_ms, process_ms, physics_ms, gpu_ms, render_cpu_ms, draw_calls, nodes, goons, chunks, lights`.

```
Godot_console.exe --path . --disable-vsync --max-fps 0 --resolution 1920x1080 --fullscreen -- --bench=S4 --preset=low --seconds=150
Godot_console.exe --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle ... -- --bench=S4 ...
```

Back up `%APPDATA%/GoonCrusher` before any benchmark run.

### 9.2 Performance overlay (shipped, F3)
- **FPS mode:** fps and frame ms.
- **Detailed mode:**
  - frame time: avg, p99 and max over 300 frames;
  - `Performance.TIME_PROCESS` and `TIME_PHYSICS_PROCESS`;
  - GPU ms (`viewport_set_measure_render_time` / `viewport_get_measured_render_time_gpu`; shows "n/a" on Compatibility, where it returns 0);
  - `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `OBJECT_NODE_COUNT` and `PHYSICS_2D_ACTIVE_OBJECTS`;
  - goons, chunks, active lights, and the current renderer.
- **Custom monitors:** register these with `Performance.add_custom_monitor("game/…")` so they also show up in the editor's Monitors tab.

### 9.3 Scenarios

| ID | Scenario | Stresses |
|---|---|---|
| S1 | Main menu idle, 60 s | 3D text fill |
| S2 | Day drive on `level_grass_1`, sedan, 90 s | terrain, smoke, streaming |
| S3 | **Night:** force `setNighttime(true)`, `level_mud_3`, police car (2 exhausts), circling, spawnTimer 2 | lights, shadows, occluders |
| S4 | **Late-game night crowd:** S3 plus spawnTimer 1, `gameTimeProgress` 200, `giantOdds` 50, 150 s; plot frame ms against goon count | goon physics, draw calls |
| S5 | 5 back-to-back slot claims | lotto, icon burst, reels |
| S6 | 10-minute straight drive (+x, then −y) | chunk leak and hitches |
| S7 | 10 purses in 10 s at night | flyers, lights, HUD |
| S8 | 4K panel, S1–S3 | render resolution |

**Run conditions**
- Matrix: current build plus each preset; Mobile, plus ANGLE for S3 and S4; 1600x900 windowed and 1080p fullscreen.
- Run each cell once uncapped and once with vsync on.
- On AC power, with a 2-minute cool-down between runs.
- 3 runs per cell; report the median.

### 9.4 Targets (HD 620, 1080p fullscreen, Vulkan)

| Preset | S1–S3 (vsync on) | S4 night crowd | S5–S7 | Hitches |
|---|---|---|---|---|
| Potato | 60 fps, 1% low ≥ 55 | avg ≥ 58, 1% low ≥ 45 | no frame > 50 ms after warm-up | ≤ 1 frame > 50 ms per minute in S6 |
| Low | ≥ 99% of frames ≤ 17.5 ms (S3: ≥ 98%) | avg ≥ 55, 1% low ≥ 45 | no frame > 66 ms | same |
| Medium/High | no regression from baseline; High looks identical to today | | | |

Every phase's PR attaches S1–S4 results for Low on Mobile at 1080p.

---

## 10. Technical notes and remaining risks

- **Render scale below 900p can't come from the root viewport.**
  - In viewport mode the logical canvas equals `content_scale_size`, so a 1280x720 root would show less world at zoom 0.45. That is a gameplay change, and it breaks the 1600x900 UI layout.
  - Lower internal resolutions need a world `SubViewport` with `size_2d_override` (Phase 9). Every gameplay `add_child` already goes through `Root.levelRoot`, which makes this feasible.
  - The doctool check found no dedicated 2D render-scale option in 4.7.
- **`override.cfg` renderer switch.** Verified only from `--path`. It must be re-tested in an exported build. The fallback is the Steam launch option `--rendering-method gl_compatibility`.
- **Automatic renderer fallback.** The engine's fallback flags default to true in 4.7: `fallback_to_d3d12`, `fallback_to_vulkan` and `fallback_to_opengl3`, plus the GL `fallback_to_angle`. On Windows a Vulkan failure may land on D3D12, which is still Mobile, before reaching GL. Call the option "Standard", not "Vulkan".
- **Adaptive slices.** Check the GOON/CRUSHER titles at 4K. If they look stepped, scale the slice count by the canvas scale.
- **Texture compression and mipmaps** can cause terrain seams. Keep terrain atlases lossless if they appear; mipmaps alone still help.
- **2D lights per canvas item.** A per-item light limit could not be confirmed from the class reference. Watch for lights popping at night near the station (S3 by a Sprint station).
- **Thermal noise** on laptops (±20%) is why each benchmark cell is run 3 times.

---

## 11. Open questions for the author

1. **Lighting Low and shadows.** Shadows fully block light, so turning them off reveals goons behind rocks. Should Low keep shadows on one merged cone (cost to be measured, probably 2–3 ms) so the night stealth gameplay is the same for everyone? *Recommendation:* keep one shadowed cone on Low and remove all shadows only on Potato.
2. **Night Visibility Assist.** Include it (off by default, labelled), and show an "Assist" badge on the summary?
3. **Art direction.** Is Flat text acceptable on Potato, with Still 3D as the floor for Low? Should the GOON/CRUSHER title stay animated on every preset? At 16 slices it costs about 1–2 ms.
4. **Gameplay-adjacent fixes (§7.3).** The despawn sweep, region BFS and goon cap. What cap feels right?
5. **Volume range.** Old saves allowed +10 dB, so clamping to 100% makes boosted players quieter. Is that acceptable, or should the slider go to 150%?
6. **Smoke draws over goons on Full.** Move it below goons for everyone? This is a readability fix.
7. **Demo and full game save folder** (the Phase 1 gate). Should they share `%APPDATA%/GoonCrusher`?
8. **Steam Auto-Cloud.** Sync `saveData_*.tres` and `settings.cfg`; exclude `graphics.cfg` and `override.cfg`. This is Steamworks configuration only.
9. **Steam Deck / Linux target?** If so, Low becomes the Deck default, HUD Scale becomes required, and analog steering needs a decision.
10. **4K test hardware.** Is a 4K panel available to run S8?
