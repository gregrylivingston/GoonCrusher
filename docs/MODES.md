# Game modes

What is left to do on the modes: `docs/roadmap/ROADMAP_MODES.md` (it links the approved design plan). How the AI plays each mode: docs/AI_DRIVER.md.

## Where it lives

| What | Where |
|---|---|
| The mode list (append only) | `Root.gameModes` |
| Each mode's id, category, words and rules | `Modes.DATA` (`scripts/global/modes.gd`; its header explains the keys) |
| Each mode's numbers per tier | `ModeTiers` (`scripts/global/mode_tiers.gd`) |
| A level's two openers and three featured modes | `LevelDef.openers`, `featured` (`world/levels/<id>.tres`); `Modes.openers`, `Modes.featured` |
| Mode and level unlock rules, availability, the demo gate | `Root` (`modePath`, `isModeUnlocked`, `isModePlayable`, `MODE_AVAILABLE`, `opensNextLevel`, `IS_DEMO`) |
| Crediting a win: level, tier, the car's clear | `SaveManager.currentLevelPassed`, `meta.carClears` |
| The run's own level, mode and tier | `Level.runLevel`, `runMode`, `tier` |
| Endings and pay | `Level.endLevel`, `timeUpCondition`, `runPayout`; `Root.computePayout` |
| Per-mode helpers on `Level` | `bounty` (`BountyHunt`), `course` (`Course`, `ConeCourse`: fixed maps, checkpoints, records), `trial` (`TrialScore`), `rivals` (`Rivals`: AI-driven car scenes), `KeepCup`, `Derby` (`scene/level/`) |

## Rules

- **Three categories:** Crusher (goons are the point), Trial (no goons: the course and the clock), Goon Cup (other drivers).
- **One mode order:** every level plays five modes: its two openers (Sprint then Countdown unless the level names others), then its three featured modes, one per category. Every menu, harness and test reads `Root.modePath(level)`; nothing may assume a level has Sprint or Countdown.
- **Openers** are simple modes, and at least one of the two has goons (Trials drop no coins and fill no gift boxes). The first is open with the level, the second opens behind it, the featured three behind the second (`Root.isModeUnlocked` goes by slot).
- **Free Play** (`Root.freePlayOpen`, `freePlayModes`, `Level.freePlay`): all five won on a level opens every other mode there, on any tier. A Free Play run pays its coins, win bonus included, and nothing else: no medal, first-clear or car-clear bonus, record or unlock counter. The results ticket checks `Level.freePlay` before crediting.
- **A variant runs on its base mode's rules** (`Modes.plays`), and a Trial has no goons, drops, night or fuel burn. So run code asks `Modes.running()`, `Modes.isTrial`, `hasGoons`, `drops`; it never compares against the save's mode.
- **Any featured mode won opens the next level**, on Medium at a region's finale.
- **Tiers:** every mode on every level has Easy, Medium and Hard, picked in Level Options (`PlayerData.gameTier`). The tier sets the goal and the world's toughness and shows as a medal. `gamemodeBeat` stays "beaten on any tier".
- **A run ends once**, through `levelRoot.endLevel()` (`hasEnded`), whichever ending gets there first.
- **A fixed-map mode** takes its world seed from the level and mode (`Course.seedFor`), so records compare like with like.
- Every run with a course, a score or marks prints a `RUN_GOAL` line when it ends, for the harnesses' logs.

## Two players

A second person on a controller joins in Level Options and drives a car of the garage's on a split screen. `Coop` (`scripts/global/coop.gd`) holds who joined and what they picked; `CoopRun` (`scene/level/coop_run.gd`) is the guest's car, their half of the screen and the leash; `PadDriver` reads their controller by device.

- **The run is the first player's.** The save, rewards, records, HUD and goal are theirs. The guest's car has `isGuest` set and `isPlayer` off, so `Root.playerCar` and every `isPlayer` check still mean the first player. Give the guest a behavior with `isGuest`, never by turning `isPlayer` on.
- **The mode picks the guest's side** (`Coop.isRival`): a rival in a Goon Cup mode, a friend everywhere else, Pursuit included (both chase the runner). A friend's crushes and arrival at the station count for the player (`Coop.creditTo`). Of the pickups it drives over, a friend keeps what a car uses (repairs, tuning, boosts, gadgets) and hands the player what a run pays, plus fuel (`Coop.pickupFor`), with the coins also counted on the guest's own visor. A rival joins the mode's field (`Rivals.cars`) and keeps the pickups and chain coins it earns.
- **Wrecks.** With a friend, one car still going is enough: whichever car is wrecked comes back beside the other (`CoopRun.revives`, `holdsWreck`, `OverheadCarBody2D.revive`), and the run is lost when both are down at once. Nobody comes back in Goonpocalypse, which is about lasting. A wrecked rival is out, and the player's wreck ends the run as it does alone.
- **The leash.** The world streams round the first player, so the two stay within `CoopRun.LEASH` of each other, which must stay under one chunk each way. The guest is towed to the player; in a race between the two, whoever is behind is towed up to the leader (`CoopRun.leads`) and takes the leader's place on the course (`Course.matchProgress`). A towed player's course time is not recorded (`Course.towed`).
- **One screen, covered.** The level's viewport still draws the whole window (menus and results are full width) with its camera shifted to the left half; a second viewport on the same world covers the right half. Each half has its own HUD (docs/HUD.md, "Two HUDs").
- **The pads.** While a guest is in, every pad binding in the `InputMap` points at the first player's device (`Coop.claimPads`); anything that adds pad bindings later must run it again.
- **No prize games** with two players: no gift boxes and no prize-game pickups, since each stops the run for both.
- Try it without a second pad: `-- --coop` (and `--coop-car=<index>` for the guest's car).

## Run rank

Every run gets a score and one of 25 ranks, shown on the results (`RunRank`, `Level.runRank`). Each part of the score (the mode's goal, carnage, style, haul) is measured against a par for the run's level, mode and tier, so every mode shares one ladder; the tier scales the total, and a lost run tops out mid-ladder. The best score of a mode on a level is kept in `meta.records.rank` (`SaveManager.recordRank`) and shown in Level Options; Free Play is ranked but not recorded.

Par is what the AI drivers do: play the runs with a `--tag` that starts with `par`, then `scripts/debug/bake_run_par.gd` writes `world/run_par.json` (its header has the commands). A level, mode and tier with nothing baked takes the mode's mean over the levels that have one. Re-bake after a balance change; the playtest CSV's `run_score` and `run_rank` columns show the spread.

## Trying a mode

`-- --console="start maxed;play derby hard"`, or the same two commands in the console (`start maxed` first, so it plays on a scratch save; bare `play` lists the mode ids).
