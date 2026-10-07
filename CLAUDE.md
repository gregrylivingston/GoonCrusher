# GoonCrusher: context for AI assistants

GoonCrusher is a top-down 2D arcade car game in **Godot 4.7 / GDScript**. You drive across a procedurally generated, chunk-streamed world and run over "goons" at speed to crush them, earning coins, stars and slot-machine bonuses. Between runs, coins buy cars and per-car stat upgrades. A free demo is live on Steam (app 1941650); the current work is finishing the full release.

This file is a map. The detail lives in `docs/`:
- `docs/WORLD.md`: levels and `LevelDef`s, the world generator, districts, objectives and route clocks, chunk recipes and streaming, the ground shader, water, breakables, wall contact, goon/AI hooks, how to add a level, prop or terrain.
- `docs/WORLD_ART.md`: generated world art (ground materials, strips, props and `props.json`, station, posters, the bake).
- `docs/GOONS.md`: the 43 generated goons (factions, the `Goons` registry, verbs, crush rules, GoonFx, bake).
- `docs/PICKUPS.md`: the 78 pickups (the `Pickups` registry, drop roll, buffs, gadgets, slot paylines, pausing menus, world events, hooks in shared files).
- `docs/CAR_ART.md`: generated car art and the system damage model.
- `docs/HUD.md` and `docs/UI.md`: the in-run HUD; the card menus, `MenuTheme` and key hints.
- `docs/AI_DRIVER.md`: the AI driver, the playtest harness and tournaments.
- `docs/PERFORMANCE.md`: the settings system, every option and preset, benchmarks and the latest numbers.
- `docs/GAMEPLAY_SUGGESTIONS.md`: what is done (one line each) and the open work packages.

## Running and tooling

- **Engine:** Godot 4.7.2, renderer `mobile` (Vulkan). Editor: `C:/Users/Greg/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`; use the `..._console.exe` beside it for CLI runs (it prints to stdout). The dev box (Intel HD 620, 4 threads) is the low-end target; Compatibility runs through ANGLE/D3D11 there and is slower.
- **CLI runs:** bound them with `--quit-after <frames>`. Godot eats its own display flags and saved settings override them, so use the game's user args: `-- --window=1600x900`, `-- --uncapped` (no V-Sync, no cap), `-- --safe-mode` (Potato, windowed, Compatibility, once), `-- --reset-graphics` (deletes `graphics.cfg` and `override.cfg`). F3 cycles the performance overlay.
- **Tests:** `Godot_console.exe --headless --path . -s res://tests/game/run_tests.gd` (or `scripts/*/run_game_tests.*`); the exit code is the failure count (224 tests, all passing). They use `tests/game/game_test.gd`, a small GUT-compatible base, because **GUT 9.0.0 does not parse on 4.7**. The rest of `tests/` belongs to rmsmartshape. Headless runs skip tier detection and the crashed-boot counter.
- **Benchmarks:** `scripts/debug/bench.gd` (autoload `Bench`, inert without `--bench`), e.g. `Godot_console.exe --path . -- --bench=S3 --uncapped --preset=low --seconds=90`. Scenarios and options are in its header and `docs/PERFORMANCE.md`. Output: `user://bench/`. Level scenes can also be launched directly; they fall back to the saved car.
- **Playtests:** `scripts/debug/playtest.gd` (autoload `Playtest`, inert without `--playtest`) plays real runs with the AI driver, e.g. `Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=countdown,sprint --level=prairie --car=sedan --runs=8 --seed=1`. The game, the playtest and `scripts/ai/tournament.py` all play `AIProfiles.BEST` (`"cautious"`, `scripts/ai/ai_profiles.gd`) unless `--profiles` says otherwise. `--world-preview` prints generated maps as text. Options and output: `docs/AI_DRIVER.md`. Write long output to a file.
- **Never pipe a Godot run into `head` or `Select-Object -First`:** the process keeps running and spoils later benchmarks. Capture, then filter.
- **Save location:** `user://` is `%APPDATA%/GoonCrusher/` (`use_custom_user_dir`). Progress `saveData_0.1.tres`; settings `settings.cfg`, `graphics.cfg`; renderer `override.cfg`. **Back them up before testing.** Bench and playtest runs use a scratch save.
- **Addons:** `gut` (tests only, broken on 4.7), `rmsmartshape` (unused, removable), `godotsteam` (loads on 4.7; no game code calls Steam yet).
- **Exports:** `export_presets.cfg` (tracked, no secrets) has one Windows Desktop preset that writes to `build/` and excludes tests, editor addons, `scripts/art/*`, bake helpers and source art. **Install the 4.7.2 export templates before shipping** (the dev box has 4.7.0).

