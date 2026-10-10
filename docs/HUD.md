# In-run HUD

The HUD is `scene/player/playerRoot.tscn` (class `GameUI`): an instrument cluster sunk into each bottom corner, the held items along the bottom edge between them, and slim panels along the top. Damage shows on the car itself (docs/CAR_ART.md).

## Layout (1600 x 900 canvas)

| Node | Script | Anchor | Shows |
|---|---|---|---|
| `TopLeft/CrushPill` | `hud_crush.gd` | top left | The next gift box (docs/PICKUPS.md, "Gift boxes"): its tier in its colour, a crush XP bar and the XP still to go. Prize pickups fly to its box (`slotmachineui`). |
| `TopLeft/RegionChip` | `hud_region.gd` | top left | District name, goon size (giantism) and the run's wave ring: "Wave n: survive m:ss for a star". Waves are one clock for the whole run (`Region.wave`, `waveProgress`), with no cap. |
| `TopCenter/ModeLabel`, `TopCenter/Timer` | `Timer.gd` (unchanged) | top center | Mode name and run clock. `Timer` keeps group `runTimer`. |
| `Objective` | `hud_objective.gd` | top center, under the clock | The mode's goal, in every mode, with its icon: Countdown "SURVIVE THE CLOCK", Sprint "REACH THE STATION" and Marathon "STATION n OF 5" with the distance in the station's blue, Defense the BASE bar and percent (the rim flashes red when a goon blows up at a pump), Goonpocalypse the score and time to the star. |
| `TopRight` | `hud_payout.gd` | top right | Pause button, coins x the star multiplier (1 + 0.1 a star up to ×3, shown by the star) = payout (`Root.computePayout`), gems. |
| `Tach` | `hud_dial.gd` | bottom left corner, two thirds on screen | Tachometer with the gear (`car.gear`) in its hub, the fuel as an arc round its inner side, the engine and tank lamps and the horn lamp on its face. Its look is the car's dashboard (below). |
| `Speedo` | `hud_dial.gd` | bottom right corner, two thirds on screen | Speedometer with the speed in its hub, the hull as an arc round its inner side, and the steering, lights and tires lamps on its face. |
| `Instrument` (added in code) | `hud_instrument.gd` | bottom edge, just inside the tachometer's fuel arc | The car's signature instrument (below). Hidden on the house dash. |
| `Items` (added in code) | `hud_items.gd` | bottom edge, between the dials | The held gadget (charges, the Fire key) and the held boost beside it (charges, the Boost key), small counters left of them (star fragments, lottery tickets, a parcel, barricades, and from the car's traits: Cargo Bay's second gadget, the Meter's multiplier, the Loaded Bed's crates), the semi's Drop the Load box after the boost (lit when ready, filling while it restocks, with the Ability key), and a ring per timed power-up (right) that drains clockwise and blinks in its last 2 s. Groups `itemui`, `moveui`, `buffui`, and `clockui` (on `TopCenter`). |
| `NowPlaying` (added in code) | `scene/ui/radio/now_playing.gd` | bottom left, above the tachometer and the instrument | The radio: song, artist and station, sliding in for 5 s at each new song or station change (docs/RADIO.md). Hidden otherwise. |
| `HudChance` (added in code) | `hud_chance.gd` | full screen, not HUD-scaled | Rare-pickup toasts under the clock, the Scratch Card and Double or Nothing under the payout, the Crush Combo under the crush pill, edge-of-screen beacons for events and supply drops, the station pointer, the Goon Nuke's flash, the deep-water warning. Redraws only while one shows. |

**The station** (Sprint, Marathon, Defense) has its own colour, `HudTheme.STATION` (sky blue; nothing else on the HUD is blue). `HudChance.drawStation`: off screen, a pill on the screen edge (clear of the top panels and the dials) with the mode's icon, "STATION" (Defense: "BASE"), the distance (`HudTheme.stationDistance`: one decimal under 10, in the Speed Units' mi or km) and an arrow; on screen, a tag over the driveway (`station.drivewayPoint`) that fades as the car arrives. With 15 s left on a race clock the pill pulses (Reduce Motion: no swelling; Reduce Flashing: a steady white rim). In Defense the pointer and the objective turn red for 1.2 s when a goon blows up at a pump (`HudTheme.stationHit`, `station.lastHitMsec`), and the pointer shakes unless Reduce Motion.

