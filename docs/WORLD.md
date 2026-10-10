# The world

There are 30 levels in 6 regions (the road atlas). A level is three choices: where (its **landscape**: generator, ground, walls, water, natural props), who (its **region**: goon class, the region's own props, landmark, strength step) and what (its `LevelDef`: line-up, rules, overrides). The map is built once per run on a worker thread, chunks are turned into "recipes" on worker threads, and the main thread only applies recipes a few nodes at a time. There are no TileMaps: one shader draws the ground, walls are convex collision pieces traced from a field, and props are generated scenes. The art is in `docs/WORLD_ART.md`; the AI driver's view of the world in `docs/AI_DRIVER.md`.

## Files

| Path | Owns |
|---|---|
| `scripts/world/world.gd` | `World`: the terrain table (`TERRAIN`) and the static runtime queries. |
| `scripts/world/level_def.gd`, `levels.gd`, `level_roster.gd` | `LevelDef` (one level; `resolve()` fills its world from its landscape), `Levels` (the registry, `ORDER`), `LevelRoster` (line-up checks, a district's three goons). |
| `scripts/world/landscape.gd`, `landscapes.gd` | `Landscape` and its registry (`ORDER`, `skinOf`, `--landscape=`). |
| `scripts/world/territories.gd` | `Territories`: the six regions (`DATA`), zones, Sprint distance by region. |
| `scripts/world/world_field.gd` | `WorldField`: the pure field functions of the eight grammars. |
| `scripts/world/world_gen.gd` | `WorldGen`: the coarse build, the fine raster, hashing (`ihash`), routing, the station search. |
| `scripts/world/world_map.gd` | `WorldMap` (`Root.worldMap`): coarse arrays, districts, the raster and recipe cache, the taken set, the queries. |
| `scripts/world/chunk_recipe.gd` | `ChunkRecipe`: what one chunk is made of, built on a worker. |
| `scripts/world/chunk_view.gd` | `ChunkView`: one chunk being applied or released on the main thread, a step at a time. |
| `scripts/world/world_skin.gd` | `WorldSkin`: the level's materials, strips, decor, prop scenes, node pools, pickup stock, the placement tables and `recipeContext()`. |
| `scripts/world/world_hooks.gd` | `WorldHooks`: grid rules for goons, GoonFx and the AI driver. |
| `scripts/world/breakable.gd` | `BreakableProp`: smashing, debris, coin spills, explosives and chains, prop groups. |
| `scripts/world/spill.gd` | `Spill`: interactive props, lures, roosts, what spilled. |
| `scripts/world/prop_reactions.gd`, `smash_tags.gd` | `PropReactions` (canopies, hit reactions, knocked cones) and its `SmashTags` (speed tags and first-meeting hints, docs/HUD.md "Smash tags"). |
| `scene/level/tileManager.gd` | `TileManager`: builds the map, places stations, streams chunks, owns the apply budget. |
| `scene/level/levelRoot.gd` | `Level`: applies the def, sets the race clocks from route lengths, Marathon legs, Defense setup. |
| `shader/ground.gdshader` | The ground: one material for every ground quad. |
| `world/levels/<id>.tres`, `world/landscapes/<id>.tres` | The data. **Edit level numbers here**, not in `scene/level/levels/level_<id>.tscn` (which only sets `def`). |
| `world/art/` | Baked art and `props.json` (docs/WORLD_ART.md). |

## Overview and data flow

1. **Level start.** `Level._enter_tree` calls `applyDef()`: it resolves the def, takes the region's strength step and copies the clock and spawn tuning (scaled by the tier, `ModeTiers`) before any child is ready.
2. **Coarse build (worker).** `TileManager.buildWorld` picks the seed (a harness's, else `Course.seedFor` in a fixed-map mode, else `randi()`) and the objective from `Modes.running()` (`"sprint"`, `"defense"` or none), makes the job on the main thread (`WorldMap.jobFor`: a deep-copied `LevelDef.snapshot()` plus the table columns workers need) and runs `WorldGen.buildCoarse` on the `WorkerThreadPool`.
3. **WorldMap.** `WorldMap.fromJob` wraps the result and sets up the districts; `Region.setDistricts` makes them the run's regions.
4. **Skin.** `WorldSkin.new(def)` loads the materials, strips, decor and prop scenes; `prewarm()` fills the pools; `recipeContext(lots, lanes)` turns the level's tables into plain dictionaries for the workers.
5. **Chunk tasks (worker).** `WorldMap.request` queues `WorldGen.fineRaster` then `ChunkRecipe.build` for chunks in the prefetch set; results sit in an LRU.
6. **Apply (main thread).** `TileManager.updateChunks` steps a `ChunkView` per ready chunk within the frame budget. The car's own chunk is urgent: its recipe is waited for and its ground and collision go in at once.
7. **Stations.** `placeStations` puts the station where the generator chose and pins its chunk; `world_ready` fires and `Level.onWorldReady` sets the clock or the mode's setup.

The map is pure data built from the seed and the def; the scene only ever sees recipes.

**Scales** (constants in `WorldGen`, with `TileManager`'s streaming radii and `WorldMap.LRU`): a chunk is 5120 × 2560 px, the map 96 × 96 chunks with chunk (0,0) in the middle; a coarse cell is 1280 px (4 × 2 a chunk), a fine cell 128 px (40 × 20 a chunk, fields with a one-cell apron); field values are distance-like, 1.0 ≈ 640 px (`WorldField.UNIT`).

## The terrain table

`World.TERRAIN` has one row per `Root.terrain` value, in the same order; `Goons.T` mirrors the enum too (`test_world.gd` and `test_goons.gd` check all three agree). `Root.terrain` is append-only. The columns are explained in the file's header. Points the table doesn't make obvious:

- `lethal` means "goons drown here, nothing spawns near it, the AI never plans through it, tethers break by it". The car survives a short swim: WATER's friction, grip, brake and `hurt` exist for the car and for `integrate()` predictions.
- Friction above grass is softened by armor (`World.effectiveFriction`), so heavy cars plow through.
- Never compare against WATER or HILLS: use `World.isPassable/isLethal/isWallTerrain/isSpawnable/isBlocked`.

**The runtime queries** (`terrainAt`, `surfaceAt`, `lethalAt`, `blockedAt`, `spawnableAt`, `pushAt`) and the flag and number lookups are the hot path: the car calls them every tick and the AI about 900 times per plan through `integrate()`. They must stay allocation-free. `def(t)`, `routeWeight(t)` and `letter(t)` read a Dictionary row: setup code and tools only.

- **Native parity.** A real map answers through `WorldMap.grid` (a native `WorldGrid` that mirrors the coarse map and every stored raster; Root's `worldMap` setter makes it `World.grid`). The GDScript `WorldMap.terrainAt` is the same rule, kept for tools, stand-ins and the parity tests: **a change to a query's rule goes in both** the GDScript and `native/src/world_grid.cpp`.
- **No map** (the menu, most tests, the first frames of a run): the queries answer `UNKNOWN` (−1), nothing is lethal, blocked or spawnable, and the car keeps its own friction. A test stand-in in `Root.worldMap` provides `terrainAt`, `surfaceAt`, `lethalAt`, `blockedAt`, `spawnableAt` and optionally `beltDirAt`.
- **Workers** never touch autoloads, so `WorldGen`, `WorldField` and `ChunkRecipe` keep their own terrain id constants and read table columns from the job.

## The levels

`Levels.ORDER` lists the 30 ids in road order: six regions (`Territories.ORDER`) of five stops, the fifth the finale. The demo gets the first `Root.DEMO_LEVEL_COUNT`. Each level's fields are documented in `level_def.gd`; what is not obvious there:

- World fields left empty (`grammar`, `features`, `baseTerrain`, `accents`) come from the landscape (`resolve()`). `dressing`, `motifs` and `heroes` are laid over the landscape's and region's; a weight of 0 takes a prop out.
- `features` holds the grammar's parameters and also layout switches read by the recipe and `Level` (`props`, `decor`, `motifs`, `heroes`, `homePaddock`, `hedgeWalls`, `fieldAngle`, `fieldSpacing`, `fenceDensity`, `hedgeDensity`, `edgeProps`, `bitProps`, `routeFactor`, `barrierCap`).
- `rules`: `nightShare`, `events` (weights for pickup events, and the switch for level-owned world events: docs/PICKUPS.md "The world"), `dazeHeavies`, `oakCoins`.
- `snapshot()` deep-copies the resolved def into a plain Dictionary, because Resources aren't safe to share across threads.
- The clock and spawn numbers rise along each region's road, and a region opens a little easier than the finale before it (`test_levels.gd` checks this).
- `lineup` must come from the region's class (`LevelRoster.lineupFor` falls back to the whole class).

## Landscapes

A `Landscape` is a generator grammar with its default world, a skin (terrain → material map over `WorldSkin.MATERIAL_OF`, wall top, wall strip, tint, `organic`, roof decor), a water look, natural `dressing` and `motifs`, and district name words. The fields are documented in `landscape.gd`.

- **A new landscape re-skins an existing generator**: needles drive like grass, salt like dirt, lava hurts like deep water. So it needs no new terrain physics and no native change.
- **Fallback skin.** `Landscapes.skinOf` draws a landscape with its `fallback`'s skin until every material and strip it names exists in `world/art`, keeping its own generator, world, props and names. All 15 have their art today.
- `-- --landscape=<id>` (any run, playtest, bench or preview) builds every level in that landscape on its own numbers and region.

## Regions

`Territories.DATA` (the `Region` autoload already means a run's districts) holds, per region: name, color, goon class, landmark, district first words, the strength step and three zone tables each of `dressing`, `motifs` and `heroes`.

- **Zones:** 0 near the start to 2 far out (`Territories.zoneFor`, by a district's distance). The region's props are laid over the landscape's per zone (`WorldSkin.zoneTables`), heavier further out, so driving out feels like going deeper into their turf.
- **Strength step:** `Walker.applyStrength` multiplies a goon's speed, damage and crush speed as it spawns. Nothing marks elites.

## Grammars

`WorldField.sample(x, y)` returns `Vector3(water, wall, surface)`: two signed distance-like fields (negative inside, 0 on the edge, `BIG` where there is none) and the ground's terrain id. It is a pure function of the seed, the def snapshot and the point, so the coarse build and the fine rasters agree and chunk edges meet.

Each grammar's `features` keys and defaults are in `WorldField.setup`. Thresholds are raw noise values (plain simplex spans about −1..1, half within ±0.35; 3-octave fbm about ±0.8, half within ±0.2); frequencies are 1/px, widths px. Within `START_CLEAR` of the start there is no barrier. The map edge is ocean. `WorldGen.grammarPost` adds what fields alone can't say (city bridges, yard belt directions in the `aux` byte, reserved set pieces and lots).

## The coarse build

`WorldGen.run` gives every coarse cell a terrain id, flag bits (`BLOCKED`, `LETHAL`, `CROSSING`, `RESERVED`, `CROSS_X/Y`, `FILL`, `START`), a district id and an aux byte, in this order: sample, grammar post-pass, share caps, start bubble, crossings, connectivity, objectives, districts, exits, mixed crossings, A*. What it guarantees:

- Hard barriers cover at most `barrierCap` of any 3 × 3-chunk window.
- Long barriers get a crossing at least every `MAX_RUN` cells (a ford, bridge or pass); short ones are driven round.
- Small pockets are filled; islands are joined to the start's component where a short cut reaches. An island no cut reaches stays, and nothing is placed there.
- `RESERVED` cells (start bubble, objectives, set pieces, the edge) are left alone by later passes.
- The route to the station is A* over passable cells weighted by `routeWeight`, never shorter than the straight line.
- A crossing's kind (ford or bridge, slot canyon or pass) is hashed on its root cell (`crossingRoot`), so all its cells agree.

### The fine raster

`WorldGen.fineRaster` samples the same fields per fine cell and clamps them to the coarse map, **so the two never disagree about passability**: between two adjacent passable coarse cells the fine map is open (a corridor about 900 px wide), a blocked cell is blocked round its center, filled pockets are filled, and crossings open their full width. That clamp is why thin walls can't be terrain (see "Field walls"). The output also carries `tracks` (meadow dirt tracks) and `crossings`, which the recipe anchors heroes to. Where the bands of water fall is under "Water".

## Districts

`WorldGen.buildDistricts` floods districts from jittered seeds over passable cells, so barriers become borders. `WorldMap.setupDistricts` then decides, seeded per district: its zone, three goons from the level's line-up (`LevelRoster.pickGoons`; the district's faction is its first goon's), a unique name (a region word and a landscape word), a tint the ground shader shows faintly, and the landmark's cell.

A district decides only *who* spawns: `TileManager.updateChunks` calls `Region.updatePlayerRegion` when the car's coarse cell changes district. Waves are one clock for the whole run (`Region.wave`). `-- --class=` and `-- --goons=` override the goons.

## Objectives

- **Sprint station:** `findStationChunk` takes the chunk nearest the wanted offset whose center is reachable and whose lot rect (`WorldGen.LOT_RECT`) is clear, never much nearer than wanted (`STATION_MIN_SHARE`), then clears and reserves the lot. The distance is the region's × `ModeTiers.SPRINT_DISTANCE` (`Level.sprintDistance`, `sprintOffsetPx`).
- **Route clocks:** `Level.onWorldReady` sets the clock from the A* route: `route × ROUTE_FACTOR[grammar]` (or `features.routeFactor`) `+ STATION_APPROACH_PX`, at `REFERENCE_SPEED`, × the slack. The factor exists because the coarse route is shorter than the real drive.
- **Marathon legs:** `TileManager.placeNextStation` finds the next chunk on the *finished* map, so its lot's terrain is not cleared (a naturally clear one is preferred); `pinChunk` reserves the lot and drops recipes already built round it.
- **Defense:** the station goes at the start with three cleared lanes; the lane mouths are where `Level.setupDefense` puts the spawners. Cone Course asks for the same cleared lot without a station.
- Station chunks are pinned and their lots added to `lots`; props and pickups in a lot are also skipped at apply time (`TileManager.reservedAt`), so a recipe cached before the lot existed still keeps out.

## Chunk recipes

`ChunkRecipe.build(job)` turns a raster into a Dictionary in chunk-local px (keys in the class comment). It touches only its job: the level's tables come in `job.ctx`. Order: control block, wall contours (marching squares over the wall field), convex pieces, occluders, lines, then placement (landmarks, the Home Paddock's reservation, field walls, spots, pickups, props, decor, rooftops), then the node budget.

### Budgets and how they are enforced

The caps are `ChunkRecipe.MAX_NODES`, `MAX_OCCLUDERS`, `MAX_PIECES` and `MAX_LINES`; `test_world_recipe.gd` checks them for every distinct world.

- **Nodes:** fixed costs first (ground quads, the wall body, occluders, lines, a MultiMesh per decor id), then props **in placement order**; one that would pass the budget is dropped. So what must survive is placed first.
- **Pieces:** the contour is simplified harder until the pieces fit; points on the chunk's edge are kept so neighbors meet.
- **Occluders and lines** are split to a span and the shortest dropped.
- **Taken-set bits:** breakables get bits in placement order; a *paying* breakable (`WorldSkin.PAYING_PROPS`, `BreakableProp.COIN_SPILL`, `Spill.DEFS`) that gets none is left out, so nothing pays twice.
- No `Area2D` but pickups, and no world lights: landmarks glow through an additive unlit `Beacon` sprite.

### Props and decor

Each zone's table is the landscape's dressing, the region's for that zone and the level's own (`WorldSkin.zoneTables`). DECOR ids become MultiMesh decor, the rest pooled or instanced scenes. `placeProps` runs these passes, all counted against `features.props` × the chunk's open share:

1. **The Home Paddock** (`features.homePaddock`, Prairie Run): a fixed opener ahead of the start, laid out in world space so it may straddle a chunk seam. The recipe builds it because `decorateChunk` skips the start's chunk.
2. **Heroes** (below).
3. **Edge props** (`features.edgeProps`): on a thicket's lip, close enough that no car-wide gap is left to wedge in.
4. **Field lines:** fences and hedges (`WorldSkin.FIELD_PROPS`) are never scattered. They lie on a field lattice in world space, so runs line up across chunks; each run has a gate gap. Roads and creeks cut gaps.
5. **Motifs:** set pieces from `WorldSkin.MOTIFS` (the member format is in its comment). Members load with the level whatever its dressing says, and share a `group` key.
6. **Scatter** by dart throwing: on spawnable ground, off roads unless a `ROAD_PROPS` id, clear of water, walls, the start, lots and lanes, and `PROP_GAP` from everything placed, so a car can weave through.

Decor (`placeDecor`) follows `WorldSkin.DECOR_PLACE`; `BEND_DECOR` ids bend away from the car (`gc_car_pos`). Roof decor (`placeRoofs`, `ROOF_STYLE`) goes on wall tops.

### Heroes

Interactive props and set pieces are placed **first** in each chunk, on layout anchors, so the node budget keeps them (`test_world_recipe.gd`: `counts.heroesDropped` is 0). The table per zone is the region's `heroes` under the level's: `{prop or motif id: [weight, anchor, variant]}`. Anchors (`ChunkRecipe.ANCHORS`, `anchorPoint`): `ford`, `bridge`, `bank`, `track`, `pass`, `clearing`, `edge`, `any`. What the hero pass places carries metadata `hero`; `WorldSkin.HERO_BREAKABLE` props (the saguaro) break only when it placed them.

### Field walls

On a level with `features.hedgeWalls` (Orchard Lanes) a hedge lattice edge is an unbreakable hedgerow: boxes in the chunk's own wall body, a few occluder loops and one decor MultiMesh (docs/WORLD_ART.md "Hedgerow"), so a dense lattice costs almost no nodes. Gaps fall where a run crosses a road, track, water or reservation; some get a breakable farm gate, which goons open and shut (`Spill`, "farm gates"). **Not terrain:** the fine/coarse clamp would punch a corridor through a thin terrain hedge every 1280 px.

### Region 1 levels

The Wilds' five levels are the only ones with their own layout pass; the numbers are in their `.tres`. Prairie Run: the Home Paddock. Orchard Lanes: hedgerow walls, `bitProps` oaks. Snapper Bayou: mixed fords and bridges (`fordShare`). Red Canyon: slot canyons (`slotShare`), hero saguaros. Moose Woods: thickets (`standFrequency`: HILLS walls drawn as pine crowns, tracks running through as trails); its coarse build is the slowest.

### Pickups and the taken set

`placePickups` rolls `pickupsPerChunk` kinds from `pickupTable`; `WorldSkin.pickupIds()` maps kinds to `Pickups` ids through `Pickups.openOr`, so locked ones never appear.

**The taken set** (`WorldMap.taken`: chunk → bitmask) lasts the whole run: pickups take bits 0–31 in placement order, breakables 32–62. `ChunkView` puts the slot on each node (metadata `worldSlot`); collecting or smashing sets the bit and a re-applied chunk skips it. `PickupWorld.decorateChunk`'s extras have no bits: they come from their own chunk seed, and its crates are remembered by position (`BreakableProp.makeOneShot`, `Spill.markUsed`).

## Applying chunks

`ChunkView` applies a recipe in stages (GROUND, BODY, OCCLUDE, LINES, DECOR, PROPS, PICKUPS, EXTRAS), one piece per step, so neither a load nor an unload costs more than the frame's budget (`TileManager.APPLY_BUDGET_USEC`; `START_BUDGET_USEC` behind the countdown). **Never build a raster or a recipe on the main thread in a run**, and keep new steps inside the budget.

- Nodes come from `WorldSkin`'s pools (`POOL_CAP`) and go back on release. STATEFUL props and anything with a taken bit are instanced instead, with `BreakableProp` attached.
- Pickups come from a ready-made stock (`PICKUP_STOCK`), topped up in spare steps.
- `TileManager` prints `WORLD_BUILD` and, on exit, `WORLD_CHUNKS` (timings, over-budget frames).

## The ground shader

`shader/ground.gdshader` draws every ground quad with one shared material.

- **Control ring:** an RGBA8 texture of 8 × 8 chunks of fine cells, addressed by world cell modulo its size. Each applied chunk blits its block (and its apron into empty neighbor slots, so seams still blend). The texel format is `ChunkRecipe.controlBytes`: material layer, water field, wall field, flags and the district tint.
- **Materials:** a `Texture2DArray` of the level's own ground materials only.
- The fields are interpolated between cell centers, so drawn water and wall edges match the collision contours (the same values went through marching squares).
- `gc_ground_quality` (Ground Detail; declared in `project.godot [shader_globals]`): 0 draws the nearest cell with no blending or animation.
- Lava is the water layer with `water_glow`; night darkens it like any ground, so it lights nothing.

## Collision, occluders and lines

One `StaticBody2D` per chunk on layer 1 holds the wall pieces. Props are `StaticBody2D` scenes on layer 1, so `World.isWall` treats walls, props and the station alike. Water has no collision. Wall occluders carry `gc_world = true`, so they stay on at Lighting Low while goon occluders go off. Lines are shore foam and the landscape's wall strip, built with the barrier on the left.

## Breakables and explosives

Baked breakables carry their state as metadata (`smashSpeed`, `broken`, `debris`, `explosive`); smash speeds are in `props.json`, what a smash gives in `BreakableProp` (`COIN_SPILL`, `PICKUP_SPILL`, `BLAST`, `BURNS`, `SPEED_KEEPS`).

- A breakable hit at or above its smash speed is smashed with no wall damage and the car keeps most of its speed; slower, it is a normal wall hit.
- Coins spill as real pickups: **never credit from the animation.**
- Explosives detonate deferred, once per prop, through `GoonFx.blast`; `blastAt` sets off others in radius with a clear line after `CHAIN_DELAY`, so a chain is bounded.
- `SpawnManager.onNodeAdded` tags props into the groups goons look for (`BreakableProp.GROUPS`; a goon's `seeks` rows in `Goons.DATA`, docs/GOONS.md).
- The AI plans through breakables it is fast enough to smash; explosives are always walls (docs/AI_DRIVER.md).

## Interactive props

`Spill.release(node, dir)` runs from `BreakableProp.smashNode` for every prop in `Spill.DEFS` (what each kind does is in the file's header): logs and rocks roll, towers and billboards topple, hives swarm, the crane drops its container, dens give back stolen loot, burrows cave in, sluices flood. Lures (the Dinner Bell, the Salt Lick), Buzzard roosts and the farm gates goons open and shut live there too; the goon side is docs/GOONS.md "Wild instincts".

- Every kill goes through `Spill.flatten`, which credits the player.
- **What spilled is kept** on the TileManager per chunk (`addSpilled`, `markSpillUsed`), so a reloaded chunk shows the logs where they came to rest and a crane drops only once.
- `PropReactions.addHero` calls `Spill.arm` as a prop streams in and `disarm` as it goes, which restores per-prop state (a den's sacks, a rung bell).

## Prop reactions

`PropReactions`: one node per run, made by the TileManager. Show only, except cones.

- **Canopies:** a layered prop's `Canopy` sprite draws over the car and fades while the player's car is under it. It never fades for goons, so crowns can hide goons (by choice).
- **Hits:** `collideWithFixedObject` calls `PropReactions.hit` on a fresh wall hit; `REACT` gives each prop id a kind. A prop without an entry is a plain wall. Reactions are springs on the prop's sprites, put back exactly at rest.
- **Cones and mailboxes** (KNOCK) fly off above `KNOCK_SPEED` and stop being walls until their chunk reloads; they have no taken bit.
- **Near misses:** a breakable hit just under its smash speed cracks and throws chips, so the player learns how close they were.

## Water

From the bank in: **shallows** (SHALLOWS, harmless and slow), **wading depth** (WADE, deep water's outer band: draggy, slippery, a little damage), then **deep water** (WATER). Band widths are `WorldGen.BAND` and `WADE_DEPTH`. The city's canals have neither band, and a landscape can opt out of wading (`Landscape.wade`; lava). Fords are shallows, bridges are BRIDGE cells over water.

- **The car** ("Water and the car" in code comments). Deep water doesn't wreck the car on contact: once a tick `OverheadCarBody2D.checkGround` takes `World.hurt(surface)` through `damage()`, so armor counts once. Shields don't keep water out; an airborne car is out of it. Drag and grip come from the terrain rows inside `integrate()`, so the AI's predictions see them. A wreck with the car's center over deep water is a drowning (`drowned`). `test_water.gd` prints what a crossing costs.
- **Goons** drown in deep water only; within `DROWN_CREDIT_SECONDS` of the car's touch it counts as a crush. Off-screen goons treat water as blocked, so none drowns unseen. In wading depth they are slowed.
- **Tethers** snap near deep water; hazards are never laid on shallows, wading depth or by deep water.
- **The AI** never plans through deep water; it may wade, at a cost.

## The wall contact model

In `overhead_car_body_2d.gd` (`wallTick`, `wallContact`, `wallDamage`, the `WALL_*` constants): damage is **per contact**, not per tick. A fresh hit costs by speed × impact (how head-on it is); staying against a wall costs a small capped scrape at intervals; two pieces of one wall in a tick are one hit. Armor is applied once, in `damage()`.

## Goon and FX hooks

`WorldHooks` is static and reads only the grid, so 250 goons and the planner can call it every tick; with no map every rule is a no-op. Its grid walks are native (docs/NATIVE.md). Spawning and FX rules are in docs/GOONS.md "The world".

## Determinism

- Every random stream in the world is `WorldGen.ihash(seed, tag, a, b)`; each file has its own tag range (`WorldGen` 1+, `WorldField` 101+, `ChunkRecipe` 201+). **Take a new tag for a new stream**, never reuse one.
- **Workers touch only their job Dictionary**: no nodes, autoloads or global RNG. That is what makes a seed rebuild the same map, districts, stations and recipes whatever the thread timing.
- `TileManager.worldSeed` is −1 (rolled) unless a harness sets it.
- Still on the global RNG: goon spawns, drops and goon behavior.

## Debugging tools

- **World preview:** `Godot_console.exe --headless --path . -- --playtest --world-preview --level=prairie,city --seeds=1,2 --objective=sprint` prints timings, shares, the route and an ASCII map (`World.TERRAIN` letters). Options are in `scripts/debug/world_preview.gd`.
- Bench `--at=water|wall|x,y --shot` shows edges (docs/PERFORMANCE.md); playtest `--trace` prints the map, wall hits, stuck events and drownings (docs/AI_DRIVER.md).

## How to add a level

1. Make `world/levels/<id>.tres` (copy one of the same region). Leave the world fields empty to take the landscape's.
2. Put the id in `Levels.ORDER` at its stop. **Appending is save-safe; reordering moves unlocks** (saves match entries by id, but unlocks advance by index).
3. Make `scene/level/levels/level_<id>.tscn`: inherit `levelRoot.tscn` and set only `def`.
4. Add a poster to `POSTER` in `scripts/art/world_gen.js` and bake it (docs/WORLD_ART.md).
5. Update `IDS` in `tests/game/test_levels.gd`; preview with `--world-preview`, then playtest.

## How to add a landscape

1. Make `world/landscapes/<id>.tres` (copy the one whose generator it re-skins), with a `fallback` whose art is all there.
2. Add the id to `Landscapes.ORDER` and point levels at it.
3. Add its materials and strips to the bake (docs/WORLD_ART.md). A new *grammar* also needs its fields in `WorldField` (`Grammar`, `GRAMMARS`, a `sample` branch), any post-pass in `WorldGen.grammarPost` and a `Level.ROUTE_FACTOR`.
4. Run `test_landscapes.gd` and `test_world_art.gd`; preview with `-- --landscape=<id> --world-preview`.

## How to add a region

1. Add an entry to `Territories.DATA` and its id to `ORDER`; its landmark also goes in `WorldSkin.LANDMARKS`.
2. Add its five levels to `Levels.ORDER`.
3. Update `test_levels.gd`.

## How to add a prop

1. Draw and bake it (docs/WORLD_ART.md, "Adding a prop").
2. Dress it in: a landscape's `dressing`, a region's zone table or a level's.
3. Placement rules: `WorldSkin.ROAD_PROPS`, `CHAIN_PROPS`, `DECOR_PLACE`.
4. A breakable: coins in `BreakableProp.COIN_SPILL`; if it pays, `WorldSkin.PAYING_PROPS`; an explosive `BLAST`; a prop goons look for `GROUPS`; an interactive one `Spill.DEFS` and a hint in `SmashTags.HEROES`.
5. A reaction in `PropReactions.REACT`. Anything the car can pass under gets a `canopy` drawing.
6. Run `test_world_art.gd`, `test_world_recipe.gd` and `test_prop_reactions.gd`.

## How to add a terrain value

Append to `Root.terrain` and update every mirror:

1. `Root.terrain` and `Goons.T`, in the same order.
2. A row in `World.TERRAIN` with every column and a unique `letter`.
3. The constant in `WorldField` (and `PLAIN_SURFACES` if accents may sprinkle it); in `WorldGen` or `ChunkRecipe` only if their code needs it.
4. `WorldSkin.MATERIAL_OF`, and a landscape's `terrains` if its generator produces it.
5. A ground material in the bake, and `GROUNDS` in `test_world_art.gd`.
6. The letter in the legends of `world_preview.gd` and `playtest.gd`.

The native `WorldGrid` needs no change for a new value (it reads the ids and `World._flags`); only a change to a query's rule does.

## Tests

`tests/game/test_world*.gd`, `test_terrain.gd`, `test_water.gd`, `test_levels.gd`, `test_landscapes.gd`, `test_prop_*.gd`, `test_spill.gd`, `test_region1_props.gd`: each header says what it covers.

## Known issues

Traps for anyone working here; open work is in `docs/roadmap/ROADMAP_WORLD.md`.

- **Islands** no cut reaches stay on the map; nothing may be placed there.
- **Keep props either touching a wall or a car's width from it,** so a car can't wedge between them.
- **Pickups past bit 31 in a chunk** have no taken bit and come back on a reload.