## Architecture

### Autoloads (in load order)
| Name | File | Owns |
|---|---|---|
| `Settings` | `scripts/global/settings.gd` | `settings.cfg` (synced) and `graphics.cfg` (per machine), presets, tier detection and calibration, safe mode, the `gc_*` shader globals, the lighting hook on `node_added`, rebinding, the F3 overlay, and `menu_open` (push/pop) to block input under menus. Read with `Settings.get_value("gfx/smoke")`. |
| `Root` | `scripts/global/root.gd` | Global enums (`gameModes`, `endCondition`, `upgrade`, `terrain`), shared refs (`playerCar` (null in the menu), `carInfo`, `station`, `levelRoot`, `spawnManager`, `playerRoot`, `mainMenu`, `worldMap`), run flags and currency, `getPowerupFromWeights`, mode descriptions, `IS_DEMO`. |
| `SaveManager` | `scripts/global/saveManager.gd` | Loading, migrating and saving `PlayerData` (debounced 1 s, flushed on scene change and exit), the economy (upgrade cost `int((lvl+1)^1.6*15)`), selection, per-level records. |
| `Audio` | `scripts/global/Audio.tscn/.gd` | Music and a pooled FX player (`Audio.play`), capped by Max Sound Effects. |
| `Region` | `scripts/global/Region.gd` | The run's regions = the world map's districts: faction, 3 goons, name, a 60 s wave timer paying stars (carried over between districts of one faction). Pushes the goon list to the spawner. `-- --faction=` / `-- --goons=` force them. |
| `Bench`, `Playtest` | `scripts/debug/` | Harnesses; free themselves without `--bench` / `--playtest`. |
| `Console` | `scripts/debug/dev_console.gd` | Debug builds only. Backtick toggles it; `help` lists commands (unlocks, coins, gems, `level`, `heal`, `god`, `ai`, `pickup <id>`, `win`, `night`...). Progress commands write the real save. `-- --console="unlock all;coins 50k"` runs commands at startup. |

### Flow
1. `scene/player/menu/main/main2.tscn` is the menu, built in code (docs/UI.md): GARAGE (driver cards, upgrades) and RUN SETUP (level posters, mode medallions). Mode unlocks: `Root.isModeUnlocked` (Countdown → Sprint → Goonpocalypse; Marathon and Defense after Sprint), `Root.MODE_AVAILABLE`, combined in `Root.isModePlayable`. G opens the Goonopedia. The menu shows cars from `CarInfo` (`scene/car/<car>/<car>_info.tres`), not car scenes.
2. Starting a run loads the level and car on worker threads, then changes scene to `RunView.wrap(level)` (`scene/level/run_view.gd`: at Render Resolution 720p/540p the whole run renders in a SubViewport, so `get_viewport()` in a run may be that SubViewport).
3. Levels are a registry: `Levels.ORDER` (`scripts/world/levels.gd`: prairie, bayou, canyon, quarry, frostbite, highway, city, crusher; the demo gets the first 3), one `LevelDef` per level in `world/levels/<id>.tres`. `scene/level/levels/level_<id>.tscn` only inherits `levelRoot.tscn` and sets `def`; **edit level numbers in the `.tres`**. Tools take a level id, index or old scene name (`Levels.LEGACY_KEYS`).
4. `levelRoot.gd` (`Level`) applies the def, instantiates the car, attaches 5 spawners **as children of the car**, and runs day/night by tweening a `CanvasModulate` to black every 60 s. `TileManager` builds the world map on a worker and streams chunks (docs/WORLD.md).
5. Endings: everything goes through `levelRoot.endLevel()` once (`hasEnded`). The clock (`Timer.gd`) counts down except in Goonpocalypse; at 0 `Level.timeUpCondition` decides (Countdown and Defense win, Sprint and Marathon lose). Sprint wins at the station driveway, its clock derived from the A* route; Marathon is `Level.MARATHON_LEGS` legs (`Level.stationReached`); Defense loses when the station barrier (`station.gd`) hits 0; Goonpocalypse is endless and beaten by surviving `POCALYPSE_TARGET` × seconds. `gameSummary` credits `Root.computePayout(coin, star)` = coin × max(1, star) to the save and, in debug builds, appends to `user://runlog.csv`.