**Deep water** (`HudChance.drawDeepWater`): while the car's centre is over deep water (`car.deepTicks` > 0, docs/WORLD.md "Water"), a red edge round the screen (four gradient bands, `DEEP_EDGE` 10% of the height deep) and "DEEP WATER" in red under the toasts and the briefing banner (y 300), pulsing about 1.4 times a second (Reduce Flashing: steady; Reduce Motion: the text doesn't swell). It fades in and out over a quarter second (`DEEP_FADE`). A lava landscape says "LAVA". It makes no sound of its own: the car's splash and hiss going in (CarJuice) are the cue.

**The briefing:** at GO on a run start (not resumes) a tape banner says the mode's goal (`Level.briefing`, e.g. "REACH THE STATION", "HOLD THE BASE"), and for a mode's first 3 runs (`Level.BRIEF_RUNS`, counted in `meta.hints.briefings`) a second one says how ("FOLLOW THE BLUE ARROW BEFORE TIME RUNS OUT").

**Version label:** bottom-left corner, 11 px.

**Name tags:** the held gadget and boost boxes carry their short names above them, and a power-up's ring for its first 3 s (`HudItems.tag`, `Pickups.shortName`; docs/PICKUPS.md, "Name tags").

`hud_theme.gd` (class `HudTheme`) holds the colors, the Tektur fonts and the draw helpers.

## Dashboards

Each car has its own dashboard: a `HudSkin` (`hud_skin.gd`), named in `CarInfo.hudSkin` and built from the table `HudSkin.SKINS`. A car that names none gets `house`, the HUD's own orange look, and so does every car with **Classic Dashboard** on (`access/classic_dash`, Accessibility): the same layout in the house look, with no signature instrument. `HudSkin.current()` is the skin of the car being driven.

| Car | Skin | Dials | Signature instrument (`HudInstrument`) |
|---|---|---|---|
| Sedan | `beater` | The house dials, with a cracked speedometer glass | `beater`: an odometer that counts the run, a CHECK ENGINE lamp that never goes out (red and blinking under 40% engine), the Second Wind lamp (lit until used), an air freshener that swings in corners. Tape across the top of the fuel arc lights up while Duct Tape is patching (`CarTraitRig.taping`) |
| Taxi | `hack` | Checker bezel, yellow tapered needles | `meter`: The Meter's fare so far (`CarTraitRig.meterFare`), its rate, FOR HIRE / HIRED |
| Police | `interceptor` | Blue rim, a tick every 2 MPH, a red needle tip | `radar`: a lightbar repeater in step with the car's own at night, the speed now and the run's fastest |
| Ambulance | `medic` | Light faces with dark numerals; the hull is a heart monitor beside the speedometer, whose trace speeds up as the hull drops | `defib`: the Defibrillator, READY or USED |
| Semi | `rig` | Chrome on wood plates, a tach in hundreds with a green economy band | `load`: how far Drop the Load is through restocking, and the gear in its own window (not on the tach) with LO / HI for the gearbox's range |
| Pickup | `truck` | No round dials: a pointer on a ribbon for revs and speed, with a bar for fuel or hull and the lamps in a row under each | `bed`: the bed's five crate slots and the payout they add, a 4x4 lamp on rough ground |
| Van | `delivery` | Square housings, a shorter scale (78° either side) | `tilt`: how far it leans, red as it nears a roll (Top-Heavy), and Cargo Bay's two gadgets in bays 1 and 2 |
| Racer, supercar | `track_racer`, `track_super` | A segmented bar tach round a big gear number, speed in digits; magenta, or yellow on carbon | `shift`: ten shift lights that fill through the gear and flash where a shift up earns its kick, then the drift charge's three tiers or the downforce |

**What a skin sets:** colours (face, rim, numerals, needle, track, accent, night glow), fonts (Saira Condensed, Rokkitt, Michroma, and Share Tech Mono for LED digits, in `style/font/`), the bezel (`Bezel`: ring, checker, chrome, square), the style (`Style`: round, ribbon, bar), the sweep, the needle's shape, the speedometer's tick density, the tach's units, the lamps' style, where a cluster sits if it is not a sunken dial (`rects`, offsets by `HudDial.Kind`), and the instrument (and where it sits, `instrumentAt`). The panels' rim colour and corner radius follow it too (`HudTheme.panel` with no rim or radius given).

