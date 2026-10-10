# Game modes

The 19 modes, their tiers, what a win opens, how a run ends and what it pays. The design plan with every mode's pitch is linked from docs/GAMEPLAY_SUGGESTIONS.md, package 18, which also lists what is left. How the AI plays each mode: docs/AI_DRIVER.md. The run setup screens: docs/UI.md.

## Where it lives

| What | Where |
|---|---|
| The mode list (append only) | `Root.gameModes` |
| Each mode's id, category, words and design rules | `Modes.DATA` (`scripts/global/modes.gd`) |
| Each mode's numbers per tier | `ModeTiers` (`scripts/global/mode_tiers.gd`) |
| A level's three featured modes | `LevelDef.featured` (`world/levels/<id>.tres`) |
| The run's own level, mode and tier | `Level.runLevel`, `runMode`, `tier` |

Three categories: **Crusher** (goons are the point), **Trial** (no goons: the course and the clock) and **Goon Cup** (other drivers).

- **The mode order:** every level plays Sprint, then Countdown, then its three featured modes, one per category. `Root.modePath(level)` is the one order every menu, harness and test reads.
- **Variants** run on their base mode's rules (`Modes.plays`: Blackout plays Countdown; Rally Stage, Flat Out, Cannonball and Pursuit play Sprint).
- **A Trial** has no goons, drops, night or fuel burn (`Modes.isTrial`, `hasGoons`, `drops`). Run code branches on `Modes.running()`, never on the save's mode.
- **Availability:** `Root.MODE_AVAILABLE` switches a mode off ("Coming Soon"); all 19 are on, as untuned first versions. `Root.isModePlayable` combines it with the unlock.
- **The demo** (`Root.IS_DEMO`) has the first 10 levels (two regions) and every mode they feature.

## Unlocks

- **Modes** (`Root.isModeUnlocked`): Sprint, then Countdown, then the three featured.
- **Levels** (`Root.opensNextLevel`, `openRuleText`, `openLeftText`): any featured mode won on a level opens the next (`Root.roadModes`), on Medium at a region's finale (stop 5). `SaveManager.currentLevelPassed` credits the run's own level, mode and tier.
- **Car clears** (`meta.carClears`; `SaveManager.carClearTier`, `carsCleared`, `isFullGarage`): a win also credits the car. A new car's first clear pays coins; every car clearing a mode, level and tier is a Full Garage, which pays gems.

## Tiers

Every mode on every level has Easy, Medium and Hard completions, picked in Level Options (`PlayerData.gameTier`). The tier sets the goal and the world's toughness (`Level.tier`), pays a win bonus and a first-clear bonus, and shows as bronze, silver and gold medals. `gamemodeBeat` stays "beaten on any tier"; the level entry's `tiers` keeps the best.

## Endings and pay

Everything ends through `levelRoot.endLevel()`, once (`hasEnded`). The clock (`Timer.gd`) counts down except in Goonpocalypse; at 0 `Level.timeUpCondition` decides.

| Mode | Ends |
|---|---|
| Countdown | Won when the clock runs out. |
| Sprint | Won at the station driveway, lost at 0. The station is further off on the harder tiers (`ModeTiers.SPRINT_DISTANCE`); the clock comes from the A* route. |
| Marathon | `Level.legs()` legs by tier (`Level.stationReached`); lost at 0. The station lot has no walls. |
| Defense | Won when the clock runs out; lost when the station barrier (`station.gd`) hits 0. Goons march on the pumps and blow up there (`Walker.siege`, `station.siegeStep`, `station.BLAST_DAMAGE`). |
| Goonpocalypse | Endless; beaten by surviving `ModeTiers.POCALYPSE_TARGET` seconds, after which it escalates harder (`SpawnManager.overtime`). |