### Key gameplay code
- **Car:** `lib/overhead_car_2d/overhead_car_body_2d.gd`, a bicycle-model `CharacterBody2D` that handles collisions, crushing, damage, fuel, rewards, camera zoom, headlights and the station indicator. Base stats come from its `info: CarInfo` (**edit `<car>_info.tres`, not the scene**). 9 cars in `scene/car/<name>/`. Art is generated (`scripts/art/car_gen.js`, docs/CAR_ART.md): **never paint the PNGs**.
- **Handling lives in `integrate()`**, which must stay pure (one tick, no side effects): the AI driver predicts with it. It reads the ground (`World.surfaceAt`), `car.buffs` and `conditionFactor()`.
- **Input:** `scene/player/controller/playerCarController.gd`; all input is digital. When `driver` is set (an `AIDriver`), the AI holds the keys.
- **Goons** (docs/GOONS.md): tune in `scripts/global/goons.gd`; base `Walker` (`scene/enemy/walker/walker.gd`), verbs in `goon_verbs.gd`, effects in `goon_fx.gd`. The car calls `goon.tryCrush(car, speed)`. The AI reads `Walker.mode` and `myMode`; keep those names. Capped at 250 (`SpawnManager.GOON_CAP`), swept every 0.5 s when off screen and either over 8000 px away or stuck (`Walker.isStuck`).
- **Pickups** (docs/PICKUPS.md): tune in `scripts/global/pickups.gd`. Collecting credits at once; the flying icon is visual only. **Never credit rewards from an animation.**
- **Slot machine:** `scene/player/slots/*`, `scene/fx/lotto/*`. Crush goals (`playerRoot.gd`, milestones at `(n+1)^1.7*12`) alternate between it and The Deal. Pausing pickup menus join group `slotMachine` so the harnesses tap through them.
- **HUD:** `scene/player/playerRoot.tscn` (docs/HUD.md). Pickups fly to the node in group `"<powerup>ui"`.
- **Menus:** give a new menu `theme = MenuTheme.theme()`, one `PrimaryButton`, and `KeyHint`s; never hard-code "A" or "Enter" (docs/UI.md).
- **Settings:** to add one, add the key to `Settings.DEFAULTS` (plus `OPTIONS`/`RANGES`, and `PRESET` if presets drive it), apply it in `Settings.applyKey` or where it is read, then add a row in `settings_menu.gd`'s `buildSchema()`.

### Save data (`scene/player/save/playerData.gd`)
- A text `.tres` that embeds the script path: **renaming or moving `playerData.gd` breaks player saves.**
- `SaveManager.migrate()` merges every save with the defaults (demo saves carry over). Bump `SAVE_VERSION` (now 5) and extend `migrate()` when adding fields; `tests/game/test_save_migration.gd` covers it.
- `levels` is rebuilt from `Levels.defaultEntries` keeping only each entry's unlock and `gamemodeBeat`; put anything else per level in `meta`. Pre-v5 entries (old scene names) carry their unlock by index, and records are rekeyed to level ids.
- `meta` sections: `records` (keyed by level id, `SaveManager.levelKey`), `hints`, `lifetime`, `medals`, `achievements`, `pickups`.
- `settings` in the save is legacy (read once by `Settings.import_legacy_volume()`); delete it one release after launch.

## Conventions and gotchas

