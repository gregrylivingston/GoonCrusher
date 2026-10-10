# Gameplay suggestions

The roadmap: open work only. What is built is in the area docs and in git history. Suggestions to discuss, not a spec; the author runs gameplay as a separate project. Effort: **S** under a day, **M** 1–3 days, **L** a week or more.

Nothing in the game has been tuned by hand, and every balance number measured so far was fitted on the old 8 levels and 5 modes: measure again before tuning.

## Work packages, in order

Package numbers are IDs (other docs cite them); the table is in the suggested order. Packages 2, 11, 12 and 16 are done (their tuning is in package 1).

| # | Package | Effort | Needs |
|---|---|---|---|
| 18 | The mode menu: play, cost, what the first versions left out | L + play time | — |
| 17 | Road atlas: level content, pacing, Region 1 follow-ups | L + play time | — |
| 1 | Balance pass | L + play time | — |
| 13 | Driving juice: feel pass | S + play time | — |
| 6 | Driver perks | M–L | 1 |
| 14 | Props: feel pass | S + play time | — |
| 3 | Regions, waves and giants | M–L | 1 |
| 5 | Gems | S | 1 |
| 7 | Goals and teaching | M–L | 1 |
| 8 | Sound and radio | M | — |
| 15 | Cosmetics | M | 1 |
| 9 | Goon depth | M | — |
| 10 | Post-launch | — | 7 |

Re-run the crowd benchmarks (S3, S4, docs/PERFORMANCE.md) after packages 1, 3, 9, 13 and 14.

### Package 18: The mode menu
The plan, with every mode's pitch: https://claude.ai/artifact/CBinsKaUkcXvu3S3V2YMbk. Rules as built and how to try a mode: docs/MODES.md.
1. **Play each of the 14 by hand,** then tune (`ModeTiers`). Known from the AI (docs/AI_DRIVER.md "Status and what is next"): Drift Trial's targets are far too low; the Pursuit runner may be too soft; derbies may be too short; Rally Stage and Flat Out want a par time per course in place of one slack per mode; Smash Run wants a quota per level.
2. **Cost:** benchmark a six-car race on the HD 620; a cheaper driving profile for rivals if it is too much.
3. **Left out of the first versions:** Flat Out's launch light, lanes of different ground, fork and hazards; pickup pads on the loops; rivals collecting pickups; name plates over rivals; ghosts (Hot Lap's description promises one); marked corners for Drift Trial; a walled derby arena; a night spawn table for Blackout (T2-11).
4. First-run hints per mode, the record book on the records ticket, Cannonball's rules in docs/MODES.md.

