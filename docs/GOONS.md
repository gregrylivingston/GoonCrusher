# Goons

43 generated goons in three factions, fielded by six classes (one per road atlas region), plus the Goonling a Splitter bursts into. Each has one rule of its own (its verb), a tell before it acts, and a window when it can be punished.

## Files

| Path | What |
|---|---|
| `scripts/global/goons.gd` | `Goons`, the registry. Every goon's name, faction, rank, biomes, verb and tuning, the six classes and the wave mix. **Tune goons here.** |
| `scripts/art/goon_gen.js` | The generator: eleven rigs (biped, quad, beast, shell, blob, boulder, cart, scorpion, bird, snake, vehicle) and one design entry of about 15 numbers per goon at the bottom. **Change a goon's look here.** |
| `scripts/art/bake_goons.html`, `bake_goons.py` | The bake. `python scripts/art/bake_goons.py [id ...]` opens the page in headless Edge and writes each goon's folder. All 44 take about 2 minutes. Frames are baked at 2× game size (`RES`, 192 px for the default 96 px box) and shown at scale 0.5; `Goons.ART_RES` mirrors it (the Goonopedia preview zooms by it, and `test_goons.gd` checks every scene). That keeps goons sharp at 4K and in the Goonopedia; mipmaps keep small screens cheap. Change both together. |
| `scene/enemy/goons/<id>/` | Baked output: `art/<id>_<anim><n>.png` (35 frames), `art/<id>_decal.png`, `<id>_frames.tres` and `<id>.tscn`. Don't edit these by hand; re-bake. |
| `scene/enemy/walker/walker.gd`, `walker.tscn` | `Walker`, the base every goon scene inherits: state, helpers, `tryCrush`, death, night eyes. It extends `Enemy`, which extends the native `GoonBody` (`native/src/goon_body.cpp`): the per-tick fields (`speed`, `turnRate`, `bodyRadius`, `state`, `stateTime`, `cooldown`, `lockPos`, `lockDir`, `myMode`...) and the movement helpers the verbs call (`chase`, `advance`, `faceTo`, `play`, `setState`...) live there (docs/NATIVE.md). |
| `scene/enemy/goon_verbs.gd` | `GoonVerbs`, the 21 behaviours as small state machines. |
| `scene/enemy/goon_fx.gd` | `GoonFx`: telegraphs, projectiles, hazards, blasts, tethers, crush decals, bits, labels and delayed drops. |
| `scene/enemy/spawnManager.gd` | Spawning (single goons, packs, bursts), scene loading, the night flag, crush credit. |
| `scripts/world/level_roster.gd` | `LevelRoster`: a level's line-up (`LevelDef.lineup`, validated) and a district's three goons. |
| `scripts/global/Region.gd` | The run's regions, one per world district (`WorldMap.districts`): faction, goons, name, tint and the wave timer. |
| `scripts/world/world_hooks.gd` | `WorldHooks`: how goons read the world (walls, deep water, banks, line of sight). See "The world" below. |
| `tests/game/test_goons.gd` | Registry vs. baked art, faction coverage, faction and wave rules, crush rules. Line-ups and classes are checked in `test_levels.gd`. |

After a bake that adds new PNGs, run `Godot_console.exe --headless --path . --import`, then set `mipmaps/generate=true` in the new frames' `.import` files and import again. Re-bakes keep the existing `.import` files.

## Factions and territory

| Faction | Tier | What they are | Look |
|---|---|---|---|
| Wild Things | 1 | Mutant wildlife with simple instincts | Natural colours, no gear, amber eyes |
| Goon Tribe | 2 | One mutant species with tools and tricks | Violet skin, pointed ears, an orange rag, car-junk kit |
| Scrap Gang | 3 | Anything with an engine or wheels: human raiders, goon drivers, junk machines | Gang teal on every vehicle |

- **Regions are the world map's districts** (docs/WORLD.md, "Districts"): each district's three goons, name and landmark are decided once, seeded per district, from the level's line-up (see Classes below). The district's faction is its first goon's.
- **Wave mix** (`WAVE_MIX`): in wave 1 the district spawns goon 1 95% of the time; goons 2 and 3 grow more common over waves 2 to 4. The wave is the run's (one clock wherever the car drives, `Region.wave`), and the spawner's escalation adds a wave every 2 minutes on top (`SpawnManager.pickGoonId`).
- **Region data:** `Region.currentRegion` (`faction`, `name`, `giantism`, `goon` = goon ids) and `Region.factionName()`.
- **Crush XP:** each crush earns gift box XP by rank (1 / 3 / 8), ×4 for a giant, ×10 for a boss (docs/PICKUPS.md, "Gift boxes").
- **Goonopedia:** a goon shows once crushed; the console's `unlock goons` / `lock goons` override that.

