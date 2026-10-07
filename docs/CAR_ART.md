# Car art and system damage

The 9 cars use generated top-down art that follows each driver's menu painting, and they show damage per system.

## Files

| Path | What |
|---|---|
| `scripts/art/car_gen.js` | The generator: each car is about 60 numbers (body outline, cabin, wheels, lights, livery). Change a car here. |
| `scripts/art/bake.html`, `scripts/art/bake_cars.py` | The bake: `python scripts/art/bake_cars.py [car ...]` opens `bake.html#<car>` in headless Edge and writes the car's files. Takes about 5 s per car. |
| `scene/car/<car>/art/` | Baked output: `<car>_a0..a2.png` (weathered), `<car>_c0..c2.png` (showroom), `<car>_mask.png`, `<car>_shadow.png`, `<car>_art.tres` and `geometry.json`. |
| `scene/car/car_art_set.gd` | `CarArtSet`, the resource each car scene points at through `art`. |
| `shader/car_damage.gdshader` | Blends the three sheets per system. |
| `scene/car/damage_fx.gd` | Smoke, flames, fuel drips, wheel sparks and headlight flicker (node `damageFx` on `car.tscn`). |
| `tests/game/test_damage.gd` | Hit mapping, cooldown, physics factor, repair, art checks. |

After a bake that adds new PNGs, run `Godot_console.exe --headless --path . --import`, then set `mipmaps/generate=true` in the new sheets' and shadows' `.import` files (not the mask's) and import again. Re-bakes keep the existing `.import` files.

## Sheets

- Every sheet is 272×584 (2× the 136×292 px box, car facing up). The car shows them on `sprite/body` at scale 0.5, with linear filtering and mipmaps, because the default 0.45 zoom shrinks them a lot.
- **Paints:** Weathered (look A) is the default. Showroom (look C) is the cosmetic setting **Car Paint** (`gameplay/car_paint`), and the car swaps it live (`applyArt`).
- **Stages:** like new, dented and wrecked. All three come from the same geometry and seed, so they line up pixel for pixel. The wrecked silhouette is smaller, so crushed corners disappear.
- **Shadow:** a separate sprite (`sprite/shadow`). It is centred, so it reads right whichever way the car faces. It is not part of the sheets, because `carhighlight` uses the sheet as its light texture at night.
- **Geometry:** the scenes' bumper collision polygons, footprint (`carBodyArea`), tyre-mark points, exhaust and lamp offsets were set from `geometry.json`. If a car's outline changes, update those by hand from the new `geometry.json`.

## Systems and zones

`overhead_car_body_2d.gd` owns `condition` (0 to 100 per system). The HUD reads it (docs/HUD.md).

| System | Worn by | In physics (`conditionFactor`, floor at 0%) |
|---|---|---|
| lights | front corner hits | headlight reach (`setHeadlightStrength`), floor 0.35 |
| engine | front centre hits | engine in `integrate()`, floor 0.6 |
| steering | side hits ahead of the middle | steering in `integrate()`, floor 0.7 |
| tires | side hits behind the middle | traction (grip and brakes) in `integrate()`, floor 0.5 |
| tank | rear hits | oil in `fuelBurn`, floor 0.4, plus `fuelLeak` below 50% (up to 0.006 fuel per tick) |

- **Mapping:** `zoneForHit(normal, point, halfWidth)` works in car space. The normal points from the obstacle to the car: x < -0.6 is a front hit, x > 0.6 a rear hit. A front hit is a corner when |y| > 45% of the half width.
- **Wall wear:** `ZONE_WEAR_PER_SPEED` (0.035) × speed × 100 / (armor + 100), so a 500 px/s hit takes 17.5 at armor 0. Hits under 80 px/s don't wear. Each system has a 30-tick cooldown, so scraping along a wall can't empty it.
- **Goons:** a crush never wears the car. A goon bump below crush speed takes `GOON_SCUFF` (2) from the side it hit. Goon attacks only take health.
- **AI:** the factors are applied inside `integrate()`, so the AI driver's prediction matches.
- **Repair:** the station repairs everything (`repairAll`) in the modes where it doesn't end the run. Destroying the car sets every system to 0, so the art goes fully wrecked.

## The shader

`damage[6]` holds hull (1 − health/100) followed by the five systems, each as 0 (like new) to 1 (wrecked). `updateDamageLook()` pushes it only when a value changes.

- **Mask:** R holds the system id × 51, in the order hull, lights, engine, steering, tires, tank. G holds how far damage must spread from that system's impact point to reach the pixel.
- **Blending:** the dented sheet shows where G < damage × 1.6. The wrecked sheet shows where G < (damage − 0.35) × 1.55.
- **Cost:** one draw call and four texture reads per car pixel.

## Damage effects

`damage_fx.gd` has no `_process` while every system is healthy.

| Effect | Starts below | Setting |
|---|---|---|
| Engine smoke (grey, black below 30) | engine 60 | always |
| Flames (unshaded, additive, so they glow at night) | engine or tank 15 | Damage Effects Full |
| Fuel drips on the ground | tank 50 | Full |
| Sparks from a front wheel above 150 px/s | steering 40 | Full |
| Headlights cut out briefly | lights 50 | always (it is information) |

**Damage Effects** (`gfx/damage_fx`) is Low on Potato and Full on the other presets. Pools: 16 puffs and 24 drips. Every timer is delta-based.

## Checking it

```
Godot_console.exe --path . -- --bench=S2 --seconds=14 --shot=6;12 --car=taxi --damage=engine:35;tank:20;lights:60
```

`--damage` holds those conditions for the whole run, and `--car` swaps the scenario's car. Use `SL` (parked at night) to look at flames and flicker.

## Adding a car

1. Add an entry to `CARS` and `ORDER` in `car_gen.js`, and the name to `CARS` in `bake_cars.py`.
2. Bake it and import.
3. Point the car scene's `art` at `<car>_art.tres`, and set its collision and footprint from `geometry.json`.
4. Add the car to `CARS` in `test_damage.gd`.
