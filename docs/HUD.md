# In-run HUD

The HUD is `scene/player/playerRoot.tscn` (class `GameUI`). It was rebuilt in October 2026 from the "A6" concept: twin gauges in the bottom corners, a slim systems strip at bottom center, and slim panels along the top. The concept rounds are claude.ai artifacts; the last one is "GoonCrusher HUD A6". The car damage diagram from that concept was left out on purpose. Showing damage on the car itself comes later.

## Layout (1600 x 900 canvas)

| Node | Script | Anchor | Shows |
|---|---|---|---|
| `TopLeft/CrushPill` | `hud_crush.gd` | top left | Goons left to the next crush goal, its progress bar and the star it pays. |
| `TopLeft/RegionChip` | `hud_region.gd` | top left | Region name, goon size (giantism) and the wave ring: "survive m:ss for a star", up to `Region.waveCap()` waves (no cap in Goonpocalypse). |
| `TopCenter/ModeLabel`, `TopCenter/Timer` | `Timer.gd` (unchanged) | top center | Mode name and run clock. `Timer` keeps group `runTimer`. |
| `Objective` | `hud_objective.gd` | top center, under the clock | The mode's own goal: Goonpocalypse score and time to the star, Marathon "STATION n OF 5", Defense barrier bar. Hidden in Countdown and Sprint. |
| `TopRight` | `hud_payout.gd` | top right | Pause button, coins x stars = payout (`Root.computePayout`), gems. |
| `Tach`, `Fuel` | `hud_dial.gd` | bottom left | Tachometer with the gear (`car.gear`), and the fuel dial. |
| `Speedo`, `Hull` | `hud_dial.gd` | bottom right | Speedometer and the hull (health) dial. |
| `Systems` | `hud_systems.gd` | bottom center | One lamp per car system, each with a rating underline. |

`hud_theme.gd` (class `HudTheme`) holds the colors, the Tektur fonts and the draw helpers.

- **HUD Scale:** every node above is a direct child of PlayerRoot, so `applyHudScale()` scales each one about its anchor. The crush pill and region chip sit inside `TopLeft` because their animations (`NewGoonCrushBonus` and `NewWave`) move and scale them, and HUD Scale would fight that if they were direct children.
- **Speedometer scale:** the speedometer scales to the car. `HudDial.speedScaleFor(car)` takes the car's flat-out speed (engine force against drag and friction, the same terms as `_physics_process`), adds 10%, and rounds up to a multiple of 40, from 80 to 320. The sedan gets 0–120 MPH and the police car 0–160. The green arc starts at 10 MPH, the speed where hitting a goon crushes it.

## Rendering and cost

The widgets draw with `_draw()`, and each one redraws only when its numbers change. Each widget builds a small key every frame and calls `queue_redraw()` when the key differs.

- **Dials:** the face (ticks, numbers, arcs) is drawn once. The needle and readouts are drawn on a child CanvasItem through its `draw` signal. The needle eases toward its target with `1 - exp(-delta * 14)`, which is frame-rate independent. It only redraws once it has moved by a visible step (0.2 MPH, 0.02 thousand RPM, a quarter point of fuel or hull). The speed digits refresh 10 times a second, as before.
- **Strip:** it redraws when a stat, a condition or the headlights change, and every frame only while a pickup pulse or a sub-25% blink is playing.
- **Assets:** there are no new textures. The lamps and the fuel and hull dials use the pickup icons in `texture/icon/` (the plain `.svg` files, not `_flat`), so a pickup flies into its own icon.

## Pickups fly to their widget

`RewardFlyers` sends a pickup's icon to the first node in group `"<powerup>ui"` (`powerup.powerup + "ui"`). The HUD puts a zero-size marker node (`HudTheme.marker`) in each group, at the icon the pickup should land on:

