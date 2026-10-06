# Goons

The goons are original art drawn by a code generator, in the same top-down Dust & Rust style as the cars. They replaced a third-party fantasy sprite set in October 2026. There are 43 goons in three factions, plus the Goonling that a Splitter bursts into. Each goon has one rule of its own (its verb), a tell before it acts, and a window when it can be punished. The concept page that chose the look is the claude.ai artifact "GoonCrusher Goon Art".

## Files

| Path | What |
|---|---|
| `scripts/global/goons.gd` | `Goons`, the registry. Every goon's name, faction, rank, regions, verb and tuning. **Tune goons here.** It also holds the faction rules and the wave mix. |
| `scripts/art/goon_gen.js` | The generator: eleven rigs (biped, quad, beast, shell, blob, boulder, cart, scorpion, bird, snake, vehicle) and one design entry of about 15 numbers per goon at the bottom. **Change a goon's look here.** |
| `scripts/art/bake_goons.html`, `bake_goons.py` | The bake. `python scripts/art/bake_goons.py [id ...]` opens the page in headless Edge and writes each goon's folder. All 44 take about 40 s. |
| `scene/enemy/goons/<id>/` | Baked output: `art/<id>_<anim><n>.png` (35 frames), `art/<id>_decal.png`, `<id>_frames.tres` and `<id>.tscn`. Don't edit these by hand; re-bake. |
| `scene/enemy/walker/walker.gd`, `walker.tscn` | `Walker`, the base every goon scene inherits: state, helpers, `tryCrush`, death, night eyes. |
| `scene/enemy/goon_verbs.gd` | `GoonVerbs`, the 21 behaviours as small state machines. |
| `scene/enemy/goon_fx.gd` | `GoonFx`: telegraphs, projectiles, hazards, blasts, tethers, crush decals, bits, labels and delayed drops. |
| `scene/enemy/spawnManager.gd` | Spawning (single goons, packs, bursts), scene loading, the night flag, crush credit. |
| `scripts/global/Region.gd` | Gives each region a faction and its three goons. |
| `tests/game/test_goons.gd` | Registry vs. baked art, faction coverage, faction and wave rules, crush rules. |

After a bake that adds new PNGs, run `Godot_console.exe --headless --path . --import`, then set `mipmaps/generate=true` in the new frames' `.import` files and import again. Re-bakes keep the existing `.import` files.

## Factions and territory

| Faction | Tier | What they are | Look |
|---|---|---|---|
| Wild Things | 1 | Mutant wildlife with simple instincts | Natural colours, no gear, amber eyes |
| Goon Tribe | 2 | One mutant species with tools and tricks | Violet skin, pointed ears, an orange rag, car-junk kit |
| Scrap Gang | 3 | Anything with an engine or wheels: human raiders, goon drivers, junk machines | Gang teal on every vehicle |

- **Which faction holds a region** (`Goons.factionFor`): the score is distance from the start in chunks × 0.35, plus level index × 0.3, ± 0.4 of random jitter. Below 1.0 the region is Wild, below 2.2 it's Tribe, and above that it's Scrap. So level 1 starts wild and gets tribal further out, while the last level starts tribal and is Scrap Gang further out. The constants are at the top of `goons.gd`.
- **A region's three goons** (`Goons.regionGoons`) all come from its faction and live on its terrain. Goon 1 is fodder (rank 1); goons 2 and 3 are specials or heavies.
- **Wave mix** (`WAVE_MIX`): in wave 1 a region spawns its goon 1 95% of the time, and goons 2 and 3 grow more common over waves 2 to 4. The HUD reveals goons 2 and 3 on the same schedule. Global time adds a wave every 2 minutes.
- **Region data:** `Region.currentRegion.faction` (a `Goons.faction` value) and `Region.factionName()`. The keys `name`, `giantism`, `time`, `wave` and `goon` are unchanged; `goon` now holds goon ids.
- **Goonopedia:** a goon shows once it has been crushed. The dev console's `unlock goons` (also part of `unlock all`) reveals all of them, and `lock goons` hides them again.
- **Testing:** `-- --faction=wild|tribe|scrap` forces every region's faction, and `-- --goons=a,b,c` forces its three goons. Both work with `--playtest` and `--bench`.