## Classes

The road atlas (docs/WORLD.md, "The levels", "Regions") picks goons by class, not faction. A goon keeps its faction, which still sets its colours, goo, drop weights, the EMP's target and the `crushed:<faction>` unlock counters. A **class** is only a list of the goons a region may field (`Goons.CLASSES`, `CLASS_ORDER`, `classMembers`, `className`, `isElite`, `classesOf`):

| Class | Kind | Region | Members |
|---|---|---|---|
| `wild` Wild Things | faction | The Wilds | every rank-1+ Wild Thing (12) |
| `tribe` Goon Tribe | faction | Tribe Country | every rank-1+ Tribe goon (18; the Goonling is spawn-only). Its Yeti and Boulder play in Big Game. |
| `scrap` Scrap Gang | faction | Raider Road | every Scrap Gang rider (13) |
| `biggame` Big Game | elite | Hunting Grounds | tusker, thunderhoof, bullmoose, snapper, yeti, boulder, wrecker, rammer, plowboss, harpooner |
| `swarm` Street Swarm | elite | The Sprawl | rat, yipper, jackalope, bandit, splitter, dasher, gremlin, karter, spoke, sawbot |
| `warmachine` War Machine | elite | The Works | doomcart, torch, torcher, spitter, slinger, turret, sidecar, boostjack, magnet, foreman |

- **Line-ups:** each level fields 3-6 goons of its region's class (`LevelDef.lineup`; `test_levels.gd` checks every line-up is in its class and that a region's levels field all of its class, except a goon handed to another region's class). `LevelRoster.lineupFor` validates it (unknown ids and rank-0 goons dropped, an empty one falls back to the class).
- **A district's three goons** (`LevelRoster.pickGoons`): slot 1 one of the line-up's lowest rank, slots 2 and 3 a seeded shuffle of the rest, with no faction padding. The district's `faction` is its first goon's, so an elite district can mix factions.
- **Zones, not factions:** a district's distance from the start gives its zone (`Territories.zoneFor`, scored with `Goons.DISTANCE_WEIGHT`, `WILD_BELOW` and `TRIBE_BELOW`), which only picks how dense the region's own props are (docs/WORLD.md, "Regions"). `Goons.factionFor`, `pool` and `regionGoons` are the faction-by-distance picker from before the atlas: only `test_goons.gd` calls them.
- **Elite strength step:** the elite regions step their goons up as they spawn (`Territories.step`, `Level.strength`, `Walker.applyStrength`): Hunting Grounds damage and crush speed ×1.10, The Sprawl speed and damage ×1.10 and crush ×1.05, The Works speed ×1.10, damage ×1.20, crush ×1.10. A head-on armor no speed beats stays as it is. No mark shows on elites. Placeholders for the pacing pass.
- **Goonopedia:** a goon's page lists the classes it plays in; a level's card lists its region, class, line-up and elite step.
- **Testing:** `-- --class=wild|tribe|scrap|biggame|swarm|warmachine` picks every district's goons from that class instead of the line-up (`Region.forcedClass`); `-- --goons=a,b,c` forces three. Both work with `--playtest` and `--bench`.

## The roster

