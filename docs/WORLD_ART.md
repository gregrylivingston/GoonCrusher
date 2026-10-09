# World art

The ground, edges, props, station textures and level posters are generated top-down art in the same "Dust & Rust" style as the cars and goons. The bake writes everything into `res://world/art/`. Where things go is docs/WORLD.md.

## Files

| Path | What |
|---|---|
| `scripts/art/art_core.js` | Shared helpers: seeded `rng`, noise and periodic `fbm`/`worley`, colour maths, the overhead-lit `vol`/`polyVol`, `facetRock`, `tire`, grime, and the alpha-mask convex `hull`. (`car_gen.js` and `goon_gen.js` keep their own copies so their output never changes.) |
| `scripts/art/world_gen.js` | The generator (`window.WorldArt`): `GROUND` (materials), `EDGE` (strips), `PROPS` (the catalog: class, size and a draw function per prop), `STATION`, `POSTER` (one vignette per level) and the bake functions. **Change world art here.** |
| `scripts/art/bake_world.html`, `scripts/art/bake_world.py` | The bake. `python scripts/art/bake_world.py [job ...] [--only id,id]` opens `bake_world.html#<job>:<ids>` in headless Edge (3 in parallel) and writes the files, `props.json`, the prop scenes and every `.import` file. |
| `world/art/ground/` | 20 seamless materials (`<name>.png`, 512²) and `macro_noise.png` (256², greyscale). |
| `world/art/edges/` | 9 edge strips for `Line2D` (512×96). |
| `world/art/props/` | Each prop's variants (`<id>.png`, `<id>_v1.png`...), breakable and explosive states (`<id>_broken.png`, `<id>_debris.png`), the landmarks' beacon glows (`<id>_beacon.png`) and its scene (`<id>.tscn`). |
| `shader/world_beacon.gdshader`, `shader/world_beacon.tres` | The landmarks' beacon: additive, unlit, a slow breath and a double flash, out of step per landmark; `gc_motion` (Reduce Motion) calms it. One shared material; its `night` parameter dims it to 15% by day, faded by `Level.fadeBeacons` with the day and night. |
| `world/art/decor/` | One atlas per decor id (`<id>.png`, a row of 4 square cells). |
| `world/art/props.json` | The prop manifest (below). |
| `world/art/station/` | `station_lot`, `station_roof` (512² tiles), `station_wall` (strip; unused since the lot lost its walls), `station_lamp` and `station_pump` (sprites). |
| `world/art/posters/` | The 8 level posters, `<level id>.png`, 1792×1024. |
| `tests/game/test_world_art.gd` | Manifest vs. files and scenes, hull shape, occluders, level dressing ids, ground, edges, station and posters. |

**Never edit the baked files by hand; change the generator and re-bake.** That includes the `.tscn` files and `props.json`.

## Re-baking

```
python scripts/art/bake_world.py                          # everything: about 1.5 minutes
python scripts/art/bake_world.py ground edge              # jobs: ground edge prop decor station poster
python scripts/art/bake_world.py prop --only oak,crate    # a few props (props.json keeps the others)
python scripts/art/bake_world.py poster --only city
Godot_console.exe --headless --path . --import
```

- The script writes each new PNG's `.import` file before Godot sees it: mipmaps on for everything, VRAM compression with high quality (BC7/BPTC on desktop) for `ground/*` (not the macro noise), `posters/*`, `station_lot` and `station_roof`, lossless for the rest. A re-bake keeps an existing `.import` file's uid and only rewrites the compression and mipmap lines, so no manual mipmap step is needed (unlike cars and goons).
- Prop scenes are written without uids; Godot assigns them on import.
- `--workers N` sets how many Edge processes run at once (default 3). Each gets a scratch profile.
- The bake is deterministic: no `Math.random`, no `Date`. Re-baking without changes gives the same pixels.
- Prop tags (`tags.levels`, `tags.faction`) come from the `dressing` tables in `world/levels/*.tres` at bake time, merged with tags set in the design. Re-bake props (`prop decor`) after changing a level's dressing. (Before package 14 the dressing regex stopped at the last faction's brace, so each level's last table, usually Scrap, was never tagged; fixed in `level_tags`.)

