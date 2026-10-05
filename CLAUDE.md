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
- **CLI runs:** always pass `--windowed --resolution 1600x900` and bound the run with `--quit-after <frames>`. The project boots fullscreen. `--print-fps` prints an FPS reading every second.
- **Running a level from the CLI doesn't work.** A level needs `Root.selectedCar`, which only the main menu sets. Benchmarks therefore boot `main2.tscn` and then change scene, using a throwaway `-s` script kept outside the repo.
- **Save location:** `user://` resolves to `%APPDATA%/GoonCrusher/`, because `use_custom_user_dir=true`. The save file is `saveData_0.1.tres`. **Back it up before running the game for testing.**
- **Tests:** everything in `tests/` belongs to the rmsmartshape addon. There are **no tests for game code**. The runner scripts in `scripts/windows|linux` point at `res://gut`, which doesn't exist. If you add game tests, put them in a separate folder such as `tests/game/`.
- **Addons:**
  - `gut`: tests. The main menu also borrows fonts from `addons/gut/fonts/` (`main2.tscn:6,10`, `splash_text.tscn`). Move those fonts before excluding gut from exports.
  - `rmsmartshape`: an editor plugin that no game scene uses, so it can be removed.
  - `godotsteam`: the binaries are present, but **no game code calls Steam**.
- **Repo hygiene:**
  - `.godot/` appears in `.gitignore`, but 874 files under it are still tracked.
  - About 12 editor `*.tmp` scene backups are committed.
  - `export_presets.cfg` is gitignored, so export settings are not in version control.

## Architecture

### Autoloads (`project.godot` [autoload], in load order)
| Name | File | Owns |
|---|---|---|
| `Root` | `scripts/global/root.gd` | Global enums (`gameModes`, `endCondition`, `upgrade`, `terrain`, `goon`). Shared node references: `playerCar`, `station`, `levelRoot`, `spawnManager`, `playerRoot` (HUD) and `mainMenu`. Run flags and earned currency. The powerup preload table with `getPowerupFromWeights`. Mode descriptions. |
| `SaveManager` | `scripts/global/saveManager.gd` | Loading and saving `PlayerData` (a `.tres` Resource). The economy: coins, gems and upgrade cost `int((lvl+1)^1.6*15)`. Car, level and mode selection. Applying saved volume to the audio buses. |
| `Audio` | `scripts/global/Audio.tscn/.gd` | The music player and a pool of FX players, capped at 4 new sounds per frame. |
| `Region` | `scripts/global/Region.gd` | Named regions generated per terrain, 3 goon types per region, and a 60 s wave timer per region that awards stars. Also pushes terrain friction to the car and the goon list to the spawner. |

`scripts/global/Event.gd` is an empty stub and nothing uses it.

### Flow
1. `main2.tscn` (`scene/player/menu/main/`) is the main menu, a state machine with RIDER → LEVEL → GAMEMODE states.
   - The GAMEMODE step is commented out at `main2.gd:277`, so runs always use the saved `gameMode`, which defaults to GOONCRUSHER.
   - The menu calls `instantiate()` on the selected car **without adding it to the tree**. Treat `Root.playerCar` in the menu as an orphan data holder whose `_ready` never runs.
2. Starting a run calls `change_scene_to_file(level.scene)`. Each level `scene/level/levels/level_*.tscn` is a thin override of `levelRoot.tscn` that changes only timer seconds, object pools and spawn tuning.
3. `levelRoot.gd` instantiates `Root.selectedCar.scene`. It then attaches 5 spawners **as children of the car**, so their offsets rotate with it, and runs day/night by tweening a `CanvasModulate` to pure black every 60 s.
4. `tileManager.gd` and `landscapeGenerator.gd` handle the world:
   - A 256×256 noise grid becomes terrain types. Each cell is one 5120×2560 px chunk, which is one TileMap per terrain type.
   - About 16 chunks are streamed around the car. Chunk (0,0) is `mapDict[128][128]`.
   - Regions are labelled by an async flood fill that keeps running during play.
5. A run ends in one of three ways:
   - The car calls `levelRoot.endLevel()` on NOHEALTH or NOGAS.
   - The station driveway calls it with SUCCESS, in SPRINT and MARATHON only.
   - `gameSummary` records stats and sets `Root.earnedCoins = coin * star`.
   Returning to `main2` pays the coins out.

### Key gameplay code
- `lib/overhead_car_2d/overhead_car_body_2d.gd` is the car. It is a KidsCanCode bicycle-model `CharacterBody2D` that also handles collisions and crushing, damage, fuel, rewards, the camera zoom, the headlights and the station indicator.
  - Stats are plain ints. Upgrades are added in `_ready`, and powerups are applied with `reward()` as `self[name] += qty`.
  - The 9 cars are inherited scenes in `scene/car/<name>/`.
