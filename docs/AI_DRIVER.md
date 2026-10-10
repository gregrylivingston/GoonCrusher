# AI driver and playtest harness

The AI driver plays like a player: the same digital keys, only what a player could see, the same physics, fuel and clock. It playtests the game, drives the console's `ai` and `autopilot`, and drives every rival of the Goon Cup.

## What is where

| File | Owns |
|---|---|
| `scripts/ai/car_driver.gd` (`CarDriver`) | What anything holding a car's keys must answer (`think`, `isPressed`, `justPressed`, `shiftsByHand`). The controller and the car read every key and button through it (`OverheadCarBody2D.actionDown`) |
| `scripts/ai/ai_driver.gd` (`AIDriver`) | The driver every car shares: sight, goals, route, plans, recovery, the lever and the buttons |
| `scene/car/<car>/<car>_driver.gd` | Each car's driver: extends `AIDriver`, overrides the hooks its traits touch, holds its tuning and two personalities |
| `scripts/ai/mode_brief.gd` (`ModeBrief`), `scripts/ai/briefs/`, `mode_briefs.gd` (`ModeBriefs`) | What each mode asks of a driver |
| `scripts/ai/ai_route.gd` (`AIRoute`) | Long-range routes: A* over the `WorldMap`'s own coarse grid (docs/WORLD.md) |
| `scripts/ai/ai_profiles.gd` (`AIProfiles`) | Every tuning parameter with a comment (`DEFAULTS`), the house styles, the skills, and how a spec becomes a driver's set (`build`) |
| `scripts/debug/playtest.gd` (autoload `Playtest`) | Plays and records runs; inert without `--playtest`, `--career` or `--play-start` |
| `scripts/debug/career.gd` (`CareerPilot`), `scripts/ai/personas.gd` (`Personas`), `scripts/ai/career_start.gd` (`CareerStart`) | Career playtests: the menu pilot, the personas' decisions, the starting saves |
| `scripts/ai/tournament.py`, `scripts/ai/career.py` | Run many playtests or careers in parallel processes and print one table |

## Who is driving

A driver's tuning is built in layers, each listing only what it changes (`AIProfiles.build`): `DEFAULTS` → the house style (`HOUSE`, `cautious`) → the car's driver (`tuning()`) → one of that car's personalities (`personalities()`; the first is the default) → the mode's brief (`ModeBrief.tuning()`) → a skill (`SKILLS`: `ace`, `regular`, `rookie`) → overrides from the spec.

A **spec** names the personality, the skill and overrides: `auto` (first personality, ace; `AIProfiles.BEST`, what the game and every harness play by default), `alt` (second), `showoff@rookie`, `@regular`, `auto+hitCost=4`. A personality another car owns falls back to the car's first, so one spec drives a whole field. A house style by name (`crusher`...) replaces `HOUSE` with no personality on top; those exist only to compare against. Specs go in `--profiles`, the tournament, the console (`ai alt@rookie`) or code (`AIDriver.attach(car, {"profile": ...})`); `AIProfiles.problemWith(spec)` says what is wrong with one.

Rivals drive their own car's driver and first personality at a skill by tier (`Rivals.SKILL`) under a pace cap. The personas' specs are in `Personas.DATA`.

**Add a car's driver:** write `scene/car/<id>/<id>_driver.gd` extending `AIDriver`, add the id to `AIProfiles.CARS`. Handling traits live in `integrate()`, so plans already feel them; the driver adds only rules outside it, through the hooks at the top of `ai_driver.gd` (`flankScale`, `nightGlow`, `cruiseFloor`, `spareHealth`, `fuelCaution`, `pickupWorth`, `planGuard`, `wantsAbility`). A car without a file gets the shared driver.

**Add a personality:** an entry in that driver's `personalities()`: a name and the `DEFAULTS` keys it changes.

## Mode briefs

