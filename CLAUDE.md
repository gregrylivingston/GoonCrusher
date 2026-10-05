# GoonCrusher: context for AI assistants

GoonCrusher is a top-down 2D arcade car game written in **Godot 4.7 / GDScript**. You drive a car across a procedurally generated, chunk-streamed world and run over "goons" (enemies) at speed to crush them. Crushing earns coins and stars and triggers slot-machine bonuses. Between runs, coins buy cars and per-car stat upgrades.

A free demo is live on Steam (app 1941650). The current work is to finish the game for a full release. Detailed plans live in `docs/`:
- `docs/PERFORMANCE_SETTINGS_PLAN.md`: settings overhaul, performance fixes, and low-end ("potato") options.
- `docs/GAMEPLAY_SUGGESTIONS.md`: ways to complete and improve the gameplay content.

## Running and tooling

- **Engine:** Godot 4.7.2 (`config/features = "4.7", "Mobile"`). On the author's machine:
  - Editor: `C:/Users/Greg/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`
  - Console build: `..._console.exe` in the same folder. Use this one for CLI runs, because it prints to stdout.
- **Renderer:** `mobile` (Vulkan).
  - The dev box is an Intel HD 620 iGPU with 4 threads, so it doubles as the low-end target.
  - Measured there, Vulkan Mobile was 15–55% faster than Compatibility. Compatibility runs through ANGLE/D3D11, because Godot blocklists the Intel GL driver.
- **CLI runs:** bound the run with `--quit-after <frames>`. Godot consumes its own flags (`--windowed`, `--resolution`, `--disable-vsync`, `--max-fps`) before scripts see them, and the saved settings would override them anyway, so use the game's user args instead: `-- --window=1600x900` (windowed at that size) and `-- --uncapped` (V-Sync off, no frame cap).
- **Launch options:** `-- --safe-mode` (Potato, windowed, Compatibility; handled once), `-- --reset-graphics` (deletes `graphics.cfg` and `override.cfg`). F3 cycles the performance overlay.
- **Benchmarks:** `scripts/debug/bench.gd` (autoload `Bench`, inert without `--bench`). Example: `Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90`. Scenarios S1-S7 and SL (lighting parity) are listed at the top of the file; options `--set=gfx/lighting:0;...` (values go through `str_to_var`, so strings need quotes: `display/render_res:"720"`, and PowerShell mangles those quotes unless the command line is built by hand, e.g. with `Start-Process -ArgumentList`), `--shot=5;30`, `--tag=name`, `--headlights=N`, `--open-settings`, `--notext`. Output goes to `user://bench/` (per-frame CSV plus `summary.csv`). Bench runs save progress to a scratch copy, never the real save. Levels can also be launched directly; they fall back to the saved car.
- **Save location:** `user://` resolves to `%APPDATA%/GoonCrusher/`, because `use_custom_user_dir=true`. Progress is `saveData_0.1.tres`; settings are `settings.cfg` and `graphics.cfg`; the renderer choice is `override.cfg`. **Back them up before running the game for testing.**
- **Tests:** game tests live in `tests/game/` and run with `Godot_console.exe --headless --path . -s res://tests/game/run_tests.gd` (or `scripts/*/run_game_tests.*`); the exit code is the number of failures. They use a small GUT-compatible base class (`tests/game/game_test.gd`) because **GUT 9.0.0 does not parse on Godot 4.7** (its `Logger` class shadows a new native class). Everything else in `tests/` belongs to rmsmartshape. Headless runs (tests, `--import`) skip tier detection and the crashed-boot counter, so they don't change the player's `graphics.cfg`.
- **Piping Godot output:** don't pipe a Godot run into `Select-Object -First N` or `head`. Closing the pipe early leaves the Godot process running, and it eats CPU and spoils later benchmarks. Capture the output into a variable, then filter it.
- **Addons:**
  - `gut`: tests only, and it needs upgrading for 4.7. The menu fonts it used to supply now live in `style/font/`.
  - `rmsmartshape`: an editor plugin that no game scene uses, so it can be removed.
  - `godotsteam`: the binaries load on 4.7, and the `Steam` singleton registers and can call `steamInitEx` (checked 2026-10-05). **No game code calls Steam yet.**
