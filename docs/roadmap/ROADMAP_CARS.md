# Roadmap: cars

How cars work today: `docs/CAR_ART.md`. Tags and effort: `ROADMAP.md`. The demo has the first 3 cars.

## Planned
- **[0.3 want] Handling by hand,** on keys and pad: the three demo cars first; handbrake, drift boost and, on the full game's manual cars, the gearboxes. Tune live with the console's `handling` command, then copy the numbers into `car_handling.gd`. S + play.
- **[0.3 want] Driving feel pass** on `scene/fx/car_juice.gd`: lean, two-wheel tilt, bounce, wall jolt, trail density, engine pitch, backfire odds. S + play.
- **[later] Engine sound:** the engine loops one recording; gear shifts, backfires and landings borrow other clips. The car scenes' old crash, tire and engine audio nodes may be unused: check and remove. M.
- **[later] Upgrades:** a flat +1 a level helps weak stats far more than strong ones. Proposal: a `stat_max` per stat in `<car>_info.tres`, tier-based cost bases, car prices re-fit (`ROADMAP_BALANCE.md`). M.
- **[later] The other six cars by hand** (full game), and the semi's trailer and Drop the Load.

## Suggestions
- **Driver perks and affinity,** beside the car traits (`CarTraits`; hooks: `awardBase` in `playerRoot.gd`, the purse's `MIN_COINS`/`MAX_COINS`, `car.crushXpMult`). M to L.
- **Cosmetics** that never change stats: paint and liveries per car, decals and numbers, smoke, spark and flame colors, horns, driver outfits. Generated with `car_gen.js`, chosen on the driver card, bought or earned through `Unlocks` (`paint:` ids), saved per car in `meta.cosmetics`. M.
- **Medal-gated top cars** (needs the upgrade rework). S to M.
- **Analog steering** for Steam Deck (all input is digital today).
- Two-wheel tilt has no perspective skew (it would need a shader pass); the drift bloom is a glow sprite.