`gameSummary` credits `Level.runPayout(won)` = (coin + the tier's win bonus when won) × (1 + 0.1 × star, at most ×3) (`Root.computePayout`, `STAR_BONUS`, `STAR_MULT_MAX`), plus a first-clear bonus and any car clear bonus. Debug builds append the run to `user://runlog.csv`. Every run with a course, a score or marks prints a `RUN_GOAL` line when it ends, for the harnesses' logs.

## The other modes, as first built

Numbers are Easy / Medium / Hard. None is tuned.

- **Blackout** (plays Countdown): night from start to end.
- **Bounty Hunt** (`BountyHunt`, `Level.bounty`): 3 / 4 / 5 marks, one at a time, 80 / 70 / 60 s of clock each. A mark is a giant from the level's line-up, weakest first, with a red ring and an escort, 3,200 px off and 500 further each time. It is never swept, and only a death the car caused counts (`Walker.deathCause`).
- **Courses and the record book** (`Course`, `Level.course`): a fixed-map mode gets its world seed from the level and mode (`Course.seedFor`), checkpoints every 5,000 px along the route (inside 650 px, in order), a split banner against the driver's best, and a record per level, mode and car (`meta.records.course`, `SaveManager.bestCourse`, `recordCourse`).
- **Rally Stage** (plays Sprint): one course for all three medals, a Marathon leg long; the clock is the Sprint clock × `ModeTiers.RALLY_SLACK`.
- **Flat Out** (plays Sprint): due east to the station, a nitro at every checkpoint, `FLATOUT_SLACK`; crossing the line over 420 px/s adds 2 s.
- **Cone Course** (`ConeCourse`): a cleared lot with no station; 30 gates of two cones in three slalom lanes (pass within 105 px of the middle); a knocked cone takes a second off the clock; 90 / 70 / 55 s.
- **Smash Run** and **Drift Trial** (`TrialScore`, `Level.trial`): reach a score before the clock runs out; the time to the target is the record. Smash Run: 15 / 25 / 35 breakables in 150 s. Drift Trial: a chain banks when a held slide of 20 ticks or more ends (speed / 100 a tick, doubled from the blue sparks, tripled from the orange); 1,500 / 3,000 / 5,000 in 120 s.
- **Loops** (`Course.loopRoute`, `Level.setupLoop`): out to two corners 5,200 px off and back, checkpoints every 4,000 px, driven in laps. **Hot Lap**: 3 laps, the best under the tier's target (`HOTLAP_SLACK`). **Circuit Race**: 3 laps against five rivals, top 3 / 2 / 1. **Knockout**: the last car on each lap is out (`Rivals.eliminate`).
- **Rivals** (`Rivals`, `Level.rivals`): the Goon Cup's other cars are car scenes with `isPlayer` off and an `AIDriver`. Cars bump in `OverheadCarBody2D.bumpCar`: damage by closing speed and where the hit lands (nose 30%, flank or tail all), weight to the power 0.25, armour not at all.
- **Pursuit** (plays Sprint, `Rivals.spawnRunner`): the runner starts 1,600 / 2,200 / 2,800 px ahead with 45 / 60 / 75 health at 78 / 86 / 94% of the player's top speed; cars hit 2.5× harder. Wrecking it wins; it reaching the station loses.
- **Keep the Cup** (`KeepCup`): the cup lies 1,600 px ahead; a car within 130 px takes it, and any car within 230 px of the holder takes it after 2 s. The holder drives at 88% pace. First to 40 / 55 / 70 s wins, inside 240 s.
- **Demolition Derby** (`Derby`): a painted circle 3,400 px in radius on the level's own ground, six cars on a ring facing in, Repair Kits and Nitro at eight spots (back after 18 s; rivals don't collect pickups yet), 12 health a second outside the line, 240 s.
- **Cannonball**: built and played by the AI (docs/AI_DRIVER.md); its rules are not written up yet.

## Trying a mode

`-- --console="start maxed;play derby hard"`, or the same two commands in the console (`start maxed` first, so it plays on a scratch save; bare `play` lists the mode ids).
