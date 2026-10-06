# GoonCrusher: Gameplay Suggestions

This is a list of suggestions to discuss, not a spec. The author has their own gameplay ideas and runs gameplay as a separate project. Codebase context is in `../CLAUDE.md`, and settings and performance are in `PERFORMANCE.md`.

**Done:** Tier 0, the shared prerequisites, T1-1 to T1-4 (all five modes are playable), and the pickup expansion (T1-9, T2-7, part of T1-10 and T2-6; `docs/PICKUPS.md`). Further pickup work is on hold. **Open:** the rest, regrouped below into **work packages**: small sets of related items, listed in the order to do them.

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
| T0-4 | `tileManager.placeObjective` puts stations on reachable land and pins them. `world_ready` signals when `Root.station` is valid. Chunks unload by distance. |
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
| Goon physics layer | Goons are on layer 3 "Goon" (`collision_layer = 4`) with mask 1+2 (world, car body), so they no longer collide with each other. The car's mask is 1+3 (`collision_mask = 5`) so it still crushes them, and the water `Area2D` (`landscapeMap_water.tscn`) masks 1+3 so it still drowns both. Pickups and the station driveway (mask 1) no longer test goons at all. `Walker.savedLayers` defaults to the new pair, and `setSolid` restores it. Layer 2 is renamed "CarBody" (`carBodyArea`). Not benchmarked yet: re-run S4 (package 1) to see what it saved against Low's 55.0 / 37.9. |
| `meta` in the save | `PlayerData.meta` holds the sections `records`, `hints`, `lifetime`, `medals` and `achievements`. `SAVE_VERSION` is 4, `migrate()` adds any missing section and keeps existing contents, and `reset_save()` now migrates the template too. Each car's `records` gained `score`. |
| Explosion pooling | `ExplosionPool` (`scene/fx/explosion_pool.gd`) lives on the level, which exposes `Level.explode(worldPosition)`. It keeps at most 16 explosions and restarts the oldest when they are all burning. The car's wreck uses it. `goon_fx.gd`'s `blast()` still instantiates its own explosions and should switch to `Root.levelRoot.explode(pos)`; that file belongs to the goon work. |

### T1-1 to T1-4
| ID | What changed | Numbers to check in the playtest (package 1) |
|---|---|---|
| T1-1 Run log | Debug builds append a row per run to `user://runlog.csv` (`scripts/debug/run_log.gd`, `RunLog`, called from `gameSummary.buildGameSummary`). Columns: date, version, driver (player or ai), car, upgrade total, level, mode, seconds, coins, stars, payout, crushes, giants, regions visited, end reason, gems, slot machines, top speed, end fuel and health, plus score, leg (the Marathon leg being driven) and barrier for the new modes. A file with other columns is moved aside. The car counts `giantsCrushed`. | — |
| T1-2 Goonpocalypse | Spawning escalates 2× faster (`SpawnManager.POCALYPSE_ESCALATION`) down to a 0.6 s floor (`POCALYPSE_SPAWN_FLOOR`; other modes keep 1.0 s). Region waves keep paying stars with no cap (`Region.waveCap()`). Score = crushes + 5 × giants + seconds / 2 (`Level.pocalypseScore`). Surviving 2× the level's seconds (`POCALYPSE_TARGET`) beats the mode (its star), even if the run then ends in a wreck or Abandon. The ticket stamps it SURVIVED. Best time and best score are kept per level and car in `meta.records.goonpocalypse` and per car in `records.time`/`records.score` (`SaveManager.recordGoonpocalypse`), shown on the ticket (NEW BEST), the driver's records and the mode card. The HUD shows the score and the time to the star. | Escalation 2×, floor 0.6 s, target 2×. Crowds reach the 250 cap much sooner, so re-run S4. |
| T1-3 Marathon | A relay of `MARATHON_LEGS` = 5 Sprint-length legs. The first is placed as in Sprint. Each station but the last adds that leg's Sprint clock, fills the tank, restores 35 health, repairs every system, and opens the Pit Shop and then a free slot machine (`Level.stationReached`, called deferred from the driveway so the next station isn't placed inside a physics callback). The next station is placed with `placeObjective` a Sprint distance away, within 60° of the last leg's heading (`tileManager.placeNextStation`). The reached station is retired and unpinned (`unpinChunk`), so it unloads once the car leaves. A car coasting in on an empty tank is saved: `outOfFuel` checks the tank again before ending the run. The last station gives SUCCESS. The HUD shows "STATION 2 OF 5". The AI driver rebuilds its station graph when the station changes. | Legs 5, heal 35, the 60° turn. |
| T1-4 Defense | The clock counts down from the level's seconds and is won at 0 (`Level.timeUpCondition`). The station's walls are a barrier with 1000 health (`station.gd`: `startBarrier`, `damage`, `nearestWallPoint`); the walls redden as it drops, and at 0 the run ends with the new `BASEDESTROYED` ("OVERRUN"). Four spawners ring the station at 4000 px. Goons march on the nearest wall point and hit it once per windup + attack + at least 2 s of rest (`Walker.siege`), unless the car comes within 650 px, when their verb hunts the car as usual. Burrowers, flyers and Scrap Gang vehicles always hunt the car. Goons near the station are kept by the despawn sweep. The car starts outside the lot's gap; parked in the driveway it refuels at 4 per second, and entering repairs it. The HUD shows a barrier bar. | Barrier 1000, rest 2 s, ring 4000, 4 spawners, aggro 650, refuel 4/s. The first AI run with a 300 barrier and 0.6 s rest lost it in 45 s. |

