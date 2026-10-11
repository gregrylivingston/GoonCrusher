# Roadmap: juice

In-run effects: particles, decals, fire, water, the camera, screen effects, weather, effect sounds and rumble. The goal (the author): from about 3 out of 10 to 11. Menu juice is in `ROADMAP_UI_HUD.md`; the feel passes that only turn existing numbers are in `ROADMAP_CARS.md`, `ROADMAP_GOONS.md` and `ROADMAP_WORLD.md`.

## Where it stands

- **Built:** one particle kit (`FxParticles`), the level's effects door (`Fx`: blasts, scorch marks, sparks, fire, splashes), the screen layer and the heat (`ScreenFx`), tire marks per surface, tire smoke, the wake. `CarJuice`, `CrushFeel`, `GoonFx` and `PropReactions` call into them.
- **Nothing has been seen moving by a person yet,** only in stills. Every amount, color, rate and time in `Fx`, `ScreenFx`, `FxParticles`, `Tiremark.LOOK` and the new `CarJuice` and `CrushFeel` constants is a first guess.
- **Nothing has been measured on the low-end target.** The risks are fill (smoke clouds, fires, the screen edge) and the tire ruts' node count.
- **Still the originals:** exhaust and damage smoke (`texture/animation/smoke.tscn`), the explosion's fireball (`scene/fx/explosion.*`), tire marks as a node per segment.
- **Effect sounds are borrowed:** most in-run feel sounds are the nine menu transition clips (`Transition.SOUNDS`) at other pitches, over one explosion and one crash recording. Rumble is one-shot pulses only.
- **There is no weather and no ambient air** (dust, leaves, snow, embers, insects).

## Rules every item follows

- **Show only.** Effects never write velocity, health, rewards or the game's random numbers (own `RandomNumberGenerator`, as `CarJuice` does), so taped drives and the AI's predictions are unchanged. Anything that hurts or blocks is gameplay and goes through `GoonFx` hazards or `World`, on the tick.
- **Pooled and capped,** drawn by a few nodes; a full pool skips or overwrites. No node per particle.
- **Sized by the effect settings,** and by Reduce Motion, Reduce Flashing and Screen Shake. Effect levels never change results.
- **Night is gameplay:** flames, sparks and blasts draw unshaded so they read at night, but nothing new may reveal goons the headlights don't.
- **Measured:** each package is checked against the targets in `docs/PERFORMANCE.md` before it ships.

## Planned

### 1. Prove what is built
- **[0.3 need] A feel pass by hand** over everything above, by day and at night, alone and with two players: sizes, colors, how long smoke hangs, how often the screen edge shows, how long the slow motion on a boss and a mega crush lasts, whether the heat is felt. S + play.
- **[0.3 need] An effects bench scenario** (`Bench.SCENARIOS`): a chain of blasts, fires, a crowd crush, a water crossing and a drift in soft ground at night. Then measure Low and Potato, and cut or cap what costs. S.
- **[0.3 want] Two players:** the screen layer is off and the heat, flashes and shake follow the first player only. Give the guest's view its own. M.