| Goon | Faction | Verb | Rule |
|---|---|---|---|
| Jackalope | Wild | hopper | Hops; can't be hit in the air (0.12-0.6 s of each 0.75 s hop, resting 0.7 s between: in the air about a third of the time). Take-off and landing can be crushed. The hop is drawn as a jump: the sprite rises 46 px and grows, draws over the car while out of reach, leaves a shadow on the ground and dust at both ends; driving under one says "AIRBORNE" |
| Tusker | Wild | charger | Long straight charge, armoured head-on while charging |
| Bandit | Wild | thief | Steals pickups and runs; crush it to get them back |
| Stinger | Wild | striker | Stops at its reach and strikes |
| Buzzard | Wild | flyer | Circles out of reach, dives at your lights, lands to feed on crushed goons |
| Rattler | Wild | striker | Rattles, then strikes the tyres |
| Quill | Wild | spiky | Fires a ring of quills; crushing it under 300 px/s costs tyres |
| Spitter | Wild | lobber | Lobs slime that slows the car |
| Snapper | Wild | burrow | Lies still as a log, then lunges |
| Yipper | Wild | pack | Packs of four that flank |
| Bullmoose | Wild | lunge | Wanders; needs 400 px/s to crush |
| Thunderhoof | Wild | herd | A herd of five stampeding across your path; 300 px/s to crush |
| Grunt | Tribe | lunge | Baseline |
| Hubcap | Tribe | lunge (shield) | Blocks head-on hits under 380 px/s |
| Dasher | Tribe | dodger | Sidesteps once when you bear down on it |
| Torch | Tribe | lobber | Lobs molotovs; fire where it dies |
| Spiker | Tribe | trapper | Lays spike strips across your line |
| Yeti | Tribe | lunge | 360 px/s to crush |
| Doomcart | Tribe | bomber | Lights a fuse and rushes you; the blast kills goons too |
| Gremlin | Tribe | hitcher | Rides the car and sabotages it until you swerve |
| Shellback | Tribe | turtle | Hides in its shell (at most 2.5 s, then 3 s before it can hide again); kick the shell above 350 px/s |
| Foreman | Tribe | boss | Goons near it move 35% faster |
| Skink | Tribe | burrow | Moves underground, surfaces to bite |
| Rat Pack | Tribe | pack | Packs of six that scatter and regroup |
| Boulder | Tribe | roller | Rolls straight at you; dizzy afterwards |
| Nightcrawler | Tribe | lunge (night) | Sleeps by day; at night it avoids your beams |
| Wrecker | Tribe | slammer | Slams a ring ahead; the hammer sticks |
| Slinger | Tribe | shooter | Shoots along a dotted aim line |
| Rammer | Tribe | charger | Long charge; armoured head-on under 320 px/s |
| Splitter | Tribe | lunge (split) | Bursts into three Goonlings |
| Spoke | Scrap | rider: ram | Biker that rams |
| Chainer | Scrap | rider: swipe | Biker that swings a chain alongside |
| Torcher | Scrap | rider: burn | Trike that overtakes and lays fire |
| Harpooner | Scrap | rider: harpoon | Buggy that hooks and drags you |
| Sidecar | Scrap | rider: bomb | Gunner lobs pipe bombs |
| Plowboss | Scrap | rider: ram | Plow truck; immune head-on (a narrow front), T-bone it above 200 px/s |
| Karter | Scrap | rider: tailgate | Goon kart that bumps your tank |
| Slick | Scrap | rider: oil | Van that overtakes and drops oil |
| Boostjack | Scrap | rider: boost | Goon on a rocket chair; explodes |
| Shredder | Scrap | rider: swipe | Spiked quad that shreds tyres |
| Sawbot | Scrap | rider: saw | Junk robot with a sawblade |
| Turret | Scrap | rider: shoot | Parks at range and shoots |
| Magnet | Scrap | rider: magnet | Tow truck that pulls the car |

## How a goon works

- **Scene:** every `<id>.tscn` inherits `walker.tscn`. The bake sets the frames, the crush decal, a collision capsule (from the rig, not the props), an occluder (the convex hull of the first walk frame, at most 10 points) and the eye positions. The sprite, shape and occluder nodes are turned a quarter turn, because the art faces up and the body faces +x.
- **Tuning:** `Walker._ready` copies the goon's `Goons.DATA` entry, then `GoonVerbs.make` builds its verb, a `RefCounted` rather than a node. `Walker._physics_process` calls `verb.tick`.
- **States:** `move`, `windup` (the tell), `attack`, `recover`, `stun`, plus each verb's own (`hidden`, `roll`, `riding`, `drop`, and so on). `setState` keeps `myMode` in step for the AI driver: windup is `PREPAREATTACK`, and lunges, charges, rolls, slams and dives are `ATTACK`.
- **Animation:**
  - Each goon has walk 8, idle 4, windup 4, attack 6, special 8 and stun 4 frames.
  - `play(anim, duration)` stretches an animation to fit the tell or attack.
  - `walkAnim(speed)` advances the walk by ground covered, so feet never skate.
- **Contact:** the car takes `damage(5)` at most once per goon every 30 ticks (`goonBumpReady` in the car). A goon that bumps the car outside an attack also steps back (`onTouch`), and riders peel off.
- **Physics layer:** goons are on their own layer (layer 3 "Goon": `collision_layer` 4, mask 3; `savedLayers` defaults to `Vector2i(4, 3)` for `setSolid`), so they don't collide with each other. Kicked shells and blasts find goons by distance (`SpawnManager.goonsNear`), not by collision.
- **Defense:** `walker.gd` has a siege block (`siegeTarget`, `sieging`, `siege`). When the car is more than `SIEGE_AGGRO` away, a goon in `move` marches on the nearer pump island (`station.nearestPump`), rounding the house by its corners when it is in the way (`station.siegeStep`), and blows up when it reaches the pump: `station.damage(attackDamage)` takes `BLAST_DAMAGE` × that off the barrier, and the goon dies as `&"self"` (no crush credit). Verbs in `SIEGE_SKIP` (burrow, flyer, rider) don't siege. Keep this block when editing `walker.gd`.

