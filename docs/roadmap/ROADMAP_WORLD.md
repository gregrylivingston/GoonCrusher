# Roadmap: world, levels and props

How the world works today: `docs/WORLD.md`, `docs/WORLD_ART.md`. Tags and effort: `ROADMAP.md`.

## Planned

### Region 1: The Wilds (in the demo)
- **[0.3 need] AI stalls.** The AI stalls in Orchard Lanes' hedgerow lanes and Moose Woods' thickets, and Countdown wins fell on Snapper Bayou. Measure first (`--playtest --level=<id> --mode=countdown,sprint --runs=8 --seed=1 --trace`); the numbers on file predate the driver rebuild and the Moose Woods pine fix. If a player can wedge the same way, widen the gate gaps or let farm gates break at speed. M.
- **[0.3 want] Hay Wagon and Bandit Barge in the demo?** Both need the Loot Truck pickup, which the demo can't unlock (`pickup_world.gd`). Open it in the demo or leave the events for the full game (the author's call). S.
- **[0.3 want] Feel pass by hand.** Every smash speed, coin value, event weight and lure radius is a placeholder (`Spill`, `BreakableProp`, `rules` in `world/levels/*.tres`). S + play.

### Region 2: Tribe Country (in the demo)
The revamp is on hold, so its five levels are their landscape's template with a line-up; four of the five have no `rules` of their own.
- **[0.3 need] Sanity pass.** Each level: the line-up fits the level, the station is in reach (Stilt Town's sits too far out), the Sprint clock is beatable, the template's barrier and surfaces text is replaced. AI playtest each level in its five modes. M.
- **[later] The revamp:** set pieces, twists as data (`LevelDef.rules`), its own props and events, as Region 1 had. On hold until Region 1 is settled. L.

### Regions 3 to 6 (full game)
- **[later] Level content** for the 20 levels: twists as data, line-up checks, AI playtests. Cul-de-Sac's station sits too far out. On hold. L per region.
- **[later] Benchmarks** on The Sprawl and The Works (S3, S4).

### Props
- **[0.3 want] Feel pass by hand:** canopy fade, springs and knock speeds (`PropReactions`), the field lattice, motif weights, the spills. Check how much a crown hides goons at night. S + play.
- **[later] Dressing weights** for the Road Atlas props are first guesses.
- **[later] `steam_vent` doesn't glow at night** (needs `"blend": "add"` in the generator's atlas entry). S.
- **[later] `mountain` keeps the plain `pine`;** snowy pines there are the author's call.

### The generator
- **[0.3 want] Cars wedging on corners.** Every car now has a middle hull, yet the AI still gets stuck: find what stalls it (`overlap=` in `PLAYTEST_STUCK`). S to M.
- **[later] Highway edges look blobby:** a crisper border for road surfaces, or a curb line. S.
- **[later] Marathon's later stations** are found on the finished map, so their lot's terrain isn't cleared.
- **[later] Pickups past bit 31 in a chunk** have no taken bit and come back on a reload.
- **[later] Lava doesn't light the night:** its glow is part of the ground, so the night darkens it.
- **[later] Clean up:** `station_wall.png` is baked and tested but never loaded; the `bridge` hero anchor and the `curb` strip are used by no level; `TileManager.tilesPerChunk` and `pixelsPerTile` duplicate `WorldGen.CHUNK_PX`.

## Suggestions
- **Region mutators and objectives:** "fog", "giants only", "double coins"; "crush 20 Rat Pack", anchored on district landmarks. M.
- **District giantism** is rolled and unused: giant odds = `giantOdds + giantism / 5`, plus a term from the run's wave (`ROADMAP_GOONS.md`). S.
- **Custom seed entry** (`TileManager.worldSeed` has no UI) and a daily seeded run, which needs goon choice, giants and drops moved off the global RNG.
- Goon nests, single-use gas pumps, boost chevrons, ramps and airtime crushes, a Training Grounds level.
