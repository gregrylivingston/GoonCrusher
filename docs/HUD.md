# In-run HUD

The HUD is `scene/player/playerRoot.tscn` (`GameUI`), with its widgets in `scene/player/hud/`. Sizes, colors and positions are in those scripts.

## Layout

| Widget | Script | Where | Owns |
|---|---|---|---|
| `LeftVisor`, `RightVisor` | `hud_visor.gd` | top corners | Gift box and radio; star, coins, payout, gems |
| `Mirror` | `hud_mirror.gd` | top center | The frame behind the clock and the goal; dice and clover |
| `TopCenter` | `Timer.gd` | on the mirror | Mode name and run clock (group `runTimer`) |
| `Objective` | `hud_objective.gd` | on the mirror | The mode's goal: one branch per mode in `_process` and `_draw` |
| `Tach`, `Speedo` | `hud_dial.gd` | bottom corners | Revs, gear, fuel; speed, hull; the system lamps |
| `Instrument` | `hud_instrument.gd` | by the tach | The car's signature instrument |
| `Items` | `hud_items.gd` | bottom edge | Held gadget and boost, counters, the ability, timed power-up rings |
| `HudChance` | `hud_chance.gd` | full screen | Toasts, scratch card, Double or Nothing, combo, beacons, pointers, deep-water warning, subtitles |

`hud_theme.gd` (`HudTheme`) holds the colors, fonts and draw helpers; the menus build their theme from it. `GameUI` adds `Mirror`, `Instrument`, `Items` and `HudChance` in code.

## Rules

- **Redraw only on change.** Widgets draw with `_draw()`; each builds a small key every frame and calls `queue_redraw()` only when it differs.
- **Anything that moves is delta-based** (needles ease with `1 - exp(-delta * k)`), because frame caps exist.
- **Icons** are the pickup icons in `texture/icon/` (the plain `.svg`, not `_flat`), so a pickup flies into its own icon.
- **HUD Scale:** every `Control` that is a direct child of PlayerRoot when `setupHudScale()` runs is scaled about its anchor. `HudChance` and runtime menus are not.
- **Accessibility:** flashes hold steady with Reduce Flashing; swings, sweeps and swelling stop with Reduce Motion. A new effect must honor both.
- **Pausing** is Esc / Start or losing focus (`GameUI.openPause`); there is no HUD button.
- **Districts show nothing:** entering one only changes who spawns.
- **A widget never names the player's car.** It asks its HUD: `GameUI.carOf(self)` for the car, `HudSkin.of(self)` for the dashboard, `GameUI.canvasOf(self)` for world-to-screen. A run can have two HUDs (below).

## Two HUDs

In a two-player run (docs/MODES.md, "Two players") each half of the screen has a HUD: `GameUI.setFrame(rect, fit)` reparents the widgets under a frame laid over that half and scaled to fit (`CoopRun.HUD_FIT`), so anchors mean the half's corners and center; `GameUI.widget(name)` finds one wherever it is. `CoopRun` adds a second `playerRoot.tscn` with `guest` set for the second player: the guest's car and dashboard on the dials, the same clock (its `Timer` only shows the time: `drives` is off) and goal, its own coins on the right visor, no gift boxes, no pause. Each HUD points at the other car once it is off its half (`HudChance.drawPartner`), in red as the leash runs out. A frame clips its widgets, so a dial that hangs off its corner never reaches the other half. It is in no group and its markers join no flyer group, and `HudChance.current` stays the player's, so pickups, toasts and prompts go to the player's HUD only.

## Pickups fly to their widget

`RewardFlyers` sends a pickup's icon to the first node in group `"<powerup>ui"`. The HUD puts a zero-size marker (`HudTheme.marker`) in each group, at the icon the pickup should land on:

| Group | Marker is on |
|---|---|
| `headlightsui`, `engineui`, `steeringui`, `tractionui`, `oilui` | Its lamp on a dial |
| `healthui`, `armorui`; `fuelui` | The hull icon; the fuel icon (`HudDial.flyerGroups`) |
| `coinui`, `starui`, `gemui` | The right visor |
| `luckui`, `cloverui` | The mirror's dice and clover |
| `currentGoonsCrushedui`, `slotmachineui` | The gift box on the left visor |
| `itemui`, `moveui`, `buffui`; `clockui` | The items row; the run clock |