- **Exports:** `export_presets.cfg` is tracked; Godot 4 keeps credentials in `.godot/export_credentials.cfg`, so the preset holds no secrets. Its single preset is Windows Desktop: separate `.pck`, console wrapper on debug exports, output in `build/` (gitignored). It already excludes `addons/gut/*`, `addons/rmsmartshape/*`, `tests/*`, `scripts/debug/bake_headlight_cone.gd`, `*.psd` and `texture/backgroundTexture.png`. **Install the 4.7.2 export templates before shipping**; the dev box only has 4.7.0 templates, which were used once, through `custom_template`, for the export test. The `override.cfg` renderer switch works in an exported build. Compatibility uses Godot's built-in ANGLE, so no ANGLE DLLs need exporting.

## Architecture

### Autoloads (`project.godot` [autoload], in load order)
| Name | File | Owns |
|---|---|---|
| `Settings` | `scripts/global/settings.gd` | All player settings: `settings.cfg` (synced) and `graphics.cfg` (per machine), presets and tier detection (plus a first-run GPU calibration on the menu, `calibrate_if_needed`), safe mode, applying display/audio/input, the shader globals (`gc_*`), the lighting hook on `node_added`, rebinding, the F3 overlay, the runtime advisor, and `menu_open` (push/pop) for blocking input under menus. Read values with `Settings.get_value("gfx/smoke")`. |
| `Root` | `scripts/global/root.gd` | Global enums (`gameModes`, `endCondition`, `upgrade`, `terrain`, `goon`). Shared node references: `playerCar` (the run's car; null in the menu), `carInfo` (the menu's car), `station`, `levelRoot`, `spawnManager`, `playerRoot` (HUD) and `mainMenu`. Run flags and earned currency. The powerup preload table with `getPowerupFromWeights`. Mode descriptions. |
| `SaveManager` | `scripts/global/saveManager.gd` | Loading, migrating and saving `PlayerData` (a `.tres` Resource). Saves are debounced by 1 s and flushed on scene change and exit. The economy: coins, gems and upgrade cost `int((lvl+1)^1.6*15)`. Car, level and mode selection. |
| `Audio` | `scripts/global/Audio.tscn/.gd` | The music player and a pool of FX players (`Audio.play` / `queueRequest`), limited by Max Sound Effects. Goon death sounds use it too. |
| `Region` | `scripts/global/Region.gd` | Named regions generated per terrain, 3 goon types per region, and a 60 s wave timer per region that awards stars. Also pushes terrain friction to the car and the goon list to the spawner. |
| `Bench` | `scripts/debug/bench.gd` | The benchmark harness. It frees itself unless the game is launched with `--bench`. |

### Flow
1. `main2.tscn` (`scene/player/menu/main/`) is the main menu, a state machine with RIDER → LEVEL → GAMEMODE states.
   - The GAMEMODE step is commented out at `main2.gd:277`, so runs always use the saved `gameMode`, which defaults to GOONCRUSHER.
   - The menu shows cars from their `CarInfo` (`scene/car/<car>/<car>_info.tres`: portrait, background, intro lines, base stats) in `Root.carInfo`, without loading car scenes. **`Root.playerCar` is null in the menu**; it is the run's car only.
2. Starting a run loads the level and the selected car's scene on worker threads (`main2.startLevel`), then changes scene to `RunView.wrap(level)`. At Render Resolution 720p or 540p, `scene/level/run_view.gd` puts the whole run (level, HUD, in-run menus) in a SubViewport of that height with the 1600x900 logical canvas and scales it up. Otherwise the level is the scene. Inside a run, `get_viewport()` may therefore be that SubViewport. It listens for 2D audio itself, and the root viewport's GPU timing doesn't include it. Each level `scene/level/levels/level_*.tscn` is a thin override of `levelRoot.tscn` that changes only timer seconds, object pools and spawn tuning.
3. `levelRoot.gd` instantiates `Root.selectedCar.scene`. It then attaches 5 spawners **as children of the car**, so their offsets rotate with it, and runs day/night by tweening a `CanvasModulate` to pure black every 60 s.
4. `tileManager.gd` and `landscapeGenerator.gd` handle the world:
   - A 256×256 noise grid becomes terrain types in `terrainMap` (`PackedByteArray`) and region ids in `regionMap` (`PackedInt32Array`), index `y * 256 + x`. Read cells with `landscapeGenerator.cellAt(x, y)` or `tileManager.tileAt(chunk)`, which return `{"terrain", "region"}`. Each cell is one 5120×2560 px chunk, which is one TileMap per terrain type.
   - The grid, the grass start area (region 0) and the region flood fill are built on a `WorkerThreadPool` task by static functions that touch only their job dictionary; the start area's random rolls are taken on the main thread first. The maps stay empty (every cell reads as water) until `createNewTerrain()` returns.
   - Chunks the camera can see, plus 1 s of travel, are loaded one per frame. Chunks more than 2 away (Chebyshev) are unloaded, except the pinned station chunk; their landscape TileMaps go to a pool (8 per terrain) and are reused, while objects are freed. Chunk (0,0) is map cell (128,128); `tileManager.chunkOf()` uses floor, and anything outside the map is water. Each chunk's objects come from its own seed.
