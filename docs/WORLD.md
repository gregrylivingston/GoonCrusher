# The world

Each of the 8 levels has its own generator grammar, signature barrier and surfaces. The map is built once per run on a worker thread, chunks are turned into "recipes" on worker threads, and the main thread only applies recipes a few nodes at a time. There are no TileMaps: the ground is drawn by one shader, walls are convex collision pieces traced from a field, and props are generated scenes. The art is in `docs/WORLD_ART.md`; the AI driver's view of the world is in `docs/AI_DRIVER.md`.

## Files

| Path | What |
|---|---|
| `scripts/world/world.gd` | `World`: the terrain table (`TERRAIN`) and the static runtime queries. Static only. |
| `scripts/world/level_def.gd` | `LevelDef`: one level (menu text, clock, spawn tuning, faction band, roster, generator parameters, dressing, pickups). |
| `scripts/world/levels.gd` | `Levels`: the registry (`ORDER`), id/index/legacy-name resolution, the save's default level entries, `GRAMMAR_TEXT`. |
| `scripts/world/level_roster.gd` | `LevelRoster`: faction scores clamped to a level's band, validated rosters, a district's three goons. |
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
| `world/levels/<id>.tres` | The 8 `LevelDef`s. **Edit level numbers here.** |
| `scene/level/levels/level_<id>.tscn` | Thin scenes that inherit `levelRoot.tscn` and only set `def`. |
| `world/art/` | Baked world art and `props.json` (docs/WORLD_ART.md). |
| `scripts/debug/world_preview.gd` | `WorldPreview`: prints a level's map as text. |

## Overview and data flow

1. **Level start.** `Level._enter_tree` calls `applyDef()`, which copies `seconds`, `spawnTimer`, `giantOdds` and `escalationSpeed` from the def before any child is ready. `Level._ready` places the car at `def.startPosition`.
2. **Coarse build (worker).** `TileManager.buildWorld` picks the seed (`worldSeed`, `randi()` unless a harness set it), works out the objective (`"sprint"` for Sprint and Marathon with an offset from `Level.sprintOffsetPx`, `"defense"`, or none) and makes the job with `WorldMap.jobFor` on the main thread: a deep-copied `LevelDef.snapshot()`, the level's main terrain (`"_main"`) and the route weights from `World.TERRAIN`. `WorldGen.buildCoarse` runs on a `WorkerThreadPool` task while the main thread awaits frames.
3. **WorldMap.** `WorldMap.fromJob` wraps the result and decides each district's faction, goons, name, tint, giantism and landmark (`setupDistricts`, main thread, seeded per district). The map becomes `Root.worldMap`, and `Region.setDistricts` turns the districts into the run's regions.
4. **Skin.** `WorldSkin.new(def)` loads the level's materials into a `Texture2DArray`, the strips, decor atlases and prop scenes, and `prewarm()` fills the pools and the pickup stock. `recipeContext(lots, lanes)` turns the level's tables into plain dictionaries for the workers.
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
| Map edge | the outer 2 coarse cells (2560 px) are ocean (lethal water) | `WorldGen.EDGE_CELLS`, `WorldField.EDGE_PX` |
| Objectives | stay within 45 chunks of the centre on each axis | `WorldGen.CHUNK_LIMIT` |
| Keep radius | chunks more than 2 away (Chebyshev) unload, except pinned ones | `TileManager.KEEP_RADIUS` |
| Prefetch | views for what the camera sees plus 1 s of travel; rasters and recipes 1.5 s ahead | `PREFETCH_SECONDS`, `RASTER_PREFETCH_SECONDS` |
| Raster/recipe cache | 24 chunks (the car's 3 × 3 is never evicted) | `WorldMap.LRU`, `setKeep` |
| Start bubble | no barrier within 2500 px of the start; the start's coarse cells are cleared and reserved within 2500 + 1920 px | `WorldField.START_CLEAR`, `WorldGen.startBubble` |
| Shallows band | 256 px (field 0.4) round deep water | `WorldGen.BAND` |
| District seeds | every 32 coarse cells (about 41,000 px), jittered by up to 8 cells | `DISTRICT_STEP`, `DISTRICT_JITTER` |

## The terrain table

`Root.terrain` is append-only, and `World.TERRAIN` has one row per value in the same order (`Goons.T` mirrors the enum too; `test_world.gd` and `test_goons.gd` check all three agree). Friction is on the car's scale; grip multiplies the car's grip after `gripFor`'s clamp; brake multiplies the brake force; push is a conveyor's speed in px/s.

| id | Name | Letter | Friction | Grip | Brake | Push | Passable | Lethal | Wall | Route weight | Spawnable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | GRASS | g | 0.13 | 1.0 | 1.0 | | yes | | | 1.0 | yes |
| 1 | SAND | s | 0.5 | 0.9 | 1.0 | | yes | | | 1.4 | yes |
| 2 | MUD | m | 0.6 | 0.8 | 1.0 | | yes | | | 1.4 | yes |
| 3 | WATER (deep) | ~ | | | | | no | yes | | 0 | no |
| 4 | HILLS (rock, cliff, mountain, scrap) | ^ | | | | | no | | yes | 0 | no |
| 5 | MOSS | o | 0.08 | 1.0 | 1.0 | | yes | | | 1.0 | yes |
| 6 | DIRT | d | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes |
| 7 | SNOW | * | 0.3 | 0.85 | 1.0 | | yes | | | 1.2 | yes |
| 8 | ASPHALT | = | 0.02 | 1.1 | 1.0 | | yes | | | 1.0 | yes |
| 9 | ICE | i | 0.05 | 0.35 | 0.5 | | yes | | | 1.3 | yes |
| 10 | OIL | % | 0.03 | 0.25 | 0.4 | | yes | | | 1.3 | yes |
| 11 | SHALLOWS | - | 0.45 | 0.7 | 1.0 | | yes | | | 1.4 | **no** |
| 12 | WASH | w | 0.02 | 0.9 | 1.0 | | yes | | | 1.0 | yes |
| 13 | CONVEYOR | > | 0.03 | 1.0 | 1.0 | 250 | yes | | | 1.0 | yes |
| 14 | MUDPIT | @ | 1.0 | 0.7 | 1.0 | | yes | | | 2.0 | yes |
| 15 | DEEPSNOW | # | 0.6 | 0.8 | 1.0 | | yes | | | 1.4 | yes |
| 16 | LOT | l | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes |
| 17 | BUILDING | B | | | | | no | | yes | 0 | no |
| 18 | BRIDGE (deck over water) | b | 0.03 | 1.0 | 1.0 | | yes | | | 1.0 | yes |

**Off-road rule** (`World.effectiveFriction`): friction above grass is softened by armor, so heavy cars plough through: `f_eff = 0.13 + (f − 0.13) × (1 − clamp(armor / 200, 0, 0.35))`.

### The World API

Table lookups: `count()`, `def(t)`, `isPassable(t)`, `isLethal(t)`, `isWallTerrain(t)`, `isSpawnable(t)`, `isBlocked(t)` (not passable: water or wall), `friction(t)`, `grip(t)`, `brake(t)`, `push(t)`, `routeWeight(t)`, `letter(t)`, `effectiveFriction(f, armor)`, `isWall(collider)` (`is StaticBody2D || is TileMap`: chunk wall bodies, props and the station are all `StaticBody2D`).

Runtime queries, delegated to `Root.worldMap`: `terrainAt(pos)`, `surfaceAt(pos)` (the ground the car drives on; the same as `terrainAt` today), `lethalAt(pos)`, `blockedAt(pos)`, `spawnableAt(pos)`, `pushAt(pos, t)` (the conveyor push as a vector, `WorldMap.beltDirAt`).

- **Hot path, allocation-free:** the runtime queries and the flag/friction/grip/brake/push lookups. The car calls them every physics tick and the AI ~900 times per plan through `integrate()`. The flag and number columns are flat packed arrays built once in `_static_init`. A real map answers them natively: `WorldMap.grid` (a `WorldGrid`, docs/NATIVE.md) mirrors the coarse map and every stored raster (`store`, eviction and `forget` keep it in step), and Root's `worldMap` setter makes it `World.grid`, so `World.terrainAt` is one native call. The GDScript `WorldMap.terrainAt` is the same rule (the last chunk's raster cached in `_cx/_cy/_fine`, else the coarse cell), kept for tools and the parity test; stand-in maps in tests go through it.
- **Not hot:** `def(t)`, `routeWeight(t)` and `letter(t)` return or read a Dictionary row. Use them in setup code and tools only.
- **No map** (`Root.worldMap == null`: the menu, most tests, the first frames of a run): the queries answer `UNKNOWN` (−1); nothing is lethal or blocked, nothing is spawnable, and the car keeps its own `friction`. Tests can put a stand-in object in `Root.worldMap` that provides `terrainAt`, `surfaceAt`, `lethalAt`, `blockedAt`, `spawnableAt` and optionally `beltDirAt`.

