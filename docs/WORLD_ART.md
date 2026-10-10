# World art

The ground, edges, props, station textures and level posters are generated top-down art in the same "Dust & Rust" style as the cars and goons, baked into `res://world/art/`. Where things go in the world is docs/WORLD.md.

**Never edit the baked files by hand; change the generator and re-bake.** That includes the prop `.tscn` files and `props.json`.

## Files

| Path | What |
|---|---|
| `scripts/art/world_gen.js` | The generator (`window.WorldArt`): `GROUND`, `EDGE`, `PROPS`, `STATION`, `POSTER` and the bake functions. **Change world art here.** |
| `scripts/art/art_core.js` | Shared helpers (seeded `rng`, periodic noise, overhead-lit volumes, the convex `hull`). `car_gen.js` and `goon_gen.js` keep their own copies so their output never changes. |
| `scripts/art/bake_world.html`, `bake_world.py` | The bake: headless Edge pages write the PNGs, `props.json`, the prop scenes and every `.import` file. |
| `world/art/ground/`, `edges/`, `decor/`, `props/`, `station/`, `posters/` | The output. `props/` holds each prop's variants, states and scene; `station/` is what `scene/level/station.tscn` is built from. |
| `world/art/props.json` | The prop manifest (below). |
| `shader/world_beacon.gdshader`, `.tres` | The landmarks' shared beacon material (faded with day and night by `Level.fadeBeacons`). |
| `tests/game/test_world_art.gd` | Manifest vs. files and scenes, hulls, occluders, dressing ids, ground, edges, station, posters. |

## Re-baking

```
python scripts/art/bake_world.py                          # everything (slow: the posters are most of it)
python scripts/art/bake_world.py ground edge              # jobs: ground edge prop decor station poster
python scripts/art/bake_world.py prop --only oak,crate    # a few props (props.json keeps the others)
Godot_console.exe --headless --path . --import
```

- The script writes each PNG's `.import` file itself (mipmaps on; VRAM compression for ground, posters and the station tiles, lossless for the rest; the `VRAM` regex in `bake_world.py`). A re-bake keeps an existing `.import` file's uid, so no manual import step is needed, unlike cars and goons.
- The bake is deterministic: no `Math.random`, no `Date`. Re-baking without changes gives the same pixels.

## Rules

- **Light from straight overhead.** Nothing implies a sun direction; height reads only through ambient occlusion (a dark contact band at the foot, a lighter lip on top). So every sprite and strip may be rotated and flipped freely.
- **Actors stay the most outlined thing on screen:** props get a thinner rim than goons, a centered contact shadow, and flat things (decor, scorch, debris) no rim.
- **Palette:** ground is mid-value and less saturated than the actors. Never use telegraph red `#ff5c30`, HUD orange `#f0a030` or Scrap teal `#2aa6a1` as a large fill. Deep water is slate, not teal. Bake at final brightness: no modulates above 1. Snow, salt, tar and lava break the mid-value band on purpose, because they have to read as what they are.
- **Texel density:** ground 0.5 texels per world px (a 512 tile covers 1024 px); props, strips and decor 0.75 (shown at scale 1.3333), matching the goons.

## Ground materials

One function per material in `GROUND`; the list is `GROUNDS` in the test. Which terrain uses which is `WorldSkin.MATERIAL_OF` and each landscape's `materials`.

- **Seamless:** every noise call wraps its lattice and strokes near an edge are drawn again on the far side (`wrapAt`). Sample with repeat on.
- **Direction matters for three:** `conveyor` moves along +x (the shader rotates the UVs with the belt), `bridge` planks run across x, and roof courses run along x.
- Keep cell patterns faint, or the 1024 px repeat shows.
- `macro_noise.png` is the tileable grayscale the ground shader uses for macro variation and organic borders.

## Edge strips

512×96 texels, tiling along x, drawn by a 128 px wide `Line2D` in Tile mode with `texture_repeat` on. One-sided strips put the barrier (water, cliff top, roof) at the top (v = 0); `ChunkRecipe` builds its lines with the barrier on the left to match. Each landscape names its wall strip (`Landscape.wallStrip`).

## Props

`PROPS` holds one design per prop: `cls`, `box` (world px, centered), `n` (variants), `shadow`, `grime`, `draw(ctx, rng, variant)`, and optionally `core` (the solid part, for the hull), `occluder`, `breakable`, `explosive`, `solid`, `beacon`, `canopy`, `leaves`, `tags`. The catalog with sizes and hulls is `props.json`.

### Classes

`DECOR` (MultiMesh sprite: no collision, scene or occluder), `LOW` (pooled scene, collides), `TALL` (pooled, collides and casts a night shadow), `STATEFUL` (instanced, with state: breakable, explosive or a spawn point), `WALL` (wall segment, occluder).

### How a prop is baked

