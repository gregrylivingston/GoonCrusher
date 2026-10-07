# Native code (GDExtension)

GoonCrusher can run C++ through a GDExtension built with [godot-cpp](https://github.com/godotengine/godot-cpp). GDScript stays the main language; C++ is for hot loops that profile badly in GDScript.

## Layout

| Path | What it is |
|---|---|
| `native/godot-cpp/` | Git submodule, pinned to godot-cpp `10.0.0-stable`. Built against the Godot 4.7 API (`api_version` in the SConstruct). |
| `native/SConstruct` | Builds `libgooncrusher` and installs it into `bin/<platform>/`. |
| `native/src/` | The extension's sources. `register_types.cpp` registers classes; `goon_native.*` is `GoonNative`, a placeholder with a static `version()`. |
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

Or run `scripts\windows\build_native.bat` from the project root to do both. The first build compiles all of godot-cpp (several minutes on the dev box); later builds only recompile `src/`. Add `-j4` to use all 4 threads.

The extension is `reloadable`, so the editor picks up a rebuilt debug DLL without restarting. A DLL the editor or a running game holds can still block the install step; close it and rebuild if SCons reports the file is in use.

## Using it from GDScript

Registered classes are global, like built-ins: `GoonNative.version()`. Code that must also run when the DLL is missing can check `ClassDB.class_exists("GoonNative")` first; code that can't should just use the class, and the build becomes a requirement.

`tests/game/test_native.gd` fails when the DLL is missing or stale. When GDScript starts relying on new native API, bump `NATIVE_VERSION` in both `native/src/goon_native.cpp` and the test.

## Adding a class

1. Add `src/<name>.h/.cpp` with `GDCLASS(Name, Base)` and a `_bind_methods()` that binds what GDScript calls (`ClassDB::bind_method`, `bind_static_method`, `ADD_PROPERTY`, `ADD_SIGNAL`).
2. Register it in `initialize_gooncrusher_module` with `GDREGISTER_CLASS(Name)`.
3. Rebuild both targets.

Keep the game's rules intact when moving code: physics stays per tick, and the car's `integrate()` must stay pure because the AI driver predicts with it (CLAUDE.md).

## Exporting

Godot exports the library named in `bin/gooncrusher.gdextension` for the export's target, so **build `template_release` before a release export** (and `template_debug` for a debug one). godot-cpp links the C++ runtime statically on Windows, so no MSVC redistributable is needed.
