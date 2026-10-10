# Pickups and unlock trees

**Pitch:** 83 pickups, and you decide which ones can drop.

## What it is
- Nine kinds: supplies, tune-ups, power-ups, gadgets, boosts, loot, casino, skill challenges, mode specials.
- A gadget slot (Fire) and a boost slot (Boost / Hop), each with its own button.
- A new save starts with three: the Fuel Can, the Coin and the Claw Crane. The rest sit on trees on the Pickups screen, bought or earned by play.
- Locked pickups never drop, so every unlock changes your runs.
- Buy a starting gadget and boost in run setup.

## Numbers
- 83 pickups: 12 tune-ups, 12 power-ups, 12 casino, 11 supplies, 10 gadgets, 9 skill, 8 loot, 6 mode specials, 3 boosts (`scripts/global/pickups.gd`, `DATA`).
- 5 rarities, Common to Legendary.
- 7 tabs on the Pickups screen.
- 0.1 had 15 pickup types and no unlocks (old `root.gd`).

## Demo vs full game
- Demo: 49 of the 83 (Commons, Uncommons, each tree's root, and the casino games next to the Claw Crane). The other 34 read "FULL GAME" (`unlocks.gd`, `inDemo`).

## What to show
- `elements`: `lineup_pickups`, `page_pickups`.
- A gadget in use (Air Horn, Oil Slick and Goon Bait are in the demo): **needs a shot**; a shot's `console` event can hand one over (`pickup <id>`).

Prices are placeholders: say "bought with coins", not how many.

Details: docs/PICKUPS.md.
