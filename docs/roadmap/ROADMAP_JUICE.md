# Roadmap: juice

In-run effects: particles, decals, fire, water, the camera, screen effects, weather, effect sounds and rumble. The goal (the author): from about 3 out of 10 to 11. Menu juice is in `ROADMAP_UI_HUD.md`; the feel passes that only turn existing numbers are in `ROADMAP_CARS.md`, `ROADMAP_GOONS.md` and `ROADMAP_WORLD.md`.

The tags and the order below are a proposal: nothing here is agreed yet.

## Where it stands

- **The newer systems are sound but quiet.** `CarJuice`, `CrushFeel`, `GoonFx` and `PropReactions` are pooled, capped, show only and settings-aware. Their particles are plain dots, soft dots and lines, in small pools, and `GoonFx` still has particle code of its own.
- **The originals are the weak spots:** exhaust and damage smoke (`texture/animation/smoke.tscn`), sparks (`scene/fx/spark/`: a node instantiated per spark), the explosion's fireball (`scene/fx/explosion.*`: one small flipbook) and tire marks that are still a node per segment.
- **Fire** is a ring of flat circles (`GoonFx.drawGround`) or a tinted smoke puff (`damage_fx.gd`). Nothing burns, scorches or lights its surroundings.
- **Water** moves in `ground.gdshader`, but the car leaves no wake, there are no ripples or shore foam, and a splash is a handful of dots.
- **There is no screen layer at all:** no flash, vignette, speed effect, distortion or bloom. The camera only reacts to crushes, wall hits and landings.
- **There is no weather and no ambient air** (dust, leaves, snow, embers, insects).
- **Effect sounds are borrowed:** most in-run feel sounds are the nine menu transition clips (`Transition.SOUNDS`) at other pitches, over one explosion and one crash recording. Rumble is one-shot pulses only.

## Rules every item follows

- **Show only.** Effects never write velocity, health, rewards or the game's random numbers (own `RandomNumberGenerator`, as `CarJuice` does), so taped drives and the AI's predictions are unchanged. Anything that hurts or blocks is gameplay and goes through `GoonFx` hazards or `World`, on the tick.
- **Pooled and capped,** drawn by a few nodes; a full pool skips the effect. No node per particle.
- **Sized by the existing effect settings,** and by Reduce Motion, Reduce Flashing and Screen Shake. Effect levels never change results.
- **Night is gameplay:** flames, sparks and blasts draw unshaded so they read at night, but nothing new may reveal goons the headlights don't. Real lights from effects are a question (below).
- **Measured:** each package is checked against the targets in `docs/PERFORMANCE.md` before it lands. Fill rate on the low-end target is the limit, so big soft sprites and screen passes are the risk, not particle counts.

## Planned

