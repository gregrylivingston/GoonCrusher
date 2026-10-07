# GoonCrusher: Gameplay Suggestions

This is a list of suggestions to discuss, not a spec. The author has their own gameplay ideas and runs gameplay as a separate project. Codebase context is in `../CLAUDE.md`, and settings and performance are in `PERFORMANCE.md`.

**Done:** Tier 0, the shared prerequisites, and T1-1 to T1-4 (all five modes are playable). The world revamp (branch `world-revamp`, docs/WORLD.md) absorbed package 4 (T1-5, T1-6, T1-8, T2-9), drowning credit, most of T2-10, the region side of T1-7 and Tier 3's shallows and bridges. **Open:** the rest, regrouped below into **work packages**: small sets of related items, listed in the order to do them, plus the items the revamp surfaced ("Open items from the world revamp").

References use file and function names rather than line numbers, because the goon overhaul (commit `e52c30b`) moved most of the code. Effort: **S** is under a day, **M** is 1–3 days, **L** is a week or more.

---

## Done

### Tier 0
All ten items are in commit `b60aba9`, together with the perf/settings commits on `perf-settings`. The test files (`tests/game/test_progression.gd`, `test_run_flow.gd`, `test_upgrades.gd`) refer to these IDs.

| ID | What changed |
|---|---|
| T0-1 | `levels` is saved. `SaveManager.migrate()` merges old saves with the defaults, including every mode's `gamemodeBeat` key. Beating the last level no longer crashes. The demo and the full game share the save. |
| T0-2 | A run ends exactly once (`Level.hasEnded`). Every end goes through `endLevel`, including Abandon. |
| T0-3 | Countdown counts down from the level's seconds and is won at 0. The clock clamps at 0:00. |
| T0-4 | `tileManager.placeObjective` puts stations on reachable land and pins them (since the world revamp, `WorldGen.findStationChunk`: in the start's component, with a clear lot). `world_ready` signals when `Root.station` is valid. Chunks unload by distance. |
| T0-5 | Sprint places its station by distance (at most 32,000 px at a reference 450 px/s) and derives its clock from it. Slack goes from 1.5 on Easy to 1.1 on Northern Wastes. Running out of time ends the run (NOTIME). |
| T0-6 | Mode menu restored, with a per-level unlock chain (`Root.isModeUnlocked`): Countdown → Sprint → Goonpocalypse. Every demo gate reads `Root.IS_DEMO`. |
| T0-7 | Marathon and Defense no longer crash. (Now finished: T1-3, T1-4.) |
| T0-8 | Oil saves fuel (`fuelBurn`). Dice raises prize weights without mutating the drop table. Traction feeds grip (`gripFor`). Armor applies once. Upgrades cap at 20 per stat (shown as MAX) and in-run stats at 150. Clover and Dice are labelled correctly. The goon drop table's coin weight dropped to 30. |
| T0-9 | Payout is coins × max(1, stars), shown on the summary and credited there. Abandon pays like a death. Crush awards reached while paused are granted on unpause. The summary needs a fresh press. |
| T0-10 | Start pauses on a controller. |

### Shared prerequisites
`tests/game/test_modes.gd` covers all three.

| Item | What changed |
|---|---|
| Goon physics layer | Goons are on layer 3 "Goon" (`collision_layer = 4`) with mask 1+2 (world, car body), so they no longer collide with each other. The car's mask is 1+3 (`collision_mask = 5`) so it still crushes them, and the water `Area2D` (`landscapeMap_water.tscn`) masked 1+3 so it still drowned both (the world revamp removed it: deep water is a grid check now, `World.lethalAt`). Pickups and the station driveway (mask 1) no longer test goons at all. `Walker.savedLayers` defaults to the new pair, and `setSolid` restores it. Layer 2 is renamed "CarBody" (`carBodyArea`). Not benchmarked yet: re-run S4 (package 1) to see what it saved against Low's 55.0 / 37.9. |
| `meta` in the save | `PlayerData.meta` holds the sections `records`, `hints`, `lifetime`, `medals` and `achievements`. `SAVE_VERSION` is 4, `migrate()` adds any missing section and keeps existing contents, and `reset_save()` now migrates the template too. Each car's `records` gained `score`. |
| Explosion pooling | `ExplosionPool` (`scene/fx/explosion_pool.gd`) lives on the level, which exposes `Level.explode(worldPosition)`. It keeps at most 16 explosions and restarts the oldest when they are all burning. The car's wreck uses it. `goon_fx.gd`'s `blast()` still instantiates its own explosions and should switch to `Root.levelRoot.explode(pos)`; that file belongs to the goon work. |

### T1-1 to T1-4
| ID | What changed | Numbers to check in the playtest (package 1) |
|---|---|---|
| T1-1 Run log | Debug builds append a row per run to `user://runlog.csv` (`scripts/debug/run_log.gd`, `RunLog`, called from `gameSummary.buildGameSummary`). Columns: date, version, driver (player or ai), car, upgrade total, level, mode, seconds, coins, stars, payout, crushes, giants, regions visited, end reason, gems, slot machines, top speed, end fuel and health, plus score, leg (the Marathon leg being driven) and barrier for the new modes. A file with other columns is moved aside. The car counts `giantsCrushed`. | — |
| T1-2 Goonpocalypse | Spawning escalates 2× faster (`SpawnManager.POCALYPSE_ESCALATION`) down to a 0.6 s floor (`POCALYPSE_SPAWN_FLOOR`; other modes keep 1.0 s). Region waves keep paying stars with no cap (`Region.waveCap()`). Score = crushes + 5 × giants + seconds / 2 (`Level.pocalypseScore`). Surviving 2× the level's seconds (`POCALYPSE_TARGET`) beats the mode (its star), even if the run then ends in a wreck or Abandon. The ticket stamps it SURVIVED. Best time and best score are kept per level and car in `meta.records.goonpocalypse` and per car in `records.time`/`records.score` (`SaveManager.recordGoonpocalypse`), shown on the ticket (NEW BEST), the driver's records and the mode card. The HUD shows the score and the time to the star. | Escalation 2×, floor 0.6 s, target 2×. Crowds reach the 250 cap much sooner, so re-run S4. |
| T1-3 Marathon | A relay of `MARATHON_LEGS` = 5 Sprint-length legs. The first is placed as in Sprint. Each station but the last adds that leg's Sprint clock, fills the tank, restores 35 health, repairs every system and opens a free slot machine (`Level.stationReached`). The next station is placed (now with `WorldGen.findStationChunk`) a Sprint distance away, within 60° of the last leg's heading (`tileManager.placeNextStation`). The reached station is retired and unpinned (`unpinChunk`), so it unloads once the car leaves. A car coasting in on an empty tank is saved: `outOfFuel` checks the tank again before ending the run. The last station gives SUCCESS. The HUD shows "STATION 2 OF 5". The AI driver rebuilds its station graph when the station changes. | Legs 5, heal 35, the 60° turn. |
| T1-4 Defense | The clock counts down from the level's seconds and is won at 0 (`Level.timeUpCondition`). The station's walls are a barrier with 1000 health (`station.gd`: `startBarrier`, `damage`, `nearestWallPoint`); the walls redden as it drops, and at 0 the run ends with the new `BASEDESTROYED` ("OVERRUN"). Four spawners ring the station at 4000 px. Goons march on the nearest wall point and hit it once per windup + attack + at least 2 s of rest (`Walker.siege`), unless the car comes within 650 px, when their verb hunts the car as usual. Burrowers, flyers and Scrap Gang vehicles always hunt the car. Goons near the station are kept by the despawn sweep. The car starts outside the lot's gap; parked in the driveway it refuels at 4 per second, and entering repairs it. The HUD shows a barrier bar. | Barrier 1000, rest 2 s, ring 4000, 4 spawners, aggro 650, refuel 4/s. The first AI run with a 300 barrier and 0.6 s rest lost it in 45 s. |

`Root.MODE_AVAILABLE` is true for every mode. The demo still offers only Countdown and Sprint.

### World revamp
Eight new levels with their own generator grammars, barriers and surfaces replaced the old maps (docs/WORLD.md). These suggestions were absorbed or changed by it:

| Item | What the revamp did | Still open |
|---|---|---|
| T1-5 Sand traps, stacking friction | Ground handling comes from one terrain table (`World.TERRAIN`: friction, grip, brake, push) read in `integrate()` at the car's position, with an armor off-road rule. `OverheadCarArea2D` is inert, so nothing adds or subtracts friction any more. Sand is a real surface (dunes on Red Canyon, verges on Route Nowhere). | Goons don't slow on soft ground. |
| T1-6 Hills | Walls are terrain now: canyon walls and mesas, mountain ranges, pit and fort rings, rock outcrops, buildings, scrap mountains. A crossing at least every 4 coarse cells, a start bubble, share caps per 3 × 3 chunks and connectivity repair keep routes open; stations are always reachable. | |
| T1-8 Per-level terrain | Each level is a `LevelDef` (`world/levels/<id>.tres`) with a grammar, base and accent surfaces, dressing, pickups, a faction band and a roster. The start is the level's main ground. | `signatureGoon` wasn't added; rosters do that job. |
| T2-9 Surface hazards | ICE, OIL, MUDPIT, DEEPSNOW, SHALLOWS and CONVEYOR (a 250 px/s push) are terrains with their own grip and brake. | Boost chevrons. |
| T2-3 Drowning credit | Goons drown by grid check; a drowning within 3 s of the car's touch counts as a crush ("SPLASH") and in the Goonopedia. Blasted and shell-killed goons count in the Goonopedia too. | |
| T2-10 Destructibles, nests, landmarks (dropped from this file in the reorganization) | Hedges, fences, hay bales, crates and barricades smash at speed (coin spills); barrels and tanks explode and chain; wrecks are the player's own car models; every district has a faction landmark with a beacon. Snappers spawn by logs and the Rat Pack from manholes. | Goon nests; single-use gas pumps. |
| T1-7 Region chip | Regions are the map's districts (about 40,000 px, bounded by barriers): faction, goons, name and tint are decided when the map is built, the wave count carries over between districts of the same faction, and the ground shows a faint district tint. | `giantism` is still shown but unused (package 3). |
| Tier 3: water shallows and bridges | Deep water is lethal (two ticks), ringed by a 256 px shallows band; creeks have fords, the bayou has boardwalks, the city's canals bridges. | |
| Tier 3: daily seeded run | The map, districts, stations, lanes, chunk contents and spawner offsets come from the world seed (`WorldGen.ihash`). | Which goon spawns, giants and drops still use the global RNG. |

---

## Work packages, in order

Each package groups items that touch the same code or need each other, so they can be done and playtested together.

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 1 | Playtest and tune | Tier 0 playtest, the new modes' numbers | S + play time | — |
| 2 | Crush feel | T1-12, T2-6 (drowning credit: done in the world revamp) | M | — |
| 3 | Regions, waves and giants | T1-7 (giantism), T2-4, T2-8, T2-11 | M–L | 1 |
| 4 | Terrain with identity | **Done** in the world revamp (docs/WORLD.md) | — | — |
| 5 | Slot machine and gems | T1-9, T1-10 | M | — |
| 6 | Economy | T1-11, T2-13 | M | 1 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 6 for T2-15 |
| 8 | Sound | T1-13, T1-14 | S + assets | — |
| 9 | Goon depth | T2-1, T2-2, T2-3, T2-5, T2-7 | M | 2 |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd and night benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3 and 9. They add load, and S4's 1% low is the tightest target.

### Package 1: Playtest and tune
Everything after this assumes numbers that have been played.

- **Run log:** play about 30 runs across 3 cars and all five modes, then read `user://runlog.csv`. Filter out `driver = ai` rows.
- **AI playtests:** `--playtest --mode=marathon,defense,goonpocalypse` gives fast first numbers (CLAUDE.md, `docs/AI_DRIVER.md`). The AI has no Defense strategy beyond patrolling near the station.
- **Tier 0 numbers:** the Sprint distances and clocks; the drop mix; fuel pressure (the stock sedan gets about 87 s of full throttle per tank); the handling and wall damage of all 9 cars (armored cars now take up to 1.7× more wall damage, because armor used to count twice).
- **New mode numbers:** the right-hand column of the T1-1 to T1-4 table.
- **Then:** re-run S3 and S4.

### Package 2: Crush feel
All three items change what happens at the moment of a crush, in the car's collision loop and `Walker.destroy`.

**T1-12. Crush feel, and the giant scale fix.**
- **Already done:** death sounds go through the limiter; Reduce Motion, Reduce Flashing, Car Shake and crush vibration exist; contact damage counts once per goon per 30 ticks (`goonBumpReady`); a crush never wears a system.
- **Problem:**
  - A goon contact still calls `damage(5)` before the speed check, so a successful crush costs a little health.
  - Giants set `scale = Vector2(1.6, 1.6)` in `Walker._ready` instead of multiplying the scene's scale.
  - There is no camera shake, hit-stop or corpse fling.
- **Proposal:** damage only on non-crush contact; multiply the giant scale; trauma-based camera shake (respecting Reduce Motion) and 30–50 ms hit-stop on giant crushes. GoonFx already has decals and bits; a "Splats" option under Graphics could cap them.
- **Effort:** S–M. **Files:** `overhead_car_body_2d.gd`, `walker.gd`.

**T2-6. Combos and style bonuses:** drift crush, splash (several goons in one pass), giant slayer, plus a `bestCombo` record (a new car record key; `migrate()` adds it). The skid check is in the car's tire-mark code. **Effort:** S–M.

**Drowning credit (from T2-3):** **Done** in the world revamp: a goon that drowns within 3 s of the car touching it is credited through `SpawnManager.creditCrush` with a "SPLASH" label (`WorldHooks.drownCredited`).

### Package 3: Regions, waves and giants
These all change what a region asks of the player over time. Do them together so the region chip, spawn mix and wave timer stay consistent.

**T1-7. Make the region chip tell the truth.**
- **Already done:** the wave ring fills per wave and handles the last wave (`hud_region.gd`); `pickGoonId` reveals goons 2 and 3 by the region's wave; Goonpocalypse has no wave cap. Since the world revamp, regions are the map's districts, with faction, goons, name, tint and giantism decided per district when the map is built (`WorldMap.setupDistricts`, docs/WORLD.md).
- **Problem:** `giantism` is shown as a percentage but used nowhere, and `pickGoonId` still adds global time (`gameTimeProgress / 12`) to the wave.
- **Proposal:** effective giant odds = `giantOdds + giantism / 5`. Decide whether global time should still push the mix.
- **Effort:** S. **Files:** `spawnManager.gd`, `Region.gd`, `hud_region.gd`.

**T2-4. Giant overhaul and Warlord bosses.** Giants get hp 3 (a crush only wounds them twice). A Warlord appears at wave 4 with a health bar, minions and charges, and the station indicator points at it. The `Boss` verb (Foreman) and the NewWave animation in `playerRoot.tscn` are the starting points. **Effort:** M.

**T2-8. Region mutators and optional objectives.** Districts now have a faction landmark near their middle, a natural anchor for an objective. Mutators such as "fog", "giants only" or "double coins", and objectives such as "crush 20 Rat Pack". **Effort:** M.

**T2-11. Night as a real phase.** About 150 s of day and 90 s of night, a night spawn table, ×1.5 coins at night. Day and night alternate on the run clock every 60 s (`Timer.gd` `daylength`). Goon eyes already glow and night goons already wake (`SpawnManager.nightSweep`). **Effort:** S.

### Package 4: Terrain with identity
**Done** in the world revamp; see "World revamp" under Done and docs/WORLD.md. The old proposals (sand-trap areas, a hills mask in `landscapeGenerator.gd`, per-level elevation biases) no longer apply: the landscape generator, the terrain TileMaps and the old level scenes are gone.

### Package 5: Slot machine and gems
Gems pay for rerolls, so both items decide what a gem is worth.

**T1-9. Slot machine: matches, jackpots, and luck that matters.** **Done** with the pickup expansion (docs/PICKUPS.md): the reels show pickups by rarity tier (`SlotSymbols`), Dice and a run-coin bet tilt them rarer, a pair pays twice and a triple five times, three stars are the jackpot (+1 star and a purse rain), and Dice gives a `luck / 500` chance that reel 3 copies reel 2. The award icon's `type` is untyped now, which fixes the lotto String bug.

**T1-10. Give banked gems a use.**
- **Problem:** `playerData.gem` is only displayed. In a run, gems only pay for rerolls.
- **Done:** the run setup's Gadget button buys a starting gadget for 1 to 4 banked gems (`Pickups.LOADOUT`), and The Deal deals a new hand for a gem.
- **Proposal, cheapest first:** a gem pouch (carry up to 3 banked gems into a run); Second Wind (once per run, pay gems to continue with 50 health and 50 fuel; it must hook in before `endLevel`, because `hasEnded` makes every end final; not in Goonpocalypse); upgrade respec; paint jobs.
- **Effort:** M.

### Package 6: Economy
Needs package 1's data.

**T1-11. Per-car upgrade curves and visible prices.**
- **Already done:** a cap of 20 levels with a MAX state.
- **Problem:** every car uses `int((lvl+1)^1.6 × 15)` (`SaveManager.requestStatCost`), so maxing all 8 stats costs about 119k coins per car. A flat +1 per level raises the sedan's thrust by 118% but the racer's by only 31%.
- **Proposal:** a `stat_max` per stat in each `<car>_info.tres`, with level n moving the stat toward it; tier-based cost bases; the garage shows the price of every upgrade, including unaffordable ones; re-fit car prices (`playerData.gd`) with run-log data.
- **Effort:** M.

**T2-13. Driver perks and affinity.** Hooks exist: `awardBase` (`playerRoot.gd`) and the purse's `MIN_COINS`/`MAX_COINS`. **Effort:** M–L.

### Package 7: Goals and teaching
All of these store state in `PlayerData.meta`, which now exists.

**T1-15. First-run hints.** No hint system exists yet. Nothing teaches that crushing needs more than 100 px/s (about 10 MPH; some goons need more), how the slot controls work (Accelerate stops a reel, releasing Brake rerolls), or that stars come from crush goals and 60 s region waves. Since the world revamp, two more are wanted: deep water wrecks the car in two ticks (the shallows ring is the only warning), and fences, hedges, hay bales, crates and barricades smash at speed while rocks and walls don't. One-time toasts for the first nearby goon, the first slow contact, the first slot machine, the first star, the first night, the first goon that resists, the first deep water and the first breakable. Flags in `meta.hints`. **Effort:** S–M.

**T2-12. Medals, per-level records and a "Next up" panel.** Per-level records now exist for Goonpocalypse (`meta.records`); extend the same shape to other modes. Medals in `meta.medals`. The Goonopedia already covers the codex. **Effort:** M.

**T1-16. Steam achievements and lifetime stats.** GodotSteam loads and `steamInitEx` works, but no game code calls Steam. A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`; achievements mirrored into `meta.achievements` so non-Steam builds show them too; lifetime totals in `meta.lifetime` (goons already carry an id, `goonId`, and `goonsCrushed` counts them); about 25 achievements on the full game's app ID; `steam_appid.txt` only in dev builds. **Effort:** M.

**T2-14. Rotating contracts:** 3 date-seeded goals, reroll for a gem. **Effort:** M. **Needs:** T1-16.

**T2-15. Medal-gated top cars.** **Effort:** S–M. **Needs:** T2-12, T1-11.

### Package 8: Sound
Independent of the rest; mostly asset work.

**T1-13. A voice director.** Joy lines fire only on stat and gem rewards, and purse and powerup lines share one pool. Warnings re-arm on fixed timers. Giants, awards, records, wins, new regions and nightfall have no lines. The sedan's intro list includes warning clips. Proposal: a `VoiceDirector` with priorities (warning > win > record > jackpot > giant > award > region), a cooldown of about 5 s and no repeats within the last 3 lines; reuse existing clips; subtitles. **Effort:** S.

**T1-14. More than one music track.** One track loops everywhere; the night playlist is commented out (`Audio.gd` `loadNextNightSong`). Menu, day and night sets switched in `Level.setNighttime`; duck under voice lines; `winner_*` and `bonus_*` as stingers; budget 6–10 tracks. **Effort:** S in code, plus licensing.

### Package 9: Goon depth
The goon overhaul (docs/GOONS.md) did most of what Tier 2 asked for. What's left:

| ID | Status |
|---|---|
| T2-1 Goon behaviour API | **Mostly done.** Each goon has `crush`, `front`, `dmg` and other tuning in `Goons.DATA`, and verbs with hooks (`allowCrush`, `onResist`, `beforeCrush`, `onDeath`). Missing: `hp` (needed by T2-4) and a speed-label tint when the car is too slow for a nearby heavy goon. |
| T2-2 Movement archetypes | **Done:** chargers, dodgers and shielded goons are verbs. |
| T2-3 On-death effects | **Partly done:** Splitters burst into Goonlings and Doomcarts explode; drowning credit came with the world revamp. Open: goons that leave fire behind or reassemble (the old skeleton and firekin ideas, now for the new roster). |
| T2-5 Swarms and thrown attacks | **Partly done:** Rat Pack and herds; lobbers and shooters (GoonFx projectiles, pooled). Open: true swarms. |
| T2-7 Timed powerups | **Done**, and far beyond: 78 pickups in nine kinds and five rarities, with timed power-ups, held gadgets (Use), casino and skill games, world props, events, supply drops and mode specials (docs/PICKUPS.md). Open: tuning them all (package 1). |

### Package 10: Post-launch (Tier 3)

| Item | Notes |
|---|---|
| Steam leaderboards (Goonpocalypse score, Sprint time) | The score and best times now exist (T1-2). Needs T1-16. |
| Daily seeded run | Mostly enabled by the world revamp: the map, districts (names, goons, tints), stations, Sprint and Marathon offsets, chunk contents and spawner offsets all come from the world seed (`WorldGen.ihash`, docs/WORLD.md). Still on the global RNG: which goon spawns, giants and drops. |
| "Heat" modifiers after level 8 | Crowds are capped at 250 |
| Ramps and airtime crushes | Collision-mask work around `setForwardCollisionMode` |
| Water shallows and bridges | **Done** in the world revamp (fords, boardwalks, canal bridges, a 256 px shallows band) |
| Interactive music layers; new voice lines (about 7 × 9 drivers) | Mostly asset cost |
| Training Grounds; custom seed entry | `TileManager.worldSeed` takes a seed (the harnesses set it), but there's no UI |

### Open items from the world revamp
The revamp's playtests and reviews surfaced these. Each names the package it belongs with; docs/WORLD.md ("Known issues") has the technical side.

| Item | Problem | Proposal | Effort | Package |
|---|---|---|---|---|
| Late-level economy and escalation | On the late levels (spawn timer down to 2.6 s, giant odds up to 30) long survival runs reach 2,000+ crushes and six-figure payouts under the coins × stars multiplier. | Re-fit `escalationSpeed`, the Goonpocalypse escalation and the region-wave stars against run-log data; decide open question 2 (payout model) first. | M | 6 (needs 1) |
| Bumper-only car collision | The car's physics shape is two polygons, the front bumper and the rear (`CollisionShape2D`, `CollisionShape2D_rear`); the middle has none. Against prop and wall corners it can wedge its middle and stall. `--trace` shows it as `overlap=` on `PLAYTEST_STUCK`. | A middle polygon or side capsule on layer 1 only, checking that crushing (bumper) and goon contact (`carBodyArea`) are unchanged. | S–M | 1 |
| AI Defense strategy | The driver only patrols 600–1800 px from the station; it doesn't weigh goons at the walls or park to refuel, so it loses barriers it could hold. | Rank goons by distance to the walls and by `siege` state, guard the lanes, refuel in the driveway when low. | M | 1 |
| Frostbite passes for heavy cars | Heavy cars get stuck in Frostbite Pass's passes (deep snow and ice between the ranges). | Keep deep snow and ice lakes out of passes, widen `passWidth`, or retune DEEPSNOW against the off-road rule; check with the semi and the ambulance. | S | 1 |
| AI skips pickups near water | Pickups within 400 px of deep water are never goals (`waterTargetPx`), so on Snapper Bayou the AI passes fuel by and runs short. | Allow them at low approach speed, or measure the margin along the approach rather than round the pickup. | S | 1 |
| World build speed | All GDScript: the map takes 1.3–2.9 s to build (on a worker, behind the loading) and a chunk recipe about 4–13 ms on average. A C++ `WorldCore` (GDExtension: field sampling, fine rasters, contours) would cut both, but the dev box has no compiler. | Install a toolchain (or build on CI) and port the hot loops; keep the GDScript as the reference the tests compare against. | M–L | — |
| First-run hints | No hint system exists; deep water and breakables are new things to learn. | T1-15, with the two world hints added. | S–M | 7 |
| Highway edges | The asphalt band's edges look blobby: they come from the 128 px raster through the shader's organic blending. | A crisper border for road surfaces (no warp across an asphalt edge), or a verge or kerb line along the road. | S | — |
| Tribe landmark by day | Landmark beacons are additive and unlit, so the Tribe's glowing eyes and torches read in daylight too. | Fade beacons with the level's CanvasModulate (night only), or dim them by day. | S | — |
| Merge with the main tree | `world-revamp` was built in a worktree while other sessions changed the main tree (goons, pickups, UI). The revamp kept its edits to `goons.gd`, `scene/enemy/**`, `scene/pickups/` and `pickups.gd` small for this. | Merge, keep the pickups hooks listed in the revamp spec working, then run the suite and the playtest matrix. | M | first |

---

## Maybe

Ideas the author is on the fence about. Not planned; listed so they aren't lost.

**Curses (Deals & Curses).** These are opt-in risks for bigger rewards, from the pickup plan (October 2026). They were held back because they add ways to lose a run. If they come back, they would be a `K.CURSE` kind in `Pickups.DATA`, and the art already exists in `scripts/art/pickup_icons.js` (`idol`, `glass`, `moon`, `bargain`, `sack`, which the generator skips).
- **Cursed Idol** (Uncommon, 30 s): coins x3 and the drop rate doubles, but goons move 40% faster, and it can't be ended early.
- **Glass Cannon** (Rare, 20 s): crush at any speed, but armour drops to 0 and walls hit twice as hard.
- **Blood Moon** (Rare, 60 s): night falls at once (the level's CanvasModulate), and goons crushed at night pay double.
- **Devil's Bargain** (Epic, at Marathon stations and the Defense lot): trade 30 hull or half your fuel for a random Epic.
- **Gremlin Sack** (Common, a Mystery Box dud): two Gremlins hop on. The Mystery Box would then have a 1-in-8 curse chance.

## Decisions already made

- **Mode list for 1.0:** all five modes are playable. The demo offers Countdown and Sprint.
- **Unlock chain:** Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint. Beating any mode unlocks the next level. Goonpocalypse is beaten by surviving 2× the level's seconds.
- **Sprint's clock:** running out of time ends the run. Marathon's clock grows by one Sprint clock per station.
- **Payout:** coins × max(1, stars).
- **Saves:** the demo and the full game share the save, and demo progress carries over.
- **One codebase:** the demo is built with `Root.IS_DEMO`.

## Open questions for the author

1. **Marathon and Defense:** they are playable now. Do they ship in 1.0 or in a free update, and what does the store page say?
2. **Payout model:** keep stars as a multiplier, or move to an additive model with a win bonus? Goonpocalypse's uncapped waves make long runs pay a lot under the multiplier.
3. **The slot machine:** answered. Pauses are fine as long as they're fun, so the slot stays as the signature moment, with paylines and bets (T1-9). Crush goals alternate between it and The Deal, and Marathon stations open the Pit Shop first.
4. **Fuel pressure:** about 87 s of throttle per tank in the stock sedan. Should fuel be the main way runs end, or health?
5. **Price and length target:** this sets every economy number in T1-11 and T2-15.
6. **Gems:** confirm gems are never sold. Is a gem-paid continue (Second Wind) acceptable?
7. **Steam scope for 1.0:** achievements versus leaderboards and dailies. Steam Deck support needs analog steering; input is still digital (`playerCarController.gd`).
8. **Audio budget:** new music and new voice recordings.
