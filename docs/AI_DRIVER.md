# AI driver and playtest harness

The AI driver plays like a player: it holds the same digital keys, sees only what a player could see, and lives with the same physics, walls, water, goons, fuel and clock. It playtests the game, and it drives every rival of the Goon Cup.

**Who drives:** the game (console `ai`), the playtest harness and `tournament.py` all play `AIProfiles.BEST` = `"auto"`: the car's own driver, its first personality, at ace skill, unless `--profiles` names another spec ("Who is driving", below).

- `scripts/ai/car_driver.gd` (`CarDriver`): what anything that holds a car's keys must answer (`think`, `isPressed`, `justPressed`, `shiftsByHand`). The car's controller and the car itself read every key and button through it.
- `scripts/ai/ai_driver.gd` (`AIDriver`): the driver every car shares: perception, route, plans, recovery, the lever and the buttons.
- `scene/car/<car>/<car>_driver.gd`: each car's own driver. It extends `AIDriver`, overrides the hooks its traits touch and holds the car's tuning and personalities.
- `scripts/ai/mode_brief.gd` (`ModeBrief`), `scripts/ai/briefs/`, `scripts/ai/mode_briefs.gd` (`ModeBriefs`): what each mode asks of a driver.
- `scripts/ai/ai_route.gd` (`AIRoute`): the long-range route planner (A* over the world's coarse map; docs/WORLD.md).
- `scripts/ai/ai_profiles.gd` (`AIProfiles`): the tuning: every parameter, the house styles, the skills, and how a spec is built into a driver's set.
- `scripts/debug/playtest.gd` (autoload `Playtest`): the harness that plays and records runs.
- `scripts/ai/tournament.py`: plays several profiles on the same seeds and ranks them.
- `tests/game/test_ai_driver.gd`: the route planner, the prediction and the scoring rules. `tests/game/test_ai_cars.gd`: the car drivers, personalities, skills, briefs, the handbrake, the lever and the buttons.

## Who is driving

A driver is built in layers, each changing only what it must (`AIProfiles.build`):

1. **`DEFAULTS`**: every parameter, with a comment on each.
2. **The house style** (`AIProfiles.HOUSE`, `cautious`): the tuning the single driver won its tournaments with.
3. **The car's driver** (`tuning()`): what this car needs changed whoever drives it.
4. **A personality** of that car (`personalities()`; the first is the default).
5. **The mode's brief** (`ModeBrief.tuning()`): what the mode demands, over any personality.
6. **A skill** (`AIProfiles.SKILLS`): how well the keys are worked.
7. **Overrides** from the spec.

A **spec** names the personality, the skill and overrides: `auto` (first personality, ace), `alt` (second), `showoff@rookie`, `@regular`, `auto+hitCost=4`. A personality another car owns falls back to the car's first, so one spec drives a whole field. A house style by name (`cautious`, `crusher`, `default`...) replaces the house style and puts no personality on top. Use a spec in `--profiles`, the tournament, the console (`ai alt@rookie`) or code (`AIDriver.attach(car, {"profile": ...})`). `AIProfiles.problemWith(spec)` says what is wrong with one.

### The cars' drivers

Handling traits live in `integrate()`, so every plan already feels them. A car's driver adds what is a rule on top, through hooks the shared driver calls.

| Car (character) | Personalities | What its driver adds |
|---|---|---|
| Sedan (Anthony) | `steady`, `scrappy` | Second Wind unused: worries less about the tank (`fuelCaution`) |
| Van (Lester) | `hauler`, `tipsy` | Charges plans that keep it on two wheels until it rolls (`planGuard`, `tipCost`); never pulls the handbrake |
| Taxi (Andrew) | `fare`, `shortcut` | Fuel saving never drops below the meter's speed (`cruiseFloor`); walls cost more |
| Pickup (Karen) | `hoarder`, `mudder` | A pickup is worth a crate in the bed too, while there is room (`pickupWorth`); walls cost more |
| Police (Nikita) | `interceptor`, `bythebook` | PIT: goons beside it matter a quarter as much (`flankScale`); the lightbar's 900 px of sight at night (`nightGlow`) |
| Ambulance (Xavier) | `careful`, `codethree` | The unused defibrillator is 12 health in hand (`spareHealth`) |
| Racer (Kim) | `showoff`, `lineholder` | Pulls the handbrake for smaller turns; the showoff slides for the boost (`driftReward`); a bigger health reserve |
| Supercar (Snake) | `flatout`, `precious` | Walls cost more; a bigger health reserve |
| Semi (Tiffany) | `bulldozer`, `trucker` | Drops the load on a pack behind it (`wantsAbility`); never pulls the handbrake |

The shared driver also asks the car what it can smash (`OverheadCarBody2D.smashThreshold`, so the semi drives through fences from a standstill) and drags a trailer along every plan (`towTrailer`, `trailerSnags`, `trailerCost`).

To add a car: write `scene/car/<id>/<id>_driver.gd` extending `AIDriver` and add the id to `AIProfiles.CARS`. A car without one gets the shared driver.

### Skills

| Skill | |
|---|---|
| `ace` | No delay, no noise, shifts on the redline |
| `regular` | Keys reach the car 0.08 s late, 0.3 s of noise on each plan's cost, shift points off by up to 12% of the band |
| `rookie` | 0.2 s late, 0.8 s of noise, a shorter look ahead, shifts early and unevenly |

The Goon Cup's rivals drive their own car's driver and first personality, with a skill by tier (`Rivals.SKILL`: rookie on Easy, regular on Medium, ace on Hard) on top of the pace cap. The personas: the Rookie plays `auto@rookie`, the Grinder `auto`, the Explorer `alt@regular`.

### The keys beyond the four

- **Handbrake.** Four handbrake plans (`HAND_PLANS`: a slide held for the plan, or a flick) are weighed above `handbrakeFrom` px/s when the aim is more than `handbrakeTurn` radians off the nose, or always where sliding scores. `simulate()` holds `CarInput.handbrake`, which `integrate()` already models, and counts the ticks of slide the drift charge would count; `driftReward` takes that off the plan's cost.
- **The lever.** On a geared car a driver with `shiftByHand` makes the car a manual (`OverheadCarBody2D.isManual`) and works `ShiftUp` / `ShiftDown` (`workLever`): up at `shiftAt` of the gear's band (0.8 or more earns the kick), down when the engine bogs, down to R to back up. `shiftSlop` moves each shift's point, so a rookie's shifts cut the push.
- **Horn.** At `hornGoons` goons ahead in the horn's cone that the car is too slow to crush (or any, when it is protecting its health).
- **Gadget and boost.** `Gadgets.aiWantsUse` / `aiWantsMove` (the crowd rules), plus the brief's `wantsBoost`: Nitro on a long, clear, straight run at the aim (`openRoadAhead`) in the modes with no goons.
- **Ability.** The car's driver decides (`wantsAbility`).

The car reads all of these through `actionDown`, which asks the driver; nothing reaches the car another way.

## Mode briefs

`AIDriver` holds a `ModeBrief` for the mode being played (`Level.runMode`, so a variant has its own) and asks it instead of matching on the mode.

| Brief | Modes | What it sets |
|---|---|---|
| base (`ModeBrief`) | Goonpocalypse | Roam, crush, collect; a course's next gate if there is one |
| `survival_brief` | Countdown, Blackout | The tank must last the clock; the health reserve shrinks with the time left |
| `race_brief` | Sprint, Marathon, Rally Stage, Cannonball | The station through any checkpoints; detour budget; goons worth less |
| `flatout_brief` | Flat Out | No slow zone at the lot; brakes to 380 px/s from the point its own physics says it must (`brakeDistance`), under the 420 stop speed; Nitro on the straights |
| `pursuit_brief` | Pursuit | The hunter aims where the runner will be (`leadPoint`) and leaves cars out of its sweeps; the runner races |
| `lap_brief` | Hot Lap, Circuit Race, Knockout | The next gate; Nitro on the straights |
| `cones_brief` | Cone Course | A knocked cone costs a plan 1.2 s (`knockCost`), not a passing touch; the handbrake for tighter turns |
| `drift_brief` | Drift Trial | Handbrake plans always weighed; 3 s off a plan per second of slide |
| `smash_brief` | Smash Run | The nearest thing this car can smash; Nitro on the straights |
| `defense_brief` | Defense | Patrol by the base; goons worth more the nearer the pumps |
| `bounty_brief` | Bounty Hunt | Out to the mark; the mark worth 6 goons |
| `derby_brief` | Demolition Derby | The car whose flank or tail is soonest reached, led; stays inside the line |
| `keepcup_brief` | Keep the Cup | After the cup; the holder flees the nearest chaser |

To add a mode: extend `ModeBrief` (or a brief near it) in `scripts/ai/briefs/` and add it to `ModeBriefs.BRIEFS`.

## Watching it drive

In a debug build (the editor's Play button), start any run from the menu, press backtick and type `ai`. The AI takes the wheel and draws what it is thinking:
- green line: the plan it chose; red when it expects to hit something
- yellow line and circle: what it is going for
- cyan dot: where it is steering
- blue line: its route around water

It keeps driving with the console open, and it drives every later run too until `ai off` gives the keys back. `-- --console="ai on"` turns it on at startup.

**The whole game: `autopilot`.** In the console, from the menu or mid-run, type `autopilot` (a random persona) or `autopilot rookie`, `grinder` or `explorer`.
- The persona plays as in a career playtest (below), with the transitions on and its plan drawn: it shops in the garage, picks the run, drives it, answers every screen that pauses it, reads the results and goes again.
- Any key, pad button or click takes control back, and so does `autopilot off`. Mid-run the car is simply yours again.
- Opening the console (backtick) doesn't take control back; nor does typing or clicking in it. While it is open the persona waits before its next menu press (the car keeps driving in a run), and its time-outs don't count that time.
- `ailines off` hides what every AI driver draws (goal, plan and route), for `autopilot` and `ai` alike; `ailines on` brings it back.
- It plays the save in use. Type `start mid` first to hand it a tier's scratch save. On your real save it backs the save up first, since the persona spends coins.
- Its log is `user://playtest/autopilot_events.log`. `-- --console="start mid;autopilot explorer"` starts it at launch.

## Running playtests

```
Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=countdown,sprint --runs=8
```

`--headless --fixed-fps 60` runs the game as fast as the CPU allows, with every frame still 1/60 s of game time. A 250 s Countdown takes about 15–30 s on the dev box. `--uncapped` stops the saved frame cap from slowing it.

| Option | Default | |
|---|---|---|
| `--level=a,b` | `prairie` | level ids (`Levels.ORDER`, 30), 0-based indices or scene names |
| `--landscape=<id>` | the level's | builds every level in this landscape (`Landscapes.ORDER`; docs/WORLD.md "Landscapes"); benchmarks and the world preview take it too |
| `--class=<id>` | the line-up | every district's goons from this class (`Goons.CLASSES`) instead of the level's line-up; `--goons=a,b,c` forces three |
| `--mode=a,b` | `countdown` | any of `Modes.IDS`: `countdown`, `sprint`, `marathon`, `defense`, `goonpocalypse`, `blackout`, `bounty`, `rally`, `flatout`, `hotlap`, `drift`, `cones`, `smash`, `cannonball`, `circuit`, `derby`, `knockout`, `keepcup`, `pursuit` |
| `--car=a,b` | `sedan` | car names from the save (`sedan`, `van`, `police`, ...) |
| `--profiles=a,b` | `auto` (`AIProfiles.BEST`) | AI specs to play ("Who is driving"); each is another dimension like car or mode |
| `--matrix` | off | every car in every mode (unless `--car` or `--mode` names some): the table to check a driver change against |
| `--tier=a,b` | `easy` | mode tiers (`ModeTiers`): `easy`, `medium`, `hard` |
| `--runs=N` | 1 | runs per level × mode × tier × car × profile |
| `--seed=N` | 1 | first map seed; run *k* uses seed + *k* |
| `--upgrades=N` or `save` | 0 | every stat upgraded to level N (0 = stock car), or the save's own upgrades |
| `--sight=human` or `full` | `human` | what the driver may see (below) |
| `--max-seconds=N` | 900 | level time after which a run is cut short (`TIMEOUT`) |
| `--unlocks=all\|save` | `all` (`save` for careers and `--play-start`) | every pickup can drop, as before the unlocks, or only what the save has unlocked (`Unlocks.allOpen`; docs/PICKUPS.md, "Unlocks"). Benchmarks take the same option |
| `--tag=name` | none | results go to `results<name>.csv` |
| `--trace` | off | prints the driver's state and every plan's cost each second, each wall hit and stuck event, and an ASCII map of the terrain |
| `--ai-debug` | off | draws the chosen plan, goal and route (needs a window, not `--headless`) |

Each run appends one row to `user://playtest/results<tag>.csv` (`%APPDATA%/GoonCrusher/playtest/`) and prints `PLAYTEST_RESULT {json}`. When every run is done, it prints one `PLAYTEST_SUMMARY` per level/mode/car/profile with wins, endings and averages, and a `PLAYTEST_RANKING` of the profiles in each mode. Progress goes to a scratch save, so the real save is never touched. A seed rebuilds the same map, and with `--fixed-fps` it usually replays the same run. Exact replays aren't guaranteed, because the terrain is built on a worker thread.

Write long runs to a file (`> out.txt`) rather than capturing them in a shell variable.

## House styles and tournaments

Everything the driver weighs is a parameter in `AIProfiles.DEFAULTS` (`scripts/ai/ai_profiles.gd`), with a comment on each. The house styles are whole-driver tunings from before each car had a driver; `cautious` is what every car's driver is built on, and the rest are kept to compare against:

| Style | Idea |
|---|---|
| `cautious` | **`HOUSE`.** Keeps health: walls, flanks and slowness among goons cost more; stops hunting sooner. The best all-round style in the single-driver tournaments (stock sedan, Prairie, three modes) |
| `default` | the plain `DEFAULTS` |
| `v1` | the driver as first tuned: 1 s plans, a 400 px sweep, no reverse cost or crush reward |
| `crusher` | plays for crushes: goons worth twice as much, flanks matter less, hunts until lower health |
| `farsight` | simulates 2–3 s ahead tick by tick (several times the CPU) |
| `collector` | pickups first: every pickup worth twice as much, goons less |
| `rookie` | the old Rookie persona's style (the `rookie` skill replaces it) |

A tournament plays every profile in every mode on the same seeds, so all of them meet the same maps, and ranks them by score:

```
python scripts/ai/tournament.py --profiles auto,alt --car racer --runs 6
python scripts/ai/tournament.py --profiles "auto,auto+reverseCost=6" --modes sprint --runs 10 --name reverse
```

Each profile × mode is one headless Godot process, `--parallel` at a time (default 3 of the dev box's 4 threads). The script prints a table per mode and writes every run to `tournament_<name>.csv` next to the per-process logs. `--rerank <csv>` prints the tables of an earlier tournament again, so a change to the score doesn't need a replay.

The score per run is **coins + the mode's result**, because payout (coins × the star multiplier, `Root.computePayout`) is what buys cars and upgrades, and a run pays out even when it is lost. It is computed once, by `runScore` in `playtest.gd`; `tournament.py` reads the `score` column.
- **Coins:** 30 × log10(1 + payout): 60 for 100 coins, 90 for 1,000, 104 for 3,000. The log keeps one huge payout from swamping every other run.
- **Countdown:** plus 50 × the share of the clock survived.
- **Sprint and Marathon:** a win adds 50 + 25 × the share of the clock left; a loss adds up to 25 for the share of the way to the station covered.
- **Blackout and Defense:** as Countdown (won by outlasting the clock).
- **Goonpocalypse:** plus 50 × the share of 300 s survived.
- **Every other mode** (the Trials, the Goon Cup, Bounty Hunt): a win adds 50 + 25 × the share of the clock left; a loss adds up to 25 for the share of the goal reached (`goalProgress`: score or marks out of the target, the cup's seconds, gates and laps, the way to the station).

To iterate: copy the winner into a new profile, change one or two values, and play it against its parent with more seeds. Differences of a few points over 6 runs are noise. Look at the `+/-` column (the spread of scores) before believing a ranking.

### What a row records

- **Run:** `level`, `mode`, `car`, `profile` (the spec), `personality`, `seed`, `upgrades`, `sight` and `score`.
- **Goal:** `progress` (the share of the mode's goal reached), `place` and `field` (races against rivals), `overshot` (Flat Out: crossed the line too fast), `ai_shifts` (pulls on the lever).
- **Ending:** `reason` is `SUCCESS`, `NOHEALTH`, `NOGAS`, `NOTIME`, `ABANDONED`, `WATER` (drowned: a `NOHEALTH` with the car's centre over deep water, `car.drowned`) or `TIMEOUT`. Also `won`, `level_time`, the starting `clock`, `time_left`, and for races `station_px`, `station_left_px` (how far from the station it ended) `route_reached` (false when the station is cut off by water) and `legs` (stations reached: 0 or 1 in Sprint, one per leg in Marathon).
- **Score:** `crushed`, `coin`, `star`, `payout`, `gem`, `slot_machines`, and pickups by kind (`fuel_pickups`, `health_pickups`, `purses`, `coins_picked`, `gems_picked`, `stat_pickups`). Slot machine prizes count as pickups.
- **Damage**, as health lost, split by what the car was touching at the time:
  - `damage_rocks`: rocks, walls, hills and props, exactly what the car's wall hits and scrapes took (`wallHealthLost`); a car pinned to a wall by goons counts their attacks as goon damage.
  - `damage_water`: what wading depth and deep water took (`waterHealthLost`); the last column, after `first_clear_gem`.
  - `damage_goon_contact`: the car ran into a goon. Every crush costs the car health too.
  - `damage_goon_attacks`: a goon lunged into the car's body.
  - `crush_misses`: goons the car hit at over 200 px/s that survived.
- **Resources:** `min_fuel`, `min_health`, `end_fuel`, `end_health`.
- **Driving:** `distance_px`, `avg_speed`, `top_speed`, `eco_seconds` (time spent saving fuel), `stuck`, `escapes`, `ai_ms` (the driver's own CPU per second of game time, wall clock, so inflated on a busy machine), and `goals` (how often it chose each kind of goal). `--trace` also splits `ai_ms` by layer at the end of each run.

## Career playtests

A career playtest has one of three **personas** play the whole game the way a player does. It starts from a chosen point in progress and goes through the real menus. It shops in the garage, picks a car, level, mode and starting gadget in run setup, and drives the run with the AI driver. It answers every screen that pauses the run, reads the results ticket and goes back to the garage, then starts again. Use it for deep checks: blocks, softlocks, menus that don't take input, economy and unlock mistakes, script errors, and how fast each kind of player progresses.

```
Godot_console.exe --headless --fixed-fps 60 --path . -- --career --persona=rookie --start=fresh --sessions=40 --uncapped > career.txt
```

- `scripts/debug/career.gd` (`CareerPilot`) is the harness. The `Playtest` autoload starts it with `--career` and records each run as it does for plain playtests (same CSV columns, plus `persona` and `session`).
- `scripts/ai/personas.gd` (`Personas`) holds the personas and every decision they make. The functions are pure (save, run history and a seeded RNG in, choice out), so `tests/game/test_career.gd` covers them.
- `scripts/ai/career_start.gd` (`CareerStart`) builds the starting saves.
- `scripts/ai/career.py` runs several careers in parallel processes (`--personas rookie,grinder,explorer --starts fresh,mid,maxed --sessions 30`), then prints one table: runs, wins, minutes, modes beaten, cars and upgrades from start to end, the longest stall, issues and errors. After the table come coins per minute by mode, and every issue and script error with the careers that met it. `--report` prints the summaries already written.

### The personas

| | Rookie | Grinder | Explorer |
|---|---|---|---|
| Drives with | `auto@rookie` (late keys, noisy plans, fluffed shifts) | `auto` (`BEST`) | `alt@regular` (each car's second personality) |
| Menus with | the mouse | keys | both, plus pad glyphs |
| Runs | the obvious next one: the furthest open level's first unbeaten mode in `Root.modePath` order (Sprint, Countdown, then its featured modes, the first of which to be won opens the next level); a finale whose featured mode was won below Medium gets that mode again on Medium; then the modes left on earlier levels; after 3 losses in a row there, Countdown on the level before to farm coins | the path while it's winning, else the run that pays most per minute in its own history (20% sampling the others) | the level and mode it has played least, with the car it has driven least |
| Garage | a new car the moment it is affordable, any pickup unlock under half the bank, then the cheapest upgrade going | saves once the next car is within 3 average payouts; meanwhile the pickup unlock with the best `ai` worth per coin (under a third of the bank), then Engine, Armor, Oil, Traction first (no stat more than 2 levels ahead of the lowest) | buys every car to try it, often a random pickup unlock, then the stat it has least of |
| Gems | never | a starting gadget only with 6+ gems, Nitro in the boost slot with 8+ left | gadgets, boosts, new hands, raises at random |
| In-run screens | slot bet 0; in The Deal keeps a card once fewer than half the deck beat it; the nearest claw prize; the first Pit Shop offer it can afford | bets 25 with 400+ run coins; keeps a Deal card worth 20+ (`ai`); the rarest claw prize; supplies in the Pit Shop | random bets; keeps a Deal card it hasn't discovered; extra claw grabs; buys the whole Pit Shop |
| Prize games (all personas) | the claw is dropped as it passes over the persona's prize; the Deal redraws (Q) until the persona's rule keeps a card; the Pit Shop buys in order, stopping at the first offer it doesn't want; Hubcap Shuffle, Goon Press, Pachinko Drop and Coin Pusher (drafts) are tapped through with the action key (`answerTapping`); every game's winnings board is left with Accelerate or a click (`career.gd`, `answer*`, `leaveBoard`) | | |
| Side trips | Goonopedia or records sometimes (15%) | none | Goonopedia and Pickups (every tab), records and Settings (every tab, changing nothing) every visit; pauses half its runs, opens Settings from pause; abandons 6% of runs |

### Starting points

`--start=` picks a `CareerStart.TIERS` entry. Every tier is a state play can reach: levels open in order, beaten modes follow the unlock chain, and only owned cars carry upgrades.

| Tier | Levels and modes | Cars | Upgrades | Bank | Pickups |
|---|---|---|---|---|---|
| `fresh` | a new save | sedan | none | 0 | the 10 tree roots |
| `early` | The Wilds (levels 1-5) beaten on Medium (Sprint, Countdown and the first featured mode that can be played), so Mudlick Marsh (6) is open | 2 | 3 per stat | 1,500 coins, 2 gems | Commons |
| `mid` | three regions (levels 1-15) the same way on Medium; Frostbite Pass (16) open | 4 | 8 | 8,000, 5 | up to Uncommon |
| `late` | five regions (1-25) fully beaten on Medium; Blast Pits (26) open | 7 | 14 | 40,000, 12 | up to Epic |
| `maxed` | all 30 levels beaten on Hard, every car has cleared every mode (`meta.carClears`) | all 9 | 20 (max) | 1,000,000, 99 | all |

Modes are credited on Medium (the finales ask for it), and only modes a level plays that are built (`CareerStart.beatenModes`), as play would.

Pickups open down each tree from its root, so none is open while its parent is locked (`CareerStart.build`).

`--coins=`, `--gems=`, `--cars=`, `--upgrades=` and `--levels=` override a tier. `--save=<path>` starts from a copy of any save file instead (the file is only read). Progress always goes to a scratch save, `user://playtest/<tag>_save.tres`.

| Option | Default | |
|---|---|---|
| `--persona=` | `rookie` | `rookie`, `grinder` or `explorer` |
| `--start=` | `fresh` | a tier above |
| `--sessions=N` | 30 | runs to play (one garage visit and one run each) |
| `--minutes=N` | none | stop after this much level time |
| `--seed=N` | 1 | run *k* uses map seed N + *k*; the persona's own choices use a generator seeded from it |
| `--tag=` | `career_<persona>_<start>` | names the output files |
| `--sight`, `--max-seconds` | | as for playtests |

### How it plays the menus

Menus get only what a player sends:
- **Keys and pads:** an input action (`KeyHint.fire`), which `_input` handlers, the GUI and polling all see.
- **Mouse:** a move, then a button down and up, pushed into the viewport at the control's centre.

It never calls menu functions. A menu a player can't work blocks the persona too, and each block is reported as an issue. Before every click it checks which control the mouse is actually over. A click that would land on something else is a `mouse` issue: the "everything works with the mouse alone" rule, tested.

Waits run on game time and real time together. A wait gives up only when both have passed: 5–20 s for menus and 120 s for a run to start. Three sessions in a row that end in a block stop the career. After a single block it changes scene to the main menu and carries on, as restarting the game would.

### What it checks

After every run:
- The bank grew by exactly the run's payout.
- Gems changed by the run's gems, less the starting gadget.
- A win marked the mode beaten and opened the next level.
- Nothing in the bank went negative.
- The save on disk loads back equal to the one in memory.

Every purchase must move the bank by its price and the stat by one level. Every pausing screen must close. A run paused with no menu open for 10 s is a `softlock`, and the harness unpauses it. Script and engine errors are caught by an `OS` logger, counted by message.

### Output (`user://playtest/`)

- `results<tag>.csv`: one row per run, the playtest columns plus `persona` and `session`.
- `<tag>_events.log`: every press, click, purchase, screen and issue, by frame.
- `<tag>_summary.json`, also printed as `CAREER_SUMMARY`:
  - progress at the start and end (`CareerStart.progress`)
  - **milestones** (each car bought, level opened, mode beaten and pickup unlocked, with the session and minutes of level time it took)
  - `unlock_pace`: per kind of milestone (car, level, beat, pickup), how many and the first and last minute
  - `longest_runs_without_progress`, where this player stalls
  - per mode: runs, wins and coins per minute
  - shopping totals (cars and upgrades bought in the garage, upgrades on the driver focus's bench, and pickup unlocks bought on the Pickups screen, with their coins)
  - issues by kind (`block`, `ui`, `mouse`, `economy`, `progress`, `save`, `softlock`, `no_run`)
  - script errors

**Playing it yourself.** In a debug build, open the console (backtick) in the menu and type `start late` (`start` lists the tiers, `start real` goes back to your save), or launch with `Godot_console.exe --path . -- --play-start=late`. Either gives you the `late` tier's progress on a scratch save, `user://playtest/human_late_save.tres`. Your real save isn't touched. Later launches with the same tier carry on from where you left it, and `--fresh` rebuilds it. The tier overrides (`--coins=` and so on) work here too. Runs land in `runlog.csv` as `driver = player`, to set beside the personas' rows.

Lines to grep: `CAREER_RUN`, `CAREER_SHOP`, `CAREER_SCREEN`, `CAREER_ISSUE`, `CAREER_MILESTONE`, `CAREER_SUMMARY`.

## How it drives

The car's controller calls `AIDriver.think()` every physics tick, then reads the keys from `isPressed()` instead of the keyboard. The driver works in four layers.

1. **Goal**, 4 times a second: what to go for.
2. **Route**: how to get there across the map, round water and walls.
3. **Control**, 7.5 times a second (`scanTicks`): which keys to hold for the next moment.
4. **Recovery**: getting unstuck.

### What it can see (`--sight=human`)

- By day, it sees what is on screen: the camera's view around the car.
- At night, it sees what is in the headlight beam (about 2000 px, scaled by the Headlights stat, ±26°) or within 350 px of the car.
- Pickups it has seen stay known until they are taken or their chunk unloads.
- The station is always known, as it is to a player through the indicator arrow.
- The terrain map is known, as it is to a player who knows the level.

`--sight=full` sees everything within 4000 px, day or night. It is useful for separating "the AI can't see it" from "the AI can't do it".

### How it reads the world

- **Route:** `AIRoute.forWorld` shares the `WorldMap`'s own `AStarGrid2D` (1280 px coarse cells, built with the map on a worker): water and walls are solid, the rest weighted by the terrain table's `routeWeight` (sand and mud 1.4, mud pits 2), and the map's fords, bridges and passes are open cells, so routes use them. Diagonals never cut a blocked corner.
- **Ground:** `World.terrainAt` reads the 128 px fine raster where the chunk is loaded, else the coarse cell. `footprintTerrain` takes the worst ground under the car's centre and four corners (plus 40 px): deep water first, then a wall, then wading depth, then shallows.
- **Handling:** the prediction runs `integrate()`, which reads the surface under each predicted position, so ice, oil, conveyors and the off-road rule are in every plan without extra rules.
- **Water:** see "Deep water" in the goal rules and the sweeps below; the lookups are `WorldHooks.nearLethal` and `lethalAhead`, plain grid reads.
- **Breakables:** fences, hedges, hay bales, crates and barricades are walls to the physics but passable to the planner at speed (below).
- **Regions:** roam points come from the map's districts (`WorldMap.districtOfCell`).

### Goal rules

Every candidate is scored **value ÷ (seconds to get there + 1)**. The current goal keeps a 30% bonus, so the driver doesn't flip between goals.

- **Seconds to get there:** distance at cruise speed, plus 0.6 s per radian the car must turn. A target inside the car's turning circle also costs the time of a full loop, because chasing it means orbiting it.
- **Pickup values** (a goon crush is about 12 points):
  - Fuel is worth 4 points, plus 2–8 points per unit of fuel the tank can actually hold. The rate rises the more fuel the rest of the run needs.
  - Health works the same way, with more value below 60 health.
  - A purse is worth 60, a slot machine 50, a gem 25, an Engine pickup 10 and a coin 5; any other pickup its `ai` worth in `Pickups.DATA`, else 7.
- **Pickups among obstacles** (a wall or a solid prop within 450 px; a breakable that isn't explosive doesn't count):
  - They are slow and risky, so their time estimate gets 4 s longer.
  - Under 20 points they are skipped altogether. A coin isn't worth a pocket of walls.
  - The car approaches them at 260 px/s.
- **Goons:** 14 points, plus 4 for each other goon within 350 px (up to 6), for goons within 3000 px.
  - Each goon has its own crush speed (`Walker.crushSpeed`, 100–400 px/s), or a higher one head-on while its front armor is up, and some are invulnerable for a while (`AIDriver.crushNeed`). A goon this car can't reach the speed to crush is never a goal. It stays in the obstacle sweeps, since hitting it bounces the car and hurts.
  - While the goal is a goon, the throttle may go 15% past its crush speed, whatever fuel saving says.
  - Goons only die by being crushed, so every goon left alive joins the horde. Crushing is also the defence.
  - Below a health reserve the car stops hunting and steers around goons like rocks (protect mode). The reserve is 10 + 0.04 × the seconds left in Countdown, 20 in races and 25 otherwise.
- **Deep water:** pickups and roam or patrol points within 400 px of deep water are skipped (`waterTargetPx`; a bridge deck is fine), and goons within 350 px of it aren't hunted (`waterGoonPx`): they drown on their own. Above 340 px/s the throttle lifts while deep water lies ahead within 1.35 s of travel (`waterSpeed`).
- **Unreachable goals:** a goal chased for 2.5× its estimated time (at least 3 s) is dropped for 10 s. One the car gets stuck on twice is dropped for the rest of the run.

### Mode rules

- **Countdown and Goonpocalypse: roaming.**
  - Waves are one clock for the whole run (`Region.wave`): each 60 s survived pays a star wherever the car is, so no district is worth more than another.
  - With nothing better in sight, the car roams to a reachable point (`pickRoamPoint`).
  - Roam points are at least 6000 px away and preferably ahead. Long straight runs meet fresh goons with the bumper, since 4 of the 5 spawners are 4000 px ahead of the car, and they leave the horde behind.
- **Sprint and Marathon: the station.**
  - The station is the objective. The time needed is the A* route length at cruise speed. In Marathon the station moves on after each stop; the station graph is rebuilt when `Root.station` changes.
  - **Spare time** is the clock left minus the time the rest of the route needs. After the first 10 s of a leg, the time needed comes from the progress the car has really made toward the station on this leg (detours, rocks and turns included), not its cruise speed. Before this, the driver thought it had about a minute to spare when it had none.
  - **Detours** must fit in 15% of the spare time, up to 8 s each. All detours on one leg together may use only `raceDetourShare` (30%) of the spare time the leg started with, so a chain of small goon detours can't eat the clock. A needed fuel can may cost three times the single-detour limit.
  - **Goons** are worth `raceGoonScale` (0.4) of their usual value as a goal. Crushing those met on the way still pays through the plans' `crushReward`.
- **Station approach.**
  - The lot is walled with one gap. The car keeps a small visibility graph: the driveway, two markers 1100 and 2000 px out in front of the gap, and four corners clear of the lot.
  - Points are joined wherever a car-wide sweep is clear, and the driveway and inner marker can only be entered from within 34° of the gap's line.
  - The car steers along the shortest way through the graph and slows to 450 px/s within 2500 px. It goes round the lot and turns in lined up, instead of pushing into a wall or reaching the gap side-on.
- **Defense:** the car patrols 500–1100 px from the base. Goons beyond `defenseRingPx` (2500 px) from it are ignored. Nearer ones are worth up to `defenseThreat` (3) times more the closer they are, and double within `DEFENSE_BLAST_PX` (500 px) of a pump, where they are about to blow up. It doesn't park to refuel yet.

### Fuel rules: pulse and glide

- Holding speed *v* needs the throttle a share *duty(v) = (drag·v² + friction·v) / engine force* of the time. Fuel only burns under throttle, so a slower car burns far less per second, and less per px.
- **Countdown:** the driver solves for the speed the tank can sustain until the clock ends, allowing for 15% more fuel turning up, and holds the throttle only below it. A stock sedan holds about 430 px/s from the start (top speed 744).
- **Races:** the cap is the fastest speed whose fuel per px covers the route. The clock sets a floor: never slower than the station's distance ÷ time left × 1.15.
- **Floor and exception:** the cap is never below 250 px/s, and there is no cap while a known fuel pickup within 3000 px is still worth going for.

### Control rules: plan, predict, score

- **Candidate plans,** re-chosen 7.5 times a second:
  - Straight, or left or right for a tap (0.1 s), a turn (0.3 s), a swerve (0.6 s, the usual way round a rock) or the whole plan, each with full throttle.
  - Straight, left or right while braking.
  - Three reverse plans, weighed whenever the car is nearly stopped (under 60 px/s: three-point turns), when it is slow and every forward plan hits something within 1 s, or during an escape.
- **Prediction:** each plan is simulated 0.75 s ahead (`horizonTicks`), tick by tick, with the car's own physics, `OverheadCarBody2D.integrate()`, and the controller's key rules (`playerCarController.nextSteering`). The prediction therefore includes the steering ramp, tyre slip, drag and terrain friction, and any handling change made inside `integrate()`.
- **Sweeps:** the predicted path is swept in 0.1 s segments with the car's footprint against everything solid on layer 1: the chunks' wall pieces, props and the station.
  - Godot's `cast_motion` ignores anything the shape already overlaps, so each segment first tests for overlap with the exact footprint.
  - **Breakable props** (fence, hedge, hay bale, crate, barricade) are passable when the predicted speed at that point is at least `smashMargin` (1.15) × the prop's smash speed: the sweep looks up what it touched (`get_rest_info`), leaves the prop out and sweeps on, and the plan pays `smashCost` (0.25 s) per prop. Slower, it is a wall. Explosives (barrel, tank) are always walls. Standing cones count the same way at `smashMargin` × `PropReactions.KNOCK_SPEED` (they knock over and the car keeps its speed; `PropReactions.isKnockable`). Pickups among breakables don't count as "among rocks".
  - Deep water under the car's centre ends the plan with a death cost (`LETHAL_COST`): the car survives a short swim now (about 33 health a second, docs/WORLD.md "Water"), but the driver never plans through deep water. A car already in it (shoved in by goons, or slid in) pays 600 s per second its centre stays wet instead, so the plan that gets it out soonest wins. Under a corner of its footprint (with a 40 px margin) it costs 300 s per second, so when every plan is wet the one that keeps the centre dry wins. Wading depth (WADE, the outer 224 px of deep water on most levels) is driveable: a plan with a wheel in it pays `WADE_COST` (0.8 s per second; shallows `SHALLOWS_COST`, 0.3), and the prediction feels its drag and lost grip through `integrate()`.
  - **Deep water ahead** (`waterAheadCost`): at each 0.1 s point of a plan, deep water along the direction of travel within 0.9 s of travel (`waterLookSeconds`) costs up to 8 s per second (`waterNearCost`), more the closer and the faster. The end-of-plan probe charges for deep water like a wall, twice over. At 700 px/s on shallows the car can't stop in the 256 px band (and the wading band after it), so this is what makes it brake or turn while it still can.
- **A plan's cost** is its estimated seconds to the goal:
  - Time used, plus the rest of the way at cruise speed, plus the time lost getting back up to cruise speed, (c − v)² / (2ac).
  - Plus 0.6 s per radian still to turn.
  - Plus a hit cost that grows with impact speed, and a large cost for water.
  - Plus 1.5 s per second per goon within 350 px while below crush speed. A slow car among goons is chewed up: every touch costs health and crushes nothing.
  - Plus a smaller cost per goon beside the path, inside lunge range but outside the bumper, doubled if it is already winding up an attack.
  - Plus 0.5 s per second spent rolling backwards (`reverseCost`): forwards is preferred, backing up is not ruled out.
  - Minus 1.5 s for each goon the plan would meet with the bumper at 10% over that goon's crush speed (`crushReward`), so of two otherwise equal plans the car takes the one through goons. A goon met too slowly to crush adds half a wall hit instead: it would bounce the car.
  - Plus up to 4 s (`probeCost`, more the closer it is) if a car-wide straight sweep from the plan's end, along where it ends up pointing, finds a rock or wall. The sweep reaches 1,600 px from the car (`lookaheadPx`), or 1.5 s of travel at the end speed if that is further (`probeSeconds`). A stock sedan at full speed needs about 800 px to brake or swerve round a rock, so this is what makes it start steering early. Simulating every plan that far tick by tick would be several times dearer, which is why the far part is a sweep.
- **Goons in the sweeps:** they are left out, because they are targets. A slow car should floor it through, since crush speed takes a third of a second. Protect mode puts them back in.

### Recovery rules

- **Stuck:** moving less than 150 px in 2.5 s. The car drops its current pickup or goon goal and, for 1 s, takes the forward plan with the most room if one has at least 0.5 s clear (`recoverForward`); only otherwise does it reverse on the reverse plan with the most room.
- **Water:** neither the recovery plan (the one with the most room stops counting at deep water) nor an escape point (never a lethal trail point) leads into deep water.
- **Escape:** three stuck events in 20 s. The car drives back to where its breadcrumb trail was at least 6 s and 600 px ago, the way it came in, which is known to be drivable. Reversing is allowed until it gets there.

## Limits

- **New pickups:** the driver values pickups by their registry `ai` worth but has no plan for events, and its gadget use is a few crowd rules (`Gadgets.aiWantsUse`, `aiWantsMove`).
- **Routes are the same for every car:** `AIRoute` shares the map's one weighted grid, so the pickup doesn't prefer the rough it barely feels and the supercar doesn't avoid it.
- **Drift:** plans know how long they slide, not the boost a release fires or the score's tiers. The handbrake's catch and a spin into a wall are predicted (`integrate()`); the drift charge is not.
- **Manual shifting:** predictions use the shift points without their slop, the kick or the cut, so a clumsy shifter's plans are a little optimistic.
- **Goon changes** need the goon rules re-checked (lunge range, crush rules, what is safe to touch); handling changes are followed automatically through `integrate()` and `carBodyArea`.
- **Horizon:** the planner simulates 0.75 s and sweeps on to 1,600 px; long walls are left to the route, the station graph and the breadcrumb escape.
- **CPU:** simulating plans is most of the cost (several hundred ms per game second on a busy dev box), so `ai` in the console can lower the frame rate. Plans that share a beginning could share its simulation.
- **Pockets:** the escape gets out of most, but can lose 10–20 s in one.
- **Defense:** it hunts goons by their threat to the base but doesn't guard lanes or park to refuel. The score's Defense line still uses survival out of 300 s, though Defense counts down and is won at 0.
- **Water margins:** pickups within 400 px of deep water are skipped, which on Snapper Bayou leaves fuel behind.
- **Rivals:** they don't know their place in a race, and each is a full planner (one more than 3,200 px from the player plans half as often, `AIDriver.scanEvery`). The cost of six drivers on the low-end target is not measured.
