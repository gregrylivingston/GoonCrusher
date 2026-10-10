# The Wilds: a world that fights back

**Pitch:** In the first region the scenery is a weapon, for you and for the goons.

## What it is
- Smash a log pile and the logs roll through the crowd. Rock piles slide, beehives swarm, towers and saguaros topple, a sluice gate floods its channel.
- Goons use the same props: Bandits haul stolen loot to a den (smash it to get it back), Jackalopes hide in burrows, others cut log piles loose at you.
- Kills you set up count as crushes and join the combo as a Critter Chain; mixing kinds pays more.
- World events: a stampede, and a flash flood down a wash.
- A Dinner Bell calls goons to it; a Salt Lick draws the heavies.

## Numbers
- 13 kinds of interactive prop in the game (`scripts/world/spill.gd`, `DEFS`); 94 props in all (`world/art/props.json`).
- 5 Wilds levels, each with its own layout pass (docs/WORLD.md, "Region 1 levels").

## Demo vs full game
- All five Wilds levels are in the demo.
- The Hay Wagon and Bandit Barge events need the Loot Truck pickup: full game.

## What to show
- Prairie Run and Orchard Lanes with the sedan: `trailer_launch cold_open`, `social_loops crush_prairie`.
- A log pile, a hive or a flood: **needs a shot**, best as a hand drive (`capture.py hand`).

Smash speeds and event odds are placeholders: show the moment, don't quote numbers.

Details: docs/WORLD.md ("Interactive props"), docs/GOONS.md ("Wild instincts").