### Package 17: Road atlas
- **P5 leftovers:** dressing weights for the new props are first guesses; `mountain` keeps the plain `pine` (snowy pines are the author's call); `steam_vent` doesn't glow at night (needs `"blend": "add"` in the generator's atlas entry).
- **P6. Level content** for the 22 new levels, which start from their landscape's template: twists as data (`LevelDef.rules`), line-up checks, AI playtests; regions 1 and 2 first, for the demo.
- **P7. Pacing pass** (needs the author's play notes): `ModeTiers.LEVEL_STEP`, `SPRINT_DISTANCE`, the elite steps, car-clear prices; careers against 15 hours; S3 and S4 on The Sprawl and The Works. Known: Stilt Town's and Cul-de-Sac's stations sit too far out; goon damage is about 14× on unarmored cars since the "damage updates" change.
- **Region 1 (The Wilds):**
  - AI stalls in Orchard Lanes' hedgerow lanes (widen the gate gaps, or let the AI treat farm gates as breakable at speed) and Moose Woods' thickets; Countdown wins fell on Snapper Bayou. Measure first: `--playtest --level=<id> --mode=countdown,sprint --runs=8 --seed=1 --trace`. M.
  - Benchmarks: S2 and S4 on Prairie and Moose Woods at Low, on an idle machine; record in docs/PERFORMANCE.md. S.
  - Feel pass by hand: every smash speed, coin value, event weight and lure radius is a placeholder (docs/GOONS.md "Wild instincts").

### Package 1: Balance pass
Targets (the author): about 15+ hours to finish (all levels open, every mode seen, most cars owned); every mode earns similar coins a minute; every mode winnable.
- **B-3. Winnable modes.** Play Defense Medium by hand. Give the AI a fuller Defense (guard lanes, park to refuel); its lot-approach graph and the Sprint clock's approach allowance still assume a walled station lot. Check Sprint clocks on the late levels.
- **B-4. Fit the numbers** with career playtests (`scripts/ai/career.py`, three personas from `fresh`; read `unlock_pace`, coins a minute by mode, `longest_runs_without_progress`):
  - Payouts: `ModeTiers.winBonus`, late-level escalation, wave stars (no cap: a long Goonpocalypse earns a star a minute).
  - Upgrades (T1-11): a flat +1 a level helps weak stats far more than strong ones. Proposal: a `stat_max` per stat in `<car>_info.tres`, tier-based cost bases, car prices re-fit.
  - Unlocks: `Unlocks.PRICE_RANGE`, car gem prices, completion-count unlocks (`clears:<tier>:<n>`: none assigned). Target: a Rookie sees every mode before the last level and opens about 20 pickups by the end of Prairie.
  - Gift boxes (`CrushPrizes.XP_BASE`, `XP_EXP`): first box in under a minute of decent play, then one every 2–4 minutes; measure the eight games' values.
  - Also: the drop mix, pickup odds and timers, fuel pressure, wall damage, Marathon's and Defense's pit numbers, the water costs.
- **B-5. By hand** (the author; `start <tier>` or `-- --play-start=<tier>`; runs log to `user://runlog.csv`): about 30 runs across 3 cars and the modes; crush feel (`GoonFx.STYLE_WEIGHTS`, `FLING_SPEED`, trauma, hit-stop); handling, gearboxes, handbrake and drift boost on keys and pad (console `handling`, then copy into `car_handling.gd`); a late level's Countdown in a mid car; Goonpocalypse in a maxed car (does overtime end it?).
- **B-6. World and AI:**
  - Cars still wedge on corners although every car has a middle hull: find what stalls them (`overlap=` in `PLAYTEST_STUCK`). S–M.
  - The AI skips pickups near deep water (`waterTargetPx`): allow them at low approach speed. S.
  - Highway edges look blobby: a crisper border for road surfaces, or a curb line. S.
  - Benchmark S3/S4 at Crush Effects Full; drop the Low preset to Minimal if crowds cost frames.
- **B-7. Small connections:** a "+XP" tag flying to the gift box on the visor; the AI weights goons by XP; an "XP Boost" pickup or perk (`car.crushXpMult`: nothing sets it yet).

### Package 13: Driving juice
- Feel pass by hand on `scene/fx/car_juice.gd`: lean, two-wheel tilt, bounce, wall jolt, trail density, engine pitch, backfire odds.
- Benchmark S3/S4 at Driving Effects Full against Reduced; drop Low to Minimal if trails cost frames.
- Sound: the engine loops one recording; gear shifts, backfires and landings borrow other clips.

### Package 14: Props
- Feel pass by hand: canopy fade, springs and knock speeds (`PropReactions`), the field lattice, motif weights, the spills (`Spill`). Check how much a crown hides goons at night.
- Questions for the author: should goons that release a pile get credit and run away? Should spilled logs and the crane's container ever clear away? Should water towers leave a slippery puddle (a terrain overlay `integrate()` would read)?

### Package 3: Regions, waves and giants
- **T1-7.** A district's `giantism` is shown but unused. Proposal: giant odds = `giantOdds + giantism / 5`, plus a term from the run's wave. S.
- **T2-4.** Giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges (start from the Foreman's `Boss` verb). M.
- **T2-8.** Region mutators ("fog", "giants only", "double coins") and objectives ("crush 20 Rat Pack"), anchored on district landmarks. M.
- **T2-11.** A night spawn table and ×1.5 coins at night (night length is already per level, `rules.nightShare`). S.

### Package 5: Gems
- **T1-10.** More to spend gems on, cheapest first: a gem pouch (carry up to 3 into a run), a gem-paid continue (50 health and fuel, hooked in before `endLevel`, not in Goonpocalypse), respec. M.

### Package 6: Driver perks
- **T2-13.** Driver perks and affinity, beside the car traits (`CarTraits`; hooks: `awardBase` in `playerRoot.gd`, the purse's `MIN_COINS`/`MAX_COINS`, `car.crushXpMult`). M–L.

### Package 7: Goals and teaching
- **T1-15. First-run hints** (one-time toasts, flags in `meta.hints`) for: crush speed, the prize games' keys, where stars come from, gadget Use, deep water, what smashes and what doesn't. S–M.
- **T2-12.** Per-level records for the modes without a course record; a "Next up" panel. M.
- **T1-16.** A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`; achievements mirrored into `meta.achievements`; `steam_appid.txt` only in dev builds. M.
- **T2-14.** Three date-seeded contracts, reroll for a gem. M. Needs T1-16.
- **T2-15.** Medal-gated top cars. S–M. Needs T1-11.

### Package 8: Sound and radio
- **T1-13.** A `VoiceDirector`: priorities (warning > win > record > jackpot > giant > award > region), a ~5 s cooldown, no repeats in the last 3 lines, subtitles. S.
- **Mix:** listen in play (docs/RADIO.md "Mix"). Maybe clashing with the songs: the glockenspiel chime on pickups, the results ticket's impact, the wolf howl at nightfall. Goon death sounds are one shared set. S.
- **Radio:** a listening pass on crossfade lengths, segment odds and ducking depth; more tracks as they come (sound/radio/gooncrusher/writing/songs.md).

### Package 15: Cosmetics
- **C-1.** Looks that never change stats: paint and liveries per car, decals and numbers, smoke, spark and flame colors, horns, driver outfits. Generated with `car_gen.js`, chosen on the driver card, bought or earned through `Unlocks` (`paint:` ids), saved per car in `meta.cosmetics`. M.

### Package 9: Goon depth
- **T2-1.** `hp` (for T2-4) and a speed-label tint when the car is too slow for a nearby heavy.
- **T2-3.** Goons that leave fire behind or reassemble.
- **T2-5.** True swarms.

### Package 10: Post-launch
- Steam leaderboards (needs T1-16); a daily seeded run (move goon choice, giants and drops off the global RNG); custom seed entry (`TileManager.worldSeed` has no UI).
- "Heat" modifiers after the last level; ramps and airtime crushes; goon nests, single-use gas pumps, boost chevrons; interactive music layers and new voice lines; Training Grounds.

## Maybe

- **Elite escort goon** (deferred by the author): line-ups with no rank-1 goon have no fodder between heavies. Add a Grunt to Goon Quarry and the War Machine levels and a Yipper to the Big Game levels (`lineup` in `world/levels/*.tres`, and `Goons.CLASSES`).
- **Curses** (on hold: they add ways to lose a run): a `K.CURSE` kind in `Pickups.DATA`; five icons exist in `scripts/art/pickup_icons.js`, skipped by the generator.

## Decisions already made

- **On hold (the author):** Region 2 and the regions 3–6 revamps, and champions, until Region 1 is settled. Don't start them.
- **Rejected modes:** Convoy, Turf War, Big Game, Last Drop, Crush-Off, Odd Jobs, Goon Ball, stunt and airtime modes, Hill Climb. Marathon, Defense and Goonpocalypse ship in 1.0; a mode can be retired later.
- Rivals are the garage's own drivers. Records are kept per car. Pickups in a mode are only ones useful there.
- Payout stays (coins + a win bonus) × a small star multiplier capped at ×3. Coins × stars and a flat win bonus were both tried and broke the economy.
- Crushes chip the car's health, by choice.
- Saves from before version 8 start over; nothing from them is kept.
- No game pays another prize game; gift boxes pay no star; only the weakest game starts open.
- Waves are one clock for the run with no cap, not per district.
- Cosmetics never change stats and cost coins or gems.
- Tree canopies may hide goons. The two-wheel tilt is style only: cars never tip over.
- No jingles or stingers over the radio; any new cue is short and not tonal.
- Radio: one station of in-house tracks plus Off (Lofi stations were tried and dropped); no driving key; talk is not contextual.

## Open questions for the author

Numbered as before (1, 2 and 7 to 10 were answered).

3. Fuel pressure: should fuel or health be the main way runs end?
4. Price?
5. Gems: never sold? Is a gem-paid continue acceptable?
6. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
