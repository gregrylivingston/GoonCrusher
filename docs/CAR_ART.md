# Cars: art, damage, handling and feel

A car's numbers are data: stats, weight, traits, gears, redline and dashboard in `scene/car/<car>/<car>_info.tres` (`CarInfo`); handling numbers in `CarHandling`; trait numbers in the car script and `CarTraitRig`. This doc is the map and the rules that are easy to break.

## Files

| Path | Owns |
|---|---|
| `scripts/art/car_gen.js` | The generator (`CARS`, `ORDER`). Change a car's look here. |
| `scripts/art/bake.html`, `bake_cars.py` | The bake (below). |
| `scene/car/<car>/art/` | Baked output: sheets, mask, shadow, `<car>_art.tres` (`CarArtSet`), `geometry.json`, `<car>_side.png`. **Never edit these.** |
| `shader/car_damage.gdshader`, `scene/car/damage_fx.gd` | The damage look: sheet blending per system; smoke, flames, drips, sparks. |
| `lib/overhead_car_2d/overhead_car_body_2d.gd` | The car: `integrate()`, damage, the gearbox, horn, lights. |
| `lib/overhead_car_2d/car_handling.gd` | `CarHandling`: stats and weight to handling numbers. |
| `scripts/global/car_traits.gd`, `lib/overhead_car_2d/car_trait_rig.gd` | Traits: the registry and the rules. |
| `lib/overhead_car_2d/car_trailer.gd` | The semi's trailer. |
| `scene/fx/car_juice.gd` | `CarJuice`: lean, bounce, trails, engine and tire sound. |

Each has its test in `tests/game/` (`test_damage`, `test_car_side`, `test_handling`, `test_gearbox`, `test_traits`, `test_trailer`, `test_car_juice`).

## Baking

1. `python scripts/art/bake_cars.py [--job sheets|side] [car ...]` (headless Edge, about 5 s a car; no `--job` runs both). Baking `semi` also bakes its trailer (`EXTRA`).
2. `Godot_console.exe --headless --path . --import`.
3. For new sheets and shadows (not the mask) set `mipmaps/generate=true` in their `.import` and import again. Re-bakes keep existing `.import` files and uids.

If headless Edge prints nothing on a machine, any renderer that gives `car_gen.js` a 2D canvas and prints `bake.html`'s JSON works (`@napi-rs/canvas` in Node does).

- The three damage stages share geometry and seed, so they line up pixel for pixel.
- The shadow is its own sprite, not part of the sheets: `carhighlight` uses the sheet as its light texture at night.
- **If a car's outline changes, update the scene by hand from the new `geometry.json`:** bumper collision polygons, `carBodyArea`, tire-mark points, exhaust and lamp offsets.

## Side views

`CarArt.renderSide` in `car_gen.js` draws a side profile from the same parts as the sheets (`--job side`), used by the menu through `CarInfo.sidePic`. It is not in `CarInfo.FIELDS`, because the car itself doesn't need it. Each car is fitted to the frame on its own, facing right. The menu draws outlines from its alpha, so it has no soft shadow.

## Systems and zones

The car owns `condition` (0 to 100) for five systems, each paired with the stat it scales (`SYSTEM_STATS`): lights/headlights, engine/engine, steering/steering, tires/traction, tank/oil. `conditionFactor(system)` scales the stat, never below `CONDITION_FLOOR`; a worn tank also leaks fuel (`fuelLeak`).

- **Which system a hit wears:** `zoneForHit` in car space: front center engine, front corners lights, sides ahead of the middle steering, behind it tires, rear tank.
- **Wear:** wall hits wear by speed and armor, with a per-system cooldown so scraping can't empty a system. A crush never wears the car; a goon attack wears the system it targets (`Walker.hitCar`).
- The factors are applied inside `integrate()`, so the AI's predictions match.
- **Look:** `updateDamageLook()` pushes `damage[6]` (hull, then the five systems) to the shader only when a value changes.
- **Effects:** `damage_fx.gd` has no `_process` while every system is healthy. Engine smoke and headlight flicker always show (they are information); the rest need Damage Effects Full (`gfx/damage_fx`).

### Health damage

