# Roadmap

Everything that is not built yet lives in this folder: nowhere else. The area docs in `docs/` describe the game as it is; when a roadmap item lands, delete it here and, if players will notice it, add a line to `CHANGELOG.md`.

| Doc | Covers |
|---|---|
| this file | The 0.3 demo release list, decisions that constrain future work, questions for the author |
| `ROADMAP_WORLD.md` | Levels by region, props, the world generator |
| `ROADMAP_GOONS.md` | Goons, giants, bosses, waves |
| `ROADMAP_PICKUPS.md` | Pickups, unlock trees, prize games, gift boxes, gems |
| `ROADMAP_MODES.md` | The 19 game modes and their tiers |
| `ROADMAP_CARS.md` | Handling, driving feel, upgrades, perks, cosmetics |
| `ROADMAP_UI_HUD.md` | Menus, HUD, hints, records, Steam features |
| `ROADMAP_AUDIO.md` | Voice, the mix, the radio, songs |
| `ROADMAP_BALANCE.md` | The economy, pacing and the play passes that fit them |
| `ROADMAP_TECH.md` | The AI driver, performance, native code, tests, the capture kit, release builds |
| `ROADMAP_MARKETING.md` | The changelog, posts and footage for 0.3 |

## How items are written

- Each doc has **Planned** (in the plan; it will be built) and **Suggestions** (ideas to discuss; not agreed).
- Each planned item carries a tag: **[0.3 need]** blocks the demo release, **[0.3 want]** goes in if there is time, **[later]** waits until after 0.3.
- Effort: **S** under a day, **M** 1 to 3 days, **L** a week or more. "+ play" means it needs a person driving.
- Nothing in the game has been tuned by hand yet. Every balance number measured so far was fitted on the old 8 levels and 5 modes: measure again before tuning.

## The 0.3 demo

**Scope (the author):** the first two regions, The Wilds and Tribe Country: 10 levels, the first 3 cars, and every mode those levels play (`Root.IS_DEMO`, `DEMO_LEVEL_COUNT`, `DEMO_CAR_COUNT`, `Unlocks.inDemo`): all 19 between them, since levels now pick their own two openers.

### Calls to confirm
The sorting below is a proposal. These are the calls most worth a second look:

1. **14 of the demo's modes have never been driven by a person.** I made "play each once and fix or switch off what is broken" a need, and tuning them a want. A mode that isn't ready can show "Coming Soon" (`Root.MODE_AVAILABLE`), but a level then needs another featured mode to open the next one.
2. **Tribe Country ships on its landscape templates.** Its revamp is on hold (below), so I made only "every Region 2 level is winnable and nothing softlocks" a need.
3. **Players of the 0.1 demo start over** (saves before version 8 are not kept). Already decided; listed so the store update says it.
4. **Two Wilds events can't appear in the demo:** the Hay Wagon and the Bandit Barge need the Loot Truck pickup, which the demo can't unlock. I left them out of the demo; say if a demo player should see them.
5. **Only 3 cars are in the demo,** so manual gearboxes, the semi's trailer and six of the nine dashboards are full-game only. I kept that; it matters for what the 0.3 footage may show (`ROADMAP_MARKETING.md`).
6. **Performance on the low-end target** with six AI rivals is unmeasured. I made measuring it a need and fixing it a want, since Goon Cup modes are in the demo from the second level.

### Needs (blocking)
| Item | Where |
|---|---|
| Play every demo mode once by hand; fix or switch off what is broken | `ROADMAP_MODES.md` |
| Mode text that promises things not built (Hot Lap's ghost, Drift Trial's marked corners) | `ROADMAP_MODES.md` |
| Every demo level and mode winnable on Easy and Medium; no softlocks from a fresh save through the demo | `ROADMAP_BALANCE.md` |
| Goon damage check on unarmored cars (about 14× since the damage change) | `ROADMAP_BALANCE.md` |
| Region 1 AI stalls (Orchard Lanes, Moose Woods) measured, and fixed if a player can hit them too | `ROADMAP_WORLD.md` |
| Region 2 sanity pass: line-ups, stations in reach, Sprint clocks | `ROADMAP_WORLD.md` |
| Measure a six-car race and a night crowd on the low-end target | `ROADMAP_TECH.md` |
| The manual test checklist, on keyboard, mouse alone and pad alone | `ROADMAP_UI_HUD.md` |
| Release build: version, demo flag, native release DLL, export templates, the end-of-demo path | `ROADMAP_TECH.md` |
| Changelog checked by the author; footage refilmed on demo cars and levels | `ROADMAP_MARKETING.md` |

### Wants (if time allows)
| Item | Where |
|---|---|
| First-run hints: crush speed, prize game keys, deep water, what smashes | `ROADMAP_UI_HUD.md` |
| Tune the modes the AI showed to be off (Drift Trial, Pursuit, derby length) | `ROADMAP_MODES.md` |
| First fit of prices, payouts and gift box pace for a fresh save across 10 levels | `ROADMAP_BALANCE.md` |
| Region 1 feel pass by hand (smash speeds, coin values, event weights) | `ROADMAP_WORLD.md` |
| Driving and prop feel passes | `ROADMAP_CARS.md`, `ROADMAP_WORLD.md` |
| A listening pass on the mix and the radio | `ROADMAP_AUDIO.md` |
| Gameplay timers off the wall clock, so taped drives replay exactly for the trailer | `ROADMAP_TECH.md` |
| Fix what the performance measurements find | `ROADMAP_TECH.md` |
| The Goonopedia's "Found on" line, which no longer matches where goons spawn | `ROADMAP_GOONS.md` |
| Missing capture shots and a devlog series | `ROADMAP_MARKETING.md` |

### After 0.3
Regions 3 to 6 content, the Region 2 revamp, driver perks, cosmetics, gems to spend, Steam achievements and leaderboards, contracts, bosses and goon depth, what the first versions of the modes left out, native ports. Each is in its area's roadmap.

## Decisions already made
These constrain future work; don't redo or undo them without the author.

- **On hold:** the Region 2 revamp, the regions 3 to 6 revamps, and champions, until Region 1 is settled. Don't start them.
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
- American English everywhere.

## Open questions for the author

1. Fuel pressure: should fuel or health be the main way runs end?
2. Price?
3. Gems: never sold? Is a gem-paid continue acceptable?
4. Steam scope for 1.0 (achievements vs. leaderboards and dailies); Steam Deck needs analog steering.
5. Should goons that release a log pile get credit and run away? Should spilled logs and the crane's container ever clear away? Should water towers leave a slippery puddle?
6. Should Low or Potato default to 720p?
7. Should the capture kit's "minimal" HUD feed keep the visors?
