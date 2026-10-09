# Car art and system damage

The 9 cars use generated top-down art that follows each driver's menu painting, and they show damage per system.

## Files

| Path | What |
|---|---|
| `scripts/art/car_gen.js` | The generator: each car is about 60 numbers (body outline, cabin, wheels, lights, livery). Change a car here. |
| `scripts/art/bake.html`, `scripts/art/bake_cars.py` | The bake: `python scripts/art/bake_cars.py [--job sheets\|side] [car ...]` opens `bake.html#<car>` in headless Edge and writes the car's files. Takes about 5 s per car. With no `--job` it runs both jobs. Baking `semi` also bakes its trailer (`EXTRA`: `car_gen.js`'s `semiTrailer`, written as `semi_trailer_*`, with `semi_trailer_geometry.json` and `semi_trailer_art.tres`). If headless Edge prints nothing (it can't run on every machine), any renderer that gives `car_gen.js` a 2D canvas and prints `bake.html`'s JSON works; `@napi-rs/canvas` in Node matched Edge to within 0.2% of pixels. |
| `scene/car/<car>/art/` | Baked output: `<car>_a0..a2.png` (weathered), `<car>_c0..c2.png` (showroom), `<car>_mask.png`, `<car>_shadow.png`, `<car>_art.tres` and `geometry.json` (the `sheets` job), and `<car>_side.png` with its `.import` (the `side` job). |
| `tests/game/test_car_side.gd` | Every `CarInfo` has a `sidePic` of the baked size, with alpha, standing on the bottom pad. |
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

## Side views

Each car also has a "rust and dust" side profile in the weathered paint (look A), for the menu. The level select's car strip draws it at about 45×18 (the current car a little bigger), and later it may go on the driver cards and the results ticket. The menu also draws a dark silhouette of it through a modulate, so its alpha edge has no soft shadow.

- **Generator:** `CarArt.renderSide(key, opts)` in `car_gen.js`. It reads the same parts, cabin, doors, filler, wheels, lights, bumpers, mirrors, paint, grime and feats as the sheets, so it is the same car. Each car's `side` entry adds the heights: `sill`, `nose`, `hood`, `belt`, `roof`, `deck`, `tail`, the corner radii, `winR` (where the side glass ends on a car with no back glass), `box` (a trailer or box part's bottom and top) and `rim` (steel, white or dark). The car faces right: side x is the top-down's -y, so a feature at top-down y sits at x = -y.
- **Look:** faded paint, bleached more on top; dust thickening toward the ground and sprayed around the wheels; rust at the arches and sills; rain streaks; dark glass, dusty along the bottom; tyres with a hint of tread and a dusty rim. The light is from above: the top surfaces (hood, roof, deck) carry a lighter band, and the flank darkens toward the sill. Features: the sedan's primer hood, the taxi's checker band and roof sign, the police two-tone and light bar, the racer's stripes on the top band and its hood scoop, the supercar's side intake, splitter and wing, the pickup's bed, the semi's stacks, fuel tank, chassis and trailer, and the ambulance's box, stripe, cross and lamps. A filler cap shows only if it is on the car's left, the side the view shows.
- **Size:** 256×96 (`SIDE.W`, `SIDE.H`), with 2 px clear on every side (`SIDE.PAD`). Each car is fitted to that frame on its own, tyres on the bottom pad and centred across, so the semi and the ambulance are height-limited and the cars are width-limited. It is drawn 4× larger (`SIDE.SS`) and halved twice, which keeps thin details and the edge clean. `opts.w`, `h`, `pad`, `ss` and `style` render it at other sizes for larger uses; re-bake if the menu needs a bigger file. The canvas's `frame` gives the scale in px per game unit and where x = 0 and the ground land.
- **Bake:** `python scripts/art/bake_cars.py --job side [car ...]`. It writes `<car>_side.png` and its `.import` (lossless, mipmaps on; an existing `.import` keeps its uid), then run `--import`. It never touches the sheets.
- **Use:** `CarInfo.sidePic` (`scene/car/car_info.gd`), set in each `<car>_info.tres`. It is not in `CarInfo.FIELDS`, because the car itself doesn't need it.

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
- **Wall wear:** `ZONE_WEAR_PER_SPEED` (0.035) × speed × `armorFactor(armor)`, so a 500 px/s hit takes 17.5 at armor 0. Hits under 80 px/s don't wear. Each system has a 30-tick cooldown, so scraping along a wall can't empty it.
- **Goons:** a crush never wears the car. A goon bump below crush speed takes `GOON_SCUFF` (2) from the side it hit. A goon attack takes health and wears the system it targets by 3 × its `dmg` (`Walker.hitCar`).

