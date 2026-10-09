# AI driver and playtest harness

The AI driver plays like a player: it holds the same digital keys, sees only what a player could see, and lives with the same physics, walls, water, goons, fuel and clock. Its job is automated playtesting.

**Profile:** the game (console `ai`), the playtest harness and `tournament.py` all play `AIProfiles.BEST` = `"cautious"` unless `--profiles` names others.

- `scripts/ai/ai_driver.gd` (`AIDriver`): the driver. One node, attached to a car.
- `scripts/ai/ai_route.gd` (`AIRoute`): the long-range route planner (A* over the world's coarse map; docs/WORLD.md).
- `scripts/ai/ai_profiles.gd` (`AIProfiles`): the driver's tuning, as named profiles.
- `scripts/debug/playtest.gd` (autoload `Playtest`): the harness that plays and records runs.
- `scripts/ai/tournament.py`: plays several profiles on the same seeds and ranks them.
- `tests/game/test_ai_driver.gd`: the route planner, the prediction and the scoring rules.

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
| `--mode=a,b` | `countdown` | `countdown`, `sprint`, `goonpocalypse`, `marathon`, `defense` |
| `--car=a,b` | `sedan` | car names from the save (`sedan`, `van`, `police`, ...) |
| `--profiles=a,b` | `cautious` (`AIProfiles.BEST`) | AI profiles to play (below); each is another dimension like car or mode |
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

## Profiles and tournaments

Everything the driver weighs is a parameter in `AIProfiles.DEFAULTS` (`scripts/ai/ai_profiles.gd`), with a comment on each. A profile lists only what it changes from the defaults:

| Profile | Idea |
|---|---|
| `cautious` | **`BEST`.** Keeps health: walls, flanks and slowness among goons cost more; stops hunting sooner. The best all-round profile in the tournaments |
| `default` | the plain `DEFAULTS` (not yet measured in a tournament) |
| `v1` | the driver as first tuned: 1 s plans, a 400 px sweep, no reverse cost or crush reward |
| `crusher` | plays for crushes: goons worth twice as much, flanks matter less, hunts until lower health |
| `farsight` | simulates 2–3 s ahead tick by tick (several times the CPU) |
| `collector` | pickups first: every pickup worth twice as much, goons less |
| `rookie` | a new player (the Rookie persona): keys reach the car 0.2 s late (`reactionTicks`), up to 0.8 s of noise on each plan's cost (`planSlop`) so close calls sometimes go wrong, a shorter look ahead, chases goons |

A spec can change values on the fly without editing the file: `crusher+horizonTicks=120+flankCost=2`. Use one in `--profiles` (separated by commas), in the tournament or in code (`AIDriver.attach(car, {"profile": ...})`).

A tournament plays every profile in every mode on the same seeds, so all of them meet the same maps, and ranks them by score:

```
python scripts/ai/tournament.py --profiles cautious,default,crusher --runs 6
python scripts/ai/tournament.py --profiles "default,default+reverseCost=6" --modes sprint --runs 10 --name reverse
```

Each profile × mode is one headless Godot process, `--parallel` at a time (default 3 of the dev box's 4 threads). The script prints a table per mode and writes every run to `tournament_<name>.csv` next to the per-process logs. `--rerank <csv>` prints the tables of an earlier tournament again, so a change to the score doesn't need a replay.

The score per run is **coins + the mode's result**, because payout (coins × the star multiplier, `Root.computePayout`) is what buys cars and upgrades, and a run pays out even when it is lost. It is computed by `runScore` in `playtest.gd` and again by `run_score` in `tournament.py`; keep the two in step.
- **Coins:** 30 × log10(1 + payout): 60 for 100 coins, 90 for 1,000, 104 for 3,000. The log keeps one huge payout from swamping every other run.
- **Countdown:** plus 50 × the share of the clock survived.
- **Sprint and Marathon:** a win adds 50 + 25 × the share of the clock left; a loss adds up to 25 for the share of the way to the station covered.
- **Goonpocalypse and Defense:** plus 50 × the share of 300 s survived.

To iterate: copy the winner into a new profile, change one or two values, and play it against its parent with more seeds. Differences of a few points over 6 runs are noise. Look at the `+/-` column (the spread of scores) before believing a ranking.

### What a row records

- **Run:** `level`, `mode`, `car`, `profile`, `seed`, `upgrades`, `sight` and `score`.
- **Ending:** `reason` is `SUCCESS`, `NOHEALTH`, `NOGAS`, `NOTIME`, `ABANDONED`, `WATER` (drowned: a `NOHEALTH` with health left) or `TIMEOUT`. Also `won`, `level_time`, the starting `clock`, `time_left`, and for races `station_px`, `station_left_px` (how far from the station it ended) `route_reached` (false when the station is cut off by water) and `legs` (stations reached: 0 or 1 in Sprint, one per leg in Marathon).
- **Score:** `crushed`, `coin`, `star`, `payout`, `gem`, `slot_machines`, and pickups by kind (`fuel_pickups`, `health_pickups`, `purses`, `coins_picked`, `gems_picked`, `stat_pickups`). Slot machine prizes count as pickups.
- **Damage**, as health lost, split by what the car was touching at the time:
  - `damage_rocks`: rocks, walls, hills and props, exactly what the car's wall hits and scrapes took (`wallHealthLost`); a car pinned to a wall by goons counts their attacks as goon damage.
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
| Drives with | `rookie` (late keys, noisy plans) | `cautious` (`BEST`) | `crusher` |
| Menus with | the mouse | keys | both, plus pad glyphs |
| Runs | the obvious next one: the furthest open level's first unbeaten mode in `Root.MODE_PATH` order (Countdown, Sprint, then the Marathon that opens the next level); a finale whose Marathon was won below Medium gets the Marathon again on Medium; then Goonpocalypse and Defense where they are open; after 3 losses in a row there, Countdown on the level before to farm coins | the path while it's winning, else the run that pays most per minute in its own history (20% sampling the others) | the level and mode it has played least, with the car it has driven least |
| Garage | a new car the moment it is affordable, any pickup unlock under half the bank, then the cheapest upgrade going | saves once the next car is within 3 average payouts; meanwhile the pickup unlock with the best `ai` worth per coin (under a third of the bank), then Engine, Armor, Oil, Traction first (no stat more than 2 levels ahead of the lowest) | buys every car to try it, often a random pickup unlock, then the stat it has least of |
| Gems | never | a starting gadget only with 6+ gems, Nitro in the boost slot with 8+ left | gadgets, boosts, new hands, raises at random |
| In-run screens | slot bet 0; in The Deal keeps a card once fewer than half the deck beat it; the nearest claw prize; the first Pit Shop offer it can afford | bets 25 with 400+ run coins; keeps a Deal card worth 20+ (`ai`); the rarest claw prize; supplies in the Pit Shop | random bets; keeps a Deal card it hasn't discovered; extra claw grabs; buys the whole Pit Shop |
| Prize games (all personas) | the claw is dropped as it passes over the persona's prize; the Deal redraws (Q) until the persona's rule keeps a card; the Pit Shop buys in order, stopping at the first offer it doesn't want; Hubcap Shuffle, Goon Press, Pachinko Drop and Coin Pusher (drafts) are tapped through with the action key (`answerTapping`); every game's winnings board is left with Accelerate or a click (`career.gd`, `answer*`, `leaveBoard`) | | |
| Side trips | Goonopedia or records sometimes (15%) | none | Goonopedia (every tab), records and Settings (every tab, changing nothing) every visit; pauses half its runs, opens Settings from pause; abandons 6% of runs |

### Starting points

`--start=` picks a `CareerStart.TIERS` entry. Every tier is a state play can reach: levels open in order, beaten modes follow the unlock chain, and only owned cars carry upgrades.

| Tier | Levels and modes | Cars | Upgrades | Bank | Pickups |
|---|---|---|---|---|---|
| `fresh` | a new save | sedan | none | 0 | the 10 tree roots |
| `early` | The Wilds (levels 1-5) beaten through the Marathon on Medium, so Mudlick Marsh (6) is open | 2 | 3 per stat | 1,500 coins, 2 gems | Commons |
| `mid` | three regions (levels 1-15) through the Marathon and Goonpocalypse on Medium; Frostbite Pass (16) open | 4 | 8 | 8,000, 5 | up to Uncommon |
| `late` | five regions (1-25) fully beaten on Medium; Blast Pits (26) open | 7 | 14 | 40,000, 12 | up to Epic |
| `maxed` | all 30 levels beaten on Hard, every car has cleared every mode (`meta.carClears`) | all 9 | 20 (max) | 1,000,000, 99 | all |

Modes are credited on Medium (the finales ask for it), and Goonpocalypse and Defense only where the Marathon is, as play would.

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
  - shopping totals (cars, upgrades and pickup unlocks bought through the Goonopedia, with their coins)
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
- **Ground:** `World.terrainAt` reads the 128 px fine raster where the chunk is loaded, else the coarse cell. `footprintTerrain` takes the worst ground under the car's centre and four corners (plus 40 px): deep water first, then a wall, then shallows.
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
  - Deep water under the car's centre (the car dies two ticks after its centre is over it) ends the plan with a death cost; under a corner of its footprint (with a 40 px margin) it costs 300 s per second, so when every plan is wet the one that keeps the centre dry wins.
  - **Deep water ahead** (`waterAheadCost`): at each 0.1 s point of a plan, deep water along the direction of travel within 0.9 s of travel (`waterLookSeconds`) costs up to 8 s per second (`waterNearCost`), more the closer and the faster. The end-of-plan probe charges for deep water like a wall, twice over. At 700 px/s on shallows the car can't stop in the 256 px band, so this is what makes it brake or turn while it still can.
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

- **New pickups:** the driver values pickups by their registry `ai` worth but has no plan for events, and its gadget and boost use is a few rules (`Gadgets.aiWantsUse`, `aiWantsMove`).
- **Handbrake:** the driver never pulls it (`isPressed("Handbrake")` is false). `simulate()` leaves `CarInput.handbrake` off, so its predictions stay exact; teaching it to powerslide would mean a new key bit and candidates that hold it.
- **Goon changes** need the goon rules re-checked (lunge range, crush rules, what is safe to touch); handling changes are followed automatically through `integrate()` and `carBodyArea`.
- **Horizon:** the planner simulates 0.75 s and sweeps on to 1,600 px; long walls are left to the route, the station graph and the breadcrumb escape.
- **CPU:** simulating plans is most of the cost (several hundred ms per game second on a busy dev box), so `ai` in the console can lower the frame rate. Plans that share a beginning could share its simulation.
- **Pockets:** the escape gets out of most, but can lose 10–20 s in one.
- **Defense:** it hunts goons by their threat to the base but doesn't guard lanes or park to refuel. The score's Defense line still uses survival out of 300 s, though Defense counts down and is won at 0.
- **Water margins:** pickups within 400 px of deep water are skipped, which on Snapper Bayou leaves fuel behind.
- **Rivals:** a rival car would also need `isPlayer = false`, its own camera off, no player HUD, goons, spawners and the sweep not assuming one `Root.playerCar`, and a difficulty knob (reaction time, sight, plan noise).