Every group must keep a target wherever a skin puts things (`tests/game/test_hud.gd`). The flight is visual only: rewards are credited at once.

## Dashboards

Each car has its own dashboard: a `HudSkin` (`hud_skin.gd`) named in `CarInfo.hudSkin` and built from `HudSkin.SKINS`. A car that names none, and every car with Classic Dashboard on (`access/classic_dash`), gets `house`. `HudSkin.current()` is the skin in use.

**A skin is paint.** It sets colors, fonts, bezel, style, lamp style, the mirror's dressing, where a cluster sits and which instrument shows. It never changes (`tests/game/test_hud_skin.gd`):

- the speed scale (`HudDial.speedScaleFor`), the redline (`CarInfo.redline`, `rpmMaxFor`) and the gear, which come from the car;
- what green (the speed that crushes a goon), red (redline, danger) and amber (warning) mean; a skin may only shade them (`ok`, `warn`, `bad`);
- revs left and speed right, fuel with revs and hull with speed, each lamp on its own side, and the flyer groups.

**Every dash starts a run pristine.** Wear is the car's state, never a skin's dressing: the glass on the dials and the mirror cracks in stages as the hull drops and mends as it is repaired (`HudDial.glassStage`), and a skin's own damage props (the sedan's tape and check-engine lamp) come on from what happens in the run.

**To add a dashboard:**
1. Add an entry to `HudSkin.SKINS` with only what differs from the house look.
2. Name it in the car's `<car>_info.tres` (`hudSkin`).
3. For a new instrument, add its kind to `HudInstrument.KINDS` with a branch in `_process` (its redraw key) and in `_draw`.
4. If the instrument shows a trait the items row also counts, drop the row's counter for that skin (`hud_items.gd`).

## The mirror

`HudMirror` does not own the clock or the goal: it lays `TopCenter` and `Objective` out on its glass (`apply`), turns off the goal's own panel (`HudObjective.framed`) and dresses the clock in the skin's font. Its dressing is `HudSkin.mirror`; the semi gets a console. The dice are the luck stat in pips and the clover carries the clover stat; they hang from the top of the frame on strings that run behind it (`charms`, drawn behind the frame). A skin can hang its driver's own things beside them (`HudSkin.hangs`, drawn by `drawHang`, on the strings in `HANGS`). Each is a pendulum plus a bounce along its string (`stepCharms`), driven by the car's turn and by its change of velocity each frame (`swingCharms`, `jolt`), and what lights up over the frame is on `front`. The start lamps' layer is under the HUD's, so the rack comes down behind the mirror too. The frame pulses red in the last seconds of a clock that loses the run (`hurry`).

## The visors

`HudVisor` has two kinds, `PRIZE` (left) and `PAY` (right). The star's ring is the run's wave (`Region.waveProgress`): one clock for the whole run that districts never restart. A mode with no goons has no waves. A gift box earned or a wave survived flashes its visor (`GameUI.flashWidget`).

## System lamps

`HudLamps` draws the five systems (docs/CAR_ART.md, "Systems and zones") on the dials, on the same side on every dash: engine and tank on the tachometer, steering, lights and tires on the speedometer. A lamp's rating is the stat against 100, not the in-run cap, split by `HudLamps.spans`: what the run started with, what pickups added, what damage takes off. How it is drawn is `HudSkin.lamp`.

## Pointers and warnings

`HudChance.drawPointer` shows a world point as an edge pill with the distance when off screen and a tag over it when on screen. The station, courses, Bounty Hunt, Pursuit and Keep the Cup use it, and a new mode's target should. The deep-water warning (`drawDeepWater`) shows while `car.deepTicks` > 0.

## Critter Chain readout

`HudChance.showCombo(count, coins, sources)` counts every kill the player sets up near the car, not only bumper crushes (docs/PICKUPS.md, "Critter Chain"). Mixed kinds read as a Critter Chain naming them (`comboText`).

## Smash tags

`SmashTags` (`scripts/world/smash_tags.gd`, a child of `PropReactions`) draws a tag in the world over an interactive prop the car is heading at: the speed that smashes it. `SmashTags.HEROES` is the one place to add or drop a kind; walls never get one. The first tag of each kind toasts a hint, flagged `smash_<id>` in `meta.hints`. ChunkView registers props as they stream in (`PropReactions.addHero`).
