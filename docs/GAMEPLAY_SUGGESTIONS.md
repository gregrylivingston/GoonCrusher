# Gameplay suggestions

Suggestions to discuss, not a spec; the author runs gameplay as a separate project. Effort: **S** under a day, **M** 1–3 days, **L** a week or more.

## Done (one line each)

How a finished system works is in its area doc (named on each line), not here.

- **T0-1 to T0-10** The first fixes: `levels` saved and migrated; a run ends exactly once (`Level.endLevel`); Countdown is won at 0; stations on reachable land; Sprint's clock from its route; the per-level mode chain; Marathon and Defense no longer crash; the stat fixes (Oil, Dice, traction, armor once, upgrade cap 20, in-run cap 150); payout credited on the summary, Abandon pays like a death; Start pauses on a controller.
- **Goon physics layer**, **`meta` in the save**, **explosion pooling** (`Level.explode`).
- **T1-1** Debug run log (`user://runlog.csv`, `scripts/debug/run_log.gd`).
- **T1-2, T1-3, T1-4** Goonpocalypse (escalation, score, survival target, overtime), Marathon (a relay of legs with a pit stop at each station) and Defense (a station barrier, goons that march on the pumps and blow up, lanes) (docs/MODES.md, "Endings and pay").
- **T1-5, T1-6, T1-8, T2-9, Tier 3 (shallows, fords, bridges)** Per-level terrain, walls, surfaces and hazards (docs/WORLD.md).
- **T1-7 (regions)** A run's regions are the map's districts, with faction, goons, name and tint.
- **T1-9** Slot machine paylines and Dice (docs/PICKUPS.md).
- **T2-2, T2-7** Goon movement archetypes; 79 pickups (docs/GOONS.md, docs/PICKUPS.md).
- **T2-3 (drowning credit)** A drowning within 3 s of the car's touch counts as a crush.
- **T2-10 (most)** Breakables, explosives, faction landmarks, log and manhole spawns (docs/WORLD.md).
- **Package 2 (T1-12, T2-6)** Crush feel: death styles, goo, camera trauma, hit-stop, combo readout, crush bonuses, three settings (docs/GOONS.md "Crush feel"). Crushes still chip 0.35 health before armour, by choice.
- **Driving controls** Handbrake powerslide and drift boost, a second held slot for boosts, gadgets on E / X, a starting gadget and boost for gems in run setup (CLAUDE.md, docs/PICKUPS.md).
- **Handling overhaul (2026-10-09, merged)** `CarHandling` with a weight stat, wall deflection and bounce, camera look-ahead, the semi's trailer, two traits per car, a horn per car, manual gearboxes on the racer, supercar and semi with gear ratios from each car's top speed and a tach per car (docs/CAR_ART.md "Handling", "Traits", "Trailer"). Untuned (B-5).
- **Package 13 (D-1 to D-4, code)** Driving juice, `CarJuice`: lean, two-wheel tilt, bounce, trails, engine and tyre sound, a Driving Effects setting (docs/CAR_ART.md "Driving feel"). What is left is below.
- **Package 14 (P-1 to P-5, code)** Prop layers, reactions and layout: canopies over the car, hit reactions, field lines, motifs, interactive props (`Spill`) (docs/WORLD.md "Props and decor", "Interactive props", "Prop reactions"). What is left is below.
- **Package 12 (U-1 to U-5)** One unlock system (`Unlocks`): four states, one tree per pickup kind, a new save opens only the Fuel Can, the Coin and the Claw Crane, locked pickups never drop or get offered, results-ticket unlocks, advanced cars cost gems too, the demo's cap, and the **Pickups screen** (`PickupShop`, G / View), which replaced buying in the Goonopedia (docs/PICKUPS.md "Unlocks", docs/UI.md "Pickups"). Prices are placeholders (B-4).
- **Package 11 (M-1)** Left-hand menu keys: Space accepts, WASD before the arrows, letters near WASD for shortcuts, hold Accept to keep buying (docs/UI.md).
- **Menu juice** Shutter, hatch and tire-smoke transitions; every menu works with the mouse alone (docs/UI.md "Transitions", docs/TEST_SCOPE_TRANSITIONS.md).
- **Run setup: road map and Level Options (2026-10-09; road atlas P3 and P4)** Six regions of five stops on a road with region buttons, a glyph per mode in its best medal's colour; Level Options with the mode rows, the tier switch, the records, the car strip of the 9 side views (`CarInfo.sidePic`) and START; the career harness drives it. The Goonopedia's Levels and Modes tabs are gone (docs/UI.md "Run setup").
- **HUD (2026-10-10)** The clock and goal on a rear-view mirror, two sun visors (gift box and radio; star, coins and payout), and a dashboard per car (`HudSkin`: two dials, system lamps, one signature instrument); they replaced the crush, payout and region panels (docs/HUD.md).
- **Career playtests** Three personas play the whole game through the real menus (docs/AI_DRIVER.md).
- **AI drivers rebuilt (2026-10-10)** One shared `AIDriver`, a driver per car with two personalities, a brief per mode, three skills; handbrake, manual shifting, horn and ability; rivals drive their own car. 133 wins of 171 in the car × mode matrix (was 110); what is left is in docs/AI_DRIVER.md, "Status and what is next".
- **W-1** Run-wide waves: one wave clock for the run (`Region.wave`), a star and a wave chest every 60 s with no cap; districts only decide who spawns (docs/WORLD.md).
- **N-1** Pickup name tags (`Pickups.shortName`) (docs/PICKUPS.md "Name tags").
- **Package 16 (G-1 to G-4) and the prize games (2026-10-09)** Gift boxes from crush XP, Cardboard to Diamond, each holding one unlocked prize game; eight skill games in one frame with one key scheme (Claw Crane, Hubcap Shuffle, Scratch Card, Goon Press, The Deal, Pachinko Drop, Slot Machine, Coin Pusher; the Prize Wheel and The Vault are gone), each unlocked by its Casino pickup; no game pays another; the prize lab (docs/PICKUPS.md "Gift boxes", "Prize games"). The box curve is now `120 × n^2.4` XP (`CrushPrizes.XP_BASE`, `XP_EXP`; was `50 n²`: games came too often). Values need measuring again (B-4).
- **R-1 (code)** Radio: one station, GoonCrusher Radio, scanned from `sound/radio/`, with skip and on/off in the pause menu, a now-playing card, ducking under the Voice bus; 14 songs, 10 ads, 23 talk segments, 9 idents (docs/RADIO.md, docs/RADIO_SONGS.md, docs/RADIO_SEGMENTS.md).
- **Polish (2026-10-08)** A mode icon per mode (`HudTheme.MODE_ICONS`); the mix pass and the removed jingles (docs/RADIO.md "Mix").
- **Road atlas P1, P2, P4 data and P5 (2026-10-09)** 30 levels in 6 regions of 5 stops, six goon classes with a line-up per level, elite steps, a 10-level demo, car clears and Full Garages, 15 landscapes with their own baked skins, props, landmarks and posters (docs/WORLD.md "The levels", "Landscapes", "Regions"; docs/GOONS.md "Classes"; docs/WORLD_ART.md).
- **Region 1 (The Wilds) systems (code, untuned)** Wild instincts, the Critter Chain, herds, dens and warrens, bee yards and lures, the Region 1 spills, heroes and MPH smash tags, layout (the Home Paddock, hedgerow lanes, slot canyons, thickets), world events and the levels' rules (docs/GOONS.md "Wild instincts"; docs/WORLD.md "Heroes", "Region 1 levels", "Interactive props").
- **Water rework (2026-10-09, untuned)** A wading band and deep water that hurts the car instead of wrecking it; goons still drown (docs/WORLD.md "Water").
- **B-1 Mode tiers (2026-10-08)** Easy, Medium and Hard for every mode on every level, picked in Level Options; the tier sets the goal and the world's toughness, pays a win bonus and a first-clear bonus, and shows as medals; `clears:<tier>:<n>` unlock conditions; `--tier=` for playtests. Every number is in `ModeTiers` (`scripts/global/mode_tiers.gd`).
- **B-2 Win pay (2026-10-08)** `ModeTiers.winBonus` pays by the minute of the goal, by tier and by level; `Level.runPayout` is the one payout the ticket, run log and harnesses use. A flat bonus was tried first and got farmed (Prairie's Hard Sprint, 1,575 coins a minute).
- **B-3 fixes so far (2026-10-08, 2026-10-09)** Defense spawns 2.5× less often (`ModeTiers.DEFENSE_SPAWN_SCALE`), holds a fixed time per tier, and its goons march on the nearer pump and blow up there (`station.siegeStep`, `BLAST_DAMAGE`); the station lot has no walls in any mode, which also unstuck Marathon; every car has a middle hull (`CollisionShape2D_body`).
- **B-4 first fit (2026-10-08)** Goonpocalypse overtime (`SpawnManager.overtime`), the star multiplier capped at ×3, car and pickup prices raised about ×3, upgrades × the car's `UPGRADE_COST_SCALE`.
- **B-6, B-7 (parts)** Frostbite's passes; landmark beacons dim by day; lifetime gift boxes and the best run's count in `meta.lifetime`, a `boxes:<n>` unlock condition, boxes and medals on the records ticket.
- **Package 18, first versions (2026-10-09, 2026-10-10)** The mode menu: `Modes` (19 modes, three categories), three featured modes per level (`LevelDef.featured`), the unlock chain and road rule (`Root.modePath`, `roadModes`, `opensNextLevel`), save version 12, and a first playable version of all 14 new modes (`Root.MODE_AVAILABLE` is all true). Their rules as built, and what is left, are below.
- **Dev console (2026-10-10)** A status line, quick buttons (`Console.QUICK`), short help, Tab completion, `start <tier>`, `play <mode> [level] [tier]`, `autopilot` (CLAUDE.md "Autoloads").
- **Capture kit** Trailer and social footage, stills and interface elements from the game: takes, hand drives and replays, stages (docs/PROMO.md, `promo/README.md`).

## Work packages, in order

Package numbers are IDs (other docs link to them); the table is in the suggested order.

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 18 | The mode menu (what's left) | play by hand, cost, what the first versions left out | L + play time | — |
| 17 | Road atlas (what's left) | P5 leftovers, P6, P7, Region 1 follow-ups | L + play time | — |
| 1 | Balance pass (absorbs the package 2 follow-ups and packages 12 and 16) | B-3 to B-7 below | L + play time | — |
| 13 | Driving juice (what's left) | feel pass, benchmark | S + play time | — |
| 6 | Driver perks | T2-13 | M–L | 1 |
| 14 | Prop layers, reactions and layout (what's left) | feel pass, questions | S + play time | — |
| 3 | Regions, waves and giants | T1-7 (giantism), T2-4, T2-8, T2-11 | M–L | 1 |
| 5 | Slot machine and gems | T1-10 | S | 1 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 1 for T2-15 |
| 8 | Sound and radio | T1-13, mix follow-ups, R-1 listening pass | M | — |
| 15 | Cosmetics | C-1 | M | 1 |
| 9 | Goon depth | T2-1, T2-3, T2-5 | M | — |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3, 9, 13 and 14.

### Package 18: The mode menu (what's left)
The plan, with every mode's pitch and the level sheet: https://claude.ai/artifact/CBinsKaUkcXvu3S3V2YMbk (approved 2026-10-09). The structure (categories, featured modes, unlocks, tiers, endings) is in docs/MODES.md. **None of the 14 new modes has been driven by a person, none is tuned, none has been looked at by eye** (the category ring, the icons, the mark's ring and pointer, the checkpoint rings, the cone lot), and the frame cost of six AI drivers is not measured.

Each mode's rules as first built, and how to try one from the console: docs/MODES.md. Tuning notes from building them:
- Blackout has no night spawn table yet (T2-11).
- Rally Stage: one slack doesn't fit every landscape. Prairie is loose and Frostbite's gold is out of a stock sedan's reach.
- Smash Run: the levels differ a lot in how much there is to smash.
- Demolition Derby (reworked after the author's first drive): the semi no longer wins on armour; derbies may now be too short.
- Cannonball has no notes: write its rules into docs/MODES.md.

Left, in order:
1. **By hand first:** play each of the 14. The AI's results per mode are in docs/AI_DRIVER.md, "Status and what is next": it clears Drift Trial's Easy target in under 10 s (the target wants raising), wrecks the Pursuit runner in 6 of 9 cars, some in under 15 s (the runner may be too soft), and wins under half its Cone Courses, derbies and Keep the Cups.
2. **Cost:** benchmark a six-car race on the HD 620 (the headless playtests ran several times slower with rivals); a cheaper driving profile for rivals if it is too much.
3. **What the first versions left out:** Flat Out's launch light, lanes of different ground, fork and hazards; pickup pads on the loops; pickups for rivals in the arena; name plates over rivals; ghosts (Hot Lap's description promises one); marked corners for Drift Trial; a walled arena; a per-level Smash Run quota; a par time per course in place of one slack per mode.
4. First-run hints (each mode has a start briefing, `meta.hints.briefings`), the record book on the records ticket, then the pacing pass.

### Package 17: Road atlas (what's left)
- **P5 leftovers.** The new props' dressing weights are first guesses; `mountain` keeps the plain `pine` (snowy pines there are the author's call); `steam_vent` doesn't glow at night (it would need `"blend": "add"` in the generator's atlas entry).
- **P6. Level content** for the 22 new levels: they start from their landscape's template (docs/WORLD.md "Known issues"); twists as data, line-up checks, AI playtests, regions 1 and 2 first for the demo.
- **P7. Pacing pass:** the level curve, `ModeTiers.LEVEL_STEP` (0.085), Sprint distance by region and tier (`ModeTiers.SPRINT_DISTANCE`), the elite steps and the car-clear prices; careers against 15 hours; S3 and S4 on The Sprawl and The Works. Also: Stilt Town's and Cul-de-Sac's stations sit too far out, and the goon damage from the "damage updates" change is about 14× on unarmoured cars. Needs the author's play notes first.
- **Region 1 (The Wilds) follow-ups:**
  - *AI tuning.* Orchard Lanes: the hedgerow lanes stall the AI (stuck 18–26 a run, was 5–6); widen the gate gaps or let the AI's breakable sweep treat farm gates as passable at speed. Moose Woods: thicket stucks 8–10 (was 3); the edge pines were moved since (6cddbb01), not measured again. Snapper Bayou: Countdown AI wins fell from 4/4 to 1/4 after the props/events merge. All three were measured before the driver rebuild: measure again first (`--playtest --level=<id> --mode=countdown,sprint --runs=8 --seed=1 --trace`). M.
  - *Benchmarks.* S2 and S4 on Prairie and Moose Woods at Low on an idle machine (earlier S2 runs were spoiled by CPU load); record them in docs/PERFORMANCE.md. S.
  - *Feel and tuning pass* by hand: every smash speed, coin value, event weight and lure radius is a placeholder. Wait for the author's notes.
  - *On hold (author's call):* Region 2 (Tribe Country) and the regions 3–6 revamps, and champions, until Region 1 is settled. Don't start them.

### Package 1: Balance pass
One pass that connects and balances what is built. **Targets (the author, 2026-10-08):** about **15+ hours** to finish (all levels open, every mode seen, most cars owned), with maxing out taking longer; every mode earns a similar number of coins per minute; Defense must be winnable. B-1 (mode tiers) and B-2 (win pay) are built ("Done" above); both were fitted on the old 8 levels and 5 modes, before the road atlas and the mode menu.

**B-3. Every mode winnable.** After the fixes (`cautious` sedan, no upgrades, Prairie): Defense Easy 2 of 2, Medium 1 of 2 (lost at 201 of 210 s); Marathon Easy and Medium 4 of 6; Sprint on Prairie wins on every tier with about half the clock. Left:
- Play Defense Medium by hand before tuning further.
- The AI's Defense: it hunts by threat to the pumps but doesn't guard lanes or park to refuel (docs/AI_DRIVER.md "Limits"). Its lot-approach graph and the Sprint clock's approach allowance still assume a walled lot with an east gap: they work, but are more cautious than they need to be.
- Check Sprint on Bayou and the late levels.

**B-4. Fit the numbers** with career playtests (`scripts/ai/career.py`, all three personas from `fresh`; read `unlock_pace`, coins a minute by mode, `longest_runs_without_progress`) against the 15-hour target. The first fit's careers ran 89–105 minutes on 8 levels (wins 11 / 13 / 13 of 20, 3–4 levels open; the Rookie opened 73 of 79 pickups, so prices went up). Next: re-run them on the 30 levels and compare the pace.
- Payouts: the win bonus, `escalationSpeed` and Goonpocalypse escalation on late levels, wave stars (no cap, so a long Goonpocalypse earns a star a minute: check star totals per mode).
- Upgrades (T1-11): about 119k coins to max a sedan, and a flat +1 a level helps weak stats far more than strong ones. Proposal: a `stat_max` per stat in `<car>_info.tres`, tier-based cost bases, car prices re-fit.
- Unlocks: `Unlocks.PRICE_RANGE`, the car gem prices, and completion-count unlocks (`clears:<tier>:<n>`; none assigned yet). The target is a Rookie who sees every mode before the last level and opens about 20 pickups by the end of Prairie.
- Gift boxes: the curve was fitted to AI runs only (1–3 boxes a run). The goal is the first box in under a minute of decent play, then one every 2–4 minutes (`crush_xp`, `boxes` in `runlog.csv`). The eight games' values need measuring again.
- Other numbers: the drop mix, pickup odds and timers (docs/PICKUPS.md); fuel pressure (about 87 s of full throttle per tank in the stock sedan, measured before the handling and gearbox changes); all 9 cars' handling and wall damage; Marathon's and Defense's pit numbers; the water costs.

**B-5. By hand** (the author; the AI can't judge feel). Play from the console's `start <tier>` or `-- --play-start=<tier>` (a scratch save); runs log to `runlog.csv` as `driver = player`.
- About 30 runs across 3 cars and the modes, for the run log.
- Crush feel: the death-style weights (`GoonFx.STYLE_WEIGHTS`), `FLING_SPEED`, trauma sizes, hit-stop lengths, the bonus coins, and whether the giant's 10% speed loss feels heavy or sticky.
- Handling (docs/CAR_ART.md "Handling"): drive the stock sedan, the semi and a maxed racer on keyboard and pad. Tune live with the console's `handling` (`handling yawlow 1.9`, `handling car weight 80`), then copy the numbers into `car_handling.gd`. Questions: is full lock quick enough on keys; is the semi heavy in a good way; do walls deflect too much or too little; is the look-ahead too much; do the gearboxes and the slower climb to top speed feel right?
- Handbrake (`HANDBRAKE_*`), drift boost (`DRIFT_TIERS`) and slams (`SLAM_MIN_SPEED`).
- The checks where the AI struggled (2026-10-07 careers, on the old level order):

  | Level and mode | Start | What to look for |
  |---|---|---|
  | Crusher, Countdown, in a mid car (`--play-start=late --cars=4`) | `late` | the Rookie wrecked 3 runs in a row here |
  | Sprint and Marathon on Crusher, Highway and Bayou | `late` | clocks short or fair? |
  | Defense on Prairie and Bayou | `mid` | after B-3 |
  | Goonpocalypse in a maxed car | `maxed` | does overtime end it? A run once outlived the harness's 15 minutes |

**B-6. World and AI follow-ups:**
- Cars wedging on corners: the middle hull is in, but it didn't change Defense's stuck counts (17–41 a run). Find what still stalls them (`overlap=` in `PLAYTEST_STUCK`). S–M.
- The AI skips pickups near deep water (`waterTargetPx`): allow them at low approach speed. S.
- Highway edges look blobby: a crisper border for road surfaces, or a kerb line. S.
- Benchmark S3/S4 at Crush Effects Full; drop the Low preset to Minimal if crowds cost frames.

**B-7. Small connections** (gift boxes and unlocks):
- A small "+XP" tag flying to the gift box on the visor; the AI weights goons by XP.
- An "XP Boost" pickup or car perk through `car.crushXpMult` (the hook exists; nothing sets it).
- Cosmetics (package 15) take `paint:` ids in `meta.unlocks` when they are built.

Moved out: world build speed is a native port (docs/NATIVE.md, "What to port next"); driver perks are package 6.

**Evidence (career playtests, 2026-10-07).** Under coins × stars the first Countdown win paid 10k–17k and the Grinder owned all 9 cars after 4 runs: hence coins × (1 + 0.1 × stars). Before win pay, Sprint and Defense earned 25–80 coins a minute against 270–1,200 in Countdown and Goonpocalypse. Crusher was a wall for the Rookie (5 wrecks with every car owned) while the Grinder beat it first try.

### Packages 2, 12 and 16
Merged into package 1 (2026-10-08). What they built is under "Done".

### Package 13: Driving juice (what's left)
- **Feel pass by hand.** Nothing is tuned: how far the body leans (`ROLL_PX`, `ROLL_ACCEL`), how often the car goes up on two wheels (`TWO_WHEEL_ON`), the bounce sizes (`BUMP_*`), the wall jolt (`WALL_KICK_*`, `WALL_TRAUMA_*`), the trail density (`TRAILS`, `LEVELS`), engine pitch per gear and the backfire odds (`scene/fx/car_juice.gd`).
- **Built differently from the brief** (can change after the feel pass): the two-wheel look is an offset, a narrower body and a shadow shift, with no perspective skew (that would need a pass in the car's damage shader); the speed pull is the existing zoom-out plus a short pull on a drift boost; the bloom is an additive glow sprite.
- **Benchmark** S3/S4 on the HD 620 at Driving Effects Full against Reduced. If trails cost frames in crowds, drop Low to Minimal.
- **Sound (package 8):** the engine loops one recording. Real gear shifts and backfires want their own clips (the backfire is the transition "pop" pitched down, landings use "thud").

### Package 14: Prop layers and reactions (what's left)
The report with the prop catalog, the placement rules and the recommendations: https://claude.ai/artifact/NHJTxtvaqVsyzXSU2MSKNE. Benchmarked: about 1.4 fps on S3, nothing on S2 (docs/PERFORMANCE.md).
- **Feel pass by hand.** Nothing is tuned: the canopy fade (`FADE_ALPHA`), the springs (`PropReactions.SPRING`), `KNOCK_SPEED`, `NEAR_SMASH`; the field lattice (`fieldSpacing`, densities, gates, `CORNER_TREE`); motif sizes and weights; the spills (log distance and damage, the flood radius, the swarm, the crane's `DROP_SPEED`); which goons release piles. Check how much a crown hides goons at night.
- **Questions for the author:** should goons that release a pile get credit and run away (today they go back to their own verb)? Should spilled logs and the crane's container ever clear away? Should water towers leave a slippery puddle (it would need a terrain overlay `integrate()` reads, kept pure for the AI)?

### Package 3: Regions, waves and giants
- **T1-7.** A district's `giantism` is shown but unused (the spawner reads only the level's `giantOdds` plus the tier's). Proposal: giant odds = `giantOdds + giantism / 5`, plus a term from the run's wave. S.
- **T2-4.** Giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges, pointed at by the indicator (start from the Foreman's `Boss` verb). M.
- **T2-8.** Region mutators ("fog", "giants only", "double coins") and objectives ("crush 20 Rat Pack"), anchored on district landmarks. M.
- **T2-11.** Night as a real phase. Built: a level sets how much of each cycle is night (`LevelDef.rules.nightShare`), and night adds crush XP. Left: a night spawn table (Blackout wants one too) and ×1.5 coins at night. S.

### Package 5: Slot machine and gems
- **T1-10.** Gems buy a starting gadget and boost (`Pickups.LOADOUT`, `BOOST_LOADOUT`), cars and top pickups; the slot's gem respin and The Deal's gem hand went with the prize game reworks. Proposal, cheapest first: a gem pouch (carry up to 3 into a run), a gem-paid continue (50 health and fuel; must hook in before `endLevel`; not in Goonpocalypse; not named "Second Wind", which is now the sedan's trait), respec. M.

### Package 6: Driver perks
- **T2-13.** Driver perks and affinity (hooks: `awardBase` in `playerRoot.gd`, the purse's `MIN_COINS`/`MAX_COINS`, `car.crushXpMult`). Each car now has two traits (`CarTraits`); perks would sit beside them. M–L.

### Package 7: Goals and teaching
- **T1-15. First-run hints.** Built: a start briefing per mode (`meta.hints.briefings`), MPH smash tags with first-meeting toasts for hero props (`SmashTags`), a manual-gearbox toast. Still untaught: crush speed, the prize games' keys, where stars come from, gadget Use, that deep water hurts the car, that ordinary breakables smash and rocks don't. One-time toasts via `HudChance.toast`, flags in `meta.hints`. S–M.
- **T2-12.** Medals are built (B-1) and course modes keep a record per car (`meta.records.course`). Left: per-level records for the other modes in the Goonpocalypse shape, a "Next up" panel. M.
- **T1-16.** A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`, achievements mirrored into `meta.achievements`, lifetime totals in `meta.lifetime`, `steam_appid.txt` only in dev builds. No game code calls Steam yet. M.
- **T2-14.** Three date-seeded contracts, reroll for a gem. M. Needs T1-16.
- **T2-15.** Medal-gated top cars. S–M. Needs T1-11 (B-4).

### Package 8: Sound and radio
- **T1-13.** A `VoiceDirector`: priorities (warning > win > record > jackpot > giant > award > region), a ~5 s cooldown, no repeats in the last 3 lines, subtitles. S.
- **Mix follow-ups (2026-10-08).** Listen to the mix in play (docs/RADIO.md "Mix"). Still tonal and maybe clashing with the songs: the glockenspiel chime on every pickup and reward flyer, the results ticket's impact on a loss and on stamps, and the wolf howl at nightfall. The goon death sounds are the old shared set for every goon. Any new cue should be short and not tonal. S.
- **R-1.** The code and the first set of audio are in (14 songs, about 45 minutes, past the 8 to ship). Left: a listening pass on crossfade lengths, segment odds and the ducking depth; more tracks as they come (docs/RADIO_SONGS.md).

### Package 15: Cosmetics
- **C-1.** Unlockable looks that never change stats: paint jobs and liveries per car (look C "Showroom" is already a whole-car paint, docs/CAR_ART.md), decals and numbers, tyre-smoke and drift-spark colours, horns, a boost-flame colour, and driver outfits on the card portrait. Generated with `car_gen.js` (never painted by hand), chosen on the driver card, bought with coins or gems, or earned from medals and achievements through `Unlocks`. Saved per car in `meta.cosmetics`. M.

### Package 9: Goon depth
- **T2-1.** Add `hp` (for T2-4) and a speed-label tint when the car is too slow for a nearby heavy goon.
- **T2-3.** Goons that leave fire behind or reassemble.
- **T2-5.** True swarms.

### Package 10: Post-launch (Tier 3)
- Steam leaderboards (Goonpocalypse score, Sprint time); needs T1-16.
- Daily seeded run: the map and its contents already come from the world seed; move goon choice, giants and drops off the global RNG.
- "Heat" modifiers after the last level (written as "after level 8" when there were 8).
- Ramps and airtime crushes (Jump Jets already drop the goon mask while airborne).
- Goon nests, single-use gas pumps, boost chevrons.
- Interactive music layers; new voice lines.
- Training Grounds; custom seed entry (`TileManager.worldSeed` exists, no UI).

## Maybe

- **Elite escort goon.** Line-ups with no rank-1 goon have no fodder to crush between heavies. Add one weak escort: Goon Quarry + Grunt; the War Machine levels (blastpits, tankfarm, slagfields, theline, crusher) + Grunt; the Big Game levels + Yipper (`world/levels/*.tres` `lineup`; `test_levels.gd` wants every line-up inside its class, so add the escort to `Goons.CLASSES` too). Check an AI playtest on crusher survives past 25 s. Deferred by the author (2026-10-09).
- **Curses** (on hold: they add ways to lose a run). They would be a `K.CURSE` kind in `Pickups.DATA`; icons exist in `scripts/art/pickup_icons.js` (skipped by the generator): Cursed Idol, Glass Cannon, Blood Moon, Devil's Bargain, Gremlin Sack.

## Decisions already made

- **Modes (2026-10-09):** Sprint, then Countdown on every level, then one Crusher, one Trial and one Goon Cup mode picked for it; a win in any of the three opens the next level, on Medium at a region's finale. Rejected: Convoy, Turf War, Big Game, Last Drop, Crush-Off, Odd Jobs, Goon Ball, stunt and airtime modes, Hill Climb. Rivals are the garage's own drivers. Fixed or random maps, pickups and gift boxes are decided per mode (`Modes.DATA`); pickups in a mode are only ones useful there. Records are kept per car. Cannonball and Pursuit have light goons. The demo shows the modes its two regions feature. Marathon, Defense and Goonpocalypse stay and ship in 1.0; a mode can be retired later.
- **Tiers:** every mode on every level has Easy, Medium and Hard, picked in run setup; Hard means a longer goal and a tougher world, and opens once Medium is beaten; tiers pay a bigger win bonus, a first-clear bonus and medals.
- Sprint's clock ends the run; Marathon adds one Sprint clock per station.
- **Payout** is (coins + a win bonus) × (1 + 0.1 × stars), the multiplier capped at ×3 (20 stars). The win bonus pays by the minute of the goal and grows with the tier and level.
- The full game takes about 15+ hours to finish; prices and unlock pace are fitted to that (package 1).
- The demo and the full game share the save; one codebase (`Root.IS_DEMO`). The demo opens Common and Uncommon pickups, every tree's root and the Casino tree's first tier.
- **Unlocks:** pickups unlock in a separate tree per kind, nearly all locked on a new save; locked ones never drop and show as "???" until their parent is open, then with a preview and price. Entry cars cost coins; advanced ones (semi, supercar, racer, police, ambulance) cost coins and gems. No level gates on cars. Prices are placeholders until B-4.
- Saves from before the road atlas (version 8) start over; nothing from them is kept.
- **Gift boxes:** crush goals are crush XP toward gift boxes holding one prize game. The games are ranked by measured strength; only the weakest (the Claw Crane) starts unlocked. Higher boxes hold better versions, boxes pay no star, and no game pays another.
- Waves are one clock for the whole run, not per district, with no cap. Districts still set faction, goons, name and giantism.
- Pickups show short name tags wherever an icon stands for something held or offered.
- Menu shortcuts are letters near WASD; numbers only for lists such as stops and tabs.
- Cosmetics cost coins or gems.
- Tree canopies may hide goons beneath them.
- The two-wheel tilt is style only; cars never tip over.
- No jingles or stingers over the radio: the music plays straight through a run's start, its prize games and its results.
- **Radio:** one station of in-house tracks, GoonCrusher Radio, plus Radio Off; no other stations (2026-10-10; Classical Lofi and Lofi were tried and dropped). Changed in the pause menu and Settings, no driving key. Talk is not contextual (no night, level or event lines).

## Open questions for the author

Numbers are kept from earlier versions; 1, 2 and 7 to 10 are answered (see "Decisions").

3. Fuel pressure: should fuel or health be the main way runs end?
4. Price?
5. Gems: never sold? Is a gem-paid continue acceptable?
6. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
