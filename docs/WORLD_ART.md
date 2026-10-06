# World art

The world's ground, edges, props, station textures and level posters are original top-down art drawn by a code generator, in the same "Dust & Rust" style as the cars (docs/CAR_ART.md) and goons (docs/GOONS.md). They replace the third-party isometric tile packs, the pre-rendered rocks, the station's photo textures and the old painted posters. The bake writes everything into `res://world/art/`. The world system (docs/WORLD.md) decides where things go; this page covers what they look like and how they are made.

## Files

| Path | What |
|---|---|
| `scripts/art/art_core.js` | Shared helpers: seeded `rng`, `hash2`, value noise and `fbm` (with an optional period, so tiles are seamless), periodic `worley`, colour maths, the overhead-lit `vol`/`polyVol`, `facetRock` and `tire` from the goon rigs, the grime pattern (plus a seamless twin), and the alpha-mask convex `hull`. Copied from `car_gen.js` and `goon_gen.js`, which keep their own copies so their output never changes. |
| `scripts/art/world_gen.js` | The generator (`window.WorldArt`): `GROUND` (materials), `EDGE` (strips), `PROPS` (the catalog: class, size and a draw function per prop), `STATION`, `POSTER` (one vignette per level) and the bake functions. **Change world art here.** |
| `scripts/art/bake_world.html`, `scripts/art/bake_world.py` | The bake. `python scripts/art/bake_world.py [job ...] [--only id,id]` opens `bake_world.html#<job>:<ids>` in headless Edge (3 in parallel) and writes the files, `props.json`, the prop scenes and every `.import` file. |
| `world/art/ground/` | 20 seamless materials (`<name>.png`, 512²) and `macro_noise.png` (256², greyscale). |
| `world/art/edges/` | 8 edge strips for `Line2D` (512×96). |
| `world/art/props/` | Each prop's variants (`<id>.png`, `<id>_v1.png`...), breakable and explosive states (`<id>_broken.png`, `<id>_debris.png`) and its scene (`<id>.tscn`). |
| `world/art/decor/` | One atlas per decor id (`<id>.png`, a row of 4 square cells). |
| `world/art/props.json` | The prop manifest (below). |
| `world/art/station/` | `station_lot`, `station_roof` (512² tiles), `station_wall` (strip), `station_lamp` and `station_pump` (sprites). |
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
- Prop tags (`tags.levels`, `tags.faction`) come from the `dressing` tables in `world/levels/*.tres` at bake time, merged with tags set in the design. Re-bake props (`prop decor`) after changing a level's dressing.

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

One-sided strips put the barrier (water, cliff top, canyon, kerb) at the top (v = 0). Which side of a `Line2D` that lands on depends on the direction of its points, so build contours with a consistent winding and reverse the points if the lip faces the wrong way.

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

Sizes are the solid sprite (alpha > 140) in world px; the hull may be smaller (`core`).

