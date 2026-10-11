# Roadmap: game modes

How modes work today: `docs/MODES.md`. The approved plan with every mode's pitch: https://claude.ai/artifact/CBinsKaUkcXvu3S3V2YMbk. Tags and effort: `ROADMAP.md`.

The demo's 10 levels play all 19 modes. Sprint, Countdown, Marathon, Defense and Goonpocalypse have been played; the other 14 are first versions that no person has driven, tuned or looked at.

## Planned

### Before the demo
- **[0.3 need] The new openers by hand.** Eight demo levels now open on modes of their own (`openers` in `world/levels/*.tres`; the reasoning: https://claude.ai/artifact/Bm6yafr7UhDvk6kQYrQeRB): is each simple enough to start a level, and winnable in a stock car? Swap any that isn't. Regions 3 to 6 still open on Sprint and Countdown. S + play.
- **[0.3 need] Free Play by hand:** win all five on a level, try several off-list modes, check the ticket pays coins and nothing else. The row cycles modes one press at a time; a picker by category would be kinder. S + play.
- **[0.3 need] Play each of the demo's modes once by hand** (`start maxed`, then `play <mode> [level] [tier]`). For each: it starts, the goal reads clearly, it can be won and lost, the results ticket is right. Fix what is broken, or switch the mode off (`Root.MODE_AVAILABLE`) and check its level still has a featured mode that opens the next. M + play.
- **[0.3 need] Menu text that promises what isn't built:** Hot Lap's description promises a ghost and Drift Trial's says "Marked corners" (`Modes.DATA`). Change the words until the features exist. S.
- **[0.3 need] Defense Medium by hand:** is it winnable? S + play.
- **[0.3 want] Tune what the AI exposed** (`ModeTiers`): Drift Trial's targets are far too low; the Pursuit runner may be too soft; derbies may be too short now that armor doesn't decide car hits. S each + play.
- **[0.3 want] Cannonball's rules** written into `docs/MODES.md`. S.
- **[0.3 want] A start briefing check:** every mode has one (`meta.hints.briefings`); read each for accuracy. S.

### Two players (first version is in; docs/MODES.md "Two players")

- **[0.3 want] Play it with two people.** Nothing here has been driven by a second person yet: the join in Level Options, every mode as friend and as rival, the tow, a friend's respawn. M + play.
- **[0.3 want] The two HUDs, finished.** Each half has its own, at a fixed scale picked by eye. Left: a look at every dashboard at that size, banners (`TapeBanner`) still cross the divider, the guest's goal is the player's except its race place, a warning before the tow, and the radio's track name is gone with the left visor. S + play.
- **[0.3 want] The tow in a race, played.** Whoever is behind is towed up to the leader and takes its place on the course; nobody has raced with it yet. Check that it isn't a way to skip a lap. S + play.
- **[later] A rival's crushes drop nothing** and pay it no coins: only pickups lying in the world count for it. S.
- **[0.3 want] The guest's rules per mode:** what a rival means outside the Goon Cup (it only shares the road now), whether a friend's wreck should end some modes, a guest crossing checkpoints for the player, and the guest in Pursuit as the runner. M + play.
- **[later] Loose ends:** a mouse or first-player way to remove the guest, the guest's pad unplugged mid-run, rumble on the guest's pad, the guest's own sounds and crush feel, `gc_car_pos` (one car's position for shaders), and performance at night with two views (not measured). M.

### After 0.3
- **[later] Par times:** Rally Stage and Flat Out want a par time per course in place of one slack per mode (Prairie is loose, Frostbite's gold is out of a stock sedan's reach). Smash Run wants a quota per level. M.
- **[later] What the first versions left out:** Flat Out's launch light, lanes of different ground, fork and hazards; pickup pads on the loops; rivals collecting pickups; name plates over rivals; ghosts for Hot Lap; marked corners for Drift Trial; a walled derby arena; a night spawn table for Blackout.
- **[later] The record book** on the records ticket; per-level records for the modes without a course record.
- **[later] Pacing pass** on tiers across all 30 levels (`ROADMAP_BALANCE.md`).

## Suggestions
- **"Heat" modifiers** after the last level.
- **Goonpocalypse in a maxed car:** does overtime ever end it? Decide whether it should.