### Health damage

Health is 100. `damage(amount)` takes `amount` as the health a car with no armor loses, times `armorFactor(armor)` = `ARMOR_FLOOR + (1 - ARMOR_FLOOR) × ARMOR_KNEE / (ARMOR_KNEE + armor)` (0.4 and 20). A little armor helps a lot and a lot never makes the car immune:

| Armor | 0 | 10 | 20 | 50 | 90 | 150 (in-run cap) |
|---|---|---|---|---|---|---|
| Share of a hit taken | 100% | 80% | 70% | 57% | 51% | 47% |

What things cost a bare car: a goon attack its `dmg` in `Goons.DATA` (1 to 12, ×2 for a giant; a typical lunge 3, a Wrecker 12); a crush or bump `GOON_CONTACT_DAMAGE` (0.35, once per goon per 30 ticks); a wall hit `WALL_DAMAGE_PER_SPEED` (0.012) × speed × impact (6 for a 500 px/s head-on); a wall scrape at most 0.3 every 15 ticks; logs, crates and air drops 6, 8 and 10 (`Spill`); a bee sting 0.5 every 0.4 s. A Repair Kit heals 20. `loseHealth` (a Hot Potato) skips armor and shields. A Bubble Shield soaks everything but only spends a charge on hits over 5.
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

## Handling

`OverheadCarBody2D.integrate()` is one tick of a bicycle model: the heading comes from the front and rear wheels, and the travel swings toward the heading by the grip each tick. `CarHandling` (`lib/overhead_car_2d/car_handling.gd`) turns the stats into its numbers. One shared instance, `CarHandling.tune`, holds every number, so the dev console's `handling` command changes them live for every car (and the AI's predictions follow). Nothing it sets is saved.

Every stat goes through `CarHandling.dim()` first (`stat × 60 / (stat + 60)`), so upgrades and pickups sharpen a car with diminishing returns instead of erasing its character. **Weight** (`CarInfo.weight`, 0–100, never upgraded) is the character. The values are racer 15, audi 30, sedan 35, taxi 45, police 50, pickup 65, van 70, ambulance 80, semi 100.

| What | Rule | Stats |
|---|---|---|
| The wheel | The controller moves it toward the keys (or the stick, `Input.get_axis`) at `steerRate()`: full lock in `steerTimeSlow` 0.20 s to `steerTimeFast` 0.06 s by steering, ×0.85 to ×1.3 by weight. Back toward the centre (letting go, easing off, counter-steering) is `steerReturn` (2.5) times quicker, and it stops at the centre before it turns the other way. | steering, weight |
| Turn rate | At full input the wheel turns the car at `yawAt`: `yawLow` 1.7 to `yawHigh` 3.2 rad/s by steering, ×1.15 to ×0.8 by weight, easing to ×0.8 from 650 to 1,700 px/s so top speed isn't twitchy. Slower, the full lock (`wheelLow` 34° to `wheelHigh` 44°) limits it, so the turn builds from a crawl to full by about 200 px/s. | steering, weight |
| Grip | The share of the gap between travel and nose closed per tick: `gripSlow*` (0.6–0.9) below 60 px/s blending to `gripFast*` (0.10–0.30) by 260 px/s, by traction, ×1.15 to ×0.8 by weight (heavy cars slide wider). The ground's grip multiplies it. The travel swings keeping its length; `turnScrub` (0.08 per radian) and `thrustSteerCut` (12% of the push at full lock) are what a corner costs. | traction, weight |
| Engine | The push is unchanged (`(engine + 14) × 22`). Weight scales engine, drag and friction together (`inertia`, ×1.1 to ×0.85), so a heavy car has the same top speed and takes longer to reach it. Reverse tops out at `reverseBase` 250 + 6 × dim(engine) px/s. | engine, weight |
| Brakes | Speed comes off at `brakeLow` 650 to `brakeHigh` 1,600 px/s² by traction, ×1.1 to ×0.8 by weight, times the ground's brake, down to zero and never past it. Stopped, Brake reverses. | traction, weight |
| Walls | A fresh hit loses speed once (`wallSpeedKeep`). Going in at `bounceMinSpeed` 150 px/s or more, it bounces back `bounceLight` 0.35 to `bounceHeavy` 0.12 of the speed into the wall. Staying against it keeps `scrapeKeep` 99.5% a tick. A nose (or a tail in reverse) meeting a wall within `deflectMaxAngle` 55° of glancing turns `deflect` 25% of the way along it each contact tick, so the car slides off instead of grinding (`wallResponse`, `wallDeflect`). | weight |
| Camera | Leads the car by `lookAhead` 0.3 s of travel, up to 450 px, catching up at 3/s; half with Reduce Motion (`updateLookAhead`). It adds only its own change to `Camera2D.offset`, which CrushFeel shares. | |

