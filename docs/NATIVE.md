# Native code (GDExtension)

GoonCrusher runs C++ through a GDExtension built with [godot-cpp](https://github.com/godotengine/godot-cpp). GDScript stays the main language; C++ is for hot loops that profile badly in GDScript. **The game needs the library:** every goon scene's root is a `GoonBody`, so without a built DLL no goon loads.

## Layout

| Path | What it is |
|---|---|
| `native/godot-cpp/` | Git submodule, pinned to godot-cpp `10.0.0-stable`. Built against the Godot 4.7 API (`api_version` in the SConstruct). |
| `native/SConstruct` | Builds `libgooncrusher` and installs it into `bin/<platform>/`. |
| `native/src/` | The extension's sources. `register_types.cpp` registers the classes below; `goon_native.*` is `GoonNative`, whose static `version()` the test checks. |
| `native/.gdignore` | Keeps Godot from scanning or exporting the C++ tree. |
| `bin/gooncrusher.gdextension` | Tells Godot which DLL to load (`template_debug` for the editor and debug exports, `template_release` for release exports). Tracked. |
| `bin/windows/*.dll` | Build output. **Gitignored**, so a fresh clone (or a new worktree) must build before the project loads the extension. |

## Building

Prerequisites: Python, SCons (`pip install scons`) and a C++ toolchain. On Windows that is Visual Studio Build Tools 2022 with the "Desktop development with C++" workload; SCons finds MSVC itself, so any shell works.

```
git submodule update --init native/godot-cpp
cd native
scons                           # debug DLL: editor, debug exports, tests
scons target=template_release   # release DLL: release exports
```

Or run `scripts\windows\build_native.bat` from the project root to do both. The first build compiles all of godot-cpp once per target (over 10 minutes each on the dev box with `-j4`); later builds only recompile `src/`. Add `-j4` to use all 4 threads; the batch file does.

The extension is `reloadable`, so the editor picks up a rebuilt debug DLL without restarting. A DLL the editor or a running game holds can still block the install step; close it and rebuild if SCons reports the file is in use.

## Using it from GDScript

Registered classes are global, like built-ins: `GoonNative.version()`, `WorldGrid.new()`. Native methods and properties are bound in camelCase so GDScript reads the same as before (`goon.stateTime`, `grid.terrainAt(p)`).

`tests/game/test_native.gd` fails when the DLL is missing or stale. When GDScript starts relying on new native API, bump `NATIVE_VERSION` in both `native/src/goon_native.cpp` and the test (now `"2"`). The same file holds every native class to the GDScript it replaced: same inputs, same outputs.

## What is native

Each port followed a profile and kept the GDScript rule beside it, which the parity tests compare against.

| Class | Replaces | Used by | Gain (HD 620) |
|---|---|---|---|
| `GoonBody` (`goon_body.*`), a `CharacterBody2D` | Walker's per-tick fields and the helpers the verbs call every tick: `chase`, `advance` (the LOD check, `move_and_slide` and its contact scan, or the off-screen grid slide), `faceTo`, `play`, `walkAnim`, `setState`, `speedNow`, `distTo`, `lockOn`, `predict`, `touchedByCar`; the tick's state clock, staggered water check, cooldowns and `carSpin` (`beginTick`, `tickTimers`) | `Enemy extends GoonBody`, `Walker extends Enemy`; `walker.tscn`'s root is a `GoonBody` | goon script 62 → 30 µs per goon per tick |
| `WorldGrid` (`world_grid.*`), a `RefCounted` | `WorldMap`'s terrain queries (`terrainAt`, `lethalAt`, `blockedAt`, `spawnableAt`, `wallAt`) and WorldHooks' grid walks (`slideStep`, `nearLethal`, `lethalAhead`, `lineClear`, `bounce`) | `WorldMap.grid` mirrors the coarse map and every stored raster; Root's `worldMap` setter makes it `World.grid` and `WorldGrid.getCurrent()`; World, WorldHooks and GoonBody answer from it | `slideStep` 14 → about 1 µs |
| `WorldGenNative` (`world_gen_native.*`), static | `WorldGen.cutCrossings` (with `openCell`) and `barrierExtents`, plus `ihash` | the coarse build, on its worker | crossings 290–750 → 2–5 ms; map build 1.36–2.02 → 0.82–1.29 s |

Rules that came with the moves:
- **The GDScript stays.** `WorldMap.terrainAt` and friends, WorldHooks' bodies, `WorldGen.cutCrossingsGDScript` and `barrierExtentsGDScript` are the reference. Test stand-in maps (any `Root.worldMap` that isn't a `WorldMap`) have no grid, so World and WorldHooks run the GDScript, and `GoonBody` calls back `Walker._worldLethalAt` / `_worldSlideStep`.
- **GoonBody calls GDScript only for rare events:** `_onCarContact(car)` when `advance` bumps the car (it has already done `touchedByCar` and reset `stuckTime`). Drowning stays in GDScript: `beginTick` returns true and `Walker` calls `drown()`.
- **The LOD view is pushed, not read:** `SpawnManager` hands its `physicsView` to `GoonBody.setPhysicsView` every tick (and clears it on exit); `GoonBody.needsFullPhysics(point)` is the native check.
- **Two wall checks:** `World.isWall` and `GoonBody::advance` both treat `StaticBody2D` and `TileMap` colliders as walls. Change both together.
- **Goons move in floating mode** (`Walker._ready`), like the car. They had been in CharacterBody2D's default grounded (platformer) mode.
- **`WorldGrid` is main-thread only** (the AI plans on the main thread too). `WorldGenNative` touches only its arguments, so it runs on the build's worker.