5. A run ends in one of three ways:
   - The car calls `levelRoot.endLevel()` on NOHEALTH or NOGAS.
   - The station driveway calls it with SUCCESS, in SPRINT and MARATHON only.
   - `gameSummary` records stats and sets `Root.earnedCoins = coin * star`.
   Returning to `main2` pays the coins out.

### Key gameplay code
- `lib/overhead_car_2d/overhead_car_body_2d.gd` is the car. It is a KidsCanCode bicycle-model `CharacterBody2D` that also handles collisions and crushing, damage, fuel, rewards, the camera zoom, the headlights and the station indicator.
  - Stats are plain ints. Base stats and menu data (`carId`, `charName`, `profilePic`, `backgroundPic`, `introAudio`) come from the car's `info: CarInfo`, whose setter copies them in (`CarInfo.FIELDS`). **Edit them in `<car>_info.tres`, not on the car scene.** Upgrades are added in `_ready`, and powerups are applied with `reward()`.
  - The 9 cars are inherited scenes in `scene/car/<name>/`, each with its `<name>_info.tres`; `CarInfo.pathFor(scenePath)` maps one to the other.
- `scene/player/controller/playerCarController.gd` handles input. All input is digital, so analog values are ignored.
- `scene/enemy/spawnManager.gd`, `scene/player/spawner.gd` and `scene/enemy/walker/walker.gd` handle goons. There are 18 goons, all one walker state machine with different numbers. They die in one hit at speed > 100. Two places must be updated together when adding goons:
  - the `goon` enum, which is duplicated in `root.gd` and `spawnManager.gd` in the same order;
  - `Region.terrainGoons`.
- `scene/powerup/*` contains pickups. Collecting one credits it at once through `car.reward()`; the icon that flies to the HUD is a pooled visual from `scene/fx/reward_flyers.gd` and can be capped without changing totals. Never credit rewards from an animation.
- Goons are capped at 250 (`SpawnManager.GOON_CAP`, the same for every preset) and swept every 0.5 s when they are more than 8000 px away and off screen.
- `scene/player/slots/*` and `scene/fx/lotto/*` are the slot machine: 3 reels with no combo logic, and a reroll costs 1 gem.
- `scene/player/playerRoot.gd` is the HUD. Crush milestones at `(n+1)^1.7*12` award a star and a free slot machine.
- `scene/player/menu/settings/*` is the settings overlay. `settings_menu.gd` builds the tabs from `buildSchema()`; each row is an `OptionRow` (choice, slider, button, header or binding), and `SettingsDialog` is the shared modal. To add a setting: add the key to `Settings.DEFAULTS` (plus `OPTIONS`/`RANGES`, and `PRESET` if presets drive it), apply it in `Settings.applyKey` or read it where it is used, then add a row.

### Save data (`scene/player/save/playerData.gd`, template `playerData.tres`)
- The save is a text `.tres` Resource that embeds the script path. **Renaming or moving `playerData.gd` breaks existing player saves.**
- `SaveManager.migrate()` merges every loaded save with the script defaults: new cars and levels are added, scene paths and record keys are updated, locked cars get current prices, and unlocks and beaten modes are kept. The demo and the full game share the save, so demo progress carries over. Bump `SAVE_VERSION` and extend `migrate()` when you add fields; `tests/game/test_save_migration.gd` covers it.
- `levels` is `@export` now, so unlocks and `gamemodeBeat` are saved.
- `settings` in the save is legacy (demo volumes). `Settings.import_legacy_volume()` reads it once and nothing writes it. Delete it one release after launch.

