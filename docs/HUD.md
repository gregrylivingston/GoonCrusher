# In-run HUD

The HUD is `scene/player/playerRoot.tscn` (class `GameUI`): twin gauges in the bottom corners, a slim systems strip at bottom center, and slim panels along the top. Damage shows on the car itself (docs/CAR_ART.md).

## Layout (1600 x 900 canvas)

| Node | Script | Anchor | Shows |
|---|---|---|---|
| `TopLeft/CrushPill` | `hud_crush.gd` | top left | The next gift box (docs/PICKUPS.md, "Gift boxes"): its tier in its colour, a crush XP bar and the XP still to go. Prize pickups fly to its box (`slotmachineui`). |
| `TopLeft/RegionChip` | `hud_region.gd` | top left | District name, goon size (giantism) and the run's wave ring: "Wave n: survive m:ss for a star". Waves are one clock for the whole run (`Region.wave`, `waveProgress`), with no cap. |
| `TopCenter/ModeLabel`, `TopCenter/Timer` | `Timer.gd` (unchanged) | top center | Mode name and run clock. `Timer` keeps group `runTimer`. |
| `Objective` | `hud_objective.gd` | top center, under the clock | The mode's own goal: Goonpocalypse score and time to the star, Marathon "STATION n OF 5", Defense barrier bar. Hidden in Countdown and Sprint. |
| `TopRight` | `hud_payout.gd` | top right | Pause button, coins x the star multiplier (1 + 0.1 a star up to ×3, shown by the star) = payout (`Root.computePayout`), gems. |
| `Tach`, `Fuel` | `hud_dial.gd` | bottom left | Tachometer with the gear (`car.gear`), and the fuel dial. |
| `Speedo`, `Hull` | `hud_dial.gd` | bottom right | Speedometer and the hull (health) dial. |
| `Systems` | `hud_systems.gd` | bottom center | One lamp per car system, each with a rating underline. |
| `Items` (added in code) | `hud_items.gd` | bottom center, above the strip | The held gadget (charges, the Fire key) and the held boost beside it (charges, the Boost key), small counters left of them (star fragments, lottery tickets, a parcel, barricades), and a ring per timed power-up (right) that drains clockwise and blinks in its last 2 s. Groups `itemui`, `moveui`, `buffui`, and `clockui` (on `TopCenter`). |
| `NowPlaying` (added in code) | `scene/ui/radio/now_playing.gd` | bottom left, above the tachometer | The radio: song, artist and station, sliding in for 5 s at each new song or station change (docs/RADIO.md). Hidden otherwise. |
| `HudChance` (added in code) | `hud_chance.gd` | full screen, not HUD-scaled | Rare-pickup toasts under the clock, the Scratch Card and Double or Nothing under the payout, the Crush Combo under the crush pill, edge-of-screen beacons for events and supply drops, the Goon Nuke's flash. Redraws only while one shows. |

**Name tags:** the held gadget and boost boxes carry their short names above them, and a power-up's ring for its first 3 s (`HudItems.tag`, `Pickups.shortName`; docs/PICKUPS.md, "Name tags").

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

`tests/game/test_hud.gd` checks that every powerup scene has a target inside the HUD.

## The systems strip

There are five systems, each paired with the stat it scales (`OverheadCarBody2D.SYSTEM_STATS`): lights/`headlights`, engine/`engine`, steering/`steering`, tires/`traction` and tank/`oil`.

- **Lamp:** dimmed while healthy. The headlight lamp is full brightness while the headlights are on (`car.myLights.visible`). Under 70% condition the lamp gets an amber glow, under 40% a red one, and under 25% it blinks.
- **Underline:** the stat against 100, not the 150 cap, because no car's base stat is above 70. It has four parts:
  - **cream:** the rating the run started with (`car.runStartStats`, base plus upgrades)
  - **gold:** what pickups added this run
  - **red:** what damage takes off (`rating * (1 - conditionFactor)`)
  - **dark:** the room left up to 100

  A gold "+N" by the lamp counts the pickups for that stat. A stat over 100 gets a "+" at the end of its line.

## Later

- **Per-car skins:** colors, dial faces and speedometer scale via a `HudSkin` resource on `CarInfo`.
- **Region faction:** the region chip doesn't show the district's faction yet (`Region.factionName()`).