`Root.MODE_AVAILABLE` is true for every mode. The demo still offers only Countdown and Sprint.

---

## Work packages, in order

Each package groups items that touch the same code or need each other, so they can be done and playtested together.

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 1 | Playtest and tune | Tier 0 playtest, the new modes' numbers | S + play time | — |
| 2 | Crush feel | T1-12, T2-6, drowning credit (from T2-3) | M | — |
| 3 | Regions, waves and giants | T1-7, T2-4, T2-8, T2-11 | M–L | 1 |
| 4 | Terrain with identity | T1-5, T1-6, T2-9, T1-8 | M | — |
| 5 | Slot machine and gems | ~~T1-9~~, T1-10 (partly done) | S | — |
| 6 | Economy | T1-11, T2-13 | M | 1 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 6 for T2-15 |
| 8 | Sound | T1-13, T1-14 | S + assets | — |
| 9 | Goon depth | T2-1, T2-3, T2-5 (T2-2 and T2-7 done) | M | 2 |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd and night benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3 and 9. They add load, and S4's 1% low is the tightest target.

### Package 1: Playtest and tune
Everything after this assumes numbers that have been played.

- **Run log:** play about 30 runs across 3 cars and all five modes, then read `user://runlog.csv`. Filter out `driver = ai` rows.
- **AI playtests:** `--playtest --mode=marathon,defense,goonpocalypse` gives fast first numbers (CLAUDE.md, `docs/AI_DRIVER.md`). The AI has no Defense strategy beyond patrolling near the station.
- **Tier 0 numbers:** the Sprint distances and clocks; the drop mix; fuel pressure (the stock sedan gets about 87 s of full throttle per tank); the handling and wall damage of all 9 cars (armored cars now take up to 1.7× more wall damage, because armor used to count twice).
- **New mode numbers:** the right-hand column of the T1-1 to T1-4 table.
- **Pickups** (docs/PICKUPS.md): the tier odds and Dice divisors, the item weights, Pit Shop prices, slot bets, event and supply-drop timers, and every power-up's length.
  - Fuel and hull keep about their old share of drops: the Fuel Can weight is 32 and the Repair Kit 15 in the common tier.
  - The run log doesn't count pickups by kind yet; add that before tuning them.
- **Harness bug:** a multi-level playtest's second run hits a goon-list type error (`playtest.gd` `startNext` sets `basicGoons` from ints).
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

**T2-6. Combos and style bonuses.** **Partly done:** the Crush Combo pays coins for crushes less than 1.5 s apart (`PickupEffects.onCrush`), and the results ticket shows the run's best combo (`car.bestCombo`). Open: drift crush, splash (several goons in one pass), giant slayer, and keeping `bestCombo` as a car record (a new record key; `migrate()` adds it). The skid check is in the car's tire-mark code. **Effort:** S.

**Drowning credit (from T2-3):** goons pushed into water die with cause `drown` and give no crush credit or drop. Credit them like blasts do (`SpawnManager.creditCrush`) when the car pushed them. **Effort:** S.

### Package 3: Regions, waves and giants
These all change what a region asks of the player over time. Do them together so the region chip, spawn mix and wave timer stay consistent.

**T1-7. Make the region chip tell the truth.**
- **Already done:** the wave ring fills per wave and handles the last wave (`hud_region.gd`); `pickGoonId` reveals goons 2 and 3 by the region's wave; Goonpocalypse has no wave cap.
- **Problem:** `giantism` is shown as a percentage but used nowhere, and `pickGoonId` still adds global time (`gameTimeProgress / 12`) to the wave.
- **Proposal:** effective giant odds = `giantOdds + giantism / 5`. Decide whether global time should still push the mix.
- **Effort:** S. **Files:** `spawnManager.gd`, `Region.gd`, `hud_region.gd`.

**T2-4. Giant overhaul and Warlord bosses.** Giants get hp 3 (a crush only wounds them twice). A Warlord appears at wave 4 with a health bar, minions and charges, and the station indicator points at it. The `Boss` verb (Foreman) and the NewWave animation in `playerRoot.tscn` are the starting points. **Effort:** M.

**T2-8. Region mutators and optional objectives.** `Region.updatePlayerRegion` still ends with a TODO list (terrain objects, objectives). Mutators such as "fog", "giants only" or "double coins", and objectives such as "crush 20 Rat Pack". **Effort:** M.

**T2-11. Night as a real phase.** About 150 s of day and 90 s of night, a night spawn table, ×1.5 coins at night. Day and night alternate on the run clock every 60 s (`Timer.gd` `daylength`). Goon eyes already glow and night goons already wake (`SpawnManager.nightSweep`). **Effort:** S.

