# The goons

**Pitch:** 44 goons, and each one has a single rule you can learn and punish.

## What it is
- Every goon has a verb (what it does), a tell before it acts and a window when it is open.
- Three factions: Wild Things, Goon Tribe and Scrap Gang.
- A level fields 3 to 6 of them; districts mix three at a time and a new wave comes every minute.
- Some resist a slow hit or a head-on hit: Hubcap shields block the front, so go round.
- The Goonopedia shows a goon once you have crushed it, with how to beat it.

## Numbers
- 44 goons: 12 Wild Things, 19 Goon Tribe (counting the Goonling, which only comes out of a Splitter), 13 Scrap Gang (`scripts/global/goons.gd`).
- The demo's ten line-ups field 28 (`world/levels/*.tres`, `lineup`).
- At most 250 on the map at once (`GOON_CAP`).
- 0.1 had 18 goons (old `scene/enemy/walker/`).

## Demo vs full game
- Demo: Wild Things and Goon Tribe.
- Full game: the Scrap Gang, and three mixed classes (Big Game, Street Swarm, War Machine).

## What to show
- `elements`: `lineup_goons`, `page_goonopedia`; `title_goons` (check its number: the beat sheet says 43).
- `social_loops crush_prairie`, `trailer_launch cold_open` for crowds.
- One goon's tell and punish, close up: **needs a shot**.

Details: docs/GOONS.md.