- `scene/player/controller/playerCarController.gd` handles input. All input is digital, so analog values are ignored.
- `scene/enemy/spawnManager.gd`, `scene/player/spawner.gd` and `scene/enemy/walker/walker.gd` handle goons. There are 18 goons, all one walker state machine with different numbers. They die in one hit at speed > 100. Two places must be updated together when adding goons:
  - the `goon` enum, which is duplicated in `root.gd` and `spawnManager.gd` in the same order;
  - `Region.terrainGoons`.
- `scene/powerup/*` contains pickups that fly to the HUD and call `car.reward()`.
- `scene/player/slots/*` and `scene/fx/lotto/*` are the slot machine: 3 reels with no combo logic, and a reroll costs 1 gem.
- `scene/player/playerRoot.gd` is the HUD. Crush milestones at `(n+1)^1.7*12` award a star and a free slot machine.
- `scene/player/menu/settings/*` is the settings overlay with tabs Gameplay, Sound, Graphics and Input. The Input tab is hidden and empty.

### Save data (`scene/player/save/playerData.gd`, template `playerData.tres`)
- The save is a text `.tres` Resource that embeds the script path. **Renaming or moving `playerData.gd` breaks existing player saves.**
- `cars[]` in the saved file replaces the script defaults. New cars, price changes and scene-path moves therefore never reach existing saves unless you add a migration.
- `settings = {volume:{master,voice,music,fx}}` lives inside the progress save. Lookups index it directly, so **adding keys crashes on old saves**, and Reset Save wipes the settings too.
- **`levels` is a plain `var`, not `@export`.** Level unlocks and `gamemodeBeat` are never saved.
- Before adding any saved field, add a schema version plus a merge-defaults migration in `SaveManager.load_data()`. The plan is to move settings into a separate `user://settings.cfg` (ConfigFile).

## Conventions and gotchas

- **Physics is tick-based, not delta-based.** Car steering ramp, fuel burn, camera zoom and goon idle counters all advance per physics tick. Never change `physics_ticks_per_second`, and never expose it as a setting.
- Some visuals are frame-based too and will speed up or slow down under an FPS cap: `slot_row.gd` reel scrolling, `splashicon_1.gd`, and the `smoke.gd` rotation. Convert them to use delta before adding an FPS cap.
- **The 3D text shader is copied about 24 times.** Copies are inline in `.tscn` files (car variants, `main2`, `roadButton`, `regionUi`, `top_menu`, `statUpgradeButton`, `gameSummary`, `car_panel`) plus `shader/3dtext.gdshader`, `3dText_Common.tres` and the star materials.
  - Each copy ray-marches `slices` (up to 64) texture taps per pixel and animates on `TIME`.
  - It derives quad corners from `VERTEX_ID`, which may break under the Compatibility renderer.
  - Consolidate the copies before adding a quality toggle.
- Some materials use `resource_local_to_scene`: the shine and outline on pickups, and the 3D text. Goon animations are separate PNG files per frame. Both of these defeat 2D batching.
- Night is gameplay. With `CanvasModulate` at black, visibility comes only from the car's 2D lights:
  - 5 of the headlamps cast shadows.
  - Goons, rocks and walls all carry `LightOccluder2D`.
  - Headlight size is an upgradeable stat (`setHeadlightStrength`), so low-quality modes must keep a headlight cone.
- Collision type checks use `get_class()` strings, and any `CharacterBody2D` is treated as a goon (`overhead_car_body_2d.gd:207-216`). Moving from TileMap to TileMapLayer will silently break wall hits.
- `randi() % n - 1` indexing appears in `Region.gd` and `gameSummary.gd`. It looks wrong, but it works because index -1 wraps.
- `getPowerupFromWeights` mutates the caller's dictionary and sets the coin weight to `luck`.
- HUD label naming is confusing: "Luck" shows `clover` and "Dice" shows `luck`.
- Demo gates live in `main2.gd` (around lines 54, 111-117 and 197-233) and in `versionTracker` ("Demo 0.1"). Remove them for the full release.
- Code style: tabs, camelCase functions and variables (mixed with some snake_case from the original templates), heavy use of the `Root.*` globals, and `$Node` paths. Match the surrounding style. Delete empty `_process` and `_ready` template stubs rather than adding new ones, because 22 scripts already carry them and that costs per-frame callbacks.

## Known critical bugs (full lists in `docs/`)
- GOONCRUSHER cannot be won: the countdown end is commented out in `scene/player/Timer.gd:34-39`. Because of that, SPRINT never unlocks on a fresh save.
- MARATHON's station index runs past the 256-cell map (`tileManager.gd:87`). DEFENSE reads `Root.station` before it is set (`levelRoot.gd:33`).
- Chunk unload leak (`tileManager.gd:144-152`): loaded chunks grow to 100+ on long drives.
- Beating the last level reads out of bounds (`saveManager.gd:139`).
- The V-Sync toggle reads the fullscreen checkbox (`graphics.gd:23`), and graphics settings are never saved.
- A run that ends with 0 stars pays 0 coins (payout is `coin * star`), and the summary screen doesn't say so.
- Goon count is uncapped. Late game spawns 5 goons per second, and goons only despawn when they are more than 8000 px away and come out of idle.
