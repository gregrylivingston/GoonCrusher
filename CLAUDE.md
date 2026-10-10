# GoonCrusher: context for AI assistants

GoonCrusher is a top-down 2D arcade car game in **Godot 4.7 / GDScript**. You drive across a procedurally generated, chunk-streamed world and run over "goons" at speed to crush them, earning coins, stars and prize games. Between runs, coins buy cars and per-car upgrades. A free demo is live on Steam (app 1941650); the current work is finishing the full release.

This file is the map and the rules. The code and data files are the source of truth; a doc says where things live, why, and what breaks if you ignore it. **Keep docs that way: don't copy numbers, tables or behavior out of the code into a doc.**

| Doc | Covers |
|---|---|
| `docs/roadmap/` | Everything not built yet: `ROADMAP.md` (the 0.3 demo release list, decisions, open questions) and one `ROADMAP_<AREA>.md` per area. The one home for open work. |
| `CHANGELOG.md`, `promo/marketing/` | What changed for players, by version; feature fact sheets and post templates built on it. |
| `docs/MODES.md` | Game modes, tiers, level unlocks, endings and pay. |
| `docs/WORLD.md`, `docs/WORLD_ART.md` | Levels, landscapes, regions, the generator, chunks, terrain, water, props; the generated world art and its bake. |
| `docs/GOONS.md` | Goons: registry, classes, verbs, crush rules, effects, bake. |
| `docs/PICKUPS.md` | Pickups, drops, unlock trees, prize games, gift boxes, world events. |
| `docs/CAR_ART.md` | Cars: generated art, damage, handling, traits, driving feel. |
| `docs/HUD.md`, `docs/UI.md` | The in-run HUD; the menus, `MenuTheme`, key hints, transitions. |
| `docs/AI_DRIVER.md` | The AI drivers, playtests, career playtests, tournaments. |
| `docs/PERFORMANCE.md` | Settings, presets, benchmarks. |
| `docs/NATIVE.md` | The C++ GDExtension. |
| `docs/RADIO.md` | The radio: what the audio author delivers. Lyrics, prompts and scripts are in `sound/radio/gooncrusher/writing/`. |
| `docs/PROMO.md`, `promo/README.md`, `promo/CLAUDE.md` | The capture kit for trailers and stills. |
| `docs/TEST_SCOPE_TRANSITIONS.md` | The manual test checklist. |

## Running and tooling

- **Engine:** Godot 4.7.2, renderer `mobile` (Vulkan). Use the `Godot_v4.7.2-stable_win64_console.exe` for CLI runs (it prints to stdout); its path differs per machine. Use the same Godot version on every machine. The low-end target is an Intel HD 620 with 4 threads.
- **CLI runs:** bound them with `--quit-after <frames>`. Godot eats its own display flags, so use the game's user args after `--`: `--window=1600x900`, `--uncapped`, `--safe-mode`, `--reset-graphics`. F3 cycles the performance overlay.
- **Never pipe a Godot run into `head` or `Select-Object -First`:** the process keeps running and spoils later benchmarks. Write long output to a file, then filter.
- **Tests:** `Godot_console.exe --headless --path . -s res://tests/game/run_tests.gd` (about 12 min; the exit code is the failure count; run `--import` first after pulling). They use `tests/game/game_test.gd`, a small base with GUT's assert names.
- **Harnesses** are autoloads that free themselves without their flag; each script's header lists its options. All use a scratch save and open every unlock (`--unlocks=save` plays the progression).
  - `--bench=<scenario>` (`scripts/debug/bench.gd`, docs/PERFORMANCE.md), output in `user://bench/`.
  - `--playtest` (`scripts/debug/playtest.gd`, docs/AI_DRIVER.md): real runs with the AI driver, e.g. `--headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=countdown,sprint --level=prairie --car=sedan --runs=8 --seed=1`. `--world-preview` prints generated maps as text.
  - `--career --persona=... --start=... --sessions=N` (`scripts/debug/career.gd`): a persona plays the whole game through the real menus and reports blocks, softlocks and economy issues.
  - `--capture` (`scripts/debug/capture.gd`, driven by `python promo/tools/capture.py`; docs/PROMO.md).