### 1. Foundation
- **[0.3 want] Finish the effects kit** (`FxParticles`; `CarJuice`, `PropReactions` and `Fx` use it). Move `GoonFx`'s bits, `damage_fx.gd` and the car's sparks onto it, so `spark.tscn` and the smoke flipbook go. Its textures are built in code today: replace them with one small generated atlas (`scripts/art/`) with real puff, flame, chip and droplet shapes. M.
- **[0.3 want] A ground decal layer.** One pooled, batched layer for everything left on the ground: tire marks, scorch marks (drawn by `Fx` for now), puddles, fuel and oil trails, goo. It fades by age and drops the oldest first. M.
- **[0.3 want] An effects bench scenario** (`Bench.SCENARIOS`): blasts, a crowd crush, a water crossing and a drift at night, so every package below has one number to hold. S.
- **[0.3 want] More events on `Fx`** (the level's front door; it has `blast` and `scorch`): `burst`, `splash`, `flash`, `shake`, added as the packages below need them.

### 2. Tires, smoke and sparks
- **[0.3 want] Tire marks, what is left** (`Tiremark` has a look per surface, ruts in soft ground, marks in any slide and a fade): draw them into the decal layer instead of a node per segment, and measure the ruts on the low-end target first, since soft ground now marks all the time; width and darkness from slip and load; wet tracks after water; burnout marks. The colors in `Tiremark.LOOK` are a first guess. M + play.
- **[0.3 want] Tire smoke:** thick, billowing, lit puffs that hang and drift; a burnout cloud on launch; the smoke takes the drift charge's tier color; a smoke ring on a handbrake turn. S after the kit.
- **[0.3 want] Exhaust:** puffs on throttle and shifts, a flame cone on nitro and on the top drift tier, heat shimmer behind it at High. S.
- **[0.3 want] Sparks:** hot streaks with gravity that bounce once and leave a glow dot; showers on scrapes sized by speed; a grinding spark trail from a wrecked wheel and from the semi's trailer on walls. S.
- **[later] Per-surface roost:** gravel that sprays and rattles on the body, grass clippings, snow plumes, mud that sticks to the car's sides and washes off in water. M.

### 3. Blasts and fire
- **[0.3 want] Explosions, what is left** (`Fx.blast` does the layers, sizes, boom and shake): a better fireball than the old flipbook, debris that lands and stays a moment, a duck of the other effect sounds, and each caller picking its size (all but the car's wreck use the middle one). Every number in `Fx.BLAST` is a first guess. S + play.
- **[0.3 want] Fire that looks like fire:** flame particles with a dark base, licks, sparks rising and smoke above, replacing the circles in `GoonFx` and the puff in `damage_fx.gd`; a wrecked car burns properly, and a car on fire trails flame at speed. M.
- **[later] Things burn:** smashed and blasted props smolder; flung goons can catch and run burning; grass and crops near a fire char in the decal layer. Show only. M.
- **[later] Spreading fire as a hazard:** fire creeps over flammable surfaces and props, hurts cars and goons, burns out behind itself. This is gameplay: it needs hazard caps, terrain rules in both `World` and the native grid, the AI driver's avoidance and a balance pass. L.

### 4. Water
- **[0.3 want] Wake and splash:** a V wake and foam trail behind the car in water, sized by speed; a real entry splash (a crown, droplets that fall back, a ripple ring); spray sheets off the wheels in the shallows; rings where goons, logs and debris land. M.
- **[later] Shore and surface:** foam along the waterline and sun glints in `ground.gdshader` (above the lowest ground quality), ripples that spread from the car through the shader, a drip trail and wet tracks after leaving water. M.
- **[later] Lava:** ember fountains, a heat glow on the car's flanks, smoke off the tires. S after the above.

### 5. Camera and screen
- **[0.3 want] A screen layer for the run,** drawn inside the run's view (`RunView`), cheap enough for Low and off on Potato: a hit flash, a red edge pulse on damage and at low health, speed streaks at the edges on nitro and boost, a brief color split on giants and big blasts, a darkened edge during hit-stop. Reduce Flashing and Reduce Motion cut each one. M.
- **[0.3 want] Camera moments:** blasts add trauma by distance (one call for every source); a short push and zoom on a boost; a slow-motion beat on a boss crush, a mega crush and the run's last crush; a wreck that zooms in before the results. All through `CrushFeel`, so one node still owns the offset. S + play.
- **[0.3 want] The heat rule:** one 0 to 1 value from the Crush Combo that scales the kit's amounts, the screen layer and the mix. The game gets louder as the player does well, and calms when the combo drops. S + play.
- **[later] Distortion:** a shockwave ripple on blasts and heat haze over fire and lava (a screen-texture pass; High only). M.
- **[later] Bloom and effect lights** at Medium and up: glow on flames, sparks and blasts, and blasts and fires that light the ground at night. Needs HDR-2D measured on the low-end target and a setting (`docs/PERFORMANCE.md` lists both as absent today). M.

### 6. Weather and air
- **[later] Ambient air per landscape** (a field in the landscape's `.tres`): dust and tumbleweed gusts, drifting leaves, pollen, snow flurries, embers and ash over lava, insects round the headlights at night. A screen-space layer that scrolls with the camera, so it costs the same anywhere. M.
- **[later] Weather as a look:** rain (streaks, ground rings, a wet sheen in the ground shader, spray from every tire), snowfall, dust storms, ground fog, far lightning with a flash and delayed thunder. Per level or per run; show only at first. L.
- **[later] Weather as gameplay** (grip in rain, fog that shortens sight) belongs with region mutators in `ROADMAP_WORLD.md`.

### 7. Sound and rumble
- **[0.3 want] An effect sound set of its own,** replacing the borrowed transition clips: several takes each of crush (by goon size), wall hit (by speed), prop smash (by material), blast (three sizes, with a tail), splash, skid per surface, spark scrape, boost, landing. Random take and pitch per play. Each cue short and not tonal. M + sourcing.
- **[0.3 want] Loops and mix moves:** a surface loop under the tires (gravel, mud, water, snow), a fire crackle near flames, wind at speed; a low-pass and a duck for a moment on hit-stop and big blasts; the crush tick's rise with the combo carried into the new set. M.
- **[later] Rumble map:** continuous low rumble from surface and slip, a ramp while a drift charges, pulses sized by the kit's events; the guest's pad too (`ROADMAP_MODES.md`). S.

## Suggested order

1. Foundation (the kit, the decal layer, the bench scenario).
2. Explosions, the screen layer, camera moments and the effect sound set: the biggest change per day.
3. Tire marks, tire smoke, sparks, fire.
4. Water, the heat rule, loops and mix.
5. Everything tagged later.

## Decisions (the author)

- **Bloom and effect lights are allowed** at Medium and up. Low and Potato stay on additive sprites, and night must play the same with them off.
- **Fire spreads, as a look and as a hazard.**
- **Weather is set per level.**
- **0.3 takes what is high value or easy;** the expensive items wait. The tags above are that split, still to be confirmed item by item.
- **Effect sounds are generated or found;** none are recorded.

## Questions for the author

1. **How loud is 11 for Reduce Motion and Reduce Flashing players?** The plan cuts each new effect for them; say if any should stay.
