# Roadmap: balance and pacing

Tags and effort: `ROADMAP.md`. Tools: career playtests (`scripts/ai/career.py`, `docs/AI_DRIVER.md`), `start <tier>` in the console, `user://runlog.csv`.

**Targets (the author):** about 15+ hours to finish the full game (all levels open, every mode seen, most cars owned); every mode earns similar coins a minute; every mode winnable.

## Planned

### Before the demo
- **[0.3 need] A fresh save through the demo.** Career playtests with the three personas from `fresh`, demo flag on: no blocks, no softlocks, every level opens, read `longest_runs_without_progress`. Then once by hand. M.
- **[0.3 need] Winnable:** every demo level and mode on Easy and Medium, checked with AI playtests and spot-checked by hand. Sprint clocks first. M.
- **[0.3 need] Goon damage** is about 14× on unarmored cars since the damage change: confirm it is intended, in a stock demo car. S + play.
- **[0.3 want] First fit for the demo's span** (10 levels, 3 cars):
  - Payouts: `ModeTiers.winBonus`, wave stars (no cap: a long Goonpocalypse earns a star a minute).
  - Unlock prices: `Unlocks.PRICE_RANGE` (placeholders). Target: a Rookie opens about 20 pickups by the end of Prairie and sees every mode before the demo ends.
  - Gift boxes (`CrushPrizes.XP_BASE`, `XP_EXP`): first box in under a minute of decent play, then one every 2 to 4 minutes.
  - The drop mix, pickup odds and timers, fuel pressure, wall damage, the water costs.
- **[0.3 want] About 30 runs by hand** across the 3 demo cars and the modes, with notes.

### After 0.3
- **[later] The full-game fit:** late-level escalation (`ModeTiers.LEVEL_STEP`, `SPRINT_DISTANCE`, the elite steps in `Territories`), car prices and gem prices, car-clear bonuses; careers against 15 hours.
- **[later] Upgrade costs** with the upgrade rework (`ROADMAP_CARS.md`).
- **[later] Marathon's and Defense's pit numbers;** Sprint clocks on the late levels.
- **[later] A late level's Countdown in a mid car; Goonpocalypse in a maxed car.**

## Suggestions
- The AI weights goons by crush XP, so its runs earn boxes at a player's pace.