- The **hull** is the convex hull of the body's opaque pixels (or of the `core` drawing), reduced to at most 10 points. One hull serves the collision shape and the occluder.
- **Breakables** also bake `<id>_broken.png` (what stays on the ground) and `<id>_debris.png` (a row of 4 cells of flying pieces). `blastOnly` (the tank) means only explosions break it.
- **Beacons:** a design with `beacon(c)` bakes `<id>_beacon.png` in the prop's own frame; the scene gets a `Beacon` node.
- **Decor** atlases are a row of 4 square cells; the cell is picked per instance from `INSTANCE_CUSTOM.x` in `shader/world_decor.gdshader`. `streetglow` is additive (`world_decor_glow.gdshader`).
- **States and overlays:** `states` are extra baked drawings code can adopt (the saguaro's `fallen` and `chunks`, used by `Spill.armSaguaro`; they don't make the prop breakable). `overlays` are frame strips over the body (the den's `Sacks`: frame = sacks stashed).

### Region 1 props

The Wilds' props (den, burrow, bell, salt lick, scarecrow, farm gate, pumpkin, still, sluice, rock pile, TNT and the rest) only supply states here; what each does in play is docs/WORLD.md "Interactive props" and docs/GOONS.md "Wild instincts".

### Hedgerow

The unbreakable hedgerow is deliberately unlike the breakable `hedge`: tall, dark, flat-topped with a hard lit edge, on a dry-stone base.

- `decor/hedgerow.png` is a 4-cell atlas, 192 world px a cell, drawn edge to edge: cells 0 and 1 are straights along x, cell 2 an end cap (the run enters from −x), cell 3 a corner (in from −x, out through +y).
- Every piece shares one cross-section and one fixed set of stones and foliage near each joint, so any piece meets any other with no seam.
- `edges/hedgerow.png` is the same look as a `Line2D` strip for runs at any angle; it ends square, so cap it with cell 2.
- Collision and occluders are the code's (the chunk's wall body). The art has no hull.

### Layered props

A design with a `canopy(c, R, v)` drawing is baked in two layers: `draw` becomes the **ground layer** (roots, trunk top, litter; the crane's cab) with the canopy's shade baked under it, and the canopy becomes `<id>_canopy.png`, drawn over the car. The hull still comes from `core`, so collision and night occluders stay on the trunk. A `leaves(c, R, k)` drawing bakes `<id>_leaves.png`, a 4-cell strip of what falls when the prop is hit. `PropReactions` fades and shakes the canopy (docs/WORLD.md, "Prop reactions").

Only props whose overhang reaches past their hull get a canopy (trees, the crane's jib). Billboards and bus stops collide across their whole footprint, so they don't.

### Scenes

`world/art/props/<id>.tscn`, for every non-DECOR prop, is written by `scene_tscn` in `bake_world.py`:

- Root `StaticBody2D`, layer 1, mask 0, no script, so `World.isWall` treats props as walls with no extra code. State is metadata: `propId`, `propClass`, and for breakables `smashSpeed`, `broken`, `debris`, `explosive`. `ChunkView` attaches `BreakableProp`, which reads it.
- `Sprite2D` (variant 0; `ChunkView` swaps the texture), `CollisionShape2D` from the hull, and a one-sided `LightOccluder2D` with metadata `gc_world = true`, so it stays on at Lighting Low.
- `Canopy` (z 8 absolute: `CANOPY_Z` in `bake_world.py` and `PropReactions` must agree), overlays and `Beacon` are extra sprites. A canopy and a beacon each count as one more node in `ChunkRecipe`'s budget.

## The manifest

`world/art/props.json`: `{version, texelsPerPx, classes, props: {id: {...}}}`. Per prop: `class`, `sizePx`, `variants` (paths), `hull` (convex, world px round the sprite's center, wound for `cull_mode = 2`; empty for decor), `occluder`, `breakable` (`null` or `{smashSpeed, broken, debris, debrisCells, blastOnly}`), `explosive`, `scene`, and where they apply `solid: false`, `atlas` (decor), `beacon`, `canopy`, `leaves`, `overlays`, `states`.

`tags` are hints only; no game code reads them.

## Posters

`world/art/posters/<id>.png`, one per level, named by `LevelDef.poster`: a top-down vignette built from the same ground materials, props, cars (`CarArt`) and goons (`GoonArt`), no text. Each `POSTER` entry is a `ground(X, Y, o)` per-pixel function and a `dress(p)` function that queues props, decor, the car and goons; the shared helpers sit beside it in `world_gen.js`. `test_world_art.gd` checks the posters are exactly the levels in `Levels.ORDER`.

## Adding a prop

1. Add a design to `PROPS`: `cls`, `box`, `n`, `shadow`, `grime`, `draw(c, R, v)`, and `core` if the hull should be smaller than the drawing. Breakables get `breakable: {smashSpeed, box, broken(c, R), cell, debris(c, R, k)}`.
2. `python scripts/art/bake_world.py prop --only <id>`, then `--import`.
3. Dress it in and give it its rules and reaction (docs/WORLD.md, "How to add a prop").
4. Add the id to `CATALOG` in `tests/game/test_world_art.gd`.

## Adding a ground material or strip

Add a function to `GROUND` (512 texels; periodic `fbm`/`worley` and `scatter`/`wrapAt` so it tiles) or `EDGE` (512×96, periodic in x only), bake `ground` or `edge`, import, and add the name to `GROUNDS` or `EDGES` in the test.
