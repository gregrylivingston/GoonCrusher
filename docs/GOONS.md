# Goons

Every goon has one rule of its own (its verb), a tell before it acts and a window when it can be punished. The data is the source of truth: read `Goons.DATA` and `Goons.CLASSES` for who exists and their numbers. This doc is the map, the rules that are easy to break, and the recipes.

## Files

| Path | Owns |
|---|---|
| `scripts/global/goons.gd` (`Goons`) | The registry: `DATA` (every goon; the keys are explained in the comment above it), `CLASSES`, `WAVE_MIX`. **Tune goons here.** |
| `scripts/art/goon_gen.js`, `bake_goons.py` | The generator (rigs, and one design entry per goon at the bottom) and the bake. **Change a goon's look here**, then re-bake. |
| `scene/enemy/goons/<id>/` | Baked output: frames, decal, `<id>_frames.tres`, `<id>.tscn`. Never edit by hand. |
| `scene/enemy/walker/walker.gd` (`Walker`) | The base of every goon scene: tuning from `DATA`, `tryCrush`, death, the Defense siege, water, night eyes. It extends the native `GoonBody` (per-tick fields and movement helpers, docs/NATIVE.md). |
| `scene/enemy/goon_verbs.gd` (`GoonVerbs`) | The behaviors: one `Verb` subclass per verb, a small state machine, a `RefCounted` rather than a node. |
| `scene/enemy/goon_fx.gd` (`GoonFx`) | Everything drawn or thrown: telegraphs, projectiles, hazards, blasts, tethers, crush decals, corpses, labels, delayed drops. Pooled, with caps at the top of the file. |
| `scene/enemy/spawnManager.gd` (`SpawnManager`) | Spawning (single, packs, bursts, groups), scene loading, the cap and the sweep, the nearby floor, night, crush credit. |
| `scripts/world/level_roster.gd` (`LevelRoster`) | A level's validated line-up and a district's three goons. |
| `scripts/global/Region.gd` (`Region`) | The run's regions, one per world district, and the wave clock. |
| `scene/fx/crush_feel.gd` (`CrushFeel`) | Camera trauma, hit-stop and the crush bonuses. |
| `tests/game/test_goons.gd`, `test_levels.gd`, `test_wild_instincts.gd`, `test_region1_props.gd`, `test_crush_feel.gd` | The tests. |

## Classes

- **A goon keeps its faction** (Wild Things, Goon Tribe, Scrap Gang). The faction sets its look, drop weights (`fac` in `Pickups.DATA`), what the EMP stalls and the `crushed:<faction>` unlock counters.
- **A class is only a list** of the goons a road atlas region may field (`Goons.CLASSES`; docs/WORLD.md, "Regions"): one per faction, plus three elite classes that mix factions.
- **Line-ups:** a level fields 3 to 6 goons of its region's class (`LevelDef.lineup`, validated by `LevelRoster.lineupFor`; `test_levels.gd` checks them). Districts spawn only from the line-up.
- **A district's three goons** (`LevelRoster.pickGoons`, seeded per district): slot 1 is one of the line-up's lowest rank, slots 2 and 3 a shuffle of the rest. The district's `faction` is its first goon's, so an elite district can mix factions.
- **Waves:** `WAVE_MIX` weighs the three slots by the run's wave. The wave is one clock for the whole run (`Region.wave`), never restarted by a district, and escalation adds to it (`SpawnManager.pickGoonId`).
- **Elite strength step:** elite regions scale goons as they spawn (`Territories.step`, `Walker.applyStrength`). A head-on armor no speed beats is left alone. Nothing marks an elite on screen.
- **Rank 0** (the Goonling) never spawns from a district, only from another goon.
- **Try it:** `-- --class=<class id>` picks every district's goons from that class, `-- --goons=a,b,c` forces three. Both work with `--playtest` and `--bench`.

## How a goon works