`AIDriver` holds one `ModeBrief` for the mode being played and asks it (objective, fuel plan, health reserve, a goon's worth, ramming, boost...) instead of matching on the mode. A variant mode has its own brief (Flat Out is not Sprint here). `ModeBriefs.BRIEFS` maps modes to briefs; a mode with no entry gets the base brief: roam, crush, collect.

**Add a mode:** extend `ModeBrief` (or a brief near it) in `scripts/ai/briefs/` and add it to `ModeBriefs.BRIEFS`.

## How it drives

The controller calls `AIDriver.think()` every physics tick and reads the keys from `isPressed()`.

1. **Sight** (`canSee`, `--sight=human`): by day what is on screen; at night the headlight beam or a small glow round the car. The station and the terrain map are always known. `--sight=full` separates "can't see it" from "can't do it".
2. **Goal**, 4 times a second (`updateGoal`): the brief's objective, pickups and goons are scored value ÷ (seconds to reach + 1), with a bonus for the current goal. A goon this car can't reach the speed to crush is never a goal (`crushNeed`). Below the brief's health reserve the car stops hunting and treats goons as obstacles (`protecting`).
3. **Route** (`AIRoute`): A* on the map's grid, water and walls solid, fords and bridges open. Near the station a small graph lines the car up with the lot's gap (`buildStationGraph`).
4. **Speed cap** (`updateSpeedCap`): pulse and glide. Fuel burns only under throttle, so the driver solves for the speed the tank can sustain for the clock or the route (`ModeBrief.fuelPlan`).
5. **Plan**, 7.5 times a second (`choosePlan`): a fixed set of key patterns (`PLANS`, `HAND_PLANS`, `REVERSE_PLANS`) is each simulated tick by tick with the car's own `integrate()` and the controller's key rules (`simulate`), swept with the car's footprint against layer 1, and costed in seconds to the goal (`scoreRollout`): time, turning left to do, hits, water, goons beside a slow car, minus crushes. The cheapest wins.
6. **Recovery** (`checkProgress`): a stuck car takes the roomiest way out, forwards first; repeated stucks send it back along its breadcrumb trail.
7. **Buttons** (`pressButtons`, `workLever`): horn, gadget and boost (`Gadgets.aiWantsUse` / `aiWantsMove`, the brief's `wantsBoost`), the car's ability, and the gear lever on a manual.

### Rules to keep

- **`integrate()` must stay pure** (one tick, no side effects): every plan is predicted with it. A handling change inside it is followed automatically; a rule outside it (the van's roll, the trailer, the drift charge) is invisible to plans unless a driver hook charges for it.
- **The driver only presses keys.** Nothing reaches the car except through `CarDriver`; no teleports, no stat changes, no hidden knowledge.
- **Names the AI reads:** `Walker.mode`, `myMode`, `Walker.crushSpeed`, `carBodyArea`, `Level.runMode`, group `cars`, group `slotMachine` (pausing menus the harnesses tap through). Keep them.
- **Goon changes need the goon rules re-checked** (lunge range, crush rules, what is safe to touch): they are not derived from the goon code.
- **Breakables and cones** are walls to physics but passable to the planner at speed: it asks the car (`OverheadCarBody2D.smashThreshold`, `PropReactions.isKnockable`). A new prop kind must answer there.
- **Deep water is never planned through,** although the car survives a short swim.

## Watching it drive

In a debug build, start a run, press backtick and type `ai` (or `ai <spec>`; `ai off` gives the keys back; `-- --console="ai on"` at launch). It draws its plan, goal and route; `ailines off` hides them.

`autopilot [rookie|grinder|explorer]` hands the whole game (menus, runs, results) to a persona until any key, button or click outside the console. It plays the save in use (the real one is backed up first; `start mid` gives it a scratch save).

## Running playtests

```
Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=countdown,sprint --level=prairie --car=sedan --runs=8 --seed=1 > out.txt
```

`--headless --fixed-fps 60` runs as fast as the CPU allows with every frame still 1/60 s of game time; `--uncapped` stops the saved frame cap slowing it. Options are in the header of `scripts/debug/playtest.gd`; levels, modes, cars, profiles and tiers each take a list and multiply. `--matrix` plays every car in every mode (171 runs: split `--car=` over three processes, each with its own `--tag`): check a driver change against it. `--trace` prints the driver's state and plan costs.

Each run appends a row to `user://playtest/results<tag>.csv` (`COLUMNS` in `playtest.gd`) and prints `PLAYTEST_RESULT`; the end prints `PLAYTEST_SUMMARY` and `PLAYTEST_RANKING`. Progress goes to a scratch save. Every pickup is unlocked unless `--unlocks=save`. Write long output to a file, and never pipe a Godot run into `head`.

**Score** (`Playtest.runScore`, the one place it is computed): 30 × log10(1 + payout), plus the mode's result (the share of the clock survived, or a win bonus with the time to spare, or the share of the goal reached, `goalProgress`).

**Tournaments** play specs against each other on the same seeds, one headless process per spec × mode:

```
python scripts/ai/tournament.py --profiles auto,alt --car racer --modes sprint,countdown --runs 6
```

`--rerank <csv>` prints an old tournament's tables again. Differences of a few points over 6 runs are noise: look at the spread column, and change one or two values at a time.

## Career playtests

A persona (`rookie`, `grinder`, `explorer`) plays the whole game from a starting tier through the real menus: shops, picks a run, drives it with the AI driver, answers every pausing screen, reads the results, repeats. It finds blocks, softlocks, dead menus, economy and unlock mistakes, script errors, and how fast each kind of player progresses.

```
Godot_console.exe --headless --fixed-fps 60 --path . -- --career --persona=rookie --start=fresh --sessions=40 --uncapped > career.txt
python scripts/ai/career.py --personas rookie,grinder,explorer --starts fresh,mid,maxed --sessions 30
```

Options, output files and the lines to grep (`CAREER_*`) are in the header of `scripts/debug/career.gd`. The tiers are `CareerStart.TIERS` (`fresh`, `early`, `mid`, `late`, `maxed`; `TIER_TEXT` says what each holds); `--save=<path>` starts from a copy of any save. Progress always goes to `user://playtest/<tag>_save.tres`.

- **Menus get only what a player sends:** input actions (`KeyHint.fire`) or a mouse move and click pushed into the viewport. It never calls menu functions, so a menu a player can't work blocks the persona, and a click that would land on another control is a `mouse` issue. This is the test of "everything works with the mouse alone" and of pad play.
- **Persona decisions are pure functions** in `Personas` (save, run history and a seeded RNG in, choice out), which is what lets `test_career.gd` cover them. Keep them pure.
- **Tiers must be states play can reach:** levels open in order, modes follow the unlock chain, pickups open down their trees, only owned cars carry upgrades (`CareerStart.build`).
- **Checked after every run:** the bank and gems moved by exactly the payout, a win marked the mode and opened what it should, the save on disk equals the one in memory. Every purchase must move the bank by its price. A run paused with no menu open for 10 s is a `softlock`.
- **A new pausing screen** needs an answer in `career.gd` (`answer*`) and, if it has a choice, a rule in `Personas`.

**By hand:** the console's `start <tier>` (or `-- --play-start=<tier>`, `--fresh` to rebuild) gives a person that tier on `user://playtest/human_<tier>_save.tres`; `start real` goes back.

## Status and what is next

Every personality, skill and brief number is a first guess: nothing has been tuned by tournament.

1. **More seeds before tuning** the goon modes and Cone Course: one seed is noise.
2. **Mode numbers the AI exposed:** Drift Trial's Easy target falls in seconds (`ModeTiers.DRIFT_TARGET`); Pursuit's runner may be too soft (`ModeTiers.RUNNER_*`).
3. **Weak modes:** Cone Course (the planner clips cones it didn't predict), Demolition Derby (it doesn't guard its own flanks), Keep the Cup (the chaser doesn't cut the holder off).
4. **Tune by tournament,** per car and mode family, on levels with different ground.
5. **Rivals:** place awareness in races; the cost of six planners on the low-end target.
6. **Housekeeping:** routes weighted per car; split `ai_driver.gd`; move the pattern drivers in `bench.gd` and `promo/capture/session.gd` onto `CarDriver`; retire the unused house styles; scenario tests on small hand-built maps.

## Limits

- **Defense:** it hunts goons by their threat to the pumps but doesn't guard lanes or park to refuel.
- **Pickups:** valued by their registry `ai` worth; no plan for events, and gadget use is a few crowd rules. Pickups near deep water are skipped, which leaves fuel behind on water levels.
- **Not predicted:** the drift boost a release fires, shift slop, the kick and the cut.
- **Horizon:** under a second of simulation plus a straight sweep; a pocket of walls can cost 10–20 s.
- **CPU:** simulating plans is most of the cost, so `ai` can lower the frame rate. Each rival is a full planner (a far one plans half as often, `AIDriver.scanEvery`); six on the low-end target is unmeasured.
