# Native code (GDExtension)

GoonCrusher runs C++ through a GDExtension built with godot-cpp. GDScript stays the main language; C++ is for hot loops that profile badly in GDScript. **The game needs the library:** every goon scene's root is a `GoonBody`, so without a built DLL no goon loads.

## Layout

| Path | What it is |
|---|---|
| `native/godot-cpp/` | Git submodule, pinned to godot-cpp `10.0.0-stable`, built against the Godot 4.7 API (`api_version` in the SConstruct) |
| `native/SConstruct`, `native/src/` | The build and the sources; `register_types.cpp` registers the classes |
| `bin/gooncrusher.gdextension` | Which DLL Godot loads: `template_debug` for the editor and debug exports, `template_release` for release exports. Tracked |
| `bin/windows/*.dll` | Build output. **Gitignored: a fresh clone or a new worktree must build before the project loads** |

## Building

Needs Python, SCons (`pip install scons`) and Visual Studio Build Tools 2022 with "Desktop development with C++". SCons finds MSVC itself.

```
scripts\windows\build_native.bat      # from the project root: the submodule, then debug and release
```

or by hand: `git submodule update --init native/godot-cpp`, then in `native/` run `scons -j4` (debug) and `scons -j4 target=template_release`. The first build compiles all of godot-cpp once per target (over 10 minutes each on the dev box); later builds only recompile `src/`.

If SCons reports the DLL is in use, close the editor or the game and rebuild.

**Exporting:** Godot ships the DLL that matches the export's target, so build `template_release` before a release export. The C++ runtime is linked statically; no redistributable is needed.

## What is native

| Class | Does | Used by |
|---|---|---|
| `GoonBody` (`goon_body.*`), a `CharacterBody2D` | The goon tick's fields and the movement helpers the verbs call every tick (`chase`, `advance`, `faceTo`, `walkAnim`, `beginTick`, `tickTimers`...) | `Enemy extends GoonBody`, `Walker extends Enemy` |
| `WorldGrid` (`world_grid.*`), a `RefCounted` | Terrain queries (`terrainAt`, `lethalAt`, `blockedAt`...) and WorldHooks' grid walks (`slideStep`, `nearLethal`, `lethalAhead`, `lineClear`, `bounce`) | `WorldMap.grid` mirrors the coarse map and every stored raster; `World`, `WorldHooks` and `GoonBody` answer from the current one (`WorldGrid.getCurrent()`) |
| `WorldGenNative` (`world_gen_native.*`), static | `cutCrossings`, `barrierExtents`, `ihash` | the coarse map build, on its worker |

Registered classes are global, like built-ins, and bound in camelCase so GDScript reads as before.

## Rules

- **The GDScript version stays, and parity is tested.** `WorldMap.terrainAt` and friends, WorldHooks' bodies, `WorldGen.cutCrossingsGDScript` and `barrierExtentsGDScript` are the reference; `test_native.gd` holds each native class to them (same inputs, same outputs). **A change to a rule goes in both.**
- **Maps without a grid run the GDScript.** Test stand-in maps (any `Root.worldMap` that isn't a `WorldMap`) have no `WorldGrid`, so `World` and `WorldHooks` use their own bodies and `GoonBody` calls back `Walker._worldLethalAt` / `_worldSlideStep`.
- **Two wall checks:** `World.isWall` and `GoonBody::advance` both treat `StaticBody2D` and `TileMap` colliders as walls. Change both together.
- **Bump the version when GDScript relies on new native API:** `NATIVE_VERSION` in `native/src/goon_native.cpp` (`GoonNative.version()`) and in `test_native.gd`, so a stale DLL fails the test instead of misbehaving.
- **`GoonBody` calls GDScript only for rare events:** `_onCarContact(car)` when `advance` bumps the car. Drowning stays in GDScript (`beginTick` returns true, `Walker` calls `drown()`).
- **The LOD view is pushed, not read:** `SpawnManager` calls `GoonBody.setPhysicsView` every tick.
- **Threads:** `WorldGrid` is main-thread only. `WorldGenNative` touches only its arguments, so it may run on the build's worker.
- **Keep the game's rules when moving code:** physics stays per tick, goons move in floating mode, and the car's `integrate()` stays pure and in GDScript's reach, because the AI driver predicts with it.

## Adding a class

1. Add `src/<name>.h/.cpp` with `GDCLASS(Name, Base)` and a `_bind_methods()` that binds what GDScript calls, in camelCase.
2. Register it in `register_types.cpp` with `GDREGISTER_CLASS(Name)`.
3. Keep the GDScript it replaces, and add a parity test to `tests/game/test_native.gd`.
4. Bump `NATIVE_VERSION` in both places and rebuild both targets.

## What to port next

Port only what a profile points at. Calls across the GDScript/C++ boundary cost about as much as a GDScript call, so one call must do a whole job (a pass, a helper with its engine calls), never one per cell.

Candidates, in order:
1. **`WorldField.sample`:** the coarse build's sample step and the fine raster's inner loop; the biggest remaining load cost. Its float math must match bit for bit or the rasters drift.
2. **The rest of the coarse build** (`shareCaps`, `connectIslands`, `markStart`, `buildDistricts`): integer grid passes like `cutCrossings`, arrays in, arrays out.
3. **Verb logic** (`scene/enemy/goon_verbs.gd`): the whole state machine would move, and most of a crowd's physics time is now the physics server. Try no collision for off-screen goons first.
4. **`ChunkRecipe`:** runs on workers inside its budget, so it isn't urgent.