- **Dev console** (debug builds, backtick; `scripts/debug/dev_console.gd`): `help` lists commands. `start <tier>` plays from further in on a scratch save (`start real` goes back); `play <mode> [level] [tier]` starts any run; `autopilot` hands the game to a persona. Other progress commands write the real save. `-- --console="start late"` runs commands at startup; `-- --play-start=<tier>` does the same for hand testing.
- **Save location:** `user://` is `%APPDATA%/GoonCrusher/`: progress `saveData_0.1.tres`, settings `settings.cfg` and `graphics.cfg`, renderer `override.cfg`. **Back them up before testing**, or give the checkout its own user dir with an `override.cfg` in the repo root (`[application] config/custom_user_dir_name="..."`; it is not gitignored, so never commit it).
- **Git:** `.gitattributes` pins text to LF. Commit `.import` and `.uid` files.
- **Native code** (docs/NATIVE.md): the game needs the GDExtension in `bin/windows/` (gitignored), so **run `scripts/windows/build_native.bat` after cloning, making a worktree or editing `native/src/`**.
- **Exports:** one Windows preset in `export_presets.cfg` writes to `build/`. Build `template_release` of the native code and install the 4.7.2 export templates first.
- **Addons:** `godotsteam` (loads; no game code calls Steam yet).

## Architecture

### Autoloads (in load order)
| Name | File | Owns |
|---|---|---|
| `Settings` | `scripts/global/settings.gd` | `settings.cfg` and `graphics.cfg`, presets, tier detection, the `gc_*` shader globals, rebinding, the F3 overlay, `menu_open` (blocks input under menus). Read with `Settings.get_value("gfx/smoke")`. |
| `Root` | `scripts/global/root.gd` | Global enums (`gameModes`, `endCondition`, `upgrade`, `terrain`: all append only), shared refs (`playerCar` (null in the menu), `levelRoot`, `spawnManager`, `playerRoot`, `station`, `worldMap`), mode and level unlock rules, payout, `IS_DEMO`. |
| `SaveManager` | `scripts/global/saveManager.gd` | Loading, migrating and saving `PlayerData` (debounced, flushed on scene change and exit), the economy, per-level records. |
| `Audio` | `scripts/global/Audio.tscn` | The pooled FX player (`Audio.play`) and the radio (`Audio.radio`). |
| `Region` | `scripts/global/Region.gd` | The run's districts (goons from the level's line-up) and the wave clock. Not the road atlas's regions: those are `Territories`. |
| `Bench`, `Playtest`, `Capture`, `Console` | `scripts/debug/` | The harnesses and the dev console. `promo/` is not exported, so nothing shipped may name a class from it. |

### Flow
1. **Menu:** `scene/player/menu/main/main2.tscn`, built in code (docs/UI.md): the garage, run setup (road map, then Level Options), the Pickups screen (`PickupShop`) and the Goonopedia. It shows cars from `CarInfo` (`scene/car/<car>/<car>_info.tres`), not car scenes.
2. **Unlocks** (`scripts/global/unlocks.gd`, docs/PICKUPS.md) answers what is open for pickups, cars, levels and modes. Locked pickups never drop or get offered. Unlocks open on the results ticket and the Pickups screen, never mid-run.
3. **Modes** (docs/MODES.md): `Root.gameModes`, described in `Modes.DATA`, with tiers in `ModeTiers`. `Root.modePath(level)` is the one mode order every menu, harness and test reads. **Run code branches on `Modes.running()` and the run's own `Level.runLevel`, `runMode` and `tier`, never on the save's selection.**
4. **Starting a run** loads the level and car on worker threads, then changes scene to `RunView.wrap(level)`: at Render Resolution 720p/540p the run renders in a SubViewport, so `get_viewport()` in a run may be that SubViewport.
5. **Levels** are a registry (`Levels.ORDER`, `scripts/world/levels.gd`): one `LevelDef` per level in `world/levels/<id>.tres`, its landscape in `world/landscapes/<id>.tres`. `scene/level/levels/level_<id>.tscn` only inherits `levelRoot.tscn` and sets `def`: **edit level numbers in the `.tres`**. Tools take a level id, index or scene name (`Levels.resolve`).
6. **In a run**, `levelRoot.gd` (`Level`) applies the def, instantiates the car and attaches the spawners as children of the car. `TileManager` builds the world map on a worker and streams chunks (docs/WORLD.md).
7. **Endings:** everything goes through `levelRoot.endLevel()` once (`hasEnded`); `gameSummary` credits `Level.runPayout(won)` to the save.