The handbrake (`HANDBRAKE_*`) is unchanged, except that weight, not armor, sets how long it slides. Damaged steering, engine and tyres scale their stat before any of this.

**Checking it:** `scripts/debug/handling_lab.gd` drives every car's real `integrate()` and steering through set manoeuvres and prints one row per car: top speed, ticks to full lock, turn rate at 200, 400 and 600 px/s and top speed, a held circle, a 90° turn from top speed, the stop and reverse.

```
Godot_console.exe --headless --path . -s res://scripts/debug/handling_lab.gd -- --up=0,20 --ground=grass,asphalt
```

`tests/game/test_handling.gd` holds every car, stock and maxed, to the bands: 1.3 to 2.6 rad/s at 500 px/s (and the stock cars at least 1.25× apart), full lock in 0.09 to 0.26 s, a stop from 1,000 px/s within 2.5 s, reverse under 500 px/s, and at least 80% of the speed kept through a 90° turn.

Stock cars on grass after the first fit (2026-10-09). Before, the stock sedan took 20 ticks to full lock, turned 0.6 rad/s at 200 px/s and lost 25% through a corner, while maxed cars reached full lock in 3 ticks and turned 3.1 rad/s:

| Car | Top px/s | Full lock | Turn rad/s at 200 / 600 / top | 90° from top speed | Stop from top | Reverse px/s |
|---|---|---|---|---|---|---|
| sedan | 745 | 10 ticks | 1.89 / 1.84 / 1.84 | 1.07 s, 88% kept | 0.9 s | 272 |
| van | 693 | 13 | 1.59 / 1.56 / 1.55 | 1.25 s, 88% | 0.9 s | 258 |
| semi | 906 | 13 | 1.49 / 1.46 / 1.44 | 1.37 s, 88% | 1.3 s | 307 |
| audi | 1,417 | 9 | 2.11 / 2.05 / 1.85 | 1.03 s, 89% | 1.2 s | 409 |
| racer | 1,553 | 9 | 2.11 / 2.02 / 1.77 | 1.08 s, 89% | 1.4 s | 417 |

## Traits

Every car has signature features beyond its stats (`scripts/global/car_traits.gd`, `CarTraits`). A car lists them in its `CarInfo` (`traits`, edited in `<car>_info.tres`). The garage card shows them as badges along the foot of its art (`DriverCard.traitBadge`; a third wraps onto a second row), and the Goonopedia's Cars tab explains each under **Signature** (`signatureRows`). Each has an icon, `texture/icon/trait_<id>.svg`, drawn by `scripts/art/pickup_icons.js`.

Each trait has a kind, and its kind decides where it lives:
- **Physics** changes handling inside `integrate()`, so the AI driver's predictions follow it. The car caches one flag per trait in `_ready` (`cacheTraits`: `second_wind` becomes `tSecondWind`), and `integrate()` reads them through `surfaceGrip`, `traitGrip`, `traitSteer`, `groundFriction`, `handbrakeGrip` and `effectiveWeight`.
- **Mechanic** and **Ability** are rules on top. They live in `CarTraitRig` (`lib/overhead_car_2d/car_trait_rig.gd`), a child the car makes when it has any trait and ticks after its own move. The rig also holds the state the physics flags read (`twoWheels`, `loadDropped`).
- **Ability** has its own button: the **Ability** action (F, pad B), rebindable in Settings.