### 2. Foundation, what is left
- **[0.3 want] A ground decal layer.** One pooled, batched layer for everything left on the ground: tire marks (a node per segment today), scorch marks (drawn by `Fx`), puddles, fuel and oil trails, goo. M.
- **[0.3 want] Finish the effects kit.** Move `GoonFx`'s bits and `damage_fx.gd`'s puffs and drips onto `FxParticles`, and the exhaust off the smoke flipbook. Its textures are built in code: replace them with one small generated atlas (`scripts/art/`) with real puff, flame, chip and droplet shapes. M.
- **[0.3 want] A better fireball** than the old flipbook, debris that lands and stays a moment, and each caller picking its blast size (all but the car's wreck use the middle one). S.

### 3. Driving
- **[0.3 want] Exhaust:** puffs on throttle and shifts, a flame cone on nitro and on the top drift tier. S.
- **[0.3 want] Tire marks:** width and darkness from slip and load, wet tracks after water, burnout marks. S after the decal layer.
- **[later] Sparks that bounce** and leave a glow dot; a grinding trail from a wrecked wheel and from the semi's trailer on walls. S.
- **[later] Per-surface roost:** gravel that sprays and rattles on the body, grass clippings, snow plumes, mud that sticks to the car's sides and washes off in water. M.

### 4. Fire
- **[later] Things burn:** smashed and blasted props smolder; flung goons can catch and run burning; grass and crops near a fire char in the decal layer. Show only. M.
- **[later] Spreading fire as a hazard:** fire creeps over flammable surfaces and props, hurts cars and goons, burns out behind itself. Gameplay: it needs hazard caps, terrain rules in both `World` and the native grid, the AI driver's avoidance and a balance pass. L.

### 5. Water
- **[0.3 want] Splashes for everything that lands in water** (logs, debris, pickups; goons and the car have one), and a wake behind swimming goons. S.
- **[later] Shore and surface:** foam along the waterline and sun glints in `ground.gdshader` (above the lowest ground quality), ripples that spread from the car through the shader, a drip trail after leaving water. M.
- **[later] Lava:** ember fountains, a heat glow on the car's flanks, smoke off the tires. S.

### 6. Camera and screen
- **[0.3 want] A slow-motion beat on the crush that wins the run.** S.
- **[0.3 want] The heat in the mix:** the effect sounds brighten and the music ducks less as it rises. S, with the sound set.
- **[later] Distortion:** a color split on giants and big blasts, a shockwave ripple, heat haze over fire and lava (a screen-texture pass; High only). M.
- **[later] Bloom and effect lights** at Medium and up: glow on flames, sparks and blasts, and blasts and fires that light the ground at night. Needs HDR-2D measured on the low-end target and a setting (`docs/PERFORMANCE.md` lists both as absent today). M.

### 7. Weather and air
- **[later] Ambient air per landscape** (a field in the landscape's `.tres`): dust and tumbleweed gusts, drifting leaves, pollen, snow flurries, embers and ash over lava, insects round the headlights at night. A screen-space layer that scrolls with the camera, so it costs the same anywhere. M.
- **[later] Weather per level, as a look:** rain (streaks, ground rings, a wet sheen in the ground shader, spray from every tire), snowfall, dust storms, ground fog, far lightning with a flash and delayed thunder. L.
- **[later] Weather as gameplay** (grip in rain, fog that shortens sight) belongs with region mutators in `ROADMAP_WORLD.md`.

### 8. Sound and rumble
- **[0.3 want] An effect sound set of its own,** generated or found, replacing the borrowed transition clips: several takes each of crush (by goon size), wall hit (by speed), prop smash (by material), blast (three sizes, with a tail), splash, skid per surface, spark scrape, fire crackle, boost, landing. Random take and pitch per play. Each cue short and not tonal. Fire and splashes have no sound at all today. M + sourcing.
- **[0.3 want] Loops and mix moves:** a surface loop under the tires (gravel, mud, water, snow), wind at speed; a low-pass and a duck for a moment on hit-stop and big blasts. M.
- **[later] Rumble map:** continuous low rumble from surface and slip, a ramp while a drift charges, pulses sized by the kit's events; the guest's pad too (`ROADMAP_MODES.md`). S.

## Decisions (the author)

- **Bloom and effect lights are allowed** at Medium and up. Low and Potato stay on additive sprites, and night must play the same with them off.
- **Fire spreads, as a look and as a hazard.**
- **Weather is set per level.**
- **0.3 takes what is high value or easy;** the expensive items wait. The tags above are that split.
- **Effect sounds are generated or found;** none are recorded.

## Questions for the author

1. **How loud is 11 for Reduce Motion and Reduce Flashing players?** Today they lose the flashes and the streaks, and keep the edges, smoke, fire, sparks and slow motion (Hit-Stop has its own switch). Say if that line is wrong.
2. **Should the heat ever touch play,** or stay a look?
