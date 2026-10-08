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
| 1 | Playtest and tune | the numbers below, world follow-ups | S + play time | — |
| 12 | Unlocks and progression (what's left) | pace check | S | 1 |
| 16 | Crush prizes (what's left) | selling prize games, the curve by hand | S | 1 |
| 6 | Economy | T1-11, T2-13, late-level payouts | M | 1, 12, 16 |
| 13 | Driving juice | D-1 to D-4 | M | — |
| 14 | Prop layers and reactions | P-1, P-2 | M | — |
| 3 | Regions, waves and giants | T1-7 (giantism), T2-4, T2-8, T2-11 | M–L | 1 |
| 5 | Slot machine and gems | T1-10 | S | 12 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 6 for T2-15 |
| 8 | Sound and radio | T1-13, T1-14, R-1 | M + in-house tracks | — |
| 15 | Cosmetics | C-1 | M | 12 |
| 9 | Goon depth | T2-1, T2-3, T2-5 | M | — |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3, 9, 13 and 14.

### Package 1: Playtest and tune
- **Data:** about 30 hand-played runs across 3 cars and all five modes (`user://runlog.csv`, filter out `driver = ai`; `pk_<kind>` counts pickups by kind), plus AI playtests and **career playtests** (`docs/AI_DRIVER.md`, "Career playtests"). Career playtests have the Rookie, Grinder and Explorer personas play through the real menus from any point in progress (`--start=fresh` to `maxed`). Use them for progression pace (milestones, runs without progress), the economy (coins per minute by mode, shopping totals) and blocks or bugs (issues, script errors).
- **Numbers to check:** Sprint clocks (`sprintSlack`, `ROUTE_FACTOR`); the drop mix and pickup odds, prices and timers (docs/PICKUPS.md); fuel pressure (about 87 s of full throttle per tank in the stock sedan); all 9 cars' handling and wall damage; Goonpocalypse (escalation 2×, floor 0.6 s, target 2×); Marathon (5 legs, heal 35, 60° turn); Defense (barrier 1000, rest 2 s, aggro 650, refuel 4/s).
- **First career playtests (2026-10-07):** Rookie and Grinder from `fresh` (12 runs each), Explorer from `maxed` (12 sessions) and `mid` (8). Times are minutes of level time.
  - **Payouts swamp every price.**
    - The first Countdown win pays 10k-17k (about 1,000 coins × 9-11 stars). By level 6-8 a run pays 150k-360k.
    - The Grinder owned all 9 cars after 4 runs (23 min) and banked 813k by run 12. Countdown earns 16k-19k coins a minute.
    - One Goonpocalypse run with a maxed car survived the harness's 15-minute cap (4,209 crushes) and paid 1.93M.
    - Stars as a multiplier is the cause (open question 2). The economy work in package 6 needs that answer first.
  - **Countdown alone opens every level** (fixed: 3 modes now, `LevelDef.unlockModes`). Beating any mode opened the next level, so both personas that follow the path opened all 8 levels in 7 runs (about 40 min) playing nothing but Countdown. The Rookie ended with 5 of 40 modes beaten. Consider requiring Sprint (or two modes) to open the next level.
  - **Crusher is a wall for the Rookie.** It wrecked 3 times there, then twice more on City, with every car owned. The Grinder beat it first try. Check late-level escalation against a weaker driver before tuning it down.
  - **Races rarely finish.**
    - Sprint was won 3 times in 10 tries and Marathon 0 in 6, nearly all ending NOTIME (Defense 0 of 2).
    - One Crusher Sprint clock was 46.8 s, which looks too short to be right.
    - A won Sprint can pay 1-23 coins, so racing earns almost nothing next to Countdown.
    - Some of this is the AI (the Explorer drives `crusher`, which detours for goons), so check Sprint clocks with `--profiles=cautious` playtests before tuning `sprintSlack`.
  - **Human checks** (where the AI struggles; is it the game or the driver?). Play each a few times from the console's `start <tier>` in the menu, or `-- --play-start=<tier>` (a scratch save either way; docs/AI_DRIVER.md "Career playtests"). Your runs log to `runlog.csv` as `driver = player`, to compare with the personas.

    | Level and mode | Start | What to look for |
    |---|---|---|
    | Crusher, Countdown, in a mid car (`--play-start=late --cars=4`) | `late` | the Rookie wrecked 3 runs in a row here |
    | Sprint and Marathon on Crusher, Highway and Bayou | `late` | clocks short or fair? Crusher's slack is 1.15 (stations no longer land short: `STATION_MIN_SHARE`) |
    | Defense on Prairie and Bayou | `mid` | before the AI fix the barrier fell at about 95 s every time |
    | Goonpocalypse in a maxed car | `maxed` | does it ever end? A run outlived the harness's 15 minutes |

  - **Changed after the careers (2026-10-07):**
    - **Payout:** coins × (1 + 0.1 × stars), `Root.STAR_BONUS`.
    - **Level gate:** 3 modes beaten (Countdown, Sprint and one more) open the next level (`Root.LEVEL_UNLOCK_MODES`). The results ticket says what is left.
    - **AI in races:** spare time is estimated from real progress, there is a detour budget per leg, and goons are worth 0.4 as goals.
    - **AI in Defense:** it hunts goons by their threat to the base and patrols closer.
    - **Human tests:** the console's `start <tier>` (or `--play-start`) for testing late levels by hand.
    - **New saves:** only the first level starts open.
    - **Station placement:** stations stay at least 85% of a Sprint's distance out.
  - **Race and Defense rules, same seeds before and after** (`cautious`, sedan with 8 upgrades per stat):
    - **Sprint:** Prairie 0 of 3 → 3 of 3 (50-71 s used of 101-128). Bayou 2 of 3 → 1 of 3, the two losses ending 1,600-2,700 px short; Bayou's water may be the problem rather than goons.
    - **Marathon:** 1 of 6 complete. Three runs ran out of fuel with 40-73 stuck events, so the driver loses too much time stuck between legs.
    - **Defense:** 0 of 9 either way. The barrier falls at 85-105 s on Prairie and Bayou whatever the car does.
      - Some runs never leave their first patrol goal (stuck 32-36 times), so the car may be stuck where Defense starts it (`Level.DEFENSE_START`).
      - Even a car hunting near the base loses the barrier at about 90 s. Play it by hand before blaming the AI: barrier 1000 may simply be too weak.
  - **Fixed from the careers:**
    - the records ticket and the upgrade sheet left keys and pads with no focus
    - Accept cycled the Gadget button instead of starting the run after a click on it
    - two Goonopedia loaders called back into freed nodes
- **World follow-ups:**
  - Bumper-only car collision: add a middle polygon or side capsule on layer 1 only, keeping crushing and `carBodyArea` contact unchanged. S–M.
  - Frostbite passes stick heavy cars: keep deep snow and ice out of passes, widen `passWidth`, or retune DEEPSNOW. S.
  - AI Defense strategy: rank goons by distance to the walls and `siege` state, guard the lanes, refuel when low. M.
  - AI skips pickups near deep water (`waterTargetPx`): allow them at low approach speed. S.
  - Highway edges look blobby: a crisper border for road surfaces, or a kerb line. S.
  - Landmark beacons glow by day: fade them with the level's CanvasModulate. S.
  - World build speed (0.8–1.3 s map after the native crossings, 7–12 ms recipes): port `WorldField.sample` and the remaining coarse passes (docs/NATIVE.md, "What to port next"), keeping the GDScript as the reference the tests compare against. M–L.

### Package 2 follow-ups (play time)
- Tune by hand: the death-style weights (`GoonFx.STYLE_WEIGHTS`), `FLING_SPEED`, trauma sizes, hit-stop lengths, the bonus coins (they feed the payout), and whether the giant's 10% speed loss feels heavy or sticky.
- Feel pass on the handbrake (the `HANDBRAKE_*` constants, strengthened once: grip 0.16/0.07, steer ×1.6, throttle 0.85, decel 60) and the drift boost (`DRIFT_TIERS`: 40 ticks for +120 px/s, 100 for +240), and on slams (`SLAM_MIN_SPEED` 150, 2 coins).
- Benchmark S3/S4 at Crush Effects Full; drop the Low preset to Minimal if crowds cost frames.

### Package 12: Unlocks and progression
Built (2026-10-07, "Done" above; the proposal and its options are at https://claude.ai/artifact/5fVWpCsD8xZLferKDcYvTN). What is left:
- **U-3** is done: the Cars tab buys cars and upgrades, and the Pickups tab draws each kind as a tree.
- **Pace check:** re-run the three personas from `fresh` (`--unlocks=save` is the career default) and read `unlock_pace` in the career summary. The target is a Rookie who sees every mode before the last level and opens about 20 pickups by the end of Prairie. Then re-fit `Unlocks.PICKUP_PRICE` and the car gem prices with package 6.
- **Prize games** (package 16) read `prize:<game>` through the registry's saved ids (`CrushPrizes`); show and buy them in the Goonopedia next to pickups.
- Cosmetics (package 15) and radio stations (R-1) take `paint:` and `station:` ids in `meta.unlocks` when they are built.

### Package 16: Crush prizes (what's left)
Built (2026-10-07, "Done" above; docs/PICKUPS.md "Gift boxes"). What is left:
- **The curve by hand** (package 1): `XP_BASE` 50 and `XP_EXP` 2 were fitted to AI playtests only (150-1300 XP and 1-3 boxes in 3-4 minutes). Play a few runs and read `crush_xp` and `boxes` in `runlog.csv`. The goal is the first box in under a minute of decent play, then every 2-4 minutes.
- **Ideas:** an "XP Boost" pickup or a car perk through `car.crushXpMult`; a small "+XP" tag flying to the pill; lifetime boxes and the best box in `meta.lifetime`; the AI could weight goons by XP.
- *Done:* the Goonopedia sells the prize games (a ladder at the top of the Pickups tab) and the personas buy them; the Claw Crane pickup is an Uncommon drop now (was Epic).

### Package 13: Driving juice
Driving should be the most fun part. The handbrake, drift boost, slams and crush feel are done; these add feel to the car itself. All of it is visual or sound, outside `integrate()`, scaled by Reduce Motion and Car Shake, and benchmarked on the HD 620.
- **D-1. Two-wheel tilt and body roll.** In a hard turn (high `spinRate` at speed, or a powerslide catch) skew and offset the car sprite so it reads as up on two wheels: a perspective skew on the outside edge, the shadow shifting the other way, sparks or squeal from the inner tyres, and a little bounce when it lands back. Smaller turns get a slight roll. Style only: the car never tips over, and handling is unchanged. S–M.
- **D-2. Weight and suspension.** Nose dip on hard braking, squat on launch and boost, a bounce off kerbs, bumps and landings (Hop, Jump Jets), screen kick on wall hits scaled by speed. S.
- **D-3. Speed and surface.** Speed lines or a slight zoom-out pull above top speed, dust or spray trails per surface (`World.surfaceAt`: dirt, snow, water shallows, oil), wall-scrape sparks, a boost flame and bloom on drift-boost release. S–M.
- **D-4. Engine and tyres.** Engine pitch with RPM and gear shifts (`car.gear`), tyre squeal tied to slip, a backfire pop on lift-off; these feed the sound package. S.

### Package 14: Prop layers and reactions
- **P-1. Trees in two layers.** Bake each tree (`oak`, `pine`, `cypress`, `deadtree`, `saguaro` stays one piece) as a **trunk** (the collision hull, drawn under the car) and a **canopy** (drawn above the car and goons, no collision). The canopy fades to about 40% while the car is under it so the player can still see; it does not fade for goons, so a canopy can hide goons beneath it (by choice). Hitting the trunk shakes the canopy (a short spring wobble) and drops a few leaves (pine needles, snow on Frostbite) as pooled particles; a hard hit drops more. Generator work: a `canopy` drawing in `world_gen.js` `PROPS`, a second texture in `props.json`, a canopy `Sprite2D` on a higher `z_index` in the prop scene; occluders stay on the trunk so night shadows don't change. M.
- **P-2. Review every prop.** Give each class a reaction to a hit: bushes and reeds squash and spring back; signs, cones and bins wobble or fly; hydrants spray; tents and shacks shake; tall rocks only thud and dust. Decide which tall props also get an over-the-car layer (billboards, cranes, bus stops). S–M per batch.
- Keep reactions pooled and per chunk (inside `TileManager.APPLY_BUDGET_USEC`), and check S2/S3 frame times on the HD 620.

### Package 3: Regions, waves and giants
- **T1-7.** `giantism` is shown but unused. Proposal: giant odds = `giantOdds + giantism / 5`, plus a term from the run's wave (`Region.waveIntensity()`). S.
- **Wave stars** have no cap since W-1, so a long Goonpocalypse earns a star a minute: check star totals per mode in package 1 alongside the payout model (question 2).
- **T2-4.** Giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges, pointed at by the indicator (start from the Foreman's `Boss` verb). M.
- **T2-8.** Region mutators ("fog", "giants only", "double coins") and objectives ("crush 20 Rat Pack"), anchored on district landmarks. M.
- **T2-11.** Night as a real phase: about 150 s day and 90 s night, a night spawn table, ×1.5 coins at night (`Timer.gd` `daylength`). S.

### Package 5: Slot machine and gems
- **T1-10.** Gems buy rerolls, a starting gadget and boost (`Pickups.LOADOUT`, `BOOST_LOADOUT`) and a new hand in The Deal. Proposal, cheapest first: a gem pouch (carry up to 3 into a run), Second Wind (pay gems to continue with 50 health and fuel; must hook in before `endLevel`; not in Goonpocalypse), respec. Cosmetics move to package 15; locked pickups to package 12. M.

### Package 6: Economy
- **T1-11.** Every car uses `int((lvl+1)^1.6 × 15)`, about 119k coins to max one car, and a flat +1 per level helps weak stats far more than strong ones. Proposal: a `stat_max` per stat in `<car>_info.tres`, tier-based cost bases, all prices shown in the garage, car prices re-fit from run-log data. M.
- **T2-13.** Driver perks and affinity (hooks: `awardBase` in `playerRoot.gd`, the purse's `MIN_COINS`/`MAX_COINS`). M–L.
- **Late-level payouts:** long survival runs on late levels reach 2,000+ crushes and six-figure payouts under coins × stars. Re-fit `escalationSpeed`, Goonpocalypse escalation and wave stars after deciding the payout model (question 2). M.

### Package 7: Goals and teaching
- **T1-15. First-run hints.** Nothing teaches crush speed, the slot controls, where stars come from, gadget Use, that deep water wrecks the car, or that breakables smash and rocks don't. One-time toasts via `HudChance.toast`, flags in `meta.hints`. S–M.
- **T2-12.** Medals and per-level records for every mode (the Goonpocalypse shape in `meta.records`), a "Next up" panel. M.
- **T1-16.** A `SteamService` autoload guarded by `Engine.has_singleton("Steam")`, achievements mirrored into `meta.achievements`, lifetime totals in `meta.lifetime`, `steam_appid.txt` only in dev builds. M.
- **T2-14.** Three date-seeded contracts, reroll for a gem. M. Needs T1-16.
- **T2-15.** Medal-gated top cars. S–M. Needs T2-12, T1-11.

### Package 8: Sound and radio
- **T1-13.** A `VoiceDirector`: priorities (warning > win > record > jackpot > giant > award > region), a ~5 s cooldown, no repeats in the last 3 lines, subtitles. S.
- **T1-14.** Menu music, ducking under voice, stingers. S plus licensing.
- **R-1. Radio stations.** The code is done (above, docs/RADIO.md). Left: more in-house tracks (GoonCrusher Radio has 9 songs (about 28 minutes, past the 8 to ship) but no idents, talk or ads yet; Classical Lofi and Lofi have none and stay hidden until they do; docs/RADIO.md part 1 and docs/RADIO_SONGS.md), then a listening pass on crossfade lengths, segment odds and the ducking depth. Stations could become unlocks (package 12, `Radio.isStationOpen`).

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
- Unlocks: Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint. A new save opens only the first level; each next one opens once 3 modes are beaten on the one before (Countdown, Sprint and one of the rest; 2 in the demo). Most pickups start locked, one tree per kind (package 12).
- Sprint's clock ends the run; Marathon adds one Sprint clock per station.
- Payout is coins × (1 + 0.1 × stars): 50 stars pay ×6.
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

1. Do Marathon and Defense ship in 1.0 or a free update?
2. Payout model: keep stars as a multiplier, or move to additive with a win bonus?
3. Fuel pressure: should fuel or health be the main way runs end?
4. Price and length target (sets the economy numbers).
5. Gems: never sold? Is a gem-paid continue acceptable?
6. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
7. *(Answered: the demo opens Common and Uncommon pickups; see "Decisions".)*
8–10. *(Answered: prize games ranked by measured strength, the weakest open first; better versions in higher boxes, no star per box; no wave cap. See "Decisions".)*
