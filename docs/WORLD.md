# The world

There are 30 levels in 6 regions (the road atlas). A level is three choices: where (its **landscape**: the generator grammar, ground materials, walls, water and natural props), who (its **region**: the goon class, the region's own props, its landmark, district names and strength step) and what (its twist: line-up, rules and overrides in its `LevelDef`). The map is built once per run on a worker thread, chunks are turned into "recipes" on worker threads, and the main thread only applies recipes a few nodes at a time. There are no TileMaps: the ground is drawn by one shader, walls are convex collision pieces traced from a field, and props are generated scenes. The art is in `docs/WORLD_ART.md`; the AI driver's view of the world is in `docs/AI_DRIVER.md`.

## Files

| Path | What |
|---|---|
| `scripts/world/world.gd` | `World`: the terrain table (`TERRAIN`) and the static runtime queries. Static only. |
| `scripts/world/level_def.gd` | `LevelDef`: one level (menu text, region and stop, clock, spawn tuning, rules, line-up, landscape, generator overrides, dressing overrides, pickups); `resolve()` fills its world from its landscape. |
| `scripts/world/levels.gd` | `Levels`: the registry (`ORDER`, 30 ids), id/index/scene-name resolution, the save's default level entries. |
| `scripts/world/level_roster.gd` | `LevelRoster`: a level's validated line-up and a district's three goons from it. |
| `scripts/world/landscape.gd` | `Landscape`: one landscape (generator, default world, terrain to material map, walls, roofs, water look, natural dressing, district second words, fallback). |
| `scripts/world/landscapes.gd` | `Landscapes`: the registry (`ORDER`, 15 ids), the missing-art check and fallback skin (`skinOf`), `--landscape=`. |
| `scripts/world/territories.gd` | `Territories`: the six regions (name, colour, class, landmark, district first words, prop overlays by zone, strength step, demo flag), zones, Sprint distance by region. |
| `scripts/world/world_field.gd` | `WorldField`: the pure field functions of the eight grammars. |
| `scripts/world/world_gen.gd` | `WorldGen`: the coarse build (`buildCoarse`), the fine raster (`fineRaster`), hashing (`ihash`), routing, station search, the ASCII dump. |
| `scripts/world/world_map.gd` | `WorldMap`: the run's map (`Root.worldMap`): coarse arrays, districts, the fine raster and recipe LRU, the taken set, the queries. |
| `scripts/world/chunk_recipe.gd` | `ChunkRecipe`: what one chunk is made of, built on a worker. |
| `scripts/world/chunk_view.gd` | `ChunkView`: one chunk being applied (or released) on the main thread, a step at a time. |
| `scripts/world/world_skin.gd` | `WorldSkin`: the level's ground material, strips, decor, prop scenes, node pools, pickup stock and `recipeContext()`. |
| `scripts/world/world_hooks.gd` | `WorldHooks`: O(1) grid rules for goons, GoonFx and the AI driver. |
| `scripts/world/breakable.gd` | `BreakableProp`: smashing, debris, coin spills, explosives and chains, prop groups for goons. |
| `scripts/world/prop_reactions.gd` | `PropReactions`: canopies fading over the car, props answering hits (springs, leaves, dust, spray, near-miss cracks), knocked cones, the car's position for bending decor (package 14). |
| `scripts/world/spill.gd` | `Spill`: interactive props (log piles, water towers, billboards, hives, the crane's container), goons cutting piles loose, what spilled (package 14). |
| `scene/level/tileManager.gd` | `TileManager`: builds the map at level start, places stations, streams chunks, owns the apply budget. |
| `scene/level/levelRoot.gd` | `Level`: applies the def (`applyDef`), sets the race clocks from route lengths, Marathon legs, Defense setup. |
| `shader/ground.gdshader` | The ground: one material for every ground quad. |
| `world/levels/<id>.tres` | The 30 `LevelDef`s. **Edit level numbers here.** |
| `world/landscapes/<id>.tres` | The 15 `Landscape`s. |
| `scene/level/levels/level_<id>.tscn` | Thin scenes that inherit `levelRoot.tscn` and only set `def`. |
| `world/art/` | Baked world art and `props.json` (docs/WORLD_ART.md). |
| `scripts/debug/world_preview.gd` | `WorldPreview`: prints a level's map as text. |

## Overview and data flow

1. **Level start.** `Level._enter_tree` calls `applyDef()`, which resolves the def (`LevelDef.resolve`: world fields the def leaves empty come from its landscape), takes the region's strength step (`Level.strength`) and copies `seconds`, `spawnTimer`, `giantOdds` and `escalationSpeed` from the def before any child is ready. `Level._ready` places the car at `def.startPosition`.
2. **Coarse build (worker).** `TileManager.buildWorld` picks the seed (`worldSeed`, `randi()` unless a harness set it), works out the objective (`"sprint"` for Sprint and Marathon with an offset from `Level.sprintOffsetPx`, `"defense"`, or none) and makes the job with `WorldMap.jobFor` on the main thread: a deep-copied `LevelDef.snapshot()`, the level's main terrain (`"_main"`) and the route weights from `World.TERRAIN`. `WorldGen.buildCoarse` runs on a `WorkerThreadPool` task while the main thread awaits frames.
3. **WorldMap.** `WorldMap.fromJob` wraps the result and decides each district's zone, goons, faction, name, tint, giantism and landmark (`setupDistricts`, main thread, seeded per district). The map becomes `Root.worldMap`, and `Region.setDistricts` turns the districts into the run's regions.
4. **Skin.** `WorldSkin.new(def)` takes the level's landscape and the skin it is drawn with (`Landscapes.skinOf`: its own once its art is in, else its fallback's), loads the materials into a `Texture2DArray`, the strips, decor atlases and prop scenes (the landscape's natural dressing, the region's overlay and the level's own), and `prewarm()` fills the pools and the pickup stock. `recipeContext(lots, lanes)` turns the level's tables into plain dictionaries for the workers.
5. **Chunk tasks (worker).** When a chunk enters the prefetch set, `WorldMap.request` queues `WorldMap.chunkTask`: `WorldGen.fineRaster` (the 128 px raster and the two fields), then `ChunkRecipe.build`. Results are cached in an LRU of 24 chunks.
6. **Apply (main thread).** `TileManager.updateChunks` opens a `ChunkView` per needed chunk whose recipe is ready and steps it within the frame budget. The car's own chunk is urgent: its recipe is waited for (`WorldMap.ensure`) and its ground and collision go in at once.
7. **Stations.** After one more frame, `placeStations` puts the station at the chunk the generator chose (pinned) and records the route length. `world_ready` is emitted; `Level.onWorldReady` sets the Sprint/Marathon clock or sets up Defense.

The map is pure data built from the seed and the def; the scene only ever sees recipes.

## Constants

| Name | Value | Where |
|---|---|---|
| Chunk | 5120 × 2560 px | `WorldGen.CHUNK_PX`, `World.CHUNK_PX`, `ChunkRecipe.CHUNK` |
| Map | 96 × 96 chunks (491,520 × 245,760 px); chunk (0,0) at map cell (48,48), chunks −48..47 | `WorldGen.MAP_CHUNKS` |
| Coarse cell | 1280 px square; 4 × 2 per chunk; 384 × 192 for the map; cell (0,0)'s corner at (−245760, −122880) | `WorldGen.CELL`, `W`, `H`, `ORIGIN` |
| Fine cell | 128 px; 40 × 20 per chunk (800 bytes); fields 42 × 22 with a one-cell apron | `WorldGen.FINE`, `FINE_W/H`, `FIELD_W/H` |
| Field unit | 640 px (field values are distance-like: 1.0 ≈ 640 px) | `WorldField.UNIT` |
| Map edge | the outer 2 coarse cells (2560 px) are ocean (deep water) | `WorldGen.EDGE_CELLS`, `WorldField.EDGE_PX` |
| Objectives | stay within 45 chunks of the centre on each axis | `WorldGen.CHUNK_LIMIT` |
| Keep radius | chunks more than 2 away (Chebyshev) unload, except pinned ones | `TileManager.KEEP_RADIUS` |
| Prefetch | views for what the camera sees plus 1 s of travel; rasters and recipes 1.5 s ahead | `PREFETCH_SECONDS`, `RASTER_PREFETCH_SECONDS` |
| Raster/recipe cache | 24 chunks (the car's 3 × 3 is never evicted) | `WorldMap.LRU`, `setKeep` |
| Start bubble | no barrier within 2500 px of the start; the start's coarse cells are cleared and reserved within 2500 + 1920 px | `WorldField.START_CLEAR`, `WorldGen.startBubble` |
| Shallows band | 256 px (field 0.4) round deep water | `WorldGen.BAND` |
| Wading band | the outer 224 px (field 0 to −0.35) of deep water is wading depth (WADE), where the level has shallows and its landscape doesn't opt out | `WorldGen.WADE_DEPTH`, `WorldField.hasWade` |
| District seeds | every 32 coarse cells (about 41,000 px), jittered by up to 8 cells | `DISTRICT_STEP`, `DISTRICT_JITTER` |

## The terrain table

`Root.terrain` is append-only, and `World.TERRAIN` has one row per value in the same order (`Goons.T` mirrors the enum too; `test_world.gd` and `test_goons.gd` check all three agree). Friction is on the car's scale; grip multiplies the car's grip (`CarHandling.grip`); brake multiplies the brake force; push is a conveyor's speed in px/s; hurt is the health per second the car loses there before armor (see "Water").

| id | Name | Letter | Friction | Grip | Brake | Push | Passable | Lethal | Wall | Route weight | Spawnable | Hurt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | GRASS | g | 0.13 | 1.0 | 1.0 | | yes | | | 1.0 | yes | |
| 1 | SAND | s | 0.5 | 0.9 | 1.0 | | yes | | | 1.4 | yes | |
| 2 | MUD | m | 0.6 | 0.8 | 1.0 | | yes | | | 1.4 | yes | |
| 3 | WATER (deep) | ~ | 0.9 | 0.3 | 0.5 | | no | yes | | 0 | no | 33 |
| 4 | HILLS (rock, cliff, mountain, scrap) | ^ | | | | | no | | yes | 0 | no | |
| 5 | MOSS | o | 0.08 | 1.0 | 1.0 | | yes | | | 1.0 | yes | |
| 6 | DIRT | d | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes | |
| 7 | SNOW | * | 0.3 | 0.85 | 1.0 | | yes | | | 1.2 | yes | |
| 8 | ASPHALT | = | 0.02 | 1.1 | 1.0 | | yes | | | 1.0 | yes | |
| 9 | ICE | i | 0.05 | 0.35 | 0.5 | | yes | | | 1.3 | yes | |
| 10 | OIL | % | 0.03 | 0.25 | 0.4 | | yes | | | 1.3 | yes | |
| 11 | SHALLOWS | - | 0.45 | 0.7 | 1.0 | | yes | | | 1.4 | **no** | |
| 12 | WASH | w | 0.02 | 0.9 | 1.0 | | yes | | | 1.0 | yes | |
| 13 | CONVEYOR | > | 0.03 | 1.0 | 1.0 | 250 | yes | | | 1.0 | yes | |
| 14 | MUDPIT | @ | 1.0 | 0.7 | 1.0 | | yes | | | 2.0 | yes | |
| 15 | DEEPSNOW | # | 0.6 | 0.8 | 1.0 | | yes | | | 1.4 | yes | |
| 16 | LOT | l | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes | |
| 17 | BUILDING | B | | | | | no | | yes | 0 | no | |
| 18 | BRIDGE (deck over water) | b | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes | |
| 19 | WADE (wading depth: deep water's outer band) | v | 0.75 | 0.45 | 0.6 | | yes | | | 2.5 | **no** | 2 |

WATER's friction, grip and brake only matter to the car (and the AI's `integrate()` predictions): for everything else it is solid and lethal. `lethal` means "goons drown here, nothing spawns near it, the AI never plans through it, tethers break by it"; the car survives a short swim.

**Off-road rule** (`World.effectiveFriction`): friction above grass is softened by armor, so heavy cars plough through: `f_eff = 0.13 + (f − 0.13) × (1 − clamp(armor / 200, 0, 0.35))`.

### The World API

Table lookups: `count()`, `def(t)`, `isPassable(t)`, `isLethal(t)`, `isWallTerrain(t)`, `isSpawnable(t)`, `isBlocked(t)` (not passable: water or wall), `friction(t)`, `grip(t)`, `brake(t)`, `push(t)`, `hurt(t)`, `routeWeight(t)`, `letter(t)`, `effectiveFriction(f, armor)`, `isWall(collider)` (`is StaticBody2D || is TileMap`: chunk wall bodies, props and the station are all `StaticBody2D`).

Runtime queries, delegated to `Root.worldMap`: `terrainAt(pos)`, `surfaceAt(pos)` (the ground the car drives on; the same as `terrainAt` today), `lethalAt(pos)`, `blockedAt(pos)`, `spawnableAt(pos)`, `pushAt(pos, t)` (the conveyor push as a vector, `WorldMap.beltDirAt`).

- **Hot path, allocation-free:** the runtime queries and the flag/friction/grip/brake/push/hurt lookups. The car calls them every physics tick and the AI ~900 times per plan through `integrate()`. The flag and number columns are flat packed arrays built once in `_static_init`. A real map answers them natively: `WorldMap.grid` (a `WorldGrid`, docs/NATIVE.md) mirrors the coarse map and every stored raster (`store`, eviction and `forget` keep it in step), and Root's `worldMap` setter makes it `World.grid`, so `World.terrainAt` is one native call. The GDScript `WorldMap.terrainAt` is the same rule (the last chunk's raster cached in `_cx/_cy/_fine`, else the coarse cell), kept for tools and the parity test; stand-in maps in tests go through it.
- **Not hot:** `def(t)`, `routeWeight(t)` and `letter(t)` return or read a Dictionary row. Use them in setup code and tools only.
- **No map** (`Root.worldMap == null`: the menu, most tests, the first frames of a run): the queries answer `UNKNOWN` (−1); nothing is lethal or blocked, nothing is spawnable, and the car keeps its own `friction`. Tests can put a stand-in object in `Root.worldMap` that provides `terrainAt`, `surfaceAt`, `lethalAt`, `blockedAt`, `spawnableAt` and optionally `beltDirAt`.

Worker code (`WorldGen`, `WorldField`, `ChunkRecipe`) never touches autoloads, so it keeps its own copies of the terrain ids as constants, and reads table columns from the job (`weights`, `ctx.blocked`, `ctx.spawnable`).

## The levels

Each level is a `LevelDef` in `world/levels/<id>.tres`, listed in road order by `Levels.ORDER`: six regions (`Territories.ORDER`) of five stops each, the fifth the region's finale. The demo offers the first `Root.DEMO_LEVEL_COUNT` (10: The Wilds and Tribe Country). The plan is the road atlas (the author's `road_atlas.html`); the 22 new levels start as copies of their landscape's template level and get their content later (docs/GAMEPLAY_SUGGESTIONS.md).

| # | id | Name | Region | Landscape | Clock | Line-up |
|---|---|---|---|---|---|---|
| 1-1 | `prairie` | Prairie Run | The Wilds | meadow | 240 s | jackalope, bandit, tusker |
| 1-2 | `orchard` | Orchard Lanes | | meadow | 250 s | jackalope, yipper, bandit, buzzard |
| 1-3 | `bayou` | Snapper Bayou | | bayou | 260 s | snapper, spitter, jackalope, tusker |
| 1-4 | `canyon` | Red Canyon | | canyon | 270 s | rattler, stinger, quill, buzzard |
| 1-5 | `moosewoods` | Moose Woods (finale) | | forest | 290 s | bullmoose, thunderhoof, tusker, yipper |
| 2-1 | `mudlick` | Mudlick Marsh | Tribe Country | bayou | 280 s | grunt, splitter, shellback |
| 2-2 | `stilttown` | Stilt Town | | coast | 300 s | grunt, hubcap, slinger, dasher |
| 2-3 | `lantern` | Lantern Marsh (mostly night) | | bayou | 310 s | nightcrawler, skink, rat, gremlin |
| 2-4 | `sawmill` | Sawmill Landing | | forest | 320 s | grunt, splitter, spiker, torch, rammer |
| 2-5 | `quarry` | Goon Quarry (finale) | | quarry | 340 s | foreman, doomcart, wrecker, rammer, slinger |
| 3-1 | `highway` | Route Nowhere | Raider Road | highway | 330 s | spoke, karter, chainer |
| 3-2 | `ghosttown` | Ghost Town | | ghosttown | 350 s | karter, slick, torcher, sidecar |
| 3-3 | `saltflats` | Salt Flats | | saltflats | 360 s | sawbot, shredder, spoke, harpooner |
| 3-4 | `raiderpass` | Raider Pass | | canyon | 370 s | chainer, torcher, boostjack, turret |
| 3-5 | `thunderroad` | Thunder Road (finale) | | highway | 380 s | spoke, magnet, plowboss, sidecar, slick |
| 4-1 | `frostbite` | Frostbite Pass | Hunting Grounds | mountain | 380 s | yeti, tusker, boulder |
| 4-2 | `frozenlake` | Frozen Lake | | mountain | 390 s | snapper, harpooner, tusker, plowboss |
| 4-3 | `timberline` | Timberline Camp | | forest_snow | 400 s | wrecker, rammer, thunderhoof, yeti |
| 4-4 | `tarpits` | Tar Pits | | volcano | 410 s | bullmoose, boulder, rammer, thunderhoof |
| 4-5 | `summit` | Yeti Summit (finale) | | mountain | 430 s | yeti, bullmoose, boulder, plowboss, wrecker |
| 5-1 | `city` | Rust City | The Sprawl | city | 420 s | rat, gremlin, bandit, karter |
| 5-2 | `manhole` | Manhole Mile | | city | 440 s | rat, splitter, gremlin |
| 5-3 | `culdesac` | Cul-de-Sac (mostly night) | | suburbs | 450 s | yipper, jackalope, bandit, splitter |
| 5-4 | `gridlock` | Gridlock | | highway | 460 s | karter, spoke, dasher, sawbot |
| 5-5 | `blockparty` | Block Party (finale) | | city | 480 s | rat, yipper, karter, spoke, dasher, gremlin |
| 6-1 | `blastpits` | Blast Pits | The Works | quarry | 470 s | doomcart, sidecar, boostjack, slinger |
| 6-2 | `tankfarm` | Tank Farm | | scrapyard | 490 s | torch, torcher, spitter |
| 6-3 | `slagfields` | Slag Fields | | volcano | 500 s | doomcart, turret, torcher, spitter |
| 6-4 | `theline` | The Line | | scrapyard | 510 s | magnet, turret, slinger |
| 6-5 | `crusher` | The Crusher (finale) | | scrapyard | 530 s | foreman, turret, magnet, boostjack, doomcart |

**The curve.** Today's range is spread over the 30 levels (seconds 240 to 530, `spawnTimer` 5.0 to 2.6, `giantOdds` −20 to 30, `escalationSpeed` 0.12 to 0.19, `sprintSlack` 1.5 to 1.15), stepping by thirtieths, with one step eased at each region's first stop and one added at each finale. So the numbers rise along each region's road, and a region opens a little easier than the finale before it (`test_levels.gd` checks order by region). Pickup tables run straight from Prairie's to The Crusher's over the 30 (coins thin from about 3 a chunk to about 1.5; `test_world_recipe.gd`). The kept eight keep their own generator settings (`grammar`, `features`, `baseTerrain`, `accents`, `startPosition`), so they build the same maps as before. `LevelDef.blurb`, `barrier` and `surfaces` are the level's text in run setup (the road map's panel and Level Options); the landscape adds a line (`Landscape.text`).

**Rules.** `rules.nightShare` makes a level mostly night (Lantern Marsh and Cul-de-Sac 0.75): `Timer.gd` runs day then night over each two-`daylength` cycle on the run clock; without it the old cycle runs. `rules.events` weighs the world events (`PickupWorld.pickEvent`; Salt Flats favour Ring Runs, Thunder Road and Gridlock the Loot Truck, Block Party the Golden Goon and Goon Bowling).

### LevelDef fields

- **Menu:** `id`, `displayName`, `poster` (`world/art/posters/<id>.png`, its own; `test_world_art.gd` checks the 30 posters are the 30 levels), `region` (a `Territories` id), `stop` (1-5; `isFinale()`), `order`, `blurb`, `barrier`, `surfaces`.
- **Run:** `startPosition`, `seconds`, `spawnTimer`, `giantOdds`, `escalationSpeed`, `sprintSlack`, `rules` (`nightShare`, `events`).
- **Goons:** `lineup` (3-6 goon ids of the region's class; `LevelRoster.lineupFor` validates it and falls back to the whole class).
- **World:** `landscape` (a `Landscapes` id), and overrides of the landscape's world: `grammar`, `features` (the grammar's parameters, below), `baseTerrain` (terrain ids by noise band, low to high; the commonest is the level's main ground, the faster one on a tie: `WorldField.mainTerrain`), `accents` (surfaces sprinkled as patches; only "plain" surfaces count: grass, sand, mud, moss, dirt, snow, wash, deep snow, lot). Empty ones come from the landscape (`resolve()`, called by `Levels.get_def`, `Level.applyDef`, `snapshot()` and `WorldSkin`). Then `dressing` and `motifs` (`{id: weight}` over the landscape's and region's, below), `heroes` (`{prop or motif id: [weight, anchor, variant]}`, "Heroes" below), `pickupTable` (`{kind: weight}`), `pickupsPerChunk`.
- **Layout features** (in `features`, read by the recipe and `Level`, not the grammar): `heroes` (heroes a fully open chunk gets, 1 by default), `homePaddock` (the Home Paddock opener), `hedgeWalls` (hedges as unbreakable walls, "Field walls" below), `fieldAngle` (how far the field lattice turns, 0.6 rad by default), `edgeProps` (`{id: count}` along thicket edges), `bitProps` (ids that take a taken-set bit though they don't break: Orchard Lanes' oaks, which shake apples down once), `routeFactor` (replaces the grammar's `Level.ROUTE_FACTOR` for the Sprint and Marathon clocks: Orchard Lanes 1.2, Moose Woods 1.15).
- **Look:** `palette` (the shader's fallback colour when material images are missing), `nightTint`, `ambience` (both unused).

`snapshot()` resolves the def and deep-copies every field into a plain Dictionary for worker jobs, because Resources aren't safe to share across threads.

## Landscapes

A `Landscape` (`world/landscapes/<id>.tres`, registry `Landscapes`) is where a level is: a generator grammar with its default world (`features`, `baseTerrain`, `accents`), the terrains the generator adds (`terrains`, the old `GRAMMAR_TERRAIN`), the skin (`materials`: terrain id → ground material over `WorldSkin.MATERIAL_OF`; `roofMaterial`, the wall top; `wallStrip`; `wallTint`; `organic`; `roofDecor`), the water look (`waterLook` water or lava, `waterGlow`, `waterFoam`, and `wade`: false keeps deep water's edge sheer, no wading band, as on the volcano's lava), natural `dressing` and `motifs`, district `nameSecond` words, the Goonopedia `text`, `snowy` (prop hits throw snow dust and pines drop snow: `mountain` and `forest_snow`) and a `fallback`. A new landscape re-skins an existing generator: needles drive like grass, salt like dirt, tar like mud and lava hurts like deep water, so no new terrain physics or native `WorldGrid` changes are needed.

| id | Name | Generator | Its own new art | Fallback | Levels |
|---|---|---|---|---|---|
| `meadow` | Meadow | meadow | | | 2 |
| `bayou` | Bayou | bayou | | | 3 |
| `canyon` | Canyon | canyon | | | 2 |
| `quarry` | Quarry | quarry | | | 2 |
| `mountain` | Mountain | mountain | | | 3 |
| `highway` | Desert Highway | highway | | | 3 |
| `city` | City | city | | | 3 |
| `scrapyard` | Scrapyard | yard | | | 3 |
| `forest` | Pine Forest | meadow (no field lines, pine stands; thickets where a level sets `standFrequency`, drawn with `pine_crown` roof decor and the `treeline` lip on a needles top) | `needles` | `meadow` | 2 |
| `forest_snow` | Snowy Pine Forest | meadow on snow | `needles` | `mountain` | 1 |
| `coast` | Coast | bayou (more lagoon) | `beach` | `bayou` | 1 |
| `ghosttown` | Ghost Town | city (small blocks, wide streets) | `roof_timber`, `timber_edge` | `city` | 1 |
| `saltflats` | Salt Flats | highway (few roads, no rocks) | `salt` | `canyon` | 1 |
| `volcano` | Volcano | canyon | `ash`, `tar`, `lava`, `basalt`, `basalt_lip` | `canyon` | 2 |
| `suburbs` | Suburbs | city (houses, lawns, hedges) | `lawn`, `roof_shingle`, `shingle_edge` | `city` | 1 |

**Fallback skin.** `Landscapes.skinOf(id)` checks once per landscape whether every material and the wall strip it names exist in `world/art` (`missingArt`); if not, the level is drawn with its fallback's skin (materials map, roof, strip, tint, borders, roof decor) while keeping its own generator, world, props and names. The lava look needs no art, so a volcano level glows from day one. Each landscape switches to its own skin by itself once its whole set is baked; all seven new ones have theirs now.

**Today's eight draw as before.** Their tables moved out of `WorldSkin` (`GRAMMAR_TERRAIN`, `WALL_STRIP`, `WALL_TINT`, `ORGANIC`, `ROOF_DECOR`), `WorldMap` (`NAME_SECOND`) and `Levels` (`GRAMMAR_TEXT`) unchanged, and `test_landscapes.gd` checks each kept level's material layers, water and wall layers, tint, borders, strips and roof decor against what the old code built. The world preview of the eight is identical too. What changed on purpose is the dressing: the per-district faction tables gave way to the landscape's natural props and the region's overlay.

**Forcing a landscape.** `-- --landscape=<id>` with any run, playtest, bench or world preview builds every level in that landscape (generator, default world, skin and natural props), on the level's own numbers and region.

## Regions

`Territories` (`scripts/world/territories.gd`; the `Region` autoload already means a run's districts) holds the six regions:

| id | Name | Class | Landmark | Strength step: speed / damage / crush | Sprint distance | Demo |
|---|---|---|---|---|---|---|
| `wilds` | The Wilds | Wild Things | `landmark_wild` | ×1 | 20,000 px | yes |
| `tribe` | Tribe Country | Goon Tribe | `landmark_tribe` | ×1 | 22,800 px | yes |
| `raiders` | Raider Road | Scrap Gang | `landmark_scrap` | ×1 | 25,600 px | |
| `hunting` | Hunting Grounds | Big Game | `landmark_big` | ×1.00 / ×1.10 / ×1.10 | 28,400 px | |
| `sprawl` | The Sprawl | Street Swarm | `landmark_swarm` | ×1.10 / ×1.10 / ×1.05 | 31,200 px | |
| `works` | The Works | War Machine | `landmark_war` | ×1.10 / ×1.20 / ×1.10 | 34,000 px | |

- **Class:** every level's line-up comes from the region's class (`Goons.CLASSES`, docs/GOONS.md "Classes").
- **Overlay:** `dressing`, `motifs` and `heroes` are three tables, one per zone (0 near the start, 2 far out): the region's own props laid over the landscape's (`WorldSkin.zoneTables`), heavier further out, so driving out feels like going deeper into their turf. The Wilds: carcasses, beehives, bones, crates (the baked crate, the one the Bandit raids) and crate stashes, with crate stashes and hives as heroes. Tribe Country: tents, totems, firepits, crates, fort walls, camps. Raider Road: tyres, wrecks, barrels, barricades, scrap heaps, wreck piles. Hunting Grounds: bones, carcasses, hunting stands, boneyards. The Sprawl: dumpsters, trash bags, crates, manholes, graffiti. The Works: barrels, tanks, cranes, oil, containers, junkyards.
- **Landmark:** every district's, each with a beacon that glows at night (`WorldSkin.LANDMARKS`).
- **Names:** district first words (`nameFirst`); the landscape gives the second.
- **Strength step:** `Level.applyDef` copies it to `Level.strength`, and `Walker.applyStrength` multiplies each goon's speed, attack damage and crush speed (and a crushable head-on armor) as it spawns, like the giant multipliers. No mark shows on elites.

## Grammars

`WorldField.sample(x, y)` returns `Vector3(water, wall, surface)` for any world point: two signed distance-like fields (negative inside deep water or a wall, 0 on the edge, `BIG` = 4 where there is none) and the terrain id of the ground ignoring water and walls. Everything is a pure function of the seed, the def snapshot and the point, so the coarse build and the fine rasters sample the same fields and chunk edges agree.

Common to all grammars: the plain ground is `baseTerrain` by a broad 3-octave noise band (1/9000 px), replaced by an `accents` patch where a second noise (1/2600 px) is above 0.5. The map edge is ocean. Within `START_CLEAR` of the start there is no barrier and the ground is the main terrain (a road or street stays asphalt; oil becomes asphalt).

Thresholds in `features` are raw noise values: plain simplex noise spans about −1..1 (half within ±0.35), 3-octave fbm about −0.8..0.8 (half within ±0.2). Frequencies are in 1/px, widths in px. Every grammar also reads `barrierCap` (0.2 by default; 0.35 by default on canyon, city and yard), `props` (16) and `decor` (110).

| Grammar | What the fields do | `features` keys (defaults in `WorldField.setup`) | Barrier terrain, crossing |
|---|---|---|---|
| meadow | creeks along the zero lines of one noise, where a slower mask lets them run; pools where a third noise is high widen them; dirt tracks along a fourth noise's zero lines | `creekFrequency` 6e-5, `creekWidth` 640, `poolThreshold` 0.45, `poolWidth` 520, `trackWidth` 420, `fordWidth` 1200 | water with a wading band and shallows; fords (SHALLOWS) |
| bayou | lakes where an fbm rises above `lakeThreshold`; two braided channels either side of a noise's zero line, each strand masked by its own noise | `lakeFrequency` 1/12000, `lakeThreshold` 0.3, `channelFrequency` 1.1e-4, `channelWidth` 560, `channelGap` 0.2, `bridgeWidth` 900 | water with a wading band and shallows; bridges (BRIDGE) |
| canyon | canyon walls along ridged zero lines (masked); mesas where an fbm rises above `mesaAbove`; wash lanes along another noise's zero lines; sand dunes where a fifth noise is above `duneAbove` | `ridgeFrequency` 7e-5, `wallWidth` 900, `mesaFrequency` 1/9000, `mesaAbove` 0.38, `washFrequency` 4e-5, `washWidth` 700, `duneAbove` 0.35, `passWidth` 1400 | HILLS; passes |
| meadow | creeks along the zero lines of one noise, where a slower mask lets them run; pools where a third noise is high widen them; dirt tracks along a fourth noise's zero lines; thickets (walls) where a fifth noise rises above `standAbove`, the tracks running through them as trails (`TRAIL_MARGIN` 160 px of verge); with `homePaddock`, a dirt track past the Home Paddock (`PADDOCK_TRACK_Y` −1000 px from the start, x from +1500 to +5600) | `creekFrequency` 6e-5, `creekWidth` 640, `poolThreshold` 0.45, `poolWidth` 520, `trackWidth` 420, `fordWidth` 1200, `standFrequency` 0 (none; Moose Woods 1.4e-4), `standAbove` 0.3 (Moose Woods 0.42) | water with shallows; fords (SHALLOWS); thickets: HILLS, passes |
| bayou | lakes where an fbm rises above `lakeThreshold`; two braided channels either side of a noise's zero line, each strand masked by its own noise | `lakeFrequency` 1/12000, `lakeThreshold` 0.3, `channelFrequency` 1.1e-4, `channelWidth` 560, `channelGap` 0.2, `bridgeWidth` 900, `fordShare` 0 (Snapper Bayou 0.4), `fordWidth` 1200 | water with shallows; bridges (BRIDGE), or fords for `fordShare` of them |
| canyon | canyon walls along ridged zero lines (masked); mesas where an fbm rises above `mesaAbove`; wash lanes along another noise's zero lines; sand dunes where a fifth noise is above `duneAbove` | `ridgeFrequency` 7e-5, `wallWidth` 900, `mesaFrequency` 1/9000, `mesaAbove` 0.38, `washFrequency` 4e-5, `washWidth` 700 (Red Canyon 900), `duneAbove` 0.35, `passWidth` 1400, `slotShare` 0 (Red Canyon 0.3), `slotWidth` 600 | HILLS; passes, slot canyons for `slotShare` of them |
| quarry | noise ground and dirt haul roads; one set-piece slot per `pieceCells` coarse cells: a terraced pit (ring wall with `pitRamps` ramps, mud in the middle), a junk fort (ring wall with `fortGates` gates, a lot inside) or a tyre camp (open dirt, reserved for props); mud pits (radius `mudPitRadius`, at most one per 2560 px lattice cell, 14% chance, never on a haul road) | `haulFrequency` 4.5e-5, `haulRoadWidth` 900, `pieceCells` 10, `pitChance` 0.3, `pitRadius` 3200, `pitRamps` 2, `fortChance` 0.25, `fortRadius` 2200, `fortGates` 3, `tyreCamps` 0.25, `campRadius` 1500, `rampWidth` 1000, `mudPitRadius` 200, `passWidth` 1300 | HILLS; ramps and gates are crossings |
| mountain | ranges along zero lines (masked) and massifs where an fbm peaks above `peakAbove`; ice lakes where another fbm is above `iceLakeThreshold`; deep snow where a fifth noise is above `deepSnowAbove` | `ridgeFrequency` 6e-5, `rangeWidth` 1800, `peakFrequency` 1/8000, `peakAbove` 0.42, `iceFrequency` 1/7000, `iceLakeThreshold` 0.3, `deepSnowAbove` 0.3, `passWidth` 1500 (Frostbite 1800) | HILLS; passes |
| highway | highways along +x every `highwaySpacing` px of y (highway 0 through the start), warped by up to `warpAmplitude`; branch roads along y every `branchEvery` chunks (each with `branchChance`); oil on the asphalt where a noise is above `oilAbove`; a dirt verge; gas station lots beside the highways every `gasStationEvery` chunks; rock outcrops (the only walls) where an fbm is above `rockAbove`, at least 1600 px off any road | `warpFrequency` 4e-5, `roadWidth` 1600, `branchWidth` 1000, `warpAmplitude` 3000, `highwaySpacing` 23040, `branchEvery` 3, `branchChance` 0.7, `gasStationEvery` 6, `oilAbove` 0.6, `rockAbove` 0.4 | HILLS; passes |
| city | a street lattice on the coarse grid: in every group of 5 columns (and rows) a street at offset 0 and at 2 or 3 (hashed); street cells are asphalt; blocks between streets are buildings (inset by a `sidewalk`, lot underneath), parks (grass, moss) or lots, by share; some street rows are canals (never within 6000 px of the start's row), bridged at every street column | `buildingShare` 0.45, `parkShare` 0.2, `lotShare` 0.25, `canalShare` 0.1, `canalWidth` 1040, `sidewalk` 110 | BUILDING; bridges at the full street width; no shallows or wading band |
| yard | plots of `plotSize` + 1 coarse cells, the last row and column of each being its fence line; each fence segment is a scrap mountain, a container row or open, and a walled one has a gap cell with `gapChance`; corners are always open; some plots are tank farms (lot, reserved for props); every `conveyorEvery`-th plot row has a conveyor along its middle, running +x or −x (hashed per plot row); oil spills where a noise is above `oilAbove` | `plotSize` 3, `scrapMountainShare` 0.25 (+0.35), `containerRows` 0.3 (×0.5), `tankFarmChance` 0.15, `gapChance` 0.6, `conveyorEvery` 4, `conveyorWidth` 640, `oilAbove` 0.55, `scrapWidth` 860, `containerWidth` 600 | HILLS; the gaps and corners |

`WorldGen.grammarPost` adds what the fields alone don't say: city bridges (crossings at every street column of a canal row, reserved), yard belt directions (the coarse `aux` byte: 1 +x, 2 −x, 3 +y, 4 −y) and reserved tank farms, quarry set pieces (reserved, with their ramps and gates opened as crossings), and reserved gas station lots near the middle of the highway map.

## The coarse build

`WorldGen.buildCoarse(job)` runs these passes in order (`WorldGen.run`). Each coarse cell gets a terrain id, flag bits, a district id and an aux byte.

| Flag | Bit | Meaning |
|---|---|---|
| `BLOCKED` | 1 | water or wall: A*, spawns and objectives keep out |
| `LETHAL` | 2 | deep water |
| `CROSSING` | 4 | a ford, bridge or pass cut through a barrier |
| `RESERVED` | 8 | start bubble, objectives, set pieces, the map edge: later passes leave it alone |
| `CROSS_X`, `CROSS_Y` | 16, 32 | the direction a crossing is travelled |
| `FILL` | 64 | a pocket filled in; the fine map fills it too |
| `START` | 128 | in the start's component (reachable) |

1. **Sample** every cell centre: a wall field below `BAND` (0.4) blocks the cell as the grammar's wall terrain, a water field below it as WATER. `cover` records how much of a blocked cell the barrier really covers (0..255), for the share caps.
2. **Grammar post-pass** (above).
3. **Share caps:** hard barriers may cover at most `barrierCap` of any 3 × 3-chunk window (12 × 6 cells, every chunk offset), measured by `cover`. A summed-area table finds windows over the cap; cells are removed from blob edges first (the most blocked neighbours, hash tie-break), so lakes and mesas shrink before thin barriers get holes. Reserved cells don't count.
4. **Start bubble:** every cell within `START_CLEAR + 1.5 × CELL` of the start is opened and reserved.
5. **Crossings:** short barriers (8-connected components no more than `SHORT_BARRIER` = 8 cells across: ponds, mesas, short walls) are driven round, not cut. Along every other barrier, a crossing at least every `MAX_RUN` cells (4, or 3 by a hashed bit): the map is scanned column by column for barriers running along x (runs that touch the previous column's continue its count; short runs chain diagonally), then row by row for barriers along y, then once more along x. A crossing is cut only through a run at most `MAX_CUT` (4) cells thick with open ground on both sides, and none is cut next to an existing crossing. Water becomes the grammar's `waterCrossing` (SHALLOWS ford or BRIDGE); a wall becomes the surface below it (a pass).
6. **Connectivity:** 4-connected passable components are labelled. Pockets smaller than `POCKET` (12 cells) are filled (water or wall, whichever borders them more; `FILL`). Larger islands are joined to the start's component by the shortest straight cut of at most `CONNECT_DEPTH` (6) cells, in up to 3 passes. An island no cut reaches stays: nothing is placed there and A* never routes to it.
7. **Objectives** (below): the Sprint station or Defense's station and lanes.
8. **Districts:** multi-source BFS over passable cells from seeds every `DISTRICT_STEP` (32) cells, each jittered by up to 8 and moved to the nearest passable cell, so barriers become borders. Cells no seed reaches get districts of their own.
9. **Exits:** every district in the start component with fewer than 2 neighbouring districts gets the shortest straight cut (at most `MAX_CUT` cells) to a district it doesn't border yet.
9a. **Mixed crossings** (`mixCrossings`, L-6): on a grammar that bridges its water, `fordShare` of the water crossings become fords (SHALLOWS), each crossing as a whole: the choice is hashed (`TAG_FORD`) on the crossing's root (`WorldGen.crossingRoot`: its first cell, walked back against the way through), so all its cells agree. Fords are slow (route weight 1.4) but wide (`fordWidth`); bridges fast and narrow. Slot canyons are chosen the same way (`WorldGen.isSlot`, `TAG_SLOT`) but only in the fine raster.
10. **`START`** is recomputed, then an `AStarGrid2D` is built over the passable cells (`makeAStar`: solid where blocked, weight = the terrain's `routeWeight`, diagonals only where no corner is cut), and the route from the start to the station is measured (`routeBetween`: never shorter than the straight line).

The result also lists every district (`id`, `cells`, `centroid`, `firstCell`, `neighbours`, `inStart`, `landmark`), the crossings, the station and its chunk, the lane mouths, the route, `routeLength`, `routeReached` and timings (`ms`). The build takes about 1.3–2.9 s on the dev box's worker thread, depending on the level.

### The fine raster

`WorldGen.fineRaster(job)` samples the same fields at the centres of a chunk's 40 × 20 fine cells (plus a one-cell apron, so neighbouring chunks agree) and clamps them to the coarse map so the two never disagree about passability:

- Between the centres of two 4-adjacent passable coarse cells the fine map is always open: the fine fields stay above (the bilinear coarse envelope − `A_LO`), a corridor at least 2 × 448 px wide.
- A blocked coarse cell is always blocked within `PILLAR_PX` (160 px) of its centre (on levels with a wading band the water pillar falls `WADE_STEEP` (2) times as fast below 0, so the same edge is deep water round the centre and wading depth only near the edge).
- Filled pockets are filled (their water steepened the same way, so they are deep inside); crossings in a cell or its 4-neighbours open their full width (`fordHalf`, `bridgeHalf`, `passHalf` across the way through). Inside a pass, deep snow and ice become plain snow, so heavy cars don't stick there.
- The fine terrain is the wall terrain where the wall field is below 0; BRIDGE where a bridge crossing covers water; WATER where the water field is below −`WADE_DEPTH` (−0.35, 224 px in) where the level has a wading band, else below 0; WADE between that and 0; SHALLOWS where the water field is below `BAND` (256 px) on grammars with shallows (all but the city) or at a ford; else the surface. The wading band is on where `WorldField.wade`: the grammar has shallows (`WorldField.hasShallows`: all but the city, whose canals keep sheer edges) and the landscape doesn't opt out (`Landscape.wade`, passed to the worker as the def's `_wade` by `WorldMap.jobFor`; the volcano's lava opts out). Fords keep their field above 0, so they stay shallows; bridge decks stay bridges.
- A blocked coarse cell is always blocked within `PILLAR_PX` (160 px) of its centre.
- Filled pockets are filled; crossings in a cell or its 4-neighbours open their full width (`fordHalf`, `bridgeHalf`, `passHalf` across the way through). Inside a pass, deep snow and ice become plain snow, so heavy cars don't stick there.
- A slot canyon (`slotShare` of the passes, `WorldGen.isSlot`) opens only `slotHalf` (`slotWidth` / 2) across the way through: where the natural wall stands, the fine wall field is clamped to `max(wall, (slotHalf − across) / UNIT)`, closer than the coarse envelope's 896 px corridor would leave it. The walk along its middle stays open, so the fine map still agrees with the coarse one.
- The fine terrain is the wall terrain where the wall field is below 0; BRIDGE where a bridge crossing covers water; WATER where the water field is below 0; SHALLOWS where the water field is below `BAND` (256 px) on grammars with shallows (all but the city) or at a ford; else the surface.

The output is the 40 × 20 terrain bytes plus the `water` and `wall` fields at 42 × 22 (under a bridge the water field stays negative, for the art), `tracks` (meadow: a 40 × 20 mask of the cells on a dirt track, as opposed to a dirt patch of the base ground; empty elsewhere) and `crossings` (`WorldGen.crossingRuns`: one entry per crossing among the 7 × 5 coarse cells round the chunk, `{centre, axis, kind (ford, bridge, pass), slot, cells}`), which the recipe anchors heroes and slot coin lines to.

## Districts

`WorldMap.setupDistricts` decides, per district and seeded from the world seed and the district id (`ihash` tags `TAG_FACTION` (the zone's jitter), `TAG_GOONS`, `TAG_NAME`, `TAG_TINT`, `TAG_GIANT`):

- **Zone** (`Territories.zoneFor`): the centroid's distance from the start in chunks (5120 px) × `Goons.DISTANCE_WEIGHT` (0.35), ± `Goons.FACTION_JITTER` (0.4): below 1.0 zone 0, below 2.2 zone 1, else zone 2. The start's own district counts as distance 0. The zone picks the dressing table (the region's props grow denser further out).
- **Goons** (`LevelRoster.pickGoons`): three of the level's line-up, slot 1 its lowest rank, slots 2 and 3 a seeded shuffle of the rest (a line-up shorter than three repeats). The district's **faction** is its first goon's (an elite line-up mixes factions).
- **Name:** a region word (`Territories` `nameFirst`) and a landscape word (`Landscape.nameSecond`), unique within the map ("Tusker Flats", "Rust Junction").
- **Tint:** 0.9–1.08, also stored as a 4-bit code (`tintCodes`) that the ground shader shows as a faint brightness shift (0.93–1.05) on open ground.
- **Giantism:** 0–99. Shown on the HUD region chip; not used by spawning yet.
- **Landmark:** the region's (`Territories.landmark`) at the open cell nearest the centroid (within 10 cells, not reserved, all 8 neighbours passable), recorded per chunk in `WorldMap.landmarks`. `ChunkRecipe.placeLandmarks` finds the exact spot round it (rings of 128 px, 8 rings) and leaves it out if nothing fits.

`Region.setDistricts` turns each district into a region (`name`, `terrain`, `giantism`, `faction`, `goon`, `terrain_modulate`, `visited`). A district decides *who* spawns; waves are one clock for the whole run (`Region.wave`, `runTime`: a star and a wave chest every 60 s, no cap, untouched by crossing districts; roadmap W-1); `-- --class=<class>` (any of `Goons.CLASSES`) and `-- --goons=` override them. `TileManager.updateChunks` checks the car's coarse cell; when it enters a cell of another district (a barrier cell keeps the last one), it calls `Region.updatePlayerRegion`, which pushes the district's goons to the spawner. 

## Objectives

- **Sprint station:** `placeSprintStation` asks `findStationChunk` for the chunk nearest `start + Level.sprintOffsetPx(seconds, roll)`, searching square rings outward: the 4 cells round the chunk's centre must be passable and in the start component, and the lot rect (`WorldGen.LOT_RECT`, 5300 × 2800 px round the centre: the lot, 2000 px of approach to the east and room behind) must be clear. Failing that within three more rings, the nearest chunk with a good centre is used. Only chunks at least `STATION_MIN_SHARE` (85%) as far from the start as the desired one count (Marathon's next legs measure from the last station), so the nearest good chunk can't lie back toward the start. Before this, one Crusher seed put the station 11,812 px out with a 46.8 s clock. If none qualifies, any chunk does. The lot's cells are then opened and reserved. The offset is the region's Sprint distance ahead (+x; `Level.sprintDistance`, `Territories.sprintDistance`: 20,000 px in The Wilds rising by 2,800 a region to 34,000 in The Works), with a y spread of up to 25% (`TAG_SPRINT` roll), at most `Level.SPRINT_MAX_DISTANCE` (34,000 px) × the same multiplier. The multiplier is `ModeTiers.SPRINT_DISTANCE`: a Sprint's tier (Easy ×2.875, Medium ×3.25, Hard ×3.75: 57,500 to 75,000 px in The Wilds, 97,750 to 127,500 in The Works) or ×2.5 for a Marathon leg (50,000 px in The Wilds, 85,000 in The Works; 2, 3 or 4 legs by tier, `ModeTiers.LEGS`). A stock sedan's tank lasts about 34,000 px on sand or mud, so every race needs fuel pickups on the way. A Marathon leg that would leave the map heads back toward its centre (`Level.legHeadingFrom`).
- **Route-length clocks:** `Level.onWorldReady` sets the Sprint clock from the A* route (`TileManager.lastRouteLength`, never shorter than the straight line): `drive = route × ROUTE_FACTOR[grammar] + STATION_APPROACH_PX` (a level's `features.routeFactor` replaces the grammar's: Orchard Lanes 1.2, Moose Woods 1.15), then `clock = drive / 450 × sprintSlack`. The route on 1280 px cells is shorter than the real drive (fine walls, pools, props, corners, and the lot's single east gap), so `ROUTE_FACTOR` is 1.08 meadow, 1.12 bayou, 1.15 canyon, 1.12 quarry, 1.15 mountain, 1.05 highway, 1.12 city, 1.15 yard (1.1 default), and the approach allowance is 1500 px.
- **Marathon legs:** each station but the last calls `Level.stationReached`. `TileManager.placeNextStation` retires and unpins the old station, then finds the next chunk a Sprint offset away, turned within 60° of the last leg (`TAG_LEG` rolls), never the chunk just left. It is searched on the finished map, so its lot's terrain is not cleared (walls or water can stand in it): a chunk whose lot is already clear is preferred. Its props, pickups and `decorateChunk` spots are kept out of it as for the first station: `pinChunk` reserves the lot and drops the recipes already built round it, so they are built again. The leg's clock comes from `WorldMap.routeBetween` with the same drive formula.
- **Defense lanes:** the station goes in the start's chunk or the nearest one that qualifies (`findStationChunk`), its lot is cleared, the car is moved outside the lot's gap (`Level.DEFENSE_START`), and 3 straight lanes (`DEFENSE_LANES`) run out from it at a seeded turn plus 120° each (± 0.3 rad), from 900 px to 4900 px from the station; every cell within 1000 px of a lane's line is opened and reserved. The lane mouths (4000 px out) are where `Level.setupDefense` puts the spawners; props keep 450 px off the lanes. Without lanes (no map) the spawners ring the station at 4000 px.
- Every station chunk is pinned (`TileManager.pinChunk`), and its lot rect is added to `lots`: the recipe context is rebuilt, and props and pickups inside a lot are skipped at apply time too (`TileManager.reservedAt`), so a recipe cached before the lot existed still keeps out.

## Chunk recipes

`ChunkRecipe.build(job)` runs on the worker right after the fine raster and turns it into a Dictionary in chunk-local px (the chunk's top-left corner is 0,0). It touches only its job: the level's tables come in `job.ctx` (`WorldSkin.recipeContext`), the district zones and tint codes of the chunk's 8 coarse cells in `job.zones` and `job.tints`, the belt directions in `job.aux`, and the landmarks standing in the chunk in `job.landmarks`.

| Key | Contents |
|---|---|
| `control` | 42 × 22 RGBA8 for the ground shader (below) |
| `pieces` | convex `PackedVector2Array`s: the walls' collision |
| `occluders` | open polylines along walls, solid on the right |
| `lines` | `[strip index, points]`: shore foam and wall lips for `Line2D`, barrier on the left |
| `decor` | `{decor id: PackedFloat32Array}`: MultiMesh buffers (12 floats an instance: 2D transform, custom data x picks the atlas cell); in the city also the rooftop dressing |
| `props` | `[id, pos, rotation, variant, taken bit (−1 none), occluder, group, hero]`, a landmark first. `group` (int, 0 for none) is the motif instance the prop belongs to, `WorldGen.ihash(seed, TAG_GROUP, chunk, motif index)`; `hero` is true for what the hero pass placed. `ChunkView` puts both on the node as metadata `group` and `hero` (and clears them on pooled props), for the set pieces' behaviour (a warren cleared, an apiary's hives) |
| `fieldWalls` | convex boxes: unbreakable field lines (Orchard Lanes' hedgerows), added to the chunk's wall body |
| `pickups` | `[pickup id, pos, taken bit]` |
| `spots` | up to 3 open places (480 px clear) for `PickupWorld.decorateChunk` |
| `counts`, `phases`, `usec` | budget counts (`nodes`, `occluders`, `pieces`, `props`, `pickups`, `decor`, `lines`, `dropped`, `simplify`, `heroes`, `heroesDropped`, `bits`, `fieldWalls`) and timings |

Order of work: control block; wall contours (marching squares over the padded wall field, only when some wall value is below 0); convex pieces; occluders; lines (wall lips and, when some water value is below 0, shore foam broken at bridge decks); then placement: landmarks, the Home Paddock's reservation, field walls, `spots`, pickups (a slot canyon's coin line first), props, decor, rooftops; then the node budget.

### Budgets and how they are enforced

| Budget | Value | Enforcement |
|---|---|---|
| Nodes per chunk (pickups and decorateChunk extras not counted) | 100 (`MAX_NODES`) | fixed cost first: 8 ground quads, the wall body, occluders, lines, one MultiMesh per decor id; then props in placement order, each costing 3 nodes (+1 with an occluder, +1 with a beacon, +1 with a canopy); a prop that would pass the budget is dropped |
| Occluders | 16 (`MAX_OCCLUDERS`), each at most 1280 px on a side (`SPAN`) | wall occluders are split to the span, sorted longest first, and the shortest dropped; props past the remaining room are placed without their occluder |
| Static pieces | 48 (`MAX_PIECES`), field walls included | Douglas-Peucker simplification grows through 16, 32, 64, 128 px until the pieces fit; points on the chunk's edge are kept so neighbouring chunks meet; a simplification that lost too much area falls back to the exact outline; field walls take what is left, a run that doesn't fit is left out with its decor |
| Taken-set bits | 31 breakables (32–62) | given in placement order (landmarks, paddock, heroes, gates, field lines, motifs, scatter); a paying breakable (coins, a spill, a stash: `WorldSkin.PAYING_PROPS`, `BreakableProp.COIN_SPILL`, `Spill.DEFS`) that gets none is left out, so nothing pays twice |
| Lines | 24 (`MAX_LINES`), each within 1280 px | split to the span, the shortest dropped |
| Area2D | none but pickups | |
| World lights | none | landmarks glow through an additive unlit `Beacon` sprite instead |

Wall blobs and holes under 2500 px² are dropped or filled (`MIN_LOOP_AREA`), pieces under 64 px² are dropped. `test_world_recipe.gd` checks the budgets for every level over 3 seeds. A recipe takes about 4–13 ms on average on a worker, depending on the level.

### Props and decor

- **Dressing:** each zone's table (`WorldSkin.zoneTables`) is the landscape's natural dressing (`Landscape.dressing`), the region's own for that zone added on top (`Territories` `dressing[zone]`, denser further out) and the level's own (`LevelDef.dressing`, replacing a weight; 0 takes a prop out); motifs the same way. Ids `props.json` doesn't have are left out. `WorldSkin.dressingIds` splits them by the manifest's class: DECOR ids become MultiMesh decor, the rest (LOW, TALL, STATEFUL, WALL) pooled or instanced scenes. The region's landmark is always loaded, and the skin's `roofDecor` (the city's `rooftop`) too.
- **Props** (`placeProps`) come in these passes, all counted against `features.props` (16 by default; Bayou and Frostbite 18, Canyon and Highway 13, City 12) × the chunk's open share:
  1. **The Home Paddock** (`placeHomePaddock`, below), on a level with `homePaddock`.
  2. **Heroes** (`placeHeroes`, R-2, below). Each counts as `HERO_COST` (1.0); the hedgerows' farm gates follow them.
  3. **Edge props** (`placeEdgeProps`): `features.edgeProps` (`{id: count}`) on a thicket's lip (the wall field within `LIP_FIELD` 0.03–0.12, so the trunk meets the wall and leaves no gap a car could wedge in): Moose Woods' 7 pines a chunk, the only real trees round its thickets.
  4. **Field lines** (`placeFieldLines`, package 14 P-3). Fences and hedges (`WorldSkin.FIELD_PROPS`) are never scattered: they lie on the edges of a field lattice in world space, one lattice per `FIELD_REGION` (10,240 px) square, turned up to `features.fieldAngle` (`FIELD_ANGLE`, 0.6 rad; Orchard Lanes 0.12) from the world axes by the seed, `features.fieldSpacing` px apart (1400; Prairie 1600, Orchard Lanes 1200). Each lattice edge is a fence (chance `features.fenceDensity`), a hedge (`hedgeDensity`) or nothing; a run has a gap (a gate; two on runs of `FIELD_GATE_LONG` pieces or more). A chunk places the pieces whose centres are inside it, in the dressing of the district's zone there, on open ground off roads (so roads and creeks cut gaps) and clear of water, walls and earlier reservations; pieces of one run touch end to end. Hedgerows get an oak at some corners (`CORNER_TREE`); a lattice cell fenced on `PADDOCK_EDGES` (3) sides is a paddock with 2-4 hay bales inside. Each piece counts as `FIELD_COST` (0.5) of a scattered prop. On a level with `hedgeWalls` the hedges are walls instead ("Field walls", below).
  5. **Motifs** (`placeMotifs`, P-5). The zone's motif table (landscape, region, level) picks set pieces from `WorldSkin.MOTIFS` (camp, cabincamp, wreckpile, junkyard, pinestand, snowstand, rangerpost, cypressgrove, orchard, boneyard, roadblock, pileup, and Region 1's cratestash, warren, apiary, ranch, farmyard, pumpkinpatch, loglanding, hivegrove), `features.motifs` (1; City 0.4, Highway and Crusher 1.2) a fully open chunk. A motif's members sit at its centre, round a ring, scattered in a disc, in a grid or line turned to the field lattice (a line may stand `offset` px off the centre), or as a fenced pen (`pen`: pieces round a square, one gap); a member's count may be a range, and it may pick from listed `variants` (the apiary's box hives). Members are `MOTIF_GAP` (70 px) apart instead of `PROP_GAP` (pen pieces touch end to end, and the rest keep off their boxes); the motif keeps `PROP_GAP` from everything else and is skipped when fewer than its `min` members fit. Members load with the level whatever its dressing says, and share a `group` key. Each counts as `MOTIF_COST` (1.0).
  6. **Scatter** by dart throwing for the rest (up to 14 darts per prop wanted), each spot from its coarse cell's district zone's table, field props left out. A prop must fit at its centre and 4 points across its box: on spawnable ground, never on a conveyor, mud pit or bridge, off asphalt and oil unless it is a road prop (`ROAD_PROPS`: cone, jersey, wreck, manhole, barricade, sign, mile marker), at least 77 px (`PROP_MARGIN`) from water and walls, outside the start's core (1200 px), station lots and Defense lanes, and `PROP_GAP` (150 px) clear of everything placed, so a car can weave through. Other chain props (jersey, fortwall) are laid 2–4 end to end; a chain that may stand on roads lies along the road there (`roadAxis`: the heading of 8 with the longest run of road).
  Breakables take taken-set bits in placement order across the passes (`nextBit`). Recipes now average about 14-15 ms on a worker on Prairie (field lines and motifs), Prairie's chunks reach the 100-node budget, and the rest stay under it.
- **Decor** (`placeDecor`): `features.decor` (110) × the open share, never on blocked, bridge or conveyor cells. `WorldSkin.DECOR_PLACE` limits some ids: `paint` and `streetglow` only on roads and lots, `reeds` only on shallows and banks, `oilstain` and `cracks` anywhere; the rest stay off asphalt, oil and shallows. Tufts, reeds and tumbleweeds bend away from the player's car (`WorldSkin.BEND_DECOR`, `world_decor.gdshader`: each corner pushed by how close it is to `gc_car_pos`, which PropReactions sets each frame; off at Ground Detail Simple).
- **Roof decor** (`placeRoofs`): the skin's `roofDecor` on wall-top cells (BUILDING in the city, HILLS elsewhere), styled by `WorldSkin.ROOF_STYLE`. City rooftops: up to 48 a chunk, at least 0.3 field units (192 px) inside the parapet and 190 px apart, square to the street grid. Moose Woods' pine crowns (the forest landscape's `roofDecor`, over its thickets): up to 110, 0.1 units inside the edge, 150 px apart, any way round, scaled 0.95–1.3.

### Heroes (R-2)

Interactive props and set pieces are placed **first** in each chunk (after the landmark and the Home Paddock), on layout anchors, so the node budget (which drops props in placement order) keeps them; `test_world_recipe.gd` checks none is ever dropped (`counts.heroesDropped`). The table per zone (`ctx.heroTables`) is the region's overlay (`Territories` `heroes`) under the level's (`LevelDef.heroes`): `{prop or motif id: [weight, anchor, variant]}`. A chunk wants `features.heroes` (1 by default) × its open share, picks from its majority zone's table (up to `HERO_PICKS` ids per hero, so a chunk without a ford moves on to another id) and throws `HERO_TRIES` darts at the anchor:

| Anchor | Where |
|---|---|
| `ford` | 600–1400 px from a ford crossing's middle (`HERO_NEAR`: past its shallows onto the bank), facing it |
| `bank` | 2–5 fine cells (256–640 px) from water, shallows or a deck (a search from the wet cells) |
| `track` | 250–500 px off a dirt track (the raster's track mask), none within 200 px, turned so its +y faces the track (a tower or a deadfall falls across it) |
| `pass` | 350–1000 px from a pass, where the wall field is 0.15–0.8 (a wall's foot), facing the pass |
| `clearing` | at least 90% of 17 points out to 640 px open and 0.4 units off walls and water |
| `edge` | a thicket's edge (wall field 0.3–0.6) |
| `any` | anywhere a prop fits |

Everything the hero pass places carries `hero` (metadata `hero`); a motif's members share a `group`. `WorldSkin.HERO_BREAKABLE` props (the saguaro) take a taken-set bit only when the hero pass placed them, so C2's behaviour can make exactly those breakable. The levels:

| Level | `heroes` | Heroes |
|---|---|---|
| Prairie Run | 1.5 | water tower `ford`, log pile `track`, crate stash `any`, Dinner Bell `track`, den `any` (rare), apiary `any` (rare) |
| Orchard Lanes | 1.5 | apiary, farmyard, scarecrow, den (rare) `any`; pumpkin patch, bell `track`; water tower `ford` |
| Snapper Bayou | 1.5 | log, still, log pile `bank`; sluice `ford` |
| Red Canyon | 2.5 | saguaro `any` (the breakable ones); rock pile, TNT `pass` |
| Moose Woods | 1.5 | log landing, salt lick `clearing`; ranger tower, deadfall (fallen trunk variant 2) `track` |
| (The Wilds overlay) | | crate stash `any`; beehive `any` from zone 1 |

### The Home Paddock

`features.homePaddock` (Prairie Run): a fixed set piece `PADDOCK_AHEAD` (2600 px) ahead of the start along +x (where Sprint goes; outside `START_CORE`): a fenced paddock of half side `PADDOCK_HALF` (480 px) with its gate toward the start, a three-crate stash (one `group`) and two hay bales inside, a log pile at the far corner above the dirt track the grammar runs past it (`WorldField.PADDOCK_TRACK_Y`). It is laid out in world space (`ChunkRecipe.PADDOCK`) and each chunk places the members whose centres it holds, so it may straddle a seam; its disc is reserved before the spots and pickups. `decorateChunk` skips the start's chunk, which is why the recipe builds it.

### Field walls (L-8)

On a level with `features.hedgeWalls` (Orchard Lanes), a hedge lattice edge is an unbreakable hedgerow (`WorldSkin.WALL_FIELD_PROPS`), not a row of 4-node breakable props: boxes in the chunk's own wall body (`fieldWalls`, 100 px wide), closed occluder loops (at most `WALL_OCCLUDERS` 10 a chunk, within `MAX_OCCLUDERS`) and one decor MultiMesh of the `hedgerow` atlas (straights stretched to the run, end caps; docs/WORLD_ART.md "Hedgerow"), so a dense lattice costs almost no nodes. They are laid first, before the spots, pickups and props, which keep off them. Each edge is cut into the slots a run of hedge props would have; the chunk holding a slot's centre owns it and consecutive owned slots make one box. A slot that crosses a road, a farm track (so the tracks are the lanes), a belt, a bridge, water or an earlier reservation is a gap. The gate slot gets a farm gate (breakable, `gateChance` 0.75; the rest stay open). Caps close a run at a gate, a gap, or a lattice point no other hedgerow meets. Not terrain: the fine/coarse clamp would punch a corridor through a 100 px terrain hedge every 1280 px.

### Region 1 levels

- **Prairie Run:** creek 1100 px, `trackWidth` 600 (the Sprint spine), `fenceDensity` 0.22, `hedgeDensity` 0.10, orchard motif ×1, ranch and warren motifs, the Home Paddock, heroes.
- **Orchard Lanes:** the hedgerow lattice (`fieldSpacing` 1200, `fieldAngle` 0.12, `hedgeDensity` 0.45, `fenceDensity` 0.25) with farm gates, narrow creeks (700), farm tracks 500 wide, orchards ×2 and pumpkin patches, scarecrows, `routeFactor` 1.2, oaks with a taken-set bit (`bitProps`).
- **Snapper Bayou:** mixed crossings (`fordShare` 0.4: fords 1200 wide, bridges 900), cypress groves with hives (`hivegrove`), warrens.
- **Red Canyon:** washes 900 wide, slot canyons (`slotShare` 0.3, 600 wide, each with a coin line along its middle in `placePickups`), rock piles and TNT at passes, hero saguaros.
- **Moose Woods:** thickets (`standFrequency` 1.4e-4, `standAbove` 0.42, `barrierCap` 0.3: about 20% of the map, a 2.8–3.1 s coarse build) as HILLS walls drawn with pine crowns (`roofDecor`) and the `treeline` lip (`wallStrip`) on a needles top (`roofMaterial`, `wallTint`), trails along the dirt tracks, edge pines, log landings and salt licks in clearings, towers and deadfalls on trails, `routeFactor` 1.15.

### Pickups and the taken set

`placePickups` rolls `pickupsPerChunk` kinds from `pickupTable` (`coinline`, `fuel`, `health`, `purse`, `slot`, or `none`, which places nothing, so a chunk can stay empty; `WorldSkin.PICKUP_IDS` maps them to `Pickups` ids, `slot` → `slotmachine`). A `coinline` is 7 coins 130 px apart on a gentle bend. Every pickup stands on spawnable ground, 128 px from water and walls, inside the chunk and outside the reservations.

**The taken set** (`WorldMap.taken`: chunk → int bitmask) lasts the whole run. Pickups take bits 0–31 in placement order (each coin its own; a pickup past bit 31 has none and comes back on a reload), breakables bits 32–62. `ChunkView` puts the slot on each node as metadata `worldSlot = Vector3i(chunk x, chunk y, bit)`. Collecting a pickup (`Powerup` calls `WorldMap.takeNode`) or smashing a breakable (`BreakableProp.markTaken`) sets the bit, and a re-applied chunk skips it. `PickupWorld.decorateChunk`'s extras (crates, the Speed Trap...) have no bits; they come from their own chunk seed.

## Applying chunks

`ChunkView` applies a recipe in stages, one piece per step, so neither a load nor an unload costs more than the frame's budget:

| Stage | Step |
|---|---|
| GROUND | the control block into the control ring; then 8 ground quads (1280 × 1280) and the chunk's `objects` node |
| BODY | one `StaticBody2D` (layer 1, mask 0) with a `ConvexPolygonShape2D` per piece and per field wall |
| OCCLUDE | one `LightOccluder2D` per step (open polygon, cull counter-clockwise, metadata `gc_world = true`) |
| LINES | one `Line2D` per step (width 128, the strip tiled) |
| DECOR | one `MultiMeshInstance2D` per decor id |
| PROPS | one prop per step: pooled for LOW/TALL/WALL, instanced with `BreakableProp` attached for STATEFUL ones and anything with a taken bit; variant texture; the occluder kept or dropped per the recipe; metadata `group` and `hero` set or cleared |
| PICKUPS | one pickup per step, from the skin's stock when it has one; taken ones and ones in a lot are skipped |
| EXTRAS | `PickupWorld.decorateChunk` (not in the start's chunk or a station's), each group of its props moved onto one of the recipe's `spots` (a group without a spot is dropped); then the pickup stock is topped up one pickup a step |

`TileManager.processViews` runs releases and then applies within `APPLY_BUDGET_USEC` (1500 µs; a step may run past it, about 2 ms in all), or `START_BUDGET_USEC` (10 ms) for the first 120 frames behind the countdown. At most 2 new views open a frame (`NEW_VIEWS_PER_FRAME`), nearest first; the queue is rebuilt every 0.2 s. A chunk that leaves the keep radius goes on the release queue, which hands nodes back to the pools a few at a time (`ChunkView.release`). The car's chunk is loaded urgently whenever the car enters it: its recipe is waited for if need be (the main thread never builds one itself during a run) and its GROUND and BODY stages run at once.

Draw order is the TileManager's layers: `groundLayer`, `edgeLayer`, `decorLayer`, `wallLayer` (bodies and occluders), `objectLayer` (props, pickups, stations).

**Pools** (`WorldSkin.POOL_CAP`): quad 200, body 16, occluder 160, line 160, MultiMesh 24 per decor id, prop 40 per id, shapes 600. A node given back to a full pool is freed. `prewarm()` loads two of each pooled prop, the level's pickup scenes and 24 quads before the run starts.

**Pickup stock** (`WorldSkin.PICKUP_STOCK`): ready-made pickups kept out of the tree, 14 coins and 2 of each other kind, so a chunk's pickup steps only add nodes to the tree. `takePickup` falls back to `Pickups.make` when the stock is empty.

`TileManager` prints `WORLD_BUILD` (seed, build ms, districts, crossings, skin and start-chunk times) when the map is ready and `WORLD_CHUNKS` (recipe and raster averages and maxima, waits, apply frames, over-budget frames, the longest step per stage) when the level exits.

## The ground shader

`shader/ground.gdshader` draws every ground quad with one shared `ShaderMaterial` (`WorldSkin.groundMaterial`).

- **Control ring** (`ctl`): an RGBA8 texture of 8 × 8 chunks of fine cells (320 × 160 texels, `WorldSkin.RING`), addressed by world cell modulo its size, nearest filtering. Each applied chunk blits its 40 × 20 block into its slot, and its apron into neighbouring slots that don't hold their own chunk yet, so seams next to an unloaded chunk still blend. `flush()` uploads the image once a frame when something was written.
- **Control texel** (`ChunkRecipe.controlBytes`):
  - R: the material layer of the cell's surface (`WorldSkin.layerOf`). Water and wall cells take a passable neighbour's layer by a few dilation passes, else the main ground.
  - G: the water field, B: the wall field, encoded `(f × 0.5 + 0.5) × 255` (`FIELD_RANGE` = 1 field unit either way of 0.5).
  - A: low 4 bits flags (1 bridge deck, 2 rotate the material 90°, 4 conveyor belt, 8 belt reversed); high 4 bits the district's tint code (0–15).
- **Materials** (`materials`): a `Texture2DArray` of the level's ground materials only: the main ground first, then base, accents, the landscape's own terrains (`Landscape.terrains`), water, shallows and the wall top (the skin's `roofMaterial`: `rock`, `roof` in the city), then wading depth (`wade`) last where the level has the band. Each terrain's material is the skin's (`Landscape.materialOf`: its `materials` map over `WorldSkin.MATERIAL_OF`). A tile covers 1024 world px. Without image data (headless) or with mismatched formats, flat placeholder colours are used.
- **Other uniforms:** `macro_noise`, `water_layer`, `wall_layer`, `wall_tint` (the skin's `wallTint`), `ctl_size`, `organic` (the skin's: how far borders wander: 0.2 city, 0.5 scrapyard, 0.7 highway, else 1), `water_glow` (lava: the landscape's `waterGlow` when its `waterLook` is `lava`, else 0; the deep water is mixed toward the glow colour by its alpha, hotter away from the shore, pulsing slowly above `gc_ground_quality` 0). `wade_layer` and `wade_depth` (`WorldGen.WADE_DEPTH` where the level has a wading band, else 0): water above −`wade_depth` is drawn with the `wade` material on a quicker, crossing chop, darkening slightly with depth, and blends into the deep water over ±0.05 field units at −`wade_depth` (still one water texture read a pixel, two only across that step). Lava is the WATER terrain, so it hurts like deep water; its shore foam strip takes the landscape's `waterFoam` colour (`WorldSkin.stripColors`). No new shader globals.
- **Drawing:** the fields are interpolated between cell centres, so water and wall edges are smooth and match the collision contours (the same values went through marching squares). Wall tops get a lighter lip and a contact shadow at their foot; deep water darkens with depth; the wading band is lighter and choppier, with the shore foam on its outer edge (the old water line) and no line where it turns deep; a bridge deck hides the water.
- **`gc_ground_quality`** (a global in `project.godot [shader_globals]`, set from the Ground Detail setting `gfx/ground`: Potato 0, others 1): 0 draws the nearest cell's material with no macro noise and no water or belt animation; 1 blends four cells with the blend warped by the macro noise (organic borders), adds macro brightness variation, moves the water and runs the belts at 250 px/s. `ShaderWarmup` compiles the ground, decor and beacon shaders behind the countdown.

## Collision, occluders and lines

- **Walls:** one `StaticBody2D` per chunk on layer 1 with convex pieces (from the wall field's contour, so it matches the drawn edge). Water has no collision: it hurts and drags by grid check instead (below).
- **Props** are `StaticBody2D` scenes on layer 1 with a convex hull (docs/WORLD_ART.md). `World.isWall` treats bodies, props and the station alike.
- **Occluders** run along wall edges facing open ground, solid on the right, one-sided. They carry `gc_world = true`, so at Lighting Low (`Settings.occluderVisible`) world occluders stay on while goon occluders go off.
- **Lines:** shore foam (`shore_foam`) on water edges, and the skin's wall strip (`Landscape.wallStrip`) on wall edges: `mesa_lip` (canyon), `snow_ridge` (mountain), `roof_edge` (city), `scrapwall` (scrapyard), else `cliff_lip`.

## Breakables and explosives

Baked STATEFUL props carry their state as metadata on the root (`smashSpeed`, `broken`, `debris`, `explosive`), and `ChunkView` attaches `scripts/world/breakable.gd` (`BreakableProp`) to them, which adds the `smashSpeed` property and `smash(car)`.

| Prop | Smash speed (px/s) | On smash |
|---|---|---|
| crate | 150 | 3 coins; Bandit bait |
| fence | 180 | 1 coin |
| haybale | 250 | 2 coins |
| hedge | 300 | |
| barricade | 350 | |
| barrel | 120 | explodes: radius 170 px, 8 car damage |
| tank | blast only (100000) | explodes: radius 320 px, 16 car damage |
| beehive | 100 | a swarm (Interactive props) |
| logpile | 350 | rolling logs (Interactive props) |
| billboard | 360 | topples (Interactive props) |
| watertower | 420 | a flood (Interactive props) |

- **The car** (`overhead_car_body_2d.gd`): a breakable hit at or above its smash speed is smashed with no wall damage, and the car keeps 85% of its speed (`BreakableProp.SPEED_KEEP`). Slower, it is a normal wall hit.
- **Smash** (`smashNode`): the broken sprite in place, collision and occluder off, a pooled 5-piece debris burst on tweens, coins spilled ahead of the car (collected the usual way, never credited from an animation), a dust puff, and the taken bit set.
- **Explosives** (`detonate`, `explode`): deferred, once per prop, through `GoonFx.blast` (car damage, goons flattened with crush credit, the pooled explosion). Every blast calls `blastAt`, which sets off other explosives in its radius with a clear line (`WorldHooks.lineClear`) 0.12 s later, so a chain spreads a hop at a time and each prop goes off once. Doomcart blasts and the Sidecar's bombs set barrels off too.
- **Goons:** `SpawnManager.onNodeAdded` tags props (`BreakableProp.tag`): `prop_log` (Snapper spawns), `prop_manhole` (Rat Pack spawns), `prop_crate` (the Bandit smashes one open and steals what spills), `prop_carcass` (Buzzard perches), `prop_explosive`.
- **The AI** plans through breakables it is fast enough to smash, and through standing cones above `PropReactions.KNOCK_SPEED`; explosives are always walls (docs/AI_DRIVER.md).

## Interactive props

`Spill` (`scripts/world/spill.gd`, package 14 P-4): props that let something loose when they go. `Spill.release(node, dir)` runs from `BreakableProp.smashNode` for every prop in `Spill.DEFS`, with the direction from the node's `spillDir` metadata (a goon or a blast sets it) or the car's travel.

| Prop | Where | Breaks at | What comes out |
|---|---|---|---|
| `logpile` | Prairie, Bayou, Frostbite (Wild, Tribe) | 350 px/s, a blast, or a goon | `LOGS` (5) logs roll 260-560 px along the release direction over 1.1 s, fanned ±0.55 rad: goons in their path are flattened (crushes for the player), the car takes 6 once and stops the log; each settles as an ordinary `log` prop (so Snappers can use it) |
| `watertower` | Prairie, Canyon, Quarry, Highway | 420 px/s or a blast | a flood flattens goons within 340 px in the clear ("SPLASH!") |
| `billboard` | City, Highway (Scrap) | 360 px/s or a blast | it topples away from the car (its broken sprite is the board flat on its +y side, flipped when the car came from that side) and flattens what is under it; the car takes 8 if it is there |
| `beehive` | Prairie, Bayou (Wild) | 100 px/s or a blast | a swarm hunts the nearest goon within 700 px for 12 s, flattening up to 8, and stings the car (1.5 every 0.4 s) when it is close |
| `crane` | Quarry, Crusher | rammed at `DROP_SPEED` (320 px/s) or a blast, once | the container falls off the jib's tip over 0.7 s, flattens goons under it, hits the car for 10 if it is there, and stays as a `container` prop |


**Region 1 (The Wilds).** The same hook, plus `arm`/`disarm` (called by `PropReactions.addHero` when a prop streams in and when its chunk goes, to restore per-prop state):

| Prop | Where | What it does |
|---|---|---|
| `rockpile` | Red Canyon (`pass`) | a rockslide: `ROCKS` (4) spinning `rock_roll` boulders, rolled like logs and credited as rocks ("ROCKSLIDE!") |
| `tnt` | Red Canyon (`pass`) | an explosive (`BreakableProp.BLAST`, 190 px, 8 damage) |
| `still` | Snapper Bayou (`bank`) | an explosive (220 px) that leaves fire behind (`BreakableProp.BURNS`, 90 px for 6 s) |
| `saguaro` (hero ones) | Red Canyon | topples at `SAGUARO_SMASH` (380 px/s) away from what broke it, 6 damage; its spines flatten rank-1 goons (`SPINE_RANK`) |
| `ranger_tower` | Moose Woods (`track`) | topples across the track, 10 damage ("TIMBER!") |
| `fallen_trunk` (variant 2, leaning) | Moose Woods (`track`) | a deadfall: drops flat across the trail, 8 damage ("DEADFALL!"); the other variants just break |
| `sluice` | Snapper Bayou (`ford`) | a flood capsule `FLOOD_LENGTH` (900 px) × `FLOOD_RADIUS` (170 px) along the nearest channel flattens goons in the shallows and on bridges ("SPLASH") |
| `pumpkin` | Orchard Lanes | bursts in orange bits and keeps the car's speed |
| `oak` (apples) | Orchard Lanes (`rules.oakCoins`) | its first hit at `OAK_SHAKE` (200 px/s) drops that many coins, once a run |
| `den` | Prairie, Orchard (rare) | Bandits carry stolen pickups home to it; smashing it bursts them all out ("LOOT RECOVERED"); the stash survives a chunk reload |
| `burrow` | warrens (a motif) | caves in: the hiding Jackalope is thrown out stunned and spawns no more; the last burrow of its warren: "WARREN CLEARED" |
| `bell` (Dinner Bell) | Prairie, Orchard (`track`) | rammed at `BELL_RAM` (150 px/s) it calls every goon within `BELL_LURE` (1200 px) for `BELL_SECONDS` (6 s), once a run |
| `saltlick` | Moose Woods (`clearing`) | a permanent lure (`SALT_LURE` 900 px) for heavies only (`SALT_RANK` 3) while its chunk is loaded; a heavy lets go once the car is within `SALT_LOOSE` (500 px). Goons below a lure's rank never read it, and with only permanent lures out a heavy looks every `Pickups.LURE_POLL` (8) ticks (`Pickups.lureCheckDue`) |

Roosts (`Spill.ROOSTS`): dead trees and scarecrows hold Buzzards; a ram on the trunk knocks them down stunned.

- **Goons cut log piles loose.** Goons with `"releases": true` in `Goons.DATA` (Grunt, Yipper, Splitter) check every 0.5 s in their move state (`GoonVerbs.Verb.seekRelease`): with the car within `LURE_CAR` (900 px) of a pile that is within `LURE_GOON` (650 px) of the goon, it runs to the pile and, within `REACH`, cuts it loose aimed at the car ("TIMBER!"), then goes back to its own business.
- **Blasts** (`BreakableProp.blastAt`) set off spilling props in their radius with a clear line: piles burst away from the blast, cranes drop their container.
- **Groups:** `prop_logpile` (goons look for piles), `prop_spill` (blasts).
- **What spilled is kept.** Logs and containers that come to rest are recorded on the TileManager (`addSpilled`, per chunk, chunk-local) and go into the chunk they landed in; a re-applied chunk puts them back (`ChunkView.applyExtras`). A crane that dropped its container is marked (`markSpillUsed`) and `ChunkView` sets its `spilled` metadata, so it never drops another.
- **Loading:** `WorldSkin.dressingIds` adds `Spill.PRODUCTS` (a log pile's logs, the crane's container) for any spilling prop the level uses; `Spill.productScene` falls back to the manifest's scene.

## Prop reactions

`PropReactions` (`scripts/world/prop_reactions.gd`, package 14): one node per run, made by the TileManager after the skin (`TileManager.reactions`, `PropReactions.current`), pausable. Show only, except cones.

- **Canopies.** A layered prop (trees and the crane, docs/WORLD_ART.md "Layered props") has a `Canopy` sprite at absolute z `CANOPY_Z` (8: over goons, at most 6, and the car; under the station roof, 20). `ChunkView.applyProp` gives it the variant's canopy texture (`WorldSkin.canopies`) and registers it (`addCanopy`); `release` forgets it. Each frame the canopy fades toward `FADE_ALPHA` (0.4) while the player's car is inside its shape grown by `UNDER_PAD` (34 px), else back to 1, at `FADE_RATE` a second. The shape is the canopy texture's opaque rect (read once per texture): the ellipse inside it for trees, the box for the crane (`SQUARE_CANOPIES`). It never fades for goons, so crowns can hide goons beneath them (by choice).
- **Hits.** `collideWithFixedObject` in the car calls `PropReactions.hit(collider, moving, point)` on a fresh wall hit (not a scrape). `REACT` gives each prop id a kind: CANOPY (the crown springs, leaves fall), SWAY, WOBBLE (rotation springs), SHAKE (a positional rattle), SQUASH (scale across the hit), THUD (dust only), SPRAY (a hydrant: wobble and about 2 s of droplets), KNOCK (cones). Nothing reacts below `MIN_SPEED` (60 px/s); the size grows to `FULL_SPEED` (520). Breakables react only below their smash speed. Springs are `[amplitude, Hz, decay]` in `SPRING`, on the prop's existing sprites, and put back exactly at rest when they settle.
- **Cones** (`knocks`, checked by the car before the wall branch): hit at `KNOCK_SPEED` (120 px/s) or more, a cone's sprite flies 140-230 px along the hit and its collision goes off; the car keeps `KNOCK_KEEP` (96%) of its speed and takes no wall damage. Cones have no taken bit: a reloaded chunk stands them up again (`reset`, called by `ChunkView` on every pooled prop).
- **Blasts:** `BreakableProp.blastAt` calls `PropReactions.blast`, which shakes the crowns in the radius and drops a few leaves.
- **Near misses:** a breakable hit too slow to smash wobbles by speed ÷ smash speed instead of by `FULL_SPEED`; at `NEAR_SMASH` (70%) or more it cracks (the "rattle" sound, pitched up) and throws 2-5 chips off its debris strip, so the player learns how close they were.
- **Bits:** leaves from each layered prop's baked `<id>_leaves.png` strip (`WorldSkin.leaves`; pine drops snow clumps on a snowy landscape, `Landscape.snowy`, which also turns hit dust to snow), drawn by one `Bits` node (72 pooled), and dust and spray through a `CarJuice.Particles` (96). Driving Effects (`gfx/driving_fx`) scales them by `PARTICLE_SCALE` (none at Minimal); Reduce Motion cuts the springs to 40%.

## Water

From the bank in: **shallows** (256 px, field 0.4 to 0), **wading depth** (WADE, 224 px, field 0 to −0.35), then **deep water** (WATER). The city's canals and the volcano's lava have neither band: deep water starts at the edge.

- **Shallows** ring every deep-water body (except the city's canals): passable, slow (friction 0.45, grip 0.7), not spawnable, harmless. Fords cut through creeks are shallows too.
- **Wading depth** (WADE) is deep water's outer band where the level has one (`WorldField.wade`, "The fine raster"): passable, very draggy and slippery (friction 0.75, grip 0.45, brake 0.6), not spawnable, route weight 2.5. It costs the car about 2 health a second before armor (`hurt`). The car throws spray from all four tyres and a bow wave off the nose at speed (CarJuice, docs/CAR_ART.md "Driving feel", Water).
- **Water and the car.** Deep water no longer wrecks the car on contact. Once a physics tick `OverheadCarBody2D.checkGround` takes `World.hurt(surface)` health per second (WATER 33, WADE 2) through `damage()` (`soak`), so armor counts once; shields and golden rides don't keep the water out (they block hits, not the river), but an airborne car (Hop, Jump Jets) is out of it. The drag and lost grip come from the same rows inside `integrate()` (WATER: friction 0.9, grip 0.3, brake 0.5), so the AI's predictions see them; Off-Road and Low Clearance don't change deep water (`groundFriction`, `surfaceGrip`). Measured on a stock sedan (armor 0) flat out from grass: 300 px of deep water costs about 16 health, 400 px 22, 500 px 29 (it goes in at about 745 px/s); with a 224 px wading band either side, 300 px costs about 20; parked in deep water it is wrecked in about 3.0 s (`test_water.gd` prints these). A wreck with the car's centre over deep water (`deepTicks` > 0) is a drowning (`drowned`): the results say WRECKED as before, the playtest `WATER`. The Defibrillator can save a drowning car once (back to 30 health: about a second to get out). The HUD shows "DEEP WATER" and a red edge while the car's centre is over it (docs/HUD.md), and the car settles in (docs/CAR_ART.md "Driving feel", Water). The playtest counts the water's damage as `damage_water`.
- **Bridges** are BRIDGE cells over water (bayou boardwalks, city streets over canals): passable, fast, not lethal; the shader hides the water and shore foam stops at the deck.
- **The ocean** fills the map's outer 2 coarse cells (with a wading band inside its edge, like any deep water).
- **Goons:** a solid goon over a lethal cell (deep water, not wading depth) drowns (checked every 4 ticks, staggered by instance id; buried, hopping, flying and riding goons are immune until they land). A drowning within 3 s of the car touching the goon counts as a crush with a "SPLASH" label (`WorldHooks.drownCredited`, `SpawnManager.creditCrush`, also counted per goon for the Goonopedia). A drowned Bandit's loot washes up on the nearest dry cell past the wading band (`WorldHooks.bankNear`). Off-screen goons treat water as blocked (`slideStep`), so none drowns unseen. In wading depth a solid goon is slowed to `WorldHooks.WADE_SLOW` (0.6) of its speed through the buff scale, like slime (`Walker.checkWade` every `WADE_EVERY` ticks, held `WADE_HOLD` s; a stronger slow is kept), and never drowns.
- **Tethers:** harpoon and magnet tethers snap when the car is within 400 px of deep water (`WorldHooks.tetherMustBreak`; wading depth doesn't count). Oil and slime are never laid on shallows, wading depth or within a fine cell of deep water (`hazardAllowed`).
- **The AI** never plans through deep water (its centre over it ends a plan at `LETHAL_COST`) and keeps goals away from it; it may drive through wading depth, at its route weight and `WADE_COST` (docs/AI_DRIVER.md).
- **Lava** (the volcano) is the WATER terrain, so it hurts like deep water; its landscape opts out of the wading band.

## The wall contact model

In `overhead_car_body_2d.gd` (`wallTick`, `wallContact`, `wallDamage`):

- **Impact:** `|normal · direction of travel|`, clamped to 0.15–1 (`wallImpact`). Every contact tick keeps `lerp(1, 0.85, impact)` of the velocity.
- **Hit:** meeting a wall with none touched in the last 10 ticks (`WALL_CONTACT_GAP_TICKS`), or driving into it again at 150 px/s or more along its normal (`WALL_REHIT_SPEED`), costs `0.012 × speed before the slide × impact` health (`WALL_DAMAGE_PER_SPEED`; armor is applied in `damage()`, docs/CAR_ART.md, "Health damage"). Two pieces of one wall in the same tick are one hit.
- **Scrape:** staying against a wall costs at most every 15 ticks (`WALL_SCRAPE_TICKS`) `min(0.012 × speed × 0.15, 0.3)` (`WALL_SCRAPE_MAX`), about 1.2 health a second for a car with no armor.
- Zone wear follows the damage (`zoneForHit`, a 30-tick cooldown per system). `wallHealthLost` sums what walls took (the playtest's `damage_rocks`).

## Goon and FX hooks

`WorldHooks` (static, pure grid reads, so 250 goons and the planner can call it every tick; with no map every rule is a no-op):

| Function | Used by | Rule |
|---|---|---|
| `slideStep(pos, step)` | `GoonBody.advance` off screen | the whole step if open, else along the open axis, else hold; a goon already on blocked ground may step anywhere |
| `drownCredited(now, lastTouch)` | `Walker.drown` | within 3 s of the car's touch |
| `bankNear(pos)` | the Bandit's loot | the nearest dry, open point within 6 fine cells, past the wading band |
| `wadeScaleAt(pos)` | `Walker.checkWade` | `WADE_SLOW` (0.6) in wading depth, else 1 |
| `nearLethal(pos, r)`, `lethalAhead(pos, dir, dist)` | tethers, the AI | 17 samples round a point; samples every 128 px along a heading |
| `tetherMustBreak(carPos)` | `GoonFx` tethers | deep water within 400 px |
| `hazardAllowed(pos)` | `GoonFx.hazard` | not shallows, wading depth, water or wall, and no deep water within a fine cell |
| `wallAt(pos)`, `lineClear(a, b)` | shots, lobs, blasts, chains | wall cells stop shots and shelter from blasts (samples every 64 px); water stops nothing |
| `bounce(pos, vel, delta)` | the kicked shell | reflects the blocked axis |
| `nearestInGroup(tree, group, pos, maxDist)` | spawns, Bandit, Buzzard | the nearest tagged prop |

Spawning, props and FX rules for goons are in docs/GOONS.md ("The world").

## Determinism

- Every random stream in the world is `WorldGen.ihash(seed, tag, a, b)`, an integer mixer (`hashf` gives a float in [0, 1)). Tags: `WorldGen` 1–14 (run, share, district, lane, sprint, leg, spawner, faction, name, tint, goons, giant, ford, slot), `WorldField` 101–111 (noise seeds, pieces, mud pits, branches, gas stations, lattice, canals, blocks, segments, plots), `ChunkRecipe` 201–217 (recipe, pickup, prop, decor, spot, roof; 207-211 field lines: region angle and edge kinds, gates, corner oaks, their turn, paddock bales; 212 motifs; 213 heroes, 214 motif group keys, 215 edge props, 216 hedgerow gates, 217 the Home Paddock's group). `FastNoiseLite` seeds come from `ihash` too.
- A seed rebuilds the same map, districts, stations, lanes and recipes. The worker threads don't change that: each job reads only its own input.
- `TileManager.worldSeed` is −1 (rolls `randi()`) unless set: the playtest sets `--seed` (run *k* uses seed + *k*), the bench defaults to 1337 (`--seed=N` to change).
- Spawners get their own RNG from `WorldMap.nextSpawnerSeed()` (seed and a counter). `PickupWorld.decorateChunk` uses `TileManager.chunkRng` (Godot's `hash([seed, x, y])`).
- Still on the global RNG: which goon spawns and whether it is a giant, drops, and the goons' own behaviour. A daily seeded run would need those moved too.

## Debugging tools

- **World preview** (`scripts/debug/world_preview.gd`, through the playtest harness, which quits afterwards):
  ```
  Godot_console.exe --headless --path . -- --playtest --world-preview --level=prairie,city --seeds=1,2 --objective=sprint
  ```
  Prints each map's build timings (sample, rules, districts, A*), blocked and reachable shares, district and crossing counts, the station and its route, the start district's zone, faction and goons, and an ASCII crop (`--w=80 --h=30` coarse cells) using `World.TERRAIN` letters, `+` for a pass, `S` start, `X` station, `M` a Defense lane mouth, `.` the route. `--level=all`, `--objective=defense`, `--fine=N` times N fine rasters round the start. `--probe=x,y` prints the coarse cells (letter and flag byte) and the fine map round a world point. `-- --landscape=<id>` (with any harness) builds every level in that landscape (`Landscapes.forcedId`): its generator, default world and skin, on the level's own numbers and region.
- **Bench** (`scripts/debug/bench.gd`): `--level=<id|index|old name|path>`, `--seed=N`, `--pattern=none|sine|circle|route`, `--at=water|wall|x,y` (moves the car beside the nearest deep water or wall, or to a point, once the world is ready), `--zoom=0.4` (holds the camera zoom), with `--shot` to look at edges. The CSV has `chunk_ms` (main-thread apply time per frame) and `occluders` columns.
- **Playtest** (`--trace`): `PLAYTEST_MAP` (the coarse map round the start and the station), `PLAYTEST_HIT` (wall hits with what was hit: the body's name and parent, its layer and the point), `PLAYTEST_STUCK` (stuck events with `near=` (prop ids or `wall` within 320 px), `water=` (deep water within 400 px), `ground=` (the terrain letter under the car), keys, acceleration, slide count, forward speed, buffs and `overlap=` (what the car's front and rear polygons overlap)). Every drowning (a wreck over deep water, `car.drowned`) prints `PLAYTEST_WATER` and a 9 × 9 `PLAYTEST_WATER_MAP` of fine cells round the car. Defense runs print `PLAYTEST_DEFENSE` every 10 s (barrier, goons marching, blown up at the pumps so far, near and wedged).
- **Logs:** `WORLD_BUILD` and `WORLD_CHUNKS` (above).

## How to add a level

1. Make `world/levels/<id>.tres` (a `LevelDef`; copy a level of the same region). Set the menu text (`displayName`, `blurb`, `barrier`, `surfaces`), `region`, `stop`, `order` (its index), the clock and spawn tuning on the region's curve, `rules`, `lineup` (3-6 of the region's class), `landscape`, `pickupTable` and `pickupsPerChunk`. Leave `grammar`, `features`, `baseTerrain` and `accents` empty to take the landscape's, or set them to tune this level's world; `dressing` and `motifs` only for props this level adds or drops.
2. Put the id in `Levels.ORDER` at its stop. Regions are five stops each (`Territories.STOPS`, `levelsOf`); appending is save-safe, reordering moves unlocks (`SaveManager.migrate()` matches saved entries by id, but unlocks advance by index).
3. Make `scene/level/levels/level_<id>.tscn`: inherit `levelRoot.tscn` and set only `def`.
4. Point `poster` at an existing poster, or add one to `POSTER` in `scripts/art/world_gen.js` and bake it (`python scripts/art/bake_world.py poster --only <id>`; docs/WORLD_ART.md).
5. Update `IDS` in `tests/game/test_levels.gd` and the table above, then run the suite (`test_levels.gd` checks the curve by region and the line-up against the class). Preview it with `--world-preview`, and playtest it.

## How to add a landscape

1. Make `world/landscapes/<id>.tres` (a `Landscape`; copy the one whose generator it re-skins). Set `grammar` and its default `features`, `baseTerrain` and `accents`, `terrains` (what the generator adds), the skin (`materials`, `roofMaterial`, `wallStrip`, `wallTint`, `organic`, `roofDecor`), the water look, natural `dressing` and `motifs` (only ids already in `props.json`), ten `nameSecond` words, `text` and a `fallback` whose art is all there.
2. Add the id to `Landscapes.ORDER` and point levels at it (`LevelDef.landscape`).
3. Its new ground materials and strips go in `scripts/art/world_gen.js` and the bake (docs/WORLD_ART.md); until all of them exist the level is drawn with the fallback's skin. A new generator grammar also needs its fields in `WorldField` (a `Grammar` value, `GRAMMARS`, a `sample` branch), any post-pass in `WorldGen.grammarPost` and `Level.ROUTE_FACTOR`.
4. Run `test_landscapes.gd` and `test_world_art.gd`; preview it on any level with `-- --landscape=<id> --world-preview`.

## How to add a region

1. Add an entry to `Territories.DATA` and its id to `Territories.ORDER`: name, colour, class (a `Goons.CLASSES` id, or a new class there), landmark (a prop with a beacon, also in `WorldSkin.LANDMARKS`), ten `nameFirst` words, three zones of `dressing` and `motifs`, the strength `step` and `demo`.
2. Add its five levels to `Levels.ORDER` (How to add a level). The Sprint distance spreads over `Territories.ORDER` by itself.
3. Update `test_levels.gd` (`IDS`, the regions test) and the tables in this file and docs/GOONS.md.

## How to add a prop

1. Draw it in `PROPS` in `scripts/art/world_gen.js` and bake it (docs/WORLD_ART.md, "Adding a prop"); `props.json` gets its class, size, hull, occluder, breakable state and scene.
2. Add it to a landscape's `dressing` (natural props), a region's `dressing[zone]` in `Territories` (its own props) or a level's `dressing` (one level), with a weight. DECOR ids become decor automatically. `test_landscapes.gd` and `test_world_art.gd` check every named id is in `props.json`.
3. If it may stand on roads, add it to `WorldSkin.ROAD_PROPS`; if it is laid in chains, to `CHAIN_PROPS`; a decor with a placement rule goes in `DECOR_PLACE`.
4. A breakable needs `smashSpeed` (and optionally coins in `BreakableProp.COIN_SPILL`); an explosive a blast in `BreakableProp.BLAST`; a prop goons look for a group in `BreakableProp.GROUPS`.
5. Give it a reaction in `PropReactions.REACT` (a prop without one is a plain wall when hit). Anything the car can pass under gets a `canopy` drawing (docs/WORLD_ART.md, "Layered props").
6. Run `test_world_art.gd`, `test_world_recipe.gd` (budgets) and `test_prop_reactions.gd`.

## How to add a terrain value

`Root.terrain` is append-only. Add the value at the end and update every mirror:

1. `Root.terrain` (`scripts/global/root.gd`) and `Goons.T` (`scripts/global/goons.gd`), in the same order.
2. A row in `World.TERRAIN` (`scripts/world/world.gd`) with every column, including a unique `letter`.
3. The constant in `WorldField` (and in `PLAIN_SURFACES` if accent noise may sprinkle it); in `WorldGen` or `ChunkRecipe` only if their code needs it.
4. The material name in `WorldSkin.MATERIAL_OF` (by id), and in a landscape's `terrains` if its generator produces it outside `baseTerrain`/`accents`.
5. A ground material in `GROUND` (`scripts/art/world_gen.js`), baked into `world/art/ground/<name>.png`, and the name in `GROUNDS` in `tests/game/test_world_art.gd`.
6. The letter in the legends of `world_preview.gd` and `playtest.gd` (`printMap`).
7. Optionally a name list in `Region.names` (only for regions made without a map) and `goonopedia.gd`'s `TERRAIN_NAMES` if goons get it as a biome.

`test_world.gd` and `test_goons.gd` fail when the enum, the table and `Goons.T` disagree.

The native `WorldGrid` (native/src/world_grid.cpp) needs no change for a new value: it answers from the terrain ids it mirrors and `World._flags`, which `WorldMap.setupGrid` hands it. Only a change to a query's rule goes in both. WADE (19, the last added) followed these steps; the raster's rule for it is in `WorldGen.fineRaster` ("The fine raster").

## Tests

| File | Covers |
|---|---|
| `test_world.gd` | the terrain table and mirrors, the queries' delegation, surface handling in `integrate()`, the off-road rule, wall impacts and the contact model, deep water hurting the car per tick, `gc_world` occluders at Lighting Low |
| `test_terrain.gd` | the map's shape: 96 × 96 chunks, the coarse grid, districts per passable cell, fine rasters, chunk summaries |
| `test_world_gen.gd` | every distinct world (`GameTest.worldLevels`: levels that share a world are built once) over 5 seeds: determinism, the start bubble and a non-lethal start, reachable stations, routes never shorter than the straight line, crossing spacing, fine/coarse agreement, district zones, line-up goons and exits, names from the region and landscape, share caps, Defense lanes |
| `test_world_recipe.gd` | every distinct world over 3 seeds and a sample of chunks: budgets, convex in-chunk pieces that agree with the wall field, short occluders and lines, props and pickups on open ground away from the start and the lot, same input same recipe, the applied node budget, collected pickups staying gone |
| `test_world_hooks.gd` | `slideStep`, drowning and its credit, tethers and hazards near water, shells and shots against walls, breakables and explosives, prop groups, the AI's water margin |
| `test_water.gd` | water and the car: the WADE and WATER rows, a stock sedan crossing 300-500 px of deep water flat out (survives; prints the health lost), the wading band's extra cost, a parked car drowning in about 3 s, shields vs hops, the Defibrillator, armor, drag and traits, `integrate()` staying pure, wading damage and grip, goons drowning and wading, hazards and loot off the band, the raster's band on prairie and bayou and none on city canals or lava, and native/GDScript parity on WADE |
| `test_levels.gd` | the registry (30 levels, 6 regions of 5 stops), defs, thin scenes, the curve by region, line-ups within their class and covering it, the classes, the strength step, Sprint distance by region |
| `test_landscapes.gd` | the 15 landscapes and their data, today's eight drawn exactly as before the move (layers, water and wall layers, tints, borders, strips, roof decor), the fallback skin for missing art, lava, forced landscapes, region props rising with distance, region landmarks and district names |
| `test_world_art.gd` | the baked art and manifest (docs/WORLD_ART.md) |
| `test_prop_reactions.gd` | canopies over the car and their fade, the crane's box, reactions by kind settling at rest, bits off at Minimal, hydrant spray, knocked cones and their reset, blasts, forget, the AI and cones, near-miss cracks, decor bending |
| `test_prop_layout.gd` | field lines square to their lattice and off roads, road barriers along the road, motif clusters, level motif and hero tables and dead keys, the skin loading motif members and spill leftovers; Region 1: heroes first, on their anchors and kept by the budget, motif groups and the view's `group`/`hero` metadata, the Home Paddock and its track, Orchard Lanes' hedgerow walls and gates, Snapper Bayou's mixed crossings, Red Canyon's slot canyons and their coin lines, Moose Woods' thickets, crowns, lips and edge pines |
| `test_spill.gd` | log piles (rolling logs flatten goons and settle), water towers, billboards toppling away from the car, hives, the crane's one drop, goons cutting piles loose, blasts setting spills off, the TileManager's record |
| `test_save_migration.gd` | `SAVE_VERSION` 8 (older saves start over): levels rebuilt from the registry, car clears |

## Known issues

- **Worker speed:** the map build takes 0.8–1.3 s on the HD 620 box (seed 1337; crossings run natively since 2026-10-07, which saved 0.5–0.7 s) and a recipe about 7–12 ms, the rest GDScript. The apply side stays inside its budget. `WorldField.sample` (280–620 ms of the build) is the next port (docs/NATIVE.md, "What to port next").
- **Highway edges** look blobby: the asphalt edge comes from the 128 px raster through organic blending.
- **Bumper-only car collision:** the car's shape is a front and a rear polygon, so its middle can wedge on prop and wall corners (`overlap=` in `PLAYTEST_STUCK`).
- **Unused def fields:** `nightTint`, `ambience`, and `sideStreetChance` in City's `features`.
- **Placeholder content:** the 22 new levels start from their landscape's template level (barrier and surfaces text; their posters are their own) (docs/GAMEPLAY_SUGGESTIONS.md, road atlas P6). The new props' dressing weights are first guesses.
- **Lava at night:** the glow is part of the ground, so the night's `CanvasModulate` darkens it like any ground; it does not light the scene.
- **Giantism** is per district but only shown on the HUD.
- **Marathon's later stations** are found on the finished map, so their lot's terrain isn't cleared (props and pickups are kept out); a chunk with a naturally clear lot is preferred.
- **No first-run hints** explain deep water or breakables.
