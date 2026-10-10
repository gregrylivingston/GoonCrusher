# Cars and handling

**Pitch:** Nine cars that drive differently on purpose: weight, a handbrake and two traits each.

## What it is
- Handbrake slides that charge a drift boost, fired when you let go.
- Weight is the character: heavy cars turn in slower, slide wider and crush at lower speed.
- Two signature traits per car, shown as badges on its garage card.
- Five damage systems (engine, steering, tires, lights, tank): where you are hit decides what wears, and the car's art shows it.
- A horn per car; goons ahead flinch.

## Numbers
- 9 cars, 18 traits (`scene/car/*/*_info.tres`, `scripts/global/car_traits.gd`).
- 2 drift boost tiers, and a third for the racer (`DRIFT_TIERS`, `DRIFT_KING_TIER`).
- Manual gearboxes: racer 6 gears, supercar 7, semi 10 (`gears` in each info file).
- Upgrades: 20 levels a stat.
- 0.1 had the same nine cars and four driving keys: left, right, gas, brake (old `project.godot`).

## Demo vs full game
- Demo: sedan (Second Wind, Duct Tape), van (Cargo Bay, Top-Heavy), taxi (The Meter, City Tires).
- Full game: pickup, semi with its trailer and Drop the Load, supercar, racer, police, ambulance; all three manual gearboxes.

## What to show
- `elements`: `lineup_cars`, `piece_driver_card`, `piece_bench`.
- A handbrake slide into a drift boost: **needs a hand drive** (`capture.py hand`).
- Most existing shots use full-game cars: say so, or refilm with a demo car.

Details: docs/CAR_ART.md.
