# Roadmap: game modes

How modes work today: `docs/MODES.md`. The approved plan with every mode's pitch: https://claude.ai/artifact/CBinsKaUkcXvu3S3V2YMbk. Tags and effort: `ROADMAP.md`.

The demo's 10 levels feature 18 modes (all but Flat Out). Sprint, Countdown, Marathon, Defense and Goonpocalypse have been played; the other 14 are first versions that no person has driven, tuned or looked at.

## Planned

### Before the demo
- **[0.3 need] Play each of the demo's modes once by hand** (`start maxed`, then `play <mode> [level] [tier]`). For each: it starts, the goal reads clearly, it can be won and lost, the results ticket is right. Fix what is broken, or switch the mode off (`Root.MODE_AVAILABLE`) and check its level still has a featured mode that opens the next. M + play.
- **[0.3 need] Menu text that promises what isn't built:** Hot Lap's description promises a ghost and Drift Trial's says "Marked corners" (`Modes.DATA`). Change the words until the features exist. S.
- **[0.3 need] Defense Medium by hand:** is it winnable? S + play.
- **[0.3 want] Tune what the AI exposed** (`ModeTiers`): Drift Trial's targets are far too low; the Pursuit runner may be too soft; derbies may be too short now that armor doesn't decide car hits. S each + play.
- **[0.3 want] Cannonball's rules** written into `docs/MODES.md`. S.
- **[0.3 want] A start briefing check:** every mode has one (`meta.hints.briefings`); read each for accuracy. S.

### After 0.3
- **[later] Par times:** Rally Stage and Flat Out want a par time per course in place of one slack per mode (Prairie is loose, Frostbite's gold is out of a stock sedan's reach). Smash Run wants a quota per level. M.
- **[later] What the first versions left out:** Flat Out's launch light, lanes of different ground, fork and hazards; pickup pads on the loops; rivals collecting pickups; name plates over rivals; ghosts for Hot Lap; marked corners for Drift Trial; a walled derby arena; a night spawn table for Blackout.
- **[later] The record book** on the records ticket; per-level records for the modes without a course record.
- **[later] Pacing pass** on tiers across all 30 levels (`ROADMAP_BALANCE.md`).

## Suggestions
- **Varied openers and Free Play** (the author's idea, 2026-10-10): each level picks its first two modes as it picks its last three, from the simple modes; winning all five opens any mode on that level. Report with rules, a sketch for the demo levels and the code changes: https://claude.ai/artifact/Bm6yafr7UhDvk6kQYrQeRB. Needs the hand test of every mode first.
- **"Heat" modifiers** after the last level.
- **Goonpocalypse in a maxed car:** does overtime ever end it? Decide whether it should.
