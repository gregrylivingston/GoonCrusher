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
- **T0-9** Payout = coins × max(1, stars), credited on the summary; Abandon pays like a death.
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
- **Career playtests** Three personas play the whole game through the real menus (docs/AI_DRIVER.md).
- **R-1 (code)** Radio: three stations scanned from `sound/radio/` (shuffle bags, crossfades, idents, talk and ads between songs, lazy threaded loads), picked in the pause menu and Settings, a now-playing card in the HUD and menu, music ducking under the Voice bus (docs/RADIO.md). Songs in: *Crush Hour*, *Gooncrusher*, *Full Tank, Empty Head* (docs/RADIO_SONGS.md).
- **Tier 3** Shallows, fords and bridges; most of a daily seeded run (the map and its contents come from the world seed).

## Work packages, in order

Package numbers are IDs (other docs link to them); the table is in the suggested order.

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 1 | Playtest and tune | the numbers below, world follow-ups | S + play time | — |
| 11 | Left-hand menu controls | M-1 | S | — |
| 12 | Unlocks and progression | U-1 to U-5 | M–L | questions 2, 4 |
| 6 | Economy | T1-11, T2-13, late-level payouts | M | 1, 12 |
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
  - **Countdown alone opens every level.** Beating any mode opens the next level, so both personas that follow the path opened all 8 levels in 7 runs (about 40 min) playing nothing but Countdown. The Rookie ended with 5 of 40 modes beaten. Consider requiring Sprint (or two modes) to open the next level.
  - **Crusher is a wall for the Rookie.** It wrecked 3 times there, then twice more on City, with every car owned. The Grinder beat it first try. Check late-level escalation against a weaker driver before tuning it down.
  - **Races rarely finish.**
    - Sprint was won 3 times in 10 tries and Marathon 0 in 6, nearly all ending NOTIME (Defense 0 of 2).
    - One Crusher Sprint clock was 46.8 s, which looks too short to be right.
    - A won Sprint can pay 1-23 coins, so racing earns almost nothing next to Countdown.
    - Some of this is the AI (the Explorer drives `crusher`, which detours for goons), so check Sprint clocks with `--profiles=cautious` playtests before tuning `sprintSlack`.
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
- Tune by hand: the death-style weights (`GoonFx.STYLE_WEIGHTS`), `FLING_SPEED`, trauma sizes, hit-stop lengths, the bonus coins (they feed coins × stars), and whether the giant's 10% speed loss feels heavy or sticky.
- Feel pass on the handbrake (the `HANDBRAKE_*` constants, strengthened once: grip 0.16/0.07, steer ×1.6, throttle 0.85, decel 60) and the drift boost (`DRIFT_TIERS`: 40 ticks for +120 px/s, 100 for +240), and on slams (`SLAM_MIN_SPEED` 150, 2 coins).
- Benchmark S3/S4 at Crush Effects Full; drop the Low preset to Minimal if crowds cost frames.

