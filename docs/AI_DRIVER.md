# AI driver and playtest harness

The AI driver plays GoonCrusher like a player does: it holds the same four digital keys, sees only what a player could see, and has to live with the same physics, rocks, water, goons, fuel and clock. Its first job is automated playtesting, where it plays real runs headless and reports what happened. It is also built so it could drive a rival car later (see the end).

- `scripts/ai/ai_driver.gd` (`AIDriver`): the driver. One node, attached to a car.
- `scripts/ai/ai_route.gd` (`AIRoute`): the long-range route planner (A* over the terrain map).
- `scripts/debug/playtest.gd` (autoload `Playtest`): the harness that plays and records runs.
- `tests/game/test_ai_driver.gd`: the route planner, the prediction and the scoring rules.

## Running playtests

```
Godot_console.exe --headless --fixed-fps 60 --path . -- --playtest --uncapped --mode=countdown,sprint --runs=8
```

`--headless --fixed-fps 60` runs the game as fast as the CPU allows, with every frame still 1/60 s of game time. A 250 s Countdown takes about 15–30 s on the dev box. `--uncapped` stops the saved frame cap from slowing it.

| Option | Default | |
|---|---|---|
| `--level=a,b` | `level_grass_1` | level scene names in `scene/level/levels/` |
| `--mode=a,b` | `countdown` | `countdown`, `sprint`, `goonpocalypse`, `marathon`, `defense` |
| `--car=a,b` | `sedan` | car names from the save (`sedan`, `van`, `police`, ...) |
| `--runs=N` | 1 | runs per level × mode × car |
| `--seed=N` | 1 | first map seed; run *k* uses seed + *k* |
| `--upgrades=N` or `save` | 0 | every stat upgraded to level N (0 = stock car), or the save's own upgrades |
| `--sight=human` or `full` | `human` | what the driver may see (below) |
| `--max-seconds=N` | 900 | level time after which a run is cut short (`TIMEOUT`) |
| `--tag=name` | none | results go to `results<name>.csv` |
| `--trace` | off | prints the driver's state and every plan's cost each second, each wall hit and stuck event, and an ASCII map of the terrain |
| `--ai-debug` | off | draws the chosen plan, goal and route (needs a window, not `--headless`) |

Each run appends one row to `user://playtest/results<tag>.csv` (`%APPDATA%/GoonCrusher/playtest/`) and prints `PLAYTEST_RESULT {json}`. When every run is done, it prints one `PLAYTEST_SUMMARY` per level/mode/car with wins, endings and averages. Progress goes to a scratch save, so the real save is never touched. A seed rebuilds the same map, and with `--fixed-fps` it usually replays the same run. Exact replays aren't guaranteed, because the terrain is built on a worker thread.

Write long runs to a file (`> out.txt`) rather than capturing them in a shell variable.

### What a row records

- **Ending:** `reason` is `SUCCESS`, `NOHEALTH`, `NOGAS`, `NOTIME`, `ABANDONED`, `WATER` (drowned: a `NOHEALTH` with health left) or `TIMEOUT`. Also `won`, `level_time`, the starting `clock`, `time_left`, and for races `station_px` and `route_reached` (false when the station is cut off by water).
- **Score:** `crushed`, `coin`, `star`, `payout`, `gem`, `slot_machines`, and pickups by kind (`fuel_pickups`, `health_pickups`, `purses`, `coins_picked`, `gems_picked`, `stat_pickups`). Slot machine prizes count as pickups.
- **Damage**, as health lost, split by what the car was touching at the time:
  - `damage_rocks`: rocks, walls and hills.
  - `damage_goon_contact`: the car ran into a goon. Every crush costs the car health too.
  - `damage_goon_attacks`: a goon lunged into the car's body.
  - `crush_misses`: goons the car hit at over 200 px/s that survived.
- **Resources:** `min_fuel`, `min_health`, `end_fuel`, `end_health`.
- **Driving:** `distance_px`, `avg_speed`, `top_speed`, `eco_seconds` (time spent saving fuel), `stuck`, `escapes`, and `goals` (how often it chose each kind of goal).

## How it drives

The car's controller calls `AIDriver.think()` every physics tick, then reads the keys from `isPressed()` instead of the keyboard. The driver works in four layers.

1. **Goal**, 4 times a second: what to go for.
2. **Route**: how to get there across the map without water.
3. **Control**, 10 times a second: which keys to hold for the next moment.
4. **Recovery**: getting unstuck.

### What it can see (`--sight=human`)

- By day, it sees what is on screen: the camera's view around the car.
- At night, it sees what is in the headlight beam (about 2000 px, scaled by the Headlights stat, ±26°) or within 350 px of the car.
- Pickups it has seen stay known until they are taken or their chunk unloads.
- The station is always known, as it is to a player through the indicator arrow.
- The terrain map is known, as it is to a player who knows the level.