- **Scene and tick:** every `<id>.tscn` inherits `walker.tscn` (the art faces up and the body faces +x, so sprite, shape and occluder are turned a quarter turn). `Walker._physics_process` runs the Time Warp skip, water, lures, the siege, then `verb.tick`. Off screen, `GoonBody.advance` moves without collision queries and treats water as blocked, so nothing drowns unseen.
- **`Walker.mode` and `myMode` are read by the AI driver: keep the names.** `setState` keeps `myMode` in step (windup is `PREPAREATTACK`; lunges, charges, rolls, slams and dives are `ATTACK`).
- **Physics layer 3 only** (`collision_layer` 4, mask 1+2), so goons never collide with each other. Anything that must find goons uses distance (`SpawnManager.goonsNear`) or needs layer 3. `setSolid(false)` (buried, flying, riding) takes a goon off every layer, which also makes it immune to water, slams and trampling.
- **Cap and sweep:** at most `SpawnManager.GOON_CAP` live goons, the same on every preset. Every `SWEEP_SECONDS` a goon that is off screen and either far away or stuck on a wall (`Walker.isStuck`) is freed. Defense keeps its siege; a Bounty Hunt mark is never swept. Benchmarks turn the nearby floor off (`floorOn`) so their numbers stay comparable.
- **Defense:** the siege block in `walker.gd` (`siegeTarget`, `sieging`, `siege`) marches a goon in `move` on the station's pumps while the car is away, and it dies there as `&"self"`, with no crush credit. Verbs in `SIEGE_SKIP` always hunt the car. Keep this block when editing `walker.gd`.
- **Night:** telegraphs, projectiles, blasts and fire are unshaded, so night never hides a threat. Goons light their eyes when the level's `CanvasModulate` goes dark (`nightSweep`).

## Crushing

`OverheadCarBody2D.crushGoon` calls `goon.tryCrush(car, speed × car.crushWeight())`; false means the goon resisted. The order inside `tryCrush` matters:

1. `car.crushOverride(goon)` (a pickup buff) crushes at any speed, before any resist rule.
2. The goon resists when it is `invulnerable`, the car is under its `crush` speed, its `front` armor applies (the car hits its front arc too slowly and `verb.frontArmorActive()`), or `verb.allowCrush` says no.
3. A resisted hit calls `verb.onResist` at most once per `RESIST_COOLDOWN`, usually `bounceCar` with a label that says why.

- **Crush speeds stay at or under 400 px/s:** a stock sedan tops out near 433, so heavies need near-top speed, not upgrades.
- **Contact damage:** every goon contact chips the hull by `GOON_CONTACT_DAMAGE`, once per goon per 30 ticks. Keep it at 5 or less, or a Bubble Shield would spend a charge on every crush. A successful crush never wears the car's systems.
- **Death** goes through `Walker.destroy(cause)` (`crush`, `boom`, `self`, `drown`); `vanish()` is leaving without a death: no corpse, drop or credit.
- **Credit and drops:** kills the player sets up count as crushes through `SpawnManager.creditCrush(pos, goon, source)` ("Critter Chain" below), a pushed drowning included. What a goon drops is rolled by `Pickups` (docs/PICKUPS.md, "Drops").

## Crush feel

Two halves, both tuned by constants at the top of their files:

- **Drawn** (`GoonFx.crushed`, `deathStyle`): splat, shove, hood ride or fling, by speed and where the car hit. The Crush Effects setting (`gfx/crush_fx`) scales it down.
- **Felt** (`CrushFeel`, a child of the player's car; `onCrush` from `crushGoon`, `onIndirect` from `creditCrush`): camera trauma, hit-stop and the crush bonuses.

Rules:
- **Bonuses are credited at once, never from an effect.**
- **Hit-stop** changes `Engine.time_scale`. It never stacks, ends at once when the tree pauses or a menu opens (`CrushFeel` runs while paused only for that), and `_exit_tree` resets it. It is off under `Transition.instant()`.
- **Shake** shares `Camera2D.offset` with `Juice.rumble` and stands aside while a rumble runs. Screen Shake, Hit-Stop, Reduce Motion and Reduce Flashing all gate it.
- **Slams** (`OverheadCarBody2D.slamGoons`): the car's physics shapes are only its bumpers, so the flanks and tail crush here, through the footprint area. Goons off every layer are out of reach.

## The world

Goons read the world through `WorldHooks`: O(1) grid reads on the run's `WorldMap`, never physics queries (docs/WORLD.md, "Goon and FX hooks" and "Water").

- **Spawns:** a spawn point must be `World.spawnableAt`. Some goons spawn beside a prop that is near the spot and out of the car's sight (`SpawnManager.SPAWN_PROPS`, `SPAWN_OFFSET`, `SPAWN_STATE`).
- **Props:** `SpawnManager.onNodeAdded` tags props into groups as chunks stream in (`BreakableProp.tag`, `GROUPS`); goons find them by group.
- **Blasts** go through `GoonFx.blast`, which uses the level's pooled explosions (never instantiate one per blast), stops at wall cells (`WorldHooks.lineClear`) and sets off explosive props (`BreakableProp.blastAt`).

## Wild instincts

Goons use the world's props and each other. Each behavior is a key in `Goons.DATA` (`seeks`, `smashes`, `tramples`, `daze`, documented above `DATA`) or a row in a `Spill` or `BreakableProp` table, so any goon can take one up by data alone. The prop side is in `spill.gd`'s header and docs/WORLD.md, "Interactive props".

- **`seeks`** rows send a goon to a prop group to do an action (`GoonVerbs.Verb.seekProp`). `Goons.SEEK_SELF` actions are skipped by the generic look: the verb uses its row at its own moment (`Goons.seekRow`).
- **State on props survives a chunk reload:** a den's stash, a rung bell and one-shot crates are recorded by position (`Spill.STASH_META`, `Spill.markUsed`), not on the node.
- **Lures** are owned by pickups (docs/PICKUPS.md "Lures"); the Dinner Bell and Salt Lick props register theirs through `Spill`.

### Critter Chain

Every kill the player sets up (logs, bees, a flood, a fall, a blast, a trample, a quill, a kicked shell, a pushed drowning) goes through `creditCrush` with a `source`.

- Within `CRITTER_CREDIT_PX` of the car it counts as a crush and joins the Crush Combo. `PickupEffects.onCrush` runs before the XP, so the XP sees the chain.
- Farther off it credits nothing (the kill still happens), except `FAR_CREDIT` sources (the player's own gadgets, a drowning the car pushed), which count anywhere without joining the chain.
- The car keeps the chain's distinct sources (`car.chainSources`, named by `PickupEffects.CHAIN_NAMES`); mixing them pays more crush XP (docs/PICKUPS.md, "Gift boxes") and shows in gold (docs/HUD.md, "Critter Chain readout").
- A new kind of kill needs a source name in `CHAIN_NAMES` and a `creditCrush` call with it.

## Recipes

**Add a goon**
1. Add a design entry to `goon_gen.js` (copy the closest goon of the same rig) and bake it.
2. Add its entry to `Goons.DATA`. Reuse a verb if one fits.
3. Add it to its faction's class in `Goons.CLASSES` (and an elite class if it fits) and to the `lineup` of the levels that should field it (`world/levels/<id>.tres`).
4. Import, turn mipmaps on, and run `test_goons.gd` and `test_levels.gd`.

**Add a verb**
1. Add a `Verb` subclass in `goon_verbs.gd` and a line in `GoonVerbs.make`.
2. Override what it needs: `setup`, `tick`, `onTouch`, `onResist`, `allowCrush`, `frontArmorActive`, `beforeCrush`, `onDeath`, `onNight`.
3. Give every threat a tell (`windup`, `Walker.telegraph`) and a punish window (`recover` or `stun`), and move through `setState` so the AI driver's `myMode` stays right.
4. A verb with its own movement that should not march on the station goes in `Walker.SIEGE_SKIP`.

**Re-baking**
1. `python scripts/art/bake_goons.py [id ...]` opens the bake page in headless Edge and writes each goon's folder.
2. After a bake that adds PNGs: `Godot_console.exe --headless --path . --import`, set `mipmaps/generate=true` in the new frames' `.import` files, import again. Re-bakes keep existing `.import` files.
3. Frames are baked at 2× game size and shown at half scale. `RES` in `bake_goons.html` and `Goons.ART_RES` must change together (`test_goons.gd` checks every scene).

## Known gaps

- Nothing is tuned by hand: speeds, crush thresholds, timings, giants, the elite steps.
- The Goonopedia shows a goon once crushed; the console's `unlock goons` / `lock goons` override that.
