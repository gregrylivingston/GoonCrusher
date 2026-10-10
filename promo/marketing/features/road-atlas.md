# The road atlas

**Pitch:** The level list is now a road map: six regions, five stops each, and you drive it in order.

## What it is
- Each region has its own goons, props, landmark and color; each stop has a poster, a line-up and its own layout.
- The fifth stop is the region's finale; it has to be won on Medium to open the next region.
- Win any of a level's three featured modes to open the next stop.
- Worlds are generated and stream in as you drive: creeks and fords, hedgerow lanes, bayou channels, slot canyons, pine thickets.

## Numbers
- 30 levels, 6 regions, 5 stops each (`scripts/world/levels.gd`, `territories.gd`).
- 15 landscapes (`world/landscapes/`).
- 0.1 had 8 levels in a flat list (old `playerData.gd`).

## Demo vs full game
- Demo: The Wilds (Prairie Run, Orchard Lanes, Snapper Bayou, Red Canyon, Moose Woods) and Tribe Country (Mudlick Marsh, Stilt Town, Lantern Marsh, Sawmill Landing, Goon Quarry).
- Full game: Raider Road, Hunting Grounds, The Sprawl, The Works.

## What to show
- `elements`: `piece_road_map`, `lineup_posters`, `title_levels` (says 30: full game).
- `trailer_launch world_pullback` (Moose Woods, sedan); `capture.py panorama --level <id>`.
- `stock` films every level; use only the ten demo levels for demo posts.

Details: docs/WORLD.md ("The levels", "Regions").