## Adding a class

1. Add `src/<name>.h/.cpp` with `GDCLASS(Name, Base)` and a `_bind_methods()` that binds what GDScript calls (`ClassDB::bind_method`, `bind_static_method`, `ADD_PROPERTY`, `ADD_SIGNAL`).
2. Register it in `initialize_gooncrusher_module` with `GDREGISTER_CLASS(Name)`.
3. Rebuild both targets.

Keep the game's rules intact when moving code: physics stays per tick, and the car's `integrate()` must stay pure because the AI driver predicts with it (CLAUDE.md).

## What to port next

Port only what a profile points at, and keep a GDScript version until the native one matches it (same seed, same output). Calls across the GDScript/C++ boundary cost about as much as a GDScript call, so batch the work: one call does a whole job (a pass, a helper with its engine calls), never one per cell.

**The goon tick, profiled** (S4 night crowd on Low, 100–200 goons, `Time.get_ticks_usec` counters in `Walker`, 2026-10-07). Before: 62 µs per goon per tick: `move_and_slide` about 15–20 µs per on-screen call, `slideStep` 14 µs, the water check 17 µs per check, `faceTo` 7, the LOD check 3, `walkAnim` 3, the lure check 2.6, and the rest the verbs' own logic and their calls into Walker. After: 30 µs, of which `verb.tick` (verb logic plus `move_and_slide`) is 23. Goon script is now under a quarter of `physics_ms`; most of the rest is the physics server and other nodes.

**The coarse build, profiled** (seed 1337, idle machine): after the crossings port, `sample` (every cell through `WorldField.sample`) 280–620 ms, the district steps 220–280 ms, `shareCaps` 65–250 ms, `connectIslands` 75–100 ms.

Candidates, in order:
1. **`WorldField.sample`** (the coarse `sample` step, and the fine raster's inner loop: 6–9 ms per chunk idle, 16–25 ms in a run). The biggest remaining load cost, but its float math must match bit for bit or the rasters drift; port the whole field with a parity test over every grammar.
2. **The rest of the coarse build:** `shareCaps`/`trimWindow`, `components`/`connectIslands`, `markStart`, `buildDistricts`/`districtTable`. Integer grid passes like `cutCrossings`, so they port the same way: arrays in, arrays out.
3. **Verb logic.** A native verb means moving the whole state machine (21 verbs in `goon_verbs.gd`), so do it only if crowds still miss the targets after cheaper changes (e.g. no collision for off-screen goons, which never use it).
4. **`ChunkRecipe`** (7–12 ms per chunk on workers): streaming stays inside its budget, so it isn't urgent.

## Exporting

Godot exports the library named in `bin/gooncrusher.gdextension` for the export's target, so **build `template_release` before a release export** (and `template_debug` for a debug one). godot-cpp links the C++ runtime statically on Windows, so no MSVC redistributable is needed.
