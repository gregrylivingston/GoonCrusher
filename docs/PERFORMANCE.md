# Performance and settings

The reference machine is the dev box: Intel HD 620 iGPU, 4 threads. It is the "potato" target.

## How settings work

| File | Contents | Steam Auto-Cloud |
|---|---|---|
| `user://settings.cfg` | Audio, controls, accessibility, gameplay | Sync |
| `user://graphics.cfg` | Display and graphics, detected tier and GPU, boot counter | Don't sync (per machine) |
| `user://override.cfg` | Only the renderer, read at engine start | Don't sync |

Reset Progress never touches them. The save's own `settings` field is legacy.

**The `Settings` autoload** (`scripts/global/settings.gd`, loaded first) owns every key: `DEFAULTS`, the allowed values (`OPTIONS`, `RANGES`) and the preset columns (`PRESET`, Potato / Low / Medium / High; a changed preset key shows Custom). Read with `Settings.get_value(key)`, react through the `changed` signal.

- **Applying:** `applyKey` sets the `gc_*` shader globals (declared in `project.godot [shader_globals]`), the window, the frame cap and audio. A `node_added` hook (`onNodeAdded`) ANDs the Lighting level with each light's and occluder's authored state.
- **Restart:** only the renderer needs one.
- **Safe mode:** two boots in a row that never reach the menu, or `-- --safe-mode`, apply Potato, windowed and Compatibility for the session, then ask whether to keep them. Headless and harness runs never count as crashed boots.
- **First run:** the tier comes from the adapter and thread count (`detect_tier`), then the menu measures GPU time and may step down one tier (`calibrate_if_needed`).
- **The menu** (`scene/player/menu/settings/settings_menu.gd`): tabs and rows come from `buildSchema()`, which holds each option's label, info, cost and gameplay note; Display changes revert after 15 s unless confirmed. `Settings.menu_open` blocks input underneath.

**Add a setting:** the key in `DEFAULTS` (plus `OPTIONS` or `RANGES`, and `PRESET` if presets drive it), apply it in `applyKey` or where it is read, add a row in `buildSchema()`.

## The options

The list is the schema in `settings_menu.gd`; the values are in `settings.gd`. What the code doesn't say:

- **Only Lighting Low (Potato) changes what the player can see:** no shadows or small lights, so goons no longer hide behind rocks at night. Medium keeps every shadow and occluder so night plays the same.
- **Simple Headlight Cone** is baked: re-bake it if the lamps change (`scripts/debug/bake_headlight_cone.gd`).
- **Effect levels never change rewards or results:** reward pop-ups, crush and driving effects are visuals only.
- **Render Resolution 720p / 540p** render the whole run in a SubViewport (`scene/level/run_view.gd`), so `get_viewport()` in a run may be that SubViewport.
- **Accessibility options override presets** without making them Custom.
- **Compatibility renderer** is a troubleshooting option: OpenGL through ANGLE/D3D11 on Intel, slower, and V-Sync stays on.
- **Deliberately absent:** MSAA, FXAA, HDR-2D and glow options, a Night Visibility Assist, and **the physics tick rate, which is never exposed**. Volume tops out at 0 dB.

## Always on

- **World streaming:** the map, rasters and recipes are built on workers; the main thread applies chunks inside `TileManager.APPLY_BUDGET_USEC`; nodes are pooled (docs/WORLD.md, "Budgets and how they are enforced").
- **Goons:** capped at `SpawnManager.GOON_CAP` for everyone; off-screen goons skip collision; spawns are staggered; a despawn sweep runs twice a second.
- **Native code:** the goon tick, terrain queries and the map's crossings pass are C++ (docs/NATIVE.md).
- **Batching and textures:** one 3D text shader, shared pickup materials, mipmaps on world textures, BC7 for large art. A level loads only its own world art.
- **Lights:** no world lights (landmarks use unlit beacon sprites). **Rewards** are credited at once; flyers are pooled visuals.
- **Loading:** levels and the car load on worker threads; the menu loads `CarInfo`, not car scenes; shaders warm up behind the countdown.
- **Physics overload:** `max_physics_steps_per_frame = 4` (brief slow motion instead of a stall).

## Benchmarking

`scripts/debug/bench.gd` (autoload `Bench`, inert without `--bench`) boots through the menu, uses a scratch save, fixes the seed, drives a pattern (not the AI driver) and refills health and fuel every tick. It writes a per-frame CSV and a `summary.csv` row to `user://bench/`. Scenarios (`SCENARIOS`) and every option are in its header.

```
Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90
```

S1 is the idle menu (3D text fill), S2 a day drive (terrain, streaming), S3 night (lights, shadows, occluders), S4 a night crowd (goon physics, draw calls), S5 slot claims, S6 a long drive (hitches), S7 purses at night (flyers, HUD), SL lighting parity screenshots.

**Add a scenario:** an entry in `SCENARIOS` (level, car, pattern, night, spawn pressure, seconds).

**Run conditions:** from a clean `git worktree` of HEAD (build the native library in it), on AC power, nothing else running, a cool-down between runs (thermals add about ±20%), and more than one run per cell. Never pipe Godot output into `head` or `Select-Object -First`: the process keeps running and spoils the next run. `--set` values go through `str_to_var`, so strings need quotes that PowerShell strips unless the command is built with `Start-Process -ArgumentList`.

**Targets** (1080p, Vulkan Mobile, uncapped): Low holds 99% of frames under 17.5 ms in S1–S3, and S4 averages at least 55 fps with a 1% low of at least 45. Potato S4: at least 58 / 45. A change should not regress Low's S1–S4.

## Known slow

No numbers are kept here: everything measured predates the road atlas, the 19 modes, the rivals and the new HUD, and must be re-run.

- **Night crowds miss the S4 targets on Low and Potato.** Above about 160 goons physics takes most of the frame, and most of that is the physics server, not goon script. Next steps, in order: no collision for off-screen goons, a lower cap on Low and Potato, native verbs (docs/NATIVE.md, "What to port next").
- **Level load:** the world build is still mostly GDScript; `WorldField.sample` is the next port.
- **Unmeasured:** the Goon Cup's rivals (each a car and an AI planner; docs/AI_DRIVER.md, "Limits"), Crush and Driving Effects in a crowd, 4K, V-Sync on.
- **Measured and dropped:** a goon texture atlas (fewer draw calls, no time saved); physics interpolation (no effect at 60 Hz).
- **Open:** should Low or Potato default to 720p?