### Package 11: Left-hand menu controls
- **M-1.** Menu keys are hard to discover. WASD already moves focus and Space already accepts (Godot's default `ui_accept`), but the hints show Enter, so buying an upgrade reads as "press Enter". The secondary actions are scattered across the keyboard: U Upgrade or Gadget, R Records, G Goonopedia, B Boost (`InputGlyphs.addIfMissing`). Goal: every menu works from the left hand on WASD (and with the mouse alone, as now). Proposal:
  - Hints show Space for Accept (Buy, Drive, Start), with Enter still working; Esc is Back, Q/E switch the carousel or tab.
  - Letters next to WASD for the secondary actions (the author prefers letters): F Upgrade (garage) or Gadget (run setup), V Boost (run setup), R Records, G Goonopedia. Numbers only where they index a list: 1–8 pick a level poster in run setup, 1–6 a Goonopedia tab.
  - Upgrade sheet: W/S pick a stat, with a visible BUY button on the focused row (not just a flash) so the action is obvious; holding Space buys repeatedly.
  - Key hints read their glyphs from the bindings (`KeyHint`, `InputGlyphs`), so the work is the default keys in `InputGlyphs`, which glyph the hints show first, and `main2.gd`'s `_input`.
- Check with the career playtests (they press input actions) and a hand pass with each input type. S.

### Package 12: Unlocks and progression
The author wants one designed unlock system across levels, modes, pickups, drivers, upgrades and cosmetics, mixing coins, gems and play-based triggers. Today each piece has its own rule, and the career playtests show it is too loose ("Countdown alone opens every level", above).

| What | Today | Direction |
|---|---|---|
| Levels | First 3 start unlocked (`Levels.DEMO_LEVEL_COUNT`); beating any mode opens the next | **Only the first starts unlocked**; a stricter trigger (e.g. beat Sprint, or two modes) opens the next |
| Modes | Per level: Countdown → Sprint → Goonpocalypse; Marathon and Defense after Sprint (`Root.isModeUnlocked`) | Keep the chain; show what opens what |
| Drivers | Bought with coins from the garage | Coins, some gated by a medal or level (T2-15) |
| Upgrades | Coins, cap 20, same curve for every car | Package 6 (T1-11) |
| Pickups | All 79 drop from the start; `meta.pickups` only records discovery for the Goonopedia | **Most start locked**, in a tree per kind (U-2) |
| Cosmetics | Car Paint setting only | Package 15 |

- **U-1. One unlock registry.** An `Unlocks` table: id, kind, cost (coins, gems, or none) and trigger (a flag such as `beat:prairie:sprint`, `crushes:500`, `discovered:<goon>`), with `Unlocks.isOpen(id)` and `Unlocks.progress(id)`. Store opened ids in `meta.unlocks`; `migrate()` grants existing saves whatever they already have. Level and mode gates read it instead of their own rules. M.
- **U-2. Unlock pickups in a tree per kind.** Each of the nine kinds (`Pickups.K`) is its own small tree, handled separately: a new save opens one starter pickup per kind (Loot starts with the Coin), and each unlocked pickup opens better ones of its kind (the Coin leads to the Purse). Locked pickups never drop: the drop roll (`Pickups.roll`, `rollForCar`, `rollAtLeast`, `dropShare`) and every menu that offers pickups (slot reels, The Deal, the Claw, the Pit Shop) skip them. In the Goonopedia a pickup whose parent is still locked is a "???" tile; one whose parent is unlocked shows its preview and its price or trigger (coins, gems or play: crush a faction's goons, reach a level, play a mode). The tree is data in `Pickups.DATA` (a `parent` and a `cost` per pickup). M.
- **U-3. Buy in the Goonopedia.** The Goonopedia becomes the place to see and buy unlocks: a locked tile shows its price or trigger and progress, and Accept buys it (the same flash and shake as the garage). Upgrades can be bought from the Cars tab (the driver card's upgrade sheet, reused). S–M after U-1.
- **U-4. Level gates.** Only `prairie` starts open (the demo keeps its 3 levels available but still unlocks them in order). Pick the next-level trigger from career-playtest pace: the target is a Rookie who sees every mode before the last level. S.
- **U-5. Show what's next.** An unlock toast on the results ticket ("BAYOU UNLOCKED", "NEW PICKUP: Magnet"), and a "Next unlock" line in run setup. Overlaps T2-12's "Next up" panel; build them together. S.
- Re-run the three personas from `fresh` after each change, and add an unlock-pace table to the career summary (`CAREER_MILESTONE` already logs each unlock).

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
- **T1-7.** `giantism` is shown but unused, and `pickGoonId` still adds global time to the wave. Proposal: giant odds = `giantOdds + giantism / 5`; decide whether global time should push the mix. S.
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
- **R-1. Radio stations.** The code is done (above, docs/RADIO.md). Left: more in-house tracks (GoonCrusher Radio has 3 of the 8 songs to ship and no idents, talk or ads yet; Classical Lofi and Lofi have none and stay hidden until they do; docs/RADIO.md part 1 and docs/RADIO_SONGS.md), then a listening pass on crossfade lengths, segment odds and the ducking depth. Stations could become unlocks (package 12, `Radio.isStationOpen`).

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
- Unlocks: Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint. The level rule (beating any mode opens the next) and the 3 open levels are being replaced (package 12): only the first level starts unlocked, and most pickups start locked.
- Sprint's clock ends the run; Marathon adds one Sprint clock per station.
- Payout is coins × max(1, stars).
- The demo and the full game share the save; one codebase (`Root.IS_DEMO`).
- The slot machine stays as the signature pause, alternating with The Deal.
- Menu shortcuts are letters near WASD; numbers only for lists such as levels and tabs.
- Pickups unlock in a separate tree per kind; locked ones never drop and show as "???" until their parent is unlocked, then with a preview and price.
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
7. Should the demo hold some pickups back? (Package 12's starter set may answer this.)
