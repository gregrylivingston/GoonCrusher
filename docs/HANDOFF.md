# Handoff: open work after the Road Atlas and Region 1 push (2026-10-09)

Self-contained tasks for any agent. Read CLAUDE.md first. Rules for every task:
- **Save safety:** before any Godot run, put an `override.cfg` in the repo root (`[application]` / `config/custom_user_dir_name="GoonCrusherDev"`). Never commit it. Runs otherwise write the real save.
- **Tests:** run `--import` first after pulling, then the full suite (`-s res://tests/game/run_tests.gd`, about 12 min, exit code = failures; 556 pass on main 711711cb).
- **Git:** a feature branch per task, no push unless asked.
- **Scope:** Region 2 and regions 3–6 revamps are ON HOLD (author's decision) until Region 1 is settled. Don't start them.

Context: docs/GAMEPLAY_SUGGESTIONS.md (package 17), docs/WORLD.md, GOONS.md, PICKUPS.md, HUD.md, UI.md.

The Region 1 design (props, systems, ids R-/G-/L-) is in the session study, summarised in docs/GOONS.md "Wild instincts" and docs/WORLD.md.

## Quick wins (small, well-defined: good for a cheaper model)

| # | Task | Where | Done when |
|---|---|---|---|
| Q1 | (Done: `Pickups.lureCheckDue`) **Salt lick lure cost.** Its permanent lure makes every goon read `Pickups.lures` every tick on Moose Woods. Only heavies should check it, throttled (every 8 ticks). | `scripts/global/pickups.gd` `lureFor`, `walker.gd` lure read | Test: a non-heavy goon never reads the salt lick; no per-tick allocation |
| Q2 | (Done) **Stale docs.** docs/WORLD.md "Interactive props" doesn't list the Region 1 spills (still, sluice, rockslide, TNT, topples, deadfall, pumpkins, apples, dens, burrows, bell, salt lick). | docs/WORLD.md; source of truth `scripts/world/spill.gd`, `breakable.gd` | Docs only |
| Q3 | (Done) **Stale comments.** bench.gd/playtest.gd still mention "faction band and roster"; GOONS.md lines about `--faction=` and the faction band (now classes and `--class=`). | those files | Text only |
| Q4 | (Deferred: moved to GAMEPLAY_SUGGESTIONS.md "Maybe") **Elite escort goon** (pending author OK: recommended). Add one rank-1 goon to line-ups with none: Goon Quarry + Grunt; War Machine levels (blastpits, tankfarm, slagfields, theline, crusher) + Grunt; Big Game levels + Yipper. | `world/levels/*.tres` `lineup` | test_levels passes; AI playtest on crusher survives longer than 25 s |
| Q5 | (Done: blue Star of Life) **Ambulance emblem** (pending author OK). Replace the red cross (a protected emblem) with a Star of Life on the top-down sheets and the side view. | `scripts/art/car_gen.js`, re-bake `python scripts/art/bake_cars.py ambulance` | Contact sheet looks right; no PNG hand edits |
| Q6 | (Done) **Blueprint unlock** fires on `open:quarry`, now the 10th level (was 4th). Move it to `open:canyon` (4th). | `scripts/global/pickups.gd` / unlocks data | test_unlocks passes |

## Medium (worth it; a mid-tier model with care)

| # | Task | Notes |
|---|---|---|
| M1 | **Road-map level select + car strip (plan P3/P4 UI).** It replaces the 3-poster carousel with:<br>• 6 region tabs (Z/C, LT/RT)<br>• 5 stops on a road (Q/E, 1–5)<br>• mode medallions, tier chips and START underneath<br>• a small strip of the 9 car side views (`CarInfo.sidePic`) for the selected mode/level/tier: in colour = cleared, dark = owned but not cleared, outline = not owned, the current driver bigger with an orange bar. | The data and queries exist: `SaveManager.carClearTier`, `carsCleared`, `isFullGarage`, `Levels.regionAt`, `Territories`. The layout spec and mock are in the plan report (author has it). File: `scene/player/menu/main/main2.gd` `buildSetup`/`refreshSetup`. Follow docs/UI.md: MenuTheme, KeyHints, mouse-only must work. Update `scripts/debug/career.gd selectLevel` (the career harness clicks the menu) and docs/TEST_SCOPE_TRANSITIONS.md. **Biggest visible win.** |
| M2 | **Region 1 AI tuning.**<br>• Orchard Lanes: the hedgerow lanes stall the AI (stuck 18–26 vs 5–6 before). Widen gate gaps, or teach the AI's breakable sweep to treat farm gates as passable at speed.<br>• Moose Woods: thicket stucks 8–10 vs 3. Lower the stand density or widen the trails.<br>• Snapper Bayou Countdown AI wins fell from 4/4 to 1/4 after the props/events merge; find out why (events? crates? sluice?). | Use `--playtest --level=<id> --mode=countdown,sprint --runs=8 --seed=1 --trace` before and after. Files: `world/levels/{orchard,moosewoods,bayou}.tres`, `scripts/world/chunk_recipe.gd`, `scripts/ai/ai_driver.gd`. |
| M3 | **Benchmarks** (docs/PERFORMANCE.md): S2/S4 on prairie and moosewoods at Low on an idle machine. The earlier S2 runs were inconclusive because of CPU load. | Record the numbers in PERFORMANCE.md |

## Larger (needs the author's play notes first, so a stronger model)

- **L1 Region 1 feel and tuning pass.** Every smash speed, coin value, event weight and lure radius is a placeholder (constants are listed in GOONS.md "Wild instincts" and PICKUPS.md). Wait for the author's notes.
- **L2 Pacing pass (plan P7).** Fit the 30-level curve, `ModeTiers.LEVEL_STEP`, Sprint distances (Stilt Town and Cul-de-Sac stations sit too far out), elite strength steps, and the goon-damage change from "damage updates" (about 14× on unarmoured cars), using career playtests (`scripts/ai/career.py`) against the 15-hour target.
- **On hold:** Region 2 (Tribe Country) build; regions 3–6 revamps; champions.