### Package 4: Terrain with identity
All four are in the landscape generator and the car's friction, in this order.

**T1-5. Working sand traps, and friction that stacks.**
- **Problem:** `scene/scenery/groundarea/sand.tscn` is `visible = false` and its `OverheadCarArea2D` has no collision shape, so `level_sandtrap_1` and the SAND object pool do nothing. `setTerrain` sets friction outright while areas add and subtract it, so friction drifts when terrain changes inside an area.
- **Proposal:** make the sand visible and build its shape from `get_used_cells()` in `_ready`; keep `terrainFriction` and `areaFriction` separate and add them; optionally slow goons in sand.
- **Effort:** S.

**T1-6. Make hills generate.**
- **Problem:** the noise is normalized to 0–1 and elevation is `value − 0.1`, so `elevation > 0.9 → HILLS` in `landscapeGenerator.gd` never matches; SNOW (above 0.75 after the offset) is rare.
- **Proposal:** a second ridge-noise mask for hills, kept at least 2 chunks from the start. `placeObjective` already rejects hill chunks.
- **Effort:** S–M. **Risk:** hills could wall off routes; check with the AI route planner (`AIRoute`).

**T2-9. Surface hazards:** mud pits, oil slicks, ice sheets and boost chevrons, by extending `OverheadCarArea2D` with traction and impulse. GoonFx hazards (fire, slime, oil, spikes) already show the look. The Oil Slick gadget and the Fire Trail power-up hurt goons, not the car. **Effort:** S. **Needs:** T1-5.

**T1-8. Give each level its own terrain.**
- **Problem:** all 8 levels share one generator and terrain table. `landscapeType` is set in 5 levels and never read; mud_2 and mud_3 set it to sand. Dunes and Snow use the rocks-only default pool. `level_coins_4.tscn` is empty, while `level_empty.tscn` has 7 coins.
- **Proposal:** an elevation bias per level when the lookup table is built (Dunes mostly sand, Snow with a lower snow threshold, Pools of Agony with more water and mud); force the start patch to the level's main terrain (goons follow terrain through `Goons.regionGoons`); an exported `signatureGoon`; Dunes and Snow pools; fill `level_coins_4` and rename `level_empty`.
- **Effort:** M. **Needs:** T1-5, T1-6.

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

**T1-15. First-run hints.** Nothing teaches these:
- crushing needs more than 100 px/s (about 10 MPH; some goons need more);
- how the slot controls work (Accelerate stops a reel, releasing Brake rerolls, Steer sets the bet);
- that stars come from crush goals, 60 s region waves and Star Fragments;
- that gadgets fire with Use (E / Space).

The proposal is one-time toasts for the first nearby goon, the first slow contact, the first slot machine, the first gadget, the first star, the first night and the first goon that resists. `HudChance.toast` can show them; flags go in `meta.hints`. **Effort:** S–M.

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
| T2-3 On-death effects | **Partly done:** Splitters burst into Goonlings and Doomcarts explode. Open: goons that leave fire behind or reassemble (the old skeleton and firekin ideas, now for the new roster), and drowning credit (package 2). |
| T2-5 Swarms and thrown attacks | **Partly done:** Rat Pack and herds; lobbers and shooters (GoonFx projectiles, pooled). Open: true swarms. |
| T2-7 Timed powerups | **Done**, and far beyond: 78 pickups in nine kinds and five rarities, with timed power-ups, held gadgets (Use), casino and skill games, world props, events, supply drops and mode specials (docs/PICKUPS.md). Open: tuning them all (package 1). |

### Package 10: Post-launch (Tier 3)

| Item | Notes |
|---|---|
| Steam leaderboards (Goonpocalypse score, Sprint time) | The score and best times now exist (T1-2). Needs T1-16. |
| Daily seeded run | Partly enabled: chunk objects have their own RNG, and the map and regions are deterministic. Still on the global RNG: region names and goons (`Region.createRegion`), the start area, the Sprint and Marathon offsets, spawns and drops. |
| "Heat" modifiers after level 8 | Crowds are capped at 250 |
| Ramps and airtime crushes | Collision-mask work around `setForwardCollisionMode`; the Jump Jets gadget already turns off the goon mask while airborne (`Gadgets.use`, `Gadgets.land`) |
| Water shallows and bridges | Station pinning and unpinning are in place |
| Interactive music layers; new voice lines (about 7 × 9 drivers) | Mostly asset cost |
| Training Grounds; custom seed entry | `inputSeed` is exported, but there's no UI |

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
6. **Gems:** confirm gems are never sold. Is a gem-paid continue (Second Wind) acceptable? Gems now also buy a starting gadget and a new hand in The Deal.
7. **Steam scope for 1.0:** achievements versus leaderboards and dailies. Steam Deck support needs analog steering; input is still digital (`playerCarController.gd`).
8. **Audio budget:** new music and new voice recordings.
9. **Pickups in the demo:** the demo currently has every pickup. Should `Root.IS_DEMO` hold some back?