`damage(amount)` takes the health a car with no armor would lose, times `armorFactor(armor)` (`ARMOR_FLOOR`, `ARMOR_KNEE`): a little armor helps a lot and a lot never makes the car immune. Armor is applied once, there. What each thing costs is a constant at its source (`Goons.DATA` `dmg`, the car's `*_DAMAGE*` constants, `Spill`, `World.hurt`).

- Water goes through `damage(amount, true)`: armor counts, a shield or golden ride doesn't stop it, being airborne does (docs/WORLD.md, "Water").
- `loseHealth` skips armor and shields. A Bubble Shield soaks everything but water.

## Handling

`integrate()` is one tick of a bicycle model and **must stay pure** (no side effects): the AI driver predicts with it thousands of times a tick, so everything it calls is read only and allocation-free. `CarHandling.tune` is one shared instance holding every number.

- Every stat goes through `CarHandling.dim()` first (diminishing returns), so upgrades and pickups sharpen a car without erasing its character.
- **Steering** sets how fast the wheel reaches full lock and the turn rate. **Traction** sets grip (how fast the travel swings to the nose) and brakes. **Engine** sets the push and reverse speed.
- **Weight** (`CarInfo.weight`, 0 to 100, never upgraded) is the character: heavy cars turn in slower, slide wider, brake longer, bounce less off walls, hold a handbrake slide longer and take longer to reach the same top speed. A heavy car also crushes goons at a lower speed (`crushWeight`).
- Every car gains speed more slowly the faster it goes (`CarHandling.pickup`); it scales only rising speed, so top speed and slowing down are untouched.
- The ground multiplies grip, friction and brakes (`World.surfaceAt`).
- Walls are handled after `move_and_slide`, outside `integrate()` (`wallResponse`, `wallDeflect`): a hard hit bounces, a glancing one turns the nose along the wall.
- The camera leads the car (`updateLookAhead`) and adds only its own change to `Camera2D.offset`, which CrushFeel shares.

**Tuning:** the dev console's `handling` command changes `CarHandling.tune` live for every car (nothing is saved). `scripts/debug/handling_lab.gd` (run with `-s`; options in its header) drives every car's real `integrate()` through set maneuvers and prints a row per car. `test_handling.gd` holds every car, stock and maxed, to bands, so a retune that breaks a car fails there.

## Traits

Every car lists exactly two in its `CarInfo.traits`; `CarTraits.DATA` has each one's kind, name and text. The kind decides where it lives:

- **Physics** changes handling inside `integrate()`, through a cached flag (`cacheTraits`: `second_wind` becomes `tSecondWind`) read by the helpers `surfaceGrip`, `traitGrip`, `traitSteer`, `groundFriction`, `handbrakeGrip`, `effectiveWeight`.
- **Mechanic** and **Ability** are rules in `CarTraitRig`, a child the car ticks after its own move. The rig also holds the state the physics flags read.
- **Ability** has its own button, the Ability action.

**Adding a trait:**
1. Add it to `CarTraits.DATA` and to a car's `traits`.
2. Draw its icon in `scripts/art/pickup_icons.js` (`trait_<id>`) and run it.
3. Add the `t<Name>` flag to the car. Put handling in the integrate helpers, rules in `CarTraitRig`.
4. Add a test to `test_traits.gd`.

## Gearbox

Cars with `CarInfo.gears` above 0 are manual; 0 is an automatic, which only shows gears (tach and engine note). The model is in the car script under "the gearbox"; `gearThrust()` is read inside `integrate()`.

- Gear spacing comes from the car's cruising top speed at run start (`setupGearbox`). The last gear has no limiter and stays flat, so a manual's top speed matches an automatic's.
- A shift cuts the push briefly; a shift up near the top of the gear's band earns a kick instead. Only a lever earns it.
- **Who shifts** (`isManual`): the player, unless Automatic Gearbox (`gameplay/auto_gearbox`) is on; an AI driver when its profile says so (`CarDriver.shiftsByHand`). Otherwise `autoGear`.
- The tach and the engine pitch both read `revShare()`.
- After changing a gear count, the gearbox constants or `CarHandling.pickup`, run the tests and read the `GEARS` lines `test_every_car_climbs_through_its_gears` prints.

## Horn and weight

Every car's horn has its own sound, `sound/horn/<carId>.wav`, baked by `scripts/art/horn_sounds.py`; goons in a cone ahead flinch (`honk`, `HORN_*`). Weight crushes: see "Handling".

## Trailer

The semi's trailer (`CarTrailer`, the `trailer` node in `semi.tscn`) is its own top-level `CharacterBody2D` that the car moves once a tick after its own move (`follow()`). It is not part of `integrate()`, so the AI predicts the tractor alone. `car_gen.js` draws tractor and trailer as two cars (`semi`, `semiTrailer`).

- Being top level, it sets its own z ordering and carries the car's tail lamps (`syncLights`).
- The hitch is rigid (`hold()`): the two never part and nothing gets between them.
- A hit damages the truck, judged by the trailer's real speed coming in, **never the push that corrects it** (that fed back into its swing and wrecked a semi in seconds).
- The tractor's drawn axles are further apart than its `wheel_base`: at the drawn length its turn was too wide and the AI semi got stuck far more often. Keep the two apart.
- `test_a_folded_trailer_clears_the_cab` checks the geometry against the bake, so re-run it after changing either car.

## Driving feel

`CarJuice` is **show only**: it reads the car each physics tick after the car moves and never writes its velocity, input or stats, so handling and the AI's predictions don't change. It moves `sprite/body` and `sprite/shadow`, emits pooled particles and sets engine and tire sound. Callers: `collideWithFixedObject` (`onWall`), `tickDriftCharge` (`driftBoost`), `Gadgets.land` (`land`).

- Its random rolls use their own RNG, so seeded runs are unchanged. Only the player's car has one.
- Driving Effects (`gfx/driving_fx`) sizes the pools; Reduce Motion, Car Shake and Screen Shake calm it.

## Checking damage art

Bench option `--damage=engine:35;tank:20;lights:60` holds those conditions for the run (with `--car=` and `--shot=`); scenario `SL` (parked at night) shows flames and flicker.

**Headlights:** `setHeadlightStrength` turns the stat times the lights' condition into the lamps. The beam's `scale.x` is the reach, which the AI's sight reads.

## Adding a car

1. Add it to `CARS` and `ORDER` in `car_gen.js` (with its `side` heights) and to `CARS` in `bake_cars.py`.
2. Bake and import. Set `sidePic` in its `<car>_info.tres`.
3. Point the scene's `art` at `<car>_art.tres` and set collision and footprint from `geometry.json`.
4. In `_info.tres` give it `weight`, `redline`, two `traits` and, if it has them, `gears` and a `hudSkin` (docs/HUD.md, "Dashboards").
5. Add it to `CARS` in `test_damage.gd`, `test_handling.gd` and `handling_lab.gd`, and check its lab row and `GEARS` line.
