# Gameplay suggestions

Suggestions to discuss, not a spec; the author runs gameplay as a separate project. Effort: **S** under a day, **M** 1–3 days, **L** a week or more.

## Done (one line each)

- **T0-1** `levels` is saved and migrated; the demo and full game share the save.
- **T0-2** A run ends exactly once (`Level.hasEnded`, `endLevel`), Abandon included.
- **T0-3** Countdown counts down and is won at 0.
- **T0-4** Stations are placed on reachable land and pinned; `world_ready` signals a valid `Root.station`.
- **T0-5** Sprint's clock comes from the route to its station; running out ends the run (NOTIME).
- **T0-6** Per-level mode unlock chain (`Root.isModeUnlocked`); demo gates read `Root.IS_DEMO`.
- **T0-7** Marathon and Defense no longer crash.
- **T0-8** Stat fixes: Oil (`fuelBurn`), Dice, traction (`gripFor`), armor once, upgrade cap 20, in-run cap 150, Clover/Dice labels.
- **T0-9** Payout = coins × (1 + 0.1 × stars) (`Root.STAR_BONUS`; was coins × stars until the career playtests), credited on the summary; Abandon pays like a death.
- **T0-10** Start pauses on a controller.
- **Goon physics layer** (layer 3, goons don't collide with each other), **`meta` in the save**, **explosion pooling** (`Level.explode`, used by GoonFx too).
- **T1-1** Debug run log (`user://runlog.csv`, `scripts/debug/run_log.gd`).
- **T1-2** Goonpocalypse: faster escalation, uncapped waves, score, survival target, records.
- **T1-3** Marathon: a relay of 5 legs with refuel, heal, repair, Pit Shop and a free slot machine at each station.
- **T1-4** Defense: a station barrier, sieging goons, lanes from the world generator, refuel in the driveway.
- **T1-5, T1-6, T1-8, T2-9** Per-level terrain, walls, surfaces and hazards (the world revamp, docs/WORLD.md).
- **T1-7 (regions)** Regions are the map's districts, with faction, goons, name and tint.
- **T1-9** Slot machine paylines, bets, jackpot and Dice (docs/PICKUPS.md).
- **T2-2, T2-7** Goon movement archetypes; 79 pickups in nine kinds (docs/GOONS.md, docs/PICKUPS.md).
- **T2-3 (drowning credit)** A drowning within 3 s of the car's touch counts as a crush ("SPLASH").
- **T2-10 (most)** Breakables, explosives, faction landmarks, log and manhole spawns.
- **Package 2 (T1-12, T2-6)** Crush feel: four death styles (splat, shove, hood ride, fling) picked by speed and hit point, goo spatter, impact bursts, camera trauma and kick, hit-stop and zoom punch on giants, bosses and crowds, a rising combo tick and hot combo readout; multi, drift, giant and boss crush bonuses; best combo as a car record; Crush Effects, Screen Shake and Hit-Stop settings (docs/GOONS.md, "Crush feel"). Crushes still chip 5 before armour, by choice.
- **Driving controls** Handbrake powerslide (Space / RB, shaped per car by its stats; a held slide charges a drift boost, blue then orange sparks, fired on release; the tail and flanks slam goons), a second held slot for boosts (Shift / LB: Nitro as 2 stored burns, the new Hop, Jump Jets), gadgets on E / X; settings v2 migrates saved bindings (CLAUDE.md, docs/PICKUPS.md). Run setup sells a starting gadget and boost for gems.
- **Menu juice** Garage shutter, hatch and tire-smoke transitions, and a mouse pass so every menu works with the mouse alone (docs/UI.md, "Transitions"; test checklist in docs/TEST_SCOPE_TRANSITIONS.md).
- **Package 14 (P-1 to P-5, code)** Prop layers, reactions and layout (docs/WORLD.md "Prop reactions"): trees (oak, pine, cypress, dead tree) are baked as a ground layer and a canopy drawn over the car and goons, which fades to 40% while the car is under it (never for goons) and shakes and drops leaves (snow on Frostbite) when the trunk is hit or a blast goes off nearby; the crane's jib is its over-the-car layer; every other prop answers a hit (squash, wobble, sway, shake, thud and dust, a hydrant's spray), and cones knock over and stop being walls (the AI plans through them); breakables hit just under their smash speed crack and chip. Fences and hedges lie as field lines on a lattice per region, with gates, corner oaks and paddocks of hay bales (P-3); camps, groves, orchards, wreck piles, junkyards, roadblocks and pile-ups come as motifs (P-5); barriers line the road. Interactive props (P-4, `Spill`): log piles that goons cut loose at the car (the logs flatten goons and stay as obstacles), water towers that flood goons flat, billboards that topple away from the car, beehives that let a goon-hunting swarm loose, and cranes that drop their container when rammed; what spills is kept per chunk. Tufts and reeds bend away from the car. The levels lost their dead feature keys and got prop counts of their own. Feel pass and benchmark still to do (below).
- **Package 13 (D-1 to D-4, code)** Driving juice (`CarJuice`, docs/CAR_ART.md "Driving feel"): the body leans out of turns and tips onto two wheels in hard ones, the nose dips and the tail squats, the body bounces on landings, wall hits and ground changes, and wall hits jolt the camera by speed. Speed lines, dust, spray and clods per surface, slide smoke, wall sparks, a drift-boost flame. Engine pitch through the gears, squeal from slip, backfires on lift-off. All show only, with a Driving Effects setting. Feel pass and benchmark still to do (below).
- **Package 12 (U-1 to U-5, most)** One unlock system (`Unlocks`, docs/PICKUPS.md "Unlocks"): four states (hidden, shown, ready, open), nine pickup trees with 10 roots open on a new save, placeholder prices by rarity plus ten play unlocks (nights, giants, Scrap crushes, a won Sprint, modes, Quarry, survival), locked pickups never drop or get offered (fixed rewards fall back to an open ancestor), buying in the Goonopedia, results-ticket unlocks and a Next unlock line in run setup, advanced cars cost gems too, level gates in `LevelDef.unlockModes`, career personas shop for pickups, the demo caps pickups at Uncommon, and saves before version 6 start over.
- **Package 11 (M-1)** Left-hand menu keys: hints show Space for Accept (Enter still works) and WASD before the arrows; F Upgrade or Gadget, V Boost, R Records, G Goonopedia; 1–8 pick a level poster, 1–6 a Goonopedia tab; the focused upgrade row's price becomes a BUY button and holding Accept keeps buying (docs/UI.md).
- **Career playtests** Three personas play the whole game through the real menus (docs/AI_DRIVER.md).
- **W-1** Run-wide waves: one wave clock for the whole run (`Region.wave`), a star and a wave chest every 60 s with no cap, the spawner's goon mix from the run's wave; districts only decide who spawns; the AI no longer hunts districts for stars (docs/WORLD.md).
- **N-1** Pickup name tags (`Pickups.shortName`) on the gadget and boost boxes, new power-up rings, slot reels, the Scratch Card, the Claw Crane and the Vault (docs/PICKUPS.md, "Name tags").
- **Package 16 (G-1 to G-4)** Gift boxes: crush XP by goon rank, giants, bosses, combo, style and night; box *n* needs 50 n² XP; Cardboard to Diamond tiers; six prize games weakest first (Claw Crane, Scratch Card, Prize Wheel, The Deal, Slot Machine, the new Vault), only the Claw open on a new save; better versions in higher boxes; no star per box; `--prize=` for testing (docs/PICKUPS.md, "Gift boxes").
- **R-1 (code)** Radio: three stations scanned from `sound/radio/` (shuffle bags, crossfades, idents, talk and ads between songs, lazy threaded loads), picked in the pause menu and Settings, a now-playing card in the HUD and menu, music ducking under the Voice bus (docs/RADIO.md). Songs in: *Crush Hour*, *Gooncrusher*, *Full Tank, Empty Head*, *My Baby Loves My Truck*, *Cheap Beer, Premium Gas*, *Trailer Park Superstar*, *Welcome to Nowhere*, *Gas Station Romance*, *She Left Me at the Truck Stop* (docs/RADIO_SONGS.md).
- **Tier 3** Shallows, fords and bridges; most of a daily seeded run (the map and its contents come from the world seed).