`--sight=full` sees everything within 4000 px, day or night. It is useful for separating "the AI can't see it" from "the AI can't do it".

### Goal rules

Every candidate is scored **value ÷ (seconds to get there + 1)**. The current goal keeps a 30% bonus, so the driver doesn't flip between goals.

- **Seconds to get there:** distance at cruise speed, plus 0.6 s per radian the car must turn. A target inside the car's turning circle also costs the time of a full loop, because chasing it means orbiting it.
- **Pickup values** (a goon crush is about 12 points):
  - Fuel is worth 4 points, plus 2–8 points per unit of fuel the tank can actually hold. The rate rises the more fuel the rest of the run needs.
  - Health works the same way, with more value below 60 health.
  - A purse is worth 60, a slot machine 50, a gem 25, an Engine pickup 10, any other stat 7 and a coin 5.
- **Pickups among rocks** (a rock within 450 px, such as fuel inside a rock ring):
  - They are slow and risky, so their time estimate gets 4 s longer.
  - Under 20 points they are skipped altogether. A coin isn't worth a pocket of rocks.
  - The car approaches them at 260 px/s.
- **Goons:** 12 points, plus 4 for each other goon within 350 px (up to 6), for goons within 2500 px.
  - Goons only die by being crushed, so every goon left alive joins the horde. Crushing is also the defence.
  - Below a health reserve the car stops hunting and steers around goons like rocks (protect mode). The reserve is 10 + 0.04 × the seconds left in Countdown, 20 in races and 25 otherwise.
- **Unreachable goals:** a goal chased for 2.5× its estimated time (at least 3 s) is dropped for 10 s. One the car gets stuck on twice is dropped for the rest of the run.

### Mode rules

- **Countdown and Goonpocalypse: region stars.**
  - A region pays a star for each 60 s spent in it, up to 3, and payout is coins × stars.
  - With nothing better in sight, the car roams to a land point it can reach in the same region until that region has paid out. Then it heads for a region that hasn't.
  - Roam points are at least 6000 px away and preferably ahead. Long straight runs meet fresh goons with the bumper, since 4 of the 5 spawners are 4000 px ahead of the car, and they leave the horde behind.
- **Sprint and Marathon: the station.**
  - The station is the objective. The time needed is the A* route length at cruise speed.
  - Detours are allowed only if they fit in 15% of the spare time, up to 8 s. A needed fuel can may cost three times that.
- **Station approach.**
  - The lot is walled with one gap. The car keeps a small visibility graph: the driveway, two markers 1100 and 2000 px out in front of the gap, and four corners clear of the lot.
  - Points are joined wherever a car-wide sweep is clear, and the driveway and inner marker can only be entered from within 34° of the gap's line.
  - The car steers along the shortest way through the graph and slows to 450 px/s within 2500 px. It goes round the lot and turns in lined up, instead of pushing into a wall or reaching the gap side-on.
- **Defense:** the car patrols within 600–1800 px of the base and crushes what comes. The mode is unfinished.

### Fuel rules: pulse and glide

- Holding speed *v* needs the throttle a share *duty(v) = (drag·v² + friction·v) / engine force* of the time. Fuel only burns under throttle, so a slower car burns far less per second, and less per px.
- **Countdown:** the driver solves for the speed the tank can sustain until the clock ends, allowing for 15% more fuel turning up, and holds the throttle only below it. A stock sedan holds about 430 px/s from the start (top speed 744).
- **Races:** the cap is the fastest speed whose fuel per px covers the route. The clock sets a floor: never slower than the station's distance ÷ time left × 1.15.
- **Floor and exception:** the cap is never below 250 px/s, and there is no cap while a known fuel pickup within 3000 px is still worth going for.

### Control rules: plan, predict, score

- **Candidate plans,** re-chosen 10 times a second:
  - Straight, or a tap, a turn or a full hold of left or right, each with full throttle.
  - Straight, left or right while braking.
  - Three reverse plans, offered only when every forward plan hits something within 0.4 s, or during an escape. Reversing is for leaving a pocket, not for driving.
- **Prediction:** each plan is simulated 1 s ahead with the car's own physics, `OverheadCarBody2D.integrate()`, and the controller's key rules (`playerCarController.nextSteering`). The prediction therefore includes the steering ramp, tyre slip, drag and terrain friction, and any handling change made inside `integrate()`.
- **Sweeps:** the predicted path is swept in 0.1 s segments with the car's footprint against rocks, walls and hills.
  - Godot's `cast_motion` ignores anything the shape already overlaps, so each segment first tests for overlap with the exact footprint.
  - Water anywhere under the car is treated as death.