**What a skin never changes:** the speed scale, the redline and the gear come from the car. Green is the speed that crushes a goon, red is the redline and danger, amber warns; a skin may only shade them for its face (`ok`, `warn`, `bad`). Revs stay left and speed right, fuel with revs and hull with speed, each lamp on its own side, and pickups still fly to the fuel, the hull and the lamps wherever a skin puts them. `tests/game/test_hud_skin.gd` checks these.

**Shared by every dash:**
- **Ignition sweep:** at the start of a run the big dials swing to the top of their scale and back (`BOOT_SECONDS`; not with Reduce Motion).
- **Night backlight:** at night the rim glows in the skin's `glow` and the numerals take a little of it.
- **Horn lamp:** on the tach (`HudDial.drawHorn`): it glows as the horn sounds, sits dim until the horn can sound again, then lights.
- **Wear:** under 40% hull the speedometer's glass cracks; under 40% engine condition the tach needle trembles (not with Reduce Motion); at night with the lights system under 40% the dials flicker (not with Reduce Flashing).
- The lightbar and the shift lights hold steady with Reduce Flashing; the heart trace and the air freshener stop with Reduce Motion.

**The sunken dials:** each cluster's box is 236 square with its centre 40 px above the bottom edge and 24 px of its outer side off screen, so about two thirds of the dial shows. The scale is a half turn (`HudSkin.sweep` either side, 90° on the house dash) leaning 12° toward the middle of the screen (`HudDial.TILT`), so both ends stay on screen and both dials read clockwise. The tach numbers every tick and the speedometer every other one. The gear and the speed sit in a disc at the hub (`HudDial.HUB`) and the needle starts at its edge. Fuel and hull are arcs outside the bezel on the inner side, filling from the bottom (`WING_FROM` to `WING_TO`), each with its icon and number; beside a square housing (the van's, the semi's wood plate) they are upright bars. The pickup's ribbons are not sunk: each is a panel on the bottom edge with the fuel or hull bar and its lamps in a row under the ribbon. The ambulance's heart monitor sits beside its speedometer.

**To add a dashboard:** add an entry to `HudSkin.SKINS` (only what differs from the house look), name it in the car's `<car>_info.tres` (`hudSkin`), and, for a new instrument, add its kind to `HudInstrument.KINDS` with a branch in `_process` (its redraw key) and `_draw`. The items row drops its own counter for a trait an instrument already shows (`hud_items.gd`).

- **HUD Scale:** every node above is a direct child of PlayerRoot, so `applyHudScale()` scales each one about its anchor. The crush pill and region chip sit inside `TopLeft` because their animations (`NewGoonCrushBonus` and `NewWave`) move and scale them, and HUD Scale would fight that if they were direct children.
- **Speedometer scale:** the speedometer scales to the car. `HudDial.speedScaleFor(car)` takes the car's flat-out speed (engine force against drag and friction, the same terms as `_physics_process`), adds 10%, and rounds up to a multiple of 40, from 80 to 320. The sedan gets 0–120 MPH and the police car 0–160. The green arc starts at 10 MPH, the speed where hitting a goon crushes it.

## Rendering and cost

The widgets draw with `_draw()`, and each one redraws only when its numbers change. Each widget builds a small key every frame and calls `queue_redraw()` when the key differs.

- **Dials:** the face (ticks, numbers, arcs) is drawn once, and again when the skin or night changes. The needle and readouts are drawn on a child CanvasItem through its `draw` signal. The needle eases toward its target with `1 - exp(-delta * 14)`, which is frame-rate independent. It only redraws once it has moved by a visible step (0.2 MPH, 0.02 thousand RPM, a quarter point of fuel or hull, which ease the same way). The speed digits refresh 10 times a second, as before.
- **Lamps:** drawn with the needle. They redraw when a stat, a condition or the headlights change, and every frame only while a pickup pulse or a sub-25% blink is playing.
- **Assets:** there are no new textures. The lamps and the fuel and hull use the pickup icons in `texture/icon/` (the plain `.svg` files, not `_flat`), so a pickup flies into its own icon.

## Pickups fly to their widget

`RewardFlyers` sends a pickup's icon to the first node in group `"<powerup>ui"` (`powerup.powerup + "ui"`). The HUD puts a zero-size marker node (`HudTheme.marker`) in each group, at the icon the pickup should land on:

| Pickup | Lands on |
|---|---|
| headlights, engine, steering, traction, oil | Its lamp on the tachometer or the speedometer. The lamp pulses and shows "+1" as the icon arrives (`RewardFlyers.FLIGHT_SECONDS` after the stat changes). |
| health, armor | The hull's icon, by the speedometer |
| fuel | The fuel's icon, by the tachometer |
| coin (and purse), gem | The coin icon in the payout and the gem pill |
| luck, clover | The payout (they change what goons drop) |
| currentGoonsCrushed, slotmachine | The crush pill |

`tests/game/test_hud.gd` checks that every powerup scene has a target inside the HUD.

## System lamps

There are five systems, each paired with the stat it scales (`OverheadCarBody2D.SYSTEM_STATS`): lights/`headlights`, engine/`engine`, steering/`steering`, tires/`traction` and tank/`oil`. Their lamps are on the dials (`HudLamps`, `hud_lamps.gd`), on the same side on every dash: **engine and tank on the tachometer** (what makes it go, with revs and fuel), **steering, lights and tires on the speedometer** (how it handles and what you see, with speed and hull). On a round face they sit between the hub and the numerals (`HudDial.lampAt`); the horn lamp takes the top of the tachometer's face.

- **Lamp:** dimmed while healthy. The headlight lamp is full brightness while the headlights are on (`car.myLights.visible`). Under 70% condition the lamp gets an amber fill, under 40% a red one, and under 25% it blinks.
- **Rating:** the stat against 100, not the 150 cap, because no car's base stat is above 70 (`HudLamps.spans`). It has four parts:
  - **cream:** the rating the run started with (`car.runStartStats`, base plus upgrades)
  - **gold:** what pickups added this run
  - **red:** what damage takes off (`rating * (1 - conditionFactor)`)
  - **dark:** the room left up to 100

  A gold "+N" by the lamp counts the pickups for that stat. A stat over 100 gets a "+" beside it.
- **Style:** the dashboard's (`HudSkin.lamp`, `HudSkin.Lamp`). The house and the beater draw a round tell-tale with the rating as a ring; the taxi a square tile, the police car an annunciator block and the pickup a pill, each with the rating as a line under it; the Track cars an LED column beside the icon. Three show what the system is worth now (rating x condition) and leave the split to the "+N": the ambulance as a number, the semi as a little gauge's needle, the van as five LCD blocks.

## Critter Chain readout

The Crush Combo readout (`HudChance.showCombo(count, coins, sources)`) counts every kill the player sets up near the car, not only bumper crushes (docs/PICKUPS.md, "Critter Chain"). While the chain has one kind of kill it reads "COMBO n +coins" and heats from gold to red as before. Once it mixes kinds it reads "CRITTER CHAIN xn: LOGS + BEES + SPLASH +coins" in gold (`HudChance.comboText`; at most 4 names, then "+n"), at a fixed 24 px so the longer line stays clear of the dials. It shows from the first mixed kill, before the combo pays coins.

## Smash tags

`SmashTags` (`scripts/world/smash_tags.gd`, a child of `PropReactions`) draws a small tag in the world over an interactive prop (`SmashTags.HEROES`: log pile, water tower, hive, crate, barrel, billboard, crane, fence, hay bale, hedge, and The Wilds' den, burrow, bell, scarecrow, farm gate, pumpkin, still, TNT, sluice, rock pile, hero saguaro, ranger tower and fallen trunk) when the car is heading at it (within about 35°) within 700 px: the speed that smashes it (for a crane, a bell or a scarecrow, the ram that drops, rings or knocks it: `Spill.ramSpeed`), in the player's units (`Settings.speed_text`, 100 px/s = 10 MPH). White, gold once the car is fast enough. At most the 3 nearest show, fading in and out; walls and rocks never get one. It is unshaded, so it shows at night. The first tag of each kind a save ever shows toasts a one-line hint ("Smash log piles at 35 MPH: the logs roll on"), flagged `smash_<id>` in `meta.hints`. ChunkView registers the props as they stream in (`PropReactions.addHero`) and they leave with their chunk. There is no setting for it yet (the settings menu belongs to another work package); `HEROES` is the one place to add or drop a kind.

## Later

- **Region faction:** the region chip doesn't show the district's faction yet (`Region.factionName()`).