## Work packages, in order

Package numbers are IDs (other docs link to them); the table is in the suggested order.

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 1 | Balance pass (absorbs the package 2 follow-ups and packages 6, 12 and 16) | B-1 to B-7 below | L + play time | — |
| 13 | Driving juice (what's left) | feel pass, benchmark | S + play time | — |
| 6 | Driver perks | T2-13 | M–L | 1 |
| 14 | Prop layers, reactions and layout (what's left) | feel pass, benchmark | S + play time | — |
| 3 | Regions, waves and giants | T1-7 (giantism), T2-4, T2-8, T2-11 | M–L | 1 |
| 5 | Slot machine and gems | T1-10 | S | 1 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 1 for T2-15 |
| 8 | Sound and radio | T1-13, T1-14, R-1 | M + in-house tracks | — |
| 15 | Cosmetics | C-1 | M | 1 |
| 9 | Goon depth | T2-1, T2-3, T2-5 | M | — |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3, 9, 13 and 14.

### Package 1: Balance pass
One pass that connects and balances what is built. It absorbs the package 2 follow-ups, the economy (old package 6, minus driver perks), the unlock pace (old 12) and the gift-box curve (old 16). **Targets (the author, 2026-10-08):** about **15+ hours** to finish (all levels open, every mode seen, most cars owned), with maxing out taking longer; every mode earns a similar number of coins per minute; all five modes ship in 1.0, so Defense must be winnable.

In priority order:

**B-1. Mode tiers** (the author's idea, 2026-10-08). Every mode on every level has three completions, **Easy, Medium and Hard** (8 levels × 5 modes × 3 = 120).
- Picked in run setup next to the mode medallion. Hard opens once Medium is beaten; beating a tier also credits the ones below it.
- Harder means a longer or stricter goal **and** a tougher world (faster escalation, more giants). Countdown: a longer clock. Sprint: tighter slack. Marathon: more legs. Defense: a longer hold. Goonpocalypse: a longer survival target.
- The next level opens on 3 modes (Countdown, Sprint and one more); in act 2 one of them must be won on Medium, in act 3 two (the author, 2026-10-08, after the careers opened all 8 levels in 3-4 hours on Easy alone).
- Rewards: the win bonus (B-2) × 1 / 2 / 4; a one-time first-clear bonus (gems on Hard); bronze, silver and gold medals on the level poster and the records ticket (folds in T2-12's medals); unlocks gated on completion counts (`Unlocks` conditions).
- The save keeps the tier beaten per mode per level; bump `SAVE_VERSION` and migrate a beaten mode as Easy.
- *Built (2026-10-08):* `ModeTiers` (`scripts/global/mode_tiers.gd`) holds every number: Countdown clock ×1 / 1.6 / 2.2, Goonpocalypse target ×1 / 1.75 / 2.5, Sprint slack ×1.15 / 1 / 0.85, Marathon 3 / 5 / 7 legs, Defense 150 / 210 / 270 s; escalation ×1 / 1.3 / 1.6, giant odds +0 / 8 / 16, spawn interval ×1 / 0.9 / 0.8. Run setup's tier chips (W/S), medals on posters and medallions, `Level.tier`, `PlayerData.gameTier` and the level entry's `tiers` (save version 7), `clears:<tier>:<n>` unlock conditions, `--tier=` for playtests, personas pick tiers (the Rookie stops at Medium). No completion-count unlocks are assigned yet (B-4).

**B-2. Win pay.** A flat **win bonus** per mode that grows with the level, added to the run's coins before the star multiplier, fitted so racing and Defense earn about as much a minute as Countdown. Before it, the careers earned 25-80 coins a minute in Sprint and Defense against 270-1,200 in Countdown and Goonpocalypse; a won Sprint could pay 1-23 coins.
- *Built (2026-10-08):* `ModeTiers.winBonus` pays by the minute of the goal (`goalSeconds`: the clock, target or hold, or the races' planned clock): Countdown 100, Sprint 150, Marathon 120, Defense 150, Goonpocalypse 60 coins a minute, × 1 / 1.3 / 1.6 by tier, × (1 + 0.35 a level after the first). Prairie pays 270-1,800 a win, Crusher 1,300-11,000. A flat bonus was tried first: the Grinder farmed Prairie's Hard Sprint (1,600 a minute-long run) eleven times running at 1,575 coins a minute. First clears pay 300 / 800 / 2,000 coins and 0 / 1 / 3 gems × the level step. `Level.runPayout` is the one payout the ticket, run log and harnesses use. Also fixed: the results ticket and run log read the mode and level after a win had moved the selection on, so a won run could be titled, recorded and logged as the next mode or level.

**B-3. Every mode winnable.** In the careers Defense was 0 for 9+ (the barrier falls at 85-105 s whatever the car does, and some runs stick where Defense starts the car, `Level.DEFENSE_START`), Marathon 1 of 6 (stuck between legs, out of fuel), Sprint fair on Prairie but short on Bayou, and one Crusher clock was 46.8 s. Fix the rules first (barrier strength, siege rate, start spot, clocks), then the AI's Defense strategy (rank goons by distance to the walls and `siege`, guard the lanes, refuel when low) so the careers can measure it.
- *Defense (2026-10-08):* the barrier fell because goons piled up, not because it was weak: every lane spawns each round and Countdown's escalation ran on, so 79 goons were alive by 80 s with 26 at the walls. Now Defense spawns 2.5× less often (`ModeTiers.DEFENSE_SPAWN_SCALE`, `SpawnManager.spawnScale`), a blow on the walls does half its damage (`station.SIEGE_DAMAGE`) and the hold is a fixed time per tier. `cautious` sedan, 8 upgrades: Prairie Easy 3 of 3 (was 0), Medium 0 of 3 (fell at 122-173 of 210 s); Bayou Easy lost one at 148 s with 1 crush (the AI). Play Medium by hand before tuning further. Every car also got an always-on middle hull (`CollisionShape2D_body`; a goon against it is left to `slamGoons`); it didn't change Defense's stuck counts (17-41 a run).
- *Marathon (2026-10-08):* traces showed the car stuck 30-40 s per leg inside the station it had just reached, sliding along the lot's walls toward its one east gap with 50-60 goons piling in. A station Marathon has moved past now opens its lot (`station.openLot`: the walls fade and stop blocking). Easy and Medium went from 1 of 4 won to 4 of 6 (Prairie Easy 2 of 2, stuck 1-10 a run, was 22-50).
- *Sprint:* Prairie Easy and Medium 4 of 4, using about half the clock; Hard wins too (the Grinder won it 11 times). Check Bayou and the late levels.

**B-4. Fit the numbers** with career playtests (`scripts/ai/career.py`, all three personas from `fresh`; read `unlock_pace`, coins a minute by mode, `longest_runs_without_progress`) against the 15-hour target:
- Payouts: the win bonus, `escalationSpeed` and Goonpocalypse escalation on late levels, wave stars (no cap since W-1, so a long Goonpocalypse earns a star a minute).
- Upgrades (T1-11): every car uses `int((lvl+1)^1.6 × 15)`, about 119k coins to max one car, and a flat +1 a level helps weak stats far more than strong ones. Proposal: a `stat_max` per stat in `<car>_info.tres`, tier-based cost bases, car prices re-fit.
- Unlocks: `Unlocks.PICKUP_PRICE`, the car gem prices, and the completion-count unlocks from B-1. The target is a Rookie who sees every mode before the last level and opens about 20 pickups by the end of Prairie.
- Gift boxes: `CrushPrizes.XP_BASE` 50 and `XP_EXP` 2 were fitted to AI runs only. The goal is the first box in under a minute of decent play, then one every 2-4 minutes (`crush_xp`, `boxes` in `runlog.csv`).
- *First fit (2026-10-08):* careers on the new code (tiers, win pay, the Defense and Marathon fixes) against this morning's: wins 9/2/6 → 11/13/13 of 20 (Rookie, Grinder, Explorer), levels open 2/2/1 → 4/3/3 in 89-105 minutes, the longest stall 9/10/4 → 2/2/1 runs. Income rose 4-6×: the Rookie opened 73 of 79 pickups in 89 minutes, and three Goonpocalypse runs that outlived the harness's 15 minutes paid 33,000-50,000 each. Changed: Goonpocalypse overtime past its target (`SpawnManager.overtime`: escalation ×2, spawn floor 0.3 s), the star multiplier capped at ×3, Medium gates in acts 2 and 3, pickups ×3-3.5 (1,000 / 3,000 / 8,000 / 20,000 + 5 gems / 15 gems), cars ×3 (Van 3,000 to Ambulance 105,000), prize games ×2, upgrades × the car's `UPGRADE_COST_SCALE` (sedan and van 1 to ambulance 2.5). Next: re-run the careers and compare the pace with 15 hours.
- Other numbers: the drop mix, pickup odds and timers (docs/PICKUPS.md); fuel pressure (about 87 s of full throttle per tank in the stock sedan); all 9 cars' handling and wall damage; Goonpocalypse (escalation 2×, floor 0.6 s); Marathon (heal 35, 60° turn); Defense (rest 2 s, aggro 650, refuel 4/s).

**B-5. By hand** (the author; the AI can't judge feel). Play from the console's `start <tier>` or `-- --play-start=<tier>` (a scratch save); runs log to `runlog.csv` as `driver = player`.
- About 30 runs across 3 cars and all five modes, for the run log.
- Crush feel: the death-style weights (`GoonFx.STYLE_WEIGHTS`), `FLING_SPEED`, trauma sizes, hit-stop lengths, the bonus coins, and whether the giant's 10% speed loss feels heavy or sticky.
- Steering at speed (new 2026-10-08, every car): the wheel is capped so the nose turns at most `maxYaw` = 2.4 + 0.015 × steering rad/s (`MAX_YAW`, `MAX_YAW_PER_STEER`, `steerLimit`). It binds only at speed: a stock sedan near its top speed, and a maxed police car above about 800 px/s. Before the cap, the maxed police car turned about 7.5 rad/s at 1,600 px/s. Check that fast cars still feel sharp, not floaty. If they still feel twitchy, the next suspect is the steering ramp (`nextSteering`: 0.01 + traction / 100 per tick, so full lock in 2–3 ticks on a maxed car).
- Handbrake (`HANDBRAKE_*`: grip 0.16/0.07, steer ×1.6, throttle 0.85, decel 60), drift boost (`DRIFT_TIERS`: 40 ticks for +120 px/s, 100 for +240) and slams (`SLAM_MIN_SPEED` 150, 2 coins).
- The checks where the AI struggles:

  | Level and mode | Start | What to look for |
  |---|---|---|
  | Crusher, Countdown, in a mid car (`--play-start=late --cars=4`) | `late` | the Rookie wrecked 3 runs in a row here |
  | Sprint and Marathon on Crusher, Highway and Bayou | `late` | clocks short or fair? |
  | Defense on Prairie and Bayou | `mid` | after B-3 |
  | Goonpocalypse in a maxed car | `maxed` | does it ever end? A run outlived the harness's 15 minutes |

**B-6. World and AI follow-ups:**
- Bumper-only car collision: add a middle polygon or side capsule on layer 1 only, keeping crushing and `carBodyArea` contact unchanged. Cars stall on it, and it adds to the stuck events in races. S–M.
- The AI skips pickups near deep water (`waterTargetPx`): allow them at low approach speed. S.
- Highway edges look blobby: a crisper border for road surfaces, or a kerb line. S.
- Benchmark S3/S4 at Crush Effects Full; drop the Low preset to Minimal if crowds cost frames.
- *Done (2026-10-08):* Frostbite's passes (deep snow and ice inside a pass become snow, `passWidth` 1800); landmark beacons dim to 15% by day (`Level.fadeBeacons`).

**B-7. Small connections** (gift boxes and unlocks):
- A small "+XP" tag flying to the crush pill; lifetime boxes and the best box in `meta.lifetime`; the AI weights goons by XP.
- An "XP Boost" pickup or car perk through `car.crushXpMult`.
- *Done (2026-10-08):* lifetime gift boxes and the best run's count in `meta.lifetime` (`boxes`, `bestBox`), a `boxes:<n>` unlock condition, and boxes and medals on the records ticket.
- Cosmetics (package 15) and radio stations (R-1) take `paint:` and `station:` ids in `meta.unlocks` when they are built.

Moved out: world build speed is a native port (docs/NATIVE.md, "What to port next"); driver perks are package 6.

**Evidence so far (career playtests, 2026-10-07).** Under coins × stars the first Countdown win paid 10k-17k and the Grinder owned all 9 cars after 4 runs; coins × (1 + 0.1 × stars) fixed that (Countdown 270-560 coins a minute, Goonpocalypse 240-1,230). Countdown alone opened every level until the 3-mode gate. Crusher is a wall for the Rookie (5 wrecks with every car owned) while the Grinder beat it first try. Also changed then: the AI's race budget and Defense hunting, `start <tier>` for testing by hand, only the first level open on a new save, stations at least 85% of a Sprint out, and three menu focus bugs.

### Packages 2, 12 and 16
Merged into package 1 (2026-10-08). What they built is under "Done".

### Package 13: Driving juice (what's left)
Built (2026-10-08, "Done" above): `CarJuice` in `scene/fx/car_juice.gd`, documented in docs/CAR_ART.md "Driving feel". It runs outside `integrate()`, reads the car after it moves, and never writes velocity or input. What is left:
- **Feel pass by hand.** Nothing is tuned yet. Check how far the body leans (`ROLL_PX` 4.5, `ROLL_ACCEL` 1300) and how often the car goes up on two wheels (`TWO_WHEEL_ON` 0.9 held 6 ticks above 380 px/s). Check the bounce sizes (`BUMP_*`), the wall jolt (`WALL_KICK_*`, `WALL_TRAUMA_*`), the trail density (`TRAILS`, `LEVELS`), where the speed lines start (`SPEED_LINES_FROM` 0.82 of top speed on grass), engine pitch per gear and the backfire odds (0.55).
- **Built differently from the brief:** the two-wheel look is an offset, a narrower body and a shadow shift, with no perspective skew on one edge. A sprite can't do that without a shader pass on the car's damage shader. The outer tyres smoke, and the inner ones throw dust when they land. The speed pull is the existing zoom-out with speed, plus a short pull on a drift boost. The bloom is an additive glow sprite, not a real glow pass. All of these can change after the feel pass.
- **Benchmark** S3/S4 on the HD 620 at Driving Effects Full against Reduced. If trails cost frames in crowds, drop Low to Minimal.
- **Sound package (8):** the engine sample loops one recording. Real gear shifts and backfires want their own clips (the backfire now uses the transition "pop" pitched down, and landings use "thud").

### Package 14: Prop layers and reactions (what's left)
Built (2026-10-08, "Done" above; docs/WORLD.md "Props and decor", "Interactive props" and "Prop reactions", docs/WORLD_ART.md "Layered props"). The report with the prop catalog, the placement rules and the recommendations: https://claude.ai/artifact/NHJTxtvaqVsyzXSU2MSKNE. What is left:
- **Feel pass by hand.** Nothing is tuned: the canopy fade (`FADE_ALPHA` 0.4), the springs (`PropReactions.SPRING`), leaves 3-12 a hit, `KNOCK_SPEED` 120, `NEAR_SMASH` 0.7; the field lattice (`fieldSpacing`, the densities, gates, `CORNER_TREE`); motif sizes and weights; the spills (log distance and damage, the flood radius, the swarm's kills and stings, the crane's `DROP_SPEED`); which goons release piles. Check how much a crown hides goons at night.
- **Benchmarked** (docs/PERFORMANCE.md): an A/B costs about 1.4 fps on S3 and nothing on S2. S3 sits about 8 fps under the 2026-10-07 numbers with package 14 off too, so that drop is from other changes.
- **Questions for the author:** should goons that release a pile get credit and run away (the brief's "maybe becoming regular goons": today they simply go back to their own verb)? Should spilled logs and the crane's container ever clear away? Should water towers leave a slippery puddle (it would need a terrain overlay `integrate()` reads, kept pure for the AI)?

### Package 3: Regions, waves and giants
- **T1-7.** `giantism` is shown but unused. Proposal: giant odds = `giantOdds + giantism / 5`, plus a term from the run's wave (`Region.waveIntensity()`). S.
- **Wave stars** have no cap since W-1, so a long Goonpocalypse earns a star a minute: check star totals per mode in package 1 alongside the payout model (question 2).
- **T2-4.** Giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges, pointed at by the indicator (start from the Foreman's `Boss` verb). M.
- **T2-8.** Region mutators ("fog", "giants only", "double coins") and objectives ("crush 20 Rat Pack"), anchored on district landmarks. M.
- **T2-11.** Night as a real phase: about 150 s day and 90 s night, a night spawn table, ×1.5 coins at night (`Timer.gd` `daylength`). S.

### Package 5: Slot machine and gems
- **T1-10.** Gems buy rerolls, a starting gadget and boost (`Pickups.LOADOUT`, `BOOST_LOADOUT`) and a new hand in The Deal. Proposal, cheapest first: a gem pouch (carry up to 3 into a run), Second Wind (pay gems to continue with 50 health and fuel; must hook in before `endLevel`; not in Goonpocalypse), respec. Cosmetics move to package 15; locked pickups to package 12. M.

### Package 6: Driver perks
- **T2-13.** Driver perks and affinity (hooks: `awardBase` in `playerRoot.gd`, the purse's `MIN_COINS`/`MAX_COINS`). The economy that was here is in package 1 (B-4). M–L.

### Package 7: Goals and teaching
- **T1-15. First-run hints.** Nothing teaches crush speed, the slot controls, where stars come from, gadget Use, that deep water wrecks the car, or that breakables smash and rocks don't. One-time toasts via `HudChance.toast`, flags in `meta.hints`. S–M.
- **T2-12.** Medals (now package 1, B-1) and per-level records for every mode (the Goonpocalypse shape in `meta.records`), a "Next up" panel. M.
- **T1-16.** A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`, achievements mirrored into `meta.achievements`, lifetime totals in `meta.lifetime`, `steam_appid.txt` only in dev builds. M.
- **T2-14.** Three date-seeded contracts, reroll for a gem. M. Needs T1-16.
- **T2-15.** Medal-gated top cars. S–M. Needs T2-12, T1-11.

### Package 8: Sound and radio
- **T1-13.** A `VoiceDirector`: priorities (warning > win > record > jackpot > giant > award > region), a ~5 s cooldown, no repeats in the last 3 lines, subtitles. S.
- **T1-14.** Menu music, ducking under voice, stingers. S plus licensing.
- **R-1. Radio stations.** The code is done (above, docs/RADIO.md). Left: more in-house tracks (GoonCrusher Radio has 9 songs (about 28 minutes, past the 8 to ship), seven ads, twelve DJ talk segments and nine idents, docs/RADIO_SEGMENTS.md; Classical Lofi and Lofi have none and stay hidden until they do; docs/RADIO.md part 1 and docs/RADIO_SONGS.md), then a listening pass on crossfade lengths, segment odds and the ducking depth. Stations could become unlocks (package 12, `Radio.isStationOpen`).

### Package 15: Cosmetics
- **C-1.** Unlockable looks that never change stats: paint jobs and liveries per car (look C "Showroom" is already a whole-car paint, docs/CAR_ART.md), decals and numbers, tyre-smoke and drift-spark colours, horns, a boost-flame colour, and driver outfits on the card portrait. Generated with `car_gen.js` (never painted by hand), chosen on the driver card, bought with coins or gems, or earned from medals and achievements through the unlock registry (package 12). Saved per car in `meta.cosmetics`. M.

### Package 9: Goon depth
- **T2-1.** Add `hp` (for T2-4) and a speed-label tint when the car is too slow for a nearby heavy goon.
- **T2-3.** Goons that leave fire behind or reassemble.
- **T2-5.** True swarms.

### Package 10: Post-launch (Tier 3)
- Steam leaderboards (Goonpocalypse score, Sprint time); needs T1-16.
- Daily seeded run: move goon choice, giants and drops off the global RNG.
- "Heat" modifiers after level 8.
- Ramps and airtime crushes (Jump Jets already drop the goon mask while airborne).
- Goon nests, single-use gas pumps, boost chevrons.
- Interactive music layers; new voice lines.
- Training Grounds; custom seed entry (`TileManager.worldSeed` exists, no UI).

## Maybe

**Curses** (on hold: they add ways to lose a run). They would be a `K.CURSE` kind in `Pickups.DATA`; icons exist in `scripts/art/pickup_icons.js` (skipped by the generator): Cursed Idol, Glass Cannon, Blood Moon, Devil's Bargain, Gremlin Sack.

## Decisions already made

- All five modes are playable; the demo offers Countdown and Sprint.
- Unlocks: Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint. A new save opens only the first level; each next one opens once 3 modes are beaten on the one before (Countdown, Sprint and one of the rest; 2 in the demo), in act 2 one of them on Medium and in act 3 two. Most pickups start locked, one tree per kind (package 12).
- Sprint's clock ends the run; Marathon adds one Sprint clock per station.
- Payout is (coins + a win bonus) × (1 + 0.1 × stars), the multiplier capped at ×3 (20 stars). The win bonus pays by the minute of the goal and grows with the tier and level (package 1, B-2).
- The full game takes about 15+ hours to finish; prices and unlock pace are fitted to that (package 1).
- Every mode on every level has Easy, Medium and Hard completions, picked in run setup; Hard means a longer goal and a tougher world; the next level opens on Easy in 3 modes; tiers pay a bigger win bonus, a first-clear bonus, medals and completion-count unlocks (package 1, B-1).
- Marathon and Defense ship in 1.0.
- The demo and the full game share the save; one codebase (`Root.IS_DEMO`).
- Crush goals are crush XP toward gift boxes holding one prize game. The games are ranked by measured strength: the Slot Machine beats pick-one games because it pays three things. Only the weakest game (the Claw Crane) starts unlocked. Higher boxes hold better versions, and boxes pay no star (package 16).
- Waves are one clock for the whole run, not per district, with no cap: you keep going wave after wave. Districts still set faction, goons, name and giantism (W-1).
- Pickups show short name tags in small type wherever an icon stands for something held or offered (N-1).
- Menu shortcuts are letters near WASD; numbers only for lists such as levels and tabs.
- Pickups unlock in a separate tree per kind; locked ones never drop and show as "???" until their parent is unlocked, then with a preview and price.
- Entry cars cost coins; advanced ones (semi, audi, racer, police, ambulance) cost coins and gems. No level gates on cars.
- The demo opens Common and Uncommon pickups only.
- Saves from before the unlocks (version 6) start over; nothing from them is kept.
- Unlock prices are placeholders, set now and re-fit in package 6.
- Cosmetics cost coins or gems.
- Tree canopies may hide goons beneath them.
- The two-wheel tilt is style only; cars never tip over.
- Radio: three stations of in-house tracks: GoonCrusher Radio (funny vocal tracks and radio talk), Classical Lofi and Lofi. Changed in the pause menu and Settings, no driving key. Talk is not contextual (no night, level or event lines).

## Open questions for the author

1. *(Answered: Marathon and Defense ship in 1.0.)*
2. *(Answered: stars stay a small multiplier, plus a win bonus.)*
3. Fuel pressure: should fuel or health be the main way runs end?
4. Price? *(Length answered: 15+ hours.)*
5. Gems: never sold? Is a gem-paid continue acceptable?
6. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
7. *(Answered: the demo opens Common and Uncommon pickups; see "Decisions".)*
8–10. *(Answered: prize games ranked by measured strength, the weakest open first; better versions in higher boxes, no star per box; no wave cap. See "Decisions".)*