- **A plan's cost** is its estimated seconds to the goal:
  - Time used, plus the rest of the way at cruise speed, plus the time lost getting back up to cruise speed, (c − v)² / (2ac).
  - Plus 0.6 s per radian still to turn.
  - Plus a hit cost that grows with impact speed, and a large cost for water.
  - Plus 1.5 s per second per goon within 350 px while below crush speed. A slow car among goons is chewed up: every touch costs health and crushes nothing.
  - Plus a smaller cost per goon beside the path, inside lunge range but outside the bumper, doubled if it is already winding up an attack.
- **Goons in the sweeps:** they are left out, because they are targets. A slow car should floor it through, since crush speed takes a third of a second. Protect mode puts them back in.

### Recovery rules

- **Stuck:** moving less than 150 px in 2.5 s. The car reverses for 1 s on the reverse plan with the most room and drops its current pickup or goon goal.
- **Escape:** three stuck events in 20 s. The car drives back to where its breadcrumb trail was at least 6 s and 600 px ago, the way it came in, which is known to be drivable. Reversing is allowed until it gets there.

## What the playtests show

Snapshot from 2026-10-05: `level_grass_1`, stock sedan, human sight, 8 runs per mode (seeds 101–108). It ran on that day's working tree, which already had the car-art session's zone damage and not yet the goon overhaul, and before the last fix to fuel saving. Damage is health lost, averaged per run.

| Mode | Result | Avg time | Crushed | Payout | Rocks | Goon contact | Goon attacks |
|---|---|---|---|---|---|---|---|
| Countdown (250 s) | 0 of 8 survived | 84 s | 18.5 | 55 | 14.6 | 11.9 | 110.0 |
| Sprint (~86 s clock) | 5 of 8 won (2 wrecked, 1 out of time) | 67 s | 7.0 | 21 | 6.6 | 3.5 | 52.6 |
| Goonpocalypse | survived 90 s on average (best 136 s) | 90 s | 19.3 | 108 | 0.6 | 22.0 | 133.4 |

1. **Goon attacks do most of the damage**: about 80% of the health lost in Countdown and Goonpocalypse. Only the car's front bumper crushes. Goons lunge into its body area, a box bigger than the bumper, and a goon in its attack deals its attack damage on every slide collision on every tick. A crowd on a stalled car therefore takes health off very fast; one trace went from 84 to 19 in one second. The goon overhaul may want per-attack damage or a per-goon cooldown.
2. **Countdown on the easiest level isn't survivable for this driver in a stock sedan.** Its best run lasted 172 s of 250. The comparison that matters is your own play. If you survive it comfortably, the driver has more to learn. If you don't, Countdown on Easy is too hard for a stock car.
3. **Crushing costs health:** 0.35 per crush for the sedan (`damage(5)` on contact, before armor). A run that crushes 200 goons pays 70 health for it.
4. **Rocks are mostly handled.** Wall damage is 0–15 per run, except for pickups inside rock rings, which remain the main trap. The worst run hit rocks for 113 damage in 22 s chasing one.
5. **The station is hard to drive into.** It is a walled lot with a single gap on its east side, while the indicator points at its centre. The AI needed a dedicated approach rule, and players arriving from the west have to find their way round. An arrow to the gap, or a second gap, would help.
6. **Sprint is lost to goons, not to the clock.** Winners arrived with 6–33 s to spare, and two of the three losses were wrecks.
7. **`crush_misses` was 0 in every run**: every hit over 200 px/s crushed.
8. **Fuel** never ended a snapshot run. A later replay ran dry because fuel saving switched off for a far-off fuel can. That is now fixed: only a nearby one counts.

## Limits and next steps

- **Moving target.** The car's zone damage model and the goon overhaul were both in progress when these rules were tuned. The driver follows handling changes automatically, because it predicts with `integrate()` and reads its footprint from `carBodyArea`. Goon behaviour changes need the goon rules re-checked: lunge range, crush rules, and what is safe to touch.
- **Prediction horizon.** The local planner looks 1 s ahead. Long walls and rock fields are handled by the route, the station graph and the breadcrumb escape, not by the planner.
- **Pockets.** The breadcrumb escape gets out of most rock pockets, but it can still lose 10–20 s in one, and that is often what lets the horde catch up.
- **Defense and Marathon** have only basic rules, like the modes themselves.
- **AI rivals.** The driver can steer any `OverheadCarBody2D` whose controller has a `driver`. A rival car would also need:
  - `isPlayer = false` and its own camera not current.
  - Its controller not touching the player HUD.
  - The goons, the spawners and the despawn sweep no longer assuming one `Root.playerCar`.
  - Damage, reward and crush code that doesn't assume the player.
  - A difficulty knob: reaction time (plan every *N* ticks), sight, and noise on the chosen plan.