## Conventions and gotchas

- **Physics is tick-based, not delta-based.** Car steering ramp, fuel burn, camera zoom and goon idle counters all advance per physics tick. Never change `physics_ticks_per_second`, and never expose it as a setting.
- Frame caps exist (Frame Rate Limit, Menu Frame Rate), so anything visual must be delta-based or advance per physics tick. Slot reels advance in `_physics_process` (exactly 60 Hz, so the reels stay aligned); never go back to per-frame steps.
- **There is one 3D text shader.** Every 3D-text material references `shader/3dtext.gdshader` with a `time_mode` parameter (0 oscillate, 1 one-sided, 2 spin, 3 none). Never paste the shader inline into a scene. Quality comes from the `gc_*` globals in `project.godot [shader_globals]`, and every global a shader uses must be declared there.
- **Icons are original SVGs in `texture/icon/`.** `<name>.svg` has its own extruded edge and is for plain sprites and TextureRects (pickups, slot reels, the lotto wall). `<name>_flat.svg` is for anything drawn by the 3D text shader: `front_tex`/`back_tex`, a TextureRect with a 3D-text material, a `roadButton` `icon`/`myIcon`, and the menu stars `main2.gd` gives star materials at runtime. The shader extrudes the node's own texture, so a non-flat icon there gets its depth twice. Each `.import` sets `svg/scale` (the art is 64 units) to the pixel size the layouts expect, 96 or 48. `discord.png` and `steam.png` are third-party logos; replace them with the official brand files, never redraws.
- Goon animations are separate PNG files per frame. Packing them into an atlas was measured and dropped: drawing every goon from one shared texture cut S4 draw calls from 178 to 116 but saved only 0.1 ms of render CPU and no GPU time. (Godot's TextureAtlas importer also only wrote its failure placeholder from the command line.) Pickup materials are shared now; don't set `resource_local_to_scene` on them again.
- Night is gameplay. With `CanvasModulate` at black, visibility comes only from the car's 2D lights:
  - The 5 headlamps cast shadows, or the baked `simpleCone` does when Simple Headlight Cone is on (one shadowed light with the same reach). Both sit under `headlamps/headlights`, whose scale is the Headlights stat. Re-run `scripts/debug/bake_headlight_cone.gd` if you change the lamps.
  - Goons, rocks and walls all carry `LightOccluder2D`.
  - `Settings.onNodeAdded` sees every light and occluder and ANDs the Lighting setting with the authored state (the `gc_shadow`, `gc_enabled` and `gc_vis` metadata). Lighting Low (Potato only) changes what the player can see; Medium and High don't.
- Collision checks use `is StaticBody2D`, `is TileMap` and `is CharacterBody2D`, and any `CharacterBody2D` is treated as a goon. Moving from TileMap to TileMapLayer will silently break wall hits.
- `randi() % n - 1` indexing appears in `Region.gd` and `gameSummary.gd`. It looks wrong, but it works because index -1 wraps.
- `getPowerupFromWeights` mutates the caller's dictionary and sets the coin weight to `luck`.
- HUD label naming is confusing: "Luck" shows `clover` and "Dice" shows `luck`.
- Demo gates live in `main2.gd` (around lines 54, 111-117 and 197-233) and in `versionTracker` ("Demo 0.1"). Remove them for the full release.
- Code style: tabs, camelCase functions and variables (mixed with some snake_case from the original templates), heavy use of the `Root.*` globals, and `$Node` paths. Match the surrounding style. Don't add empty `_process` or `_ready` stubs; they were all removed because they cost per-frame callbacks. Connect autoload signals such as `Settings.changed` to methods, not lambdas, so they disconnect when the node is freed.

## Known critical bugs (full lists in `docs/`)
- GOONCRUSHER cannot be won: the countdown end is commented out in `scene/player/Timer.gd:34-39`. Because of that, SPRINT never unlocks on a fresh save.
- MARATHON places its station far outside the 256-cell map (`seconds * 0.7` chunks in `tileManager.gd`). It no longer crashes, because outside the map is water, but the station is unreachable. DEFENSE reads `Root.station` before it is set (`levelRoot.gd`).
- A run that ends with 0 stars pays 0 coins (payout is `coin * star`), and the summary screen doesn't say so.
