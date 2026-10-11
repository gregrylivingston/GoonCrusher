# The Goon Cup

**Pitch:** Six modes against five other drivers, driven by the same AI that playtests the game.

## What it is
- **Cannonball:** five rivals, one station, no set route.
- **Circuit Race:** three laps of a track cut through the level.
- **Demolition Derby:** six cars in a walled stadium.
- **Knockout:** last place is cut every lap.
- **Keep the Cup:** one trophy; whoever holds it banks time.
- **Pursuit:** one driver runs for the station with a head start.
- Rivals are real cars on the same physics and the same digital keys as you; cars bump each other.

## Numbers
- 6 Goon Cup modes (`scripts/global/modes.gd`); 5 rivals (`scene/level/rivals.gd`, `COUNT`).
- Circuit Race: 3 laps (`mode_tiers.gd`, `CIRCUIT_LAPS`).
- New in 0.3: 0.1 had no other cars on the road.

## Demo vs full game
- All six are featured in the demo: Cannonball (Prairie Run, Mudlick Marsh), Circuit Race (Orchard Lanes, Sawmill Landing), Keep the Cup (Snapper Bayou, Stilt Town), Pursuit (Red Canyon), Demolition Derby (Moose Woods, Goon Quarry), Knockout (Lantern Marsh).

## What to show
- **Needs a shot:** nothing in `promo/shots/` films a Cup mode. A derby on Moose Woods and a Circuit Race start on Orchard Lanes are the clearest.

Not ready to quote: frame rate with six cars on low-end PCs is unmeasured; rivals have no name plates and don't collect pickups yet; the derby arena has no walls.

Details: docs/MODES.md, docs/AI_DRIVER.md.