## Rules

- **Light from straight overhead.** Nothing implies a sun direction. Height reads only through ambient occlusion: a dark contact band at the foot of cliffs, props and buildings, and a lighter lip on top edges. So every sprite and strip may be rotated and flipped freely.
- **Contact shadows are centred** under each prop (a blurred silhouette, `shadow` in the design). Props get a **1.0 px rim** in `rgba(18,13,16,.9)`, thinner than the goons' 1.6, so the actors stay the most outlined thing on screen. Flat things (decor, the manhole, scorch and debris remains) have no rim.
- **Palette:** ground mid-value (about 35-60% luminance) and less saturated than the actors. Never use telegraph red `#ff5c30`, HUD orange `#f0a030` or Scrap teal `#2aa6a1` as a large fill. Teal appears only as small daubs on Scrap Gang props; the Tribe's orange is the rag colour `#e0782c`. Deep water is slate (`#284a57`), not teal. Bake at final brightness: no modulates above 1.
- Known exceptions: snow (`#c5cbd1`, about 78%) and deep snow are brighter than the mid-value band, because snow has to read as snow; asphalt and deep water sit a little below it.
- **Texel density:** ground 0.5 texels per world px (a 512 tile covers 1024 px), props, strips and decor 0.75 (shown at scale 1/0.75 = 1.3333), matching the goons.
- **Grime:** props get the goons' grime pattern (`#2e2218`) source-atop at their `grime` alpha. Tiles use the seamless twin (`grimeTile`, 128 px with a periodic lattice) so it never seams.

## Ground materials

`grass`, `moss`, `dirt`, `sand`, `mud`, `mudpit`, `snow`, `deepsnow`, `ice`, `asphalt`, `lot`, `wash`, `oil`, `shallows`, `water` (deep), `conveyor`, `rock` (cliff and mountain tops), `roof` (building rooftops), `bridge` (deck planks), `gravel`.