| Car | Trait | Kind | What it does | Where |
|---|---|---|---|---|
| Sedan | Second Wind | Mechanic | Once a run, an empty tank restarts with 10% fuel | `outOfFuel` |
| Sedan | Duct Tape | Mechanic | After 3 s with no damage or wear, systems patch back up to 60% (+2 a second) | `CarTraitRig.tickTape` |
| Van | Cargo Bay | Mechanic | A second gadget slot (`spareItem`); it moves up when the first runs out | `giveItem`, `useItem` |
| Van | Top-Heavy | Physics | Turning at 85% of its limit above 450 px/s for 0.2 s lifts it onto two wheels: grip ×0.6, wheel ×0.85. Up for 1.25 s, or a wall hit while up, rolls it (speed ×0.35, 6 health, steering wear, 0.75 s without control) | `CarTraitRig.tickTip`, `roll` |
| Taxi | The Meter | Mechanic | Above 300 px/s, a coin per 450 px, one more per 10 s of clean running (up to 3); a wall hit or dropping under 120 px/s resets it | `CarTraitRig.tickMeter` |
| Taxi | City Tyres | Physics | Grip ×1.15 on asphalt, lots, bridges and wash; ×0.85 on dirt and rough ground | `surfaceGrip` |
| Pickup | Off-Road Suspension | Physics | Feels 30% of rough ground's extra friction and gets back 60% of its lost grip | `groundFriction`, `surfaceGrip` |
| Pickup | Loaded Bed | Mechanic | Each pickup collected loads a crate (up to 5, drawn in the bed), each +5% payout (`Level.runPayout`); a hit at 300 px/s spills one | `CarTraitRig.onRewarded`, `payoutBonus` |
| Supercar | Downforce | Physics | Grip ×0.8 below 300 px/s rising to ×1.6 by 1,100 | `traitGrip` |
| Supercar | Low Clearance | Physics | Feels rough ground's extra friction ×1.6, and loses 1.5 engine condition every half second on it above 250 px/s | `groundFriction`, `CarTraitRig.tickScrape` |
| Racer | Drift King | Physics | Handbrake grip ×0.75, catches at 78°, charges 40% faster, and a third, purple tier at 160 ticks (+380 px/s) | `handbrakeGrip`, `tierFor` |
| Racer | Featherweight | Physics | A goon it fails to crush bounces it off (45% of its speed) | `_physics_process` |
| Police | PIT Maneuver | Mechanic | Flank and tail slams cost no health and fling ×1.5 | `slamGoons` |
| Police | Lightbar | Mechanic | At night a red and a blue light, 900 px, flash round the car | `CarTraitRig.buildLightbar` |
| Ambulance | Defibrillator | Mechanic | Once a run, 0 health comes back to 30 (not drowning) | `defibrillate` |
| Ambulance | Box Sway | Physics | Braking above 200 px/s: wheel ×1.2, grip ×1.1; full power through a hard corner above 400: grip ×0.8 | `traitGrip`, `traitSteer` |
| Semi | Fifth Wheel | Physics | The trailer (below) | `CarTrailer` |
| Semi | Unstoppable | Physics | Smashes every breakable but explosives at any speed, the trailer too | `smashThreshold` |
| Semi | Drop the Load | Ability | 7 crates out the back: goons under them are crushed, the rest stand as a barrier for 25 s and spill no coins. Empty, the rig is 25 weight lighter until it restocks in 40 s | `CarTraitRig.dropLoad` |

The numbers are first guesses. The handling ones are constants on the car (`CITY_GRIP`, `DOWNFORCE_*`, `TWO_WHEEL_*`, `SWAY_*`, `DRIFT_KING_*`, `LOAD_WEIGHT`, `FEATHER_BOUNCE`), the rules' are on `CarTraitRig`. `tests/game/test_traits.gd` covers every trait.

**Adding a trait:** add it to `CarTraits.DATA` and to a car's `traits`, draw its icon in `pickup_icons.js` (`trait_<id>`) and run it, then add the `t<Name>` flag to the car (`cacheTraits` sets any flag named after the id). Put handling in the integrate helpers and rules in `CarTraitRig`, and give it a test.

## Horn and weight

**Horn.** Every car has a horn on the **Horn** action (Q, pad Y; rebindable). Each plays its own sound, `sound/horn/<carId>.wav`, baked by `scripts/art/horn_sounds.py`: the sedan's tired bleat, the van's low honk, the taxi's double honk, the pickup's beep-beep, the supercar's sharp honk, the racer's chirp, the police whoop, the ambulance's yelp, the semi's air horn. Goons within `HORN_RANGE` (450 px) and `HORN_CONE` (0.9 rad either side of the nose) flinch, stunned for 0.6 s and shoved away, like the Air Horn gadget in miniature (`Gadgets.stun`). Cooldown 1.2 s (`honk`, `tickHorn`).

