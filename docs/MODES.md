# Game modes

What is left to do on the modes: docs/GAMEPLAY_SUGGESTIONS.md, package 18 (it links the approved design plan). How the AI plays each mode: docs/AI_DRIVER.md.

## Where it lives

| What | Where |
|---|---|
| The mode list (append only) | `Root.gameModes` |
| Each mode's id, category, words and rules | `Modes.DATA` (`scripts/global/modes.gd`; its header explains the keys) |
| Each mode's numbers per tier | `ModeTiers` (`scripts/global/mode_tiers.gd`) |
| A level's three featured modes | `LevelDef.featured` (`world/levels/<id>.tres`) |
| Mode and level unlock rules, availability, the demo gate | `Root` (`modePath`, `isModeUnlocked`, `isModePlayable`, `MODE_AVAILABLE`, `opensNextLevel`, `IS_DEMO`) |
| Crediting a win: level, tier, the car's clear | `SaveManager.currentLevelPassed`, `meta.carClears` |
| The run's own level, mode and tier | `Level.runLevel`, `runMode`, `tier` |
| Endings and pay | `Level.endLevel`, `timeUpCondition`, `runPayout`; `Root.computePayout` |
| Per-mode helpers on `Level` | `bounty` (`BountyHunt`), `course` (`Course`, `ConeCourse`: fixed maps, checkpoints, records), `trial` (`TrialScore`), `rivals` (`Rivals`: AI-driven car scenes), `KeepCup`, `Derby` (`scene/level/`) |

## Rules

- **Three categories:** Crusher (goons are the point), Trial (no goons: the course and the clock), Goon Cup (other drivers).
- **One mode order:** every level plays Sprint, then Countdown, then its three featured modes, one per category. Every menu, harness and test reads `Root.modePath(level)`.
- **A variant runs on its base mode's rules** (`Modes.plays`), and a Trial has no goons, drops, night or fuel burn. So run code asks `Modes.running()`, `Modes.isTrial`, `hasGoons`, `drops`; it never compares against the save's mode.
- **Any featured mode won opens the next level**, on Medium at a region's finale.
- **Tiers:** every mode on every level has Easy, Medium and Hard, picked in Level Options (`PlayerData.gameTier`). The tier sets the goal and the world's toughness and shows as a medal. `gamemodeBeat` stays "beaten on any tier".
- **A run ends once**, through `levelRoot.endLevel()` (`hasEnded`), whichever ending gets there first.
- **A fixed-map mode** takes its world seed from the level and mode (`Course.seedFor`), so records compare like with like.
- Every run with a course, a score or marks prints a `RUN_GOAL` line when it ends, for the harnesses' logs.

## Trying a mode

`-- --console="start maxed;play derby hard"`, or the same two commands in the console (`start maxed` first, so it plays on a scratch save; bare `play` lists the mode ids).