Worker code (`WorldGen`, `WorldField`, `ChunkRecipe`) never touches autoloads, so it keeps its own copies of the terrain ids as constants, and reads table columns from the job (`weights`, `ctx.blocked`, `ctx.spawnable`).

## The levels

Each level is a `LevelDef` in `world/levels/<id>.tres`, listed in order by `Levels.ORDER`. The demo offers the first `Root.DEMO_LEVEL_COUNT` (3). The faction band decides which factions can hold land (below 1.0 Wild, below 2.2 Tribe, else Scrap; the band's top is exclusive).

| # | id | Name | Act | Grammar | Clock | Signature barrier | Surfaces | Faction band | Demo |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `prairie` | Prairie Run | 1 | meadow | 250 s | a creek with deep pools; fords every chunk | grass, moss, dirt tracks, shallows | 0.0–1.4 (Wild, Tribe) | yes |
| 2 | `bayou` | Snapper Bayou | 1 | bayou | 300 s | lakes and braided channels; boardwalk bridges | mud, moss, grass, shallows | 0.2–1.7 (Wild, Tribe) | yes |
| 3 | `canyon` | Red Canyon | 1 | canyon | 340 s | canyon walls and mesas; a pass every few cells | dirt hardpan, sand dunes, fast washes | 0.3–1.8 (Wild, Tribe) | yes |
| 4 | `quarry` | Goon Quarry | 2 | quarry | 380 s | terraced pits and junk forts (ring walls with ramps and gates) | dirt haul roads, mud, lots, mud pits | 1.0–2.2 (Tribe) | |
| 5 | `frostbite` | Frostbite Pass | 2 | mountain | 420 s | mountain ranges and massifs; passes | snow, deep snow, ice lakes | 0.2–2.6 (all three) | |
| 6 | `highway` | Route Nowhere | 2 | highway | 460 s | rock outcrops off the road; jersey barriers and wrecks on it | asphalt, oil, sand and dirt verges, gas station lots | 1.6–2.8 (Tribe, Scrap) | |
| 7 | `city` | Rust City | 3 | city | 500 s | building blocks and canals, bridged at every street | asphalt, lots, park grass and moss | 2.0–3.5 (Tribe, Scrap) | |
| 8 | `crusher` | The Crusher | 3 | yard | 540 s | scrap mountains and container rows round yard plots | dirt, lots, oil, conveyors | 2.4–3.6 (Scrap) | |

Rosters are in each `.tres` (`LevelRoster` validates and pads them; a faction with no list falls back to the Tribe's). A roster for a faction outside the level's band is only reached by `-- --faction=`.

Every level has `pickupsPerChunk = 2` and a `none` weight that grows with the order, so fuel, health, purses and slot machines keep their per-chunk rates while coins thin out from about 3 a chunk on prairie to about 1.5 on crusher (`test_world_recipe.gd` checks this). Every level also has sprint slack from 1.5 (prairie) down to 1.15 (crusher), and the clock, spawn timer and giant odds escalate with the order (`test_levels.gd` checks this). `LevelDef.blurb`, `barrier` and `surfaces` are the Goonopedia's level card text, and `Levels.GRAMMAR_TEXT` adds one line per grammar.

### LevelDef fields

- **Menu:** `id`, `displayName`, `poster` (`world/art/posters/<id>.png`), `act`, `order`, `blurb`, `barrier`, `surfaces`.
- **Run:** `startPosition`, `seconds`, `spawnTimer`, `giantOdds`, `escalationSpeed`, `sprintSlack`, `modes` (a whitelist; empty offers every mode).
- **Goons:** `factionBand` (Vector2 min/max score), `roster` (`{faction: [goon ids]}`).
- **World:** `grammar`, `features` (the grammar's parameters, below), `baseTerrain` (terrain ids by noise band, low to high; the commonest is the level's main ground, the faster one on a tie: `WorldField.mainTerrain`), `accents` (surfaces sprinkled as patches; only "plain" surfaces count: grass, sand, mud, moss, dirt, snow, wash, deep snow, lot), `dressing` (`{faction: {prop id: weight}}`), `pickupTable` (`{kind: weight}`), `pickupsPerChunk`.
- **Look:** `palette` (the shader's fallback colour when material images are missing), `nightTint`, `ambience` (both unused).

`snapshot()` deep-copies every field into a plain Dictionary for worker jobs, because Resources aren't safe to share across threads.

## Grammars

`WorldField.sample(x, y)` returns `Vector3(water, wall, surface)` for any world point: two signed distance-like fields (negative inside deep water or a wall, 0 on the edge, `BIG` = 4 where there is none) and the terrain id of the ground ignoring water and walls. Everything is a pure function of the seed, the def snapshot and the point, so the coarse build and the fine rasters sample the same fields and chunk edges agree.

Common to all grammars: the plain ground is `baseTerrain` by a broad 3-octave noise band (1/9000 px), replaced by an `accents` patch where a second noise (1/2600 px) is above 0.5. The map edge is ocean. Within `START_CLEAR` of the start there is no barrier and the ground is the main terrain (a road or street stays asphalt; oil becomes asphalt).

Thresholds in `features` are raw noise values: plain simplex noise spans about −1..1 (half within ±0.35), 3-octave fbm about −0.8..0.8 (half within ±0.2). Frequencies are in 1/px, widths in px. Every grammar also reads `barrierCap` (0.2 by default; 0.35 by default on canyon, city and yard), `props` (16) and `decor` (110).

| Grammar | What the fields do | `features` keys (defaults in `WorldField.setup`) | Barrier terrain, crossing |
|---|---|---|---|
| meadow | creeks along the zero lines of one noise, where a slower mask lets them run; pools where a third noise is high widen them; dirt tracks along a fourth noise's zero lines | `creekFrequency` 6e-5, `creekWidth` 640, `poolThreshold` 0.45, `poolWidth` 520, `trackWidth` 420, `fordWidth` 1200 | water with shallows; fords (SHALLOWS) |
| bayou | lakes where an fbm rises above `lakeThreshold`; two braided channels either side of a noise's zero line, each strand masked by its own noise | `lakeFrequency` 1/12000, `lakeThreshold` 0.3, `channelFrequency` 1.1e-4, `channelWidth` 560, `channelGap` 0.2, `bridgeWidth` 900 | water with shallows; bridges (BRIDGE) |
| canyon | canyon walls along ridged zero lines (masked); mesas where an fbm rises above `mesaAbove`; wash lanes along another noise's zero lines; sand dunes where a fifth noise is above `duneAbove` | `ridgeFrequency` 7e-5, `wallWidth` 900, `mesaFrequency` 1/9000, `mesaAbove` 0.38, `washFrequency` 4e-5, `washWidth` 700, `duneAbove` 0.35, `passWidth` 1400 | HILLS; passes |
| quarry | noise ground and dirt haul roads; one set-piece slot per `pieceCells` coarse cells: a terraced pit (ring wall with `pitRamps` ramps, mud in the middle), a junk fort (ring wall with `fortGates` gates, a lot inside) or a tyre camp (open dirt, reserved for props); mud pits (radius `mudPitRadius`, at most one per 2560 px lattice cell, 14% chance, never on a haul road) | `haulFrequency` 4.5e-5, `haulRoadWidth` 900, `pieceCells` 10, `pitChance` 0.3, `pitRadius` 3200, `pitRamps` 2, `fortChance` 0.25, `fortRadius` 2200, `fortGates` 3, `tyreCamps` 0.25, `campRadius` 1500, `rampWidth` 1000, `mudPitRadius` 200, `passWidth` 1300 | HILLS; ramps and gates are crossings |
| mountain | ranges along zero lines (masked) and massifs where an fbm peaks above `peakAbove`; ice lakes where another fbm is above `iceLakeThreshold`; deep snow where a fifth noise is above `deepSnowAbove` | `ridgeFrequency` 6e-5, `rangeWidth` 1800, `peakFrequency` 1/8000, `peakAbove` 0.42, `iceFrequency` 1/7000, `iceLakeThreshold` 0.3, `deepSnowAbove` 0.3, `passWidth` 1500 (Frostbite 1800) | HILLS; passes |
| highway | highways along +x every `highwaySpacing` px of y (highway 0 through the start), warped by up to `warpAmplitude`; branch roads along y every `branchEvery` chunks (each with `branchChance`); oil on the asphalt where a noise is above `oilAbove`; a dirt verge; gas station lots beside the highways every `gasStationEvery` chunks; rock outcrops (the only walls) where an fbm is above `rockAbove`, at least 1600 px off any road | `warpFrequency` 4e-5, `roadWidth` 1600, `branchWidth` 1000, `warpAmplitude` 3000, `highwaySpacing` 23040, `branchEvery` 3, `branchChance` 0.7, `gasStationEvery` 6, `oilAbove` 0.6, `rockAbove` 0.4 | HILLS; passes |
| city | a street lattice on the coarse grid: in every group of 5 columns (and rows) a street at offset 0 and at 2 or 3 (hashed); street cells are asphalt; blocks between streets are buildings (inset by a `sidewalk`, lot underneath), parks (grass, moss) or lots, by share; some street rows are canals (never within 6000 px of the start's row), bridged at every street column | `buildingShare` 0.45, `parkShare` 0.2, `lotShare` 0.25, `canalShare` 0.1, `canalWidth` 1040, `sidewalk` 110 | BUILDING; bridges at the full street width; no shallows |
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
10. **`START`** is recomputed, then an `AStarGrid2D` is built over the passable cells (`makeAStar`: solid where blocked, weight = the terrain's `routeWeight`, diagonals only where no corner is cut), and the route from the start to the station is measured (`routeBetween`: never shorter than the straight line).

The result also lists every district (`id`, `cells`, `centroid`, `firstCell`, `neighbours`, `inStart`, `landmark`), the crossings, the station and its chunk, the lane mouths, the route, `routeLength`, `routeReached` and timings (`ms`). The build takes about 1.3–2.9 s on the dev box's worker thread, depending on the level.

### The fine raster

`WorldGen.fineRaster(job)` samples the same fields at the centres of a chunk's 40 × 20 fine cells (plus a one-cell apron, so neighbouring chunks agree) and clamps them to the coarse map so the two never disagree about passability:

- Between the centres of two 4-adjacent passable coarse cells the fine map is always open: the fine fields stay above (the bilinear coarse envelope − `A_LO`), a corridor at least 2 × 448 px wide.
- A blocked coarse cell is always blocked within `PILLAR_PX` (160 px) of its centre.
- Filled pockets are filled; crossings in a cell or its 4-neighbours open their full width (`fordHalf`, `bridgeHalf`, `passHalf` across the way through). Inside a pass, deep snow and ice become plain snow, so heavy cars don't stick there.
- The fine terrain is the wall terrain where the wall field is below 0; BRIDGE where a bridge crossing covers water; WATER where the water field is below 0; SHALLOWS where the water field is below `BAND` (256 px) on grammars with shallows (all but the city) or at a ford; else the surface.

The output is the 40 × 20 terrain bytes plus the `water` and `wall` fields at 42 × 22 (under a bridge the water field stays negative, for the art).

## Districts

`WorldMap.setupDistricts` decides, per district and seeded from the world seed and the district id (`ihash` tags `TAG_FACTION`, `TAG_GOONS`, `TAG_NAME`, `TAG_TINT`, `TAG_GIANT`):

- **Faction** (`LevelRoster.factionAt`): the centroid's distance from the start in chunks (5120 px) × `Goons.DISTANCE_WEIGHT` (0.35), ± `Goons.FACTION_JITTER` (0.4), clamped to the level's `factionBand` with its top exclusive. The start's own district counts as distance 0. If the roster for that faction is empty, the Tribe's is used and the district is Tribe.
- **Goons** (`LevelRoster.pickGoons`): slot 1 the lowest rank in the roster, slots 2 and 3 higher ranks, by a seeded shuffle.
- **Name:** a faction word (`NAME_FIRST`) and a grammar word (`NAME_SECOND`), unique within the map ("Tusker Flats", "Rust Junction").
- **Tint:** 0.9–1.08, also stored as a 4-bit code (`tintCodes`) that the ground shader shows as a faint brightness shift (0.93–1.05) on open ground.
- **Giantism:** 0–99. Shown on the HUD region chip; not used by spawning yet.
- **Landmark:** `landmark_wild`, `landmark_tribe` or `landmark_scrap` at the open cell nearest the centroid (within 10 cells, not reserved, all 8 neighbours passable), recorded per chunk in `WorldMap.landmarks`. `ChunkRecipe.placeLandmarks` finds the exact spot round it (rings of 128 px, 8 rings) and leaves it out if nothing fits.

`Region.setDistricts` turns each district into a region (`name`, `terrain`, `giantism`, `faction`, `goon`, `terrain_modulate`, `visited`). A district decides *who* spawns; waves are one clock for the whole run (`Region.wave`, `runTime`: a star and a wave chest every 60 s, no cap, untouched by crossing districts; roadmap W-1); `-- --faction=` and `-- --goons=` override them. `TileManager.updateChunks` checks the car's coarse cell; when it enters a cell of another district (a barrier cell keeps the last one), it calls `Region.updatePlayerRegion`, which pushes the district's goons to the spawner. The wave count and time **carry over** into a district of the same faction. A region pays a star for each 60 s the car spends in it, up to 3 (waves 2 to `Region.LAST_WAVE` = 4), with no cap in Goonpocalypse.

## Objectives

- **Sprint station:** `placeSprintStation` asks `findStationChunk` for the chunk nearest `start + Level.sprintOffsetPx(seconds, roll)`, searching square rings outward: the 4 cells round the chunk's centre must be passable and in the start component, and the lot rect (`WorldGen.LOT_RECT`, 5300 × 2800 px round the centre: the lot, 2000 px of approach to the east and room behind) must be clear. Failing that within three more rings, the nearest chunk with a good centre is used. Only chunks at least `STATION_MIN_SHARE` (85%) as far from the start as the desired one count (Marathon's next legs measure from the last station), so the nearest good chunk can't lie back toward the start. Before this, one Crusher seed put the station 11,812 px out with a 46.8 s clock. If none qualifies, any chunk does. The lot's cells are then opened and reserved. The offset is `seconds × 0.25 × 450` px ahead (+x), with a y spread of up to 25% (`TAG_SPRINT` roll), at most 32,000 px.
- **Route-length clocks:** `Level.onWorldReady` sets the Sprint clock from the A* route (`TileManager.lastRouteLength`, never shorter than the straight line): `drive = route × ROUTE_FACTOR[grammar] + STATION_APPROACH_PX`, then `clock = drive / 450 × sprintSlack`. The route on 1280 px cells is shorter than the real drive (fine walls, pools, props, corners, and the lot's single east gap), so `ROUTE_FACTOR` is 1.08 meadow, 1.12 bayou, 1.15 canyon, 1.12 quarry, 1.15 mountain, 1.05 highway, 1.12 city, 1.15 yard (1.1 default), and the approach allowance is 1500 px.
- **Marathon legs:** each station but the last calls `Level.stationReached`. `TileManager.placeNextStation` retires and unpins the old station, then finds the next chunk a Sprint offset away, turned within 60° of the last leg (`TAG_LEG` rolls), never the chunk just left. It is searched on the finished map, so its lot's terrain is not cleared (walls or water can stand in it): a chunk whose lot is already clear is preferred. Its props, pickups and `decorateChunk` spots are kept out of it as for the first station: `pinChunk` reserves the lot and drops the recipes already built round it, so they are built again. The leg's clock comes from `WorldMap.routeBetween` with the same drive formula.
- **Defense lanes:** the station goes in the start's chunk or the nearest one that qualifies (`findStationChunk`), its lot is cleared, the car is moved outside the lot's gap (`Level.DEFENSE_START`), and 3 straight lanes (`DEFENSE_LANES`) run out from it at a seeded turn plus 120° each (± 0.3 rad), from 900 px to 4900 px from the station; every cell within 1000 px of a lane's line is opened and reserved. The lane mouths (4000 px out) are where `Level.setupDefense` puts the spawners; props keep 450 px off the lanes. Without lanes (no map) the spawners ring the station at 4000 px.
- Every station chunk is pinned (`TileManager.pinChunk`), and its lot rect is added to `lots`: the recipe context is rebuilt, and props and pickups inside a lot are skipped at apply time too (`TileManager.reservedAt`), so a recipe cached before the lot existed still keeps out.

## Chunk recipes

`ChunkRecipe.build(job)` runs on the worker right after the fine raster and turns it into a Dictionary in chunk-local px (the chunk's top-left corner is 0,0). It touches only its job: the level's tables come in `job.ctx` (`WorldSkin.recipeContext`), the district factions and tint codes of the chunk's 8 coarse cells in `job.factions` and `job.tints`, the belt directions in `job.aux`, and the landmarks standing in the chunk in `job.landmarks`.

| Key | Contents |
|---|---|
| `control` | 42 × 22 RGBA8 for the ground shader (below) |
| `pieces` | convex `PackedVector2Array`s: the walls' collision |
| `occluders` | open polylines along walls, solid on the right |
| `lines` | `[strip index, points]`: shore foam and wall lips for `Line2D`, barrier on the left |
| `decor` | `{decor id: PackedFloat32Array}`: MultiMesh buffers (12 floats an instance: 2D transform, custom data x picks the atlas cell); in the city also the rooftop dressing |
| `props` | `[id, pos, rotation, variant, taken bit (−1 none), occluder]`, a landmark first |
| `pickups` | `[pickup id, pos, taken bit]` |
| `spots` | up to 3 open places (480 px clear) for `PickupWorld.decorateChunk` |
| `counts`, `phases`, `usec` | budget counts (`nodes`, `occluders`, `pieces`, `props`, `pickups`, `decor`, `lines`, `dropped`, `simplify`) and timings |

Order of work: control block; wall contours (marching squares over the padded wall field, only when some wall value is below 0); convex pieces; occluders; lines (wall lips and, when some water value is below 0, shore foam broken at bridge decks); then placement: landmarks, `spots`, pickups, props, decor, rooftops; then the node budget.

### Budgets and how they are enforced

| Budget | Value | Enforcement |
|---|---|---|
| Nodes per chunk (pickups and decorateChunk extras not counted) | 100 (`MAX_NODES`) | fixed cost first: 8 ground quads, the wall body, occluders, lines, one MultiMesh per decor id; then props in placement order, each costing 3 nodes (+1 with an occluder, +1 with a beacon, +1 with a canopy); a prop that would pass the budget is dropped |
| Occluders | 16 (`MAX_OCCLUDERS`), each at most 1280 px on a side (`SPAN`) | wall occluders are split to the span, sorted longest first, and the shortest dropped; props past the remaining room are placed without their occluder |
| Static pieces | 48 (`MAX_PIECES`) | Douglas-Peucker simplification grows through 16, 32, 64, 128 px until the pieces fit; points on the chunk's edge are kept so neighbouring chunks meet; a simplification that lost too much area falls back to the exact outline |
| Lines | 24 (`MAX_LINES`), each within 1280 px | split to the span, the shortest dropped |
| Area2D | none but pickups | |
| World lights | none | landmarks glow through an additive unlit `Beacon` sprite instead |

Wall blobs and holes under 2500 px² are dropped or filled (`MIN_LOOP_AREA`), pieces under 64 px² are dropped. `test_world_recipe.gd` checks the budgets for every level over 3 seeds. A recipe takes about 4–13 ms on average on a worker, depending on the level.

### Props and decor

- **Dressing:** `LevelDef.dressing` maps each faction to `{prop id: weight}`. `WorldSkin.dressingIds` splits them by the manifest's class: DECOR ids become MultiMesh decor, the rest (LOW, TALL, STATEFUL, WALL) pooled or instanced scenes. The three landmarks are always loaded, and the city adds the `rooftop` decor (`WorldSkin.ROOF_DECOR`).
- **Props** (`placeProps`) come in three passes, all counted against `features.props` (16 by default; Bayou and Frostbite 18, Canyon and Highway 13, City 12) × the chunk's open share:
  1. **Field lines** (`placeFieldLines`, package 14 P-3). Fences and hedges (`WorldSkin.FIELD_PROPS`) are never scattered: they lie on the edges of a field lattice in world space, one lattice per `FIELD_REGION` (10,240 px) square, turned up to `FIELD_ANGLE` (0.6 rad) from the world axes by the seed, `features.fieldSpacing` px apart (1400; Prairie 1600). Each lattice edge is a fence (chance `features.fenceDensity`), a hedge (`hedgeDensity`) or nothing; a run has a gap (a gate; two on runs of `FIELD_GATE_LONG` pieces or more). A chunk places the pieces whose centres are inside it, in the dressing of the district there, on open ground off roads (so tracks and creeks cut gaps) and clear of water, walls and earlier reservations; pieces of one run touch end to end. Hedgerows get an oak at some corners (`CORNER_TREE`); a lattice cell fenced on `PADDOCK_EDGES` (3) sides is a paddock with 2-4 hay bales inside. Each piece counts as `FIELD_COST` (0.34) of a scattered prop.
  2. **Motifs** (`placeMotifs`, P-5). `LevelDef.motifs` picks set pieces per district faction from `WorldSkin.MOTIFS` (camp, cabincamp, wreckpile, junkyard, pinestand, cypressgrove, orchard, boneyard, roadblock, pileup), `features.motifs` (1; City 0.4, Highway and Crusher 1.2) a fully open chunk. A motif's members sit at its centre, round a ring, scattered in a disc, or in a grid or line turned to the field lattice, `MOTIF_GAP` (70 px) apart instead of `PROP_GAP`; the motif keeps `PROP_GAP` from everything else and is skipped when fewer than its `min` members fit. Members load with the level whatever its dressing says. Each counts as `MOTIF_COST` (0.5).
  3. **Scatter** by dart throwing for the rest (up to 14 darts per prop wanted), each spot from its coarse cell's district faction's table, field props left out. A prop must fit at its centre and 4 points across its box: on spawnable ground, never on a conveyor, mud pit or bridge, off asphalt and oil unless it is a road prop (`ROAD_PROPS`: cone, jersey, wreck, manhole, barricade, sign), at least 77 px (`PROP_MARGIN`) from water and walls, outside the start's core (1200 px), station lots and Defense lanes, and `PROP_GAP` (150 px) clear of everything placed, so a car can weave through. Other chain props (jersey, fortwall) are laid 2–4 end to end; a chain that may stand on roads lies along the road there (`roadAxis`: the heading of 8 with the longest run of road).
  Breakables take taken-set bits in placement order across the passes (`nextBit`). Recipes now average about 14-15 ms on a worker on Prairie (field lines and motifs), Prairie's chunks reach the 100-node budget, and the rest stay under it.
- **Decor** (`placeDecor`): `features.decor` (110) × the open share, never on blocked, bridge or conveyor cells. `WorldSkin.DECOR_PLACE` limits some ids: `paint` and `streetglow` only on roads and lots, `reeds` only on shallows and banks, `oilstain` and `cracks` anywhere; the rest stay off asphalt, oil and shallows. Tufts and reeds bend away from the player's car (`WorldSkin.BEND_DECOR`, `world_decor.gdshader`: each corner pushed by how close it is to `gc_car_pos`, which PropReactions sets each frame; off at Ground Detail Simple).
- **Rooftops** (city): up to 48 a chunk on BUILDING cells, at least 0.3 field units (192 px) inside the parapet and 190 px apart, square to the street grid.

### Pickups and the taken set

`placePickups` rolls `pickupsPerChunk` kinds from `pickupTable` (`coinline`, `fuel`, `health`, `purse`, `slot`, or `none`, which places nothing, so a chunk can stay empty; `WorldSkin.PICKUP_IDS` maps them to `Pickups` ids, `slot` → `slotmachine`). A `coinline` is 7 coins 130 px apart on a gentle bend. Every pickup stands on spawnable ground, 128 px from water and walls, inside the chunk and outside the reservations.

**The taken set** (`WorldMap.taken`: chunk → int bitmask) lasts the whole run. Pickups take bits 0–31 in placement order (each coin its own; a pickup past bit 31 has none and comes back on a reload), breakables bits 32–62. `ChunkView` puts the slot on each node as metadata `worldSlot = Vector3i(chunk x, chunk y, bit)`. Collecting a pickup (`Powerup` calls `WorldMap.takeNode`) or smashing a breakable (`BreakableProp.markTaken`) sets the bit, and a re-applied chunk skips it. `PickupWorld.decorateChunk`'s extras (crates, the Speed Trap...) have no bits; they come from their own chunk seed.

## Applying chunks

`ChunkView` applies a recipe in stages, one piece per step, so neither a load nor an unload costs more than the frame's budget:

| Stage | Step |
|---|---|
| GROUND | the control block into the control ring; then 8 ground quads (1280 × 1280) and the chunk's `objects` node |
| BODY | one `StaticBody2D` (layer 1, mask 0) with a `ConvexPolygonShape2D` per piece |
| OCCLUDE | one `LightOccluder2D` per step (open polygon, cull counter-clockwise, metadata `gc_world = true`) |
| LINES | one `Line2D` per step (width 128, the strip tiled) |
| DECOR | one `MultiMeshInstance2D` per decor id |
| PROPS | one prop per step: pooled for LOW/TALL/WALL, instanced with `BreakableProp` attached for STATEFUL ones and anything with a taken bit; variant texture; the occluder kept or dropped per the recipe |
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
- **Materials** (`materials`): a `Texture2DArray` of the level's ground materials only: the main ground first, then base, accents, the grammar's own terrains (`WorldSkin.GRAMMAR_TERRAIN`), water, shallows and the wall top (`rock`, or `roof` in the city). A tile covers 1024 world px. Without image data (headless) or with mismatched formats, flat placeholder colours are used.
- **Other uniforms:** `macro_noise`, `water_layer`, `wall_layer`, `wall_tint` (per grammar, `WALL_TINT`), `ctl_size`, `organic` (how far borders wander: 0.2 city, 0.5 yard, 0.7 highway, else 1).
- **Drawing:** the fields are interpolated between cell centres, so water and wall edges are smooth and match the collision contours (the same values went through marching squares). Wall tops get a lighter lip and a contact shadow at their foot; deep water darkens with depth; a bridge deck hides the water.
- **`gc_ground_quality`** (a global in `project.godot [shader_globals]`, set from the Ground Detail setting `gfx/ground`: Potato 0, others 1): 0 draws the nearest cell's material with no macro noise and no water or belt animation; 1 blends four cells with the blend warped by the macro noise (organic borders), adds macro brightness variation, moves the water and runs the belts at 250 px/s. `ShaderWarmup` compiles the ground, decor and beacon shaders behind the countdown.

## Collision, occluders and lines

- **Walls:** one `StaticBody2D` per chunk on layer 1 with convex pieces (from the wall field's contour, so it matches the drawn edge). Water has no collision: it is lethal by grid check instead (below).
- **Props** are `StaticBody2D` scenes on layer 1 with a convex hull (docs/WORLD_ART.md). `World.isWall` treats bodies, props and the station alike.
- **Occluders** run along wall edges facing open ground, solid on the right, one-sided. They carry `gc_world = true`, so at Lighting Low (`Settings.occluderVisible`) world occluders stay on while goon occluders go off.
- **Lines:** shore foam (`shore_foam`) on water edges, and a wall strip on wall edges: `WorldSkin.WALL_STRIP` gives `mesa_lip` (canyon), `snow_ridge` (mountain), `roof_edge` (city), `scrapwall` (yard), else `cliff_lip`.

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
- **Bits:** leaves from each layered prop's baked `<id>_leaves.png` strip (`WorldSkin.leaves`; pine drops snow clumps on the mountain grammar), drawn by one `Bits` node (72 pooled), and dust and spray through a `CarJuice.Particles` (96). Driving Effects (`gfx/driving_fx`) scales them by `PARTICLE_SCALE` (none at Minimal); Reduce Motion cuts the springs to 40%.

## Water

- **Deep water is lethal.** The car (`checkGround`, every physics tick) is wrecked through `destroy()` once its centre has been over a lethal cell for 2 ticks in a row (`LETHAL_TICKS`). There is no water `Area2D`. The playtest records this as `WATER`.
- **Shallows** ring every deep-water body for 256 px (except the city's canals, which have sheer edges): passable, slow (friction 0.45, grip 0.7), not spawnable. Fords cut through creeks are shallows too.
- **Bridges** are BRIDGE cells over water (bayou boardwalks, city streets over canals): passable, fast, not lethal; the shader hides the water and shore foam stops at the deck.
- **The ocean** fills the map's outer 2 coarse cells.
- **Goons:** a solid goon over a lethal cell drowns (checked every 4 ticks, staggered by instance id; buried, hopping, flying and riding goons are immune until they land). A drowning within 3 s of the car touching the goon counts as a crush with a "SPLASH" label (`WorldHooks.drownCredited`, `SpawnManager.creditCrush`, also counted per goon for the Goonopedia). A drowned Bandit's loot washes up on the nearest dry cell (`WorldHooks.bankNear`). Off-screen goons treat water as blocked (`slideStep`), so none drowns unseen.
- **Tethers:** harpoon and magnet tethers snap when the car is within 400 px of deep water (`WorldHooks.tetherMustBreak`). Oil and slime are never laid on shallows or within a fine cell of deep water (`hazardAllowed`).
- **The AI** treats deep water as death in its plans and keeps goals away from it (docs/AI_DRIVER.md).

## The wall contact model

In `overhead_car_body_2d.gd` (`wallTick`, `wallContact`, `wallDamage`):

- **Impact:** `|normal · direction of travel|`, clamped to 0.15–1 (`wallImpact`). Every contact tick keeps `lerp(1, 0.85, impact)` of the velocity.
- **Hit:** meeting a wall with none touched in the last 10 ticks (`WALL_CONTACT_GAP_TICKS`), or driving into it again at 150 px/s or more along its normal (`WALL_REHIT_SPEED`), costs `0.07 × speed before the slide × impact` (`WALL_DAMAGE_PER_SPEED`; armor is applied in `damage()`). Two pieces of one wall in the same tick are one hit.
- **Scrape:** staying against a wall costs at most every 15 ticks (`WALL_SCRAPE_TICKS`) `min(0.07 × speed × 0.15, 4)` (`WALL_SCRAPE_MAX`), about 1.1 health a second for a stock car.
- Zone wear follows the damage (`zoneForHit`, a 30-tick cooldown per system). `wallHealthLost` sums what walls took (the playtest's `damage_rocks`).

## Goon and FX hooks

`WorldHooks` (static, pure grid reads, so 250 goons and the planner can call it every tick; with no map every rule is a no-op):

| Function | Used by | Rule |
|---|---|---|
| `slideStep(pos, step)` | `GoonBody.advance` off screen | the whole step if open, else along the open axis, else hold; a goon already on blocked ground may step anywhere |
| `drownCredited(now, lastTouch)` | `Walker.drown` | within 3 s of the car's touch |
| `bankNear(pos)` | the Bandit's loot | the nearest dry, open point within 6 fine cells |
| `nearLethal(pos, r)`, `lethalAhead(pos, dir, dist)` | tethers, the AI | 17 samples round a point; samples every 128 px along a heading |
| `tetherMustBreak(carPos)` | `GoonFx` tethers | deep water within 400 px |
| `hazardAllowed(pos)` | `GoonFx.hazard` | not shallows, water or wall, and no deep water within a fine cell |
| `wallAt(pos)`, `lineClear(a, b)` | shots, lobs, blasts, chains | wall cells stop shots and shelter from blasts (samples every 64 px); water stops nothing |
| `bounce(pos, vel, delta)` | the kicked shell | reflects the blocked axis |
| `nearestInGroup(tree, group, pos, maxDist)` | spawns, Bandit, Buzzard | the nearest tagged prop |

Spawning, props and FX rules for goons are in docs/GOONS.md ("The world").

## Determinism

- Every random stream in the world is `WorldGen.ihash(seed, tag, a, b)`, an integer mixer (`hashf` gives a float in [0, 1)). Tags: `WorldGen` 1–12 (run, share, district, lane, sprint, leg, spawner, faction, name, tint, goons, giant), `WorldField` 101–111 (noise seeds, pieces, mud pits, branches, gas stations, lattice, canals, blocks, segments, plots), `ChunkRecipe` 201–212 (recipe, pickup, prop, decor, spot, roof; 207-211 field lines: region angle and edge kinds, gates, corner oaks, their turn, paddock bales; 212 motifs). `FastNoiseLite` seeds come from `ihash` too.
- A seed rebuilds the same map, districts, stations, lanes and recipes. The worker threads don't change that: each job reads only its own input.
- `TileManager.worldSeed` is −1 (rolls `randi()`) unless set: the playtest sets `--seed` (run *k* uses seed + *k*), the bench defaults to 1337 (`--seed=N` to change).
- Spawners get their own RNG from `WorldMap.nextSpawnerSeed()` (seed and a counter). `PickupWorld.decorateChunk` uses `TileManager.chunkRng` (Godot's `hash([seed, x, y])`).
- Still on the global RNG: which goon spawns and whether it is a giant, drops, and the goons' own behaviour. A daily seeded run would need those moved too.

## Debugging tools

- **World preview** (`scripts/debug/world_preview.gd`, through the playtest harness, which quits afterwards):
  ```
  Godot_console.exe --headless --path . -- --playtest --world-preview --level=prairie,city --seeds=1,2 --objective=sprint
  ```
  Prints each map's build timings (sample, rules, districts, A*), blocked and reachable shares, district and crossing counts, the station and its route, the start district's faction and goons, and an ASCII crop (`--w=80 --h=30` coarse cells) using `World.TERRAIN` letters, `+` for a pass, `S` start, `X` station, `M` a Defense lane mouth, `.` the route. `--level=all`, `--objective=defense`, `--fine=N` times N fine rasters round the start. `--probe=x,y` prints the coarse cells (letter and flag byte) and the fine map round a world point.
- **Bench** (`scripts/debug/bench.gd`): `--level=<id|index|old name|path>`, `--seed=N`, `--pattern=none|sine|circle|route`, `--at=water|wall|x,y` (moves the car beside the nearest deep water or wall, or to a point, once the world is ready), `--zoom=0.4` (holds the camera zoom), with `--shot` to look at edges. The CSV has `chunk_ms` (main-thread apply time per frame) and `occluders` columns.
- **Playtest** (`--trace`): `PLAYTEST_MAP` (the coarse map round the start and the station), `PLAYTEST_HIT` (wall hits with what was hit: the body's name and parent, its layer and the point), `PLAYTEST_STUCK` (stuck events with `near=` (prop ids or `wall` within 320 px), `water=` (deep water within 400 px), `ground=` (the terrain letter under the car), keys, acceleration, slide count, forward speed, buffs and `overlap=` (what the car's front and rear polygons overlap)). Every drowning prints `PLAYTEST_WATER` and a 9 × 9 `PLAYTEST_WATER_MAP` of fine cells round the car. Defense runs print `PLAYTEST_DEFENSE` every 10 s (barrier, goons marching, at the walls, near and wedged).
- **Logs:** `WORLD_BUILD` and `WORLD_CHUNKS` (above).

## How to add a level

1. Make `world/levels/<id>.tres` (a `LevelDef`; copy the nearest level). Set the menu text (`displayName`, `blurb`, `barrier`, `surfaces`), `act`, `order` (its index), the clock and spawn tuning, `factionBand`, `roster`, `grammar`, `features`, `baseTerrain`, `accents`, `dressing` (all three factions), `pickupTable` and `pickupsPerChunk`.
2. Append the id to `Levels.ORDER`. Appending is save-safe; reordering moves unlocks (`SaveManager.migrate()` matches saved entries by id, but unlocks advance by index).
3. Make `scene/level/levels/level_<id>.tscn`: inherit `levelRoot.tscn` and set only `def`.
4. Add a poster to `POSTER` in `scripts/art/world_gen.js` and bake it (`python scripts/art/bake_world.py poster --only <id>`); re-bake `prop decor` so the props' level tags include the new level (docs/WORLD_ART.md).
5. A new grammar also needs: its fields and setup in `WorldField` (a `Grammar` value, `GRAMMARS`, a `sample` branch), any post-pass in `WorldGen.grammarPost`, `Levels.GRAMMAR_TEXT`, `WorldMap.NAME_SECOND`, `Level.ROUTE_FACTOR`, and in `WorldSkin` `GRAMMAR_TERRAIN` (and optionally `WALL_STRIP`, `WALL_TINT`, `ORGANIC`, `ROOF_DECOR`).
6. Update `IDS` and `GRAMMARS` in `tests/game/test_levels.gd` (it also checks that the numbers escalate with the order), then run the suite; `test_world_gen.gd` and `test_world_recipe.gd` check every level in `ORDER`. Preview it with `--world-preview`, and playtest it.

## How to add a prop

1. Draw it in `PROPS` in `scripts/art/world_gen.js` and bake it (docs/WORLD_ART.md, "Adding a prop"); `props.json` gets its class, size, hull, occluder, breakable state and scene.
2. Add it to a level's `dressing` (per faction, with a weight). DECOR ids become decor automatically.
3. If it may stand on roads, add it to `WorldSkin.ROAD_PROPS`; if it is laid in chains, to `CHAIN_PROPS`; a decor with a placement rule goes in `DECOR_PLACE`.
4. A breakable needs `smashSpeed` (and optionally coins in `BreakableProp.COIN_SPILL`); an explosive a blast in `BreakableProp.BLAST`; a prop goons look for a group in `BreakableProp.GROUPS`.
5. Give it a reaction in `PropReactions.REACT` (a prop without one is a plain wall when hit). Anything the car can pass under gets a `canopy` drawing (docs/WORLD_ART.md, "Layered props").
6. Run `test_world_art.gd`, `test_world_recipe.gd` (budgets) and `test_prop_reactions.gd`.

## How to add a terrain value

`Root.terrain` is append-only. Add the value at the end and update every mirror:

1. `Root.terrain` (`scripts/global/root.gd`) and `Goons.T` (`scripts/global/goons.gd`), in the same order.
2. A row in `World.TERRAIN` (`scripts/world/world.gd`) with every column, including a unique `letter`.
3. The constant in `WorldField` (and in `PLAIN_SURFACES` if accent noise may sprinkle it); in `WorldGen` or `ChunkRecipe` only if their code needs it.
4. The material name in `WorldSkin.MATERIAL_OF` (by id), and in `GRAMMAR_TERRAIN` if a grammar produces it outside `baseTerrain`/`accents`.
5. A ground material in `GROUND` (`scripts/art/world_gen.js`), baked into `world/art/ground/<name>.png`, and the name in `GROUNDS` in `tests/game/test_world_art.gd`.
6. The letter in the legends of `world_preview.gd` and `playtest.gd` (`printMap`).
7. Optionally a name list in `Region.names` (only for regions made without a map) and `goonopedia.gd`'s `TERRAIN_NAMES` if goons get it as a biome.

`test_world.gd` and `test_goons.gd` fail when the enum, the table and `Goons.T` disagree.

## Tests

| File | Covers |
|---|---|
| `test_world.gd` | the terrain table and mirrors, the queries' delegation, surface handling in `integrate()`, the off-road rule, wall impacts and the contact model, the two-tick water death, `gc_world` occluders at Lighting Low |
| `test_terrain.gd` | the map's shape: 96 × 96 chunks, the coarse grid, districts per passable cell, fine rasters, chunk summaries |
| `test_world_gen.gd` | every level over 5 seeds: determinism, the start bubble and a non-lethal start, reachable stations, routes never shorter than the straight line, crossing spacing, fine/coarse agreement, district factions, goons and exits, share caps, Defense lanes |
| `test_world_recipe.gd` | every level over 3 seeds and a sample of chunks: budgets, convex in-chunk pieces that agree with the wall field, short occluders and lines, props and pickups on open ground away from the start and the lot, same input same recipe, the applied node budget, collected pickups staying gone |
| `test_world_hooks.gd` | `slideStep`, drowning and its credit, tethers and hazards near water, shells and shots against walls, breakables and explosives, prop groups, the AI's water margin |
| `test_levels.gd` | the registry, defs, thin scenes, escalation, rosters, faction bands |
| `test_world_art.gd` | the baked art and manifest (docs/WORLD_ART.md) |
| `test_prop_reactions.gd` | canopies over the car and their fade, the crane's box, reactions by kind settling at rest, bits off at Minimal, hydrant spray, knocked cones and their reset, blasts, forget, the AI and cones, near-miss cracks, decor bending |
| `test_prop_layout.gd` | field lines square to their lattice and off roads, road barriers along the road, motif clusters, level motif tables and dead keys, the skin loading motif members and spill leftovers |
| `test_spill.gd` | log piles (rolling logs flatten goons and settle), water towers, billboards toppling away from the car, hives, the crane's one drop, goons cutting piles loose, blasts setting spills off, the TileManager's record |
| `test_save_migration.gd` | `SAVE_VERSION` 5: levels rebuilt from the registry, old unlocks carried by index, records rekeyed to ids |

## Known issues

- **Worker speed:** the map build takes 0.8–1.3 s on the HD 620 box (seed 1337; crossings run natively since 2026-10-07, which saved 0.5–0.7 s) and a recipe about 7–12 ms, the rest GDScript. The apply side stays inside its budget. `WorldField.sample` (280–620 ms of the build) is the next port (docs/NATIVE.md, "What to port next").
- **Highway edges** look blobby: the asphalt edge comes from the 128 px raster through organic blending.
- **Bumper-only car collision:** the car's shape is a front and a rear polygon, so its middle can wedge on prop and wall corners (`overlap=` in `PLAYTEST_STUCK`).
- **Unused def fields:** `nightTint`, `ambience`, `modes` (nothing reads `offersMode`), and `sideStreetChance` in City's `features`.
- **Giantism** is per district but only shown on the HUD.
- **Marathon's later stations** are found on the finished map, so their lot's terrain isn't cleared (props and pickups are kept out); a chunk with a naturally clear lot is preferred.
- **No first-run hints** explain deep water or breakables.
