# GoonCrusher: Gameplay Content Suggestions for the Full Release

This is a list of suggestions to discuss, not a spec. The author has their own gameplay ideas and plans to run gameplay as a separate project. The settings and performance work is in `PERFORMANCE_SETTINGS_PLAN.md`, and codebase context is in `../CLAUDE.md`.

**How this list was built.** Three lists were written independently from different angles:
- finishing what's already there (tagged C#);
- progression, economy and retention (P#);
- content variety and game feel (F#).

They were then merged, deduplicated, and the cited evidence was re-checked against commit `83abe66`. Each item lists the source items it absorbs, and wrong claims are listed under "Corrections". Effort: **S** is under a day, **M** is 1–3 days, **L** is a week or more.

The most surprising findings were spot-checked by hand:
- **Oil** burns more fuel as it is upgraded: `fuel -= |accel·2| / (100 − oil)`.
- **Dice/luck** replaces the coin drop weight of 100 with `min(100, luck)`.
- **Traction** is shadowed by a local variable and never affects grip.
- **The countdown win** in GOONCRUSHER is commented out.

**What the code says right now.** In the shipped demo only GOONCRUSHER is ever played, and it can't be won:
- The mode menu is commented out (`main2.gd:277`).
- Sprint needs GOONCRUSHER beaten (`main2.gd:226`), and nothing can beat it, because the success branch is commented out (`Timer.gd:34-39`).

So Sprint, Marathon and Defense have probably never been played by anyone, and their worst bugs are still hidden. The full release has to fix the basic loop before it adds content.

---

## Tier 0: Must-fix before release (broken, unwinnable, or progression-losing)

> **Status (2026-10-05): all of Tier 0 is implemented on `perf-settings`.** Decisions taken where the items left a choice:
> - **Sprint's clock (open question 3):** running out of time ends the run (NOTIME). The station is placed at most 32,000 px away (reference speed 450 px/s), and the clock is the actual distance ÷ 450 × a slack from 1.5 (Easy) to 1.1 (Northern Wastes).
> - **Unlock chain:** Countdown → Sprint → Goonpocalypse. Marathon and Defense need Sprint, but are hidden as "Coming Soon" (T0-7). Beating any mode unlocks the next level.
> - **Payouts:** a run pays coins × max(1, stars). Abandon pays like a death.
> - **Upgrades:** cap of 20 levels per stat per car. The goon drop table's coin weight went from 100 to 30, so fuel and health drops stay about as common as in the demo after the luck fix.
> - **Demo:** every demo gate is behind `Root.IS_DEMO`.
> - **Not playtested yet:** Sprint distances, the new drop mix, and the handling and armor changes for all 9 cars.

### T0-1. Save progression between launches, and version the save
*Merges C1 and P1.*
- **Problem.**
  - `levels` is a plain `var` with no `@export` (`scene/player/save/playerData.gd:74`). It never reaches `playerData.tres` or the user save, so level unlocks and `gamemodeBeat` reset on every launch. The launch-data commit hides this, because levels 1–3 default to `unlocked: true` (`:78,86,93`).
  - `currentLevelPassed` reads `levels[selectedLevel + 1]` with no bounds check (`scripts/global/saveManager.gd:139`), so beating level 8 crashes.
  - The saved `cars` array replaces the script default, so price changes, new keys or moved scene paths never reach old saves.
  - `getVolume` indexes the settings dict directly (`saveManager.gd:107`), so any new settings key crashes an old save.
  - The demo and the full game share `user://saveData_0.1.tres` (`:21`).
  - `gamemodeBeat` has no GOONPOCALYPSE key (`playerData.gd:80-130`). Writing it is safe, but any read like the ones in `main2.gd:184,190` would crash.
- **Proposal.**
  - Add `@export` to `levels` and add `GOONPOCALYPSE: false` to every level.
  - Add `@export var schema_version` and a `meta := {}` dictionary for the new systems (records, medals, lifetime stats, hint flags).
  - Write a `migrate()` step in `load_data()`. It deep-merges default keys into the loaded data. It keeps the player's `unlocked`, `gamemodeBeat`, `upgrades`, `records`, and car ownership (`cost == 0` today), and takes `scene` and the price from the code roster.
  - Bounds-check `currentLevelPassed`. Treat the last level as "campaign complete".
  - Use a new file such as `user://save_v1.tres`, or JSON/ConfigFile, which also removes the risk of loading a user-editable `.tres`. On first launch, detect the demo file and offer a small "Demo Veteran" grant instead of importing demo coins (see Open questions).
  - Move settings to a `Settings` autoload backed by `user://settings.cfg`. This overlaps the settings/perf pass, but it has to happen in the same migration.
  - Add a GUT test that loads a real 0.1 save. The runners point at `res://gut`, a folder that doesn't exist, so fix them to `res://tests`.
- **Effort:** M. **Risk:** medium, because a migration bug loses progress.
- **Files:** `playerData.gd/.tres`, `saveManager.gd`, `main2.gd`, `scripts/windows/run_tests.bat`, `scripts/linux/run_tests.sh`.
- **Depends on:** nothing. Do this first.
- **Why it matters:** every unlock, medal and achievement below is worthless if it's gone on relaunch.

### T0-2. Make the end of a run fire exactly once
*New finding.*
- **Problem.** `endLevel` (`levelRoot.gd:91-100`) has no guard. Several paths can call it twice:
  - `outOfFuel()` sets `isDestroyed` and waits 2.5 s (`overhead_car_body_2d.gd:427-431`), but the car keeps coasting. The station driveway doesn't check `isDestroyed` (`station.gd:18-21`), so a car with an empty tank can roll in and win.
  - `SceneTreeTimer`s default to `process_always = true`, so the pending NOGAS or NOHEALTH (`:398-402`) `endLevel` still fires after the first summary has paused the tree. The result is two summaries and a double `currentLevelPassed()`.
  - Restoring countdown and NOTIME endings (T0-3, T0-5) adds more racing paths.
- **Proposal.** Add `var hasEnded := false` to `Level` and return early from `endLevel` when it's set. In `station.gd`, ignore the car when `body.isDestroyed`. Decide whether a car that is out of fuel but still rolling may finish Sprint. I recommend yes: it's a dramatic finish.
- **Effort:** S. **Risk:** low.
- **Files:** `levelRoot.gd`, `station.gd`, `Timer.gd`.
- **Depends on:** none. Needed by T0-3, T0-5 and T1-3.
- **Why it matters:** two summaries, or a win and a loss from one run, is the kind of bug reviewers screenshot.

### T0-3. GOONCRUSHER ("Countdown"): count down and allow a win
*Merges C4 and P2.*
- **Problem.**
  - The description says "Survive the countdown…" (`root.gd:67`), but the clock counts up: `Timer.gd:11-12` sets `timeIsCountingDown = 1` and `levelRoot.gd:41-42` sets `seconds = 0`.
  - The success branch is commented out (`Timer.gd:34-39`). The only endings are NOHEALTH and NOGAS, so `currentLevelPassed` can never run in the default mode, and Sprint never unlocks.
  - The per-level `seconds` values (250 / 370 / 470 / 420 / 420 / 420 / 420 / 540) are already set in the level `.tscn` files and are simply ignored in this mode.
- **Proposal.**
  - Remove GOONCRUSHER from the count-up cases in `Timer.gd:_ready` and `levelRoot.gd:36-42`.
  - When `seconds <= 0`, call `endLevel(true, SUCCESS)` (guarded by T0-2) and clamp the display at `0:00`. Today `Timer.gd:27-29` can show `0 : 0-5`.
  - The current count-up survival code becomes GOONPOCALYPSE (T1-2).
- **Balance check.** This is my estimate from the code, not measured. The sedan burns `2/(100−oil)` fuel per physics tick at full throttle (`overhead_car_body_2d.gd:259`), which is 2/95 per tick, or about 79 s of throttle per full tank. Input is digital, so there is no partial throttle. Surviving 250 s on Easy therefore means picking up several +20 fuel pickups. Playtest this after T0-8 fixes Oil.
- **Effort:** S. **Risk:** low.
- **Files:** `scene/player/Timer.gd`, `scene/level/levelRoot.gd`, `scripts/global/root.gd`.
- **Depends on:** T0-1, T0-2.
- **Why it matters:** this is the entry mode and the first step of the unlock chain. Today it's an endless mode with a misleading description.

### T0-4. Objective placement and chunk streaming that can't lose the station
*Merges C3, the P2 risk note, and the perf `chunk-unload-leak` finding (confirmed).*
- **Problem.**
  - **The station can land on water or hills.** `loadChunk` only adds the object for land chunks (`tileManager.gd:181`). The station is never added to the tree and the indicator points at nothing.
  - **The station is very likely to be unloaded in Sprint.** It sits in `loadedObjects` like any other cluster. The unload table (`:149-152`, applied as `+i` and `−i` at `:139-141`) includes relative offsets `(4, 0..4)` and `(0..3, 4)`. A player who drives toward the station from the left, on the same row or one up to 4 rows above it, crosses the chunk where `station − player = (4, 0)`, and the station is freed. When the player arrives, the chunk reloads with a random cluster. I traced this by hand from the code and haven't confirmed it in play.
  - **Unloading leaks.** The table is asymmetric, so the loaded-chunk count grows without limit. The perf verifier reproduced this: 58–287 chunks after 200k px.
  - **Negative coordinates are off by one.** `getTile`/`getPlayerChunk` (`:118-120,127-137`) disagree for negative coordinates.
  - **Marathon places its station off the map.** The chunk is around x = 875 (`:87`, with `levelRoot.gd:44` multiplying seconds by 5) on a grid that only goes to ±128 (`:170`), so the index is out of range.
  - **Defense frees its own station.** The station is placed at chunk (0,0) (`:105`). The car starts at (2129,1227) (`levelRoot.tscn:17`), which is also chunk (0,0), and `:89-91` then frees the start-chunk object, which is the station.
- **Proposal.**
  - Add `placeObjective(scene, desiredChunk) -> Vector2i` to TileManager. It clamps to about ±100, then searches outward in a spiral for the nearest chunk that isn't WATER or HILLS, ideally with land neighbours.
  - Keep the result in `pinnedChunks`, which `unloadChunk` and the start-chunk free both skip.
  - Replace the ring with a distance rule: free any chunk where `max(|dx|,|dy|) > R`. Use `floor()` for chunk coordinates everywhere.
  - Emit `world_ready` at the end of `TileManager._ready`. Anything that reads `Root.station` awaits it.
- **Effort:** M. **Risk:** medium, because it touches streaming. Check the chunk count over a 10-minute drive afterwards.
- **Files:** `scene/level/tileManager.gd`, `levelRoot.gd`.
- **Depends on:** none. Needed by T0-5, T0-7, T1-3, T1-4 and T1-6.
- **Why it matters:** this one change is what lets Sprint, Marathon and Defense be finished at all.

### T0-5. SPRINT: always possible to finish, and the clock means something
*Merges C5 and P2.*
- **Problem.**
  - The timer counts down but nothing happens at 0, because NOTIME is commented out (`Timer.gd:38`).
  - The distance ignores the car and fuel. The station chunk x is between 0.12 and 0.16 × seconds (`tileManager.gd:83`), with chunks 5120 px wide.
    - **Easy (250 s):** 154k–205k px. The sedan tops out around 744 px/s on grass (from `:173-182`), so the drive takes about 207–275 s in a straight line.
    - **Northern Wastes (540 s):** 333k–440k px, about 450–590 s in the sedan and about 215–285 s in the racer.
    - **Fuel:** at roughly 79 s of throttle per tank, the sedan needs 3–4 tanks on Easy alone.
  - So once NOTIME is on, much of the range can't be done in a starter car, whatever the player's skill.
- **Proposal.**
  - Place the station with T0-4 first.
  - Then derive the time: `seconds = distance / referenceSpeed × slack`. Use a fixed baseline speed, not the selected car, so fast cars feel fast. Slack runs from about 1.4 on Easy down to about 1.1 on Hard.
  - Cap the distance so a stock sedan with average fuel pickups can make it.
  - Turn NOTIME back on, but see Open question 3: P2 argues that running out of time should only cost a medal, not end the run.
  - Keep the "mi" indicator (`overhead_car_body_2d.gd:141-150`) and show it all the time in Sprint.
  - Optional: a "+15 s" pickup (T2-7).
- **Effort:** M (mostly tuning). **Risk:** medium.
- **Files:** `Timer.gd`, `tileManager.gd`, `levelRoot.gd`.
- **Depends on:** T0-2, T0-4, and T0-8 (the Oil fix changes the fuel budget).
- **Why it matters:** Sprint is mode 2 of the chain. It has to be possible to win in the cars a new player owns.

### T0-6. Restore the mode menu and the unlock chain behind one demo flag
*Merges C2, P2 and the star bug from P12.*
- **Problem.**
  - Choosing a level starts the run straight away, because the jump to the mode menu is commented out (`main2.gd:277`).
  - Marathon, Defense and Goonpocalypse are hard-locked with "Not Availabe In Demo" (`main2.gd:228-233`). The real logic is commented out at `:199-204`, and that commented code has the Marathon and Defense stars swapped: `TextureRect2` is in group `MARATHON` (`main2.tscn:832`) but is set from `DEFENSE`.
  - Levels 4–8 show "NOT IN DEMO" (`main2.gd:111-117`). A demo car gate is parked at `> 20` (`:54`).
  - The star highlight looks for group `"GOONCRUSHER"` (`main2.gd:236,246`), but the node is in group `"COUNTDOWN"` (`main2.tscn:810`).
  - `currentLevelPassed` unlocks the next level when **any** mode is beaten, and resets `gameMode` to GOONCRUSHER (`saveManager.gd:139-142`).
- **Proposal.**
  - Turn `goToMenuMode(menuModes.GAMEMODE)` back on.
  - Restore the per-level chain: Countdown → Sprint → (Marathon, Defense) → Goonpocalypse. The default is "Goonpocalypse unlocks once Countdown and Sprint are beaten"; see Open question 2.
  - Fix the star group and the swapped textures.
  - Put every demo gate behind one `const IS_DEMO`, so the demo can still be built from the same code.
  - Hide or grey out any mode that isn't finished yet (see T0-7). Never ship a selectable mode that crashes.
- **Effort:** S. **Risk:** low.
- **Files:** `scene/player/menu/main/main2.gd`, `main2.tscn`, `saveManager.gd`.
- **Depends on:** T0-1, T0-3.
- **Why it matters:** right now 4 of the 5 modes can't be reached, and the per-level star row is the game's built-in completion tracker.

### T0-7. No selectable mode may crash: Marathon and Defense
*The minimum from C6, C7 and P2. Finishing them is T1-3 and T1-4.*
- **Problem.**
  - **Marathon:** the station index is off the map (T0-4).
  - **Defense:**
    - `levelRoot.gd:33` calls `Root.station.add_child(...)` while TileManager is still waiting at `tileManager.gd:71`. `createNewTerrain` waits on `process_frame` (`landscapeGenerator.gd:55,57`), so `LevelRoot._ready` runs before `setupByGamemode`, and `Root.station` is null or a freed station left from an earlier run.
    - `newSpawner()` has already parented that spawner to the car (`:84`), so it would also fail with "already has a parent".
    - The start-chunk free deletes the station anyway (T0-4).
    - There is no win and no barrier.
- **Proposal.** Either finish Tier 1 items T1-3 and T1-4 before release, or hide both modes in the 1.0 menu and drop them from the unlock chain.
- **Effort:** S to gate them. **Risk:** low.
- **Files:** `main2.gd`, `levelRoot.gd`.
- **Depends on:** T0-6.
- **Why it matters:** a mode that crashes when chosen is worse than no mode.

### T0-8. Make every paid upgrade do what its label says
*Merges C14, P5, P6 and P7.*
- **Problem.** Upgrades are the only thing coins buy. Three of the eight work against their tooltip, and one does nothing:
  - **Oil works backwards.** The tooltip says "Improves fuel efficiency" (`car_stats_container.tscn:135-137`). The code is `fuel -= |accel·2| / (100 − oil)` (`overhead_car_body_2d.gd:259`), so more oil means more fuel burned: oil 50 burns about twice as much as oil 5. At oil 100 it divides by zero, and above 100 fuel goes up.
  - **Dice (`luck`) works backwards.**
    - The tooltip promises "high value prizes" (`:155-157`).
    - `getPowerupFromWeights` sets the COIN weight to `min(100, luck)` and changes the caller's dictionary (`root.gd:47-48`).
    - At luck 1, coins drop about 1 time in 72 (the other weights add up to 71, `walker.gd:10-25`). More Dice moves drops toward single coins.
    - `randi_range(0,total)` is inclusive (`:51`), which adds a small bias.
  - **Traction does nothing for grip.** A local `var traction` (`:190`) hides the exported stat, so grip is always 0.7 or 0.1. The stat only affects braking (`:184`) and the steering ramp (`playerCarController.gd:18-19`), even though the tooltip promises traction (`car_stats_container.tscn:52-54`).
  - **Armor is applied twice to wall damage** (`:230`, then again in `damage()` at `:381`).
  - **Headlights:** the tooltip promises "resistance to damage" (`:127`), which nothing implements.
  - **Labels:** the HUD shows "Luck" for clover and "Dice" for luck.
  - **No caps:** upgrades (`saveManager.gd:77-88`) and in-run `reward()` (`overhead_car_body_2d.gd:347`) are uncapped, so the formulas above eventually break.
- **Proposal.** Use bounded curves.
  - **Oil:** `fuel -= |accel| · 0.021 · 100/(100 + 2·oil)`. That matches today's sedan at oil 0, halves the burn at oil 50, and never reaches zero.
  - **Luck:** run it on a `duplicate()` of the table with COIN left at 100, and raise purse, gem and slot weights instead (for example `PURSE 4+0.3·luck`, `GEM 4+0.1·luck`). Roll with `randi() % total`.
  - **Traction:** rename the local to `grip` and blend the stat in, for example `grip_fast = clamp(traction_fast + traction·0.003, 0.05, 0.40)`. Put the coefficients in exports for tuning. The racer has `slip_speed = 0`, so test it first.
  - **Armor:** apply it once.
  - **Headlights:** fix the tooltip, or add night-only armor.
  - **Caps:** a per-stat ceiling in `reward()`, and an upgrade-level cap with a "MAX" state on the button.
  - Make the HUD and menu labels match.
- **Effort:** S–M. **Risk:** medium, because car handling changes. Re-test all 9 cars.
- **Files:** `overhead_car_body_2d.gd`, `playerCarController.gd`, `root.gd`, `walker.gd`, `saveManager.gd`, `statUpgradeButton.gd`, `car_stats_container.tscn`, `car_panel.tscn`.
- **Depends on:** none. Do it before T0-5 tuning and before T1-11.
- **Why it matters:** players who pay for an upgrade that makes the car worse will leave bad reviews.

### T0-9. Honest payouts, and never lose earned currency
*Merges C17, P4, P14 and F20's 0-star point.*
- **Problem.**
  - **Short runs pay 0.** The payout is `coin × star` (`gameSummary.gd:111,131`), and `star` starts at 0 (`overhead_car_body_2d.gd:40`). Any run that ends before 60 s in one region and before 12 crushes pays nothing.
  - **The summary shows the wrong number.** It shows raw coins (`:114`), not what's paid.
  - **Quitting via water beats Abandon.** Abandon pays 0 (`pauseMenu.gd:26-28`), but driving into water calls `destroy()` (`Water.gd:13-15`), ends the run as NOHEALTH, and pays in full.
  - **A crush award can be skipped.** One reached while the game is paused is ignored until the next crush (`playerRoot.gd:43`).
  - **The summary skips itself.** `Input.is_anything_pressed()` (`gameSummary.gd:27-32`) auto-continues if the player is still holding the gas when the run ends.
  - **Coins can be lost in the menu.** `addCoins` adds 10 coins per frame and saves only at the end (`saveManager.gd:41-51`). An 8,000-coin payout takes about 13 s. Leaving the menu before then calls into the freed menu, and the remaining coins are never added or saved.
- **Proposal.**
  - **Minimum for 1.0:** `payout = coin × max(1, star)`, plus a summary row showing "Coins × Stars = Paid". Use the same formula for `coinProjection` (`playerRoot.gd:31`).
  - **Better, tuned later with T1-1:** P4's `coin × (1 + 0.5·star) + 20·star + completionBonus`, so winning a mode pays more than dying.
  - Make Abandon pay the same as a death (after a confirmation), or pay coins × 1.
  - Queue crush awards until the game unpauses.
  - Make the summary require a fresh press (`is_action_just_pressed`) after a short delay.
  - Apply the payout to `playerData` and save at once, then animate only the display.
- **Effort:** S. **Risk:** low. Upgrade costs may need a light retune.
- **Files:** `gameSummary.gd/.tscn`, `playerRoot.gd`, `pauseMenu.gd/.tscn`, `saveManager.gd`, `main2.gd`.
- **Depends on:** none.
- **Why it matters:** the coin-and-upgrade loop is the main reason to keep playing. Silent 0-coin runs make the game feel stingy.

### T0-10. Controllers can't pause
*From F20, confirmed.*
- **Problem.** `ui_menu` is bound only to the Menu key and Escape (`project.godot:81-86`). A controller player can't pause or abandon.
- **Proposal.** Bind gamepad Start (button 6) to `ui_menu`. Separately, confirm that Esc in pause→settings doesn't close both menus (`pauseMenu.gd:13`).
- **Effort:** S. **Files:** `project.godot`.
- **Why it matters:** Steam and Steam Deck players expect a controller to work.

---

## Tier 1: Complete the existing design (high value, reuses existing systems)

### T1-1. A developer-only run log for tuning the economy
*From P3.*
- **Problem.** Every price and payout number in the three lists is a guess. Nobody knows coins-per-minute at each stage of progress.
- **Proposal.** In `gameSummary.buildGameSummary`, when `OS.is_debug_build()`, append one CSV row to `user://runlog.csv` with: car, upgrade total, level, mode, duration, coin, star, payout, crushes, giants, regions visited, end reason, gems. Play about 30 runs across 3 cars before setting prices.
- **Effort:** S. **Files:** `gameSummary.gd`, `Region.gd` (regions counter).
- **Depends on:** none.
- **Why it matters:** it turns T0-9, T1-11 and T2-15 from guesses into data.

### T1-2. GOONPOCALYPSE: the deliberate endless mode
*Merges C8 and the score part of P16.*
- **Problem.**
  - The mode runs the same code as GOONCRUSHER (`levelRoot.gd:28,39`, `tileManager.gd:97`, `Timer.gd:9`).
  - `records.time` is never written (`gameSummary.gd`).
  - Spawn escalation stops at the 1.0 s floor (`spawnManager.gd:44`). Depending on the level's starting `spawnTimer` of 3–6 s, that happens after about 133–333 s.
- **Proposal.**
  - After T0-3, the count-up code becomes this mode.
  - Make it harsher: a higher `escalationSpeed` (already exported, `spawnManager.gd:4`), a 0.6 s spawn floor in this mode only, and faster giant odds.
  - Lift the regional wave cap here only (`Region.gd:13`).
  - Score = `crushes + 5·giants + seconds/2`.
  - Write best time and best score per level and per car, and show "Best" on the summary and the level card.
  - The fifth star is awarded for surviving a target (for example 2× the level's `seconds`). After that it's a score chase.
  - No continues (T1-10) in this mode.
- **Effort:** S–M. **Risk:** medium for performance. The late game was **never stress-tested** (see `PERFORMANCE_SETTINGS_PLAN.md` §1), and spawning is uncapped (perf `goon-population-uncapped`).
- **Files:** `levelRoot.gd`, `Timer.gd`, `spawnManager.gd`, `Region.gd`, `gameSummary.gd`, `playerData.gd`, `main2.gd`.
- **Depends on:** T0-1, T0-3, and the perf work's live goon cap (about 120) plus a separate goon physics layer. Goons are on layers and masks 1+2 (`walker.tscn:33-34`), so they collide with each other.
- **Why it matters:** it gives each level and car a replayable endgame for very little code.

### T1-3. MARATHON: a relay between several stations
*Merges C6 and P2. C6's design is the one I recommend.*
- **Problem.**
  - Today's design multiplies seconds by 5 (`levelRoot.gd:44`) and puts one far station at 0.7 × seconds.
  - Fixed, that's still 15+ minutes at full throttle with nothing to do, and fuel (about 79 s of throttle per tank) can't support it.
  - P2's alternative, one station at 3× the Sprint distance, has the same problem.
- **Proposal.** Four or five Sprint-length legs.
  - Each time the player enters the driveway (`station.gd:18-21`), the leg ends instead of the run:
    - add time;
    - refill fuel and restore some health;
    - open a free `slotMachine.tscn`, as the crush bonus does;
    - un-pin the old station and call `placeObjective` for the next one, in a random direction at Sprint distance, so the route stays on the 256×256 map.
  - The last leg ends with SUCCESS.
  - Show "Leg 2/5" on the HUD.
  - Difficulty carries over because SpawnManager's escalation never resets.
- **Effort:** M. **Risk:** medium, because long runs need the T0-4 leak fix and the goon cap.
- **Files:** `station.gd`, `tileManager.gd`, `levelRoot.gd`, `Timer.gd`, `playerRoot.gd/.tscn`.
- **Depends on:** T0-2, T0-4, T0-5.
- **Why it matters:** it reuses the station, the indicator and the slot reward, and gives Marathon its own identity (checkpoints and fuel management) without making the map bigger.

### T1-4. DEFENSE: "Stop the goons from reaching the barrier"
*Merges C7 and P2.*
- **Problem.**
  - The mode is a stub, and it crashes (T0-7).
  - There is no barrier, health or objective.
  - Goons only chase the car (`walker.gd:79,91,108,120` all read `Root.playerCar.position`).
  - `var target` at `walker.gd:28` is an unused **Vector2**. It can't hold a node.
- **Proposal.**
  - Turn the station's `concrete_wall` pieces (`station.tscn:5`) into the barrier: a StaticBody2D with `damage()`, like `carBodyArea.gd`, that feeds a `barrierHealth`.
  - Add `var targetNode: Node2D` to Walker, defaulting to the car. In DEFENSE, point it at `Root.station`. The existing ATTACK branch already calls `damage()` on whatever it touches (`walker.gd:97-100`), so goons hitting the wall hurt the barrier with no new attack code.
  - Place spawners in a ring of about 4000 px around the station after `world_ready`, not on the car.
  - Count down from the level's `seconds` to SUCCESS. Barrier at 0 ends the run with a new `endCondition.BASEDESTROYED` and its own summary lines.
  - Parking in the driveway slowly refills fuel, so the mode isn't decided by NOGAS.
  - Add a barrier health bar to the HUD.
  - Use an empty object cluster around the station so goons don't get stuck on rocks.
- **Effort:** L. **Risk:** medium (goon pathing).
- **Files:** `levelRoot.gd`, `tileManager.gd`, `station.gd/.tscn`, `walker.gd`, `root.gd`, `gameSummary.gd`, `playerRoot.tscn`, `Timer.gd`.
- **Depends on:** T0-2, T0-4. Optional: T2-1.
- **Why it matters:** it's the only mode where the player protects something, and it reuses the walls, the walker attack and the damage code.

### T1-5. Working sand traps, and friction that stacks correctly
*Merges C11 and F8's prerequisite.*
- **Problem.**
  - `sand.tscn` is `visible = false` (`:8`), and its `OverheadCarArea2D` child (`:17-19`) has no collision shape. So `level_sandtrap_1` is empty, `level_sand_fuel_1` is just a fuel pickup, and the SAND pool on Easy does nothing.
  - `setTerrain` assigns friction outright (`overhead_car_body_2d.gd:133-138`), while areas add and subtract it (`:330-337`). Changing terrain while inside an area makes friction drift, even below zero.
- **Proposal.**
  - Make the sand visible and build its collision shape from `get_used_cells()` in `_ready`.
  - Store `terrainFriction` and `areaFriction` separately, and set `friction = terrainFriction + areaFriction`.
  - Optional: slow goons in sand too.
- **Effort:** S. **Risk:** low.
- **Files:** `scene/scenery/groundarea/sand.tscn/.gd`, `overhead_car_body_2d.gd`.
- **Depends on:** none. Needed by T2-9.
- **Why it matters:** the art, the class and the level objects already exist. Only one shape and one formula are missing.

### T1-6. Make hills generate, and use them as natural walls
*Merges C10 and the related note in F9.*
- **Problem.**
  - `noise.get_image()` normalizes to 0–1, and elevation is `r − 0.1`, so `elevation > 0.9 → HILLS` never matches (`landscapeGenerator.gd:129`). SNOW needs `r > 0.85`, so it's rare too.
  - `inputFractalType = 4` (`:10`) is outside FastNoiseLite's 0–3 range, with a wrong `@export_range(1,4)`.
  - The hill TileMap already has collision polygons, and spawners already skip region −2.
- **Proposal.**
  - Fix the fractal type.
  - Generate hills from a second ridge-noise mask, so they form ridges and corridors instead of blobs.
  - Keep hills at least 2 chunks from the start and from pinned objectives (T0-4).
- **Effort:** S for the threshold fix, M for the ridge mask. **Risk:** medium (it could wall off routes).
- **Files:** `landscapeGenerator.gd`, `tileManager.gd`.
- **Depends on:** T0-4.
- **Why it matters:** a finished terrain type with art and collision goes unused, and hills add route choice in Sprint and Marathon.

### T1-7. Make the region panel tell the truth
*Merges C12 and the tier/giantism parts of F6 and F7.*
- **Problem.**
  - The region panel unlocks goons 2 and 3 by regional wave (`regionUi.gd:26-35`), but `createGoonScene` picks by global `gameTimeProgress` (`spawnManager.gd:47-50`).
  - `giantism` is shown as a "%" (`regionUi.gd:20`) but used nowhere.
  - The wave bar has value `time % 60` and max `wave × 60` (`:12-14`), so it never fills after wave 1.
  - Region allows wave 4 (`Region.gd:13`), but the UI's `match` stops at 3.
- **Proposal.**
  - Pick the goon tier from `currentRegion.wave`. Keep global time only for spawn rate and giant odds.
  - Use `giantOdds + giantism/5` for the effective giant odds.
  - Set the bar to value `time − (wave−1)·60`, max 60, and handle wave 4.
- **Effort:** S. **Risk:** low.
- **Files:** `Region.gd`, `spawnManager.gd`, `regionUi.gd`.
- **Depends on:** none. Region flicker from the async flood fill is a perf/bug-pass item. Fix it before T2-8.
- **Why it matters:** the HUD currently shows information that has no effect on the game.

### T1-8. Give each level its own terrain
*Merges C9 and F7's terrain bias.*
- **Problem.**
  - All 8 levels run the same generator.
  - `landscapeType` is exported and set in 5 levels but never read (`tileManager.gd:9`). The values look wrong as well: mud_2 and mud_3 use 1, which the comment says is sand.
  - Per-level `basicGoons` isn't exported (`spawnManager.gd:9`) and Region overwrites it anyway (`Region.gd:138`).
  - Dunes and Snow use the default `[ROCKS]` pool.
  - `level_coins_4.tscn` is empty (0 instances), while `level_empty.tscn` holds 7.
- **Proposal.**
  - Pass a per-level elevation bias or threshold table into `getTerrainType`:
    - Dunes: mostly sand;
    - Snow: lower the SNOW threshold;
    - Pools of Agony: more water and mud.
  - Force the start patch to the level's main terrain.
  - Because Region already picks goons by terrain (`Region.gd:102-121`), each level also gets its own goons automatically.
  - Replace `basicGoons` with an exported `signatureGoon` mixed into each region.
  - Give Dunes and Snow their own object pools, fill `level_coins_4`, and rename `level_empty`.
- **Effort:** M. **Risk:** low–medium. Check that Sprint still works on levels with a lot of water.
- **Files:** `landscapeGenerator.gd`, `tileManager.gd`, `Region.gd`, `spawnManager.gd`, `scene/level/levels/*.tscn`, `levelObjects/*.tscn`.
- **Depends on:** T1-5, T1-6.
- **Why it matters:** "8 levels" on a store page needs 8 levels that look and play differently.

### T1-9. Slot machine: matches, jackpots, and luck that matters
*Merges C15, P11 and F15.*
- **Problem.**
  - Claiming turns all three results into separate powerups with no matching logic (`slotMachine.gd:121-133` in the original file).
  - The reels pick uniformly from 14 entries (`slot_row.gd:5-61`).
  - Neither luck nor clover affects the reels.
  - The reels move 18 px per frame (`slot_row.gd` `_process`), so they depend on frame rate.
  - `lottoTransition.gd:39` probably assigns String types to `slot_award_icon.type`, which is typed `Root.upgrade`.
- **Proposal.**
  - **Pair:** that item ×2.
  - **Triple:** ×5, plus a `winner_*` sting and the `lottoTransition`/`splashscreen_1` celebration. Special triples: three gems = +1 star, three purses = a purse rain.
  - Luck gives a small chance (`luck/500`) that reel 3 copies reel 2.
  - Rewrite reel motion with `delta`.
  - Re-check the crush threshold when the machine closes (shared with T0-9).
- **Effort:** S–M. **Risk:** low.
- **Files:** `slotMachine.gd`, `slot_row.gd`, `slot_award_icon.gd`, `lottoTransition.gd`.
- **Depends on:** T0-8 (luck fix).
- **Why it matters:** the slot machine is the game's signature reward moment, and right now a lucky spin doesn't exist.

### T1-10. Give banked gems a use
*Merges C16 and P10.*
- **Problem.**
  - Gems are banked (`saveManager.gd:56-65`), but nothing reads `playerData.gem`.
  - `car.gem` starts at 0 each run (`overhead_car_body_2d.gd:39`), so banked gems never come back into play.
  - In a run, gems only pay for rerolls (`slotMachine.gd` reroll, `spendGems(1)`).
- **Proposal**, cheapest first:
  - **Gem pouch:** carry up to 3 banked gems into a run.
  - **Second Wind:** once per run, on NOHEALTH or NOGAS, pay gems (the price rises with each use) to resume with 50 health and 50 fuel. Disabled in Goonpocalypse and in any ranked run.
  - **Upgrade respec** (T1-11).
  - **Paint jobs:** a `modulate` swap.
  - Never sell gems for real money (see Open questions).
- **Effort:** M. **Risk:** low–medium (run balance).
- **Files:** `saveManager.gd`, `overhead_car_body_2d.gd`, `slotMachine.gd`, `gameSummary.gd`, `levelRoot.gd`, `main2.gd`.
- **Depends on:** T0-1, T0-2.
- **Why it matters:** collecting a currency that does nothing makes the meta-game feel unfinished.

### T1-11. Upgrade cost curve, per-car caps, and visible prices
*Merges P8 and the price numbers from P9.*
- **Problem.**
  - Every car uses the same cost, `int((level+1)^1.6 × 15)` (`saveManager.gd:78`). Ten engine levels cost about 2,599 coins in total.
  - A flat +1 stat per level means a sedan's engine gains 59% (thrust 17 → 27, `:173`) while the racer gains 16%. With no caps the starter car eventually beats the 10k cars, and no car is ever finished.
  - Unaffordable buttons are hidden with `modulate.a = 0` (`statUpgradeButton.gd:16-18`), so players can't see what they're saving toward.
- **Proposal.**
  - 10 levels per stat per car, with a "MAX" state.
  - Each car exports a `stat_max` per stat, and level n moves the stat toward it. This keeps each car's identity.
  - Cost bases by car tier, for example `costBase[tier] × (level+1)^1.4`.
  - Show unaffordable buttons greyed out with the price.
  - Re-fit car prices (0 / 1k / 2k / 2.5k / 5k / 10k / 10k / 25k / 35k, `playerData.gd:9-63`) using T1-1 data. P9's starting point is about 64k in total.
  - The migration clamps over-cap stats in old saves and refunds the excess.
- **Effort:** M. **Risk:** medium.
- **Files:** `saveManager.gd`, `statUpgradeButton.gd`, `car_stats_container.gd`, `overhead_car_body_2d.gd:88-96`, the 9 `scene/car/*/*.tscn`.
- **Depends on:** T0-1, T0-8, T1-1.
- **Why it matters:** each car becomes a project with an end, and there is always a visible next purchase.

### T1-12. Crush feel pass, and the giant scale fix
*Merges F12 and the scale bug from C13 and F6.*
- **Problem.**
  - A crush is a death animation, two sounds and a fly-up icon.
  - Every goon contact calls `damage(5)` before the crush check (`overhead_car_body_2d.gd:213-215`), so successful crushes cost about 0.35 health each at armor 0.
  - There's no camera shake or hit-stop.
  - Goon death sounds bypass the 4-per-frame limiter (`walker.gd:141-146` against `Audio.gd:15-22`).
  - Giant scale **replaces** the goon's scale (`walker.gd:32`), so the 2.0-scale doomcart, firekin and rockman shrink when they become giants.
- **Proposal.**
  - Move `damage(5)` into the non-crush branch.
  - Add trauma-based shake on the car's Camera2D, and 30–50 ms of hit-stop on giant crushes only.
  - Fling corpses along the car's velocity.
  - Add a pooled splat ring of 64 sprites.
  - Route crush audio through `Audio.queueRequest`, with pitch rising with speed.
  - Change giant scale to `scale *= Vector2(1.6, 1.9)`.
  - Add settings for shake %, hit-stop, reduced flashing, and splats Off/Low/Full (which also helps performance).
- **Effort:** S–M. **Risk:** low.
- **Files:** `overhead_car_body_2d.gd`, `scene/car/car.tscn`, `walker.gd`, new `scene/fx/splat_pool.gd`, settings scenes.
- **Depends on:** the `Settings` autoload (T0-1) and the goon physics layer.
- **Why it matters:** in a game about crushing, every crush should feel good. This is the most feel per line of code available.

### T1-13. A voice director that reuses the recorded lines
*Merges P20 and F18 (code side).*
- **Problem.**
  - Joy lines fire only on stat pickups (`overhead_car_body_2d.gd:350-355`).
  - Purse and powerup lines share one pool (`:81`).
  - Warnings re-arm on hard-coded 200 s timers (`:112,125`).
  - Giants, awards, jackpots, records, wins, new regions and nightfall are silent.
  - The sedan's `introAudio` includes a lowHealth clip and a lowgas clip (`sedan.tscn:71`, ids `7_6itbh`, `9_6gq7h`).
- **Proposal.**
  - Add a `VoiceDirector` with priorities (warning > win > record > jackpot > giant > award > region), a global cooldown of about 4–6 s, and no repeats within the last 3 lines.
  - Route the existing joy clips to the new events until new lines are recorded.
  - Clean up the sedan's intro list.
  - Add a subtitles toggle.
- **Effort:** S. **Risk:** low.
- **Files:** `overhead_car_body_2d.gd`, new `scene/car/voice_director.gd`, `sedan.tscn`.
- **Depends on:** none. Hooks into T1-9 and T2-x.
- **Why it matters:** nine voiced drivers are the game's main personality, and almost none of it is heard during a run.

### T1-14. Music: more than one looping track
*From F17 (playlist part).*
- **Problem.** There is one track (`sound/music/abstract-world-127012.mp3`). `loadNextNightSong` has its playlist commented out and replays it (`Audio.gd:26-28`). Menu, day, night and slots all share that one loop.
- **Proposal.**
  - Use `AudioStreamPlaylist` sets for menu, day and night, switched in `setNighttime` (`levelRoot.gd:63`).
  - Duck the music under voice lines.
  - Play stingers from the existing `winner_*` and `bonus_*` sounds.
  - Budget 6–10 licensed tracks.
- **Effort:** S in code, plus the cost of the music. **Files:** `Audio.gd/.tscn`, `new_audio_bus_layout.tres`, `levelRoot.gd`.
- **Why it matters:** hearing one track for a 20-minute run makes the run feel longer.

### T1-15. First-run hints
*From F20.*
- **Problem.** Nothing teaches the core rules:
  - crushing needs more than 100 px/s, shown as 10 "MPH" (`:215`);
  - 0 stars pays 0 coins (T0-9);
  - how the slot controls work;
  - that stars come from crush awards and region waves.
- **Proposal.** A `HintManager` with one-time toasts on triggers: first goon near, first slow-contact damage, first slot machine, first star, first night, a run ending with 0 stars. Store the flags in `meta`.
- **Effort:** S–M. **Files:** new `scene/player/hint_manager.gd`, `playerRoot.tscn`, `gameSummary.gd`, `slotMachine.tscn`.
- **Depends on:** T0-1.
- **Why it matters:** demo players who never learned the star rule left with 0 coins.

### T1-16. Steam achievements and stats, plus lifetime stats
*Merges P15 and the stats half of P13.*
- **Problem.**
  - GodotSteam ships in `addons/godotsteam/`, but nothing initializes it.
  - The only Steam reference is the store link (`top_menu.gd:25-26`).
  - The binaries declare `compatibility_minimum = 4.1` and must be checked against 4.7.
  - There are no lifetime totals anywhere, and goons carry no type id.
- **Proposal.**
  - A `SteamService` autoload, guarded by `Engine.has_singleton("Steam")`, calling `steamInitEx` and running callbacks.
  - Mirror every unlock into `meta.achievements`, so non-Steam builds show them too.
  - Set `goon.goonType` in `createGoonScene`. Accumulate crushes, giants, distance, jackpots and nights in `meta.lifetime`.
  - About 25 achievements tied to the systems above.
  - Configure them on the full game's app ID, not the demo's. Ship `steam_appid.txt` only in dev builds.
  - Don't add any achievement that needs hills until T1-6 lands.
- **Effort:** M. **Risk:** medium (the 4.7 build).
- **Files:** new `scripts/global/SteamService.gd`, `project.godot`, `spawnManager.gd`, `walker.gd`, `gameSummary.gd`.
- **Depends on:** T0-1.
- **Why it matters:** players expect achievements in a paid Steam game, and they're cheap to add.

---

## Tier 2: New content and depth

### T2-1. A goon behaviour API: HP, crush speed, and overridable hooks
*Merges F1, F2 and C13.*
- **Problem.**
  - `enemy.gd` is empty.
  - All 18 goons share one state machine, and the car decides everything: any `CharacterBody2D` touched above 100 is destroyed (`overhead_car_body_2d.gd:213-215`).
  - Collision type is checked with `get_class()` strings (`:211-213`). Any future CharacterBody2D without `isDying()` crashes the car.
- **Proposal.**
  - Add exports `hp`, `crushSpeed`, `contactDamage` and `knockbackResist`, and virtual methods `_move_step`, `_on_hit_by_car(car, speed, dir) -> bool` and `_on_death`. Today's behaviour stays as the default.
  - Replace the string checks with `is Walker` or groups.
  - Example tuning: shellback needs a 450 crush speed, rockman has hp 3, immortal revives once at half scale.
  - Tint the speed label when the car is below the nearest heavy goon's crush speed.
  - Merge the duplicate `goon` enum (`root.gd:7-9` and `spawnManager.gd:6-8`).
- **Effort:** M. **Risk:** medium (balance). Keep heavy goons out of the GRASS pool.
- **Files:** `enemy.gd`, `walker.gd`, `walker/*/*.tscn`, `overhead_car_body_2d.gd`, `car_panel.gd`.
- **Why it matters:** Engine upgrades and the fast cars start to matter in fights, and the 18 sprites become 18 different threats.

### T2-2. Movement archetypes
*From F3.*
- **Chargers** (doomcart, goonbear) lock a direction and stun themselves on rocks.
- **Dodgers** (samurai, lizard) sidestep a car that's closing fast.
- **Pikeman** is braced from the front: a frontal hit hurts the car, a side or rear hit crushes it. It needs a clear tell.
- **Effort:** S–M each. **Depends on:** T2-1.
- **Why it matters:** regions start to play differently, not just look different.

### T2-3. On-death effects and drowning credit
*Merges F5 and F9.1.*
- Skeletons reassemble unless driven over.
- Firekin leave burning patches that hurt goons.
- A new "Boomer" variant explodes after a crush (reusing `explosion.tscn` after it's pooled).
- Goons that walk into water count as crushes with a "SPLASH" popup (`Water.gd:13-15` already kills them for nothing).
- **Effort:** S for drowning credit, M for the rest. **Depends on:** T2-1, explosion pooling, the goon cap.
- **Why it matters:** chain reactions are the core "crusher" fantasy.

### T2-4. Giant overhaul and "Warlord" boss events
*From F6.*
- Giants get hp 3, crush speed 300, and knockback on each hit.
- When a region reaches wave 4, or on a timer in Goonpocalypse, a 3× boss spawns:
  - a health bar at the top of the screen;
  - it summons minions and charges (T2-2);
  - it's announced with the `NewWave` animation (`playerRoot.gd:74-79`) and the wolf player;
  - the indicator (`overhead_car_body_2d.gd:141-150`) gains a target override to point at it;
  - it guarantees a slot machine and gems.
- **Effort:** M. **Risk:** medium (the big-fight case was never measured). **Depends on:** T1-7, T2-1, T2-2, the goon cap.
- **Why it matters:** runs get peaks, and there's a natural "one boss per level" pillar for the paid version.

### T2-5. Swarms and ranged throwers
*From F4.*
- Rat and gremlin packs: `packSize` 6–8 in a 150 px cluster.
- Soldier, viking and zulu throw telegraphed area attacks that also hurt goons.
- **Effort:** M. **Depends on:** T2-1, the goon cap (packs count as fractional slots), projectile pooling.
- **Why it matters:** circling forever at speed stops being the best strategy.

### T2-6. Combos and style bonuses
*From F13.*
- Crushes within 1.5 s chain. Thresholds of 5, 10 and 20 grant +1, +3 and +6 toward the crush meter.
- Popups for DRIFT CRUSH (the `:271` drift check), SPLASH, GIANT SLAYER and CLOSE CALL.
- Record `bestCombo`.
- **Effort:** S–M. **Depends on:** the T0-9 queued-award fix.
- **Why it matters:** skilful driving gets a visible score.

### T2-7. Timed powerups
*From F14.*
- Nitro, Plow, Magnet, Horn Shockwave, Shield, Goon Bait (Bait needs T1-4's `targetNode`), and Sprint's "+15 s".
- A HUD row of icons with drain bars.
- Permanent +1 pickups become rarer.
- **Effort:** M. **Depends on:** T0-8 (drop-table fix).
- **Why it matters:** +1% armor is invisible. A timed power is something the player feels.

### T2-8. Region mutators and optional objectives
*Merges F7, C12 and the `Region.gd:141-144` TODO.*
- Mutators such as Gold Rush, Goon Rush, Giant Country, Fog and Bounty.
- One optional task per region for a bonus star, for example "Crush 15 [goon1]" or "Destroy the nest" (T2-10).
- **Effort:** M. **Depends on:** T1-7, and the region flood-fill fix (perf pass) so mutators don't flicker.
- **Why it matters:** crossing into a new region becomes a decision.

### T2-9. Surface hazard family
*From F8.*
- Extend `OverheadCarArea2D` with a traction override and an impulse.
- Mud pits (slow goons too), oil slicks, ice sheets in snow, and boost chevrons.
- **Effort:** S once T1-5 is done. **Why it matters:** terrain becomes something you can see and plan around.

### T2-10. Destructibles, goon nests, and landmarks
*Merges F11 and F19.*
- Breakable fences, crates and tents that drop loot.
- Nests that spawn goons nearby and take 3 hits at high speed.
- Landmark clusters: wrecked cars using each car's `carDamagedTexture`, region signposts, single-use gas pumps.
- **Effort:** M plus art. **Depends on:** T0-4 pinning, the goon cap, T2-8.
- **Why it matters:** procedural worlds need anchors and reasons to drive somewhere.

### T2-11. Night as a real phase
*From F16. Line numbers corrected.*
- **Today:** `daylength = 60` (`Timer.gd:20`), toggled at `:31` and `:43-53`, so day and night alternate every 60 s. Night only fades `CanvasModulate` to black, plays a howl and turns on headlights (`levelRoot.gd:63-79`).
- **Proposal:** about 150 s of day and 90 s of night; a night spawn table; glowing-eye sprites (cheaper than lights); ×1.5 coins and +10 giant odds at night; a star for surviving to dawn.
- **Effort:** S. **Risk:** medium for performance. Night is the worst GPU path and was never measured. Ship it with the perf work's lighting settings.

### T2-12. Medals, per-level records, a "Next up" panel, and a Goon Codex
*Merges P12, P13 and P14.*
- Bronze, silver and gold for each level × winnable mode.
- Per-level records stored in `meta.levelRecords`, with a "NEW RECORD" banner.
- A menu panel showing the next car, the nearest medal, and the active contract.
- The Records button (`main2.gd:259-262`) becomes a Codex with silhouettes until each goon type is first crushed.
- **Effort:** M. **Depends on:** T0-1, T0-6, T1-16 (goon type id).
- **Why it matters:** it's the replay loop after the first clear.

### T2-13. Driver perks and affinity
*From P19.*
- One passive perk per driver, built on existing hooks. Examples: Karen's crush awards come every 10 instead of 12 (`awardBase`, `playerRoot.gd:35`); Andrew's purses roll 25–125 (`purse.gd:6`).
- Affinity XP unlocks a paint job, a portrait variant and a bio line.
- **Effort:** M–L. **Depends on:** T0-8, T1-11.
- **Why it matters:** players have a reason to keep using every driver.

### T2-14. Rotating contracts
*From P17.* Three active goals, seeded from the date, rerollable for 1 gem. **Effort:** M. **Depends on:** T1-16 stats.

### T2-15. Medal-gated top cars
*From P9.* The semi, audi, racer, police and ambulance need medal counts as well as coins. **Effort:** S–M. **Depends on:** T2-12, T1-1.

---

## Tier 3: Stretch / post-launch

| Item | Source | Effort | Notes |
|---|---|---|---|
| Steam leaderboards for Goonpocalypse score and Sprint time | P16 | M | Needs T1-2 and T1-16. Use `keep_best`. No Second Wind in ranked runs. |
| Daily seeded run | P18 | L | Needs per-chunk and per-region RNG, a synchronous region labelling pass, and the negative-chunk fix. Riskiest item. |
| "Heat" modifiers after level 8 | P21 | M | Swarm, Titans, Long Night, Dry Tank, Glass Car. Worst performance case. |
| Ramps and airtime crushes | F10 | M | Collision-mask juggling with `setForwardCollisionMode` (`:433-435`). |
| Water shallows and bridges | F9.2-3 | M | Needs T0-4 pinning. |
| Interactive music layers; newly recorded voice categories (about 7 × 9 drivers) | F17, F18 | M–L | Mostly asset cost. |
| Training Grounds level; custom seed entry | F20, P18 | S–M | |

---

## Corrections to the input lists

- **F16:** cites `Timer.gd:213,224`, but the file is about 60 lines. `daylength = 60` is at `:20`, the toggle at `:31`/`:43-53`, and a 20 s re-arm guard at `:56-58`.
- **C7:** "walker already has a var target (`walker.gd:27`)". It's at `:28` and typed `Vector2`, so it can't hold the station node. T1-4 adds a `targetNode`.
- **C14:** "coins drop about 1/78 of the time". It's about 1/72: the non-coin weights add up to 71, plus 1 for coin at luck 1. That matches P7.
- **C16:** "gems have a 4/178 drop weight". The nominal table is 4/171. Because of the luck bug, the real share at luck 1 is about 4/72.
- **P16:** "spawnTimer floors at about 333 s". That only holds for a starting timer of 6 s (mud_1 uses the default). Levels starting at 3–5 s reach the floor after about 133–267 s.
- **F1/F12:** "crushing quietly hurts you". True, but it's about 0.35 health per contact at armor 0 (`damage(5) × 7/100`), not a big drain.
- **C2/P2/main2:** the commented unlock logic that the lists say to "restore" has the Marathon and Defense stars swapped (`main2.gd:200-203` against `main2.tscn:832,843`).
- **Additions from re-reading the code:**
  - the double-`endLevel` race (T0-2);
  - the Defense spawner gets parented twice (T0-7);
  - coins lost when leaving the menu mid-payout (T0-9);
  - the specific unload offsets that make losing the Sprint station likely (T0-4);
  - the Sprint/Countdown fuel budget estimate: about 79 s of throttle per tank (T0-3, T0-5);
  - inconsistent `landscapeType` values on mud_2 and mud_3 (T1-8).

---

## Open design questions for the author

1. **Is the 5-mode list final?** Defense (T1-4) is the biggest single item. Shipping 1.0 with three modes (Countdown, Sprint, Goonpocalypse) and adding Marathon and Defense in a free update is a real option, but the store page needs to say so.
2. **The unlock graph.** Strictly linear per level (Countdown → Sprint → …), or "Countdown **or** Sprint unlocks the next level" (P2)? And should Goonpocalypse be open from the start?
3. **Is Sprint's clock a loss or a medal?** If NOTIME ends the run, the time limits must be generous and tied to the car. If it only costs silver and gold, the mode is friendlier but less tense.
4. **Is the slot machine core?** It pauses play on every crush award. Keep it as the signature moment (and invest in T1-9), make it skippable, or make stopping the reels a skill?
5. **Fuel pressure.** At about 79 s of throttle per tank, running out of fuel is probably the main way runs end. Is that the intended main failure, or should health be?
6. **The payout model.** Keep stars as a multiplier (high skill ceiling, harder to balance), or switch to an additive model (P4)? Should winning a mode pay a bonus?
7. **Price and length target.** Price point and hours to "campaign complete" and "100%". This sets every economy number in T1-11 and T2-15.
8. **Demo carry-over.** Import demo progress, give a veteran bonus, or start fresh? Demo coins were earned under the broken Oil and Dice formulas.
9. **What gems are for.** Confirm gems are never sold. Is a paid continue (Second Wind) acceptable in a premium game?
10. **Steam scope for 1.0.** Achievements (expected) versus leaderboards and dailies (post-launch?). Steam Deck support needs analog input; today input is digital only (`playerCarController.gd`).
11. **Audio budget.** New music tracks (T1-14) and new voice recordings for 9 drivers (T1-13 and Tier 3). Are the voice actors available?
12. **One codebase for the demo?** If yes, keep `IS_DEMO` (T0-6). If no, delete the gates.

---

## Suggested order of work

1. **Foundations (about 1 week).** T0-1 save and migration, T0-2 end guard, T0-4 placement and streaming, T0-10 pad pause. Then measure chunk counts over a long drive.
2. **A working loop (about 1 week).** T0-3 Countdown, T0-6 menu and chain, T0-7 gating, T0-8 upgrades, T0-9 payout. **Milestone: a fresh save can win Countdown on level 1, unlock Sprint, restart the game, and keep it.**
3. **Second mode, plus tuning data.** T0-5 Sprint, T1-1 run log. Collect about 30 runs.
4. **Quick wins that finish existing systems.** T1-5 sand, T1-7 regions, T1-12 crush feel, T1-13 voice, T1-15 hints.
5. **Endgame and economy.** T1-2 Goonpocalypse (after the perf goon cap), T1-9 slots, T1-10 gems, T1-11 upgrade curve and prices, T1-16 Steam achievements.
6. **Remaining modes and world identity.** T1-3 Marathon, T1-6 hills, T1-8 level identity, T1-14 music. T1-4 Defense last, or defer it (Open question 1).
7. **Depth for the paid version.** T2-1 behaviour API, then T2-2, T2-3, T2-4, T2-6 and T2-12. Then the rest of Tier 2 as time allows.
8. **Post-launch.** Tier 3, leaderboards first, the daily run last.

Throughout, re-run the benchmark scenarios from `PERFORMANCE_SETTINGS_PLAN.md` §9 after T1-2, T2-4, T2-5 and T2-11. They add exactly the night and big-fight load that was never measured on the HD 620.
