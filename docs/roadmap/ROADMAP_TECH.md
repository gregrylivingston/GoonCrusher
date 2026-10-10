# Roadmap: AI driver, performance, native code, tools and release

How they work today: `docs/AI_DRIVER.md`, `docs/PERFORMANCE.md`, `docs/NATIVE.md`, `docs/PROMO.md`. Tags and effort: `ROADMAP.md`.

## Planned

### Release build
- **[0.3 need] The 0.3 demo build:** `Root.GAME_VERSION`, `Root.IS_DEMO` on, the native `template_release` DLL built, the 4.7.2 export templates installed, a clean export run on a second machine. S.
- **[0.3 need] Old saves:** a 0.1 demo save is backed up and replaced (`SaveManager.FIRST_KEPT_VERSION`). Try it with a real 0.1 save, and say so in the store update. S.
- **[0.3 want] `settings` in the save** is legacy (read once by `Settings.import_legacy_volume()`): delete it one release after launch.

### Performance
- **[0.3 need] Measure on the low-end target (HD 620):** a six-car race, and a night crowd (S4) on Prairie and Moose Woods at Low, on an idle machine. Nothing measured so far covers the road atlas, the rivals or the new HUD. S.
- **[0.3 want] Fix what that finds.** In order: no collision for off-screen goons, a lower goon cap on Low and Potato, a cheaper driving profile for rivals. Night crowds are known to miss the Low targets above about 160 goons, mostly in the physics server. M.
- **[later] Measure** Crush and Driving Effects at Full in a crowd (drop the Low preset to Minimal if they cost frames), 4K, V-Sync on, The Sprawl and The Works.
- **[later] Level load:** the world build is mostly GDScript.

### Native ports (after 0.3; port only what a profile points at)
1. `WorldField.sample`: the biggest remaining load cost. Its float math must match bit for bit.
2. The rest of the coarse build (`shareCaps`, `connectIslands`, `markStart`, `buildDistricts`).
3. Verb logic (`goon_verbs.gd`): try no collision for off-screen goons first.
4. `ChunkRecipe`: inside its budget, not urgent.

### AI driver
Every personality, skill and brief number is a first guess.
- **[0.3 want] Weak modes:** Cone Course (it clips cones it didn't predict), Demolition Derby (it doesn't guard its flanks), Keep the Cup (the chaser doesn't cut the holder off). These are the demo's rivals. M.
- **[later] Defense:** guard lanes, park to refuel; its lot-approach graph still assumes a walled station lot.
- **[later] Pickups near deep water** are skipped (`waterTargetPx`): allow them at low approach speed. S.
- **[later] Tune by tournament,** per car and mode family, on more than one seed and on levels with different ground.
- **[later] Rivals:** place awareness in races.
- **[later] Not predicted:** the drift boost a release fires, shift slop. A pocket of walls can cost 10 to 20 s.
- **[later] Housekeeping:** routes weighted per car; split `ai_driver.gd`; move the pattern drivers in `bench.gd` and `promo/capture/session.gd` onto `CarDriver`; scenario tests on small hand-built maps.

### Replays and the capture kit
- **[0.3 want] Gameplay timers off the wall clock.** `GoonVerbs.now()` and the lure timers (`Pickups.lureFor`, `addLure`) read `Time.get_ticks_msec()`, so stuns, daze, slime and lures can differ between a taped drive and its replay. Count physics ticks instead. S to M.
- **[0.3 want] Check the Steam capsule sizes** in `capture.py`'s `PROFILES` and the safe zones in `stage.gd` before a final export: they are from memory. S.
- **[later]** The `.avi` that carries sound stops at 4 GB (about 5 minutes); `"layer": "hud"` leaves the odd world-space marker; a prebuilt native pair per commit for filmers is not automated.

### Tests
- **[later]** A script error inside a test may count as a pass: check the runner.
- **[later]** Unconditional prints in run code (`WORLD_BUILD`, `RUN_GOAL`, calibration): gate them behind debug or a flag.

## Suggestions
- A photo mode built on the capture kit's clean feed.
- `Radio`'s multi-station machinery (`order`, per-station bags, the `segment_chance` fallback) could be simplified now that one station is the plan; the fallback for a removed station must stay for old settings files.
