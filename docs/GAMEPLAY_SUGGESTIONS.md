# GoonCrusher: Gameplay Suggestions

This is a list of suggestions to discuss, not a spec. The author has their own gameplay ideas and runs gameplay as a separate project. Codebase context is in `../CLAUDE.md`, and settings and performance are in `PERFORMANCE.md`.

**Tier 0 (must-fix before release) is done.** The open work is Tiers 1–3.

Every remaining item was re-checked against commit `b60aba9`, and file:line references are to that commit. Effort: **S** is under a day, **M** is 1–3 days, **L** is a week or more.

---

## Done: Tier 0

All ten items are in commit `b60aba9`, together with the perf/settings commits on `perf-settings`. The test files (`tests/game/test_progression.gd`, `test_run_flow.gd`, `test_upgrades.gd`) refer to these IDs.

| ID | What changed |
|---|---|
| T0-1 | `levels` is saved. `SaveManager.migrate()` merges old saves with the defaults, including every mode's `gamemodeBeat` key. Beating the last level no longer crashes. The demo and the full game share the save. |
| T0-2 | A run ends exactly once (`Level.hasEnded`). Every end goes through `endLevel`, including Abandon. |
| T0-3 | Countdown counts down from the level's seconds and is won at 0. The clock clamps at 0:00. |
| T0-4 | `tileManager.placeObjective` puts stations on reachable land and pins them. `world_ready` signals when `Root.station` is valid. Chunks unload by distance. |
| T0-5 | Sprint places its station by distance (at most 32,000 px at a reference 450 px/s) and derives its clock from it. Slack goes from 1.5 on Easy to 1.1 on Northern Wastes. Running out of time ends the run (NOTIME). |
| T0-6 | Mode menu restored, with a per-level unlock chain (`Root.isModeUnlocked`): Countdown → Sprint → Goonpocalypse. Every demo gate reads `Root.IS_DEMO`. |
| T0-7 | Marathon and Defense no longer crash, and show "Coming Soon" (`Root.MODE_AVAILABLE`). |
| T0-8 | Oil saves fuel (`fuelBurn`). Dice raises prize weights without mutating the drop table. Traction feeds grip (`gripFor`). Armor applies once. Upgrades cap at 20 per stat (shown as MAX) and in-run stats at 150. Clover and Dice are labelled correctly. The goon drop table's coin weight dropped to 30, so fuel and health drops stay about as common as in the demo. |
| T0-9 | Payout is coins × max(1, stars), shown on the summary and credited there. Abandon pays like a death. Crush awards reached while paused are granted on unpause. The summary needs a fresh press. |
| T0-10 | Start pauses on a controller. |

**Still owed from Tier 0: a playtest.** Tier 0 retuned without data, so all of these need checking:
- the Sprint distances and clocks;
- the new drop mix;
- fuel pressure: the stock sedan gets about 87 s of full throttle per tank;
- the handling and wall damage of all 9 cars. Armored cars now take up to 1.7× more wall damage, because armor used to count twice.

T1-1 exists to make that playtest produce numbers.

---

## Shared prerequisites

Several items below share these. Each is small.

- **A separate goon physics layer.**
  - Goons are on layer/mask 3 (`walker.tscn:33-34`), so they collide with each other.
  - Goon-against-goon physics is the remaining cost in the crowd benchmark (S4).
  - Moving goons to their own layer needs care. The car crushes through mask 1, `carBodyArea` sits on layer 2, and water kills anything on mask 1.
- **A `meta` dictionary in `PlayerData`,** for hint flags, lifetime stats, medals and achievements. Tier 0 added `saveVersion` but no `meta`. Extend `migrate()` and its test.
- **Explosion pooling.** `levelRoot.gd:4` preloads the explosion, but the car instantiates a new one each time (`overhead_car_body_2d.gd:451`). On-death effects and bosses would spawn many.

---

## Tier 1: Complete the existing design

