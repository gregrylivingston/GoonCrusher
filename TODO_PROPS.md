# Road atlas: new props to wire in after the art lands

The art agent is baking these into `world/art/props.json` (ids from the road atlas contract). The landscape and
region data may only name props that `props.json` has today (`test_landscapes.gd` and `test_world_art.gd` check
it), so they are not wired yet. Once a prop is baked, add it where listed below and run the tests.

Weights are first guesses, on the same scale as the landscape's existing entries. "Decor" props go in the same
`dressing` table; `WorldSkin` sends DECOR-class ids to the MultiMesh decor.

## Landscape natural dressing (`world/landscapes/<id>.tres`, `dressing`)

| Prop | Landscape | Weight | Notes |
|---|---|---|---|
| `ranger_tower` | `forest` | 1 | A hero prop for Moose Woods and Sawmill Landing. Consider a motif with `cabin` and `logpile`. |
| `fallen_trunk` | `forest` | 3 | Also in `forest_snow` (2). |
| `pine_snow` | `forest_snow` | 10 | Replaces `pine` (set `pine` to 0 or remove it). Also `mountain` if it should get snowy pines (it renders identically today, so check with the author first). |
| `palm` | `coast` | 6 | |
| `beach_hut` | `coast` | 2 | Replaces `shack` (2) as the coast's building. |
| `lifeguard_tower` | `coast` | 1 | |
| `wagon` | `ghosttown` | 2 | |
| `water_trough` | `ghosttown` | 2 | |
| `tumbleweed` | `ghosttown` | 4 | DECOR. Also `saltflats` (2). Add it to `WorldSkin.BEND_DECOR` if it should lean away from the car like tufts. |
| `mile_marker` | `saltflats` | 3 | Lines the roads: add it to `WorldSkin.ROAD_PROPS` so it may stand on asphalt. |
| `salt_mound` | `saltflats` | 3 | |
| `rock_black` | `volcano` | 4 | Replaces `rock_red` (3) and `boulder_red` (2). |
| `steam_vent` | `volcano` | 3 | DECOR. Glowing at night would need `"blend": "add"` in its atlas entry. |
| `mailbox` | `suburbs` | 3 | Kerbside: maybe `WorldSkin.ROAD_PROPS`. |
| `swingset` | `suburbs` | 1 | |
| `trampoline` | `suburbs` | 1 | Cul-de-Sac's hero prop. |

## Region overlays (`scripts/world/territories.gd`, `DATA[region].dressing`, by zone 0 / 1 / 2)

| Prop | Region | Zone weights | Notes |
|---|---|---|---|
| `hunting_stand` | `hunting` | 0 / 1 / 2 | Big Game's own prop. |
| `trashbags` | `sprawl` | 1 / 2 / 3 | Street Swarm's own prop, beside the dumpsters. |

## Landmarks (no wiring needed)

`landmark_big` (Hunting Grounds), `landmark_swarm` (The Sprawl) and `landmark_war` (The Works) are already named in
`Territories.DATA[region].landmark`. Until props.json has them, `Territories.landmark()` returns the region's
`landmarkFallback` (`landmark_wild`, `landmark_tribe` and `landmark_scrap`). Once baked:

- give each a `beacon` like the existing three (`test_world_art.gd` checks the three in `LANDMARKS`; add the new ids
  to that list and to `WorldSkin.LANDMARKS`'s comment);
- they already shake when hit (`PropReactions.REACT`).

## Ground materials and edge strips (no wiring needed)

The new landscapes already name their materials and strips (`materials`, `roofMaterial`, `wallStrip` in each
`.tres`). `Landscapes.skinOf()` draws a landscape with its fallback's skin until every one of them exists in
`world/art/ground/` and `world/art/edges/`, so each landscape switches over by itself once its whole set is baked:

| Landscape | Needs | Fallback until then |
|---|---|---|
| `forest` | `needles` | `meadow` |
| `forest_snow` | `needles` | `mountain` |
| `coast` | `beach` | `bayou` |
| `ghosttown` | `roof_timber`, `timber_edge` | `city` |
| `saltflats` | `salt` | `canyon` |
| `volcano` | `ash`, `tar`, `lava`, `basalt`, `basalt_lip` | `canyon` (the lava glow applies from day one) |
| `suburbs` | `lawn`, `roof_shingle`, `shingle_edge` | `city` |

Check each wave with `--world-preview` and `-- --landscape=<id>` on any level, and add the new ground names to
`test_world_art.gd`'s `GROUNDS` and `EDGES` lists.