| Pickup | Lands on |
|---|---|
| headlights, engine, steering, traction, oil | Its lamp in the systems strip. The lamp pulses and shows "+1" as the icon arrives (`RewardFlyers.FLIGHT_SECONDS` after the stat changes). |
| health, armor | Hull dial |
| fuel | Fuel dial |
| coin (and purse), gem | The coin icon in the payout and the gem pill |
| luck, clover | The payout (they change what goons drop) |
| currentGoonsCrushed, slotmachine | The crush pill |

`tests/game/test_hud.gd` checks that every powerup scene has a target inside the HUD. (The old pause-screen stat list, `car_panel`, owned these groups and is gone; the pause card shows the stats now.)

## The systems strip

There are five systems, each paired with the stat it scales (`OverheadCarBody2D.SYSTEM_STATS`): lights/`headlights`, engine/`engine`, steering/`steering`, tires/`traction` and tank/`oil`.

- **Lamp:** dimmed while healthy. The headlight lamp is full brightness while the headlights are on (`car.myLights.visible`). Under 70% condition the lamp gets an amber glow, under 40% a red one, and under 25% it blinks.
- **Underline:** the stat against 100, not the 150 cap, because no car's base stat is above 70. It has four parts:
  - **cream:** the rating the run started with (`car.runStartStats`, base plus upgrades)
  - **gold:** what pickups added this run
  - **red:** what damage takes off (`rating * (1 - conditionFactor)`)
  - **dark:** the room left up to 100

  A gold "+N" by the lamp counts the pickups for that stat. A stat over 100 gets a "+" at the end of its line.

## Next step: the damage model

The car already has the hooks; nothing calls them yet. In `overhead_car_body_2d.gd`:

- `condition`: a dictionary from system name to 0–100, starting at 100.
- `CONDITION_FLOOR`: how much of a stat still works at 0% (lights 0.35, engine 0.6, steering 0.7, tires 0.5, tank 0.4).
- `setCondition(system, value)` clamps to 0–100. `conditionFactor(system)` returns `lerp(floor, 1, condition / 100)`.

The HUD reads `condition` every frame, so lamps and red underline segments appear as soon as condition drops. The fuel dial already shows LEAK when `condition.tank` is under 50. To finish the job:

1. **Find the hit side.** In `collideWithFixedObject(collision)`, rotate the normal into car space with `var n = collision.get_normal().rotated(-rotation)`. The normal points from the obstacle to the car, so `n.x < -0.6` is a front hit, `n.x > 0.6` a rear hit, and otherwise it's a side hit (`n.y > 0` is the car's left).
2. **Damage the system.** Front hits wear lights and engine; front corners wear steering; sides wear tires; the rear wears the tank. Scale the wear by speed, as `WALL_DAMAGE_PER_SPEED` does for hull, and reduce it by armor.
3. **Add a cooldown per zone.** `collideWithFixedObject` runs for every slide collision on every physics tick, so a wall scrape would empty a system in under a second.
4. **Apply the factor in physics.** Multiply each stat by `conditionFactor(system)` where it's used: `engine` in the acceleration line, `steering` in `steer_angle`, `traction` in `gripFor()`, and the headlight scale in `setHeadlightStrength()`. For the tank, apply `oil` in `fuelBurn()` plus an extra burn under 50%.
5. **Repair at the station.** Set every condition back to 100 when the car reaches the station.
6. **Decide on goon contacts.** Every goon contact calls `damage(5)` before the crush check. Decide whether a crush also scuffs the front, or the lights will fade during normal play.
7. **Show damage on the car.** The diagram was dropped from the HUD in favor of showing damage on the car the player drives, for example `carDamagedTexture` by zone, smoke or a flickering headlight.
8. **Test it.** Add tests for the hit-side mapping, the cooldown and the factor in physics.

Condition is per run, so the save format doesn't change.

## Later

- **Per-car skins:** colors, dial faces and speedometer scale, via a `HudSkin` resource on `CarInfo`. Concept round 1 lists ideas for each car.
- **Timed powerups:** if T2-7 in `docs/GAMEPLAY_SUGGESTIONS.md` lands, its drain bars fit at the strip's right end.