**Weight crushes.** A heavy car meets a goon's crush speed sooner and a light one later: `crushGoon` passes `tryCrush` the car's speed times `crushWeight()` = 1 / (1 + (0.5 − weight share) × 0.6). Weight 50 crushes as before, the semi at 70% of the speed (75% with its load dropped), the racer needs about 120%.

## Trailer

The semi pulls a trailer on a fifth wheel (`lib/overhead_car_2d/car_trailer.gd`, `CarTrailer`, the `trailer` node in `semi.tscn`). The car is the tractor; the trailer is its own `CharacterBody2D` (top level, layer 1) that the car moves once a physics tick, after its own move (`follow()`). It is not part of `integrate()`, so the AI driver's predictions drive the tractor alone.

**Art.** `car_gen.js` draws the semi as two cars on their own canvases (`box`): `semi`, the tractor (136 × 190, centred between its steer axle and drive tandem, its frame, fifth-wheel plate, air lines and mud flaps running on behind the cab), and `semiTrailer`, a US-style 53 ft box (136 × 330: 310 long, about 2.2 times the tractor, ribs, amber side markers, rear doors). Being top level, it leaves the car's z ordering, so it sets its own (`z_as_relative` off): its body one above the car, over the tractor's frame, fifth wheel and drive tyres (and the cab when it folds), its shadow one below. Its zone mask is hull, with tyres by its tandem; its hits wear the truck's tyres. The car's taillamps and a copy of its night silhouette light ride on the trailer (`syncLights`).