### Key gameplay code
- **Car:** `lib/overhead_car_2d/overhead_car_body_2d.gd`, a bicycle-model `CharacterBody2D`. Base stats come from its `CarInfo`: **edit `<car>_info.tres`, not the scene.** Cars live in `scene/car/<name>/`.
- **`integrate()` must stay pure** (one tick, no side effects): the AI driver predicts with it. Handling numbers are in `CarHandling` (docs/CAR_ART.md). Walls are handled after `move_and_slide`, in `wallResponse`. The semi's trailer and the drift boost charge are moved outside `integrate()`.
- **Input:** `scene/player/controller/playerCarController.gd`; all input is digital. When `driver` is set (a `CarDriver`; the AI's is an `AIDriver`) it holds every key and button. Actions are in `project.godot`.
- **Crushing:** the car calls `goon.tryCrush(car, speed)`. Only the bumper shapes crush on contact (the middle hull is for walls), so the flanks and tail crush in `slamGoons()`.
- **Goons** (docs/GOONS.md): tune in `scripts/global/goons.gd`; base `Walker` (`scene/enemy/walker/walker.gd`) on the native `GoonBody`. The AI reads `Walker.mode` and `myMode`: keep those names.
- **Pickups** (docs/PICKUPS.md): tune in `scripts/global/pickups.gd`. Collecting credits at once; the flying icon is visual only. **Never credit rewards from an animation or a transition.** Code that hands out a fixed pickup id goes through `Pickups.openOr` or `PickupEffects.collect`.
- **Prize games** extend `PickupMenu` (`scene/pickups/menus/`) and join group `slotMachine` so the harnesses tap through them. Try one in `tests/prize_lab/<game>.tscn` (F6) or with `-- --prize=<game>`.
- **HUD:** `scene/player/playerRoot.tscn` (docs/HUD.md). Pickups fly to the node in group `"<powerup>ui"`. A dashboard skin is paint: scales and the meaning of green, red and amber never change.
- **Menus** (docs/UI.md): `theme = MenuTheme.theme()`, one `PrimaryButton`, `KeyHint`s; never hard-code "A" or "Enter". Everything must work with the mouse alone and with a pad alone. Show amounts with the game's symbols, not words (`MenuTheme.symbolRow`).
- **Transitions:** `Transition.play(swap)` for screens, `GameHatch` for in-run games, `Juice.dropIn` for overlays. Headless runs skip them.
- **Music** is the radio (docs/RADIO.md): tracks are files in `sound/radio/<station>/`, scanned at startup. Never add another music player; anything that should duck the music plays on the Voice bus.
- **Settings:** adding one is a recipe in docs/PERFORMANCE.md, "How settings work".

### Save data (`scene/player/save/playerData.gd`)
- A text `.tres` that embeds the script path: **renaming or moving `playerData.gd` breaks player saves.**
- `SaveManager.migrate()` merges every save with the defaults. When adding fields, bump `SAVE_VERSION`, extend `migrate()` and `tests/game/test_save_migration.gd`.
- **Saves older than `SaveManager.FIRST_KEPT_VERSION` start over** (the author's call): `load_data` backs the old file up and makes a new save. Any run of the game or the tests does this to the real save in `user://`.
- `levels` is rebuilt from `Levels.defaultEntries` keeping only each entry's unlock and `gamemodeBeat`; put anything else per level in `meta` (sections: `records`, `hints`, `lifetime`, `medals`, `achievements`, `pickups`, `unlocks`, `carClears`).
- `settings` in the save is legacy (read once by `Settings.import_legacy_volume()`); delete it one release after launch.

## Conventions and gotchas

- **Physics is tick-based.** Steering, fuel burn, zoom, buffs and goon counters advance per physics tick. Never change `physics_ticks_per_second`. Anything visual must be delta-based or per tick, because frame caps exist.
- **Gameplay code must not read the wall clock:** a taped hand drive replays tick for tick (docs/PROMO.md).
- **Generated art** (cars, goons, pickup icons, world): change the generator in `scripts/art/` and re-bake; never edit or paint baked files.
- **Icons** are original SVGs in `texture/icon/`: `<name>.svg` for plain sprites, `<name>_flat.svg` for anything the 3D text shader draws (else the depth doubles). `discord.png`/`steam.png` must be the official brand files.
- **One 3D text shader:** every 3D-text material references `shader/3dtext.gdshader`; never inline it. Every `gc_*` global a shader uses must be declared in `project.godot [shader_globals]`.
- **Night is gameplay.** At night only the car's lights show the world. Goons, tall props and walls carry `LightOccluder2D`. Only Lighting Low (Potato) may change what the player can see. Re-bake the headlight cone (`scripts/debug/bake_headlight_cone.gd`) if the lamps change.
- **Physics layers:** 1 = world and the car body; 2 = `carBodyArea`; 3 = goons only, so goons never collide with each other. The car's mask is 1+3. Anything that must touch goons needs layer 3. Water has no collision: it is a grid check (docs/WORLD.md).
- **Walls:** `World.isWall(collider)`, mirrored in `GoonBody::advance`; any `CharacterBody2D` is treated as a goon.
- **Terrain** is described once, in `World.TERRAIN`. Use `World.isPassable/isLethal/...`, never compare against a terrain value. `World`'s runtime queries are called from `integrate()` and must stay allocation-free; they answer from the native `WorldGrid`, so a rule change goes in both the GDScript and `native/src/world_grid.cpp` (parity tests compare them).
- **World workers** (`WorldGen`, `WorldField`, `ChunkRecipe`) touch only their job Dictionary: no nodes, autoloads or global RNG (use `WorldGen.ihash`). Never build a raster or recipe on the main thread in a run; keep `ChunkView` steps inside `TileManager.APPLY_BUDGET_USEC`.
- **Explosions:** `Root.levelRoot.explode(pos)` (pooled); never instantiate `explosionScene` per blast.
- **Stats:** `clover` is labeled "Clover" (drop chance), `luck` "Dice" (prize quality). Oil goes through `fuelBurn()`, armor once inside `damage()`.
- Goon animations are one PNG per frame (an atlas was measured and dropped). Pickup materials are shared; don't set `resource_local_to_scene` on them.
- `randi() % n - 1` indexing in `Region.gd` and `gameSummary.gd` looks wrong but works (index -1 wraps).
- **Style:** tabs, camelCase (some snake_case), `Root.*` globals, `$Node` paths. American English everywhere: game text, comments, identifiers and file names (tire, color, center, gray). No empty `_process`/`_ready` stubs. Connect autoload signals to methods, not lambdas. Comments say what the code does and why, not what it used to do.

Open work and known issues: `docs/roadmap/`. Nothing has been tuned by hand yet. When a feature lands, delete its roadmap item and add a player-facing line to `CHANGELOG.md`.