## Crushing

`OverheadCarBody2D.crushGoon` calls `goon.tryCrush(car, speed × car.crushWeight())` and returns false when the goon resists. `crushWeight()` is the car's weight (docs/CAR_ART.md, "Horn and weight"): weight 50 counts its speed as it is, the semi as 1.43× (it crushes at 70% of the speed), the racer as 0.83×. On false the car keeps its usual scuff (`wearSystem(hitZone, GOON_SCUFF)`). A successful crush never wears the car's systems, but every goon contact, crush or not, chips the hull by `GOON_CONTACT_DAMAGE` (0.35 health before armour; once per goon per 30 ticks). Keep it at 5 or less, or a Bubble Shield would spend a charge on every crush. A goon's `dmg` is the health its attack takes from a car with no armor (docs/CAR_ART.md, "Health damage").

A goon resists when any of these holds:
- it is invulnerable: a hidden shell, a rolling boulder, buried, airborne, riding the car, or a flying bird
- the car is slower than its `crush` speed
- its `front` armour applies: the car hits its front arc slower than `front`, and the verb says the armour is up (chargers only while charging)

A resisted hit calls the verb's `onResist`. That usually means `bounceCar`: the car keeps 35% of its speed and is pushed back, takes damage, and a label shows why ("BLOCKED", "TOO HEAVY", "HEAD-ON", "ROCK", "SHELL").

**Death** (`destroy(cause)`):
- **Causes:** `crush`, `boom` (killed by a blast), `self` (blew itself up) and `drown` (a splash ring, no decal).
- **What it leaves** (`GoonFx.crushed`): a pooled crush decal with a tyre print along the car's heading, bits sprayed along the hit, goo spatter, death sounds (a giant's are pitched down; only for crushes and blasts within `DEATH_SOUND_RANGE` of the car, never drownings or self-destructs), and maybe a pickup (docs/PICKUPS.md, "Drops"). The node frees at once. See "Crush feel" below for the squash and fling.
- **Credit:** goons killed by blasts or a kicked shell count as crushes (`SpawnManager.creditCrush`). So does a goon that drowns within 3 s of the car touching it (a crush try, a bump, a lunge that hit, or the car alongside it), with a "SPLASH" label.

## Crush feel

A crush should feel heavy (package 2, T1-12 and T2-6). Two halves:

**What is drawn** (`GoonFx.crushed`, Settings **Crush Effects** `gfx/crush_fx`: Minimal / Reduced / Full; presets Potato Minimal, Low Reduced, else Full):
- **Death styles** (`GoonFx.deathStyle`): a crush by the car picks one of four, weighted by speed and where the car hit the goon (`STYLE_WEIGHTS`):

  | Speed | splat | shove | hood | fling |
  |---|---|---|---|---|
  | under 350 px/s (35 mph) | 9 | 1 | 0 | 0 |
  | 350–430 | 5 | 2 | 3 | 1 |
  | 430 and up | 3 | 2 | 3 | 4 |

  A hit on a corner or the side (not the nose) doubles the shove weight and cuts the hood weight to a fifth. No hood ride under 350 px/s, and at most 2 riders at once (extra ones are shoved). Giants always splat. A blast (`Walker.killedFrom`, set by `GoonFx.blast`) always flings, away from its centre.
  - **Splat:** the goon's last frame flattens over 0.13 s into its decal, with goo droplets thrown ahead along the car's heading (`GOO`, per faction).
  - **Shove:** pushed along the line of the hit (the car's direction of travel, turned at most about 20° toward the side of the bumper that hit it), tumbling flat with a goo smear until it stops, then laid down. Distance grows with speed: a nudge of about 30–40 px at 300 px/s, about 200 px at 700. A wall cell stops it with a "SPLAT"; deep water swallows it.
  - **Hood ride:** stuck to the car's nose where it was hit, wobbling, for 0.45–1 s. Braking below 140 px/s throws it forward over the nose (a fling); a hard turn (2.4 rad/s) throws it to the outside of the turn (a shove); otherwise it slides off the side it sat on, or goes under the wheels and is flattened with a tyre print ("SQUISH").
  - **Fling:** launched spinning in an arc, its shadow on the ground, landing as a decal with a puff, bits and spatter. A wall cell in the way stops it short; deep water swallows it with a splash ring.
- **Impact burst** (Full only): spokes out of the point of impact for 0.16 s; the white flash is skipped with Reduce Flashing.
- **Giants:** twice the bits, a ground ring and a dust puff.
- Minimal: decal and bits only.

**How it feels** (`CrushFeel`, `scene/fx/crush_feel.gd`, a child of the player's car; `crushGoon` calls `onCrush`, `SpawnManager.creditCrush` calls `onIndirect`):
- **Camera trauma:** each crush adds trauma (0.13 a goon, scaled by speed; 0.55 a giant; 0.75 a boss); the shake is trauma² × 46 world px, so single crushes barely move it and crowds and giants hit hard. Each crush also kicks the view along the heading. Screen Shake (`access/screen_shake`: Off, Low = half, Full) scales it; Reduce Motion and the harnesses turn it off. It shares `Camera2D.offset` with `Juice.rumble` and stands aside while a rumble runs.
- **Hit-stop:** `Engine.time_scale` dips to 0.1 for 45 ms on a giant and 60 ms on a boss, and to 0.3 for 25 ms on the third goon of a multi-crush (once per crowd, and not within 0.6 s of the last stop). It never stacks: a stop already running wins. A pause or a menu (`get_tree().paused`, `Settings.menu_open`: the slot machine, pickup events) ends it at once, so nothing that pops up runs slowed; `CrushFeel` runs while paused only for that. The Hit-Stop setting, `access/hit_stop`; never under `Transition.instant()`. The restore timer ignores the time scale and `_exit_tree` resets it.
- **Slams** (`OverheadCarBody2D.slamGoons`): the car's physics shapes are only its bumpers, so the flanks and tail crush here. A goon touching the footprint (`carBodyArea`) on a side or the tail, where that part of the car is moving into it at 150 px/s or more (the body's speed plus the swing of a slide, `spinRate`), is crushed at that point's speed. It is swatted the way that point moved (a fling at 344+ px/s, else a shove), and pays a SIDE SLAM or TAIL SLAM bonus (2 coins, instead of the drift-crush coin). The front stays the bumper's own collision; in reverse the tail does. Buried, flying and riding goons (no collision layer) are out of reach. A shoved body is drawn darker and under the car, so it never reads as a live goon being driven over.
- **Giants:** a zoom punch (+3.5%, eased back by `updateCameraZoom`), a low thud, strong rumble, and the car keeps 90% of its speed through the giant.
- **Sound:** a crush tick whose pitch rises with the Crush Combo.
- **Bonuses** (credited at once, never from an effect): multi-crush (crushes within 9 ticks; blast kills count) pays 2 coins per goon past the first, labelled DOUBLE / TRIPLE / QUAD / MEGA CRUSH ×n; drift crush (sliding over 0.4 rad at 260+ px/s) 1 coin; giant slayer 5 coins; boss crush 10.
- **Combo:** the HUD combo readout pops on each crush and heats from gold to red past 10 and 20. The car's best combo is a car record (`records.combo`, shown on the summary and the records ticket); beating a best of 5 or more toasts NEW BEST COMBO once a run.

## The world

Goons read the world through `WorldHooks` (`scripts/world/world_hooks.gd`): O(1) grid reads on the run's `WorldMap`, never physics queries (the function table is in docs/WORLD.md, "Goon and FX hooks").

- **Water:** a solid goon over deep water drowns (`Walker.checkWater`, every 4 ticks); buried, hopping, flying and riding goons are immune until they land. Wading depth (WADE, deep water's outer band) never drowns a goon; it slows a solid one to 60% through the buff scale, like slime (`Walker.checkWade`, `WorldHooks.WADE_SLOW`). Rules and credit: docs/WORLD.md, "Water".
- **Off screen** goons move without collision through `WorldHooks.slideStep` (natively, in `GoonBody.advance`), which treats water as blocked, so none drowns unseen. On screen, `move_and_slide` handles walls, in floating mode (top-down, like the car).
- **Stuck:** a goon pressing a wall on screen and getting nowhere for 4 s (`Walker.isStuck`) is freed by the despawn sweep once it is off screen, whatever its distance. Defense keeps every goon near the station.
- **Spawns:** spawn points must be `World.spawnableAt` (3 tries in `spawner.gd`); pack members that would land on water start at the pack's spot. Snappers spawn by a log prop, the Rat Pack out of a manhole, Rattlers by red rocks and Jackalopes by burrows when one is within 1,500 px of the spot and at least 1,600 px from the car (`SpawnManager.preferredSpot`, `SPAWN_PROPS`).
- **Nearby floor:** the run opens with `OPENING_GOONS` (8) spawns in a ring just off screen and the first spawner round at once. After that, every sweep (0.5 s), if fewer than `NEARBY_FLOOR` (10) live goons are within `NEARBY_PX` (3,000 px) of the car, up to `TOP_UP_PER_SWEEP` (2) more spawn 150 to 700 px past the edge of the view, within 1.2 rad of the car's heading (`SpawnManager.topUp`). Crowds above the floor are left to the spawners and escalation. Defense (`spawnScale` ≠ 1) and the benchmarks (`floorOn = false`) skip it. The playtest `--trace` line prints `seen=` (live goons in the view plus its LOD margin) to check it.
- **Props:** `SpawnManager.onNodeAdded` tags props into groups as they stream in (`BreakableProp.tag`, `GROUPS`: `prop_log`, `prop_manhole`, `prop_crate`, `prop_carcass`, `prop_logpile`, `prop_hive`, `prop_rock`, `prop_den`, `prop_burrow`; also `ROOST_GROUP`, `EXPLOSIVE_GROUP` and `BREAKABLE_GROUP`). What goons do with them is under "Wild instincts" below; the props themselves are in docs/WORLD.md, "Interactive props".
- **FX:** shots, quills and harpoons stop at wall cells, and lobs don't leave fire or slime on them. Blasts don't reach the car or goons behind a wall cell (`WorldHooks.lineClear`); water stops nothing. Every blast sets off explosive props in its radius (`BreakableProp.blastAt`): barrels and tanks chain a hop per 0.12 s, each once. A kicked shell rebounds off wall cells and off rocks, props and walls. Oil and slime are never laid on shallows or within a fine cell of deep water. Harpoon and magnet tethers snap ("SNAPPED") when the car is within 400 px of deep water.
- **Chargers** (Tusker, Rammer) that hit a wall mid-charge stop with a "BONK" and are stunned twice as long: lure them into rocks.

## GoonFx

| Thing | Cap | Notes |
|---|---|---|
| Crush decals | 64 | Sprite2D pool under goons, fade over 8 s. Buzzards land on them. |
| Telegraphs | 48 | arrow, ring, land, crack, aim, aura, beam. Drawn unshaded under goons. |
| Projectiles | 24 | Bolts, quills, harpoons (stopped by wall cells), and arcs that land as fire, slime or a bomb |
| Hazards | 24 | fire (tyres), slime (slows), oil (skids), spikes (tyres). The oldest is dropped when full. |
| Blasts | none | Hurt the car within r+40 and kill goons within r, unless a wall cell is in between. Each plays an explosion from the level's pool (`Root.levelRoot.explode`, at most 16 live) and sets off explosive props in reach. |
| Tethers | one per goon | Harpoon (drag; a hard swerve breaks it) and magnet (pull). Both break past 650 px, and near deep water. |
| Bits, labels | 140, 12 | Visual only. Labels take a size and colour (crush bonuses are gold). |
| Corpses | 16 (6 at Reduced) | Bodies being splatted, shoved, riding the hood or flung; pooled Sprite2Ds, lit like goons. At most 2 on the hood. |
| Spatter, impact bursts | 48, 12 | Goo droplets fade with the decals; bursts last 0.16 s. |

Everything is delta-based. Telegraphs, projectiles, blasts and fire are unshaded, so night never hides a threat. Goons light their eyes (two additive unshaded sprites) when the level's CanvasModulate drops below 0.4.

## Wild instincts (Region 1)

The Wild Things use the world's props and each other. Each behaviour is a key in `Goons.DATA` or a row in a table, so other goons can take it up (Grunt, Splitter and Rammer already do). The R-n and G-n tags are the Region 1 study's item numbers, which the code comments use too.

- **Critter Chain** (`SpawnManager.creditCrush(pos, goon, source)`): every kill the player sets up (`Spill.flatten` with its source, `GoonFx.blast`, a pushed drowning, a kicked shell, a trample, a quill) within `CRITTER_CREDIT_PX` (900) of the car counts as a crush and joins the Crush Combo: `PickupEffects.onCrush` runs before the XP, so the XP sees the chain. Farther off it credits nothing (the kill still happens), except `FAR_CREDIT` sources: the player's own gadgets (`gadget`) and a drowning the car pushed (`drown`), which count anywhere without joining the chain. The car keeps the chain's distinct sources (`car.chainSources`, by display name, `PickupEffects.CHAIN_NAMES`, cleared when the chain breaks); each past the first adds crush XP (`CrushPrizes.varietyBonus`; docs/PICKUPS.md, "Gift boxes"). The HUD shows a mixed chain in gold (docs/HUD.md, "Critter Chain readout").
- **Seeks** (`"seeks"`: rows of `[group, action, carRange, goonRange]`, documented over `Goons.DATA`; `GoonVerbs.Verb.seekProp`, every `Goons.SEEK_EVERY` s): Grunt, Splitter and Yipper `release` log piles at the car (the logs flatten any goon in their way, which counts for the player); the Yipper also `knock`s hives near the car (the swarm usually eats its own pack); the Bandit `raid`s crates and hives when no pickup is in reach (`Thief.seekProp` looks for pickups first); the Buzzard `perch`es on carcasses (fresh crush decals still come first, `Flyer.seekProp`) and `roost`s in dead trees. Groups come from `BreakableProp.GROUPS` and `BreakableProp.ROOST_GROUP`. Two actions are `Goons.SEEK_SELF`: the generic look skips them and the verb uses its row at its own moment (`Goons.seekRow`): the Bandit's `stash` and the Jackalope's `hide`.
- **Bandit dens** (R-6; `Thief.goHome`, `Spill.stash`): a Bandit with loot (a stolen pickup, often a raided crate's coins) runs to the nearest unbroken `den` within its stash row's range (2,500 px) instead of fleeing, stashes the loot and is gone (`Walker.vanish`: no corpse, drop or credit). A run home that takes over 25 s gives up. The den shows a sack per stashed thing (its `Sacks` overlay, frames 0-3). Smashing it (250 px/s, or a charge or blast) bursts every stashed pickup out (`GoonFx.dropAt`) plus its 4 coins: "LOOT RECOVERED ×n". The stash lives on the den (`stash` meta) and in a record on the TileManager keyed by the den's position (`Spill.STASH_META`), so a reloaded den still holds it; never smashed, the loot stays lost.
- **Burrows and warrens** (R-7; `Hopper.tryHide`, `Spill.collapseBurrow`): Jackalopes spawn beside burrows out of sight (`SpawnManager.SPAWN_PROPS`). When the car bears down (its hide row: within 420 px, 200+ px/s, checked every 0.2 s) a Jackalope dives into a free burrow within 250 px (the burrow's `occupant` meta; one each): invisible, invulnerable and not solid, out again after 1.5-6 s once the car is 450 px off. A burrow caves in at 120 px/s keeping 95% of the car's speed (`BreakableProp.SPEED_KEEPS`), pays a coin, spawns no more and throws its occupant out stunned for 1.5 s. Burrows sharing a `group` meta (the warren motif's instance key, set by ChunkView) form a warren; caving in the last one standing pays WARREN CLEARED: 20 coins and 15 crush XP, credited at once when the car is within `CRITTER_CREDIT_PX`. Every burrow stays in `prop_warren` for the count.
- **Charges break things** (`"smashes"`: Tusker, Rammer, Bullmoose): a charge (`Charger.attack`) or lunge (`Walker.lungeStep`) into a breakable whose smash speed it beats breaks it and keeps going (`BreakableProp.smashedByGoon`): spills and coins go along the charge, a log pile's logs roll on, a barrel blows. The Tusker charges at 396 px/s (everything up to a log pile and a billboard, not a water tower); the Bullmoose lunges at 238 (crates, fences, hives, barrels). Anything else is a wall: BONK.
- **Trample** (`"tramples"`: Tusker, Snapper, Bullmoose, Thunderhoof; `Walker.trample`): during a charge, a lunge or a herd's run, every `TRAMPLE_EVERY` (3) ticks, it flattens the rank-1 goons it touches ("TRAMPLED"), credited as `trample`. Only while attacking, and herds always run.
- **Herds** (`GoonVerbs.Herd`): besides the run across your path, a herd can `graze` (still, heads down; `SpawnManager.spawnGroup(id, pos, count, &"graze")` for a set piece or an event) until `spook(from)`: the Air Horn, a blast within 450 px of its edge, or the car passing within 250 px at 30 MPH. The whole herd is then driven 6 s (`drive`) away from the scare at 1.35× speed, trampling and bursting breakables, then goes back to what it was doing.
- **Daze** (`"daze"`: Bullmoose, on levels whose `LevelDef.rules` has `"dazeHeavies": true`, read at spawn; the five Wilds levels: Prairie, Orchard, Bayou, Canyon and Moosewoods): a lunge into a wall stops with a BONK and dazes it for `Walker.DAZE_SECONDS` (1.2 s): stunned, and it crushes at `DAZE_CRUSH` (×0.75, 300 px/s).
- **Roosts** (`Spill.ROOSTS`, one row per prop: perches, knock speed, stun, ring): Buzzards roost in dead trees' crowns, up to 3, out of reach and drawn over the canopy, for 9-14 s. Ramming the trunk at 250 px/s or more (`PropReactions` CANOPY hit, `Spill.ram`, `Spill.knockRoost`) drops them stunned and crushable for 1.5 s. Scarecrows (Orchard Lanes) hold 2 the same way; a knock also spins the scarecrow round on its post, and smashing one (400 px/s) drops its Buzzards and ends the roost.
- **Bee yards** (R-9; `Spill.Swarm`): a smashed hive spills 2 coins and lets a swarm loose. The swarm goes for the goon that raided the hive first (a Bandit's raid sets the hive's `raider`), then the nearest goon; it goes for the car, and stings it, only if the car broke that hive in the last 3 s (`Spill.STING_WINDOW`, the hive's `carBrokeAt`). At most 3 swarms live (`Spill.SWARM_CAP`): a new one sends the oldest off. Each looks for a target every 3 ticks.
- **Region 1 spills and breakables** (`Spill.DEFS`, `BreakableProp`; every kill credited near the car and named in the chain): the **still** (explosive, blast 220, leaves 6 s of fire, `BreakableProp.BURNS`; chains with barrels) and the **TNT** stack (explosive, blast 190); the **sluice** gate (350 px/s) floods 900 px along the nearest channel (`Spill.channelAxis`, 8 directions sampled), flattening goons on shallows and bridges within 170 px of its line (SPLASH); the **rock pile** (350) sets off a rockslide of 4 tumbling `rock_roll`s that settle as props (`ROCKS`); a **hero saguaro** (only those with the `hero` meta or a taken-set bit; `Spill.armSaguaro` gives it the 380 smash speed and its fallen state) topples away from what broke it, flattening its box and fodder in a 150 px ring of spines round the crown (`SPINES`); the **ranger tower** (420, beyond a Tusker's charge) topples with a long box; the leaning **fallen trunk** (its third variant, `deadfall` meta) drops across the trail at 300, the other trunks just break; **pumpkins** splat at 40 keeping 98% of the car's speed for a coin; **farm gates** pay 2 coins; an **orchard oak** on a level whose rules have `"oakCoins"` (Orchard Lanes: 2) drops them on its first hit at 200+ px/s, once (`Spill.shakeOak`, `markUsed`). Falls go along a charge's or blast's direction (`spillDir`), else away from the car. Charges set off whatever their speed beats (R-3).
- **Lures** (R-10; `Pickups.lures`, docs/PICKUPS.md "Lures"): the Dinner Bell (`bell`, rammed at `Spill.BELL_RAM` 150 px/s through `PropReactions` and `Spill.ram`) and the Salt Lick (`saltlick`, heavies only, registered by `Spill.arm` and dropped by `Spill.disarm`). A rung bell stays rung after a reload (`Spill.markUsed`).
- **Snapper bubbles**: a Snapper lying as a log blows bubbles while the car is within 400 px (`GoonFx.BUBBLE_PX`), unshaded, so it can be told from the real logs.
- **Slime on goons**: Spitter slime slows solid goons in it to 50% (`GoonFx.slowGoons`, every 4 ticks, through `buffScale`/`buffUntil`, the Foreman's mechanism; slime beats a Foreman's pep talk). A slowed goon has a green ring.
- **Quill friendly fire** (`GoonFx.quillsHitGoons`): a Quill's volley flattens solid fodder (rank 1 or less) it flies into, never its shooter; credited as `quill`. It runs only while quills fly: one pass over the goons a tick, skipping those outside the volley's bounds.
- **Rattlers on red rocks** (`SpawnManager.SPAWN_PROPS`, `SPAWN_OFFSET`, `SPAWN_STATE`): a Rattler spawns beside a red rock (`prop_rock`) when one is near the spot and out of sight, and lies sunning (`sun`) until the car comes within 520 px.

## Adding a goon

1. Add a design entry to `goon_gen.js` (copy the closest goon of the same rig) and bake it.
2. Add its entry to `Goons.DATA` with a faction, a rank, its biomes, a verb and tuning. Use a new verb in `goon_verbs.gd` only if no existing one fits.
3. Add it to its faction's class in `Goons.CLASSES` (and to an elite class if it fits), and to the `lineup` of the levels that should field it (`world/levels/<id>.tres`): districts spawn only from line-ups.
4. Import, turn mipmaps on, and run `tests/game/test_goons.gd` and `test_levels.gd`. They check that the art and the registry agree, that every faction can still fill a region on every terrain, and that every line-up is in its class.

## Known gaps

- Every goon still uses the old snarl, bash and death sounds. Vehicles need engine sounds, and critters need their own.
- The tuning (speeds, crush thresholds, timings) has not been played by hand.
- Giants are 1.6× the scene's scale, 1.5× speed and twice the attack damage (`Walker.GIANT_SCALE`, `GIANT_SPEED`, `_ready`); untuned like the rest.
