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
- **T2-2, T2-7** Goon movement archetypes; 78 pickups in nine kinds (docs/GOONS.md, docs/PICKUPS.md).
- **T2-3 (drowning credit)** A drowning within 3 s of the car's touch counts as a crush ("SPLASH").
- **T2-10 (most)** Breakables, explosives, faction landmarks, log and manhole spawns.
- **Tier 3** Shallows, fords and bridges; most of a daily seeded run (the map and its contents come from the world seed).

## Work packages, in order

| # | Package | Items | Effort | Needs |
|---|---|---|---|---|
| 1 | Playtest and tune | the numbers below, world follow-ups | S + play time | — |
| 2 | Crush feel | T1-12, T2-6 | M | — |
| 3 | Regions, waves and giants | T1-7 (giantism), T2-4, T2-8, T2-11 | M–L | 1 |
| 5 | Slot machine and gems | T1-10 | S | — |
| 6 | Economy | T1-11, T2-13, late-level payouts | M | 1 |
| 7 | Goals and teaching | T1-15, T2-12, T1-16, T2-14, T2-15 | M–L | 6 for T2-15 |
| 8 | Sound | T1-13, T1-14 | S + assets | — |
| 9 | Goon depth | T2-1, T2-3, T2-5 | M | 2 |
| 10 | Post-launch | Tier 3 | — | 7 |

Re-run the crowd benchmarks (S3, S4 in `PERFORMANCE.md`) after packages 1, 3 and 9.

### Package 1: Playtest and tune
- **Data:** about 30 hand-played runs across 3 cars and all five modes (`user://runlog.csv`, filter out `driver = ai`), plus AI playtests (`docs/AI_DRIVER.md`). The run log doesn't count pickups by kind yet; add that first.
- **Numbers to check:** Sprint clocks (`sprintSlack`, `ROUTE_FACTOR`); the drop mix and pickup odds, prices and timers (docs/PICKUPS.md); fuel pressure (about 87 s of full throttle per tank in the stock sedan); all 9 cars' handling and wall damage; Goonpocalypse (escalation 2×, floor 0.6 s, target 2×); Marathon (5 legs, heal 35, 60° turn); Defense (barrier 1000, rest 2 s, aggro 650, refuel 4/s).
- **World follow-ups:**
  - Bumper-only car collision: add a middle polygon or side capsule on layer 1 only, keeping crushing and `carBodyArea` contact unchanged. S–M.
  - Frostbite passes stick heavy cars: keep deep snow and ice out of passes, widen `passWidth`, or retune DEEPSNOW. S.
  - AI Defense strategy: rank goons by distance to the walls and `siege` state, guard the lanes, refuel when low. M.
  - AI skips pickups near deep water (`waterTargetPx`): allow them at low approach speed. S.
  - Highway edges look blobby: a crisper border for road surfaces, or a kerb line. S.
  - Landmark beacons glow by day: fade them with the level's CanvasModulate. S.
  - World build speed (0.8–1.3 s map after the native crossings, 7–12 ms recipes): port `WorldField.sample` and the remaining coarse passes (docs/NATIVE.md, "What to port next"), keeping the GDScript as the reference the tests compare against. M–L.

### Package 2: Crush feel
- **T1-12.** A goon contact calls `damage(5)` before the speed check, so a crush costs health; giants set `scale = Vector2(1.6, 1.6)` instead of multiplying; no camera shake, hit-stop or corpse fling. Proposal: damage only on non-crush contact, multiply the giant scale, trauma camera shake (respecting Reduce Motion) and 30–50 ms hit-stop on giant crushes. S–M.
- **T2-6.** The Crush Combo exists (`PickupEffects.onCrush`, `car.bestCombo`). Open: drift crush, multi-goon splash, giant slayer, `bestCombo` as a car record. S.

### Package 3: Regions, waves and giants
- **T1-7.** `giantism` is shown but unused, and `pickGoonId` still adds global time to the wave. Proposal: giant odds = `giantOdds + giantism / 5`; decide whether global time should push the mix. S.
- **T2-4.** Giants get hp 3; a Warlord at wave 4 with a health bar, minions and charges, pointed at by the indicator (start from the Foreman's `Boss` verb). M.
- **T2-8.** Region mutators ("fog", "giants only", "double coins") and objectives ("crush 20 Rat Pack"), anchored on district landmarks. M.
- **T2-11.** Night as a real phase: about 150 s day and 90 s night, a night spawn table, ×1.5 coins at night (`Timer.gd` `daylength`). S.

### Package 5: Slot machine and gems
- **T1-10.** Gems buy rerolls, a starting gadget (`Pickups.LOADOUT`) and a new hand in The Deal. Proposal, cheapest first: a gem pouch (carry up to 3 into a run), Second Wind (pay gems to continue with 50 health and fuel; must hook in before `endLevel`; not in Goonpocalypse), respec, paint jobs. M.

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

### Package 8: Sound
- **T1-13.** A `VoiceDirector`: priorities (warning > win > record > jackpot > giant > award > region), a ~5 s cooldown, no repeats in the last 3 lines, subtitles. S.
- **T1-14.** Menu, day and night music sets (`Audio.gd` `loadNextNightSong` is commented out), ducking under voice, stingers; 6–10 tracks. S plus licensing.

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
- Unlocks: Countdown → Sprint → Goonpocalypse; Marathon and Defense need Sprint; beating any mode unlocks the next level.
- Sprint's clock ends the run; Marathon adds one Sprint clock per station.
- Payout is coins × max(1, stars).
- The demo and the full game share the save; one codebase (`Root.IS_DEMO`).
- The slot machine stays as the signature pause, alternating with The Deal.

## Open questions for the author

1. Do Marathon and Defense ship in 1.0 or a free update?
2. Payout model: keep stars as a multiplier, or move to additive with a win bonus?
3. Fuel pressure: should fuel or health be the main way runs end?
4. Price and length target (sets the economy numbers).
5. Gems: never sold? Is a gem-paid continue acceptable?
6. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
7. Audio budget for music and voice.
8. Should the demo hold some pickups back?