| Id | Class | Size | Variants | Occluder | Notes |
|---|---|---|---|---|---|
| `rock` | TALL | 141×119 | 3 | yes | the Boulder goon's facet rig, so it hides among real rocks |
| `boulder` | TALL | 280×235 | 2 | yes | three fused rocks |
| `rock_white` | TALL | 145×125 | 2 | yes | pale limestone (quarry, frostbite) |
| `rock_ice` | TALL | 144×120 | 2 | yes | ice block |
| `oak` | TALL | 271×237 | 3 | yes | hull is the canopy core (r 58) |
| `pine` | TALL | 180×172 | 3 | yes | variant 2 is snowy; core r 36 |
| `cypress` | TALL | 213×213 | 2 | yes | Spanish moss; core r 48 |
| `log` | LOW | 243×56 | 2 | | the Snapper's disguise |
| `stump` | LOW | 115×117 | 2 | | |
| `saguaro` | TALL | 140×95 | 2 | yes | core r 34 |
| `deadtree` | TALL | 245×229 | 2 | yes | core is the trunk |
| `carcass` | LOW | 207×95 | 2 | | Buzzard perch |
| `haybale` | STATEFUL | 124×123 | 2 | | breakable at 250 px/s |
| `fence` | STATEFUL | 317×21 | 2 | | breakable at 180; rails or wire |
| `hedge` | STATEFUL | 388×96 | 2 | yes | breakable at 300 |
| `crate` | STATEFUL | 88×88 | 3 | | breakable at 150; Bandit bait (`tags.bait`) |
| `shack` | TALL | 373×299 | 2 | yes | metal or plank roof |
| `tent` | TALL | 192×195 | 2 | yes | hide tent, orange rag |
| `totem` | TALL | 107×111 | 2 | yes | orange rags and a skull |
| `firepit` | LOW | 136×129 | 1 | | |
| `tyres` | LOW | 99×99 | 3 | | |
| `barricade` | STATEFUL | 255×93 | 2 | | breakable at 350 |
| `barrel` | STATEFUL | 53×53 | 3 | | breakable at 120, explosive |
| `crane` | TALL | 541×216 | 1 | yes | hull is the tracks and deck, not the boom |
| `fortwall` | WALL | 405×111 | 2 | yes | junk fort segment |
| `cabin` | TALL | 341×280 | 2 | yes | snowy or patchy roof |
| `snowcat` | TALL | 260×160 | 1 | yes | |
| `wreck` | LOW | 92×193 | 5 | | rusted stage-2 renders of sedan, van, taxi, pickup and police |
| `jersey` | WALL | 320×51 | 2 | yes | |
| `cone` | LOW | 43×43 | 2 | | |
| `gaspump` | LOW | 179×65 | 2 | | |
| `sign` | LOW | 73×51 | 3 | | knocked-down stop sign, standing plate, arrow post |
| `billboard` | TALL | 381×48 | 2 | yes | |
| `hydrant` | LOW | 43×36 | 1 | | |
| `dumpster` | LOW | 168×96 | 2 | | |
| `busstop` | LOW | 256×88 | 1 | | |
| `manhole` | STATEFUL | 61×61 | 1 | | not solid (collision disabled); Rat Pack spawn point |
| `scrapheap` | TALL | 264×237 | 3 | yes | |
| `container` | TALL | 484×189 | 3 | yes | rust, slate, olive |
| `tank` | STATEFUL | 299×299 | 1 | yes | explosive; blast only |
| `landmark_wild` / `_tribe` / `_scrap` | TALL | about 430 | 1 | yes | district landmarks; hull is the centre piece |
| `tufts`, `pebbles`, `cracks`, `bones`, `paint`, `oilstain`, `reeds`, `streetglow` | DECOR | 64-384 cells | 4 cells | | |

### How a prop is baked

1. The design draws into a canvas at 0.75 texels per px, centred on the prop's origin.
2. Grime goes on source-atop; then the centred shadow (the silhouette, blurred), the rim (the silhouette stamped 12 times 1 px out) and the body.
3. The hull is the convex hull of the body's pixels with alpha > 140 (or of the `core` drawing), reduced to at most 10 points by dropping the vertex that removes the least area, in world px around the sprite's centre. One hull serves the collision shape and the occluder.
4. **Wrecks** load `car_gen.js` and call `CarArt.render(car, {style: 'A', stage: 2})` at 0.75, then desaturate them and add rust and moss, so the wrecks are the player's own car models.
5. **Breakables** also bake `<id>_broken.png` (what stays on the ground, no collision) and `<id>_debris.png` (a row of 4 square cells of flying pieces, for particles or flyers). Explosives bake a scorched `_broken` and a shard `_debris` strip. The tank's `smashSpeed` is 100000 with `blastOnly`: only explosions break it.
6. **Decor** atlases are a row of 4 square cells (`atlas.cellTexels` wide each), with no rim and at most a faint shadow. Use one `MultiMeshInstance2D` per decor id and pick the cell per instance, for example with the instance's custom data in a small canvas shader's `vertex()`: `UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * 4.0)) / 4.0;` (enable `use_custom_data` on the MultiMesh). `streetglow` is a warm light pool baked at final brightness, meant for additive blending (`atlas.blend = "add"`).

### Scenes

`world/art/props/<id>.tscn` for every non-DECOR prop:

- Root `StaticBody2D` named after the id, `collision_layer = 1`, `collision_mask = 0`, no script. Metadata: `propId`, `propClass`; breakables add `smashSpeed`, `broken` and `debris` (texture paths); explosives add `explosive = true`.
- `Sprite2D` at scale 1.3333 with variant 0. Swap `texture` for another variant from the manifest.
- `CollisionShape2D` with a `ConvexPolygonShape2D` from the hull (disabled when the manifest says `solid: false`).
- `LightOccluder2D` with the same polygon, `cull_mode = 2` (one-sided, wound like `scene/scenery/rocks1.tscn`), and metadata `gc_world = true`, so it stays on at Lighting Low. Only when the manifest says `occluder: true`.

The root is a `StaticBody2D`, so the car's wall-hit checks (`World.isWall`) treat props as walls with no extra code. A later phase adds the breakable script.

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
- `tags.levels` and `tags.faction` come from the levels' dressing tables (faction keys 0, 1, 2 become `wild`, `tribe`, `scrap`).