**Geometry** (tractor space, x forward): kingpin `(-59, 0)` (the plate), trailer axles `length` 248 behind it, the trailer's box 306 × 96 from 8 ahead of the kingpin. The cab's back is 55 ahead of the kingpin and the trailer's front corners sweep 51 round it (8 of nose, 48 of half width), so a folded trailer clears the cab at any angle up to the stop (`test_a_folded_trailer_clears_the_cab` checks it against the baked geometry). The tractor's drawn axles are 128 apart, but its `wheel_base` (the handling's) is 90: at 128 its tightest turn grew about 40% and the AI semi got stuck half as often again (91 stuck events in 8 runs against 42).

**Motion.** The trailer pivots on the kingpin with its own turn rate, `spin`. The rate at which its axles wouldn't slide sideways is the kingpin's sideways speed over `length`; each tick the tyres pull `spin` toward it by `CarHandling.trailerGrip` (0.35, times the ground's grip), capped at `MAX_SPIN` 5 rad/s. So it cuts inside corners, lags into a flick and swings past it after, swings wide on ice, and reversing straight it folds (about 2.6 s from 3° to the stop at 200 px/s) unless the driver steers it straight. The fold stops at `trailerJackknife` 80°, where it turns with the tractor and takes `trailerFoldDrag` 3% of the tractor's speed a tick.

**Contact.** Walls stop it (`move_and_slide`), and a hit damages the truck through `collideWithFixedObject(..., respond = false, zone = "tires")`, judged by the trailer's real speed coming in (never the push that corrects it; that fed back into its swing and wrecked a semi in seconds). Blocked, it stops swinging. The hitch is rigid (`hold()`): wherever the trailer ended up, the tractor is moved (as a body, `move_and_collide`) to keep the kingpin exactly `length` ahead of its axles and loses the speed that would pull it away; if the tractor can't move either, the trailer goes to the kingpin. So the two never part, and nothing can get between them: a log or rock stops the whole rig instead. Breakables smash and cones fly as for the car. Its sides and tail swat goons like the car's flanks (`slamGoons`, counting its swing); its nose, under the cab, doesn't.

**Spawn and teleports.** It is placed straight behind the tractor once the car is placed (`placeBehind`, deferred from `attach`), and again whenever the kingpin is more than two trailer lengths away.

`tests/game/test_trailer.gd` covers it: placement, cutting inside, the reverse fold and its stop, a teleport, low grip, and a snagged trailer staying calm.

## Driving feel

`scene/fx/car_juice.gd` (`CarJuice`, package 13) gives the player's car its feel. It is show only: it reads the car each physics tick after the car moves and never writes its velocity, input or stats, so handling and the AI's predictions don't change. The car calls it from `collideWithFixedObject` (`onWall`) and `tickDriftCharge` (`driftBoost`), and `Gadgets.land` calls `land`.

| Part | What it does | Where to tune it |
|---|---|---|
| Lean (D-1) | The car's measured acceleration, smoothed, moves `sprite/body` and `sprite/shadow` on a spring. Sideways acceleration leans the body out of the turn: it slides out and narrows, and the shadow moves the other way. The lean is measured against the car's own grip limit (`maxLateral`: the car's turn rate at top speed times top speed) on a curve (`LEAN_CURVE` 1.8), so an ordinary turn only settles the suspension (half the limit leans 0.29) whatever the car and its upgrades. Two wheels need 90% of the limit held for 0.4 s at 60% of top speed or more (lean 1.6, smoke off the outer tyres). The car drops back below 65% with a bounce and a thud. | `LEAN_CURVE`, `ROLL_*`, `TWO_WHEEL_*`, `LEAN_SPRING`/`LEAN_DAMP` |
| Weight (D-2) | Braking dips the nose and launching, drift boosts and upshifts squat it, all from the same acceleration. A height spring bounces the body (scale and shadow) on two-wheel landings, Hop and Jump Jets landings, wall hits and road-to-rough ground changes. Wall hits add CrushFeel kick and trauma, scaled by the speed into the wall. | `PITCH_*`, `BUMP_*`, `HEIGHT_*`, `WALL_KICK_*`, `WALL_TRAUMA_*` |
| Ground (D-3) | Per-surface trails from the rear tyres (`TRAILS`: dust on sand, dirt, wash and snow; clods on mud, oil, grass and ice; spray from all four tyres in shallows). Tyre smoke on hard ground in a slide. Wall-scrape and wall-hit sparks. A drift boost fires a flame and glow in the tier colour with a 2% zoom pull per tier. | `TRAILS`, `LEVELS`, `SPEED_LINES_FROM`, `FLAME_SECS`, `BOOST_ZOOM` |
| Sound (D-4) | Engine pitch climbs through each 300 px/s gear and glides down at the shift (the controller's `car.gear` rule), 5 dB quieter off the throttle. Tyre squeal volume and pitch follow slip, a locked brake or two wheels, and a charged drift sings higher. Lifting off above 250 px/s backfires half the time (a pop and a flash at the exhaust). | `PITCH_*`, `SQUEAL_*`, `BACKFIRE_*` |

**Settings:** Driving Effects (`gfx/driving_fx`; Minimal on Potato, Reduced on Low, else Full) sizes the particle pools (`LEVELS`). Reduce Motion drops the jolts and bounces and calms the lean to 40%. Car Shake Off drops the bounces and jolts. Screen Shake scales the wall jolts through CrushFeel. Particles are two pooled nodes (dust with normal blending, sparks additive and unshaded so they glow at night). The show-only rolls use their own RNG so seeded runs are unchanged. Only the player's car has one; other cars keep the old engine pitch and squeal.

## Lights and the Headlights stat

`setHeadlightStrength` turns the Headlights stat (times the lights' condition) into the lamps. Reach is `1 + stat/100` (the beam's `scale.x`, which the AI's sight reads). Width (`LIGHT_WIDTH` 0.7) and brightness (`LIGHT_GLOW` 0.9, on each lamp's authored energy) grow on `sqrt(stat/100)`, so the first upgrades show. The tail lamps grow (`TAIL_GROW` 0.6, per lamp, so they stay on the bumper) and brighten (`TAIL_GLOW` 1.2). They are faint cruising (`TAIL_DIM` 0.1) and bright when braking, handbraking or reversing (`TAIL_BRIGHT` 0.35). Flood Lights multiply the reach and width. Goons' headlight checks (`GoonVerbs.inHeadlights`) use fixed distances. Lighting Low (Potato) turns the tail lamps off.

## Checking it

```
Godot_console.exe --path . -- --bench=S2 --seconds=14 --shot=6;12 --car=taxi --damage=engine:35;tank:20;lights:60
```

`--damage` holds those conditions for the whole run, and `--car` swaps the scenario's car. Use `SL` (parked at night) to look at flames and flicker.

## Adding a car

1. Add an entry to `CARS` and `ORDER` in `car_gen.js` (with its `side` heights), and the name to `CARS` in `bake_cars.py`.
2. Bake it and import. Set `sidePic` in its `<car>_info.tres` to `<car>_side.png`.
3. Point the car scene's `art` at `<car>_art.tres`, and set its collision and footprint from `geometry.json`.
4. Add the car to `CARS` in `test_damage.gd`, `test_handling.gd` and `handling_lab.gd`, give it a `weight` in its `_info.tres`, and check its row in the handling lab.