- Seamless: every noise call wraps its lattice (`fbm(u*k, v*k, seed, oct, k)`), and strokes and pebbles near an edge are drawn again on the far side (`wrapAt`). Sample them with repeat on.
- `conveyor` moves along **+x**: cleats run across x every 32 texels and the worn chevrons point +x. Rotate the UVs with the belt direction.
- `bridge` planks run across x (each board's long axis is y), so a deck laid along x has boards across the direction of travel.
- `ice` and `shallows` keep their cell patterns faint so the 1024 px repeat doesn't show: the ice's Voronoi cracks are masked by a second noise and kept under 16% (the skate scratches carry the look), and the shallows' caustics are ridged noise (organic lines, no cells) at about 13%.
- `macro_noise.png` is 256² tileable greyscale, stretched to the full 0-255 range, for macro variation and organic borders between materials in the ground shader.
- 512² BC7 with mipmaps is about 350 KB of VRAM per material.

## Edge strips

512×96 texels at 0.75 density (a 128 px wide `Line2D` shows them 1:1). They tile along x; draw them with `Line2D` texture mode Tile and `texture_repeat` enabled.

| Strip | Top (v = 0) | Bottom (v = 1) |
|---|---|---|
| `shore_foam` | water side: faint shallow tint, then the foam line | wet bank darkening that fades out |
| `cliff_lip` | rock top fading in, then the lit lip | dark AO band at the foot |
| `canyon_rim` | the canyon: dark stratified wall | lit red lip, rubble, light fade |
| `mesa_lip` | mesa top fading in, lit lip, stratified face | AO and talus at the foot |
| `kerb` | kerb stones with joints, then the kerb face | gutter shadow over the road |
| `snow_ridge` | the bank's crest | blue lee shadow |
| `hedge` | symmetric: AO, hedge body in the middle, AO | |
| `scrapwall` | symmetric: AO, junk panels, tyres and teal daubs in the middle, AO | |
| `roof_edge` | the roof: AO cast by the parapet, its inner face, the lit coping (joints every 40 texels), its outer face on the contour | the building's AO on the pavement |

`roof_edge` is the city's wall strip (`WorldSkin.WALL_STRIP`). One-sided strips put the barrier (water, cliff top, canyon, kerb, roof) at the top (v = 0). Which side of a `Line2D` that lands on depends on the direction of its points, so build contours with a consistent winding and reverse the points if the lip faces the wrong way. `ChunkRecipe` does this: its lines run with the barrier on the left (docs/WORLD.md).

## Props

`PROPS` in `world_gen.js` holds one design entry per prop: `cls`, `box` (the world px the drawing may use, centred), `n` (variants), `shadow` (blur radius), `grime`, `draw(ctx, rng, variant)`, and optionally `core` (the solid part, for the hull), `occluder`, `breakable`, `explosive`, `solid` and `tags`.

### Classes

| Class | Meaning | Scene | Occluder |
|---|---|---|---|
| `DECOR` | MultiMesh sprite, no collision | none | never |
| `LOW` | pooled scene, collides, no shadow | yes | no |
| `TALL` | pooled scene, collides and casts a night shadow | yes | yes |
| `STATEFUL` | instanced scene with state: breakable, explosive or a spawn point | yes | per prop |
| `WALL` | wall segment | yes | yes |

### Catalog

The full list, with sizes, hulls and tags, is `props.json`. By class:

- **TALL:** (layered: `oak`, `pine`, `cypress`, `deadtree`, `crane`) `rock`, `boulder`, `rock_white`, `rock_ice`, `rock_red`, `boulder_red`, `oak`, `pine`, `cypress`, `saguaro`, `deadtree`, `shack`, `tent`, `totem`, `crane`, `cabin`, `snowcat`, `billboard`, `scrapheap`, `container`, and the landmarks `landmark_wild`/`_tribe`/`_scrap` (each with a beacon glow).
- **LOW:** `log` (the Snapper's disguise), `stump`, `carcass` (Buzzard perch), `firepit`, `tyres`, `wreck` (rusted renders of the player's cars), `cone`, `gaspump`, `sign`, `hydrant`, `dumpster`, `busstop`.
- **STATEFUL:** `haybale`, `fence`, `hedge`, `crate` (Bandit bait), `barricade`, `barrel` (explosive), `tank` (explosive, blast only), `manhole` (not solid; Rat Pack spawn), and the interactive props `logpile`, `watertower`, `beehive` (package 14; what they let loose: docs/WORLD.md, "Interactive props"). The `billboard` (TALL) is breakable too: its broken state is the board lying flat on its +y side. Smash speeds: docs/WORLD.md, "Breakables".
- **WALL:** `fortwall`, `jersey`.
- **DECOR:** `tufts`, `pebbles`, `cracks`, `bones`, `paint`, `oilstain`, `reeds`, `streetglow`, and `rooftop` (laid on BUILDING cells by `ChunkRecipe.placeRoofs`, not by dressing).

### How a prop is baked

1. The design draws into a canvas at 0.75 texels per px, centred on the prop's origin.
2. Grime goes on source-atop; then the centred shadow (the silhouette, blurred), the rim (the silhouette stamped 12 times 1 px out) and the body.
3. The hull is the convex hull of the body's pixels with alpha > 140 (or of the `core` drawing), reduced to at most 10 points by dropping the vertex that removes the least area, in world px around the sprite's centre. One hull serves the collision shape and the occluder.
4. **Wrecks** load `car_gen.js` and call `CarArt.render(car, {style: 'A', stage: 2})` at 0.75, then desaturate them and add rust and moss, so the wrecks are the player's own car models.
5. **Beacons:** a design with `beacon(c)` also bakes `<id>_beacon.png`: glows drawn at final brightness in the prop's own frame (same canvas size and centre as the sprite), no rim or shadow. The manifest gets `beacon` and the scene a `Beacon` node.
6. **Breakables** also bake `<id>_broken.png` (what stays on the ground, no collision) and `<id>_debris.png` (a row of 4 square cells of flying pieces, for particles or flyers). Explosives bake a scorched `_broken` and a shard `_debris` strip. The tank's `smashSpeed` is 100000 with `blastOnly`: only explosions break it.
7. **Decor** atlases are a row of 4 square cells (`atlas.cellTexels` wide each), with no rim and at most a faint shadow. The game draws one `MultiMeshInstance2D` per decor id per chunk (`WorldSkin.newMultiMesh`, `use_custom_data` on) and picks the cell per instance from its custom data in `shader/world_decor.gdshader`: `UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * cells)) / cells;`. `streetglow` is a warm light pool baked at final brightness for additive blending (`atlas.blend = "add"`), drawn with `shader/world_decor_glow.gdshader`.

### Layered props

A design with a `canopy(c, R, v)` drawing is baked in two layers (package 14): `draw` becomes the **ground layer** (`<id>.png` and its variants: roots, the trunk's top and leaf litter for trees, the cab and tracks for the crane) with the canopy's silhouette baked under it as a soft shade (`shadowOf`), and the canopy becomes `<id>_canopy.png` (`_canopy_v1`...), rimmed, no shadow, drawn over the car. The canopy keeps the variant's random stream, so the crowns look as they did before the split; the ground layer has its own (`litter(c, R, v)` draws unrimmed litter between the shade and the trunk; `baseShadow` sets the ground layer's own shadow, 3 by default). The hull comes from `core` as before, so collision and night occluders stay on the trunk. A `leaves(c, R, k)` drawing bakes `<id>_leaves.png`, a row of 4 square cells of `LEAF_CELL` (28) px: what falls when the prop is hit (oak and cypress leaves, Spanish moss, pine needles and snow clumps, dead twigs). The manifest gets `canopy` (one path per variant) and `leaves`; posters draw the canopy over the ground layer. The saguaro stays one piece. PropReactions fades and shakes the canopy (docs/WORLD.md, "Prop reactions").

Over-the-car layers were reviewed for every tall prop: the crane's jib reaches past its hull, so it has one; billboards and bus stops collide across their whole footprint and landmarks' and tents' overhang is ground clutter, so they don't.

### Scenes

`world/art/props/<id>.tscn` for every non-DECOR prop:

- Root `StaticBody2D` named after the id, `collision_layer = 1`, `collision_mask = 0`, no script. Metadata: `propId`, `propClass`; breakables add `smashSpeed`, `broken` and `debris` (texture paths); explosives add `explosive = true`.
- `Sprite2D` at scale 1.3333 with variant 0. Swap `texture` for another variant from the manifest.
- `CollisionShape2D` with a `ConvexPolygonShape2D` from the hull (disabled when the manifest says `solid: false`).
- `LightOccluder2D` with the same polygon, `cull_mode = 2` (one-sided), and metadata `gc_world = true`, so it stays on at Lighting Low. Only when the manifest says `occluder: true`.
- `Canopy` (layered props): a `Sprite2D` at scale 1.3333 with canopy variant 0, `z_index = 8` with `z_as_relative = false` (`CANOPY_Z` in `bake_world.py` and `PropReactions`), so it draws over goons and the car. No collision. `ChunkView` swaps its texture with the variant. It counts as one more node in `ChunkRecipe`'s budget.
- `Beacon` (landmarks): a `Sprite2D` at scale 1.3333 with the `_beacon.png` glow and the shared `res://shader/world_beacon.tres` material (`blend_add, unshaded`), so the landmark's top reads at night with no real light (world lights stay at 0 per chunk). It counts as one more node in `ChunkRecipe`'s budget.

The root is a `StaticBody2D`, so the car's wall-hit checks (`World.isWall`) treat props as walls with no extra code. `ChunkView` instances STATEFUL props (and any prop with a taken-set bit) instead of pooling them and attaches `scripts/world/breakable.gd` (`BreakableProp`), which reads the metadata above (docs/WORLD.md, "Breakables and explosives").

## The manifest

`world/art/props.json`:

```json
{
 "version": 1,
 "texelsPerPx": 0.75,
 "classes": {"DECOR": "...", "LOW": "...", "TALL": "...", "STATEFUL": "...", "WALL": "..."},
 "props": {
  "crate": {
   "class": "STATEFUL",
   "sizePx": [88, 88],
   "variants": ["res://world/art/props/crate.png", "res://world/art/props/crate_v1.png", "res://world/art/props/crate_v2.png"],
   "hull": [[-44, -40], ...],
   "occluder": false,
   "breakable": {"smashSpeed": 150, "broken": "res://world/art/props/crate_broken.png", "debris": "res://world/art/props/crate_debris.png", "debrisCells": 4},
   "explosive": false,
   "tags": {"bait": true, "levels": ["bayou", "city", "crusher", "prairie"], "faction": ["wild", "tribe", "scrap"]},
   "scene": "res://world/art/props/crate.tscn"
  }
 }
}
```

- `hull`: 3-10 points, convex, in world px around the sprite's centre, wound for `cull_mode = 2`. Empty for decor.
- `breakable`: `null`, or `{smashSpeed, broken, debris, debrisCells}` plus `blastOnly` for the tank.
- `solid`: present and `false` when the prop must not collide (decor, the manhole).
- `atlas` (decor only): `{cells, cellPx, cellTexels, blend}`.
- `beacon` (landmarks): the glow texture's path.
- `tags.levels` and `tags.faction` come from the levels' dressing tables (faction keys 0, 1, 2 become `wild`, `tribe`, `scrap`).

## Station

`station_lot` (concrete slabs, 256 px joints, oil stains and tyre smears) and `station_roof` (worn shingles) are 512² seamless tiles; `station_wall` is a strip like the others (wall top above, AO below); `station_lamp` (lamp post with a lit fixture) and `station_pump` (a pump island) are sprites at 0.75 with the prop rim and shadow. `scene/level/station.tscn` is built from them: `lot` is a Sprite2D region over the LOT at scale 2 (open on every side: the walls are gone), the house roof two Sprite2D halves at scale 2 (the south one flipped) with a ridge and eaves, two pumps on the driveway apron and a lamp over each post light, all at 1.3333. The collision (`house`) and lights keep the old layout; `tintBarrier` reddens the house.

## Posters

`world/art/posters/<id>.png`, 1792×1024, one per level in `Levels.ORDER`: a top-down vignette of the level's signature barrier and surfaces at 0.75 poster px per world px, built from the same ground materials, props, cars (`CarArt`) and goons (`GoonArt`). Each `POSTER` entry is a `ground(X, Y, o)` per-pixel function and a `dress(p)` function that queues props, decor, tracks, the car and goons. No text. `LevelDef.poster` points here.

## Budget

About 44 MB on disk (posters 27 MB, ground 10 MB, props 5 MB). A level loads only its own materials (4–6), the props its dressing names and the three landmarks, about 17 MB of VRAM, inside the 48 MB budget. If props ever need trimming, switch `props/*` to VRAM compression in `VRAM` in `bake_world.py`.

## Adding a prop

1. Add a design entry to `PROPS` in `world_gen.js`: `cls`, `box`, `n`, `shadow`, `grime`, `draw(c, R, v)` (overhead light: `vol`, `polyVol`, `crown` for the crown highlight and rim darkening), and `core` if the hull should be smaller than the drawing. Breakables get `breakable: {smashSpeed, box, broken(c, R), cell, debris(c, R, k)}`.
2. `python scripts/art/bake_world.py prop --only <id>`, then `--import`.
3. Add it to a level's `dressing` in `world/levels/<id>.tres` and re-bake props so its tags update.
4. Add the id to `CATALOG` in `tests/game/test_world_art.gd`.

## Adding a ground material or strip

Add a function to `GROUND` (512 texels; use periodic `fbm`/`worley` and `scatter`/`wrapAt` so it tiles) or `EDGE` (512×96, periodic in x only: pass `0` as the y period), bake `ground` or `edge`, import, and add the name to `GROUNDS` or `EDGES` in the test.