## Station

`station_lot` (concrete slabs, 256 px joints, oil stains and tyre smears) and `station_roof` (worn shingles) are 512² seamless tiles; `station_wall` is a strip like the others (wall top above, AO below); `station_lamp` (lamp post with a lit fixture) and `station_pump` (a pump island) are sprites at 0.75 with the prop rim and shadow. `scene/level/station.tscn` is built from them: `lot` is a Sprite2D region over the LOT at scale 2, `walls` one tiled Line2D (width 142, so the 35-texel wall top covers the 52 px wall bodies and its shadow falls inside the lot) traced clockwise so the strip's top faces out, the house roof two Sprite2D halves at scale 2 (the south one flipped) with a ridge and eaves, two pumps on the driveway apron and a lamp over each post light, all at 1.3333. The collision (`wallNorth`/`South`/`West`/`East`, `house`) and lights keep the old layout; `tintWalls` reddens `walls`.

## Posters

`world/art/posters/<id>.png`, 1792×1024, one per level in `Levels.ORDER`: a top-down vignette at 0.75 poster px per world px (a 2389×1365 px window of the world), built from the same ground materials, props, cars (`CarArt`) and goons (`GoonArt`):

| Poster | Signature |
|---|---|
| `prairie` | a creek with a ford where the dirt track crosses, hedgerows, a rail fence, oaks, a hay field |
| `bayou` | lakes and channels, a plank boardwalk, cypresses, reeds, lily pads, floating logs, a shack |
| `canyon` | a stratified red canyon, a mesa, a dry wash with the racer, saguaros, a tribal camp, a carcass with a buzzard |
| `quarry` | a terraced pit with a ramp, a haul road, a junk fort ring with orange-rag totems, a crane |
| `frostbite` | snowy terraced ridges around a pass, a frozen lake, pine stands, a cabin, a snowcat |
| `highway` | a desert highway with lane paint, jersey barriers, a wreck pile-up, a gas station, a billboard |
| `city` | a street grid at dusk with lamps, a canal under two bridges, rooftops, a park, a parking lot, a police car |
| `crusher` | scrap mountains, container rows, two conveyor lanes, a tank farm, a crane |

Each `POSTER` entry is a `ground(X, Y, o)` function (per pixel: materials, blend, tint, AO, lip, foam, paint) and a `dress(p)` function that queues props, decor, tyre tracks, the car and goons; the queue draws by layer and y. `city` gets a dusk multiply before its lights. Every poster gets a soft vignette and no text. Every `LevelDef.poster` (`world/levels/<id>.tres`) points at its poster here; the old paintings are deleted.

## Budget

| Group | Files | Disk | VRAM (estimated, with mipmaps) |
|---|---|---|---|
| ground (BC7, macro lossless) | 21 | 10.4 MB | 7.3 MB |
| edges | 8 | 0.4 MB | 2.1 MB |
| props (lossless) | 102 | 4.1 MB | 20.7 MB |
| decor | 8 | 0.4 MB | 3.2 MB |
| station | 5 | 1.2 MB | 1.1 MB |
| posters (BC7) | 8 | 27.4 MB | 19.6 MB |

A level loads only its own materials (4-6, about 2 MB) and the props its dressing names (a third to a half of the props), so world textures per level stay around 15 MB, well inside the 48 MB budget. If props ever need trimming, switch `props/*` to VRAM compression in `VRAM` in `bake_world.py` (BC7 keeps the alpha clean).

## Adding a prop

1. Add a design entry to `PROPS` in `world_gen.js`: `cls`, `box`, `n`, `shadow`, `grime`, `draw(c, R, v)` (overhead light: `vol`, `polyVol`, `crown` for the crown highlight and rim darkening), and `core` if the hull should be smaller than the drawing. Breakables get `breakable: {smashSpeed, box, broken(c, R), cell, debris(c, R, k)}`.
2. `python scripts/art/bake_world.py prop --only <id>`, then `--import`.
3. Add it to a level's `dressing` in `world/levels/<id>.tres` and re-bake props so its tags update.
4. Add the id to `CATALOG` in `tests/game/test_world_art.gd` if it is part of the spec's catalog.

## Adding a ground material or strip

Add a function to `GROUND` (512 texels; use periodic `fbm`/`worley` and `scatter`/`wrapAt` so it tiles) or `EDGE` (512×96, periodic in x only: pass `0` as the y period), bake `ground` or `edge`, import, and add the name to `GROUNDS` or `EDGES` in the test.
