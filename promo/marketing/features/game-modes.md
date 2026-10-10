# Game modes

**Pitch:** 19 modes in three kinds, and every level picks three to feature.

## What it is
- **Crusher** (goons are the point): Countdown, Sprint, Marathon, Defense, Goonpocalypse, Blackout, Bounty Hunt.
- **Trial** (no goons, the course and the clock): Rally Stage, Flat Out, Hot Lap, Drift Trial, Cone Course, Smash Run.
- **Goon Cup** (rival drivers): see `goon-cup.md`.
- A level plays five modes picked for it: two simple openers, then three featured modes, one per kind. Winning all five opens Free Play: any other mode on that level, for coins only.
- Easy, Medium and Hard on every mode and level, shown as bronze, silver and gold medals.

## Numbers
- 19 modes: 7 Crusher, 6 Trial, 6 Goon Cup (`scripts/global/modes.gd`).
- The demo's ten levels play all 19 modes between them (`world/levels/*.tres`, `openers` and `featured`).
- 0.1 had 5 modes in code; its menu locked all but Countdown and Sprint in the demo (old `main2.gd`).

## Demo vs full game
- Demo: every mode except Flat Out.
- Full game: Flat Out, and all 19 across 30 levels.

## What to show
- Every shot file defaults to Countdown, so mode clips **need shots** (add `"mode"` to a copy of a shot).
- Good pairs: Cone Course on Orchard Lanes, Drift Trial on Red Canyon, Blackout on Lantern Marsh.

Not ready to quote: every mode is an untuned first version. Hot Lap's ghost and Drift Trial's marked corners are in the menu text but not built.

Details: docs/MODES.md.