### T1-1. Developer run log
- **Problem:** No price or payout number has data behind it, and Tier 0 changed several at once. Nothing records coins per minute, stars, crushes, end reason or regions visited.
- **Proposal:**
  - In debug builds, append a CSV row to `user://runlog.csv` from `gameSummary.gd:buildGameSummary` (`:65-174`; the payout is at `:137`) with: car, upgrade total, level, mode, duration, coins, stars, payout, crushes, giants, regions visited (`Region.regions.size()`), end reason and gems.
  - Play about 30 runs across 3 cars.
- **Effort:** S. **Files:** `gameSummary.gd`.

### T1-2. Goonpocalypse as the real endless mode
- **Already done:** it counts up, is separate from Countdown, and unlocks after Countdown plus Sprint.
- **Problem:**
  - It reuses Countdown's spawners (`levelRoot.gd:50`) and has no score or harsher tuning.
  - It ends only on NOHEALTH, NOGAS or Abandon, so `currentLevelPassed` never runs and its star can never light.
  - `records.time` exists (`playerData.gd:16`) but is never written.
  - Spawn escalation hits the 1.0 s floor (`spawnManager.gd:84`) after 133–333 s, and region waves stop at 4 (`Region.gd:9`).
- **Proposal:**
  - Use a higher `escalationSpeed` (`spawnManager.gd:4`) and a 0.6 s spawn floor in this mode only, and lift the wave cap in this mode only.
  - Score = crushes + 5 × giants + seconds / 2. Record best time and best score per level and per car.
  - Light the star by surviving a target (for example 2× the level's seconds). After that it's a score chase.
- **Effort:** S–M. **Depends on:** the goon physics layer, for the 1% low in long crowds.
- **Files:** `levelRoot.gd`, `Timer.gd`, `spawnManager.gd`, `Region.gd`, `gameSummary.gd`, `main2.gd`.

### T1-3. Marathon as a relay of stations
- **Problem:**
  - Marathon is one station at the map-clamp limit, about 500,000 px away (`tileManager.gd:122-124,136`), on a clock of 5× the level seconds (`levelRoot.gd:60-61`).
  - At about 87 s of throttle per tank, no car can make it.
  - It is hidden as "Coming Soon".
- **Proposal:**
  - Run 4–5 legs of Sprint length. Each driveway entry (`station.gd:15-19`) adds time, refuels, restores some health, and opens a free slot machine.
  - Each new station is placed with `placeObjective` in a random direction. This needs an `unpinChunk` to go with `pinChunk` (`tileManager.gd:207`).
  - The last leg gives SUCCESS. The HUD shows "Leg 2/5".
  - Set `MODE_AVAILABLE` to true when it's done.
- **Effort:** M. **Files:** `station.gd`, `tileManager.gd`, `levelRoot.gd`, `Timer.gd`, HUD.

### T1-4. Defense: "Stop the goons from reaching the barrier"
- **Problem:**
  - It counts up from 0 (`levelRoot.gd:56-57`), with no barrier, barrier health, win condition or HUD bar.
  - Every goon chases the car (`walker.gd:95,107-108,124,136-142`), and `var target` (`walker.gd:30`) is an unused `Vector2`.
  - The car starts inside the station lot.
  - It is hidden as "Coming Soon".
- **Proposal:**
  - **Barrier:** make the station's concrete walls (`station.tscn:5,42,56`) a barrier with `damage()`, as `scene/car/carBodyArea.gd:3-4` does for the car.
  - **Targeting:** add `targetNode: Node2D` to the walker, defaulting to the car. In Defense, point it at the station. The existing attack already calls `damage()` on whatever it hits (`walker.gd:113-116`).
  - **Spawning:** place spawners in a ring about 4000 px around the station after `world_ready`.
  - **Clock and endings:** count down to SUCCESS. Add a `BASEDESTROYED` end condition, appended to the enum.
  - **Fuel:** parking in the driveway refuels slowly.
  - **Start:** move the car outside the lot.
- **Effort:** L. **Files:** `levelRoot.gd`, `tileManager.gd`, `station.gd/.tscn`, `walker.gd`, `root.gd`, `gameSummary.gd`, HUD, `Timer.gd`.

### T1-5. Working sand traps, and friction that stacks
- **Problem:**
  - `sand.tscn` is `visible = false` (`:8`), and its `OverheadCarArea2D` (`:17-19`) has no collision shape. So `level_sandtrap_1` and the SAND pool on Easy do nothing.
  - `setTerrain` (car `:150-158`) sets friction outright, while areas add and subtract it (`:370-377`), so friction drifts when terrain changes inside an area.
- **Proposal:**
  - Make the sand visible, and build its shape from `get_used_cells()` in `_ready`.
  - Keep `terrainFriction` and `areaFriction` separate and add them.
  - Optionally, slow goons in sand.
- **Effort:** S. **Files:** `scene/scenery/groundarea/sand.tscn/.gd`, `overhead_car_body_2d.gd`.

### T1-6. Make hills generate
- **Already done:** the fractal type is valid now.
- **Problem:**
  - The noise image is normalized to 0–1 and elevation is `value − 0.1`, so `> 0.9 → HILLS` (`landscapeGenerator.gd:155`) never matches. Hills have art and collision but never appear.
  - SNOW (raw value above 0.85) is rare.
- **Proposal:**
  - Generate hills from a second ridge-noise mask, for ridges and corridors.
  - Keep them at least 2 chunks from the start. `placeObjective` already rejects hill chunks.
- **Effort:** S–M. **Risk:** hills could wall off routes. **Files:** `landscapeGenerator.gd`.

### T1-7. Make the region panel tell the truth
- **Problem:**
  - The panel reveals goons 2 and 3 by regional wave (`regionUi.gd:28-37`), but `createGoonScene` picks the tier from global time (`spawnManager.gd:86-90`).
  - `giantism` is shown as a percentage (`regionUi.gd:22`) but used nowhere.
  - The wave bar's value is `time % 60` against a max of `wave × 60` (`:12,16`), so it never fills after wave 1.
  - Region allows wave 4, which the panel doesn't handle.
- **Proposal:**
  - Pick the goon tier from `currentRegion.wave`.
  - Effective giant odds = `giantOdds + giantism / 5`.
  - The bar's value becomes `time − (wave − 1) × 60`, with a max of 60. Handle wave 4.
- **Effort:** S. **Files:** `Region.gd`, `spawnManager.gd`, `regionUi.gd`.

### T1-8. Give each level its own terrain
- **Problem:**
  - All 8 levels share one generator and terrain table (`landscapeGenerator.gd:44-46,154-162`).
  - `landscapeType` (`tileManager.gd:9`) is set in 5 levels and never read; mud_2 and mud_3 even set it to sand.
  - Per-level `basicGoons` is overwritten by Region (`Region.gd:134`).
  - Dunes and Snow use the rocks-only default pool.
  - `level_coins_4.tscn` is empty, while `level_empty.tscn` has 7 coins.
- **Proposal:**
  - Give each level an elevation bias applied when the lookup table is built: Dunes mostly sand, Snow with a lower snow threshold, Pools of Agony with more water and mud.
  - Force the start patch to the level's main terrain. Goons follow terrain automatically (`Region.gd:98-117`).
  - Add an exported `signatureGoon`.
  - Give Dunes and Snow their own pools, fill `level_coins_4`, and rename `level_empty`.
- **Effort:** M. **Depends on:** T1-5, T1-6.

### T1-9. Slot machine: matches, jackpots, and luck that matters
- **Already done:** the reels advance per physics tick and are pooled.
- **Problem:**
  - Claiming turns the three results into three separate powerups with no pair or triple logic (`slotMachine.gd:122-134`).
  - The reels pick uniformly from 14 entries (`slot_row.gd:5-61`), and neither luck nor clover affects them.
  - `lottoTransition.gd:58` assigns String types to an enum-typed field (`slot_award_icon.gd:3`).
- **Proposal:**
  - A pair gives that item ×2. A triple gives ×5 plus the full celebration.
  - Special triples: three gems give +1 star, three purses give a purse rain.
  - Luck gives a small chance (`luck / 500`) that reel 3 copies reel 2.
  - Fix the type.
- **Effort:** S–M.

### T1-10. Give banked gems a use
- **Problem:** `playerData.gem` is written (`saveManager.gd:104-109`) and never read. In a run, gems only pay for rerolls.
- **Proposal**, cheapest first:
  - **Gem pouch:** carry up to 3 banked gems into a run.
  - **Second Wind:** once per run, pay gems to continue with 50 health and 50 fuel. It must hook in before `endLevel`, because the `hasEnded` guard makes every end final. Not available in Goonpocalypse.
  - **Upgrade respec.**
  - **Paint jobs.**
- **Effort:** M.

### T1-11. Per-car upgrade curves and visible prices
- **Already done:** a cap of 20 levels with a MAX state.
- **Problem:**
  - Every car uses `int((lvl+1)^1.6 × 15)` (`saveManager.gd:125`). Maxing all 8 stats costs about 119k coins per car.
  - A flat +1 per level raises the sedan's thrust by 118% but the racer's by only 31%, which erodes car identity.
  - Unaffordable buttons are hidden with `modulate.a = 0` (`statUpgradeButton.gd:22-24`), so players can't see what they're saving for.
- **Proposal:**
  - Give each car a `stat_max` per stat in its `<car>_info.tres`, and make level n move the stat toward it.
  - Use tier-based cost bases.
  - Grey out unaffordable buttons and show the price.
  - Re-fit car prices (`playerData.gd:13-62`) with T1-1 data.
- **Effort:** M. **Depends on:** T1-1.

### T1-12. Crush feel, and the giant scale fix
- **Already done:** death sounds go through the limiter, and Reduce Motion, Reduce Flashing, Car Shake and crush vibration exist.
- **Problem:**
  - Every goon contact calls `damage(5)` before the speed check (car `:234-236`), so a successful crush still costs about 0.35 health.
  - Giants set `scale = Vector2(1.6, 1.9)` (`walker.gd:34`) instead of multiplying, so the 2.0-scale doomcart, firekin and rockman shrink when they become giants.
  - There is no camera shake, hit-stop, corpse fling or splat.
- **Proposal:**
  - Damage only on non-crush contact. Multiply the giant scale.
  - Add trauma-based camera shake (respecting Reduce Motion), plus 30–50 ms hit-stop on giant crushes.
  - Add a pooled splat ring, and a "Splats" option under Graphics.
- **Effort:** S–M.

### T1-13. A voice director for the recorded lines
- **Problem:**
  - Joy lines fire only on stat and gem rewards (car `:392-397`), and purse and powerup lines share one pool (`:101`).
  - Warnings re-arm on fixed 200 s timers (`:132,145`).
  - Giants, awards, records, wins, new regions and nightfall have no lines.
  - The sedan's intro list (`scene/car/sedan/sedan_info.tres:24`) includes three warning clips.
- **Proposal:**
  - A `VoiceDirector` with priorities (warning > win > record > jackpot > giant > award > region), a cooldown of about 5 s, and no repeats within the last 3 lines.
  - Reuse the existing clips for the new events.
  - Clean up the sedan's intro list, and add subtitles.
- **Effort:** S.

### T1-14. More than one music track
- **Problem:** one track loops everywhere. The night playlist is commented out (`Audio.gd:35-37`).
- **Proposal:**
  - Menu, day and night sets, switched in `setNighttime` (`levelRoot.gd:127`).
  - Duck the music under voice lines.
  - Use the `winner_*` and `bonus_*` sounds as stingers.
  - Budget 6–10 tracks.
- **Effort:** S in code, plus licensing.

### T1-15. First-run hints
- **Already done:** short runs pay their coins, and the summary shows "Paid (Coins x Stars)".
- **Problem:** nothing teaches three core rules:
  - crushing needs more than 100 px/s (about 10 MPH);
  - how the slot controls work (Accelerate stops a reel, releasing Brake rerolls; `slotMachine.gd:56-65`);
  - stars come from crush milestones and 60 s region waves.
- **Proposal:** one-time toasts for the first nearby goon, first slow-contact damage, first slot machine, first star and first night. Store the flags in `meta`.
- **Effort:** S–M. **Depends on:** `meta`.

### T1-16. Steam achievements and lifetime stats
- **Problem:**
  - GodotSteam loads on 4.7 and `steamInitEx` works, but no game code calls Steam.
  - There are no lifetime totals.
  - Goons carry no type id (`spawnManager.gd:86-90`).
- **Proposal:**
  - A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`.
  - Mirror unlocks into `meta.achievements`, so non-Steam builds show them too.
  - Tag goons with their type, and accumulate lifetime stats.
  - About 25 achievements, set up on the full game's app ID. Ship `steam_appid.txt` only in dev builds.
- **Effort:** M. **Depends on:** `meta`.

---

## Tier 2: New content and depth

| ID | Suggestion | Current state | Depends on | Effort |
|---|---|---|---|---|
| T2-1 | **Goon behaviour API:** `hp`, `crushSpeed`, `contactDamage` and `knockbackResist` exports, plus overridable hooks. Merge the duplicate goon enum. Tint the speed label when the car is too slow for a nearby heavy goon. | `enemy.gd` holds only audio arrays. Any `CharacterBody2D` touched above 100 px/s is crushed, and `crushGoon` calls `isDying()` on it (car `:262`). The enum is duplicated (`root.gd:7-9`, `spawnManager.gd:6-8`). | — | M |
| T2-2 | **Movement archetypes:** chargers, dodgers, a pikeman braced from the front | Not started | T2-1 | S–M each |
| T2-3 | **On-death effects:** skeletons reassemble, firekin leave fire, a "Boomer" explodes. Goons that drown count as crushes. | Drowned goons roll a drop but give no credit (`Water.gd:4-6`, `walker.gd:164-168`) | T2-1, explosion pooling | S–M |
| T2-4 | **Giant overhaul and Warlord bosses:** giants get hp 3. A boss appears at wave 4 with a health bar, minions and charges, and the station indicator points at it. | Not started. The NewWave animation is `playerRoot.gd:117-122`. | T1-7, T2-1, T2-2 | M |
| T2-5 | **Swarms and thrown attacks** | Not started | T2-1, projectile pooling | M |
| T2-6 | **Combos and style bonuses** (drift crush, splash, giant slayer), plus a `bestCombo` record | Not started. The skid check is car `:305`. | — | S–M |
| T2-7 | **Timed powerups:** nitro, plow, magnet, horn shockwave, shield, goon bait, "+15 s" in Sprint | Not started | T1-4 (bait) | M |
| T2-8 | **Region mutators and optional objectives** | TODO at `Region.gd:137-140` | T1-7 | M |
| T2-9 | **Surface hazards:** mud pits, oil slicks, ice sheets, boost chevrons. Extend `OverheadCarArea2D` with traction and impulse. | The area has only friction and drag | T1-5 | S |
| T2-10 | **Destructibles, goon nests, landmarks** (wrecks using `carDamagedTexture`, single-use gas pumps) | Not started | T2-8 | M + art |
| T2-11 | **Night as a real phase:** about 150 s of day and 90 s of night, a night spawn table, glowing eyes, ×1.5 coins | Day and night alternate on the run clock every 60 s (`Timer.gd:19,43`). Night is measured and runs well on Low, so the performance side is covered. | — | S |
| T2-12 | **Medals, per-level records, a "Next up" panel, a Goon Codex** | Records are per car only (`main2.gd:273-276`) | `meta`, T1-16 | M |
| T2-13 | **Driver perks and affinity** | Hooks exist: `awardBase` (`playerRoot.gd:75`), purse `MIN_COINS`/`MAX_COINS` (`purse.gd:3-4`) | T1-11 | M–L |
| T2-14 | **Rotating contracts** (3 date-seeded goals, reroll for a gem) | Not started | T1-16 | M |
| T2-15 | **Medal-gated top cars** | Not started | T2-12, T1-1 | S–M |

---

## Tier 3: Stretch / post-launch

| Item | Notes |
|---|---|
| Steam leaderboards (Goonpocalypse score, Sprint time) | Needs T1-2 and T1-16 |
| Daily seeded run | Partly enabled: chunk objects have their own RNG, and the map and regions are deterministic. Still on the global RNG: region names and goons (`Region.gd:86-95,120`), the start area (`landscapeGenerator.gd:49`), the Sprint offset (`tileManager.gd:120`), spawns and drops. |
| "Heat" modifiers after level 8 | Crowds are capped at 250 |
| Ramps and airtime crushes | Collision-mask work around `setForwardCollisionMode` (car `:491-493`) |
| Water shallows and bridges | Station pinning is in place |
| Interactive music layers; new voice lines (about 7 × 9 drivers) | Mostly asset cost |
| Training Grounds; custom seed entry | `inputSeed` is exported, but there's no UI |

---

## Decisions already made

- **Mode list for 1.0:** Countdown, Sprint and Goonpocalypse. Marathon and Defense show "Coming Soon".
- **Unlock chain:** Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint. Beating any mode unlocks the next level.
- **Sprint's clock:** running out of time ends the run.
- **Payout:** coins × max(1, stars).
- **Saves:** the demo and the full game share the save, and demo progress carries over.
- **One codebase:** the demo is built with `Root.IS_DEMO`.

## Open questions for the author

1. **Marathon and Defense:** are they a free update after launch, and what does the store page say?
2. **Payout model:** keep stars as a multiplier, or move to an additive model with a win bonus?
3. **The slot machine:** is it core? It pauses play on every crush award. Keep it as the signature moment (T1-9), make it skippable, or make stopping the reels a skill?
4. **Fuel pressure:** about 87 s of throttle per tank in the stock sedan. Should fuel be the main way runs end, or health?
5. **Price and length target:** this sets every economy number in T1-11 and T2-15.
6. **Gems:** confirm gems are never sold. Is a gem-paid continue (Second Wind) acceptable?
7. **Steam scope for 1.0:** achievements versus leaderboards and dailies. Steam Deck support needs analog steering; input is still digital (`playerCarController.gd`).
8. **Audio budget:** new music and new voice recordings.

## Suggested order of work

1. **Playtest Tier 0 with data:** T1-1, then about 30 runs. Tune the Sprint distances, drops, fuel and armor.
2. **Shared prerequisites:** the goon physics layer, `meta`, explosion pooling.
3. **Quick wins that finish existing systems:** T1-5, T1-7, T1-12, T1-13, T1-15.
4. **Endgame and economy:** T1-2, T1-9, T1-10, T1-11, T1-16.
5. **Remaining modes and world identity:** T1-3, T1-6, T1-8, T1-14, then T1-4 or defer it.
6. **Depth for the paid version:** T2-1, then T2-2, T2-3, T2-4, T2-6, T2-12.
7. **Post-launch:** Tier 3.

Re-run the crowd and night benchmarks (S3, S4 in `PERFORMANCE.md`) after T1-2, T2-4, T2-5 and T2-11. They add load, and S4's 1% low is already under target.