## The roster

| Goon | Faction | Verb | Rule |
|---|---|---|---|
| Jackalope | Wild | hopper | Hops; can't be hit in the air |
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
- **LOD:** off screen, `advance` moves without collision queries, as before.
- **Contact:** the car takes `damage(5)` on every tick it touches a goon, so a goon that bumps the car outside an attack steps back (`onTouch`). Riders peel off.

## Crushing

`OverheadCarBody2D.crushGoon` calls `goon.tryCrush(car, speed)` and returns false when the goon resists. On false the car keeps its usual scuff (`wearSystem(hitZone, GOON_SCUFF)`). A successful crush never wears the car.

A goon resists when any of these holds:
- it is invulnerable: a hidden shell, a rolling boulder, buried, airborne, riding the car, or a flying bird
- the car is slower than its `crush` speed
- its `front` armour applies: the car hits its front arc slower than `front`, and the verb says the armour is up (chargers only while charging)

A resisted hit calls the verb's `onResist`. That usually means `bounceCar`: the car keeps 35% of its speed and is pushed back, takes damage, and a label shows why ("BLOCKED", "TOO HEAVY", "HEAD-ON", "ROCK", "SHELL").

**Death** (`destroy(cause)`):
- **Causes:** `crush`, `boom` (killed by a blast), `self` (blew itself up) and `drown` (Water.gd; leaves no decal).
- **What it leaves:** a pooled crush decal with a tyre print along the car's heading, bits in the faction's colours, death sounds, and the old Clover-based pickup chance. The node frees at once.
- **Credit:** goons killed by blasts or a kicked shell count as crushes (`SpawnManager.creditCrush`).

## GoonFx

| Thing | Cap | Notes |
|---|---|---|
| Crush decals | 64 | Sprite2D pool under goons, fade over 8 s. Buzzards land on them. |
| Telegraphs | 48 | arrow, ring, land, crack, aim, aura, beam. Drawn unshaded under goons. |
| Projectiles | 24 | Bolts, quills, harpoons, and arcs that land as fire, slime or a bomb |
| Hazards | 24 | fire (tyres), slime (slows), oil (skids), spikes (tyres). The oldest is dropped when full. |
| Blasts | none | Hurt the car within r+40 and kill goons within r. Each also spawns the level's explosion scene. |
| Tethers | one per goon | Harpoon (drag; a hard swerve breaks it) and magnet (pull). Both break past 650 px. |
| Bits, labels | 90, 12 | Visual only |

Everything is delta-based. Telegraphs, projectiles, blasts and fire are unshaded, so night never hides a threat. Goons light their eyes (two additive unshaded sprites) when the level's CanvasModulate drops below 0.4.

## Adding a goon

1. Add a design entry to `goon_gen.js` (copy the closest goon of the same rig) and bake it.
2. Add its entry to `Goons.DATA` with a faction, a rank, its biomes, a verb and tuning. Use a new verb in `goon_verbs.gd` only if no existing one fits.
3. Import, turn mipmaps on, and run `tests/game/test_goons.gd`. It checks that the art and the registry agree and that every faction can still fill a region on every terrain.

## Known gaps

- Every goon still uses the old snarl, bash and death sounds. Vehicles need engine sounds, and critters need their own.
- The tuning (speeds, crush thresholds, timings) comes from a headless playtest or two and has not been played by hand.
- Giants are now 1.6× size and 1.5× speed; they were 4× speed in the demo.
- Region names don't reflect the faction yet.
- The Goonopedia/bestiary, if one is added, can read names and roles from `Goons.DATA`.