- **Physics is tick-based.** Steering ramp, fuel burn, zoom, buffs and goon counters advance per physics tick. Never change `physics_ticks_per_second` or expose it. Anything visual must be delta-based or per tick, because frame caps exist (slot reels step in `_physics_process`).
- **One 3D text shader:** every 3D-text material references `shader/3dtext.gdshader` (`time_mode` 0–3); never inline it. Every `gc_*` global a shader uses must be declared in `project.godot [shader_globals]`.
- **Icons** are original SVGs in `texture/icon/`: `<name>.svg` for plain sprites, `<name>_flat.svg` for anything the 3D text shader draws (else the depth doubles). Pickup icons come from `scripts/art/pickup_icons.js`. `discord.png`/`steam.png` must be the official brand files.
- **Generated art** (cars, goons, pickups, world): change the generator and re-bake; never edit baked files.
- **Night is gameplay.** At night only the car's lights show the world: 5 shadowed headlamps or the baked `simpleCone` (re-bake with `scripts/debug/bake_headlight_cone.gd` if the lamps change). Goons, tall props and walls carry `LightOccluder2D` (world ones tagged `gc_world`). `Settings.onNodeAdded` ANDs the Lighting setting with each light's authored state; only Lighting Low (Potato) changes what the player can see.
- **Physics layers:** 1 "Player" = world (chunk walls, props, station) and the car body; 2 "CarBody" = `carBodyArea`; 3 "Goon" = goons only (`collision_layer = 4`, mask 1+2), so goons never collide with each other. The car's mask is 1+3. There is no water collision: deep water is a grid check (`World.lethalAt`). Anything that must touch goons needs layer 3.
- **Walls:** `World.isWall(collider)` (`is StaticBody2D or is TileMap`); any `CharacterBody2D` is treated as a goon. Wall damage is per contact (`wallTick`); breakables smash at speed (docs/WORLD.md).
- **Terrain** is described once, in `World.TERRAIN`; `Root.terrain` is append-only and mirrored (docs/WORLD.md, "How to add a terrain value"). Use `World.isPassable/isLethal/...`, never compare against WATER or HILLS. `World`'s runtime queries are called from `integrate()` and must stay allocation-free.
- **World workers** (`WorldGen`, `WorldField`, `ChunkRecipe`) touch only their job Dictionary: no nodes, autoloads or global RNG (use `WorldGen.ihash`). Never build a raster or recipe on the main thread in a run; keep `ChunkView` steps inside `TileManager.APPLY_BUDGET_USEC`.
- **Explosions:** `Root.levelRoot.explode(pos)` (pooled); never instantiate `explosionScene` per blast.
- **Stats:** `clover` is labelled "Clover" (drop chance), `luck` "Dice" (prize quality). Upgrades cap at `SaveManager.MAX_UPGRADE_LEVEL` (20), in-run stats at `STAT_CAP` (150). Oil goes through `fuelBurn()`, traction through `gripFor()`, armor once inside `damage()`.
- Goon animations are one PNG per frame (an atlas was measured and dropped). Pickup materials are shared; don't set `resource_local_to_scene` on them.
- `randi() % n - 1` indexing in `Region.gd` and `gameSummary.gd` looks wrong but works (index -1 wraps).
- **Style:** tabs, camelCase (some snake_case), `Root.*` globals, `$Node` paths. No empty `_process`/`_ready` stubs. Connect autoload signals (e.g. `Settings.changed`) to methods, not lambdas.

## Known issues
- Nothing has been tuned by hand: Sprint clocks, the drop mix, the 9 cars, the modes' numbers, late-level escalation and payouts (`docs/GAMEPLAY_SUGGESTIONS.md`, package 1 and "Open items").
- Night crowds miss the Low/Potato frame targets; the cost is the goon physics tick (`docs/PERFORMANCE.md`).
- The AI driver has no real Defense strategy and skips pickups near deep water (`docs/AI_DRIVER.md`).
- World follow-ups (cars stalling on bumper-only collision, sticky Frostbite passes, highway edges, landmark beacons by day, no first-run hints, all-GDScript world build of 1.3–2.9 s): `docs/WORLD.md`, "Known issues".
